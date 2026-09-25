import SwiftUI

// DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
private func demoEligibilityScore(for id: String) -> Int {
    var hash: Int32 = 0
    for scalar in id.unicodeScalars { hash = (hash &<< 5) &- hash &+ Int32(scalar.value) }
    let h64 = Int64(hash)
    let absHash: Int64 = h64 == Int64(Int32.min) ? Int64(Int32.max) : (h64 < 0 ? -h64 : h64)
    return 80 + Int(absHash % 20)
}

struct OpportunityCard: View {
    private let title: String
    private let organization: String?
    private let category: String
    private let deadline: String
    private let location: String?
    private let description: String
    private let matchScore: Int
    private let validatedSkills: [String]
    private let isSaved: Bool
    private let onSave: () -> Void
    private let onView: () -> Void
    private let showMatch: Bool
    private let showSave: Bool
    private let badges: [String]
    private let isFree: Bool?
    // Phase 10B — eligibility + deterministic reasons
    private let eligibilityStatus: OpportunityEligibilityStatus?
    private let eligibilityLabel: String?
    private let reasons: [String]
    private let deliveryMode: String?
    private let freshnessLabel: String?

    init(opportunity: MatchedOpportunity, onView: @escaping () -> Void = {}) {
        title = opportunity.title
        organization = nil
        category = opportunity.category
        deadline = opportunity.deadlineLabel
        location = nil
        description = opportunity.description
        matchScore = opportunity.matchPercent
        validatedSkills = opportunity.validatedSkills
        isSaved = false
        onSave = {}
        self.onView = onView
        showMatch = true
        showSave = false
        badges = []
        isFree = nil
        eligibilityStatus = nil
        eligibilityLabel = nil
        reasons = []
        deliveryMode = nil
        freshnessLabel = nil
    }

    init(opportunity: ScoredOpportunity, isSaved: Bool, onSave: @escaping () -> Void, onView: @escaping () -> Void) {
        title = opportunity.opportunity.title
        organization = opportunity.opportunity.organization
        category = opportunity.opportunity.category.rawValue
        deadline = opportunity.opportunity.deadline
        location = opportunity.opportunity.legacyLocation
        description = opportunity.opportunity.description
        matchScore = opportunity.matchScore
        validatedSkills = Array(opportunity.opportunity.relevantSkills.prefix(2))
        self.isSaved = isSaved
        self.onSave = onSave
        self.onView = onView
        showMatch = true
        showSave = true
        badges = []
        isFree = nil
        eligibilityStatus = nil
        eligibilityLabel = nil
        reasons = []
        deliveryMode = nil
        freshnessLabel = nil
    }

    init(remoteOpportunity: RemoteOpportunity, isSaved: Bool, onSave: @escaping () -> Void, onView: @escaping () -> Void) {
        title = remoteOpportunity.title
        organization = remoteOpportunity.organization
        category = remoteOpportunity.category.capitalized
        deadline = remoteOpportunity.deadline ?? "No deadline"
        if let city = remoteOpportunity.location.city, !city.isEmpty {
            location = city
        } else if remoteOpportunity.location.online == true {
            location = "Online"
        } else {
            location = nil
        }
        description = remoteOpportunity.description ?? ""
        matchScore = 0
        validatedSkills = Array(remoteOpportunity.skills.prefix(2))
        self.isSaved = isSaved
        self.onSave = onSave
        self.onView = onView
        showMatch = false
        showSave = true
        badges = []
        isFree = remoteOpportunity.cost.isFree
        eligibilityStatus = nil
        eligibilityLabel = nil
        reasons = []
        deliveryMode = nil
        freshnessLabel = nil
    }

    init(personalized: PersonalizedOpportunity, isSaved: Bool, onSave: @escaping () -> Void, onView: @escaping () -> Void) {
        let opp = personalized.opportunity
        title = opp.title
        organization = opp.organization
        category = opp.category.capitalized
        deadline = opp.deadline ?? "No deadline"
        if let city = opp.location.city, !city.isEmpty {
            location = city
        } else if opp.location.online == true {
            location = "Online"
        } else {
            location = nil
        }
        description = opp.description ?? ""
        // DEMO OVERRIDE — ensure high demo score display consistently
        let demoScore = demoEligibilityScore(for: opp.id)
        matchScore = demoScore // override to demo consistency (server already does, but ensure)
        validatedSkills = Array(opp.skills.prefix(2))
        self.isSaved = isSaved
        self.onSave = onSave
        self.onView = onView
        showMatch = true
        showSave = true
        badges = personalized.badges
        isFree = opp.cost.isFree
        eligibilityStatus = .eligible
        eligibilityLabel = "Eligible • \(demoScore)%"
        reasons = []
        deliveryMode = nil
        freshnessLabel = nil
    }

    // MARK: - Phase 10B: Canonical Ranked Opportunity

    init(ranked: RankedOpportunity, isSaved: Bool, onSave: @escaping () -> Void, onView: @escaping () -> Void) {
        let opp = ranked.opportunity
        title = opp.title
        organization = opp.organization
        category = opp.opportunityType.rawValue.capitalized
        deadline = opp.legacyDeadline
        // Location + delivery
        if let city = opp.location.city, !city.isEmpty {
            location = city
        } else if opp.location.online == true || opp.deliveryMode == .online {
            location = "Online"
        } else if opp.deliveryMode == .hybrid {
            location = "Hybrid"
        } else if !opp.legacyLocation.isEmpty {
            location = opp.legacyLocation
        } else {
            location = nil
        }
        description = opp.description
        matchScore = ranked.rankScore
        // Show matched skills or opportunity skills as validated
        if !ranked.matchResult.matchedSkills.isEmpty {
            validatedSkills = Array(ranked.matchResult.matchedSkills.prefix(2).map { SkillCatalog.knownSkills[$0]?.name ?? $0 })
        } else {
            validatedSkills = Array(opp.skills.prefix(2))
        }
        self.isSaved = isSaved
        self.onSave = onSave
        self.onView = onView
        showMatch = true
        showSave = true
        // DEMO OVERRIDE — show high demo eligibility scores consistently (80-99%)
        let demoScore = demoEligibilityScore(for: opp.id)
        eligibilityStatus = .eligible
        eligibilityLabel = "Eligible • \(demoScore)%"
        // Deterministic reasons (first 2)
        reasons = Array(ranked.matchResult.reasons.prefix(2))
        // Badges from urgency/eligibility
        var b: [String] = []
        if ranked.rankScore >= 80 { b.append("Best Match") }
        if let urg = ranked.matchResult.signals.first(where: { $0.dimension == "deadlineUrgency" }), urg.available && urg.score >= 0.9 { b.append("Deadline Soon") }
        badges = b
        isFree = opp.costInfo?.isFree
        // Delivery / freshness
        switch opp.deliveryMode {
        case .online: deliveryMode = "Online"
        case .hybrid: deliveryMode = "Hybrid"
        case .inPerson: deliveryMode = "In-person"
        case .unknown: deliveryMode = nil
        }
        freshnessLabel = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: category + deadline, compact
            HStack(spacing: 6) {
                Text(category).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 7).padding(.vertical, 3).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                Spacer()
                Text(deadline).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(2)
                if let organization { Text(organization).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).lineLimit(1) }
            }
            // Compact eligibility + match line (replaces separate pills + badges)
            HStack(spacing: 6) {
                if let status = eligibilityStatus, let label = eligibilityLabel {
                    eligibilityPill(status: status, label: label)
                } else if showMatch {
                    Text("\(matchScore)% Match").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 7).padding(.vertical, 3).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                }
                if eligibilityStatus != nil && showMatch {
                    Text("\(matchScore)% Match").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
            }
            // Single reason line only (spec: maximum one short reason)
            if let firstReason = reasons.first {
                Text(firstReason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
            } else if !description.isEmpty && eligibilityStatus == nil {
                Text(description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
            }
            HStack(spacing: 8) {
                Button(action: onView) {
                    HStack(spacing: 6) {
                        Text("View").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }.buttonStyle(.plain)
                if showSave {
                    Button(action: onSave) { Image(systemName: isSaved ? "bookmark.fill" : "bookmark").font(.system(size: 14)).foregroundColor(StudentOPSTheme.primaryDark) }.buttonStyle(.plain).accessibilityLabel(isSaved ? "Remove saved opportunity" : "Save opportunity")
                }
            }
        }
        .padding(14).background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard).stroke(StudentOPSTheme.border.opacity(0.4)))
    }

    @ViewBuilder
    private func eligibilityPill(status: OpportunityEligibilityStatus, label: String) -> some View {
        let color: Color = status == .eligible ? StudentOPSTheme.success : status == .unknown ? StudentOPSTheme.warning : Color.red
        let icon = status == .eligible ? "checkmark.shield.fill" : status == .unknown ? "questionmark.shield" : "xmark.shield.fill"
        Label(label, systemImage: icon).font(DashFont.labelMd()).foregroundColor(color).padding(.horizontal, 8).padding(.vertical, 3).background(color.opacity(0.12)).clipShape(Capsule())
    }

    @ViewBuilder
    private func badgeView(_ badge: String) -> some View {
        switch badge {
        case "Best Match":
            Label(badge, systemImage: "star.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textOnLime).padding(.horizontal, 8).padding(.vertical, 3).background(StudentOPSTheme.lime.opacity(0.4)).clipShape(Capsule())
        case "Deadline Soon":
            Label(badge, systemImage: "clock.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textOnWarning).padding(.horizontal, 8).padding(.vertical, 3).background(StudentOPSTheme.warning.opacity(0.8)).clipShape(Capsule())
        case "Free":
            Label(badge, systemImage: "checkmark.circle.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.success).padding(.horizontal, 8).padding(.vertical, 3).background(StudentOPSTheme.success.opacity(0.15)).clipShape(Capsule())
        default:
            Text(badge).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 3).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
        }
    }
}

struct OpportunityCardCompact: View {
    private let title: String
    private let category: String
    private let deadline: String
    private let matchScore: Int
    private let onView: () -> Void

    init(opportunity: MatchedOpportunity, onView: @escaping () -> Void) {
        title = opportunity.title
        category = opportunity.category
        deadline = opportunity.deadlineLabel
        matchScore = opportunity.matchPercent
        self.onView = onView
    }

    var body: some View {
        Button(action: onView) {
            HStack(spacing: 12) {
                Circle().fill(StudentOPSTheme.primary.opacity(0.12)).frame(width: 36, height: 36).overlay(Image(systemName: "star").font(.system(size: 14, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(category).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        Text("•").foregroundColor(StudentOPSTheme.textSecondary)
                        Text(deadline).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        if matchScore > 0 {
                            Text("\(matchScore)%").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success).padding(.horizontal, 6).padding(.vertical, 2).background(StudentOPSTheme.success.opacity(0.12)).clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
            }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
        }.buttonStyle(.plain).accessibilityLabel(Text("View opportunity: \(title)"))
    }
}
