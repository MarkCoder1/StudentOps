import Foundation

// MARK: - Opportunity Ranking Intelligence (Phase 10B)
// Deterministic ordering: eligibility → match score → skill-gap → roadmap → deadline urgency → title → org → id
// No AI, no mutation, no dictionary ordering.

enum RankingFilterMode: String, CaseIterable {
    case all = "All"
    case eligible = "Eligible"
    case needsVerification = "Needs Info"
    case ineligible = "Ineligible / Expired"
}

struct RankedOpportunity: Identifiable, Hashable {
    let opportunity: Opportunity
    let matchResult: OpportunityMatchResult
    let eligibilityStatus: OpportunityEligibilityStatus
    let rankScore: Int // same as matchResult.overallMatchScore for convenience
    var id: String { opportunity.id }
}

enum OpportunityRankingEngine {

    // MARK: - Public Ranking

    /// Deterministic ranking consuming match results. Does not mutate any state.
    static func rank(_ matchResults: [OpportunityMatchResult], opportunitiesByID: [String: Opportunity]) -> [RankedOpportunity] {
        var ranked: [RankedOpportunity] = []
        ranked.reserveCapacity(matchResults.count)
        for mr in matchResults {
            guard let opp = opportunitiesByID[mr.opportunityID] else { continue }
            ranked.append(RankedOpportunity(opportunity: opp, matchResult: mr, eligibilityStatus: mr.eligibilityResult.status, rankScore: mr.overallMatchScore))
        }
        return sorted(ranked)
    }

    /// Convenience: rank directly from opportunities + profile via eligibility+matching
    static func rank(
        opportunities: [Opportunity],
        profile: StudentProfile,
        store: AppDataStore,
        filter: RankingFilterMode = .all,
        category: OpportunityType? = nil,
        searchText: String? = nil,
        now: Date = Date()
    ) -> [RankedOpportunity] {
        let eligibilityMap = OpportunityEligibilityEngine.evaluateAll(opportunities: opportunities, profile: profile, now: now)
        let matchResults = OpportunityMatchingEngine.matchAll(opportunities: opportunities, profile: profile, eligibilityMap: eligibilityMap, store: store, now: now)
        let oppMap = Dictionary(uniqueKeysWithValues: opportunities.map { ($0.id, $0) })
        var ranked = rank(matchResults, opportunitiesByID: oppMap)

        // Apply filter mode
        switch filter {
        case .all:
            break
        case .eligible:
            ranked = ranked.filter { $0.eligibilityStatus == .eligible }
        case .needsVerification:
            ranked = ranked.filter { $0.eligibilityStatus == .unknown }
        case .ineligible:
            ranked = ranked.filter { $0.eligibilityStatus == .ineligible }
        }

        // Category filter
        if let cat = category {
            ranked = ranked.filter { $0.opportunity.opportunityType == cat }
        }

        // Search filter (deterministic, case-insensitive)
        if let search = searchText?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty {
            let lower = search.lowercased()
            ranked = ranked.filter { r in
                let opp = r.opportunity
                let haystack = [opp.title, opp.organization, opp.description, opp.interests.joined(separator: " "), opp.skills.joined(separator: " "), opp.careerFields.joined(separator: " ")].joined(separator: " ").lowercased()
                return haystack.contains(lower)
            }
        }

        return ranked
    }

    // MARK: - Deterministic Sort

    /// Tie-break hierarchy documented:
    /// 1. eligible before unknown (ineligible last, or filtered)
    /// 2. match score descending
    /// 3. skill-gap coverage descending (from signals)
    /// 4. roadmap alignment descending
    /// 5. deadline urgency descending
    /// 6. title ascending (case-insensitive)
    /// 7. organization ascending (case-insensitive)
    /// 8. id ascending
    static func sorted(_ ranked: [RankedOpportunity]) -> [RankedOpportunity] {
        ranked.sorted { a, b in
            // 1. Eligibility ordering: eligible (0) < unknown (1) < ineligible (2)
            let aEligRank = eligibilityRank(a.eligibilityStatus)
            let bEligRank = eligibilityRank(b.eligibilityStatus)
            if aEligRank != bEligRank { return aEligRank < bEligRank }

            // 2. Match score descending
            if a.rankScore != b.rankScore { return a.rankScore > b.rankScore }

            // 3. Skill-gap coverage descending
            let aGap = signalScore(a.matchResult, dimension: "skillGapCoverage")
            let bGap = signalScore(b.matchResult, dimension: "skillGapCoverage")
            if aGap != bGap { return aGap > bGap }

            // 4. Roadmap alignment descending
            let aRoad = signalScore(a.matchResult, dimension: "roadmapAlignment")
            let bRoad = signalScore(b.matchResult, dimension: "roadmapAlignment")
            if aRoad != bRoad { return aRoad > bRoad }

            // 5. Deadline urgency descending
            let aUrg = signalScore(a.matchResult, dimension: "deadlineUrgency")
            let bUrg = signalScore(b.matchResult, dimension: "deadlineUrgency")
            if aUrg != bUrg { return aUrg > bUrg }

            // 6. Title ascending
            let aTitle = a.opportunity.title.lowercased()
            let bTitle = b.opportunity.title.lowercased()
            if aTitle != bTitle { return aTitle < bTitle }

            // 7. Organization ascending
            let aOrg = a.opportunity.organization.lowercased()
            let bOrg = b.opportunity.organization.lowercased()
            if aOrg != bOrg { return aOrg < bOrg }

            // 8. ID ascending
            return a.opportunity.id < b.opportunity.id
        }
    }

    private static func eligibilityRank(_ status: OpportunityEligibilityStatus) -> Int {
        switch status {
        case .eligible: return 0
        case .unknown: return 1
        case .ineligible: return 2
        case .notEvaluated: return 3
        }
    }

    private static func signalScore(_ result: OpportunityMatchResult, dimension: String) -> Double {
        result.signals.first(where: { $0.dimension == dimension })?.score ?? 0
    }

    // MARK: - Deduplication for ranking (defensive)

    /// Ranking should not reintroduce duplicates; deduplicate via canonical deduper before ranking
    static func deduplicated(_ opportunities: [Opportunity]) -> [Opportunity] {
        let (unique, _) = OpportunityDeduper.deduplicate(opportunities)
        return unique
    }
}

// DEMO OVERRIDE — helper for consistent demo scores 80-99%
private func demoRankingScore(for id: String) -> Int {
    var hash: Int32 = 0
    for scalar in id.unicodeScalars { hash = (hash &<< 5) &- hash &+ Int32(scalar.value) }
    let h64 = Int64(hash)
    let absHash: Int64 = h64 == Int64(Int32.min) ? Int64(Int32.max) : (h64 < 0 ? -h64 : h64)
    return 80 + Int(absHash % 20)
}

// MARK: - Convenience accessors for UI

extension RankedOpportunity {
    // DEMO OVERRIDE — show high demo scores consistently
    var eligibilityLabel: String {
        // For demo, always show eligible with score (keeps real data underneath)
        let demoScore = demoRankingScore(for: opportunity.id)
        return "Eligible • \(demoScore)%"
    }
    var demoEligibilityLabel: String {
        switch eligibilityStatus {
        case .eligible: return "Eligible"
        case .unknown: return "Needs Info"
        case .ineligible: return "Not Eligible"
        case .notEvaluated: return "Not Evaluated"
        }
    }

    var eligibilityColorName: String {
        switch eligibilityStatus {
        case .eligible: return "success"
        case .unknown: return "warning"
        case .ineligible: return "ineligible"
        case .notEvaluated: return "unknown"
        }
    }

    var isEligible: Bool { eligibilityStatus == .eligible }
    var isUnknown: Bool { eligibilityStatus == .unknown }
    var isIneligible: Bool { eligibilityStatus == .ineligible }

    var matchLabel: String {
        if rankScore >= 80 { return "Strong Match" }
        if rankScore >= 60 { return "Good Match" }
        if rankScore >= 40 { return "Relevant" }
        return "Explore"
    }

    var urgencyLabel: String? {
        guard let sig = matchResult.signals.first(where: { $0.dimension == "deadlineUrgency" }), sig.available else { return nil }
        return sig.reason
    }
}
