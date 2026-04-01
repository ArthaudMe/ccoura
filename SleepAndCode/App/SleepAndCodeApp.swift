import SwiftUI
import SwiftData

@main
struct SleepAndCodeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                CommitRecord.self,
                SleepRecord.self,
                DailyAggregate.self,
                TrackedRepository.self,
                SyncState.self,
                CachedInsight.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        BackgroundSyncManager.shared.registerBackgroundTask(modelContainer: modelContainer)
        BackgroundSyncManager.shared.scheduleNextRefresh()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(modelContainer: modelContainer)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await SyncCoordinator.shared.syncIfNeeded(modelContainer: modelContainer)
                        }
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
