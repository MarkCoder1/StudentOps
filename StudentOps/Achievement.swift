import Foundation

// MARK: - Achievement Types

enum AchievementType: String, Codable, Hashable, CaseIterable {
    case project = "project"
    case learning = "learning"
    case competition = "competition"
    case research = "research"
    case leadership = "leadership"
    case communityImpact = "communityImpact"
    case technical = "technical"
    case academic = "academic"
    case milestone = "milestone"
    case other = "other"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "other"
        self = AchievementType(rawValue: raw) ?? .other
    }

    var displayName: String {
        switch self {
        case .project: return "Project"
        case .learning: return "Learning"
        case .competition: return "Competition"
        case .research: return "Research"
        case .leadership: return "Leadership"
        case .communityImpact: return "Community Impact"
        case .technical: return "Technical"
        case .academic: return "Academic"
        case .milestone: return "Milestone"
        case .other: return "Other"
        }
    }
}

enum AchievementStatus: String, Codable, Hashable, CaseIterable {
    case recorded = "recorded"
    case verified = "verified"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "recorded"
        self = AchievementStatus(rawValue: raw) ?? .recorded
    }
}

enum AchievementSource: String, Codable, Hashable, CaseIterable {
    case studentEntered = "studentEntered"
    case evidenceDerived = "evidenceDerived"
    case roadmapMilestone = "roadmapMilestone"
    case project = "project"
    case opportunity = "opportunity"
    case system = "system"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "unknown"
        self = AchievementSource(rawValue: raw) ?? .unknown
    }
}

// MARK: - Canonical Achievement

/// Career-agnostic meaningful accomplishment supported by evidence.
struct Achievement: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var description: String?
    var type: AchievementType
    var status: AchievementStatus
    var createdAt: Date
    var occurredAt: Date?
    var evidenceIDs: [String]
    var skillIDs: [String]?
    var roadmapID: String?
    var milestoneID: String?
    var projectID: String?
    var opportunityID: String?
    var source: AchievementSource

    // Legacy compatibility — kept for existing UI (AchievementRow, RoadmapAchievementContext)
    var category: String { type.displayName }
    var dateLabel: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: occurredAt ?? createdAt)
    }
    var evidenceURL: URL? { nil }

    enum CodingKeys: String, CodingKey {
        case id, title, description, type, status, createdAt, occurredAt, evidenceIDs, skillIDs, roadmapID, milestoneID, projectID, opportunityID, source
        // Legacy keys for backward decoding
        case category, dateLabel, evidenceURL
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        type: AchievementType = .other,
        status: AchievementStatus = .recorded,
        createdAt: Date = Date(),
        occurredAt: Date? = nil,
        evidenceIDs: [String] = [],
        skillIDs: [String]? = nil,
        roadmapID: String? = nil,
        milestoneID: String? = nil,
        projectID: String? = nil,
        opportunityID: String? = nil,
        source: AchievementSource = .studentEntered
    ) {
        self.id = id
        self.title = title
        self.description = description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
        self.status = status
        self.createdAt = createdAt
        self.occurredAt = occurredAt
        // Deduplicate evidenceIDs, preserve order
        var seen = Set<String>()
        var deduped: [String] = []
        for eid in evidenceIDs where !eid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let t = eid.trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.insert(t).inserted { deduped.append(t) }
        }
        self.evidenceIDs = deduped
        if let skills = skillIDs {
            let norm = skills.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }
            self.skillIDs = norm.isEmpty ? nil : Array(Set(norm)).sorted()
        } else {
            self.skillIDs = nil
        }
        self.roadmapID = roadmapID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : roadmapID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.milestoneID = milestoneID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : milestoneID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.projectID = projectID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : projectID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.opportunityID = opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.source = source
    }

    /// Legacy init from onboarding AccomplishmentEntry
    init(entry: AccomplishmentEntry) {
        self.id = entry.id.uuidString
        self.title = entry.title
        self.description = "Student-provided experience recorded in the Student OPS profile."
        // Map legacy category to type
        let cat = entry.category.lowercased()
        if cat.contains("project") { self.type = .project }
        else if cat.contains("competition") { self.type = .competition }
        else if cat.contains("research") { self.type = .research }
        else if cat.contains("leadership") { self.type = .leadership }
        else if cat.contains("volunteer") || cat.contains("community") { self.type = .communityImpact }
        else { self.type = .other }
        self.status = .recorded
        self.createdAt = Date()
        self.occurredAt = nil
        self.evidenceIDs = []
        self.skillIDs = nil
        self.roadmapID = nil
        self.milestoneID = nil
        self.projectID = nil
        self.opportunityID = nil
        self.source = .studentEntered
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id may be UUID or String
        if let str = try? c.decode(String.self, forKey: .id) {
            id = str
        } else if let uuid = try? c.decode(UUID.self, forKey: .id) {
            id = uuid.uuidString
        } else {
            id = UUID().uuidString
        }
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        // type may be missing (legacy)
        if let t = try? c.decode(AchievementType.self, forKey: .type) {
            type = t
        } else if let raw = try? c.decode(String.self, forKey: .type) {
            type = AchievementType(rawValue: raw) ?? .other
        } else if let cat = try? c.decode(String.self, forKey: .category) {
            // Legacy category fallback
            let lower = cat.lowercased()
            if lower.contains("project") { type = .project }
            else if lower.contains("competition") { type = .competition }
            else if lower.contains("research") { type = .research }
            else if lower.contains("leadership") { type = .leadership }
            else if lower.contains("volunteer") || lower.contains("community") { type = .communityImpact }
            else { type = .other }
        } else {
            type = .other
        }
        status = (try? c.decode(AchievementStatus.self, forKey: .status)) ?? .recorded
        // createdAt may be missing in legacy — fallback to dateLabel or now
        if let d = try? c.decode(Date.self, forKey: .createdAt) {
            createdAt = d
        } else if let legacyDateStr = try? c.decode(String.self, forKey: .dateLabel) {
            // Legacy dateLabel was "Recorded during onboarding" — ignore, use now
            _ = legacyDateStr
            createdAt = Date()
        } else {
            createdAt = Date()
        }
        occurredAt = try? c.decode(Date.self, forKey: .occurredAt)
        evidenceIDs = (try? c.decode([String].self, forKey: .evidenceIDs)) ?? []
        if let skills = try? c.decode([String].self, forKey: .skillIDs) {
            let norm = skills.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }
            skillIDs = norm.isEmpty ? nil : Array(Set(norm)).sorted()
        } else {
            skillIDs = nil
        }
        roadmapID = try? c.decode(String.self, forKey: .roadmapID)
        milestoneID = try? c.decode(String.self, forKey: .milestoneID)
        projectID = try? c.decode(String.self, forKey: .projectID)
        opportunityID = try? c.decode(String.self, forKey: .opportunityID)
        source = (try? c.decode(AchievementSource.self, forKey: .source)) ?? .unknown
        // Normalize empty strings to nil
        if roadmapID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { roadmapID = nil }
        if milestoneID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { milestoneID = nil }
        if projectID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { projectID = nil }
        if opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { opportunityID = nil }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(type, forKey: .type)
        try c.encode(status, forKey: .status)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(occurredAt, forKey: .occurredAt)
        try c.encode(evidenceIDs, forKey: .evidenceIDs)
        try c.encodeIfPresent(skillIDs, forKey: .skillIDs)
        try c.encodeIfPresent(roadmapID, forKey: .roadmapID)
        try c.encodeIfPresent(milestoneID, forKey: .milestoneID)
        try c.encodeIfPresent(projectID, forKey: .projectID)
        try c.encodeIfPresent(opportunityID, forKey: .opportunityID)
        try c.encode(source, forKey: .source)
    }
}
