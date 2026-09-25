import Foundation

// MARK: - Supporting Types for Enhanced Milestones

/// A structured action item within a milestone, providing a clear sequence of steps.
struct MilestoneAction: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String
    let order: Int
    let estimatedTime: String?

    init(id: String = UUID().uuidString, title: String, description: String, order: Int = 0, estimatedTime: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.order = order
        self.estimatedTime = estimatedTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        order = (try? c.decode(Int.self, forKey: .order)) ?? 0
        estimatedTime = try? c.decode(String.self, forKey: .estimatedTime)
    }
}

/// How completion of a milestone is validated.
struct MilestoneValidation: Hashable, Codable {
    /// The type of validation: "self", "portfolio", "instructor", "automated", etc.
    let method: String?
    /// Human-readable description of what needs to be submitted or demonstrated.
    let requirement: String?

    init(method: String? = nil, requirement: String? = nil) {
        self.method = method
        self.requirement = requirement
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        method = try? c.decode(String.self, forKey: .method)
        requirement = try? c.decode(String.self, forKey: .requirement)
    }
}

/// An evidence artifact that demonstrates completion of a milestone.
struct MilestoneEvidence: Identifiable, Hashable, Codable {
    let id: String
    /// The type of evidence: "project", "screenshot", "reflection", "certificate", "link", etc.
    let type: String
    let title: String
    let description: String?

    init(id: String = UUID().uuidString, type: String, title: String, description: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        type = (try? c.decode(String.self, forKey: .type)) ?? "unknown"
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
    }
}

// MARK: - Validation / Assessment Types

/// A single multiple-choice question in a milestone assessment.
struct ValidationQuestion: Identifiable, Hashable, Codable {
    let id: String
    let question: String
    let choices: [String]
    let correctAnswer: Int
    let explanation: String

    init(id: String = UUID().uuidString, question: String, choices: [String], correctAnswer: Int, explanation: String) {
        self.id = id
        self.question = question
        self.choices = choices
        self.correctAnswer = correctAnswer
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        question = (try? c.decode(String.self, forKey: .question)) ?? ""
        choices = (try? c.decode([String].self, forKey: .choices)) ?? []
        correctAnswer = (try? c.decode(Int.self, forKey: .correctAnswer)) ?? 0
        explanation = (try? c.decode(String.self, forKey: .explanation)) ?? ""
    }
}

/// A deterministic assessment attached to a milestone.
/// Career-agnostic — reusable across any roadmap domain.
struct MilestoneAssessment: Identifiable, Hashable, Codable {
    let id: String
    let questions: [ValidationQuestion]
    let passThreshold: Int // percentage 0–100, default 70

    init(id: String = UUID().uuidString, questions: [ValidationQuestion], passThreshold: Int = 70) {
        self.id = id
        self.questions = questions
        self.passThreshold = passThreshold
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        questions = (try? c.decode([ValidationQuestion].self, forKey: .questions)) ?? []
        passThreshold = (try? c.decode(Int.self, forKey: .passThreshold)) ?? 70
    }
}

/// A student's attempt at a milestone assessment.
struct ValidationAttempt: Identifiable, Hashable, Codable {
    let id: String
    let validationID: String
    let selectedAnswers: [String: Int] // questionID → selected index
    let score: Int
    let totalQuestions: Int
    let percentage: Int
    let passed: Bool

    init(id: String = UUID().uuidString, validationID: String, selectedAnswers: [String: Int], score: Int, totalQuestions: Int, percentage: Int, passed: Bool) {
        self.id = id
        self.validationID = validationID
        self.selectedAnswers = selectedAnswers
        self.score = score
        self.totalQuestions = totalQuestions
        self.percentage = percentage
        self.passed = passed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        validationID = (try? c.decode(String.self, forKey: .validationID)) ?? ""
        selectedAnswers = (try? c.decode([String: Int].self, forKey: .selectedAnswers)) ?? [:]
        score = (try? c.decode(Int.self, forKey: .score)) ?? 0
        totalQuestions = (try? c.decode(Int.self, forKey: .totalQuestions)) ?? 0
        percentage = (try? c.decode(Int.self, forKey: .percentage)) ?? 0
        passed = (try? c.decode(Bool.self, forKey: .passed)) ?? false
    }
}

// MARK: - Evidence Types

/// Controlled type describing what kind of evidence a record represents.
/// Career-agnostic — reusable across any roadmap, project, or opportunity.
enum EvidenceType: String, Codable, Hashable, CaseIterable {
    case milestoneCompletion = "milestone-completion"
    case projectWork = "project-work"
    case validation = "validation"
    case artifact = "artifact"
    case opportunityParticipation = "opportunity-participation"
    case leadershipActivity = "leadership-activity"
    case communityActivity = "community-activity"
    case learning = "learning"
    case other = "other"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "other"
        self = EvidenceType(rawValue: raw) ?? .other
    }

    var displayName: String {
        switch self {
        case .milestoneCompletion: return "Milestone"
        case .projectWork: return "Project"
        case .validation: return "Validation"
        case .artifact: return "Artifact"
        case .opportunityParticipation: return "Opportunity"
        case .leadershipActivity: return "Leadership"
        case .communityActivity: return "Community"
        case .learning: return "Learning"
        case .other: return "Other"
        }
    }
}

/// Where an evidence record originated.
enum EvidenceSource: String, Codable, Hashable, CaseIterable {
    case roadmapMilestone = "roadmapMilestone"
    case project = "project"
    case validation = "validation"
    case opportunity = "opportunity"
    case studentEntered = "studentEntered"
    case system = "system"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "unknown"
        self = EvidenceSource(rawValue: raw) ?? .unknown
    }
}

/// Explicit status of an evidence record.
enum EvidenceStatus: String, Codable, Hashable, CaseIterable {
    case recorded = "recorded"
    case verified = "verified"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "recorded"
        self = EvidenceStatus(rawValue: raw) ?? .recorded
    }
}

/// Structured artifact/link information for tangible evidence.
struct EvidenceArtifact: Hashable, Codable {
    let type: String
    let title: String
    let url: String?
    let description: String?

    init(type: String, title: String, url: String? = nil, description: String? = nil) {
        self.type = type
        self.title = title
        self.url = url
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? "link"
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        url = try? c.decode(String.self, forKey: .url)
        description = try? c.decode(String.self, forKey: .description)
    }
}

// MARK: - Evidence Record (Student-Generated)

/// Canonical record of something the student actually did, completed, demonstrated, or produced.
/// Created deterministically from roadmap milestone completion or other legitimate product state.
/// Career-agnostic — reusable across any roadmap domain.
struct EvidenceRecord: Identifiable, Hashable, Codable {
    let id: String
    /// Controlled type describing what kind of evidence this is.
    let type: EvidenceType
    let title: String
    let description: String?
    let roadmapID: String
    let milestoneID: String
    /// Legacy field preserved for backward compatibility — prefer `createdAt`.
    let completionDate: Date
    /// When Student OPS recorded this evidence.
    let createdAt: Date
    /// When the underlying activity actually occurred, when known.
    let occurredAt: Date?
    /// Where the evidence originated.
    let source: EvidenceSource
    /// Explicit status — only `verified` when actual verification exists.
    let status: EvidenceStatus
    /// Optional action within a milestone that this evidence relates to.
    let actionID: String?
    /// Canonical skill IDs this evidence demonstrates (normalized via `Skill.normalizeID`).
    let skillIDs: [String]?
    /// Structured artifact/link if tangible output exists.
    let artifact: EvidenceArtifact?
    /// Validation result if available at time of completion.
    let validationID: String?
    let validationScore: Int?
    let validationPercentage: Int?
    let validationPassed: Bool?
    /// Associated project ID if applicable (optional).
    let projectID: String?
    /// Associated opportunity ID if applicable (optional — only for actual participation).
    let opportunityID: String?

    // Backward-compat: string-typed type accessor
    var typeRawValue: String { type.rawValue }

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, roadmapID, milestoneID, completionDate, createdAt, occurredAt, source, status, actionID, skillIDs, artifact, validationID, validationScore, validationPercentage, validationPassed, projectID, opportunityID
    }

    init(
        id: String = UUID().uuidString,
        type: EvidenceType,
        title: String,
        description: String? = nil,
        roadmapID: String,
        milestoneID: String,
        completionDate: Date = Date(),
        createdAt: Date? = nil,
        occurredAt: Date? = nil,
        source: EvidenceSource = .roadmapMilestone,
        status: EvidenceStatus = .recorded,
        actionID: String? = nil,
        skillIDs: [String]? = nil,
        artifact: EvidenceArtifact? = nil,
        validationID: String? = nil,
        validationScore: Int? = nil,
        validationPercentage: Int? = nil,
        validationPassed: Bool? = nil,
        projectID: String? = nil,
        opportunityID: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.roadmapID = roadmapID
        self.milestoneID = milestoneID
        self.completionDate = completionDate
        self.createdAt = createdAt ?? completionDate
        self.occurredAt = occurredAt
        self.source = source
        self.status = status
        self.actionID = actionID
        self.skillIDs = skillIDs?.isEmpty == true ? nil : skillIDs
        self.artifact = artifact
        self.validationID = validationID
        self.validationScore = validationScore
        self.validationPercentage = validationPercentage
        self.validationPassed = validationPassed
        self.projectID = projectID
        self.opportunityID = opportunityID
    }

    /// Convenience init accepting string type for migration/call-site compatibility.
    init(
        id: String = UUID().uuidString,
        type rawType: String,
        title: String,
        description: String? = nil,
        roadmapID: String,
        milestoneID: String,
        completionDate: Date = Date(),
        validationID: String? = nil,
        validationScore: Int? = nil,
        validationPercentage: Int? = nil,
        validationPassed: Bool? = nil,
        projectID: String? = nil,
        opportunityID: String? = nil
    ) {
        self.init(
            id: id,
            type: EvidenceType(rawValue: rawType) ?? .other,
            title: title,
            description: description,
            roadmapID: roadmapID,
            milestoneID: milestoneID,
            completionDate: completionDate,
            source: .roadmapMilestone,
            status: .recorded,
            validationID: validationID,
            validationScore: validationScore,
            validationPercentage: validationPercentage,
            validationPassed: validationPassed,
            projectID: projectID,
            opportunityID: opportunityID
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        // type may be stored as string — handle both enum and legacy string values
        if let t = try? c.decode(EvidenceType.self, forKey: .type) {
            type = t
        } else if let raw = try? c.decode(String.self, forKey: .type) {
            type = EvidenceType(rawValue: raw) ?? .other
        } else {
            type = .other
        }
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        roadmapID = (try? c.decode(String.self, forKey: .roadmapID)) ?? ""
        milestoneID = (try? c.decode(String.self, forKey: .milestoneID)) ?? ""
        completionDate = (try? c.decode(Date.self, forKey: .completionDate)) ?? Date()
        // createdAt falls back to completionDate for legacy records
        if let ca = try? c.decode(Date.self, forKey: .createdAt) {
            createdAt = ca
        } else {
            createdAt = (try? c.decode(Date.self, forKey: .completionDate)) ?? Date()
        }
        occurredAt = try? c.decode(Date.self, forKey: .occurredAt)
        source = (try? c.decode(EvidenceSource.self, forKey: .source)) ?? .roadmapMilestone
        status = (try? c.decode(EvidenceStatus.self, forKey: .status)) ?? .recorded
        actionID = try? c.decode(String.self, forKey: .actionID)
        skillIDs = try? c.decode([String].self, forKey: .skillIDs)
        artifact = try? c.decode(EvidenceArtifact.self, forKey: .artifact)
        validationID = try? c.decode(String.self, forKey: .validationID)
        validationScore = try? c.decode(Int.self, forKey: .validationScore)
        validationPercentage = try? c.decode(Int.self, forKey: .validationPercentage)
        validationPassed = try? c.decode(Bool.self, forKey: .validationPassed)
        projectID = try? c.decode(String.self, forKey: .projectID)
        opportunityID = try? c.decode(String.self, forKey: .opportunityID)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(roadmapID, forKey: .roadmapID)
        try c.encode(milestoneID, forKey: .milestoneID)
        try c.encode(completionDate, forKey: .completionDate)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(occurredAt, forKey: .occurredAt)
        try c.encode(source, forKey: .source)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(actionID, forKey: .actionID)
        try c.encodeIfPresent(skillIDs, forKey: .skillIDs)
        try c.encodeIfPresent(artifact, forKey: .artifact)
        try c.encodeIfPresent(validationID, forKey: .validationID)
        try c.encodeIfPresent(validationScore, forKey: .validationScore)
        try c.encodeIfPresent(validationPercentage, forKey: .validationPercentage)
        try c.encodeIfPresent(validationPassed, forKey: .validationPassed)
        try c.encodeIfPresent(projectID, forKey: .projectID)
        try c.encodeIfPresent(opportunityID, forKey: .opportunityID)
    }
}

// MARK: - Learning Resource Types

/// The type of learning resource content.
enum MilestoneResourceType: String, Hashable, Codable {
    case article
    case video
    case documentation
    case interactive
    case course
}

/// A structured learning resource associated with a milestone.
/// Career-agnostic — reusable across any roadmap domain.
struct MilestoneResource: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let provider: String
    let url: String
    let type: MilestoneResourceType
    let description: String
    let estimatedTime: String?

    init(id: String = UUID().uuidString, title: String, provider: String, url: String, type: MilestoneResourceType, description: String, estimatedTime: String? = nil) {
        self.id = id
        self.title = title
        self.provider = provider
        self.url = url
        self.type = type
        self.description = description
        self.estimatedTime = estimatedTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        provider = (try? c.decode(String.self, forKey: .provider)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        type = (try? c.decode(MilestoneResourceType.self, forKey: .type)) ?? .article
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        estimatedTime = try? c.decode(String.self, forKey: .estimatedTime)
    }
}

// MARK: - RoadmapMilestone

struct RoadmapMilestone: Identifiable, Hashable, Codable {
    // ── Existing fields (unchanged) ───────────────────────────────
    let id: String
    let title: String
    let subtitle: String
    let estimatedTime: String
    let whatItAccomplishes: String
    let whyItMatters: String
    let recommendedActions: [String]
    let resources: [String]
    let projectAction: String?

    // ── New fields (Phase 6.4.1 — all optional, backward-compatible) ──
    /// What success looks like for this milestone.
    let goal: String?
    /// Structured action items with ordering and descriptions.
    let actions: [MilestoneAction]?
    /// How completion is validated.
    let validation: MilestoneValidation?
    /// Skills developed by completing this milestone.
    let skillsDeveloped: [String]?
    /// Evidence artifacts the student should produce.
    let evidence: [MilestoneEvidence]?
    /// Explicit criteria that define when this milestone is done.
    let completionCriteria: [String]?
    /// IDs of milestones that must be completed before this one.
    let dependencies: [String]?
    /// Structured learning resources (articles, videos, docs) for this milestone.
    let learningResources: [MilestoneResource]?
    /// Deterministic assessment with questions and a pass threshold.
    let assessment: MilestoneAssessment?

    // ── Existing memberwise init (preserved exactly) ───────────────
    init(
        id: String,
        title: String,
        subtitle: String,
        estimatedTime: String,
        whatItAccomplishes: String = "Make measurable progress toward this roadmap goal.",
        whyItMatters: String = "This step builds evidence and momentum for the milestones that follow.",
        recommendedActions: [String] = [],
        resources: [String] = [],
        projectAction: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.estimatedTime = estimatedTime
        self.whatItAccomplishes = whatItAccomplishes
        self.whyItMatters = whyItMatters
        self.recommendedActions = recommendedActions
        self.resources = resources
        self.projectAction = projectAction
        // New fields default to nil — existing call sites unaffected
        self.goal = nil
        self.actions = nil
        self.validation = nil
        self.skillsDeveloped = nil
        self.evidence = nil
        self.completionCriteria = nil
        self.dependencies = nil
        self.learningResources = nil
        self.assessment = nil
    }

    // ── Extended init (Phase 6.4.1 — for enhanced milestones) ────
    init(
        id: String,
        title: String,
        subtitle: String,
        estimatedTime: String,
        whatItAccomplishes: String = "Make measurable progress toward this roadmap goal.",
        whyItMatters: String = "This step builds evidence and momentum for the milestones that follow.",
        recommendedActions: [String] = [],
        resources: [String] = [],
        projectAction: String? = nil,
        goal: String? = nil,
        actions: [MilestoneAction]? = nil,
        validation: MilestoneValidation? = nil,
        skillsDeveloped: [String]? = nil,
        evidence: [MilestoneEvidence]? = nil,
        completionCriteria: [String]? = nil,
        dependencies: [String]? = nil,
        learningResources: [MilestoneResource]? = nil,
        assessment: MilestoneAssessment? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.estimatedTime = estimatedTime
        self.whatItAccomplishes = whatItAccomplishes
        self.whyItMatters = whyItMatters
        self.recommendedActions = recommendedActions
        self.resources = resources
        self.projectAction = projectAction
        self.goal = goal
        self.actions = actions
        self.validation = validation
        self.skillsDeveloped = skillsDeveloped
        self.evidence = evidence
        self.completionCriteria = completionCriteria
        self.dependencies = dependencies
        self.learningResources = learningResources
        self.assessment = assessment
    }

    // ── Custom Codable (handles Set, enums, and missing keys) ──────

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, estimatedTime, whatItAccomplishes, whyItMatters
        case recommendedActions, resources, projectAction
        case goal, actions, validation, skillsDeveloped, evidence, completionCriteria, dependencies, learningResources, assessment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decode(String.self, forKey: .subtitle)
        estimatedTime = try c.decode(String.self, forKey: .estimatedTime)
        whatItAccomplishes = try c.decode(String.self, forKey: .whatItAccomplishes)
        whyItMatters = try c.decode(String.self, forKey: .whyItMatters)
        recommendedActions = (try? c.decode([String].self, forKey: .recommendedActions)) ?? []
        resources = (try? c.decode([String].self, forKey: .resources)) ?? []
        projectAction = try? c.decode(String.self, forKey: .projectAction)
        // New fields — gracefully default when missing
        goal = try? c.decode(String.self, forKey: .goal)
        actions = try? c.decode([MilestoneAction].self, forKey: .actions)
        validation = try? c.decode(MilestoneValidation.self, forKey: .validation)
        skillsDeveloped = try? c.decode([String].self, forKey: .skillsDeveloped)
        evidence = try? c.decode([MilestoneEvidence].self, forKey: .evidence)
        completionCriteria = try? c.decode([String].self, forKey: .completionCriteria)
        dependencies = try? c.decode([String].self, forKey: .dependencies)
        learningResources = try? c.decode([MilestoneResource].self, forKey: .learningResources)
        assessment = try? c.decode(MilestoneAssessment.self, forKey: .assessment)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(subtitle, forKey: .subtitle)
        try c.encode(estimatedTime, forKey: .estimatedTime)
        try c.encode(whatItAccomplishes, forKey: .whatItAccomplishes)
        try c.encode(whyItMatters, forKey: .whyItMatters)
        try c.encode(recommendedActions, forKey: .recommendedActions)
        try c.encode(resources, forKey: .resources)
        try c.encodeIfPresent(projectAction, forKey: .projectAction)
        // New fields — only encode non-nil values for compact JSON
        try c.encodeIfPresent(goal, forKey: .goal)
        try c.encodeIfPresent(actions, forKey: .actions)
        try c.encodeIfPresent(validation, forKey: .validation)
        try c.encodeIfPresent(skillsDeveloped, forKey: .skillsDeveloped)
        try c.encodeIfPresent(evidence, forKey: .evidence)
        try c.encodeIfPresent(completionCriteria, forKey: .completionCriteria)
        try c.encodeIfPresent(dependencies, forKey: .dependencies)
        try c.encodeIfPresent(learningResources, forKey: .learningResources)
        try c.encodeIfPresent(assessment, forKey: .assessment)
    }
}

typealias Milestone = RoadmapMilestone

// MARK: - Roadmap

struct Roadmap: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let goal: String
    let category: RoadmapCategory
    let description: String
    let milestones: [RoadmapMilestone]
    let relevantInterests: Set<String>
    let relevantSkills: Set<String>
    let relevantCareers: Set<String>
    let relevantFields: Set<String>
    let eligibleGrades: Set<Grade>
    let collegeFocused: Bool

    // Explicit memberwise init (required because custom Codable prevents auto-synthesis)
    init(
        id: String,
        title: String,
        goal: String,
        category: RoadmapCategory,
        description: String,
        milestones: [RoadmapMilestone],
        relevantInterests: Set<String>,
        relevantSkills: Set<String>,
        relevantCareers: Set<String>,
        relevantFields: Set<String>,
        eligibleGrades: Set<Grade>,
        collegeFocused: Bool
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.category = category
        self.description = description
        self.milestones = milestones
        self.relevantInterests = relevantInterests
        self.relevantSkills = relevantSkills
        self.relevantCareers = relevantCareers
        self.relevantFields = relevantFields
        self.eligibleGrades = eligibleGrades
        self.collegeFocused = collegeFocused
    }

    // ── Custom Codable (handles Set<String>, Set<Grade>) ──────────

    enum CodingKeys: String, CodingKey {
        case id, title, goal, category, description, milestones
        case relevantInterests, relevantSkills, relevantCareers, relevantFields
        case eligibleGrades, collegeFocused
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        goal = try c.decode(String.self, forKey: .goal)
        category = try c.decode(RoadmapCategory.self, forKey: .category)
        description = try c.decode(String.self, forKey: .description)
        milestones = try c.decode([RoadmapMilestone].self, forKey: .milestones)
        relevantInterests = try c.decodeIfPresent(Set<String>.self, forKey: .relevantInterests) ?? []
        relevantSkills = try c.decodeIfPresent(Set<String>.self, forKey: .relevantSkills) ?? []
        relevantCareers = try c.decodeIfPresent(Set<String>.self, forKey: .relevantCareers) ?? []
        relevantFields = try c.decodeIfPresent(Set<String>.self, forKey: .relevantFields) ?? []
        eligibleGrades = try c.decodeIfPresent(Set<Grade>.self, forKey: .eligibleGrades) ?? []
        collegeFocused = try c.decodeIfPresent(Bool.self, forKey: .collegeFocused) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(goal, forKey: .goal)
        try c.encode(category, forKey: .category)
        try c.encode(description, forKey: .description)
        try c.encode(milestones, forKey: .milestones)
        try c.encode(relevantInterests, forKey: .relevantInterests)
        try c.encode(relevantSkills, forKey: .relevantSkills)
        try c.encode(relevantCareers, forKey: .relevantCareers)
        try c.encode(relevantFields, forKey: .relevantFields)
        try c.encode(eligibleGrades, forKey: .eligibleGrades)
        try c.encode(collegeFocused, forKey: .collegeFocused)
    }
}

// MARK: - Roadmap Activation

/// The status of a student's activation for a specific roadmap.
enum RoadmapActivationStatus: String, Codable, Hashable {
    /// Student has explicitly started this roadmap.
    case active
    /// Student has completed all milestones (or roadmap was completed before deactivation).
    case completed
}

/// Student-specific activation state for a single roadmap.
/// Persists across app relaunches. Does NOT duplicate roadmap content.
struct ActiveRoadmap: Identifiable, Hashable, Codable {
    let roadmapID: String
    let status: RoadmapActivationStatus
    let startedAt: TimeInterval
    var id: String { roadmapID }

    init(roadmapID: String, status: RoadmapActivationStatus = .active, startedAt: TimeInterval = Date().timeIntervalSince1970) {
        self.roadmapID = roadmapID
        self.status = status
        self.startedAt = startedAt
    }
}

// MARK: - ScoredRoadmap

struct ScoredRoadmap: Identifiable, Hashable {
    let roadmap: Roadmap
    let matchScore: Int
    let completedMilestones: Int
    var id: String { roadmap.id }
    var progress: Int { ProgressCalculator.percent(completed: completedMilestones, total: roadmap.milestones.count) }
    var currentMilestone: RoadmapMilestone? {
        guard completedMilestones < roadmap.milestones.count else { return nil }
        return roadmap.milestones[completedMilestones]
    }
    var isCompleted: Bool { completedMilestones >= roadmap.milestones.count }
}
