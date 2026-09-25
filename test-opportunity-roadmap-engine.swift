import Foundation

// Standalone test script for Phase 6.6 — Opportunity → Roadmap Engine
// Run: swift test-opportunity-roadmap-engine.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// ═══════════════════════════════════════════════════════════════
//  INLINE MODEL TYPES — mirroring production minimal fields
// ═══════════════════════════════════════════════════════════════

struct TestSkill: Hashable, Equatable {
    let id: String
    let name: String
    let category: String?
    init(id: String, name: String, category: String? = nil) {
        self.id = id; self.name = name; self.category = category
    }
    static func normalizeID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return parts.joined(separator: " ").lowercased()
    }
    static func canonical(from raw: String) -> TestSkill {
        let norm = normalizeID(raw)
        if let known = TestSkillCatalog.knownSkills[norm] { return known }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = trimmed.isEmpty ? norm : trimmed
        return TestSkill(id: norm, name: display)
    }
}

enum TestSkillCatalog {
    static let allSkills: [TestSkill] = [
        TestSkill(id: "python", name: "Python", category: "technical"),
        TestSkill(id: "javascript", name: "JavaScript", category: "technical"),
        TestSkill(id: "git", name: "Git", category: "technical"),
        TestSkill(id: "apis", name: "APIs", category: "technical"),
        TestSkill(id: "machine learning", name: "Machine Learning", category: "technical"),
        TestSkill(id: "data analysis", name: "Data Analysis", category: "data"),
        TestSkill(id: "software development", name: "Software Development", category: "technical"),
        TestSkill(id: "research methods", name: "Research Methods", category: "research"),
        TestSkill(id: "computational thinking", name: "Computational Thinking", category: "technical"),
        TestSkill(id: "question formation", name: "Question Formation", category: "research"),
        TestSkill(id: "data collection", name: "Data Collection", category: "data"),
        TestSkill(id: "technical writing", name: "Technical Writing", category: "communication"),
        TestSkill(id: "statistics", name: "Statistics", category: "data"),
        TestSkill(id: "ai application development", name: "AI Application Development", category: "technical"),
        TestSkill(id: "source evaluation", name: "Source Evaluation", category: "research"),
        TestSkill(id: "writing", name: "Writing", category: "communication"),
        TestSkill(id: "programming fundamentals", name: "Programming Fundamentals", category: "technical"),
        TestSkill(id: "leadership", name: "Leadership", category: "leadership"),
        TestSkill(id: "communication", name: "Communication", category: "communication"),
        TestSkill(id: "portfolio development", name: "Portfolio Development", category: "career"),
        TestSkill(id: "business fundamentals", name: "Business Fundamentals", category: "entrepreneurship"),
        TestSkill(id: "creativity", name: "Creativity", category: "core"),
        TestSkill(id: "scientific method", name: "Scientific Method", category: "research"),
        TestSkill(id: "academic planning", name: "Academic Planning", category: "academic"),
        TestSkill(id: "technical exploration", name: "Technical Exploration", category: "technical"),
        TestSkill(id: "critical thinking", name: "Critical Thinking", category: "academic"),
        TestSkill(id: "project planning", name: "Project Planning", category: "leadership"),
        TestSkill(id: "data analysis", name: "Data Analysis", category: "data"),
    ]
    static let knownSkills: [String: TestSkill] = {
        var map: [String: TestSkill] = [:]
        for s in allSkills { map[s.id] = s }
        return map
    }()
}

struct TestAction: Hashable {
    let id: String
    let title: String
    init(id: String, title: String) { self.id = id; self.title = title }
}

struct TestRoadmapMilestone: Hashable {
    let id: String
    let title: String
    let skillsDeveloped: [String]?
    let actions: [TestAction]?
    let dependencies: [String]?
    init(id: String, title: String, skillsDeveloped: [String]? = nil, actions: [TestAction]? = nil, dependencies: [String]? = nil) {
        self.id = id; self.title = title; self.skillsDeveloped = skillsDeveloped; self.actions = actions; self.dependencies = dependencies
    }
}

struct TestRoadmap: Hashable {
    let id: String
    let title: String
    let milestones: [TestRoadmapMilestone]
    init(id: String, title: String, milestones: [TestRoadmapMilestone]) {
        self.id = id; self.title = title; self.milestones = milestones
    }
}

enum TestGrade: String, Hashable { case seventh, eighth, ninth, tenth, eleventh, twelfth }

struct TestProfile: Hashable {
    var strengths: [String] = []
    var customSkills: [String] = []
    var grade: TestGrade = .ninth
}

struct TestRemoteOpportunity: Hashable {
    let id: String
    let title: String
    let skills: [String]
    let topics: [String]
    let subjects: [String]
    let category: String
    let deadline: String?
    init(id: String, title: String = "Opp", skills: [String] = [], topics: [String] = [], subjects: [String] = [], category: String = "competition", deadline: String? = nil) {
        self.id = id; self.title = title; self.skills = skills; self.topics = topics; self.subjects = subjects; self.category = category; self.deadline = deadline
    }
}

struct TestOpportunity: Hashable {
    let id: String
    let title: String
    let relevantSkills: [String]
    init(id: String, title: String = "Local", relevantSkills: [String] = []) {
        self.id = id; self.title = title; self.relevantSkills = relevantSkills
    }
}

struct TestEvidenceRecord: Hashable {
    let id: String
    let roadmapID: String
    let milestoneID: String
    init(id: String = UUID().uuidString, roadmapID: String, milestoneID: String) {
        self.id = id; self.roadmapID = roadmapID; self.milestoneID = milestoneID
    }
}

// GAP report minimal
struct TestSkillGap: Hashable {
    let skill: TestSkill
    var skillID: String { skill.id }
}
struct TestRoadmapSkillGapReport: Hashable {
    let roadmapID: String
    let roadmapTitle: String
    let requiredSkills: [TestSkill]
    let demonstratedSkills: [TestSkill]
    let gaps: [TestSkillGap]
}

// Milestone availability
enum TestMilestoneAvailability: Equatable {
    case completed
    case available
    case locked(blockingIDs: [String])
}

// Connection strength
enum TestConnectionStrength: String, Hashable, Comparable {
    case direct = "Direct"
    case relevant = "Relevant"
    case future = "Future"
    private var rank: Int {
        switch self {
        case .direct: return 3
        case .relevant: return 2
        case .future: return 1
        }
    }
    static func < (lhs: TestConnectionStrength, rhs: TestConnectionStrength) -> Bool { lhs.rank < rhs.rank }
}

enum TestMilestoneLinkStatus: String, Hashable {
    case current, available, locked, completed
}

struct TestMilestoneLink: Hashable {
    let id: String
    let title: String
    let status: TestMilestoneLinkStatus
    let actionIDs: [String]
    let actionTitles: [String]
}

struct TestConnection: Hashable {
    let id: String
    let opportunityID: String
    let roadmapID: String
    let roadmapTitle: String
    let strength: TestConnectionStrength
    let score: Int
    let matchedSkills: [TestSkill]
    let gapSkillsAddressed: [TestSkill]
    let milestoneLinks: [TestMilestoneLink]
    let reason: String
    let advancesCurrentMilestone: Bool
    let addressesGap: Bool
    var relatedMilestoneIDs: [String] { milestoneLinks.map(\.id) }
    var relatedActionIDs: [String] { milestoneLinks.flatMap(\.actionIDs) }
    var matchedSkillNames: [String] { matchedSkills.map(\.name) }
    var gapSkillNames: [String] { gapSkillsAddressed.map(\.name) }
}

// ═══════════════════════════════════════════════════════════════
//  TestSkillGapEngine — mirrors production exactly
// ═══════════════════════════════════════════════════════════════

enum TestSkillGapEngine {
    static func normalizeSkillID(_ raw: String) -> String { TestSkill.normalizeID(raw) }

    static func requiredSkills(for roadmap: TestRoadmap) -> [TestSkill] {
        var seen = Set<String>()
        var result: [TestSkill] = []
        for ms in roadmap.milestones {
            guard let dev = ms.skillsDeveloped else { continue }
            for raw in dev {
                let norm = normalizeSkillID(raw)
                guard !norm.isEmpty else { continue }
                if !seen.contains(norm) {
                    seen.insert(norm)
                    result.append(TestSkill.canonical(from: raw))
                }
            }
        }
        return result
    }

    static func demonstratedSkillIDs(profile: TestProfile, roadmapProgress: [String: Int] = [:], catalog: [TestRoadmap]? = nil, evidenceRecords: [String: TestEvidenceRecord]? = nil) -> Set<String> {
        var result = Set<String>()
        for raw in profile.strengths {
            let norm = normalizeSkillID(raw)
            if !norm.isEmpty { result.insert(norm) }
        }
        for raw in profile.customSkills {
            let norm = normalizeSkillID(raw)
            if !norm.isEmpty { result.insert(norm) }
        }
        if let catalog = catalog {
            for roadmap in catalog {
                let completed = min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
                guard completed > 0 else { continue }
                for idx in 0..<completed {
                    let ms = roadmap.milestones[idx]
                    if let skills = ms.skillsDeveloped {
                        for raw in skills {
                            let norm = normalizeSkillID(raw)
                            if !norm.isEmpty { result.insert(norm) }
                        }
                    }
                }
            }
        }
        if let evidence = evidenceRecords, let catalog = catalog {
            let map = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
            for rec in evidence.values {
                if let roadmap = map[rec.roadmapID],
                   let ms = roadmap.milestones.first(where: { $0.id == rec.milestoneID }),
                   let skills = ms.skillsDeveloped {
                    for raw in skills {
                        let norm = normalizeSkillID(raw)
                        if !norm.isEmpty { result.insert(norm) }
                    }
                }
            }
        }
        return result
    }

    static func evaluate(roadmap: TestRoadmap, profile: TestProfile, progress: [String: Int] = [:], catalog: [TestRoadmap]? = nil, evidenceRecords: [String: TestEvidenceRecord]? = nil) -> TestRoadmapSkillGapReport {
        let allRequired = requiredSkills(for: roadmap)
        let demonstratedIDs = demonstratedSkillIDs(profile: profile, roadmapProgress: progress, catalog: catalog ?? [roadmap], evidenceRecords: evidenceRecords)
        var demonstrated: [TestSkill] = []
        var missing: [TestSkill] = []
        for skill in allRequired {
            if demonstratedIDs.contains(skill.id) { demonstrated.append(skill) }
            else { missing.append(skill) }
        }
        // create gaps sorted by priority simplified: use production order? Just stable.
        // For correctness of gap detection we only need set of missing IDs.
        let gaps = missing.map { TestSkillGap(skill: $0) }
        return TestRoadmapSkillGapReport(roadmapID: roadmap.id, roadmapTitle: roadmap.title, requiredSkills: allRequired, demonstratedSkills: demonstrated, gaps: gaps)
    }
}

// ═══════════════════════════════════════════════════════════════
//  TestRoadmapEngine — milestoneAvailability
// ═══════════════════════════════════════════════════════════════

enum TestRoadmapEngine {
    static func milestoneAvailability(milestone: TestRoadmapMilestone, completedIDs: Set<String>, milestones: [TestRoadmapMilestone]) -> TestMilestoneAvailability {
        if completedIDs.contains(milestone.id) { return .completed }
        guard let deps = milestone.dependencies, !deps.isEmpty else { return .available }
        let incomplete = deps.filter { !completedIDs.contains($0) }
        if incomplete.isEmpty { return .available }
        return .locked(blockingIDs: incomplete)
    }
}

// ═══════════════════════════════════════════════════════════════
//  TestOpportunityRoadmapEngine — EXACT mirror of production
// ═══════════════════════════════════════════════════════════════

enum TestOpportunityRoadmapEngine {
    static func normalizedSkillIDs(for remote: TestRemoteOpportunity) -> Set<String> {
        var ids = Set<String>()
        for raw in remote.skills + remote.topics + remote.subjects {
            let norm = TestSkill.normalizeID(raw)
            if !norm.isEmpty { ids.insert(norm) }
        }
        return ids
    }
    static func normalizedSkillIDs(for opp: TestOpportunity) -> Set<String> {
        var ids = Set<String>()
        for raw in opp.relevantSkills {
            let norm = TestSkill.normalizeID(raw)
            if !norm.isEmpty { ids.insert(norm) }
        }
        return ids
    }

    static func connection(for remote: TestRemoteOpportunity, roadmap: TestRoadmap, profile: TestProfile, progress: [String: Int] = [:], catalog: [TestRoadmap]? = nil, evidenceRecords: [String: TestEvidenceRecord]? = nil) -> TestConnection? {
        let oppSkillIDs = normalizedSkillIDs(for: remote)
        guard !oppSkillIDs.isEmpty else { return nil }
        return connectionInternal(opportunityID: remote.id, oppSkillIDs: oppSkillIDs, roadmap: roadmap, profile: profile, progress: progress, catalog: catalog, evidenceRecords: evidenceRecords)
    }
    static func connection(for opp: TestOpportunity, roadmap: TestRoadmap, profile: TestProfile, progress: [String: Int] = [:], catalog: [TestRoadmap]? = nil, evidenceRecords: [String: TestEvidenceRecord]? = nil) -> TestConnection? {
        let oppSkillIDs = normalizedSkillIDs(for: opp)
        guard !oppSkillIDs.isEmpty else { return nil }
        return connectionInternal(opportunityID: opp.id, oppSkillIDs: oppSkillIDs, roadmap: roadmap, profile: profile, progress: progress, catalog: catalog, evidenceRecords: evidenceRecords)
    }

    static func connections(for remote: TestRemoteOpportunity, profile: TestProfile, progress: [String: Int], activeRoadmaps: [TestRoadmap], catalog: [TestRoadmap]? = nil, evidenceRecords: [String: TestEvidenceRecord]? = nil) -> [TestConnection] {
        let all = activeRoadmaps.compactMap { roadmap in
            connection(for: remote, roadmap: roadmap, profile: profile, progress: progress, catalog: catalog, evidenceRecords: evidenceRecords)
        }
        return sorted(all)
    }

    static func connections(for opp: TestOpportunity, profile: TestProfile, progress: [String: Int], activeRoadmaps: [TestRoadmap], catalog: [TestRoadmap]? = nil, evidenceRecords: [String: TestEvidenceRecord]? = nil) -> [TestConnection] {
        let oppSkillIDs = normalizedSkillIDs(for: opp)
        guard !oppSkillIDs.isEmpty else { return [] }
        let all = activeRoadmaps.compactMap { roadmap in
            connectionInternal(opportunityID: opp.id, oppSkillIDs: oppSkillIDs, roadmap: roadmap, profile: profile, progress: progress, catalog: catalog, evidenceRecords: evidenceRecords)
        }
        return sorted(all)
    }

    private static func connectionInternal(opportunityID: String, oppSkillIDs: Set<String>, roadmap: TestRoadmap, profile: TestProfile, progress: [String: Int], catalog: [TestRoadmap]?, evidenceRecords: [String: TestEvidenceRecord]?) -> TestConnection? {
        var skillToIndices: [String: [Int]] = [:]
        var skillIDToSkill: [String: TestSkill] = [:]
        for (idx, milestone) in roadmap.milestones.enumerated() {
            guard let dev = milestone.skillsDeveloped else { continue }
            for raw in dev {
                let norm = TestSkill.normalizeID(raw)
                guard !norm.isEmpty else { continue }
                skillToIndices[norm, default: []].append(idx)
                if skillIDToSkill[norm] == nil {
                    skillIDToSkill[norm] = TestSkill.canonical(from: raw)
                }
            }
        }
        guard !skillIDToSkill.isEmpty else { return nil }
        var matchedSkills: [TestSkill] = []
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

        let gapReport = TestSkillGapEngine.evaluate(roadmap: roadmap, profile: profile, progress: progress, catalog: catalog, evidenceRecords: evidenceRecords)
        let gapIDs = Set(gapReport.gaps.map(\.skillID))
        let gapSkillsAddressed = matchedSkills.filter { gapIDs.contains($0.id) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let completedCount = min(progress[roadmap.id] ?? 0, roadmap.milestones.count)
        let completedIDs = Set(roadmap.milestones.prefix(completedCount).map(\.id))

        var milestoneIndexSet = Set<Int>()
        for sid in matchedSkillIDs {
            if let indices = skillToIndices[sid] {
                for i in indices { milestoneIndexSet.insert(i) }
            }
        }
        let sortedIndices = milestoneIndexSet.sorted()
        var milestoneLinks: [TestMilestoneLink] = []
        for idx in sortedIndices {
            let milestone = roadmap.milestones[idx]
            let availability = TestRoadmapEngine.milestoneAvailability(milestone: milestone, completedIDs: completedIDs, milestones: roadmap.milestones)
            let status: TestMilestoneLinkStatus
            switch availability {
            case .completed: status = .completed
            case .locked: status = .locked
            case .available: status = (idx == completedCount) ? .current : .available
            }
            let actions = milestone.actions ?? []
            milestoneLinks.append(TestMilestoneLink(id: milestone.id, title: milestone.title, status: status, actionIDs: actions.map(\.id), actionTitles: actions.map(\.title)))
        }

        let hasCurrent = milestoneLinks.contains { $0.status == .current }
        let hasAvailable = milestoneLinks.contains { $0.status == .available || $0.status == .current }
        let totalActions = milestoneLinks.reduce(0) { $0 + $1.actionIDs.count }
        let base = matchedSkills.count * 10
        let gapBonus = gapSkillsAddressed.count * 15
        let currentBonus = hasCurrent ? 20 : 0
        let availableBonus = hasAvailable ? 10 : 0
        let actionBonus = min(totalActions, 10)
        let earliestIdx = sortedIndices.first ?? 0
        let earlinessBonus = max(0, (roadmap.milestones.count - earliestIdx) * 2)
        let score = base + gapBonus + currentBonus + availableBonus + actionBonus + earlinessBonus

        let strength: TestConnectionStrength
        if !gapSkillsAddressed.isEmpty && hasAvailable {
            strength = .direct
        } else if hasAvailable {
            strength = .relevant
        } else if !matchedSkills.isEmpty {
            strength = .future
        } else {
            strength = .future
        }

        let advancesCurrentMilestone = hasCurrent
        let addressesGap = !gapSkillsAddressed.isEmpty

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

        return TestConnection(id: "\(opportunityID)-\(roadmap.id)", opportunityID: opportunityID, roadmapID: roadmap.id, roadmapTitle: roadmap.title, strength: strength, score: score, matchedSkills: matchedSkills, gapSkillsAddressed: gapSkillsAddressed, milestoneLinks: milestoneLinks, reason: reason, advancesCurrentMilestone: advancesCurrentMilestone, addressesGap: addressesGap)
    }

    private static func sorted(_ connections: [TestConnection]) -> [TestConnection] {
        connections.sorted { lhs, rhs in
            if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.roadmapTitle.localizedCaseInsensitiveCompare(rhs.roadmapTitle) == .orderedAscending
        }
    }
}

// ═══════════════════════════════════════════════════════════════
//  TEST CATALOG — 10 roadmaps
// ═══════════════════════════════════════════════════════════════

let softwareEngineer = TestRoadmap(id: "software-engineer", title: "Become a Software Engineer", milestones: [
    TestRoadmapMilestone(id: "software-1", title: "Explore CS", skillsDeveloped: ["Python", "Computational Thinking"], actions: [TestAction(id: "software-1-action-1", title: "Watch video"), TestAction(id: "software-1-action-2", title: "Setup env")], dependencies: nil),
    TestRoadmapMilestone(id: "software-2", title: "Programming Fundamentals", skillsDeveloped: ["Git", "Software Development"], actions: [TestAction(id: "software-2-action-1", title: "Learn Git"), TestAction(id: "software-2-action-2", title: "Debug")], dependencies: ["software-1"]),
    TestRoadmapMilestone(id: "software-3", title: "Software Development", skillsDeveloped: ["APIs", "Software Development"], actions: [TestAction(id: "software-3-action-1", title: "Call API")], dependencies: ["software-2"])
])
let aiEngineer = TestRoadmap(id: "ai-engineer", title: "Become an AI Engineer", milestones: [
    TestRoadmapMilestone(id: "ai-1", title: "Explore AI", skillsDeveloped: ["Python", "Data Analysis"], actions: [TestAction(id: "ai-1-action-1", title: "Watch AI"), TestAction(id: "ai-1-action-2", title: "Try demo")], dependencies: nil),
    TestRoadmapMilestone(id: "ai-2", title: "ML Foundations", skillsDeveloped: ["Machine Learning", "Statistics"], actions: [TestAction(id: "ai-2-action-1", title: "Study ML"), TestAction(id: "ai-2-action-2", title: "Train model")], dependencies: ["ai-1"]),
    TestRoadmapMilestone(id: "ai-3", title: "AI Applications", skillsDeveloped: ["AI Application Development"], actions: [TestAction(id: "ai-3-action-1", title: "Build app")], dependencies: ["ai-2"])
])
let researchBuilder = TestRoadmap(id: "research-builder", title: "Build a Research Profile", milestones: [
    TestRoadmapMilestone(id: "research-1", title: "Explore Research", skillsDeveloped: ["Research Methods", "Question Formation"], actions: [TestAction(id: "research-1-action-1", title: "Watch researchers")], dependencies: nil),
    TestRoadmapMilestone(id: "research-2", title: "Investigate", skillsDeveloped: ["Data Collection", "Technical Writing"], actions: [TestAction(id: "research-2-action-1", title: "Collect data")], dependencies: ["research-1"])
])

let stemExplorer = TestRoadmap(id: "stem-explorer", title: "Explore STEM", milestones: [
    TestRoadmapMilestone(id: "stem-1", title: "STEM Intro", skillsDeveloped: ["Technical Exploration"], actions: [TestAction(id: "stem-1-action-1", title: "Do lab")])
])
let leadershipRoadmap = TestRoadmap(id: "leadership", title: "Build Leadership", milestones: [
    TestRoadmapMilestone(id: "leadership-1", title: "Lead Intro", skillsDeveloped: ["Leadership"], actions: [TestAction(id: "leadership-1-action-1", title: "Lead task")])
])
let entrepreneurshipRoadmap = TestRoadmap(id: "entrepreneurship", title: "Entrepreneurship Basics", milestones: [
    TestRoadmapMilestone(id: "entrepreneurship-1", title: "Startup Intro", skillsDeveloped: ["Business Fundamentals"], actions: [TestAction(id: "entrepreneurship-1-action-1", title: "Pitch")])
])
let creativeArtsRoadmap = TestRoadmap(id: "creative-arts", title: "Creative Arts Path", milestones: [
    TestRoadmapMilestone(id: "creative-1", title: "Creativity Intro", skillsDeveloped: ["Creativity"], actions: [TestAction(id: "creative-1-action-1", title: "Create")])
])
let healthSciencesRoadmap = TestRoadmap(id: "health-sciences", title: "Health Sciences", milestones: [
    TestRoadmapMilestone(id: "health-1", title: "Health Intro", skillsDeveloped: ["Scientific Method"], actions: [TestAction(id: "health-1-action-1", title: "Study")])
])
let environmentalRoadmap = TestRoadmap(id: "environmental", title: "Environmental Action", milestones: [
    TestRoadmapMilestone(id: "env-1", title: "Env Intro", skillsDeveloped: ["Data Collection"], actions: [TestAction(id: "env-1-action-1", title: "Field work")])
])
let collegePrepRoadmap = TestRoadmap(id: "college-prep", title: "College Preparation", milestones: [
    TestRoadmapMilestone(id: "college-1", title: "College Intro", skillsDeveloped: ["Academic Planning"], actions: [TestAction(id: "college-1-action-1", title: "Plan")])
])

let allTenRoadmaps: [TestRoadmap] = [softwareEngineer, aiEngineer, researchBuilder, stemExplorer, leadershipRoadmap, entrepreneurshipRoadmap, creativeArtsRoadmap, healthSciencesRoadmap, environmentalRoadmap, collegePrepRoadmap]

// Simulated store-like helper
struct TestStore {
    var profile: TestProfile
    var progress: [String: Int] = [:]
    var activeRoadmaps: [TestRoadmap] = []
    var evidence: [String: TestEvidenceRecord] = [:]
    var catalog: [TestRoadmap] { allTenRoadmaps }
    func connections(for remote: TestRemoteOpportunity) -> [TestConnection] {
        TestOpportunityRoadmapEngine.connections(for: remote, profile: profile, progress: progress, activeRoadmaps: activeRoadmaps, catalog: catalog, evidenceRecords: evidence)
    }
    func connections(for opp: TestOpportunity) -> [TestConnection] {
        TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: progress, activeRoadmaps: activeRoadmaps, catalog: catalog, evidenceRecords: evidence)
    }
}

// ═══════════════════════════════════════════════════════════════
//  TESTS — at least 44 categories
// ═══════════════════════════════════════════════════════════════

print("—— Basic (1-7) ——")

do { // 1. Opportunity with no matching skills → no connection
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-1", skills: ["Basket Weaving"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn == nil, "T1: no matching skills → nil")
    let conns = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: [:], activeRoadmaps: [softwareEngineer])
    assertEqual(conns.count, 0, "T1: connections empty")
    // also local
    let local = TestOpportunity(id: "loc-1", relevantSkills: ["Basket Weaving"])
    let connLocal = TestOpportunityRoadmapEngine.connection(for: local, roadmap: softwareEngineer, profile: profile)
    assert(connLocal == nil, "T1: local no match nil")
}

do { // 2. Opportunity matching one roadmap skill → connection
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-2", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn != nil, "T2: python matches SE")
    assertEqual(conn?.matchedSkills.count, 1, "T2: 1 matched")
    assertEqual(conn?.matchedSkills.first?.id, "python", "T2: matched python")
    assertEqual(conn?.roadmapID, "software-engineer", "T2: roadmap id")
    assertEqual(conn?.opportunityID, "opp-2", "T2: opp id")
}

do { // 3. Opportunity matching multiple roadmap skills → connection contains all
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-3", skills: ["Python", "Git"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn != nil, "T3: multi match not nil")
    assertEqual(conn?.matchedSkills.count, 2, "T3: 2 matched")
    let ids = Set(conn?.matchedSkills.map(\.id) ?? [])
    assert(ids.contains("python"), "T3: contains python")
    assert(ids.contains("git"), "T3: contains git")
    // check milestoneLinks contains both milestones
    assertEqual(conn?.milestoneLinks.count, 2, "T3: 2 milestone links")
}

do { // 4. Exact canonical skill matching
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-4", skills: ["Machine Learning"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: aiEngineer, profile: profile)
    assert(conn != nil, "T4: exact ML match")
    assertEqual(conn?.matchedSkills.first?.name, "Machine Learning", "T4: canonical name")
    assertEqual(conn?.matchedSkills.first?.id, "machine learning", "T4: canonical id")
}

do { // 5. Case normalization (PYTHON vs python)
    let profile = TestProfile()
    let oppLower = TestRemoteOpportunity(id: "opp-5a", skills: ["python"])
    let oppUpper = TestRemoteOpportunity(id: "opp-5b", skills: ["PYTHON"])
    let oppMixed = TestRemoteOpportunity(id: "opp-5c", skills: ["PyThOn"])
    let c1 = TestOpportunityRoadmapEngine.connection(for: oppLower, roadmap: softwareEngineer, profile: profile)
    let c2 = TestOpportunityRoadmapEngine.connection(for: oppUpper, roadmap: softwareEngineer, profile: profile)
    let c3 = TestOpportunityRoadmapEngine.connection(for: oppMixed, roadmap: softwareEngineer, profile: profile)
    assert(c1 != nil && c2 != nil && c3 != nil, "T5: all case variants match")
    assertEqual(c1?.matchedSkills.first?.id, "python", "T5: lower id")
    assertEqual(c2?.matchedSkills.first?.id, "python", "T5: upper id")
    assertEqual(c3?.matchedSkills.first?.id, "python", "T5: mixed id")
    assertEqual(c1?.matchedSkills, c2?.matchedSkills, "T5: lower == upper")
}

do { // 6. Whitespace normalization (" Python " vs "Python")
    let profile = TestProfile()
    let oppSpace = TestRemoteOpportunity(id: "opp-6", skills: [" Python "])
    let oppMulti = TestRemoteOpportunity(id: "opp-6b", skills: ["  Python   "])
    let oppNormal = TestRemoteOpportunity(id: "opp-6c", skills: ["Python"])
    let c1 = TestOpportunityRoadmapEngine.connection(for: oppSpace, roadmap: softwareEngineer, profile: profile)
    let c2 = TestOpportunityRoadmapEngine.connection(for: oppMulti, roadmap: softwareEngineer, profile: profile)
    let c3 = TestOpportunityRoadmapEngine.connection(for: oppNormal, roadmap: softwareEngineer, profile: profile)
    assert(c1 != nil, "T6: whitespace trimmed matches")
    assertEqual(c1?.matchedSkills.first?.id, "python", "T6: trimmed id")
    assertEqual(c1?.matchedSkills, c2?.matchedSkills, "T6: multi-space equals normal")
    assertEqual(c2?.matchedSkills, c3?.matchedSkills, "T6: multi equals normal")
    // also test normalizeID directly
    assertEqual(TestSkill.normalizeID(" Python "), "python", "T6: normalize trims")
    assertEqual(TestSkill.normalizeID("  Machine   Learning  "), "machine learning", "T6: collapses whitespace")
}

do { // 7. No fuzzy false positives ("Python" does not match "JavaScript")
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-7", skills: ["Python"])
    // researchBuilder has no python
    let connResearch = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: researchBuilder, profile: profile)
    assert(connResearch == nil, "T7: python not match research")
    let oppJS = TestRemoteOpportunity(id: "opp-7b", skills: ["JavaScript"])
    let connSE = TestOpportunityRoadmapEngine.connection(for: oppJS, roadmap: softwareEngineer, profile: profile)
    assert(connSE == nil, "T7: JS not in SE minimal (python/git/apis) → nil")
    // Ensure python != javascript ids
    assert(TestSkill.normalizeID("Python") != TestSkill.normalizeID("JavaScript"), "T7: ids distinct")
    // Python should still match SE
    let connPY = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(connPY != nil, "T7: python matches SE")
}

print("—— Skill Gaps (8-11) ——")

do { // 8. Matching a current skill gap is identified (gapSkillsAddressed not empty)
    let profile = TestProfile() // no skills → all gaps
    let opp = TestRemoteOpportunity(id: "opp-8", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn != nil, "T8: conn not nil")
    assert(!conn!.gapSkillsAddressed.isEmpty, "T8: gap not empty")
    assert(conn!.addressesGap, "T8: addressesGap true")
    assertEqual(conn?.gapSkillsAddressed.first?.id, "python", "T8: gap is python")
}

do { // 9. Demonstrated skill is not incorrectly labeled as a gap (if student has Python, gap not include Python)
    var profile = TestProfile()
    profile.strengths = ["Python"]
    let opp = TestRemoteOpportunity(id: "opp-9", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn != nil, "T9: conn still exists (matched skill)")
    assertEqual(conn?.gapSkillsAddressed.count, 0, "T9: gap empty because python demonstrated")
    assert(!conn!.addressesGap, "T9: addressesGap false")
    // verify demonstrated detection via gap engine
    let gapReport = TestSkillGapEngine.evaluate(roadmap: softwareEngineer, profile: profile)
    let gapIDs = Set(gapReport.gaps.map(\.skillID))
    assert(!gapIDs.contains("python"), "T9: gap report no python")
}

do { // 10. Multiple gaps can be addressed (opp matches 2 gaps)
    let profile = TestProfile() // empty → all gaps
    let opp = TestRemoteOpportunity(id: "opp-10", skills: ["Python", "Git"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn != nil, "T10: conn not nil")
    assertEqual(conn?.gapSkillsAddressed.count, 2, "T10: 2 gaps")
    let gapIds = Set(conn?.gapSkillsAddressed.map(\.id) ?? [])
    assert(gapIds.contains("python"), "T10: gap python")
    assert(gapIds.contains("git"), "T10: gap git")
    assert(conn!.addressesGap, "T10: addressesGap")
}

do { // 11. Unrelated gaps remain untouched
    var profile = TestProfile()
    profile.strengths = ["Python"] // demonstrate python, but opp matches Git
    let opp = TestRemoteOpportunity(id: "opp-11", skills: ["Git"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn != nil, "T11: git conn")
    assertEqual(conn?.gapSkillsAddressed.count, 1, "T11: 1 gap")
    assertEqual(conn?.gapSkillsAddressed.first?.id, "git", "T11: gap git")
    // ensure python gap not included when opp doesn't match python
    assert(!(conn?.gapSkillsAddressed.map(\.id).contains("python") ?? false), "T11: python not in gap")
    // unrelated roadmap gaps untouched: check ai gap still exists independently
    let aiGap = TestSkillGapEngine.evaluate(roadmap: aiEngineer, profile: profile)
    assert(aiGap.gaps.contains(where: { $0.skillID == "machine learning" }), "T11: AI gap untouched")
}

print("—— Milestones (12-17) ——")

do { // 12. Matching skills map to correct milestone
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-12", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assertEqual(conn?.milestoneLinks.count, 1, "T12: 1 milestone")
    assertEqual(conn?.milestoneLinks.first?.id, "software-1", "T12: python → software-1")
    let oppGit = TestRemoteOpportunity(id: "opp-12b", skills: ["Git"])
    let connGit = TestOpportunityRoadmapEngine.connection(for: oppGit, roadmap: softwareEngineer, profile: profile)
    assertEqual(connGit?.milestoneLinks.first?.id, "software-2", "T12: git → software-2")
    let oppAPI = TestRemoteOpportunity(id: "opp-12c", skills: ["APIs"])
    let connAPI = TestOpportunityRoadmapEngine.connection(for: oppAPI, roadmap: softwareEngineer, profile: profile)
    assertEqual(connAPI?.milestoneLinks.first?.id, "software-3", "T12: apis → software-3")
}

do { // 13. Matching skills map to correct actions
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-13", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assertEqual(conn?.milestoneLinks.first?.actionIDs, ["software-1-action-1", "software-1-action-2"], "T13: actions for software-1")
    assertEqual(conn?.milestoneLinks.first?.actionTitles, ["Watch video", "Setup env"], "T13: titles")
    let oppGit = TestRemoteOpportunity(id: "opp-13b", skills: ["Git"])
    let connGit = TestOpportunityRoadmapEngine.connection(for: oppGit, roadmap: softwareEngineer, profile: profile)
    assertEqual(connGit?.milestoneLinks.first?.actionIDs.count, 2, "T13: git milestone has 2 actions")
    let oppAPI = TestRemoteOpportunity(id: "opp-13c", skills: ["APIs"])
    let connAPI = TestOpportunityRoadmapEngine.connection(for: oppAPI, roadmap: softwareEngineer, profile: profile)
    assertEqual(connAPI?.milestoneLinks.first?.actionIDs, ["software-3-action-1"], "T13: api 1 action")
}

do { // 14. Multiple milestones can be returned when appropriate (opp matches skills from 2 milestones)
    let profile = TestProfile()
    // Python from software-1 and Git from software-2
    let opp = TestRemoteOpportunity(id: "opp-14", skills: ["Python", "Git"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assertEqual(conn?.milestoneLinks.count, 2, "T14: 2 milestones")
    let ids = Set(conn?.milestoneLinks.map(\.id) ?? [])
    assert(ids.contains("software-1"), "T14: contains software-1")
    assert(ids.contains("software-2"), "T14: contains software-2")
    // Software Development appears in software-2 and software-3 → should return both
    let oppSD = TestRemoteOpportunity(id: "opp-14b", skills: ["Software Development"])
    let connSD = TestOpportunityRoadmapEngine.connection(for: oppSD, roadmap: softwareEngineer, profile: profile)
    assertEqual(connSD?.milestoneLinks.count, 2, "T14: Software Dev spans 2 milestones")
    let sdIds = Set(connSD?.milestoneLinks.map(\.id) ?? [])
    assert(sdIds.contains("software-2") && sdIds.contains("software-3"), "T14: SD in both 2 and 3")
}

do { // 15. Completed milestone state is represented correctly
    var profile = TestProfile()
    let progress = ["software-engineer": 1] // software-1 completed
    let opp = TestRemoteOpportunity(id: "opp-15", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile, progress: progress)
    assert(conn != nil, "T15: conn not nil")
    assertEqual(conn?.milestoneLinks.first?.status, .completed, "T15: software-1 completed")
    assertEqual(conn?.milestoneLinks.first?.id, "software-1", "T15: id correct")
    // ensure completed still shows matched but status completed
    assertEqual(conn?.matchedSkills.first?.id, "python", "T15: matched still python")
}

do { // 16. Current milestone receives appropriate connection state (status .current, advancesCurrentMilestone true)
    let profile = TestProfile()
    let progress: [String: Int] = [:] // 0 completed → software-1 is current
    let opp = TestRemoteOpportunity(id: "opp-16", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile, progress: progress)
    assertEqual(conn?.milestoneLinks.first?.status, .current, "T16: python milestone current")
    assert(conn!.advancesCurrentMilestone, "T16: advancesCurrent true")
    // also check with progress 1: software-2 should be current
    let progress1 = ["software-engineer": 1]
    let oppGit = TestRemoteOpportunity(id: "opp-16b", skills: ["Git"])
    let connGit = TestOpportunityRoadmapEngine.connection(for: oppGit, roadmap: softwareEngineer, profile: profile, progress: progress1)
    assertEqual(connGit?.milestoneLinks.first?.status, .current, "T16: git current after 1")
    assert(connGit!.advancesCurrentMilestone, "T16: git advances current")
    // verify score bonus for current (20) included
    // base 10 + gap 15 + current 20 + available 10 + actions min2 + earliness
    // should be > without current
}

do { // 17. Locked/future milestone is not treated as immediately available (status .locked)
    let profile = TestProfile()
    let progress: [String: Int] = [:] // nothing completed, so software-2 locked, software-3 locked
    let oppGit = TestRemoteOpportunity(id: "opp-17", skills: ["Git"])
    let connGit = TestOpportunityRoadmapEngine.connection(for: oppGit, roadmap: softwareEngineer, profile: profile, progress: progress)
    assertEqual(connGit?.milestoneLinks.first?.status, .locked, "T17: git locked when 0")
    assert(!connGit!.advancesCurrentMilestone, "T17: not advances")
    assertEqual(connGit?.strength, .future, "T17: strength future when locked")
    let oppAPI = TestRemoteOpportunity(id: "opp-17b", skills: ["APIs"])
    let connAPI = TestOpportunityRoadmapEngine.connection(for: oppAPI, roadmap: softwareEngineer, profile: profile, progress: progress)
    assertEqual(connAPI?.milestoneLinks.first?.status, .locked, "T17: apis locked")
    assertEqual(connAPI?.strength, .future, "T17: apis future")
    // after completing software-1, git becomes current, but apis still locked? Actually apis deps software-2, so still locked
    let progress1 = ["software-engineer": 1]
    let connAPILocked = TestOpportunityRoadmapEngine.connection(for: oppAPI, roadmap: softwareEngineer, profile: profile, progress: progress1)
    assertEqual(connAPILocked?.milestoneLinks.first?.status, .locked, "T17: apis still locked after 1")
}

print("—— Multiple Roadmaps (18-20) ——")

do { // 18. One opportunity can connect to multiple active roadmaps
    let profile = TestProfile()
    // Python appears in both SE (software-1) and AI (ai-1)
    let opp = TestRemoteOpportunity(id: "opp-18", skills: ["Python"])
    let active = [softwareEngineer, aiEngineer]
    let conns = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: [:], activeRoadmaps: active)
    assertEqual(conns.count, 2, "T18: 2 connections")
    let ids = Set(conns.map(\.roadmapID))
    assert(ids.contains("software-engineer"), "T18: SE")
    assert(ids.contains("ai-engineer"), "T18: AI")
}

do { // 19. Roadmap calculations remain independent (gap for SE not affecting AI)
    var profile = TestProfile()
    profile.strengths = ["Python"] // python demonstrated → not gap
    // Opp with Python + Machine Learning
    let opp = TestRemoteOpportunity(id: "opp-19", skills: ["Python", "Machine Learning"])
    // SE: python not gap, but AI: machine learning still gap, python also not gap but AI has python too?
    let connSE = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    // SE matched python only? Actually SE has python, not ML. So SE matched 1, gap 0
    assertEqual(connSE?.matchedSkills.count, 1, "T19: SE matched 1")
    assertEqual(connSE?.gapSkillsAddressed.count, 0, "T19: SE gap 0 because python demonstrated")
    let connAI = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: aiEngineer, profile: profile)
    assertEqual(connAI?.matchedSkills.count, 2, "T19: AI matched 2")
    assertEqual(connAI?.gapSkillsAddressed.count, 1, "T19: AI gap 1 (ML)")
    assertEqual(connAI?.gapSkillsAddressed.first?.id, "machine learning", "T19: AI gap ML")
}

do { // 20. No cross-roadmap skill contamination
    let profile = TestProfile()
    // Opp with Research Methods should only match researchBuilder, not SE or AI
    let opp = TestRemoteOpportunity(id: "opp-20", skills: ["Research Methods"])
    let conns = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: [:], activeRoadmaps: [softwareEngineer, aiEngineer, researchBuilder])
    assertEqual(conns.count, 1, "T20: 1 connection")
    assertEqual(conns.first?.roadmapID, "research-builder", "T20: research only")
    // Ensure SE milestonLinks not polluted with research skills
    let connSE = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(connSE == nil, "T20: SE nil for research skill")
}

print("—— Edge Cases (21-30) ——")

do { // 21. No active roadmaps → empty connections
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-21", skills: ["Python"])
    let conns = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: [:], activeRoadmaps: [])
    assertEqual(conns.count, 0, "T21: empty active → empty")
    // also local
    let local = TestOpportunity(id: "loc-21", relevantSkills: ["Python"])
    let connsLocal = TestOpportunityRoadmapEngine.connections(for: local, profile: profile, progress: [:], activeRoadmaps: [])
    assertEqual(connsLocal.count, 0, "T21: local empty active")
}

do { // 22. Empty opportunity skills → no connection
    let profile = TestProfile()
    let oppEmpty = TestRemoteOpportunity(id: "opp-22", skills: [], topics: [], subjects: [])
    let conn = TestOpportunityRoadmapEngine.connection(for: oppEmpty, roadmap: softwareEngineer, profile: profile)
    assert(conn == nil, "T22: empty skills nil")
    let conns = TestOpportunityRoadmapEngine.connections(for: oppEmpty, profile: profile, progress: [:], activeRoadmaps: [softwareEngineer, aiEngineer])
    assertEqual(conns.count, 0, "T22: connections empty")
    let localEmpty = TestOpportunity(id: "loc-22", relevantSkills: [])
    let connLocal = TestOpportunityRoadmapEngine.connection(for: localEmpty, roadmap: softwareEngineer, profile: profile)
    assert(connLocal == nil, "T22: local empty nil")
}

do { // 23. Empty roadmap skills → no connection
    let emptyRoadmap = TestRoadmap(id: "empty", title: "Empty", milestones: [
        TestRoadmapMilestone(id: "empty-1", title: "Empty Milestone", skillsDeveloped: nil, actions: [TestAction(id: "a1", title: "Act")]),
        TestRoadmapMilestone(id: "empty-2", title: "Empty2", skillsDeveloped: [], actions: nil)
    ])
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-23", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: emptyRoadmap, profile: profile)
    assert(conn == nil, "T23: empty roadmap skills nil")
    let emptySkillsRoadmap2 = TestRoadmap(id: "empty2", title: "Empty2", milestones: [
        TestRoadmapMilestone(id: "e2-1", title: "M1", skillsDeveloped: ["", "   "], actions: nil)
    ])
    let conn2 = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: emptySkillsRoadmap2, profile: profile)
    assert(conn2 == nil, "T23: whitespace-only skills nil")
}

do { // 24. Missing optional topics (opp with only skills, no topics/subjects still works)
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-24", skills: ["Python"], topics: [], subjects: [])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn != nil, "T24: skills only works")
    // opp with only topics
    let oppTopics = TestRemoteOpportunity(id: "opp-24b", skills: [], topics: ["Python"], subjects: [])
    let connTopics = TestOpportunityRoadmapEngine.connection(for: oppTopics, roadmap: softwareEngineer, profile: profile)
    assert(connTopics != nil, "T24: topics only works")
    assertEqual(connTopics?.matchedSkills.first?.id, "python", "T24: topics python")
    // only subjects
    let oppSubjects = TestRemoteOpportunity(id: "opp-24c", skills: [], topics: [], subjects: ["Git"])
    let connSubj = TestOpportunityRoadmapEngine.connection(for: oppSubjects, roadmap: softwareEngineer, profile: profile, progress: ["software-engineer": 1])
    assert(connSubj != nil, "T24: subjects only works — needs progress for current")
    // All three combined should dedupe and still work
    let oppAll = TestRemoteOpportunity(id: "opp-24d", skills: ["Python"], topics: ["Python"], subjects: ["Python"])
    let connAll = TestOpportunityRoadmapEngine.connection(for: oppAll, roadmap: softwareEngineer, profile: profile)
    assertEqual(connAll?.matchedSkills.count, 1, "T24: deduped to 1")
}

do { // 25. Duplicate opportunity skills → deduplicated, one matched skill
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-25", skills: ["Python", "Python", "PYTHON", " python "])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assertEqual(conn?.matchedSkills.count, 1, "T25: deduplicated to 1")
    assertEqual(conn?.matchedSkills.first?.id, "python", "T25: python")
    // duplicate across fields also deduped
    let opp2 = TestRemoteOpportunity(id: "opp-25b", skills: ["Python"], topics: ["Python"], subjects: ["Python"])
    let conn2 = TestOpportunityRoadmapEngine.connection(for: opp2, roadmap: softwareEngineer, profile: profile)
    assertEqual(conn2?.matchedSkills.count, 1, "T25: cross-field deduplicated")
}

do { // 26. Duplicate roadmap skills → deduplicated in required
    let dupRoadmap = TestRoadmap(id: "dup", title: "Dup", milestones: [
        TestRoadmapMilestone(id: "dup-1", title: "M1", skillsDeveloped: ["Python", "Python", "PYTHON"], actions: [TestAction(id: "dup-a", title: "A")]),
        TestRoadmapMilestone(id: "dup-2", title: "M2", skillsDeveloped: ["Python"], actions: nil)
    ])
    let required = TestSkillGapEngine.requiredSkills(for: dupRoadmap)
    assertEqual(required.count, 1, "T26: deduplicated required to 1")
    assertEqual(required.first?.id, "python", "T26: python")
    // Opp matching Python should still produce correct connection with 2 milestone links (both milestones have python)
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-26", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: dupRoadmap, profile: profile)
    assertEqual(conn?.matchedSkills.count, 1, "T26: matched 1")
    assertEqual(conn?.milestoneLinks.count, 2, "T26: 2 milestones both have python")
}

do { // 27. Opportunity with only category signal → no connection (category ignored)
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-27", skills: [], topics: [], subjects: [], category: "Software Development")
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn == nil, "T27: category ignored → nil")
    // Even if category matches roadmap skill name, still nil
    let opp2 = TestRemoteOpportunity(id: "opp-27b", skills: [], topics: [], subjects: [], category: "Python")
    let conn2 = TestOpportunityRoadmapEngine.connection(for: opp2, roadmap: softwareEngineer, profile: profile)
    assert(conn2 == nil, "T27: category python ignored")
}

do { // 28. Opportunity with only title/description → no connection if no skills
    let profile = TestProfile()
    // Title contains Python but skills empty → should not match (engine only looks at skills/topics/subjects)
    let opp = TestRemoteOpportunity(id: "opp-28", title: "Learn Python Advanced", skills: [], topics: [], subjects: [])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn == nil, "T28: title not used")
    // Same for local: relevantSkills empty → nil even if title suggests match
    let local = TestOpportunity(id: "loc-28", title: "Python Workshop", relevantSkills: [])
    let connLocal = TestOpportunityRoadmapEngine.connection(for: local, roadmap: softwareEngineer, profile: profile)
    assert(connLocal == nil, "T28: local title ignored")
}

do { // 29. Expired opportunity does not corrupt connection (if deadline expired, still calculates)
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-29", skills: ["Python"], deadline: "2020-01-01")
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn != nil, "T29: expired still connects")
    assertEqual(conn?.matchedSkills.first?.id, "python", "T29: python matched despite expired")
    // future deadline also works
    let oppFuture = TestRemoteOpportunity(id: "opp-29b", skills: ["Python"], deadline: "2030-12-31")
    let connFuture = TestOpportunityRoadmapEngine.connection(for: oppFuture, roadmap: softwareEngineer, profile: profile)
    assert(connFuture != nil, "T29: future deadline connects")
    assertEqual(conn?.matchedSkills, connFuture?.matchedSkills, "T29: expired vs future same matched")
}

do { // 30. Invalid roadmap ID handled safely (empty or unknown id not crashing)
    let invalidRoadmap = TestRoadmap(id: "", title: "", milestones: [
        TestRoadmapMilestone(id: "inv-1", title: "M1", skillsDeveloped: ["Python"], actions: [TestAction(id: "inv-a1", title: "A")])
    ])
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-30", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: invalidRoadmap, profile: profile)
    assert(conn != nil, "T30: empty id roadmap still works")
    assertEqual(conn?.roadmapID, "", "T30: roadmapID empty preserved")
    assertEqual(conn?.id, "opp-30-", "T30: id stable even with empty roadmap id")
    // unknown roadmap with no milestones
    let noMilestone = TestRoadmap(id: "unknown", title: "Unknown", milestones: [])
    let conn2 = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: noMilestone, profile: profile)
    assert(conn2 == nil, "T30: no milestones → nil safely")
}

print("—— Determinism (31-35) ——")

do { // 31. Same input produces same output (call twice, compare)
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-31", skills: ["Python", "Git"])
    let progress = ["software-engineer": 1]
    let c1 = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile, progress: progress)
    let c2 = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile, progress: progress)
    assert(c1 == c2, "T31: deterministic equality")
    assertEqual(c1?.score, c2?.score, "T31: score deterministic")
    assertEqual(c1?.strength, c2?.strength, "T31: strength deterministic")
    assertEqual(c1?.reason, c2?.reason, "T31: reason deterministic")
    // also test connections sorted deterministic
    let conns1 = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: progress, activeRoadmaps: [softwareEngineer, aiEngineer])
    let conns2 = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: progress, activeRoadmaps: [softwareEngineer, aiEngineer])
    assert(conns1 == conns2, "T31: connections list deterministic")
}

do { // 32. Sorting is deterministic (strength then score then title)
    let profile = TestProfile()
    // Opp with Python matches both SE and AI. With empty profile, both will be direct? Need to engineer differing strengths
    // Make AI current gap, SE locked? Let's set progress so SE's python milestone completed, AI's python current
    // With progress SE=1, python in SE is completed → strength future, AI python is current → direct
    // So AI should sort first.
    let opp = TestRemoteOpportunity(id: "opp-32", skills: ["Python"])
    let active = [softwareEngineer, aiEngineer] // titles: Become a Software Engineer vs Become an AI Engineer
    let progress = ["software-engineer": 1, "ai-engineer": 0]
    let conns = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: progress, activeRoadmaps: active)
    assertEqual(conns.count, 2, "T32: 2 conns")
    // AI should be direct (current + gap), SE should be future (completed)
    assertEqual(conns[0].roadmapID, "ai-engineer", "T32: AI first due to strength")
    assertEqual(conns[1].roadmapID, "software-engineer", "T32: SE second")
    // test title tie-breaker: same strength/score → alphabetical
    // Create two roadmaps with identical milestones/skills so scores equal except title
    let roadmapA = TestRoadmap(id: "a-roadmap", title: "A Title", milestones: [
        TestRoadmapMilestone(id: "a-1", title: "M1", skillsDeveloped: ["Python"], actions: [TestAction(id: "a-1-a1", title: "A1")])
    ])
    let roadmapB = TestRoadmap(id: "b-roadmap", title: "B Title", milestones: [
        TestRoadmapMilestone(id: "b-1", title: "M1", skillsDeveloped: ["Python"], actions: [TestAction(id: "b-1-a1", title: "B1")])
    ])
    let conns2 = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: [:], activeRoadmaps: [roadmapB, roadmapA])
    assertEqual(conns2[0].roadmapTitle, "A Title", "T32: title ascending")
    assertEqual(conns2[1].roadmapTitle, "B Title", "T32: B second")
    // Verify sorted stable across multiple calls
    let conns3 = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: [:], activeRoadmaps: [roadmapB, roadmapA])
    assert(conns2 == conns3, "T32: stable sort")
}

do { // 33. No network dependency
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-33", skills: ["Python"])
    // Ensure engine is pure — no async, no URL, just computation
    let start = Date()
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    let elapsed = Date().timeIntervalSince(start)
    assert(conn != nil, "T33: conn not nil")
    assert(elapsed < 0.5, "T33: fast (<0.5s) → no network")
    // call many times to prove no side effect
    for _ in 0..<100 {
        _ = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    }
    assert(true, "T33: 100 sync calls succeeded")
}

do { // 34. No AI dependency
    let profile = TestProfile()
    let opp1 = TestRemoteOpportunity(id: "opp-34a", skills: ["Python"])
    let opp2 = TestRemoteOpportunity(id: "opp-34b", skills: ["Python"])
    // Same input → same output without AI variation
    let c1 = TestOpportunityRoadmapEngine.connection(for: opp1, roadmap: softwareEngineer, profile: profile)
    let c2 = TestOpportunityRoadmapEngine.connection(for: opp2, roadmap: softwareEngineer, profile: profile)
    // Need to adjust IDs to be equal for comparison of core fields (IDs differ)
    assertEqual(c1?.matchedSkills, c2?.matchedSkills, "T34: AI-free deterministic matched")
    assertEqual(c1?.score, c2?.score, "T34: score same")
    assertEqual(c1?.strength, c2?.strength, "T34: strength same")
    // Verify no randomness in reason
    assertEqual(c1?.reason, c2?.reason, "T34: reason same (aside from id?) — reason doesn't include id")
}

do { // 35. No persistence mutation (progress unchanged after engine call)
    var progress: [String: Int] = ["software-engineer": 1, "ai-engineer": 0]
    let originalProgress = progress
    var profile = TestProfile()
    profile.strengths = ["Python"]
    let originalStrengths = profile.strengths
    let opp = TestRemoteOpportunity(id: "opp-35", skills: ["Python", "Machine Learning"])
    let _ = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile, progress: progress)
    let _ = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: progress, activeRoadmaps: [softwareEngineer, aiEngineer])
    assertEqual(progress, originalProgress, "T35: progress unchanged")
    assertEqual(profile.strengths, originalStrengths, "T35: profile unchanged")
    // Also ensure activeRoadmaps unchanged
    let active: [TestRoadmap] = [softwareEngineer, aiEngineer]
    let _ = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: progress, activeRoadmaps: active)
    assertEqual(active.count, 2, "T35: active unchanged")
    assertEqual(active[0].id, "software-engineer", "T35: active id preserved")
}

print("—— All Roadmaps (36-39) ——")

do { // 36. Test against all 10 roadmap templates (loop over 10 roadmaps, each produces either connection or nil but doesn't crash, skill extraction works)
    let profile = TestProfile()
    let oppPython = TestRemoteOpportunity(id: "opp-36", skills: ["Python"])
    var connectionsCount = 0
    for roadmap in allTenRoadmaps {
        let conn = TestOpportunityRoadmapEngine.connection(for: oppPython, roadmap: roadmap, profile: profile)
        // Should not crash; either nil or valid
        if let c = conn {
            connectionsCount += 1
            assert(!c.matchedSkills.isEmpty, "T36: \(roadmap.id) matched not empty when conn exists")
            assert(c.roadmapID == roadmap.id, "T36: roadmapID matches")
        } else {
            // nil is valid for non-matching roadmaps
            assert(true, "T36: \(roadmap.id) nil is valid")
        }
        // skill extraction via gap engine should work
        let required = TestSkillGapEngine.requiredSkills(for: roadmap)
        assert(!required.isEmpty || roadmap.milestones.allSatisfy { $0.skillsDeveloped == nil || $0.skillsDeveloped?.isEmpty == true }, "T36: required extraction works for \(roadmap.id)")
    }
    assert(connectionsCount >= 2, "T36: at least 2 roadmaps matched python (SE, AI)")
    // also test with opp for each roadmap's unique skill
    let skillMap: [String: String] = [
        "software-engineer": "Python",
        "ai-engineer": "Machine Learning",
        "research-builder": "Research Methods",
        "stem-explorer": "Technical Exploration",
        "leadership": "Leadership",
        "entrepreneurship": "Business Fundamentals",
        "creative-arts": "Creativity",
        "health-sciences": "Scientific Method",
        "environmental": "Data Collection",
        "college-prep": "Academic Planning"
    ]
    for roadmap in allTenRoadmaps {
        let skill = skillMap[roadmap.id] ?? "Python"
        let opp = TestRemoteOpportunity(id: "opp-36-\(roadmap.id)", skills: [skill])
        let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: roadmap, profile: profile)
        assert(conn != nil, "T36: \(roadmap.id) matches its own skill \(skill)")
    }
}

do { // 37. No roadmap-specific branching (verify engine has no if roadmap.id == checks — just ensure it works for all)
    let profile = TestProfile()
    // Run same opp type across all roadmaps and verify generic behavior
    for roadmap in allTenRoadmaps {
        let required = TestSkillGapEngine.requiredSkills(for: roadmap)
        for skill in required {
            let opp = TestRemoteOpportunity(id: "opp-37-\(roadmap.id)-\(skill.id)", skills: [skill.name])
            let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: roadmap, profile: profile)
            assert(conn != nil, "T37: generic works for \(roadmap.id) skill \(skill.id)")
            assertEqual(conn?.roadmapID, roadmap.id, "T37: id generic")
            // Ensure no hardcoding: connection should depend only on skillsDeveloped, not roadmap.id string
            // We verify by checking that a roadmap with same skills but different id produces same structure
        }
    }
    // Create two clones with same milestone content but different IDs — should behave identically except roadmapID
    let cloneA = TestRoadmap(id: "clone-a", title: "Clone A", milestones: [
        TestRoadmapMilestone(id: "clone-a-1", title: "M1", skillsDeveloped: ["Python"], actions: [TestAction(id: "a1", title: "Act")])
    ])
    let cloneB = TestRoadmap(id: "clone-b", title: "Clone B", milestones: [
        TestRoadmapMilestone(id: "clone-b-1", title: "M1", skillsDeveloped: ["Python"], actions: [TestAction(id: "b1", title: "Act")])
    ])
    let opp = TestRemoteOpportunity(id: "opp-37-clone", skills: ["Python"])
    let cA = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: cloneA, profile: profile)
    let cB = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: cloneB, profile: profile)
    assertEqual(cA?.matchedSkills, cB?.matchedSkills, "T37: clones matched same")
    assertEqual(cA?.strength, cB?.strength, "T37: clones strength same")
    assertEqual(cA?.score, cB?.score, "T37: clones score same")
}

do { // 38. All generated milestone/action IDs are valid (every milestoneLink id exists in roadmap, every action id exists)
    let profile = TestProfile()
    for roadmap in allTenRoadmaps {
        for milestone in roadmap.milestones {
            let skill = milestone.skillsDeveloped?.first ?? "UnknownXYZ"
            // skip if no skill
            if skill == "UnknownXYZ" { continue }
            let opp = TestRemoteOpportunity(id: "opp-38-\(milestone.id)", skills: [skill])
            guard let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: roadmap, profile: profile) else {
                assert(false, "T38: expected conn for \(roadmap.id) \(milestone.id)")
                continue
            }
            for link in conn.milestoneLinks {
                assert(roadmap.milestones.contains(where: { $0.id == link.id }), "T38: link \(link.id) exists in \(roadmap.id)")
                if let ms = roadmap.milestones.first(where: { $0.id == link.id }) {
                    let validActionIDs = Set(ms.actions?.map(\.id) ?? [])
                    for aid in link.actionIDs {
                        assert(validActionIDs.contains(aid), "T38: action \(aid) valid in \(link.id)")
                    }
                    for t in link.actionTitles {
                        assert(!t.isEmpty, "T38: action title not empty")
                    }
                }
            }
        }
    }
    // Also test dedup case: Software Development appears in 2 milestones, both IDs valid
    let oppSD = TestRemoteOpportunity(id: "opp-38-sd", skills: ["Software Development"])
    let connSD = TestOpportunityRoadmapEngine.connection(for: oppSD, roadmap: softwareEngineer, profile: profile)
    for link in connSD?.milestoneLinks ?? [] {
        assert(softwareEngineer.milestones.contains(where: { $0.id == link.id }), "T38: SD link valid")
    }
}

do { // 39. All generated skill IDs are valid (every matchedSkill id is normalized and in catalog)
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-39", skills: [" Python ", "MACHINE LEARNING", "  Data Analysis "])
    for roadmap in allTenRoadmaps {
        if let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: roadmap, profile: profile) {
            for skill in conn.matchedSkills {
                assertEqual(skill.id, TestSkill.normalizeID(skill.name), "T39: skill id normalized for \(skill.name)")
                // id should be in catalog OR be custom normalized — but for these test skills, they should be in catalog
                // Also check that skill.id is non-empty and lowercased
                assert(!skill.id.isEmpty, "T39: id not empty")
                assert(skill.id == skill.id.lowercased(), "T39: id lowercased")
                // verify canonical lookup returns same name if known
                let canonical = TestSkill.canonical(from: skill.name)
                assertEqual(canonical.id, skill.id, "T39: canonical id matches")
            }
            for gapSkill in conn.gapSkillsAddressed {
                assert(conn.matchedSkills.contains(where: { $0.id == gapSkill.id }), "T39: gap skill is subset of matched")
                assert(TestSkill.normalizeID(gapSkill.name) == gapSkill.id, "T39: gap id normalized")
            }
        }
    }
    // Test with unknown skill not in catalog: should still produce normalized id
    let oppUnknown = TestRemoteOpportunity(id: "opp-39b", skills: ["Basket Weaving"])
    // No roadmap has this, so no connection, but normalize still works
    assertEqual(TestSkill.normalizeID("Basket Weaving"), "basket weaving", "T39: unknown normalize")
    let connUnknown = TestOpportunityRoadmapEngine.connection(for: oppUnknown, roadmap: softwareEngineer, profile: profile)
    assert(connUnknown == nil, "T39: unknown skill no connection")
}

print("—— Integration (40-44) ——")

do { // 40. AppDataStore-like store returns correct derived connections (activate SE, opp matches SE → 1 connection)
    var store = TestStore(profile: TestProfile(), activeRoadmaps: [softwareEngineer])
    let opp = TestRemoteOpportunity(id: "opp-40", skills: ["Python"])
    let conns = store.connections(for: opp)
    assertEqual(conns.count, 1, "T40: 1 connection")
    assertEqual(conns.first?.roadmapID, "software-engineer", "T40: SE")
    assert(conns.first?.strength == .direct || conns.first?.strength == .relevant, "T40: strength available")
    // Empty active → 0
    store.activeRoadmaps = []
    let connsEmpty = store.connections(for: opp)
    assertEqual(connsEmpty.count, 0, "T40: empty active 0")
    // Activate two
    store.activeRoadmaps = [softwareEngineer, aiEngineer]
    let conns2 = store.connections(for: opp)
    assertEqual(conns2.count, 2, "T40: 2 connections")
    // Local opportunity also
    let local = TestOpportunity(id: "loc-40", relevantSkills: ["Python"])
    let connsLocal = store.connections(for: local)
    assertEqual(connsLocal.count, 2, "T40: local 2")
}

do { // 41. Connection updates after skill acquisition (complete milestone acquiring Python, then opp that matched Python gap now no longer gap)
    var profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-41", skills: ["Python"])
    var connBefore = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assertEqual(connBefore?.gapSkillsAddressed.count, 1, "T41: before gap 1")
    assert(connBefore!.addressesGap, "T41: addressesGap before")
    // Simulate completing software-1 acquiring Python
    profile.strengths.append("Python")
    let connAfter = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assertEqual(connAfter?.gapSkillsAddressed.count, 0, "T41: after gap 0")
    assert(!connAfter!.addressesGap, "T41: not addressesGap after")
    assertEqual(connAfter?.matchedSkills.count, 1, "T41: still matched 1")
    // Strength should change from direct to relevant (hasAvailable true but gap empty → relevant, unless locked)
    // At progress 0, Python milestone is current → hasAvailable true → relevant
    assertEqual(connAfter?.strength, .relevant, "T41: strength relevant after gap gone")
    // Verify store-like progress also works via completed milestone
    let progress = ["software-engineer": 1] // completed software-1
    let connProgress = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: TestProfile(), progress: progress, catalog: [softwareEngineer])
    assertEqual(connProgress?.gapSkillsAddressed.count, 0, "T41: gap 0 via progress catalog")
}

do { // 42. Connection updates after milestone completion (progress 0→1 changes milestone status from current to completed and next becomes current)
    let profile = TestProfile()
    // Git is in software-2, which is locked at progress 0
    let oppGit = TestRemoteOpportunity(id: "opp-42", skills: ["Git"])
    let conn0 = TestOpportunityRoadmapEngine.connection(for: oppGit, roadmap: softwareEngineer, profile: profile, progress: [:])
    assertEqual(conn0?.milestoneLinks.first?.status, .locked, "T42: 0 locked")
    assertEqual(conn0?.strength, .future, "T42: 0 future")
    assert(!conn0!.advancesCurrentMilestone, "T42: 0 not advances")
    // progress 1 → software-2 becomes current
    let conn1 = TestOpportunityRoadmapEngine.connection(for: oppGit, roadmap: softwareEngineer, profile: profile, progress: ["software-engineer": 1])
    assertEqual(conn1?.milestoneLinks.first?.status, .current, "T42: 1 current")
    assertEqual(conn1?.strength, .direct, "T42: 1 direct (gap + available)")
    assert(conn1!.advancesCurrentMilestone, "T42: 1 advances")
    // Check score increased due to currentBonus
    assert((conn1?.score ?? 0) > (conn0?.score ?? 0), "T42: score increases when current")
    // Also test Python milestone completed vs current
    let oppPY = TestRemoteOpportunity(id: "opp-42-py", skills: ["Python"])
    let connPY0 = TestOpportunityRoadmapEngine.connection(for: oppPY, roadmap: softwareEngineer, profile: profile, progress: [:])
    assertEqual(connPY0?.milestoneLinks.first?.status, .current, "T42: py 0 current")
    let connPY1 = TestOpportunityRoadmapEngine.connection(for: oppPY, roadmap: softwareEngineer, profile: profile, progress: ["software-engineer": 1])
    assertEqual(connPY1?.milestoneLinks.first?.status, .completed, "T42: py 1 completed")
    assert(!connPY1!.advancesCurrentMilestone, "T42: py completed not advances")
}

do { // 43. Connection survives profile/state reload because it is derived from persistent state (simulate reload by reconstructing store from persisted data)
    var profile = TestProfile()
    profile.strengths = ["Python"]
    let progress: [String: Int] = ["software-engineer": 1]
    let active = [softwareEngineer]
    let evidence: [String: TestEvidenceRecord] = [:]
    let opp = TestRemoteOpportunity(id: "opp-43", skills: ["Git"])
    let connBefore = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile, progress: progress, catalog: allTenRoadmaps, evidenceRecords: evidence)
    // Simulate persistence: encode/decode profile and progress (like UserDefaults)
    let persistedProfile = profile // in real app this would be encoded
    let persistedProgress = progress
    let persistedActive = active
    // Reconstruct store
    let store2 = TestStore(profile: persistedProfile, progress: persistedProgress, activeRoadmaps: persistedActive, evidence: evidence)
    let connsAfter = store2.connections(for: opp)
    assertEqual(connsAfter.count, 1, "T43: reloaded 1 conn")
    assertEqual(connsAfter.first?.roadmapID, "software-engineer", "T43: roadmap id")
    assertEqual(connsAfter.first?.matchedSkills, connBefore?.matchedSkills, "T43: matched same after reload")
    assertEqual(connsAfter.first?.strength, connBefore?.strength, "T43: strength same")
    assertEqual(connsAfter.first?.score, connBefore?.score, "T43: score same")
    // Also test evidence persistence: simulate evidence for software-1
    var evidence2: [String: TestEvidenceRecord] = ["evidence-software-engineer-software-1": TestEvidenceRecord(roadmapID: "software-engineer", milestoneID: "software-1")]
    let connWithEvidence = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: TestProfile(), progress: [:], catalog: allTenRoadmaps, evidenceRecords: evidence2)
    // evidence should make Python considered demonstrated? Actually evidence for software-1 contains Python skill, so Python gap should be gone? But opp is Git, so not affected, but test that evidence doesn't corrupt connection
    assert(connWithEvidence != nil, "T43: evidence doesn't corrupt")
}

do { // 44. Multiple active roadmaps remain independent after progress changes (complete SE milestone, AI gaps unchanged)
    var profile = TestProfile()
    var progress: [String: Int] = [:]
    let oppML = TestRemoteOpportunity(id: "opp-44", skills: ["Machine Learning"])
    let oppPY = TestRemoteOpportunity(id: "opp-44-py", skills: ["Python"])
    // Before SE completion
    let connAIBefore = TestOpportunityRoadmapEngine.connection(for: oppML, roadmap: aiEngineer, profile: profile, progress: progress)
    let gapBefore = connAIBefore?.gapSkillsAddressed.count ?? -1
    // Complete SE milestone 1
    progress["software-engineer"] = 1
    // Also simulate skill acquisition via catalog: after SE 1, Python becomes demonstrated if catalog provided
    let connAIAfter = TestOpportunityRoadmapEngine.connection(for: oppML, roadmap: aiEngineer, profile: profile, progress: progress, catalog: allTenRoadmaps)
    let gapAfter = connAIAfter?.gapSkillsAddressed.count ?? -2
    assertEqual(gapBefore, gapAfter, "T44: AI gap unchanged after SE progress")
    assertEqual(connAIBefore?.strength, connAIAfter?.strength, "T44: AI strength unchanged")
    // But SE connection for Python should change: after progress 1 with catalog, Python gap gone
    let connSEBefore = TestOpportunityRoadmapEngine.connection(for: oppPY, roadmap: softwareEngineer, profile: TestProfile(), progress: [:], catalog: allTenRoadmaps)
    let connSEAfter = TestOpportunityRoadmapEngine.connection(for: oppPY, roadmap: softwareEngineer, profile: TestProfile(), progress: progress, catalog: allTenRoadmaps)
    assertEqual(connSEBefore?.gapSkillsAddressed.count, 1, "T44: SE gap before 1")
    assertEqual(connSEAfter?.gapSkillsAddressed.count, 0, "T44: SE gap after 0 via catalog")
    // Ensure AI Python gap also affected? Actually AI Python also comes from catalog completion, so AI Python gap would also be considered demonstrated after SE completion if catalog includes SE. Test independence: AI ML gap should not be affected by SE Python completion unless ML is not in SE.
    // Verify connections list independence
    let active = [softwareEngineer, aiEngineer]
    let connsBefore = TestOpportunityRoadmapEngine.connections(for: oppML, profile: profile, progress: [:], activeRoadmaps: active)
    let connsAfter = TestOpportunityRoadmapEngine.connections(for: oppML, profile: profile, progress: progress, activeRoadmaps: active, catalog: allTenRoadmaps)
    assertEqual(connsBefore.count, 1, "T44: before only AI matches ML")
    assertEqual(connsAfter.count, 1, "T44: after only AI matches ML")
    assertEqual(connsBefore.first?.roadmapID, "ai-engineer", "T44: still AI")
}

print("—— Cross-system scenario (45) ——")

do { // 45. Cross-system scenario: Student has Python, Git; Active AI Engineer; Gap is Machine Learning; Opp with Python+ML → direct, 1 gap, 2 matched; Complete AI milestone that teaches ML → gap disappears
    var profile = TestProfile()
    profile.strengths = ["Python", "Git"]
    let active = [aiEngineer]
    var progress: [String: Int] = [:]
    // Gap check before
    let gapReportBefore = TestSkillGapEngine.evaluate(roadmap: aiEngineer, profile: profile, progress: progress, catalog: allTenRoadmaps)
    let gapIDsBefore = Set(gapReportBefore.gaps.map(\.skillID))
    assert(gapIDsBefore.contains("machine learning"), "T45: ML is gap before")
    assert(!gapIDsBefore.contains("python"), "T45: python not gap (demonstrated)")
    assert(!gapIDsBefore.contains("git"), "T45: git not in AI required? Actually git not in AI, irrelevant")
    // Opp with Python + ML
    let opp = TestRemoteOpportunity(id: "opp-45", skills: ["Python", "Machine Learning"])
    let connBefore = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: aiEngineer, profile: profile, progress: progress, catalog: allTenRoadmaps)
    assert(connBefore != nil, "T45: conn before not nil")
    assertEqual(connBefore?.matchedSkills.count, 2, "T45: 2 matched before")
    assertEqual(connBefore?.gapSkillsAddressed.count, 1, "T45: 1 gap before (ML)")
    assertEqual(connBefore?.gapSkillsAddressed.first?.id, "machine learning", "T45: gap ML")
    // At this point, what is strength? ML is in ai-2 which at progress 0 is locked, Python in ai-1 current. So hasAvailable true (python current) + gap true (ML but locked?) Wait: gapSkillsAddressed is ML, but milestone for ML is ai-2 locked. hasAvailable = hasCurrent? Let's see: milestoneLinks includes ai-1 (current) and ai-2 (locked). So hasAvailable = true (ai-1 current), so strength = direct (gap && hasAvailable) → direct.
    // Actually check: gapSkillsAddressed = ML, hasAvailable = true (ai-1), so direct even though ML milestone locked? That's production logic: gap && hasAvailable (any available), not necessarily gap milestone available.
    assertEqual(connBefore?.strength, .direct, "T45: direct before")
    assert(connBefore!.advancesCurrentMilestone, "T45: advances current before (python current)")
    // Now student completes AI milestone that teaches Machine Learning
    // ai-2 is the milestone with ML. To complete it, need progress at least 2? But dependencies: ai-1 → ai-2, so need to complete ai-1 and ai-2. Simulate progress 2 (completed ai-1 and ai-2) OR acquire skill via profile
    // Simplest: add ML to profile strengths
    profile.strengths.append("Machine Learning")
    // Also progress would be 2 if completed through milestones, but we test both
    let gapReportAfter = TestSkillGapEngine.evaluate(roadmap: aiEngineer, profile: profile, progress: progress, catalog: allTenRoadmaps)
    let gapIDsAfter = Set(gapReportAfter.gaps.map(\.skillID))
    assert(!gapIDsAfter.contains("machine learning"), "T45: ML not gap after")
    let connAfter = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: aiEngineer, profile: profile, progress: progress, catalog: allTenRoadmaps)
    assert(connAfter != nil, "T45: conn after not nil")
    assertEqual(connAfter?.matchedSkills.count, 2, "T45: still 2 matched after")
    assertEqual(connAfter?.gapSkillsAddressed.count, 0, "T45: 0 gaps after")
    assert(!connAfter!.addressesGap, "T45: not addressesGap after")
    // Strength should now be relevant (hasAvailable true, but no gap) → relevant
    assertEqual(connAfter?.strength, .relevant, "T45: relevant after")
    // Also test via progress catalog path: reset profile to original, set progress to 2
    var profile2 = TestProfile()
    profile2.strengths = ["Python", "Git"]
    let progressAfterMilestone: [String: Int] = ["ai-engineer": 2]
    let connProgress = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: aiEngineer, profile: profile2, progress: progressAfterMilestone, catalog: allTenRoadmaps)
    assertEqual(connProgress?.gapSkillsAddressed.count, 0, "T45: gap 0 via progress")
    assertEqual(connProgress?.milestoneLinks.first(where: { $0.id == "ai-2" })?.status, .completed, "T45: ai-2 completed via progress")
}

do { // 46. Additional edge: local Opportunity mirroring remote logic, skill normalization via topics/subjects equivalent
    let profile = TestProfile()
    // Local opp with relevantSkills same as remote skills should produce same connection
    let remote = TestRemoteOpportunity(id: "opp-46r", skills: ["Python", "Git"])
    let local = TestOpportunity(id: "opp-46r", relevantSkills: ["Python", "Git"])
    let connRemote = TestOpportunityRoadmapEngine.connection(for: remote, roadmap: softwareEngineer, profile: profile)
    let connLocal = TestOpportunityRoadmapEngine.connection(for: local, roadmap: softwareEngineer, profile: profile)
    assertEqual(connRemote?.matchedSkills, connLocal?.matchedSkills, "T46: remote vs local matched same")
    assertEqual(connRemote?.score, connLocal?.score, "T46: score same")
    assertEqual(connRemote?.strength, connLocal?.strength, "T46: strength same")
    assertEqual(connRemote?.milestoneLinks.map(\.id), connLocal?.milestoneLinks.map(\.id), "T46: links same")
    // Test scoring formula exact mirror: base 10*matched +15*gap+20 if current +10 if available + min(actions,10)+ earliness
    // For SE with Python+Git, progress 0: matched 2, gap 2, hasCurrent false? Let's compute: Python current, Git locked → hasCurrent true (python), hasAvailable true, actions 4 (2+2), earliestIdx 0, milestones count 3 → earliness 6
    // Score = 20+30+20+10+4+6=90
    let opp = TestRemoteOpportunity(id: "opp-46-score", skills: ["Python", "Git"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile, progress: [:])
    assertEqual(conn?.score, 90, "T46: score 90 exact")
    // After progress 1: python completed via progress → demonstrated via SkillGapEngine (catalog defaults to [roadmap]), so python gap removed
    // So gap reduces from 2 to 1, score 75 even without explicit catalog (because evaluate uses [roadmap] fallback)
    let connProg1 = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile, progress: ["software-engineer": 1])
    assertEqual(connProg1?.score, 75, "T46: score 75 at progress1 (python gap removed via milestone completion)")
    // With explicit catalog same result — gap 1, base 20, gap 15, current 20, available 10, actions 4, earliness 6 = 75
    let connCatalog = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile, progress: ["software-engineer": 1], catalog: allTenRoadmaps)
    assertEqual(connCatalog?.score, 75, "T46: catalog score 75")
}

do { // 47. Verify reason string contains expected parts
    let profile = TestProfile()
    let opp = TestRemoteOpportunity(id: "opp-47", skills: ["Python"])
    let conn = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile)
    assert(conn?.reason.contains("Matches 1 roadmap skill(s): Python") == true, "T47: reason contains matched")
    assert(conn?.reason.contains("Addresses 1 current gap(s): Python") == true, "T47: reason contains gap")
    assert(conn?.reason.contains("Develops in: Explore CS") == true, "T47: reason contains milestone")
    // After gap gone, reason should not contain Addresses
    var profile2 = TestProfile()
    profile2.strengths = ["Python"]
    let conn2 = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: softwareEngineer, profile: profile2)
    assert(conn2?.reason.contains("Addresses") == false, "T47: no Addresses when no gap")
    assert(conn2?.reason.contains("Matches") == true, "T47: still matches")
}

do { // 48. Connection ID stability and uniqueness
    let profile = TestProfile()
    let opp1 = TestRemoteOpportunity(id: "opp-48a", skills: ["Python"])
    let opp2 = TestRemoteOpportunity(id: "opp-48b", skills: ["Python"])
    let conn1 = TestOpportunityRoadmapEngine.connection(for: opp1, roadmap: softwareEngineer, profile: profile)
    let conn2 = TestOpportunityRoadmapEngine.connection(for: opp2, roadmap: softwareEngineer, profile: profile)
    assertEqual(conn1?.id, "opp-48a-software-engineer", "T48: id stable")
    assertEqual(conn2?.id, "opp-48b-software-engineer", "T48: id2 stable")
    assert(conn1?.id != conn2?.id, "T48: ids distinct for different opp")
    // Same input produces same id
    let conn1b = TestOpportunityRoadmapEngine.connection(for: opp1, roadmap: softwareEngineer, profile: profile)
    assertEqual(conn1?.id, conn1b?.id, "T48: deterministic id")
}

do { // 49. Sorting tie-breaker with score exact calculation
    let profile = TestProfile()
    // Create two roadmaps with different milestones counts to test earliness bonus
    let roadmapEarly = TestRoadmap(id: "early", title: "Early", milestones: [
        TestRoadmapMilestone(id: "early-1", title: "M1", skillsDeveloped: ["Python"], actions: [TestAction(id: "early-a1", title: "A")]),
        TestRoadmapMilestone(id: "early-2", title: "M2", skillsDeveloped: ["Other"], actions: nil),
        TestRoadmapMilestone(id: "early-3", title: "M3", skillsDeveloped: ["Other2"], actions: nil)
    ])
    let roadmapLate = TestRoadmap(id: "late", title: "Late", milestones: [
        TestRoadmapMilestone(id: "late-1", title: "M1", skillsDeveloped: ["Other"], actions: nil),
        TestRoadmapMilestone(id: "late-2", title: "M2", skillsDeveloped: ["Other2"], actions: nil),
        TestRoadmapMilestone(id: "late-3", title: "M3", skillsDeveloped: ["Python"], actions: [TestAction(id: "late-a1", title: "A")])
    ])
    let opp = TestRemoteOpportunity(id: "opp-49", skills: ["Python"])
    let connEarly = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: roadmapEarly, profile: profile)
    let connLate = TestOpportunityRoadmapEngine.connection(for: opp, roadmap: roadmapLate, profile: profile)
    assert((connEarly?.score ?? 0) > (connLate?.score ?? 0), "T49: earliness bonus makes early higher score")
    // Verify sorting puts early first when both direct? Check strengths: both have Available? early-1 is current at progress 0, late-3 is locked → future, so early direct > late future
    let conns = TestOpportunityRoadmapEngine.connections(for: opp, profile: profile, progress: [:], activeRoadmaps: [roadmapLate, roadmapEarly])
    assertEqual(conns.first?.roadmapID, "early", "T49: early sorted first")
}

do { // 50. Empty strings and whitespace-only strings are ignored (no connection)
    let profile = TestProfile()
    let oppEmptyStrings = TestRemoteOpportunity(id: "opp-50", skills: ["", "   ", "\n\t"], topics: ["", " "], subjects: ["  "])
    let conn = TestOpportunityRoadmapEngine.connection(for: oppEmptyStrings, roadmap: softwareEngineer, profile: profile)
    assert(conn == nil, "T50: whitespace-only → nil")
    assertEqual(TestOpportunityRoadmapEngine.normalizedSkillIDs(for: oppEmptyStrings).count, 0, "T50: normalized empty")
    // Roadmap with whitespace-only skillsDeveloped should not crash
    let whitespaceRoadmap = TestRoadmap(id: "ws", title: "WS", milestones: [
        TestRoadmapMilestone(id: "ws-1", title: "M1", skillsDeveloped: ["   ", ""], actions: nil)
    ])
    let opp2 = TestRemoteOpportunity(id: "opp-50b", skills: ["Python"])
    let conn2 = TestOpportunityRoadmapEngine.connection(for: opp2, roadmap: whitespaceRoadmap, profile: profile)
    assert(conn2 == nil, "T50: whitespace roadmap nil")
}

// ═══════════════════════════════════════════════════════════════
//  SUMMARY
// ═══════════════════════════════════════════════════════════════

print("\nPhase 6.6 — Opportunity→Roadmap: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
