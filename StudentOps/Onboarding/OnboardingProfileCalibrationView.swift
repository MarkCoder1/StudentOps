import SwiftUI

/// Screen 2 of 4 — Profile calibration (skills, interests, milestones, goals).
struct OnboardingProfileCalibrationView: View {
    var onContinue: () -> Void
    var onBack: () -> Void
    var onCustomizeLater: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                OnboardingProgressBar(totalSteps: 4, currentStep: 2)
                copyBlock
                cardsStack
                autoAlignRow
                adaptationRow
                SOPSPrimaryButton(title: "Continue", action: onContinue)
                footerRow
            }
            .padding(.horizontal, SOPSSpacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(SOPSTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                    Text("Step 1").font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(SOPSTheme.textSecondary)
            }
            .accessibilityLabel("Back to Step 1")
            Spacer()
            Text("STEP 2 OF 4")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundColor(SOPSTheme.primaryBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(SOPSTheme.primaryBlue.opacity(0.1)))
                .accessibilityLabel("Step 2 of 4")
            Spacer()
            Color.clear.frame(width: 50, height: 1)
        }
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(icon: "sparkles", text: "Intelligent Profile Calibration")
            Text("Everything starts with you.")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(SOPSTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tell Student OPS about your interests, skills, experience, and goals so your workspace can dynamically adapt to your trajectory.")
                .font(.system(size: 15))
                .foregroundColor(SOPSTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Cards

    private var cardsStack: some View {
        VStack(spacing: 14) {
            calibrationCard(
                icon: "chevron.left.slash.chevron.right",
                title: "Core Skills",
                trailing: AnyView(statusTrailing(text: "Active", color: SOPSTheme.success, showDot: true))
            ) {
                HStack(spacing: 8) {
                    PillTag(text: "Python", dotColor: SOPSTheme.primaryBlue)
                    PillTag(text: "Systems Design", dotColor: SOPSTheme.primaryBlue)
                    PillTag(text: "Public Speaking", dotColor: SOPSTheme.textMuted)
                }
            }

            calibrationCard(
                icon: "lightbulb",
                title: "Curiosity Vectors",
                trailing: AnyView(
                    Text("3 Selected").font(.system(size: 12, weight: .medium)).foregroundColor(SOPSTheme.textMuted)
                )
            ) {
                HStack(spacing: 8) {
                    PillTag(text: "Biotech")
                    PillTag(text: "Machine Learning", icon: "checkmark", isSelected: true)
                    PillTag(text: "Aerospace")
                }
            }

            calibrationCard(
                icon: "trophy",
                title: "Key Milestones",
                trailing: AnyView(
                    Text("Verified")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SOPSTheme.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(SOPSTheme.success.opacity(0.12)))
                )
            ) {
                HStack(spacing: 8) {
                    PillTag(text: "FIRST Robotics", icon: "medal")
                    PillTag(text: "Hackathon 1st Place")
                }
            }

            calibrationCard(
                icon: "flag",
                title: "Strategic Horizons",
                trailing: AnyView(
                    Text("Priority").font(.system(size: 12, weight: .medium)).foregroundColor(SOPSTheme.textMuted)
                )
            ) {
                HStack(spacing: 8) {
                    PillTag(text: "Publish Research")
                    PillTag(text: "Lead a Team")
                    PillTag(text: "Top-Tier CS", icon: "graduationcap")
                }
            }
        }
    }

    private func statusTrailing(text: String, color: Color, showDot: Bool) -> some View {
        HStack(spacing: 5) {
            if showDot { Circle().fill(color).frame(width: 6, height: 6) }
            Text(text).font(.system(size: 12, weight: .medium)).foregroundColor(color)
        }
    }

    private func calibrationCard<Content: View>(
        icon: String,
        title: String,
        trailing: AnyView,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SOPSCard {
            HStack {
                HStack(spacing: 10) {
                    IconBadge(systemName: icon, size: 32)
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.3)
                        .foregroundColor(SOPSTheme.primaryBlue)
                }
                Spacer()
                trailing
            }
            content()
        }
    }

    // MARK: Info rows

    private var autoAlignRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SOPSTheme.primaryBlue)
            Text("Auto-aligning study blocks & cohorts")
                .font(.system(size: 13))
                .foregroundColor(SOPSTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Text("94% Fit")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SOPSTheme.primaryBlue)
        }
        .padding(14)
        .background(SOPSTheme.primaryBlue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.md, style: .continuous))
    }

    private var adaptationRow: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemName: "slider.horizontal.3", background: SOPSTheme.textMuted.opacity(0.12), foreground: SOPSTheme.textSecondary, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Real-time Workspace Adaptation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SOPSTheme.textPrimary)
                Text("Updates schedule priority, research feeds, and cohort matches as your profile evolves.")
                    .font(.system(size: 13))
                    .foregroundColor(SOPSTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footerRow: some View {
        HStack(spacing: 6) {
            Text("Step 2 of 4").font(.system(size: 12)).foregroundColor(SOPSTheme.textMuted)
            Circle().fill(SOPSTheme.textMuted).frame(width: 3, height: 3)
            Button(action: onCustomizeLater) {
                Text("Customize Calibrations Later")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SOPSTheme.primaryBlue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
