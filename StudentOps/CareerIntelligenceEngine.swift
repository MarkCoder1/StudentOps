import Foundation

// MARK: - Career Intelligence Engine (Phase 11A)
// Authoritative deterministic engine for career insights.
// No AI, no mutation, no database, reuses Skill.normalizeID, SkillGapEngine, RoadmapService.

struct CareerAlignmentSignal: Hashable, Codable {
    let dimension: String
    let score: Double // 0–1
    let reason: String
    let available: Bool
    let details: [String] // e.g., matched IDs
}

struct CareerAlignmentResult: Hashable, Codable {
    let careerID: String
    let careerTitle: String
    let score: Int // 0–100
    let signals: [CareerAlignmentSignal]
    let matchedGoals: [String]
    let matchedFields: [String]
    let matchedInterests: [String]
    let matchedSkills: [String]
    let relatedProjects: [String] // project IDs
    let roadmapConnections: [String] // roadmap IDs
    let skillCoverage: Double // 0–1
    let missingSkills: [String]
    let reasons: [String]
    let warnings: [String]
    let isInsufficientContext: Bool
}

enum CareerIntelligenceEngine {

    // MARK: - Documented Weights (denominator = sum of available)
    // Goal 25, Field 15, Interest 15, Skill 20, Project 10, Roadmap 10, Opportunity 5 = 100
    private enum Weights {
        static let goal: Double = 0.25
        static let field: Double = 0.15
        static let interest: Double = 0.15
        static let skill: Double = 0.20
        static let project: Double = 0.10
        static let roadmap: Double = 0.10
        static let opportunity: Double = 0.05
        static let total: Double = 1.0
    }

    // MARK: - Public API

    static func alignment(
        career: Career,
        profile: StudentProfile,
        store: AppDataStore
    ) -> CareerAlignmentResult {
        alignment(career: career, profile: profile, progress: store.roadmapProgress, activeRoadmaps: store.activeRoadmaps, customProjects: store.customProjects, evidenceRecords: store.evidenceRecords, catalog: RoadmapService.allRoadmaps, opportunities: store.opportunities)
    }

    static func alignment(
        career: Career,
        profile: StudentProfile,
        progress: [String: Int] = [:],
        activeRoadmaps: [String: ActiveRoadmap] = [:],
        customProjects: [Project] = [],
        evidenceRecords: [String: EvidenceRecord] = [:],
        catalog: [Roadmap] = [],
        opportunities: [Opportunity] = []
    ) -> CareerAlignmentResult {

        // Normalized student sets
        let studentCareers = normalizedSet(profile.careers)
        let studentFields = normalizedSet(profile.fields)
        let studentInterests = normalizedSet(profile.interests + profile.customInterests)
        let studentMilestones = normalizedSet(profile.milestones)
        var studentGoals = studentCareers
        studentGoals.formUnion(studentFields)
        studentGoals.formUnion(studentMilestones)

        let studentSkills = normalizedSet(profile.strengths + profile.customSkills)
        let demonstrated = SkillGapEngine.demonstratedSkillIDs(profile: profile, roadmapProgress: progress, catalog: catalog.isEmpty ? nil : catalog, evidenceRecords: evidenceRecords.isEmpty ? nil : evidenceRecords)
        // Union for coverage (profile + demonstrated)
        var allStudentSkills = studentSkills
        allStudentSkills.formUnion(demonstrated)

        // Career sets
        let careerSkills = normalizedSet(career.skills)
        let careerRelated = normalizedSet(career.relatedSkills)
        var careerAllSkills = careerSkills
        careerAllSkills.formUnion(careerRelated)
        let careerFields = normalizedSet(career.fields)
        let careerInterests = normalizedSet(career.interests)

        var signals: [CareerAlignmentSignal] = []

        // 1. Goal alignment 25% — student careers+fields+milestones vs career fields+industries
        let careerGoalRelevant = careerFields.union(normalizedSet(career.industries))
        if studentGoals.isEmpty || careerGoalRelevant.isEmpty {
            signals.append(CareerAlignmentSignal(dimension: "goalAlignment", score: 0, reason: "No goal data", available: false, details: []))
        } else {
            let inter = studentGoals.intersection(careerGoalRelevant)
            if inter.isEmpty {
                signals.append(CareerAlignmentSignal(dimension: "goalAlignment", score: 0, reason: "No goal overlap with \(career.title)", available: true, details: []))
            } else {
                let score = Double(inter.count) / Double(careerGoalRelevant.count)
                signals.append(CareerAlignmentSignal(dimension: "goalAlignment", score: score, reason: "Matches your \(inter.sorted().first.flatMap { skillDisplay($0) } ?? "goal") goal", available: true, details: Array(inter).sorted()))
            }
        }

        // 2. Field alignment 15%
        if studentFields.isEmpty || careerFields.isEmpty {
            signals.append(CareerAlignmentSignal(dimension: "fieldAlignment", score: 0, reason: "No field data", available: false, details: []))
        } else {
            let inter = studentFields.intersection(careerFields)
            if inter.isEmpty {
                signals.append(CareerAlignmentSignal(dimension: "fieldAlignment", score: 0, reason: "No field overlap", available: true, details: []))
            } else {
                let score = Double(inter.count) / Double(careerFields.count)
                signals.append(CareerAlignmentSignal(dimension: "fieldAlignment", score: score, reason: "Shares field \(inter.sorted().first!)", available: true, details: Array(inter).sorted()))
            }
        }

        // 3. Interest alignment 15%
        if studentInterests.isEmpty || careerInterests.isEmpty {
            signals.append(CareerAlignmentSignal(dimension: "interestAlignment", score: 0, reason: "No interest data", available: false, details: []))
        } else {
            let inter = studentInterests.intersection(careerInterests)
            if inter.isEmpty {
                signals.append(CareerAlignmentSignal(dimension: "interestAlignment", score: 0, reason: "No interest overlap", available: true, details: []))
            } else {
                let score = Double(inter.count) / Double(careerInterests.count)
                signals.append(CareerAlignmentSignal(dimension: "interestAlignment", score: score, reason: "Matches your interest in \(inter.sorted().first!)", available: true, details: Array(inter).sorted()))
            }
        }

        // 4. Skill coverage 20%
        if careerAllSkills.isEmpty {
            signals.append(CareerAlignmentSignal(dimension: "skillCoverage", score: 0, reason: "No career skills defined", available: false, details: []))
        } else if allStudentSkills.isEmpty {
            signals.append(CareerAlignmentSignal(dimension: "skillCoverage", score: 0, reason: "No skills in profile", available: false, details: []))
        } else {
            let inter = allStudentSkills.intersection(careerAllSkills)
            let score = Double(inter.count) / Double(careerAllSkills.count)
            if inter.isEmpty {
                signals.append(CareerAlignmentSignal(dimension: "skillCoverage", score: 0, reason: "No skill overlap with \(career.title)", available: true, details: []))
            } else {
                signals.append(CareerAlignmentSignal(dimension: "skillCoverage", score: score, reason: "Shares \(inter.count) skills with \(career.title)", available: true, details: Array(inter).sorted()))
            }
        }

        // 5. Project continuity 10%
        if customProjects.isEmpty || careerAllSkills.isEmpty {
            signals.append(CareerAlignmentSignal(dimension: "projectContinuity", score: 0, reason: "No project data", available: false, details: []))
        } else {
            var bestOverlap = 0
            var bestProjectID: String?
            for proj in customProjects {
                let projSkills = normalizedSet(proj.skills)
                let inter = projSkills.intersection(careerAllSkills).count
                if inter > bestOverlap {
                    bestOverlap = inter
                    bestProjectID = proj.id
                }
            }
            if bestOverlap == 0 {
                signals.append(CareerAlignmentSignal(dimension: "projectContinuity", score: 0, reason: "No project continuity with \(career.title)", available: true, details: []))
            } else {
                let score = min(1.0, Double(bestOverlap) / Double(max(careerAllSkills.count, 1)))
                signals.append(CareerAlignmentSignal(dimension: "projectContinuity", score: score, reason: "Your project demonstrates \(bestOverlap) relevant skills", available: true, details: bestProjectID.map { [$0] } ?? []))
            }
        }

        // 6. Roadmap alignment 10%
        let activeRoadmapIDs = Set(activeRoadmaps.filter { $0.value.status == .active }.map(\.key))
        if activeRoadmapIDs.isEmpty || careerAllSkills.isEmpty {
            signals.append(CareerAlignmentSignal(dimension: "roadmapAlignment", score: 0, reason: "No active roadmap", available: false, details: []))
        } else {
            let activeRoadmapsList = catalog.filter { activeRoadmapIDs.contains($0.id) }
            var bestScore: Double = 0
            var bestRoadmapID: String?
            for rm in activeRoadmapsList {
                let req = Set(SkillGapEngine.requiredSkills(for: rm).map(\.id))
                let inter = req.intersection(careerAllSkills).count
                let score = req.isEmpty ? 0 : Double(inter) / Double(req.count)
                if score > bestScore {
                    bestScore = score
                    bestRoadmapID = rm.id
                }
                // Direct career field match via roadmap relevant fields/careers
                let rmFields = normalizedSet(Array(rm.relevantFields) + Array(rm.relevantCareers))
                let fieldInter = rmFields.intersection(careerFields.union(careerGoalRelevant)).count
                let fieldScore = rmFields.isEmpty ? 0 : Double(fieldInter) / Double(rmFields.count)
                if fieldScore > bestScore {
                    bestScore = fieldScore
                    bestRoadmapID = rm.id
                }
            }
            if bestScore == 0 {
                signals.append(CareerAlignmentSignal(dimension: "roadmapAlignment", score: 0, reason: "Active roadmap does not target \(career.title)", available: true, details: []))
            } else {
                signals.append(CareerAlignmentSignal(dimension: "roadmapAlignment", score: bestScore, reason: "Your active roadmap targets \(career.title)", available: true, details: bestRoadmapID.map { [$0] } ?? []))
            }
        }

        // 7. Opportunity continuity 5%
        if opportunities.isEmpty || careerAllSkills.isEmpty {
            signals.append(CareerAlignmentSignal(dimension: "opportunityContinuity", score: 0, reason: "No opportunity data", available: false, details: []))
        } else {
            var bestOverlap = 0
            var bestOppID: String?
            for opp in opportunities {
                let oppSkills = normalizedSet(opp.skills)
                let inter = oppSkills.intersection(careerAllSkills).count
                if inter > bestOverlap {
                    bestOverlap = inter
                    bestOppID = opp.id
                }
            }
            if bestOverlap == 0 {
                signals.append(CareerAlignmentSignal(dimension: "opportunityContinuity", score: 0, reason: "No opportunity connects to \(career.title)", available: true, details: []))
            } else {
                let score = min(1.0, Double(bestOverlap) / Double(max(careerAllSkills.count, 1)))
                signals.append(CareerAlignmentSignal(dimension: "opportunityContinuity", score: score, reason: "Opportunities connect to \(career.title)", available: true, details: bestOppID.map { [$0] } ?? []))
            }
        }

        // Weighted scoring
        var weightedSum: Double = 0
        var availableWeight: Double = 0
        for s in signals {
            let w = weight(for: s.dimension)
            if s.available {
                weightedSum += s.score * w
                availableWeight += w
            }
        }
        let finalScore: Int
        let insufficientContext: Bool
        if availableWeight == 0 {
            finalScore = 0
            insufficientContext = true
        } else {
            finalScore = Int(round(weightedSum / availableWeight * 100))
            insufficientContext = false
        }

        // Matched collections
        let matchedGoals = Array(studentGoals.intersection(careerGoalRelevant)).sorted()
        let matchedFields = Array(studentFields.intersection(careerFields)).sorted()
        let matchedInterests = Array(studentInterests.intersection(careerInterests)).sorted()
        let matchedSkills = Array(allStudentSkills.intersection(careerAllSkills)).sorted()
        let missingSkills = Array(careerAllSkills.subtracting(allStudentSkills)).sorted()
        let relatedProjects = signals.first(where: { $0.dimension == "projectContinuity" })?.details ?? []
        let roadmapConnections = signals.first(where: { $0.dimension == "roadmapAlignment" })?.details ?? []

        // Coverage
        let coverage: Double = careerAllSkills.isEmpty ? 0 : Double(matchedSkills.count) / Double(careerAllSkills.count)

        // Reasons (only from available signals with score > 0 and >=0.1 or insufficient context)
        var reasons: [String] = []
        for s in signals where s.available && s.score > 0.05 {
            reasons.append(s.reason)
        }
        if insufficientContext {
            reasons.append("Add career goals, interests, and skills to improve matching")
        }

        var warnings: [String] = []
        for s in signals where !s.available {
            warnings.append("No data for \(s.dimension)")
        }

        return CareerAlignmentResult(
            careerID: career.id,
            careerTitle: career.title,
            score: min(max(finalScore, 0), 100),
            signals: signals,
            matchedGoals: matchedGoals,
            matchedFields: matchedFields,
            matchedInterests: matchedInterests,
            matchedSkills: matchedSkills,
            relatedProjects: relatedProjects,
            roadmapConnections: roadmapConnections,
            skillCoverage: coverage,
            missingSkills: missingSkills,
            reasons: reasons,
            warnings: warnings,
            isInsufficientContext: insufficientContext
        )
    }

    static func alignments(
        profile: StudentProfile,
        store: AppDataStore
    ) -> [CareerAlignmentResult] {
        CareerCatalog.all.map { alignment(career: $0, profile: profile, store: store) }
    }

    static func alignments(
        profile: StudentProfile,
        progress: [String: Int] = [:],
        activeRoadmaps: [String: ActiveRoadmap] = [:],
        customProjects: [Project] = [],
        evidenceRecords: [String: EvidenceRecord] = [:],
        catalog: [Roadmap] = [],
        opportunities: [Opportunity] = []
    ) -> [CareerAlignmentResult] {
        CareerCatalog.all.map {
            alignment(career: $0, profile: profile, progress: progress, activeRoadmaps: activeRoadmaps, customProjects: customProjects, evidenceRecords: evidenceRecords, catalog: catalog, opportunities: opportunities)
        }
    }

    // MARK: - Helpers

    private static func weight(for dimension: String) -> Double {
        switch dimension {
        case "goalAlignment": return Weights.goal
        case "fieldAlignment": return Weights.field
        case "interestAlignment": return Weights.interest
        case "skillCoverage": return Weights.skill
        case "projectContinuity": return Weights.project
        case "roadmapAlignment": return Weights.roadmap
        case "opportunityContinuity": return Weights.opportunity
        default: return 0
        }
    }

    private static func normalizedSet(_ arr: [String]) -> Set<String> {
        Set(arr.map { Skill.normalizeID($0) }.filter { !$0.isEmpty })
    }

    private static func normalizedSet(_ set: Set<String>) -> Set<String> {
        Set(set.map { Skill.normalizeID($0) }.filter { !$0.isEmpty })
    }

    private static func skillDisplay(_ nid: String) -> String {
        SkillCatalog.knownSkills[nid]?.name ?? nid
    }
}
