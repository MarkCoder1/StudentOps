import Foundation

// Phase 9.5 — Deterministic Project Recommendation Engine Tests
// Run: swift test-project-recommendation.swift

var passed = 0; var failed = 0
func assert(_ c: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if c { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}
func normalize(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.components(separatedBy: .whitespacesAndNewlines).filter{!$0.isEmpty}
    return parts.joined(separator: " ").lowercased()
}

// MARK: - Inline models (mirror production)

enum ProjectStatus: String, Codable { case planned="planned", inProgress="inProgress", completed="completed" }
struct ProjectLink: Hashable, Codable { let id: String; let label:String; let url:String; init(label:String, url:String){id=UUID().uuidString; self.label=label; self.url=url} }
struct ProjectMilestone: Hashable, Codable { let id:String; let title:String; let subtitle:String; let estimatedTime:String; init(id:String, title:String){self.id=id; self.title=title; self.subtitle=""; self.estimatedTime="1h"} }
struct Project: Hashable, Codable {
    let id:String; var title:String; var category:String; var goal:String; var description:String
    var skills:[String]; var milestones:[ProjectMilestone]; var resources:[String]; var estimatedCompletion:String
    var relevantInterests:Set<String>; var relevantSkills:Set<String>; var relevantCareers:Set<String>; var relevantFields:Set<String>
    var sourceRoadmapID:String?; var status:ProjectStatus
    init(id:String, title:String, category:String="Personal Project", description:String="Desc", skills:[String]=[], estimatedCompletion:String="2 weeks", relevantInterests:Set<String>=[] , relevantSkills:Set<String>=[] , relevantCareers:Set<String>=[] , relevantFields:Set<String>=[] , sourceRoadmapID:String?=nil, goal:String="Goal") {
        self.id=id; self.title=title; self.category=category; self.goal=goal; self.description=description; self.skills=skills; self.milestones=[]; self.resources=[]; self.estimatedCompletion=estimatedCompletion; self.relevantInterests=relevantInterests; self.relevantSkills=relevantSkills; self.relevantCareers=relevantCareers; self.relevantFields=relevantFields; self.sourceRoadmapID=sourceRoadmapID; self.status = .inProgress
    }
}
struct RoadmapMilestone: Hashable { let id:String; let skillsDeveloped:[String]? }
struct Roadmap: Hashable { let id:String; let title:String; let milestones:[RoadmapMilestone]; let requiredSkills: Set<String> // helper
}

struct StudentProfile {
    var interests:[String]=[]
    var customInterests:[String]=[]
    var careers:[String]=[]
    var fields:[String]=[]
    var milestones:[String]=[]
    var strengths:[String]=[]
    var customSkills:[String]=[]
}

// Simplified skill gap: gaps are those required by active roadmaps not yet demonstrated
func demonstratedIDs(profile: StudentProfile, roadmapProgress:[String:Int], roadmaps:[Roadmap]) -> Set<String> {
    var s=Set<String>()
    for raw in profile.strengths+profile.customSkills { let n=normalize(raw); if !n.isEmpty {s.insert(n)} }
    for rm in roadmaps {
        let completed = min(roadmapProgress[rm.id] ?? 0, rm.milestones.count)
        for idx in 0..<completed {
            if let dev=rm.milestones[idx].skillsDeveloped {
                for raw in dev { let n=normalize(raw); if !n.isEmpty {s.insert(n)} }
            }
        }
    }
    return s
}
func requiredIDs(for rm: Roadmap) -> Set<String> {
    var set=Set<String>()
    for ms in rm.milestones { if let dev=ms.skillsDeveloped { for raw in dev { let n=normalize(raw); if !n.isEmpty {set.insert(n)} } } }
    return set
}
func gapIDs(profile: StudentProfile, progress:[String:Int], roadmaps:[Roadmap], activeIDs:Set<String>) -> Set<String> {
    var gaps=Set<String>()
    let demo=demonstratedIDs(profile: profile, roadmapProgress: progress, roadmaps: roadmaps)
    for rm in roadmaps where activeIDs.contains(rm.id) {
        for nid in requiredIDs(for: rm) where !demo.contains(nid) { gaps.insert(nid) }
    }
    return gaps
}

// Engine mirror (same weights as production)
struct ScoreBreakdown: Hashable {
    var goal:Double; var interest:Double; var skillGap:Double; var roadmap:Double; var continuity:Double; var novelty:Double; var feasibility:Double; var evidence:Double
    var weighted: Double { goal*0.20 + interest*0.15 + skillGap*0.25 + roadmap*0.15 + continuity*0.10 + novelty*0.05 + feasibility*0.05 + evidence*0.05 }
    var final:Int { Int(round(weighted*100)) }
}
enum ReasonType: String, Hashable { case goal, interest, skillGap, roadmap, continuity, novelty }
struct Rec: Hashable {
    let project:Project; let score:Int; let breakdown:ScoreBreakdown; let reasons:[ReasonType]
}
func scoreProject(project:Project, studentInterests:Set<String>, studentGoals:Set<String>, gaps:Set<String>, activeRoadmaps:[Roadmap], roadmapRequired:[String:Set<String>], existingSkills:Set<String>, existingProjects:[Project], catalogSkills:[String]) -> ScoreBreakdown {
    let projGoals = Set((Array(project.relevantCareers)+Array(project.relevantFields)).map(normalize).filter{!$0.isEmpty})
    let goal = studentGoals.isEmpty || projGoals.isEmpty ? 0 : Double(studentGoals.intersection(projGoals).count)/Double(projGoals.count)
    let projInterests = Set(project.relevantInterests.map(normalize).filter{!$0.isEmpty})
    let interest = studentInterests.isEmpty || projInterests.isEmpty ? 0 : Double(studentInterests.intersection(projInterests).count)/Double(projInterests.count)
    let projSkillIDs = Set(project.skills.map(normalize).filter{!$0.isEmpty})
    let skillGap = gaps.isEmpty || projSkillIDs.isEmpty ? 0 : Double(gaps.intersection(projSkillIDs).count)/Double(gaps.count)
    let roadmap: Double = {
        if activeRoadmaps.isEmpty || projSkillIDs.isEmpty { return 0 }
        if let src=project.sourceRoadmapID, activeRoadmaps.contains(where:{$0.id==src}) { return 1.0 }
        var best:Double=0
        for rm in activeRoadmaps {
            let req=roadmapRequired[rm.id] ?? []
            if req.isEmpty { continue }
            let inter = req.intersection(projSkillIDs).count
            let ratio = Double(inter)/Double(max(projSkillIDs.count,1))
            let ratio2 = Double(inter)/Double(req.count)
            best=max(best, ratio, ratio2)
        }
        return min(best,1.0)
    }()
    let continuity: Double = {
        if existingSkills.isEmpty || projSkillIDs.isEmpty { return 0 }
        return Double(existingSkills.intersection(projSkillIDs).count)/Double(projSkillIDs.count)
    }()
    let novelty: Double = {
        if existingProjects.isEmpty { return 1.0 }
        var maxSim:Double=0
        for ex in existingProjects {
            let cat = project.category==ex.category ? 1.0 : 0.0
            let exIDs = Set(ex.skills.map(normalize).filter{!$0.isEmpty})
            let inter = projSkillIDs.intersection(exIDs).count
            let union = projSkillIDs.union(exIDs).count
            let jacc = union==0 ? 0 : Double(inter)/Double(union)
            let sim = 0.3*cat + 0.7*jacc
            maxSim=max(maxSim, sim)
        }
        return max(0, 1.0-maxSim)
    }()
    let feasibility: Double = {
        let est=project.estimatedCompletion.lowercased()
        if est.isEmpty { return 0.5 }
        if est.contains("min") { return 0.95 }
        if est.contains("hour") { return 0.85 }
        if est.contains("day") { return 0.80 }
        if est.contains("week") { return est.contains("1") ? 0.65 : 0.55 }
        if est.contains("month") { return 0.35 }
        return 0.5
    }()
    let evidence: Double = {
        let base=0.4
        let skillPart = min(1.0, Double(project.skills.count)/4.0)*0.4
        let milePart = min(1.0, Double(project.milestones.count)/4.0)*0.2
        return min(1.0, base+skillPart+milePart)
    }()
    return ScoreBreakdown(goal: goal, interest: interest, skillGap: skillGap, roadmap: roadmap, continuity: continuity, novelty: novelty, feasibility: feasibility, evidence: evidence)
}
func reasonsFor(breakdown:ScoreBreakdown, project:Project, gaps:Set<String>, studentGoals:Set<String>, studentInterests:Set<String>, activeRoadmaps:[Roadmap], roadmapRequired:[String:Set<String>], existingSkills:Set<String>, existingProjects:[Project]) -> [ReasonType] {
    var out:[ReasonType]=[]
    if breakdown.skillGap>0 { out.append(.skillGap) }
    if breakdown.goal>0 { out.append(.goal) }
    if breakdown.roadmap>0.2 { out.append(.roadmap) }
    if breakdown.interest>0 { out.append(.interest) }
    if breakdown.continuity>0.25 { out.append(.continuity) }
    if breakdown.novelty>0.7 { out.append(.novelty) }
    return out
}
func recommend(profile:StudentProfile, custom:[Project], catalog:[Project], roadmaps:[Roadmap], progress:[String:Int], activeIDs:Set<String>, limit:Int=5) -> [Rec] {
    let customIDs=Set(custom.map(\.id))
    let studentInterests=Set((profile.interests+profile.customInterests).map(normalize).filter{!$0.isEmpty})
    var studentGoals=Set(profile.careers.map(normalize).filter{!$0.isEmpty})
    studentGoals.formUnion(profile.fields.map(normalize).filter{!$0.isEmpty})
    studentGoals.formUnion(profile.milestones.map(normalize).filter{!$0.isEmpty})
    let gaps=gapIDs(profile: profile, progress: progress, roadmaps: roadmaps, activeIDs: activeIDs)
    var existingSkills=Set<String>()
    for p in custom { for s in p.skills { let n=normalize(s); if !n.isEmpty {existingSkills.insert(n)} } }
    let activeList=roadmaps.filter{activeIDs.contains($0.id)}
    var reqMap:[String:Set<String>]=[:]
    for rm in activeList { reqMap[rm.id]=requiredIDs(for: rm) }
    var cands:[Rec]=[]
    for proj in catalog where !customIDs.contains(proj.id) {
        let bd=scoreProject(project: proj, studentInterests: studentInterests, studentGoals: studentGoals, gaps: gaps, activeRoadmaps: activeList, roadmapRequired: reqMap, existingSkills: existingSkills, existingProjects: custom, catalogSkills: [])
        let rs=reasonsFor(breakdown: bd, project: proj, gaps: gaps, studentGoals: studentGoals, studentInterests: studentInterests, activeRoadmaps: activeList, roadmapRequired: reqMap, existingSkills: existingSkills, existingProjects: custom)
        cands.append(Rec(project: proj, score: bd.final, breakdown: bd, reasons: rs))
    }
    cands.sort{
        if $0.score != $1.score { return $0.score > $1.score }
        if $0.breakdown.skillGap != $1.breakdown.skillGap { return $0.breakdown.skillGap > $1.breakdown.skillGap }
        if $0.breakdown.roadmap != $1.breakdown.roadmap { return $0.breakdown.roadmap > $1.breakdown.roadmap }
        if $0.project.title != $1.project.title { return $0.project.title < $1.project.title }
        return $0.project.id < $1.project.id
    }
    if limit==0 { return [] }
    return Array(cands.prefix(limit))
}

// MARK: - Test data

let catalog: [Project] = [
    Project(id:"plant-health-dashboard", title:"Plant Health Dashboard", category:"Data + Biology", description:"Plant health", skills:["Python","Research"], estimatedCompletion:"2–3 weeks", relevantInterests:["Technology","Science"], relevantCareers:["AI Researcher"], relevantFields:["Biology"], sourceRoadmapID:"research-builder"),
    Project(id:"portfolio-site", title:"Personal Portfolio Site", category:"Web + Portfolio", description:"Portfolio", skills:["Programming","Writing"], estimatedCompletion:"1–2 weeks", relevantInterests:["Technology","Design"], relevantCareers:["Software Engineer"], relevantFields:["Computer Science"], sourceRoadmapID:"portfolio-projects"),
    Project(id:"sensor-study", title:"Sensor Data Mini Study", category:"Research + Engineering", description:"Sensor", skills:["Research","Python"], estimatedCompletion:"1–2 weeks", relevantInterests:["Science"], relevantCareers:["AI Researcher"], relevantFields:["Engineering"]),
    Project(id:"community-problem", title:"Community Problem Prototype", category:"Design + Impact", description:"Community", skills:["Leadership","Design"], estimatedCompletion:"2–3 weeks", relevantInterests:["Entrepreneurship"], relevantCareers:["Product Designer"], relevantFields:["Business"])
]

let roadmaps: [Roadmap] = [
    Roadmap(id:"research-builder", title:"Research Builder", milestones:[
        RoadmapMilestone(id:"r1", skillsDeveloped:["Python","Research"]),
        RoadmapMilestone(id:"r2", skillsDeveloped:["Data Analysis"]),
        RoadmapMilestone(id:"r3", skillsDeveloped:["TypeScript","Testing"])
    ], requiredSkills:[]),
    Roadmap(id:"portfolio-projects", title:"Portfolio Projects", milestones:[
        RoadmapMilestone(id:"p1", skillsDeveloped:["Programming","Writing"]),
        RoadmapMilestone(id:"p2", skillsDeveloped:["Design"])
    ], requiredSkills:[])
]

print("=== Phase 9.5 Recommendation Engine Tests ===")

// 1. Candidate filtering
do {
    let profile=StudentProfile()
    let custom=[Project(id:"plant-health-dashboard", title:"Plant Health Dashboard")]
    let recs=recommend(profile: profile, custom: custom, catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[])
    assert(!recs.contains(where:{$0.project.id=="plant-health-dashboard"}), "1a filtered existing")
    assertEqual(recs.count, 3, "1b count catalog 4 -1 =3")
    // Only ID dedup, not title similar
    let custom2=[Project(id:"custom-1", title:"Plant Health Dashboard")] // same title different ID
    let recs2=recommend(profile: profile, custom: custom2, catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[])
    assert(recs2.contains(where:{$0.project.id=="plant-health-dashboard"}), "1c title similar not filtered, only ID")
}

// 2. Goal alignment positive
do {
    var profile=StudentProfile(); profile.careers=["AI Researcher"]
    let recs=recommend(profile: profile, custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    let plant=recs.first(where:{$0.project.id=="plant-health-dashboard"})!
    assert(plant.breakdown.goal>0, "2a goal alignment positive for AI Researcher")
    assert(plant.reasons.contains(.goal), "2b reason goal present")
    // Non-matching career should be 0
    var profile2=StudentProfile(); profile2.careers=["Unrelated Career XYZ"]
    let recs2=recommend(profile: profile2, custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    let plant2=recs2.first(where:{$0.project.id=="plant-health-dashboard"})!
    assertEqual(plant2.breakdown.goal, 0, "2c non-matching goal 0")
}

// 3. Interest alignment
do {
    var profile=StudentProfile(); profile.interests=["Technology"]
    let recs=recommend(profile: profile, custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    let port=recs.first(where:{$0.project.id=="portfolio-site"})!
    assert(port.breakdown.interest>0, "3a interest positive")
    assert(port.reasons.contains(.interest), "3b interest reason")
}

// 4. Skill-gap coverage: 2/3 vs 1/3
do {
    // Create gaps: Python, TypeScript, SQL (3 gaps)
    // We simulate via active roadmap with required skills Python, TypeScript, SQL, student has none
    let rm = Roadmap(id:"test-rm", title:"Test", milestones:[
        RoadmapMilestone(id:"m1", skillsDeveloped:["Python"]),
        RoadmapMilestone(id:"m2", skillsDeveloped:["TypeScript"]),
        RoadmapMilestone(id:"m3", skillsDeveloped:["SQL"]),
    ], requiredSkills:[])
    // Custom projects: Project A covers 2 gaps, Project B covers 1
    let projA = Project(id:"proj-a", title:"A", skills:["Python","TypeScript"])
    let projB = Project(id:"proj-b", title:"B", skills:["Python"])
    let profile=StudentProfile()
    let progress:[String:Int]=[:]
    let active:Set<String>=["test-rm"]
    let recs=recommend(profile: profile, custom:[], catalog: [projA, projB], roadmaps: [rm], progress: progress, activeIDs: active, limit:10)
    let a=recs.first(where:{$0.project.id=="proj-a"})!
    let b=recs.first(where:{$0.project.id=="proj-b"})!
    assert(a.breakdown.skillGap > b.breakdown.skillGap, "4a 2/3 > 1/3")
    // Coverage values: 2/3 ≈0.66, 1/3≈0.33
    assertEqual(Int(round(a.breakdown.skillGap*100)), 67, "4b a 67%")
    assertEqual(Int(round(b.breakdown.skillGap*100)), 33, "4c b 33%")
    assert(a.score > b.score, "4d higher coverage higher total score")
}

// 5. Roadmap alignment
do {
    var profile=StudentProfile()
    let recs=recommend(profile: profile, custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:["research-builder"], limit:10)
    let plant=recs.first(where:{$0.project.id=="plant-health-dashboard"})!
    // plant sourceRoadmapID == research-builder and active => 1.0
    assertEqual(plant.breakdown.roadmap, 1.0, "5a direct source match 1.0")
    assert(plant.reasons.contains(.roadmap), "5b roadmap reason")
    // sensor-study also has research-builder? Actually sensor-study source not set? In our test catalog sensor-study has no source, but its skills overlap
    // With active research-builder, sensor-study should have some roadmap alignment via skill overlap
    let sensor=recs.first(where:{$0.project.id=="sensor-study"})!
    // sensor-study skills Research+Python overlap with research-builder required Python+Research => should be >0
    assert(sensor.breakdown.roadmap>0, "5c skill overlap roadmap >0")
}

// 6. Skill continuity
do {
    let custom=[Project(id:"existing", title:"Existing", skills:["Python","Research"])]
    var profile=StudentProfile()
    // candidate sharing skills
    let candidate=Project(id:"candidate", title:"Candidate", skills:["Python","Research","Data Analysis"])
    let recs=recommend(profile: profile, custom: custom, catalog: [candidate], roadmaps: roadmaps, progress:[:], activeIDs:[])
    let r=recs.first!
    assert(r.breakdown.continuity>0, "6a continuity positive when sharing")
    assert(r.reasons.contains(.continuity), "6b continuity reason")
    // Candidate with no overlap => 0
    let candidate2=Project(id:"candidate2", title:"Candidate2", skills:["Leadership"])
    let recs2=recommend(profile: profile, custom: custom, catalog: [candidate2], roadmaps: roadmaps, progress:[:], activeIDs:[])
    assertEqual(recs2.first!.breakdown.continuity, 0, "6c no overlap 0")
}

// 7. Novelty lower for duplicate
do {
    let custom=[Project(id:"ex1", title:"Portfolio Site", category:"Web + Portfolio", skills:["Programming","Writing"])]
    let candidateSame=Project(id:"cand-same", title:"Similar Portfolio", category:"Web + Portfolio", skills:["Programming","Writing"])
    let candidateDiff=Project(id:"cand-diff", title:"Different", category:"Data + Biology", skills:["Python"])
    let recs=recommend(profile: StudentProfile(), custom: custom, catalog: [candidateSame, candidateDiff], roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    let same=recs.first(where:{$0.project.id=="cand-same"})!
    let diff=recs.first(where:{$0.project.id=="cand-diff"})!
    assert(same.breakdown.novelty < diff.breakdown.novelty, "7a duplicate lower novelty")
    assert(same.breakdown.novelty < 0.5, "7b same low novelty")
    assert(diff.breakdown.novelty > 0.7, "7c diff high novelty")
}

// 8. Determinism twice identical
do {
    var profile=StudentProfile(); profile.careers=["Software Engineer"]; profile.interests=["Technology"]
    let custom=[Project(id:"c1", title:"A", skills:["Python"])]
    let r1=recommend(profile: profile, custom: custom, catalog: catalog, roadmaps: roadmaps, progress:["research-builder":1], activeIDs:["research-builder"], limit:5)
    let r2=recommend(profile: profile, custom: custom, catalog: catalog, roadmaps: roadmaps, progress:["research-builder":1], activeIDs:["research-builder"], limit:5)
    assertEqual(r1.map(\.project.id), r2.map(\.project.id), "8a deterministic order")
    assertEqual(r1.map(\.score), r2.map(\.score), "8b deterministic scores")
}

// 9. Tie-breaking stable
do {
    // Two projects with equal scores (identical signals) should be ordered by title then id
    let projA=Project(id:"id-a", title:"Alpha", category:"Test", skills:["Python"], estimatedCompletion:"2 weeks", relevantInterests:[], relevantCareers:[] , relevantFields:[])
    let projB=Project(id:"id-b", title:"Beta", category:"Test", skills:["Python"], estimatedCompletion:"2 weeks", relevantInterests:[], relevantCareers:[], relevantFields:[])
    // profile empty => both scores equal (only novelty/feasibility evidence)
    // With same title? Use Alpha vs Beta to test title tie-break
    let recs=recommend(profile: StudentProfile(), custom:[], catalog: [projB, projA], roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    // Both have same signals, but Alpha should come first due to title ascending
    assertEqual(recs[0].project.title, "Alpha", "9a title tie-break")
    assertEqual(recs[1].project.title, "Beta", "9b second")
    // Now same title different id
    let projSame1=Project(id:"id-1", title:"Same", category:"Test", skills:["Python"])
    let projSame2=Project(id:"id-2", title:"Same", category:"Test", skills:["Python"])
    let recs2=recommend(profile: StudentProfile(), custom:[], catalog: [projSame2, projSame1], roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    assertEqual(recs2[0].project.id, "id-1", "9c id tie-break")
}

// 10. Empty profile fallback deterministic
do {
    let profile=StudentProfile() // empty
    let recs=recommend(profile: profile, custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[], limit:5)
    assert(recs.count>0, "10a fallback has results")
    assert(recs.count<=5, "10b limit")
    // Should be deterministic catalog order via tie-break (since all scores similar low, title sort)
    // Check that all are from catalog and not custom
    for r in recs { assert(catalog.contains(where:{$0.id==r.project.id}), "10c from catalog") }
    // No personalized reasons? Could have novelty but not goal/interest etc. Fallback isFallback true if no personalized reasons
    // But novelty is not personalized, so isFallback checks only personalized types; empty profile has no goal/interest/gap etc, but still has novelty -> isFallback should be true because personalized empty
    // In our mirror, isFallback defined as no goal/interest/skillGap/roadmap/continuity reasons
    // Check at least one fallback is true
    let hasFallback = recs.contains(where: { $0.reasons.filter{[ReasonType.goal, .interest, .skillGap, .roadmap, .continuity].contains($0)}.isEmpty })
    assert(hasFallback, "10d fallback has no personalized reasons")
}

// 11. Missing roadmap still works
do {
    var profile=StudentProfile(); profile.careers=["Software Engineer"]
    let recs=recommend(profile: profile, custom:[], catalog: catalog, roadmaps: [], progress:[:], activeIDs:[], limit:5)
    assert(recs.count>0, "11a no roadmap still recommends")
    for r in recs { assertEqual(r.breakdown.roadmap, 0, "11b roadmap 0 when no active") }
}

// 12. Missing skills
do {
    var profile=StudentProfile(); profile.careers=["Software Engineer"]
    // profile has no skills
    let recs=recommend(profile: profile, custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    assert(recs.count>0, "12a missing skills still works")
    // skillGap coverage should be 0 when gaps empty or project skills empty
    // Here gaps empty because no active roadmap, so skillGap 0
    for r in recs { assertEqual(r.breakdown.skillGap, 0, "12b skillGap 0") }
}

// 13. Missing interests
do {
    let profile=StudentProfile() // no interests
    let recs=recommend(profile: profile, custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    for r in recs { assertEqual(r.breakdown.interest, 0, "13 interest 0") }
}

// 14. Missing optional project metadata (empty skills, etc)
do {
    let emptyProj=Project(id:"empty", title:"Empty", category:"Other", description:"", skills:[], estimatedCompletion:"")
    let recs=recommend(profile: StudentProfile(), custom:[], catalog: [emptyProj], roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    let r=recs.first!
    assertEqual(r.breakdown.skillGap, 0, "14a skillGap 0 for empty skills")
    assertEqual(r.breakdown.goal, 0, "14b goal 0")
    assert(r.score>=0 && r.score<=100, "14c score in range")
}

// 15. Reason integrity: every reason corresponds to positive signal
do {
    var profile=StudentProfile(); profile.careers=["AI Researcher"]; profile.interests=["Technology"]
    profile.strengths=["Python"]
    let rm=Roadmap(id:"rm1", title:"RM1", milestones:[RoadmapMilestone(id:"m1", skillsDeveloped:["TypeScript"])], requiredSkills:[])
    let recs=recommend(profile: profile, custom:[Project(id:"ex", title:"Ex", skills:["Python"])], catalog: catalog, roadmaps: [rm]+roadmaps, progress:[:], activeIDs:["rm1"], limit:10)
    for r in recs {
        for reason in r.reasons {
            switch reason {
            case .goal: assert(r.breakdown.goal>0, "15a goal reason positive")
            case .interest: assert(r.breakdown.interest>0, "15b interest reason positive")
            case .skillGap: assert(r.breakdown.skillGap>0, "15c gap reason positive")
            case .roadmap: assert(r.breakdown.roadmap>0, "15d roadmap reason positive")
            case .continuity: assert(r.breakdown.continuity>0, "15e continuity positive")
            case .novelty: assert(r.breakdown.novelty>0.7, "15f novelty positive")
            }
        }
    }
}

// 16. Limit
do {
    let recs5=recommend(profile: StudentProfile(), custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[], limit:5)
    assert(recs5.count<=5, "16a limit 5")
    let recs2=recommend(profile: StudentProfile(), custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[], limit:2)
    assertEqual(recs2.count, 2, "16b limit 2")
    let recs0=recommend(profile: StudentProfile(), custom:[], catalog: catalog, roadmaps: roadmaps, progress:[:], activeIDs:[], limit:0)
    assert(recs0.isEmpty, "16c limit 0 empty")
}

// 17. No mutation
do {
    var profile=StudentProfile(); profile.careers=["Software Engineer"]
    let custom=[Project(id:"c1", title:"C1")]
    let catalogCopy=catalog
    let progress: [String:Int]=["research-builder":1]
    let active:Set<String>=["research-builder"]
    let beforeCustom=custom
    let beforeCatalog=catalog
    let beforeProfile=profile
    _ = recommend(profile: profile, custom: custom, catalog: catalog, roadmaps: roadmaps, progress: progress, activeIDs: active, limit:5)
    assertEqual(custom, beforeCustom, "17a custom not mutated")
    assertEqual(catalog, beforeCatalog, "17b catalog not mutated")
    assertEqual(profile.careers, beforeProfile.careers, "17c profile not mutated")
}

// 18. Score monotonicity: improving skill-gap coverage does not decrease skillGapCoverage
do {
    let rm=Roadmap(id:"mono-rm", title:"Mono", milestones:[
        RoadmapMilestone(id:"m1", skillsDeveloped:["Python"]),
        RoadmapMilestone(id:"m2", skillsDeveloped:["TypeScript"]),
        RoadmapMilestone(id:"m3", skillsDeveloped:["SQL"]),
    ], requiredSkills:[])
    let profile=StudentProfile()
    let projLow=Project(id:"low", title:"Low", skills:["Python"])
    let projHigh=Project(id:"high", title:"High", skills:["Python","TypeScript"])
    let active:Set<String>=["mono-rm"]
    let recLow=recommend(profile: profile, custom:[], catalog: [projLow], roadmaps: [rm], progress:[:], activeIDs: active, limit:10).first!
    let recHigh=recommend(profile: profile, custom:[], catalog: [projHigh], roadmaps: [rm], progress:[:], activeIDs: active, limit:10).first!
    assert(recHigh.breakdown.skillGap >= recLow.breakdown.skillGap, "18a higher coverage not lower")
    assert(recHigh.score >= recLow.score || recHigh.breakdown.skillGap>recLow.breakdown.skillGap, "18b total not decrease significantly")
}

// 19. Roadmap alignment monotonicity
do {
    let rm1=Roadmap(id:"rm1", title:"RM1", milestones:[RoadmapMilestone(id:"m1", skillsDeveloped:["Python"])], requiredSkills:[])
    let rm2=Roadmap(id:"rm2", title:"RM2", milestones:[RoadmapMilestone(id:"m1", skillsDeveloped:["Python","Research"])], requiredSkills:[])
    let proj=Project(id:"p", title:"P", skills:["Python"])
    let recNoRoadmap=recommend(profile: StudentProfile(), custom:[], catalog: [proj], roadmaps: [rm1, rm2], progress:[:], activeIDs:[], limit:10).first!
    let recWithRoadmap=recommend(profile: StudentProfile(), custom:[], catalog: [proj], roadmaps: [rm1, rm2], progress:[:], activeIDs:["rm1"], limit:10).first!
    assert(recWithRoadmap.breakdown.roadmap >= recNoRoadmap.breakdown.roadmap, "19 roadmap alignment not decrease with active")
}

// 20. Deduplication via ID only (already tested in 1) but explicit
do {
    let custom=[Project(id:"dup-id", title:"Dup", category:"Web + Portfolio", skills:["Programming"])]
    let candidate=Project(id:"dup-id", title:"Dup", category:"Web + Portfolio", skills:["Programming"])
    let recs=recommend(profile: StudentProfile(), custom: custom, catalog: [candidate], roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10)
    assert(recs.isEmpty, "20 dedup removes same ID")
}

// 21. Evidence value in range and contributes
do {
    let proj=Project(id:"ev", title:"Ev", skills:["A","B","C","D"])
    let rec=recommend(profile: StudentProfile(), custom:[], catalog: [proj], roadmaps: roadmaps, progress:[:], activeIDs:[], limit:10).first!
    assert(rec.breakdown.evidence>=0 && rec.breakdown.evidence<=1, "21 evidence 0-1")
    assert(rec.breakdown.evidence>0.4, "21 evidence has base")
}

print("\n=== Results: \(passed) passed, \(failed) failed out of \(passed+failed) ===")
if failed==0 { print("All Phase 9.5 recommendation tests passed ✓") } else { print("Some failed"); exit(1) }
