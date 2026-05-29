import MapKit
import SwiftUI

struct RideHistoryView: View {
  @Bindable var rideStore: RideStore
  var preferences: SafetyPreferences

  var body: some View {
    NavigationStack {
      ScrollView {
        if rideStore.sessions.isEmpty {
          emptyState
        } else {
          LazyVStack(spacing: 12) {
            ForEach(rideStore.sessions) { session in
              NavigationLink {
                RideDetailView(session: session, preferences: preferences)
              } label: {
                RideRowView(session: session, preferences: preferences)
              }
              .buttonStyle(.plain)
            }
          }
          .padding()
        }
      }
      .navigationTitle("Ride History")
      .toolbar {
        if !rideStore.sessions.isEmpty {
          EditButton()
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "figure.outdoor.cycle")
        .font(.system(size: 60))
        .foregroundStyle(.secondary)
      Text("No rides yet")
        .font(.title3.bold())
      Text("Start a ride on the Map tab to record your first adventure.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .padding(.top, 80)
  }
}

struct RideRowView: View {
  var session: RideSession
  var preferences: SafetyPreferences

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "figure.outdoor.cycle")
        .font(.title2)
        .foregroundStyle(.green)
        .frame(width: 44, height: 44)
        .background(Color.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 4) {
        Text(session.startDate, style: .date)
          .font(.headline)
        Text(session.startDate, style: .time)
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack(spacing: 16) {
          Label(preferences.formatDistance(session.distanceMeters), systemImage: "arrow.triangle.swap")
          Label(session.formattedDuration, systemImage: "clock")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 2)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(preferences.formatSpeed(session.averageSpeedKph))
          .font(.title3.bold())
        Text("\(preferences.speedUnitLabel) avg")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .background(.quaternary.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

struct RideDetailView: View {
  var session: RideSession
  var preferences: SafetyPreferences
  @State private var position: MapCameraPosition = .automatic

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        Map(position: $position) {
          if session.clLocations.count > 1 {
            MapPolyline(coordinates: session.clLocations)
              .stroke(.green, lineWidth: 4)
          }
          if let first = session.clLocations.first {
            Annotation("Start", coordinate: first) {
              Circle()
                .fill(.green)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white, lineWidth: 2))
            }
          }
          if let last = session.clLocations.last {
            Annotation("End", coordinate: last) {
              Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white, lineWidth: 2))
            }
          }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)

        statsGrid
          .padding(.horizontal)
      }
      .padding(.vertical)
    }
    .navigationTitle(session.startDate.formatted(date: .abbreviated, time: .omitted))
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      if let coords = session.clLocations.first {
        let region = MKCoordinateRegion(
          center: coords,
          span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        position = .region(region)
      }
    }
  }

  private var statsGrid: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      StatCard(title: "Distance", value: preferences.formatDistance(session.distanceMeters), icon: "arrow.triangle.swap")
      StatCard(title: "Duration", value: session.formattedDuration, icon: "clock")
      StatCard(title: "Avg Speed", value: "\(preferences.formatSpeed(session.averageSpeedKph)) \(preferences.speedUnitLabel)", icon: "speedometer")
      StatCard(title: "Date", value: session.startDate.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
    }
  }
}

struct StatCard: View {
  var title: String
  var value: String
  var icon: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: icon)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.headline)
        .foregroundStyle(.primary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}
