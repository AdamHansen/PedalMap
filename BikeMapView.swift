import MapKit
import SwiftUI

struct BikeMapView: View {
  @Bindable var locationManager: LocationManager
  var rideStore: RideStore

  @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
  @State private var elapsedSeconds: Double = 0
  @State private var timer: Timer?
  @State private var showSaveConfirmation = false
  @State private var useMiles = false

  var body: some View {
    ZStack(alignment: .bottom) {
      Map(position: $position) {
        UserAnnotation()
        if locationManager.isTracking && locationManager.trackedLocations.count > 1 {
          MapPolyline(coordinates: locationManager.trackedLocations.map(\.coordinate))
            .stroke(.green, lineWidth: 4)
        }
      }
      .mapStyle(.standard(elevation: .realistic))
      .mapControls {
        MapUserLocationButton()
        MapCompass()
      }
      .ignoresSafeArea()

      VStack(spacing: 0) {
        if locationManager.isTracking {
          rideStatsPanel
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        controlBar
      }
    }
    .alert("Save Ride?", isPresented: $showSaveConfirmation) {
      Button("Save") { saveRide() }
      Button("Discard", role: .destructive) { discardRide() }
      Button("Continue", role: .cancel) {
        locationManager.isTracking = true
        timer = makeTimer()
      }
    } message: {
      Text("Do you want to save this ride?")
    }
    .animation(.smooth, value: locationManager.isTracking)
  }

  private var rideStatsPanel: some View {
    HStack(spacing: 0) {
      statCell(
        value: useMiles
          ? String(format: "%.2f", locationManager.totalDistance / 1609.34)
          : String(format: "%.2f", locationManager.totalDistance / 1000),
        label: useMiles ? "mi" : "km"
      )
      Divider().frame(height: 40)
      statCell(value: formatDuration(elapsedSeconds), label: "time")
      Divider().frame(height: 40)
      statCell(
        value: speedString,
        label: useMiles ? "mph" : "km/h"
      )
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(.ultraThinMaterial)
  }

  private var speedString: String {
    let speedMs = locationManager.currentSpeed
    if useMiles {
      return String(format: "%.1f", speedMs * 2.23694)
    } else {
      return String(format: "%.1f", speedMs * 3.6)
    }
  }

  private var controlBar: some View {
    HStack(spacing: 16) {
      if locationManager.isTracking {
        Button {
          stopRide()
        } label: {
          Label("Stop", systemImage: "stop.fill")
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.red)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
      } else {
        Button {
          startRide()
        } label: {
          Label("Start Ride", systemImage: "play.fill")
            .font(.headline)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(.green)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
      }

      Button {
        useMiles.toggle()
      } label: {
        Text(useMiles ? "mi" : "km")
          .font(.subheadline.bold())
          .frame(width: 44, height: 44)
          .background(.ultraThinMaterial)
          .clipShape(Circle())
      }
      .foregroundStyle(.primary)
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .background(.ultraThinMaterial)
  }

  private func statCell(value: String, label: String) -> some View {
    VStack(spacing: 2) {
      Text(value)
        .font(.title2.monospacedDigit().bold())
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private func startRide() {
    locationManager.startTracking()
    elapsedSeconds = 0
    timer = makeTimer()
    withAnimation { position = .userLocation(fallback: .automatic) }
  }

  private func stopRide() {
    timer?.invalidate()
    timer = nil
    locationManager.isTracking = false
    showSaveConfirmation = true
  }

  private func saveRide() {
    let coords = locationManager.trackedLocations.map { SerializableCoordinate($0.coordinate) }
    let session = RideSession(
      startDate: Date().addingTimeInterval(-elapsedSeconds),
      endDate: Date(),
      distanceMeters: locationManager.totalDistance,
      durationSeconds: elapsedSeconds,
      coordinates: coords
    )
    rideStore.save(session: session)
    locationManager.trackedLocations = []
    locationManager.totalDistance = 0
    elapsedSeconds = 0
  }

  private func discardRide() {
    locationManager.trackedLocations = []
    locationManager.totalDistance = 0
    elapsedSeconds = 0
  }

  private func makeTimer() -> Timer {
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      elapsedSeconds += 1
    }
  }

  private func formatDuration(_ seconds: Double) -> String {
    let h = Int(seconds) / 3600
    let m = (Int(seconds) % 3600) / 60
    let s = Int(seconds) % 60
    if h > 0 {
      return String(format: "%d:%02d:%02d", h, m, s)
    } else {
      return String(format: "%d:%02d", m, s)
    }
  }
}
