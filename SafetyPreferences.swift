import Foundation
import Observation

enum RouteMode: String, CaseIterable, Identifiable {
  case safest = "Safest"
  case fastest = "Fastest"
  case scenic = "Scenic"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .safest:  return "checkmark.shield.fill"
    case .fastest: return "bolt.fill"
    case .scenic:  return "tree.fill"
    }
  }

  var description: String {
    switch self {
    case .safest:  return "Minimizes traffic exposure"
    case .fastest: return "Shortest travel time"
    case .scenic:  return "Parks, trails & greenways"
    }
  }

  // Weights used in composite score calculation
  var safetyWeight: Double {
    switch self { case .safest: 0.70; case .fastest: 0.20; case .scenic: 0.35 }
  }
  var speedWeight: Double {
    switch self { case .safest: 0.10; case .fastest: 0.70; case .scenic: 0.15 }
  }
  var scenicWeight: Double {
    switch self { case .safest: 0.20; case .fastest: 0.10; case .scenic: 0.50 }
  }
}

enum TrafficTolerance: Int, CaseIterable, Identifiable {
  case low = 0, moderate = 1, high = 2

  var id: Int { rawValue }

  var label: String {
    switch self {
    case .low:      return "Low — avoid busy roads"
    case .moderate: return "Moderate — some main roads OK"
    case .high:     return "High — traffic is acceptable"
    }
  }

  // Fraction of busy/highway steps tolerated before penalizing
  var toleranceFraction: Double {
    switch self { case .low: 0.05; case .moderate: 0.25; case .high: 1.0 }
  }
}

@Observable
class SafetyPreferences {
  var routeMode: RouteMode = .safest
  var preferBikeLanes: Bool = true
  var preferSharedPaths: Bool = true
  var preferTrails: Bool = true
  var avoidHighways: Bool = true
  var avoidBusyStreets: Bool = false
  var trafficTolerance: TrafficTolerance = .moderate
  var useMetric: Bool = true

  var speedUnitLabel: String { useMetric ? "km/h" : "mph" }

  func formatDistance(_ meters: Double) -> String {
    if useMetric {
      return meters >= 1000
        ? String(format: "%.1f km", meters / 1000)
        : String(format: "%.0f m", meters)
    } else {
      let miles = meters / 1609.34
      return miles >= 0.1
        ? String(format: "%.1f mi", miles)
        : String(format: "%.0f ft", meters * 3.28084)
    }
  }

  func formatSpeed(_ kph: Double) -> String {
    useMetric
      ? String(format: "%.1f", kph)
      : String(format: "%.1f", kph * 0.621371)
  }

  init() { load() }

  func save() {
    let d = UserDefaults.standard
    d.set(routeMode.rawValue,         forKey: "pref.routeMode")
    d.set(preferBikeLanes,            forKey: "pref.bikeLanes")
    d.set(preferSharedPaths,          forKey: "pref.sharedPaths")
    d.set(preferTrails,               forKey: "pref.trails")
    d.set(avoidHighways,              forKey: "pref.noHighways")
    d.set(avoidBusyStreets,           forKey: "pref.noBusy")
    d.set(trafficTolerance.rawValue,  forKey: "pref.trafficTol")
    d.set(useMetric,                  forKey: "pref.useMetric")
  }

  private func load() {
    let d = UserDefaults.standard
    if let raw = d.string(forKey: "pref.routeMode"),
       let m = RouteMode(rawValue: raw) { routeMode = m }
    if d.object(forKey: "pref.bikeLanes") != nil {
      preferBikeLanes   = d.bool(forKey: "pref.bikeLanes")
      preferSharedPaths = d.bool(forKey: "pref.sharedPaths")
      preferTrails      = d.bool(forKey: "pref.trails")
      avoidHighways     = d.bool(forKey: "pref.noHighways")
      avoidBusyStreets  = d.bool(forKey: "pref.noBusy")
    }
    trafficTolerance = TrafficTolerance(rawValue: d.integer(forKey: "pref.trafficTol")) ?? .moderate
    if d.object(forKey: "pref.useMetric") != nil {
      useMetric = d.bool(forKey: "pref.useMetric")
    }
  }
}
