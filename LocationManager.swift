import CoreLocation
import Observation

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
  var currentLocation: CLLocation?
  var authorizationStatus: CLAuthorizationStatus = .notDetermined
  var isTracking = false
  var trackedLocations: [CLLocation] = []
  var currentSpeed: Double = 0
  var totalDistance: Double = 0

  private let manager = CLLocationManager()

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 5
    authorizationStatus = manager.authorizationStatus
    manager.requestWhenInUseAuthorization()
    manager.startUpdatingLocation()
  }

  func startTracking() {
    trackedLocations = []
    totalDistance = 0
    isTracking = true
  }

  func stopTracking() {
    isTracking = false
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus
    if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
      manager.startUpdatingLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    currentLocation = location
    currentSpeed = max(location.speed, 0)

    if isTracking {
      if let last = trackedLocations.last {
        totalDistance += location.distance(from: last)
      }
      trackedLocations.append(location)
    }
  }
}
