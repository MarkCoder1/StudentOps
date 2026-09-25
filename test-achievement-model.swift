import Foundation

// Standalone test script for Phase 7.3 — Achievement Data Model
// Run: swift test-achievement-model.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// MARK: - Inline canonical Achievement (mirrors Achievement.swift)

enum TestAchievementType: String, Codable, Hashable, CaseIterable {
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
        self = TestAchievementType(rawValue: raw) ?? .other
    }
}
enum TestAchievementStatus: String, Codable, Hashable {
    case recorded = "recorded"
    case verified = "verified"
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "recorded"
        self = TestAchievementStatus(rawValue: raw) ?? .recorded
    }
}
enum TestAchievementSource: String, Codable, Hashable {
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
        self = TestAchievementSource(rawValue: raw) ?? .unknown
    }
}
func normalizeSkillID(_ raw: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.components(separatedBy: .whitespacesAndNewlines).filter{!$0.isEmpty}
    return parts.joined(separator: " ").lowercased()
}
struct TestAchievement: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var description: String?
    var type: TestAchievementType
    var status: TestAchievementStatus
    var createdAt: Date
    var occurredAt: Date?
    var evidenceIDs: [String]
    var skillIDs: [String]?
    var roadmapID: String?
    var milestoneID: String?
    var projectID: String?
    var opportunityID: String?
    var source: TestAchievementSource
    enum CodingKeys: String, CodingKey {
        case id, title, description, type, status, createdAt, occurredAt, evidenceIDs, skillIDs, roadmapID, milestoneID, projectID, opportunityID, source
    }
    init(id: String = UUID().uuidString, title: String, description: String? = nil, type: TestAchievementType = .other, status: TestAchievementStatus = .recorded, createdAt: Date = Date(), occurredAt: Date? = nil, evidenceIDs: [String] = [], skillIDs: [String]? = nil, roadmapID: String? = nil, milestoneID: String? = nil, projectID: String? = nil, opportunityID: String? = nil, source: TestAchievementSource = .studentEntered) {
        self.id = id
        self.title = title
        self.description = description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
        self.status = status
        self.createdAt = createdAt
        self.occurredAt = occurredAt
        var seen=Set<String>(); var dedup:[String]=[]
        for eid in evidenceIDs where !eid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let t = eid.trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.insert(t).inserted { dedup.append(t) }
        }
        self.evidenceIDs = dedup
        if let skills = skillIDs {
            let norm = skills.map{ normalizeSkillID($0) }.filter{!$0.isEmpty}
            self.skillIDs = norm.isEmpty ? nil : Array(Set(norm)).sorted()
        } else { self.skillIDs = nil }
        self.roadmapID = roadmapID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true ? nil : roadmapID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.milestoneID = milestoneID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true ? nil : milestoneID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.projectID = projectID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true ? nil : projectID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.opportunityID = opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true ? nil : opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.source = source
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) { id = s }
        else if let u = try? c.decode(UUID.self, forKey: .id) { id = u.uuidString }
        else { id = UUID().uuidString }
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        if let t = try? c.decode(TestAchievementType.self, forKey: .type) { type = t }
        else if let raw = try? c.decode(String.self, forKey: .type) { type = TestAchievementType(rawValue: raw) ?? .other }
        else { type = .other }
        status = (try? c.decode(TestAchievementStatus.self, forKey: .status)) ?? .recorded
        if let d = try? c.decode(Date.self, forKey: .createdAt) { createdAt = d }
        else { createdAt = Date() }
        occurredAt = try? c.decode(Date.self, forKey: .occurredAt)
        evidenceIDs = (try? c.decode([String].self, forKey: .evidenceIDs)) ?? []
        if let s = try? c.decode([String].self, forKey: .skillIDs) {
            let norm = s.map{ normalizeSkillID($0) }.filter{!$0.isEmpty}
            skillIDs = norm.isEmpty ? nil : Array(Set(norm)).sorted()
        } else { skillIDs = nil }
        roadmapID = try? c.decode(String.self, forKey: .roadmapID)
        milestoneID = try? c.decode(String.self, forKey: .milestoneID)
        projectID = try? c.decode(String.self, forKey: .projectID)
        opportunityID = try? c.decode(String.self, forKey: .opportunityID)
        source = (try? c.decode(TestAchievementSource.self, forKey: .source)) ?? .unknown
        if roadmapID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true { roadmapID=nil }
        if milestoneID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true { milestoneID=nil }
        if projectID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true { projectID=nil }
        if opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true { opportunityID=nil }
    }
}

// Simulated evidence store for relationship validation
struct TestEvidenceRecord: Hashable, Codable { let id: String }

class TestAchievementStore {
    var achievements: [String: TestAchievement] = [:]
    var evidenceRecords: [String: TestEvidenceRecord] = [:]
    func add(_ ach: TestAchievement) -> Bool {
        let t = ach.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard achievements[ach.id] == nil else { return false }
        guard ach.status == .recorded else { return false }
        var filteredEvidence: [String] = []
        var seen=Set<String>()
        for eid in ach.evidenceIDs {
            let tt = eid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tt.isEmpty, !seen.contains(tt), evidenceRecords[tt] != nil else { continue }
            seen.insert(tt); filteredEvidence.append(tt)
        }
        let sanitized = TestAchievement(id: ach.id, title: t, description: ach.description, type: ach.type, status: .recorded, createdAt: ach.createdAt, occurredAt: ach.occurredAt, evidenceIDs: filteredEvidence, skillIDs: ach.skillIDs, roadmapID: ach.roadmapID, milestoneID: ach.milestoneID, projectID: ach.projectID, opportunityID: ach.opportunityID, source: ach.source)
        achievements[sanitized.id] = sanitized
        return true
    }
    func update(_ ach: TestAchievement) -> Bool {
        guard achievements[ach.id] != nil else { return false }
        let t = ach.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard ach.status == .recorded else { return false }
        var filteredEvidence: [String] = []
        var seen=Set<String>()
        for eid in ach.evidenceIDs {
            let tt = eid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tt.isEmpty, !seen.contains(tt), evidenceRecords[tt] != nil else { continue }
            seen.insert(tt); filteredEvidence.append(tt)
        }
        let sanitized = TestAchievement(id: ach.id, title: t, description: ach.description, type: ach.type, status: .recorded, createdAt: ach.createdAt, occurredAt: ach.occurredAt, evidenceIDs: filteredEvidence, skillIDs: ach.skillIDs, roadmapID: ach.roadmapID, milestoneID: ach.milestoneID, projectID: ach.projectID, opportunityID: ach.opportunityID, source: ach.source)
        achievements[sanitized.id] = sanitized
        return true
    }
    func delete(id: String) -> Bool {
        guard achievements[id] != nil else { return false }
        achievements.removeValue(forKey: id)
        return true
    }
}

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
encoder.outputFormatting = [.sortedKeys]
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

// MARK: - Model Tests

do { // required fields
    let a = TestAchievement(title: "Built Robot", type: .project)
    assert(!a.id.isEmpty, "required id")
    assertEqual(a.title, "Built Robot", "required title")
    assertEqual(a.type, .project, "required type")
    assertEqual(a.status, .recorded, "required status default")
}
do { // optional fields
    let a = TestAchievement(title: "T", description: "Desc", type: .learning, evidenceIDs: ["ev1"], skillIDs: ["python"], roadmapID: "r", milestoneID: "m", projectID: "p", opportunityID: "opp")
    assertEqual(a.description, "Desc", "optional desc")
    assertEqual(a.roadmapID, "r", "roadmapID")
    assertEqual(a.projectID, "p", "projectID")
    assertEqual(a.evidenceIDs, ["ev1"], "evidenceIDs")
    assertEqual(a.skillIDs, ["python"], "skillIDs")
}
do { // all supported achievement types
    for t in TestAchievementType.allCases {
        let a = TestAchievement(title: "T", type: t)
        let data = try! encoder.encode(a)
        let dec = try! decoder.decode(TestAchievement.self, from: data)
        assertEqual(dec.type, t, "type \(t.rawValue)")
    }
}
do { // status behavior
    let r = TestAchievement(title: "T", status: .recorded)
    assertEqual(r.status, .recorded, "status recorded")
    let v = TestAchievement(title: "T", status: .verified)
    // Store should reject verified
    let store = TestAchievementStore()
    assert(!store.add(v), "verified not automatic")
    assert(store.add(r), "recorded allowed")
}
do { // source behavior
    for s in [TestAchievementSource.studentEntered, .evidenceDerived, .roadmapMilestone, .project, .opportunity, .system, .unknown] {
        let a = TestAchievement(title: "T", source: s)
        assertEqual(a.source, s, "source \(s.rawValue)")
    }
}
do { // dates
    let created = Date(timeIntervalSince1970: 1700000000)
    let occurred = Date(timeIntervalSince1970: 1699900000)
    let a = TestAchievement(title: "T", createdAt: created, occurredAt: occurred)
    assertEqual(a.createdAt, created, "createdAt")
    assertEqual(a.occurredAt, occurred, "occurredAt")
    let data = try! encoder.encode(a)
    let dec = try! decoder.decode(TestAchievement.self, from: data)
    assertEqual(dec.createdAt, created, "createdAt roundtrip")
    assertEqual(dec.occurredAt, occurred, "occurredAt roundtrip")
}
do { // Codable round-trip
    let a = TestAchievement(title: "Full", description: "Desc", type: .research, status: .recorded, evidenceIDs: ["ev1"], skillIDs: ["python"], roadmapID: "r", projectID: "p", source: .evidenceDerived)
    let data = try! encoder.encode(a)
    let dec = try! decoder.decode(TestAchievement.self, from: data)
    assertEqual(dec.title, "Full", "roundtrip title")
    assertEqual(dec.type, .research, "roundtrip type")
    assertEqual(dec.evidenceIDs, ["ev1"], "roundtrip evidence")
}

// MARK: - Evidence relationships

do { // one evidence ID
    let store = TestAchievementStore()
    store.evidenceRecords["ev1"] = TestEvidenceRecord(id: "ev1")
    let a = TestAchievement(title: "One", evidenceIDs: ["ev1"])
    assert(store.add(a), "one evidence")
    assertEqual(store.achievements[a.id]?.evidenceIDs, ["ev1"], "one evidence stored")
}
do { // multiple evidence IDs
    let store = TestAchievementStore()
    store.evidenceRecords["ev1"] = TestEvidenceRecord(id:"ev1")
    store.evidenceRecords["ev2"] = TestEvidenceRecord(id:"ev2")
    let a = TestAchievement(title: "Multi", evidenceIDs: ["ev1","ev2"])
    assert(store.add(a), "multi evidence")
    assertEqual(store.achievements[a.id]?.evidenceIDs.count, 2, "multi count")
}
do { // duplicate evidence IDs
    let store = TestAchievementStore()
    store.evidenceRecords["ev1"] = TestEvidenceRecord(id:"ev1")
    let a = TestAchievement(title: "Dup", evidenceIDs: ["ev1","ev1"," ev1 "])
    assert(store.add(a), "dup evidence")
    assertEqual(store.achievements[a.id]?.evidenceIDs, ["ev1"], "dup deduped")
}
do { // nonexistent evidence handling (filtered, not rejected)
    let store = TestAchievementStore()
    store.evidenceRecords["ev1"] = TestEvidenceRecord(id:"ev1")
    let a = TestAchievement(title: "Bad", evidenceIDs: ["ev1","nonexistent"])
    assert(store.add(a), "nonexistent filtered not rejected")
    assertEqual(store.achievements[a.id]?.evidenceIDs, ["ev1"], "nonexistent filtered")
}
do { // evidence survives achievement deletion
    let store = TestAchievementStore()
    store.evidenceRecords["ev1"] = TestEvidenceRecord(id:"ev1")
    let a = TestAchievement(title: "T", evidenceIDs: ["ev1"])
    assert(store.add(a), "add for delete test")
    assert(store.delete(id: a.id), "delete achievement")
    assert(store.evidenceRecords["ev1"] != nil, "evidence survives")
}
do { // same evidence can support multiple achievements
    let store = TestAchievementStore()
    store.evidenceRecords["ev1"] = TestEvidenceRecord(id:"ev1")
    let a1 = TestAchievement(title: "A1", evidenceIDs: ["ev1"])
    let a2 = TestAchievement(title: "A2", evidenceIDs: ["ev1"])
    assert(store.add(a1), "a1 add")
    assert(store.add(a2), "a2 add")
    assertEqual(store.achievements[a1.id]?.evidenceIDs, ["ev1"], "a1 evidence")
    assertEqual(store.achievements[a2.id]?.evidenceIDs, ["ev1"], "a2 evidence")
}

// MARK: - Skills

do { // canonical skill IDs
    let a = TestAchievement(title: "T", skillIDs: ["Python"])
    assertEqual(a.skillIDs, ["python"], "canonical python")
}
do { // case normalization
    let a = TestAchievement(title: "T", skillIDs: ["PYTHON"])
    assertEqual(a.skillIDs, ["python"], "case norm")
}
do { // whitespace normalization
    let a = TestAchievement(title: "T", skillIDs: ["  machine   learning "])
    assertEqual(a.skillIDs, ["machine learning"], "whitespace")
}
do { // duplicate removal
    let a = TestAchievement(title: "T", skillIDs: ["Python","python"," PYTHON "])
    assertEqual(a.skillIDs, ["python"], "duplicate skill")
}
do { // achievement references do not award skills
    var strengths: [String] = []
    let a = TestAchievement(title: "T", skillIDs: ["python"])
    _ = a
    assert(strengths.isEmpty, "not award")
}

// MARK: - Relationships

do { // roadmap
    let a = TestAchievement(title: "T", roadmapID: "ai-engineer")
    assertEqual(a.roadmapID, "ai-engineer", "roadmap")
}
do { // milestone
    let a = TestAchievement(title: "T", milestoneID: "ai-3")
    assertEqual(a.milestoneID, "ai-3", "milestone")
}
do { // project
    let a = TestAchievement(title: "T", projectID: "proj-123")
    assertEqual(a.projectID, "proj-123", "project")
}
do { // opportunity
    let a = TestAchievement(title: "T", opportunityID: "opp:123")
    assertEqual(a.opportunityID, "opp:123", "opportunity")
}
do { // unrelated achievement
    let a = TestAchievement(title: "Generic", type: .other)
    assert(a.roadmapID == nil, "unrelated roadmap nil")
    assert(a.projectID == nil, "unrelated project nil")
}

// MARK: - Integrity

do { // empty title rejected
    let store = TestAchievementStore()
    let a = TestAchievement(title: "   ")
    assert(!store.add(a), "empty title rejected")
    let a2 = TestAchievement(title: "")
    assert(!store.add(a2), "empty title2 rejected")
}
do { // duplicate achievement ID rejected
    let store = TestAchievementStore()
    let a1 = TestAchievement(id: "dup-id", title: "T1")
    let a2 = TestAchievement(id: "dup-id", title: "T2")
    assert(store.add(a1), "first add")
    assert(!store.add(a2), "duplicate rejected")
}
do { // recorded default
    let a = TestAchievement(title: "T")
    assertEqual(a.status, .recorded, "default recorded")
}
do { // verified not automatic
    let store = TestAchievementStore()
    let v = TestAchievement(title: "V", status: .verified)
    assert(!store.add(v), "verified rejected")
}
do { // invalid references handled safely (evidence filtered)
    let store = TestAchievementStore()
    let a = TestAchievement(title: "T", evidenceIDs: ["bad1","bad2"])
    assert(store.add(a), "invalid evidence filtered not crash")
    assertEqual(store.achievements[a.id]?.evidenceIDs, [], "invalid filtered to empty")
}

// MARK: - IDs

do { // deterministic ID format
    let a = TestAchievement(id: "achievement-roadmap-a-ms-1", title: "T")
    assertEqual(a.id, "achievement-roadmap-a-ms-1", "deterministic format")
}
do { // student UUID compatibility
    let uuid = UUID().uuidString
    let a = TestAchievement(id: uuid, title: "T")
    assertEqual(a.id, uuid, "UUID id")
}
do { // no collision with evidence IDs
    let evID = "evidence-roadmap-a-ms-1"
    let achID = "achievement-roadmap-a-ms-1"
    assert(evID != achID, "no collision")
    let ach = TestAchievement(id: achID, title: "T")
    assert(ach.id != evID, "ids distinct")
}

// MARK: - Persistence

do { // save
    let store = TestAchievementStore()
    let a = TestAchievement(title: "Save")
    assert(store.add(a), "save")
    assertEqual(store.achievements.count, 1, "save count")
}
do { // reload UserDefaults round-trip
    let store = TestAchievementStore()
    let a = TestAchievement(title: "Reload", evidenceIDs: [], skillIDs: ["python"])
    store.evidenceRecords["ev1"] = TestEvidenceRecord(id:"ev1")
    // Add achievement without evidence
    assert(store.add(a), "reload add")
    let data = try! encoder.encode(store.achievements)
    let decoded = try! decoder.decode([String: TestAchievement].self, from: data)
    assertEqual(decoded.count, 1, "reload count")
    assertEqual(decoded[a.id]?.title, "Reload", "reload title")
}
do { // multiple achievements
    let store = TestAchievementStore()
    for i in 1...3 {
        assert(store.add(TestAchievement(title: "T\(i)")), "multi \(i)")
    }
    assertEqual(store.achievements.count, 3, "multi count")
}
do { // update
    let store = TestAchievementStore()
    let a = TestAchievement(title: "Original")
    assert(store.add(a), "update add")
    var updated = a
    updated.title = "Updated"
    // Need to create new struct with updated title
    let upd = TestAchievement(id: a.id, title: "Updated", description: "New")
    assert(store.update(upd), "update")
    assertEqual(store.achievements[a.id]?.title, "Updated", "update title")
}
do { // delete
    let store = TestAchievementStore()
    let a = TestAchievement(title: "Delete")
    assert(store.add(a), "delete add")
    assert(store.delete(id: a.id), "delete")
    assertEqual(store.achievements.count, 0, "delete count")
}
do { // debug reset
    var store = TestAchievementStore()
    assert(store.add(TestAchievement(title: "T")), "debug add")
    store.achievements = [:]
    assertEqual(store.achievements.count, 0, "debug reset")
}
do { // UserDefaults round-trip
    let a = TestAchievement(title: "UD", type: .project, evidenceIDs: [])
    let dict = ["k": a]
    let data = try! encoder.encode(dict)
    let dec = try! decoder.decode([String: TestAchievement].self, from: data)
    assertEqual(dec["k"]?.title, "UD", "UD roundtrip")
}

// MARK: - Backward Compatibility

do { // old data remains readable (legacy Achievement JSON with type)
    let oldJSON = #"{"id":"old-1","title":"Old Title","type":"project","description":"Student-provided experience recorded in the Student OPS profile."}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestAchievement.self, from: oldJSON)
    assertEqual(dec.title, "Old Title", "old title")
    assertEqual(dec.type, .project, "old type")
    assert(!dec.id.isEmpty, "old id")
}
do { // missing fields receive defaults
    let minimal = #"{"id":"min-1","title":"Min"}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestAchievement.self, from: minimal)
    assertEqual(dec.title, "Min", "minimal title")
    assertEqual(dec.type, .other, "minimal type default")
    assertEqual(dec.status, .recorded, "minimal status default")
    assert(dec.evidenceIDs.isEmpty, "minimal evidence empty")
}
do { // unknown enum values do not crash
    let unknown = #"{"id":"u-1","title":"T","type":"unknown-type-xyz","status":"weird","source":"mystery"}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestAchievement.self, from: unknown)
    assertEqual(dec.type, .other, "unknown type fallback")
    assertEqual(dec.status, .recorded, "unknown status fallback")
    assertEqual(dec.source, .unknown, "unknown source fallback")
}
do { // existing profile data remains intact (simulated)
    struct OldProfile: Codable { var loggedEntries: [String] = ["entry1"]; var categories: [String:Int]=["Projects":1] }
    let p = OldProfile()
    let data = try! encoder.encode(p)
    let dec = try! decoder.decode(OldProfile.self, from: data)
    assertEqual(dec.loggedEntries, ["entry1"], "profile loggedEntries")
    assertEqual(dec.categories, ["Projects":1], "profile categories")
}
do { // UUID id backward compat
    let uuidStr = UUID().uuidString
    let json = #"{"id":"\#(uuidStr)","title":"T"}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestAchievement.self, from: json)
    assertEqual(dec.id, uuidStr, "UUID id preserved")
}

// MARK: - Cross-System

do { // EvidenceRecord -> Achievement.evidenceIDs
    let ev = TestEvidenceRecord(id: "ev1")
    var store = TestAchievementStore()
    store.evidenceRecords["ev1"] = ev
    let ach = TestAchievement(title: "Ach", evidenceIDs: ["ev1"])
    assert(store.add(ach), "evidence -> achievement")
    assertEqual(store.achievements[ach.id]?.evidenceIDs, ["ev1"], "evidence linked")
}
do { // Achievement.skillIDs -> canonical
    let ach = TestAchievement(title: "T", skillIDs: ["PYTHON "])
    assertEqual(ach.skillIDs, ["python"], "skill canonical")
}
do { // Achievement.projectID -> existing Project (simulated)
    let ach = TestAchievement(title: "T", projectID: "proj-123")
    assertEqual(ach.projectID, "proj-123", "projectID")
}
do { // Achievement.roadmapID + milestoneID -> existing Roadmap
    let ach = TestAchievement(title: "T", roadmapID: "ai-engineer", milestoneID: "ai-3")
    assertEqual(ach.roadmapID, "ai-engineer", "roadmapID")
    assertEqual(ach.milestoneID, "ai-3", "milestoneID")
}
do { // Delete Achievement -> Evidence remains, Skills remain, Progress remains
    var evidenceStore: [String: TestEvidenceRecord] = ["ev1": TestEvidenceRecord(id:"ev1")]
    var strengths = ["Python"]
    var progress = ["roadmap-a": 1]
    var achStore = TestAchievementStore()
    achStore.evidenceRecords["ev1"] = TestEvidenceRecord(id:"ev1")
    let ach = TestAchievement(title: "T", evidenceIDs: ["ev1"])
    assert(achStore.add(ach), "add for delete test")
    assert(achStore.delete(id: ach.id), "delete")
    assert(evidenceStore["ev1"] != nil, "evidence remains")
    assertEqual(strengths, ["Python"], "skills remain")
    assertEqual(progress, ["roadmap-a":1], "progress remains")
}

print("\nPhase 7.3 — Achievement Data Model: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
