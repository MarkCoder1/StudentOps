import SwiftUI

// MARK: - Six Premium Features (Phase 3)
// Exactly these six categories — do not add seventh "Career Intelligence Pro"
enum PremiumFeature: String, CaseIterable {
    case personalizedRoadmaps = "Personalized Roadmaps"
    case skillGapIntelligence = "Skill Gap Intelligence"
    case smartProjectRecommendations = "Smart Project Recommendations"
    case opportunityMatching = "Opportunity Matching"
    case adaptiveRoadmaps = "Adaptive Roadmaps"
    case progressEvidence = "Progress & Evidence"

    var shortTitle: String {
        switch self {
        case .personalizedRoadmaps: return "Personalized Roadmaps"
        case .skillGapIntelligence: return "Skill Gap"
        case .smartProjectRecommendations: return "Smart Projects"
        case .opportunityMatching: return "Opportunity Match"
        case .adaptiveRoadmaps: return "Adaptive Up Next"
        case .progressEvidence: return "Progress Intelligence"
        }
    }

    var description: String {
        switch self {
        case .personalizedRoadmaps: return "Personalized roadmap recommendations based on your profile"
        case .skillGapIntelligence: return "See what to learn next and why it matters"
        case .smartProjectRecommendations: return "Projects picked for your goals and gaps"
        case .opportunityMatching: return "Why this opportunity fits you"
        case .adaptiveRoadmaps: return "Adaptive next steps and roadmap updates"
        case .progressEvidence: return "Deeper skill and portfolio intelligence"
        }
    }

    var icon: String {
        switch self {
        case .personalizedRoadmaps: return "map"
        case .skillGapIntelligence: return "brain.head.profile"
        case .smartProjectRecommendations: return "hammer"
        case .opportunityMatching: return "star"
        case .adaptiveRoadmaps: return "arrow.triangle.branch"
        case .progressEvidence: return "chart.bar"
        }
    }
}

// MARK: - Pro Badge (subtle, consistent with StudentOPSTheme)

struct ProBadge: View {
    var label: String = "PRO"
    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.6)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(StudentOPSTheme.primaryDark)
            .clipShape(Capsule())
            .accessibilityLabel(Text("Pro feature"))
    }
}

struct ProInlineBadge: View {
    var feature: PremiumFeature
    var body: some View {
        HStack(spacing: 4) {
            ProBadge()
            Text(feature.shortTitle.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundColor(StudentOPSTheme.primaryDark)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(StudentOPSTheme.primaryDark.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(StudentOPSTheme.primaryDark.opacity(0.15)))
    }
}

// MARK: - Locked State (compact preview, not disappearing)

struct ProLockedView: View {
    let feature: PremiumFeature
    var compact: Bool = false
    var onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            VStack(alignment: .leading, spacing: compact ? 6 : 10) {
                HStack(spacing: 8) {
                    Label(feature.shortTitle.uppercased(), systemImage: feature.icon)
                        .font(DashFont.labelMono())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                    Spacer()
                    ProBadge()
                }
                Text(feature.description)
                    .font(compact ? DashFont.bodySm() : DashFont.bodySm())
                    .foregroundColor(StudentOPSTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text("Unlock with Pro")
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.primaryDark)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            .padding(compact ? 12 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Unlock \(feature.rawValue) with Pro"))
    }
}

// Larger section locked view with preview
struct ProLockedSectionView: View {
    let feature: PremiumFeature
    let previewTitle: String
    let previewSubtitle: String
    var onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(feature.shortTitle.uppercased())
                        .font(DashFont.labelMono())
                        .tracking(0.6)
                        .foregroundColor(StudentOPSTheme.textSecondary)
                    Spacer()
                    ProBadge()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(previewTitle)
                        .font(DashFont.titleMd())
                        .foregroundColor(StudentOPSTheme.textPrimary)
                    Text(previewSubtitle)
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                }
                HStack {
                    Text("Unlock personalized analysis")
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.primaryDark)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            .padding(14)
            .background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable Gate

/// Use RevenueCatManager.isPro as ONLY source of truth.
/// If Pro → show content. If Free → show locked preview that presents existing PaywallHostView.
struct PremiumFeatureGate<Content: View>: View {
    let feature: PremiumFeature
    let content: () -> Content

    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var showPaywall = false

    init(feature: PremiumFeature, @ViewBuilder content: @escaping () -> Content) {
        self.feature = feature
        self.content = content
    }

    var body: some View {
        Group {
            if revenueCatManager.isPro {
                content()
            } else {
                ProLockedView(feature: feature) {
                    showPaywall = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallHostView()
                .environmentObject(revenueCatManager)
        }
        // If user purchases, isPro becomes true and content appears automatically
        // No manual isPro=true; driven by CustomerInfo
    }
}

// Variant that keeps a compact preview in locked state with title/subtitle
struct PremiumFeatureGateWithPreview<Content: View>: View {
    let feature: PremiumFeature
    let previewTitle: String
    let previewSubtitle: String
    let content: () -> Content

    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var showPaywall = false

    init(feature: PremiumFeature, previewTitle: String, previewSubtitle: String, @ViewBuilder content: @escaping () -> Content) {
        self.feature = feature
        self.previewTitle = previewTitle
        self.previewSubtitle = previewSubtitle
        self.content = content
    }

    var body: some View {
        Group {
            if revenueCatManager.isPro {
                content()
            } else {
                ProLockedSectionView(feature: feature, previewTitle: previewTitle, previewSubtitle: previewSubtitle) {
                    showPaywall = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallHostView()
                .environmentObject(revenueCatManager)
        }
    }
}

// MARK: - Modifier for inline gating (button-triggered paywall)

extension View {
    func proGate(_ feature: PremiumFeature, isPro: Bool, showPaywall: Binding<Bool>) -> some View {
        self
    }
}
