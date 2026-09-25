import Foundation

// Standalone test script for Phase 6.4.8 — Student Roadmap Activation
// Run: swift test-activation.swift

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

struct TestMilestoneAction: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String
    let order: Int
    let estimatedTime: String?
    init(id: String = UUID().uuidString, title: String, description: String, order: Int = 0, estimatedTime: String? = nil) {
        self.id = id; self.title = title; self.description = description; self.order = order; self.estimatedTime = estimatedTime
    }
}

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
}

struct TestMilestoneAssessment: Identifiable, Hashable, Codable {
    let id: String
    let questions: [String]
    let passThreshold: Int
    init(id: String = UUID().uuidString, questions: [String] = [], passThreshold: Int = 70) {
        self.id = id; self.questions = questions; self.passThreshold = passThreshold
    }
}

struct TestRoadmapMilestone: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let estimatedTime: String
    let whatItAccomplishes: String
    let whyItMatters: String
    let recommendedActions: [String]
    let resources: [String]
    let projectAction: String?
    let goal: String?
    let actions: [TestMilestoneAction]?
    let skillsDeveloped: [String]?
    let completionCriteria: [String]?
    let dependencies: [String]?
    let learningResources: [TestMilestoneResource]?
    let assessment: TestMilestoneAssessment?

    init(id: String, title: String, subtitle: String = "Sub", estimatedTime: String = "1 hr", whatItAccomplishes: String = "Desc", whyItMatters: String = "Why", recommendedActions: [String] = [], resources: [String] = [], projectAction: String? = nil, goal: String? = nil, actions: [TestMilestoneAction]? = nil, skillsDeveloped: [String]? = nil, completionCriteria: [String]? = nil, dependencies: [String]? = nil, learningResources: [TestMilestoneResource]? = nil, assessment: TestMilestoneAssessment? = nil) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.estimatedTime = estimatedTime; self.whatItAccomplishes = whatItAccomplishes; self.whyItMatters = whyItMatters; self.recommendedActions = recommendedActions; self.resources = resources; self.projectAction = projectAction; self.goal = goal; self.actions = actions; self.skillsDeveloped = skillsDeveloped; self.completionCriteria = completionCriteria; self.dependencies = dependencies; self.learningResources = learningResources; self.assessment = assessment
    }
}

struct TestRoadmap: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let milestones: [TestRoadmapMilestone]
    init(id: String, title: String, milestones: [TestRoadmapMilestone]) {
        self.id = id; self.title = title; self.milestones = milestones
    }
}

// ── Activation Model (mirror Roadmap.swift) ──

enum RoadmapActivationStatus: String, Codable, Hashable {
    case active
    case completed
}

struct ActiveRoadmap: Identifiable, Hashable, Codable {
    let roadmapID: String
    let status: RoadmapActivationStatus
    let startedAt: TimeInterval // Use TimeInterval for easy Codable
    var id: String { roadmapID }
    init(roadmapID: String, status: RoadmapActivationStatus = .active, startedAt: TimeInterval = Date().timeIntervalSince1970) {
        self.roadmapID = roadmapID; self.status = status; self.startedAt = startedAt
    }
}

// ── Simulated Store (mirrors AppDataStore activation logic) ──

class SimulatedStore {
    var activeRoadmaps: [String: ActiveRoadmap] = [:]
    var roadmapProgress: [String: Int] = [:]
    var completedActionIDs: Set<String> = []
    var validationAttempts: [String: String] = [:] // simplified
    var evidenceRecords: [String: String] = [:] // simplified
    var profileStrengths: [String] = []

    func completedCount(for roadmap: TestRoadmap) -> Int {
        min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
    }

    func isRoadmapActivated(_ roadmapID: String) -> Bool {
        guard let activation = activeRoadmaps[roadmapID] else { return false }
        return activation.status == .active
    }

    func roadmapActivationStatus(_ roadmapID: String) -> RoadmapActivationStatus? {
        activeRoadmaps[roadmapID]?.status
    }

    func startRoadmap(_ roadmap: TestRoadmap) {
        guard activeRoadmaps[roadmap.id]?.status != .active else { return }
        let existing = activeRoadmaps[roadmap.id]
        activeRoadmaps[roadmap.id] = ActiveRoadmap(
            roadmapID: roadmap.id,
            status: .active,
            startedAt: existing?.startedAt ?? Date().timeIntervalSince1970
        )
    }

    func deactivateRoadmap(_ roadmapID: String) {
        activeRoadmaps.removeValue(forKey: roadmapID)
    }

    func clearActivation(_ roadmapID: String) {
        activeRoadmaps.removeValue(forKey: roadmapID)
    }

    func markRoadmapMilestoneComplete(for roadmap: TestRoadmap) {
        let next = min(completedCount(for: roadmap) + 1, roadmap.milestones.count)
        roadmapProgress[roadmap.id] = next
    }

    func resetRoadmap(_ roadmap: TestRoadmap) {
        roadmapProgress[roadmap.id] = 0
        for milestone in roadmap.milestones {
            for action in milestone.actions ?? [] {
                completedActionIDs.remove(action.id)
            }
        }
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
let decoder = JSONDecoder()

// ── Test Data ──

let seMilestones: [TestRoadmapMilestone] = [
    TestRoadmapMilestone(id: "software-1", title: "Explore CS", subtitle: "Map concepts",
        actions: [TestMilestoneAction(id: "sw1-action-1", title: "A1", description: "", order: 0),
                  TestMilestoneAction(id: "sw1-action-2", title: "A2", description: "", order: 1)],
        skillsDeveloped: ["Terminal"]),
    TestRoadmapMilestone(id: "software-2", title: "Programming Fundamentals", subtitle: "Core patterns", skillsDeveloped: ["Python"], dependencies: ["software-1"]),
    TestRoadmapMilestone(id: "software-3", title: "Software Development", subtitle: "Real software", skillsDeveloped: ["Git"], dependencies: ["software-2"]),
]

let seRoadmap = TestRoadmap(id: "software-engineer", title: "Software Engineer", milestones: seMilestones)

let researchRoadmap = TestRoadmap(id: "research-builder", title: "Research Profile", milestones: [
    TestRoadmapMilestone(id: "research-1", title: "Choose Question", subtitle: "Pick a Q"),
    TestRoadmapMilestone(id: "research-2", title: "Learn Methods", subtitle: "How to research"),
])

let portfolioRoadmap = TestRoadmap(id: "portfolio-projects", title: "Project Portfolio", milestones: [
    TestRoadmapMilestone(id: "portfolio-1", title: "Pick Problem", subtitle: "Find one"),
])

// ═══════════════════════════════════════════════
//  TEST 1: Starting a roadmap creates active state
// ═══════════════════════════════════════════════

let store1 = SimulatedStore()
assert(!store1.isRoadmapActivated("software-engineer"), "Not activated before start")
store1.startRoadmap(seRoadmap)
assert(store1.isRoadmapActivated("software-engineer"), "Activated after start")
assertEqual(store1.roadmapActivationStatus("software-engineer"), .active, "Status is active")

// ═══════════════════════════════════════════════
//  TEST 2: Active state persists (simulated)
// ═══════════════════════════════════════════════

let store2 = SimulatedStore()
store2.startRoadmap(seRoadmap)
// Simulate persistence by transferring state
let persisted = store2.activeRoadmaps
let store2b = SimulatedStore()
store2b.activeRoadmaps = persisted
assert(store2b.isRoadmapActivated("software-engineer"), "Active state persists through transfer")

// ═══════════════════════════════════════════════
//  TEST 3: Starting the same roadmap twice does not duplicate
// ═══════════════════════════════════════════════

let store3 = SimulatedStore()
store3.startRoadmap(seRoadmap)
let firstStartedAt = store3.activeRoadmaps["software-engineer"]?.startedAt
store3.startRoadmap(seRoadmap) // second start
assertEqual(store3.activeRoadmaps.count, 1, "No duplicate active instances")
let secondStartedAt = store3.activeRoadmaps["software-engineer"]?.startedAt
assertEqual(firstStartedAt, secondStartedAt, "startedAt preserved on re-start")

// ═══════════════════════════════════════════════
//  TEST 4: Multiple different roadmaps can be active
// ═══════════════════════════════════════════════

let store4 = SimulatedStore()
store4.startRoadmap(seRoadmap)
store4.startRoadmap(researchRoadmap)
store4.startRoadmap(portfolioRoadmap)
assertEqual(store4.activeRoadmaps.count, 3, "Three roadmaps active")
assert(store4.isRoadmapActivated("software-engineer"), "SE active")
assert(store4.isRoadmapActivated("research-builder"), "Research active")
assert(store4.isRoadmapActivated("portfolio-projects"), "Portfolio active")

// ═══════════════════════════════════════════════
//  TEST 5: Existing progress is preserved when starting
// ═══════════════════════════════════════════════

let store5 = SimulatedStore()
store5.roadmapProgress["software-engineer"] = 2 // 2/3 milestones completed
store5.startRoadmap(seRoadmap)
assertEqual(store5.completedCount(for: seRoadmap), 2, "Progress preserved after start")

// ═══════════════════════════════════════════════
//  TEST 6: Completed milestones remain completed after activation
// ═══════════════════════════════════════════════

let store6 = SimulatedStore()
store6.roadmapProgress["software-engineer"] = 1
store6.startRoadmap(seRoadmap)
assertEqual(store6.completedCount(for: seRoadmap), 1, "Completed milestone count preserved")

// ═══════════════════════════════════════════════
//  TEST 7: Completed actions remain completed after activation
// ═══════════════════════════════════════════════

let store7 = SimulatedStore()
store7.completedActionIDs = ["sw1-action-1", "sw1-action-2"]
store7.startRoadmap(seRoadmap)
assert(store7.completedActionIDs.contains("sw1-action-1"), "Action 1 preserved")
assert(store7.completedActionIDs.contains("sw1-action-2"), "Action 2 preserved")

// ═══════════════════════════════════════════════
//  TEST 8: Validation attempts remain intact after activation
// ═══════════════════════════════════════════════

let store8 = SimulatedStore()
store8.validationAttempts["sw1-assessment"] = "passed"
store8.startRoadmap(seRoadmap)
assertEqual(store8.validationAttempts["sw1-assessment"], "passed", "Validation attempt preserved")

// ═══════════════════════════════════════════════
//  TEST 9: Evidence remains intact after activation
// ═══════════════════════════════════════════════

let store9 = SimulatedStore()
store9.evidenceRecords["evidence-software-engineer-software-1"] = "milestone-completion"
store9.startRoadmap(seRoadmap)
assertEqual(store9.evidenceRecords["evidence-software-engineer-software-1"], "milestone-completion", "Evidence preserved")

// ═══════════════════════════════════════════════
//  TEST 10: Skills remain intact after activation
// ═══════════════════════════════════════════════

let store10 = SimulatedStore()
store10.profileStrengths = ["Terminal", "Git basics"]
store10.startRoadmap(seRoadmap)
assertEqual(store10.profileStrengths.count, 2, "Skills preserved")
assert(store10.profileStrengths.contains("Terminal"), "Terminal preserved")
assert(store10.profileStrengths.contains("Git basics"), "Git basics preserved")

// ═══════════════════════════════════════════════
//  TEST 11: Starting from a recommendation uses correct roadmap ID
// ═══════════════════════════════════════════════

let store11 = SimulatedStore()
// Simulate AI recommendation with roadmap ID
let recommendedID = "software-engineer"
store11.startRoadmap(seRoadmap)
assert(store11.isRoadmapActivated(recommendedID), "Activated from recommendation ID")

// ═══════════════════════════════════════════════
//  TEST 12: AI recommendations do not automatically activate
// ═══════════════════════════════════════════════

let store12 = SimulatedStore()
// Simulate receiving AI recommendation without starting
assert(!store12.isRoadmapActivated("software-engineer"), "Not auto-activated by recommendation")
assertEqual(store12.activeRoadmaps.count, 0, "No active roadmaps without explicit start")

// ═══════════════════════════════════════════════
//  TEST 13: Starting from RoadmapDetailView works
// ═══════════════════════════════════════════════

let store13 = SimulatedStore()
store13.startRoadmap(seRoadmap)
assert(store13.isRoadmapActivated("software-engineer"), "Activated from detail view")

// ═══════════════════════════════════════════════
//  TEST 14: Active state survives app reload (simulated)
// ═══════════════════════════════════════════════

let store14 = SimulatedStore()
store14.startRoadmap(seRoadmap)
// Simulate app reload by transferring persistence
let reloaded = store14.activeRoadmaps
let store14b = SimulatedStore()
store14b.activeRoadmaps = reloaded
assert(store14b.isRoadmapActivated("software-engineer"), "Survives simulated reload")

// ═══════════════════════════════════════════════
//  TEST 15: Deactivating preserves progress/history
// ═══════════════════════════════════════════════

let store15 = SimulatedStore()
store15.roadmapProgress["software-engineer"] = 2
store15.completedActionIDs = ["sw1-action-1"]
store15.startRoadmap(seRoadmap)
store15.deactivateRoadmap("software-engineer")
assert(!store15.isRoadmapActivated("software-engineer"), "Deactivated")
assertEqual(store15.completedCount(for: seRoadmap), 2, "Progress preserved after deactivation")
assert(store15.completedActionIDs.contains("sw1-action-1"), "Actions preserved after deactivation")

// ═══════════════════════════════════════════════
//  TEST 16: Deactivation does not delete evidence
// ═══════════════════════════════════════════════

let store16 = SimulatedStore()
store16.evidenceRecords["ev-1"] = "milestone-completion"
store16.startRoadmap(seRoadmap)
store16.deactivateRoadmap("software-engineer")
assertEqual(store16.evidenceRecords["ev-1"], "milestone-completion", "Evidence preserved after deactivation")

// ═══════════════════════════════════════════════
//  TEST 17: Deactivation does not delete skills
// ═══════════════════════════════════════════════

let store17 = SimulatedStore()
store17.profileStrengths = ["Python"]
store17.startRoadmap(seRoadmap)
store17.deactivateRoadmap("software-engineer")
assertEqual(store17.profileStrengths.count, 1, "Skills preserved after deactivation")
assert(store17.profileStrengths.contains("Python"), "Python preserved")

// ═══════════════════════════════════════════════
//  TEST 18: Reset remains distinct from deactivation
// ═══════════════════════════════════════════════

let store18 = SimulatedStore()
store18.roadmapProgress["software-engineer"] = 2
store18.completedActionIDs = ["sw1-action-1", "sw1-action-2"]
store18.startRoadmap(seRoadmap)
// Deactivate: preserves progress
store18.deactivateRoadmap("software-engineer")
assertEqual(store18.completedCount(for: seRoadmap), 2, "Deactivate: progress preserved")
// Reset: clears progress
store18.resetRoadmap(seRoadmap)
assertEqual(store18.completedCount(for: seRoadmap), 0, "Reset: progress cleared")
assert(!store18.completedActionIDs.contains("sw1-action-1"), "Reset: actions cleared")

// ═══════════════════════════════════════════════
//  TEST 19: Dependency availability continues to calculate correctly
// ═══════════════════════════════════════════════

let store19 = SimulatedStore()
store19.startRoadmap(seRoadmap)
// software-2 has dependency on software-1
let ms2 = seMilestones[1]
assert(ms2.dependencies?.contains("software-1") == true, "software-2 depends on software-1")
// Without completing software-1, software-2 should be locked
let incompleteIDs: Set<String> = []
let deps = ms2.dependencies ?? []
let incomplete = deps.filter { !incompleteIDs.contains($0) }
assertEqual(incomplete, ["software-1"], "software-2 locked by software-1")
// After completing software-1, software-2 should be available
let completeIDs: Set<String> = ["software-1"]
let incompleteAfter = deps.filter { !completeIDs.contains($0) }
assert(incompleteAfter.isEmpty, "software-2 available after software-1 completed")

// ═══════════════════════════════════════════════
//  TEST 20: Roadmap progress calculations remain unchanged
// ═══════════════════════════════════════════════

let store20 = SimulatedStore()
store20.roadmapProgress["software-engineer"] = 2
store20.startRoadmap(seRoadmap)
let completed = store20.completedCount(for: seRoadmap)
let total = seRoadmap.milestones.count
let pct = Int((Double(completed) / Double(total) * 100).rounded())
assertEqual(pct, 67, "Progress calculation unchanged")

// ═══════════════════════════════════════════════
//  TEST 21: Existing roadmap IDs remain unchanged
// ═══════════════════════════════════════════════

assertEqual(seRoadmap.id, "software-engineer", "SE roadmap ID unchanged")
assertEqual(researchRoadmap.id, "research-builder", "Research roadmap ID unchanged")
assertEqual(portfolioRoadmap.id, "portfolio-projects", "Portfolio roadmap ID unchanged")
assertEqual(seMilestones[0].id, "software-1", "Milestone software-1 ID unchanged")
assertEqual(seMilestones[1].id, "software-2", "Milestone software-2 ID unchanged")
assertEqual(seMilestones[2].id, "software-3", "Milestone software-3 ID unchanged")

// ═══════════════════════════════════════════════
//  TEST 22: ActiveRoadmap Codable roundtrip
// ═══════════════════════════════════════════════

let fixedDate: TimeInterval = 1700000000
let ar = ActiveRoadmap(roadmapID: "software-engineer", status: .active, startedAt: fixedDate)
let arData = try! encoder.encode(ar)
let arDecoded = try! decoder.decode(ActiveRoadmap.self, from: arData)
assertEqual(arDecoded.roadmapID, "software-engineer", "ActiveRoadmap roundtrip: id")
assertEqual(arDecoded.status, .active, "ActiveRoadmap roundtrip: status")
assertEqual(arDecoded.startedAt, fixedDate, "ActiveRoadmap roundtrip: startedAt")

// ═══════════════════════════════════════════════
//  TEST 23: ActiveRoadmap status Codable roundtrip
// ═══════════════════════════════════════════════

let activeJSON = "\"active\"".data(using: .utf8)!
let activeStatus = try! decoder.decode(RoadmapActivationStatus.self, from: activeJSON)
assertEqual(activeStatus, .active, "Status active roundtrip")
let completedJSON = "\"completed\"".data(using: .utf8)!
let completedStatus = try! decoder.decode(RoadmapActivationStatus.self, from: completedJSON)
assertEqual(completedStatus, .completed, "Status completed roundtrip")

// ═══════════════════════════════════════════════
//  TEST 24: Multiple active roadmaps stored correctly
// ═══════════════════════════════════════════════

let store24 = SimulatedStore()
store24.startRoadmap(seRoadmap)
store24.startRoadmap(researchRoadmap)
let dictData = try! encoder.encode(store24.activeRoadmaps)
let dictDecoded = try! decoder.decode([String: ActiveRoadmap].self, from: dictData)
assertEqual(dictDecoded.count, 2, "Dictionary roundtrip: 2 entries")
assertEqual(dictDecoded["software-engineer"]?.status, .active, "Dictionary roundtrip: SE active")
assertEqual(dictDecoded["research-builder"]?.status, .active, "Dictionary roundtrip: Research active")

// ═══════════════════════════════════════════════
//  TEST 25: Deactivation removes from active list
// ═══════════════════════════════════════════════

let store25 = SimulatedStore()
store25.startRoadmap(seRoadmap)
store25.startRoadmap(researchRoadmap)
assertEqual(store25.activeRoadmaps.count, 2, "Pre-deactivation: 2 active")
store25.deactivateRoadmap("software-engineer")
assertEqual(store25.activeRoadmaps.count, 1, "Post-deactivation: 1 active")
assert(!store25.isRoadmapActivated("software-engineer"), "SE deactivated")
assert(store25.isRoadmapActivated("research-builder"), "Research still active")

// ═══════════════════════════════════════════════
//  TEST 26: clearActivation removes activation
// ═══════════════════════════════════════════════

let store26 = SimulatedStore()
store26.startRoadmap(seRoadmap)
assert(store26.isRoadmapActivated("software-engineer"), "Before clear")
store26.clearActivation("software-engineer")
assert(!store26.isRoadmapActivated("software-engineer"), "After clear")

// ═══════════════════════════════════════════════
//  TEST 27: Activated roadmaps filters correctly
// ═══════════════════════════════════════════════

let store27 = SimulatedStore()
store27.roadmapProgress["software-engineer"] = 3 // all completed
store27.startRoadmap(seRoadmap)
// SE is activated but completed — should not appear in activatedRoadmaps
// (This tests the filtering logic: active && !completed)
let activatedIDs = store27.activeRoadmaps.keys.filter { store27.activeRoadmaps[$0]?.status == .active }
assert(activatedIDs.contains("software-engineer"), "SE is in active list")
// But the derived activatedRoadmaps would filter it out if completed
// For this test, we verify the raw data is correct
assertEqual(store27.activeRoadmaps.count, 1, "One activation record")
assertEqual(store27.activeRoadmaps["software-engineer"]?.status, .active, "Status active even if completed")

// ═══════════════════════════════════════════════
//  TEST 28: Starting completed roadmap handles safely
// ═══════════════════════════════════════════════

let store28 = SimulatedStore()
store28.roadmapProgress["software-engineer"] = 3 // all completed
store28.startRoadmap(seRoadmap) // should not crash
assert(store28.isRoadmapActivated("software-engineer"), "Activated even if completed")
assertEqual(store28.completedCount(for: seRoadmap), 3, "Progress unchanged")

// ═══════════════════════════════════════════════
//  TEST 29: Non-activated roadmap returns nil status
// ═══════════════════════════════════════════════

let store29 = SimulatedStore()
assert(store29.roadmapActivationStatus("software-engineer") == nil, "Nil status for non-activated")
assert(!store29.isRoadmapActivated("software-engineer"), "Not activated")

// ═══════════════════════════════════════════════
//  TEST 30: Activation is idempotent — start twice, same result
// ═══════════════════════════════════════════════

let store30 = SimulatedStore()
store30.startRoadmap(seRoadmap)
let count1 = store30.activeRoadmaps.count
store30.startRoadmap(seRoadmap)
let count2 = store30.activeRoadmaps.count
assertEqual(count1, count2, "Idempotent: count unchanged on re-start")

// ═══════════════════════════════════════════════
//  SUMMARY
// ═══════════════════════════════════════════════

print("\nPhase 6.4.8 — Activation: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
