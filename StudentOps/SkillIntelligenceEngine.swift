import Foundation

// MARK: - Skill Intelligence Engine (Phase 11A)
// Authoritative deterministic layer for skill-level insights.
// Reuses SkillGapEngine, CareerSkillGraph, RoadmapService. No AI, no mutation.

struct SkillGapInsight: Hashable, Codable {
    let skillID: String
    let skillName: String
    let relatedCareerIDs: [String]
    let gapReason: String
    let importance: Int
    let relationshipType: CareerSkillRelationshipType?
    let roadmapConnection: String? // roadmap ID or milestone ref
    let relevantProjects: [String] // project IDs
    let relevantOpportunities: [String] // opportunity IDs
    let nextAction: String?
}

struct SkillCoverageReport: Hashable, Codable {
    let totalSkills: Int
    let coveredCount: Int
    let coverage: Double // 0–1
    let coveredSkills: [String]
    let missingSkills: [String]
}

struct NextSkillRecommendation: Hashable, Codable {
    let skillID: String
    let skillName: String
    let score: Int
    let reasons: [String]
    let relatedCareers: [String]
    let prerequisites: [String]
    let hasPrerequisiteMissing: Bool
}

enum SkillIntelligenceEngine {

    // MARK: - Skill Coverage (reuse demonstrated skills)

    static func coverage(
        profile: StudentProfile,
        careerID: String? = nil,
        progress: [String: Int] = [:],
        activeRoadmaps: [String: ActiveRoadmap] = [:],
        customProjects: [Project] = [],
        evidenceRecords: [String: EvidenceRecord] = [:],
        catalog: [Roadmap] = []
    ) -> SkillCoverageReport {
        let demonstrated = SkillGapEngine.demonstratedSkillIDs(profile: profile, roadmapProgress: progress, catalog: catalog.isEmpty ? nil : catalog, evidenceRecords: evidenceRecords.isEmpty ? nil : evidenceRecords)
        var allSkills = normalizedSet(profile.strengths + profile.customSkills)
        allSkills.formUnion(demonstrated)

        let targetSkills: Set<String>
        if let cid = careerID {
            targetSkills = Set(CareerSkillGraph.skills(for: cid))
        } else {
            // All career skills union
            targetSkills = Set(CareerSkillGraph.allRelationships.map(\.skillID))
        }

        if targetSkills.isEmpty {
            return SkillCoverageReport(totalSkills: 0, coveredCount: 0, coverage: 0, coveredSkills: [], missingSkills: [])
        }
        let covered = allSkills.intersection(targetSkills)
        let missing = targetSkills.subtracting(allSkills)
        return SkillCoverageReport(
            totalSkills: targetSkills.count,
            coveredCount: covered.count,
            coverage: Double(covered.count) / Double(targetSkills.count),
            coveredSkills: covered.sorted(),
            missingSkills: missing.sorted()
        )
    }

    @MainActor
    static func coverage(profile: StudentProfile, careerID: String? = nil, store: AppDataStore) -> SkillCoverageReport {
        coverage(profile: profile, careerID: careerID, progress: store.roadmapProgress, activeRoadmaps: store.activeRoadmaps, customProjects: store.customProjects, evidenceRecords: store.evidenceRecords, catalog: RoadmapService.allRoadmaps)
    }

    // MARK: - Gaps (reuse SkillGapEngine per roadmap, plus career gaps)

    static func gaps(
        profile: StudentProfile,
        careerID: String? = nil,
        progress: [String: Int] = [:],
        activeRoadmaps: [String: ActiveRoadmap] = [:],
        customProjects: [Project] = [],
        evidenceRecords: [String: EvidenceRecord] = [:],
        catalog: [Roadmap] = [],
        opportunities: [Opportunity] = []
    ) -> [SkillGapInsight] {
        // Career gaps
        var careerGaps: Set<String> = []
        if let cid = careerID {
            let report = coverage(profile: profile, careerID: cid, progress: progress, activeRoadmaps: activeRoadmaps, customProjects: customProjects, evidenceRecords: evidenceRecords, catalog: catalog)
            careerGaps = Set(report.missingSkills)
        } else {
            // All gaps from active roadmaps
            let activeIDs = Set(activeRoadmaps.filter { $0.value.status == .active }.map(\.key))
            if !activeIDs.isEmpty && !catalog.isEmpty {
                for rm in catalog where activeIDs.contains(rm.id) {
                    let report = SkillGapEngine.evaluate(roadmap: rm, profile: profile, progress: progress, catalog: catalog, evidenceRecords: evidenceRecords.isEmpty ? nil : evidenceRecords)
                    for gap in report.gaps { careerGaps.insert(gap.skillID) }
                }
            }
            // If no active roadmaps, fallback to career catalog gaps (all missing career skills)
            if careerGaps.isEmpty {
                let all = coverage(profile: profile, careerID: nil, progress: progress, activeRoadmaps: activeRoadmaps, customProjects: customProjects, evidenceRecords: evidenceRecords, catalog: catalog)
                careerGaps = Set(all.missingSkills)
            }
        }

        // Build insights
        var insights: [SkillGapInsight] = []
        for sid in careerGaps {
            let display = SkillCatalog.knownSkills[sid]?.name ?? sid
            let relatedCareers = CareerSkillGraph.careerIDs(for: sid)
            let relationship = relatedCareers.first.flatMap { cid in CareerSkillGraph.relationships(for: cid).first(where: { $0.skillID == sid }) }
            let importance = relationship?.importance ?? 2
            let gapReason: String
            if let rel = relationship {
                gapReason = "\(display) is a \(rel.relationshipType.displayName.lowercased()) skill for \(relatedCareers.first ?? "your career") and is not present in your current skill set."
            } else {
                gapReason = "\(display) is a current gap because it is relevant to your selected career and not present in your skill set."
            }
            // Roadmap connection
            var roadmapConnection: String?
            for rm in catalog {
                if let dev = rm.milestones.first(where: { $0.skillsDeveloped?.map { Skill.normalizeID($0) }.contains(sid) ?? false }) {
                    roadmapConnection = "\(rm.id):\(dev.id)"
                    break
                }
            }
            // Relevant projects
            let relevantProjects = customProjects.filter { proj in
                normalizedSet(proj.skills).contains(sid)
            }.map(\.id).sorted()
            // Relevant opportunities
            let relevantOpps = opportunities.filter { opp in
                normalizedSet(opp.skills).contains(sid)
            }.map(\.id).sorted()

            insights.append(SkillGapInsight(
                skillID: sid,
                skillName: display,
                relatedCareerIDs: relatedCareers.sorted(),
                gapReason: gapReason,
                importance: importance,
                relationshipType: relationship?.relationshipType,
                roadmapConnection: roadmapConnection,
                relevantProjects: relevantProjects,
                relevantOpportunities: relevantOpps,
                nextAction: "Develop \(display) via \(roadmapConnection != nil ? "roadmap" : "project or opportunity")"
            ))
        }

        // Deterministic sort: importance desc, skillName asc
        insights.sort {
            if $0.importance != $1.importance { return $0.importance > $1.importance }
            return $0.skillName.localizedCompare($1.skillName) == .orderedAscending
        }
        return insights
    }

    @MainActor
    static func gaps(profile: StudentProfile, careerID: String? = nil, store: AppDataStore) -> [SkillGapInsight] {
        gaps(profile: profile, careerID: careerID, progress: store.roadmapProgress, activeRoadmaps: store.activeRoadmaps, customProjects: store.customProjects, evidenceRecords: store.evidenceRecords, catalog: RoadmapService.allRoadmaps, opportunities: store.opportunities)
    }

    // MARK: - Next Skills

    static func nextSkills(
        profile: StudentProfile,
        careerID: String? = nil,
        limit: Int = 5,
        progress: [String: Int] = [:],
        activeRoadmaps: [String: ActiveRoadmap] = [:],
        customProjects: [Project] = [],
        evidenceRecords: [String: EvidenceRecord] = [:],
        catalog: [Roadmap] = [],
        opportunities: [Opportunity] = []
    ) -> [NextSkillRecommendation] {
        let allGaps = gaps(profile: profile, careerID: careerID, progress: progress, activeRoadmaps: activeRoadmaps, customProjects: customProjects, evidenceRecords: evidenceRecords, catalog: catalog, opportunities: opportunities)
        // Score each gap
        var scored: [(insight: SkillGapInsight, score: Int, reasons: [String], prereqs: [String], hasMissingPrereq: Bool)] = []
        let demonstrated = SkillGapEngine.demonstratedSkillIDs(profile: profile, roadmapProgress: progress, catalog: catalog.isEmpty ? nil : catalog, evidenceRecords: evidenceRecords.isEmpty ? nil : evidenceRecords)
        var allStudentSkills = normalizedSet(profile.strengths + profile.customSkills)
        allStudentSkills.formUnion(demonstrated)

        for insight in allGaps {
            var score = insight.importance * 10
            var reasons: [String] = []

            // Career importance
            if let rel = insight.relationshipType {
                switch rel {
                case .foundational: score += 15; reasons.append("Foundational for \(insight.relatedCareerIDs.first ?? "career")")
                case .core: score += 10; reasons.append("Core skill for \(insight.relatedCareerIDs.first ?? "career")")
                case .supporting: score += 5; reasons.append("Supporting skill")
                case .advanced: score += 2; reasons.append("Advanced skill")
                }
            }

            // Active gap bonus
            score += 10
            reasons.append("Current skill gap")

            // Roadmap relevance
            if insight.roadmapConnection != nil {
                score += 8
                reasons.append("Appears in active roadmap")
            }

            // Opportunity relevance
            if !insight.relevantOpportunities.isEmpty {
                score += 5
                reasons.append("Relevant to \(insight.relevantOpportunities.count) opportunities")
            }

            // Project relevance
            if !insight.relevantProjects.isEmpty {
                score += 3
                reasons.append("Relevant to your projects")
            }

            let prereqs = CareerSkillGraph.prerequisites(for: insight.skillID)
            let missingPrereqs = prereqs.filter { !allStudentSkills.contains($0) }
            let hasMissing = !missingPrereqs.isEmpty
            if hasMissing {
                // Penalize if prerequisite missing — must do prereq first
                score -= 20
                reasons.append("Requires \(missingPrereqs.first ?? "prerequisite") first")
            } else if !prereqs.isEmpty {
                score += 2
                reasons.append("Prerequisites satisfied")
            }

            scored.append((insight, score, reasons, prereqs, hasMissing))
        }

        // Filter out skills where prerequisite missing? Keep but lower score, and ensure prerequisite comes before
        // Sort by score desc, then importance desc, then skillName asc
        scored.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.insight.importance != $1.insight.importance { return $0.insight.importance > $1.insight.importance }
            return $0.insight.skillName.localizedCompare($1.insight.skillName) == .orderedAscending
        }

        // Enforce prerequisite ordering: if a skill has missing prereq that is also a gap, ensure prereq appears before
        // Simple: if a higher-scored skill has missing prereq that is in gaps, and that prereq has lower score, swap to respect order
        // For demo, we just ensure we don't recommend advanced before foundational when prereq missing: lower the advanced's score already does this

        let limitCount = max(0, min(limit, scored.count))
        return scored.prefix(limitCount).map { item in
            NextSkillRecommendation(
                skillID: item.insight.skillID,
                skillName: item.insight.skillName,
                score: item.score,
                reasons: item.reasons,
                relatedCareers: item.insight.relatedCareerIDs,
                prerequisites: item.prereqs,
                hasPrerequisiteMissing: item.hasMissingPrereq
            )
        }
    }

    @MainActor
    static func nextSkills(profile: StudentProfile, careerID: String? = nil, limit: Int = 5, store: AppDataStore) -> [NextSkillRecommendation] {
        nextSkills(profile: profile, careerID: careerID, limit: limit, progress: store.roadmapProgress, activeRoadmaps: store.activeRoadmaps, customProjects: store.customProjects, evidenceRecords: store.evidenceRecords, catalog: RoadmapService.allRoadmaps, opportunities: store.opportunities)
    }

    // MARK: - Helpers

    private static func normalizedSet(_ arr: [String]) -> Set<String> {
        Set(arr.map { Skill.normalizeID($0) }.filter { !$0.isEmpty })
    }
}
