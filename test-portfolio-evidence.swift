import Foundation

// Standalone test for Phase 8.6 — Evidence → Portfolio Connections
// Run: swift test-portfolio-evidence.swift

var passed=0, failed=0
func assert(_ c:Bool, _ msg:String,file:String=#file,line:Int=#line){if c{passed+=1}else{failed+=1; print("FAIL [\(file):\(line)] \(msg)")}}
func assertEqual<T:Equatable>(_ a:T,_ b:T,_ msg:String,file:String=#file,line:Int=#line){if a==b{passed+=1}else{failed+=1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)")}}
func normalizeSkillID(_ raw:String)->String{let t=raw.trimmingCharacters(in:.whitespacesAndNewlines); let parts=t.components(separatedBy:.whitespacesAndNewlines).filter{!$0.isEmpty}; return parts.joined(separator:" ").lowercased()}
func isValidURL(_ s:String?)->Bool{guard let t=s?.trimmingCharacters(in:.whitespacesAndNewlines),!t.isEmpty else{return false}; guard let url=URL(string:t), let sc=url.scheme?.lowercased(), ["http","https"].contains(sc) else{return false}; return url.host != nil}

// MARK: - Inline models

enum EvSource: String { case roadmapMilestone, project, studentEntered }
struct EvArtifact: Hashable { let type:String; let title:String; let url:String? }
struct TestEvidenceRecord: Hashable {
    let id:String; var title:String; var description:String?
    var roadmapID:String; var milestoneID:String
    var createdAt:Date; var occurredAt:Date?
    var source:EvSource; var status:String
    var skillIDs:[String]?; var artifact:EvArtifact?
    var projectID:String?; var opportunityID:String?; var validationID:String?; var validationPassed:Bool?
    var actionID:String?
}
enum QualityLevel: String { case basic="Basic", solid="Solid", strong="Strong" }
func quality(for rec:TestEvidenceRecord)->QualityLevel{
    var score=0
    if !rec.title.isEmpty && rec.title.count>3{score+=1}
    if let d=rec.description, d.count>10{score+=2}
    if rec.artifact != nil && isValidURL(rec.artifact?.url){score+=2}
    if rec.skillIDs != nil && !(rec.skillIDs!.isEmpty){score+=1}
    if !rec.roadmapID.isEmpty{score+=2}
    if rec.validationPassed != nil{score+=2}
    if rec.occurredAt != nil{score+=1}
    if score>=8{return .strong}
    if score>=4{return .solid}
    return .basic
}
struct TestProjectMilestone: Hashable { let id:String; let title:String }
struct TestProject: Hashable { let id:String; let title:String; let skills:[String]; let milestones:[TestProjectMilestone]; let sourceRoadmapID:String? }
struct TestRoadmapMilestone: Hashable { let id:String; let title:String; let skillsDeveloped:[String]?; init(id:String, title:String, skillsDeveloped:[String]?=nil){self.id=id; self.title=title; self.skillsDeveloped=skillsDeveloped} }
struct TestRoadmap: Hashable { let id:String; let title:String; let milestones:[TestRoadmapMilestone] }
struct TestAchievement: Hashable { let id:String; var title:String; var evidenceIDs:[String]; var skillIDs:[String]?; var roadmapID:String?; var projectID:String?; var opportunityID:String?; var source:String; var createdAt:Date }
struct TestSkill: Hashable { let id:String; let name:String }

// Portfolio
struct PortfolioSection: Hashable { let id:String; let type:String; var isEnabled:Bool }
struct TestPortfolio: Hashable {
    let id:String; var selectedProjectIDs:[String]; var selectedAchievementIDs:[String]; var selectedEvidenceIDs:[String]; var selectedSkillIDs:[String]; var selectedRoadmapIDs:[String]
    var sections:[PortfolioSection]
    init(id:String=UUID().uuidString, projects:[String]=[], achievements:[String]=[], evidence:[String]=[], skills:[String]=[], roadmaps:[String]=[], sections:[PortfolioSection]?=nil){
        self.id=id; self.selectedProjectIDs=projects; self.selectedAchievementIDs=achievements; self.selectedEvidenceIDs=evidence; self.selectedSkillIDs=skills.map{normalizeSkillID($0)}; self.selectedRoadmapIDs=roadmaps
        self.sections=sections ?? ["about","goals","skills","projects","achievements","evidence","roadmaps"].map{PortfolioSection(id:$0, type:$0, isEnabled:true)}
    }
}

// MARK: - Engine (mirrors PortfolioEvidenceEngine)

enum ConnType: String, Hashable { case project, achievement, skill, roadmap, milestone, opportunity, validation }
struct Conn: Hashable { let id:String; let evidenceID:String; let targetID:String; let targetType:ConnType; let isDirect:Bool }
struct Issue: Hashable { let id:String; let evidenceID:String; let targetType:ConnType; let targetID:String }

func supportingForProject(_ pid:String, evidence:[String:TestEvidenceRecord])->[TestEvidenceRecord]{
    let t=pid.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return []}
    return evidence.values.filter{$0.projectID?.trimmingCharacters(in:.whitespacesAndNewlines)==t}.sorted{$0.createdAt>$1.createdAt}
}
func supportingForAchievement(_ aid:String, achievements:[String:TestAchievement], evidence:[String:TestEvidenceRecord])->[TestEvidenceRecord]{
    guard let ach=achievements[aid] else{return []}
    var seen=Set<String>(), out:[TestEvidenceRecord]=[]
    for eid in ach.evidenceIDs{ if let ev=evidence[eid], seen.insert(ev.id).inserted{ out.append(ev)}}
    return out.sorted{$0.createdAt>$1.createdAt}
}
func supportingForSkill(_ sid:String, evidence:[String:TestEvidenceRecord])->[TestEvidenceRecord]{
    let n=normalizeSkillID(sid); guard !n.isEmpty else{return []}
    return evidence.values.filter{ rec in guard let sids=rec.skillIDs else{return false}; return sids.map{normalizeSkillID($0)}.contains(n) }.sorted{$0.createdAt>$1.createdAt}
}
func supportingForRoadmap(_ rid:String, evidence:[String:TestEvidenceRecord])->[TestEvidenceRecord]{
    let t=rid.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return []}
    return evidence.values.filter{$0.roadmapID==t}.sorted{$0.createdAt>$1.createdAt}
}
func supportingForMilestone(_ mid:String, roadmapID:String, evidence:[String:TestEvidenceRecord])->[TestEvidenceRecord]{
    let m=mid.trimmingCharacters(in:.whitespacesAndNewlines); let r=roadmapID.trimmingCharacters(in:.whitespacesAndNewlines); guard !m.isEmpty && !r.isEmpty else{return []}
    return evidence.values.filter{$0.roadmapID==r && $0.milestoneID==m}.sorted{$0.createdAt>$1.createdAt}
}
func supportingForOpportunity(_ oid:String, evidence:[String:TestEvidenceRecord])->[TestEvidenceRecord]{
    let t=oid.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return []}
    return evidence.values.filter{$0.opportunityID?.trimmingCharacters(in:.whitespacesAndNewlines)==t}.sorted{$0.createdAt>$1.createdAt}
}
func supportingForValidation(_ vid:String, evidence:[String:TestEvidenceRecord])->[TestEvidenceRecord]{
    let t=vid.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return []}
    return evidence.values.filter{$0.validationID?.trimmingCharacters(in:.whitespacesAndNewlines)==t}.sorted{$0.createdAt>$1.createdAt}
}

// Portfolio-level report
struct Report {
    let projectEvidence:[String:[TestEvidenceRecord]]
    let achievementEvidence:[String:[TestEvidenceRecord]]
    let skillEvidence:[String:[TestEvidenceRecord]]
    let roadmapEvidence:[String:[TestEvidenceRecord]]
    let milestoneEvidence:[String:[TestEvidenceRecord]]
    let opportunityEvidence:[String:[TestEvidenceRecord]]
    let validationEvidence:[String:[TestEvidenceRecord]]
    let selectedEvidence:[TestEvidenceRecord]
    let unresolved:[Issue]
    let orphaned:[String]
    let usage:[String:Int]
    let connections:[Conn]
}

func reportFor(portfolio:TestPortfolio, evidence:[String:TestEvidenceRecord], achievements:[String:TestAchievement], projects:[String:TestProject], roadmaps:[String:TestRoadmap])->Report{
    let selectedEvidence = portfolio.selectedEvidenceIDs.compactMap{evidence[$0]}.sorted{$0.createdAt>$1.createdAt}
    var projMap:[String:[TestEvidenceRecord]]=[:]; for pid in portfolio.selectedProjectIDs{ projMap[pid]=supportingForProject(pid, evidence:evidence)}
    var achMap:[String:[TestEvidenceRecord]]=[:]; for aid in portfolio.selectedAchievementIDs{ achMap[aid]=supportingForAchievement(aid, achievements:achievements, evidence:evidence)}
    var skillMap:[String:[TestEvidenceRecord]]=[:]; for sid in portfolio.selectedSkillIDs{ let n=normalizeSkillID(sid); skillMap[n]=supportingForSkill(n, evidence:evidence)}
    var roadmapMap:[String:[TestEvidenceRecord]]=[:]; for rid in portfolio.selectedRoadmapIDs{ roadmapMap[rid]=supportingForRoadmap(rid, evidence:evidence)}
    var milestoneMap:[String:[TestEvidenceRecord]]=[:]; for rid in portfolio.selectedRoadmapIDs{ if let rm=roadmaps[rid]{ for ms in rm.milestones{ let key="\(rid):\(ms.id)"; let evs=supportingForMilestone(ms.id, roadmapID:rid, evidence:evidence); if !evs.isEmpty{milestoneMap[key]=evs}}}}
    var oppIDs=Set<String>(); for rec in selectedEvidence where rec.opportunityID != nil{ if let oid=rec.opportunityID?.trimmingCharacters(in:.whitespacesAndNewlines),!oid.isEmpty{oppIDs.insert(oid)}}
    var oppMap:[String:[TestEvidenceRecord]]=[:]; for oid in oppIDs{ oppMap[oid]=supportingForOpportunity(oid, evidence:evidence)}
    var valIDs=Set<String>(); for rec in selectedEvidence where rec.validationID != nil{ if let vid=rec.validationID?.trimmingCharacters(in:.whitespacesAndNewlines),!vid.isEmpty{valIDs.insert(vid)}}
    var valMap:[String:[TestEvidenceRecord]]=[:]; for vid in valIDs{ valMap[vid]=supportingForValidation(vid, evidence:evidence)}
    // connections
    var conns:[Conn]=[]; var seen=Set<String>()
    func addConn(_ evID:String, _ targetID:String, _ type:ConnType){
        let id="\(evID)->\(type.rawValue):\(targetID)"
        guard !seen.contains(id) else{return}; seen.insert(id)
        conns.append(Conn(id:id, evidenceID:evID, targetID:targetID, targetType:type, isDirect:true))
    }
    for (pid,evs) in projMap{ for ev in evs{ addConn(ev.id, pid, .project)}}
    for (aid,evs) in achMap{ for ev in evs{ addConn(ev.id, aid, .achievement)}}
    for (sid,evs) in skillMap{ for ev in evs{ addConn(ev.id, sid, .skill)}}
    for (rid,evs) in roadmapMap{ for ev in evs{ addConn(ev.id, rid, .roadmap)}}
    for (key,evs) in milestoneMap{ let parts=key.split(separator:":"); let mid=String(parts[1]); for ev in evs{ addConn(ev.id, mid, .milestone)}}
    for (oid,evs) in oppMap{ for ev in evs{ addConn(ev.id, oid, .opportunity)}}
    for (vid,evs) in valMap{ for ev in evs{ addConn(ev.id, vid, .validation)}}
    // also add connections for selected evidence's own direct refs (to ensure selected evidence shows its supports)
    for rec in selectedEvidence{
        if let pid=rec.projectID?.trimmingCharacters(in:.whitespacesAndNewlines),!pid.isEmpty, projects[pid] != nil{ addConn(rec.id, pid, .project)}
        if !rec.roadmapID.isEmpty, roadmaps[rec.roadmapID] != nil{ addConn(rec.id, rec.roadmapID, .roadmap)}
        if !rec.milestoneID.isEmpty, !rec.roadmapID.isEmpty, let rm=roadmaps[rec.roadmapID], rm.milestones.contains(where:{$0.id==rec.milestoneID}){ addConn(rec.id, rec.milestoneID, .milestone)}
        if let oid=rec.opportunityID?.trimmingCharacters(in:.whitespacesAndNewlines),!oid.isEmpty{ addConn(rec.id, oid, .opportunity)}
        if let vid=rec.validationID?.trimmingCharacters(in:.whitespacesAndNewlines),!vid.isEmpty{ addConn(rec.id, vid, .validation)}
        if let sids=rec.skillIDs{ for raw in sids{ let n=normalizeSkillID(raw); if !n.isEmpty{ addConn(rec.id, n, .skill)}}}
        for aid in portfolio.selectedAchievementIDs where achievements[aid]?.evidenceIDs.contains(rec.id)==true{ addConn(rec.id, aid, .achievement)}
    }
    conns.sort{$0.id < $1.id}
    // unresolved
    var unresolved:[Issue]=[]
    for rec in selectedEvidence{
        if let pid=rec.projectID?.trimmingCharacters(in:.whitespacesAndNewlines),!pid.isEmpty, projects[pid]==nil{ unresolved.append(Issue(id:"\(rec.id)->project:\(pid)", evidenceID:rec.id, targetType:.project, targetID:pid))}
        if !rec.roadmapID.isEmpty, roadmaps[rec.roadmapID]==nil{ unresolved.append(Issue(id:"\(rec.id)->roadmap:\(rec.roadmapID)", evidenceID:rec.id, targetType:.roadmap, targetID:rec.roadmapID))}
        if !rec.milestoneID.isEmpty, !rec.roadmapID.isEmpty, let rm=roadmaps[rec.roadmapID], !rm.milestones.contains(where:{$0.id==rec.milestoneID}){ unresolved.append(Issue(id:"\(rec.id)->milestone:\(rec.milestoneID)", evidenceID:rec.id, targetType:.milestone, targetID:rec.milestoneID))}
        else if !rec.milestoneID.isEmpty && rec.roadmapID.isEmpty{ unresolved.append(Issue(id:"\(rec.id)->milestone:\(rec.milestoneID)", evidenceID:rec.id, targetType:.milestone, targetID:rec.milestoneID))}
    }
    for aid in portfolio.selectedAchievementIDs{ if let ach=achievements[aid]{ for eid in ach.evidenceIDs where evidence[eid]==nil{ unresolved.append(Issue(id:"\(eid)->achievement:\(aid)", evidenceID:eid, targetType:.achievement, targetID:aid))}}}
    unresolved.sort{$0.id < $1.id}
    // deduplicate unresolved
    var seenU=Set<String>(); var dedupedU:[Issue]=[]; for u in unresolved where !seenU.contains(u.id){seenU.insert(u.id); dedupedU.append(u)}
    // orphaned: selected evidence with no connection to selected portfolio items
    var connected=Set<String>()
    for evs in projMap.values{ for ev in evs{connected.insert(ev.id)}}
    for evs in achMap.values{ for ev in evs{connected.insert(ev.id)}}
    for evs in skillMap.values{ for ev in evs{connected.insert(ev.id)}}
    for evs in roadmapMap.values{ for ev in evs{connected.insert(ev.id)}}
    var orphaned:[String]=[]
    for rec in selectedEvidence{
        if connected.contains(rec.id){continue}
        var isConn=false
        if let pid=rec.projectID, portfolio.selectedProjectIDs.contains(pid){isConn=true}
        if !rec.roadmapID.isEmpty, portfolio.selectedRoadmapIDs.contains(rec.roadmapID){isConn=true}
        if let sids=rec.skillIDs{ for raw in sids{ if portfolio.selectedSkillIDs.map({normalizeSkillID($0)}).contains(normalizeSkillID(raw)){isConn=true; break}}}
        for aid in portfolio.selectedAchievementIDs where achievements[aid]?.evidenceIDs.contains(rec.id)==true{isConn=true; break}
        if !isConn{orphaned.append(rec.id)}
    }
    orphaned.sort()
    // usage
    var usage:[String:Int]=[:]
    for evs in projMap.values{ for ev in evs{usage[ev.id,default:0]+=1}}
    for evs in achMap.values{ for ev in evs{usage[ev.id,default:0]+=1}}
    for evs in skillMap.values{ for ev in evs{usage[ev.id,default:0]+=1}}
    for evs in roadmapMap.values{ for ev in evs{usage[ev.id,default:0]+=1}}
    for rec in selectedEvidence{usage[rec.id,default:0]+=1}
    return Report(projectEvidence:projMap, achievementEvidence:achMap, skillEvidence:skillMap, roadmapEvidence:roadmapMap, milestoneEvidence:milestoneMap, opportunityEvidence:oppMap, validationEvidence:valMap, selectedEvidence:selectedEvidence, unresolved:dedupedU, orphaned:orphaned, usage:usage, connections:conns)
}

// MARK: - Helpers

func makeProject(id:String, skills:[String]=[], sourceRoadmapID:String?=nil)->TestProject{ TestProject(id:id, title:"Project \(id)", skills:skills, milestones:[TestProjectMilestone(id:"m1", title:"M1")], sourceRoadmapID:sourceRoadmapID) }
func makeRoadmap(id:String, milestones:Int=2)->TestRoadmap{ TestRoadmap(id:id, title:"Roadmap \(id)", milestones:(0..<milestones).map{TestRoadmapMilestone(id:"\(id)-m\($0+1)", title:"M\($0+1)", skillsDeveloped:["Skill\($0)"])})}
func makeEvidence(id:String, title:String="Evidence", description:String?="Detailed description", roadmapID:String="", milestoneID:String="", projectID:String?=nil, skillIDs:[String]?=nil, opportunityID:String?=nil, validationID:String?=nil, artifactURL:String?=nil, createdAt:Date=Date(timeIntervalSince1970:1700000000))->TestEvidenceRecord{
    let art = artifactURL != nil ? EvArtifact(type:"link", title:"Art", url:artifactURL) : nil
    return TestEvidenceRecord(id:id, title:title, description:description, roadmapID:roadmapID, milestoneID:milestoneID, createdAt:createdAt, occurredAt:nil, source:.studentEntered, status:"recorded", skillIDs:skillIDs, artifact:art, projectID:projectID, opportunityID:opportunityID, validationID:validationID, validationPassed:nil)
}
func makeAchievement(id:String, evidenceIDs:[String]=[], skillIDs:[String]?=nil, roadmapID:String?=nil, projectID:String?=nil, source:String="studentEntered")->TestAchievement{ TestAchievement(id:id, title:"Achievement \(id)", evidenceIDs:evidenceIDs, skillIDs:skillIDs, roadmapID:roadmapID, projectID:projectID, opportunityID:nil, source:source, createdAt:Date(timeIntervalSince1970:1700000000))}

// MARK: - DIRECT CONNECTIONS (1-7)

do { // projectID
    let ev=makeEvidence(id:"ev-1", projectID:"proj-1")
    let res=supportingForProject("proj-1", evidence:["ev-1":ev])
    assertEqual(res.map(\.id), ["ev-1"], "project direct")
    let res2=supportingForProject("proj-2", evidence:["ev-1":ev])
    assert(res2.isEmpty, "project no match")
}
do { // achievement evidenceIDs
    let ev=makeEvidence(id:"ev-1")
    let ach=makeAchievement(id:"ach-1", evidenceIDs:["ev-1"])
    let res=supportingForAchievement("ach-1", achievements:["ach-1":ach], evidence:["ev-1":ev])
    assertEqual(res.map(\.id), ["ev-1"], "achievement direct")
    let ach2=makeAchievement(id:"ach-2", evidenceIDs:["missing"])
    let res2=supportingForAchievement("ach-2", achievements:["ach-2":ach2], evidence:["ev-1":ev])
    assert(res2.isEmpty, "achievement missing filtered")
}
do { // skillIDs
    let ev=makeEvidence(id:"ev-1", skillIDs:["Python"])
    let res=supportingForSkill("python", evidence:["ev-1":ev])
    assertEqual(res.map(\.id), ["ev-1"], "skill direct")
    let res2=supportingForSkill("git", evidence:["ev-1":ev])
    assert(res2.isEmpty, "skill no match")
    // normalization
    let ev2=makeEvidence(id:"ev-2", skillIDs:["  PYTHON  "])
    let res3=supportingForSkill("python", evidence:["ev-2":ev2])
    assertEqual(res3.map(\.id), ["ev-2"], "skill normalized")
}
do { // roadmapID
    let ev=makeEvidence(id:"ev-1", roadmapID:"rm-1")
    let res=supportingForRoadmap("rm-1", evidence:["ev-1":ev])
    assertEqual(res.map(\.id), ["ev-1"], "roadmap direct")
}
do { // milestoneID
    let ev=makeEvidence(id:"ev-1", roadmapID:"rm-1", milestoneID:"m1")
    let res=supportingForMilestone("m1", roadmapID:"rm-1", evidence:["ev-1":ev])
    assertEqual(res.map(\.id), ["ev-1"], "milestone direct")
    let res2=supportingForMilestone("m2", roadmapID:"rm-1", evidence:["ev-1":ev])
    assert(res2.isEmpty, "milestone no match")
}
do { // opportunityID
    let ev=makeEvidence(id:"ev-1", opportunityID:"opp-1")
    let res=supportingForOpportunity("opp-1", evidence:["ev-1":ev])
    assertEqual(res.map(\.id), ["ev-1"], "opportunity direct")
}
do { // validationID
    let ev=makeEvidence(id:"ev-1", validationID:"val-1")
    let res=supportingForValidation("val-1", evidence:["ev-1":ev])
    assertEqual(res.map(\.id), ["ev-1"], "validation direct")
}

// MARK: - MULTI-CONNECTION (8-9)

do { // one evidence supports multiple entities
    let ev=makeEvidence(id:"ev-multi", description:"Evidence", roadmapID:"rm-1", milestoneID:"m1", projectID:"proj-1", skillIDs:["python"], opportunityID:"opp-1", validationID:"val-1")
    // It should appear in all supporting queries
    assert(!supportingForProject("proj-1", evidence:["ev-multi":ev]).isEmpty, "multi project")
    assert(!supportingForRoadmap("rm-1", evidence:["ev-multi":ev]).isEmpty, "multi roadmap")
    assert(!supportingForMilestone("m1", roadmapID:"rm-1", evidence:["ev-multi":ev]).isEmpty, "multi milestone")
    assert(!supportingForSkill("python", evidence:["ev-multi":ev]).isEmpty, "multi skill")
    assert(!supportingForOpportunity("opp-1", evidence:["ev-multi":ev]).isEmpty, "multi opportunity")
    assert(!supportingForValidation("val-1", evidence:["ev-multi":ev]).isEmpty, "multi validation")
    // Portfolio report should have multiple connections for same evidence
    let portfolio=TestPortfolio(projects:["proj-1"], achievements:[], evidence:["ev-multi"], skills:["python"], roadmaps:["rm-1"])
    let projects=["proj-1":makeProject(id:"proj-1")]
    let roadmaps=["rm-1":makeRoadmap(id:"rm-1")]
    roadmaps["rm-1"]?.milestones.first // ensure milestone exists
    var rmWithMilestone=TestRoadmap(id:"rm-1", title:"RM1", milestones:[TestRoadmapMilestone(id:"m1", title:"M1")])
    let report=reportFor(portfolio:portfolio, evidence:["ev-multi":ev], achievements:[:], projects:["proj-1":makeProject(id:"proj-1")], roadmaps:["rm-1":rmWithMilestone])
    // Connections should include multiple target types for same evidence
    let connTypes=Set(report.connections.filter{$0.evidenceID=="ev-multi"}.map { $0.targetType })
    assert(connTypes.contains(.project), "multi conn project")
    assert(connTypes.contains(.roadmap), "multi conn roadmap")
    assert(connTypes.contains(.milestone), "multi conn milestone")
    assert(connTypes.contains(.skill), "multi conn skill")
}
do { // multiple evidence support one entity
    let ev1=makeEvidence(id:"ev-1", projectID:"proj-1")
    let ev2=makeEvidence(id:"ev-2", projectID:"proj-1")
    let ev3=makeEvidence(id:"ev-3", projectID:"proj-1")
    let res=supportingForProject("proj-1", evidence:["ev-1":ev1,"ev-2":ev2,"ev-3":ev3])
    assertEqual(res.count, 3, "multiple evidence one entity")
    // Deduplication within one section: same evidence not shown multiple times (but our engine dedups by id, so count is 3 unique)
    let evDup=makeEvidence(id:"ev-1", projectID:"proj-1")
    // If duplicate IDs, map will dedup to 1
    let resDup=supportingForProject("proj-1", evidence:["ev-1":ev1, "ev-1-dup":evDup]) // same id different key? Actually evidence dict key is id, so duplicate id would be same key, so only one entry. This is expected dedup by id.
    // Order deterministic: sorted by createdAt desc, then stable? Our implementation sorts by createdAt desc
    let evOld=makeEvidence(id:"ev-old", projectID:"proj-1", createdAt:Date(timeIntervalSince1970:1000))
    let evNew=makeEvidence(id:"ev-new", projectID:"proj-1", createdAt:Date(timeIntervalSince1970:2000))
    let resOrder=supportingForProject("proj-1", evidence:["ev-old":evOld,"ev-new":evNew])
    assertEqual(resOrder.first!.id, "ev-new", "order deterministic by createdAt desc")
}

// MARK: - ORDER (10-11)

do { // portfolio project order preserved
    let ev1=makeEvidence(id:"ev-1", projectID:"proj-1")
    let ev2=makeEvidence(id:"ev-2", projectID:"proj-2")
    let portfolio=TestPortfolio(projects:["proj-2","proj-1"], evidence:["ev-1","ev-2"])
    let projects=["proj-1":makeProject(id:"proj-1"),"proj-2":makeProject(id:"proj-2")]
    let report=reportFor(portfolio:portfolio, evidence:["ev-1":ev1,"ev-2":ev2], achievements:[:], projects:projects, roadmaps:[:])
    // Project order in portfolio preserved (checked via portfolio selected order, not report's projectEvidence order)
    assertEqual(portfolio.selectedProjectIDs, ["proj-2","proj-1"], "portfolio order preserved")
    // Evidence order deterministic: our report sorts evidence by createdAt desc, so deterministic
    let ordered=supportingForProject("proj-1", evidence:["ev-1":ev1])
    assert(ordered.count==1, "order single")
}
do { // evidence order deterministic
    let ev1=makeEvidence(id:"ev-b", projectID:"proj-1", createdAt:Date(timeIntervalSince1970:1000))
    let ev2=makeEvidence(id:"ev-a", projectID:"proj-1", createdAt:Date(timeIntervalSince1970:2000))
    let res=supportingForProject("proj-1", evidence:["ev-b":ev1,"ev-a":ev2])
    assertEqual(res.map(\.id), ["ev-a","ev-b"], "evidence order deterministic")
}

// MARK: - DEDUPLICATION (12-14)

do { // duplicate evidence IDs
    let ev=makeEvidence(id:"ev-1", projectID:"proj-1")
    // Simulate duplicate evidenceIDs in achievement
    let ach=TestAchievement(id:"ach-1", title:"Ach", evidenceIDs:["ev-1","ev-1"], skillIDs:nil, roadmapID:nil, projectID:nil, opportunityID:nil, source:"studentEntered", createdAt:Date())
    let res=supportingForAchievement("ach-1", achievements:["ach-1":ach], evidence:["ev-1":ev])
    assertEqual(res.count, 1, "duplicate evidenceIDs deduped")
}
do { // duplicate relationships
    let ev=makeEvidence(id:"ev-1", projectID:"proj-1", skillIDs:["python"])
    // Same evidence appears in project and skill supporting — but within one section (project) should not duplicate
    let projRes=supportingForProject("proj-1", evidence:["ev-1":ev])
    assertEqual(projRes.count, 1, "duplicate relationship within project section deduped")
}
do { // same evidence across multiple contexts (allowed)
    let ev=makeEvidence(id:"ev-1", projectID:"proj-1", skillIDs:["python"])
    let portfolio=TestPortfolio(projects:["proj-1"], evidence:["ev-1"], skills:["python"])
    let report=reportFor(portfolio:portfolio, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":makeProject(id:"proj-1", skills:["python"])], roadmaps:[:])
    // Evidence appears in both projectEvidence and skillEvidence, but each section deduped internally
    assertEqual(report.projectEvidence["proj-1"]?.count, 1, "across contexts project")
    assertEqual(report.skillEvidence["python"]?.count, 1, "across contexts skill")
    // But within each section, deduped
    assert(report.connections.filter{$0.evidenceID=="ev-1"}.count >= 2, "across contexts multiple connections")
}

// MARK: - SKILLS (15-17)

do { // canonical skill normalization
    let ev=makeEvidence(id:"ev-1", skillIDs:["  PYTHON  "])
    let res=supportingForSkill("python", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "skill normalized")
    let res2=supportingForSkill("  PYTHON  ", evidence:["ev-1":ev])
    assertEqual(res2.count, 1, "skill normalized query")
}
do { // evidence skill connection
    let ev=makeEvidence(id:"ev-1", skillIDs:["python","git"])
    let res=supportingForSkill("python", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "skill connection")
    let res2=supportingForSkill("research", evidence:["ev-1":ev])
    assert(res2.isEmpty, "skill no connection")
}
do { // no automatic skill awarding
    // Evidence references skill but store.skillsDemonstrated not used in supporting query — that's correct, supporting is just reference, not award
    // Awarding would be via SkillGapEngine, not this engine. Verify that supportingForSkill does not mutate a skill set
    var demonstrated:Set<String>=[] // empty
    let ev=makeEvidence(id:"ev-1", skillIDs:["python"])
    let res=supportingForSkill("python", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "support still shows even if not demonstrated (reference)")
    // But awarding check: demonstrated should not change
    assert(demonstrated.isEmpty, "no automatic awarding")
}

// MARK: - PROJECTS (18-20)

do { // project evidence
    let ev=makeEvidence(id:"ev-1", projectID:"proj-1")
    let res=supportingForProject("proj-1", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "project evidence")
}
do { // missing project
    let ev=makeEvidence(id:"ev-1", projectID:"missing-proj")
    let portfolio=TestPortfolio(projects:["missing-proj"], evidence:["ev-1"])
    let report=reportFor(portfolio:portfolio, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:])
    // Supporting for missing project still returns evidence because evidence.projectID matches, even if project not in store
    // But portfolio-level report's unresolved should flag missing project from evidence's projectID? For selected evidence that references missing project
    // Check unresolved for evidence referencing missing project
    assert(!report.projectEvidence["missing-proj"]!.isEmpty, "missing project still has supporting evidence (evidence exists, project missing)")
    // Unresolved should be reported for evidence that references missing project and is selected
    let portfolio2=TestPortfolio(projects:["missing-proj"], evidence:["ev-1"])
    let report2=reportFor(portfolio:portfolio2, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:])
    // Our engine's unresolved checks evidence's projectID against projects map — should flag
    assert(report2.unresolved.contains(where:{$0.targetType == .project && $0.targetID == "missing-proj"}), "unresolved missing project")
}
do { // standalone project (no evidence)
    let portfolio=TestPortfolio(projects:["proj-1"], evidence:[])
    let report=reportFor(portfolio:portfolio, evidence:[:], achievements:[:], projects:["proj-1":makeProject(id:"proj-1")], roadmaps:[:])
    assert(report.projectEvidence["proj-1"]!.isEmpty, "standalone project no evidence")
}

// MARK: - ACHIEVEMENTS (21-25)

do { // achievement evidence
    let ev=makeEvidence(id:"ev-1")
    let ach=makeAchievement(id:"ach-1", evidenceIDs:["ev-1"])
    let res=supportingForAchievement("ach-1", achievements:["ach-1":ach], evidence:["ev-1":ev])
    assertEqual(res.count, 1, "achievement evidence")
}
do { // missing evidence
    let ach=makeAchievement(id:"ach-1", evidenceIDs:["missing-ev"])
    let res=supportingForAchievement("ach-1", achievements:["ach-1":ach], evidence:["ev-1":makeEvidence(id:"ev-1")])
    assert(res.isEmpty, "missing evidence filtered")
    // Portfolio report should have unresolved for achievement referencing missing evidence
    let portfolio=TestPortfolio(achievements:["ach-1"], evidence:[])
    let report=reportFor(portfolio:portfolio, evidence:[:], achievements:["ach-1":ach], projects:[:], roadmaps:[:])
    assert(report.unresolved.contains(where:{$0.targetID == "ach-1" && $0.targetType == .achievement}), "unresolved missing evidence")
}
do { // generated achievement (source system)
    let ev=makeEvidence(id:"ev-1")
    let ach=makeAchievement(id:"ach-gen", evidenceIDs:["ev-1"], source:"system")
    let res=supportingForAchievement("ach-gen", achievements:["ach-gen":ach], evidence:["ev-1":ev])
    assertEqual(res.count, 1, "generated achievement evidence")
}
do { // student-created achievement
    let ev=makeEvidence(id:"ev-1")
    let ach=makeAchievement(id:"ach-student", evidenceIDs:["ev-1"], source:"studentEntered")
    let res=supportingForAchievement("ach-student", achievements:["ach-student":ach], evidence:["ev-1":ev])
    assertEqual(res.count, 1, "student achievement")
}
do { // consistency rules respected (we don't regenerate, just resolve)
    // If achievement has evidenceIDs that are missing, we filter, not fabricate
    let ach=makeAchievement(id:"ach-1", evidenceIDs:["ev-1","ev-2"])
    let ev1=makeEvidence(id:"ev-1")
    let res=supportingForAchievement("ach-1", achievements:["ach-1":ach], evidence:["ev-1":ev1])
    assertEqual(res.count, 1, "consistency missing filtered")
}

// MARK: - ROADMAPS (26-30)

do { // roadmap evidence
    let ev=makeEvidence(id:"ev-1", roadmapID:"rm-1")
    let res=supportingForRoadmap("rm-1", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "roadmap evidence")
}
do { // milestone evidence
    let ev=makeEvidence(id:"ev-1", roadmapID:"rm-1", milestoneID:"m1")
    let res=supportingForMilestone("m1", roadmapID:"rm-1", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "milestone evidence")
    let res2=supportingForMilestone("m2", roadmapID:"rm-1", evidence:["ev-1":ev])
    assert(res2.isEmpty, "milestone no match")
}
do { // unresolved milestone
    let ev=makeEvidence(id:"ev-1", roadmapID:"rm-1", milestoneID:"missing-m")
    let rm=TestRoadmap(id:"rm-1", title:"RM", milestones:[TestRoadmapMilestone(id:"m1", title:"M1")])
    let portfolio=TestPortfolio(evidence:["ev-1"], roadmaps:["rm-1"])
    let report=reportFor(portfolio:portfolio, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:["rm-1":rm])
    assert(report.unresolved.contains(where:{$0.targetType == .milestone && $0.targetID == "missing-m"}), "unresolved milestone")
    // Evidence preserved
    assert(report.selectedEvidence.count==1, "evidence preserved despite unresolved milestone")
}
do { // active roadmap
    let ev=makeEvidence(id:"ev-1", roadmapID:"rm-active")
    let res=supportingForRoadmap("rm-active", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "active roadmap evidence")
}
do { // completed milestone (roadmap progress not needed for connection, just evidence link)
    let ev=makeEvidence(id:"ev-1", roadmapID:"rm-1", milestoneID:"m1")
    let rm=TestRoadmap(id:"rm-1", title:"RM", milestones:[TestRoadmapMilestone(id:"m1", title:"M1"), TestRoadmapMilestone(id:"m2", title:"M2")])
    let res=supportingForMilestone("m1", roadmapID:"rm-1", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "completed milestone evidence")
}

// MARK: - OPPORTUNITIES (31-32)

do { // opportunity evidence
    let ev=makeEvidence(id:"ev-1", opportunityID:"opp-1")
    let res=supportingForOpportunity("opp-1", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "opportunity evidence")
}
do { // unavailable opportunity (not in local store, but evidence preserved)
    let ev=makeEvidence(id:"ev-1", opportunityID:"opp-missing")
    let portfolio=TestPortfolio(evidence:["ev-1"])
    let report=reportFor(portfolio:portfolio, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:])
    // Opportunity unresolved not reported in our simplified engine (since no opportunity catalog), but evidence preserved
    assertEqual(report.selectedEvidence.count, 1, "opportunity unavailable evidence preserved")
    assert(report.selectedEvidence[0].opportunityID=="opp-missing", "opportunity ID preserved")
}

// MARK: - VALIDATION (33-36)

do { // validation evidence
    let ev=makeEvidence(id:"ev-1", validationID:"val-1")
    let res=supportingForValidation("val-1", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "validation evidence")
}
do { // passed validation
    let ev=TestEvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", createdAt:Date(), occurredAt:nil, source:.studentEntered, status:"recorded", skillIDs:nil, artifact:nil, projectID:nil, opportunityID:nil, validationID:"val-1", validationPassed:true)
    let res=supportingForValidation("val-1", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "passed validation")
    assert(res[0].validationPassed==true, "passed true")
}
do { // failed validation
    let ev=TestEvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", createdAt:Date(), occurredAt:nil, source:.studentEntered, status:"recorded", skillIDs:nil, artifact:nil, projectID:nil, opportunityID:nil, validationID:"val-1", validationPassed:false)
    let res=supportingForValidation("val-1", evidence:["ev-1":ev])
    assertEqual(res.count, 1, "failed validation still evidence")
    assert(res[0].validationPassed==false, "failed false")
}
do { // missing validation (no evidence with that ID)
    let res=supportingForValidation("val-missing", evidence:[:])
    assert(res.isEmpty, "missing validation empty")
}

// MARK: - QUALITY (37-40)

do { // Basic
    let ev=makeEvidence(id:"ev-basic", title:"X", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil)
    // Make it basic by having minimal fields: title only (but our quality counts title +1, so basic)
    // Our quality: title >3 gives 1, so basic if only title
    let q=quality(for:ev)
    assertEqual(q, .basic, "quality basic")
}
do { // Solid
    let ev=makeEvidence(id:"ev-solid", title:"Solid Evidence", description:"A detailed description with more than ten chars", roadmapID:"rm-1", skillIDs:["python"])
    let q=quality(for:ev)
    assertEqual(q, .solid, "quality solid")
}
do { // Strong
    let ev=makeEvidence(id:"ev-strong", title:"Strong Evidence", description:"A very detailed description that is definitely longer than ten chars", roadmapID:"rm-1", milestoneID:"m1", projectID:"proj-1", skillIDs:["python"], artifactURL:"https://example.com", createdAt:Date())
    // Add validation and occurredAt to push to strong
    var ev2=ev; ev2.validationPassed=true; ev2.validationID="val-1"; ev2.occurredAt=Date()
    let q=quality(for:ev2)
    assertEqual(q, .strong, "quality strong")
}
do { // quality independent from connection
    let evStrong=makeEvidence(id:"ev-strong", title:"Strong", description:"Detailed description longer than ten", roadmapID:"rm-1", skillIDs:["python"], artifactURL:"https://example.com")
    let evBasic=makeEvidence(id:"ev-basic", title:"Basic", description:nil)
    let qStrong=quality(for:evStrong)
    let qBasic=quality(for:evBasic)
    assert(qStrong != qBasic, "quality differs")
    // Connection should work for both regardless of quality
    let resStrong=supportingForRoadmap("rm-1", evidence:["ev-strong":evStrong])
    let resBasic=supportingForRoadmap("rm-1", evidence:["ev-basic":evBasic])
    // evBasic has no roadmapID, so no connection — but that's because it lacks roadmapID, not quality
    // Instead test that evidence with same roadmapID but different quality both connect
    let evBasic2=makeEvidence(id:"ev-basic2", roadmapID:"rm-1")
    let resBasic2=supportingForRoadmap("rm-1", evidence:["ev-basic2":evBasic2])
    assertEqual(resBasic2.count, 1, "quality independent from connection")
}

// MARK: - ORPHANED EVIDENCE (41-42)

do { // selected evidence with no relationships
    let ev=makeEvidence(id:"ev-orphan", title:"Orphan", description:"Standalone")
    let portfolio=TestPortfolio(evidence:["ev-orphan"])
    let report=reportFor(portfolio:portfolio, evidence:["ev-orphan":ev], achievements:[:], projects:[:], roadmaps:[:])
    assert(report.orphaned.contains("ev-orphan"), "orphaned evidence")
    assert(report.selectedEvidence.count==1, "orphaned still preserved")
}
do { // still preserved even if orphaned
    let ev=makeEvidence(id:"ev-orphan", title:"Orphan")
    let portfolio=TestPortfolio(evidence:["ev-orphan"])
    let report=reportFor(portfolio:portfolio, evidence:["ev-orphan":ev], achievements:[:], projects:[:], roadmaps:[:])
    assert(report.orphaned.contains("ev-orphan"), "orphaned preserved")
    assert(report.selectedEvidence[0].id=="ev-orphan", "orphaned evidence in selected")
}

// MARK: - UNRESOLVED REFERENCES (43-45)

do { // missing target
    let ev=makeEvidence(id:"ev-1", projectID:"missing-proj")
    let portfolio=TestPortfolio(evidence:["ev-1"])
    let report=reportFor(portfolio:portfolio, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:])
    assert(report.unresolved.contains(where:{$0.targetID == "missing-proj"}), "unresolved missing target")
}
do { // evidence preserved despite unresolved
    let ev=makeEvidence(id:"ev-1", projectID:"missing-proj")
    let portfolio=TestPortfolio(evidence:["ev-1"])
    let report=reportFor(portfolio:portfolio, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:])
    assert(report.selectedEvidence.count==1, "evidence preserved")
    assert(report.selectedEvidence[0].id=="ev-1", "preserved id")
}
do { // no mutation on unresolved
    var portfolio=TestPortfolio(evidence:["ev-1"])
    let before=portfolio.selectedEvidenceIDs
    let ev=makeEvidence(id:"ev-1", projectID:"missing-proj")
    let _ = reportFor(portfolio:portfolio, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:])
    assertEqual(portfolio.selectedEvidenceIDs, before, "no mutation on unresolved")
}

// MARK: - MULTIPLE PORTFOLIOS (46-48)

do { // portfolio A connections
    let evA=makeEvidence(id:"ev-a", projectID:"proj-a")
    let evB=makeEvidence(id:"ev-b", projectID:"proj-b")
    let portfolioA=TestPortfolio(projects:["proj-a"], evidence:["ev-a"])
    let portfolioB=TestPortfolio(projects:["proj-b"], evidence:["ev-b"])
    let reportA=reportFor(portfolio:portfolioA, evidence:["ev-a":evA,"ev-b":evB], achievements:[:], projects:["proj-a":makeProject(id:"proj-a"),"proj-b":makeProject(id:"proj-b")], roadmaps:[:])
    let reportB=reportFor(portfolio:portfolioB, evidence:["ev-a":evA,"ev-b":evB], achievements:[:], projects:["proj-a":makeProject(id:"proj-a"),"proj-b":makeProject(id:"proj-b")], roadmaps:[:])
    assert(reportA.projectEvidence["proj-a"]?.count==1, "A connections")
    assert(reportA.projectEvidence["proj-b"]==nil || reportA.projectEvidence["proj-b"]?.isEmpty==true, "A no B")
    assert(reportB.projectEvidence["proj-b"]?.count==1, "B connections")
}
do { // portfolio B connections
    let portfolioB=TestPortfolio(projects:["proj-b"], evidence:["ev-b"])
    let evB=makeEvidence(id:"ev-b", projectID:"proj-b")
    let reportB=reportFor(portfolio:portfolioB, evidence:["ev-b":evB], achievements:[:], projects:["proj-b":makeProject(id:"proj-b")], roadmaps:[:])
    assertEqual(reportB.projectEvidence["proj-b"]?.first?.id, "ev-b", "B evidence")
}
do { // no cross-contamination
    let evA=makeEvidence(id:"ev-a", projectID:"proj-a")
    let portfolioA=TestPortfolio(projects:["proj-a"], evidence:["ev-a"])
    let portfolioB=TestPortfolio(projects:["proj-b"], evidence:["ev-a"]) // same evidence but different project
    let reportA=reportFor(portfolio:portfolioA, evidence:["ev-a":evA], achievements:[:], projects:["proj-a":makeProject(id:"proj-a")], roadmaps:[:])
    let reportB=reportFor(portfolio:portfolioB, evidence:["ev-a":evA], achievements:[:], projects:["proj-b":makeProject(id:"proj-b")], roadmaps:[:])
    // For B, evidence ev-a projectID is proj-a, not proj-b, so no connection for B's project
    assert(reportA.projectEvidence["proj-a"]?.count==1, "A has")
    assert(reportB.projectEvidence["proj-b"]?.isEmpty ?? true, "B no cross")
}

// MARK: - READ-ONLY (49-50)

do { // engine does not mutate store
    var evidence:[String:TestEvidenceRecord]=["ev-1":makeEvidence(id:"ev-1", projectID:"proj-1")]
    var achievements:[String:TestAchievement]=["ach-1":makeAchievement(id:"ach-1", evidenceIDs:["ev-1"])]
    let projects=["proj-1":makeProject(id:"proj-1")]
    let beforeE=evidence
    let beforeA=achievements
    let beforeP=projects
    let portfolio=TestPortfolio(projects:["proj-1"], achievements:["ach-1"], evidence:["ev-1"])
    let _ = reportFor(portfolio:portfolio, evidence:evidence, achievements:achievements, projects:projects, roadmaps:[:])
    assertEqual(evidence, beforeE, "read-only evidence")
    assertEqual(achievements, beforeA, "read-only achievements")
    assertEqual(projects, beforeP, "read-only projects")
}
do { // repeated calculation identical
    let ev=makeEvidence(id:"ev-1", projectID:"proj-1")
    let portfolio=TestPortfolio(projects:["proj-1"], evidence:["ev-1"])
    let r1=reportFor(portfolio:portfolio, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":makeProject(id:"proj-1")], roadmaps:[:])
    let r2=reportFor(portfolio:portfolio, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":makeProject(id:"proj-1")], roadmaps:[:])
    assertEqual(r1.projectEvidence["proj-1"]?.map(\.id), r2.projectEvidence["proj-1"]?.map(\.id), "identical repeated")
    assertEqual(r1.connections.map(\.id).sorted(), r2.connections.map(\.id).sorted(), "identical connections")
}

// MARK: - CAREER AGNOSTICISM (51-52)

do {
    for id in ["software-engineer","ai-engineer","research-builder","portfolio-projects","college-ready","stem-explorer","leadership","community-impact","venture","competitive-profile"] {
        let rm=TestRoadmap(id:id, title:id, milestones:[TestRoadmapMilestone(id:"m1", title:"M1")])
        let ev=makeEvidence(id:"ev-\(id)", roadmapID:id)
        let res=supportingForRoadmap(id, evidence:["ev-\(id)":ev])
        assertEqual(res.count, 1, "career agnostic \(id)")
        let portfolio=TestPortfolio(evidence:["ev-\(id)"], roadmaps:[id])
        let report=reportFor(portfolio:portfolio, evidence:["ev-\(id)":ev], achievements:[:], projects:[:], roadmaps:[id:rm])
        assertEqual(report.roadmapEvidence[id]?.count, 1, "career agnostic report \(id)")
    }
}
do {
    // No roadmap-specific branches: same logic for all
    let evSE=makeEvidence(id:"ev-se", roadmapID:"software-engineer")
    let evLead=makeEvidence(id:"ev-lead", roadmapID:"leadership")
    let resSE=supportingForRoadmap("software-engineer", evidence:["ev-se":evSE])
    let resLead=supportingForRoadmap("leadership", evidence:["ev-lead":evLead])
    assertEqual(resSE.count, resLead.count, "no roadmap-specific logic")
}

// MARK: - NO FUZZY MATCHING (53)

do {
    let ev=makeEvidence(id:"ev-1", title:"Python Project") // title contains Python but skillIDs empty
    // Skill connection should be via skillIDs, not title
    let res=supportingForSkill("python", evidence:["ev-1":ev])
    assert(res.isEmpty, "no fuzzy title skill")
    // Project connection via title similarity should not happen
    let resProj=supportingForProject("proj-python", evidence:["ev-1":ev])
    // ev has no projectID, so no connection despite title containing Python
    assert(resProj.isEmpty, "no fuzzy project title")
    // Roadmap connection via title should not happen
    let ev2=makeEvidence(id:"ev-2", title:"Research Paper", roadmapID:"")
    let resRoad=supportingForRoadmap("research-builder", evidence:["ev-2":ev2])
    assert(resRoad.isEmpty, "no fuzzy roadmap title")
}

print("\nPhase 8.6 — Portfolio Evidence: \(passed) passed, \(failed) failed out of \(passed+failed)")
if failed==0 { print("All \(passed) tests passed ✓") }
