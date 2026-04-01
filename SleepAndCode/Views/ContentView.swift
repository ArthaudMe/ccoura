import SwiftUI
import SwiftData

struct ContentView: View {
    var modelContainer: ModelContainer
    @State private var onboardingVM = OnboardingViewModel()

    var body: some View {
        if onboardingVM.isComplete {
            MainTabView(modelContainer: modelContainer)
        } else {
            OnboardingView(viewModel: onboardingVM)
        }
    }
}

struct MainTabView: View {
    var modelContainer: ModelContainer

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.xyaxis.line") {
                DashboardView()
            }
            Tab("Insights", systemImage: "lightbulb") {
                InsightsView(modelContainer: modelContainer)
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView(modelContainer: modelContainer)
            }
        }
    }
}
