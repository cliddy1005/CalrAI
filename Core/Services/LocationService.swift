import Foundation
import CoreLocation

protocol LocationProvider: AnyObject {
    var authorization: CLAuthorizationStatus { get }
    var location: CLLocation? { get }
    func requestWhenInUse()
}

final class CoreLocationProvider: NSObject, LocationProvider, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    private(set) var _authorization: CLAuthorizationStatus = .notDetermined
    private(set) var _location: CLLocation?

    override init() {
        super.init()
        mgr.delegate = self
    }
    var authorization: CLAuthorizationStatus { _authorization }
    var location: CLLocation? { _location }

    func requestWhenInUse() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        mgr.requestWhenInUseAuthorization()
        mgr.startUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        _authorization = status
        if status == .authorizedWhenInUse || status == .authorizedAlways { manager.startUpdatingLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        _location = locations.last
    }
}
