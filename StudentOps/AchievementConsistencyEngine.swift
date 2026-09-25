import Foundation

// MARK: - Consistency Result Types

enum ConsistencyStatus: String, Codable, Hashable {
    case valid
    case repaired
    case unresolved
    case suppressed
}

struct EvidenceConsistencyIssue: Hashable, Codable {
    let evidenceID: String
    let issueType: String
    let reason: String
    let status: ConsistencyStatus
}

struct AchievementConsistencyIssue: Hashable, Codable {
    let achievementID: String
    let issueType: String
    let reason: String
    let status: ConsistencyStatus
}

struct ReconciliationResult: Hashable, Codable {
    var evidenceRepairs: [String: EvidenceRecord] = [:] // id -> repaired record
    var achievementRepairs: [String: Achievement] = [:] // id -> repaired record
    var suppressedAchievementIDs: [String] = []
    var evidenceIssues: [EvidenceConsistencyIssue] = []
    var achievementIssues: [AchievementConsistencyIssue] = []
    var didChange: Bool { !evidenceRepairs.isEmpty || !achievementRepairs.isEmpty || !suppressedAchievementIDs.isEmpty }
}

// MARK: - Pure Consistency Engine

enum AchievementConsistencyEngine {

    // MARK: - Main Reconciliation

    static func reconcile(
        evidenceRecords: [String: EvidenceRecord],
        achievementRecords: [String: Achievement],
        roadmapProgress: [String: Int],
        projectProgress: [String: Int],
        validationAttempts: [String: ValidationAttempt],
        catalog: [Roadmap],
        projects: [Project]
    ) -> ReconciliationResult {
        var result = ReconciliationResult()

        // Build lookup sets
        let roadmapIDs = Set(catalog.map(\.id))
        var milestoneIDsByRoadmap: [String: Set<String>] = [:]
        for roadmap in catalog {
            milestoneIDsByRoadmap[roadmap.id] = Set(roadmap.milestones.map(\.id))
        }
        let projectIDs = Set(projects.map(\.id))
        let catalogMap = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

        // MARK: Evidence Integrity

        for (eid, record) in evidenceRecords {
            // Skill IDs canonicalization
            if let skills = record.skillIDs {
                let normalized = skills.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }
                let deduped = Array(Set(normalized)).sorted()
                let originalSorted = skills.map { Skill.normalizeID($0) }.sorted()
                let repairedSorted = deduped.sorted()
                if originalSorted != repairedSorted || skills.count != deduped.count {
                    // Repair needed
                    let repaired = EvidenceRecord(
                        id: record.id,
                        type: record.type,
                        title: record.title,
                        description: record.description,
                        roadmapID: record.roadmapID,
                        milestoneID: record.milestoneID,
                        completionDate: record.completionDate,
                        createdAt: record.createdAt,
                        occurredAt: record.occurredAt,
                        source: record.source,
                        status: record.status,
                        actionID: record.actionID,
                        skillIDs: deduped.isEmpty ? nil : deduped,
                        artifact: record.artifact,
                        validationID: record.validationID,
                        validationScore: record.validationScore,
                        validationPercentage: record.validationPercentage,
                        validationPassed: record.validationPassed,
                        projectID: record.projectID,
                        opportunityID: record.opportunityID
                    )
                    result.evidenceRepairs[eid] = repaired
                    result.evidenceIssues.append(EvidenceConsistencyIssue(evidenceID: eid, issueType: "skillIDsRepaired", reason: "Skill IDs normalized/deduped", status: .repaired))
                }
                // Unknown skill reporting
                for sid in deduped {
                    if SkillCatalog.knownSkills[sid] == nil {
                        result.evidenceIssues.append(EvidenceConsistencyIssue(evidenceID: eid, issueType: "unknownSkill", reason: "Skill '\(sid)' not in catalog", status: .unresolved))
                    }
                }
            }
            // Context references
            if !record.roadmapID.isEmpty && !roadmapIDs.contains(record.roadmapID) {
                result.evidenceIssues.append(EvidenceConsistencyIssue(evidenceID: eid, issueType: "roadmapNotFound", reason: "roadmapID \(record.roadmapID) not in catalog", status: .unresolved))
            }
            if !record.milestoneID.isEmpty {
                if record.roadmapID.isEmpty {
                    result.evidenceIssues.append(EvidenceConsistencyIssue(evidenceID: eid, issueType: "milestoneWithoutRoadmap", reason: "milestoneID without roadmapID", status: .unresolved))
                } else if let set = milestoneIDsByRoadmap[record.roadmapID], !set.contains(record.milestoneID) {
                    result.evidenceIssues.append(EvidenceConsistencyIssue(evidenceID: eid, issueType: "milestoneNotFound", reason: "milestoneID \(record.milestoneID) not in roadmap \(record.roadmapID)", status: .unresolved))
                } else if milestoneIDsByRoadmap[record.roadmapID] == nil {
                    // roadmap already reported as not found, don't duplicate
                }
            }
            if let pid = record.projectID, !pid.isEmpty, !projectIDs.contains(pid) {
                // Project may be custom, not in catalog `projects` list? Check both catalog and custom? For now, report unresolved but preserve.
                // We treat custom projects as not in catalog; to avoid false unresolved, we only report if not in known projects and not empty
                // Keep as unresolved but preserve evidence
                result.evidenceIssues.append(EvidenceConsistencyIssue(evidenceID: eid, issueType: "projectNotFound", reason: "projectID \(pid) not in known projects", status: .unresolved))
            }
            if let vid = record.validationID, !vid.isEmpty, validationAttempts[vid] == nil {
                result.evidenceIssues.append(EvidenceConsistencyIssue(evidenceID: eid, issueType: "validationNotFound", reason: "validationID \(vid) not in attempts", status: .unresolved))
            }
        }

        // MARK: Achievement Integrity

        // Prepare evidence existence set for quick lookup (including repaired evidence)
        var effectiveEvidence = evidenceRecords
        for (id, repaired) in result.evidenceRepairs {
            effectiveEvidence[id] = repaired
        }

        for (aid, achievement) in achievementRecords {
            var needsRepair = false
            var repairedEvidenceIDs = achievement.evidenceIDs
            var repairedSkillIDs = achievement.skillIDs

            // EvidenceIDs deduplication and missing removal
            let originalEvidenceIDs = achievement.evidenceIDs
            // Deduplicate preserving order
            var seen = Set<String>()
            var deduped: [String] = []
            for eid in originalEvidenceIDs {
                let t = eid.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty, !seen.contains(t) else { continue }
                seen.insert(t); deduped.append(t)
            }
            // Check for duplicates
            if deduped.count != originalEvidenceIDs.count {
                needsRepair = true
                result.achievementIssues.append(AchievementConsistencyIssue(achievementID: aid, issueType: "duplicateEvidenceIDs", reason: "Removed duplicate evidenceIDs", status: .repaired))
            }
            // Remove missing evidence
            var filtered: [String] = []
            for eid in deduped {
                if effectiveEvidence[eid] == nil {
                    needsRepair = true
                    // For student vs generated, handling differs later
                    result.achievementIssues.append(AchievementConsistencyIssue(achievementID: aid, issueType: "missingEvidence", reason: "Evidence \(eid) not found", status: .unresolved))
                } else {
                    filtered.append(eid)
                }
            }
            // For generated achievements, missing evidence is more severe (suppression), for student we preserve with filtered list
            let isGenerated = achievement.source != .studentEntered
            if isGenerated && filtered.isEmpty && !originalEvidenceIDs.isEmpty {
                // Generated achievement loses all required evidence -> will be suppressed later
            } else if filtered != deduped {
                needsRepair = true
                repairedEvidenceIDs = filtered
            } else {
                repairedEvidenceIDs = deduped
            }
            // Also handle case where original had duplicates and we already set deduped, now filtered may be same as deduped

            // SkillIDs canonicalization
            if let skills = achievement.skillIDs {
                let normalized = skills.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }
                let dedupedSkills = Array(Set(normalized)).sorted()
                let originalSorted = skills.map { Skill.normalizeID($0) }.sorted()
                if originalSorted != dedupedSkills.sorted() || skills.count != dedupedSkills.count {
                    needsRepair = true
                    repairedSkillIDs = dedupedSkills.isEmpty ? nil : dedupedSkills
                    result.achievementIssues.append(AchievementConsistencyIssue(achievementID: aid, issueType: "skillIDsRepaired", reason: "Skill IDs normalized/deduped", status: .repaired))
                } else if dedupedSkills.isEmpty && !skills.isEmpty {
                    // All were empty after normalization
                    needsRepair = true
                    repairedSkillIDs = nil
                }
                // Unknown skill reporting
                for sid in dedupedSkills {
                    if SkillCatalog.knownSkills[sid] == nil {
                        result.achievementIssues.append(AchievementConsistencyIssue(achievementID: aid, issueType: "unknownSkill", reason: "Skill '\(sid)' not in catalog", status: .unresolved))
                    }
                }
            }

            // Check if repair needed for evidenceIDs or skillIDs
            let evidenceChanged = repairedEvidenceIDs != originalEvidenceIDs
            let skillsChanged = (repairedSkillIDs ?? []) != (achievement.skillIDs ?? [])
            if evidenceChanged || skillsChanged {
                needsRepair = true
            }

            // For student achievements, apply repair even if evidence missing (preserve achievement with filtered list)
            // For generated, we will handle suppression below, but still need to record repair if needed
            if needsRepair && !isGenerated {
                let repaired = Achievement(
                    id: achievement.id,
                    title: achievement.title,
                    description: achievement.description,
                    type: achievement.type,
                    status: achievement.status,
                    createdAt: achievement.createdAt,
                    occurredAt: achievement.occurredAt,
                    evidenceIDs: repairedEvidenceIDs,
                    skillIDs: repairedSkillIDs,
                    roadmapID: achievement.roadmapID,
                    milestoneID: achievement.milestoneID,
                    projectID: achievement.projectID,
                    opportunityID: achievement.opportunityID,
                    source: achievement.source
                )
                result.achievementRepairs[aid] = repaired
            } else if needsRepair && isGenerated {
                // For generated, we will handle via suppression logic; but if evidence still partially valid, repair
                // We'll defer to suppression check: if filtered is empty and original had evidence, suppress instead of repair
                if filtered.isEmpty && !originalEvidenceIDs.isEmpty {
                    // Will be suppressed, no need to repair
                } else {
                    let repaired = Achievement(
                        id: achievement.id,
                        title: achievement.title,
                        description: achievement.description,
                        type: achievement.type,
                        status: achievement.status,
                        createdAt: achievement.createdAt,
                        occurredAt: achievement.occurredAt,
                        evidenceIDs: repairedEvidenceIDs,
                        skillIDs: repairedSkillIDs,
                        roadmapID: achievement.roadmapID,
                        milestoneID: achievement.milestoneID,
                        projectID: achievement.projectID,
                        opportunityID: achievement.opportunityID,
                        source: achievement.source
                    )
                    result.achievementRepairs[aid] = repaired
                }
            }

            // Generated achievement integrity checks for suppression
            if isGenerated {
                let suppressionReason = shouldSuppressGeneratedAchievement(
                    achievement: achievement,
                    effectiveEvidence: effectiveEvidence,
                    roadmapProgress: roadmapProgress,
                    projectProgress: projectProgress,
                    validationAttempts: validationAttempts,
                    catalog: catalog,
                    projects: projects,
                    catalogMap: catalogMap,
                    evidenceRecords: evidenceRecords
                )
                if let reason = suppressionReason {
                    // Only suppress if not already scheduled for repair that would fix it? For these rules, suppression is final
                    if !result.suppressedAchievementIDs.contains(aid) {
                        result.suppressedAchievementIDs.append(aid)
                        result.achievementIssues.append(AchievementConsistencyIssue(achievementID: aid, issueType: "generatedSuppressed", reason: reason, status: .suppressed))
                    }
                    // Remove any pending repair for this ID since it's suppressed
                    result.achievementRepairs.removeValue(forKey: aid)
                }
            } else {
                // Student-created: report unresolved missing evidence but preserve
                if filtered.count != deduped.count {
                    result.achievementIssues.append(AchievementConsistencyIssue(achievementID: aid, issueType: "studentEvidenceMissing", reason: "Some evidenceIDs missing, filtered", status: .unresolved))
                }
            }
        }

        return result
    }

    // MARK: - Generated Suppression Logic

    private static func shouldSuppressGeneratedAchievement(
        achievement: Achievement,
        effectiveEvidence: [String: EvidenceRecord],
        roadmapProgress: [String: Int],
        projectProgress: [String: Int],
        validationAttempts: [String: ValidationAttempt],
        catalog: [Roadmap],
        projects: [Project],
        catalogMap: [String: Roadmap],
        evidenceRecords: [String: EvidenceRecord]
    ) -> String? {
        // Determine rule by ID prefix
        let id = achievement.id
        if id.hasPrefix("achievement-validation-") {
            // Validation achievement: requires passed attempt and evidence with correct validationID
            guard let roadmapID = achievement.roadmapID, let milestoneID = achievement.milestoneID else {
                return "Validation achievement missing roadmap/milestone relationship"
            }
            // Find validationID from evidence or achievement? Use first evidence's validationID or try to extract from ID
            // Our validation achievements have evidenceIDs containing one evidence
            guard let eid = achievement.evidenceIDs.first, let evidence = effectiveEvidence[eid] else {
                return "Validation achievement missing supporting evidence"
            }
            guard let vid = evidence.validationID, !vid.isEmpty else {
                return "Validation evidence missing validationID"
            }
            guard let attempt = validationAttempts[vid] else {
                return "Validation attempt \(vid) not found"
            }
            guard attempt.passed else {
                return "Validation attempt \(vid) not passed"
            }
            guard evidence.validationPassed == true else {
                return "Evidence validationPassed not true"
            }
            // Also check roadmap/milestone still exist
            guard let roadmap = catalogMap[roadmapID], roadmap.milestones.contains(where: { $0.id == milestoneID }) else {
                return "Validation roadmap/milestone not found"
            }
            return nil
        } else if id.hasPrefix("achievement-opportunity-") {
            guard let oppID = achievement.opportunityID, !oppID.isEmpty else {
                return "Opportunity achievement missing opportunityID"
            }
            // Must have at least one opportunityParticipation evidence with this oppID
            let hasParticipation = effectiveEvidence.values.contains { $0.type == .opportunityParticipation && $0.opportunityID == oppID }
            if !hasParticipation {
                return "No participation evidence for opportunity \(oppID)"
            }
            // Also check evidenceIDs still valid (already filtered, but if empty -> suppress)
            if achievement.evidenceIDs.isEmpty {
                return "Opportunity achievement has no valid evidence"
            }
            // Check at least one evidenceID still exists and is opportunityParticipation
            let valid = achievement.evidenceIDs.contains { eid in
                guard let ev = effectiveEvidence[eid] else { return false }
                return ev.type == .opportunityParticipation && ev.opportunityID == oppID
            }
            if !valid {
                return "Opportunity achievement evidence not valid participation"
            }
            return nil
        } else if id.hasPrefix("achievement-project-") {
            guard let pid = achievement.projectID else {
                return "Project achievement missing projectID"
            }
            guard let project = projects.first(where: { $0.id == pid }) else {
                return "Project \(pid) not found"
            }
            let completed = min(projectProgress[pid] ?? 0, project.milestones.count)
            guard completed >= project.milestones.count && project.milestones.count > 0 else {
                return "Project \(pid) not completed"
            }
            // Require at least one valid project evidence? Prefer suppression if none
            let hasProjectEvidence = effectiveEvidence.values.contains { $0.projectID == pid }
            if !hasProjectEvidence {
                return "No valid project evidence for project \(pid)"
            }
            // Also check evidenceIDs if non-empty, they should be valid project evidence; if empty, it's okay but we still have hasProjectEvidence check
            return nil
        } else if id.hasPrefix("achievement-progress-") {
            guard let rid = achievement.roadmapID else {
                return "Progress achievement missing roadmapID"
            }
            guard let roadmap = catalogMap[rid] else {
                return "Progress roadmap \(rid) not found"
            }
            let threshold = min(3, roadmap.milestones.count)
            let completed = min(roadmapProgress[rid] ?? 0, roadmap.milestones.count)
            guard completed >= threshold else {
                return "Progress threshold not met for \(rid) (\(completed)<\(threshold))"
            }
            // Check threshold evidences exist
            let prefix = Array(roadmap.milestones.prefix(threshold))
            let eids = prefix.map { "evidence-\(rid)-\($0.id)" }
            for eid in eids {
                guard effectiveEvidence[eid] != nil else {
                    return "Progress evidence \(eid) missing"
                }
            }
            return nil
        } else if id.hasPrefix("achievement-") {
            // Assume milestone achievement: achievement-{roadmap}-{milestone}
            // Extract roadmap and milestone via achievement's stored relationships
            guard let rid = achievement.roadmapID, let mid = achievement.milestoneID else {
                // Fallback: try to parse ID
                return nil // If no relationships, cannot validate strictly, keep valid
            }
            guard let roadmap = catalogMap[rid], roadmap.milestones.contains(where: { $0.id == mid }) else {
                return "Milestone achievement roadmap/milestone not found \(rid)/\(mid)"
            }
            let eid = "evidence-\(rid)-\(mid)"
            guard let evidence = effectiveEvidence[eid] else {
                return "Milestone evidence \(eid) missing"
            }
            guard evidence.type == .milestoneCompletion else {
                return "Milestone evidence \(eid) wrong type"
            }
            // Also check roadmapProgress indicates completed
            let completed = min(roadmapProgress[rid] ?? 0, roadmap.milestones.count)
            guard let idx = roadmap.milestones.firstIndex(where: { $0.id == mid }), idx < completed else {
                return "Milestone \(mid) not marked completed in progress"
            }
            return nil
        }
        // Unknown generated pattern — keep valid if evidenceIDs exist
        if achievement.evidenceIDs.isEmpty {
            return nil // Allow generic generated with empty evidence? But spec says prefer evidence-backed, but not strictly required for unknown
        }
        // Check evidenceIDs exist
        for eid in achievement.evidenceIDs {
            if effectiveEvidence[eid] == nil {
                return "Generated achievement evidence \(eid) missing"
            }
        }
        return nil
    }

    // MARK: - Reconciled Collections Helper

    static func reconciledCollections(
        evidenceRecords: [String: EvidenceRecord],
        achievementRecords: [String: Achievement],
        roadmapProgress: [String: Int],
        projectProgress: [String: Int],
        validationAttempts: [String: ValidationAttempt],
        catalog: [Roadmap],
        projects: [Project]
    ) -> (evidence: [String: EvidenceRecord], achievements: [String: Achievement], result: ReconciliationResult) {
        let result = reconcile(evidenceRecords: evidenceRecords, achievementRecords: achievementRecords, roadmapProgress: roadmapProgress, projectProgress: projectProgress, validationAttempts: validationAttempts, catalog: catalog, projects: projects)
        var newEvidence = evidenceRecords
        for (id, repaired) in result.evidenceRepairs {
            newEvidence[id] = repaired
        }
        var newAchievements = achievementRecords
        for (id, repaired) in result.achievementRepairs {
            newAchievements[id] = repaired
        }
        for id in result.suppressedAchievementIDs {
            newAchievements.removeValue(forKey: id)
        }
        return (newEvidence, newAchievements, result)
    }
}
