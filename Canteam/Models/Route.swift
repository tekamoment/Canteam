//
//  Route.swift
//  Canteam
//
//  Created by Carlos Arcenas on 9/10/16.
//  Copyright © 2016 Carlos Arcenas. All rights reserved.
//

import UIKit
import Alamofire
import CoreLocation
import Gloss

class Route: NSObject {
    // key AIzaSyCfFVxVOG6MZk1-nq3g2NUYQpG4CWrZ4GA
    static let sharedInstance: Route = Route()
    
    override init() {
        super.init()
    }
    
    func fetchRouteLines(_ origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, waypoints: [CLLocationCoordinate2D]?, completion: @escaping(_ lines: String?) -> Void) {
        var waypointString = ""
        
        if waypoints != nil {
            for point in waypoints! {
                waypointString.append("via:\(point.latitude),\(point.longitude)|")
            }
            waypointString.remove(at: waypointString.index(before: waypointString.endIndex))
        }
        
        let originString = "\(origin.latitude),\(origin.longitude)"
        let destinationString = "\(destination.latitude),\(destination.longitude)"
        
        Alamofire.request("https://maps.googleapis.com/maps/api/directions/json?", method: .get, parameters: ["key" : "AIzaSyCfFVxVOG6MZk1-nq3g2NUYQpG4CWrZ4GA", "origin" : originString, "destination" : destinationString, "waypoints" : waypointString], encoding: URLEncoding.default).responseJSON { response in
            guard response.result.isSuccess else {
                print(response.result.value)
                return
            }
            
            let json = try! JSONSerialization.jsonObject(with: response.data!) as? [String: AnyObject]
            guard let item = json!["routes"] as? [AnyObject],
                let routes = item[0] as? [String: AnyObject],
                let polyline = routes["overview_polyline"] as? [String: AnyObject],
                let points = polyline["points"] else {
                completion(nil)
                return
            }
            
//            print("JSONSerialization: \(points)")
            
        
            completion(points as? String)
            
//            if let json = response.result.value as? NSDictionary {
//                print("json: \(json["routes"]))")
//                completion("")
//            }
//            
//            if let json = response.result.value as? JSON {
//                print("JSON FOR ROUTE: \(json["routes"])")
//                let routes = json["routes"] as! JSON
//                print("JSON FOR OVERVIEW: ")
//                //completion(json.string)
//                completion(routes["overview_polyline"] as! String?)
//            }
        }
    }
}
