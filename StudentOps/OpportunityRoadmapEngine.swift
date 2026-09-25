import Foundation

// MARK: - Connection Strength

/// Deterministic strength of an opportunity's connection to a roadmap.
enum OpportunityRoadmapConnectionStrength: String, Codable, Hashable, Comparable {
    /// Opportunity matches a current skill gap and an available/current milestone with concrete actions.
    case direct = "Direct"
    /// Opportunity matches a required skill in an available/current milestone.
    case relevant = "Relevant"
    /// Opportunity matches a required skill but only in a future/locked milestone.
    case future = "Future"

    var title: String { rawValue }

    private var rank: Int {
        switch self {
        case .direct: return 3
        case .relevant: return 2
        case .future: return 1
        }
    }

    static func < (lhs: OpportunityRoadmapConnectionStrength, rhs: OpportunityRoadmapConnectionStrength) -> Bool {
        lhs.rank < rhs.rank
    }
}

// MARK: - Milestone Link Status

/// Availability of a milestone in the context of the student's current progress.
enum MilestoneLinkStatus: String, Codable, Hashable {
    case current
    case available
    case locked
    case completed
}

// MARK: - Milestone Link

/// A roadmap milestone that is reached by an opportunity's skills.
struct OpportunityRoadmapMilestoneLink: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let status: MilestoneLinkStatus
    let actionIDs: [String]
    let actionTitles: [String]
}

// MARK: - Opportunity → Roadmap Connection

/// Deterministic result linking an opportunity to a single roadmap.
struct OpportunityRoadmapConnection: Identifiable, Hashable, Codable {
    /// Stable ID: "\(opportunityID)-\(roadmapID)"
    let id: String
    let opportunityID: String
    let roadmapID: String
    let roadmapTitle: String
    let strength: OpportunityRoadmapConnectionStrength
    /// Internal deterministic score used for sorting.
    let score: Int
    let matchedSkills: [Skill]
    let gapSkillsAddressed: [Skill]
    let milestoneLinks: [OpportunityRoadmapMilestoneLink]
    let reason: String
    let advancesCurrentMilestone: Bool
    let addressesGap: Bool

    // Convenience flat accessors for UI
    var relatedMilestoneIDs: [String] { milestoneLinks.map(\.id) }
    var relatedMilestoneTitles: [String] { milestoneLinks.map(\.title) }
    var relatedActionIDs: [String] { milestoneLinks.flatMap(\.actionIDs) }
    var relatedActionTitles: [String] { milestoneLinks.flatMap(\.actionTitles) }

    var matchedSkillNames: [String] { matchedSkills.map(\.name) }
    var gapSkillNames: [String] { gapSkillsAddressed.map(\.name) }
}

// MARK: - Pure Deterministic Engine

/// Pure, deterministic engine that maps opportunities to roadmap structure.
///
/// No AI, no network, no persistence mutation.
/// All logic derived from:
///   Roadmap.skillsDeveloped  +  canonical Skill normalization  +  SkillGapEngine  +  RoadmapEngine dependency state
enum OpportunityRoadmapEngine {

    // MARK: - Opportunity Signal Extraction (Remote)

    /// Extracts normalized canonical skill IDs from a RemoteOpportunity.
    /// Sources: skills + topics + subjects (deduplicated, empty strings ignored).
    /// Category is intentionally NOT used as primary signal.
    static func normalizedSkillIDs(for remote: RemoteOpportunity) -> Set<String> {
        var ids = Set<String>()
        for raw in remote.skills + remote.topics + remote.subjects {
            let norm = Skill.normalizeID(raw)
            if !norm.isEmpty { ids.insert(norm) }
        }
        return ids
    }

    /// Extracts normalized canonical skill IDs from a local Opportunity.
    static func normalizedSkillIDs(for opp: Opportunity) -> Set<String> {
        var ids = Set<String>()
        for raw in opp.relevantSkills {
            let norm = Skill.normalizeID(raw)
            if !norm.isEmpty { ids.insert(norm) }
        }
        return ids
    }

    // MARK: - Single Roadmap Connection (Remote)

    /// Deterministic connection for one opportunity → one roadmap.
    /// Returns nil when there is no meaningful skill overlap.
    static func connection(
        for remote: RemoteOpportunity,
        roadmap: Roadmap,
        profile: StudentProfile,
        progress: [String: Int] = [:],
        catalog: [Roadmap]? = nil,
        evidenceRecords: [String: EvidenceRecord]? = nil
    ) -> OpportunityRoadmapConnection? {
        let oppSkillIDs = normalizedSkillIDs(for: remote)
        guard !oppSkillIDs.isEmpty else { return nil }
        return connectionInternal(
            opportunityID: remote.id,
            oppSkillIDs: oppSkillIDs,
            roadmap: roadmap,
            profile: profile,
            progress: progress,
            catalog: catalog,
            evidenceRecords: evidenceRecords
        )
    }

    /// Deterministic connection for one local Opportunity → one roadmap.
    static func connection(
        for opp: Opportunity,
        roadmap: Roadmap,
        profile: StudentProfile,
        progress: [String: Int] = [:],
        catalog: [Roadmap]? = nil,
        evidenceRecords: [String: EvidenceRecord]? = nil
    ) -> OpportunityRoadmapConnection? {
        let oppSkillIDs = normalizedSkillIDs(for: opp)
        guard !oppSkillIDs.isEmpty else { return nil }
        return connectionInternal(
            opportunityID: opp.id,
            oppSkillIDs: oppSkillIDs,
            roadmap: roadmap,
            profile: profile,
            progress: progress,
            catalog: catalog,
            evidenceRecords: evidenceRecords
        )
    }

    // MARK: - All Active Roadmaps (Remote)

    /// Connections for one remote opportunity across all currently activated roadmaps.
    /// Each roadmap is evaluated independently — no cross-roadmap contamination.
    static func connections(
        for remote: RemoteOpportunity,
        profile: StudentProfile,
        progress: [String: Int],
        activeRoadmaps: [Roadmap],
        catalog: [Roadmap]? = nil,
        evidenceRecords: [String: EvidenceRecord]? = nil
    ) -> [OpportunityRoadmapConnection] {
        let all = activeRoadmaps.compactMap { roadmap in
            connection(for: remote, roadmap: roadmap, profile: profile, progress: progress, catalog: catalog, evidenceRecords: evidenceRecords)
        }
        return sorted(all)
    }

    /// Convenience: connections using AppDataStore as source.
    @MainActor
    static func connections(for remote: RemoteOpportunity, store: AppDataStore) -> [OpportunityRoadmapConnection] {
        let active = store.activatedRoadmaps.map(\.roadmap)
        let catalog = store.scoredRoadmaps.map(\.roadmap)
        return connections(for: remote, profile: store.profile, progress: store.roadmapProgress, activeRoadmaps: active, catalog: catalog, evidenceRecords: store.evidenceRecords)
    }

    @MainActor
    static func connections(for opp: Opportunity, store: AppDataStore) -> [OpportunityRoadmapConnection] {
        let active = store.activatedRoadmaps.map(\.roadmap)
        let catalog = store.scoredRoadmaps.map(\.roadmap)
        let oppSkillIDs = normalizedSkillIDs(for: opp)
        guard !oppSkillIDs.isEmpty else { return [] }
        let all = active.compactMap { roadmap in
            connectionInternal(opportunityID: opp.id, oppSkillIDs: oppSkillIDs, roadmap: roadmap, profile: store.profile, progress: store.roadmapProgress, catalog: catalog, evidenceRecords: store.evidenceRecords)
        }
        return sorted(all)
    }

    // MARK: - Internal Core

    private static func connectionInternal(
        opportunityID: String,
        oppSkillIDs: Set<String>,
        roadmap: Roadmap,
        profile: StudentProfile,
        progress: [String: Int],
        catalog: [Roadmap]?,
        evidenceRecords: [String: EvidenceRecord]?
    ) -> OpportunityRoadmapConnection? {
        // Build map: skillID -> [milestoneIndex] and skillID -> Skill
        var skillToIndices: [String: [Int]] = [:]
        var skillIDToSkill: [String: Skill] = [:]
        for (idx, milestone) in roadmap.milestones.enumerated() {
            guard let dev = milestone.skillsDeveloped else { continue }
            for raw in dev {
                let norm = Skill.normalizeID(raw)
                guard !norm.isEmpty else { continue }
                skillToIndices[norm, default: []].append(idx)
                if skillIDToSkill[norm] == nil {
                    skillIDToSkill[norm] = Skill.canonical(from: raw)
                }
            }
        }
        guard !skillIDToSkill.isEmpty else { return nil }

        // Find matched skills: intersection of opp skills and roadmap required skills
        var matchedSkills: [Skill] = []
        var matchedSkillIDs = Set<String>()
        for oppID in oppSkillIDs {
            if let skill = skillIDToSkill[oppID] {
                if !matchedSkillIDs.contains(oppID) {
                    matchedSkillIDs.insert(oppID)
                    matchedSkills.append(skill)
                }
            }
        }
        guard !matchedSkills.isEmpty else { return nil }
        matchedSkills.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Skill gaps for this roadmap
        let gapReport = SkillGapEngine.evaluate(roadmap: roadmap, profile: profile, progress: progress, catalog: catalog, evidenceRecords: evidenceRecords)
        let gapIDs = Set(gapReport.gaps.map(\.skillID))
        let gapSkillsAddressed = matchedSkills.filter { gapIDs.contains($0.id) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Milestone availability context
        let completedCount = min(progress[roadmap.id] ?? 0, roadmap.milestones.count)
        let completedIDs = Set(roadmap.milestones.prefix(completedCount).map(\.id))

        // Collect unique milestone indices that develop matched skills
        var milestoneIndexSet = Set<Int>()
        for sid in matchedSkillIDs {
            if let indices = skillToIndices[sid] {
                for i in indices { milestoneIndexSet.insert(i) }
            }
        }
        let sortedIndices = milestoneIndexSet.sorted()

        // Build milestone links
        var milestoneLinks: [OpportunityRoadmapMilestoneLink] = []
        for idx in sortedIndices {
            let milestone = roadmap.milestones[idx]
            let availability = RoadmapEngine.milestoneAvailability(milestone: milestone, completedIDs: completedIDs, milestones: roadmap.milestones)
            let status: MilestoneLinkStatus
            switch availability {
            case .completed:
                status = .completed
            case .locked:
                status = .locked
            case .available:
                status = (idx == completedCount) ? .current : .available
            }
            let actions = milestone.actions ?? []
            milestoneLinks.append(
                OpportunityRoadmapMilestoneLink(
                    id: milestone.id,
                    title: milestone.title,
                    status: status,
                    actionIDs: actions.map(\.id),
                    actionTitles: actions.map(\.title)
                )
            )
        }

        // Deterministic score
        let hasCurrent = milestoneLinks.contains { $0.status == .current }
        let hasAvailable = milestoneLinks.contains { $0.status == .available || $0.status == .current }
        let totalActions = milestoneLinks.reduce(0) { $0 + $1.actionIDs.count }
        let base = matchedSkills.count * 10
        let gapBonus = gapSkillsAddressed.count * 15
        let currentBonus = hasCurrent ? 20 : 0
        let availableBonus = hasAvailable ? 10 : 0
        let actionBonus = min(totalActions, 10)
        // Earliness: earlier milestones are more actionable. Use earliest index.
        let earliestIdx = sortedIndices.first ?? 0
        let earlinessBonus = max(0, (roadmap.milestones.count - earliestIdx) * 2)
        let score = base + gapBonus + currentBonus + availableBonus + actionBonus + earlinessBonus

        // Strength
        let strength: OpportunityRoadmapConnectionStrength
        if !gapSkillsAddressed.isEmpty && hasAvailable {
            strength = .direct
        } else if hasAvailable {
            strength = .relevant
        } else if !matchedSkills.isEmpty {
            // Has matched skills but all milestones are locked/completed
            // Check if any completed? If all completed, still future? But roadmap completed case handled.
            strength = .future
        } else {
            strength = .future
        }

        let advancesCurrentMilestone = hasCurrent
        let addressesGap = !gapSkillsAddressed.isEmpty

        // Reason
        let matchedNames = matchedSkills.map(\.name).joined(separator: ", ")
        let gapNames = gapSkillsAddressed.map(\.name).joined(separator: ", ")
        let milestoneNames = milestoneLinks.map(\.title).joined(separator: ", ")
        var reasonParts: [String] = []
        reasonParts.append("Matches \(matchedSkills.count) roadmap skill(s): \(matchedNames)")
        if !gapSkillsAddressed.isEmpty {
            reasonParts.append("Addresses \(gapSkillsAddressed.count) current gap(s): \(gapNames)")
        }
        if !milestoneLinks.isEmpty {
            reasonParts.append("Develops in: \(milestoneNames)")
        }
        let reason = reasonParts.joined(separator: ". ")

        return OpportunityRoadmapConnection(
            id: "\(opportunityID)-\(roadmap.id)",
            opportunityID: opportunityID,
            roadmapID: roadmap.id,
            roadmapTitle: roadmap.title,
            strength: strength,
            score: score,
            matchedSkills: matchedSkills,
            gapSkillsAddressed: gapSkillsAddressed,
            milestoneLinks: milestoneLinks,
            reason: reason,
            advancesCurrentMilestone: advancesCurrentMilestone,
            addressesGap: addressesGap
        )
    }

    private static func sorted(_ connections: [OpportunityRoadmapConnection]) -> [OpportunityRoadmapConnection] {
        connections.sorted { lhs, rhs in
            if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.roadmapTitle.localizedCaseInsensitiveCompare(rhs.roadmapTitle) == .orderedAscending
        }
    }
}
