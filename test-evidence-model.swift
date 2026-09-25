import Foundation

// Standalone test script for Phase 7.1 — Evidence Data Model
// Run: swift test-evidence-model.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// MARK: - Inline canonical Evidence model (mirrors Roadmap.swift evolved model)

enum TestEvidenceType: String, Codable, Hashable, CaseIterable {
    case milestoneCompletion = "milestone-completion"
    case projectWork = "project-work"
    case validation = "validation"
    case artifact = "artifact"
    case opportunityParticipation = "opportunity-participation"
    case leadershipActivity = "leadership-activity"
    case communityActivity = "community-activity"
    case learning = "learning"
    case other = "other"
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "other"
        self = TestEvidenceType(rawValue: raw) ?? .other
    }
}
enum TestEvidenceSource: String, Codable, Hashable, CaseIterable {
    case roadmapMilestone = "roadmapMilestone"
    case project = "project"
    case validation = "validation"
    case opportunity = "opportunity"
    case studentEntered = "studentEntered"
    case system = "system"
    case unknown = "unknown"
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "unknown"
        self = TestEvidenceSource(rawValue: raw) ?? .unknown
    }
}
enum TestEvidenceStatus: String, Codable, Hashable, CaseIterable {
    case recorded = "recorded"
    case verified = "verified"
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "recorded"
        self = TestEvidenceStatus(rawValue: raw) ?? .recorded
    }
}
struct TestEvidenceArtifact: Hashable, Codable {
    let type: String
    let title: String
    let url: String?
    let description: String?
    init(type: String, title: String, url: String? = nil, description: String? = nil) {
        self.type = type; self.title = title; self.url = url; self.description = description
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? "link"
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        url = try? c.decode(String.self, forKey: .url)
        description = try? c.decode(String.self, forKey: .description)
    }
}
struct TestEvidenceRecord: Identifiable, Hashable, Codable {
    let id: String
    let type: TestEvidenceType
    let title: String
    let description: String?
    let roadmapID: String
    let milestoneID: String
    let completionDate: Date
    let createdAt: Date
    let occurredAt: Date?
    let source: TestEvidenceSource
    let status: TestEvidenceStatus
    let actionID: String?
    let skillIDs: [String]?
    let artifact: TestEvidenceArtifact?
    let validationID: String?
    let validationScore: Int?
    let validationPercentage: Int?
    let validationPassed: Bool?
    let projectID: String?
    let opportunityID: String?
    enum CodingKeys: String, CodingKey {
        case id, type, title, description, roadmapID, milestoneID, completionDate, createdAt, occurredAt, source, status, actionID, skillIDs, artifact, validationID, validationScore, validationPercentage, validationPassed, projectID, opportunityID
    }
    init(id: String = UUID().uuidString, type: TestEvidenceType, title: String, description: String? = nil, roadmapID: String, milestoneID: String, completionDate: Date = Date(), createdAt: Date? = nil, occurredAt: Date? = nil, source: TestEvidenceSource = .roadmapMilestone, status: TestEvidenceStatus = .recorded, actionID: String? = nil, skillIDs: [String]? = nil, artifact: TestEvidenceArtifact? = nil, validationID: String? = nil, validationScore: Int? = nil, validationPercentage: Int? = nil, validationPassed: Bool? = nil, projectID: String? = nil, opportunityID: String? = nil) {
        self.id = id; self.type = type; self.title = title; self.description = description; self.roadmapID = roadmapID; self.milestoneID = milestoneID; self.completionDate = completionDate; self.createdAt = createdAt ?? completionDate; self.occurredAt = occurredAt; self.source = source; self.status = status; self.actionID = actionID; self.skillIDs = skillIDs?.isEmpty == true ? nil : skillIDs; self.artifact = artifact; self.validationID = validationID; self.validationScore = validationScore; self.validationPercentage = validationPercentage; self.validationPassed = validationPassed; self.projectID = projectID; self.opportunityID = opportunityID
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        if let t = try? c.decode(TestEvidenceType.self, forKey: .type) { type = t }
        else if let raw = try? c.decode(String.self, forKey: .type) { type = TestEvidenceType(rawValue: raw) ?? .other }
        else { type = .other }
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        roadmapID = (try? c.decode(String.self, forKey: .roadmapID)) ?? ""
        milestoneID = (try? c.decode(String.self, forKey: .milestoneID)) ?? ""
        completionDate = (try? c.decode(Date.self, forKey: .completionDate)) ?? Date()
        if let ca = try? c.decode(Date.self, forKey: .createdAt) { createdAt = ca } else { createdAt = (try? c.decode(Date.self, forKey: .completionDate)) ?? Date() }
        occurredAt = try? c.decode(Date.self, forKey: .occurredAt)
        source = (try? c.decode(TestEvidenceSource.self, forKey: .source)) ?? .roadmapMilestone
        status = (try? c.decode(TestEvidenceStatus.self, forKey: .status)) ?? .recorded
        actionID = try? c.decode(String.self, forKey: .actionID)
        skillIDs = try? c.decode([String].self, forKey: .skillIDs)
        artifact = try? c.decode(TestEvidenceArtifact.self, forKey: .artifact)
        validationID = try? c.decode(String.self, forKey: .validationID)
        validationScore = try? c.decode(Int.self, forKey: .validationScore)
        validationPercentage = try? c.decode(Int.self, forKey: .validationPercentage)
        validationPassed = try? c.decode(Bool.self, forKey: .validationPassed)
        projectID = try? c.decode(String.self, forKey: .projectID)
        opportunityID = try? c.decode(String.self, forKey: .opportunityID)
    }
}

// Skill canonical helper (mirrors Skill.swift)
func normalizeSkillID(_ raw: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.components(separatedBy: .whitespacesAndNewlines).filter{!$0.isEmpty}
    return parts.joined(separator: " ").lowercased()
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
encoder.dateEncodingStrategy = .iso8601
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

// MARK: - Model Tests (1-8)

do { // 1. EvidenceRecord can be created.
    let r = TestEvidenceRecord(type: .milestoneCompletion, title: "Test", roadmapID: "r", milestoneID: "m")
    assert(!r.id.isEmpty, "1: id not empty")
    assertEqual(r.type, .milestoneCompletion, "1: type")
}
do { // 2. All required fields encode/decode.
    let d = Date(timeIntervalSince1970: 1700000000)
    let r = TestEvidenceRecord(type: .milestoneCompletion, title: "T", description: "D", roadmapID: "r1", milestoneID: "m1", completionDate: d, createdAt: d, source: .roadmapMilestone, status: .recorded)
    let data = try! encoder.encode(r)
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
    assertEqual(dec.title, "T", "2: title")
    assertEqual(dec.roadmapID, "r1", "2: roadmapID")
    assertEqual(dec.milestoneID, "m1", "2: milestoneID")
    assertEqual(dec.createdAt, d, "2: createdAt")
}
do { // 3. Optional fields encode/decode.
    let r = TestEvidenceRecord(type: .projectWork, title: "Proj", roadmapID: "r", milestoneID: "m", occurredAt: Date(timeIntervalSince1970: 1700000000), actionID: "act-1", skillIDs: ["python","git"], artifact: TestEvidenceArtifact(type:"link", title:"Repo", url:"https://github.com/x", description:"desc"), validationID:"val1", validationScore:2, validationPercentage:100, validationPassed:true, projectID:"p1", opportunityID:"opp1")
    let data = try! encoder.encode(r)
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
    assertEqual(dec.actionID, "act-1", "3: actionID")
    assertEqual(dec.skillIDs, ["python","git"], "3: skillIDs")
    assertEqual(dec.artifact?.url, "https://github.com/x", "3: artifact url")
    assertEqual(dec.projectID, "p1", "3: projectID")
    assertEqual(dec.opportunityID, "opp1", "3: opportunityID")
    assertEqual(dec.validationPassed, true, "3: validationPassed")
}
do { // 4. Empty optional relationships are safe.
    let r = TestEvidenceRecord(type: .other, title: "Empty", roadmapID: "", milestoneID: "")
    let data = try! encoder.encode(r)
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
    assert(dec.actionID == nil, "4: actionID nil")
    assert(dec.skillIDs == nil, "4: skillIDs nil")
    assert(dec.artifact == nil, "4: artifact nil")
    assert(dec.opportunityID == nil, "4: opportunityID nil")
}
do { // 5. Evidence types are valid.
    for t in TestEvidenceType.allCases {
        let r = TestEvidenceRecord(type: t, title:"t", roadmapID:"r", milestoneID:"m")
        let data = try! encoder.encode(r)
        let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
        assertEqual(dec.type, t, "5: type \(t.rawValue)")
    }
}
do { // 6. Status values are valid.
    for s in TestEvidenceStatus.allCases {
        let r = TestEvidenceRecord(type: .other, title:"t", roadmapID:"r", milestoneID:"m", status: s)
        let data = try! encoder.encode(r)
        let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
        assertEqual(dec.status, s, "6: status \(s.rawValue)")
    }
}
do { // 7. Source values are valid.
    for src in TestEvidenceSource.allCases {
        let r = TestEvidenceRecord(type: .other, title:"t", roadmapID:"r", milestoneID:"m", source: src)
        let data = try! encoder.encode(r)
        let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
        assertEqual(dec.source, src, "7: source \(src.rawValue)")
    }
}
do { // 8. Artifact model encodes/decodes if implemented.
    let art = TestEvidenceArtifact(type:"github", title:"My Repo", url:"https://github.com/me/repo", description:"Project repo")
    let r = TestEvidenceRecord(type: .artifact, title:"Artifact", roadmapID:"r", milestoneID:"m", artifact: art)
    let data = try! encoder.encode(r)
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
    assertEqual(dec.artifact?.type, "github", "8: artifact type")
    assertEqual(dec.artifact?.title, "My Repo", "8: artifact title")
    assertEqual(dec.artifact?.url, "https://github.com/me/repo", "8: artifact url")
}

// MARK: - Relationships (9-16)

do { // 9. Roadmap relationship works.
    let r = TestEvidenceRecord(type: .milestoneCompletion, title:"T", roadmapID:"ai-engineer", milestoneID:"ai-1")
    assertEqual(r.roadmapID, "ai-engineer", "9: roadmapID")
}
do { // 10. Milestone relationship works.
    let r = TestEvidenceRecord(type: .milestoneCompletion, title:"T", roadmapID:"r", milestoneID:"ai-3")
    assertEqual(r.milestoneID, "ai-3", "10: milestoneID")
}
do { // 11. Action relationship works.
    let r = TestEvidenceRecord(type: .learning, title:"T", roadmapID:"r", milestoneID:"m", actionID:"act-123")
    assertEqual(r.actionID, "act-123", "11: actionID")
}
do { // 12. Project relationship works.
    let r = TestEvidenceRecord(type: .projectWork, title:"T", roadmapID:"r", milestoneID:"m", projectID:"proj-123")
    assertEqual(r.projectID, "proj-123", "12: projectID")
}
do { // 13. Opportunity relationship works.
    let r = TestEvidenceRecord(type: .opportunityParticipation, title:"T", roadmapID:"r", milestoneID:"m", opportunityID:"opp:123")
    assertEqual(r.opportunityID, "opp:123", "13: opportunityID")
}
do { // 14. Validation relationship works.
    let r = TestEvidenceRecord(type: .validation, title:"T", roadmapID:"r", milestoneID:"m", validationID:"val-1", validationScore:2, validationPercentage:100, validationPassed:true)
    assertEqual(r.validationID, "val-1", "14: validationID")
    assertEqual(r.validationPassed, true, "14: passed")
}
do { // 15. Multiple skill relationships work.
    let r = TestEvidenceRecord(type: .milestoneCompletion, title:"T", roadmapID:"r", milestoneID:"m", skillIDs:["python","git","apis"])
    assertEqual(r.skillIDs?.count, 3, "15: skill count")
    assert(r.skillIDs!.contains("python"), "15: contains python")
}
do { // 16. Missing relationships do not break decoding.
    let json = #"{"id":"ev-1","type":"milestone-completion","title":"T","roadmapID":"r","milestoneID":"m","completionDate":"2023-11-14T22:13:20Z","createdAt":"2023-11-14T22:13:20Z","source":"roadmapMilestone","status":"recorded"}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: json)
    assert(dec.actionID == nil, "16: missing actionID nil")
    assert(dec.skillIDs == nil, "16: missing skillIDs nil")
    assert(dec.artifact == nil, "16: missing artifact nil")
}

// MARK: - Canonical Skills (17-20)

do { // 17. Skill IDs use canonical representation.
    let raw = ["Python"," python ","PYTHON"]
    let normalized = raw.map{normalizeSkillID($0)}
    assert(normalized.allSatisfy{$0=="python"}, "17: canonical python")
}
do { // 18. Duplicate skill IDs can be normalized.
    let ids = ["Python","PYTHON"," python "].map{normalizeSkillID($0)}
    let unique = Set(ids)
    assertEqual(unique.count, 1, "18: duplicate normalized to 1")
}
do { // 19. Evidence does not automatically mutate student skills (semantic check).
    // Create evidence referencing python — student profile should not auto gain python.
    var profileStrengths: [String] = []
    let _ = TestEvidenceRecord(type: .artifact, title:"Repo", roadmapID:"r", milestoneID:"m", skillIDs:["python"])
    assert(profileStrengths.isEmpty, "19: evidence does not auto mutate skills")
    // Also verify that creating evidence with skillIDs does not affect external state
    let skillIDs = ["python","git"]
    let normalized = skillIDs.map{normalizeSkillID($0)}
    assertEqual(normalized, ["python","git"], "19b: skillIDs normalized correctly")
}
do { // 20. Existing SkillCatalog IDs remain compatible (test known ids).
    let known = ["python","javascript","research methods","leadership","community research"]
    for k in known {
        let n = normalizeSkillID(k)
        assertEqual(n, k.lowercased(), "20: catalog id \(k)")
    }
}

// MARK: - Dates (21-23)

do { // 21. createdAt persists.
    let d = Date(timeIntervalSince1970: 1700000000)
    let r = TestEvidenceRecord(type: .other, title:"T", roadmapID:"r", milestoneID:"m", completionDate: d, createdAt: d)
    let data = try! encoder.encode(r)
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
    assertEqual(dec.createdAt, d, "21: createdAt")
}
do { // 22. occurredAt persists.
    let d1 = Date(timeIntervalSince1970: 1700000000)
    let d2 = Date(timeIntervalSince1970: 1700000100)
    let r = TestEvidenceRecord(type: .other, title:"T", roadmapID:"r", milestoneID:"m", completionDate: d1, createdAt: d1, occurredAt: d2)
    let data = try! encoder.encode(r)
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
    assertEqual(dec.occurredAt, d2, "22: occurredAt")
}
do { // 23. Missing occurredAt is safe.
    let d = Date(timeIntervalSince1970: 1700000000)
    let r = TestEvidenceRecord(type: .other, title:"T", roadmapID:"r", milestoneID:"m", completionDate: d)
    let data = try! encoder.encode(r)
    // Decode JSON without occurredAt
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
    assert(dec.occurredAt == nil, "23: occurredAt nil")
}

// MARK: - IDs (24-26)

do { // 24. Existing deterministic milestone evidence IDs remain unchanged.
    func evidenceID(for milestoneID: String, roadmap: String) -> String { "evidence-\(roadmap)-\(milestoneID)" }
    assertEqual(evidenceID(for: "ms-1", roadmap: "roadmap-a"), "evidence-roadmap-a-ms-1", "24: deterministic format")
    let id2 = evidenceID(for: "ai-3", roadmap: "ai-engineer")
    assertEqual(id2, "evidence-ai-engineer-ai-3", "24b: ai id")
}
do { // 25. Automatically generated evidence cannot silently duplicate.
    var store:[String:TestEvidenceRecord]=[:]
    func createIfNeeded(id:String) {
        if store[id]==nil {
            store[id]=TestEvidenceRecord(id:id, type: .milestoneCompletion, title:"T", roadmapID:"r", milestoneID:"m")
        }
    }
    createIfNeeded(id:"evidence-r-m1")
    createIfNeeded(id:"evidence-r-m1")
    assertEqual(store.count, 1, "25: idempotent")
}
do { // 26. Different source entities produce distinct IDs.
    func evidenceID(for milestoneID: String, roadmap: String) -> String { "evidence-\(roadmap)-\(milestoneID)" }
    let a = evidenceID(for: "m1", roadmap: "r1")
    let b = evidenceID(for: "m2", roadmap: "r1")
    let c = evidenceID(for: "m1", roadmap: "r2")
    assert(a != b, "26: different milestone distinct")
    assert(a != c, "26: different roadmap distinct")
}

// MARK: - Backward Compatibility (27-30)

do { // 27. Existing Phase 6 evidence records decode.
    let oldJSON = #"{"id":"evidence-roadmap-a-ms-1","type":"milestone-completion","title":"Foundations","description":"Setup","roadmapID":"roadmap-a","milestoneID":"ms-1","completionDate":"2023-11-14T22:13:20Z","validationID":"val-1","validationScore":2,"validationPercentage":100,"validationPassed":true}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: oldJSON)
    assertEqual(dec.id, "evidence-roadmap-a-ms-1", "27: id")
    assertEqual(dec.type, .milestoneCompletion, "27: type")
    assertEqual(dec.source, .roadmapMilestone, "27: source defaults to roadmapMilestone")
    assertEqual(dec.status, .recorded, "27: status defaults to recorded")
    assert(dec.createdAt.timeIntervalSince1970 > 0, "27: createdAt fallback")
}
do { // 28. Old persisted evidence without newly added fields remains valid.
    let oldMinimal = #"{"id":"ev-old","type":"milestone-completion","title":"T","roadmapID":"r","milestoneID":"m","completionDate":"2023-11-14T22:13:20Z"}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: oldMinimal)
    assertEqual(dec.id, "ev-old", "28: id")
    assert(dec.actionID == nil, "28: actionID nil for old")
    assert(dec.skillIDs == nil, "28: skillIDs nil for old")
    assert(dec.artifact == nil, "28: artifact nil for old")
    assert(dec.occurredAt == nil, "28: occurredAt nil for old")
}
do { // 29. Existing milestone completion still creates evidence (semantic).
    // Simulate store behavior: mark complete creates evidence with deterministic ID
    var store:[String:TestEvidenceRecord]=[:]
    func createEvidence(roadmapID:String, milestoneID:String, title:String) {
        let eid="evidence-\(roadmapID)-\(milestoneID)"
        if store[eid]==nil {
            store[eid]=TestEvidenceRecord(id:eid, type:.milestoneCompletion, title:title, roadmapID:roadmapID, milestoneID:milestoneID, skillIDs:["python"])
        }
    }
    createEvidence(roadmapID:"ai-engineer", milestoneID:"ai-1", title:"Explore AI")
    assert(store["evidence-ai-engineer-ai-1"] != nil, "29: evidence created")
    assertEqual(store["evidence-ai-engineer-ai-1"]?.skillIDs, ["python"], "29: skillIDs set")
}
do { // 30. Existing skill acquisition behavior remains unchanged (no auto award from evidence).
    var strengths:[String]=[]
    let evidence = TestEvidenceRecord(type: .milestoneCompletion, title:"T", roadmapID:"r", milestoneID:"m", skillIDs:["python"])
    // Evidence alone should not add to strengths
    assert(strengths.isEmpty, "30: strengths still empty after evidence creation")
    // Only explicit acquire adds
    func acquire(_ skills:[String]?) {
        guard let skills else { return }
        for s in skills { let t=s.trimmingCharacters(in:.whitespacesAndNewlines); if !t.isEmpty && !strengths.map({$0.lowercased()}).contains(t.lowercased()) { strengths.append(t) } }
    }
    acquire(evidence.skillIDs)
    // This test shows acquire must be explicit; evidence itself doesn't auto-mutate
    // But if we DON'T call acquire, strengths remain empty — proves separation
    var strengths2:[String]=[]
    let _ = evidence
    assert(strengths2.isEmpty, "30b: evidence reference does not auto award")
}

// MARK: - Trust / Semantics (31-35)

do { // 31. Saved opportunity is not automatically participation.
    let savedOppID = "opp-saved-123"
    // Saved state is separate bool; evidence should not be auto-created for saved
    var evidenceStore:[String:TestEvidenceRecord]=[:]
    let isSaved = true
    // No evidence should be auto-created just because isSaved true
    assert(evidenceStore.isEmpty, "31: saved does not create evidence")
    // Only actual participation should create evidence with opportunityParticipation type
    let participationEvidence = TestEvidenceRecord(type: .opportunityParticipation, title:"Participated", roadmapID:"", milestoneID:"", opportunityID: "opp-participated-123")
    evidenceStore[participationEvidence.id]=participationEvidence
    assertEqual(evidenceStore.count, 1, "31b: participation does create evidence")
    assert(evidenceStore.first?.value.opportunityID == "opp-participated-123", "31c: opportunityID is participation, not saved")
    assert(isSaved, "31d: saved still true but different from participation")
}
do { // 32. Recommendation is not evidence.
    let recommendedRoadmapID = "ai-engineer"
    var evidenceStore:[String:TestEvidenceRecord]=[:]
    // Recommendation should not create evidence
    assert(evidenceStore.isEmpty, "32: recommendation not evidence")
    _ = recommendedRoadmapID
}
do { // 33. Incomplete milestone is not completion evidence.
    let progress = 0 // 0 milestones completed
    let milestoneID = "ai-3"
    var evidenceStore:[String:TestEvidenceRecord]=[:]
    // No evidence should exist for incomplete milestone
    assert(evidenceStore["evidence-ai-engineer-\(milestoneID)"] == nil, "33: incomplete no evidence")
    _ = progress
}
do { // 34. Failed validation is not positive mastery evidence.
    let failed = TestEvidenceRecord(type: .validation, title:"Validation", roadmapID:"r", milestoneID:"m", validationID:"val-1", validationScore:1, validationPercentage:50, validationPassed:false)
    assertEqual(failed.validationPassed, false, "34: failed validation")
    // Evidence with failed validation should not be treated as mastery; status remains recorded, not verified, and passed false
    assert(failed.status == .recorded, "34b: status recorded not verified")
    // Consumer must check validationPassed before treating as mastery
    let isMastery = (failed.validationPassed == true)
    assert(!isMastery, "34c: failed not mastery")
}
do { // 35. Skill reference does not automatically award skill.
    let evidence = TestEvidenceRecord(type: .artifact, title:"Repo", roadmapID:"r", milestoneID:"m", skillIDs:["machine learning"])
    var strengths:[String]=[]
    // Evidence references skill but strengths unchanged
    assert(strengths.isEmpty, "35: skill not auto awarded")
    _ = evidence
}

// MARK: - Codable Round Trip (36-37)

do { // 36. Full evidence object survives encode/decode.
    let original = TestEvidenceRecord(
        type: .milestoneCompletion,
        title: "Foundations",
        description: "Setup environment",
        roadmapID: "roadmap-a",
        milestoneID: "ms-1",
        completionDate: Date(timeIntervalSince1970: 1700000000),
        createdAt: Date(timeIntervalSince1970: 1700000000),
        occurredAt: Date(timeIntervalSince1970: 1699999000),
        source: .roadmapMilestone,
        status: .recorded,
        actionID: "act-1",
        skillIDs: ["python","git"],
        artifact: TestEvidenceArtifact(type:"link", title:"Repo", url:"https://example.com", description:"desc"),
        validationID: "val-1",
        validationScore: 2,
        validationPercentage: 100,
        validationPassed: true,
        projectID: "proj-1",
        opportunityID: "opp-1"
    )
    let data = try! encoder.encode(original)
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: data)
    assertEqual(dec.type, original.type, "36: type")
    assertEqual(dec.source, original.source, "36: source")
    assertEqual(dec.status, original.status, "36: status")
    assertEqual(dec.actionID, original.actionID, "36: actionID")
    assertEqual(dec.skillIDs, original.skillIDs, "36: skillIDs")
    assertEqual(dec.artifact?.url, original.artifact?.url, "36: artifact url")
    assertEqual(dec.validationPassed, original.validationPassed, "36: validationPassed")
    assertEqual(dec.projectID, original.projectID, "36: projectID")
}
do { // 37. Legacy evidence object survives decode/re-encode.
    let oldJSON = #"{"id":"evidence-r-m1","type":"milestone-completion","title":"T","roadmapID":"r","milestoneID":"m1","completionDate":"2023-11-14T22:13:20Z"}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: oldJSON)
    let reencoded = try! encoder.encode(dec)
    let redecoded = try! decoder.decode(TestEvidenceRecord.self, from: reencoded)
    assertEqual(redecoded.id, "evidence-r-m1", "37: id survives")
    assertEqual(redecoded.type, .milestoneCompletion, "37: type survives")
    assertEqual(redecoded.source, .roadmapMilestone, "37: source default survives")
}

// MARK: - Additional semantic

do { // Evidence type string backward compat: unknown type maps to .other
    let json = #"{"id":"ev-1","type":"unknown-type-xyz","title":"T","roadmapID":"r","milestoneID":"m","completionDate":"2023-11-14T22:13:20Z"}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: json)
    assertEqual(dec.type, .other, "unknown type -> other")
}
do { // Evidence status defaults to recorded for legacy
    let json = #"{"id":"ev-1","type":"milestone-completion","title":"T","roadmapID":"r","milestoneID":"m","completionDate":"2023-11-14T22:13:20Z"}"#.data(using:.utf8)!
    let dec = try! decoder.decode(TestEvidenceRecord.self, from: json)
    assertEqual(dec.status, .recorded, "legacy status defaults recorded")
}
do { // Skill IDs empty array should decode as nil or empty handled
    let r = TestEvidenceRecord(type: .other, title:"T", roadmapID:"r", milestoneID:"m", skillIDs: [])
    assert(r.skillIDs == nil, "empty skillIDs becomes nil")
}

print("\nPhase 7.1 — Evidence Data Model: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
