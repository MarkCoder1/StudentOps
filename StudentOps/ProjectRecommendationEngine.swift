import Foundation

// MARK: - Project Recommendation Engine (Phase 9.5)
//
// Deterministic, offline ranking of project catalog ideas against the canonical Student Graph.
// No AI, no network, no mutation, no persistence — pure computed result.
//
// Pipeline:
// Student Graph → catalog → filtering (exclude custom IDs) → signal extraction → scoring → reasons → dedup → stable ranking
//
// Inputs: StudentProfile, customProjects, roadmapProgress, activeRoadmaps, evidenceRecords, catalog, roadmapCatalog
// Output: [ProjectRecommendation] sorted descending by score with deterministic tie-breakers.
//
// Scoring (documented weights, 0.0–1.0 per signal, final 0–100):
// Goal alignment        20%  (student careers+fields+milestones vs project relevantCareers/Fields)
// Interest alignment    15%  (student interests vs project relevantInterests)
// Skill-gap coverage    25%  (gapIDs from SkillGapEngine vs project skills)
// Roadmap alignment     15%  (active roadmap required skills / sourceRoadmapID match)
// Skill continuity      10%  (overlap with existing custom project skills)
// Novelty                5%  (1 - max similarity to existing projects)
// Feasibility            5%  (estimatedCompletion heuristic)
// Evidence value         5%  (skills count + milestone count heuristic)
//
// If a signal cannot be computed (e.g., no active roadmap, no gaps), it contributes 0 rather than being renormalized.
// This keeps weights stable and reasoning explainable. Fallback when all personalized signals are zero is deterministic catalog order
// via tie-breakers (title/id).
//
// Ranking tie-breakers: 1) score descending, 2) skillGapCoverage descending, 3) roadmapAlignment descending, 4) title ascending, 5) id ascending
// Guarantees stable ordering, no random, no timestamps.
//

// MARK: - Reason Type

enum ProjectRecommendationReasonType: String, Codable, Hashable, CaseIterable {
    case goalAlignment = "goalAlignment"
    case interestAlignment = "interestAlignment"
    case skillGap = "skillGap"
    case roadmapAlignment = "roadmapAlignment"
    case skillContinuity = "skillContinuity"
    case novelty = "novelty"
    case feasibility = "feasibility"
    case evidenceValue = "evidenceValue"

    var priority: Int {
        switch self {
        case .skillGap: return 1
        case .goalAlignment: return 2
        case .roadmapAlignment: return 3
        case .interestAlignment: return 4
        case .skillContinuity: return 5
        case .novelty: return 6
        case .feasibility: return 7
        case .evidenceValue: return 8
        }
    }

    var displayLabel: String {
        switch self {
        case .goalAlignment: return "Goal"
        case .interestAlignment: return "Interest"
        case .skillGap: return "Skills"
        case .roadmapAlignment: return "Roadmap"
        case .skillContinuity: return "Continuity"
        case .novelty: return "Novelty"
        case .feasibility: return "Feasibility"
        case .evidenceValue: return "Evidence"
        }
    }
}

// MARK: - Reason

struct ProjectRecommendationReason: Identifiable, Hashable, Codable {
    let id: String
    let type: ProjectRecommendationReasonType
    let message: String
    let relatedID: String?

    init(type: ProjectRecommendationReasonType, message: String, relatedID: String? = nil) {
        self.id = "\(type.rawValue)-\(message.hashValue)-\(relatedID ?? "")"
        self.type = type
        self.message = message
        self.relatedID = relatedID
    }
}

// MARK: - Score Breakdown

struct ProjectRecommendationScoreBreakdown: Hashable, Codable {
    let goalAlignment: Double        // 0-1
    let interestAlignment: Double    // 0-1
    let skillGapCoverage: Double     // 0-1
    let roadmapAlignment: Double     // 0-1
    let skillContinuity: Double      // 0-1
    let novelty: Double              // 0-1
    let feasibility: Double          // 0-1
    let evidenceValue: Double        // 0-1

    var weightedScore: Double {
        // Documented weights, sum to 1.0
        goalAlignment * 0.20 +
        interestAlignment * 0.15 +
        skillGapCoverage * 0.25 +
        roadmapAlignment * 0.15 +
        skillContinuity * 0.10 +
        novelty * 0.05 +
        feasibility * 0.05 +
        evidenceValue * 0.05
    }

    var finalScore: Int { Int(round(weightedScore * 100)) }

    static var zero: Self {
        .init(goalAlignment: 0, interestAlignment: 0, skillGapCoverage: 0, roadmapAlignment: 0, skillContinuity: 0, novelty: 0, feasibility: 0, evidenceValue: 0)
    }
}

// MARK: - Recommendation

struct ProjectRecommendation: Identifiable, Hashable, Codable {
    let id: String // project.id
    let project: Project
    let score: Int // 0-100
    let scoreBreakdown: ProjectRecommendationScoreBreakdown
    let reasons: [ProjectRecommendationReason]

    var isFallback: Bool {
        // Fallback when no personalized signal produced a reason (all personalized scores zero)
        let personalizedTypes: Set<ProjectRecommendationReasonType> = [.goalAlignment, .interestAlignment, .skillGap, .roadmapAlignment, .skillContinuity]
        return reasons.filter { personalizedTypes.contains($0.type) }.isEmpty
    }
}

// MARK: - Engine

enum ProjectRecommendationEngine {

    // MARK: Weights (documented)

    private enum Weights {
        static let goal = 0.20
        static let interest = 0.15
        static let skillGap = 0.25
        static let roadmap = 0.15
        static let continuity = 0.10
        static let novelty = 0.05
        static let feasibility = 0.05
        static let evidence = 0.05
    }

    // MARK: Public API — AppDataStore convenience

    @MainActor
    static func recommendations(for store: AppDataStore, limit: Int = 5) -> [ProjectRecommendation] {
        let catalog = ProjectService.catalogProjects
        let roadmapCatalog = RoadmapService.allRoadmaps
        return recommendations(
            profile: store.profile,
            customProjects: store.customProjects,
            roadmapProgress: store.roadmapProgress,
            activeRoadmaps: store.activeRoadmaps,
            evidenceRecords: store.evidenceRecords,
            catalog: catalog,
            roadmapCatalog: roadmapCatalog,
            limit: limit
        )
    }

    // MARK: Pure function (testable, no MainActor)

    static func recommendations(
        profile: StudentProfile,
        customProjects: [Project],
        roadmapProgress: [String: Int] = [:],
        activeRoadmaps: [String: ActiveRoadmap] = [:],
        evidenceRecords: [String: EvidenceRecord] = [:],
        catalog: [Project],
        roadmapCatalog: [Roadmap] = [],
        limit: Int = 5
    ) -> [ProjectRecommendation] {

        // 1. Deduplication set
        let customIDs = Set(customProjects.map(\.id))

        // 2. Precompute student signals
        let studentInterests = normalizedSet(profile.interests + profile.customInterests)
        let studentCareers = normalizedSet(profile.careers)
        let studentFields = normalizedSet(profile.fields)
        let studentMilestones = normalizedSet(profile.milestones)
        var studentGoals = studentCareers
        studentGoals.formUnion(studentFields)
        studentGoals.formUnion(studentMilestones)

        let demonstrated = SkillGapEngine.demonstratedSkillIDs(
            profile: profile,
            roadmapProgress: roadmapProgress,
            catalog: roadmapCatalog.isEmpty ? nil : roadmapCatalog,
            evidenceRecords: evidenceRecords.isEmpty ? nil : evidenceRecords
        )

        // Existing project skills union
        var existingSkills = Set<String>()
        for p in customProjects {
            for s in p.skills {
                let nid = Skill.normalizeID(s)
                if !nid.isEmpty { existingSkills.insert(nid) }
            }
        }

        // Gap IDs from active roadmaps
        let gapIDs = activeGapIDs(
            profile: profile,
            roadmapProgress: roadmapProgress,
            activeRoadmaps: activeRoadmaps,
            evidenceRecords: evidenceRecords,
            roadmapCatalog: roadmapCatalog
        )

        // Active roadmap required skill sets
        let activeRoadmapIDs = Set(activeRoadmaps.filter { $0.value.status == .active }.map(\.key))
        let activeRoadmapsList = roadmapCatalog.filter { activeRoadmapIDs.contains($0.id) }
        // Map roadmapID -> requiredSkillIDs set
        var roadmapRequired: [String: Set<String>] = [:]
        for rm in activeRoadmapsList {
            let req = Set(SkillGapEngine.requiredSkills(for: rm).map(\.id))
            roadmapRequired[rm.id] = req
        }

        // 3. Score each candidate
        var candidates: [ProjectRecommendation] = []

        for project in catalog where !customIDs.contains(project.id) {
            let breakdown = score(
                project: project,
                studentInterests: studentInterests,
                studentGoals: studentGoals,
                studentCareers: studentCareers,
                studentFields: studentFields,
                gapIDs: gapIDs,
                demonstrated: demonstrated,
                activeRoadmapsList: activeRoadmapsList,
                roadmapRequired: roadmapRequired,
                existingSkills: existingSkills,
                existingProjects: customProjects,
                profile: profile
            )
            let reasons = generateReasons(
                project: project,
                breakdown: breakdown,
                studentInterests: studentInterests,
                studentGoals: studentGoals,
                gapIDs: gapIDs,
                activeRoadmapsList: activeRoadmapsList,
                roadmapRequired: roadmapRequired,
                existingSkills: existingSkills,
                existingProjects: customProjects,
                profile: profile
            )
            let rec = ProjectRecommendation(
                id: project.id,
                project: project,
                score: breakdown.finalScore,
                scoreBreakdown: breakdown,
                reasons: reasons.sorted { $0.type.priority < $1.type.priority }
            )
            candidates.append(rec)
        }

        // 4. Stable ranking
        candidates.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            if a.scoreBreakdown.skillGapCoverage != b.scoreBreakdown.skillGapCoverage {
                return a.scoreBreakdown.skillGapCoverage > b.scoreBreakdown.skillGapCoverage
            }
            if a.scoreBreakdown.roadmapAlignment != b.scoreBreakdown.roadmapAlignment {
                return a.scoreBreakdown.roadmapAlignment > b.scoreBreakdown.roadmapAlignment
            }
            if a.project.title != b.project.title {
                return a.project.title.localizedCompare(b.project.title) == .orderedAscending
            }
            return a.project.id < b.project.id
        }

        // 5. Limit
        let effectiveLimit = max(0, limit)
        if effectiveLimit == 0 { return [] }
        if candidates.count <= effectiveLimit { return candidates }
        return Array(candidates.prefix(effectiveLimit))
    }

    // MARK: - Scoring

    private static func score(
        project: Project,
        studentInterests: Set<String>,
        studentGoals: Set<String>,
        studentCareers: Set<String>,
        studentFields: Set<String>,
        gapIDs: Set<String>,
        demonstrated: Set<String>,
        activeRoadmapsList: [Roadmap],
        roadmapRequired: [String: Set<String>],
        existingSkills: Set<String>,
        existingProjects: [Project],
        profile: StudentProfile
    ) -> ProjectRecommendationScoreBreakdown {

        // Goal alignment: intersection / projectGoalRelevant count
        let projectGoalRelevant = normalizedSet(Array(project.relevantCareers) + Array(project.relevantFields))
        let goalAlignment: Double = {
            if studentGoals.isEmpty || projectGoalRelevant.isEmpty { return 0 }
            let inter = studentGoals.intersection(projectGoalRelevant)
            return Double(inter.count) / Double(projectGoalRelevant.count)
        }()

        // Interest alignment
        let projectInterests = normalizedSet(Array(project.relevantInterests))
        let interestAlignment: Double = {
            if studentInterests.isEmpty || projectInterests.isEmpty { return 0 }
            let inter = studentInterests.intersection(projectInterests)
            return Double(inter.count) / Double(projectInterests.count)
        }()

        // Skill-gap coverage
        let projectSkillIDs = normalizedSet(project.skills)
        let skillGapCoverage: Double = {
            if gapIDs.isEmpty || projectSkillIDs.isEmpty { return 0 }
            let inter = gapIDs.intersection(projectSkillIDs)
            return Double(inter.count) / Double(gapIDs.count)
        }()

        // Roadmap alignment
        let roadmapAlignment: Double = {
            if activeRoadmapsList.isEmpty || projectSkillIDs.isEmpty { return 0 }
            // sourceRoadmapID direct match gives 1.0
            if let src = project.sourceRoadmapID?.trimmingCharacters(in: .whitespacesAndNewlines), !src.isEmpty {
                if activeRoadmapsList.contains(where: { $0.id == src }) { return 1.0 }
            }
            var best: Double = 0
            for rm in activeRoadmapsList {
                guard let req = roadmapRequired[rm.id], !req.isEmpty else { continue }
                let inter = req.intersection(projectSkillIDs)
                // proportion of project's skills that are required by roadmap
                let ratio = Double(inter.count) / Double(max(projectSkillIDs.count, 1))
                if ratio > best { best = ratio }
                // also consider coverage of roadmap: inter / req.count alternative
                // take max of both to be generous but deterministic
                let ratio2 = Double(inter.count) / Double(req.count)
                if ratio2 > best { best = ratio2 }
            }
            return min(best, 1.0)
        }()

        // Skill continuity
        let skillContinuity: Double = {
            if existingSkills.isEmpty || projectSkillIDs.isEmpty { return 0 }
            let inter = existingSkills.intersection(projectSkillIDs)
            return Double(inter.count) / Double(projectSkillIDs.count)
        }()

        // Novelty
        let novelty: Double = {
            if existingProjects.isEmpty { return 1.0 }
            var maxSim: Double = 0
            for existing in existingProjects {
                let catMatch = project.category == existing.category ? 1.0 : 0.0
                let existingSkillIDs = normalizedSet(existing.skills)
                let inter = projectSkillIDs.intersection(existingSkillIDs).count
                let union = projectSkillIDs.union(existingSkillIDs).count
                let jaccard = union == 0 ? 0 : Double(inter) / Double(union)
                let sim = 0.3 * catMatch + 0.7 * jaccard
                if sim > maxSim { maxSim = sim }
            }
            return max(0, 1.0 - maxSim)
        }()

        // Feasibility (heuristic on estimatedCompletion)
        let feasibility: Double = {
            let est = project.estimatedCompletion.lowercased()
            if est.isEmpty { return 0.5 }
            if est.contains("min") { return 0.95 }
            if est.contains("hour") { return 0.85 }
            if est.contains("day") { return est.contains("1") ? 0.80 : 0.75 }
            if est.contains("week") {
                if est.contains("1–2") || est.contains("1-2") { return 0.65 }
                if est.contains("2–3") || est.contains("2-3") { return 0.55 }
                return 0.50
            }
            if est.contains("month") { return 0.35 }
            // fallback based on milestone count
            return project.milestones.isEmpty ? 0.5 : max(0.3, 1.0 - Double(project.milestones.count) * 0.12)
        }()

        // Evidence value (secondary) — base 0.4 + skill/milestone contribution, capped at 1.0
        let evidenceValue: Double = {
            let base = 0.4
            let skillPart = min(1.0, Double(project.skills.count) / 4.0) * 0.4
            let milestonePart = min(1.0, Double(project.milestones.count) / 4.0) * 0.2
            return min(1.0, base + skillPart + milestonePart)
        }()
        return ProjectRecommendationScoreBreakdown(
            goalAlignment: goalAlignment,
            interestAlignment: interestAlignment,
            skillGapCoverage: skillGapCoverage,
            roadmapAlignment: roadmapAlignment,
            skillContinuity: skillContinuity,
            novelty: novelty,
            feasibility: feasibility,
            evidenceValue: evidenceValue
        )
    }

    // MARK: - Reasons

    private static func generateReasons(
        project: Project,
        breakdown: ProjectRecommendationScoreBreakdown,
        studentInterests: Set<String>,
        studentGoals: Set<String>,
        gapIDs: Set<String>,
        activeRoadmapsList: [Roadmap],
        roadmapRequired: [String: Set<String>],
        existingSkills: Set<String>,
        existingProjects: [Project],
        profile: StudentProfile
    ) -> [ProjectRecommendationReason] {
        var out: [ProjectRecommendationReason] = []

        // Helper to find display name for normalized ID from profile or catalog
        func displayName(for norm: String) -> String {
            // try profile careers/fields first
            for raw in profile.careers where Skill.normalizeID(raw) == norm { return raw }
            for raw in profile.fields where Skill.normalizeID(raw) == norm { return raw }
            for raw in profile.milestones where Skill.normalizeID(raw) == norm { return raw }
            for raw in profile.interests where Skill.normalizeID(raw) == norm { return raw }
            // fallback to catalog skill name
            return SkillCatalog.knownSkills[norm]?.name ?? norm
        }

        // Skill gap reason — most important
        if breakdown.skillGapCoverage > 0 {
            let projectSkillIDs = normalizedSet(project.skills)
            let intersect = gapIDs.intersection(projectSkillIDs)
            if !intersect.isEmpty {
                let sorted = intersect.sorted()
                let names = sorted.compactMap { SkillCatalog.knownSkills[$0]?.name ?? $0 }
                if names.count == 1 {
                    out.append(.init(type: .skillGap, message: "Builds a skill you need to strengthen: \(names[0])", relatedID: sorted[0]))
                } else if names.count == 2 {
                    out.append(.init(type: .skillGap, message: "Builds 2 skills you need to strengthen: \(names.joined(separator: " and "))", relatedID: sorted.joined(separator: ",")))
                } else {
                    out.append(.init(type: .skillGap, message: "Builds \(names.count) skills you need to strengthen", relatedID: sorted.joined(separator: ",")))
                }
            } else {
                // fallback generic but still positive coverage means some gap covered? Actually if coverage>0 then intersect not empty, so this branch shouldn't happen
                out.append(.init(type: .skillGap, message: "Builds skills you need to strengthen"))
            }
        }

        // Goal alignment
        if breakdown.goalAlignment > 0 {
            let projectGoalRelevant = normalizedSet(Array(project.relevantCareers) + Array(project.relevantFields))
            let inter = studentGoals.intersection(projectGoalRelevant)
            if let first = inter.sorted().first {
                let name = displayName(for: first)
                out.append(.init(type: .goalAlignment, message: "Matches your \(name) goal", relatedID: first))
            } else {
                out.append(.init(type: .goalAlignment, message: "Aligned with your goals", relatedID: nil))
            }
        }

        // Roadmap alignment
        if breakdown.roadmapAlignment > 0.2 {
            // find best roadmap
            let projectSkillIDs = normalizedSet(project.skills)
            var bestRoadmap: Roadmap?
            var bestScore: Double = 0
            for rm in activeRoadmapsList {
                let req = roadmapRequired[rm.id] ?? []
                let inter = req.intersection(projectSkillIDs).count
                let score = Double(inter) / Double(max(projectSkillIDs.count, 1))
                if let src = project.sourceRoadmapID, src == rm.id { // direct match
                    bestRoadmap = rm; bestScore = 1.0; break
                }
                if score > bestScore { bestScore = score; bestRoadmap = rm }
            }
            if let rm = bestRoadmap {
                out.append(.init(type: .roadmapAlignment, message: "Supports your \(rm.title) roadmap", relatedID: rm.id))
            } else {
                out.append(.init(type: .roadmapAlignment, message: "Supports your current roadmap", relatedID: nil))
            }
        }

        // Interest alignment
        if breakdown.interestAlignment > 0 {
            let projectInterests = normalizedSet(Array(project.relevantInterests))
            let inter = studentInterests.intersection(projectInterests)
            if let first = inter.sorted().first {
                let name = displayName(for: first)
                out.append(.init(type: .interestAlignment, message: "Matches your interest in \(name)", relatedID: first))
            } else {
                out.append(.init(type: .interestAlignment, message: "Matches your interests", relatedID: nil))
            }
        }

        // Skill continuity
        if breakdown.skillContinuity > 0.25 {
            let projectSkillIDs = normalizedSet(project.skills)
            var bestProj: Project?
            var bestOverlap = -1
            for existing in existingProjects {
                let existingIDs = normalizedSet(existing.skills)
                let overlap = existingIDs.intersection(projectSkillIDs).count
                if overlap > bestOverlap { bestOverlap = overlap; bestProj = existing }
            }
            if let bp = bestProj, bestOverlap > 0 {
                out.append(.init(type: .skillContinuity, message: "Builds on skills from your \(bp.title) project", relatedID: bp.id))
            } else if !existingSkills.isEmpty {
                out.append(.init(type: .skillContinuity, message: "Builds on your existing skills", relatedID: nil))
            }
        }

        // Novelty — only when high
        if breakdown.novelty > 0.7 {
            out.append(.init(type: .novelty, message: "Adds a new project rather than duplicating existing work", relatedID: nil))
        }

        // Feasibility and evidenceValue are secondary; we do not generate prominent reasons for them by default
        // but they contribute to score.

        return out
    }

    // MARK: - Helpers

    private static func normalizedSet(_ arr: [String]) -> Set<String> {
        Set(arr.map { Skill.normalizeID($0) }.filter { !$0.isEmpty })
    }
    private static func normalizedSet(_ set: Set<String>) -> Set<String> {
        Set(set.map { Skill.normalizeID($0) }.filter { !$0.isEmpty })
    }

    private static func activeGapIDs(
        profile: StudentProfile,
        roadmapProgress: [String: Int],
        activeRoadmaps: [String: ActiveRoadmap],
        evidenceRecords: [String: EvidenceRecord],
        roadmapCatalog: [Roadmap]
    ) -> Set<String> {
        guard !roadmapCatalog.isEmpty else { return [] }
        let activeIDs = Set(activeRoadmaps.filter { $0.value.status == .active }.map(\.key))
        if activeIDs.isEmpty { return [] }
        var gaps = Set<String>()
        for roadmap in roadmapCatalog where activeIDs.contains(roadmap.id) {
            let report = SkillGapEngine.evaluate(
                roadmap: roadmap,
                profile: profile,
                progress: roadmapProgress,
                catalog: roadmapCatalog,
                evidenceRecords: evidenceRecords
            )
            for gap in report.gaps {
                gaps.insert(gap.skill.id)
            }
        }
        return gaps
    }
}
