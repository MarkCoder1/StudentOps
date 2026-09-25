import SwiftUI

// MARK: - Segmented step progress bar (used on screens 2-4)

struct OnboardingProgressBar: View {
    let totalSteps: Int
    let currentStep: Int // 1-based

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? SOPSTheme.primaryBlue : SOPSTheme.border)
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentStep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep) of \(totalSteps)")
    }
}

// MARK: - Eyebrow / kicker label (icon + small caps blue text)

struct SectionEyebrow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(text.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
        }
        .foregroundColor(SOPSTheme.primaryBlue)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Generic pill / tag chip

struct PillTag: View {
    let text: String
    var icon: String? = nil
    var dotColor: Color? = nil
    var isSelected: Bool = false
    var filledColor: Color? = nil
    var textColor: Color? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            }
            if let dotColor {
                Circle().fill(dotColor).frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(isSelected ? SOPSTheme.primaryBlue : (filledColor ?? SOPSTheme.background))
        )
        .foregroundColor(isSelected ? .white : (textColor ?? SOPSTheme.textSecondary))
        .overlay(
            Capsule().stroke(isSelected ? Color.clear : SOPSTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Card container (white/surface panel with border + soft shadow)

struct SOPSCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: { content })
            .padding(padding)
            .background(SOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SOPSRadius.lg, style: .continuous)
                    .stroke(SOPSTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Circular icon badge

struct IconBadge: View {
    let systemName: String
    var background: Color = SOPSTheme.primaryBlue.opacity(0.12)
    var foreground: Color = SOPSTheme.primaryBlue
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle().fill(background)
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(foreground)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Wordmark row (logo + "STUDENTOPS", used on screen 1's top bar)

struct SOPSWordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SOPSTheme.primaryBlue)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 15))
                )
            (
                Text("STUDENT").fontWeight(.heavy).foregroundColor(SOPSTheme.textPrimary)
                + Text("OPS").fontWeight(.heavy).foregroundColor(SOPSTheme.primaryBlue)
            )
            .font(.system(size: 19))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Student OPS")
    }
}

// MARK: - Primary full-width CTA button

struct SOPSPrimaryButton: View {
    let title: String
    var trailingIcon: String = "arrow.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 17, weight: .semibold))
                Image(systemName: trailingIcon).font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(SOPSTheme.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.md, style: .continuous))
        }
        .buttonStyle(SOPSPressableStyle())
        .accessibilityLabel(title)
    }
}

/// Subtle press-scale feedback for primary buttons.
struct SOPSPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Round back-chevron button used on screens 3 & 4

struct SOPSBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SOPSTheme.textSecondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(SOPSTheme.surface))
                .overlay(Circle().stroke(SOPSTheme.border, lineWidth: 1))
        }
        .accessibilityLabel("Back")
    }
}
