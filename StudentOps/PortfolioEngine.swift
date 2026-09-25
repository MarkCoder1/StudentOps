import Foundation

// MARK: - Portfolio Candidate Type

enum PortfolioCandidateType: String, Codable, Hashable, CaseIterable {
    case project = "project"
    case achievement = "achievement"
    case evidence = "evidence"
    case skill = "skill"
    case roadmap = "roadmap"
}

// MARK: - Portfolio Candidate Signal (explainable, deterministic)

enum PortfolioCandidateSignal: String, Codable, Hashable, CaseIterable {
    case completed
    case partiallyCompleted
    case hasEvidence
    case hasMultipleEvidence
    case hasArtifact
    case hasDescription
    case hasSkills
    case hasMultipleSkills
    case hasValidation
    case hasValidationPassed
    case hasRoadmapConnection
    case supportsActiveRoadmap
    case hasProjectConnection
    case hasOpportunityConnection
    case hasAchievementConnection
    case hasAchievements
    case recent
    case highEvidenceQuality
    case solidEvidenceQuality
    case demonstratesSkill
    case active
    case meaningfulProgress
    case verified
}

// MARK: - Portfolio Candidate

struct PortfolioCandidate: Identifiable, Hashable, Codable {
    let id: String // deterministic: "<type>:<sourceID>"
    let type: PortfolioCandidateType
    let sourceID: String
    let title: String
    let score: Int // 0-100 bounded
    let signals: [PortfolioCandidateSignal]
    let reason: String
    let relatedSkillIDs: [String]
    let relatedRoadmapIDs: [String]
    let evidenceCount: Int
    let createdAt: Date?
    let occurredAt: Date?

    var isRecommended: Bool { score >= 40 }
}

// MARK: - Portfolio Reference Issue (stale portfolio references)

struct PortfolioReferenceIssue: Identifiable, Hashable, Codable {
    let id: String // "<type>:<sourceID>"
    let type: PortfolioCandidateType
    let sourceID: String
    let reason: String
}

// MARK: - Reports

struct PortfolioCandidateReport: Hashable, Codable {
    let projects: [PortfolioCandidate]
    let achievements: [PortfolioCandidate]
    let evidence: [PortfolioCandidate]
    let skills: [PortfolioCandidate]
    let roadmaps: [PortfolioCandidate]
    let unresolvedReferences: [PortfolioReferenceIssue]
    let asOf: Date
    let generatedAt: Date

    var allCandidates: [PortfolioCandidate] {
        projects + achievements + evidence + skills + roadmaps
    }

    var recommended: [PortfolioCandidate] {
        allCandidates.filter { $0.isRecommended }.sorted { $0.score > $1.score }
    }
}

enum PortfolioCandidateStatus: String, Codable, Hashable {
    case alreadySelected
    case recommended
    case notRecommended
}

struct PortfolioEvaluatedCandidate: Identifiable, Hashable, Codable {
    let candidate: PortfolioCandidate
    let status: PortfolioCandidateStatus
    var id: String { candidate.id }
}

struct PortfolioEvaluationReport: Hashable, Codable {
    let portfolioID: String
    let candidates: [PortfolioEvaluatedCandidate]
    let unresolvedReferences: [PortfolioReferenceIssue]
    let asOf: Date
}

// MARK: - Portfolio Engine (deterministic, read-only, career-agnostic)

enum PortfolioEngine {

    // MARK: - Public API (AppDataStore convenience)

    /// Deterministic candidates from canonical student data (read-only, no portfolio mutation).
    /// Uses `asOf` for recency so tests are deterministic; do not use `Date()` inside scoring.
    @MainActor
    static func candidates(store: AppDataStore, asOf: Date) -> PortfolioCandidateReport {
        let catalog = RoadmapService.allRoadmaps
        let projects = store.scoredProjects.map(\.project)
        return evaluate(
            profile: store.profile,
            projectProgress: store.projectProgress,
            roadmapProgress: store.roadmapProgress,
            evidenceRecords: store.evidenceRecords,
            achievementRecords: store.achievementRecords,
            activeRoadmaps: store.activeRoadmaps,
            completedActionIDs: store.completedActionIDs,
            projects: projects,
            roadmaps: catalog,
            asOf: asOf
        )
    }

    /// Portfolio-specific evaluation: distinguishes alreadySelected / recommended / notRecommended without mutating portfolio.
    @MainActor
    static func evaluation(for portfolio: StudentPortfolio, store: AppDataStore, asOf: Date) -> PortfolioEvaluationReport {
        let report = candidates(store: store, asOf: asOf)
        let unresolved = unresolvedReferences(for: portfolio, store: store)
        var evaluated: [PortfolioEvaluatedCandidate] = []
        for cand in report.allCandidates {
            let status: PortfolioCandidateStatus
            if isCandidate(cand, alreadySelectedIn: portfolio) {
                status = .alreadySelected
            } else if cand.isRecommended {
                status = .recommended
            } else {
                status = .notRecommended
            }
            evaluated.append(PortfolioEvaluatedCandidate(candidate: cand, status: status))
        }
        // Deterministic ordering: score desc, title asc, sourceID asc
        evaluated.sort {
            if $0.candidate.score != $1.candidate.score { return $0.candidate.score > $1.candidate.score }
            if $0.candidate.title != $1.candidate.title { return $0.candidate.title < $1.candidate.title }
            return $0.candidate.sourceID < $1.candidate.sourceID
        }
        return PortfolioEvaluationReport(portfolioID: portfolio.id, candidates: evaluated, unresolvedReferences: unresolved, asOf: asOf)
    }

    /// Pure evaluation from raw canonical data (no MainActor, fully testable).
    static func evaluate(
        profile: StudentProfile,
        projectProgress: [String: Int],
        roadmapProgress: [String: Int],
        evidenceRecords: [String: EvidenceRecord],
        achievementRecords: [String: Achievement],
        activeRoadmaps: [String: ActiveRoadmap],
        completedActionIDs: Set<String>,
        projects: [Project],
        roadmaps: [Roadmap],
        asOf: Date
    ) -> PortfolioCandidateReport {
        let demonstrated = SkillGapEngine.demonstratedSkillIDs(
            profile: profile,
            roadmapProgress: roadmapProgress,
            catalog: roadmaps,
            evidenceRecords: evidenceRecords
        )
        let activeRoadmapIDs = Set(activeRoadmaps.filter { $0.value.status == .active }.map(\.key))

        let projectCands = projectCandidates(
            projects: projects,
            projectProgress: projectProgress,
            evidenceRecords: evidenceRecords,
            achievementRecords: achievementRecords,
            activeRoadmapIDs: activeRoadmapIDs,
            demonstratedSkillIDs: demonstrated,
            asOf: asOf
        )
        let achievementCands = achievementCandidates(
            achievementRecords: achievementRecords,
            evidenceRecords: evidenceRecords,
            roadmapProgress: roadmapProgress,
            activeRoadmapIDs: activeRoadmapIDs,
            asOf: asOf
        )
        let evidenceCands = evidenceCandidates(
            evidenceRecords: evidenceRecords,
            activeRoadmapIDs: activeRoadmapIDs,
            demonstratedSkillIDs: demonstrated,
            asOf: asOf
        )
        let skillCands = skillCandidates(
            demonstratedSkillIDs: demonstrated,
            evidenceRecords: evidenceRecords,
            achievementRecords: achievementRecords,
            projects: projects,
            projectProgress: projectProgress,
            roadmaps: roadmaps,
            activeRoadmapIDs: activeRoadmapIDs,
            asOf: asOf
        )
        let roadmapCands = roadmapCandidates(
            roadmaps: roadmaps,
            roadmapProgress: roadmapProgress,
            evidenceRecords: evidenceRecords,
            achievementRecords: achievementRecords,
            activeRoadmapIDs: activeRoadmapIDs,
            completedActionIDs: completedActionIDs,
            demonstratedSkillIDs: demonstrated,
            asOf: asOf
        )

        return PortfolioCandidateReport(
            projects: projectCands,
            achievements: achievementCands,
            evidence: evidenceCands,
            skills: skillCands,
            roadmaps: roadmapCands,
            unresolvedReferences: [],
            asOf: asOf,
            generatedAt: Date()
        )
    }

    // MARK: - Stale Reference Handling (read-only)

    /// Returns deterministic unresolved references for a portfolio's selected IDs that have no canonical record.
    /// Does NOT mutate the portfolio (Phase 8.1 deliberately preserves stale IDs).
    @MainActor
    static func unresolvedReferences(for portfolio: StudentPortfolio, store: AppDataStore) -> [PortfolioReferenceIssue] {
        let catalog = RoadmapService.allRoadmaps
        let projectIDs = Set(store.scoredProjects.map(\.project.id))
        let roadmapIDs = Set(catalog.map(\.id))
        let demonstrated = SkillGapEngine.demonstratedSkillIDs(
            profile: store.profile,
            roadmapProgress: store.roadmapProgress,
            catalog: catalog,
            evidenceRecords: store.evidenceRecords
        )
        return unresolvedReferences(
            portfolio: portfolio,
            knownProjectIDs: projectIDs,
            knownAchievementIDs: Set(store.achievementRecords.keys),
            knownEvidenceIDs: Set(store.evidenceRecords.keys),
            knownSkillIDs: demonstrated, // skills considered known only if demonstrated (strict)
            knownRoadmapIDs: roadmapIDs
        )
    }

    static func unresolvedReferences(
        portfolio: StudentPortfolio,
        knownProjectIDs: Set<String>,
        knownAchievementIDs: Set<String>,
        knownEvidenceIDs: Set<String>,
        knownSkillIDs: Set<String>,
        knownRoadmapIDs: Set<String>
    ) -> [PortfolioReferenceIssue] {
        var out: [PortfolioReferenceIssue] = []
        for pid in portfolio.selectedProjectIDs where !knownProjectIDs.contains(pid) {
            out.append(PortfolioReferenceIssue(id: "project:\(pid)", type: .project, sourceID: pid, reason: "No canonical project found for \(pid)"))
        }
        for aid in portfolio.selectedAchievementIDs where !knownAchievementIDs.contains(aid) {
            out.append(PortfolioReferenceIssue(id: "achievement:\(aid)", type: .achievement, sourceID: aid, reason: "No canonical achievement found for \(aid)"))
        }
        for eid in portfolio.selectedEvidenceIDs where !knownEvidenceIDs.contains(eid) {
            out.append(PortfolioReferenceIssue(id: "evidence:\(eid)", type: .evidence, sourceID: eid, reason: "No canonical evidence found for \(eid)"))
        }
        for sid in portfolio.selectedSkillIDs {
            let norm = Skill.normalizeID(sid)
            if !knownSkillIDs.contains(norm) {
                out.append(PortfolioReferenceIssue(id: "skill:\(sid)", type: .skill, sourceID: sid, reason: "Skill not demonstrated: \(sid)"))
            }
        }
        for rid in portfolio.selectedRoadmapIDs where !knownRoadmapIDs.contains(rid) {
            out.append(PortfolioReferenceIssue(id: "roadmap:\(rid)", type: .roadmap, sourceID: rid, reason: "No canonical roadmap found for \(rid)"))
        }
        // Deterministic ordering
        out.sort { $0.id < $1.id }
        return out
    }

    // MARK: - Project Candidates

    private static func projectCandidates(
        projects: [Project],
        projectProgress: [String: Int],
        evidenceRecords: [String: EvidenceRecord],
        achievementRecords: [String: Achievement],
        activeRoadmapIDs: Set<String>,
        demonstratedSkillIDs: Set<String>,
        asOf: Date
    ) -> [PortfolioCandidate] {
        // Pre-group evidence/achievements by projectID for efficiency
        var evidenceByProject: [String: [EvidenceRecord]] = [:]
        for rec in evidenceRecords.values where rec.projectID != nil {
            let pid = rec.projectID!.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pid.isEmpty { evidenceByProject[pid, default: []].append(rec) }
        }
        var achievementByProject: [String: [Achievement]] = [:]
        for ach in achievementRecords.values where ach.projectID != nil {
            let pid = ach.projectID!.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pid.isEmpty { achievementByProject[pid, default: []].append(ach) }
        }

        var out: [PortfolioCandidate] = []
        var seen = Set<String>()

        for project in projects {
            let pid = project.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pid.isEmpty else { continue }
            let dedupKey = "project:\(pid)"
            guard !seen.contains(dedupKey) else { continue }
            seen.insert(dedupKey)

            let completed = min(projectProgress[pid] ?? 0, project.milestones.count)
            let total = project.milestones.count
            let evidenceForProject = evidenceByProject[pid] ?? []
            let achievementsForProject = achievementByProject[pid] ?? []

            // Filtering: untouched project with zero activity is not a strong portfolio candidate
            // Career-agnostic: same rule for all projects
            let isMeaningful = completed > 0 || !evidenceForProject.isEmpty || !achievementsForProject.isEmpty
            guard isMeaningful else { continue }

            var score = 0
            var signals: [PortfolioCandidateSignal] = []

            // Completion signals (bounded)
            if total > 0 && completed >= total {
                score += 20; signals.append(.completed)
            } else if completed > 0 {
                score += 10; signals.append(.partiallyCompleted)
            }

            // Evidence
            if !evidenceForProject.isEmpty {
                score += 15; signals.append(.hasEvidence)
                if evidenceForProject.count >= 2 {
                    score += 5; signals.append(.hasMultipleEvidence)
                }
            }

            // Artifact (any evidence with valid http/https artifact URL)
            let hasArtifact = evidenceForProject.contains { isValidArtifact($0.artifact) }
            if hasArtifact {
                score += 12; signals.append(.hasArtifact)
            }

            // Skills (project declares skills)
            if !project.skills.isEmpty {
                score += 10; signals.append(.hasSkills)
                if project.skills.count >= 3 {
                    score += 2; signals.append(.hasMultipleSkills)
                }
                // Demonstrates at least one skill actually demonstrated (not just referenced)
                let projectSkillIDs = project.skills.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }
                if projectSkillIDs.contains(where: { demonstratedSkillIDs.contains($0) }) {
                    score += 5; signals.append(.demonstratesSkill)
                }
            }

            // Description (meaningful project context)
            let descCount = project.description.trimmingCharacters(in: .whitespacesAndNewlines).count
            if descCount > 10 {
                score += 5; signals.append(.hasDescription)
            }

            // Roadmap connection
            if let src = project.sourceRoadmapID?.trimmingCharacters(in: .whitespacesAndNewlines), !src.isEmpty {
                signals.append(.hasRoadmapConnection)
                if activeRoadmapIDs.contains(src) {
                    score += 10; signals.append(.supportsActiveRoadmap)
                } else {
                    score += 4
                }
            }

            // Achievement connection
            if !achievementsForProject.isEmpty {
                score += 10; signals.append(.hasAchievementConnection)
                if achievementsForProject.count >= 2 { score += 2 }
            }

            // Recency (any evidence for project within 180 days of asOf)
            let latestDate = evidenceForProject.compactMap { $0.occurredAt ?? $0.createdAt }.max()
            if let d = latestDate, isRecent(date: d, asOf: asOf) {
                score += 5; signals.append(.recent)
            }

            // Quality (strong/solid from EvidenceQualityEngine)
            let hasStrong = evidenceForProject.contains { EvidenceQualityEngine.quality(for: $0).overallLevel == .strong }
            let hasSolid = evidenceForProject.contains { EvidenceQualityEngine.quality(for: $0).overallLevel == .solid }
            if hasStrong {
                score += 3; signals.append(.highEvidenceQuality)
            } else if hasSolid {
                score += 2; signals.append(.solidEvidenceQuality)
            }

            score = min(score, 100)
            let reason = buildProjectReason(project: project, completed: completed, total: total, evidenceCount: evidenceForProject.count, signals: signals)
            let relatedSkillIDs = project.skills.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }.sorted()
            let relatedRoadmapIDs = project.sourceRoadmapID.map { [$0] } ?? []

            let cand = PortfolioCandidate(
                id: dedupKey,
                type: .project,
                sourceID: pid,
                title: project.title,
                score: score,
                signals: signals.sorted { $0.rawValue < $1.rawValue },
                reason: reason,
                relatedSkillIDs: relatedSkillIDs,
                relatedRoadmapIDs: relatedRoadmapIDs,
                evidenceCount: evidenceForProject.count,
                createdAt: nil,
                occurredAt: latestDate
            )
            out.append(cand)
        }

        // Deterministic ordering: score desc, title asc, sourceID asc
        out.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.sourceID < $1.sourceID
        }
        return out
    }

    // MARK: - Achievement Candidates

    private static func achievementCandidates(
        achievementRecords: [String: Achievement],
        evidenceRecords: [String: EvidenceRecord],
        roadmapProgress: [String: Int],
        activeRoadmapIDs: Set<String>,
        asOf: Date
    ) -> [PortfolioCandidate] {
        var out: [PortfolioCandidate] = []
        var seen = Set<String>()

        // Deterministic iteration: sorted by id
        let sortedAch = achievementRecords.values.sorted { $0.id < $1.id }

        for ach in sortedAch {
            let aid = ach.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !aid.isEmpty else { continue }
            let dedupKey = "achievement:\(aid)"
            guard !seen.contains(dedupKey) else { continue }
            seen.insert(dedupKey)

            // Filter: invalid record (empty title) should have been rejected at store, but guard anyway
            let titleTrim = ach.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !titleTrim.isEmpty else { continue }
            // Suppressed generated achievements are already removed from achievementRecords via consistency engine,
            // so any remaining record is considered valid. Student-created and valid generated both eligible.

            let evidenceSupport = ach.evidenceIDs.compactMap { evidenceRecords[$0] }
            // Note: achievementRecords store already filters to existing evidence, but we re-evaluate

            var score = 0
            var signals: [PortfolioCandidateSignal] = []

            // Supporting evidence
            if !evidenceSupport.isEmpty {
                score += 20; signals.append(.hasEvidence)
                if evidenceSupport.count >= 2 {
                    score += 5; signals.append(.hasMultipleEvidence)
                }
                // Quality
                let hasStrong = evidenceSupport.contains { EvidenceQualityEngine.quality(for: $0).overallLevel == .strong }
                let hasSolid = evidenceSupport.contains { EvidenceQualityEngine.quality(for: $0).overallLevel == .solid }
                if hasStrong {
                    score += 10; signals.append(.highEvidenceQuality)
                } else if hasSolid {
                    score += 5; signals.append(.solidEvidenceQuality)
                }
                // Artifact
                if evidenceSupport.contains(where: { isValidArtifact($0.artifact) }) {
                    score += 10; signals.append(.hasArtifact)
                }
                // Validation passed
                if evidenceSupport.contains(where: { $0.validationPassed == true }) {
                    score += 5; signals.append(.hasValidationPassed)
                } else if evidenceSupport.contains(where: { $0.validationID != nil }) {
                    score += 2; signals.append(.hasValidation)
                }
            } else {
                // No supporting evidence: still candidate but lower support (career-agnostic, no exclusion)
                // Score remains low; reason will reflect limited support
            }

            // Skills
            let hasSkills = !(ach.skillIDs?.isEmpty ?? true)
            if hasSkills {
                score += 10; signals.append(.hasSkills)
                if (ach.skillIDs?.count ?? 0) >= 2 {
                    score += 2; signals.append(.hasMultipleSkills)
                }
            }

            // Roadmap connection
            if let rid = ach.roadmapID?.trimmingCharacters(in: .whitespacesAndNewlines), !rid.isEmpty {
                signals.append(.hasRoadmapConnection)
                if activeRoadmapIDs.contains(rid) {
                    score += 10; signals.append(.supportsActiveRoadmap)
                } else if (roadmapProgress[rid] ?? 0) > 0 {
                    score += 4
                } else {
                    score += 2
                }
            }

            // Project connection
            if let pid = ach.projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
                score += 10; signals.append(.hasProjectConnection)
            }

            // Opportunity connection
            if let oid = ach.opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines), !oid.isEmpty {
                score += 5; signals.append(.hasOpportunityConnection)
            }

            // Description
            if let desc = ach.description?.trimmingCharacters(in: .whitespacesAndNewlines), desc.count > 10 {
                score += 5; signals.append(.hasDescription)
            }

            // Recency (occurredAt preferred)
            let date = ach.occurredAt ?? ach.createdAt
            if isRecent(date: date, asOf: asOf) {
                score += 5; signals.append(.recent)
            }

            // Verified status is not required; recorded is default. No extra bonus for verified (remains deterministic).

            score = min(score, 100)
            let reason = buildAchievementReason(achievement: ach, evidenceCount: evidenceSupport.count, signals: signals)
            let relatedSkillIDs = ach.skillIDs ?? []
            var relatedRoadmapIDs: [String] = []
            if let r = ach.roadmapID, !r.isEmpty { relatedRoadmapIDs.append(r) }

            let cand = PortfolioCandidate(
                id: dedupKey,
                type: .achievement,
                sourceID: aid,
                title: titleTrim,
                score: score,
                signals: signals.sorted { $0.rawValue < $1.rawValue },
                reason: reason,
                relatedSkillIDs: relatedSkillIDs.sorted(),
                relatedRoadmapIDs: relatedRoadmapIDs,
                evidenceCount: evidenceSupport.count,
                createdAt: ach.createdAt,
                occurredAt: ach.occurredAt
            )
            out.append(cand)
        }

        out.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.sourceID < $1.sourceID
        }
        return out
    }

    // MARK: - Evidence Candidates

    private static func evidenceCandidates(
        evidenceRecords: [String: EvidenceRecord],
        activeRoadmapIDs: Set<String>,
        demonstratedSkillIDs: Set<String>,
        asOf: Date
    ) -> [PortfolioCandidate] {
        var out: [PortfolioCandidate] = []
        var seen = Set<String>()
        let sorted = evidenceRecords.values.sorted { $0.id < $1.id }

        for rec in sorted {
            let eid = rec.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !eid.isEmpty else { continue }
            let dedupKey = "evidence:\(eid)"
            guard !seen.contains(dedupKey) else { continue }
            seen.insert(dedupKey)

            // Filter: evidence with empty title is invalid and would have been rejected; guard anyway
            let titleTrim = rec.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !titleTrim.isEmpty else { continue }

            let quality = EvidenceQualityEngine.quality(for: rec)
            var score = 0
            var signals: [PortfolioCandidateSignal] = []

            switch quality.overallLevel {
            case .strong:
                score += 20; signals.append(.highEvidenceQuality)
            case .solid:
                score += 10; signals.append(.solidEvidenceQuality)
            case .basic:
                break
            }

            if isValidArtifact(rec.artifact) {
                score += 15; signals.append(.hasArtifact)
            }

            if let pid = rec.projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
                score += 10; signals.append(.hasProjectConnection)
            }

            if !rec.roadmapID.isEmpty && !rec.milestoneID.isEmpty {
                signals.append(.hasRoadmapConnection)
                if activeRoadmapIDs.contains(rec.roadmapID) {
                    score += 10; signals.append(.supportsActiveRoadmap)
                } else {
                    score += 5
                }
            }

            if let oid = rec.opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines), !oid.isEmpty {
                score += 10; signals.append(.hasOpportunityConnection)
            }

            if !(rec.skillIDs?.isEmpty ?? true) {
                score += 10; signals.append(.hasSkills)
                if (rec.skillIDs?.count ?? 0) >= 2 {
                    score += 3; signals.append(.hasMultipleSkills)
                }
                // Demonstrates at least one skill that is actually demonstrated (not just referenced)
                let recSkillIDs = rec.skillIDs?.map { Skill.normalizeID($0) }.filter { !$0.isEmpty } ?? []
                if recSkillIDs.contains(where: { demonstratedSkillIDs.contains($0) }) {
                    // Small bonus, but quality not the only signal
                    score += 2; signals.append(.demonstratesSkill)
                }
            }

            if let desc = rec.description?.trimmingCharacters(in: .whitespacesAndNewlines), desc.count > 10 {
                score += 10; signals.append(.hasDescription)
            }

            if rec.validationPassed == true {
                score += 5; signals.append(.hasValidationPassed)
            } else if rec.validationID != nil {
                score += 2; signals.append(.hasValidation)
            }

            let date = rec.occurredAt ?? rec.createdAt
            if isRecent(date: date, asOf: asOf) {
                score += 5; signals.append(.recent)
            }

            if rec.source == .roadmapMilestone {
                score += 5; signals.append(.verified)
            }

            score = min(score, 100)
            let reason = buildEvidenceReason(record: rec, quality: quality, signals: signals)
            let relatedSkillIDs = rec.skillIDs ?? []
            let relatedRoadmapIDs = rec.roadmapID.isEmpty ? [] : [rec.roadmapID]

            let cand = PortfolioCandidate(
                id: dedupKey,
                type: .evidence,
                sourceID: eid,
                title: titleTrim,
                score: score,
                signals: signals.sorted { $0.rawValue < $1.rawValue },
                reason: reason,
                relatedSkillIDs: relatedSkillIDs.sorted(),
                relatedRoadmapIDs: relatedRoadmapIDs,
                evidenceCount: 1,
                createdAt: rec.createdAt,
                occurredAt: rec.occurredAt
            )
            out.append(cand)
        }

        out.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.sourceID < $1.sourceID
        }
        return out
    }

    // MARK: - Skill Candidates

    private static func skillCandidates(
        demonstratedSkillIDs: Set<String>,
        evidenceRecords: [String: EvidenceRecord],
        achievementRecords: [String: Achievement],
        projects: [Project],
        projectProgress: [String: Int],
        roadmaps: [Roadmap],
        activeRoadmapIDs: Set<String>,
        asOf: Date
    ) -> [PortfolioCandidate] {
        // Only demonstrated skills are candidates (referenced != demonstrated)
        // This uses SkillGapEngine as authoritative source.
        guard !demonstratedSkillIDs.isEmpty else { return [] }

        // Precompute supporting counts
        var evidenceCountBySkill: [String: Int] = [:]
        var achievementCountBySkill: [String: Int] = [:]
        var projectCountBySkill: [String: Int] = [:]
        var latestDateBySkill: [String: Date] = [:]

        for rec in evidenceRecords.values where rec.skillIDs != nil {
            for raw in rec.skillIDs! {
                let norm = Skill.normalizeID(raw)
                guard demonstratedSkillIDs.contains(norm) else { continue }
                evidenceCountBySkill[norm, default: 0] += 1
                let d = rec.occurredAt ?? rec.createdAt
                if let existing = latestDateBySkill[norm] {
                    if d > existing { latestDateBySkill[norm] = d }
                } else {
                    latestDateBySkill[norm] = d
                }
            }
        }

        for ach in achievementRecords.values where ach.skillIDs != nil {
            for raw in ach.skillIDs! {
                let norm = Skill.normalizeID(raw)
                guard demonstratedSkillIDs.contains(norm) else { continue }
                achievementCountBySkill[norm, default: 0] += 1
                let d = ach.occurredAt ?? ach.createdAt
                if let existing = latestDateBySkill[norm] {
                    if d > existing { latestDateBySkill[norm] = d }
                } else {
                    latestDateBySkill[norm] = d
                }
            }
        }

        // Projects that actually have progress/evidence and declare skill
        for proj in projects {
            let completed = min(projectProgress[proj.id] ?? 0, proj.milestones.count)
            let hasEvidence = evidenceRecords.values.contains { $0.projectID == proj.id }
            let isActive = completed > 0 || hasEvidence
            guard isActive else { continue }
            for raw in proj.skills {
                let norm = Skill.normalizeID(raw)
                guard demonstratedSkillIDs.contains(norm) else { continue }
                projectCountBySkill[norm, default: 0] += 1
            }
        }

        // Active roadmap required skills
        var requiredByActive: Set<String> = []
        for roadmap in roadmaps where activeRoadmapIDs.contains(roadmap.id) {
            for skill in SkillGapEngine.requiredSkills(for: roadmap) {
                if demonstratedSkillIDs.contains(skill.id) {
                    requiredByActive.insert(skill.id)
                }
            }
        }

        var out: [PortfolioCandidate] = []
        var seen = Set<String>()
        let sortedIDs = demonstratedSkillIDs.sorted()

        for sid in sortedIDs {
            let norm = Skill.normalizeID(sid)
            guard !norm.isEmpty else { continue }
            let dedupKey = "skill:\(norm)"
            guard !seen.contains(dedupKey) else { continue }
            seen.insert(dedupKey)

            let skill = SkillCatalog.knownSkills[norm] ?? Skill(id: norm, name: sid)
            let eCount = evidenceCountBySkill[norm] ?? 0
            let aCount = achievementCountBySkill[norm] ?? 0
            let pCount = projectCountBySkill[norm] ?? 0
            let totalSupport = eCount + aCount + pCount

            var score = 0
            var signals: [PortfolioCandidateSignal] = []

            // Base demonstrated
            score += 10; signals.append(.demonstratesSkill)

            // Connected to completed work
            if totalSupport > 0 {
                score += 20; signals.append(.hasEvidence)
                if totalSupport >= 2 {
                    score += 15; signals.append(.hasMultipleEvidence)
                }
                if totalSupport >= 3 {
                    score += 5
                }
            }

            // Multiple records (evidence/achievement)
            if eCount >= 1 && aCount >= 1 {
                score += 5; // both evidence and achievement
            }

            // Project connection
            if pCount > 0 {
                score += 15; signals.append(.hasProjectConnection)
            }

            // Achievement connection
            if aCount > 0 {
                score += 10; signals.append(.hasAchievementConnection)
            }

            // Supports active roadmap
            if requiredByActive.contains(norm) {
                score += 15; signals.append(.supportsActiveRoadmap)
            } else if !requiredByActive.isEmpty {
                // Check if required by any roadmap at all (even inactive) — small bonus
                let requiredByAny = roadmaps.contains { rm in
                    SkillGapEngine.requiredSkills(for: rm).contains(where: { $0.id == norm })
                }
                if requiredByAny {
                    score += 5; signals.append(.hasRoadmapConnection)
                }
            }

            // Recent activity for skill
            if let latest = latestDateBySkill[norm], isRecent(date: latest, asOf: asOf) {
                score += 10; signals.append(.recent)
            }

            // Category / catalog presence
            if SkillCatalog.knownSkills[norm] != nil {
                score += 5; signals.append(.hasSkills)
            }

            score = min(score, 100)
            let reason = buildSkillReason(skill: skill, evidenceCount: eCount, achievementCount: aCount, projectCount: pCount, signals: signals)

            // Related roadmap IDs where skill is required (active only for relevance)
            var relatedRoadmapIDs: [String] = []
            for rm in roadmaps where SkillGapEngine.requiredSkills(for: rm).contains(where: { $0.id == norm }) {
                relatedRoadmapIDs.append(rm.id)
            }
            // Related skills: just itself for simplicity; UI can show connections
            let cand = PortfolioCandidate(
                id: dedupKey,
                type: .skill,
                sourceID: norm,
                title: skill.name,
                score: score,
                signals: signals.sorted { $0.rawValue < $1.rawValue },
                reason: reason,
                relatedSkillIDs: [norm],
                relatedRoadmapIDs: relatedRoadmapIDs.sorted(),
                evidenceCount: totalSupport,
                createdAt: nil,
                occurredAt: latestDateBySkill[norm]
            )
            out.append(cand)
        }

        out.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.sourceID < $1.sourceID
        }
        return out
    }

    // MARK: - Roadmap Candidates

    private static func roadmapCandidates(
        roadmaps: [Roadmap],
        roadmapProgress: [String: Int],
        evidenceRecords: [String: EvidenceRecord],
        achievementRecords: [String: Achievement],
        activeRoadmapIDs: Set<String>,
        completedActionIDs: Set<String>,
        demonstratedSkillIDs: Set<String>,
        asOf: Date
    ) -> [PortfolioCandidate] {
        var out: [PortfolioCandidate] = []
        var seen = Set<String>()

        // Deterministic iteration sorted by id
        let sortedRoadmaps = roadmaps.sorted { $0.id < $1.id }

        for roadmap in sortedRoadmaps {
            let rid = roadmap.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rid.isEmpty else { continue }
            let dedupKey = "roadmap:\(rid)"
            guard !seen.contains(dedupKey) else { continue }
            seen.insert(dedupKey)

            let active = activeRoadmapIDs.contains(rid)
            let completed = min(roadmapProgress[rid] ?? 0, roadmap.milestones.count)
            let total = roadmap.milestones.count
            let evidenceForRoadmap = evidenceRecords.values.filter { $0.roadmapID == rid }
            let achievementsForRoadmap = achievementRecords.values.filter { $0.roadmapID == rid }

            // Filter: zero activity roadmaps are not strong portfolio candidates
            let isMeaningful = active || completed > 0 || !evidenceForRoadmap.isEmpty || !achievementsForRoadmap.isEmpty
            guard isMeaningful else { continue }

            var score = 0
            var signals: [PortfolioCandidateSignal] = []

            if active {
                score += 20; signals.append(.active)
            }

            if completed > 0 {
                score += 15; signals.append(.meaningfulProgress)
                if total > 0 && completed >= total {
                    score += 10; signals.append(.completed)
                } else if completed >= max(1, total / 2) {
                    score += 5; signals.append(.partiallyCompleted)
                }
                // Progress ratio bonus not needed beyond above
            }

            if !evidenceForRoadmap.isEmpty {
                score += 15; signals.append(.hasEvidence)
                if evidenceForRoadmap.count >= 2 {
                    score += 5; signals.append(.hasMultipleEvidence)
                }
            }

            if evidenceForRoadmap.contains(where: { isValidArtifact($0.artifact) }) {
                score += 10; signals.append(.hasArtifact)
            }

            if !achievementsForRoadmap.isEmpty {
                score += 10; signals.append(.hasAchievements)
            }

            // Demonstrated skills for this roadmap
            let required = SkillGapEngine.requiredSkills(for: roadmap)
            let demonstratedForRoadmap = required.filter { demonstratedSkillIDs.contains($0.id) }.count
            if demonstratedForRoadmap > 0 {
                score += 10; signals.append(.demonstratesSkill)
                if demonstratedForRoadmap >= 2 {
                    score += 5; signals.append(.hasMultipleSkills)
                }
            }

            if !required.isEmpty {
                score += 2; signals.append(.hasSkills)
            }

            // Completed actions across roadmap milestones
            let allActionIDs = Set(roadmap.milestones.flatMap { $0.actions ?? [] }.map(\.id))
            let completedActions = completedActionIDs.intersection(allActionIDs).count
            if completedActions > 0 {
                score += 5; // meaningful actions completed
                // Do not reuse hasAchievements signal for actions to keep distinct; but add generic
            }

            // Recent activity
            let latestEvidenceDate = evidenceForRoadmap.compactMap { $0.occurredAt ?? $0.createdAt }.max()
            let latestAchDate = achievementsForRoadmap.compactMap { $0.occurredAt ?? $0.createdAt }.max()
            let latest = [latestEvidenceDate, latestAchDate].compactMap { $0 }.max()
            if let l = latest, isRecent(date: l, asOf: asOf) {
                score += 5; signals.append(.recent)
            }

            score = min(score, 100)
            let reason = buildRoadmapReason(roadmap: roadmap, completed: completed, total: total, active: active, evidenceCount: evidenceForRoadmap.count, signals: signals)
            let relatedSkillIDs = required.map(\.id).sorted()
            let cand = PortfolioCandidate(
                id: dedupKey,
                type: .roadmap,
                sourceID: rid,
                title: roadmap.title,
                score: score,
                signals: signals.sorted { $0.rawValue < $1.rawValue },
                reason: reason,
                relatedSkillIDs: relatedSkillIDs,
                relatedRoadmapIDs: [rid],
                evidenceCount: evidenceForRoadmap.count,
                createdAt: nil,
                occurredAt: latest
            )
            out.append(cand)
        }

        out.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.sourceID < $1.sourceID
        }
        return out
    }

    // MARK: - Helpers

    private static func isRecent(date: Date, asOf: Date) -> Bool {
        // Deterministic recency: within 180 days before asOf, not in future
        // 180 * 24 * 60 * 60 = 15552000 seconds
        let window: TimeInterval = 180 * 24 * 60 * 60
        let diff = asOf.timeIntervalSince(date)
        return diff >= 0 && diff <= window
    }

    private static func isValidArtifact(_ artifact: EvidenceArtifact?) -> Bool {
        guard let art = artifact, let urlStr = art.url?.trimmingCharacters(in: .whitespacesAndNewlines), !urlStr.isEmpty else { return false }
        guard let url = URL(string: urlStr) else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
        return url.host != nil
    }

    private static func isValidURLString(_ str: String) -> Bool {
        let t = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard let url = URL(string: t) else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
        return url.host != nil
    }

    private static func isCandidate(_ candidate: PortfolioCandidate, alreadySelectedIn portfolio: StudentPortfolio) -> Bool {
        switch candidate.type {
        case .project: return portfolio.selectedProjectIDs.contains(candidate.sourceID)
        case .achievement: return portfolio.selectedAchievementIDs.contains(candidate.sourceID)
        case .evidence: return portfolio.selectedEvidenceIDs.contains(candidate.sourceID)
        case .skill: return portfolio.selectedSkillIDs.contains(candidate.sourceID)
        case .roadmap: return portfolio.selectedRoadmapIDs.contains(candidate.sourceID)
        }
    }

    // MARK: Reason Builders (factual, no exaggerated language)

    private static func buildProjectReason(project: Project, completed: Int, total: Int, evidenceCount: Int, signals: [PortfolioCandidateSignal]) -> String {
        var parts: [String] = []
        if signals.contains(.completed) {
            parts.append("Completed project")
        } else if signals.contains(.partiallyCompleted) {
            parts.append("Project with \(completed) of \(total) milestones completed")
        } else {
            parts.append("Project with supporting activity")
        }
        if signals.contains(.hasEvidence) {
            parts.append(evidenceCount == 1 ? "with supporting evidence" : "with \(evidenceCount) supporting evidence records")
        }
        if signals.contains(.hasArtifact) { parts.append("includes an artifact") }
        if signals.contains(.demonstratesSkill) { parts.append("demonstrates skills") }
        else if signals.contains(.hasSkills) { parts.append("references skills") }
        if signals.contains(.supportsActiveRoadmap) { parts.append("connected to an active roadmap") }
        else if signals.contains(.hasRoadmapConnection) { parts.append("connected to a roadmap") }
        if signals.contains(.hasAchievementConnection) { parts.append("linked to achievements") }
        if signals.contains(.highEvidenceQuality) { parts.append("supported by strong evidence") }
        else if signals.contains(.solidEvidenceQuality) { parts.append("supported by solid evidence") }
        if signals.contains(.recent) { parts.append("with recent activity") }
        if parts.isEmpty { return "Project with available activity." }
        return parts.joined(separator: ", ") + "."
    }

    private static func buildAchievementReason(achievement: Achievement, evidenceCount: Int, signals: [PortfolioCandidateSignal]) -> String {
        var parts: [String] = []
        parts.append("Achievement \"\(achievement.title)\"")
        if signals.contains(.hasEvidence) {
            parts.append(evidenceCount == 1 ? "supported by 1 evidence record" : "supported by \(evidenceCount) evidence records")
        } else {
            parts.append("with no supporting evidence")
        }
        if signals.contains(.hasArtifact) { parts.append("includes an artifact") }
        if signals.contains(.hasSkills) { parts.append("references skills") }
        if signals.contains(.supportsActiveRoadmap) { parts.append("connected to an active roadmap") }
        else if signals.contains(.hasRoadmapConnection) { parts.append("connected to a roadmap") }
        if signals.contains(.hasProjectConnection) { parts.append("linked to a project") }
        if signals.contains(.hasOpportunityConnection) { parts.append("linked to an opportunity") }
        if signals.contains(.highEvidenceQuality) { parts.append("supported by strong evidence") }
        if signals.contains(.recent) { parts.append("recent") }
        return parts.joined(separator: ", ") + "."
    }

    private static func buildEvidenceReason(record: EvidenceRecord, quality: EvidenceQualityResult, signals: [PortfolioCandidateSignal]) -> String {
        var parts: [String] = []
        switch quality.overallLevel {
        case .strong: parts.append("Strong evidence")
        case .solid: parts.append("Solid evidence")
        case .basic: parts.append("Evidence")
        }
        if signals.contains(.hasArtifact) { parts.append("with an artifact") }
        if signals.contains(.hasProjectConnection) { parts.append("linked to a project") }
        if signals.contains(.hasRoadmapConnection) {
            if signals.contains(.supportsActiveRoadmap) { parts.append("connected to an active roadmap") }
            else { parts.append("linked to a roadmap") }
        }
        if signals.contains(.hasOpportunityConnection) { parts.append("linked to an opportunity") }
        if signals.contains(.hasSkills) { parts.append(signals.contains(.demonstratesSkill) ? "demonstrates skills" : "references skills") }
        if signals.contains(.hasDescription) { parts.append("includes a description") }
        if signals.contains(.hasValidationPassed) { parts.append("includes a passed validation") }
        if signals.contains(.recent) { parts.append("recent") }
        if parts.isEmpty { return "Evidence with available context." }
        return parts.joined(separator: ", ") + "."
    }

    private static func buildSkillReason(skill: Skill, evidenceCount: Int, achievementCount: Int, projectCount: Int, signals: [PortfolioCandidateSignal]) -> String {
        var parts: [String] = []
        parts.append("Skill \"\(skill.name)\" is demonstrated")
        if evidenceCount > 0 { parts.append("supported by \(evidenceCount) evidence record\(evidenceCount==1 ? "" : "s")") }
        if achievementCount > 0 { parts.append("linked to \(achievementCount) achievement\(achievementCount==1 ? "" : "s")") }
        if projectCount > 0 { parts.append("connected to \(projectCount) project\(projectCount==1 ? "" : "s")") }
        if signals.contains(.supportsActiveRoadmap) { parts.append("supports an active roadmap") }
        if signals.contains(.recent) { parts.append("with recent activity") }
        return parts.joined(separator: ", ") + "."
    }

    private static func buildRoadmapReason(roadmap: Roadmap, completed: Int, total: Int, active: Bool, evidenceCount: Int, signals: [PortfolioCandidateSignal]) -> String {
        var parts: [String] = []
        if active { parts.append("Active roadmap") } else { parts.append("Roadmap") }
        parts.append("with \(completed) of \(total) milestones completed")
        if evidenceCount > 0 { parts.append(evidenceCount == 1 ? "1 evidence record" : "\(evidenceCount) evidence records") }
        if signals.contains(.hasAchievements) { parts.append("linked to achievements") }
        if signals.contains(.demonstratesSkill) { parts.append("demonstrates skills") }
        if signals.contains(.hasArtifact) { parts.append("includes an artifact") }
        if signals.contains(.recent) { parts.append("recent activity") }
        return parts.joined(separator: ", ") + "."
    }
}
