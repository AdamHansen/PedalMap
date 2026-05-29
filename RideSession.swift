import CoreLocation
import Foundation

struct RideSession: Identifiable, Codable {
  var id: UUID = UUID()
  var startDate: Date
  var endDate: Date
  var distanceMeters: Double
  var durationSeconds: Double
  var coordinates: [SerializableCoordinate]

  var distanceKilometers: Double { distanceMeters / 1000 }
  var distanceMiles: Double { distanceMeters / 1609.34 }
  var averageSpeedKph: Double {
    guard durationSeconds > 0 else { return 0 }
    return (distanceKilometers / durationSeconds) * 3600
  }
  var averageSpeedMph: Double { averageSpeedKph * 0.621371 }

  var formattedDuration: String {
    let h = Int(durationSeconds) / 3600
    let m = (Int(durationSeconds) % 3600) / 60
    let s = Int(durationSeconds) % 60
    if h > 0 {
      return String(format: "%d:%02d:%02d", h, m, s)
    } else {
      return String(format: "%d:%02d", m, s)
    }
  }

  var clLocations: [CLLocationCoordinate2D] {
    coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
  }
}

struct SerializableCoordinate: Codable {
  var latitude: Double
  var longitude: Double

  init(_ coordinate: CLLocationCoordinate2D) {
    latitude = coordinate.latitude
    longitude = coordinate.longitude
  }
}

@Observable
class RideStore {
  var sessions: [RideSession] = []

  private let saveKey = "savedRideSessions"

  init() {
    load()
  }

  func save(session: RideSession) {
    sessions.insert(session, at: 0)
    persist()
  }

  func delete(at offsets: IndexSet) {
    sessions.remove(atOffsets: offsets)
    persist()
  }

  private func persist() {
    if let data = try? JSONEncoder().encode(sessions) {
      UserDefaults.standard.set(data, forKey: saveKey)
    }
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: saveKey),
          let decoded = try? JSONDecoder().decode([RideSession].self, from: data)
    else { return }
    sessions = decoded
  }
}
