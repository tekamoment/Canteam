//
//  HeatMap.swift
//  Canteam
//
//  Created by Carlos Arcenas on 9/10/16.
//  Copyright © 2016 Carlos Arcenas. All rights reserved.
//

import UIKit
import Alamofire
import CoreLocation
import Gloss

class HeatMapSource: NSObject {
    static let sharedInstance = HeatMapSource()
    fileprivate var canteens: [Canteen]?
    
    override init() {
        super.init()
    }
    
    func fetchCanteens(_ completion: @escaping (_ canteens: [Canteen]?) -> Void) {
        guard canteens != nil else {
            Alamofire.request("http://hackfestsg.leelinde.com/api/heat/?key=d41d8cd98f00b204e9800998ecf8427e").responseJSON { response in
                
                guard response.result.isSuccess else {
                    print("Error while fetching canteens.")
                    return
                }
                
                if let json = response.result.value as? JSON {
                    var jsonArray: [JSON] = [JSON]()
                    
                    for (_, value) in json {
                        jsonArray.append((value as? JSON)!)
                    }
                    
                    self.canteens = [Canteen].fromJSONArray(jsonArray)
                    completion(self.canteens)
                }
            }
            return
        }
        
        completion(self.canteens)
    }
}

enum Crowdedness {
    case extreme
    case high
    case medium
    case low
    case noData
}

struct Canteen: Decodable {
    let name: String
    let code: String
    let coordinates: CLLocationCoordinate2D
    let capacity: Int
    let color: String
    let percentage: Double
    let id: String
    let visitors: Int
//
    let crowd: Int?
    let lastUpdated: Date?
    
    init?(json: JSON) {
        guard let name: String = "canteen_name" <~~ json,
            let code: String = "canteen_code" <~~ json,
            let longitude: Double = Decoder.decodeDouble("canteen_longitude", json: json),
            let latitude: Double = Decoder.decodeDouble("canteen_latitude", json: json),
            let capacity: Int = Decoder.decodeStringyInt("canteen_capacity", json: json),
            let color: String = "color" <~~ json,
            let percentage: Double = "percentage" <~~ json,
            let lastUpdated: Double = "timestamp" <~~ json,
            let id: Int = "canteen_id" <~~ json,
            let visitors: Int = "visitors" <~~ json
            else { print("Error in decoding"); return nil }
        
        self.name = name
        self.code = code
        self.coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.capacity = capacity
        self.color = color
        self.percentage = percentage
        self.id = "\(id)"
        self.visitors = visitors
        
        self.crowd = "crowd" <~~ json
        self.lastUpdated = Date(timeIntervalSince1970: lastUpdated)
    }
    
    func crowdedness() -> Crowdedness {
        guard let currentCrowd: Int = crowd else {
            return .noData
        }
        
        let index = Double(currentCrowd / capacity)
        
        if index > 1.0 {
            return .extreme
        } else if index <= 1.0 && index > 0.75 {
            return .high
        } else if index <= 0.75 && index > 0.5 {
            return .medium
        } else {
            return .low
        }
    }
}

enum TransportMode {
    case walking
    case riding
}

class RouteSource: NSObject {
    static let sharedInstance = RouteSource()
    fileprivate var busStops: [BusStop]?
    
    override init() {
        super.init()
    }
    
    func fetchBusStops(_ completion: @escaping (_ busStops: [BusStop]?) -> Void) {
        guard busStops != nil else {
            Alamofire.request("http://hackfestsg.leelinde.com/api/stops/?key=d41d8cd98f00b204e9800998ecf8427e").responseJSON { response in
                
                guard response.result.isSuccess else {
                    print("Error while fetching canteens.")
                    return
                }
                
                if let json = response.result.value as? JSON {
                    
                    var jsonArray: [JSON] = [JSON]()
                    
                    for (_, value) in json {
                        jsonArray.append((value as? JSON)!)
                    }
                    
                    self.busStops = [BusStop].fromJSONArray(jsonArray)
                    completion(self.busStops)
                }
            }
            return
        }
        
        completion(self.busStops)
    }
    
    func fetchRoute(currentLocation: CLLocationCoordinate2D, canteen: Canteen, completion: @escaping (_ routeLegs: [(TransportMode, String)]?, _ directions: [(String, String)]?) -> Void) {
        let headers = ["Accept" : "application/json"]
        
        Alamofire.request("http://hackfestsg.leelinde.com/api/route/?key=d41d8cd98f00b204e9800998ecf8427e", method: .get, parameters: ["canteen" : "\(canteen.id)", "location": "\(currentLocation.latitude),\(currentLocation.longitude)"], encoding: URLEncoding.default, headers: headers).responseJSON { response in
            print("URL requested: \(response.request!)")
            
            guard response.result.isSuccess else {
                print(response.data!)
                print("Unable to request from Lin De API.")
                completion(nil, nil)
                return
            }
            
            print("JSON returns: \(response.result.value)")
            
            let json = try! JSONSerialization.jsonObject(with: response.data!) as? [String: AnyObject]
            
            guard let pointers = json!["pointers"] as? [[String: String]] else {
                print("Unable to do pointers.")
                completion(nil, nil)
                return
            }
            
            var directionsArray = [(String, String)]()
            
            for entry in pointers {
                directionsArray.append((entry["duration"]!, entry["text"]!))
            }
            
            guard let legs = json!["legs"] as? [[String: AnyObject]] else {
                print("Unable to do legs.")
                completion(nil, nil)
                return
            }
            
            let routeSharedInstance = Route.sharedInstance
            
            var routeLines = [(TransportMode, String)]()
            
            let requestsDispatchGroup = DispatchGroup()
            
            var currentIndex = 0
            
            for segment in legs {
                guard let origin = segment["origin"] as? [String: AnyObject],
                    let destination = segment["destination"] as? [String: AnyObject],
                    let mode = segment["mode"] as? String else {
                    
                    print("Disassembly not working")
                    completion(nil, nil)
                    return
                }
                
                guard mode == "WALKING" || mode == "DRIVING" else {
                    print("Invalid mode of transport.")
                    completion(nil, nil)
                    return
                }
                
                var transportMode: TransportMode
                
                if mode == "WALKING" {
                    transportMode = TransportMode.walking
                } else {
                    transportMode = TransportMode.riding
                }
                
                let originCoordinate = CLLocationCoordinate2D(latitude: Double(origin["latitude"]! as! String)!, longitude: Double(origin["longitude"]! as! String)!)
                let destinationCoordinate = CLLocationCoordinate2D(latitude: Double(destination["latitude"]! as! String)!, longitude: Double(destination["longitude"]! as! String)!)

                
                routeLines.append((transportMode, ""))
                
                var convertedWaypoints: [CLLocationCoordinate2D]?
                
                if let waypoints = segment["waypoints"] as? [String] {
                    convertedWaypoints = [CLLocationCoordinate2D]()
                    for wp in waypoints {
                        let coordsArray = wp.components(separatedBy: ",")
                        convertedWaypoints?.append(CLLocationCoordinate2D(latitude: Double(coordsArray[0])!, longitude: Double(coordsArray[1])!))
                    }
                }
                
                let currIndex = currentIndex
                
                requestsDispatchGroup.enter()
                routeSharedInstance.fetchRouteLines(originCoordinate, destination: destinationCoordinate, waypoints: convertedWaypoints, completion: { (routelines) in
                    guard routelines != nil else {
                        print("Error occured while sourcing routelines for index \(currentIndex)")
                        return
                    }
                    
                    routeLines[currIndex] = (transportMode, routelines!)
                    requestsDispatchGroup.leave()
                })
                
                currentIndex += 1
            }
            
            requestsDispatchGroup.notify(queue: DispatchQueue.main, execute: {
                completion(routeLines, directionsArray)
            })
            

        }
    }
}

struct BusStop: Decodable {
    let name: String
    let coordinates: CLLocationCoordinate2D
    var routes: [RouteStopInfo]
    
    init?(json: JSON) {
        guard let name: String = "bus_stop_name" <~~ json,
            let longitude: Double = Decoder.decodeDouble("bus_stop_longitude", json: json),
            let latitude: Double = Decoder.decodeDouble("bus_stop_latitude", json: json)
            //let routes: [RouteStopInfo] = "buses" <~~ json
            else { print("Error in decoding."); return nil }
    
        
//        print("Bus stop array: \(json["buses"] as! JSON)")
        
        routes = [RouteStopInfo]()
        
        for (_, value) in json["buses"]! as! JSON {
            routes.append(RouteStopInfo(json: value as! JSON)!)
        }
        
//        print("ROUTES: \(routes)")
        
        self.name = name
        self.coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        //self.routes = routes
    }
}

struct RouteStopInfo: Decodable {
    let routeNumber: String
    let stopOrder: Int
    
    init?(json: JSON) {
        guard let routeNumber: String = "bus_number" <~~ json,
            let stopOrder: Int = Decoder.decodeStringyInt("stop_order", json: json)
            else { print("Error in decoding."); return nil }
    
        self.routeNumber = routeNumber
        self.stopOrder = stopOrder
    }
}

extension Decoder {
    static func decodeDouble(_ key: String, json: JSON) -> Double? {
        if let string = json[key] as? String {
            return (string as NSString).doubleValue
        }
        
        return nil
    }
    
    static func decodeDate(_ key: String, json: JSON) -> Date? {
        if let string = json[key] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return dateFormatter.date(from:string)
        }
        
        return nil
    }
    
    static func decodeStringyInt(_ key: String, json: JSON) -> Int? {
        if let string = json[key] as? String {
            return (string as NSString).integerValue
        }
        
        return nil
    }
}
