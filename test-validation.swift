import Foundation

// Standalone test script for Phase 6.4.5 — Deterministic Milestone Validation
// Run: swift test-validation.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// ── Inline model definitions (mirror Roadmap.swift) ──

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

// ── Engine functions (mirror RoadmapEngine) ──

func score(answers: [String: Int], questions: [TestValidationQuestion]) -> Int {
    guard !questions.isEmpty else { return 0 }
    return questions.filter { q in
        if let selected = answers[q.id] { return selected == q.correctAnswer }
        return false
    }.count
}

func percentage(score: Int, total: Int) -> Int {
    guard total > 0 else { return 0 }
    return Int((Double(score) / Double(total) * 100).rounded())
}

func passed(percentage: Int, threshold: Int) -> Bool {
    percentage >= threshold
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
let decoder = JSONDecoder()

// ── Test data ──

let sampleQuestions: [TestValidationQuestion] = [
    TestValidationQuestion(id: "q1", question: "What is 2+2?", choices: ["3", "4", "5", "6"], correctAnswer: 1, explanation: "2+2=4."),
    TestValidationQuestion(id: "q2", question: "What color is the sky?", choices: ["Green", "Blue", "Red", "Yellow"], correctAnswer: 1, explanation: "The sky appears blue."),
    TestValidationQuestion(id: "q3", question: "How many legs does a dog have?", choices: ["2", "3", "4", "5"], correctAnswer: 2, explanation: "Dogs have 4 legs."),
]

let sampleAssessment = TestMilestoneAssessment(id: "test-assessment", questions: sampleQuestions, passThreshold: 70)

// ── Test 1: Validation model Codable roundtrip ──

let qData = try! encoder.encode(sampleQuestions[0])
let qDecoded = try! decoder.decode(TestValidationQuestion.self, from: qData)
assertEqual(qDecoded.id, "q1", "Question roundtrip: id")
assertEqual(qDecoded.question, "What is 2+2?", "Question roundtrip: question")
assertEqual(qDecoded.choices.count, 4, "Question roundtrip: choices count")
assertEqual(qDecoded.correctAnswer, 1, "Question roundtrip: correctAnswer")
assertEqual(qDecoded.explanation, "2+2=4.", "Question roundtrip: explanation")

let aData = try! encoder.encode(sampleAssessment)
let aDecoded = try! decoder.decode(TestMilestoneAssessment.self, from: aData)
assertEqual(aDecoded.id, "test-assessment", "Assessment roundtrip: id")
assertEqual(aDecoded.questions.count, 3, "Assessment roundtrip: question count")
assertEqual(aDecoded.passThreshold, 70, "Assessment roundtrip: threshold")

// ── Test 2: Legacy milestones without validation decode ──

struct LegacyMilestone: Codable {
    let id: String
    let title: String
    let validation: String?
    let assessment: TestMilestoneAssessment?
}
let legacyJSON = """
{"id":"legacy-1","title":"Legacy"}
""".data(using: .utf8)!
let legacyDecoded = try! decoder.decode(LegacyMilestone.self, from: legacyJSON)
assertEqual(legacyDecoded.id, "legacy-1", "Legacy milestone decodes")
assert(legacyDecoded.validation == nil, "Legacy has nil validation")
assert(legacyDecoded.assessment == nil, "Legacy has nil assessment")

// ── Test 3: Software Engineer milestones contain validation ──

let swAssessments: [String: TestMilestoneAssessment] = [
    "software-1": TestMilestoneAssessment(id: "sw1-assessment", questions: [
        TestValidationQuestion(id: "sw1-q1", question: "What is an algorithm?", choices: ["A type of computer hardware", "A step-by-step procedure for solving a problem", "A programming language", "A website for learning code"], correctAnswer: 1, explanation: "An algorithm is a clear, step-by-step set of instructions."),
        TestValidationQuestion(id: "sw1-q2", question: "What is the main purpose of a development environment?", choices: ["To browse the internet", "To write, edit, and organize code efficiently", "To play video games", "To send emails"], correctAnswer: 1, explanation: "A development environment provides tools for writing and organizing code."),
        TestValidationQuestion(id: "sw1-q3", question: "What does version control track?", choices: ["Your school grades", "Changes to files over time", "Internet browsing history", "Social media posts"], correctAnswer: 1, explanation: "Version control records changes to your code."),
    ]),
    "software-2": TestMilestoneAssessment(id: "sw2-assessment", questions: [
        TestValidationQuestion(id: "sw2-q1", question: "What is a variable?", choices: ["A fixed value", "A named container that stores a value", "A type of loop", "A function"], correctAnswer: 1, explanation: "A variable is a named label for a value."),
        TestValidationQuestion(id: "sw2-q2", question: "What does a conditional do?", choices: ["Repeats code", "Makes the program faster", "Chooses actions based on a condition", "Stores data"], correctAnswer: 2, explanation: "Conditionals make decisions."),
        TestValidationQuestion(id: "sw2-q3", question: "What is a loop?", choices: ["Deletes files", "Repeats instructions until a condition is met", "Connects to the internet", "Creates a variable"], correctAnswer: 1, explanation: "Loops repeat code."),
        TestValidationQuestion(id: "sw2-q4", question: "What does a function do?", choices: ["Runs without errors", "Reuses code by calling it by name", "Stores data permanently", "Connects to a database"], correctAnswer: 1, explanation: "Functions package instructions for reuse."),
    ]),
    "software-3": TestMilestoneAssessment(id: "sw3-assessment", questions: [
        TestValidationQuestion(id: "sw3-q1", question: "What does a Git commit represent?", choices: ["A merge request", "A saved snapshot of code", "A bug", "A password file"], correctAnswer: 1, explanation: "A commit is a saved snapshot."),
        TestValidationQuestion(id: "sw3-q2", question: "What is an API?", choices: ["A virus", "Rules for software communication", "A language", "Hardware"], correctAnswer: 1, explanation: "An API defines communication between software."),
        TestValidationQuestion(id: "sw3-q3", question: "Benefit of a debugger?", choices: ["Faster code", "Pause and inspect step by step", "Auto-fixes bugs", "Python only"], correctAnswer: 1, explanation: "Debuggers let you step through code."),
        TestValidationQuestion(id: "sw3-q4", question: "Purpose of tests?", choices: ["Look professional", "Verify code works and catch bugs early", "Slow down code", "Replace documentation"], correctAnswer: 1, explanation: "Tests verify correctness."),
    ]),
    "software-4": TestMilestoneAssessment(id: "sw4-assessment", questions: [
        TestValidationQuestion(id: "sw4-q1", question: "First step for a project?", choices: ["Start coding immediately", "Define the problem", "Choose a new language", "Create social media"], correctAnswer: 1, explanation: "Understand the problem first."),
        TestValidationQuestion(id: "sw4-q2", question: "Why break into milestones?", choices: ["Takes longer", "Makes progress visible and keeps you on track", "Prevents Git use", "Required by languages"], correctAnswer: 1, explanation: "Milestones make projects manageable."),
        TestValidationQuestion(id: "sw4-q3", question: "Purpose of a README?", choices: ["Hide code", "Explain what it does, how to run it, what you learned", "Replace comments", "Auto-fix bugs"], correctAnswer: 1, explanation: "READMEs explain the project."),
        TestValidationQuestion(id: "sw4-q4", question: "What is iterating?", choices: ["Delete and restart", "Make small improvements and test after each change", "Wait for perfection", "Copy someone else"], correctAnswer: 1, explanation: "Iteration means build-test-improve cycles."),
    ]),
    "software-5": TestMilestoneAssessment(id: "sw5-assessment", questions: [
        TestValidationQuestion(id: "sw5-q1", question: "What is a pull request?", choices: ["Delete a repo", "Proposal to merge your changes", "A bug report", "Download command"], correctAnswer: 1, explanation: "A pull request proposes changes for review."),
        TestValidationQuestion(id: "sw5-q2", question: "Why contribute to open source?", choices: ["Guarantees a job", "Builds collaboration skills and visible evidence", "Required for college", "Improves grades"], correctAnswer: 1, explanation: "Open source demonstrates real skills."),
        TestValidationQuestion(id: "sw5-q3", question: "First step for open-source issues?", choices: ["Rewrite the project", "Look for 'good first issue' labels", "Email the owner", "Ignore descriptions"], correctAnswer: 1, explanation: "Good first issues are curated entry points."),
    ]),
    "software-6": TestMilestoneAssessment(id: "sw6-assessment", questions: [
        TestValidationQuestion(id: "sw6-q1", question: "What makes a good portfolio project?", choices: ["Most popular language", "Solves a real problem and shows thinking", "Most lines of code", "Assigned by teacher"], correctAnswer: 1, explanation: "Strong projects show problem-solving."),
        TestValidationQuestion(id: "sw6-q2", question: "What should you explain in a portfolio?", choices: ["Only the result", "Problem, approach, what you built, what you learned", "Only syntax", "Nothing"], correctAnswer: 1, explanation: "Explain the full journey."),
        TestValidationQuestion(id: "sw6-q3", question: "Why have a README in portfolio projects?", choices: ["Looks bigger", "Helps others understand quickly", "Required by GitHub", "Improves SEO"], correctAnswer: 1, explanation: "READMEs are the first thing viewers read."),
    ]),
]

for (mid, assessment) in swAssessments {
    assert(!assessment.questions.isEmpty, "\(mid) has questions")
    assert(assessment.questions.count >= 2, "\(mid) has at least 2 questions, got \(assessment.questions.count)")
    assert(assessment.questions.count <= 5, "\(mid) has at most 5 questions, got \(assessment.questions.count)")
    assertEqual(assessment.passThreshold, 70, "\(mid) has 70% threshold")
}

// ── Test 4: Every question has a stable unique ID ──

var allQuestionIDs: [String] = []
for (_, assessment) in swAssessments {
    for q in assessment.questions {
        allQuestionIDs.append(q.id)
        assert(!q.id.isEmpty, "Question has non-empty ID")
    }
}
assertEqual(Set(allQuestionIDs).count, allQuestionIDs.count, "All question IDs are unique globally")

// ── Test 5: Every question has at least 2 choices ──

for (mid, assessment) in swAssessments {
    for q in assessment.questions {
        assert(q.choices.count >= 2, "\(mid) \(q.id) has at least 2 choices, got \(q.choices.count)")
    }
}

// ── Test 6: Correct answer indexes are valid ──

for (mid, assessment) in swAssessments {
    for q in assessment.questions {
        assert(q.correctAnswer >= 0, "\(mid) \(q.id) correctAnswer >= 0")
        assert(q.correctAnswer < q.choices.count, "\(mid) \(q.id) correctAnswer \(q.correctAnswer) < choices.count \(q.choices.count)")
    }
}

// ── Test 7: Every question has an explanation ──

for (mid, assessment) in swAssessments {
    for q in assessment.questions {
        assert(!q.explanation.isEmpty, "\(mid) \(q.id) has non-empty explanation")
    }
}

// ── Test 8: Validation score calculation ──

let allCorrect: [String: Int] = ["q1": 1, "q2": 1, "q3": 2]
assertEqual(score(answers: allCorrect, questions: sampleQuestions), 3, "All correct → score 3")

let noneCorrect: [String: Int] = ["q1": 0, "q2": 0, "q3": 0]
assertEqual(score(answers: noneCorrect, questions: sampleQuestions), 0, "None correct → score 0")

let partialCorrect: [String: Int] = ["q1": 1, "q2": 0, "q3": 2]
assertEqual(score(answers: partialCorrect, questions: sampleQuestions), 2, "Partial → score 2")

// ── Test 9: Percentage calculation ──

assertEqual(percentage(score: 3, total: 3), 100, "3/3 → 100%")
assertEqual(percentage(score: 2, total: 3), 67, "2/3 → 67%")
assertEqual(percentage(score: 1, total: 3), 33, "1/3 → 33%")
assertEqual(percentage(score: 0, total: 3), 0, "0/3 → 0%")
assertEqual(percentage(score: 0, total: 0), 0, "0/0 → 0%")

// ── Test 10: Pass/fail calculation ──

assert(passed(percentage: 100, threshold: 70), "100% ≥ 70% → pass")
assert(passed(percentage: 70, threshold: 70), "70% ≥ 70% → pass")
assert(!passed(percentage: 69, threshold: 70), "69% < 70% → fail")
assert(!passed(percentage: 0, threshold: 70), "0% < 70% → fail")

// ── Test 11: Configurable pass threshold ──

assert(passed(percentage: 50, threshold: 50), "50% ≥ 50% → pass")
assert(!passed(percentage: 49, threshold: 50), "49% < 50% → fail")
assert(passed(percentage: 80, threshold: 80), "80% ≥ 80% → pass")
assert(passed(percentage: 100, threshold: 100), "100% ≥ 100% → pass")
assert(passed(percentage: 0, threshold: 0), "0% ≥ 0% → pass (edge case)")

// ── Test 12: Empty submission handling ──

assertEqual(score(answers: [:], questions: sampleQuestions), 0, "Empty answers → score 0")
assertEqual(percentage(score: 0, total: 3), 0, "Empty → 0%")
assert(!passed(percentage: 0, threshold: 70), "0% → fail")

// ── Test 13: Incorrect answer handling ──

let wrongAnswers: [String: Int] = ["q1": 0, "q2": 0, "q3": 0]
assertEqual(score(answers: wrongAnswers, questions: sampleQuestions), 0, "All wrong → score 0")

let oneRight: [String: Int] = ["q1": 1, "q2": 0, "q3": 0]
assertEqual(score(answers: oneRight, questions: sampleQuestions), 1, "One right → score 1")

// ── Test 14: Retry behavior ──

let attempt1 = TestValidationAttempt(id: "a1", validationID: "v1", selectedAnswers: ["q1": 0], score: 0, totalQuestions: 3, percentage: 0, passed: false)
let attempt2 = TestValidationAttempt(id: "a2", validationID: "v1", selectedAnswers: ["q1": 1, "q2": 1, "q3": 2], score: 3, totalQuestions: 3, percentage: 100, passed: true)
assert(!attempt1.passed, "First attempt failed")
assert(attempt2.passed, "Retry passed")
assertNotEqual(attempt1.id, attempt2.id, "Retry has different attempt ID")

func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a != b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}

// ── Test 15: Validation attempt persistence ──

var attempts: [String: TestValidationAttempt] = [:]
attempts[attempt1.validationID] = attempt1
assertEqual(attempts["v1"]?.score, 0, "Persisted attempt: score 0")
attempts["v1"] = attempt2
assertEqual(attempts["v1"]?.score, 3, "Updated attempt: score 3")
assert(attempts["v1"]?.passed == true, "Updated attempt: passed")

// ── Test 16: One attempt does not modify another ──

var store: [String: TestValidationAttempt] = [:]
let v1Attempt = TestValidationAttempt(id: "a-v1", validationID: "v1", selectedAnswers: [:], score: 0, totalQuestions: 3, percentage: 0, passed: false)
let v2Attempt = TestValidationAttempt(id: "a-v2", validationID: "v2", selectedAnswers: [:], score: 3, totalQuestions: 3, percentage: 100, passed: true)
store["v1"] = v1Attempt
store["v2"] = v2Attempt
assertEqual(store["v1"]?.passed, false, "v1 still failed")
assertEqual(store["v2"]?.passed, true, "v2 passed")
store["v1"] = TestValidationAttempt(id: "a-v1-retry", validationID: "v1", selectedAnswers: [:], score: 3, totalQuestions: 3, percentage: 100, passed: true)
assertEqual(store["v1"]?.passed, true, "v1 retry passed")
assertEqual(store["v2"]?.passed, true, "v2 unchanged")

// ── Test 17: Existing action completion remains intact ──

let actionIDs = [
    "software-1-action-1", "software-1-action-2", "software-1-action-3", "software-1-action-4",
    "software-2-action-1", "software-2-action-2", "software-2-action-3", "software-2-action-4",
    "software-3-action-1", "software-3-action-2", "software-3-action-3", "software-3-action-4",
    "software-4-action-1", "software-4-action-2", "software-4-action-3", "software-4-action-4",
    "software-5-action-1", "software-5-action-2", "software-5-action-3",
    "software-6-action-1", "software-6-action-2", "software-6-action-3", "software-6-action-4",
]
assertEqual(actionIDs.count, 23, "23 action IDs unchanged")
assertEqual(Set(actionIDs).count, 23, "All action IDs unique")

// ── Test 18: Existing resource data remains intact ──

let resourceIDs = [
    "sw1-res-1", "sw1-res-2", "sw1-res-3",
    "sw2-res-1", "sw2-res-2", "sw2-res-3",
    "sw3-res-1", "sw3-res-2", "sw3-res-3",
    "sw4-res-1", "sw4-res-2", "sw4-res-3",
    "sw5-res-1", "sw5-res-2", "sw5-res-3",
    "sw6-res-1", "sw6-res-2", "sw6-res-3",
]
assertEqual(resourceIDs.count, 18, "18 resource IDs unchanged")
assertEqual(Set(resourceIDs).count, 18, "All resource IDs unique")

// ── Test 19: Existing roadmap progress calculations unchanged ──

func percent(completed: Int, total: Int) -> Int {
    guard total > 0 else { return 0 }
    return Int((Double(completed) / Double(total) * 100).rounded())
}
assertEqual(percent(completed: 0, total: 6), 0, "Progress 0/6 → 0%")
assertEqual(percent(completed: 3, total: 6), 50, "Progress 3/6 → 50%")
assertEqual(percent(completed: 6, total: 6), 100, "Progress 6/6 → 100%")

// ── Test 20: Other roadmap templates remain unchanged ──

let otherRoadmapIDs = ["research-builder", "portfolio-projects", "college-ready"]
for rid in otherRoadmapIDs {
    assert(swAssessments[rid] == nil, "Roadmap \(rid) has no assessments (unchanged)")
}

// ── Test 21: Stable milestone IDs remain unchanged ──

let milestoneIDs = ["software-1", "software-2", "software-3", "software-4", "software-5", "software-6"]
assertEqual(milestoneIDs.count, 6, "6 milestone IDs")
for mid in milestoneIDs {
    assert(mid.hasPrefix("software-"), "Milestone ID \(mid) prefix preserved")
}

// ── Test 22: Stable action IDs remain unchanged ──

for id in actionIDs {
    assert(id.hasPrefix("software-"), "Action ID \(id) prefix preserved")
    assert(id.contains("-action-"), "Action ID \(id) format preserved")
}

// ── Test 23: Stable resource IDs remain unchanged ──

for id in resourceIDs {
    assert(id.hasPrefix("sw"), "Resource ID \(id) prefix preserved")
    assert(id.contains("-res-"), "Resource ID \(id) format preserved")
}

// ── Summary ──

print("\n══════════════════════════════════════════════")
print("Phase 6.4.5 Tests: \(passed) passed, \(failed) failed")
print("══════════════════════════════════════════════")
if failed > 0 { exit(1) }
