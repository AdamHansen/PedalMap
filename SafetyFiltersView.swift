import SwiftUI

struct SafetyFiltersView: View {
  @Bindable var preferences: SafetyPreferences

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          routeModeSection
          infrastructureSection
          trafficSection
          scoringExplainerSection
        }
        .padding()
      }
      .navigationTitle("Safety Filters")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Picker("Units", selection: $preferences.useMetric) {
            Text("km").tag(true)
            Text("mi").tag(false)
          }
          .pickerStyle(.segmented)
          .frame(width: 90)
          .onChange(of: preferences.useMetric) { _, _ in preferences.save() }
        }
      }
    }
    .onDisappear { preferences.save() }
  }

  // MARK: - Route Mode

  private var routeModeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("Route Priority", icon: "slider.horizontal.3")

      VStack(spacing: 8) {
        ForEach(RouteMode.allCases) { mode in
          Button {
            preferences.routeMode = mode
          } label: {
            HStack(spacing: 14) {
              Image(systemName: mode.icon)
                .font(.title3)
                .foregroundStyle(preferences.routeMode == mode ? .white : .green)
                .frame(width: 36)

              VStack(alignment: .leading, spacing: 2) {
                Text(mode.rawValue).font(.subheadline.bold())
                Text(mode.description).font(.caption).opacity(0.8)
              }

              Spacer()

              if preferences.routeMode == mode {
                Image(systemName: "checkmark").font(.caption.bold())
              }
            }
            .padding(14)
            .background(preferences.routeMode == mode ? Color.green : Color(.systemGray6))
            .foregroundStyle(preferences.routeMode == mode ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          .buttonStyle(.plain)
        }
      }

      weightDisplay
    }
    .cardStyle()
  }

  private var weightDisplay: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Scoring Weights for \(preferences.routeMode.rawValue)")
        .font(.caption).foregroundStyle(.secondary)
      HStack(spacing: 8) {
        weightPill("Safety", value: preferences.routeMode.safetyWeight, color: .green)
        weightPill("Speed", value: preferences.routeMode.speedWeight, color: .blue)
        weightPill("Scenic", value: preferences.routeMode.scenicWeight, color: .teal)
      }
    }
    .padding(.top, 4)
  }

  private func weightPill(_ label: String, value: Double, color: Color) -> some View {
    VStack(spacing: 2) {
      Text("\(Int(value * 100))%").font(.caption.bold()).foregroundStyle(color)
      Text(label).font(.caption2).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 6)
    .background(color.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  // MARK: - Infrastructure

  private var infrastructureSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("Prefer Infrastructure", icon: "checkmark.shield")

      VStack(spacing: 0) {
        filterToggle("Bike Lanes & Cycle Tracks", icon: "figure.outdoor.cycle", color: .green, value: $preferences.preferBikeLanes)
        Divider().padding(.leading, 46)
        filterToggle("Shared Paths & Greenways", icon: "tree.fill", color: Color(red: 0.3, green: 0.6, blue: 0.1), value: $preferences.preferSharedPaths)
        Divider().padding(.leading, 46)
        filterToggle("Trails & Rail Trails", icon: "leaf.fill", color: .teal, value: $preferences.preferTrails)
      }
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 12))

      sectionHeader("Avoid", icon: "xmark.shield")

      VStack(spacing: 0) {
        filterToggle("Highways & Freeways", icon: "road.lanes", color: .red, value: $preferences.avoidHighways)
        Divider().padding(.leading, 46)
        filterToggle("Busy / High-Volume Streets", icon: "car.fill", color: .orange, value: $preferences.avoidBusyStreets)
      }
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .cardStyle()
  }

  private func filterToggle(_ label: String, icon: String, color: Color, value: Binding<Bool>) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 22)
      Text(label).font(.subheadline)
      Spacer()
      Toggle("", isOn: value).tint(.green).labelsHidden()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
  }

  // MARK: - Traffic Tolerance

  private var trafficSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("Max Traffic Tolerance", icon: "car.fill")

      VStack(spacing: 8) {
        ForEach(TrafficTolerance.allCases) { level in
          Button {
            preferences.trafficTolerance = level
          } label: {
            HStack {
              Circle()
                .fill(toleranceColor(level))
                .frame(width: 10, height: 10)
              Text(level.label).font(.subheadline)
              Spacer()
              if preferences.trafficTolerance == level {
                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.green)
              }
            }
            .padding(12)
            .background(preferences.trafficTolerance == level ? Color.green.opacity(0.08) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(preferences.trafficTolerance == level ? Color.green : Color.clear, lineWidth: 1.5))
          }
          .buttonStyle(.plain)
          .foregroundStyle(.primary)
        }
      }
    }
    .cardStyle()
  }

  private func toleranceColor(_ t: TrafficTolerance) -> Color {
    switch t { case .low: return .green; case .moderate: return .orange; case .high: return .red }
  }

  // MARK: - Scoring Explainer

  private var scoringExplainerSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader("How Routes Are Scored", icon: "info.circle")

      VStack(alignment: .leading, spacing: 8) {
        explainerRow(color: .green, label: "Bike Infrastructure", text: "Dedicated lanes, cycle tracks, greenways — highest safety weight")
        explainerRow(color: Color(red: 0.45, green: 0.78, blue: 0.18), label: "Shared Path", text: "Multi-use paths and pedestrian trails")
        explainerRow(color: .yellow, label: "Quiet Road", text: "Residential or low-traffic streets")
        explainerRow(color: .orange, label: "Busy Road", text: "Higher-volume streets; penalized by traffic tolerance")
        explainerRow(color: .red, label: "Highway", text: "Freeways and expressways — strong safety penalty")
      }

      Text("Each step is classified, scored 0–100, then blended using your chosen route-priority weights above. Routes are re-ranked whenever you change a filter.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }
    .cardStyle()
  }

  private func explainerRow(color: Color, label: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Capsule().fill(color).frame(width: 14, height: 5).padding(.top, 6)
      VStack(alignment: .leading, spacing: 1) {
        Text(label).font(.caption.bold())
        Text(text).font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Helpers

  private func sectionHeader(_ title: String, icon: String) -> some View {
    Label(title, systemImage: icon)
      .font(.subheadline.bold())
      .foregroundStyle(.secondary)
  }
}

extension View {
  func cardStyle() -> some View {
    self
      .padding(16)
      .background(Color(.systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
  }
}
