import SwiftUI

/// Screen 1 of 4 — Hero / welcome screen.
struct OnboardingWelcomeView: View {
    var onGetStarted: () -> Void
    var onSkip: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearanceManager: AppearanceManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar
                stepRow
                heroPanel
                    .padding(.top, 4)
                copyBlock
                SOPSPrimaryButton(title: "Get Started", action: onGetStarted)
                swipeHint
            }
            .padding(.horizontal, SOPSSpacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(SOPSTheme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            SOPSWordmark()
            Spacer()
            Button(action: onSkip) {
                Text("Skip")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SOPSTheme.textMuted)
            }
            .accessibilityLabel("Skip onboarding")
        }
    }

    // MARK: Step row (dash + 3 dots, "1 of 4", theme toggle)

    private var stepRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Capsule().fill(SOPSTheme.primaryBlue).frame(width: 32, height: 4)
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(SOPSTheme.border).frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)
            Text("1 of 4")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(SOPSTheme.textMuted)
                .accessibilityLabel("Step 1 of 4")
            Spacer()
            // Theme toggle cycles System → Light → Dark using existing AppearanceManager
            Button(action: { cycleAppearance() }) {
                HStack(spacing: 6) {
                    Image(systemName: themeIcon).font(.system(size: 12))
                    Text(appearanceManager.preference.rawValue.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.4)
                }
                .foregroundColor(SOPSTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(SOPSTheme.surface))
                .overlay(Capsule().stroke(SOPSTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Appearance: \(appearanceManager.preference.rawValue)")
            .accessibilityHint("Cycles between System, Light and Dark")
        }
    }

    private var themeIcon: String {
        switch appearanceManager.preference {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    private func cycleAppearance() {
        switch appearanceManager.preference {
        case .system: appearanceManager.preference = .light
        case .light: appearanceManager.preference = .dark
        case .dark: appearanceManager.preference = .system
        }
    }

    // MARK: Hero panel (floating chips + code window + rover row)

    private var heroPanel: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                chipCard(
                    icon: "chevron.left.slash.chevron.right",
                    iconColor: SOPSTheme.primaryBlue,
                    title: "Algorithms & AI",
                    subtitle: "In progress",
                    subtitleColor: SOPSTheme.textMuted,
                    dotColor: SOPSTheme.textMuted
                )
                chipCard(
                    icon: "sparkle",
                    iconColor: SOPSTheme.success,
                    title: "NASA GeneLab",
                    subtitle: "98% Match",
                    subtitleColor: SOPSTheme.success,
                    dotColor: nil,
                    subtitleIcon: "plus.circle.fill"
                )
            }

            codeWindowCard

            HStack(spacing: 12) {
                IconBadge(systemName: "cpu", background: SOPSTheme.primaryBlue.opacity(0.12), foreground: SOPSTheme.primaryBlue, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Autonomous Rover")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SOPSTheme.textPrimary)
                    Text("Hardware • Lead Engineer")
                        .font(.system(size: 13))
                        .foregroundColor(SOPSTheme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SOPSTheme.textMuted)
            }
            .padding(14)
            .background(SOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.md, style: .continuous))
        }
        .padding(16)
        .background(SOPSTheme.primaryBlue.opacity(colorScheme == .dark ? 0.10 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.xl, style: .continuous))
    }

    private func chipCard(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        subtitleColor: Color,
        dotColor: Color?,
        subtitleIcon: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                IconBadge(systemName: icon, background: iconColor.opacity(0.12), foreground: iconColor, size: 26)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SOPSTheme.textPrimary)
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                if let subtitleIcon {
                    Image(systemName: subtitleIcon).font(.system(size: 10))
                } else if let dotColor {
                    Circle().fill(dotColor).frame(width: 6, height: 6)
                }
                Text(subtitle).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(subtitleColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.md, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var codeWindowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "EF4444")).frame(width: 9, height: 9)
                    Circle().fill(Color(hex: "F59E0B")).frame(width: 9, height: 9)
                    Circle().fill(Color(hex: "10B981")).frame(width: 9, height: 9)
                }
                Spacer()
                Text("student_ops.dev")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(SOPSTheme.textMuted)
                Spacer()
                Color.clear.frame(width: 33)
            }
            Divider().background(SOPSTheme.border)
            VStack(alignment: .leading, spacing: 4) {
                (Text("const ").foregroundColor(Color(hex: "C026D3")) + Text("mission = {").foregroundColor(SOPSTheme.textPrimary))
                Text("  velocity: \"accelerating\",").foregroundColor(SOPSTheme.textPrimary)
                (Text("  readiness: ").foregroundColor(SOPSTheme.textPrimary) + Text("100%").foregroundColor(SOPSTheme.primaryBlue))
                Text("};").foregroundColor(SOPSTheme.textPrimary)
            }
            .font(.system(size: 13, design: .monospaced))
        }
        .padding(16)
        .background(SOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SOPSRadius.lg, style: .continuous)
                .stroke(SOPSTheme.textPrimary.opacity(0.85), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    // MARK: Copy block

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(icon: "circle.fill", text: "AI-Powered Operating System")

            Text("Your path. Your projects.\nYour next move.")
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(SOPSTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
                .lineLimit(3)

            Text("Build your skills, discover breakthrough opportunities, and turn what you do into verified, high-impact career progress.")
                .font(.system(size: 16))
                .foregroundColor(SOPSTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                PillTag(text: "Adaptive Copilot", icon: "brain.head.profile")
                PillTag(text: "Peer Audited", icon: "checkmark.seal")
            }
            .padding(.top, 4)
        }
    }

    private var swipeHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.left.arrow.right").font(.system(size: 12))
            Text("Swipe to explore or tap Get Started").font(.system(size: 13))
        }
        .foregroundColor(SOPSTheme.textMuted)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }
}
