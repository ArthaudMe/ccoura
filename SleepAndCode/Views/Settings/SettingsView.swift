import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    var modelContainer: ModelContainer
    @State private var viewModel = SettingsViewModel()
    @State private var syncCoordinator = SyncCoordinator.shared
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                // GitHub section
                Section("GitHub") {
                    if viewModel.isGitHubConnected {
                        HStack {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            if let username = viewModel.githubUsername {
                                Text(username)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        NavigationLink("Manage Repositories") {
                            RepoSelectionView(viewModel: viewModel)
                        }

                        Button("Disconnect", role: .destructive) {
                            viewModel.disconnectGitHub(modelContext: modelContext)
                        }
                    } else {
                        NavigationLink("Connect GitHub") {
                            GitHubSetupView(viewModel: viewModel)
                        }
                    }
                }

                // Oura section
                Section("Oura Ring") {
                    if viewModel.isOuraConnected {
                        HStack {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                        }

                        Button("Disconnect", role: .destructive) {
                            viewModel.disconnectOura(modelContext: modelContext)
                        }
                    } else {
                        NavigationLink("Connect Oura") {
                            OuraSetupView(onConnected: {
                                viewModel.loadState(modelContext: modelContext)
                            })
                        }
                    }
                }

                // Sync section
                Section("Sync") {
                    if syncCoordinator.isSyncing {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Syncing...")
                        }
                    } else {
                        if let date = syncCoordinator.lastSyncDate {
                            Text("Last synced: \(DateHelpers.relativeDescription(for: date))")
                                .foregroundStyle(.secondary)
                        }

                        Button("Sync Now") {
                            Task {
                                await syncCoordinator.syncAll(modelContainer: modelContainer)
                            }
                        }
                    }

                    if let error = syncCoordinator.syncError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Data section
                Section("Data") {
                    Button("Export CSV") {
                        exportURL = viewModel.exportCSV(modelContext: modelContext)
                        showExportSheet = exportURL != nil
                    }
                }

                // Notifications section
                Section("Notifications") {
                    NavigationLink("Notification Preferences") {
                        NotificationSettingsView()
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { viewModel.loadState(modelContext: modelContext) }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
        }
    }
}

// Simple share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct NotificationSettingsView: View {
    @State private var notifications = NotificationService.shared

    var body: some View {
        List {
            Toggle("Enable Notifications", isOn: $notifications.isEnabled)

            if notifications.isEnabled {
                Toggle("Morning Report", isOn: $notifications.morningEnabled)
                Toggle("Evening Streak", isOn: $notifications.eveningEnabled)
                Toggle("Weekly Summary", isOn: $notifications.weeklyEnabled)
            }
        }
        .navigationTitle("Notifications")
        .onChange(of: notifications.isEnabled) { _, enabled in
            if enabled {
                Task {
                    _ = await notifications.requestPermission()
                }
            }
        }
    }
}
