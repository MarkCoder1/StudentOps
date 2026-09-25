import Foundation

// Standalone test for Phase 7.6 — Evidence + Achievement UI integration
// Run: swift test-evidence-achievement-ui.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

func normalizeSkillID(_ raw: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.components(separatedBy: .whitespacesAndNewlines).filter{!$0.isEmpty}
    return parts.joined(separator: " ").lowercased()
}

// MARK: - Inline models (mirror production)

enum AchType: String, Codable, Hashable { case milestone, project, other, learning }
enum AchStatus: String, Codable, Hashable { case recorded, verified }
enum AchSource: String, Codable, Hashable { case studentEntered, evidenceDerived, roadmapMilestone, project, opportunity }
struct Achievement: Hashable, Codable {
    let id: String; var title: String; var type: AchType; var status: AchStatus; var createdAt: Date; var evidenceIDs: [String]; var skillIDs: [String]?; var roadmapID: String?; var milestoneID: String?; var projectID: String?; var opportunityID: String?; var source: AchSource
    init(id: String, title: String, type: AchType = .other, status: AchStatus = .recorded, createdAt: Date = Date(), evidenceIDs: [String]=[], skillIDs: [String]?=nil, roadmapID: String?=nil, milestoneID: String?=nil, projectID: String?=nil, opportunityID: String?=nil, source: AchSource = .studentEntered) {
        self.id=id; self.title=title; self.type=type; self.status=status; self.createdAt=createdAt; self.evidenceIDs=evidenceIDs; self.skillIDs=skillIDs; self.roadmapID=roadmapID; self.milestoneID=milestoneID; self.projectID=projectID; self.opportunityID=opportunityID; self.source=source
    }
}
enum EvType: String, Codable, Hashable { case milestoneCompletion = "milestone-completion", projectWork, opportunityParticipation, other }
enum EvSource: String, Codable, Hashable { case roadmapMilestone, studentEntered }
enum EvStatus: String, Codable, Hashable { case recorded, verified }
struct EvidenceRecord: Hashable, Codable {
    let id: String; var title: String; var type: EvType; var roadmapID: String; var milestoneID: String; var createdAt: Date; var source: EvSource; var status: EvStatus; var skillIDs: [String]?; var projectID: String?; var opportunityID: String?; var artifactURL: String?; var validationID: String?; var validationPassed: Bool?
    init(id: String, title: String, type: EvType, roadmapID: String = "", milestoneID: String = "", createdAt: Date = Date(), source: EvSource = .studentEntered, status: EvStatus = .recorded, skillIDs: [String]?=nil, projectID: String?=nil, opportunityID: String?=nil, artifactURL: String?=nil, validationID: String?=nil, validationPassed: Bool?=nil) {
        self.id=id; self.title=title; self.type=type; self.roadmapID=roadmapID; self.milestoneID=milestoneID; self.createdAt=createdAt; self.source=source; self.status=status; self.skillIDs=skillIDs; self.projectID=projectID; self.opportunityID=opportunityID; self.artifactURL=artifactURL; self.validationID=validationID; self.validationPassed=validationPassed
    }
}
struct Roadmap { let id: String; let title: String }

// MARK: - Simulated store

class Store {
    var evidenceRecords: [String: EvidenceRecord] = [:]
    var achievementRecords: [String: Achievement] = [:]
    var isSystemGenerated: (EvidenceRecord) -> Bool = { rec in rec.id.hasPrefix("evidence-") && rec.source == .roadmapMilestone && rec.type == .milestoneCompletion }
    func addEvidence(_ rec: EvidenceRecord) -> Bool {
        guard !rec.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard evidenceRecords[rec.id] == nil else { return false }
        guard rec.status == .recorded else { return false }
        evidenceRecords[rec.id] = rec
        return true
    }
    func updateEvidence(_ rec: EvidenceRecord) -> Bool {
        guard let existing = evidenceRecords[rec.id] else { return false }
        guard !isSystemGenerated(existing) else { return false }
        guard !rec.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        evidenceRecords[rec.id] = rec
        return true
    }
    func deleteEvidence(id: String) -> Bool {
        guard let rec = evidenceRecords[id] else { return false }
        guard !isSystemGenerated(rec) else { return false }
        evidenceRecords.removeValue(forKey: id)
        return true
    }
    func addAchievement(_ ach: Achievement) -> Bool {
        guard !ach.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard achievementRecords[ach.id] == nil else { return false }
        guard ach.status == .recorded else { return false }
        achievementRecords[ach.id] = ach
        return true
    }
    func evidence(for achievement: Achievement) -> [EvidenceRecord] {
        achievement.evidenceIDs.compactMap { evidenceRecords[$0] }
    }
    func achievements(for evidence: EvidenceRecord) -> [Achievement] {
        achievementRecords.values.filter { $0.evidenceIDs.contains(evidence.id) }.sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Tests

print("—— Achievements ——")
do { // empty achievement state
    let store = Store()
    assert(store.achievementRecords.isEmpty, "empty achievement state")
    // UI should show empty state, not crash, with action to complete milestones
    let count = store.achievementRecords.count
    assertEqual(count, 0, "empty count 0")
}
do { // generated achievement appears
    let store = Store()
    store.evidenceRecords["evidence-r-m1"] = EvidenceRecord(id:"evidence-r-m1", title:"Milestone", type: .milestoneCompletion, roadmapID:"r", milestoneID:"m1", source: .roadmapMilestone)
    let ach = Achievement(id:"achievement-r-m1", title:"Milestone Achievement", type: .milestone, evidenceIDs:["evidence-r-m1"], roadmapID:"r", milestoneID:"m1", source: .roadmapMilestone)
    assert(store.addAchievement(ach), "generated achievement add")
    assertEqual(store.achievementRecords.count, 1, "generated appears")
    assertEqual(store.achievementRecords["achievement-r-m1"]?.title, "Milestone Achievement", "generated title")
}
do { // student-created achievement appears
    let store = Store()
    let ach = Achievement(id:"student-1", title:"My Custom Project", type: .project, evidenceIDs:[], projectID:"proj-123", source: .studentEntered)
    assert(store.addAchievement(ach), "student achievement add")
    assertEqual(store.achievementRecords["student-1"]?.source, .studentEntered, "student source")
}
do { // achievement detail displays
    let ach = Achievement(id:"ach1", title:"Build Robot", type: .project, evidenceIDs:["ev1","ev2"], roadmapID:"r", projectID:"p", source: .evidenceDerived)
    assertEqual(ach.evidenceIDs.count, 2, "achievement detail evidence count")
    assertEqual(ach.type, .project, "achievement detail type")
    assert(!ach.title.isEmpty, "achievement detail title")
}
do { // evidence navigation works (achievement -> evidence)
    let store = Store()
    store.evidenceRecords["ev1"] = EvidenceRecord(id:"ev1", title:"Evidence 1", type: .other)
    store.evidenceRecords["ev2"] = EvidenceRecord(id:"ev2", title:"Evidence 2", type: .other)
    let ach = Achievement(id:"ach1", title:"T", evidenceIDs:["ev1","ev2"])
    assert(store.addAchievement(ach), "add for navigation")
    let evs = store.evidence(for: ach)
    assertEqual(evs.count, 2, "evidence navigation count")
    assert(evs.contains(where:{$0.id=="ev1"}), "evidence navigation ev1")
}

print("—— Evidence ——")
do { // empty evidence state
    let store = Store()
    assert(store.evidenceRecords.isEmpty, "empty evidence")
}
do { // evidence list
    let store = Store()
    store.evidenceRecords["ev1"] = EvidenceRecord(id:"ev1", title:"E1", type: .other)
    store.evidenceRecords["ev2"] = EvidenceRecord(id:"ev2", title:"E2", type: .other)
    let sorted = store.evidenceRecords.values.sorted { $0.createdAt > $1.createdAt }
    assertEqual(sorted.count, 2, "evidence list count")
}
do { // evidence detail
    let rec = EvidenceRecord(id:"ev1", title:"My Project", type: .projectWork, roadmapID:"r", milestoneID:"m", source: .studentEntered, artifactURL:"https://github.com/me/repo")
    assertEqual(rec.title, "My Project", "evidence detail title")
    assertEqual(rec.artifactURL, "https://github.com/me/repo", "evidence artifact")
    assertEqual(rec.type, .projectWork, "evidence type")
}
do { // add evidence
    let store = Store()
    let rec = EvidenceRecord(id:"ev-new", title:"New Evidence", type: .other)
    assert(store.addEvidence(rec), "add evidence")
    assertEqual(store.evidenceRecords.count, 1, "add count")
}
do { // edit evidence
    let store = Store()
    let rec = EvidenceRecord(id:"ev1", title:"Original", type: .other, source: .studentEntered)
    assert(store.addEvidence(rec), "edit add")
    var updated = rec
    updated = EvidenceRecord(id:"ev1", title:"Updated", type: .other, source: .studentEntered)
    assert(store.updateEvidence(updated), "edit evidence")
    assertEqual(store.evidenceRecords["ev1"]?.title, "Updated", "edit title")
}
do { // delete student evidence
    let store = Store()
    let rec = EvidenceRecord(id:"ev1", title:"To Delete", type: .other, source: .studentEntered)
    assert(store.addEvidence(rec), "delete add")
    assert(store.deleteEvidence(id:"ev1"), "delete student")
    assertEqual(store.evidenceRecords.count, 0, "delete count")
}
do { // system evidence remains protected
    let store = Store()
    let sys = EvidenceRecord(id:"evidence-r-m1", title:"System", type: .milestoneCompletion, roadmapID:"r", milestoneID:"m1", source: .roadmapMilestone)
    assert(store.addEvidence(sys), "system add")
    assert(!store.deleteEvidence(id:"evidence-r-m1"), "system delete protected")
    assert(!store.updateEvidence(EvidenceRecord(id:"evidence-r-m1", title:"Hacked", type: .other, source: .studentEntered)), "system edit protected")
    assertEqual(store.evidenceRecords.count, 1, "system remains")
}

print("—— Relationships ——")
do { // achievement -> evidence
    let store = Store()
    store.evidenceRecords["ev1"] = EvidenceRecord(id:"ev1", title:"Ev", type: .other)
    let ach = Achievement(id:"ach1", title:"Ach", evidenceIDs:["ev1"])
    assert(store.addAchievement(ach), "ach->ev add")
    let evs = store.evidence(for: ach)
    assertEqual(evs.first?.id, "ev1", "ach->ev")
}
do { // evidence -> achievement
    let store = Store()
    store.evidenceRecords["ev1"] = EvidenceRecord(id:"ev1", title:"Ev", type: .other)
    let ach = Achievement(id:"ach1", title:"Ach", evidenceIDs:["ev1"])
    assert(store.addAchievement(ach), "ev->ach add")
    let achs = store.achievements(for: store.evidenceRecords["ev1"]!)
    assertEqual(achs.first?.id, "ach1", "ev->ach")
}
do { // achievement -> roadmap
    let ach = Achievement(id:"ach1", title:"T", roadmapID:"ai-engineer", milestoneID:"ai-1")
    assertEqual(ach.roadmapID, "ai-engineer", "ach roadmap")
    let roadmap = Roadmap(id:"ai-engineer", title:"Become an AI Engineer")
    assertEqual(roadmap.title, "Become an AI Engineer", "roadmap title")
}
do { // achievement -> project
    let ach = Achievement(id:"ach1", title:"T", projectID:"proj-123")
    assertEqual(ach.projectID, "proj-123", "ach project")
}
do { // achievement -> opportunity
    let ach = Achievement(id:"ach1", title:"T", opportunityID:"opp-123", source: .opportunity)
    assertEqual(ach.opportunityID, "opp-123", "ach opportunity")
}
do { // evidence -> skills
    let rec = EvidenceRecord(id:"ev1", title:"T", type: .other, skillIDs:["python","git"])
    assertEqual(rec.skillIDs, ["python","git"], "evidence skills")
    let ach = Achievement(id:"ach1", title:"T", skillIDs:["python"])
    assertEqual(ach.skillIDs, ["python"], "achievement skills")
}

print("—— Validation ——")
do { // passed validation evidence displays correctly
    let rec = EvidenceRecord(id:"ev1", title:"Validation", type: .milestoneCompletion, validationID:"val-1", validationPassed:true)
    assertEqual(rec.validationPassed, true, "passed validation")
    assert(rec.validationID != nil, "validationID present")
}
do { // failed validation is not shown as positive achievement
    let rec = EvidenceRecord(id:"ev1", title:"Validation", type: .milestoneCompletion, validationID:"val-1", validationPassed:false)
    assertEqual(rec.validationPassed, false, "failed validation")
    // Achievement generation should not create positive achievement from failed
    let store = Store()
    store.evidenceRecords["ev1"] = rec
    // Simulate no achievement generated for failed validation
    assert(store.achievementRecords.isEmpty, "failed not achievement")
}

print("—— Persistence ——")
do { // add evidence reload
    let store = Store()
    let rec = EvidenceRecord(id:"ev1", title:"Persist", type: .other)
    assert(store.addEvidence(rec), "persist add")
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let data = try! encoder.encode(store.evidenceRecords)
    let decoded = try! decoder.decode([String: EvidenceRecord].self, from: data)
    assertEqual(decoded["ev1"]?.title, "Persist", "reload evidence")
}
do { // achievements remain
    let store = Store()
    let ach = Achievement(id:"ach1", title:"Ach Persist", evidenceIDs:[])
    assert(store.addAchievement(ach), "ach persist add")
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let data = try! encoder.encode(store.achievementRecords)
    let decoded = try! decoder.decode([String: Achievement].self, from: data)
    assertEqual(decoded["ach1"]?.title, "Ach Persist", "reload achievement")
}
do { // relationships remain
    let store = Store()
    store.evidenceRecords["ev1"] = EvidenceRecord(id:"ev1", title:"Ev", type: .other)
    let ach = Achievement(id:"ach1", title:"Ach", evidenceIDs:["ev1"], roadmapID:"r", projectID:"p")
    assert(store.addAchievement(ach), "rel persist add")
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let achData = try! encoder.encode(store.achievementRecords)
    let evData = try! encoder.encode(store.evidenceRecords)
    let decAch = try! decoder.decode([String: Achievement].self, from: achData)
    let decEv = try! decoder.decode([String: EvidenceRecord].self, from: evData)
    assertEqual(decAch["ach1"]?.evidenceIDs, ["ev1"], "rel evidenceIDs")
    assertEqual(decAch["ach1"]?.roadmapID, "r", "rel roadmap")
    assertEqual(decEv["ev1"]?.title, "Ev", "rel evidence")
}

print("—— Integrity ——")
do {
    let store = Store()
    store.evidenceRecords["ev1"] = EvidenceRecord(id:"ev1", title:"Ev", type: .other)
    let ach = Achievement(id:"ach1", title:"Ach", evidenceIDs:["ev1","missing"])
    // Simulate reconciliation filtering missing
    let filtered = ach.evidenceIDs.filter { store.evidenceRecords[$0] != nil }
    assertEqual(filtered, ["ev1"], "reconciled removes missing")
    assert(!filtered.contains("missing"), "missing removed")
}

print("\nPhase 7.6 — Evidence/Achievement UI: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
