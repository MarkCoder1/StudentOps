import SwiftUI

/// Screen 4 of 4 — Vertical connected flow of goal → gap → roadmap → action → opportunity → proof.
struct OnboardingGrowthArchitectureView: View {
    var onBuild: () -> Void
    var onBack: () -> Void

    private struct FlowStep: Identifiable {
        let id = UUID()
        let icon: String
        let iconColor: Color
        let label: String
        let title: String
        let titleColor: Color
        let badgeText: String
        let badgeColor: Color
        let badgeStyle: BadgeStyle
    }

    private enum BadgeStyle { case pill, filled, dotted }

    private var steps: [FlowStep] {
        [
            FlowStep(icon: "safari", iconColor: SOPSTheme.primaryBlue, label: "Career Goal", title: "AI & Robotics Engineer", titleColor: SOPSTheme.textPrimary, badgeText: "Anchor", badgeColor: SOPSTheme.textMuted, badgeStyle: .pill),
            FlowStep(icon: "bolt", iconColor: SOPSTheme.primaryBlue, label: "Skill Gap", title: "Deep Learning & ROS2", titleColor: SOPSTheme.textPrimary, badgeText: "2 Gaps", badgeColor: SOPSTheme.danger, badgeStyle: .filled),
            FlowStep(icon: "medal", iconColor: SOPSTheme.primaryBlue, label: "Milestone Roadmap", title: "Phase 2: Neural Perception", titleColor: SOPSTheme.textPrimary, badgeText: "Sprint 4", badgeColor: SOPSTheme.textMuted, badgeStyle: .pill),
            FlowStep(icon: "message", iconColor: SOPSTheme.primaryBlue, label: "High Priority Action", title: "Vision-Guided Quadruped", titleColor: SOPSTheme.primaryBlue, badgeText: "In Build", badgeColor: SOPSTheme.success, badgeStyle: .dotted),
            FlowStep(icon: "medal.fill", iconColor: SOPSTheme.success, label: "Target Opportunity", title: "NASA Ames Showcase", titleColor: SOPSTheme.textPrimary, badgeText: "14d left", badgeColor: SOPSTheme.textMuted, badgeStyle: .pill),
            FlowStep(icon: "checkmark.seal", iconColor: SOPSTheme.success, label: "Portfolio Proof", title: "Verified GitHub + ROS Stack", titleColor: SOPSTheme.textPrimary, badgeText: "Ready", badgeColor: SOPSTheme.success, badgeStyle: .filled)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                OnboardingProgressBar(totalSteps: 4, currentStep: 4)
                copyBlock
                flowCard
                synergyRow
                SOPSPrimaryButton(title: "Build My Student OPS", trailingIcon: "sparkles", action: onBuild)
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
            SOPSBackButton(action: onBack)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(SOPSTheme.primaryBlue).frame(width: 6, height: 6)
                Text("STEP 4 OF 4").font(.system(size: 11, weight: .bold)).tracking(0.4)
            }
            .foregroundColor(SOPSTheme.primaryBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(SOPSTheme.primaryBlue.opacity(0.1)))
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SOPSTheme.primaryBlue)
                .frame(width: 32, height: 32)
                .background(Circle().fill(SOPSTheme.primaryBlue.opacity(0.12)))
                .accessibilityHidden(true)
        }
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(icon: "point.3.connected.trianglepath.dotted", text: "Autonomous Growth Architecture")
            Text("Turn your goals into action.")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(SOPSTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Student OPS connects your career trajectory, skill gaps, roadmap, projects, and evidence — ensuring absolute clarity on your next optimal move.")
                .font(.system(size: 15))
                .foregroundColor(SOPSTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Flow card

    private var flowCard: some View {
        SOPSCard(padding: 16) {
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step)
                    if index < steps.count - 1 {
                        HStack {
                            Rectangle()
                                .fill(SOPSTheme.border)
                                .frame(width: 2, height: 18)
                                .padding(.leading, 17)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func stepRow(_ step: FlowStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemName: step.icon, background: step.iconColor.opacity(0.12), foreground: step.iconColor, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(step.label.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.3)
                    .foregroundColor(SOPSTheme.textMuted)
                Text(step.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(step.titleColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            badge(for: step)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func badge(for step: FlowStep) -> some View {
        switch step.badgeStyle {
        case .pill:
            Text(step.badgeText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(step.badgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(SOPSTheme.background))
        case .filled:
            Text(step.badgeText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(step.badgeColor))
        case .dotted:
            HStack(spacing: 5) {
                Circle().fill(step.badgeColor).frame(width: 6, height: 6)
                Text(step.badgeText).font(.system(size: 12, weight: .medium)).foregroundColor(step.badgeColor)
            }
        }
    }

    // MARK: Footer rows

    private var synergyRow: some View {
        HStack(spacing: 12) {
            IconBadge(systemName: "waveform.path.ecg", background: SOPSTheme.primaryBlue.opacity(0.12), foreground: SOPSTheme.primaryBlue, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("System Synergy Active")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SOPSTheme.textPrimary)
                Text("All 6 execution vectors primed for acceleration.")
                    .font(.system(size: 13))
                    .foregroundColor(SOPSTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            Text("100%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(SOPSTheme.primaryBlue)
        }
    }

    private var footerRow: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "clock").font(.system(size: 11))
                Text("Takes 2 minutes to personalize").font(.system(size: 12))
            }
            .foregroundColor(SOPSTheme.textMuted)
            Spacer()
            Text("4/4 • Launch Ready")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(SOPSTheme.textMuted)
        }
    }
}
