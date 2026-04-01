import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        TabView(selection: Binding(
            get: { viewModel.currentStep },
            set: { viewModel.currentStep = $0 }
        )) {
            welcomePage.tag(OnboardingStep.welcome)
            githubPage.tag(OnboardingStep.github)
            ouraPage.tag(OnboardingStep.oura)
            donePage.tag(OnboardingStep.done)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 72))
                .foregroundStyle(.purple)

            Text("Sleep & Code")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Understand how your sleep affects your coding output.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                featureRow(icon: "chart.xyaxis.line", title: "Correlation Dashboard", subtitle: "See sleep quality vs commit activity")
                featureRow(icon: "lightbulb.fill", title: "Smart Insights", subtitle: "Discover your patterns")
                featureRow(icon: "bell.fill", title: "Gentle Nudges", subtitle: "Morning & evening notifications")
            }
            .padding(.horizontal)

            Spacer()

            Button("Get Started") { viewModel.advance() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Spacer()
        }
    }

    private var githubPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "curlybraces")
                .font(.system(size: 56))
                .foregroundStyle(.primary)

            Text("Connect GitHub")
                .font(.title)
                .fontWeight(.bold)

            Text("Add a Personal Access Token to track your commits. You can do this now or later in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button("Set Up GitHub") { viewModel.advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Button("Skip for Now") { viewModel.advance() }
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var ouraPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(.purple)

            Text("Connect Oura Ring")
                .font(.title)
                .fontWeight(.bold)

            Text("Sign in with Oura to sync your sleep data. You can do this now or later in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button("Connect Oura") { viewModel.advance() }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.large)

                Button("Skip for Now") { viewModel.advance() }
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var donePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)

            Text("Connect your accounts in Settings whenever you're ready. Data will sync automatically.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button("Start Using Sleep & Code") {
                viewModel.completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 36)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
