import Foundation

// MARK: - Adaptive Proposal Change Type (Phase 12B)
// Finite, deterministic — no arbitrary rewriting.

enum AdaptiveProposalChangeType: String, Codable, Hashable, CaseIterable {
    case reorderAction = "reorderAction"
    case unlockAction = "unlockAction"
    case deferAction = "deferAction"
    case insertExistingProject = "insertExistingProject"
    case connectOpportunity = "connectOpportunity"
    case markProgressDerived = "markProgressDerived"
    case adjustSkillSequence = "adjustSkillSequence"
}

// MARK: - Adaptive Proposal Reason Code (Phase 12B)
// Deterministic, explainable. Subset maps to AdaptiveReasonCode but proposal-specific for traceability.

enum AdaptiveProposalReasonCode: String, Codable, Hashable, CaseIterable {
    case newlySatisfiedPrerequisite = "newlySatisfiedPrerequisite"
    case blockedActionReady = "blockedActionReady"
    case relevanceChanged = "relevanceChanged"
    case projectSatisfiesNeed = "projectSatisfiesNeed"
    case opportunityAligned = "opportunityAligned"
    case evidenceConnection = "evidenceConnection"
    case prerequisiteSatisfied = "prerequisiteSatisfied"
    case skillGapReduced = "skillGapReduced"
    case projectCompleted = "projectCompleted"
    case dependencyUnlocked = "dependencyUnlocked"
    case actionCompleted = "actionCompleted"
    case skillDemonstrated = "skillDemonstrated"
}

// MARK: - Proposal State Snapshot
// Minimal before/after representation for reversibility without version control.

struct AdaptiveProposalStateSnapshot: Hashable, Codable {
    /// Ordered milestone IDs for roadmap (if reordering milestones/phases)
    let orderedMilestoneIDs: [String]?
    /// Ordered action IDs for a specific milestone (if reordering actions)
    let orderedActionIDs: [String]?
    /// Deferred action IDs snapshot
    let deferredActionIDs: [String]?
    /// Linked project ID (if any)
    let linkedProjectID: String?
    /// Linked opportunity ID (if any)
    let linkedOpportunityID: String?
    /// Completed action IDs snapshot (for markProgressDerived)
    let completedActionIDs: [String]?
    /// Roadmap progress snapshot (roadmapID -> completedCount)
    let roadmapProgress: [String: Int]?
    /// Skill sequence (ordered skill IDs) for adjustSkillSequence
    let skillSequence: [String]?

    init(
        orderedMilestoneIDs: [String]? = nil,
        orderedActionIDs: [String]? = nil,
        deferredActionIDs: [String]? = nil,
        linkedProjectID: String? = nil,
        linkedOpportunityID: String? = nil,
        completedActionIDs: [String]? = nil,
        roadmapProgress: [String: Int]? = nil,
        skillSequence: [String]? = nil
    ) {
        self.orderedMilestoneIDs = orderedMilestoneIDs
        self.orderedActionIDs = orderedActionIDs
        self.deferredActionIDs = deferredActionIDs
        self.linkedProjectID = linkedProjectID
        self.linkedOpportunityID = linkedOpportunityID
        self.completedActionIDs = completedActionIDs
        self.roadmapProgress = roadmapProgress
        self.skillSequence = skillSequence
    }
}

// MARK: - Adaptive Roadmap Proposal (Phase 12B)
// Deterministic proposed change. Never auto-applied. User must explicitly apply via AppDataStore.

struct AdaptiveRoadmapProposal: Identifiable, Hashable, Codable {
    // Stable ID: deterministic composite of roadmap + type + key
    let id: String
    let roadmapID: String
    let changeType: AdaptiveProposalChangeType
    let affectedActionIDs: [String]
    let affectedMilestoneIDs: [String]
    let affectedPhaseIDs: [String] // alias for milestones (phases == milestones for compatibility)
    let title: String
    let explanation: String
    let reasonCode: AdaptiveProposalReasonCode
    let beforeState: AdaptiveProposalStateSnapshot?
    let afterState: AdaptiveProposalStateSnapshot?
    let priority: Int // higher = more urgent (deterministic)
    let isReversible: Bool
    let createdAt: Date
    // Deterministic source references (nil when not applicable)
    let sourceSkillID: String?
    let sourceProjectID: String?
    let sourceOpportunityID: String?
    let sourceMilestoneID: String?
    let prerequisiteSkillIDs: [String]

    init(
        id: String,
        roadmapID: String,
        changeType: AdaptiveProposalChangeType,
        affectedActionIDs: [String] = [],
        affectedMilestoneIDs: [String] = [],
        affectedPhaseIDs: [String]? = nil,
        title: String,
        explanation: String,
        reasonCode: AdaptiveProposalReasonCode,
        beforeState: AdaptiveProposalStateSnapshot? = nil,
        afterState: AdaptiveProposalStateSnapshot? = nil,
        priority: Int,
        isReversible: Bool = true,
        createdAt: Date = Date(timeIntervalSince1970: 0), // deterministic default; engine overrides with fixed epoch or derived
        sourceSkillID: String? = nil,
        sourceProjectID: String? = nil,
        sourceOpportunityID: String? = nil,
        sourceMilestoneID: String? = nil,
        prerequisiteSkillIDs: [String] = []
    ) {
        self.id = id
        self.roadmapID = roadmapID
        self.changeType = changeType
        self.affectedActionIDs = affectedActionIDs.sorted()
        self.affectedMilestoneIDs = affectedMilestoneIDs.sorted()
        self.affectedPhaseIDs = (affectedPhaseIDs ?? affectedMilestoneIDs).sorted()
        self.title = title
        self.explanation = explanation
        self.reasonCode = reasonCode
        self.beforeState = beforeState
        self.afterState = afterState
        self.priority = priority
        self.isReversible = isReversible
        self.createdAt = createdAt
        self.sourceSkillID = sourceSkillID.map { Skill.normalizeID($0) }
        self.sourceProjectID = sourceProjectID
        self.sourceOpportunityID = sourceOpportunityID
        self.sourceMilestoneID = sourceMilestoneID
        self.prerequisiteSkillIDs = prerequisiteSkillIDs.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }.sorted()
    }

    // Deterministic ID helper
    static func makeID(roadmapID: String, type: AdaptiveProposalChangeType, key: String) -> String {
        let safeKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "-")
        return "\(roadmapID)-\(type.rawValue)-\(safeKey)"
    }
}

// MARK: - Adaptive Proposal History Record (for reversibility)

struct AppliedProposalRecord: Hashable, Codable {
    let proposalID: String
    let roadmapID: String
    let changeType: AdaptiveProposalChangeType
    let beforeState: AdaptiveProposalStateSnapshot?
    let afterState: AdaptiveProposalStateSnapshot?
    let appliedAt: Date
    let affectedActionIDs: [String]
    let affectedMilestoneIDs: [String]
    let isReversible: Bool

    init(proposal: AdaptiveRoadmapProposal, appliedAt: Date = Date()) {
        self.proposalID = proposal.id
        self.roadmapID = proposal.roadmapID
        self.changeType = proposal.changeType
        self.beforeState = proposal.beforeState
        self.afterState = proposal.afterState
        self.appliedAt = appliedAt
        self.affectedActionIDs = proposal.affectedActionIDs
        self.affectedMilestoneIDs = proposal.affectedMilestoneIDs
        self.isReversible = proposal.isReversible
    }
}

// MARK: - Adaptive Overrides (single persisted blob)

struct AdaptiveRoadmapOverrides: Hashable, Codable {
    var deferredActionIDs: Set<String> = []
    var linkedProjects: [String: String] = [:] // actionID -> projectID
    var linkedOpportunities: [String: String] = [:] // actionID -> opportunityID
    var reorderedMilestones: [String: [String]] = [:] // roadmapID -> ordered milestoneIDs
    var reorderedActions: [String: [String]] = [:] // milestoneID -> ordered actionIDs
    var completedActionOverrides: Set<String> = [] // actions marked via proposals (mirrors completedActionIDs but tracked for reversibility)
    var appliedProposalIDs: Set<String> = []
    var history: [AppliedProposalRecord] = []
    var skillSequenceOverrides: [String: [String]] = [:] // roadmapID -> ordered skillIDs
    var dismissedProposalIDs: Set<String> = []

    init() {}
}
