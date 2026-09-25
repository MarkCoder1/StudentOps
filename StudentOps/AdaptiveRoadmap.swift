import Foundation

// MARK: - Adaptive Item State

/// The current state of a skill/action relative to the student's progress.
enum AdaptiveItemState: String, Codable, Hashable, CaseIterable {
    case completed = "completed"
    case inProgress = "inProgress"
    case ready = "ready"
    case blocked = "blocked"
    case notStarted = "notStarted"
    case covered = "covered"
}

// MARK: - Adaptive Recommendation Type

/// Finite enum of adaptation types — no arbitrary AI-generated types allowed.
enum AdaptiveRoadmapRecommendationType: String, Codable, Hashable, CaseIterable {
    case `continue` = "continue"
    case skillGap = "skillGap"
    case prerequisite = "prerequisite"
    case project = "project"
    case opportunity = "opportunity"
    case evidence = "evidence"
    case review = "review"
    case blocked = "blocked"
    case complete = "complete"
}

// MARK: - Adaptive Reason Code

/// Structured reason codes for deterministic explainability.
enum AdaptiveReasonCode: String, Codable, Hashable {
    case missingPrerequisite = "missingPrerequisite"
    case activeSkillGap = "activeSkillGap"
    case roadmapAligned = "roadmapAligned"
    case projectBuildsSkill = "projectBuildsSkill"
    case opportunityBuildsSkill = "opportunityBuildsSkill"
    case evidenceMissing = "evidenceMissing"
    case actionIncomplete = "actionIncomplete"
    case actionCompleted = "actionCompleted"
    case blockedByPrerequisite = "blockedByPrerequisite"
    case targetAlreadyCovered = "targetAlreadyCovered"
    case insufficientContext = "insufficientContext"
}

// MARK: - Adaptive Roadmap Context

/// Represents the inputs used to calculate adaptation.
/// Derived from the Student Graph — never independently persisted.
struct AdaptiveRoadmapContext: Hashable, Codable {
    let roadmapID: String
    let roadmapTitle: String
    let targetCareerID: String?
    let targetGoal: String?
    let currentSkills: [String]
    let skillGaps: [String]
    let completedActionIDs: [String]
    let completedMilestoneIDs: [String]
    let activeRoadmapID: String?
    let completedProjectIDs: [String]
    let activeProjectIDs: [String]
    let relevantOpportunityIDs: [String]
    let evidenceSkillIDs: [String]
    let prerequisites: [String]
    let hasInsufficientContext: Bool
}

// MARK: - Adaptive Roadmap Recommendation

/// Represents a recommended roadmap change/action with full traceability.
struct AdaptiveRoadmapRecommendation: Identifiable, Hashable, Codable {
    let id: String
    let type: AdaptiveRoadmapRecommendationType
    let title: String
    let reason: String
    let reasonCode: AdaptiveReasonCode
    let priority: Int
    let state: AdaptiveItemState?
    let relatedSkillID: String?
    let prerequisiteSkillIDs: [String]
    let relatedProjectID: String?
    let relatedOpportunityID: String?
    let relatedRoadmapActionID: String?
    let evidenceSkillID: String?
    let isBlocked: Bool
    let blockedReason: String?

    init(
        id: String,
        type: AdaptiveRoadmapRecommendationType,
        title: String,
        reason: String,
        reasonCode: AdaptiveReasonCode,
        priority: Int,
        state: AdaptiveItemState? = nil,
        relatedSkillID: String? = nil,
        prerequisiteSkillIDs: [String] = [],
        relatedProjectID: String? = nil,
        relatedOpportunityID: String? = nil,
        relatedRoadmapActionID: String? = nil,
        evidenceSkillID: String? = nil,
        isBlocked: Bool = false,
        blockedReason: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.reason = reason
        self.reasonCode = reasonCode
        self.priority = priority
        self.state = state
        self.relatedSkillID = relatedSkillID
        self.prerequisiteSkillIDs = prerequisiteSkillIDs
        self.relatedProjectID = relatedProjectID
        self.relatedOpportunityID = relatedOpportunityID
        self.relatedRoadmapActionID = relatedRoadmapActionID
        self.evidenceSkillID = evidenceSkillID
        self.isBlocked = isBlocked
        self.blockedReason = blockedReason
    }
}

// MARK: - Adaptive Roadmap Result

/// Complete derived adaptive recommendation layer for a roadmap.
/// Never stored as canonical student data — recomputed on demand.
struct AdaptiveRoadmapResult: Hashable, Codable {
    let roadmapID: String
    let roadmapTitle: String
    let targetCareerID: String?
    let targetGoal: String?
    let context: AdaptiveRoadmapContext
    let recommendedNext: [AdaptiveRoadmapRecommendation]
    let blocked: [AdaptiveRoadmapRecommendation]
    let completed: [AdaptiveRoadmapRecommendation]
    let skillGaps: [String]
    let prerequisiteWarnings: [String]
    let isInsufficientContext: Bool
    let explanations: [String]
    let generatedAt: Date

    init(
        roadmapID: String,
        roadmapTitle: String,
        targetCareerID: String?,
        targetGoal: String?,
        context: AdaptiveRoadmapContext,
        recommendedNext: [AdaptiveRoadmapRecommendation],
        blocked: [AdaptiveRoadmapRecommendation],
        completed: [AdaptiveRoadmapRecommendation],
        skillGaps: [String],
        prerequisiteWarnings: [String],
        isInsufficientContext: Bool,
        explanations: [String],
        generatedAt: Date = Date()
    ) {
        self.roadmapID = roadmapID
        self.roadmapTitle = roadmapTitle
        self.targetCareerID = targetCareerID
        self.targetGoal = targetGoal
        self.context = context
        self.recommendedNext = recommendedNext
        self.blocked = blocked
        self.completed = completed
        self.skillGaps = skillGaps
        self.prerequisiteWarnings = prerequisiteWarnings
        self.isInsufficientContext = isInsufficientContext
        self.explanations = explanations
        self.generatedAt = generatedAt
    }
}