import SwiftUI

struct CareerDetailView: View {
    let career: Career
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var selectedSkillID: String?

    private var alignment: CareerAlignmentResult {
        store.careerAlignment(for: career.id) ?? CareerIntelligenceEngine.alignment(career: career, profile: store.profile, store: store)
    }
    private var coverage: SkillCoverageReport { store.skillCoverage(careerID: career.id) }
    private var gaps: [SkillGapInsight] { store.skillGaps(careerID: career.id) }
    private var nextSkills: [NextSkillRecommendation] { store.nextSkills(careerID: career.id, limit: 5) }
    private var relatedOpportunities: [RankedOpportunity] {
        // Opportunities that develop career skills, ranked
        let careerSkills = Set(CareerSkillGraph.skills(for: career.id))
        let ranked = store.rankedOpportunities().filter { r in
            !Set(r.opportunity.skills.map { Skill.normalizeID($0) }).isDisjoint(with: careerSkills)
        }
        return Array(ranked.prefix(3))
    }
    private var relatedProjects: [ProjectRecommendation] {
        let recs = ProjectRecommendationEngine.recommendations(for: store, limit: 50)
        let careerSkills = Set(CareerSkillGraph.skills(for: career.id))
        return recs.filter { rec in
            !Set(rec.project.skills.map { Skill.normalizeID($0) }).isDisjoint(with: careerSkills)
        }.prefix(3).map { $0 }
    }
    private var roadmapConnections: [ScoredRoadmap] {
        let careerFields = Set(career.fields.map { Skill.normalizeID($0) })
        let careerSkills = Set(CareerSkillGraph.skills(for: career.id))
        return store.scoredRoadmaps.filter { scored in
            let req = Set(SkillGapEngine.requiredSkills(for: scored.roadmap).map(\.id))
            return !req.isDisjoint(with: careerSkills) || !Set(scored.roadmap.relevantFields.map { Skill.normalizeID($0) }).isDisjoint(with: careerFields)
        }.prefix(3).map { $0 }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: StudentOPSTheme.sectionSpacing) {
                overviewSection
                alignmentSection
                skillsSection
                // PRO 2 — Skill Gap Intelligence mapped for Career (detailed next skills via SkillIntelligenceEngine)
                PremiumFeatureGateWithPreview(feature: .skillGapIntelligence, previewTitle: "Next Skills Intelligence", previewSubtitle: "What to learn next for \(career.title)") {
                    nextSkillsSection
                }
                // Primary connections — keep visible but compact
                roadmapSection
                projectsSection
                opportunitiesSection
                // Skill map behind disclosure (secondary)
                DisclosureGroup {
                    skillGraphSection
                } label: {
                    Label("View skill map", systemImage: "point.3.connected.trianglepath.dotted").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }.tint(StudentOPSTheme.textSecondary)
                .padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.35)))
            }.padding(StudentOPSTheme.gutter)
        }
        .background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle(career.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedSkillID) { skillID in
            if let skill = SkillCatalog.knownSkills[skillID] {
                SkillDetailView(skill: skill).environmentObject(store)
            } else {
                SkillDetailView(skill: Skill(id: skillID, name: skillID)).environmentObject(store)
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(career.title).font(DashFont.heroTitle()).foregroundColor(StudentOPSTheme.textPrimary)
            Text(career.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(3)
            HStack(spacing: 8) {
                StatusPill(text: career.status == .catalog ? "Catalog data" : "Verified", color: StudentOPSTheme.primaryDark)
                if let url = career.sourceURL, let u = URL(string: url) {
                    Link(destination: u) { Label("Source", systemImage: "link").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark) }
                }
            }
            if !career.fields.isEmpty { sectionChipRow(title: "Fields", items: career.fields) }
            if !career.industries.isEmpty { sectionChipRow(title: "Industries", items: career.industries) }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusHero)).overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusHero).stroke(StudentOPSTheme.border.opacity(0.35)))
    }

    private func sectionChipRow(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                }
            }
        }
    }

    private var alignmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR CAREER FIT").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("\(alignment.score)% Match").font(DashFont.captionMono()).foregroundColor(alignment.score >= 70 ? StudentOPSTheme.success : StudentOPSTheme.primaryDark)
            }
            HStack(spacing: 12) {
                Text("\(alignment.score)%").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(alignment.score >= 70 ? StudentOPSTheme.success : alignment.score >= 40 ? StudentOPSTheme.primaryDark : StudentOPSTheme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alignment.score >= 70 ? "Strong fit" : alignment.score >= 40 ? "Moderate fit" : "Low fit").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text("Career fit").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
            }
            GeometryReader { proxy in
                Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                    Capsule().fill(alignment.score >= 70 ? StudentOPSTheme.success : StudentOPSTheme.primary).frame(width: proxy.size.width * CGFloat(alignment.score) / 100)
                }
            }.frame(height: 6).accessibilityLabel(Text("\(alignment.score) percent career alignment"))
            if alignment.isInsufficientContext {
                Text("Add career goals, interests, and skills to improve matching").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.warning).padding(8).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if !alignment.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(alignment.reasons, id: \.self) { r in
                        HStack(alignment: .top, spacing: 6) { Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.success).frame(width: 14, height: 14); Text(r).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                }
            }
            if !alignment.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(alignment.warnings, id: \.self) { w in Text(w).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) { Text("\(alignment.matchedGoals.count) goals").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark); Text("Matched").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                VStack(alignment: .leading, spacing: 2) { Text("\(alignment.matchedSkills.count) skills").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success); Text("Matched").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                VStack(alignment: .leading, spacing: 2) { Text("\(alignment.missingSkills.count) to develop").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning); Text("Missing").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                Spacer()
            }.padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
            if !alignment.matchedGoals.isEmpty {
                Text("Matched goals: \(alignment.matchedGoals.joined(separator: ", "))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            if !alignment.matchedFields.isEmpty {
                Text("Matched fields: \(alignment.matchedFields.joined(separator: ", "))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    // MARK: - Skills

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SKILLS", systemImage: "wrench.and.screwdriver").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) { Text("\(coverage.coveredCount)").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.success); Text("Current").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                VStack(alignment: .leading, spacing: 2) { Text("\(coverage.missingSkills.count)").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.warning); Text("To develop").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                Spacer()
                Text("\(Int(coverage.coverage * 100))% coverage").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
            }
            if !coverage.coveredSkills.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CURRENT SKILLS").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    FlowLayout(spacing: 6) {
                        ForEach(coverage.coveredSkills, id: \.self) { sid in
                            let name = SkillCatalog.knownSkills[sid]?.name ?? sid
                            Button { selectedSkillID = sid } label: { Label(name, systemImage: "checkmark.circle.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.success).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.success.opacity(0.1)).clipShape(Capsule()) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            if !coverage.missingSkills.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SKILLS TO DEVELOP").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    FlowLayout(spacing: 6) {
                        ForEach(coverage.missingSkills, id: \.self) { sid in
                            let name = SkillCatalog.knownSkills[sid]?.name ?? sid
                            Button { selectedSkillID = sid } label: { Text(name).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.warning.opacity(0.1)).clipShape(Capsule()) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    // MARK: - Next Skills

    private var nextSkillsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("NEXT SKILLS", systemImage: "arrow.up.circle").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            Text("Deterministic prioritization via SkillIntelligenceEngine").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            ForEach(nextSkills, id: \.skillID) { rec in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(rec.skillName).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Spacer()
                        if rec.hasPrerequisiteMissing {
                            Label("Prerequisite needed", systemImage: "exclamationmark.triangle.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
                        } else {
                            Text("Score \(rec.score)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                        }
                    }
                    ForEach(rec.reasons, id: \.self) { r in
                        HStack(alignment: .top, spacing: 6) { Image(systemName: "arrow.right.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.primaryDark).frame(width: 14, height: 14); Text(r).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                    if !rec.prerequisites.isEmpty {
                        Text("Prerequisites: \(rec.prerequisites.joined(separator: ", "))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }.padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
                    .onTapGesture { selectedSkillID = rec.skillID }
            }
            if nextSkills.isEmpty {
                Text("No next skills — add a career or complete roadmaps to see recommendations.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    // MARK: - Skill Graph

    private var skillGraphSection: some View {
        let rels = CareerSkillGraph.relationships(for: career.id)
        return VStack(alignment: .leading, spacing: 10) {
            Label("CAREER ↔ SKILL GRAPH — FACTS", systemImage: "point.3.connected.trianglepath.dotted").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            ForEach(CareerSkillRelationshipType.allCases, id: \.self) { type in
                let subset = rels.filter { $0.relationshipType == type }
                if !subset.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(type.displayName) (\(subset.count))").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        FlowLayout(spacing: 6) {
                            ForEach(subset, id: \.skillID) { rel in
                                let name = SkillCatalog.knownSkills[rel.skillID]?.name ?? rel.skillID
                                Button { selectedSkillID = rel.skillID } label: { Text(name).font(DashFont.labelMd()).foregroundColor(type == .foundational ? StudentOPSTheme.primaryDark : StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4).background(type == .core ? StudentOPSTheme.primary.opacity(0.1) : StudentOPSTheme.background).clipShape(Capsule()).overlay(Capsule().stroke(StudentOPSTheme.border.opacity(0.4))) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    // MARK: - Roadmap / Project / Opportunity

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ROADMAP CONNECTION", systemImage: "map").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            if roadmapConnections.isEmpty {
                Text("No active roadmap directly targets \(career.title). Explore roadmaps to find a path.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                ForEach(roadmapConnections.prefix(3), id: \.id) { rm in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rm.roadmap.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                        Text(rm.roadmap.goal).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                    }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("PROJECT CONNECTIONS", systemImage: "hammer").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            if relatedProjects.isEmpty {
                Text("No projects yet demonstrate skills for \(career.title). Try a project idea from Projects.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                ForEach(relatedProjects.prefix(3), id: \.id) { rec in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.project.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        if let reason = rec.reasons.first { Text(reason.message).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2) }
                    }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var opportunitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("OPPORTUNITY CONNECTIONS", systemImage: "star").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            if relatedOpportunities.isEmpty {
                Text("No ranked opportunities currently connect to \(career.title). Check Explore for opportunities that develop its skills.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                ForEach(relatedOpportunities.prefix(3)) { ranked in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ranked.opportunity.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Text("\(ranked.rankScore)% match • \(ranked.eligibilityLabel)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            Text("Eligibility is verified separately via OpportunityEligibilityEngine.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }
}
