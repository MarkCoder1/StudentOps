import Foundation

// MARK: - Project Status

enum ProjectStatus: String, Codable, Hashable, CaseIterable {
    case planned = "planned"
    case inProgress = "inProgress"
    case completed = "completed"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "planned"
        // Handle legacy/case variations: "In Progress", "in_progress", etc.
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        switch normalized {
        case "planned": self = .planned
        case "inprogress": self = .inProgress
        case "completed", "complete", "done": self = .completed
        default: self = .planned
        }
    }

    var displayName: String {
        switch self {
        case .planned: return "Planned"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }

    var rawDisplay: String {
        switch self {
        case .planned: return "Planned"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Project Link

struct ProjectLink: Identifiable, Hashable, Codable {
    let id: String
    var label: String
    var url: String

    init(id: String = UUID().uuidString, label: String, url: String) {
        self.id = id
        let tLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = tLabel.isEmpty ? "Link" : tLabel
        self.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum CodingKeys: String, CodingKey { case id, label, url, title }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        // label may be stored as "label" or "title"
        let rawLabel = (try? c.decode(String.self, forKey: .label)) ?? (try? c.decode(String.self, forKey: .title)) ?? "Link"
        let t = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        label = t.isEmpty ? "Link" : t
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(label, forKey: .label)
        try c.encode(url, forKey: .url)
    }

    /// Validates that url is http/https with host
    var isValidURL: Bool {
        let t = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard let u = URL(string: t) else { return false }
        guard let scheme = u.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
        return u.host != nil
    }
}

// MARK: - Project Milestone

struct ProjectMilestone: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let estimatedTime: String
}

// MARK: - Project

struct Project: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var category: String
    var goal: String
    var description: String
    var skills: [String]
    var milestones: [ProjectMilestone]
    var resources: [String]
    var estimatedCompletion: String
    var relevantInterests: Set<String>
    var relevantSkills: Set<String>
    var relevantCareers: Set<String>
    var relevantFields: Set<String>
    var sourceRoadmapID: String?
    /// Source catalog project ID when this custom project was started from an idea (Phase 9.7)
    var sourceProjectID: String?

    // MARK: Rich fields (Phase 9.3) — all optional for backward compatibility

    /// Project status (Planned / In Progress / Completed)
    var status: ProjectStatus
    /// Longer detailed background when useful (optional)
    var detailedDescription: String?
    /// Concise outcome/result (optional)
    var outcome: String?
    /// Optional longer impact description
    var outcomeDetails: String?
    /// Relevant external links (optional)
    var links: [ProjectLink]
    /// Local image identifiers/references (filenames) — not raw bytes
    var imageReferences: [String]
    /// Optional start date
    var startDate: Date?
    /// Optional completion date
    var completionDate: Date?
    /// Optional related achievement
    var achievementID: String?

    // MARK: - Project Type helpers

    static let typeOptions: [String] = [
        "Personal Project",
        "School Project",
        "Science Fair",
        "Research Project",
        "Coding Project",
        "Competition Project",
        "Community Project",
        "Other"
    ]

    /// Convenience: category as type alias
    var type: String { category }

    /// Effective status — always returns a value even if stored status was legacy nil (handled via decoder default)
    var effectiveStatus: ProjectStatus { status }

    // MARK: - Coding

    enum CodingKeys: String, CodingKey {
        case id, title, category, type, goal, description, skills, milestones, resources, estimatedCompletion
        case relevantInterests, relevantSkills, relevantCareers, relevantFields, sourceRoadmapID, sourceProjectID
        case status, detailedDescription, outcome, outcomeDetails, links, imageReferences, startDate, completionDate, achievementID
        // Legacy image keys
        case imageRefs, photos
    }

    // MARK: - Initializers

    init(
        id: String,
        title: String,
        category: String,
        goal: String,
        description: String,
        skills: [String],
        milestones: [ProjectMilestone],
        resources: [String],
        estimatedCompletion: String,
        relevantInterests: Set<String>,
        relevantSkills: Set<String>,
        relevantCareers: Set<String>,
        relevantFields: Set<String>,
        sourceRoadmapID: String? = nil,
        sourceProjectID: String? = nil,
        status: ProjectStatus = .inProgress,
        detailedDescription: String? = nil,
        outcome: String? = nil,
        outcomeDetails: String? = nil,
        links: [ProjectLink] = [],
        imageReferences: [String] = [],
        startDate: Date? = nil,
        completionDate: Date? = nil,
        achievementID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.goal = goal
        self.description = description
        self.skills = skills
        self.milestones = milestones
        self.resources = resources
        self.estimatedCompletion = estimatedCompletion
        self.relevantInterests = relevantInterests
        self.relevantSkills = relevantSkills
        self.relevantCareers = relevantCareers
        self.relevantFields = relevantFields
        self.sourceRoadmapID = sourceRoadmapID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : sourceRoadmapID
        let srcProj = sourceProjectID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceProjectID = srcProj?.isEmpty == true ? nil : srcProj
        self.status = status
        let dd = detailedDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.detailedDescription = dd?.isEmpty == true ? nil : dd
        let oc = outcome?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.outcome = oc?.isEmpty == true ? nil : oc
        let od = outcomeDetails?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.outcomeDetails = od?.isEmpty == true ? nil : od
        self.links = links.filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.imageReferences = imageReferences.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.startDate = startDate
        self.completionDate = completionDate
        let ach = achievementID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.achievementID = ach?.isEmpty == true ? nil : ach
    }

    // Convenience for minimal test creation
    init(id: String, title: String) {
        self.init(
            id: id, title: title, category: "Personal Project", goal: "Complete this project",
            description: "A project created by you.",
            skills: [], milestones: [], resources: [], estimatedCompletion: "Your timeline",
            relevantInterests: [], relevantSkills: [], relevantCareers: [], relevantFields: [], sourceRoadmapID: nil
        )
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id may be UUID or String
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let u = try? c.decode(UUID.self, forKey: .id) {
            id = u.uuidString
        } else {
            id = UUID().uuidString
        }
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        // category may be "category" or legacy "type"
        if let cat = try? c.decode(String.self, forKey: .category) {
            category = cat
        } else if let t = try? c.decode(String.self, forKey: .type) {
            category = t
        } else {
            category = "Personal Project"
        }
        goal = (try? c.decode(String.self, forKey: .goal)) ?? "Complete this project"
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        skills = (try? c.decode([String].self, forKey: .skills)) ?? []
        milestones = (try? c.decode([ProjectMilestone].self, forKey: .milestones)) ?? []
        resources = (try? c.decode([String].self, forKey: .resources)) ?? []
        estimatedCompletion = (try? c.decode(String.self, forKey: .estimatedCompletion)) ?? "Your timeline"
        relevantInterests = (try? c.decode(Set<String>.self, forKey: .relevantInterests)) ?? []
        relevantSkills = (try? c.decode(Set<String>.self, forKey: .relevantSkills)) ?? []
        relevantCareers = (try? c.decode(Set<String>.self, forKey: .relevantCareers)) ?? []
        relevantFields = (try? c.decode(Set<String>.self, forKey: .relevantFields)) ?? []
        sourceRoadmapID = try? c.decode(String.self, forKey: .sourceRoadmapID)
        sourceProjectID = try? c.decode(String.self, forKey: .sourceProjectID)
        if sourceProjectID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { sourceProjectID = nil }
        // Rich fields — all optional with defaults
        status = (try? c.decode(ProjectStatus.self, forKey: .status)) ?? .inProgress
        detailedDescription = try? c.decode(String.self, forKey: .detailedDescription)
        if detailedDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { detailedDescription = nil }
        outcome = try? c.decode(String.self, forKey: .outcome)
        if outcome?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { outcome = nil }
        outcomeDetails = try? c.decode(String.self, forKey: .outcomeDetails)
        if outcomeDetails?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { outcomeDetails = nil }
        links = (try? c.decode([ProjectLink].self, forKey: .links)) ?? []
        // imageReferences may be stored under different keys
        if let refs = try? c.decode([String].self, forKey: .imageReferences) {
            imageReferences = refs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else if let refs = try? c.decode([String].self, forKey: .imageRefs) {
            imageReferences = refs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else if let refs = try? c.decode([String].self, forKey: .photos) {
            imageReferences = refs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else {
            imageReferences = []
        }
        startDate = try? c.decode(Date.self, forKey: .startDate)
        completionDate = try? c.decode(Date.self, forKey: .completionDate)
        achievementID = try? c.decode(String.self, forKey: .achievementID)
        if achievementID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { achievementID = nil }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(category, forKey: .category)
        try c.encode(goal, forKey: .goal)
        try c.encode(description, forKey: .description)
        try c.encode(skills, forKey: .skills)
        try c.encode(milestones, forKey: .milestones)
        try c.encode(resources, forKey: .resources)
        try c.encode(estimatedCompletion, forKey: .estimatedCompletion)
        try c.encode(relevantInterests, forKey: .relevantInterests)
        try c.encode(relevantSkills, forKey: .relevantSkills)
        try c.encode(relevantCareers, forKey: .relevantCareers)
        try c.encode(relevantFields, forKey: .relevantFields)
        try c.encodeIfPresent(sourceRoadmapID, forKey: .sourceRoadmapID)
        try c.encodeIfPresent(sourceProjectID, forKey: .sourceProjectID)
        // Rich fields — only encode non-defaults compactly but include status always for clarity
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(detailedDescription, forKey: .detailedDescription)
        try c.encodeIfPresent(outcome, forKey: .outcome)
        try c.encodeIfPresent(outcomeDetails, forKey: .outcomeDetails)
        if !links.isEmpty { try c.encode(links, forKey: .links) }
        if !imageReferences.isEmpty { try c.encode(imageReferences, forKey: .imageReferences) }
        try c.encodeIfPresent(startDate, forKey: .startDate)
        try c.encodeIfPresent(completionDate, forKey: .completionDate)
        try c.encodeIfPresent(achievementID, forKey: .achievementID)
    }
}

struct ScoredProject: Identifiable, Hashable {
    let project: Project
    let matchScore: Int
    let completedMilestones: Int
    var id: String { project.id }
    var progress: Int { ProgressCalculator.percent(completed: completedMilestones, total: project.milestones.count) }
    var isCompleted: Bool { completedMilestones >= project.milestones.count }
    var currentMilestone: ProjectMilestone? { project.milestones.indices.contains(completedMilestones) ? project.milestones[completedMilestones] : nil }
}
