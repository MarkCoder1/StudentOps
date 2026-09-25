import SwiftUI

/// Top-level container that hosts all 4 onboarding screens in a swipeable pager.
/// Each screen's own CTA (Get Started / Continue / Build My Student OPS) advances
/// `selection`; the user can also swipe freely between already-unlocked pages.
struct OnboardingContainerView: View {
    @State private var selection: Int = 0

    /// Called when onboarding completes (from screen 4's CTA) or is skipped
    /// (from screen 1 or 3's Skip button).
    var onFinish: () -> Void = {}

    var body: some View {
        TabView(selection: $selection) {
            OnboardingWelcomeView(
                onGetStarted: { advance(to: 1) },
                onSkip: onFinish
            )
            .tag(0)

            OnboardingProfileCalibrationView(
                onContinue: { advance(to: 2) },
                onBack: { advance(to: 0) },
                onCustomizeLater: onFinish
            )
            .tag(1)

            OnboardingOpportunityMatchingView(
                onContinue: { advance(to: 3) },
                onBack: { advance(to: 1) },
                onSkip: onFinish
            )
            .tag(2)

            OnboardingGrowthArchitectureView(
                onBuild: onFinish,
                onBack: { advance(to: 2) }
            )
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.3), value: selection)
        .background(SOPSTheme.background.ignoresSafeArea())
    }

    private func advance(to page: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selection = page
        }
    }
}
