import Foundation

// MARK: - Connection Type (explicit, deterministic)

enum PortfolioEvidenceConnectionType: String, Codable, Hashable, CaseIterable {
    case project = "project"
    case achievement = "achievement"
    case skill = "skill"
    case roadmap = "roadmap"
    case milestone = "milestone"
    case opportunity = "opportunity"
    case validation = "validation"
}

// MARK: - Connection

struct PortfolioEvidenceConnection: Identifiable, Hashable, Codable {
    let id: String // deterministic: "<evidenceID>-><targetType>:<targetID>"
    let evidenceID: String
    let targetID: String
    let targetType: PortfolioEvidenceConnectionType
    let relationship: String // e.g., "Supports this project"
    let reason: String // factual, e.g., "EvidenceRecord.projectID matches this project."
    let isDirect: Bool

    init(evidenceID: String, targetID: String, targetType: PortfolioEvidenceConnectionType, relationship: String, reason: String, isDirect: Bool) {
        self.evidenceID = evidenceID
        self.targetID = targetID
        self.targetType = targetType
        self.relationship = relationship
        self.reason = reason
        self.isDirect = isDirect
        self.id = "\(evidenceID)->\(targetType.rawValue):\(targetID)"
    }
}

// MARK: - Reference Issue

struct PortfolioEvidenceReferenceIssue: Identifiable, Hashable, Codable {
    let id: String // "<evidenceID>-><targetType>:<targetID>"
    let evidenceID: String
    let targetType: PortfolioEvidenceConnectionType
    let targetID: String
    let reason: String

    init(evidenceID: String, targetType: PortfolioEvidenceConnectionType, targetID: String, reason: String) {
        self.evidenceID = evidenceID
        self.targetType = targetType
        self.targetID = targetID
        self.reason = reason
        self.id = "\(evidenceID)->\(targetType.rawValue):\(targetID)"
    }
}

// MARK: - Portfolio Evidence Report (derived, not persisted)

struct PortfolioEvidenceReport: Hashable, Codable {
    let portfolioID: String
    let asOf: Date
    let generatedAt: Date

    // Resolved selected evidence records
    let selectedEvidenceRecords: [EvidenceRecord]

    // Supporting evidence per selected item (deterministic, deduped, sorted)
    let projectEvidence: [String: [EvidenceRecord]] // projectID -> [EvidenceRecord]
    let achievementEvidence: [String: [EvidenceRecord]] // achievementID -> [EvidenceRecord]
    let skillEvidence: [String: [EvidenceRecord]] // normalized skillID -> [EvidenceRecord]
    let roadmapEvidence: [String: [EvidenceRecord]] // roadmapID -> [EvidenceRecord]
    let milestoneEvidence: [String: [EvidenceRecord]] // "roadmapID:milestoneID" -> [EvidenceRecord]
    let opportunityEvidence: [String: [EvidenceRecord]] // opportunityID -> [EvidenceRecord]
    let validationEvidence: [String: [EvidenceRecord]] // validationID -> [EvidenceRecord]

    // Flat connections for UI
    let connections: [PortfolioEvidenceConnection]

    // Unresolved references
    let unresolved: [PortfolioEvidenceReferenceIssue]

    // Orphaned selected evidence (no connection to selected portfolio items)
    let orphanedEvidenceIDs: [String]

    // Evidence used by multiple portfolio items (evidenceID -> count)
    let evidenceUsageCount: [String: Int]

    var hasOrphaned: Bool { !orphanedEvidenceIDs.isEmpty }
    var hasUnresolved: Bool { !unresolved.isEmpty }
}

// MARK: - Engine

enum PortfolioEvidenceEngine {

    // MARK: - Public API (AppDataStore convenience, read-only)

    @MainActor
    static func report(for portfolio: StudentPortfolio, store: AppDataStore, asOf: Date = Date()) -> PortfolioEvidenceReport {
        let projects = Dictionary(uniqueKeysWithValues: store.scoredProjects.map { ($0.project.id, $0.project) })
        // Include custom projects as well (scoredProjects already includes them)
        let roadmaps = Dictionary(uniqueKeysWithValues: RoadmapService.allRoadmaps.map { ($0.id, $0) })
        return report(
            for: portfolio,
            evidenceRecords: store.evidenceRecords,
            achievementRecords: store.achievementRecords,
            projects: projects,
            roadmaps: roadmaps,
            asOf: asOf
        )
    }

    // MARK: - Pure Report (no MainActor, fully testable)

    static func report(
        for portfolio: StudentPortfolio,
        evidenceRecords: [String: EvidenceRecord],
        achievementRecords: [String: Achievement],
        projects: [String: Project],
        roadmaps: [String: Roadmap],
        asOf: Date = Date()
    ) -> PortfolioEvidenceReport {
        // Resolve selected evidence records (those directly selected in portfolio)
        let selectedEvidenceRecords = portfolio.selectedEvidenceIDs.compactMap { evidenceRecords[$0] }.sorted { $0.createdAt > $1.createdAt }

        // Build maps for fast lookup
        let evidenceByID = evidenceRecords

        // For each selected item, find supporting evidence via direct canonical relationships

        // Project support
        var projectEvidence: [String: [EvidenceRecord]] = [:]
        for pid in portfolio.selectedProjectIDs {
            let evs = supportingEvidence(forProjectID: pid, evidenceRecords: evidenceRecords)
            projectEvidence[pid] = evs
        }

        // Achievement support
        var achievementEvidence: [String: [EvidenceRecord]] = [:]
        for aid in portfolio.selectedAchievementIDs {
            let evs = supportingEvidence(forAchievementID: aid, achievementRecords: achievementRecords, evidenceRecords: evidenceByID)
            achievementEvidence[aid] = evs
        }

        // Skill support
        var skillEvidence: [String: [EvidenceRecord]] = [:]
        for raw in portfolio.selectedSkillIDs {
            let norm = Skill.normalizeID(raw)
            guard !norm.isEmpty else { continue }
            let evs = supportingEvidence(forSkillID: norm, evidenceRecords: evidenceRecords)
            skillEvidence[norm] = evs
        }

        // Roadmap support
        var roadmapEvidence: [String: [EvidenceRecord]] = [:]
        for rid in portfolio.selectedRoadmapIDs {
            let evs = supportingEvidence(forRoadmapID: rid, evidenceRecords: evidenceRecords)
            roadmapEvidence[rid] = evs
        }

        // Milestone support (for each selected roadmap, also expose per-milestone)
        var milestoneEvidence: [String: [EvidenceRecord]] = [:]
        for rid in portfolio.selectedRoadmapIDs {
            guard let roadmap = roadmaps[rid] else { continue }
            for milestone in roadmap.milestones {
                let key = "\(rid):\(milestone.id)"
                let evs = supportingEvidence(forMilestoneID: milestone.id, roadmapID: rid, evidenceRecords: evidenceRecords)
                if !evs.isEmpty {
                    milestoneEvidence[key] = evs
                }
            }
        }

        // Opportunity support (collect distinct opportunityIDs from selected evidence)
        var opportunityIDs = Set<String>()
        for rec in selectedEvidenceRecords where rec.opportunityID != nil {
            if let oid = rec.opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines), !oid.isEmpty {
                opportunityIDs.insert(oid)
            }
        }
        var opportunityEvidence: [String: [EvidenceRecord]] = [:]
        for oid in opportunityIDs {
            let evs = supportingEvidence(forOpportunityID: oid, evidenceRecords: evidenceRecords)
            opportunityEvidence[oid] = evs
        }

        // Validation support (distinct validationIDs)
        var validationIDs = Set<String>()
        for rec in selectedEvidenceRecords where rec.validationID != nil {
            if let vid = rec.validationID?.trimmingCharacters(in: .whitespacesAndNewlines), !vid.isEmpty {
                validationIDs.insert(vid)
            }
        }
        var validationEvidence: [String: [EvidenceRecord]] = [:]
        for vid in validationIDs {
            let evs = supportingEvidence(forValidationID: vid, evidenceRecords: evidenceRecords)
            validationEvidence[vid] = evs
        }

        // Flat connections (for UI convenience)
        var connections: [PortfolioEvidenceConnection] = []
        // Use Set to dedup connections
        var seenConnIDs = Set<String>()

        func addConnection(evidenceID: String, targetID: String, type: PortfolioEvidenceConnectionType, relationship: String, reason: String, isDirect: Bool) {
            let conn = PortfolioEvidenceConnection(evidenceID: evidenceID, targetID: targetID, targetType: type, relationship: relationship, reason: reason, isDirect: isDirect)
            guard !seenConnIDs.contains(conn.id) else { return }
            seenConnIDs.insert(conn.id)
            connections.append(conn)
        }

        // Build connections from direct evidence relationships (only for evidence that is either selected or supporting selected items)
        // For all evidence that supports selected items, create connections
        for (pid, evs) in projectEvidence {
            for ev in evs {
                addConnection(evidenceID: ev.id, targetID: pid, type: .project, relationship: "Supports this project", reason: "EvidenceRecord.projectID matches this project.", isDirect: true)
            }
        }
        for (aid, evs) in achievementEvidence {
            for ev in evs {
                addConnection(evidenceID: ev.id, targetID: aid, type: .achievement, relationship: "Supports this achievement", reason: "Achievement.evidenceIDs contains this evidence.", isDirect: true)
            }
        }
        for (sid, evs) in skillEvidence {
            for ev in evs {
                addConnection(evidenceID: ev.id, targetID: sid, type: .skill, relationship: "Supports this skill", reason: "EvidenceRecord.skillIDs contains this skill.", isDirect: true)
            }
        }
        for (rid, evs) in roadmapEvidence {
            for ev in evs {
                addConnection(evidenceID: ev.id, targetID: rid, type: .roadmap, relationship: "Supports this roadmap", reason: "EvidenceRecord.roadmapID matches this roadmap.", isDirect: true)
            }
        }
        for (key, evs) in milestoneEvidence {
            // key is "roadmapID:milestoneID"
            let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let rid = parts[0]
            let mid = parts[1]
            for ev in evs {
                addConnection(evidenceID: ev.id, targetID: mid, type: .milestone, relationship: "Supports this milestone", reason: "EvidenceRecord.milestoneID matches this milestone in \(rid).", isDirect: true)
            }
        }
        for (oid, evs) in opportunityEvidence {
            for ev in evs {
                addConnection(evidenceID: ev.id, targetID: oid, type: .opportunity, relationship: "Supports this opportunity", reason: "EvidenceRecord.opportunityID matches this opportunity.", isDirect: true)
            }
        }
        for (vid, evs) in validationEvidence {
            for ev in evs {
                addConnection(evidenceID: ev.id, targetID: vid, type: .validation, relationship: "Includes this validation", reason: "EvidenceRecord.validationID matches this validation.", isDirect: true)
            }
        }

        // Also add connections for selected evidence's own direct references (so selected evidence shows its supports)
        // This ensures selected evidence that is standalone still shows its own connections
        for rec in selectedEvidenceRecords {
            // Project
            if let pid = rec.projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty, projects[pid] != nil {
                // Only add if not already added via projectEvidence (which is for selected projects); but selected evidence may reference a project not selected — still show
                // To avoid duplication, addConnection dedups
                addConnection(evidenceID: rec.id, targetID: pid, type: .project, relationship: "Supports this project", reason: "EvidenceRecord.projectID matches this project.", isDirect: true)
            }
            // Roadmap
            if !rec.roadmapID.isEmpty, roadmaps[rec.roadmapID] != nil {
                addConnection(evidenceID: rec.id, targetID: rec.roadmapID, type: .roadmap, relationship: "Supports this roadmap", reason: "EvidenceRecord.roadmapID matches this roadmap.", isDirect: true)
            }
            // Milestone
            if !rec.roadmapID.isEmpty && !rec.milestoneID.isEmpty, let rm = roadmaps[rec.roadmapID], rm.milestones.contains(where: { $0.id == rec.milestoneID }) {
                addConnection(evidenceID: rec.id, targetID: rec.milestoneID, type: .milestone, relationship: "Supports this milestone", reason: "EvidenceRecord.milestoneID matches this milestone.", isDirect: true)
            }
            // Opportunity
            if let oid = rec.opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines), !oid.isEmpty {
                addConnection(evidenceID: rec.id, targetID: oid, type: .opportunity, relationship: "Supports this opportunity", reason: "EvidenceRecord.opportunityID matches this opportunity.", isDirect: true)
            }
            // Validation
            if let vid = rec.validationID?.trimmingCharacters(in: .whitespacesAndNewlines), !vid.isEmpty {
                addConnection(evidenceID: rec.id, targetID: vid, type: .validation, relationship: "Includes this validation", reason: "EvidenceRecord.validationID matches this validation.", isDirect: true)
            }
            // Skills (one per skill)
            if let sids = rec.skillIDs {
                for raw in sids {
                    let norm = Skill.normalizeID(raw)
                    guard !norm.isEmpty else { continue }
                    addConnection(evidenceID: rec.id, targetID: norm, type: .skill, relationship: "Supports this skill", reason: "EvidenceRecord.skillIDs contains this skill.", isDirect: true)
                }
            }
            // Achievement (reverse: achievement contains evidence) — handled via achievementEvidence, but also ensure selected evidence shows its achievements
            // Find achievements that reference this evidence and are selected
            for aid in portfolio.selectedAchievementIDs where achievementRecords[aid]?.evidenceIDs.contains(rec.id) == true {
                addConnection(evidenceID: rec.id, targetID: aid, type: .achievement, relationship: "Supports this achievement", reason: "Achievement.evidenceIDs contains this evidence.", isDirect: true)
            }
        }

        connections.sort { $0.id < $1.id }

        // Unresolved references
        var unresolved: [PortfolioEvidenceReferenceIssue] = []
        // We need to check all evidence that is in the portfolio context (selected + supporting)
        // For simplicity, check all evidence in evidenceRecords that is referenced by selected portfolio items
        // Build set of evidence to check: selectedEvidenceRecords + supporting evidence for selected items
        var evidenceToCheck: [EvidenceRecord] = selectedEvidenceRecords
        // Add supporting evidence for selected items (deduped)
        var seenEvCheck = Set(selectedEvidenceRecords.map(\.id))
        for evs in projectEvidence.values {
            for ev in evs where !seenEvCheck.contains(ev.id) { evidenceToCheck.append(ev); seenEvCheck.insert(ev.id) }
        }
        for evs in achievementEvidence.values {
            for ev in evs where !seenEvCheck.contains(ev.id) { evidenceToCheck.append(ev); seenEvCheck.insert(ev.id) }
        }
        // Also check evidence that is selected but references missing targets
        for rec in evidenceToCheck {
            // Project
            if let pid = rec.projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty, projects[pid] == nil {
                unresolved.append(PortfolioEvidenceReferenceIssue(evidenceID: rec.id, targetType: .project, targetID: pid, reason: "No canonical project found for \(pid)."))
            }
            // Roadmap
            if !rec.roadmapID.isEmpty, roadmaps[rec.roadmapID] == nil {
                unresolved.append(PortfolioEvidenceReferenceIssue(evidenceID: rec.id, targetType: .roadmap, targetID: rec.roadmapID, reason: "No canonical roadmap found for \(rec.roadmapID)."))
            }
            // Milestone (only if roadmap exists but milestone not found)
            if !rec.roadmapID.isEmpty && !rec.milestoneID.isEmpty, let rm = roadmaps[rec.roadmapID], !rm.milestones.contains(where: { $0.id == rec.milestoneID }) {
                unresolved.append(PortfolioEvidenceReferenceIssue(evidenceID: rec.id, targetType: .milestone, targetID: rec.milestoneID, reason: "No milestone \(rec.milestoneID) in roadmap \(rec.roadmapID)."))
            } else if !rec.milestoneID.isEmpty && rec.roadmapID.isEmpty {
                // Milestone without roadmap — unresolved
                unresolved.append(PortfolioEvidenceReferenceIssue(evidenceID: rec.id, targetType: .milestone, targetID: rec.milestoneID, reason: "Milestone \(rec.milestoneID) has no roadmap context."))
            }
            // Opportunity: we don't have opportunity store locally, so treat any opportunityID as potentially unresolved only if we could resolve locally
            // For now, we don't report opportunity unresolved unless we have a local opportunity catalog — skip
            // Validation: check if validationID not in store.validationAttempts (we don't have that here, so skip pure report — MainActor version will handle)
            // Skill: skills are always considered resolvable if normalized non-empty (catalog may be missing but not unresolved)
        }

        // Also check achievements with missing evidence
        for aid in portfolio.selectedAchievementIDs {
            guard let ach = achievementRecords[aid] else { continue } // stale achievement handled elsewhere (PortfolioEngine)
            for eid in ach.evidenceIDs where evidenceRecords[eid] == nil {
                unresolved.append(PortfolioEvidenceReferenceIssue(evidenceID: eid, targetType: .achievement, targetID: aid, reason: "Achievement \(aid) references missing evidence \(eid)."))
            }
        }

        unresolved.sort { $0.id < $1.id }
        // Dedup unresolved
        var seenUnresolved = Set<String>()
        var dedupedUnresolved: [PortfolioEvidenceReferenceIssue] = []
        for issue in unresolved where !seenUnresolved.contains(issue.id) {
            seenUnresolved.insert(issue.id)
            dedupedUnresolved.append(issue)
        }

        // Orphaned selected evidence: selected evidence with no connection to selected portfolio items
        var connectedEvidenceIDs = Set<String>()
        for evs in projectEvidence.values { for ev in evs { connectedEvidenceIDs.insert(ev.id) } }
        for evs in achievementEvidence.values { for ev in evs { connectedEvidenceIDs.insert(ev.id) } }
        for evs in skillEvidence.values { for ev in evs { connectedEvidenceIDs.insert(ev.id) } }
        for evs in roadmapEvidence.values { for ev in evs { connectedEvidenceIDs.insert(ev.id) } }
        // Selected evidence that is not connected to any selected item (other than itself)
        // Orphaned if selectedEvidence not in any of the above supporting sets and also its own direct references don't point to selected items
        // Simplify: orphaned if selected evidence ID not in connectedEvidenceIDs and also its own connections don't point to selected portfolio IDs
        var orphaned: [String] = []
        for rec in selectedEvidenceRecords {
            if connectedEvidenceIDs.contains(rec.id) { continue }
            // Check if evidence's own project/roadmap/skill etc. points to a selected item
            var isConnected = false
            if let pid = rec.projectID, portfolio.selectedProjectIDs.contains(pid) { isConnected = true }
            if !rec.roadmapID.isEmpty, portfolio.selectedRoadmapIDs.contains(rec.roadmapID) { isConnected = true }
            if let sids = rec.skillIDs {
                for raw in sids {
                    let norm = Skill.normalizeID(raw)
                    if portfolio.selectedSkillIDs.map({ Skill.normalizeID($0) }).contains(norm) { isConnected = true; break }
                }
            }
            // Check if any selected achievement references this evidence
            for aid in portfolio.selectedAchievementIDs where achievementRecords[aid]?.evidenceIDs.contains(rec.id) == true {
                isConnected = true
                break
            }
            if !isConnected {
                orphaned.append(rec.id)
            }
        }
        orphaned.sort()

        // Evidence usage count (how many portfolio items use this evidence)
        var usageCount: [String: Int] = [:]
        for ev in projectEvidence.values.flatMap({ $0 }) { usageCount[ev.id, default: 0] += 1 }
        for ev in achievementEvidence.values.flatMap({ $0 }) { usageCount[ev.id, default: 0] += 1 }
        for ev in skillEvidence.values.flatMap({ $0 }) { usageCount[ev.id, default: 0] += 1 }
        for ev in roadmapEvidence.values.flatMap({ $0 }) { usageCount[ev.id, default: 0] += 1 }
        // Also count selected evidence direct usage (at least 1)
        for rec in selectedEvidenceRecords { usageCount[rec.id, default: 0] += 1 }

        return PortfolioEvidenceReport(
            portfolioID: portfolio.id,
            asOf: asOf,
            generatedAt: Date(),
            selectedEvidenceRecords: selectedEvidenceRecords,
            projectEvidence: projectEvidence,
            achievementEvidence: achievementEvidence,
            skillEvidence: skillEvidence,
            roadmapEvidence: roadmapEvidence,
            milestoneEvidence: milestoneEvidence,
            opportunityEvidence: opportunityEvidence,
            validationEvidence: validationEvidence,
            connections: connections,
            unresolved: dedupedUnresolved,
            orphanedEvidenceIDs: orphaned,
            evidenceUsageCount: usageCount
        )
    }

    // MARK: - Supporting Evidence (deterministic, read-only, sorted)

    /// Evidence where `EvidenceRecord.projectID == projectID` (direct)
    static func supportingEvidence(forProjectID projectID: String, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        let pid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return [] }
        let filtered = evidenceRecords.values.filter { $0.projectID?.trimmingCharacters(in: .whitespacesAndNewlines) == pid }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    static func supportingEvidence(forProject project: Project, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        supportingEvidence(forProjectID: project.id, evidenceRecords: evidenceRecords)
    }

    /// Evidence where `Achievement.evidenceIDs` contains evidence (via achievement)
    static func supportingEvidence(forAchievementID achievementID: String, achievementRecords: [String: Achievement], evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        let aid = achievementID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !aid.isEmpty, let ach = achievementRecords[aid] else { return [] }
        let evs = ach.evidenceIDs.compactMap { evidenceRecords[$0] }
        return evs.sorted { $0.createdAt > $1.createdAt }
    }

    static func supportingEvidence(forAchievement achievement: Achievement, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        let evs = achievement.evidenceIDs.compactMap { evidenceRecords[$0] }
        return evs.sorted { $0.createdAt > $1.createdAt }
    }

    /// Evidence where `EvidenceRecord.skillIDs` contains normalized skillID
    static func supportingEvidence(forSkillID skillID: String, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        let norm = Skill.normalizeID(skillID)
        guard !norm.isEmpty else { return [] }
        let filtered = evidenceRecords.values.filter { rec in
            guard let sids = rec.skillIDs else { return false }
            return sids.map { Skill.normalizeID($0) }.contains(norm)
        }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    static func supportingEvidence(forSkill skill: Skill, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        supportingEvidence(forSkillID: skill.id, evidenceRecords: evidenceRecords)
    }

    /// Evidence where `EvidenceRecord.roadmapID == roadmapID`
    static func supportingEvidence(forRoadmapID roadmapID: String, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        let rid = roadmapID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rid.isEmpty else { return [] }
        let filtered = evidenceRecords.values.filter { $0.roadmapID == rid }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    static func supportingEvidence(forRoadmap roadmap: Roadmap, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        supportingEvidence(forRoadmapID: roadmap.id, evidenceRecords: evidenceRecords)
    }

    /// Evidence where `roadmapID` and `milestoneID` both match
    static func supportingEvidence(forMilestoneID milestoneID: String, roadmapID: String, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        let mid = milestoneID.trimmingCharacters(in: .whitespacesAndNewlines)
        let rid = roadmapID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mid.isEmpty, !rid.isEmpty else { return [] }
        let filtered = evidenceRecords.values.filter { $0.roadmapID == rid && $0.milestoneID == mid }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    static func supportingEvidence(forMilestone milestone: RoadmapMilestone, roadmap: Roadmap, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        supportingEvidence(forMilestoneID: milestone.id, roadmapID: roadmap.id, evidenceRecords: evidenceRecords)
    }

    /// Evidence where `EvidenceRecord.opportunityID == opportunityID`
    static func supportingEvidence(forOpportunityID opportunityID: String, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        let oid = opportunityID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oid.isEmpty else { return [] }
        let filtered = evidenceRecords.values.filter { $0.opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines) == oid }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    /// Evidence where `EvidenceRecord.validationID == validationID`
    static func supportingEvidence(forValidationID validationID: String, evidenceRecords: [String: EvidenceRecord]) -> [EvidenceRecord] {
        let vid = validationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !vid.isEmpty else { return [] }
        let filtered = evidenceRecords.values.filter { $0.validationID?.trimmingCharacters(in: .whitespacesAndNewlines) == vid }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Helpers

    private static func isValidURL(_ s: String?) -> Bool {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return false }
        guard let url = URL(string: t) else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
        return url.host != nil
    }
}
