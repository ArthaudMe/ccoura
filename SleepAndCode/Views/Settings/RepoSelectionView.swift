import SwiftUI
import SwiftData

struct RepoSelectionView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            if viewModel.isLoadingRepos {
                Section {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Loading repositories...")
                    }
                }
            }

            if !viewModel.trackedRepos.isEmpty {
                Section("Tracked") {
                    ForEach(viewModel.trackedRepos.filter(\.isActive)) { repo in
                        repoRow(name: repo.fullName, description: repo.repoDescription, isTracked: true) {
                            repo.isActive = false
                            try? modelContext.save()
                        }
                    }
                }
            }

            if !viewModel.repos.isEmpty {
                Section("Available") {
                    ForEach(viewModel.repos) { repo in
                        let tracked = viewModel.isRepoTracked(repo)
                        repoRow(name: repo.fullName, description: repo.description, isTracked: tracked) {
                            viewModel.toggleRepo(repo, modelContext: modelContext)
                        }
                    }
                }
            }
        }
        .navigationTitle("Repositories")
        .task {
            await viewModel.loadGitHubRepos()
        }
    }

    private func repoRow(
        name: String,
        description: String?,
        isTracked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: isTracked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isTracked ? .blue : .secondary)
            }
        }
    }
}
