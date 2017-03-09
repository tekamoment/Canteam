//
//  ViewController.swift
//  Canteam
//
//  Created by Carlos Arcenas on 9/10/16.
//  Copyright © 2016 Carlos Arcenas. All rights reserved.
//

import UIKit
import GoogleMaps
import Alamofire

enum MarkerDataType {
    case canteen
    case busStop
}

class ViewController: UIViewController {

    var locationManager: CLLocationManager!
    var mapView: GMSMapView?
    
    var selectedCanteen: Canteen? {
        didSet (oldValue) {
            guard selectedCanteen != nil else {
                return
            }
            
            self.dismissPresented()
            routeUser()
        }
    }
    
    var isPresentingRoute = false {
        willSet (newValue) {
            guard newValue == true else {
                return
            }
            
            presentRoute()
        }
        
        didSet {
    
        }
    }
    
    var busStopMarkers = [GMSMarker]()
    var canteenMarkers = [GMSMarker]()
    
    var presentedPolylines: [GMSPolyline]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let camera = GMSCameraPosition.camera(withLatitude: 1.2925365, longitude: 103.7747835, zoom: 18.0)
        let mapView = GMSMapView.map(withFrame: view.frame, camera: camera)
        mapView.isMyLocationEnabled = true
        mapView.delegate = self
        self.mapView = mapView
//        print(mapView.myLocation)
        
        view.addSubview(mapView)
        
        let heatMapSource = HeatMapSource.sharedInstance
        heatMapSource.fetchCanteens { (canteens) in
            for canteen in canteens! {
                // print("Canteen \(canteen.name) has current index \(canteen.crowdedness())")
                
                let canMarker = GMSMarker()
                canMarker.position = canteen.coordinates
                canMarker.title = canteen.name
                canMarker.snippet = "\(canteen.crowd!) people"
                canMarker.map = mapView
                canMarker.userData = (MarkerDataType.canteen, canteen) as (MarkerDataType, Any)
                
//                switch canteen.crowdedness() {
//                case Crowdedness.extreme:
//                    canMarker.icon = GMSMarker.markerImage(with: UIColor.red)
//                    break
//                
//                case Crowdedness.high:
//                    canMarker.icon = GMSMarker.markerImage(with: UIColor.orange)
//                    break
//                    
//                case Crowdedness.medium:
//                    canMarker.icon = GMSMarker.markerImage(with: UIColor.yellow)
//                    break
//                
//                case Crowdedness.low:
//                    canMarker.icon = GMSMarker.markerImage(with: UIColor.green)
//                    break
//                    
//                case Crowdedness.noData:
//                    canMarker.icon = GMSMarker.markerImage(with: UIColor.gray)
//                }
                canMarker.icon = #imageLiteral(resourceName: "CanteenIcon.png")
                self.canteenMarkers.append(canMarker)
            }
        }
        
        let routeSource = RouteSource.sharedInstance
        routeSource.fetchBusStops { (busStops) in
            for busStop in busStops! {
                let busStopMarker = GMSMarker()
                busStopMarker.position = busStop.coordinates
                busStopMarker.title = busStop.name
                busStopMarker.snippet = "Routes served: "
                var routesString: String = "Routes served: "
                for service in busStop.routes {
                    routesString.append("\n" + service.routeNumber)
                }
                busStopMarker.snippet = routesString
                busStopMarker.map = mapView
                busStopMarker.icon = #imageLiteral(resourceName: "BusStopMarker.png")
                busStopMarker.userData = (MarkerDataType.busStop, busStop) as (MarkerDataType, Any)
                self.busStopMarkers.append(busStopMarker)
            }
        }
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
    }
    
    func routeUser() {
        let sharedInstance = RouteSource.sharedInstance
        sharedInstance.fetchRoute(currentLocation: locationManager.location!.coordinate, canteen: selectedCanteen!) { (transport, directions) in
            guard transport != nil && directions != nil else {
                print("Error while routing user.")
                return
            }
            
            print(transport!)
            
            self.presentedPolylines = [GMSPolyline]()
            
            for (transportMode, polylineString) in transport! {
                DispatchQueue.main.async {
                    
                    let path = GMSPath(fromEncodedPath: polylineString)
                    let polyline = GMSPolyline(path: path!)
                    switch transportMode {
                        case .riding:
                            polyline.strokeColor = UIColor.orange
                        case .walking:
                            polyline.strokeColor = UIColor.blue
                    }
                    polyline.strokeWidth = 2.0
                
                    polyline.map = self.mapView
                    self.presentedPolylines?.append(polyline)
                }
                
                
                
                let pageViewController = UIPageViewController(transitionStyle: UIPageViewControllerTransitionStyle.scroll, navigationOrientation: UIPageViewControllerNavigationOrientation.horizontal, options: nil)
                
                
            }
            
            self.isPresentingRoute = true
        }
        self.navigationItem.title = "Routing..."
    }

    
    func presentRoute() {
        self.navigationItem.title = selectedCanteen!.name
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePresentingRoute))
        busStopMarkers.forEach { marker in
            marker.map = nil
        }
        canteenMarkers.forEach { marker in
            let content = marker.userData as! (MarkerDataType, Any)
            if (content.1 as! Canteen).id != selectedCanteen!.id {
                marker.map = nil
            }
        }
    }
    
    func donePresentingRoute() {
        selectedCanteen = nil
        self.navigationItem.title = "Pick a Canteen"
        self.navigationItem.rightBarButtonItem = nil
        busStopMarkers.forEach { marker in
            marker.map = self.mapView
        }
        canteenMarkers.forEach { marker in
            marker.map = self.mapView
        }
        presentedPolylines!.forEach({ polyline in
            polyline.map = nil
        })
        presentedPolylines = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController: CLLocationManagerDelegate {
    private func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        // 3
        if status == .authorizedWhenInUse {
            
            // 4
            locationManager.startUpdatingLocation()
            
            //5
            mapView?.isMyLocationEnabled = true
            mapView?.settings.myLocationButton = true
        }
    }
    
    // 6
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            
            // 7
            mapView?.camera = GMSCameraPosition(target: location.coordinate, zoom: 15, bearing: 0, viewingAngle: 0)
            
            // 8
            locationManager.stopUpdatingLocation()
        }
        
    }
}

extension ViewController: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didTapInfoWindowOf marker: GMSMarker) {
        let tupleMarkerUserData = marker.userData as! (MarkerDataType, Any)
        switch tupleMarkerUserData.0 {
        case .canteen:
            let cvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "canteenViewController") as! CanteenViewController
            let nav = UINavigationController(rootViewController: cvc)
            cvc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissPresented))
            cvc.canteen = tupleMarkerUserData.1 as? Canteen
            cvc.hostViewController = self
            self.navigationController!.present(nav, animated: true, completion: nil)
            break
            
        case .busStop:
            break
        }
    }
    
//    func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
//        let tupleMarkerUserData = marker.userData as! (MarkerDataType, Any)
//        let canteen = tupleMarkerUserData.1 as? Canteen
//        let canteenInfoView = Bundle.main.loadNibNamed("CanteenInfoView", owner: self, options: nil)![0] as! CanteenInfoView
//        canteenInfoView.canteenNameLabel.text = canteen?.name
//        return canteenInfoView
//    }
    
    func dismissPresented() {
        self.dismiss(animated: true, completion: nil)
    }
}

