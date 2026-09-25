import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    @EnvironmentObject var store: AppDataStore
    @State private var selectedCareerID: String?

    private var isDemonstrated: Bool {
        let all = Set(store.profile.strengths + store.profile.customSkills).map { Skill.normalizeID($0) }
        let demo = SkillGapEngine.demonstratedSkillIDs(profile: store.profile, roadmapProgress: store.roadmapProgress, catalog: RoadmapService.allRoadmaps, evidenceRecords: store.evidenceRecords)
        return all.contains(skill.id) || demo.contains(skill.id)
    }
    private var isGap: Bool {
        // Check if skill is in any active gap or missing career skill
        let gaps = SkillIntelligenceEngine.gaps(profile: store.profile, store: store)
        return gaps.contains(where: { $0.skillID == skill.id })
    }
    private var relatedCareers: [Career] {
        let ids = CareerSkillGraph.careerIDs(for: skill.id)
        return ids.compactMap { CareerCatalog.career(for: $0) }
    }
    private var roadmapConnections: [(roadmap: Roadmap, milestone: RoadmapMilestone)] {
        var out: [(Roadmap, RoadmapMilestone)] = []
        for rm in RoadmapService.allRoadmaps {
            for ms in rm.milestones where ms.skillsDeveloped?.map({ Skill.normalizeID($0) }).contains(skill.id) ?? false {
                out.append((rm, ms))
            }
        }
        return out
    }
    private var projectConnections: [Project] {
        store.customProjects.filter { proj in
            Set(proj.skills.map { Skill.normalizeID($0) }).contains(skill.id)
        }
    }
    private var opportunityConnections: [RankedOpportunity] {
        let ranked = store.rankedOpportunities()
        return ranked.filter { r in
            Set(r.opportunity.skills.map { Skill.normalizeID($0) }).contains(skill.id)
        }.prefix(3).map { $0 }
    }
    private var evidenceConnection: EvidenceRecord? {
        store.evidenceRecords.values.first(where: { $0.skillIDs?.contains(skill.id) ?? false })
    }
    private var portfolioConnection: Bool {
        store.allPortfoliosSorted.contains(where: { $0.selectedSkillIDs.contains(skill.id) })
    }
    private var nextAction: String? {
        SkillIntelligenceEngine.nextSkills(profile: store.profile, store: store).first(where: { $0.skillID == skill.id })?.reasons.first
    }

    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var selectedRoadmap: ScoredRoadmap?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: StudentOPSTheme.sectionSpacing) {
                header
                statusSection
                // Phase 5: Prominent Skill → Roadmap connection (not hidden in disclosure)
                if let primaryRoadmap = roadmapConnections.first,
                   let scored = store.scoredRoadmaps.first(where: { $0.id == primaryRoadmap.roadmap.id }) {
                    Button {
                        selectedRoadmap = scored
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(StudentOPSTheme.primary.opacity(0.12)).frame(width: 36, height: 36).overlay(Image(systemName: "point.3.connected.trianglepath.dotted").foregroundColor(StudentOPSTheme.primary))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Part of your \(primaryRoadmap.roadmap.title)").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                Text(primaryRoadmap.milestone.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                        .padding(12)
                        .background(StudentOPSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.35)))
                    }.buttonStyle(.plain)
                    .sheet(item: $selectedRoadmap) { scored in
                        NavigationStack { RoadmapDetailView(scoredRoadmap: scored).environmentObject(store).environmentObject(revenueCatManager) }
                    }
                }
                // PRO 2 — Skill Gap Intelligence: detailed gap, prerequisites, what next, career/roadmap relevance
                PremiumFeatureGateWithPreview(feature: .skillGapIntelligence, previewTitle: "Skill Gap Intelligence", previewSubtitle: "\(skill.name) • Why it matters and what to learn next") {
                    nextActionSection
                }
                // Related connections collapsed under single disclosure (per spec)
                DisclosureGroup {
                    VStack(spacing: 12) {
                        careerConnectionsSection
                        roadmapSection
                        projectSection
                        opportunitySection
                        evidencePortfolioSection
                    }
                } label: {
                    Label("RELATED", systemImage: "link").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                }.tint(StudentOPSTheme.textSecondary)
                .padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.35)))
            }.padding(StudentOPSTheme.gutter)
        }
        .background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCareerID) { id in
            if let c = CareerCatalog.career(for: id) {
                CareerDetailView(career: c).environmentObject(store).environmentObject(revenueCatManager)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(skill.name).font(DashFont.headlineLgMobile()).foregroundColor(StudentOPSTheme.textPrimary)
            if let cat = skill.category { Text(cat).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule()) }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("YOUR STATUS", systemImage: "person.crop.circle.badge.checkmark").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            HStack(spacing: 8) {
                if isDemonstrated {
                    Label("Demonstrated", systemImage: "checkmark.seal.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.success).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.success.opacity(0.12)).clipShape(Capsule())
                } else if isGap {
                    Label("Skill gap", systemImage: "exclamationmark.triangle.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.warning.opacity(0.12)).clipShape(Capsule())
                } else {
                    Label("Not yet demonstrated", systemImage: "circle").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.border.opacity(0.3)).clipShape(Capsule())
                }
                Spacer()
            }
            if isDemonstrated, let ev = evidenceConnection {
                Text("Demonstrated in \(ev.title)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else if isGap {
                Text("\"\(skill.name) is a current gap because it is relevant to your selected career and not present in your skill set.\"").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var careerConnectionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("CAREER CONNECTIONS", systemImage: "briefcase").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            if relatedCareers.isEmpty {
                Text("No catalog career directly lists \(skill.name). It may still be relevant via related skills.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                ForEach(relatedCareers, id: \.id) { career in
                    let rel = CareerSkillGraph.relationships(for: career.id).first(where: { $0.skillID == skill.id })
                    Button { selectedCareerID = career.id } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(career.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                if let r = rel { Text(r.relationshipType.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                        }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ROADMAP CONNECTIONS", systemImage: "map").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            if roadmapConnections.isEmpty {
                Text("No roadmap milestone directly develops \(skill.name).").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                ForEach(roadmapConnections.prefix(3), id: \.milestone.id) { pair in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.roadmap.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                        Text(pair.milestone.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("PROJECT CONNECTIONS", systemImage: "hammer").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            if projectConnections.isEmpty {
                Text("No project yet demonstrates \(skill.name). Build a project that uses this skill.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                ForEach(projectConnections.prefix(3), id: \.id) { proj in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(proj.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Text(proj.skills.joined(separator: ", ")).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                    }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var opportunitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("OPPORTUNITY CONNECTIONS", systemImage: "star").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            if opportunityConnections.isEmpty {
                Text("No ranked opportunity currently develops \(skill.name).").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                ForEach(opportunityConnections, id: \.id) { ranked in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ranked.opportunity.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Text("\(ranked.rankScore)% match • \(ranked.eligibilityLabel)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            Text("Opportunity eligibility remains separate from skill relevance.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var evidencePortfolioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("EVIDENCE & PORTFOLIO", systemImage: "doc.badge.ellipsis").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            if let ev = evidenceConnection {
                HStack(spacing: 6) { Image(systemName: "checkmark.seal.fill").foregroundColor(StudentOPSTheme.success); Text("Demonstrated in \(ev.title)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
            } else {
                Text("No evidence yet demonstrates \(skill.name). Completing a project can create evidence.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            if portfolioConnection {
                Text("This skill supports your career portfolio.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.success)
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var nextActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("WHAT NEXT", systemImage: "arrow.up.circle").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            if let action = nextAction {
                Text(action).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else if isGap {
                Text("Develop \(skill.name) via a project, roadmap milestone, or opportunity that explicitly lists this skill.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else if isDemonstrated {
                Text("\(skill.name) is already demonstrated. Choose a next gap to focus on.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                Text("Add \(skill.name) to a project or roadmap to make progress.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            let prereqs = CareerSkillGraph.prerequisites(for: skill.id)
            if !prereqs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prerequisites:").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    ForEach(prereqs, id: \.self) { pre in
                        let done = SkillIntelligenceEngine.coverage(profile: store.profile, store: store).coveredSkills.contains(pre)
                        HStack(spacing: 6) { Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundColor(done ? StudentOPSTheme.success : StudentOPSTheme.warning); Text(SkillCatalog.knownSkills[pre]?.name ?? pre).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                    if prereqs.contains(where: { !SkillIntelligenceEngine.coverage(profile: store.profile, store: store).coveredSkills.contains($0) }) {
                        Text("Complete prerequisites before this advanced skill.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.warning)
                    }
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }
}

extension String: Identifiable { public var id: String { self } }
