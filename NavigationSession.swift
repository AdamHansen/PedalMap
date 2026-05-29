import CoreLocation
import MapKit
import Observation

@Observable
class NavigationSession {
  var isActive = false
  var route: MKRoute?
  var stepInfraTypes: [InfraType] = []
  var currentStepIndex = 0
  var distanceToNextTurn: Double = 0
  var showHazardBanner = false
  var hazardDescription = ""

  // Ride recording
  var elapsedSeconds: Double = 0
  var distanceCovered: Double = 0
  var currentSpeedKph: Double = 0
  private var lastLocation: CLLocation?

  var currentStep: MKRoute.Step? {
    guard let route, route.steps.indices.contains(currentStepIndex) else { return nil }
    return route.steps[currentStepIndex]
  }

  var remainingDistance: Double {
    guard let route else { return 0 }
    let stepsLeft = route.steps[currentStepIndex...]
    let total = stepsLeft.reduce(0) { $0 + $1.distance }
    return max(total - (currentStep.map { $0.distance - distanceToNextTurn } ?? 0), 0)
  }

  var isArriving: Bool {
    guard let route else { return false }
    return currentStepIndex >= route.steps.count - 1
  }

  func start(route: MKRoute, infraTypes: [InfraType]) {
    self.route = route
    self.stepInfraTypes = infraTypes
    currentStepIndex = 0
    elapsedSeconds = 0
    distanceCovered = 0
    currentSpeedKph = 0
    showHazardBanner = false
    lastLocation = nil
    distanceToNextTurn = route.steps.first?.distance ?? 0
    isActive = true
  }

  func stop() {
    isActive = false
  }

  func tick() {
    guard isActive else { return }
    elapsedSeconds += 1
  }

  func update(with location: CLLocation) {
    guard isActive, let route else { return }

    currentSpeedKph = max(location.speed, 0) * 3.6
    if let last = lastLocation { distanceCovered += location.distance(from: last) }
    lastLocation = location

    advanceStepIfNeeded(location: location, route: route)
    updateHazardBanner(location: location, route: route)
  }

  private func advanceStepIfNeeded(location: CLLocation, route: MKRoute) {
    let steps = route.steps
    guard currentStepIndex < steps.count else { return }
    let step = steps[currentStepIndex]
    let endCoords = step.polyline.coordinates
    guard let endCoord = endCoords.last else { return }

    let stepEnd = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
    let dist = location.distance(from: stepEnd)
    distanceToNextTurn = dist

    if dist < 20, currentStepIndex < steps.count - 1 {
      currentStepIndex += 1
      distanceToNextTurn = steps[currentStepIndex].distance
    }
  }

  private func updateHazardBanner(location: CLLocation, route: MKRoute) {
    // Look 1-2 steps ahead for hazard steps
    let lookAhead = min(currentStepIndex + 2, route.steps.count - 1)
    var foundHazard = false

    for i in (currentStepIndex + 1)...max(currentStepIndex + 1, lookAhead) {
      guard route.steps.indices.contains(i) else { break }
      let stepType = stepInfraTypes.indices.contains(i) ? stepInfraTypes[i] : .quietRoad
      if stepType.isHazard {
        // Show banner when within 300m of the hazard step's start
        let coords = route.steps[i].polyline.coordinates
        guard let first = coords.first else { continue }
        let hazardStart = CLLocation(latitude: first.latitude, longitude: first.longitude)
        if location.distance(from: hazardStart) < 300 {
          hazardDescription = route.steps[i].instructions
          foundHazard = true
          break
        }
      }
    }
    showHazardBanner = foundHazard
  }

  func directionIcon(for instruction: String) -> String {
    let t = instruction.lowercased()
    if t.contains("arrive") || t.contains("destination") { return "flag.checkered.fill" }
    if t.contains("u-turn") || t.contains("uturn")        { return "arrow.uturn.left" }
    if t.contains("roundabout") || t.contains("rotary")   { return "arrow.clockwise" }
    if t.contains("slight left") || t.contains("bear left")  { return "arrow.up.left" }
    if t.contains("slight right") || t.contains("bear right") { return "arrow.up.right" }
    if t.contains("turn left") || t.contains("left")      { return "arrow.turn.up.left" }
    if t.contains("turn right") || t.contains("right")    { return "arrow.turn.up.right" }
    return "arrow.up"
  }
}
