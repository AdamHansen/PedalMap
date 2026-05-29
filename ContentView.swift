import SwiftUI

struct ContentView: View {
  @State private var locationManager = LocationManager()
  @State private var rideStore = RideStore()
  @State private var preferences = SafetyPreferences()
  @State private var navigationSession = NavigationSession()
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      RoutePlannerView(
        locationManager: locationManager,
        preferences: preferences,
        onStartNavigation: startNavigation
      )
      .tabItem { Label("Plan", systemImage: "map.fill") }
      .tag(0)

      SafetyFiltersView(preferences: preferences)
        .tabItem { Label("Filters", systemImage: "slider.horizontal.3") }
        .tag(1)

      RideHistoryView(rideStore: rideStore, preferences: preferences)
        .tabItem { Label("History", systemImage: "list.bullet.clipboard.fill") }
        .tag(2)
    }
    .fullScreenCover(isPresented: $navigationSession.isActive) {
      ActiveRideView(
        locationManager: locationManager,
        navigationSession: navigationSession,
        rideStore: rideStore,
        preferences: preferences,
        onEnd: { navigationSession.isActive = false }
      )
    }
  }

  private func startNavigation(_ scored: ScoredRoute) {
    locationManager.startTracking()
    navigationSession.start(route: scored.route, infraTypes: scored.stepInfraTypes)
  }
}
