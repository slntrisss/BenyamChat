//
//  LocationViewController.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 20.12.2022.
//

import UIKit
import CoreLocation
import MapKit

class LocationViewController: UIViewController {
    
    public var completion: ((CLLocationCoordinate2D) -> ())?
    private var coordinate: CLLocationCoordinate2D?
    private var isPickable = true
    private let map: MKMapView = {
        let map = MKMapView()
        return map
    }()

    init(coordinate: CLLocationCoordinate2D?){
        if let coordinate = coordinate {
            self.coordinate = coordinate
            isPickable = false
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        if isPickable{
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send",
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(didTapSendButton))
            map.isUserInteractionEnabled = true
            let gesture = UITapGestureRecognizer(target: self,
                                                 action: #selector(didTapMap(_:)))
            
            gesture.numberOfTapsRequired = 1
            gesture.numberOfTouchesRequired = 1
            map.addGestureRecognizer(gesture)
            print("heeey!")
        }
        else{
            guard let coordinate = coordinate else {
                return
            }
            
            let pin = MKPointAnnotation()
            pin.coordinate = coordinate
            map.addAnnotation(pin)
        }
        view.addSubview(map)
    }
    
    @objc func didTapSendButton(){
        guard let coordinate = coordinate else {
            return
        }
        completion?(coordinate)
        navigationController?.popViewController(animated: true)
    }
    
    @objc func didTapMap(_ gesture: UITapGestureRecognizer){
        let locationInView = gesture.location(in: map)
        let coordinate = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinate = coordinate
        
        
        
        for annotation in map.annotations{
            map.removeAnnotation(annotation)
        }
        
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        map.addAnnotation(pin)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }

}
