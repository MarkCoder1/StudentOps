import Foundation

// MARK: - Portfolio Section Type

enum PortfolioSectionType: String, Codable, Hashable, CaseIterable {
    case about = "about"
    case goals = "goals"
    case skills = "skills"
    case projects = "projects"
    case achievements = "achievements"
    case evidence = "evidence"
    case roadmaps = "roadmaps"

    var displayName: String {
        switch self {
        case .about: return "About"
        case .goals: return "Goals"
        case .skills: return "Skills"
        case .projects: return "Projects"
        case .achievements: return "Achievements"
        case .evidence: return "Evidence"
        case .roadmaps: return "Roadmaps"
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "other"
        self = PortfolioSectionType(rawValue: raw) ?? .about
    }
}

// MARK: - Portfolio Section

struct PortfolioSection: Identifiable, Hashable, Codable {
    let id: String
    var type: PortfolioSectionType
    var title: String
    var isEnabled: Bool

    init(id: String, type: PortfolioSectionType, title: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.type = type
        self.title = title ?? type.displayName
        self.isEnabled = isEnabled
    }

    init(type: PortfolioSectionType, isEnabled: Bool = true) {
        self.id = type.rawValue
        self.type = type
        self.title = type.displayName
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id, type, title, isEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id stable, fallback to type rawValue
        if let decodedID = try? c.decode(String.self, forKey: .id) {
            id = decodedID
        } else if let t = try? c.decode(PortfolioSectionType.self, forKey: .type) {
            id = t.rawValue
        } else {
            id = UUID().uuidString
        }
        type = (try? c.decode(PortfolioSectionType.self, forKey: .type)) ?? .about
        title = (try? c.decode(String.self, forKey: .title)) ?? type.displayName
        isEnabled = (try? c.decode(Bool.self, forKey: .isEnabled)) ?? true
    }
}

// MARK: - Student Portfolio

struct StudentPortfolio: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var headline: String?
    var about: String?
    var goals: [String]
    var selectedProjectIDs: [String]
    var selectedAchievementIDs: [String]
    var selectedEvidenceIDs: [String]
    var selectedSkillIDs: [String]
    var selectedRoadmapIDs: [String]
    var sections: [PortfolioSection]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, headline, about, goals, selectedProjectIDs, selectedAchievementIDs, selectedEvidenceIDs, selectedSkillIDs, selectedRoadmapIDs, sections, createdAt, updatedAt
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        headline: String? = nil,
        about: String? = nil,
        goals: [String] = [],
        selectedProjectIDs: [String] = [],
        selectedAchievementIDs: [String] = [],
        selectedEvidenceIDs: [String] = [],
        selectedSkillIDs: [String] = [],
        selectedRoadmapIDs: [String] = [],
        sections: [PortfolioSection]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Portfolio" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.headline = headline?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : headline?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.about = about?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : about?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.goals = goals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.selectedProjectIDs = StudentPortfolio.dedupOrdered(selectedProjectIDs)
        self.selectedAchievementIDs = StudentPortfolio.dedupOrdered(selectedAchievementIDs)
        self.selectedEvidenceIDs = StudentPortfolio.dedupOrdered(selectedEvidenceIDs)
        self.selectedSkillIDs = StudentPortfolio.dedupOrderedSkillIDs(selectedSkillIDs)
        self.selectedRoadmapIDs = StudentPortfolio.dedupOrdered(selectedRoadmapIDs)
        self.sections = sections ?? StudentPortfolio.defaultSections
        // Ensure section IDs stable and deduped
        self.sections = StudentPortfolio.dedupSections(self.sections)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        let rawTitle = (try? c.decode(String.self, forKey: .title)) ?? "My Portfolio"
        title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Portfolio" : rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        headline = try? c.decode(String.self, forKey: .headline)
        if headline?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { headline = nil }
        about = try? c.decode(String.self, forKey: .about)
        if about?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { about = nil }
        goals = (try? c.decode([String].self, forKey: .goals))?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        selectedProjectIDs = StudentPortfolio.dedupOrdered((try? c.decode([String].self, forKey: .selectedProjectIDs)) ?? [])
        selectedAchievementIDs = StudentPortfolio.dedupOrdered((try? c.decode([String].self, forKey: .selectedAchievementIDs)) ?? [])
        selectedEvidenceIDs = StudentPortfolio.dedupOrdered((try? c.decode([String].self, forKey: .selectedEvidenceIDs)) ?? [])
        selectedSkillIDs = StudentPortfolio.dedupOrderedSkillIDs((try? c.decode([String].self, forKey: .selectedSkillIDs)) ?? [])
        selectedRoadmapIDs = StudentPortfolio.dedupOrdered((try? c.decode([String].self, forKey: .selectedRoadmapIDs)) ?? [])
        if let decodedSections = try? c.decode([PortfolioSection].self, forKey: .sections) {
            sections = StudentPortfolio.dedupSections(decodedSections)
        } else {
            sections = StudentPortfolio.defaultSections
        }
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(headline, forKey: .headline)
        try c.encodeIfPresent(about, forKey: .about)
        try c.encode(goals, forKey: .goals)
        try c.encode(selectedProjectIDs, forKey: .selectedProjectIDs)
        try c.encode(selectedAchievementIDs, forKey: .selectedAchievementIDs)
        try c.encode(selectedEvidenceIDs, forKey: .selectedEvidenceIDs)
        try c.encode(selectedSkillIDs, forKey: .selectedSkillIDs)
        try c.encode(selectedRoadmapIDs, forKey: .selectedRoadmapIDs)
        try c.encode(sections, forKey: .sections)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    // MARK: - Helpers

    static var defaultSections: [PortfolioSection] {
        [
            PortfolioSection(type: .about),
            PortfolioSection(type: .goals),
            PortfolioSection(type: .skills),
            PortfolioSection(type: .projects),
            PortfolioSection(type: .achievements),
            PortfolioSection(type: .evidence),
            PortfolioSection(type: .roadmaps),
        ]
    }

    static func dedupOrdered(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in ids {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !seen.contains(t) else { continue }
            seen.insert(t); out.append(t)
        }
        return out
    }

    static func dedupOrderedSkillIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in ids {
            let norm = Skill.normalizeID(raw)
            guard !norm.isEmpty, !seen.contains(norm) else { continue }
            seen.insert(norm); out.append(norm)
        }
        return out
    }

    static func dedupSections(_ sections: [PortfolioSection]) -> [PortfolioSection] {
        var seen = Set<String>()
        var out: [PortfolioSection] = []
        for sec in sections {
            guard !seen.contains(sec.id) else { continue }
            seen.insert(sec.id); out.append(sec)
        }
        return out.isEmpty ? defaultSections : out
    }
}
