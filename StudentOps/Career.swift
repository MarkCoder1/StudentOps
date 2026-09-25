import Foundation

// MARK: - Canonical Career Model (Phase 11A)
// Single source of truth for career intelligence. Deterministic, Codable, strongly-typed.
// DEMO/CATALOG DATA is clearly marked as such — not live labor-market data.

struct Career: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let normalizedID: String
    let description: String
    let fields: [String]
    let industries: [String]
    let skills: [String] // canonical Skill IDs via Skill.normalizeID
    let relatedSkills: [String]
    let interests: [String]
    let educationRequirements: [String]?
    let commonActivities: [String]
    let source: CareerSourceMetadata?
    let sourceURL: String?
    let lastVerified: Date?
    let status: CareerStatus

    // Derived aliases for compatibility
    var displayTitle: String { title }

    init(
        id: String,
        title: String,
        description: String,
        fields: [String] = [],
        industries: [String] = [],
        skills: [String] = [],
        relatedSkills: [String] = [],
        interests: [String] = [],
        educationRequirements: [String]? = nil,
        commonActivities: [String] = [],
        source: CareerSourceMetadata? = nil,
        sourceURL: String? = nil,
        lastVerified: Date? = nil,
        status: CareerStatus = .catalog
    ) {
        self.id = Career.normalizeID(title: id) // id is already normalized form, but ensure deterministic
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedID = Career.normalizeID(title: title)
        self.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fields = Career.normalizeStringArray(fields)
        self.industries = Career.normalizeStringArray(industries)
        self.skills = Career.normalizeSkillArray(skills)
        self.relatedSkills = Career.normalizeSkillArray(relatedSkills)
        self.interests = Career.normalizeStringArray(interests)
        if let edu = educationRequirements {
            let trimmed = edu.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            self.educationRequirements = trimmed.isEmpty ? nil : trimmed
        } else {
            self.educationRequirements = nil
        }
        self.commonActivities = Career.normalizeStringArray(commonActivities)
        self.source = source
        let urlTrim = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceURL = (urlTrim?.isEmpty == true) ? nil : urlTrim.flatMap { Career.validateURL($0) ? $0 : nil }
        self.lastVerified = lastVerified
        self.status = status
    }

    // MARK: - Codable (backward compatible, tolerant)

    enum CodingKeys: String, CodingKey {
        case id, title, normalizedID, description, fields, industries, skills, relatedSkills, interests, educationRequirements, commonActivities, source, sourceURL, lastVerified, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawID = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        id = Career.normalizeID(title: rawID)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        normalizedID = (try? c.decode(String.self, forKey: .normalizedID)) ?? Career.normalizeID(title: title)
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        fields = (try? c.decode([String].self, forKey: .fields))?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        industries = (try? c.decode([String].self, forKey: .industries))?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        let rawSkills = (try? c.decode([String].self, forKey: .skills)) ?? []
        skills = Career.normalizeSkillArray(rawSkills)
        let rawRelated = (try? c.decode([String].self, forKey: .relatedSkills)) ?? []
        relatedSkills = Career.normalizeSkillArray(rawRelated)
        interests = (try? c.decode([String].self, forKey: .interests))?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        educationRequirements = try? c.decode([String].self, forKey: .educationRequirements)
        commonActivities = (try? c.decode([String].self, forKey: .commonActivities))?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        source = try? c.decode(CareerSourceMetadata.self, forKey: .source)
        sourceURL = try? c.decode(String.self, forKey: .sourceURL)
        if let d = try? c.decode(Date.self, forKey: .lastVerified) {
            lastVerified = d
        } else if let s = try? c.decode(String.self, forKey: .lastVerified), let d = ISO8601DateFormatter().date(from: s) {
            lastVerified = d
        } else {
            lastVerified = nil
        }
        status = (try? c.decode(CareerStatus.self, forKey: .status)) ?? .catalog
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(normalizedID, forKey: .normalizedID)
        try c.encode(description, forKey: .description)
        try c.encode(fields, forKey: .fields)
        try c.encode(industries, forKey: .industries)
        try c.encode(skills, forKey: .skills)
        try c.encode(relatedSkills, forKey: .relatedSkills)
        try c.encode(interests, forKey: .interests)
        try c.encodeIfPresent(educationRequirements, forKey: .educationRequirements)
        try c.encode(commonActivities, forKey: .commonActivities)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try c.encodeIfPresent(lastVerified, forKey: .lastVerified)
        try c.encode(status, forKey: .status)
    }

    // MARK: - Normalization

    /// Deterministic career ID normalization:
    /// - trims whitespace/newlines
    /// - lowercases
    /// - replaces punctuation (-, _, /) with spaces, collapses whitespace
    /// - maps explicit aliases (only if defined in `aliasMap`)
    static func normalizeID(title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return "" }
        // Replace punctuation with spaces
        var s = trimmed
        let punct = CharacterSet(charactersIn: "-_/\\")
        for c in ["-", "_", "/", "\\"] {
            s = s.replacingOccurrences(of: c, with: " ")
        }
        // Collapse whitespace
        let parts = s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let collapsed = parts.joined(separator: " ")
        // Explicit alias mapping — only if canonical
        if let alias = aliasMap[collapsed] {
            return alias
        }
        // Otherwise, hyphenate for ID
        return collapsed.replacingOccurrences(of: " ", with: "-")
    }

    /// Explicit alias map — only careers in this map are treated as same.
    /// Do NOT add fuzzy matches. Documented.
    private static let aliasMap: [String: String] = [
        "software engineering": "software-engineering",
        "software engineer": "software-engineering",
        "software-engineer": "software-engineering",
        "swe": "software-engineering",
        "data science": "data-science",
        "data scientist": "data-science",
        "ai ml": "ai-ml",
        "ai/ml": "ai-ml",
        "artificial intelligence": "ai-ml",
        "machine learning": "ai-ml",
        "cybersecurity": "cybersecurity",
        "cyber security": "cybersecurity",
        "mechanical engineering": "mechanical-engineering",
        "mechanical engineer": "mechanical-engineering",
        "electrical engineering": "electrical-engineering",
        "electrical engineer": "electrical-engineering",
        "biomedical engineering": "biomedical-engineering",
        "biomedical engineer": "biomedical-engineering",
        "product design": "product-design",
        "product designer": "product-design",
        "business": "business-entrepreneurship",
        "entrepreneurship": "business-entrepreneurship",
        "business entrepreneurship": "business-entrepreneurship",
    ]

    static func normalizeStringArray(_ arr: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in arr {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let collapsed = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
            let lower = collapsed.lowercased()
            if seen.contains(lower) { continue }
            seen.insert(lower)
            out.append(collapsed)
        }
        return out
    }

    static func normalizeSkillArray(_ arr: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in arr {
            let nid = Skill.normalizeID(raw)
            guard !nid.isEmpty, !seen.contains(nid) else { continue }
            seen.insert(nid)
            // Preserve display but normalize ID for dedup
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { out.append(trimmed) }
        }
        return out
    }

    static func validateURL(_ s: String) -> Bool {
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme), url.host != nil else { return false }
        return true
    }
}

// MARK: - Supporting Types

struct CareerSourceMetadata: Hashable, Codable {
    let sourceID: String
    let sourceName: String
    let sourceType: String // e.g., "catalog", "verified"
    let retrievedAt: Date?
    let publisher: String?

    init(sourceID: String, sourceName: String, sourceType: String = "catalog", retrievedAt: Date? = nil, publisher: String? = nil) {
        self.sourceID = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceType = sourceType
        self.retrievedAt = retrievedAt
        self.publisher = publisher?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CareerStatus: String, Codable, Hashable {
    case catalog = "catalog" // DEMO/CATALOG DATA
    case verified = "verified" // LIVE/VERIFIED DATA (when source is verified)
    case archived = "archived"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "catalog"
        self = CareerStatus(rawValue: raw) ?? .catalog
    }
}

enum CareerSkillRelationshipType: String, Codable, Hashable, CaseIterable {
    case foundational = "foundational"
    case core = "core"
    case supporting = "supporting"
    case advanced = "advanced"

    var importance: Int {
        switch self {
        case .foundational: return 4
        case .core: return 3
        case .supporting: return 2
        case .advanced: return 1
        }
    }

    var displayName: String {
        switch self {
        case .foundational: return "Foundational"
        case .core: return "Core"
        case .supporting: return "Supporting"
        case .advanced: return "Advanced"
        }
    }
}

struct CareerSkillRelationship: Hashable, Codable {
    let careerID: String
    let skillID: String // canonical Skill ID
    let relationshipType: CareerSkillRelationshipType
    let importance: Int // derived from type, but explicit for sorting

    init(careerID: String, skillID: String, relationshipType: CareerSkillRelationshipType) {
        self.careerID = Career.normalizeID(title: careerID)
        self.skillID = Skill.normalizeID(skillID)
        self.relationshipType = relationshipType
        self.importance = relationshipType.importance
    }
}

// MARK: - Skill Prerequisite (deterministic, only where explicitly defined)

struct SkillPrerequisite: Hashable, Codable {
    let skillID: String
    let prerequisiteSkillID: String

    init(skillID: String, prerequisiteSkillID: String) {
        self.skillID = Skill.normalizeID(skillID)
        self.prerequisiteSkillID = Skill.normalizeID(prerequisiteSkillID)
    }
}
