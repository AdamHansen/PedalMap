import MapKit
import SwiftUI

struct RoutePlannerView: View {
  var locationManager: LocationManager
  var preferences: SafetyPreferences
  var onStartNavigation: (ScoredRoute) -> Void

  @State private var planner = RoutePlanner()
  @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
  @State private var showSearch = false
  @State private var showTraffic = true
  @State private var showBikePaths = false
  @State private var showSteps = false

  var body: some View {
    ZStack(alignment: .bottom) {
      mapLayer
      VStack(spacing: 0) {
        topBar
        Spacer()
        bottomPanel
      }
    }
    .sheet(isPresented: $showSearch) {
      DestinationSearchView(planner: planner, locationManager: locationManager) {
        showSearch = false
        if let loc = locationManager.currentLocation {
          Task {
            await planner.calculateRoutes(from: loc.coordinate, preferences: preferences)
            fitRoutes()
          }
        }
      }
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showSteps) {
      if let selected = planner.selectedRoute {
        RouteStepsView(route: selected.route, infraTypes: selected.stepInfraTypes)
          .presentationDetents([.medium, .large])
      }
    }
    .onChange(of: preferences.routeMode) { _, _ in
      if let loc = locationManager.currentLocation, !planner.scoredRoutes.isEmpty {
        Task {
          await planner.calculateRoutes(from: loc.coordinate, preferences: preferences)
        }
      }
    }
  }

  // MARK: - Map

  private var mapLayer: some View {
    Map(position: $position) {
      UserAnnotation()

      // Non-selected routes as dim gray
      ForEach(Array(planner.scoredRoutes.enumerated()), id: \.element.id) { index, scored in
        if index != planner.selectedRouteIndex {
          MapPolyline(scored.route.polyline)
            .stroke(.gray.opacity(0.3), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
      }

      // Selected route: colored per step infrastructure type
      if let selected = planner.selectedRoute {
        ForEach(Array(selected.route.steps.enumerated()), id: \.offset) { index, step in
          let coords = step.polyline.coordinates
          let infraType = selected.stepInfraTypes[safe: index] ?? .quietRoad
          if coords.count >= 2 {
            MapPolyline(coordinates: coords)
              .stroke(infraType.color, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
          }
        }
      }

      // Bike infrastructure markers
      if showBikePaths {
        ForEach(planner.nearbyBikePaths, id: \.self) { item in
          if let coord = item.placemark.location?.coordinate {
            Annotation(item.name ?? "Bike Path", coordinate: coord) {
              Image(systemName: "figure.outdoor.cycle")
                .font(.caption2.bold())
                .padding(4)
                .background(.green)
                .foregroundStyle(.white)
                .clipShape(Circle())
            }
          }
        }
      }

      // Destination
      if let dest = planner.destination, let coord = dest.placemark.location?.coordinate {
        Annotation(dest.name ?? "Destination", coordinate: coord) {
          Image(systemName: "flag.checkered.fill")
            .font(.title3)
            .foregroundStyle(.red)
            .shadow(radius: 2)
        }
      }
    }
    .mapStyle(showTraffic
      ? .standard(elevation: .realistic, showsTraffic: true)
      : .standard(elevation: .realistic)
    )
    .mapControls { MapUserLocationButton(); MapCompass() }
    .ignoresSafeArea()
  }

  // MARK: - Top Bar

  private var topBar: some View {
    HStack(spacing: 8) {
      Button { showSearch = true } label: {
        HStack {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          Text(planner.destination?.name ?? "Where are you going?")
            .foregroundStyle(planner.destination == nil ? .secondary : .primary)
            .lineLimit(1)
          Spacer()
          if planner.destination != nil {
            Button { planner.clearRoute() } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)

      iconToggle(isOn: $showTraffic, icon: "car.fill", tint: .orange)
        .onChange(of: showTraffic) { _, _ in }

      iconToggle(isOn: $showBikePaths, icon: "figure.outdoor.cycle", tint: .green)
        .onChange(of: showBikePaths) { _, on in
          if on, let loc = locationManager.currentLocation {
            Task { await planner.findBikePaths(near: loc.coordinate) }
          }
        }
    }
    .padding(.horizontal)
    .padding(.top, 8)
    .padding(.bottom, 4)
  }

  private func iconToggle(isOn: Binding<Bool>, icon: String, tint: Color) -> some View {
    Toggle(isOn: isOn) {
      Image(systemName: icon)
    }
    .toggleStyle(.button)
    .tint(tint)
    .padding(10)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Bottom Panel

  @ViewBuilder
  private var bottomPanel: some View {
    if planner.isCalculating {
      calculatingBar
    } else if !planner.scoredRoutes.isEmpty {
      routePanel
    } else {
      legendBar
    }
  }

  private var calculatingBar: some View {
    HStack(spacing: 10) {
      ProgressView()
      Text("Scoring routes by safety & traffic…")
        .font(.subheadline).foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(.regularMaterial)
  }

  private var legendBar: some View {
    HStack(spacing: 14) {
      ForEach([InfraType.bikeDedicated, .sharedPath, .quietRoad, .busyRoad, .highway], id: \.label) { t in
        HStack(spacing: 4) {
          Capsule().fill(t.color).frame(width: 16, height: 5)
          Text(t.label).font(.caption2).foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
  }

  private var routePanel: some View {
    VStack(spacing: 0) {
      Divider()
      VStack(spacing: 14) {
        // Route mode picker
        modePickerRow

        // Route option cards
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(Array(planner.scoredRoutes.enumerated()), id: \.element.id) { index, scored in
              RouteCard(
                scored: scored,
                isSelected: index == planner.selectedRouteIndex,
                preferences: preferences
              )
              .onTapGesture {
                withAnimation(.snappy) { planner.selectedRouteIndex = index }
                fitRoutes()
              }
            }
          }
          .padding(.horizontal)
        }

        // Action row
        HStack(spacing: 12) {
          Button { showSteps = true } label: {
            Label("Steps", systemImage: "list.number")
              .font(.subheadline)
          }
          .buttonStyle(.bordered)
          .tint(.secondary)

          Button {
            if let selected = planner.selectedRoute {
              onStartNavigation(selected)
            }
          } label: {
            Label("Start Ride", systemImage: "play.fill")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(.green)
              .foregroundStyle(.white)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal)

        if let err = planner.errorMessage {
          Text(err).font(.caption).foregroundStyle(.red).padding(.horizontal)
        }
      }
      .padding(.top, 14)
      .padding(.bottom, 20)
      .background(.regularMaterial)
    }
  }

  private var modePickerRow: some View {
    HStack(spacing: 8) {
      ForEach(RouteMode.allCases) { mode in
        Button {
          preferences.routeMode = mode
          preferences.save()
          if let loc = locationManager.currentLocation, !planner.scoredRoutes.isEmpty {
            Task { await planner.calculateRoutes(from: loc.coordinate, preferences: preferences) }
          }
        } label: {
          HStack(spacing: 5) {
            Image(systemName: mode.icon).font(.caption.bold())
            Text(mode.rawValue).font(.caption.bold())
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .background(preferences.routeMode == mode ? .green : Color(.systemGray5))
          .foregroundStyle(preferences.routeMode == mode ? .white : .primary)
          .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
      Spacer()
    }
    .padding(.horizontal)
  }

  // MARK: - Helpers

  private func fitRoutes() {
    guard let selected = planner.selectedRoute else { return }
    let rect = selected.route.polyline.boundingMapRect
    let padded = rect.insetBy(dx: -rect.width * 0.15, dy: -rect.height * 0.15)
    position = .rect(padded)
  }
}

// MARK: - Route Card

struct RouteCard: View {
  var scored: ScoredRoute
  var isSelected: Bool
  var preferences: SafetyPreferences

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(scored.label).font(.subheadline.bold())
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
      }

      ScoreBar(value: scored.safetyScore, color: .green, label: "Safety")
      ScoreBar(value: scored.trafficExposure, color: .orange, label: "Traffic exposure", invert: true)

      HStack(spacing: 12) {
        Label(preferences.formatDistance(scored.route.distance), systemImage: "arrow.left.and.right")
        Label(bikeTime(scored.route.expectedTravelTime), systemImage: "figure.outdoor.cycle")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(12)
    .frame(width: 210)
    .background(isSelected ? Color.green.opacity(0.08) : Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(isSelected ? Color.green : Color.clear, lineWidth: 1.5)
    )
  }

  private func bikeTime(_ walkSec: Double) -> String {
    let min = Int(walkSec / 3 / 60)
    return min >= 60 ? "\(min/60)h \(min%60)m" : "\(min) min"
  }
}

struct ScoreBar: View {
  var value: Double  // 0-100
  var color: Color
  var label: String
  var invert: Bool = false

  private var displayValue: Double { invert ? 100 - value : value }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 4) {
        Text(label).font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text("\(Int(value))%")
          .font(.caption2.bold())
          .foregroundStyle(invert ? (value > 60 ? .red : .secondary) : (value > 60 ? .green : .orange))
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(color.opacity(0.15)).frame(height: 5)
          Capsule().fill(color).frame(width: geo.size.width * displayValue / 100, height: 5)
        }
      }
      .frame(height: 5)
    }
  }
}

// MARK: - Destination Search

struct DestinationSearchView: View {
  var planner: RoutePlanner
  var locationManager: LocationManager
  var onSelect: () -> Void

  @State private var searchText = ""
  @State private var results: [MKMapItem] = []
  @State private var isSearching = false
  @FocusState private var focused: Bool

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        HStack {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          TextField("Search destination", text: $searchText)
            .focused($focused)
            .submitLabel(.search)
            .onSubmit { Task { await search(query: searchText) } }
          if !searchText.isEmpty {
            Button { searchText = "" } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
          }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()

        if isSearching {
          ProgressView().padding()
        } else {
          ScrollView {
            LazyVStack(spacing: 0) {
              ForEach(results, id: \.self) { item in
                Button {
                  planner.destination = item
                  onSelect()
                } label: {
                  SearchResultRow(item: item)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 56)
              }
            }
          }
        }
        Spacer()
      }
      .navigationTitle("Where to?")
      .navigationBarTitleDisplayMode(.inline)
    }
    .onAppear { focused = true }
    .onChange(of: searchText) { _, q in
      guard !q.isEmpty else { results = []; return }
      Task { await search(query: q) }
    }
  }

  private func search(query: String) async {
    isSearching = true
    let req = MKLocalSearch.Request()
    req.naturalLanguageQuery = query
    if let loc = locationManager.currentLocation {
      req.region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 20000, longitudinalMeters: 20000)
    }
    results = (try? await MKLocalSearch(request: req).start())?.mapItems ?? []
    isSearching = false
  }
}

struct SearchResultRow: View {
  var item: MKMapItem
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: poiIcon(for: item))
        .font(.body).foregroundStyle(.green)
        .frame(width: 32, height: 32)
        .background(Color.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      VStack(alignment: .leading, spacing: 2) {
        Text(item.name ?? "Unknown").font(.subheadline)
        if let addr = item.placemark.formattedAddress {
          Text(addr).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer()
    }
    .padding(.horizontal).padding(.vertical, 10)
  }

  private func poiIcon(for item: MKMapItem) -> String {
    switch item.pointOfInterestCategory {
    case .park, .nationalPark:    return "tree.fill"
    case .cafe, .restaurant:       return "fork.knife"
    case .hospital, .pharmacy:     return "cross.fill"
    case .school, .university:     return "building.columns.fill"
    case .fitnessCenter:           return "figure.run"
    default:                       return "mappin"
    }
  }
}

extension MKPlacemark {
  var formattedAddress: String? {
    [subThoroughfare, thoroughfare, locality]
      .compactMap { $0 }.filter { !$0.isEmpty }
      .joined(separator: " ").nilIfEmpty
  }
}

extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Route Steps

struct RouteStepsView: View {
  var route: MKRoute
  var infraTypes: [InfraType]

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(Array(route.steps.enumerated()), id: \.offset) { i, step in
            if !step.instructions.isEmpty {
              let infra = infraTypes[safe: i] ?? .quietRoad
              HStack(alignment: .top, spacing: 12) {
                Circle().fill(infra.color)
                  .frame(width: 10, height: 10)
                  .padding(.top, 5)
                VStack(alignment: .leading, spacing: 3) {
                  Text(step.instructions).font(.subheadline)
                  HStack(spacing: 8) {
                    if step.distance > 0 {
                      Text(step.distance >= 1000
                        ? String(format: "%.1f km", step.distance/1000)
                        : String(format: "%.0f m", step.distance))
                    }
                    Text(infra.label)
                      .padding(.horizontal, 6).padding(.vertical, 2)
                      .background(infra.color.opacity(0.15))
                      .foregroundStyle(infra.color)
                      .clipShape(Capsule())
                  }
                  .font(.caption)
                  .foregroundStyle(.secondary)
                }
                Spacer()
              }
              .padding(.horizontal).padding(.vertical, 10)
              if i < route.steps.count - 1 { Divider().padding(.leading, 30) }
            }
          }
        }
      }
      .navigationTitle("Turn-by-Turn")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
