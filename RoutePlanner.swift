import CoreLocation
import MapKit
import Observation

struct ScoredRoute: Identifiable {
  var id = UUID()
  var route: MKRoute
  var label: String
  var safetyScore: Double      // 0–100, higher = safer
  var trafficExposure: Double  // 0–100, higher = more traffic
  var scenicScore: Double      // 0–100, higher = more scenic
  var compositeScore: Double   // weighted blend, higher = better for chosen mode
  var stepInfraTypes: [InfraType]
}

@Observable
class RoutePlanner {
  var destination: MKMapItem?
  var scoredRoutes: [ScoredRoute] = []
  var selectedRouteIndex: Int = 0
  var isCalculating = false
  var errorMessage: String?
  var nearbyBikePaths: [MKMapItem] = []

  var selectedRoute: ScoredRoute? {
    scoredRoutes.indices.contains(selectedRouteIndex) ? scoredRoutes[selectedRouteIndex] : nil
  }

  func calculateRoutes(from coordinate: CLLocationCoordinate2D, preferences: SafetyPreferences) async {
    guard let destination else { return }
    isCalculating = true
    errorMessage = nil
    scoredRoutes = []
    selectedRouteIndex = 0

    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    request.destination = destination
    request.transportType = .walking
    request.requestsAlternateRoutes = true
    request.departureDate = Date()

    do {
      let response = try await MKDirections(request: request).calculate()
      scoredRoutes = buildScoredRoutes(from: Array(response.routes.prefix(3)), preferences: preferences)
    } catch {
      errorMessage = "Could not find a route. Try a different destination."
    }
    isCalculating = false
  }

  private func buildScoredRoutes(from routes: [MKRoute], preferences: SafetyPreferences) -> [ScoredRoute] {
    let labels = ["Route A", "Route B", "Route C"]
    var result = routes.enumerated().map { index, route -> ScoredRoute in
      let (safety, traffic, scenic, types) = InfrastructureClassifier.score(route: route, preferences: preferences)
      let composite = safety   * preferences.routeMode.safetyWeight
                    + (100 - traffic) * preferences.routeMode.speedWeight
                    + scenic   * preferences.routeMode.scenicWeight
                    - (route.expectedTravelTime / 3600) * preferences.routeMode.speedWeight * 5
      return ScoredRoute(
        route: route,
        label: labels[safe: index] ?? "Route",
        safetyScore: safety,
        trafficExposure: traffic,
        scenicScore: scenic,
        compositeScore: composite,
        stepInfraTypes: types
      )
    }
    result.sort { $0.compositeScore > $1.compositeScore }
    return result
  }

  func findBikePaths(near coordinate: CLLocationCoordinate2D) async {
    let queries = [
      "bike path", "bike trail", "bike lane", "cycle track",
      "greenway", "rail trail", "shared use path", "cycling path"
    ]
    var results: [MKMapItem] = []
    var seen = Set<String>()

    await withTaskGroup(of: [MKMapItem].self) { group in
      for query in queries {
        group.addTask {
          let req = MKLocalSearch.Request()
          req.naturalLanguageQuery = query
          req.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 8000, longitudinalMeters: 8000)
          return (try? await MKLocalSearch(request: req).start())?.mapItems ?? []
        }
      }
      for await items in group {
        for item in items {
          let key = "\(item.name ?? "")|\(item.placemark.coordinate.latitude)"
          if seen.insert(key).inserted { results.append(item) }
        }
      }
    }
    nearbyBikePaths = results
  }

  func clearRoute() {
    destination = nil
    scoredRoutes = []
    selectedRouteIndex = 0
    errorMessage = nil
  }
}

extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
