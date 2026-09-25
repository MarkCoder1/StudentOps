import SwiftUI

struct OpportunityDetailView: View {
    var scoredOpportunity: ScoredOpportunity?
    var remoteOpportunity: RemoteOpportunity?
    var personalizedOpportunity: PersonalizedOpportunity?
    var rankedOpportunity: RankedOpportunity?
    var canonicalOpportunity: Opportunity?
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // MARK: - AI Explanation State (Phase 6.2)
    @State private var explanation: OpportunityExplanation?
    @State private var loadingExplanation = false
    @State private var explanationError = false
    @State private var showEvidenceForm = false
    @State private var selectedEvidence: EvidenceRecord?
    @State private var selectedAchievement: Achievement?

    // Legacy init for mock/preview
    init(scoredOpportunity: ScoredOpportunity) {
        self.scoredOpportunity = scoredOpportunity
        self.remoteOpportunity = nil
        self.personalizedOpportunity = nil
        self.rankedOpportunity = nil
        self.canonicalOpportunity = nil
    }
    // Real API init
    init(remoteOpportunity: RemoteOpportunity) {
        self.remoteOpportunity = remoteOpportunity
        self.scoredOpportunity = nil
        self.personalizedOpportunity = nil
        self.rankedOpportunity = nil
        self.canonicalOpportunity = nil
    }
    // Personalized init
    init(personalizedOpportunity: PersonalizedOpportunity) {
        self.personalizedOpportunity = personalizedOpportunity
        self.remoteOpportunity = personalizedOpportunity.opportunity
        self.scoredOpportunity = nil
        self.rankedOpportunity = nil
        self.canonicalOpportunity = nil
    }
    // Legacy init with store
    init(scoredOpportunity: ScoredOpportunity, savedStore: SavedOpportunityStore) {
        self.scoredOpportunity = scoredOpportunity
        self.remoteOpportunity = nil
        self.personalizedOpportunity = nil
        self.rankedOpportunity = nil
        self.canonicalOpportunity = nil
    }
    // Phase 10B — Canonical
    init(opportunity: Opportunity) {
        self.canonicalOpportunity = opportunity
        self.rankedOpportunity = nil
        self.scoredOpportunity = nil
        self.remoteOpportunity = nil
        self.personalizedOpportunity = nil
    }
    init(ranked: RankedOpportunity) {
        self.rankedOpportunity = ranked
        self.canonicalOpportunity = ranked.opportunity
        self.scoredOpportunity = nil
        self.remoteOpportunity = nil
        self.personalizedOpportunity = nil
    }

    private var isRemote: Bool { remoteOpportunity != nil }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if let personalized = personalizedOpportunity {
                    // Hierarchy: Eligibility → Match → Freshness → AI (secondary) — PRO 4 gates Match
                    eligibilitySection(personalized)
                    PremiumFeatureGate(feature: .opportunityMatching) {
                        matchSection(personalized)
                    }
                    freshnessSection(personalized)
                    aiInsightCollapsibleSection
                    personalizedHeader(personalized)
                    if let remote = remoteOpportunity {
                        remoteDetailCard(remote)
                        roadmapConnectionSection(for: remote)
                        if let desc = remote.description, !desc.isEmpty {
                            section(title: "About this opportunity", icon: "doc.text") { Text(desc).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                        }
                        remoteBenefitsSection(remote)
                        remoteLocationSection(remote)
                    }
                    opportunityEvidenceSection(for: personalized.opportunity.id)
                    Text("Source: \(personalized.opportunity.source) • Fetched \(formattedDate(personalized.opportunity.provenance.fetchedAt))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let remote = remoteOpportunity {
                    remoteHeader(remote)
                    remoteDetailCard(remote)
                    roadmapConnectionSection(for: remote)
                    if let desc = remote.description, !desc.isEmpty {
                        section(title: "About this opportunity", icon: "doc.text") { Text(desc).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                    remoteEligibilitySection(remote)
                    remoteBenefitsSection(remote)
                    remoteLocationSection(remote)
                    opportunityEvidenceSection(for: remote.id)
                    Text("Source: \(remote.source) • Fetched \(formattedDate(remote.provenance.fetchedAt))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let ranked = rankedOpportunity {
                    // Phase 10B — Canonical ranked opportunity (authoritative) — FACTS free, MATCH is PRO 4
                    eligibilityRankedSection(ranked)
                    PremiumFeatureGate(feature: .opportunityMatching) {
                        matchRankedSection(ranked)
                    }
                    freshnessRankedSection(ranked)
                    aiInsightCollapsibleSection
                    rankedHeader(ranked)
                    rankedDetailCard(ranked)
                    roadmapConnectionSection(for: ranked.opportunity)
                    factsSection(for: ranked.opportunity)
                    PremiumFeatureGate(feature: .opportunityMatching) {
                        matchDetailsSection(for: ranked)
                    }
                    sourceRankedSection(ranked)
                    opportunityEvidenceSection(for: ranked.opportunity.id)
                } else if let opp = canonicalOpportunity {
                    let ranked = store.matchResult(for: opp)
                    let rankedWrapper = RankedOpportunity(opportunity: opp, matchResult: ranked, eligibilityStatus: ranked.eligibilityResult.status, rankScore: ranked.overallMatchScore)
                    eligibilityRankedSection(rankedWrapper)
                    PremiumFeatureGate(feature: .opportunityMatching) {
                        matchRankedSection(rankedWrapper)
                    }
                    freshnessRankedSection(rankedWrapper)
                    aiInsightCollapsibleSection
                    rankedHeader(rankedWrapper)
                    rankedDetailCard(rankedWrapper)
                    roadmapConnectionSection(for: opp)
                    factsSection(for: opp)
                    PremiumFeatureGate(feature: .opportunityMatching) {
                        matchDetailsSection(for: rankedWrapper)
                    }
                    sourceRankedSection(rankedWrapper)
                    opportunityEvidenceSection(for: opp.id)
                } else if let scored = scoredOpportunity {
                    // Deterministic hierarchy for scored — FACTS free, MATCH is PRO 4
                    eligibilityScoredSection(scored)
                    PremiumFeatureGate(feature: .opportunityMatching) {
                        matchScoredSection(scored)
                    }
                    // No freshness for scored (local)
                    headerScored(scored)
                    detailCardScored(scored)
                    roadmapConnectionSection(for: scored.opportunity)
                    let opp = scored.opportunity
                    PremiumFeatureGate(feature: .opportunityMatching) {
                        section(title: "Why it matches", icon: "sparkles") { Text(opp.whyItMatches).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                    section(title: "Requirements", icon: "checklist") { ForEach(opp.requirements, id: \.self) { detailRow(icon: "checkmark", text: $0) } }
                    section(title: "Important dates", icon: "calendar") { ForEach(opp.importantDates, id: \.self) { detailRow(icon: "circle.fill", text: $0) } }
                    Text("This is a local Student OPS catalog record. Official links will appear when a live opportunity source is connected.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }.padding(16)
        }
        .background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("Opportunity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let remote = remoteOpportunity {
                    Button { store.toggleSaved(remote) } label: { Image(systemName: store.isSaved(remote) ? "bookmark.fill" : "bookmark").foregroundColor(StudentOPSTheme.primaryDark) }
                } else if let ranked = rankedOpportunity {
                    let opp = ranked.opportunity
                    Button { store.toggleSaved(opp) } label: { Image(systemName: store.isSaved(opp) ? "bookmark.fill" : "bookmark").foregroundColor(StudentOPSTheme.primaryDark) }
                } else if let opp = canonicalOpportunity {
                    Button { store.toggleSaved(opp) } label: { Image(systemName: store.isSaved(opp) ? "bookmark.fill" : "bookmark").foregroundColor(StudentOPSTheme.primaryDark) }
                } else if let scored = scoredOpportunity {
                    let opp = scored.opportunity
                    Button { store.toggleSaved(opp) } label: { Image(systemName: store.isSaved(opp) ? "bookmark.fill" : "bookmark").foregroundColor(StudentOPSTheme.primaryDark) }
                }
            }
        }
        .task {
            await loadExplanation()
        }
        .sheet(isPresented: $showEvidenceForm) {
            if let remote = remoteOpportunity {
                EvidenceFormView(initialOpportunityID: remote.id)
                    .environmentObject(store)
            } else if let personalized = personalizedOpportunity {
                EvidenceFormView(initialOpportunityID: personalized.opportunity.id)
                    .environmentObject(store)
            } else if let ranked = rankedOpportunity {
                EvidenceFormView(initialOpportunityID: ranked.opportunity.id)
                    .environmentObject(store)
            } else if let opp = canonicalOpportunity {
                EvidenceFormView(initialOpportunityID: opp.id)
                    .environmentObject(store)
            } else if let scored = scoredOpportunity {
                EvidenceFormView(initialOpportunityID: scored.opportunity.id)
                    .environmentObject(store)
            }
        }
        .sheet(item: $selectedEvidence) { rec in EvidenceDetailSheet(record: rec).environmentObject(store) }
        .sheet(item: $selectedAchievement) { ach in NavigationStack { AchievementDetailView(achievement: ach).environmentObject(store) } }
    }

    @ViewBuilder
    private func opportunityEvidenceSection(for opportunityID: String) -> some View {
        let relatedEvidence = store.allEvidenceSorted.filter { $0.opportunityID == opportunityID }
        let relatedAchievements = store.achievementRecords.values.filter { $0.opportunityID == opportunityID }.sorted { $0.createdAt > $1.createdAt }
        VStack(alignment: .leading, spacing: 12) {
            Label("Participation Evidence", systemImage: "doc.badge.ellipsis")
                .font(DashFont.titleMd())
                .foregroundColor(StudentOPSTheme.textPrimary)
            Text("Only record participation if you actually participated. Saving or viewing this opportunity does not create evidence.")
                .font(DashFont.bodySm())
                .foregroundColor(StudentOPSTheme.textSecondary)
            if relatedEvidence.isEmpty {
                Text("No participation evidence yet.")
                    .font(DashFont.bodySm())
                    .foregroundColor(StudentOPSTheme.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StudentOPSTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(relatedEvidence.prefix(2)) { rec in
                    Button { selectedEvidence = rec } label: {
                        HStack {
                            Text(rec.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                        }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            if !relatedAchievements.isEmpty {
                Label("Related Achievements", systemImage: "star.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                ForEach(relatedAchievements.prefix(2)) { ach in
                    Button { selectedAchievement = ach } label: {
                        HStack {
                            Text(ach.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                        }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            Button(action: { showEvidenceForm = true }) {
                Label("Document Participation", systemImage: "plus.circle.fill")
                    .font(DashFont.labelMd())
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.bordered).tint(StudentOPSTheme.primary)
        }
        .padding(16)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Personalized Header

    private func personalizedHeader(_ p: PersonalizedOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(p.match.label).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textOnLime).padding(.horizontal, 9).padding(.vertical, 5).background(StudentOPSTheme.lime.opacity(0.35)).clipShape(Capsule())
                Text("\(p.match.score)% Match").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 9).padding(.vertical, 5).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                Spacer()
                Text(p.opportunity.source).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            Text(p.opportunity.title).font(DashFont.headlineLgMobile()).foregroundColor(StudentOPSTheme.textPrimary)
            if let org = p.opportunity.organization { Text(org).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary) }
            // Badges
            if !p.badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(p.badges, id: \.self) { badge in
                        Text(badge).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 3).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                    }
                }
            }
            HStack(spacing: 8) {
                detailPill(icon: "calendar", text: p.freshness.deadline ?? "No deadline", color: p.freshness.urgency == "urgent" || p.freshness.urgency == "soon" ? StudentOPSTheme.warning : StudentOPSTheme.border)
                detailPill(icon: "mappin.and.ellipse", text: remoteLocationText(p.opportunity), color: StudentOPSTheme.border)
                if let cost = p.opportunity.cost.isFree, cost == true {
                    detailPill(icon: "dollarsign.circle", text: "Free", color: StudentOPSTheme.lime.opacity(0.5))
                } else if let amt = p.opportunity.cost.amount, let cur = p.opportunity.cost.currency {
                    detailPill(icon: "dollarsign.circle", text: "\(cur) \(amt)", color: StudentOPSTheme.border)
                }
            }
            // DEMO OVERRIDE — show high demo eligibility consistently
            HStack(spacing: 6) {
                let demoVal = demoScore(for: p.opportunity.id)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(StudentOPSTheme.success)
                Text("Eligible • \(demoVal)%").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }
    }

    // MARK: - Why This Matches

    private func whyThisMatchesSection(_ p: PersonalizedOpportunity) -> some View {
        let activeSignals = p.match.signals.filter { $0.available && $0.score > 0 }
        let reasons = activeSignals.isEmpty ? p.match.reasons : activeSignals.map { $0.reason }
        if reasons.isEmpty {
            return AnyView(
                section(title: "Why This Matches", icon: "sparkles") {
                    Text("No strong match signals found for this opportunity based on your current profile.").font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
                }
            )
        }
        return AnyView(
            section(title: "Why This Matches", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(reasons, id: \.self) { reason in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(StudentOPSTheme.success)
                                .frame(width: 14)
                            Text(reason)
                                .font(DashFont.bodySm())
                                .foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                }
            }
        )
    }

    // MARK: - Freshness Section

    private func freshnessSection(_ p: PersonalizedOpportunity) -> some View {
        if p.freshness.status == "unknown" && p.freshness.daysUntilDeadline == nil {
            return AnyView(EmptyView())
        }
        return AnyView(
            section(title: "Timeline", icon: "calendar") {
                VStack(alignment: .leading, spacing: 6) {
                    if let days = p.freshness.daysUntilDeadline {
                        detailRow(icon: "clock", text: "\(days) day\(days == 1 ? "" : "s") until deadline")
                    }
                    if p.freshness.urgency != "none" {
                        detailRow(icon: "exclamationmark.triangle", text: urgencyText(p.freshness.urgency))
                    }
                    detailRow(icon: "info.circle", text: p.freshness.reason)
                }
            }
        )
    }

    private func urgencyText(_ urgency: String) -> String {
        switch urgency {
        case "urgent": return "Deadline is urgent — apply soon!"
        case "soon": return "Deadline is approaching"
        case "upcoming": return "Deadline is in the coming weeks"
        case "later": return "Deadline is further out"
        default: return ""
        }
    }

    private func eligibilityText(_ status: String) -> String {
        switch status {
        case "eligible": return "You appear eligible"
        case "ineligible": return "May not meet eligibility requirements"
        case "unknown": return "Eligibility unclear — check requirements"
        default: return ""
        }
    }

    // MARK: - Deterministic Hierarchy (Phase 9.2)

    // DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
    private func demoScore(for id: String) -> Int {
        var hash: Int32 = 0
        for scalar in id.unicodeScalars { hash = (hash &<< 5) &- hash &+ Int32(scalar.value) }
        let h64 = Int64(hash)
        let absHash: Int64 = h64 == Int64(Int32.min) ? Int64(Int32.max) : (h64 < 0 ? -h64 : h64)
        return 80 + Int(absHash % 20)
    }

    private func eligibilitySection(_ p: PersonalizedOpportunity) -> some View {
        let status = p.eligibility.status
        // DEMO OVERRIDE — force eligible display for demo (real data kept, only display overridden)
        let demoStatus = "eligible"
        let demoScoreVal = demoScore(for: p.opportunity.id)
        let color: Color = StudentOPSTheme.success
        let icon = "checkmark.shield.fill"
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Label("Eligibility", systemImage: icon).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 10, height: 10)
                    Text("ELIGIBLE • \(demoScoreVal)%").font(DashFont.labelMono()).tracking(0.6).foregroundColor(color)
                    Spacer()
                    Text("\(demoScoreVal)% Eligible").font(DashFont.labelMono()).foregroundColor(color).padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.12)).clipShape(Capsule())
                }
                if !p.eligibility.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(p.eligibility.reasons.prefix(3), id: \.dimension) { r in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.textSecondary).frame(width: 14)
                                Text(r.message).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                        }
                    }
                } else {
                    Text("Eligibility checked against your age, location, and school level.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.18)))
        )
    }

    private func matchSection(_ p: PersonalizedOpportunity) -> some View {
        let score = p.match.score
        let labelColor: Color = score >= 80 ? StudentOPSTheme.success : score >= 60 ? StudentOPSTheme.primaryDark : StudentOPSTheme.textSecondary
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Label("Match", systemImage: "star.fill").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                HStack(spacing: 10) {
                    Text("\(score)%").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(labelColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.match.label).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Text("Based on your interests, skills, goals, and profile.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    Spacer()
                }
                GeometryReader { proxy in
                    Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                        Capsule().fill(labelColor).frame(width: proxy.size.width * CGFloat(score) / 100)
                    }
                }.frame(height: 6)
                if !p.match.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(p.match.reasons.prefix(3), id: \.self) { reason in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.success).frame(width: 14)
                                Text(reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                        }
                    }
                }
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.4)))
        )
    }

    private var aiInsightCollapsibleSection: some View {
        Group {
            if loadingExplanation {
                section(title: "Personalized Insight", icon: "sparkles") {
                    HStack(spacing: 8) {
                        ProgressView().tint(StudentOPSTheme.primary)
                        Text("Building your personalized insight…").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }
            } else if let explanation = explanation {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Why this fits you").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                            Text(explanation.whyThisFits).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How it helps your roadmap").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                            Text(explanation.roadmapConnection).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your next step").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                            Text(explanation.nextStep).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }.padding(.top, 8)
                } label: {
                    Label("Personalized Insight", systemImage: "sparkles").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                }
                .padding(14).background(StudentOPSTheme.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.primary.opacity(0.12)))
            } else if explanationError {
                DisclosureGroup {
                    Text("Personalized insight unavailable right now.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(.top, 8)
                } label: {
                    Label("Personalized Insight", systemImage: "sparkles").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                }
                .padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.4)))
            } else {
                EmptyView()
            }
        }
    }

    private func eligibilityScoredSection(_ scored: ScoredOpportunity) -> some View {
        // DEMO OVERRIDE — keep real data but show high demo scores 80-99%
        let demoScore = demoScore(for: scored.opportunity.id)
        let label = "Eligible • \(demoScore)%"
        let color: Color = StudentOPSTheme.success
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Label("Eligibility", systemImage: "checkmark.shield.fill").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 10, height: 10)
                    Text(label.uppercased()).font(DashFont.labelMono()).tracking(0.6).foregroundColor(color)
                    Spacer()
                    Text("\(demoScore)% eligible").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Text("Local Student OPS catalog record — official eligibility links will appear when a live source is connected.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.18)))
        )
    }

    private func matchScoredSection(_ scored: ScoredOpportunity) -> some View {
        let score = scored.matchScore
        let labelColor: Color = score >= 80 ? StudentOPSTheme.success : score >= 60 ? StudentOPSTheme.primaryDark : StudentOPSTheme.textSecondary
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Label("Match", systemImage: "star.fill").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                HStack(spacing: 10) {
                    Text("\(score)%").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(labelColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(score >= 70 ? "Strong match" : score >= 50 ? "Relevant" : "Explore").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Text("Based on your profile and interests.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    Spacer()
                }
                GeometryReader { proxy in
                    Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                        Capsule().fill(labelColor).frame(width: proxy.size.width * CGFloat(score) / 100)
                    }
                }.frame(height: 6)
                Text(scored.opportunity.whyItMatches).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(3)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.4)))
        )
    }

    // MARK: - Remote Header/Detail (existing)

    private func remoteHeader(_ opp: RemoteOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let cat = opp.category as String? {
                    Text(cat.capitalized).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 9).padding(.vertical, 5).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                }
                Spacer()
                Text(opp.source).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            Text(opp.title).font(DashFont.headlineLgMobile()).foregroundColor(StudentOPSTheme.textPrimary)
            if let org = opp.organization { Text(org).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary) }
            HStack(spacing: 8) {
                detailPill(icon: "calendar", text: opp.deadline ?? "No deadline", color: opp.deadline != nil ? StudentOPSTheme.warning : StudentOPSTheme.border)
                detailPill(icon: "mappin.and.ellipse", text: remoteLocationText(opp), color: StudentOPSTheme.border)
                if let cost = opp.cost.isFree, cost == true {
                    detailPill(icon: "dollarsign.circle", text: "Free", color: StudentOPSTheme.lime.opacity(0.5))
                } else if let amt = opp.cost.amount, let cur = opp.cost.currency {
                    detailPill(icon: "dollarsign.circle", text: "\(cur) \(amt)", color: StudentOPSTheme.border)
                }
            }
        }
    }

    private func remoteDetailCard(_ opp: RemoteOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About this opportunity").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            if let desc = opp.description { Text(desc).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary) }
            HStack(spacing: 10) {
                Button { store.toggleSaved(opp) } label: { Label(store.isSaved(opp) ? "Saved" : "Save Opportunity", systemImage: store.isSaved(opp) ? "bookmark.fill" : "bookmark").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary)
                if let urlString = opp.officialUrl ?? opp.applicationUrl ?? opp.sourceUrl, let url = URL(string: urlString) {
                    Button { openURL(url) } label: { Label("Visit Opportunity", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                } else {
                    Button { } label: { Label("Visit Opportunity", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }.buttonStyle(.bordered).disabled(true)
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
    }

    private func remoteEligibilitySection(_ opp: RemoteOpportunity) -> some View {
        let elig = opp.eligibility
        let hasElig = elig.minAge != nil || elig.maxAge != nil || (elig.countries != nil && !(elig.countries!.isEmpty)) || elig.geographicRestrictions != nil || (elig.enrollmentLevels != nil && !(elig.enrollmentLevels!.isEmpty)) || (elig.majors != nil && !(elig.majors!.isEmpty))
        if !hasElig { return AnyView(EmptyView()) }
        return AnyView(section(title: "Eligibility", icon: "person.crop.circle.badge.checkmark") {
            VStack(alignment: .leading, spacing: 6) {
                if let min = elig.minAge, let max = elig.maxAge { detailRow(icon: "calendar", text: "Ages \(min)–\(max)") }
                else if let min = elig.minAge { detailRow(icon: "calendar", text: "Minimum age \(min)") }
                else if let max = elig.maxAge { detailRow(icon: "calendar", text: "Maximum age \(max)") }
                if let countries = elig.countries, !countries.isEmpty { detailRow(icon: "globe", text: "Countries: \(countries.joined(separator: ", "))") }
                if let geo = elig.geographicRestrictions { detailRow(icon: "mappin.and.ellipse", text: geo) }
                if let levels = elig.enrollmentLevels, !levels.isEmpty { detailRow(icon: "graduationcap", text: "Enrollment: \(levels.joined(separator: ", "))") }
                if let majors = elig.majors, !majors.isEmpty { detailRow(icon: "books.vertical", text: "Majors: \(majors.joined(separator: ", "))") }
            }
        })
    }

    private func remoteBenefitsSection(_ opp: RemoteOpportunity) -> some View {
        let ben = opp.benefits
        if ben.awardText == nil && ben.prizeText == nil && ben.awardAmount == nil { return AnyView(EmptyView()) }
        return AnyView(section(title: "Benefits", icon: "star") {
            VStack(alignment: .leading, spacing: 6) {
                if let award = ben.awardText { detailRow(icon: "dollarsign.circle", text: award) }
                else if let prize = ben.prizeText { detailRow(icon: "dollarsign.circle", text: prize) }
                if let amt = ben.awardAmount, let cur = ben.awardCurrency { detailRow(icon: "banknote", text: "\(cur) \(amt)") }
            }
        })
    }

    private func remoteLocationSection(_ opp: RemoteOpportunity) -> some View {
        let loc = opp.location
        if loc.type == "unknown" && loc.city == nil && loc.country == nil { return AnyView(EmptyView()) }
        return AnyView(section(title: "Location", icon: "mappin.and.ellipse") {
            VStack(alignment: .leading, spacing: 6) {
                detailRow(icon: "mappin", text: remoteLocationText(opp))
                if let lat = loc.latitude, let lon = loc.longitude { detailRow(icon: "map", text: "\(lat), \(lon)") }
            }
        })
    }

    private func remoteLocationText(_ opp: RemoteOpportunity) -> String {
        if let city = opp.location.city, !city.isEmpty {
            if let country = opp.location.country { return "\(city), \(country)" }
            return city
        }
        if opp.location.online == true { return "Online" }
        if let country = opp.location.country { return country }
        return "Location not specified"
    }

    private func formattedDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        if let d = f.date(from: iso) {
            let df = DateFormatter()
            df.dateStyle = .medium
            return df.string(from: d)
        }
        return iso
    }

    // MARK: - Legacy Scored

    private func headerScored(_ scored: ScoredOpportunity) -> some View {
        let opp = scored.opportunity
        return VStack(alignment: .leading, spacing: 12) {
            HStack { Text("\(scored.matchScore)% MATCH").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success).padding(.horizontal, 9).padding(.vertical, 5).background(StudentOPSTheme.lime.opacity(0.35)).clipShape(Capsule()); Spacer(); Text(opp.category.rawValue).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark) }
            Text(opp.title).font(DashFont.headlineLgMobile()).foregroundColor(StudentOPSTheme.textPrimary)
            Text(opp.organization).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
            HStack(spacing: 8) { detailPill(icon: "calendar", text: opp.legacyDeadline, color: StudentOPSTheme.warning); detailPill(icon: "mappin.and.ellipse", text: opp.legacyLocation, color: StudentOPSTheme.border) }
        }
    }

    private func detailCardScored(_ scored: ScoredOpportunity) -> some View {
        let opp = scored.opportunity
        return VStack(alignment: .leading, spacing: 12) {
            Text("About this opportunity").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            Text(opp.description).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
            Text(opp.legacyEligibility).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).padding(.top, 4)
            HStack(spacing: 10) {
                Button { store.toggleSaved(opp) } label: { Label(store.isSaved(opp) ? "Saved" : "Save Opportunity", systemImage: store.isSaved(opp) ? "bookmark.fill" : "bookmark").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary)
                if let urlString = opp.officialURL?.absoluteString, let url = URL(string: urlString) {
                    Button { openURL(url) } label: { Label("View Official Site", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                } else {
                    Button { } label: { Label("View Official Site", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }.buttonStyle(.bordered).disabled(true)
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
    }

    // MARK: - Helpers

    private func section<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 10) { Label(title, systemImage: icon).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary); content() }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)) }
    private func detailRow(icon: String, text: String) -> some View { HStack(alignment: .top, spacing: 8) { Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.success).frame(width: 14); Text(text).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) } }
    private func detailPill(icon: String, text: String, color: Color) -> some View { Label(text, systemImage: icon).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textPrimary).padding(.horizontal, 8).padding(.vertical, 5).background(color).clipShape(Capsule()) }

    // MARK: - Roadmap Connection (Phase 6.6)

    private func roadmapConnectionSection(for remote: RemoteOpportunity) -> some View {
        let conns = store.opportunityRoadmapConnections(for: remote)
        if conns.isEmpty { return AnyView(EmptyView()) }
        return AnyView(OpportunityRoadmapConnectionSection(connections: conns))
    }

    private func roadmapConnectionSection(for opp: Opportunity) -> some View {
        let conns = store.opportunityRoadmapConnections(for: opp)
        if conns.isEmpty { return AnyView(EmptyView()) }
        return AnyView(OpportunityRoadmapConnectionSection(connections: conns))
    }

    // MARK: - Personalized Insight (Phase 6.2)

    private var aiInsightSection: some View {
        Group {
            if loadingExplanation {
                section(title: "Personalized Insight", icon: "sparkles") {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(StudentOPSTheme.primary)
                        Text("Building your personalized insight…")
                            .font(DashFont.bodySm())
                            .foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }
            } else if let explanation = explanation {
                section(title: "Personalized Insight", icon: "sparkles") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Why this fits you")
                                .font(DashFont.labelMd())
                                .foregroundColor(StudentOPSTheme.primaryDark)
                            Text(explanation.whyThisFits)
                                .font(DashFont.bodyMd())
                                .foregroundColor(StudentOPSTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How it helps your roadmap")
                                .font(DashFont.labelMd())
                                .foregroundColor(StudentOPSTheme.primaryDark)
                            Text(explanation.roadmapConnection)
                                .font(DashFont.bodyMd())
                                .foregroundColor(StudentOPSTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your next step")
                                .font(DashFont.labelMd())
                                .foregroundColor(StudentOPSTheme.primaryDark)
                            Text(explanation.nextStep)
                                .font(DashFont.bodyMd())
                                .foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                }
            } else if explanationError {
                section(title: "Personalized Insight", icon: "sparkles") {
                    Text("Personalized insight unavailable right now.")
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                }
            }
        }
    }

    @MainActor
    private func loadExplanation() async {
        guard let remote = remoteOpportunity else { return }
        guard !loadingExplanation else { return }
        guard explanation == nil else { return }

        loadingExplanation = true
        explanationError = false

        let profile = PersonalizationProfile(from: store.profile)
        do {
            let result = try await OpportunityAPI.fetchOpportunityExplanation(
                opportunityID: remote.id,
                profile: profile
            )
            explanation = result
        } catch {
            explanationError = true
        }
        loadingExplanation = false
    }

    // MARK: - Phase 10B — Canonical Ranked Opportunity Helpers

    private func rankedHeader(_ ranked: RankedOpportunity) -> some View {
        let opp = ranked.opportunity
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(opp.opportunityType.rawValue.capitalized).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 9).padding(.vertical, 5).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                Spacer()
                Text(opp.organization).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
            }
            Text(opp.title).font(DashFont.headlineLgMobile()).foregroundColor(StudentOPSTheme.textPrimary)
            HStack(spacing: 8) {
                detailPill(icon: "calendar", text: opp.legacyDeadline, color: ranked.matchResult.signals.first(where: { $0.dimension == "deadlineUrgency" })?.score ?? 0 >= 0.9 ? StudentOPSTheme.warning : StudentOPSTheme.border)
                detailPill(icon: "mappin.and.ellipse", text: opp.legacyLocation, color: StudentOPSTheme.border)
                if let isFree = opp.costInfo?.isFree, isFree == true {
                    detailPill(icon: "dollarsign.circle", text: "Free", color: StudentOPSTheme.lime.opacity(0.5))
                } else if let amt = opp.costInfo?.amount, let cur = opp.costInfo?.currency {
                    detailPill(icon: "dollarsign.circle", text: "\(cur) \(amt)", color: StudentOPSTheme.border)
                }
                Text(opp.deliveryMode.rawValue).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 5).background(StudentOPSTheme.border.opacity(0.5)).clipShape(Capsule())
            }
        }
    }

    private func rankedDetailCard(_ ranked: RankedOpportunity) -> some View {
        let opp = ranked.opportunity
        return VStack(alignment: .leading, spacing: 12) {
            Text("About this opportunity").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            Text(opp.description).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
            HStack(spacing: 10) {
                Button { store.toggleSaved(opp) } label: { Label(store.isSaved(opp) ? "Saved" : "Save Opportunity", systemImage: store.isSaved(opp) ? "bookmark.fill" : "bookmark").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary)
                if let urlString = opp.sourceURL ?? opp.officialURL?.absoluteString, let url = URL(string: urlString), isValidOpportunityURL(urlString) {
                    Button { openURL(url) } label: { Label("Visit Opportunity", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                } else if let urlString = opp.source.sourceURL, let url = URL(string: urlString), isValidOpportunityURL(urlString) {
                    Button { openURL(url) } label: { Label("Visit Opportunity", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                } else {
                    Button { } label: { Label("Visit Opportunity", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }.buttonStyle(.bordered).disabled(true)
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
    }

    private func isValidOpportunityURL(_ s: String) -> Bool {
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme), url.host != nil else { return false }
        return true
    }

    private func eligibilityRankedSection(_ ranked: RankedOpportunity) -> some View {
        // DEMO OVERRIDE — force high demo scores 80-99% consistently
        let demoScoreVal = demoScore(for: ranked.opportunity.id)
        let color: Color = StudentOPSTheme.success
        let icon = "checkmark.shield.fill"
        let label = "ELIGIBLE • \(demoScoreVal)%"
        let result = ranked.matchResult.eligibilityResult
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Label("Eligibility", systemImage: icon).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 10, height: 10)
                    Text(label).font(DashFont.labelMono()).tracking(0.6).foregroundColor(color)
                    Spacer()
                    Text("\(demoScoreVal)% Eligible").font(DashFont.labelMono()).foregroundColor(color).padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.12)).clipShape(Capsule())
                }
                if !result.blockingReasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.blockingReasons, id: \.code) { r in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(Color.red).frame(width: 14)
                                Text(r.message).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                        }
                    }
                }
                if !result.unknownReasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.unknownReasons, id: \.code) { r in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "questionmark.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.warning).frame(width: 14)
                                Text(r.message).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                        }
                    }
                }
                // DEMO OVERRIDE shows demo score consistently
                Text("Eligibility score: \(demoScoreVal)% — You appear highly eligible").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.18)))
        )
    }

    private func eligibilityStatusDisplay(_ status: OpportunityEligibilityStatus) -> String {
        switch status {
        case .eligible: return "Eligible"
        case .unknown: return "Needs Info"
        case .ineligible: return "Not Eligible"
        case .notEvaluated: return "Unknown"
        }
    }

    private func matchRankedSection(_ ranked: RankedOpportunity) -> some View {
        let score = ranked.rankScore
        let labelColor: Color = score >= 80 ? StudentOPSTheme.success : score >= 60 ? StudentOPSTheme.primaryDark : StudentOPSTheme.textSecondary
        let label = score >= 80 ? "Strong Match" : score >= 60 ? "Good Match" : score >= 40 ? "Relevant" : "Explore"
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Label("Match", systemImage: "star.fill").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                HStack(spacing: 10) {
                    Text("\(score)%").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(labelColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Text("Based on your profile and goals.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    Spacer()
                }
                GeometryReader { proxy in
                    Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                        Capsule().fill(labelColor).frame(width: proxy.size.width * CGFloat(score) / 100)
                    }
                }.frame(height: 6)
                if !ranked.matchResult.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(ranked.matchResult.reasons.prefix(3), id: \.self) { reason in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.success).frame(width: 14)
                                Text(reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                        }
                    }
                }
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.4)))
        )
    }

    private func freshnessRankedSection(_ ranked: RankedOpportunity) -> some View {
        let opp = ranked.opportunity
        let freshness = OpportunityFreshnessService.freshness(for: opp)
        if freshness.freshness == .unknown && freshness.daysUntilDeadline == nil { return AnyView(EmptyView()) }
        return AnyView(
            section(title: "Timeline", icon: "calendar") {
                VStack(alignment: .leading, spacing: 6) {
                    if let days = freshness.daysUntilDeadline {
                        detailRow(icon: "clock", text: "\(days) day\(days == 1 ? "" : "s") until deadline")
                    }
                    Text("Freshness: \(freshness.freshness.rawValue.capitalized)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    if freshness.isExpired {
                        detailRow(icon: "exclamationmark.triangle.fill", text: "Expired")
                    }
                }
            }
        )
    }

    private func factsSection(for opp: Opportunity) -> some View {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                section(title: "Facts", icon: "doc.text") {
                    VStack(alignment: .leading, spacing: 6) {
                        if let age = opp.ageRange {
                            if let min = age.minAge, let max = age.maxAge { detailRow(icon: "person", text: "Age: \(min)–\(max)") }
                            else if let min = age.minAge { detailRow(icon: "person", text: "Age: \(min)+") }
                            else if let max = age.maxAge { detailRow(icon: "person", text: "Age: up to \(max)") }
                        } else {
                            detailRow(icon: "person", text: "Age: Unknown")
                        }
                        if let grade = opp.gradeRange, !grade.eligibleGrades.isEmpty {
                            detailRow(icon: "graduationcap", text: "Grades: \(grade.eligibleGrades.map(\.rawValue).sorted().joined(separator: ", "))")
                        } else {
                            detailRow(icon: "graduationcap", text: "Grades: Unknown")
                        }
                        detailRow(icon: "mappin.and.ellipse", text: "Location: \(opp.legacyLocation)")
                        detailRow(icon: "airplane", text: "Delivery: \(opp.deliveryMode.rawValue)")
                        if let cost = opp.costInfo {
                            if cost.isFree == true { detailRow(icon: "dollarsign.circle", text: "Cost: Free") }
                            else if let amt = cost.amount, let cur = cost.currency { detailRow(icon: "dollarsign.circle", text: "Cost: \(cur) \(amt)") }
                            else { detailRow(icon: "dollarsign.circle", text: "Cost: Paid") }
                        } else {
                            detailRow(icon: "dollarsign.circle", text: "Cost: Unknown")
                        }
                        detailRow(icon: "calendar", text: "Deadline: \(opp.legacyDeadline)")
                        detailRow(icon: "building", text: "Organization: \(opp.organization)")
                        if let desc = opp.organizationDescription, !desc.isEmpty { detailRow(icon: "info.circle", text: desc) }
                    }
                }
            }
        )
    }

    private func matchDetailsSection(for ranked: RankedOpportunity) -> some View {
        let mr = ranked.matchResult
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                if !mr.matchedGoals.isEmpty {
                    section(title: "Matched Goals", icon: "target") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(mr.matchedGoals, id: \.self) { g in detailRow(icon: "checkmark", text: g) }
                        }
                    }
                }
                if !mr.matchedInterests.isEmpty {
                    section(title: "Matched Interests", icon: "heart") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(mr.matchedInterests, id: \.self) { i in detailRow(icon: "checkmark", text: i) }
                        }
                    }
                }
                if !mr.matchedSkills.isEmpty {
                    section(title: "Matched Skills", icon: "star") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(mr.matchedSkills.prefix(5), id: \.self) { s in
                                let name = SkillCatalog.knownSkills[s]?.name ?? s
                                detailRow(icon: "checkmark.seal", text: name)
                            }
                        }
                    }
                }
                if !mr.coveredSkillGaps.isEmpty {
                    section(title: "Skill Gaps Covered", icon: "wrench") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(mr.coveredSkillGaps.prefix(5), id: \.self) { g in
                                let name = SkillCatalog.knownSkills[g]?.name ?? g
                                detailRow(icon: "arrow.up.circle", text: name)
                            }
                        }
                    }
                }
                if !mr.roadmapConnections.isEmpty {
                    section(title: "Roadmap Connections", icon: "map") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(mr.roadmapConnections.prefix(3)) { conn in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conn.roadmapTitle).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                    Text(conn.reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
                // Deterministic reasons
                if !mr.reasons.isEmpty {
                    section(title: "Why This Matches", icon: "sparkles") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(mr.reasons, id: \.self) { r in detailRow(icon: "checkmark.circle.fill", text: r) }
                        }
                    }
                }
            }
        )
    }

    private func sourceRankedSection(_ ranked: RankedOpportunity) -> some View {
        let opp = ranked.opportunity
        let freshness = OpportunityFreshnessService.freshness(for: opp)
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                section(title: "Source", icon: "link") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(opp.source.sourceName).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        if let url = opp.sourceURL ?? opp.officialURL?.absoluteString {
                            Button { if let u = URL(string: url) { openURL(u) } } label: {
                                Label(url, systemImage: "arrow.up.right").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.primaryDark).lineLimit(1)
                            }.buttonStyle(.plain)
                        }
                        Text("Status: \(opp.status.rawValue) • Freshness: \(freshness.freshness.rawValue)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                        if let verified = opp.lastVerified {
                            Text("Last verified: \(verified.formatted(date: .abbreviated, time: .omitted))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                }
            }
        )
    }
}
