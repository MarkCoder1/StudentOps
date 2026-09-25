import Foundation

// MARK: - Career Ranking Engine (Phase 11A)
// Deterministic ranking for multiple careers. No AI, no randomness.

struct RankedCareer: Identifiable, Hashable {
    let career: Career
    let alignment: CareerAlignmentResult
    var id: String { career.id }
    var score: Int { alignment.score }
}

enum CareerRankingEngine {

    static func rank(
        careers: [Career] = CareerCatalog.all,
        profile: StudentProfile,
        progress: [String: Int] = [:],
        activeRoadmaps: [String: ActiveRoadmap] = [:],
        customProjects: [Project] = [],
        evidenceRecords: [String: EvidenceRecord] = [:],
        catalog: [Roadmap] = [],
        opportunities: [Opportunity] = []
    ) -> [RankedCareer] {
        let results = careers.map {
            CareerIntelligenceEngine.alignment(career: $0, profile: profile, progress: progress, activeRoadmaps: activeRoadmaps, customProjects: customProjects, evidenceRecords: evidenceRecords, catalog: catalog, opportunities: opportunities)
        }
        var ranked = results.map { RankedCareer(career: CareerCatalog.career(for: $0.careerID)!, alignment: $0) }
        ranked.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            // skill-gap relevance (higher coverage first) — use skillCoverage
            if a.alignment.skillCoverage != b.alignment.skillCoverage { return a.alignment.skillCoverage > b.alignment.skillCoverage }
            // roadmap alignment
            let aRoad = a.alignment.signals.first(where: { $0.dimension == "roadmapAlignment" })?.score ?? 0
            let bRoad = b.alignment.signals.first(where: { $0.dimension == "roadmapAlignment" })?.score ?? 0
            if aRoad != bRoad { return aRoad > bRoad }
            // project continuity
            let aProj = a.alignment.signals.first(where: { $0.dimension == "projectContinuity" })?.score ?? 0
            let bProj = b.alignment.signals.first(where: { $0.dimension == "projectContinuity" })?.score ?? 0
            if aProj != bProj { return aProj > bProj }
            // title asc
            if a.career.title.lowercased() != b.career.title.lowercased() { return a.career.title.lowercased() < b.career.title.lowercased() }
            // id asc
            return a.career.id < b.career.id
        }
        return ranked
    }

    @MainActor
    static func rank(profile: StudentProfile, store: AppDataStore) -> [RankedCareer] {
        rank(profile: profile, progress: store.roadmapProgress, activeRoadmaps: store.activeRoadmaps, customProjects: store.customProjects, evidenceRecords: store.evidenceRecords, catalog: RoadmapService.allRoadmaps, opportunities: store.opportunities)
    }

    static func top(_ n: Int, profile: StudentProfile, store: AppDataStore) -> [RankedCareer] {
        Array(rank(profile: profile, store: store).prefix(max(0, n)))
    }
}
