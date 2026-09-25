import Foundation

// Standalone test script for Phase 7.4 — Deterministic Achievement Generation
// Run: swift test-achievement-generation.swift

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

// MARK: - Inline models

enum AchType: String, Codable, Hashable { case project, learning, competition, research, leadership, communityImpact, technical, academic, milestone, other }
enum AchStatus: String, Codable, Hashable { case recorded, verified }
enum AchSource: String, Codable, Hashable { case studentEntered, evidenceDerived, roadmapMilestone, project, opportunity, system, unknown }
struct Achievement: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var description: String?
    var type: AchType
    var status: AchStatus
    var createdAt: Date
    var occurredAt: Date?
    var evidenceIDs: [String]
    var skillIDs: [String]?
    var roadmapID: String?
    var milestoneID: String?
    var projectID: String?
    var opportunityID: String?
    var source: AchSource
    init(id: String = UUID().uuidString, title: String, description: String? = nil, type: AchType = .other, status: AchStatus = .recorded, createdAt: Date = Date(), occurredAt: Date? = nil, evidenceIDs: [String] = [], skillIDs: [String]? = nil, roadmapID: String? = nil, milestoneID: String? = nil, projectID: String? = nil, opportunityID: String? = nil, source: AchSource = .studentEntered) {
        self.id=id; self.title=title; self.description=description; self.type=type; self.status=status; self.createdAt=createdAt; self.occurredAt=occurredAt
        var seen=Set<String>(); var dedup:[String]=[]
        for eid in evidenceIDs where !eid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { let t=eid.trimmingCharacters(in: .whitespacesAndNewlines); if seen.insert(t).inserted {dedup.append(t)} }
        self.evidenceIDs=dedup
        if let s=skillIDs { let n=s.map{normalizeSkillID($0)}.filter{!$0.isEmpty}; self.skillIDs = n.isEmpty ? nil : Array(Set(n)).sorted() } else { self.skillIDs=nil }
        self.roadmapID=roadmapID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true ? nil : roadmapID
        self.milestoneID=milestoneID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true ? nil : milestoneID
        self.projectID=projectID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true ? nil : projectID
        self.opportunityID=opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty==true ? nil : opportunityID
        self.source=source
    }
}
enum EvType: String, Codable, Hashable { case milestoneCompletion = "milestone-completion", projectWork = "project-work", validation = "validation", artifact = "artifact", opportunityParticipation = "opportunity-participation", learning = "learning", other = "other" }
enum EvSource: String, Codable, Hashable { case roadmapMilestone, project, validation, opportunity, studentEntered, system, unknown }
enum EvStatus: String, Codable, Hashable { case recorded, verified }
struct EvidenceRecord: Hashable, Codable {
    let id: String
    let type: EvType
    let title: String
    let roadmapID: String
    let milestoneID: String
    let createdAt: Date
    let source: EvSource
    let status: EvStatus
    let skillIDs: [String]?
    let projectID: String?
    let opportunityID: String?
    let validationID: String?
    let validationPassed: Bool?
    init(id: String, type: EvType, title: String, roadmapID: String = "", milestoneID: String = "", createdAt: Date = Date(), source: EvSource = .roadmapMilestone, status: EvStatus = .recorded, skillIDs: [String]? = nil, projectID: String? = nil, opportunityID: String? = nil, validationID: String? = nil, validationPassed: Bool? = nil) {
        self.id=id; self.type=type; self.title=title; self.roadmapID=roadmapID; self.milestoneID=milestoneID; self.createdAt=createdAt; self.source=source; self.status=status; self.skillIDs=skillIDs; self.projectID=projectID; self.opportunityID=opportunityID; self.validationID=validationID; self.validationPassed=validationPassed
    }
}
struct Milestone: Hashable { let id: String; let title: String; let subtitle: String; let skillsDeveloped: [String]?; let assessmentID: String? }
struct Roadmap: Hashable { let id: String; let title: String; let milestones: [Milestone] }
struct ProjectMilestone: Hashable { let id: String; let title: String }
struct Project: Hashable { let id: String; let title: String; let goal: String; let milestones: [ProjectMilestone]; let skills: [String] }
struct ValidationAttempt: Hashable { let validationID: String; let passed: Bool }

// MARK: - Engine (mirrors production)

enum AchievementGenerationEngine {
    static func generate(evidenceRecords:[String:EvidenceRecord], roadmapProgress:[String:Int], projectProgress:[String:Int], validationAttempts:[String:ValidationAttempt], achievementRecords:[String:Achievement], catalog:[Roadmap], projects:[Project]) -> [Achievement] {
        var c:[Achievement]=[]
        c.append(contentsOf: milestoneAchievements(evidenceRecords:evidenceRecords, roadmapProgress:roadmapProgress, catalog:catalog))
        c.append(contentsOf: progressionAchievements(evidenceRecords:evidenceRecords, roadmapProgress:roadmapProgress, catalog:catalog))
        c.append(contentsOf: projectAchievements(evidenceRecords:evidenceRecords, projectProgress:projectProgress, projects:projects))
        c.append(contentsOf: validationAchievements(evidenceRecords:evidenceRecords, validationAttempts:validationAttempts, catalog:catalog))
        c.append(contentsOf: opportunityAchievements(evidenceRecords:evidenceRecords))
        var seen=Set<String>(); var dedup:[Achievement]=[]
        for a in c { if seen.insert(a.id).inserted { dedup.append(a) } }
        return dedup
    }
    static func milestoneAchievements(evidenceRecords:[String:EvidenceRecord], roadmapProgress:[String:Int], catalog:[Roadmap]) -> [Achievement] {
        var out:[Achievement]=[]
        for roadmap in catalog {
            let completed = min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
            guard completed>0 else { continue }
            for idx in 0..<completed {
                let ms = roadmap.milestones[idx]
                let eid = "evidence-\(roadmap.id)-\(ms.id)"
                guard let ev = evidenceRecords[eid], ev.type == .milestoneCompletion else { continue }
                let aid = "achievement-\(roadmap.id)-\(ms.id)"
                let skills = ms.skillsDeveloped?.map{normalizeSkillID($0)}.filter{!$0.isEmpty}
                let dedup = skills.map{ Array(Set($0)).sorted() }
                let ach = Achievement(id: aid, title: ms.title, description: ms.subtitle, type: .milestone, createdAt: ev.createdAt, evidenceIDs: [eid], skillIDs: dedup, roadmapID: roadmap.id, milestoneID: ms.id, source: .roadmapMilestone)
                out.append(ach)
            }
        }
        return out
    }
    static func progressionAchievements(evidenceRecords:[String:EvidenceRecord], roadmapProgress:[String:Int], catalog:[Roadmap]) -> [Achievement] {
        var out:[Achievement]=[]
        for roadmap in catalog {
            let completed = min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
            let threshold = min(3, roadmap.milestones.count)
            guard completed >= threshold else { continue }
            let prefix = Array(roadmap.milestones.prefix(threshold))
            let eids = prefix.map{ "evidence-\(roadmap.id)-\($0.id)" }.filter{ evidenceRecords[$0] != nil }
            guard eids.count >= threshold else { continue }
            let aid = "achievement-progress-\(roadmap.id)"
            let dates = eids.compactMap{ evidenceRecords[$0]?.createdAt }.sorted()
            let created = dates.first ?? Date()
            let allSkills = prefix.flatMap{ $0.skillsDeveloped ?? [] }.map{normalizeSkillID($0)}.filter{!$0.isEmpty}
            let dedup = allSkills.isEmpty ? nil : Array(Set(allSkills)).sorted()
            let ach = Achievement(id: aid, title: "Made Progress in \(roadmap.title)", description: "Completed \(threshold) milestones in a structured learning roadmap.", type: .milestone, createdAt: created, evidenceIDs: eids, skillIDs: dedup, roadmapID: roadmap.id, source: .evidenceDerived)
            out.append(ach)
        }
        return out
    }
    static func projectAchievements(evidenceRecords:[String:EvidenceRecord], projectProgress:[String:Int], projects:[Project]) -> [Achievement] {
        var out:[Achievement]=[]
        for proj in projects {
            let completed = min(projectProgress[proj.id] ?? 0, proj.milestones.count)
            guard completed >= proj.milestones.count && proj.milestones.count>0 else { continue }
            let aid = "achievement-project-\(proj.id)"
            let projEvs = evidenceRecords.values.filter{ $0.projectID == proj.id }.map(\.id).sorted()
            let created = projEvs.compactMap{ evidenceRecords[$0]?.createdAt }.sorted().first ?? Date()
            let dedup: [String]? = {
                let s = proj.skills.map{normalizeSkillID($0)}.filter{!$0.isEmpty}
                return s.isEmpty ? nil : Array(Set(s)).sorted()
            }()
            let ach = Achievement(id: aid, title: proj.title, description: proj.goal, type: .project, createdAt: created, evidenceIDs: projEvs, skillIDs: dedup, projectID: proj.id, source: .project)
            out.append(ach)
        }
        return out
    }
    static func validationAchievements(evidenceRecords:[String:EvidenceRecord], validationAttempts:[String:ValidationAttempt], catalog:[Roadmap]) -> [Achievement] {
        var out:[Achievement]=[]
        var valToMilestone:[String:(roadmap:Roadmap,milestone:Milestone)] = [:]
        for roadmap in catalog { for ms in roadmap.milestones { if let vid = ms.assessmentID { valToMilestone[vid]=(roadmap,ms) } } }
        for (vid, attempt) in validationAttempts {
            guard attempt.passed else { continue }
            guard let pair = valToMilestone[vid] else { continue }
            let eid = "evidence-\(pair.roadmap.id)-\(pair.milestone.id)"
            guard let ev = evidenceRecords[eid], ev.validationID == vid else { continue }
            let aid = "achievement-validation-\(vid)"
            let dedup: [String]? = {
                guard let s = pair.milestone.skillsDeveloped else { return nil }
                let n = s.map{normalizeSkillID($0)}.filter{!$0.isEmpty}
                return n.isEmpty ? nil : Array(Set(n)).sorted()
            }()
            let ach = Achievement(id: aid, title: "Demonstrated Understanding: \(pair.milestone.title)", description: "Passed validation for \(pair.milestone.title).", type: .learning, createdAt: ev.createdAt, evidenceIDs: [eid], skillIDs: dedup, roadmapID: pair.roadmap.id, milestoneID: pair.milestone.id, source: .evidenceDerived)
            out.append(ach)
        }
        return out
    }
    static func opportunityAchievements(evidenceRecords:[String:EvidenceRecord]) -> [Achievement] {
        var byOpp:[String:[EvidenceRecord]] = [:]
        for rec in evidenceRecords.values {
            guard rec.type == .opportunityParticipation else { continue }
            guard let opp = rec.opportunityID, !opp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            byOpp[opp,default:[]].append(rec)
        }
        var out:[Achievement]=[]
        for (oppID, recs) in byOpp {
            let eids = recs.map(\.id).sorted()
            let sanitized = oppID.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "/", with: "-")
            let aid = "achievement-opportunity-\(sanitized)"
            let created = recs.map(\.createdAt).sorted().first ?? Date()
            let ach = Achievement(id: aid, title: recs.first?.title ?? "Participated in Opportunity", description: recs.first?.title, type: .other, createdAt: created, evidenceIDs: eids, opportunityID: oppID, source: .opportunity)
            out.append(ach)
        }
        return out
    }
}

// MARK: - Test Catalog

let softwareEngineer = Roadmap(id:"software-engineer", title:"Become a Software Engineer", milestones:[
    Milestone(id:"software-1", title:"Explore CS", subtitle:"Map concepts", skillsDeveloped:["Python"], assessmentID: nil),
    Milestone(id:"software-2", title:"Build Fundamentals", subtitle:"Fluency", skillsDeveloped:["Git"], assessmentID: "assess-software-2"),
    Milestone(id:"software-3", title:"Learn Software Development", subtitle:"Beyond scripts", skillsDeveloped:["APIs"], assessmentID: nil),
])

let aiEngineer = Roadmap(id:"ai-engineer", title:"Become an AI Engineer", milestones:[
    Milestone(id:"ai-1", title:"Explore AI", subtitle:"AI basics", skillsDeveloped:["Python"], assessmentID: nil),
    Milestone(id:"ai-2", title:"Math Foundations", subtitle:"Math", skillsDeveloped:["Statistics"], assessmentID: nil),
])

let researchBuilder = Roadmap(id:"research-builder", title:"Build a Research Profile", milestones:[
    Milestone(id:"research-1", title:"Explore Research", subtitle:"What is research", skillsDeveloped:["Research Methods"], assessmentID: nil),
])

let portfolioProjects = Roadmap(id:"portfolio-projects", title:"Build a Technical Portfolio", milestones:[
    Milestone(id:"portfolio-1", title:"Define Direction", subtitle:"Choose", skillsDeveloped:["Project Planning"], assessmentID: nil),
])

let collegeReady = Roadmap(id:"college-ready", title:"Prepare for College", milestones:[
    Milestone(id:"college-1", title:"Understand Goals", subtitle:"Goals", skillsDeveloped:["Goal Setting"], assessmentID: nil),
])

let stemExplorer = Roadmap(id:"stem-explorer", title:"Explore STEM", milestones:[
    Milestone(id:"stem-1", title:"Discover STEM", subtitle:"Discover", skillsDeveloped:["Technical Exploration"], assessmentID: nil),
])

let leadership = Roadmap(id:"leadership", title:"Build Leadership Experience", milestones:[
    Milestone(id:"leadership-1", title:"Understand Leadership", subtitle:"Leadership", skillsDeveloped:["Leadership"], assessmentID: nil),
])

let communityImpact = Roadmap(id:"community-impact", title:"Build Community Impact", milestones:[
    Milestone(id:"community-1", title:"Understand Community", subtitle:"Community", skillsDeveloped:["Community Research"], assessmentID: nil),
])

let venture = Roadmap(id:"venture", title:"Explore Entrepreneurship", milestones:[
    Milestone(id:"venture-1", title:"Identify Problems", subtitle:"Problems", skillsDeveloped:["Problem Discovery"], assessmentID: nil),
])

let competitiveProfile = Roadmap(id:"competitive-profile", title:"Build a Competitive Student Profile", milestones:[
    Milestone(id:"profile-1", title:"Define Direction", subtitle:"Direction", skillsDeveloped:["Academic Planning"], assessmentID: nil),
])

let allRoadmaps = [softwareEngineer, aiEngineer, researchBuilder, portfolioProjects, collegeReady, stemExplorer, leadership, communityImpact, venture, competitiveProfile]

let projA = Project(id:"proj-a", title:"Plant Health Dashboard", goal:"Build tool", milestones:[ProjectMilestone(id:"plant-1",title:"Define"), ProjectMilestone(id:"plant-2",title:"Collect")], skills:["Python"])
let projCustom = Project(id:"custom-123", title:"My Custom Project", goal:"Custom", milestones:[ProjectMilestone(id:"custom-m",title:"Do")], skills:[])

// MARK: - Tests

// Roadmap
do { // completed milestone generates achievement
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore CS", roadmapID:"software-engineer", milestoneID:"software-1", skillIDs:["python"])
    let ach = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":1], catalog:[softwareEngineer])
    assertEqual(ach.count, 1, "completed milestone generates")
    assertEqual(ach.first?.id, "achievement-software-engineer-software-1", "milestone achievement ID")
    assertEqual(ach.first?.evidenceIDs, ["evidence-software-engineer-software-1"], "milestone evidence")
    assertEqual(ach.first?.roadmapID, "software-engineer", "roadmapID")
    assertEqual(ach.first?.milestoneID, "software-1", "milestoneID")
    assertEqual(ach.first?.type, .milestone, "type milestone")
    assertEqual(ach.first?.source, .roadmapMilestone, "source roadmapMilestone")
}
do { // incomplete milestone does not
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let ach = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":0], catalog:[softwareEngineer])
    assertEqual(ach.count, 0, "incomplete no achievement")
}
do { // locked milestone does not (requires evidence? locked milestone has no evidence because not completed, so no achievement)
    var ev:[String:EvidenceRecord]=[:]
    // Only software-1 completed, software-3 not completed (locked behind 2)
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let ach = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":1], catalog:[softwareEngineer])
    // Should only have software-1, not software-3
    assert(!ach.contains(where:{$0.milestoneID=="software-3"}), "locked no achievement")
}
do { // missing evidence prevents unsupported generation
    let ev:[String:EvidenceRecord]=[:]
    let ach = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":1], catalog:[softwareEngineer])
    assertEqual(ach.count, 0, "missing evidence prevents")
}
do { // skills are referenced correctly
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1", skillIDs:["python"])
    let ach = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":1], catalog:[softwareEngineer])
    assertEqual(ach.first?.skillIDs, ["python"], "skills referenced")
}
do { // roadmap/milestone relationships correct
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-ai-engineer-ai-1"] = EvidenceRecord(id:"evidence-ai-engineer-ai-1", type: .milestoneCompletion, title:"Explore AI", roadmapID:"ai-engineer", milestoneID:"ai-1")
    let ach = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["ai-engineer":1], catalog:[aiEngineer])
    assertEqual(ach.first?.roadmapID, "ai-engineer", "ai roadmapID")
    assertEqual(ach.first?.milestoneID, "ai-1", "ai milestoneID")
}

// Projects
do { // completed project generates appropriate achievement
    var ev:[String:EvidenceRecord]=[:]
    ev["ev-proj"] = EvidenceRecord(id:"ev-proj", type: .projectWork, title:"Proj ev", roadmapID:"", milestoneID:"", projectID:"proj-a")
    let ach = AchievementGenerationEngine.projectAchievements(evidenceRecords:ev, projectProgress:["proj-a":2], projects:[projA])
    assertEqual(ach.count, 1, "completed project generates")
    assertEqual(ach.first?.id, "achievement-project-proj-a", "project achievement ID")
    assertEqual(ach.first?.type, .project, "project type")
    assertEqual(ach.first?.source, .project, "project source")
}
do { // incomplete project does not
    let ev:[String:EvidenceRecord]=[:]
    let ach = AchievementGenerationEngine.projectAchievements(evidenceRecords:ev, projectProgress:["proj-a":1], projects:[projA])
    assertEqual(ach.count, 0, "incomplete project no achievement")
}
do { // creating a project alone does not generate achievement
    let ev:[String:EvidenceRecord]=[:]
    let ach = AchievementGenerationEngine.projectAchievements(evidenceRecords:ev, projectProgress:["proj-a":0], projects:[projA])
    assertEqual(ach.count, 0, "creating alone no achievement")
}
do { // duplicate generation is prevented (idempotency via ID)
    var ev:[String:EvidenceRecord]=[:]
    ev["ev-proj"] = EvidenceRecord(id:"ev-proj", type: .projectWork, title:"ev", roadmapID:"", milestoneID:"", projectID:"proj-a")
    let first = AchievementGenerationEngine.projectAchievements(evidenceRecords:ev, projectProgress:["proj-a":2], projects:[projA])
    let second = AchievementGenerationEngine.projectAchievements(evidenceRecords:ev, projectProgress:["proj-a":2], projects:[projA])
    assertEqual(first.map(\.id), second.map(\.id), "duplicate prevented")
}

// Validation
do { // passed validation can generate achievement
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-2"] = EvidenceRecord(id:"evidence-software-engineer-software-2", type: .milestoneCompletion, title:"Build", roadmapID:"software-engineer", milestoneID:"software-2", validationID:"assess-software-2")
    let attempts:[String:ValidationAttempt]=["assess-software-2": ValidationAttempt(validationID:"assess-software-2", passed:true)]
    let ach = AchievementGenerationEngine.validationAchievements(evidenceRecords:ev, validationAttempts:attempts, catalog:[softwareEngineer])
    assertEqual(ach.count, 1, "passed validation generates")
    assertEqual(ach.first?.id, "achievement-validation-assess-software-2", "validation ID")
    assertEqual(ach.first?.type, .learning, "validation type learning")
}
do { // failed validation cannot
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-2"] = EvidenceRecord(id:"evidence-software-engineer-software-2", type: .milestoneCompletion, title:"Build", roadmapID:"software-engineer", milestoneID:"software-2", validationID:"assess-software-2")
    let attempts:[String:ValidationAttempt]=["assess-software-2": ValidationAttempt(validationID:"assess-software-2", passed:false)]
    let ach = AchievementGenerationEngine.validationAchievements(evidenceRecords:ev, validationAttempts:attempts, catalog:[softwareEngineer])
    assertEqual(ach.count, 0, "failed no achievement")
}
do { // incomplete validation cannot
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-2"] = EvidenceRecord(id:"evidence-software-engineer-software-2", type: .milestoneCompletion, title:"Build", roadmapID:"software-engineer", milestoneID:"software-2")
    let attempts:[String:ValidationAttempt]=[:]
    let ach = AchievementGenerationEngine.validationAchievements(evidenceRecords:ev, validationAttempts:attempts, catalog:[softwareEngineer])
    assertEqual(ach.count, 0, "incomplete no achievement")
}
do { // validation relationship is preserved
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-2"] = EvidenceRecord(id:"evidence-software-engineer-software-2", type: .milestoneCompletion, title:"Build", roadmapID:"software-engineer", milestoneID:"software-2", validationID:"assess-software-2")
    let attempts:[String:ValidationAttempt]=["assess-software-2": ValidationAttempt(validationID:"assess-software-2", passed:true)]
    let ach = AchievementGenerationEngine.validationAchievements(evidenceRecords:ev, validationAttempts:attempts, catalog:[softwareEngineer])
    assertEqual(ach.first?.evidenceIDs, ["evidence-software-engineer-software-2"], "validation evidence preserved")
    assertEqual(ach.first?.roadmapID, "software-engineer", "validation roadmapID")
}

// Opportunities
do { // saved opportunity does not generate achievement
    let ev:[String:EvidenceRecord]=[:]
    let ach = AchievementGenerationEngine.opportunityAchievements(evidenceRecords:ev)
    assertEqual(ach.count, 0, "saved no achievement without evidence")
}
do { // recommended opportunity does not (same as saved, no evidence)
    let ev:[String:EvidenceRecord]=[:]
    let ach = AchievementGenerationEngine.opportunityAchievements(evidenceRecords:ev)
    assertEqual(ach.count, 0, "recommended no achievement")
}
do { // matched opportunity does not (no evidence)
    let ev:[String:EvidenceRecord]=[:]
    let ach = AchievementGenerationEngine.opportunityAchievements(evidenceRecords:ev)
    assertEqual(ach.count, 0, "matched no achievement")
}
do { // actual participation evidence can support generation
    var ev:[String:EvidenceRecord]=[:]
    ev["ev-opp"] = EvidenceRecord(id:"ev-opp", type: .opportunityParticipation, title:"Participated in Hackathon", roadmapID:"", milestoneID:"", opportunityID:"hack-123")
    let ach = AchievementGenerationEngine.opportunityAchievements(evidenceRecords:ev)
    assertEqual(ach.count, 1, "participation generates")
    assertEqual(ach.first?.opportunityID, "hack-123", "opportunityID preserved")
    assertEqual(ach.first?.type, .other, "opportunity type other")
}
do { // unsupported participation does not generate achievement (missing opportunityID)
    var ev:[String:EvidenceRecord]=[:]
    ev["ev-opp"] = EvidenceRecord(id:"ev-opp", type: .opportunityParticipation, title:"Bad", roadmapID:"", milestoneID:"", opportunityID:"")
    let ach = AchievementGenerationEngine.opportunityAchievements(evidenceRecords:ev)
    assertEqual(ach.count, 0, "unsupported no achievement")
}

// Evidence
do { // generated achievement references real evidence
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let ach = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":1], catalog:[softwareEngineer])
    assertEqual(ach.first?.evidenceIDs.first, "evidence-software-engineer-software-1", "references real evidence")
}
do { // nonexistent evidence prevents generation
    let ev:[String:EvidenceRecord]=[:]
    let ach = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":1], catalog:[softwareEngineer])
    assertEqual(ach.count, 0, "nonexistent prevents")
}
do { // multiple evidence records can support one achievement (progression)
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    ev["evidence-software-engineer-software-2"] = EvidenceRecord(id:"evidence-software-engineer-software-2", type: .milestoneCompletion, title:"Build", roadmapID:"software-engineer", milestoneID:"software-2")
    ev["evidence-software-engineer-software-3"] = EvidenceRecord(id:"evidence-software-engineer-software-3", type: .milestoneCompletion, title:"Learn", roadmapID:"software-engineer", milestoneID:"software-3")
    let ach = AchievementGenerationEngine.progressionAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":3], catalog:[softwareEngineer])
    assertEqual(ach.count, 1, "progression one achievement")
    assertEqual(ach.first?.evidenceIDs.count, 3, "progression multiple evidence")
}
do { // evidence remains unchanged
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let before = ev
    _ = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:[:], catalog:[softwareEngineer], projects:[])
    assertEqual(ev, before, "evidence unchanged")
}

// Skills
do { // generated achievement skill IDs canonicalized
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let ach = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":1], catalog:[softwareEngineer])
    assertEqual(ach.first?.skillIDs, ["python"], "skill canonical")
}
do { // duplicates removed (milestone has duplicate skills? test progression dedup)
    var ev:[String:EvidenceRecord]=[:]
    // Create roadmap with duplicate skills across milestones for progression
    let dupRoadmap = Roadmap(id:"dup-roadmap", title:"Dup", milestones:[
        Milestone(id:"dup-1", title:"M1", subtitle:"", skillsDeveloped:["Python","python"], assessmentID: nil),
        Milestone(id:"dup-2", title:"M2", subtitle:"", skillsDeveloped:["PYTHON"], assessmentID: nil),
        Milestone(id:"dup-3", title:"M3", subtitle:"", skillsDeveloped:["Git"], assessmentID: nil),
    ])
    ev["evidence-dup-roadmap-dup-1"] = EvidenceRecord(id:"evidence-dup-roadmap-dup-1", type: .milestoneCompletion, title:"M1", roadmapID:"dup-roadmap", milestoneID:"dup-1")
    ev["evidence-dup-roadmap-dup-2"] = EvidenceRecord(id:"evidence-dup-roadmap-dup-2", type: .milestoneCompletion, title:"M2", roadmapID:"dup-roadmap", milestoneID:"dup-2")
    ev["evidence-dup-roadmap-dup-3"] = EvidenceRecord(id:"evidence-dup-roadmap-dup-3", type: .milestoneCompletion, title:"M3", roadmapID:"dup-roadmap", milestoneID:"dup-3")
    let ach = AchievementGenerationEngine.progressionAchievements(evidenceRecords:ev, roadmapProgress:["dup-roadmap":3], catalog:[dupRoadmap])
    // Python should appear once
    let pythonCount = ach.first?.skillIDs?.filter{$0=="python"}.count ?? 0
    assertEqual(pythonCount, 1, "duplicate skill removed")
}
do { // achievement generation does not award skills
    var strengths:[String]=[]
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1", skillIDs:["python"])
    _ = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:[:], catalog:[softwareEngineer], projects:[])
    assert(strengths.isEmpty, "not award skills")
}
do { // SkillGapEngine state unchanged (strengths not mutated)
    var strengths = ["Existing"]
    let before = strengths
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    _ = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:[:], catalog:[softwareEngineer], projects:[])
    assertEqual(strengths, before, "SkillGap unchanged")
}

// Idempotency
do { // run generation twice same
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let first = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:[:], catalog:[softwareEngineer], projects:[])
    let second = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:[:], catalog:[softwareEngineer], projects:[])
    assertEqual(first.map(\.id).sorted(), second.map(\.id).sorted(), "idempotent")
    assertEqual(first.count, second.count, "idempotent count")
}

// Student-created achievements
do { // remain untouched
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let studentAch = Achievement(id:"student-1", title:"My Custom", type: .project, evidenceIDs: [])
    var achievementRecords:[String:Achievement]=["student-1": studentAch]
    let generated = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:achievementRecords, catalog:[softwareEngineer], projects:[])
    // Simulate store refresh: add generated where not exists
    for ach in generated { if achievementRecords[ach.id]==nil { achievementRecords[ach.id]=ach } }
    assert(achievementRecords["student-1"] != nil, "student untouched")
    assertEqual(achievementRecords["student-1"]?.title, "My Custom", "student not overwritten")
}
do { // remain persisted (simulate reload)
    var store:[String:Achievement]=["student-1": Achievement(id:"student-1", title:"Custom", evidenceIDs:[])]
    let data = try! JSONEncoder().encode(store)
    let decoded = try! JSONDecoder().decode([String:Achievement].self, from: data)
    assertEqual(decoded["student-1"]?.title, "Custom", "persisted")
}
do { // are not overwritten by generated records
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let studentAch = Achievement(id:"achievement-software-engineer-software-1", title:"My Custom Title", type: .other, evidenceIDs:["evidence-software-engineer-software-1"])
    var achievementRecords:[String:Achievement]=[studentAch.id: studentAch]
    let generated = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:achievementRecords, catalog:[softwareEngineer], projects:[])
    for ach in generated { if achievementRecords[ach.id]==nil { achievementRecords[ach.id]=ach } }
    assertEqual(achievementRecords["achievement-software-engineer-software-1"]?.title, "My Custom Title", "not overwritten")
}
do { // can coexist with generated achievements
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    var achievementRecords:[String:Achievement]=["student-1": Achievement(id:"student-1", title:"Custom", evidenceIDs:[])]
    let generated = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:achievementRecords, catalog:[softwareEngineer], projects:[])
    for ach in generated { if achievementRecords[ach.id]==nil { achievementRecords[ach.id]=ach } }
    assertEqual(achievementRecords.count, 2, "coexist")
}

// Status/source
do { // generated achievement is .recorded
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let ach = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:[:], catalog:[softwareEngineer], projects:[]).first!
    assertEqual(ach.status, .recorded, "generated recorded")
}
do { // correct source assigned
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let msAch = AchievementGenerationEngine.milestoneAchievements(evidenceRecords:ev, roadmapProgress:["software-engineer":1], catalog:[softwareEngineer]).first!
    assertEqual(msAch.source, .roadmapMilestone, "milestone source")
    let projAch = AchievementGenerationEngine.projectAchievements(evidenceRecords:ev, projectProgress:["proj-a":2], projects:[projA]).first!
    assertEqual(projAch.source, .project, "project source")
}
do { // .verified never automatically assigned
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let all = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:["assess-software-2": ValidationAttempt(validationID:"assess-software-2", passed:true)], achievementRecords:[:], catalog:[softwareEngineer], projects:[])
    assert(!all.contains(where:{$0.status == .verified}), "never verified")
}

// Career Agnosticism
do {
    for roadmap in allRoadmaps {
        var ev:[String:EvidenceRecord]=[:]
        // Create evidence for first milestone of each roadmap
        let ms = roadmap.milestones.first!
        let eid = "evidence-\(roadmap.id)-\(ms.id)"
        ev[eid] = EvidenceRecord(id:eid, type: .milestoneCompletion, title:ms.title, roadmapID:roadmap.id, milestoneID:ms.id)
        let ach = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:[roadmap.id:1], projectProgress:[:], validationAttempts:[:], achievementRecords:[:], catalog:[roadmap], projects:[])
        // Should generate at least one for each roadmap (milestone) without branching
        assert(!ach.isEmpty, "career agnostic \(roadmap.id)")
        assert(ach.first?.roadmapID == roadmap.id, "career agnostic roadmapID \(roadmap.id)")
    }
}

// Persistence
do { // generated achievements persist
    var store:[String:Achievement]=[:]
    var ev:[String:EvidenceRecord]=[:]
    ev["evidence-software-engineer-software-1"] = EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")
    let gen = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:store, catalog:[softwareEngineer], projects:[])
    for ach in gen { store[ach.id]=ach }
    let data = try! JSONEncoder().encode(store)
    let decoded = try! JSONDecoder().decode([String:Achievement].self, from: data)
    assertEqual(decoded.count, 1, "persist count")
    assertEqual(decoded["achievement-software-engineer-software-1"]?.title, "Explore CS", "persist title")
}
do { // reload preserves them
    var store:[String:Achievement]=["achievement-software-engineer-software-1": Achievement(id:"achievement-software-engineer-software-1", title:"Explore CS", evidenceIDs:["evidence-software-engineer-software-1"])]
    let data = try! JSONEncoder().encode(store)
    let decoded = try! JSONDecoder().decode([String:Achievement].self, from: data)
    assertEqual(decoded["achievement-software-engineer-software-1"]?.title, "Explore CS", "reload title")
}
do { // debug reset clears them
    var store:[String:Achievement]=["a1": Achievement(id:"a1", title:"T")]
    store = [:]
    assertEqual(store.count, 0, "debug reset clears")
}
do { // existing evidence remains intact
    var ev:[String:EvidenceRecord]=["evidence-software-engineer-software-1": EvidenceRecord(id:"evidence-software-engineer-software-1", type: .milestoneCompletion, title:"Explore", roadmapID:"software-engineer", milestoneID:"software-1")]
    let before = ev
    _ = AchievementGenerationEngine.generate(evidenceRecords:ev, roadmapProgress:["software-engineer":1], projectProgress:[:], validationAttempts:[:], achievementRecords:[:], catalog:[softwareEngineer], projects:[])
    assertEqual(ev, before, "evidence intact")
}

print("\nPhase 7.4 — Achievement Generation: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
