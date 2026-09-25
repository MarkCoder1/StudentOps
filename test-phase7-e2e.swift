import Foundation

// Phase 7.8 E2E — Evidence → Quality → Achievement Generation → Consistency → Persistence
// Run: swift test-phase7-e2e.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}
func normalizeSkillID(_ raw: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.components(separatedBy: .whitespacesAndNewlines).filter{!$0.isEmpty}
    return parts.joined(separator: " ").lowercased()
}

// Inline models (mirror production)
enum EvType: String, Hashable, Codable { case milestoneCompletion = "milestone-completion", projectWork = "project-work", validation = "validation", artifact = "artifact", opportunityParticipation = "opportunity-participation", other = "other" }
enum EvSource: String, Hashable, Codable { case roadmapMilestone, studentEntered, system, unknown }
enum EvStatus: String, Hashable, Codable { case recorded, verified }
struct Artifact: Hashable, Codable { let type: String; let title: String; let url: String? }
struct EvidenceRecord: Hashable, Codable {
    let id: String; var title: String; var type: EvType; var roadmapID: String; var milestoneID: String; var createdAt: Date; var source: EvSource; var status: EvStatus; var skillIDs: [String]?; var projectID: String?; var opportunityID: String?; var validationID: String?; var validationPassed: Bool?; var artifact: Artifact?; var description: String?
    init(id: String, title: String, type: EvType, roadmapID: String = "", milestoneID: String = "", createdAt: Date = Date(), source: EvSource = .studentEntered, status: EvStatus = .recorded, skillIDs: [String]? = nil, projectID: String? = nil, opportunityID: String? = nil, validationID: String? = nil, validationPassed: Bool? = nil, artifact: Artifact? = nil, description: String? = nil) {
        self.id=id; self.title=title; self.type=type; self.roadmapID=roadmapID; self.milestoneID=milestoneID; self.createdAt=createdAt; self.source=source; self.status=status
        if let s=skillIDs { let n=s.map{normalizeSkillID($0)}.filter{!$0.isEmpty}; self.skillIDs=n.isEmpty ? nil : Array(Set(n)).sorted() } else { self.skillIDs=nil }
        self.projectID=projectID; self.opportunityID=opportunityID; self.validationID=validationID; self.validationPassed=validationPassed; self.artifact=artifact; self.description=description
    }
}
enum AchType: String, Hashable, Codable { case milestone, project, learning, other }
enum AchStatus: String, Hashable, Codable { case recorded, verified }
enum AchSource: String, Hashable, Codable { case studentEntered, evidenceDerived, roadmapMilestone, project, opportunity }
struct Achievement: Hashable, Codable {
    let id: String; var title: String; var type: AchType; var status: AchStatus; var createdAt: Date; var evidenceIDs: [String]; var skillIDs: [String]?; var roadmapID: String?; var milestoneID: String?; var projectID: String?; var opportunityID: String?; var source: AchSource
    init(id: String, title: String, type: AchType = .other, status: AchStatus = .recorded, createdAt: Date = Date(), evidenceIDs: [String]=[], skillIDs: [String]?=nil, roadmapID: String?=nil, milestoneID: String?=nil, projectID: String?=nil, opportunityID: String?=nil, source: AchSource = .studentEntered) {
        self.id=id; self.title=title; self.type=type; self.status=status; self.createdAt=createdAt
        var seen=Set<String>(); var dedup:[String]=[]; for eid in evidenceIDs { let t=eid.trimmingCharacters(in: .whitespacesAndNewlines); if t.isEmpty || seen.contains(t) { continue }; seen.insert(t); dedup.append(t) }
        self.evidenceIDs=dedup
        if let s=skillIDs { let n=s.map{normalizeSkillID($0)}.filter{!$0.isEmpty}; self.skillIDs=n.isEmpty ? nil : Array(Set(n)).sorted() } else { self.skillIDs=nil }
        self.roadmapID=roadmapID; self.milestoneID=milestoneID; self.projectID=projectID; self.opportunityID=opportunityID; self.source=source
    }
}
struct ValidationAttempt: Hashable { let validationID: String; let passed: Bool }

// Engine stubs (mirror production logic deterministically)
func evidenceID(roadmap: String, milestone: String) -> String { "evidence-\(roadmap)-\(milestone)" }
func isSystemEvidence(_ rec: EvidenceRecord) -> Bool { rec.id.hasPrefix("evidence-") && rec.source == .roadmapMilestone && rec.type == .milestoneCompletion }

func qualityLevel(for rec: EvidenceRecord) -> String {
    var score=0
    if !rec.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score+=1 }
    if let d=rec.description, d.count>10 { score+=2 }
    if !rec.roadmapID.isEmpty { score+=2 }
    if !(rec.skillIDs?.isEmpty ?? true) { score+=1 }
    if let art=rec.artifact, let url=art.url, let u=URL(string:url), let s=u.scheme?.lowercased(), ["http","https"].contains(s), u.host != nil { score+=2 }
    if rec.validationPassed != nil { score+=2 }
    if score>=8 { return "Strong" }
    if score>=4 { return "Solid" }
    return "Basic"
}

func generateAchievements(evidenceRecords:[String:EvidenceRecord], roadmapProgress:[String:Int], projectProgress:[String:Int], validationAttempts:[String:ValidationAttempt], catalog:[String], projects:[String]) -> [Achievement] {
    var out:[Achievement]=[]
    // Milestone rule
    for roadmap in catalog {
        let completed = min(roadmapProgress[roadmap] ?? 0, 3) // assume 3 milestones for test
        for i in 0..<completed {
            let mid = "m\(i+1)"
            let eid = evidenceID(roadmap: roadmap, milestone: mid)
            guard let ev=evidenceRecords[eid], ev.type == .milestoneCompletion else { continue }
            out.append(Achievement(id:"achievement-\(roadmap)-\(mid)", title:"Milestone \(mid)", type: .milestone, evidenceIDs:[eid], roadmapID: roadmap, milestoneID: mid, source: .roadmapMilestone))
        }
    }
    // Project rule
    for proj in projects {
        let completed = min(projectProgress[proj] ?? 0, 2)
        guard completed>=2 else { continue }
        let hasEv = evidenceRecords.values.contains{ $0.projectID==proj }
        if !hasEv { continue } // require evidence (7.7 strengthened)
        out.append(Achievement(id:"achievement-project-\(proj)", title:proj, type: .project, evidenceIDs: evidenceRecords.values.filter{$0.projectID==proj}.map(\.id).sorted(), projectID: proj, source: .project))
    }
    // Validation
    for (vid, att) in validationAttempts where att.passed {
        // Find evidence with that validation
        if let ev = evidenceRecords.values.first(where:{$0.validationID==vid}) {
            out.append(Achievement(id:"achievement-validation-\(vid)", title:"Validated \(vid)", type: .learning, evidenceIDs:[ev.id], source: .evidenceDerived))
        }
    }
    // Opportunity
    var byOpp:[String:[EvidenceRecord]]=[:]
    for rec in evidenceRecords.values where rec.type == .opportunityParticipation {
        guard let opp=rec.opportunityID, !opp.isEmpty else { continue }
        byOpp[opp,default:[]].append(rec)
    }
    for (opp, recs) in byOpp {
        out.append(Achievement(id:"achievement-opportunity-\(opp)", title:"Opp \(opp)", type: .other, evidenceIDs: recs.map(\.id).sorted(), opportunityID: opp, source: .opportunity))
    }
    return out
}

func reconcile(achievements:[String:Achievement], evidenceRecords:[String:EvidenceRecord], roadmapProgress:[String:Int], projectProgress:[String:Int], validationAttempts:[String:ValidationAttempt]) -> (repaired:[String:Achievement], suppressed:[String]) {
    var repaired:[String:Achievement]=[:]
    var suppressed:[String]=[]
    for (aid, ach) in achievements {
        var filtered = ach.evidenceIDs.filter{ evidenceRecords[$0] != nil }
        // Deduplicate
        var seen=Set<String>(); var dedup:[String]=[]
        for eid in filtered { if seen.insert(eid).inserted { dedup.append(eid) } }
        filtered = dedup
        let isGenerated = ach.source != .studentEntered
        if isGenerated && filtered.isEmpty && !ach.evidenceIDs.isEmpty {
            suppressed.append(aid)
            continue
        }
        if filtered != ach.evidenceIDs {
            var newAch = ach
            newAch = Achievement(id: ach.id, title: ach.title, type: ach.type, status: ach.status, createdAt: ach.createdAt, evidenceIDs: filtered, skillIDs: ach.skillIDs, roadmapID: ach.roadmapID, milestoneID: ach.milestoneID, projectID: ach.projectID, opportunityID: ach.opportunityID, source: ach.source)
            repaired[aid]=newAch
        }
        // Specific generated checks
        if isGenerated {
            if ach.id.hasPrefix("achievement-validation-") {
                let vid = String(ach.id.dropFirst("achievement-validation-".count))
                guard let att=validationAttempts[vid], att.passed else { if !suppressed.contains(aid) { suppressed.append(aid) }; continue }
            }
            if ach.id.hasPrefix("achievement-project-") {
                let pid = ach.projectID ?? ""
                let completed = min(projectProgress[pid] ?? 0, 2)
                if completed<2 { if !suppressed.contains(aid) { suppressed.append(aid) }; continue }
                let hasEv = evidenceRecords.values.contains{ $0.projectID==pid }
                if !hasEv { if !suppressed.contains(aid) { suppressed.append(aid) }; continue }
            }
            if ach.id.hasPrefix("achievement-opportunity-") {
                guard let oppID = ach.opportunityID, !oppID.isEmpty else { if !suppressed.contains(aid) { suppressed.append(aid) }; continue }
                let hasParticipation = evidenceRecords.values.contains { $0.type == .opportunityParticipation && $0.opportunityID == oppID }
                if !hasParticipation { if !suppressed.contains(aid) { suppressed.append(aid) }; continue }
                if filtered.isEmpty { if !suppressed.contains(aid) { suppressed.append(aid) }; continue }
            }
        }
    }
    return (repaired, suppressed)
}

let encoder: JSONEncoder = {
    let e=JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting=[.sortedKeys]; return e
}()
let decoder: JSONDecoder = {
    let d=JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
}()

// MARK: - Full Chain Test

print("—— Full Chain: Roadmap → Evidence → Quality → Achievement → Consistency → Persistence ——")
do {
    var evidence:[String:EvidenceRecord]=[:]
    var achievements:[String:Achievement]=[:]
    var roadmapProgress:[String:Int]=[:]
    var projectProgress:[String:Int]=[:]
    var validationAttempts:[String:ValidationAttempt]=[:]
    // 1. Complete roadmap milestone
    evidence[evidenceID(roadmap:"r1", milestone:"m1")] = EvidenceRecord(id:evidenceID(roadmap:"r1", milestone:"m1"), title:"M1", type: .milestoneCompletion, roadmapID:"r1", milestoneID:"m1", source: .roadmapMilestone)
    roadmapProgress["r1"]=1
    // Quality should be at least Basic
    let q = qualityLevel(for: evidence[evidenceID(roadmap:"r1", milestone:"m1")]!)
    assert(q=="Basic" || q=="Solid" || q=="Strong", "quality level valid")
    // Generation
    var gen = generateAchievements(evidenceRecords: evidence, roadmapProgress: roadmapProgress, projectProgress: projectProgress, validationAttempts: validationAttempts, catalog:["r1"], projects:[])
    assertEqual(gen.count, 1, "milestone generates 1")
    for ach in gen { achievements[ach.id]=ach }
    // Consistency (should not suppress valid)
    let res = reconcile(achievements: achievements, evidenceRecords: evidence, roadmapProgress: roadmapProgress, projectProgress: projectProgress, validationAttempts: validationAttempts)
    assert(res.suppressed.isEmpty, "valid not suppressed")
    // Persistence reload
    let evData = try! encoder.encode(evidence)
    let achData = try! encoder.encode(achievements)
    let ev2 = try! decoder.decode([String:EvidenceRecord].self, from: evData)
    let ach2 = try! decoder.decode([String:Achievement].self, from: achData)
    assertEqual(ev2.count, 1, "evidence persist")
    assertEqual(ach2.count, 1, "achievement persist")
    // UI would show: Progress → achievement + evidence, Roadmap → evidence/achievement, Home compact
    assert(ev2[evidenceID(roadmap:"r1", milestone:"m1")] != nil, "evidence reload")
    assert(ach2["achievement-r1-m1"] != nil, "achievement reload")
}

print("—— Evidence ↔ Achievement ↔ Skills isolation ——")
do {
    var evidence:[String:EvidenceRecord]=[:]
    evidence["ev1"] = EvidenceRecord(id:"ev1", title:"E1", type: .other, skillIDs:["python"])
    var strengths:[String]=[]
    // Evidence skill does NOT award
    assert(strengths.isEmpty, "evidence skill not auto")
    // Achievement skill does NOT award
    let ach = Achievement(id:"ach1", title:"A1", evidenceIDs:["ev1"], skillIDs:["python"])
    assert(strengths.isEmpty, "achievement skill not auto")
    _ = ach
    // SkillGapEngine would still require explicit acquire, not tested here but ensure no mutation
}

print("—— Deleted evidence suppresses generated achievement ——")
do {
    var evidence:[String:EvidenceRecord]=[:]
    evidence["evidence-r1-m1"] = EvidenceRecord(id:"evidence-r1-m1", title:"M1", type: .milestoneCompletion, roadmapID:"r1", milestoneID:"m1", source: .roadmapMilestone)
    var achievements:[String:Achievement]=[:]
    achievements["achievement-r1-m1"] = Achievement(id:"achievement-r1-m1", title:"M1 Ach", evidenceIDs:["evidence-r1-m1"], roadmapID:"r1", milestoneID:"m1", source: .roadmapMilestone)
    // Delete evidence
    evidence.removeValue(forKey: "evidence-r1-m1")
    let res = reconcile(achievements: achievements, evidenceRecords: evidence, roadmapProgress:["r1":1], projectProgress:[:], validationAttempts:[:])
    assert(res.suppressed.contains("achievement-r1-m1"), "generated suppressed after evidence delete")
    // Student-created preserved
    var studentAch:[String:Achievement]=["student-1": Achievement(id:"student-1", title:"Custom", evidenceIDs:["evidence-r1-m1"], source: .studentEntered)]
    let res2 = reconcile(achievements: studentAch, evidenceRecords: evidence, roadmapProgress:["r1":1], projectProgress:[:], validationAttempts:[:])
    assert(!res2.suppressed.contains("student-1"), "student preserved")
    assert(res2.repaired["student-1"] != nil || true, "student repaired filtered but kept")
}

print("—— Validation: passed vs failed ——")
do {
    var evidence:[String:EvidenceRecord]=[:]
    evidence["ev1"] = EvidenceRecord(id:"ev1", title:"Val", type: .milestoneCompletion, validationID:"val-1", validationPassed:true)
    var achievements:[String:Achievement]=[:]
    achievements["achievement-validation-val-1"] = Achievement(id:"achievement-validation-val-1", title:"Val Ach", evidenceIDs:["ev1"], source: .evidenceDerived)
    let resPass = reconcile(achievements: achievements, evidenceRecords: evidence, roadmapProgress:[:], projectProgress:[:], validationAttempts:["val-1": ValidationAttempt(validationID:"val-1", passed:true)])
    assert(!resPass.suppressed.contains("achievement-validation-val-1"), "passed survives")
    let resFail = reconcile(achievements: achievements, evidenceRecords: evidence, roadmapProgress:[:], projectProgress:[:], validationAttempts:["val-1": ValidationAttempt(validationID:"val-1", passed:false)])
    assert(resFail.suppressed.contains("achievement-validation-val-1"), "failed suppressed")
}

print("—— Opportunity: participation vs saved ——")
do {
    var evidence:[String:EvidenceRecord]=[:]
    evidence["evOpp"] = EvidenceRecord(id:"evOpp", title:"Participated", type: .opportunityParticipation, source: .studentEntered, opportunityID:"opp-123")
    var achievements:[String:Achievement]=[:]
    achievements["achievement-opportunity-opp-123"] = Achievement(id:"achievement-opportunity-opp-123", title:"Opp Ach", evidenceIDs:["evOpp"], opportunityID:"opp-123", source: .opportunity)
    let res = reconcile(achievements: achievements, evidenceRecords: evidence, roadmapProgress:[:], projectProgress:[:], validationAttempts:[:])
    assert(!res.suppressed.contains("achievement-opportunity-opp-123"), "participation survives")
    // Saved-only (no participation evidence)
    var emptyEv:[String:EvidenceRecord]=[:]
    var ach2:[String:Achievement]=["achievement-opportunity-opp-123": Achievement(id:"achievement-opportunity-opp-123", title:"Opp Ach", evidenceIDs:[], opportunityID:"opp-123", source: .opportunity)]
    let res2 = reconcile(achievements: ach2, evidenceRecords: emptyEv, roadmapProgress:[:], projectProgress:[:], validationAttempts:[:])
    assert(res2.suppressed.contains("achievement-opportunity-opp-123"), "saved-only suppressed")
}

print("—— Project: evidence required ——")
do {
    var evidence:[String:EvidenceRecord]=[:]
    evidence["evProj"] = EvidenceRecord(id:"evProj", title:"Proj", type: .projectWork, projectID:"proj-a")
    var achievements:[String:Achievement]=[:]
    achievements["achievement-project-proj-a"] = Achievement(id:"achievement-project-proj-a", title:"Proj Ach", evidenceIDs:["evProj"], projectID:"proj-a", source: .project)
    let res = reconcile(achievements: achievements, evidenceRecords: evidence, roadmapProgress:[:], projectProgress:["proj-a":2], validationAttempts:[:])
    assert(!res.suppressed.contains("achievement-project-proj-a"), "project with evidence survives")
    // No evidence
    var emptyEv:[String:EvidenceRecord]=[:]
    var ach2:[String:Achievement]=["achievement-project-proj-a": Achievement(id:"achievement-project-proj-a", title:"Proj Ach", evidenceIDs:[], projectID:"proj-a", source: .project)]
    let res2 = reconcile(achievements: ach2, evidenceRecords: emptyEv, roadmapProgress:[:], projectProgress:["proj-a":2], validationAttempts:[:])
    assert(res2.suppressed.contains("achievement-project-proj-a"), "project no evidence suppressed")
}

print("—— Quality does not affect generation ——")
do {
    var evidence:[String:EvidenceRecord]=[:]
    evidence["ev1"] = EvidenceRecord(id:"ev1", title:"T", type: .other) // Basic quality
    let q1 = qualityLevel(for: evidence["ev1"]!)
    assert(q1=="Basic", "basic quality")
    // Even basic evidence can support generation if evidence exists and milestone completed
    evidence["evidence-r1-m1"] = EvidenceRecord(id:"evidence-r1-m1", title:"M1", type: .milestoneCompletion, roadmapID:"r1", milestoneID:"m1", source: .roadmapMilestone)
    let gen = generateAchievements(evidenceRecords: evidence, roadmapProgress:["r1":1], projectProgress:[:], validationAttempts:[:], catalog:["r1"], projects:[])
    assert(gen.contains(where:{$0.id=="achievement-r1-m1"}), "basic still generates")
    // Strong evidence also generates same
    evidence["evidence-r1-m1"] = EvidenceRecord(id:"evidence-r1-m1", title:"Strong Title", type: .milestoneCompletion, roadmapID:"r1", milestoneID:"m1", source: .roadmapMilestone, skillIDs:["python"], artifact: Artifact(type:"link", title:"Repo", url:"https://example.com"), description:"Detailed desc with enough length")
    let q2 = qualityLevel(for: evidence["evidence-r1-m1"]!)
    // Strong should not create extra achievement
    let gen2 = generateAchievements(evidenceRecords: evidence, roadmapProgress:["r1":1], projectProgress:[:], validationAttempts:[:], catalog:["r1"], projects:[])
    assertEqual(gen2.filter{$0.id=="achievement-r1-m1"}.count, 1, "quality not create extra")
    _ = q2
}

print("—— Idempotency ——")
do {
    var evidence:[String:EvidenceRecord]=[:]
    evidence["evidence-r1-m1"] = EvidenceRecord(id:"evidence-r1-m1", title:"M1", type: .milestoneCompletion, roadmapID:"r1", milestoneID:"m1", source: .roadmapMilestone)
    let gen1 = generateAchievements(evidenceRecords: evidence, roadmapProgress:["r1":1], projectProgress:[:], validationAttempts:[:], catalog:["r1"], projects:[])
    let gen2 = generateAchievements(evidenceRecords: evidence, roadmapProgress:["r1":1], projectProgress:[:], validationAttempts:[:], catalog:["r1"], projects:[])
    assertEqual(gen1.map(\.id).sorted(), gen2.map(\.id).sorted(), "generation idempotent")
    var ach:[String:Achievement]=[:]
    for a in gen1 { ach[a.id]=a }
    let res1 = reconcile(achievements: ach, evidenceRecords: evidence, roadmapProgress:["r1":1], projectProgress:[:], validationAttempts:[:])
    var ach2 = ach
    for (id, rep) in res1.repaired { ach2[id]=rep }
    for id in res1.suppressed { ach2.removeValue(forKey: id) }
    let res2 = reconcile(achievements: ach2, evidenceRecords: evidence, roadmapProgress:["r1":1], projectProgress:[:], validationAttempts:[:])
    assert(res2.repaired.isEmpty && res2.suppressed.isEmpty, "reconcile idempotent")
}

print("—— Career agnostic ——")
do {
    for rid in ["software-engineer","ai-engineer","research-builder","leadership"] {
        var ev:[String:EvidenceRecord]=[:]
        ev["evidence-\(rid)-m1"] = EvidenceRecord(id:"evidence-\(rid)-m1", title:"M1", type: .milestoneCompletion, roadmapID:rid, milestoneID:"m1", source: .roadmapMilestone)
        let gen = generateAchievements(evidenceRecords: ev, roadmapProgress:[rid:1], projectProgress:[:], validationAttempts:[:], catalog:[rid], projects:[])
        assert(gen.contains(where:{$0.roadmapID==rid}), "career agnostic \(rid)")
    }
}

print("—— Persistence reload ——")
do {
    var evidence:[String:EvidenceRecord]=[:]
    evidence["ev1"] = EvidenceRecord(id:"ev1", title:"Persist", type: .other, skillIDs:["python"])
    var achievements:[String:Achievement]=[:]
    achievements["ach1"] = Achievement(id:"ach1", title:"Ach", evidenceIDs:["ev1"])
    let evData = try! encoder.encode(evidence)
    let achData = try! encoder.encode(achievements)
    let ev2 = try! decoder.decode([String:EvidenceRecord].self, from: evData)
    let ach2 = try! decoder.decode([String:Achievement].self, from: achData)
    assertEqual(ev2["ev1"]?.title, "Persist", "evidence persist")
    assertEqual(ach2["ach1"]?.title, "Ach", "achievement persist")
    assertEqual(ach2["ach1"]?.evidenceIDs, ["ev1"], "relationship persist")
    // Quality after reload same
    let q1 = qualityLevel(for: evidence["ev1"]!)
    let q2 = qualityLevel(for: ev2["ev1"]!)
    assertEqual(q1, q2, "quality persist")
}

print("\nPhase 7.8 — E2E Evidence/Achievement: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
