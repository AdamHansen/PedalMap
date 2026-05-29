import MapKit
import SwiftUI

struct ActiveRideView: View {
  var locationManager: LocationManager
  @Bindable var navigationSession: NavigationSession
  var rideStore: RideStore
  var preferences: SafetyPreferences
  var onEnd: () -> Void

  @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
  @State private var showSavePrompt = false
  @State private var timer: Timer?
  @State private var isUserPanning = false

  private var step: MKRoute.Step? { navigationSession.currentStep }

  var body: some View {
    ZStack(alignment: .top) {
      navigationMap

      VStack(spacing: 0) {
        turnCard
        if navigationSession.showHazardBanner {
          hazardBanner
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        Spacer()
        statsBar
      }
    }
    .animation(.snappy, value: navigationSession.showHazardBanner)
    .animation(.snappy, value: navigationSession.currentStepIndex)
    .onAppear { startTimer() }
    .onDisappear { stopTimer() }
    .onChange(of: locationManager.currentLocation) { _, loc in
      guard let loc else { return }
      navigationSession.update(with: loc)
      if !isUserPanning {
        withAnimation(.easeInOut(duration: 0.5)) {
          position = .userLocation(fallback: .automatic)
        }
      }
    }
    .alert("Save this ride?", isPresented: $showSavePrompt) {
      Button("Save") { saveAndEnd() }
      Button("Discard", role: .destructive) { discardAndEnd() }
    } message: {
      let km = String(format: "%.2f km", navigationSession.distanceCovered / 1000)
      Text("You rode \(km) in \(formatTime(navigationSession.elapsedSeconds)).")
    }
  }

  // MARK: - Map

  private var navigationMap: some View {
    Map(position: $position) {
      UserAnnotation()

      if let route = navigationSession.route {
        // Completed portion — gray
        let completedSteps = Array(route.steps.prefix(navigationSession.currentStepIndex))
        ForEach(Array(completedSteps.enumerated()), id: \.offset) { i, step in
          let coords = step.polyline.coordinates
          if coords.count >= 2 {
            MapPolyline(coordinates: coords)
              .stroke(.gray.opacity(0.4), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
          }
        }

        // Remaining portion — colored by infra type
        let remainingSteps = Array(route.steps.dropFirst(navigationSession.currentStepIndex))
        ForEach(Array(remainingSteps.enumerated()), id: \.offset) { i, step in
          let globalIndex = navigationSession.currentStepIndex + i
          let infra = navigationSession.stepInfraTypes[safe: globalIndex] ?? .quietRoad
          let coords = step.polyline.coordinates
          if coords.count >= 2 {
            MapPolyline(coordinates: coords)
              .stroke(infra.color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
          }
        }

        // Destination
        if let lastStep = route.steps.last,
           let lastCoord = lastStep.polyline.coordinates.last {
          Annotation("Destination", coordinate: lastCoord) {
            Image(systemName: "flag.checkered.fill")
              .font(.title3).foregroundStyle(.red).shadow(radius: 2)
          }
        }
      }
    }
    .mapStyle(.standard(elevation: .realistic, showsTraffic: true))
    .mapControls { MapCompass() }
    .ignoresSafeArea()
    .onMapCameraChange { _ in isUserPanning = true }
    .overlay(alignment: .bottomTrailing) {
      if isUserPanning {
        Button {
          isUserPanning = false
          withAnimation { position = .userLocation(fallback: .automatic) }
        } label: {
          Image(systemName: "location.fill")
            .padding(12)
            .background(.regularMaterial)
            .clipShape(Circle())
        }
        .padding(.trailing, 16)
        .padding(.bottom, 100)
      }
    }
  }

  // MARK: - Turn Card

  private var turnCard: some View {
    HStack(spacing: 14) {
      Image(systemName: navigationSession.directionIcon(for: step?.instructions ?? ""))
        .font(.system(size: 32, weight: .semibold))
        .foregroundStyle(.green)
        .frame(width: 48)

      VStack(alignment: .leading, spacing: 3) {
        Text(step?.instructions.isEmpty == false ? step!.instructions : (navigationSession.isArriving ? "Arriving at destination" : "Follow the route"))
          .font(.headline)
          .lineLimit(2)
        if let infra = navigationSession.stepInfraTypes[safe: navigationSession.currentStepIndex] {
          HStack(spacing: 5) {
            Circle().fill(infra.color).frame(width: 7, height: 7)
            Text(infra.label).font(.caption).foregroundStyle(.secondary)
          }
        }
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(formatDist(navigationSession.distanceToNextTurn))
          .font(.title3.monospacedDigit().bold())
          .foregroundStyle(.primary)
        Text("to turn").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(.regularMaterial)
    .overlay(alignment: .topTrailing) {
      Button {
        stopTimer()
        navigationSession.stop()
        showSavePrompt = true
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.title3)
          .foregroundStyle(.secondary)
          .padding(8)
      }
    }
  }

  // MARK: - Hazard Banner

  private var hazardBanner: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.white)
        .font(.headline)
      VStack(alignment: .leading, spacing: 1) {
        Text("Hazard ahead — prepare to merge")
          .font(.subheadline.bold())
          .foregroundStyle(.white)
        Text(navigationSession.hazardDescription)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.85))
          .lineLimit(1)
      }
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(.red)
  }

  // MARK: - Stats Bar

  private var statsBar: some View {
    HStack(spacing: 0) {
      statCell(
        value: preferences.formatSpeed(navigationSession.currentSpeedKph),
        label: preferences.speedUnitLabel
      )
      Divider().frame(height: 36)
      statCell(
        value: preferences.formatDistance(navigationSession.distanceCovered),
        label: "done"
      )
      Divider().frame(height: 36)
      statCell(
        value: preferences.formatDistance(navigationSession.remainingDistance),
        label: "remaining"
      )
      Divider().frame(height: 36)
      statCell(
        value: formatTime(navigationSession.elapsedSeconds),
        label: "time"
      )
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(.regularMaterial)
  }

  private func statCell(value: String, label: String) -> some View {
    VStack(spacing: 2) {
      Text(value).font(.subheadline.monospacedDigit().bold())
      Text(label).font(.caption2).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Helpers

  private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      navigationSession.tick()
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  private func saveAndEnd() {
    guard let route = navigationSession.route else { onEnd(); return }
    let coords = locationManager.trackedLocations.map { SerializableCoordinate($0.coordinate) }
    let session = RideSession(
      startDate: Date().addingTimeInterval(-navigationSession.elapsedSeconds),
      endDate: Date(),
      distanceMeters: navigationSession.distanceCovered,
      durationSeconds: navigationSession.elapsedSeconds,
      coordinates: coords.isEmpty
        ? route.polyline.coordinates.map { SerializableCoordinate($0) }
        : coords
    )
    rideStore.save(session: session)
    onEnd()
  }

  private func discardAndEnd() { onEnd() }

  // Kept for the distance-to-turn display in the turn card (always uses preferences)
  private func formatDist(_ m: Double) -> String { preferences.formatDistance(m) }

  private func formatTime(_ s: Double) -> String {
    let h = Int(s)/3600, m = (Int(s)%3600)/60, sec = Int(s)%60
    return h > 0
      ? String(format: "%d:%02d:%02d", h, m, sec)
      : String(format: "%d:%02d", m, sec)
  }
}
