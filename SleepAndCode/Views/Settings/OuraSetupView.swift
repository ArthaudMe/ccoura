import SwiftUI
import AuthenticationServices

struct OuraSetupView: View {
    let onConnected: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isAuthenticating = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)

                    Text("Connect Oura Ring")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Sign in with your Oura account to sync your sleep data. We'll access your daily sleep scores, duration, and sleep stages.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    Task { await startOAuthFlow() }
                } label: {
                    if isAuthenticating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Sign in with Oura", systemImage: "person.circle")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(isAuthenticating)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What we access:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Label("Daily sleep score", systemImage: "checkmark")
                    Label("Sleep duration & stages", systemImage: "checkmark")
                    Label("Heart rate & HRV", systemImage: "checkmark")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .padding()
        }
        .navigationTitle("Oura")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func startOAuthFlow() async {
        isAuthenticating = true
        error = nil
        defer { isAuthenticating = false }

        do {
            try await OuraAuthService.shared.authenticate()
            onConnected()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
