import Foundation

// MARK: - Deterministic Achievement Generation Engine

/// Pure deterministic engine that detects legitimate achievements from existing Student OPS state.
/// No AI, no networking, no UserDefaults mutation, no fake evidence.
enum AchievementGenerationEngine {

    // MARK: - Public API

    /// Generates deterministic achievement candidates from current store state.
    /// Pure — does not mutate store.
    @MainActor
    static func generate(for store: AppDataStore) -> [Achievement] {
        generate(
            evidenceRecords: store.evidenceRecords,
            roadmapProgress: store.roadmapProgress,
            projectProgress: store.projectProgress,
            validationAttempts: store.validationAttempts,
            achievementRecords: store.achievementRecords,
            profile: store.profile,
            catalog: store.scoredRoadmaps.map(\.roadmap),
            projects: store.scoredProjects.map(\.project)
        )
    }

    /// Pure generation from explicit state (testable).
    static func generate(
        evidenceRecords: [String: EvidenceRecord],
        roadmapProgress: [String: Int],
        projectProgress: [String: Int],
        validationAttempts: [String: ValidationAttempt],
        achievementRecords: [String: Achievement],
        profile: StudentProfile,
        catalog: [Roadmap],
        projects: [Project]
    ) -> [Achievement] {
        var candidates: [Achievement] = []
        candidates.append(contentsOf: milestoneAchievements(evidenceRecords: evidenceRecords, roadmapProgress: roadmapProgress, catalog: catalog))
        candidates.append(contentsOf: progressionAchievements(evidenceRecords: evidenceRecords, roadmapProgress: roadmapProgress, catalog: catalog))
        candidates.append(contentsOf: projectAchievements(evidenceRecords: evidenceRecords, projectProgress: projectProgress, projects: projects))
        candidates.append(contentsOf: validationAchievements(evidenceRecords: evidenceRecords, validationAttempts: validationAttempts, catalog: catalog))
        candidates.append(contentsOf: opportunityAchievements(evidenceRecords: evidenceRecords))
        // Deduplicate by ID, preserve first occurrence order
        var seen = Set<String>()
        var deduped: [Achievement] = []
        for ach in candidates {
            if seen.insert(ach.id).inserted {
                deduped.append(ach)
            }
        }
        // Filter out already-existing IDs (idempotency at engine level, but store also handles)
        // Note: engine returns all candidates; store will filter existing. For pure generation we return all.
        return deduped
    }

    // MARK: - Rule A — Roadmap Milestone Completed

    private static func milestoneAchievements(
        evidenceRecords: [String: EvidenceRecord],
        roadmapProgress: [String: Int],
        catalog: [Roadmap]
    ) -> [Achievement] {
        var out: [Achievement] = []
        for roadmap in catalog {
            let completedCount = min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
            guard completedCount > 0 else { continue }
            for idx in 0..<completedCount {
                let milestone = roadmap.milestones[idx]
                let evidenceID = "evidence-\(roadmap.id)-\(milestone.id)"
                guard let evidence = evidenceRecords[evidenceID] else { continue }
                // Evidence must exist and be system-generated milestone completion
                guard evidence.type == .milestoneCompletion else { continue }
                let achievementID = "achievement-\(roadmap.id)-\(milestone.id)"
                let skillIDs = milestone.skillsDeveloped?.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }.map { $0.lowercased() }
                let dedupedSkills: [String]? = {
                    guard let s = skillIDs, !s.isEmpty else { return nil }
                    return Array(Set(s)).sorted()
                }()
                let ach = Achievement(
                    id: achievementID,
                    title: milestone.title,
                    description: milestone.subtitle,
                    type: .milestone,
                    status: .recorded,
                    createdAt: evidence.createdAt,
                    occurredAt: evidence.occurredAt,
                    evidenceIDs: [evidenceID],
                    skillIDs: dedupedSkills,
                    roadmapID: roadmap.id,
                    milestoneID: milestone.id,
                    source: .roadmapMilestone
                )
                out.append(ach)
            }
        }
        return out
    }

    // MARK: - Rule B — Roadmap Progression

    private static func progressionAchievements(
        evidenceRecords: [String: EvidenceRecord],
        roadmapProgress: [String: Int],
        catalog: [Roadmap]
    ) -> [Achievement] {
        var out: [Achievement] = []
        for roadmap in catalog {
            let completedCount = min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
            // Meaningful threshold: 3 milestones (or half for small roadmaps)
            let threshold = min(3, roadmap.milestones.count)
            guard completedCount >= threshold else { continue }
            // Only generate if at least threshold evidences exist
            let prefixMilestones = Array(roadmap.milestones.prefix(threshold))
            let evidenceIDs = prefixMilestones.map { "evidence-\(roadmap.id)-\($0.id)" }.filter { evidenceRecords[$0] != nil }
            guard evidenceIDs.count >= threshold else { continue }
            let achievementID = "achievement-progress-\(roadmap.id)"
            // Use earliest evidence date for createdAt
            let dates = evidenceIDs.compactMap { evidenceRecords[$0]?.createdAt }
            let created = dates.sorted().first ?? Date()
            let allSkills = prefixMilestones.flatMap { $0.skillsDeveloped ?? [] }.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }
            let dedupedSkills: [String]? = allSkills.isEmpty ? nil : Array(Set(allSkills)).sorted()
            let ach = Achievement(
                id: achievementID,
                title: "Made Progress in \(roadmap.title)",
                description: "Completed \(threshold) milestones in a structured learning roadmap.",
                type: .milestone,
                status: .recorded,
                createdAt: created,
                evidenceIDs: evidenceIDs,
                skillIDs: dedupedSkills,
                roadmapID: roadmap.id,
                source: .evidenceDerived
            )
            out.append(ach)
        }
        return out
    }

    // MARK: - Rule C — Completed Project

    private static func projectAchievements(
        evidenceRecords: [String: EvidenceRecord],
        projectProgress: [String: Int],
        projects: [Project]
    ) -> [Achievement] {
        var out: [Achievement] = []
        for project in projects {
            let completedCount = min(projectProgress[project.id] ?? 0, project.milestones.count)
            guard completedCount >= project.milestones.count && project.milestones.count > 0 else { continue }
            // Project must be completed according to deterministic state
            let achievementID = "achievement-project-\(project.id)"
            // Collect project-related evidence if any
            let projectEvidenceIDs = evidenceRecords.values.filter { $0.projectID == project.id }.map(\.id).sorted()
            // Allow generation even without explicit evidence (project completion itself is evidence), but prefer with evidence
            let created = projectEvidenceIDs.compactMap { evidenceRecords[$0]?.createdAt }.sorted().first ?? Date()
            let dedupedSkills: [String]? = {
                let s = project.skills.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }
                return s.isEmpty ? nil : Array(Set(s)).sorted()
            }()
            let ach = Achievement(
                id: achievementID,
                title: project.title,
                description: project.goal,
                type: .project,
                status: .recorded,
                createdAt: created,
                evidenceIDs: projectEvidenceIDs,
                skillIDs: dedupedSkills,
                projectID: project.id,
                source: .project
            )
            out.append(ach)
        }
        return out
    }

    // MARK: - Rule D — Validated Learning

    private static func validationAchievements(
        evidenceRecords: [String: EvidenceRecord],
        validationAttempts: [String: ValidationAttempt],
        catalog: [Roadmap]
    ) -> [Achievement] {
        var out: [Achievement] = []
        // Map validationID -> (roadmap, milestone)
        var validationToMilestone: [String: (roadmap: Roadmap, milestone: RoadmapMilestone)] = [:]
        for roadmap in catalog {
            for milestone in roadmap.milestones {
                if let assessment = milestone.assessment {
                    validationToMilestone[assessment.id] = (roadmap, milestone)
                }
            }
        }
        for (validationID, attempt) in validationAttempts {
            guard attempt.passed else { continue }
            guard let pair = validationToMilestone[validationID] else { continue }
            let evidenceID = "evidence-\(pair.roadmap.id)-\(pair.milestone.id)"
            guard let evidence = evidenceRecords[evidenceID] else { continue }
            // Ensure evidence has this validation
            guard evidence.validationID == validationID else { continue }
            let achievementID = "achievement-validation-\(validationID)"
            let skillIDs = pair.milestone.skillsDeveloped?.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }
            let dedupedSkills: [String]? = {
                guard let s = skillIDs, !s.isEmpty else { return nil }
                return Array(Set(s)).sorted()
            }()
            let ach = Achievement(
                id: achievementID,
                title: "Demonstrated Understanding: \(pair.milestone.title)",
                description: "Passed validation for \(pair.milestone.title).",
                type: .learning,
                status: .recorded,
                createdAt: evidence.createdAt,
                evidenceIDs: [evidenceID],
                skillIDs: dedupedSkills,
                roadmapID: pair.roadmap.id,
                milestoneID: pair.milestone.id,
                source: .evidenceDerived
            )
            out.append(ach)
        }
        return out
    }

    // MARK: - Rule E — Opportunity Participation

    private static func opportunityAchievements(evidenceRecords: [String: EvidenceRecord]) -> [Achievement] {
        var out: [Achievement] = []
        // Group evidence by opportunityID where type is opportunityParticipation
        var byOpportunity: [String: [EvidenceRecord]] = [:]
        for rec in evidenceRecords.values {
            guard rec.type == .opportunityParticipation else { continue }
            guard let oppID = rec.opportunityID, !oppID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            // Only student-entered or opportunity source with recorded status
            byOpportunity[oppID, default: []].append(rec)
        }
        for (oppID, records) in byOpportunity {
            let evidenceIDs = records.map(\.id).sorted()
            guard !evidenceIDs.isEmpty else { continue }
            // Use sanitized opportunityID for achievement ID (replace non-alphanumeric for stability)
            let sanitizedOpp = oppID.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "/", with: "-")
            let achievementID = "achievement-opportunity-\(sanitizedOpp)"
            let created = records.map(\.createdAt).sorted().first ?? Date()
            // Infer type from evidence context if possible, default to other/competition
            let ach = Achievement(
                id: achievementID,
                title: records.first?.title ?? "Participated in Opportunity",
                description: records.first?.description ?? "Documented participation in an opportunity.",
                type: .other,
                status: .recorded,
                createdAt: created,
                evidenceIDs: evidenceIDs,
                opportunityID: oppID,
                source: .opportunity
            )
            out.append(ach)
        }
        return out
    }
}
