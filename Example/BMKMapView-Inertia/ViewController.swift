//
//  ViewController.swift
//  BMKMapView-Inertia
//
//  Created by yinpan on 02/13/2019.
//  Copyright (c) 2019 yinpan. All rights reserved.
//

import UIKit
import BaiduMapAPI_Map
import BMKMapView_Inertia

class ViewController: UIViewController {
    
    var mapView: BMKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView = BMKMapView(frame: view.bounds)
        view.addSubview(mapView)
        // 设置惯性
        mapView.isInertiaScalable = true
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

