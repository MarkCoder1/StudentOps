import SwiftUI

/// Screen 3 of 4 — Opportunity matching engine, showing a single matched-project card
/// with a peeking card stacked behind it, plus a horizontal filter row.
struct OnboardingOpportunityMatchingView: View {
    var onContinue: () -> Void
    var onBack: () -> Void
    var onSkip: () -> Void

    @State private var selectedFilter: String = "All Matches"
    private let filters = ["All Matches", "Tech & AI", "Competitions", "Research"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                OnboardingProgressBar(totalSteps: 4, currentStep: 3)
                copyBlock
                cardStack
                filterRow
                SOPSPrimaryButton(title: "Continue", action: onContinue)
                Text("Curating 14 additional matching initiatives  •  Step 3/4")
                    .font(.system(size: 12))
                    .foregroundColor(SOPSTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
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
            Text("Step 3 of 4")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SOPSTheme.textPrimary)
            Spacer()
            Button(action: onSkip) {
                Text("Skip").font(.system(size: 14, weight: .medium)).foregroundColor(SOPSTheme.textMuted)
            }
            .accessibilityLabel("Skip onboarding")
        }
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(icon: "sparkles", text: "Opportunity Matching Engine")
            Text("Find what fits you.")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(SOPSTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Discover projects, competitions, and opportunities precision-matched to your skills, goals, and academic velocity.")
                .font(.system(size: 15))
                .foregroundColor(SOPSTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Card stack (peeking card behind the active match card)

    private var cardStack: some View {
        ZStack(alignment: .top) {
            HStack {
                Text("Climate AI Research")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("89%")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(SOPSTheme.textMuted)
            .padding(16)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(SOPSTheme.surface.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.xl, style: .continuous))
            .padding(.horizontal, 16)
            .offset(y: -14)
            .opacity(0.7)

            matchCard
        }
        .padding(.top, 14)
    }

    private var matchCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            thumbnail

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 11, weight: .bold))
                    Text("96% MATCH").font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(SOPSTheme.success))

                Text("Project Sprint")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SOPSTheme.primaryBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(SOPSTheme.primaryBlue.opacity(0.1)))
            }

            Text("Data Structures & Visualizer")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(SOPSTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            matchedProfileRow

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metaItem(icon: "tag", label: "Skills", value: "Python, Graph Tre...")
                metaItem(icon: "briefcase", label: "Career Track", value: "Software Eng")
                metaItem(icon: "graduationcap", label: "Eligibility", value: "High School / Und...")
                metaItem(icon: "clock", label: "Timeline", value: "3 Weeks Sprint")
            }

            Divider().background(SOPSTheme.border)

            HStack {
                HStack(spacing: 6) {
                    Circle().fill(SOPSTheme.success).frame(width: 7, height: 7)
                    Text("Active cohort matching now")
                        .font(.system(size: 12))
                        .foregroundColor(SOPSTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 3) {
                        Text("View Brief").font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(SOPSTheme.primaryBlue)
                }
            }
        }
        .padding(16)
        .background(SOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SOPSRadius.xl).stroke(SOPSTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    /// NOTE: Replace this gradient placeholder with the real project thumbnail asset
    private var thumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: "1E293B"), Color(hex: "0F172A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.lg, style: .continuous))

            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 11, weight: .semibold))
                Text("Algorithm Architecture").font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.35))
            .clipShape(Capsule())
            .padding(12)

            VStack {
                HStack {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(SOPSTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(SOPSTheme.surface.opacity(0.9)))
                    }
                }
                Spacer()
            }
            .padding(12)
        }
    }

    private var matchedProfileRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 13))
                .foregroundColor(SOPSTheme.primaryBlue)
            (
                Text("Matched to your ").foregroundColor(SOPSTheme.textSecondary)
                + Text("Python").foregroundColor(SOPSTheme.primaryBlue)
                + Text(" & ").foregroundColor(SOPSTheme.textSecondary)
                + Text("CS Systems").foregroundColor(SOPSTheme.primaryBlue)
                + Text(" profile").foregroundColor(SOPSTheme.textSecondary)
            )
            .font(.system(size: 13))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(SOPSTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: SOPSRadius.sm, style: .continuous))
    }

    private func metaItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(SOPSTheme.textMuted)
                .frame(width: 22, height: 22)
                .background(Circle().fill(SOPSTheme.background))
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 11)).foregroundColor(SOPSTheme.textMuted)
                Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(SOPSTheme.textPrimary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Filter row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    Button(action: { withAnimation(.easeOut(duration: 0.15)) { selectedFilter = filter } }) {
                        HStack(spacing: 4) {
                            if selectedFilter == filter {
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                            }
                            Text(filter).font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(selectedFilter == filter ? SOPSTheme.primaryBlue : SOPSTheme.surface))
                        .foregroundColor(selectedFilter == filter ? .white : SOPSTheme.textSecondary)
                        .overlay(Capsule().stroke(selectedFilter == filter ? Color.clear : SOPSTheme.border, lineWidth: 1))
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
