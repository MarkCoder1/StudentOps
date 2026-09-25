import Foundation

// DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
// See OpportunityEligibilityEngine.DemoScores for shared helper. Duplicated here to keep file self-contained.
// Generates deterministic 80-99% scores per opportunity ID.
private enum DemoMatchScores {
    static let enabled = true
    static func score(for id: String) -> Int {
        var hash: Int32 = 0
        for scalar in id.unicodeScalars {
            hash = (hash &<< 5) &- hash &+ Int32(scalar.value)
        }
        let h64 = Int64(hash)
        let absHash: Int64 = h64 == Int64(Int32.min) ? Int64(Int32.max) : (h64 < 0 ? -h64 : h64)
        return 80 + Int(absHash % 20)
    }
}

// MARK: - Opportunity Matching Intelligence (Phase 10B)
// Deterministic signals measuring alignment of eligible/unknown opportunities with Student Graph.
// No AI, no mutation, no eligibility decisions. Reuses Skill.normalizeID, SkillGapEngine, RoadmapService.

struct MatchSignal: Hashable, Codable {
    let dimension: String // e.g., "goalAlignment", "careerAlignment"
    let score: Double // 0.0–1.0, 0 = no match, 1 = perfect
    let reason: String
    let available: Bool
    let weightedContribution: Double // score * weight (for debugging)
}

struct OpportunityMatchResult: Hashable, Codable {
    let opportunityID: String
    let opportunityType: OpportunityType
    let eligibilityResult: OpportunityEligibilityResult
    let overallMatchScore: Int // 0–100 deterministic
    let signals: [MatchSignal]
    let matchedSkills: [String] // normalized skill IDs that matched
    let matchedGoals: [String]
    let matchedInterests: [String]
    let coveredSkillGaps: [String] // gap IDs covered
    let roadmapConnections: [OpportunityRoadmapConnection]
    let reasons: [String] // deterministic human-readable reasons (from signals)
    let warnings: [String]
    let isEligible: Bool
    let isUnknown: Bool

    var title: String { "" } // placeholder, actual title from Opportunity
}

enum OpportunityMatchingEngine {

    // MARK: - Documented Weights (must sum to 1.0)
    // If a signal is unavailable, denominator excludes its weight (no artificial penalty).
    private enum Weights {
        static let goal: Double = 0.20
        static let career: Double = 0.15
        static let interest: Double = 0.10
        static let skill: Double = 0.15
        static let skillGap: Double = 0.15
        static let roadmap: Double = 0.10
        static let projectContinuity: Double = 0.05
        static let evidenceValue: Double = 0.05
        static let feasibility: Double = 0.03
        static let deadlineUrgency: Double = 0.02
        static let total: Double = 1.0
    }

    // MARK: Public API — per opportunity

    static func match(
        opportunity: Opportunity,
        profile: StudentProfile,
        eligibility: OpportunityEligibilityResult,
        activeGapIDs: Set<String>? = nil,
        roadmapConnections: [OpportunityRoadmapConnection]? = nil,
        customProjects: [Project] = [],
        evidenceRecords: [String: EvidenceRecord] = [:],
        portfolios: [String: StudentPortfolio] = [:],
        now: Date = Date()
    ) -> OpportunityMatchResult {
        // Precompute student sets
        let studentInterests = normalizedSet(profile.interests + profile.customInterests)
        let studentCareers = normalizedSet(profile.careers)
        let studentFields = normalizedSet(profile.fields)
        let studentMilestones = normalizedSet(profile.milestones)
        var studentGoals = studentCareers
        studentGoals.formUnion(studentFields)
        studentGoals.formUnion(studentMilestones)

        let studentSkills = normalizedSet(profile.strengths + profile.customSkills)

        // Opportunity sets
        let oppInterests = normalizedSet(opportunity.interests)
        let oppSkills = normalizedSet(opportunity.skills)
        let oppCareerFields = normalizedSet(opportunity.careerFields)

        // Use provided gaps or compute lazily? Caller should provide for performance; if nil, treat as unavailable
        let gapIDs = activeGapIDs ?? Set<String>()
        let hasGaps = activeGapIDs != nil

        // Roadmap connections
        let connections = roadmapConnections ?? []
        let hasRoadmapContext = roadmapConnections != nil

        var signals: [MatchSignal] = []

        // 1. Goal alignment (20%)
        let goalSignal = signalGoal(
            studentGoals: studentGoals,
            oppCareerFields: oppCareerFields,
            opportunity: opportunity
        )
        signals.append(goalSignal)

        // 2. Career alignment (15%)
        let careerSignal = signalCareer(
            studentCareers: studentCareers,
            oppCareerFields: oppCareerFields
        )
        signals.append(careerSignal)

        // 3. Interest alignment (10%)
        let interestSignal = signalInterest(
            studentInterests: studentInterests,
            oppInterests: oppInterests
        )
        signals.append(interestSignal)

        // 4. Skill alignment (15%)
        let skillSignal = signalSkill(
            studentSkills: studentSkills,
            oppSkills: oppSkills
        )
        signals.append(skillSignal)

        // 5. Skill-gap coverage (15%)
        let gapSignal = signalSkillGap(
            gapIDs: gapIDs,
            hasGaps: hasGaps,
            oppSkills: oppSkills
        )
        signals.append(gapSignal)

        // 6. Roadmap alignment (10%)
        let roadmapSignal = signalRoadmap(
            connections: connections,
            hasContext: hasRoadmapContext
        )
        signals.append(roadmapSignal)

        // 7. Project continuity (5%)
        let continuitySignal = signalProjectContinuity(
            customProjects: customProjects,
            oppSkills: oppSkills,
            oppCareerFields: oppCareerFields
        )
        signals.append(continuitySignal)

        // 8. Evidence / portfolio value (5%)
        let evidenceSignal = signalEvidenceValue(
            oppSkills: oppSkills,
            gapIDs: gapIDs,
            hasGaps: hasGaps,
            portfolios: portfolios,
            evidenceRecords: evidenceRecords
        )
        signals.append(evidenceSignal)

        // 9. Feasibility (3%)
        let feasibilitySignal = signalFeasibility(
            opportunity: opportunity,
            profile: profile
        )
        signals.append(feasibilitySignal)

        // 10. Deadline urgency (2%)
        let urgencySignal = signalDeadlineUrgency(
            opportunity: opportunity,
            now: now
        )
        signals.append(urgencySignal)

        // Compute weighted score normalized over available weights
        var weightedSum: Double = 0
        var availableWeightSum: Double = 0
        for sig in signals {
            let w = weight(for: sig.dimension)
            if sig.available {
                weightedSum += sig.score * w
                availableWeightSum += w
            }
        }
        let overallScore: Int
        if availableWeightSum == 0 {
            overallScore = 0
        } else {
            let normalized = weightedSum / availableWeightSum
            overallScore = Int(round(normalized * 100))
        }

        // Matched collections (for UI)
        let matchedSkills = Array(studentSkills.intersection(oppSkills)).sorted()
        let matchedGoals = Array(studentGoals.intersection(oppCareerFields)).sorted()
        let matchedInterests = Array(studentInterests.intersection(oppInterests)).sorted()
        let coveredGaps = hasGaps ? Array(gapIDs.intersection(oppSkills)).sorted() : []

        // Deterministic reasons (only from available signals with score > 0)
        var reasons: [String] = []
        for sig in signals where sig.available && sig.score > 0 {
            // Only include strong signals (>0.1) to avoid noise, but ensure at least one reason if score>0
            if sig.score >= 0.1 {
                reasons.append(sig.reason)
            }
        }
        // Ensure no fabricated reasons: if signal score is 0, reason not added

        let warnings: [String] = signals.filter { !$0.available }.map { "No data for \($0.dimension)" }

        // DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
        // Keep real opportunity names/data but display randomized high scores (80-99%) consistently.
        var finalScore = min(max(overallScore, 0), 100)
        if DemoMatchScores.enabled {
            finalScore = DemoMatchScores.score(for: opportunity.id)
        }

        return OpportunityMatchResult(
            opportunityID: opportunity.id,
            opportunityType: opportunity.opportunityType,
            eligibilityResult: eligibility,
            overallMatchScore: finalScore,
            signals: signals,
            matchedSkills: matchedSkills,
            matchedGoals: matchedGoals,
            matchedInterests: matchedInterests,
            coveredSkillGaps: coveredGaps,
            roadmapConnections: connections,
            reasons: reasons,
            warnings: warnings,
            isEligible: eligibility.status == .eligible,
            isUnknown: eligibility.status == .unknown
        )
    }

    // MARK: - Batch API

    static func matchAll(
        opportunities: [Opportunity],
        profile: StudentProfile,
        eligibilityMap: [String: OpportunityEligibilityResult],
        store: AppDataStore,
        now: Date = Date()
    ) -> [OpportunityMatchResult] {
        // Precompute gap IDs once for performance (1000+ opps)
        let gapIDs = activeGapIDs(for: store)
        // Precompute roadmap connections per opportunity
        var results: [OpportunityMatchResult] = []
        results.reserveCapacity(opportunities.count)
        for opp in opportunities {
            let eligibility = eligibilityMap[opp.id] ?? OpportunityEligibilityEngine.evaluate(opportunity: opp, profile: profile, now: now)
            let connections = store.opportunityRoadmapConnections(for: opp)
            let hasRoadmapContext = !store.activatedRoadmaps.isEmpty
            let m = match(
                opportunity: opp,
                profile: profile,
                eligibility: eligibility,
                activeGapIDs: gapIDs,
                roadmapConnections: hasRoadmapContext ? connections : nil,
                customProjects: store.customProjects,
                evidenceRecords: store.evidenceRecords,
                portfolios: store.portfolios,
                now: now
            )
            results.append(m)
        }
        return results
    }

    // MARK: - Signal Helpers

    private static func weight(for dimension: String) -> Double {
        switch dimension {
        case "goalAlignment": return Weights.goal
        case "careerAlignment": return Weights.career
        case "interestAlignment": return Weights.interest
        case "skillAlignment": return Weights.skill
        case "skillGapCoverage": return Weights.skillGap
        case "roadmapAlignment": return Weights.roadmap
        case "projectContinuity": return Weights.projectContinuity
        case "evidenceValue": return Weights.evidenceValue
        case "feasibility": return Weights.feasibility
        case "deadlineUrgency": return Weights.deadlineUrgency
        default: return 0
        }
    }

    private static func normalizedSet(_ arr: [String]) -> Set<String> {
        Set(arr.map { Skill.normalizeID($0) }.filter { !$0.isEmpty })
    }
    private static func normalizedSet(_ set: Set<String>) -> Set<String> {
        Set(set.map { Skill.normalizeID($0) }.filter { !$0.isEmpty })
    }

    private static func activeGapIDs(for store: AppDataStore) -> Set<String>? {
        // If no active roadmaps, return nil to signal unavailable (not empty)
        if store.activatedRoadmaps.isEmpty { return nil }
        var gaps = Set<String>()
        for report in store.activeSkillGapReports {
            for gap in report.gaps { gaps.insert(gap.skillID) }
        }
        // Return empty set if active roadmaps exist but no gaps (means fully demonstrated) → treat as available with 0 gaps? But spec says unavailable if no gaps
        // We'll return empty set as available but with 0 gaps, which will make skillGap signal unavailable? Actually if gaps empty, skillGap signal should be unavailable (no gaps to cover)
        // To distinguish, return empty set as available but signal will check gapIDs.isEmpty → unavailable
        return gaps
    }

    // MARK: Individual Signals

    private static func signalGoal(studentGoals: Set<String>, oppCareerFields: Set<String>, opportunity: Opportunity) -> MatchSignal {
        let dim = "goalAlignment"
        if studentGoals.isEmpty || oppCareerFields.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No goal data", available: false, weightedContribution: 0)
        }
        let inter = studentGoals.intersection(oppCareerFields)
        if inter.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No goal overlap", available: true, weightedContribution: 0)
        }
        let score = Double(inter.count) / Double(oppCareerFields.count)
        let name = inter.sorted().first.flatMap { SkillCatalog.knownSkills[$0]?.name ?? $0 } ?? "your goals"
        return MatchSignal(dimension: dim, score: score, reason: "Matches your \(name) goal", available: true, weightedContribution: score * Weights.goal)
    }

    private static func signalCareer(studentCareers: Set<String>, oppCareerFields: Set<String>) -> MatchSignal {
        let dim = "careerAlignment"
        if studentCareers.isEmpty || oppCareerFields.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No career data", available: false, weightedContribution: 0)
        }
        let inter = studentCareers.intersection(oppCareerFields)
        if inter.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No career overlap", available: true, weightedContribution: 0)
        }
        let score = Double(inter.count) / Double(oppCareerFields.count)
        let name = inter.sorted().first.flatMap { SkillCatalog.knownSkills[$0]?.name ?? $0 } ?? "your career interests"
        return MatchSignal(dimension: dim, score: score, reason: "Aligns with your career interest in \(name)", available: true, weightedContribution: score * Weights.career)
    }

    private static func signalInterest(studentInterests: Set<String>, oppInterests: Set<String>) -> MatchSignal {
        let dim = "interestAlignment"
        if studentInterests.isEmpty || oppInterests.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No interest data", available: false, weightedContribution: 0)
        }
        let inter = studentInterests.intersection(oppInterests)
        if inter.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No interest overlap", available: true, weightedContribution: 0)
        }
        let score = Double(inter.count) / Double(oppInterests.count)
        let name = inter.sorted().first ?? "your interests"
        return MatchSignal(dimension: dim, score: score, reason: "Matches your interest in \(name)", available: true, weightedContribution: score * Weights.interest)
    }

    private static func signalSkill(studentSkills: Set<String>, oppSkills: Set<String>) -> MatchSignal {
        let dim = "skillAlignment"
        if studentSkills.isEmpty || oppSkills.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No skill data", available: false, weightedContribution: 0)
        }
        let inter = studentSkills.intersection(oppSkills)
        if inter.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No skill overlap", available: true, weightedContribution: 0)
        }
        let score = Double(inter.count) / Double(oppSkills.count)
        let name = inter.sorted().first.flatMap { SkillCatalog.knownSkills[$0]?.name ?? $0 } ?? "your skills"
        return MatchSignal(dimension: dim, score: score, reason: "Builds on your \(name) skill", available: true, weightedContribution: score * Weights.skill)
    }

    private static func signalSkillGap(gapIDs: Set<String>, hasGaps: Bool, oppSkills: Set<String>) -> MatchSignal {
        let dim = "skillGapCoverage"
        if !hasGaps || gapIDs.isEmpty || oppSkills.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No skill gaps", available: false, weightedContribution: 0)
        }
        let inter = gapIDs.intersection(oppSkills)
        if inter.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "Does not cover current skill gaps", available: true, weightedContribution: 0)
        }
        let score = Double(inter.count) / Double(gapIDs.count)
        if inter.count == 1 {
            let name = inter.first.flatMap { SkillCatalog.knownSkills[$0]?.name ?? $0 } ?? "a skill"
            return MatchSignal(dimension: dim, score: score, reason: "Covers your skill gap in \(name)", available: true, weightedContribution: score * Weights.skillGap)
        } else {
            return MatchSignal(dimension: dim, score: score, reason: "Covers \(inter.count) of your skill gaps", available: true, weightedContribution: score * Weights.skillGap)
        }
    }

    private static func signalRoadmap(connections: [OpportunityRoadmapConnection], hasContext: Bool) -> MatchSignal {
        let dim = "roadmapAlignment"
        if !hasContext {
            return MatchSignal(dimension: dim, score: 0, reason: "No active roadmaps", available: false, weightedContribution: 0)
        }
        if connections.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No roadmap connection", available: true, weightedContribution: 0)
        }
        // Use strongest connection strength
        let best = connections.max { $0.strength < $1.strength } ?? connections.first!
        let score: Double
        switch best.strength {
        case .direct: score = 1.0
        case .relevant: score = 0.6
        case .future: score = 0.3
        }
        return MatchSignal(dimension: dim, score: score, reason: "Supports your \(best.roadmapTitle) roadmap", available: true, weightedContribution: score * Weights.roadmap)
    }

    private static func signalProjectContinuity(customProjects: [Project], oppSkills: Set<String>, oppCareerFields: Set<String>) -> MatchSignal {
        let dim = "projectContinuity"
        if customProjects.isEmpty || (oppSkills.isEmpty && oppCareerFields.isEmpty) {
            return MatchSignal(dimension: dim, score: 0, reason: "No project data", available: false, weightedContribution: 0)
        }
        var bestOverlap = 0
        var bestProject: Project?
        for proj in customProjects {
            let projSkills = normalizedSet(proj.skills)
            let projFields = normalizedSet(Array(proj.relevantFields) + Array(proj.relevantCareers))
            let skillInter = projSkills.intersection(oppSkills).count
            let fieldInter = projFields.intersection(oppCareerFields).count
            let overlap = skillInter + fieldInter
            if overlap > bestOverlap {
                bestOverlap = overlap
                bestProject = proj
            }
        }
        if bestOverlap == 0 {
            return MatchSignal(dimension: dim, score: 0, reason: "No project continuity", available: true, weightedContribution: 0)
        }
        // Score based on overlap relative to opportunity's total relevant items
        let totalRelevant = max(oppSkills.count + oppCareerFields.count, 1)
        let score = min(1.0, Double(bestOverlap) / Double(totalRelevant))
        let projTitle = bestProject?.title ?? "your project"
        return MatchSignal(dimension: dim, score: score, reason: "Builds on your \(projTitle) project", available: true, weightedContribution: score * Weights.projectContinuity)
    }

    private static func signalEvidenceValue(oppSkills: Set<String>, gapIDs: Set<String>, hasGaps: Bool, portfolios: [String: StudentPortfolio], evidenceRecords: [String: EvidenceRecord]) -> MatchSignal {
        let dim = "evidenceValue"
        if oppSkills.isEmpty {
            return MatchSignal(dimension: dim, score: 0, reason: "No skills for evidence", available: false, weightedContribution: 0)
        }
        // Evidence value based on whether opportunity could generate new evidence for portfolio
        // Heuristic: if opp skills overlap with gaps, high value; if opp skills are already demonstrated, lower value; otherwise moderate
        if hasGaps && !gapIDs.isEmpty {
            let inter = gapIDs.intersection(oppSkills)
            if !inter.isEmpty {
                let score = Double(inter.count) / Double(oppSkills.count)
                return MatchSignal(dimension: dim, score: score, reason: "Could provide evidence for \(inter.count) skill gap(s)", available: true, weightedContribution: score * Weights.evidenceValue)
            }
        }
        // Fallback: base value on richness
        let score = min(1.0, Double(oppSkills.count) / 4.0) * 0.5 + 0.3
        return MatchSignal(dimension: dim, score: score, reason: "Opportunity could support portfolio evidence", available: true, weightedContribution: score * Weights.evidenceValue)
    }

    private static func signalFeasibility(opportunity: Opportunity, profile: StudentProfile) -> MatchSignal {
        let dim = "feasibility"
        // Feasibility based on delivery + location + cost + deadline availability
        let hasDelivery = opportunity.deliveryMode != .unknown
        let hasLocation = opportunity.location.type.lowercased() != "unknown" || opportunity.location.city != nil || opportunity.location.state != nil
        let hasCost = opportunity.costInfo != nil

        if !hasDelivery && !hasLocation && !hasCost {
            return MatchSignal(dimension: dim, score: 0, reason: "No feasibility data", available: false, weightedContribution: 0)
        }

        // Delivery feasibility
        var score: Double = 0.5
        switch opportunity.deliveryMode {
        case .online:
            score = 1.0
        case .hybrid:
            score = 0.85
        case .inPerson:
            // Check location match
            let loc = opportunity.location
            if loc.online == true {
                score = 1.0
            } else if loc.city != nil || loc.state != nil {
                let studentLoc = profile.location.lowercased()
                if studentLoc.isEmpty {
                    // Unknown student location → moderate feasibility (unknown but not ineligible)
                    score = 0.5
                } else {
                    var matches = false
                    if let city = loc.city?.lowercased(), !city.isEmpty, studentLoc.contains(city) { matches = true }
                    if let state = loc.state?.lowercased(), !state.isEmpty, studentLoc.contains(state) { matches = true }
                    score = matches ? 0.9 : 0.3
                }
            } else {
                score = 0.6 // generic inPerson
            }
        case .unknown:
            // Use location as proxy
            if hasLocation {
                score = 0.6
            } else {
                score = 0.5
            }
        }

        // Cost feasibility: if paid and no constraint, still feasible, but slightly lower than free?
        // Since no StudentProfile cost constraint, we don't penalize paid
        // Keep score as is

        let reason: String
        switch opportunity.deliveryMode {
        case .online: reason = "Feasible: Remote/Online"
        case .hybrid: reason = "Feasible: Hybrid"
        case .inPerson: reason = "Feasibility depends on location"
        case .unknown: reason = "Feasibility: \(hasLocation ? "Location available" : "Limited info")"
        }

        return MatchSignal(dimension: dim, score: score, reason: reason, available: true, weightedContribution: score * Weights.feasibility)
    }

    private static func signalDeadlineUrgency(opportunity: Opportunity, now: Date) -> MatchSignal {
        let dim = "deadlineUrgency"
        guard let dl = opportunity.deadlineInfo else {
            return MatchSignal(dimension: dim, score: 0, reason: "No deadline", available: false, weightedContribution: 0)
        }
        switch dl.type {
        case .rolling:
            return MatchSignal(dimension: dim, score: 0.6, reason: "Rolling deadline — apply anytime", available: true, weightedContribution: 0.6 * Weights.deadlineUrgency)
        case .noDeadline:
            return MatchSignal(dimension: dim, score: 0.5, reason: "No deadline", available: true, weightedContribution: 0.5 * Weights.deadlineUrgency)
        case .unknown:
            return MatchSignal(dimension: dim, score: 0, reason: "Deadline unknown", available: false, weightedContribution: 0)
        case .fixed:
            guard let date = dl.date else {
                return MatchSignal(dimension: dim, score: 0, reason: "Deadline unknown", available: false, weightedContribution: 0)
            }
            let days = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
            if days < 0 {
                return MatchSignal(dimension: dim, score: 0, reason: "Expired", available: true, weightedContribution: 0)
            } else if days <= 7 {
                return MatchSignal(dimension: dim, score: 1.0, reason: "Deadline urgent — \(days) days left", available: true, weightedContribution: 1.0 * Weights.deadlineUrgency)
            } else if days <= 30 {
                return MatchSignal(dimension: dim, score: 0.7, reason: "Deadline upcoming — \(days) days left", available: true, weightedContribution: 0.7 * Weights.deadlineUrgency)
            } else {
                return MatchSignal(dimension: dim, score: 0.4, reason: "Deadline in \(days) days", available: true, weightedContribution: 0.4 * Weights.deadlineUrgency)
            }
        }
    }
}
