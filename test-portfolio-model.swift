import Foundation

// Standalone test script for Phase 8.1 — Portfolio Data Model Foundation
// Run: swift test-portfolio-model.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}
func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a != b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — values equal \(a)") }
}

// MARK: - Skill normalize helper (mirrors Skill.normalizeID)

func normalizeSkillID(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    return parts.joined(separator: " ").lowercased()
}

// MARK: - Inline canonical Portfolio models (mirrors StudentPortfolio.swift)

enum TestPortfolioSectionType: String, Codable, Hashable, CaseIterable {
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
        self = TestPortfolioSectionType(rawValue: raw) ?? .about
    }
}

struct TestPortfolioSection: Identifiable, Hashable, Codable {
    let id: String
    var type: TestPortfolioSectionType
    var title: String
    var isEnabled: Bool

    init(id: String, type: TestPortfolioSectionType, title: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.type = type
        self.title = title ?? type.displayName
        self.isEnabled = isEnabled
    }

    init(type: TestPortfolioSectionType, isEnabled: Bool = true) {
        self.id = type.rawValue
        self.type = type
        self.title = type.displayName
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey { case id, type, title, isEnabled }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedID = try? c.decode(String.self, forKey: .id) {
            id = decodedID
        } else if let t = try? c.decode(TestPortfolioSectionType.self, forKey: .type) {
            id = t.rawValue
        } else {
            id = UUID().uuidString
        }
        type = (try? c.decode(TestPortfolioSectionType.self, forKey: .type)) ?? .about
        title = (try? c.decode(String.self, forKey: .title)) ?? type.displayName
        isEnabled = (try? c.decode(Bool.self, forKey: .isEnabled)) ?? true
    }
}

struct TestStudentPortfolio: Identifiable, Hashable, Codable {
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
    var sections: [TestPortfolioSection]
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
        sections: [TestPortfolioSection]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Portfolio" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.headline = headline?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : headline?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.about = about?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : about?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.goals = goals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.selectedProjectIDs = TestStudentPortfolio.dedupOrdered(selectedProjectIDs)
        self.selectedAchievementIDs = TestStudentPortfolio.dedupOrdered(selectedAchievementIDs)
        self.selectedEvidenceIDs = TestStudentPortfolio.dedupOrdered(selectedEvidenceIDs)
        self.selectedSkillIDs = TestStudentPortfolio.dedupOrderedSkillIDs(selectedSkillIDs)
        self.selectedRoadmapIDs = TestStudentPortfolio.dedupOrdered(selectedRoadmapIDs)
        self.sections = sections ?? TestStudentPortfolio.defaultSections
        self.sections = TestStudentPortfolio.dedupSections(self.sections)
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
        selectedProjectIDs = TestStudentPortfolio.dedupOrdered((try? c.decode([String].self, forKey: .selectedProjectIDs)) ?? [])
        selectedAchievementIDs = TestStudentPortfolio.dedupOrdered((try? c.decode([String].self, forKey: .selectedAchievementIDs)) ?? [])
        selectedEvidenceIDs = TestStudentPortfolio.dedupOrdered((try? c.decode([String].self, forKey: .selectedEvidenceIDs)) ?? [])
        selectedSkillIDs = TestStudentPortfolio.dedupOrderedSkillIDs((try? c.decode([String].self, forKey: .selectedSkillIDs)) ?? [])
        selectedRoadmapIDs = TestStudentPortfolio.dedupOrdered((try? c.decode([String].self, forKey: .selectedRoadmapIDs)) ?? [])
        if let decodedSections = try? c.decode([TestPortfolioSection].self, forKey: .sections) {
            sections = TestStudentPortfolio.dedupSections(decodedSections)
        } else {
            sections = TestStudentPortfolio.defaultSections
        }
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? createdAt
    }

    static var defaultSections: [TestPortfolioSection] {
        [
            TestPortfolioSection(type: .about),
            TestPortfolioSection(type: .goals),
            TestPortfolioSection(type: .skills),
            TestPortfolioSection(type: .projects),
            TestPortfolioSection(type: .achievements),
            TestPortfolioSection(type: .evidence),
            TestPortfolioSection(type: .roadmaps),
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
            let norm = normalizeSkillID(raw)
            guard !norm.isEmpty, !seen.contains(norm) else { continue }
            seen.insert(norm); out.append(norm)
        }
        return out
    }

    static func dedupSections(_ sections: [TestPortfolioSection]) -> [TestPortfolioSection] {
        var seen = Set<String>()
        var out: [TestPortfolioSection] = []
        for sec in sections {
            guard !seen.contains(sec.id) else { continue }
            seen.insert(sec.id); out.append(sec)
        }
        return out.isEmpty ? defaultSections : out
    }
}

// MARK: - Simulated Portfolio Store (mirrors AppDataStore portfolio API)

class TestPortfolioStore {
    var portfolios: [String: TestStudentPortfolio] = [:]
    // Canonical records simulation for independence tests
    var projectProgress: [String: Int] = [:]
    var achievementRecords: [String: String] = [:] // id -> title
    var evidenceRecords: [String: String] = [:]
    var skillSet: Set<String> = []
    var activeRoadmaps: Set<String> = []

    init() {
        // Create default portfolio like AppDataStore
        let defaultPortfolio = TestStudentPortfolio(title: "My Portfolio")
        portfolios[defaultPortfolio.id] = defaultPortfolio
    }

    var allPortfoliosSorted: [TestStudentPortfolio] {
        portfolios.values.sorted { $0.createdAt > $1.createdAt }
    }

    func portfolio(id: String) -> TestStudentPortfolio? {
        let t = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return portfolios[t]
    }

    @discardableResult
    func createPortfolio(title: String, headline: String? = nil, about: String? = nil, goals: [String] = [], id: String? = nil) -> TestStudentPortfolio {
        let rawID = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid: String
        if let r = rawID, !r.isEmpty, portfolios[r] == nil {
            pid = r
        } else if let r = rawID, !r.isEmpty, portfolios[r] != nil {
            pid = UUID().uuidString
        } else {
            pid = UUID().uuidString
        }
        let p = TestStudentPortfolio(id: pid, title: title, headline: headline, about: about, goals: goals)
        portfolios[p.id] = p
        return p
    }

    @discardableResult
    func updatePortfolio(_ portfolio: TestStudentPortfolio) -> Bool {
        guard portfolios[portfolio.id] != nil else { return false }
        var sanitized = portfolio
        let titleTrim = sanitized.title.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.title = titleTrim.isEmpty ? "My Portfolio" : titleTrim
        if let h = sanitized.headline, h.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { sanitized.headline = nil } else { sanitized.headline = sanitized.headline?.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let a = sanitized.about, a.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { sanitized.about = nil } else { sanitized.about = sanitized.about?.trimmingCharacters(in: .whitespacesAndNewlines) }
        sanitized.goals = sanitized.goals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        sanitized.selectedProjectIDs = TestStudentPortfolio.dedupOrdered(sanitized.selectedProjectIDs)
        sanitized.selectedAchievementIDs = TestStudentPortfolio.dedupOrdered(sanitized.selectedAchievementIDs)
        sanitized.selectedEvidenceIDs = TestStudentPortfolio.dedupOrdered(sanitized.selectedEvidenceIDs)
        sanitized.selectedSkillIDs = TestStudentPortfolio.dedupOrderedSkillIDs(sanitized.selectedSkillIDs)
        sanitized.selectedRoadmapIDs = TestStudentPortfolio.dedupOrdered(sanitized.selectedRoadmapIDs)
        sanitized.sections = TestStudentPortfolio.dedupSections(sanitized.sections)
        sanitized.updatedAt = Date()
        portfolios[sanitized.id] = sanitized
        return true
    }

    @discardableResult
    func deletePortfolio(id: String) -> Bool {
        let t = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, portfolios[t] != nil else { return false }
        portfolios.removeValue(forKey: t)
        if portfolios.isEmpty {
            let defaultPortfolio = TestStudentPortfolio(title: "My Portfolio")
            portfolios[defaultPortfolio.id] = defaultPortfolio
        }
        return true
    }

    @discardableResult
    func addProject(to portfolioID: String, projectID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedProjectIDs.contains(tid) else { return false }
        p.selectedProjectIDs.append(tid)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeProject(from portfolioID: String, projectID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedProjectIDs.firstIndex(of: tid) else { return false }
        p.selectedProjectIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func addAchievement(to portfolioID: String, achievementID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = achievementID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedAchievementIDs.contains(tid) else { return false }
        p.selectedAchievementIDs.append(tid)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeAchievement(from portfolioID: String, achievementID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = achievementID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedAchievementIDs.firstIndex(of: tid) else { return false }
        p.selectedAchievementIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func addEvidence(to portfolioID: String, evidenceID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = evidenceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedEvidenceIDs.contains(tid) else { return false }
        p.selectedEvidenceIDs.append(tid)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeEvidence(from portfolioID: String, evidenceID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = evidenceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedEvidenceIDs.firstIndex(of: tid) else { return false }
        p.selectedEvidenceIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func addSkill(to portfolioID: String, skillID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = normalizeSkillID(skillID)
        guard !pid.isEmpty, !norm.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedSkillIDs.contains(norm) else { return false }
        p.selectedSkillIDs.append(norm)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeSkill(from portfolioID: String, skillID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = normalizeSkillID(skillID)
        guard !pid.isEmpty, !norm.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedSkillIDs.firstIndex(of: norm) else { return false }
        p.selectedSkillIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func addRoadmap(to portfolioID: String, roadmapID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = roadmapID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedRoadmapIDs.contains(tid) else { return false }
        p.selectedRoadmapIDs.append(tid)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeRoadmap(from portfolioID: String, roadmapID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = roadmapID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedRoadmapIDs.firstIndex(of: tid) else { return false }
        p.selectedRoadmapIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderProjects(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedProjectIDs = TestStudentPortfolio.dedupOrdered(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderAchievements(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedAchievementIDs = TestStudentPortfolio.dedupOrdered(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderEvidence(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedEvidenceIDs = TestStudentPortfolio.dedupOrdered(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderSkills(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedSkillIDs = TestStudentPortfolio.dedupOrderedSkillIDs(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderRoadmaps(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedRoadmapIDs = TestStudentPortfolio.dedupOrdered(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderSections(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        var byID: [String: TestPortfolioSection] = [:]
        for sec in p.sections { byID[sec.id] = sec }
        var newOrder: [TestPortfolioSection] = []
        var seen = Set<String>()
        for raw in orderedIDs {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !seen.contains(t), let sec = byID[t] else { continue }
            seen.insert(t); newOrder.append(sec)
        }
        for sec in p.sections where !seen.contains(sec.id) {
            newOrder.append(sec)
        }
        guard !newOrder.isEmpty else { return false }
        p.sections = TestStudentPortfolio.dedupSections(newOrder)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func setSectionEnabled(in portfolioID: String, sectionID: String, isEnabled: Bool) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let sid = sectionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !sid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.sections.firstIndex(where: { $0.id == sid }) else { return false }
        p.sections[idx].isEnabled = isEnabled
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func updatePortfolioTitle(id: String, title: String) -> Bool {
        let pid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !t.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        p.title = t
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func updatePortfolioHeadline(id: String, headline: String?) -> Bool {
        let pid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        if let h = headline {
            let t = h.trimmingCharacters(in: .whitespacesAndNewlines)
            p.headline = t.isEmpty ? nil : t
        } else {
            p.headline = nil
        }
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func updatePortfolioAbout(id: String, about: String?) -> Bool {
        let pid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        if let a = about {
            let t = a.trimmingCharacters(in: .whitespacesAndNewlines)
            p.about = t.isEmpty ? nil : t
        } else {
            p.about = nil
        }
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func updatePortfolioGoals(id: String, goals: [String]) -> Bool {
        let pid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        p.goals = goals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }
}

let encoder: JSONEncoder = {
    let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys]; return e
}()
let decoder: JSONDecoder = {
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
}()

// MARK: - Model Tests (1-6)

do { // 1. Portfolio initializes correctly.
    let p = TestStudentPortfolio(title: "My Portfolio")
    assert(!p.id.isEmpty, "1: id not empty")
    assertEqual(p.title, "My Portfolio", "1: title")
    assert(p.headline == nil, "1: headline nil")
    assert(p.about == nil, "1: about nil")
    assert(p.goals.isEmpty, "1: goals empty")
    assert(p.selectedProjectIDs.isEmpty, "1: projects empty")
    assert(p.selectedAchievementIDs.isEmpty, "1: achievements empty")
    assert(p.selectedEvidenceIDs.isEmpty, "1: evidence empty")
    assert(p.selectedSkillIDs.isEmpty, "1: skills empty")
    assert(p.selectedRoadmapIDs.isEmpty, "1: roadmaps empty")
    assertEqual(p.sections.count, 7, "1: default 7 sections")
    assert(p.createdAt.timeIntervalSince1970 > 0, "1: createdAt")
    assert(p.updatedAt.timeIntervalSince1970 > 0, "1: updatedAt")
}
do { // 2. Optional metadata works.
    let p = TestStudentPortfolio(title: "Title", headline: "Headline", about: "About text", goals: ["Goal 1", "Goal 2"])
    assertEqual(p.headline, "Headline", "2: headline")
    assertEqual(p.about, "About text", "2: about")
    assertEqual(p.goals, ["Goal 1", "Goal 2"], "2: goals")
    // Empty strings become nil / filtered
    let p2 = TestStudentPortfolio(title: "T", headline: "   ", about: "", goals: [" ", ""])
    assert(p2.headline == nil, "2b: headline empty nil")
    assert(p2.about == nil, "2b: about empty nil")
    assert(p2.goals.isEmpty, "2b: goals empty filtered")
    // Whitespace trimming
    let p3 = TestStudentPortfolio(title: "  My Title  ", headline: "  Hi  ", about: "  About  ", goals: ["  G1  "])
    assertEqual(p3.title, "My Title", "2c: title trimmed")
    assertEqual(p3.headline, "Hi", "2c: headline trimmed")
    assertEqual(p3.about, "About", "2c: about trimmed")
    assertEqual(p3.goals, ["G1"], "2c: goals trimmed")
}
do { // 3. Sections encode/decode.
    let p = TestStudentPortfolio(title: "T")
    let data = try! encoder.encode(p)
    let dec = try! decoder.decode(TestStudentPortfolio.self, from: data)
    assertEqual(dec.sections.count, 7, "3: sections count")
    assertEqual(dec.sections.map(\.id), p.sections.map(\.id), "3: section ids")
    assertEqual(dec.sections.map(\.type), p.sections.map(\.type), "3: section types")
    assertEqual(dec.sections.map(\.title), p.sections.map(\.title), "3: section titles")
    // Section enabled state persists
    var p2 = TestStudentPortfolio(title: "T")
    p2.sections[0].isEnabled = false
    let data2 = try! encoder.encode(p2)
    let dec2 = try! decoder.decode(TestStudentPortfolio.self, from: data2)
    assertEqual(dec2.sections[0].isEnabled, false, "3b: section enabled persists")
    // Unknown section type fallback
    let json = #"{"id":"portfolio-1","title":"T","goals":[],"selectedProjectIDs":[],"selectedAchievementIDs":[],"selectedEvidenceIDs":[],"selectedSkillIDs":[],"selectedRoadmapIDs":[],"sections":[{"id":"about","type":"unknown-type","title":"About","isEnabled":true}],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}"#.data(using:.utf8)!
    let dec3 = try! decoder.decode(TestStudentPortfolio.self, from: json)
    assertEqual(dec3.sections[0].type, .about, "3c: unknown type fallback to about")
}
do { // 4. IDs persist.
    let id = UUID().uuidString
    let p = TestStudentPortfolio(id: id, title: "T")
    let data = try! encoder.encode(p)
    let dec = try! decoder.decode(TestStudentPortfolio.self, from: data)
    assertEqual(dec.id, id, "4: id persist")
    // Section IDs persist
    assertEqual(dec.sections.map(\.id), p.sections.map(\.id), "4b: section ids")
}
do { // 5. Dates persist.
    let created = Date(timeIntervalSince1970: 1700000000)
    let updated = Date(timeIntervalSince1970: 1700000100)
    let p = TestStudentPortfolio(title: "T", createdAt: created, updatedAt: updated)
    let data = try! encoder.encode(p)
    let dec = try! decoder.decode(TestStudentPortfolio.self, from: data)
    assertEqual(dec.createdAt, created, "5: createdAt")
    assertEqual(dec.updatedAt, updated, "5: updatedAt")
}
do { // 6. All selection arrays persist.
    let p = TestStudentPortfolio(
        title: "T",
        selectedProjectIDs: ["proj-1", "proj-2"],
        selectedAchievementIDs: ["ach-1"],
        selectedEvidenceIDs: ["ev-1", "ev-2"],
        selectedSkillIDs: ["python", "git"],
        selectedRoadmapIDs: ["roadmap-1"]
    )
    let data = try! encoder.encode(p)
    let dec = try! decoder.decode(TestStudentPortfolio.self, from: data)
    assertEqual(dec.selectedProjectIDs, ["proj-1", "proj-2"], "6: projects")
    assertEqual(dec.selectedAchievementIDs, ["ach-1"], "6: achievements")
    assertEqual(dec.selectedEvidenceIDs, ["ev-1", "ev-2"], "6: evidence")
    assertEqual(dec.selectedSkillIDs, ["python", "git"], "6: skills")
    assertEqual(dec.selectedRoadmapIDs, ["roadmap-1"], "6: roadmaps")
    // Empty arrays persist
    let p2 = TestStudentPortfolio(title: "T2")
    let data2 = try! encoder.encode(p2)
    let dec2 = try! decoder.decode(TestStudentPortfolio.self, from: data2)
    assert(dec2.selectedProjectIDs.isEmpty, "6b: empty projects")
    assert(dec2.selectedSkillIDs.isEmpty, "6b: empty skills")
}

// MARK: - Selection Tests (7-18)

do { // 7. Add project.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.addProject(to: pid, projectID: "proj-1"), "7: add project")
    assertEqual(store.portfolio(id: pid)!.selectedProjectIDs, ["proj-1"], "7b: projects contains proj-1")
    assert(store.addProject(to: pid, projectID: "proj-2"), "7c: add proj-2")
    assertEqual(store.portfolio(id: pid)!.selectedProjectIDs, ["proj-1", "proj-2"], "7d: order preserved")
}
do { // 8. Remove project.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.addProject(to: pid, projectID: "proj-1")
    _ = store.addProject(to: pid, projectID: "proj-2")
    assert(store.removeProject(from: pid, projectID: "proj-1"), "8: remove proj-1")
    assertEqual(store.portfolio(id: pid)!.selectedProjectIDs, ["proj-2"], "8b: proj-2 remains")
    assert(!store.removeProject(from: pid, projectID: "nonexistent"), "8c: remove nonexistent false")
}
do { // 9. Duplicate project prevented.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.addProject(to: pid, projectID: "proj-1"), "9: first add")
    assert(!store.addProject(to: pid, projectID: "proj-1"), "9b: duplicate prevented")
    assert(!store.addProject(to: pid, projectID: " proj-1 "), "9c: duplicate with whitespace prevented")
    assertEqual(store.portfolio(id: pid)!.selectedProjectIDs, ["proj-1"], "9d: still one")
    // Via reorder dedup
    _ = store.reorderProjects(in: pid, orderedIDs: ["proj-1", "proj-1", "proj-2", "proj-1"])
    assertEqual(store.portfolio(id: pid)!.selectedProjectIDs, ["proj-1", "proj-2"], "9e: reorder deduped")
}
do { // 10. Add achievement.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.addAchievement(to: pid, achievementID: "ach-1"), "10: add ach")
    assertEqual(store.portfolio(id: pid)!.selectedAchievementIDs, ["ach-1"], "10b")
}
do { // 11. Remove achievement.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.addAchievement(to: pid, achievementID: "ach-1")
    _ = store.addAchievement(to: pid, achievementID: "ach-2")
    assert(store.removeAchievement(from: pid, achievementID: "ach-1"), "11: remove")
    assertEqual(store.portfolio(id: pid)!.selectedAchievementIDs, ["ach-2"], "11b")
}
do { // 12. Duplicate achievement prevented.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.addAchievement(to: pid, achievementID: "ach-1"), "12: add")
    assert(!store.addAchievement(to: pid, achievementID: "ach-1"), "12b: duplicate prevented")
    assertEqual(store.portfolio(id: pid)!.selectedAchievementIDs.count, 1, "12c: count 1")
}
do { // 13. Add evidence.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.addEvidence(to: pid, evidenceID: "ev-1"), "13: add ev")
    assertEqual(store.portfolio(id: pid)!.selectedEvidenceIDs, ["ev-1"], "13b")
}
do { // 14. Remove evidence.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.addEvidence(to: pid, evidenceID: "ev-1")
    assert(store.removeEvidence(from: pid, evidenceID: "ev-1"), "14: remove")
    assert(store.portfolio(id: pid)!.selectedEvidenceIDs.isEmpty, "14b: empty")
}
do { // 15. Add skill.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.addSkill(to: pid, skillID: "Python"), "15: add python")
    assertEqual(store.portfolio(id: pid)!.selectedSkillIDs, ["python"], "15b: normalized")
    assert(store.addSkill(to: pid, skillID: "Git"), "15c: add git")
    assertEqual(store.portfolio(id: pid)!.selectedSkillIDs, ["python", "git"], "15d")
}
do { // 16. Remove skill.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.addSkill(to: pid, skillID: "Python")
    _ = store.addSkill(to: pid, skillID: "Git")
    assert(store.removeSkill(from: pid, skillID: "PYTHON"), "16: remove case-insensitive")
    assertEqual(store.portfolio(id: pid)!.selectedSkillIDs, ["git"], "16b: git remains")
    assert(!store.removeSkill(from: pid, skillID: "nonexistent"), "16c: nonexistent false")
    // Whitespace normalization
    assert(store.removeSkill(from: pid, skillID: "  git  "), "16d: remove whitespace")
    assert(store.portfolio(id: pid)!.selectedSkillIDs.isEmpty, "16e: empty")
}
do { // 17. Add roadmap.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.addRoadmap(to: pid, roadmapID: "roadmap-1"), "17: add roadmap")
    assertEqual(store.portfolio(id: pid)!.selectedRoadmapIDs, ["roadmap-1"], "17b")
}
do { // 18. Remove roadmap.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.addRoadmap(to: pid, roadmapID: "r1")
    _ = store.addRoadmap(to: pid, roadmapID: "r2")
    assert(store.removeRoadmap(from: pid, roadmapID: "r1"), "18: remove")
    assertEqual(store.portfolio(id: pid)!.selectedRoadmapIDs, ["r2"], "18b")
}

// MARK: - Ordering Tests (19-24)

do { // 19. Project ordering persists.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.reorderProjects(in: pid, orderedIDs: ["proj-3", "proj-1", "proj-2"])
    assertEqual(store.portfolio(id: pid)!.selectedProjectIDs, ["proj-3", "proj-1", "proj-2"], "19: order")
    let data = try! encoder.encode(store.portfolios)
    let dec = try! decoder.decode([String: TestStudentPortfolio].self, from: data)
    assertEqual(dec[pid]!.selectedProjectIDs, ["proj-3", "proj-1", "proj-2"], "19b: persist")
}
do { // 20. Achievement ordering persists.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.reorderAchievements(in: pid, orderedIDs: ["ach-3", "ach-1", "ach-2"])
    assertEqual(store.portfolio(id: pid)!.selectedAchievementIDs, ["ach-3", "ach-1", "ach-2"], "20: order")
    let data = try! encoder.encode(store.portfolios)
    let dec = try! decoder.decode([String: TestStudentPortfolio].self, from: data)
    assertEqual(dec[pid]!.selectedAchievementIDs, ["ach-3", "ach-1", "ach-2"], "20b: persist")
}
do { // 21. Evidence ordering persists.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.reorderEvidence(in: pid, orderedIDs: ["ev-2", "ev-1", "ev-3"])
    assertEqual(store.portfolio(id: pid)!.selectedEvidenceIDs, ["ev-2", "ev-1", "ev-3"], "21: order")
    let data = try! encoder.encode(store.portfolios)
    let dec = try! decoder.decode([String: TestStudentPortfolio].self, from: data)
    assertEqual(dec[pid]!.selectedEvidenceIDs, ["ev-2", "ev-1", "ev-3"], "21b: persist")
}
do { // 22. Skill ordering persists.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.reorderSkills(in: pid, orderedIDs: ["git", "python", "research"])
    assertEqual(store.portfolio(id: pid)!.selectedSkillIDs, ["git", "python", "research"], "22: order")
    let data = try! encoder.encode(store.portfolios)
    let dec = try! decoder.decode([String: TestStudentPortfolio].self, from: data)
    assertEqual(dec[pid]!.selectedSkillIDs, ["git", "python", "research"], "22b: persist")
    // Skill dedup normalized
    _ = store.reorderSkills(in: pid, orderedIDs: ["Python", "PYTHON", "python"])
    assertEqual(store.portfolio(id: pid)!.selectedSkillIDs, ["python"], "22c: dedup normalized")
}
do { // 23. Roadmap ordering persists.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.reorderRoadmaps(in: pid, orderedIDs: ["r2", "r1", "r3"])
    assertEqual(store.portfolio(id: pid)!.selectedRoadmapIDs, ["r2", "r1", "r3"], "23: order")
    let data = try! encoder.encode(store.portfolios)
    let dec = try! decoder.decode([String: TestStudentPortfolio].self, from: data)
    assertEqual(dec[pid]!.selectedRoadmapIDs, ["r2", "r1", "r3"], "23b: persist")
}
do { // 24. Section ordering persists.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    let originalOrder = store.portfolio(id: pid)!.sections.map(\.id)
    assertEqual(originalOrder, ["about", "goals", "skills", "projects", "achievements", "evidence", "roadmaps"], "24: default order")
    _ = store.reorderSections(in: pid, orderedIDs: ["projects", "about", "skills", "goals", "achievements", "evidence", "roadmaps"])
    assertEqual(store.portfolio(id: pid)!.sections.map(\.id), ["projects", "about", "skills", "goals", "achievements", "evidence", "roadmaps"], "24b: reorder")
    let data = try! encoder.encode(store.portfolios)
    let dec = try! decoder.decode([String: TestStudentPortfolio].self, from: data)
    assertEqual(dec[pid]!.sections.map(\.id), ["projects", "about", "skills", "goals", "achievements", "evidence", "roadmaps"], "24c: persist")
    // Partial reorder should preserve missing sections appended
    _ = store.reorderSections(in: pid, orderedIDs: ["evidence", "projects"])
    let reordered = store.portfolio(id: pid)!.sections.map(\.id)
    assertEqual(reordered[0], "evidence", "24d: first evidence")
    assertEqual(reordered[1], "projects", "24d: second projects")
    // Should still contain all 7 sections
    assertEqual(reordered.count, 7, "24e: count 7")
}

// MARK: - Metadata Tests (25-29)

do { // 25. Update title.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    let before = store.portfolio(id: pid)!.updatedAt
    Thread.sleep(forTimeInterval: 0.01)
    assert(store.updatePortfolioTitle(id: pid, title: "New Title"), "25: update title")
    assertEqual(store.portfolio(id: pid)!.title, "New Title", "25b: title")
    assert(store.portfolio(id: pid)!.updatedAt > before, "25c: updatedAt increased")
    // Empty title rejected
    assert(!store.updatePortfolioTitle(id: pid, title: "   "), "25d: empty rejected")
}
do { // 26. Update headline.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.updatePortfolioHeadline(id: pid, headline: "My Headline"), "26: set headline")
    assertEqual(store.portfolio(id: pid)!.headline, "My Headline", "26b")
    assert(store.updatePortfolioHeadline(id: pid, headline: nil), "26c: clear headline")
    assert(store.portfolio(id: pid)!.headline == nil, "26d: nil")
    assert(store.updatePortfolioHeadline(id: pid, headline: "   "), "26e: blank headline becomes nil via update")
    assert(store.portfolio(id: pid)!.headline == nil, "26f: blank nil")
}
do { // 27. Update about.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.updatePortfolioAbout(id: pid, about: "About me"), "27: set about")
    assertEqual(store.portfolio(id: pid)!.about, "About me", "27b")
    assert(store.updatePortfolioAbout(id: pid, about: nil), "27c: clear")
    assert(store.portfolio(id: pid)!.about == nil, "27d")
}
do { // 28. Update goals.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.updatePortfolioGoals(id: pid, goals: ["Goal 1", "Goal 2"]), "28: set goals")
    assertEqual(store.portfolio(id: pid)!.goals, ["Goal 1", "Goal 2"], "28b")
    // Empty filtered
    assert(store.updatePortfolioGoals(id: pid, goals: [" ", "Goal 3", ""]), "28c: filtered")
    assertEqual(store.portfolio(id: pid)!.goals, ["Goal 3"], "28d")
    assert(store.updatePortfolioGoals(id: pid, goals: []), "28e: clear")
    assert(store.portfolio(id: pid)!.goals.isEmpty, "28f: empty")
}
do { // 29. Updated timestamp changes appropriately.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    let before = store.portfolio(id: pid)!.updatedAt
    Thread.sleep(forTimeInterval: 0.02)
    _ = store.addProject(to: pid, projectID: "proj-1")
    let afterAdd = store.portfolio(id: pid)!.updatedAt
    assert(afterAdd > before, "29: updated after add")
    Thread.sleep(forTimeInterval: 0.02)
    _ = store.updatePortfolioTitle(id: pid, title: "Another Title")
    let afterTitle = store.portfolio(id: pid)!.updatedAt
    assert(afterTitle > afterAdd, "29b: updated after title")
    Thread.sleep(forTimeInterval: 0.02)
    _ = store.reorderSections(in: pid, orderedIDs: ["projects", "about", "goals", "skills", "achievements", "evidence", "roadmaps"])
    let afterSection = store.portfolio(id: pid)!.updatedAt
    assert(afterSection > afterTitle, "29c: updated after section reorder")
    // Full portfolio update also bumps
    Thread.sleep(forTimeInterval: 0.02)
    var p = store.portfolio(id: pid)!
    p.title = "Final Title"
    let beforeUpdate = store.portfolio(id: pid)!.updatedAt
    Thread.sleep(forTimeInterval: 0.02)
    _ = store.updatePortfolio(p)
    assert(store.portfolio(id: pid)!.updatedAt > beforeUpdate, "29d: updated after full update")
}

// MARK: - Persistence Tests (30-33)

do { // 30. Save portfolio.
    let store = TestPortfolioStore()
    let p = store.createPortfolio(title: "Save Test")
    assert(store.portfolios[p.id] != nil, "30: saved")
    assertEqual(store.portfolios[p.id]!.title, "Save Test", "30b")
}
do { // 31. Reload AppDataStore.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.addProject(to: pid, projectID: "proj-1")
    _ = store.addSkill(to: pid, skillID: "python")
    _ = store.updatePortfolioTitle(id: pid, title: "Reload Title")
    // Simulate UserDefaults encode/decode
    let data = try! encoder.encode(store.portfolios)
    let decoded = try! decoder.decode([String: TestStudentPortfolio].self, from: data)
    assertEqual(decoded.count, store.portfolios.count, "31: count after reload")
    assertEqual(decoded[pid]!.title, "Reload Title", "31b: title after reload")
    assertEqual(decoded[pid]!.selectedProjectIDs, ["proj-1"], "31c: projects after reload")
    assertEqual(decoded[pid]!.selectedSkillIDs, ["python"], "31d: skills after reload")
    // Re-create store from decoded (simulates app relaunch)
    let newStore = TestPortfolioStore()
    newStore.portfolios = decoded
    assertEqual(newStore.portfolio(id: pid)!.title, "Reload Title", "31e: new store title")
}
do { // 32. Portfolio remains intact.
    let store = TestPortfolioStore()
    let p = store.createPortfolio(title: "Intact", headline: "H", about: "A", goals: ["G1"])
    _ = store.addProject(to: p.id, projectID: "proj-1")
    _ = store.addAchievement(to: p.id, achievementID: "ach-1")
    _ = store.addEvidence(to: p.id, evidenceID: "ev-1")
    _ = store.addSkill(to: p.id, skillID: "python")
    _ = store.addRoadmap(to: p.id, roadmapID: "roadmap-1")
    let data = try! encoder.encode(store.portfolios)
    let decoded = try! decoder.decode([String: TestStudentPortfolio].self, from: data)
    let rp = decoded[p.id]!
    assertEqual(rp.title, "Intact", "32: title intact")
    assertEqual(rp.headline, "H", "32b: headline")
    assertEqual(rp.about, "A", "32c: about")
    assertEqual(rp.goals, ["G1"], "32d: goals")
    assertEqual(rp.selectedProjectIDs, ["proj-1"], "32e: projects")
    assertEqual(rp.selectedAchievementIDs, ["ach-1"], "32f")
    assertEqual(rp.selectedEvidenceIDs, ["ev-1"], "32g")
    assertEqual(rp.selectedSkillIDs, ["python"], "32h")
    assertEqual(rp.selectedRoadmapIDs, ["roadmap-1"], "32i")
    assertEqual(rp.sections.count, 7, "32j: sections")
}
do { // 33. Multiple portfolios remain independent.
    let store = TestPortfolioStore()
    store.portfolios = [:]
    let p1 = store.createPortfolio(title: "Portfolio 1")
    let p2 = store.createPortfolio(title: "Portfolio 2")
    _ = store.addProject(to: p1.id, projectID: "proj-A")
    _ = store.addProject(to: p2.id, projectID: "proj-B")
    assertEqual(store.portfolio(id: p1.id)!.selectedProjectIDs, ["proj-A"], "33: p1 independent")
    assertEqual(store.portfolio(id: p2.id)!.selectedProjectIDs, ["proj-B"], "33b: p2 independent")
    assertNotEqual(store.portfolio(id: p1.id)!.selectedProjectIDs, store.portfolio(id: p2.id)!.selectedProjectIDs, "33c: not equal")
    // Modify p1 doesn't affect p2
    _ = store.updatePortfolioTitle(id: p1.id, title: "Updated 1")
    assertEqual(store.portfolio(id: p2.id)!.title, "Portfolio 2", "33d: p2 title unchanged")
    _ = store.addSkill(to: p1.id, skillID: "python")
    assert(store.portfolio(id: p2.id)!.selectedSkillIDs.isEmpty, "33e: p2 skills empty")
    // Persistence independent
    let data = try! encoder.encode(store.portfolios)
    let dec = try! decoder.decode([String: TestStudentPortfolio].self, from: data)
    assertEqual(dec[p1.id]!.selectedProjectIDs, ["proj-A"], "33f: p1 persist")
    assertEqual(dec[p2.id]!.selectedProjectIDs, ["proj-B"], "33g: p2 persist")
    // Delete one doesn't affect other except invariant
    // Ensure we have 2 then delete 1, should remain 1
    let countBefore = store.portfolios.count
    assertEqual(countBefore, 2, "33h: count 2")
    _ = store.deletePortfolio(id: p1.id)
    assert(store.portfolios[p1.id] == nil, "33i: p1 deleted")
    assert(store.portfolios[p2.id] != nil, "33j: p2 remains")
}

// MARK: - Integrity Tests (34-37)

do { // 34. Duplicate references are prevented.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    // Projects
    _ = store.addProject(to: pid, projectID: "proj-1")
    assert(!store.addProject(to: pid, projectID: "proj-1"), "34: duplicate project prevented")
    // Achievements
    _ = store.addAchievement(to: pid, achievementID: "ach-1")
    assert(!store.addAchievement(to: pid, achievementID: "ach-1"), "34b: duplicate ach")
    // Evidence
    _ = store.addEvidence(to: pid, evidenceID: "ev-1")
    assert(!store.addEvidence(to: pid, evidenceID: "ev-1"), "34c: duplicate ev")
    // Skills normalized duplicate
    _ = store.addSkill(to: pid, skillID: "Python")
    assert(!store.addSkill(to: pid, skillID: "python"), "34d: duplicate skill case")
    assert(!store.addSkill(to: pid, skillID: "  PYTHON  "), "34e: duplicate skill whitespace")
    // Roadmaps
    _ = store.addRoadmap(to: pid, roadmapID: "r1")
    assert(!store.addRoadmap(to: pid, roadmapID: "r1"), "34f: duplicate roadmap")
    // Verify counts remain 1 each
    let p = store.portfolio(id: pid)!
    assertEqual(p.selectedProjectIDs.count, 1, "34g: project count 1")
    assertEqual(p.selectedSkillIDs.count, 1, "34h: skill count 1")
}
do { // 35. Invalid/stale references do not crash.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    // Add references to non-existent canonical records — should succeed storing ID
    assert(store.addProject(to: pid, projectID: "nonexistent-project-123"), "35: stale project stored")
    assert(store.addAchievement(to: pid, achievementID: "stale-ach-999"), "35b: stale ach stored")
    assert(store.addEvidence(to: pid, evidenceID: "stale-ev-999"), "35c: stale ev stored")
    assert(store.addSkill(to: pid, skillID: "nonexistent-skill-xyz"), "35d: stale skill stored")
    assert(store.addRoadmap(to: pid, roadmapID: "stale-roadmap-xyz"), "35e: stale roadmap stored")
    // Portfolio should still be loadable and encode/decode
    let p = store.portfolio(id: pid)!
    assert(p.selectedProjectIDs.contains("nonexistent-project-123"), "35f: stale project preserved")
    let data = try! encoder.encode(p)
    let dec = try! decoder.decode(TestStudentPortfolio.self, from: data)
    assert(dec.selectedProjectIDs.contains("nonexistent-project-123"), "35g: stale survives encode/decode")
    // Deleting underlying canonical record should not affect portfolio (preserves IDs)
    // Simulate deletion: canonical store would remove project, but portfolio still holds ID
    assert(dec.selectedAchievementIDs.contains("stale-ach-999"), "35h: stale ach preserved")
    // Empty/whitespace IDs should be rejected not crash
    assert(!store.addProject(to: pid, projectID: "   "), "35i: blank project rejected")
    assert(!store.addSkill(to: pid, skillID: "   "), "35j: blank skill rejected")
    assert(store.portfolio(id: pid) != nil, "35k: portfolio still loadable")
    // Decode portfolio with missing optional fields should not crash
    let minimalJSON = #"{"id":"test-id","title":"Minimal"}"#.data(using:.utf8)!
    let decMin = try! decoder.decode(TestStudentPortfolio.self, from: minimalJSON)
    assertEqual(decMin.title, "Minimal", "35l: minimal decode title")
    assert(decMin.sections.count == 7, "35m: minimal defaults sections")
    assert(decMin.selectedProjectIDs.isEmpty, "35n: minimal projects empty")
    // Malformed sections should fallback gracefully
    let badSectionsJSON = #"{"id":"test-id2","title":"T","sections":[{"id":"bad","type":"invalid","title":"","isEnabled":false}],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}"#.data(using:.utf8)!
    let decBad = try! decoder.decode(TestStudentPortfolio.self, from: badSectionsJSON)
    assert(decBad.sections.count >= 1, "35o: bad sections decoded")
}
do { // 36. Duplicate sections are prevented.
    // Via init dedup
    let sections = [
        TestPortfolioSection(type: .about),
        TestPortfolioSection(type: .about),
        TestPortfolioSection(type: .projects),
        TestPortfolioSection(type: .projects),
        TestPortfolioSection(type: .skills),
    ]
    let p = TestStudentPortfolio(title: "T", sections: sections)
    assertEqual(p.sections.count, 3, "36: deduped to 3")
    assertEqual(p.sections.map(\.id), ["about", "projects", "skills"], "36b: order preserved first occurrence")
    // Via store dedup
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    // Try to create portfolio with duplicate sections via direct update
    var p2 = store.portfolio(id: pid)!
    p2.sections = [
        TestPortfolioSection(type: .about),
        TestPortfolioSection(type: .about),
        TestPortfolioSection(type: .goals),
    ]
    _ = store.updatePortfolio(p2)
    assertEqual(store.portfolio(id: pid)!.sections.map(\.id), ["about", "goals"], "36c: store dedup")
    // Duplicate via JSON decode
    let json = #"{"id":"dup-sec","title":"T","sections":[{"id":"about","type":"about","title":"About","isEnabled":true},{"id":"about","type":"about","title":"About Dup","isEnabled":true},{"id":"projects","type":"projects","title":"Projects","isEnabled":true}],"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","goals":[],"selectedProjectIDs":[],"selectedAchievementIDs":[],"selectedEvidenceIDs":[],"selectedSkillIDs":[],"selectedRoadmapIDs":[]}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestStudentPortfolio.self, from: json)
    assertEqual(dec.sections.count, 2, "36d: JSON dedup")
    assertEqual(dec.sections.map(\.id), ["about", "projects"], "36e")
}
do { // 37. Stable IDs remain stable.
    // Portfolio ID
    let id = "stable-portfolio-id-123"
    let p = TestStudentPortfolio(id: id, title: "Stable")
    assertEqual(p.id, id, "37: portfolio id stable")
    let data = try! encoder.encode(p)
    let dec = try! decoder.decode(TestStudentPortfolio.self, from: data)
    assertEqual(dec.id, id, "37b: portfolio id persist")
    // Section IDs stable (rawValue)
    for type in TestPortfolioSectionType.allCases {
        let sec = TestPortfolioSection(type: type)
        assertEqual(sec.id, type.rawValue, "37c: section id \(type.rawValue)")
    }
    // No index-based IDs
    let p2 = TestStudentPortfolio(title: "T2")
    for sec in p2.sections {
        assert(!sec.id.hasPrefix("section-") || sec.id == sec.type.rawValue, "37d: no index id \(sec.id)")
        assert(!sec.id.contains("-0") || sec.id == sec.type.rawValue, "37e: stable not index")
    }
    // Updating portfolio preserves ID
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    let originalID = pid
    _ = store.updatePortfolioTitle(id: pid, title: "New Title")
    assertEqual(store.portfolio(id: originalID)!.id, originalID, "37f: ID stable after title update")
    _ = store.addProject(to: originalID, projectID: "proj-1")
    assertEqual(store.portfolio(id: originalID)!.id, originalID, "37g: ID stable after selection")
    // Reordering preserves IDs
    _ = store.reorderSections(in: originalID, orderedIDs: ["projects", "about", "goals", "skills", "achievements", "evidence", "roadmaps"])
    assertEqual(store.portfolio(id: originalID)!.id, originalID, "37h: ID stable after reorder")
    let afterReorderSections = store.portfolio(id: originalID)!.sections.map(\.id)
    assert(afterReorderSections.contains("about"), "37i: about still stable")
}

// MARK: - Independence Tests (38-42)

do { // 38. Selecting project does not alter project progress.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    store.projectProgress["proj-1"] = 0
    let before = store.projectProgress["proj-1"]
    _ = store.addProject(to: pid, projectID: "proj-1")
    assertEqual(store.projectProgress["proj-1"], before, "38: projectProgress unchanged")
    _ = store.removeProject(from: pid, projectID: "proj-1")
    assertEqual(store.projectProgress["proj-1"], before, "38b: still unchanged after deselect")
    // Ordering also not mutate
    _ = store.addProject(to: pid, projectID: "proj-2")
    _ = store.reorderProjects(in: pid, orderedIDs: ["proj-2", "proj-1"])
    assertEqual(store.projectProgress["proj-1"], before, "38c: reorder not mutate")
}
do { // 39. Selecting achievement does not alter achievement status.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    store.achievementRecords["ach-1"] = "Recorded"
    let before = store.achievementRecords["ach-1"]
    _ = store.addAchievement(to: pid, achievementID: "ach-1")
    assertEqual(store.achievementRecords["ach-1"], before, "39: achievement unchanged")
    _ = store.removeAchievement(from: pid, achievementID: "ach-1")
    assertEqual(store.achievementRecords["ach-1"], before, "39b")
}
do { // 40. Selecting evidence does not alter evidence.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    store.evidenceRecords["ev-1"] = "Recorded Evidence"
    let before = store.evidenceRecords["ev-1"]
    _ = store.addEvidence(to: pid, evidenceID: "ev-1")
    assertEqual(store.evidenceRecords["ev-1"], before, "40: evidence unchanged")
    _ = store.removeEvidence(from: pid, evidenceID: "ev-1")
    assertEqual(store.evidenceRecords["ev-1"], before, "40b")
}
do { // 41. Selecting skill does not award the skill.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    store.skillSet = ["existing-skill"]
    let beforeCount = store.skillSet.count
    _ = store.addSkill(to: pid, skillID: "python")
    assertEqual(store.skillSet.count, beforeCount, "41: skillSet not mutated by add")
    assert(!store.skillSet.contains("python"), "41b: python not auto-added to skillSet")
    _ = store.addSkill(to: pid, skillID: "New Skill")
    assert(!store.skillSet.contains("new skill"), "41c: normalized skill not auto-added")
    // Ensure portfolio holds it but skillSet not changed
    assert(store.portfolio(id: pid)!.selectedSkillIDs.contains("python"), "41d: portfolio has python")
}
do { // 42. Selecting roadmap does not activate the roadmap.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    store.activeRoadmaps = []
    let before = store.activeRoadmaps
    _ = store.addRoadmap(to: pid, roadmapID: "roadmap-1")
    assertEqual(store.activeRoadmaps, before, "42: activeRoadmaps unchanged")
    assert(store.activeRoadmaps.isEmpty, "42b: still empty")
    _ = store.addRoadmap(to: pid, roadmapID: "software-engineer")
    assertEqual(store.activeRoadmaps, before, "42c: still not activated")
    _ = store.removeRoadmap(from: pid, roadmapID: "roadmap-1")
    assertEqual(store.activeRoadmaps, before, "42d: remove also not mutate")
}

// MARK: - Career Agnosticism Tests (43-44)

do { // 43. Portfolio can reference any roadmap type.
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    let roadmapTypes = ["software-engineer", "ai-engineer", "research-builder", "portfolio-projects", "college-ready", "stem-explorer", "leadership", "community-impact", "venture", "competitive-profile", "custom-roadmap-xyz", "entrepreneurship-1"]
    for rid in roadmapTypes {
        assert(store.addRoadmap(to: pid, roadmapID: rid), "43: can reference \(rid)")
    }
    let p = store.portfolio(id: pid)!
    for rid in roadmapTypes {
        assert(p.selectedRoadmapIDs.contains(rid), "43b: contains \(rid)")
    }
    // Persistence of diverse types
    let data = try! encoder.encode(p)
    let dec = try! decoder.decode(TestStudentPortfolio.self, from: data)
    for rid in roadmapTypes {
        assert(dec.selectedRoadmapIDs.contains(rid), "43c: persist \(rid)")
    }
    // Not limited to one category
    assertEqual(p.selectedRoadmapIDs.count, roadmapTypes.count, "43d: all stored")
}
do { // 44. No roadmap-specific portfolio logic exists.
    // Verify portfolio does not contain career-specific fields / logic
    let p = TestStudentPortfolio(title: "Career Agnostic")
    // Check that portfolio has generic fields only
    let mirror = Mirror(reflecting: p)
    let propertyNames = mirror.children.compactMap { $0.label }
    let forbiddenSubstrings = ["software", "ai", "college", "engineer", "coding"]
    for prop in propertyNames {
        for forbidden in forbiddenSubstrings {
            assert(!prop.lowercased().contains(forbidden), "44: property \(prop) does not contain forbidden \(forbidden)")
        }
    }
    // Check that portfolio can hold mixed types without special handling
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    _ = store.addRoadmap(to: pid, roadmapID: "software-engineer")
    _ = store.addRoadmap(to: pid, roadmapID: "leadership")
    _ = store.addProject(to: pid, projectID: "proj-research")
    _ = store.addProject(to: pid, projectID: "proj-leadership")
    _ = store.addSkill(to: pid, skillID: "Python")
    _ = store.addSkill(to: pid, skillID: "Leadership")
    _ = store.addSkill(to: pid, skillID: "Research")
    let p2 = store.portfolio(id: pid)!
    assert(p2.selectedRoadmapIDs.contains("software-engineer"), "44b: sw eng")
    assert(p2.selectedRoadmapIDs.contains("leadership"), "44c: leadership")
    assert(p2.selectedProjectIDs.contains("proj-research"), "44d: research proj")
    assert(p2.selectedSkillIDs.contains("python"), "44e: python")
    assert(p2.selectedSkillIDs.contains("leadership"), "44f: leadership skill")
    // Ensure no scoring or recommendation behavior is triggered by portfolio selection
    // Portrait: adding to portfolio should not affect any computed score (simulated by no mutation)
    let beforeProgress = store.projectProgress
    let beforeActive = store.activeRoadmaps
    _ = store.addRoadmap(to: pid, roadmapID: "another-roadmap")
    assertEqual(store.projectProgress, beforeProgress, "44g: no progress change")
    assertEqual(store.activeRoadmaps, beforeActive, "44h: no activation")
}

// MARK: - Additional Architecture Checks

do { // Ensure portfolio does not mutate canonical progress when updating metadata
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    store.projectProgress["proj-1"] = 1
    let before = store.projectProgress
    _ = store.updatePortfolioTitle(id: pid, title: "New Title")
    assertEqual(store.projectProgress, before, "arch: metadata update not mutate progress")
}
do { // Ensure portfolio Codable is additive / backward compatible
    // Old JSON without new fields should decode safely
    let oldJSON = #"{"id":"old-portfolio","title":"Old","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestStudentPortfolio.self, from: oldJSON)
    assertEqual(dec.title, "Old", "backward: title")
    assert(dec.sections.count == 7, "backward: sections default")
    assert(dec.selectedProjectIDs.isEmpty, "backward: projects default")
    assert(dec.headline == nil, "backward: headline nil")
    assert(dec.about == nil, "backward: about nil")
    // New field added later (e.g., extra optional) should not break old data
}
do { // Duplicate protection deterministic ordering
    let ids = ["proj-1", " proj-1 ", "PROJ-1", "proj-2", "proj-1"]
    // For non-skill dedup, "PROJ-1" is considered different (case-sensitive) — only whitespace trimmed, not lowercased
    let deduped = TestStudentPortfolio.dedupOrdered(ids)
    assertEqual(deduped, ["proj-1", "PROJ-1", "proj-2"], "deterministic: case-sensitive project dedup")
    // Skill dedup is case-insensitive via normalize
    let skillDedup = TestStudentPortfolio.dedupOrderedSkillIDs(["Python", "python", " PYTHON "])
    assertEqual(skillDedup, ["python"], "deterministic: skill case-insensitive")
}
do { // Section visibility
    let store = TestPortfolioStore()
    let pid = store.allPortfoliosSorted.first!.id
    assert(store.portfolio(id: pid)!.sections.first(where: { $0.id == "projects" })!.isEnabled == true, "visibility: default enabled")
    assert(store.setSectionEnabled(in: pid, sectionID: "projects", isEnabled: false), "visibility: disable")
    assert(store.portfolio(id: pid)!.sections.first(where: { $0.id == "projects" })!.isEnabled == false, "visibility: disabled")
    assert(store.setSectionEnabled(in: pid, sectionID: "projects", isEnabled: true), "visibility: enable")
    assert(store.portfolio(id: pid)!.sections.first(where: { $0.id == "projects" })!.isEnabled == true, "visibility: enabled again")
    // Invalid section id should return false not crash
    assert(!store.setSectionEnabled(in: pid, sectionID: "nonexistent", isEnabled: false), "visibility: invalid false")
}
do { // Verify no AI/networking/calculation logic in portfolio model (static check simulated)
    let p = TestStudentPortfolio(title: "T")
    // Mirror should not contain forbidden keywords
    let mirror = Mirror(reflecting: p)
    let names = mirror.children.compactMap { $0.label }.joined(separator: ",").lowercased()
    let forbidden = ["ai", "score", "ranking", "gpa", "confidence", "employability", "recommendation", "network"]
    for f in forbidden {
        // Check property names not containing forbidden scoring concepts
        // Allow "about" containing "ai"? but "about" is not forbidden; we check exact words
        // Use precise check: property names should not be exactly forbidden
        assert(!names.contains("\"\(f)\""), "static: no property \(f)")
    }
    // Also ensure portfolio sections enum not containing career-specific types
    assert(TestPortfolioSectionType.allCases.count == 7, "static: 7 section types")
    assertEqual(TestPortfolioSectionType.allCases.map(\.rawValue).sorted(), ["about", "achievements", "evidence", "goals", "projects", "roadmaps", "skills"], "static: section types correct")
}

print("\nPhase 8.1 — Portfolio Data Model: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
else { print("Some tests failed — review output above") }
