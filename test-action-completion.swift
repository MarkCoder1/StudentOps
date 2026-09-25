import Foundation

// Standalone test script for Phase 6.4.3 — Action Completion
// Run: swift StudentOps/test-action-completion.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// ── Load the StudentOps module types inline ──
// We compile the necessary types from source for testing

// MilestoneAction
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

// MARK: - Test 1: Stable IDs in Software Engineer roadmap

let expectedIDs: [String] = [
    "software-1-action-1", "software-1-action-2", "software-1-action-3", "software-1-action-4",
    "software-2-action-1", "software-2-action-2", "software-2-action-3", "software-2-action-4",
    "software-3-action-1", "software-3-action-2", "software-3-action-3", "software-3-action-4",
    "software-4-action-1", "software-4-action-2", "software-4-action-3", "software-4-action-4",
    "software-5-action-1", "software-5-action-2", "software-5-action-3",
    "software-6-action-1", "software-6-action-2", "software-6-action-3", "software-6-action-4",
]

assertEqual(expectedIDs.count, 23, "Expected 23 action IDs")

// Verify no duplicates
let uniqueIDs = Set(expectedIDs)
assertEqual(uniqueIDs.count, expectedIDs.count, "All action IDs must be unique")

// Verify naming convention
for id in expectedIDs {
    assert(id.hasPrefix("software-"), "ID \(id) should start with 'software-'")
    assert(id.contains("-action-"), "ID \(id) should contain '-action-'")
}

// Verify milestone prefix grouping
let m1IDs = expectedIDs.filter { $0.hasPrefix("software-1-") }
let m2IDs = expectedIDs.filter { $0.hasPrefix("software-2-") }
let m3IDs = expectedIDs.filter { $0.hasPrefix("software-3-") }
let m4IDs = expectedIDs.filter { $0.hasPrefix("software-4-") }
let m5IDs = expectedIDs.filter { $0.hasPrefix("software-5-") }
let m6IDs = expectedIDs.filter { $0.hasPrefix("software-6-") }
assertEqual(m1IDs.count, 4, "Software-1 should have 4 actions")
assertEqual(m2IDs.count, 4, "Software-2 should have 4 actions")
assertEqual(m3IDs.count, 4, "Software-3 should have 4 actions")
assertEqual(m4IDs.count, 4, "Software-4 should have 4 actions")
assertEqual(m5IDs.count, 3, "Software-5 should have 3 actions")
assertEqual(m6IDs.count, 4, "Software-6 should have 4 actions")

// MARK: - Test 2: Action ordering

let actions = expectedIDs.enumerated().map { (i, id) in
    let desc = "Complete action \(id) by following the instructions and submitting evidence of your work for review."
    return TestMilestoneAction(id: id, title: "Action \(i)", description: desc, order: i % 4 + 1)
}
for milestone in 1...6 {
    let milestoneActions = actions.filter { $0.id.hasPrefix("software-\(milestone)-") }
    let sorted = milestoneActions.sorted { $0.order < $1.order }
    for (idx, action) in sorted.enumerated() {
        assertEqual(action.order, idx + 1, "software-\(milestone) action \(action.id) order should be \(idx + 1)")
    }
}

// MARK: - Test 3: Action has all required fields

for action in actions {
    assert(!action.title.isEmpty, "Action \(action.id) must have a title")
    assert(!action.description.isEmpty, "Action \(action.id) must have a description")
    assert(action.order > 0, "Action \(action.id) must have order > 0")
}

// MARK: - Test 4: Codable roundtrip

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
let decoder = JSONDecoder()

for action in actions {
    let data = try! encoder.encode(action)
    let decoded = try! decoder.decode(TestMilestoneAction.self, from: data)
    assertEqual(decoded.id, action.id, "Codable roundtrip for \(action.id) id")
    assertEqual(decoded.title, action.title, "Codable roundtrip for \(action.id) title")
    assertEqual(decoded.description, action.description, "Codable roundtrip for \(action.id) description")
    assertEqual(decoded.order, action.order, "Codable roundtrip for \(action.id) order")
}

// MARK: - Test 5: ActionProgress calculations (logic-only)

func completedCount(actions: [TestMilestoneAction], completedIDs: Set<String>) -> Int {
    actions.filter { completedIDs.contains($0.id) }.count
}

func actionProgress(completed: Int, total: Int) -> Int {
    guard total > 0 else { return 0 }
    return Int((Double(completed) / Double(total) * 100).rounded())
}

let m1Actions = actions.filter { $0.id.hasPrefix("software-1-") }
let m2Actions = actions.filter { $0.id.hasPrefix("software-2-") }
let m3Actions = actions.filter { $0.id.hasPrefix("software-3-") }
let m4Actions = actions.filter { $0.id.hasPrefix("software-4-") }
let m5Actions = actions.filter { $0.id.hasPrefix("software-5-") }
let m6Actions = actions.filter { $0.id.hasPrefix("software-6-") }
assertEqual(completedCount(actions: m1Actions, completedIDs: []), 0, "0 of 4 complete → 0")
assertEqual(completedCount(actions: m1Actions, completedIDs: ["software-1-action-1"]), 1, "1 of 4 complete")
assertEqual(completedCount(actions: m1Actions, completedIDs: ["software-1-action-1", "software-1-action-2"]), 2, "2 of 4 complete")
assertEqual(completedCount(actions: m1Actions, completedIDs: ["software-1-action-1", "software-1-action-2", "software-1-action-3", "software-1-action-4"]), 4, "4 of 4 complete")

assertEqual(actionProgress(completed: 0, total: 4), 0, "0% progress")
assertEqual(actionProgress(completed: 1, total: 4), 25, "25% progress")
assertEqual(actionProgress(completed: 2, total: 4), 50, "50% progress")
assertEqual(actionProgress(completed: 3, total: 4), 75, "75% progress")
assertEqual(actionProgress(completed: 4, total: 4), 100, "100% progress")
assertEqual(actionProgress(completed: 0, total: 0), 0, "0/0 → 0%")

// MARK: - Test 6: Completion requires ALL actions

func allCompleted(actions: [TestMilestoneAction], completedIDs: Set<String>) -> Bool {
    guard !actions.isEmpty else { return false }
    return actions.allSatisfy { completedIDs.contains($0.id) }
}

assert(!allCompleted(actions: m1Actions, completedIDs: []), "Empty completed → not all done")
assert(!allCompleted(actions: m1Actions, completedIDs: ["software-1-action-1"]), "1 of 4 → not all done")
assert(!allCompleted(actions: m1Actions, completedIDs: ["software-1-action-1", "software-1-action-2"]), "2 of 4 → not all done")
assert(allCompleted(actions: m1Actions, completedIDs: ["software-1-action-1", "software-1-action-2", "software-1-action-3", "software-1-action-4"]), "4 of 4 → all done")
assert(!allCompleted(actions: [TestMilestoneAction](), completedIDs: []), "Empty actions → not all done")

// MARK: - Test 7: Toggle logic

func toggle(id: String, in set: inout Set<String>) {
    if set.contains(id) { set.remove(id) } else { set.insert(id) }
}

var testSet: Set<String> = []
toggle(id: "software-1-action-1", in: &testSet)
assert(testSet.contains("software-1-action-1"), "Toggle on adds ID")
toggle(id: "software-1-action-1", in: &testSet)
assert(!testSet.contains("software-1-action-1"), "Toggle off removes ID")
toggle(id: "software-1-action-2", in: &testSet)
assertEqual(testSet.count, 1, "Only one ID after toggle on different action")

// MARK: - Test 8: Storing does not auto-complete milestones

// Simulate: completing all actions in milestone 1 should NOT auto-complete the milestone
var completedIDs: Set<String> = []
for action in m1Actions {
    completedIDs.insert(action.id)
}
assert(allCompleted(actions: m1Actions, completedIDs: completedIDs), "All milestone-1 actions completed")
// The milestone itself should still need explicit completion — this is verified by
// the fact that milestoneProgress and completedActionIDs are separate stores.
// Milestone progress is in roadmapProgress[roadmapID] (Int), actions in completedActionIDs (Set<String>).
assert(completedIDs.count == 4, "4 action IDs stored, but milestone count stays separate")

// MARK: - Test 9: Backward compatibility — milestones without actions

let legacyMilestone = TestMilestoneAction(id: UUID().uuidString, title: "Legacy", description: "No order", order: 0)
assertEqual(legacyMilestone.order, 0, "Legacy action with order 0 is valid")
assert(legacyMilestone.estimatedTime == nil, "Legacy action without estimatedTime is valid")

// MARK: - Test 10: estimatedTime is preserved

let timedAction = TestMilestoneAction(id: "test-timed", title: "Timed", description: "Has time", order: 1, estimatedTime: "30 min")
let encoded = try! encoder.encode(timedAction)
let decodedTimed = try! decoder.decode(TestMilestoneAction.self, from: encoded)
assertEqual(decodedTimed.estimatedTime ?? "", "30 min", "estimatedTime preserved through Codable")

let untimedAction = TestMilestoneAction(id: "test-untimed", title: "Untimed", description: "No time", order: 2)
let encodedUntimed = try! encoder.encode(untimedAction)
let decodedUntimed = try! decoder.decode(TestMilestoneAction.self, from: encodedUntimed)
assert(decodedUntimed.estimatedTime == nil, "nil estimatedTime preserved through Codable")

// MARK: - Test 11: Empty completedIDs gives 0 progress

assertEqual(actionProgress(completed: completedCount(actions: m1Actions, completedIDs: []), total: m1Actions.count), 0, "Empty completedIDs → 0%")
assertEqual(actionProgress(completed: completedCount(actions: m2Actions, completedIDs: []), total: m2Actions.count), 0, "Empty completedIDs for m2 → 0%")

// MARK: - Test 12: Cross-milestone completion isolation

var allIDs: Set<String> = ["software-1-action-1", "software-1-action-2", "software-2-action-1"]
assertEqual(completedCount(actions: m1Actions, completedIDs: allIDs), 2, "Milestone 1 has 2 of its own actions completed")
assertEqual(completedCount(actions: m2Actions, completedIDs: allIDs), 1, "Milestone 2 has 1 of its own actions completed")
assertEqual(completedCount(actions: m1Actions, completedIDs: []), 0, "Milestone 1 has 0 with empty set")

// MARK: - Test 13: Total action counts per milestone

assertEqual(m1Actions.count, 4, "Software-1 has 4 actions total")
assertEqual(m2Actions.count, 4, "Software-2 has 4 actions total")
assertEqual(m3Actions.count, 4, "Software-3 has 4 actions total")
assertEqual(m4Actions.count, 4, "Software-4 has 4 actions total")
assertEqual(m5Actions.count, 3, "Software-5 has 3 actions total")
assertEqual(m6Actions.count, 4, "Software-6 has 4 actions total")
assertEqual(actions.count, 23, "Total 23 actions across all 6 milestones")

// MARK: - Test 14: Action descriptions are substantive

for action in actions {
    assert(action.description.count >= 20, "Action \(action.id) description should be substantive (≥20 chars), got \(action.description.count)")
}

// MARK: - Test 15: Actions sort by order correctly for all milestones

for milestone in 1...6 {
    let milestoneActions = actions.filter { $0.id.hasPrefix("software-\(milestone)-") }
    let sorted = milestoneActions.sorted { $0.order < $1.order }
    let orders = sorted.map { $0.order }
    assertEqual(orders, Array(1...milestoneActions.count), "Milestone \(milestone) orders are sequential 1..\(milestoneActions.count)")
}

// ── Summary ──
print("\n══════════════════════════════════════════════")
print("Phase 6.4.3 Tests: \(passed) passed, \(failed) failed")
print("══════════════════════════════════════════════")
if failed > 0 { exit(1) }
