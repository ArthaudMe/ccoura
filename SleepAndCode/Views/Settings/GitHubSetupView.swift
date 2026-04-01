import SwiftUI

struct GitHubSetupView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pat = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connect GitHub")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Create a fine-grained Personal Access Token with read-only repository access.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Go to GitHub Settings > Developer Settings", systemImage: "1.circle.fill")
                        Label("Personal Access Tokens > Fine-grained tokens", systemImage: "2.circle.fill")
                        Label("Generate new token with 'Contents' read access", systemImage: "3.circle.fill")
                        Label("Paste the token below", systemImage: "4.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                // Token input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personal Access Token")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    SecureField("ghp_xxxxxxxxxxxx", text: $pat)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let error = viewModel.patError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        try? await viewModel.validateAndSaveGitHubPAT(pat)
                        if viewModel.isGitHubConnected {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isValidatingPAT {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pat.isEmpty || viewModel.isValidatingPAT)
            }
            .padding()
        }
        .navigationTitle("GitHub")
        .navigationBarTitleDisplayMode(.inline)
    }
}
