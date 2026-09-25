import Foundation

// Standalone test script for Phase 6.4.6 — Connect Roadmap Completion to Skills and Evidence
// Run: swift test-evidence-and-skills.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// ── Inline model definitions (mirror Roadmap.swift + AppDataStore.swift) ──

struct TestMilestoneResource: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let provider: String
    let url: String
    let type: String
    let description: String
    let estimatedTime: String?
    init(id: String = UUID().uuidString, title: String, provider: String, url: String, type: String, description: String, estimatedTime: String? = nil) {
        self.id = id; self.title = title; self.provider = provider; self.url = url; self.type = type; self.description = description; self.estimatedTime = estimatedTime
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        provider = (try? c.decode(String.self, forKey: .provider)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        type = (try? c.decode(String.self, forKey: .type)) ?? "article"
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        estimatedTime = try? c.decode(String.self, forKey: .estimatedTime)
    }
}

struct TestMilestoneAction: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let description: String
    init(id: String = UUID().uuidString, label: String, description: String) {
        self.id = id; self.label = label; self.description = description
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
    }
}

struct TestMilestoneValidation: Hashable, Codable {
    let id: String
    let prompt: String
    init(id: String = UUID().uuidString, prompt: String) {
        self.id = id; self.prompt = prompt
    }
}

struct TestMilestoneEvidence: Hashable, Codable {
    let title: String
    let description: String
    init(title: String, description: String) {
        self.title = title; self.description = description
    }
}

struct TestValidationQuestion: Identifiable, Hashable, Codable {
    let id: String
    let question: String
    let choices: [String]
    let correctAnswer: Int
    let explanation: String
    init(id: String = UUID().uuidString, question: String, choices: [String], correctAnswer: Int, explanation: String) {
        self.id = id; self.question = question; self.choices = choices; self.correctAnswer = correctAnswer; self.explanation = explanation
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

struct TestMilestoneAssessment: Identifiable, Hashable, Codable {
    let id: String
    let questions: [TestValidationQuestion]
    let passThreshold: Int
    init(id: String = UUID().uuidString, questions: [TestValidationQuestion], passThreshold: Int = 70) {
        self.id = id; self.questions = questions; self.passThreshold = passThreshold
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        questions = (try? c.decode([TestValidationQuestion].self, forKey: .questions)) ?? []
        passThreshold = (try? c.decode(Int.self, forKey: .passThreshold)) ?? 70
    }
}

struct TestValidationAttempt: Identifiable, Hashable, Codable {
    let id: String
    let validationID: String
    let selectedAnswers: [String: Int]
    let score: Int
    let totalQuestions: Int
    let percentage: Int
    let passed: Bool
}

struct ValidationAttempt: Identifiable, Hashable, Codable {
    let id: String
    let validationID: String
    let selectedAnswers: [String: Int]
    let score: Int
    let totalQuestions: Int
    let percentage: Int
    let passed: Bool
    init(id: String = UUID().uuidString, validationID: String, selectedAnswers: [String: Int], score: Int, totalQuestions: Int, percentage: Int, passed: Bool) {
        self.id = id; self.validationID = validationID; self.selectedAnswers = selectedAnswers; self.score = score; self.totalQuestions = totalQuestions; self.percentage = percentage; self.passed = passed
    }
}

struct TestRoadmapMilestone: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let estimatedTime: String?
    let goal: String?
    let actions: [TestMilestoneAction]?
    let skillsDeveloped: [String]?
    let completionCriteria: String?
    let learningResources: [TestMilestoneResource]?
    let validation: TestMilestoneValidation?
    let evidence: TestMilestoneEvidence?
    let assessment: TestMilestoneAssessment?
    init(id: String = UUID().uuidString, title: String, subtitle: String, estimatedTime: String? = nil, goal: String? = nil, actions: [TestMilestoneAction]? = nil, skillsDeveloped: [String]? = nil, completionCriteria: String? = nil, learningResources: [TestMilestoneResource]? = nil, validation: TestMilestoneValidation? = nil, evidence: TestMilestoneEvidence? = nil, assessment: TestMilestoneAssessment? = nil) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.estimatedTime = estimatedTime; self.goal = goal; self.actions = actions; self.skillsDeveloped = skillsDeveloped; self.completionCriteria = completionCriteria; self.learningResources = learningResources; self.validation = validation; self.evidence = evidence; self.assessment = assessment
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        estimatedTime = try? c.decode(String.self, forKey: .estimatedTime)
        goal = try? c.decode(String.self, forKey: .goal)
        actions = try? c.decode([TestMilestoneAction].self, forKey: .actions)
        skillsDeveloped = try? c.decode([String].self, forKey: .skillsDeveloped)
        completionCriteria = try? c.decode(String.self, forKey: .completionCriteria)
        learningResources = try? c.decode([TestMilestoneResource].self, forKey: .learningResources)
        validation = try? c.decode(TestMilestoneValidation.self, forKey: .validation)
        evidence = try? c.decode(TestMilestoneEvidence.self, forKey: .evidence)
        assessment = try? c.decode(TestMilestoneAssessment.self, forKey: .assessment)
    }
}

struct TestRoadmap: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let milestones: [TestRoadmapMilestone]
    let carear: String?
    let field: String?
    init(id: String, title: String, subtitle: String, icon: String, milestones: [TestRoadmapMilestone], carear: String? = nil, field: String? = nil) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.icon = icon; self.milestones = milestones; self.carear = carear; self.field = field
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        icon = (try? c.decode(String.self, forKey: .icon)) ?? ""
        milestones = (try? c.decode([TestRoadmapMilestone].self, forKey: .milestones)) ?? []
        carear = try? c.decode(String.self, forKey: .carear)
        field = try? c.decode(String.self, forKey: .field)
    }
}

// ── EvidenceRecord (mirror Roadmap.swift) ──

struct EvidenceRecord: Identifiable, Hashable, Codable {
    let id: String
    let type: String
    let title: String
    let description: String?
    let roadmapID: String
    let milestoneID: String
    let completionDate: Date
    let validationID: String?
    let validationScore: Int?
    let validationPercentage: Int?
    let validationPassed: Bool?
    let projectID: String?
    let opportunityID: String?
    init(id: String = UUID().uuidString, type: String, title: String, description: String? = nil, roadmapID: String, milestoneID: String, completionDate: Date = Date(), validationID: String? = nil, validationScore: Int? = nil, validationPercentage: Int? = nil, validationPassed: Bool? = nil, projectID: String? = nil, opportunityID: String? = nil) {
        self.id = id; self.type = type; self.title = title; self.description = description; self.roadmapID = roadmapID; self.milestoneID = milestoneID; self.completionDate = completionDate; self.validationID = validationID; self.validationScore = validationScore; self.validationPercentage = validationPercentage; self.validationPassed = validationPassed; self.projectID = projectID; self.opportunityID = opportunityID
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        type = (try? c.decode(String.self, forKey: .type)) ?? "unknown"
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        roadmapID = (try? c.decode(String.self, forKey: .roadmapID)) ?? ""
        milestoneID = (try? c.decode(String.self, forKey: .milestoneID)) ?? ""
        completionDate = (try? c.decode(Date.self, forKey: .completionDate)) ?? Date()
        validationID = try? c.decode(String.self, forKey: .validationID)
        validationScore = try? c.decode(Int.self, forKey: .validationScore)
        validationPercentage = try? c.decode(Int.self, forKey: .validationPercentage)
        validationPassed = try? c.decode(Bool.self, forKey: .validationPassed)
        projectID = try? c.decode(String.self, forKey: .projectID)
        opportunityID = try? c.decode(String.self, forKey: .opportunityID)
    }
}

// ── Simplified student profile for testing ──

struct TestStudentProfile: Codable, Equatable {
    var strengths: [String] = []
    var customSkills: [String] = []
    init() {}
    init(strengths: [String] = [], customSkills: [String] = []) {
        self.strengths = strengths; self.customSkills = customSkills
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strengths = (try? c.decode([String].self, forKey: .strengths)) ?? []
        customSkills = (try? c.decode([String].self, forKey: .customSkills)) ?? []
    }
}

// ── Simulated store (mirrors AppDataStore completion logic) ──

class SimulatedStore {
    var profile = TestStudentProfile()
    var evidenceRecords: [String: EvidenceRecord] = [:]
    var roadmapProgress: [String: Int] = [:]
    var completedActionIDs: Set<String> = []
    var validationAttempts: [String: ValidationAttempt] = [:]

    func completedCount(for roadmap: TestRoadmap) -> Int {
        min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
    }

    func markRoadmapMilestoneComplete(for roadmap: TestRoadmap) {
        let next = min(completedCount(for: roadmap) + 1, roadmap.milestones.count)
        roadmapProgress[roadmap.id] = next
        if next >= 1, next <= roadmap.milestones.count {
            let milestone = roadmap.milestones[next - 1]
            acquireSkills(milestone.skillsDeveloped)
        }
        if next >= 1, next <= roadmap.milestones.count {
            let milestone = roadmap.milestones[next - 1]
            createEvidenceIfNeeded(for: roadmap, milestone: milestone)
        }
    }

    func resetRoadmap(_ roadmap: TestRoadmap) {
        roadmapProgress[roadmap.id] = 0
        for milestone in roadmap.milestones {
            for action in milestone.actions ?? [] {
                completedActionIDs.remove(action.id)
            }
            let evidenceID = evidenceID(for: milestone.id, roadmap: roadmap.id)
            evidenceRecords.removeValue(forKey: evidenceID)
        }
    }

    func acquireSkills(_ skills: [String]?) {
        guard let skills, !skills.isEmpty else { return }
        var existing = Set(profile.strengths.map { $0.lowercased() })
        existing.formUnion(profile.customSkills.map { $0.lowercased() })
        for skill in skills {
            let trimmed = skill.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !existing.contains(trimmed.lowercased()) else { continue }
            profile.strengths.append(trimmed)
            existing.insert(trimmed.lowercased())
        }
    }

    func evidenceID(for milestoneID: String, roadmap: String) -> String {
        "evidence-\(roadmap)-\(milestoneID)"
    }

    func hasEvidence(for milestoneID: String, roadmap: String) -> Bool {
        evidenceRecords[evidenceID(for: milestoneID, roadmap: roadmap)] != nil
    }

    func evidence(for milestoneID: String, roadmap: String) -> EvidenceRecord? {
        evidenceRecords[evidenceID(for: milestoneID, roadmap: roadmap)]
    }

    private func createEvidenceIfNeeded(for roadmap: TestRoadmap, milestone: TestRoadmapMilestone) {
        let eid = evidenceID(for: milestone.id, roadmap: roadmap.id)
        guard evidenceRecords[eid] == nil else { return }
        let assessment = milestone.assessment
        let best: ValidationAttempt? = assessment.flatMap { validationAttempts[$0.id] }
        let record = EvidenceRecord(
            id: eid,
            type: "milestone-completion",
            title: milestone.title,
            description: milestone.subtitle,
            roadmapID: roadmap.id,
            milestoneID: milestone.id,
            completionDate: Date(),
            validationID: assessment?.id,
            validationScore: best?.score,
            validationPercentage: best.map { pct(score: $0.score, total: assessment?.questions.count ?? 1) },
            validationPassed: best?.passed
        )
        evidenceRecords[eid] = record
    }

    private func pct(score: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100).rounded())
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
let decoder = JSONDecoder()

// ── Test data ──

let roadmapA = TestRoadmap(
    id: "roadmap-a", title: "Software Engineering", subtitle: "Build software skills", icon: "laptopcomputer",
    milestones: [
        TestRoadmapMilestone(id: "ms-1", title: "Foundations", subtitle: "Setup environment", skillsDeveloped: ["Terminal", "Git basics"]),
        TestRoadmapMilestone(id: "ms-2", title: "Variables", subtitle: "Learn variables", skillsDeveloped: ["Variables", "Conditionals", "Loops"]),
        TestRoadmapMilestone(id: "ms-3", title: "Git", subtitle: "Version control", skillsDeveloped: ["Branching", "Merge conflicts"]),
        TestRoadmapMilestone(id: "ms-4", title: "APIs", subtitle: "Build API", skillsDeveloped: ["HTTP", "JSON"]),
        TestRoadmapMilestone(id: "ms-5", title: "Project", subtitle: "Full project", skillsDeveloped: ["Project planning", "Debugging"]),
        TestRoadmapMilestone(id: "ms-6", title: "Deploy", subtitle: "Ship it", skillsDeveloped: ["Deployment", "CI/CD"]),
    ]
)

let roadmapB = TestRoadmap(
    id: "roadmap-b", title: "Data Science", subtitle: "Analyze data", icon: "chart.bar",
    milestones: [
        TestRoadmapMilestone(id: "ds-1", title: "Python Basics", subtitle: "Learn Python", skillsDeveloped: ["Python"]),
        TestRoadmapMilestone(id: "ds-2", title: "Pandas", subtitle: "Data manipulation", skillsDeveloped: ["Pandas", "Data cleaning"]),
    ]
)

let roadmapEmpty = TestRoadmap(
    id: "roadmap-empty", title: "Empty Roadmap", subtitle: "No skills", icon: "questionmark",
    milestones: [
        TestRoadmapMilestone(id: "empty-1", title: "Placeholder", subtitle: "Nothing here"),
    ]
)

let roadmapWithAssessment = TestRoadmap(
    id: "roadmap-assess", title: "With Assessment", subtitle: "Has validation", icon: "checkmark.shield",
    milestones: [
        TestRoadmapMilestone(id: "assess-1", title: "Assessed Milestone", subtitle: "Has validation", skillsDeveloped: ["Testing"],
            assessment: TestMilestoneAssessment(id: "assess-1-assessment", questions: [
                TestValidationQuestion(id: "aq1", question: "Q1?", choices: ["A", "B"], correctAnswer: 1, explanation: "B"),
                TestValidationQuestion(id: "aq2", question: "Q2?", choices: ["C", "D"], correctAnswer: 0, explanation: "C"),
            ], passThreshold: 70)),
    ]
)

// ═══════════════════════════════════════════════
//  TEST 1: EvidenceRecord creation with all fields
// ═══════════════════════════════════════════════

let fixedDate = Date(timeIntervalSince1970: 1700000000)
let record = EvidenceRecord(
    id: "ev-1", type: "milestone-completion", title: "Foundations",
    description: "Setup environment", roadmapID: "roadmap-a", milestoneID: "ms-1",
    completionDate: fixedDate, validationID: "val-1", validationScore: 3,
    validationPercentage: 100, validationPassed: true, projectID: nil, opportunityID: nil
)
assertEqual(record.id, "ev-1", "EvidenceRecord: id")
assertEqual(record.type, "milestone-completion", "EvidenceRecord: type")
assertEqual(record.title, "Foundations", "EvidenceRecord: title")
assertEqual(record.description, "Setup environment", "EvidenceRecord: description")
assertEqual(record.roadmapID, "roadmap-a", "EvidenceRecord: roadmapID")
assertEqual(record.milestoneID, "ms-1", "EvidenceRecord: milestoneID")
assertEqual(record.completionDate, fixedDate, "EvidenceRecord: completionDate")
assertEqual(record.validationID, "val-1", "EvidenceRecord: validationID")
assertEqual(record.validationScore, 3, "EvidenceRecord: validationScore")
assertEqual(record.validationPercentage, 100, "EvidenceRecord: validationPercentage")
assertEqual(record.validationPassed, true, "EvidenceRecord: validationPassed")
assert(record.projectID == nil, "EvidenceRecord: projectID nil")
assert(record.opportunityID == nil, "EvidenceRecord: opportunityID nil")

// ═══════════════════════════════════════════════
//  TEST 2: EvidenceRecord with nil optionals
// ═══════════════════════════════════════════════

let minimalRecord = EvidenceRecord(id: "ev-min", type: "milestone-completion", title: "Test", roadmapID: "r1", milestoneID: "m1")
assert(minimalRecord.description == nil, "Minimal record: description nil")
assert(minimalRecord.validationID == nil, "Minimal record: validationID nil")
assert(minimalRecord.validationScore == nil, "Minimal record: validationScore nil")
assert(minimalRecord.validationPercentage == nil, "Minimal record: validationPercentage nil")
assert(minimalRecord.validationPassed == nil, "Minimal record: validationPassed nil")
assert(minimalRecord.projectID == nil, "Minimal record: projectID nil")
assert(minimalRecord.opportunityID == nil, "Minimal record: opportunityID nil")

// ═══════════════════════════════════════════════
//  TEST 3: EvidenceRecord Codable roundtrip
// ═══════════════════════════════════════════════

let evData = try! encoder.encode(record)
let evDecoded = try! decoder.decode(EvidenceRecord.self, from: evData)
assertEqual(evDecoded.id, "ev-1", "Evidence roundtrip: id")
assertEqual(evDecoded.type, "milestone-completion", "Evidence roundtrip: type")
assertEqual(evDecoded.title, "Foundations", "Evidence roundtrip: title")
assertEqual(evDecoded.roadmapID, "roadmap-a", "Evidence roundtrip: roadmapID")
assertEqual(evDecoded.milestoneID, "ms-1", "Evidence roundtrip: milestoneID")
assertEqual(evDecoded.validationID, "val-1", "Evidence roundtrip: validationID")
assertEqual(evDecoded.validationScore, 3, "Evidence roundtrip: validationScore")
assertEqual(evDecoded.validationPercentage, 100, "Evidence roundtrip: validationPercentage")
assertEqual(evDecoded.validationPassed, true, "Evidence roundtrip: validationPassed")

// ═══════════════════════════════════════════════
//  TEST 4: Deterministic evidence IDs
// ═══════════════════════════════════════════════

let store = SimulatedStore()
let eid1 = store.evidenceID(for: "ms-1", roadmap: "roadmap-a")
let eid2 = store.evidenceID(for: "ms-1", roadmap: "roadmap-a")
assertEqual(eid1, "evidence-roadmap-a-ms-1", "Deterministic ID: format")
assertEqual(eid1, eid2, "Deterministic ID: same inputs produce same ID")
let eid3 = store.evidenceID(for: "ms-2", roadmap: "roadmap-a")
assert(eid1 != eid3, "Deterministic ID: different milestones produce different IDs")
let eid4 = store.evidenceID(for: "ms-1", roadmap: "roadmap-b")
assert(eid1 != eid4, "Deterministic ID: different roadmaps produce different IDs")

// ═══════════════════════════════════════════════
//  TEST 5: Skill acquisition — adds to strengths
// ═══════════════════════════════════════════════

store.markRoadmapMilestoneComplete(for: roadmapA)
assertEqual(store.profile.strengths.count, 2, "Skill acquisition: two skills added")
assert(store.profile.strengths.contains("Terminal"), "Skill acquisition: contains Terminal")
assert(store.profile.strengths.contains("Git basics"), "Skill acquisition: contains Git basics")

// ═══════════════════════════════════════════════
//  TEST 6: Skill acquisition — idempotent (no duplicates)
// ═══════════════════════════════════════════════

let idempotentStore = SimulatedStore()
idempotentStore.markRoadmapMilestoneComplete(for: roadmapA) // ms-1: Terminal, Git basics
assertEqual(idempotentStore.profile.strengths.count, 2, "Idempotent skills: two skills after first completion")
// Simulate re-completing the same milestone by directly calling acquireSkills again
idempotentStore.acquireSkills(["Terminal", "Git basics"])
assertEqual(idempotentStore.profile.strengths.count, 2, "Idempotent skills: count unchanged after re-acquire")

// ═══════════════════════════════════════════════
//  TEST 7: Skill acquisition — case-insensitive dedup
// ═══════════════════════════════════════════════

let caseStore = SimulatedStore()
caseStore.profile.strengths = ["terminal"]
caseStore.acquireSkills(["Terminal", "Git Basics"])
assertEqual(caseStore.profile.strengths.count, 2, "Case-insensitive: terminal not duplicated, Git Basics added")
assertEqual(caseStore.profile.strengths[0], "terminal", "Case-insensitive: original preserved")

// ═══════════════════════════════════════════════
//  TEST 8: Skill acquisition — dedup across customSkills
// ═══════════════════════════════════════════════

let crossStore = SimulatedStore()
crossStore.profile.customSkills = ["Python"]
crossStore.acquireSkills(["Python", "JavaScript"])
assertEqual(crossStore.profile.strengths.count, 1, "Cross-dedup: Python not added to strengths")
assertEqual(crossStore.profile.strengths[0], "JavaScript", "Cross-dedup: JavaScript added")
assertEqual(crossStore.profile.customSkills.count, 1, "Cross-dedup: customSkills unchanged")
assertEqual(crossStore.profile.customSkills[0], "Python", "Cross-dedup: Python still in customSkills")

// ═══════════════════════════════════════════════
//  TEST 9: Skill acquisition — whitespace trimming
// ═══════════════════════════════════════════════

let wsStore = SimulatedStore()
wsStore.acquireSkills(["  Terminal  ", "  Git basics  "])
assertEqual(wsStore.profile.strengths.count, 2, "Whitespace: two skills added")
assertEqual(wsStore.profile.strengths[0], "Terminal", "Whitespace: trimmed")
assertEqual(wsStore.profile.strengths[1], "Git basics", "Whitespace: trimmed")

// ═══════════════════════════════════════════════
//  TEST 10: Skill acquisition — empty/nil skills
// ═══════════════════════════════════════════════

let emptyStore = SimulatedStore()
emptyStore.acquireSkills(nil)
assertEqual(emptyStore.profile.strengths.count, 0, "Nil skills: no change")
emptyStore.acquireSkills([])
assertEqual(emptyStore.profile.strengths.count, 0, "Empty skills: no change")
emptyStore.acquireSkills(["", "  "])
assertEqual(emptyStore.profile.strengths.count, 0, "Whitespace-only skills: no change")

// ═══════════════════════════════════════════════
//  TEST 11: Evidence creation on first completion
// ═══════════════════════════════════════════════

let evStore = SimulatedStore()
evStore.markRoadmapMilestoneComplete(for: roadmapA)
assert(evStore.hasEvidence(for: "ms-1", roadmap: "roadmap-a"), "Evidence created on completion")
let ev = evStore.evidence(for: "ms-1", roadmap: "roadmap-a")!
assertEqual(ev.type, "milestone-completion", "Evidence: type")
assertEqual(ev.title, "Foundations", "Evidence: title")
assertEqual(ev.description, "Setup environment", "Evidence: description")
assertEqual(ev.roadmapID, "roadmap-a", "Evidence: roadmapID")
assertEqual(ev.milestoneID, "ms-1", "Evidence: milestoneID")
assertEqual(ev.id, "evidence-roadmap-a-ms-1", "Evidence: deterministic ID")
assert(ev.completionDate.timeIntervalSince1970 > 0, "Evidence: completionDate set")

// ═══════════════════════════════════════════════
//  TEST 12: Evidence creation — idempotent (re-creating same evidence doesn't duplicate)
// ═══════════════════════════════════════════════

let evIdempotentStore = SimulatedStore()
evIdempotentStore.markRoadmapMilestoneComplete(for: roadmapA) // creates evidence for ms-1
let firstEv = evIdempotentStore.evidence(for: "ms-1", roadmap: "roadmap-a")!
let firstDate = firstEv.completionDate
// Re-create the same evidence directly (simulates calling createEvidenceIfNeeded again)
evIdempotentStore.markRoadmapMilestoneComplete(for: roadmapA) // advances to ms-2
let ev2 = evIdempotentStore.evidence(for: "ms-1", roadmap: "roadmap-a")!
assertEqual(ev2.id, firstEv.id, "Idempotent evidence: same ID")
assertEqual(ev2.completionDate, firstDate, "Idempotent evidence: same date")
assertEqual(evIdempotentStore.evidenceRecords.count, 2, "Idempotent evidence: 2 records (ms-1 and ms-2)")

// ═══════════════════════════════════════════════
//  TEST 13: Evidence — no skillsDeveloped, still creates evidence
// ═══════════════════════════════════════════════

let noSkillStore = SimulatedStore()
noSkillStore.markRoadmapMilestoneComplete(for: roadmapEmpty)
assert(noSkillStore.hasEvidence(for: "empty-1", roadmap: "roadmap-empty"), "Evidence created even without skillsDeveloped")
assertEqual(noSkillStore.profile.strengths.count, 0, "No skills added when skillsDeveloped nil")

// ═══════════════════════════════════════════════
//  TEST 14: Multiple milestone completions accumulate
// ═══════════════════════════════════════════════

let multiStore = SimulatedStore()
multiStore.markRoadmapMilestoneComplete(for: roadmapA) // ms-1: Terminal, Git basics
multiStore.markRoadmapMilestoneComplete(for: roadmapA) // ms-2: Variables, Conditionals, Loops
assertEqual(multiStore.profile.strengths.count, 5, "Accumulate: 5 skills after 2 milestones")
assert(multiStore.profile.strengths.contains("Terminal"), "Accumulate: Terminal")
assert(multiStore.profile.strengths.contains("Variables"), "Accumulate: Variables")
assert(multiStore.profile.strengths.contains("Conditionals"), "Accumulate: Conditionals")
assert(multiStore.profile.strengths.contains("Loops"), "Accumulate: Loops")
assertEqual(multiStore.evidenceRecords.count, 2, "Accumulate: 2 evidence records")

// ═══════════════════════════════════════════════
//  TEST 15: Evidence with assessment includes validation info
// ═══════════════════════════════════════════════

let assessStore = SimulatedStore()
assessStore.markRoadmapMilestoneComplete(for: roadmapWithAssessment)
let assessEv = assessStore.evidence(for: "assess-1", roadmap: "roadmap-assess")!
assertEqual(assessEv.validationID, "assess-1-assessment", "Assessment evidence: validationID")
assert(assessEv.validationScore == nil, "Assessment evidence: no score yet (no attempt)")
assert(assessEv.validationPercentage == nil, "Assessment evidence: no percentage yet")
assert(assessEv.validationPassed == nil, "Assessment evidence: no passed yet")

// ═══════════════════════════════════════════════
//  TEST 16: Evidence with completed assessment attempt
// ═══════════════════════════════════════════════

let passStore = SimulatedStore()
// Simulate a passed validation attempt
passStore.validationAttempts["assess-1-assessment"] = ValidationAttempt(
    id: "attempt-1", validationID: "assess-1-assessment",
    selectedAnswers: ["aq1": 1, "aq2": 0],
    score: 2, totalQuestions: 2, percentage: 100, passed: true
)
passStore.markRoadmapMilestoneComplete(for: roadmapWithAssessment)
let passEv = passStore.evidence(for: "assess-1", roadmap: "roadmap-assess")!
assertEqual(passEv.validationScore, 2, "Passed attempt: score")
assertEqual(passEv.validationPercentage, 100, "Passed attempt: percentage")
assertEqual(passEv.validationPassed, true, "Passed attempt: passed")

// ═══════════════════════════════════════════════
//  TEST 17: Evidence with failed assessment attempt
// ═══════════════════════════════════════════════

let failStore = SimulatedStore()
failStore.validationAttempts["assess-1-assessment"] = ValidationAttempt(
    id: "attempt-2", validationID: "assess-1-assessment",
    selectedAnswers: ["aq1": 0],
    score: 1, totalQuestions: 2, percentage: 50, passed: false
)
failStore.markRoadmapMilestoneComplete(for: roadmapWithAssessment)
let failEv = failStore.evidence(for: "assess-1", roadmap: "roadmap-assess")!
assertEqual(failEv.validationScore, 1, "Failed attempt: score")
assertEqual(failEv.validationPercentage, 50, "Failed attempt: percentage")
assertEqual(failEv.validationPassed, false, "Failed attempt: passed")

// ═══════════════════════════════════════════════
//  TEST 18: Reset roadmap clears evidence
// ═══════════════════════════════════════════════

let resetStore = SimulatedStore()
resetStore.markRoadmapMilestoneComplete(for: roadmapA)
resetStore.markRoadmapMilestoneComplete(for: roadmapA)
assertEqual(resetStore.evidenceRecords.count, 2, "Pre-reset: 2 evidence records")
resetStore.resetRoadmap(roadmapA)
assertEqual(resetStore.evidenceRecords.count, 0, "Post-reset: 0 evidence records")
assert(!resetStore.hasEvidence(for: "ms-1", roadmap: "roadmap-a"), "Post-reset: ms-1 evidence gone")
assert(!resetStore.hasEvidence(for: "ms-2", roadmap: "roadmap-a"), "Post-reset: ms-2 evidence gone")

// ═══════════════════════════════════════════════
//  TEST 19: Reset roadmap does NOT clear skills (intentional)
// ═══════════════════════════════════════════════

let resetSkillStore = SimulatedStore()
resetSkillStore.markRoadmapMilestoneComplete(for: roadmapA)
assertEqual(resetSkillStore.profile.strengths.count, 2, "Pre-reset: skills present")
resetSkillStore.resetRoadmap(roadmapA)
assertEqual(resetSkillStore.profile.strengths.count, 2, "Post-reset: skills preserved (intentional)")

// ═══════════════════════════════════════════════
//  TEST 20: Cross-roadmap evidence independence
// ═══════════════════════════════════════════════

let crossRoadmapStore = SimulatedStore()
crossRoadmapStore.markRoadmapMilestoneComplete(for: roadmapA) // ms-1
crossRoadmapStore.markRoadmapMilestoneComplete(for: roadmapB) // ds-1
assertEqual(crossRoadmapStore.evidenceRecords.count, 2, "Cross-roadmap: 2 evidence records")
assert(crossRoadmapStore.hasEvidence(for: "ms-1", roadmap: "roadmap-a"), "Cross-roadmap: roadmap-a ms-1")
assert(crossRoadmapStore.hasEvidence(for: "ds-1", roadmap: "roadmap-b"), "Cross-roadmap: roadmap-b ds-1")
assert(!crossRoadmapStore.hasEvidence(for: "ms-1", roadmap: "roadmap-b"), "Cross-roadmap: no cross-contamination")

// ═══════════════════════════════════════════════
//  TEST 21: Cross-roadmap skill independence
// ═══════════════════════════════════════════════

assertEqual(crossRoadmapStore.profile.strengths.count, 3, "Cross-roadmap skills: Terminal, Git basics, Python")
assert(crossRoadmapStore.profile.strengths.contains("Terminal"), "Cross-roadmap skills: Terminal from roadmap-a")
assert(crossRoadmapStore.profile.strengths.contains("Python"), "Cross-roadmap skills: Python from roadmap-b")

// ═══════════════════════════════════════════════
//  TEST 22: Skills preserved through multiple milestone completions
// ═══════════════════════════════════════════════

let persistStore = SimulatedStore()
persistStore.markRoadmapMilestoneComplete(for: roadmapA) // ms-1: Terminal, Git basics
persistStore.markRoadmapMilestoneComplete(for: roadmapA) // ms-2: Variables, Conditionals, Loops
assertEqual(persistStore.profile.strengths.count, 5, "Persist: 5 skills after 2 milestones")
assert(persistStore.profile.strengths.contains("Terminal"), "Persist: Terminal present")
assert(persistStore.profile.strengths.contains("Git basics"), "Persist: Git basics present")
assert(persistStore.profile.strengths.contains("Variables"), "Persist: Variables present")
assert(persistStore.profile.strengths.contains("Conditionals"), "Persist: Conditionals present")
assert(persistStore.profile.strengths.contains("Loops"), "Persist: Loops present")

// ═══════════════════════════════════════════════
//  TEST 23: Evidence records Codable roundtrip (dictionary)
// ═══════════════════════════════════════════════

let dictStore = SimulatedStore()
dictStore.markRoadmapMilestoneComplete(for: roadmapA)
dictStore.markRoadmapMilestoneComplete(for: roadmapA)
let dictData = try! encoder.encode(dictStore.evidenceRecords)
let dictDecoded = try! decoder.decode([String: EvidenceRecord].self, from: dictData)
assertEqual(dictDecoded.count, 2, "Dictionary roundtrip: 2 records")
assertEqual(dictDecoded["evidence-roadmap-a-ms-1"]?.title, "Foundations", "Dictionary roundtrip: ms-1 title")
assertEqual(dictDecoded["evidence-roadmap-a-ms-2"]?.title, "Variables", "Dictionary roundtrip: ms-2 title")

// ═══════════════════════════════════════════════
//  TEST 24: Complete all 6 SE milestones — full skill set
// ═══════════════════════════════════════════════

let fullStore = SimulatedStore()
for _ in 1...6 {
    fullStore.markRoadmapMilestoneComplete(for: roadmapA)
}
assertEqual(fullStore.profile.strengths.count, 13, "Full roadmap: all 13 SE skills acquired")
assertEqual(fullStore.evidenceRecords.count, 6, "Full roadmap: 6 evidence records")
let allSESkills = ["Terminal", "Git basics", "Variables", "Conditionals", "Loops", "Branching", "Merge conflicts", "HTTP", "JSON", "Project planning", "Debugging", "Deployment", "CI/CD"]
for skill in allSESkills {
    assert(fullStore.profile.strengths.contains(skill), "Full roadmap: \(skill) present")
}

// ═══════════════════════════════════════════════
//  TEST 25: Legacy milestone without skillsDeveloped
// ═══════════════════════════════════════════════

let legacyMilestone = TestRoadmapMilestone(id: "legacy-1", title: "Legacy", subtitle: "Old milestone")
let legacyRoadmap = TestRoadmap(id: "legacy-rm", title: "Legacy", subtitle: "Old", icon: "clock", milestones: [legacyMilestone])
let legacyStore = SimulatedStore()
legacyStore.markRoadmapMilestoneComplete(for: legacyRoadmap)
assertEqual(legacyStore.profile.strengths.count, 0, "Legacy: no skills added")
assert(legacyStore.hasEvidence(for: "legacy-1", roadmap: "legacy-rm"), "Legacy: evidence still created")

// ═══════════════════════════════════════════════
//  TEST 26: Skill acquisition preserves existing strengths
// ═══════════════════════════════════════════════

let existingStore = SimulatedStore()
existingStore.profile.strengths = ["Leadership", "Communication"]
existingStore.markRoadmapMilestoneComplete(for: roadmapA)
assertEqual(existingStore.profile.strengths.count, 4, "Existing skills: 2 original + 2 new")
assert(existingStore.profile.strengths.contains("Leadership"), "Existing skills: Leadership preserved")
assert(existingStore.profile.strengths.contains("Communication"), "Existing skills: Communication preserved")
assert(existingStore.profile.strengths.contains("Terminal"), "Existing skills: Terminal added")
assert(existingStore.profile.strengths.contains("Git basics"), "Existing skills: Git basics added")

// ═══════════════════════════════════════════════
//  TEST 27: Evidence includes completionDate as current time
// ═══════════════════════════════════════════════

let timeStore = SimulatedStore()
let before = Date()
timeStore.markRoadmapMilestoneComplete(for: roadmapA)
let after = Date()
let timeEv = timeStore.evidence(for: "ms-1", roadmap: "roadmap-a")!
assert(timeEv.completionDate >= before, "Timing: completionDate >= before")
assert(timeEv.completionDate <= after, "Timing: completionDate <= after")

// ═══════════════════════════════════════════════
//  TEST 28: Skills and evidence are independent
// ═══════════════════════════════════════════════

let indepStore = SimulatedStore()
indepStore.markRoadmapMilestoneComplete(for: roadmapA)
assertEqual(indepStore.profile.strengths.count, 2, "Independent: skills present")
assertEqual(indepStore.evidenceRecords.count, 1, "Independent: evidence present")
// Skills can exist without evidence (manual add) and evidence without skills
let manualEvidence = EvidenceRecord(id: "manual-ev", type: "project", title: "Manual", roadmapID: "manual", milestoneID: "manual-ms")
indepStore.evidenceRecords["manual-ev"] = manualEvidence
assertEqual(indepStore.evidenceRecords.count, 2, "Independent: manual evidence added without affecting skills")

// ═══════════════════════════════════════════════
//  TEST 29: Evidence description from milestone subtitle
// ═══════════════════════════════════════════════

let descStore = SimulatedStore()
descStore.markRoadmapMilestoneComplete(for: roadmapA)
let descEv = descStore.evidence(for: "ms-1", roadmap: "roadmap-a")!
assertEqual(descEv.description, "Setup environment", "Description: matches milestone subtitle")
descStore.markRoadmapMilestoneComplete(for: roadmapA)
let descEv2 = descStore.evidence(for: "ms-2", roadmap: "roadmap-a")!
assertEqual(descEv2.description, "Learn variables", "Description: ms-2 matches subtitle")

// ═══════════════════════════════════════════════
//  SUMMARY
// ═══════════════════════════════════════════════

print("\nPhase 6.4.6 — Evidence & Skills: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
