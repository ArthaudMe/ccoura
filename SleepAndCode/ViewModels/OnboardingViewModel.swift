import Foundation
import Observation

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case github
    case oura
    case done
}

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var isComplete: Bool {
        get { UserDefaults.standard.bool(forKey: "onboarding_complete") }
        set { UserDefaults.standard.set(newValue, forKey: "onboarding_complete") }
    }

    var githubPAT = ""
    var isGitHubConnected = false
    var isOuraConnected = false

    private let keychain = KeychainService.shared

    func advance() {
        guard let nextIndex = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        currentStep = nextIndex
    }

    func skip() {
        completeOnboarding()
    }

    func completeOnboarding() {
        isComplete = true
    }

    func checkConnectionStatus() {
        isGitHubConnected = keychain.isGitHubConnected
        isOuraConnected = keychain.isOuraConnected
    }
}
