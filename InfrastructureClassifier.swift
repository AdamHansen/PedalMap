import MapKit
import SwiftUI

enum InfraType: Equatable {
  case bikeDedicated, sharedPath, quietRoad, busyRoad, highway

  var color: Color {
    switch self {
    case .bikeDedicated: return .green
    case .sharedPath:    return Color(red: 0.45, green: 0.78, blue: 0.18)
    case .quietRoad:     return .yellow
    case .busyRoad:      return .orange
    case .highway:       return .red
    }
  }

  var label: String {
    switch self {
    case .bikeDedicated: return "Bike Infrastructure"
    case .sharedPath:    return "Shared Path"
    case .quietRoad:     return "Quiet Road"
    case .busyRoad:      return "Busy Road"
    case .highway:       return "Highway"
    }
  }

  var isHazard: Bool { self == .busyRoad || self == .highway }

  // Higher = safer (0-100)
  var baseSafetyScore: Double {
    switch self {
    case .bikeDedicated: return 95
    case .sharedPath:    return 80
    case .quietRoad:     return 62
    case .busyRoad:      return 28
    case .highway:       return 5
    }
  }

  // Higher = more traffic exposure (0-100)
  var trafficScore: Double {
    switch self {
    case .bikeDedicated: return 8
    case .sharedPath:    return 18
    case .quietRoad:     return 38
    case .busyRoad:      return 76
    case .highway:       return 96
    }
  }

  // Higher = more scenic (0-100)
  var scenicBase: Double {
    switch self {
    case .bikeDedicated: return 55
    case .sharedPath:    return 70
    case .quietRoad:     return 35
    case .busyRoad:      return 15
    case .highway:       return 5
    }
  }
}

enum InfrastructureClassifier {
  private static let bikeTerms: [String] = [
    "bike lane", "bike path", "cycle track", "cycleway",
    "bike trail", "greenway", "rail trail", "multi-use path",
    "protected lane", "shared use path", "cycling path"
  ]
  private static let sharedTerms:  [String] = ["path", "trail", "pedestrian", "shared", "park way", "parkway"]
  private static let scenicTerms:  [String] = ["park", "river", "lake", "creek", "trail", "greenway", "nature", "preserve"]
  private static let busyTerms:    [String] = ["boulevard", "avenue", "ave ", "main st", "broadway", "state route", "sr-", "us-", "county road", "arterial"]
  private static let highwayTerms: [String] = ["highway", "freeway", "expressway", "motorway", "interstate", " i-", "hwy", "fwy"]

  static func classify(_ step: MKRoute.Step) -> InfraType {
    let t = step.instructions.lowercased()
    if bikeTerms.contains(where: { t.contains($0) })   { return .bikeDedicated }
    if highwayTerms.contains(where: { t.contains($0) }) { return .highway }
    if busyTerms.contains(where: { t.contains($0) })    { return .busyRoad }
    if sharedTerms.contains(where: { t.contains($0) })  { return .sharedPath }
    return .quietRoad
  }

  static func score(
    route: MKRoute,
    preferences: SafetyPreferences
  ) -> (safety: Double, traffic: Double, scenic: Double, types: [InfraType]) {
    let steps = route.steps.filter { !$0.instructions.isEmpty }
    guard !steps.isEmpty else { return (50, 50, 50, []) }

    let total = max(route.distance, 1)
    var safetyAcc = 0.0
    var trafficAcc = 0.0
    var scenicAcc = 0.0
    var types: [InfraType] = []

    for step in steps {
      let infra = classify(step)
      types.append(infra)
      let w = step.distance / total

      var s = infra.baseSafetyScore
      if preferences.preferBikeLanes  && infra == .bikeDedicated { s += 8 }
      if preferences.preferSharedPaths && infra == .sharedPath    { s += 5 }
      if preferences.preferTrails     && infra == .sharedPath    { s += 3 }
      if preferences.avoidHighways    && infra == .highway        { s -= 25 }
      if preferences.avoidBusyStreets && infra == .busyRoad       { s -= 15 }
      // Traffic tolerance penalty: if route has more hazardous steps than the tolerance, penalize
      if infra.isHazard {
        let penalty = (1.0 - preferences.trafficTolerance.toleranceFraction) * 20
        s -= penalty
      }

      let scenicBoost = scenicTerms.contains(where: { step.instructions.lowercased().contains($0) }) ? 30.0 : 0
      safetyAcc  += min(max(s, 0), 100) * w
      trafficAcc += infra.trafficScore * w
      scenicAcc  += (infra.scenicBase + scenicBoost) * w
    }

    // Normalize infra types to match step count (include all steps)
    let allTypes = route.steps.map { classify($0) }
    return (safetyAcc, trafficAcc, min(scenicAcc, 100), allTypes)
  }
}

extension MKPolyline {
  var coordinates: [CLLocationCoordinate2D] {
    var coords = Array(repeating: CLLocationCoordinate2D(), count: pointCount)
    getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
    return coords
  }
}
