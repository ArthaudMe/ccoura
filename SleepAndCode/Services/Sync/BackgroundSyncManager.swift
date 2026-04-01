import BackgroundTasks
import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.sleepandcode", category: "BackgroundSync")

/// Manages background app refresh tasks to keep GitHub and Oura data up to date.
///
/// Call `registerBackgroundTask(modelContainer:)` once during app launch
/// (e.g., in your `App.init`) and `scheduleNextRefresh()` whenever a sync completes
/// or the app moves to the background.
final class BackgroundSyncManager: Sendable {
    static let shared = BackgroundSyncManager()

    private init() {}

    // MARK: - Registration

    /// Registers the background refresh task handler with the system.
    /// Must be called before the end of the app's launch sequence.
    func registerBackgroundTask(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.Sync.backgroundTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(refreshTask, modelContainer: modelContainer)
        }
        logger.info("Registered background task: \(Constants.Sync.backgroundTaskID)")
    }

    // MARK: - Scheduling

    /// Schedules the next background app refresh. Safe to call multiple times;
    /// each call replaces any previously pending request for the same identifier.
    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Constants.Sync.backgroundTaskID)
        request.earliestBeginDate = Date(
            timeIntervalSinceNow: Constants.Sync.backgroundRefreshInterval
        )

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info(
                "Scheduled next background refresh in \(Constants.Sync.backgroundRefreshInterval / 3600, privacy: .public)h"
            )
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }

    // MARK: - Task Handling

    private func handleAppRefresh(
        _ task: BGAppRefreshTask,
        modelContainer: ModelContainer
    ) {
        // Schedule the next refresh immediately so we don't lose periodicity
        // even if this execution fails.
        scheduleNextRefresh()

        let syncTask = Task { @MainActor in
            await SyncCoordinator.shared.syncAll(modelContainer: modelContainer)
        }

        // If the system needs to reclaim resources, cancel the sync gracefully.
        task.expirationHandler = {
            logger.warning("Background sync task expired — cancelling")
            syncTask.cancel()
        }

        Task {
            await syncTask.value
            let hasError = await MainActor.run {
                SyncCoordinator.shared.syncError != nil
            }
            task.setTaskCompleted(success: !hasError)
            logger.info("Background sync task finished — success: \(!hasError)")
        }
    }
}
