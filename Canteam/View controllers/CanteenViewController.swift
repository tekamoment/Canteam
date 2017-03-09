//
//  CanteenViewController.swift
//  Canteam
//
//  Created by Carlos Arcenas on 9/10/16.
//  Copyright © 2016 Carlos Arcenas. All rights reserved.
//

import UIKit

class CanteenViewController: UIViewController {

    @IBOutlet weak var canteenNameLabel: UILabel!
    @IBOutlet weak var canteenCapacityLabel: UILabel!
    @IBOutlet weak var canteenCurrentlyLabel: UILabel!
    @IBOutlet weak var canteenVisitingLabel: UILabel!
    
    
    weak var hostViewController: UIViewController?
    var canteen: Canteen?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        canteenNameLabel.text = canteen!.name
        canteenCapacityLabel.text = "\(canteen!.capacity) people"
        canteenCurrentlyLabel.text = "\(canteen!.crowd ?? 0) people are here right now."
        canteenVisitingLabel.text = "\(canteen!.visitors) people are thinking of visiting right now."
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func routeHerePressed(_ sender: AnyObject) {
        guard hostViewController != nil, canteen != nil else {
            return
        }
        
        (hostViewController as! ViewController).selectedCanteen = canteen!
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
