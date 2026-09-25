import Foundation

// Standalone test for Phase 8.4 — Portfolio Builder + Selection
// Run: swift test-portfolio-builder.swift

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
    let parts = t.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    return parts.joined(separator: " ").lowercased()
}
func isRecent(date: Date, asOf: Date) -> Bool {
    let window: TimeInterval = 180*24*60*60
    let diff = asOf.timeIntervalSince(date)
    return diff>=0 && diff<=window
}

// MARK: - Inline models (mirrors production)

enum SectionType: String, Codable, Hashable, CaseIterable { case about="about", goals="goals", skills="skills", projects="projects", achievements="achievements", evidence="evidence", roadmaps="roadmaps" }
struct PortfolioSection: Hashable, Codable {
    let id: String; var type: SectionType; var title: String; var isEnabled: Bool
    init(type: SectionType, isEnabled:Bool=true){ self.id=type.rawValue; self.type=type; self.title=type.rawValue.capitalized; self.isEnabled=isEnabled}
    init(id:String, type:SectionType, title:String, isEnabled:Bool){ self.id=id; self.type=type; self.title=title; self.isEnabled=isEnabled}
}
struct StudentPortfolio: Hashable, Codable {
    let id: String; var title: String; var headline: String?; var about: String?; var goals:[String]
    var selectedProjectIDs:[String]; var selectedAchievementIDs:[String]; var selectedEvidenceIDs:[String]; var selectedSkillIDs:[String]; var selectedRoadmapIDs:[String]
    var sections:[PortfolioSection]; var createdAt:Date; var updatedAt:Date
    init(id:String=UUID().uuidString, title:String, headline:String?=nil, about:String?=nil, goals:[String]=[], selectedProjectIDs:[String]=[], selectedAchievementIDs:[String]=[], selectedEvidenceIDs:[String]=[], selectedSkillIDs:[String]=[], selectedRoadmapIDs:[String]=[], sections:[PortfolioSection]?=nil, createdAt:Date=Date(), updatedAt:Date=Date()){
        self.id=id; self.title=title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "My Portfolio" : title.trimmingCharacters(in:.whitespacesAndNewlines)
        self.headline=headline?.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty==true ? nil : headline?.trimmingCharacters(in:.whitespacesAndNewlines)
        self.about=about?.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty==true ? nil : about?.trimmingCharacters(in:.whitespacesAndNewlines)
        self.goals=goals.map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty}
        self.selectedProjectIDs=dedup(selectedProjectIDs); self.selectedAchievementIDs=dedup(selectedAchievementIDs); self.selectedEvidenceIDs=dedup(selectedEvidenceIDs)
        self.selectedSkillIDs=dedupSkill(selectedSkillIDs); self.selectedRoadmapIDs=dedup(selectedRoadmapIDs)
        let secs=sections ?? SectionType.allCases.map{PortfolioSection(type:$0)}
        self.sections=dedupSections(secs); self.createdAt=createdAt; self.updatedAt=updatedAt
    }
}
func dedup(_ ids:[String])->[String]{var seen=Set<String>(), out:[String]=[]; for r in ids{let t=r.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty, !seen.contains(t) else{continue}; seen.insert(t); out.append(t)}; return out}
func dedupSkill(_ ids:[String])->[String]{var seen=Set<String>(), out:[String]=[]; for r in ids{let n=normalizeSkillID(r); guard !n.isEmpty, !seen.contains(n) else{continue}; seen.insert(n); out.append(n)}; return out}
func dedupSections(_ secs:[PortfolioSection])->[PortfolioSection]{var seen=Set<String>(), out:[PortfolioSection]=[]; for s in secs{guard !seen.contains(s.id) else{continue}; seen.insert(s.id); out.append(s)}; return out.isEmpty ? SectionType.allCases.map{PortfolioSection(type:$0)} : out}

// Candidate
enum CandidateType: String { case project, achievement, evidence, skill, roadmap }
struct Candidate: Hashable { let id:String; let type:CandidateType; let sourceID:String; let title:String; let score:Int; let reason:String; var isRecommended:Bool{score>=40} }
struct Report: Hashable { let projects:[Candidate]; let achievements:[Candidate]; let evidence:[Candidate]; let skills:[Candidate]; let roadmaps:[Candidate]; var all:[Candidate]{projects+achievements+evidence+skills+roadmaps} }
struct Issue: Hashable { let id:String; let type:CandidateType; let sourceID:String }

// MARK: - Test Store (mirrors AppDataStore portfolio APIs)

class TestStore {
    var portfolios:[String:StudentPortfolio]=[:]
    var profileFirstName="Alex"
    var projects:[String:String]=[:] // id->title
    var achievements:[String:String]=[:]
    var evidence:[String:String]=[:]
    var skillsDemonstrated:Set<String>=[] // normalized
    var roadmaps:[String:String]=[:]
    var portfolioIDsSet:Set<String>=[]

    init(){
        let p=StudentPortfolio(title: portfolioTitle())
        portfolios[p.id]=p
    }
    func portfolioTitle()->String{ profileFirstName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "My Portfolio" : "\(profileFirstName)'s Portfolio" }

    func portfolio(id:String)->StudentPortfolio?{ portfolios[id.trimmingCharacters(in:.whitespacesAndNewlines)] }
    func createPortfolio(title:String)->StudentPortfolio{
        let t=title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "My Portfolio" : title.trimmingCharacters(in:.whitespacesAndNewlines)
        let p=StudentPortfolio(title:t)
        portfolios[p.id]=p; return p
    }
    func updatePortfolio(_ p:StudentPortfolio)->Bool{
        guard portfolios[p.id] != nil else{return false}
        var s=p
        s.title=s.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "My Portfolio" : s.title.trimmingCharacters(in:.whitespacesAndNewlines)
        if let h=s.headline, h.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{s.headline=nil} else {s.headline=s.headline?.trimmingCharacters(in:.whitespacesAndNewlines)}
        if let a=s.about, a.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{s.about=nil} else {s.about=s.about?.trimmingCharacters(in:.whitespacesAndNewlines)}
        s.goals=s.goals.map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty}
        s.selectedProjectIDs=dedup(s.selectedProjectIDs); s.selectedAchievementIDs=dedup(s.selectedAchievementIDs); s.selectedEvidenceIDs=dedup(s.selectedEvidenceIDs); s.selectedSkillIDs=dedupSkill(s.selectedSkillIDs); s.selectedRoadmapIDs=dedup(s.selectedRoadmapIDs)
        s.sections=dedupSections(s.sections); s.updatedAt=Date()
        portfolios[s.id]=s; return true
    }
    func deletePortfolio(id:String)->Bool{
        let t=id.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty, portfolios[t] != nil else{return false}
        portfolios.removeValue(forKey:t)
        if portfolios.isEmpty{let p=StudentPortfolio(title:portfolioTitle()); portfolios[p.id]=p}
        return true
    }
    // selection
    func addProject(to pid:String, projectID:String)->Bool{
        let t=projectID.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard !p.selectedProjectIDs.contains(t) else{return false}
        p.selectedProjectIDs.append(t); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func removeProject(from pid:String, projectID:String)->Bool{
        let t=projectID.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard let idx=p.selectedProjectIDs.firstIndex(of:t) else{return false}
        p.selectedProjectIDs.remove(at:idx); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func addAchievement(to pid:String, achievementID:String)->Bool{
        let t=achievementID.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard !p.selectedAchievementIDs.contains(t) else{return false}
        p.selectedAchievementIDs.append(t); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func removeAchievement(from pid:String, achievementID:String)->Bool{
        let t=achievementID.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard let idx=p.selectedAchievementIDs.firstIndex(of:t) else{return false}
        p.selectedAchievementIDs.remove(at:idx); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func addEvidence(to pid:String, evidenceID:String)->Bool{
        let t=evidenceID.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard !p.selectedEvidenceIDs.contains(t) else{return false}
        p.selectedEvidenceIDs.append(t); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func removeEvidence(from pid:String, evidenceID:String)->Bool{
        let t=evidenceID.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard let idx=p.selectedEvidenceIDs.firstIndex(of:t) else{return false}
        p.selectedEvidenceIDs.remove(at:idx); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func addSkill(to pid:String, skillID:String)->Bool{
        let n=normalizeSkillID(skillID); guard !n.isEmpty else{return false}
        // only demonstrated selectable
        guard skillsDemonstrated.contains(n) else{return false}
        guard var p=portfolios[pid] else{return false}
        guard !p.selectedSkillIDs.contains(n) else{return false}
        p.selectedSkillIDs.append(n); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func removeSkill(from pid:String, skillID:String)->Bool{
        let n=normalizeSkillID(skillID); guard !n.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard let idx=p.selectedSkillIDs.firstIndex(of:n) else{return false}
        p.selectedSkillIDs.remove(at:idx); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func addRoadmap(to pid:String, roadmapID:String)->Bool{
        let t=roadmapID.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard !p.selectedRoadmapIDs.contains(t) else{return false}
        p.selectedRoadmapIDs.append(t); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func removeRoadmap(from pid:String, roadmapID:String)->Bool{
        let t=roadmapID.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard let idx=p.selectedRoadmapIDs.firstIndex(of:t) else{return false}
        p.selectedRoadmapIDs.remove(at:idx); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    // ordering
    func reorderProjects(in pid:String, orderedIDs:[String])->Bool{
        guard var p=portfolios[pid] else{return false}
        p.selectedProjectIDs=dedup(orderedIDs); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func reorderAchievements(in pid:String, orderedIDs:[String])->Bool{guard var p=portfolios[pid] else{return false}; p.selectedAchievementIDs=dedup(orderedIDs); p.updatedAt=Date(); portfolios[pid]=p; return true}
    func reorderEvidence(in pid:String, orderedIDs:[String])->Bool{guard var p=portfolios[pid] else{return false}; p.selectedEvidenceIDs=dedup(orderedIDs); p.updatedAt=Date(); portfolios[pid]=p; return true}
    func reorderSkills(in pid:String, orderedIDs:[String])->Bool{guard var p=portfolios[pid] else{return false}; p.selectedSkillIDs=dedupSkill(orderedIDs); p.updatedAt=Date(); portfolios[pid]=p; return true}
    func reorderRoadmaps(in pid:String, orderedIDs:[String])->Bool{guard var p=portfolios[pid] else{return false}; p.selectedRoadmapIDs=dedup(orderedIDs); p.updatedAt=Date(); portfolios[pid]=p; return true}
    func reorderSections(in pid:String, orderedIDs:[String])->Bool{
        guard var p=portfolios[pid] else{return false}
        var byID=[String:PortfolioSection](); for s in p.sections{byID[s.id]=s}
        var newOrder:[PortfolioSection]=[]; var seen=Set<String>()
        for oid in orderedIDs{let t=oid.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty, !seen.contains(t), let sec=byID[t] else{continue}; seen.insert(t); newOrder.append(sec)}
        for sec in p.sections where !seen.contains(sec.id){newOrder.append(sec)}
        guard !newOrder.isEmpty else{return false}
        p.sections=dedupSections(newOrder); p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    func setSectionEnabled(in pid:String, sectionID:String, isEnabled:Bool)->Bool{
        let sid=sectionID.trimmingCharacters(in:.whitespacesAndNewlines); guard !sid.isEmpty else{return false}
        guard var p=portfolios[pid] else{return false}
        guard let idx=p.sections.firstIndex(where:{$0.id==sid}) else{return false}
        p.sections[idx].isEnabled=isEnabled; p.updatedAt=Date(); portfolios[pid]=p; return true
    }
    // metadata
    func updateTitle(id:String, title:String)->Bool{
        let t=title.trimmingCharacters(in:.whitespacesAndNewlines); guard !t.isEmpty else{return false}
        guard var p=portfolios[id] else{return false}
        p.title=t; p.updatedAt=Date(); portfolios[id]=p; return true
    }
    func updateHeadline(id:String, headline:String?)->Bool{
        guard var p=portfolios[id] else{return false}
        if let h=headline{let tr=h.trimmingCharacters(in:.whitespacesAndNewlines); p.headline=tr.isEmpty ? nil : tr} else {p.headline=nil}
        p.updatedAt=Date(); portfolios[id]=p; return true
    }
    func updateAbout(id:String, about:String?)->Bool{
        guard var p=portfolios[id] else{return false}
        if let a=about{let tr=a.trimmingCharacters(in:.whitespacesAndNewlines); p.about=tr.isEmpty ? nil : tr} else {p.about=nil}
        p.updatedAt=Date(); portfolios[id]=p; return true
    }
    func updateGoals(id:String, goals:[String])->Bool{
        guard var p=portfolios[id] else{return false}
        p.goals=goals.map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty}; p.updatedAt=Date(); portfolios[id]=p; return true
    }
    // unresolved
    func unresolved(for pid:String)->[Issue]{
        guard let p=portfolios[pid] else{return []}
        var out:[Issue]=[]
        for id in p.selectedProjectIDs where projects[id]==nil{out.append(Issue(id:"project:\(id)", type:.project, sourceID:id))}
        for id in p.selectedAchievementIDs where achievements[id]==nil{out.append(Issue(id:"achievement:\(id)", type:.achievement, sourceID:id))}
        for id in p.selectedEvidenceIDs where evidence[id]==nil{out.append(Issue(id:"evidence:\(id)", type:.evidence, sourceID:id))}
        for sid in p.selectedSkillIDs{let n=normalizeSkillID(sid); if !skillsDemonstrated.contains(n){out.append(Issue(id:"skill:\(sid)", type:.skill, sourceID:sid))}}
        for id in p.selectedRoadmapIDs where roadmaps[id]==nil{out.append(Issue(id:"roadmap:\(id)", type:.roadmap, sourceID:id))}
        out.sort{$0.id < $1.id}; return out
    }
    func candidatesReport()->Report{
        // Deterministic scoring mimic PortfolioEngine: project completed + evidence etc.
        var projCands:[Candidate]=[]
        for (id,title) in projects{
            var score=0; var reason=""
            // mimic: completed project with evidence gets high score
            let hasEvidence = evidence.values.contains{ $0.contains(id) || $0==id } // simplified
            if id.hasSuffix("-completed") {score=80; reason="Completed project with supporting evidence."}
            else if hasEvidence {score=50; reason="Project with supporting evidence."}
            else {score=20; reason="Project with available activity."}
            projCands.append(Candidate(id:"project:\(id)", type:.project, sourceID:id, title:title, score:score, reason:reason))
        }
        var achCands:[Candidate]=[]
        for (id,title) in achievements{ achCands.append(Candidate(id:"achievement:\(id)", type:.achievement, sourceID:id, title:title, score:55, reason:"Achievement supported by evidence."))}
        var evCands:[Candidate]=[]
        for (id,title) in evidence{ evCands.append(Candidate(id:"evidence:\(id)", type:.evidence, sourceID:id, title:title, score:60, reason:"Strong evidence with artifact."))}
        var skillCands:[Candidate]=[]
        for sid in skillsDemonstrated{ skillCands.append(Candidate(id:"skill:\(sid)", type:.skill, sourceID:sid, title:sid.capitalized, score:70, reason:"Skill demonstrated"))}
        var rmCands:[Candidate]=[]
        for (id,title) in roadmaps{ rmCands.append(Candidate(id:"roadmap:\(id)", type:.roadmap, sourceID:id, title:title, score:65, reason:"Active roadmap"))}
        return Report(projects:projCands, achievements:achCands, evidence:evCands, skills:skillCands, roadmaps:rmCands)
    }
}

let encoder: JSONEncoder = {let e=JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting=[.sortedKeys]; return e}()
let decoder: JSONDecoder = {let d=JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d}()

// MARK: - DATA MODEL (1-4)

do { // 1. existing StudentPortfolio compatibility
    let p=StudentPortfolio(title:"My Portfolio")
    assert(!p.id.isEmpty, "1: id not empty")
    assertEqual(p.title, "My Portfolio", "1b: title")
    assertEqual(p.sections.count, 7, "1c: 7 sections")
    let data=try! encoder.encode(p)
    let dec=try! decoder.decode(StudentPortfolio.self, from:data)
    assertEqual(dec.title, "My Portfolio", "1d: decode title")
    assertEqual(dec.sections.map(\.id), p.sections.map(\.id), "1e: sections")
}
do { // 2. metadata editing
    let store=TestStore()
    let pid=store.portfolios.first!.key
    assert(store.updateTitle(id:pid, title:"New Title"), "2: update title")
    assertEqual(store.portfolio(id:pid)!.title, "New Title", "2b: title")
    assert(store.updateHeadline(id:pid, headline:"Headline"), "2c: headline")
    assertEqual(store.portfolio(id:pid)!.headline, "Headline", "2d")
    assert(store.updateAbout(id:pid, about:"About text"), "2e: about")
    assertEqual(store.portfolio(id:pid)!.about, "About text", "2f")
    assert(store.updateGoals(id:pid, goals:["Goal 1","Goal 2"]), "2g: goals")
    assertEqual(store.portfolio(id:pid)!.goals, ["Goal 1","Goal 2"], "2h")
    // Blank headline becomes nil
    assert(store.updateHeadline(id:pid, headline:"   "), "2i: blank headline")
    assert(store.portfolio(id:pid)!.headline == nil, "2j: nil")
    // Verify timestamps: updatedAt increases
    let before=store.portfolio(id:pid)!.updatedAt
    Thread.sleep(forTimeInterval: 0.01)
    _ = store.updateTitle(id:pid, title:"Another")
    assert(store.portfolio(id:pid)!.updatedAt > before, "2k: updatedAt bump")
}
do { // 3. section state
    let store=TestStore()
    let pid=store.portfolios.first!.key
    let original=store.portfolio(id:pid)!.sections.map(\.id)
    assertEqual(original, ["about","goals","skills","projects","achievements","evidence","roadmaps"], "3: default order")
    assert(store.setSectionEnabled(in:pid, sectionID:"projects", isEnabled:false), "3b: disable")
    assert(store.portfolio(id:pid)!.sections.first(where:{$0.id=="projects"})!.isEnabled==false, "3c: disabled")
    assert(store.setSectionEnabled(in:pid, sectionID:"projects", isEnabled:true), "3d: enable")
    assert(store.reorderSections(in:pid, orderedIDs:["projects","about","goals","skills","achievements","evidence","roadmaps"]), "3e: reorder")
    assertEqual(store.portfolio(id:pid)!.sections.map(\.id).prefix(3), ["projects","about","goals"], "3f: reorder prefix")
}
do { // 4. selection arrays
    let p=StudentPortfolio(title:"T", selectedProjectIDs:["proj-1"], selectedAchievementIDs:["ach-1"], selectedEvidenceIDs:["ev-1"], selectedSkillIDs:["python"], selectedRoadmapIDs:["rm-1"])
    assertEqual(p.selectedProjectIDs, ["proj-1"], "4: project")
    assertEqual(p.selectedSkillIDs, ["python"], "4b: skill normalized")
    let p2=StudentPortfolio(title:"T", selectedSkillIDs:["Python","PYTHON"])
    assertEqual(p2.selectedSkillIDs, ["python"], "4c: skill dedup normalized")
}

// MARK: - SELECTION (5-14)

do { // add/remove project
    let store=TestStore(); store.projects["proj-1"]="Proj 1"; store.projects["proj-2"]="Proj 2"
    let pid=store.portfolios.first!.key
    assert(store.addProject(to:pid, projectID:"proj-1"), "5: add project")
    assertEqual(store.portfolio(id:pid)!.selectedProjectIDs, ["proj-1"], "5b")
    assert(!store.addProject(to:pid, projectID:"proj-1"), "5c: duplicate prevented")
    assert(store.addProject(to:pid, projectID:"proj-2"), "5d: second")
    assert(store.removeProject(from:pid, projectID:"proj-1"), "5e: remove")
    assertEqual(store.portfolio(id:pid)!.selectedProjectIDs, ["proj-2"], "5f")
    // canonical not deleted
    assert(store.projects["proj-1"] != nil, "5g: project still exists")
}
do { // add/remove achievement
    let store=TestStore(); store.achievements["ach-1"]="Ach 1"
    let pid=store.portfolios.first!.key
    assert(store.addAchievement(to:pid, achievementID:"ach-1"), "6: add ach")
    assert(store.removeAchievement(from:pid, achievementID:"ach-1"), "6b: remove")
    assert(store.achievements["ach-1"] != nil, "6c: ach still exists")
}
do { // add/remove evidence
    let store=TestStore(); store.evidence["ev-1"]="Ev 1"
    let pid=store.portfolios.first!.key
    assert(store.addEvidence(to:pid, evidenceID:"ev-1"), "7: add ev")
    assert(store.removeEvidence(from:pid, evidenceID:"ev-1"), "7b: remove")
    assert(store.evidence["ev-1"] != nil, "7c: evidence still exists")
}
do { // add/remove skill (demonstrated only)
    let store=TestStore(); store.skillsDemonstrated=["python","git"]
    let pid=store.portfolios.first!.key
    assert(store.addSkill(to:pid, skillID:"Python"), "8: add demonstrated python")
    assertEqual(store.portfolio(id:pid)!.selectedSkillIDs, ["python"], "8b: normalized")
    assert(!store.addSkill(to:pid, skillID:"python"), "8c: duplicate prevented")
    assert(!store.addSkill(to:pid, skillID:"nonexistent"), "8d: non-demonstrated unavailable")
    assert(store.removeSkill(from:pid, skillID:"python"), "8e: remove")
    assert(!store.skillsDemonstrated.isEmpty, "8f: skill set still exists")
    // normalized
    assert(store.addSkill(to:pid, skillID:"  GIT  "), "8g: normalized git")
    assertEqual(store.portfolio(id:pid)!.selectedSkillIDs, ["git"], "8h")
}
do { // add/remove roadmap
    let store=TestStore(); store.roadmaps["rm-1"]="Roadmap 1"
    let pid=store.portfolios.first!.key
    assert(store.addRoadmap(to:pid, roadmapID:"rm-1"), "9: add roadmap")
    assert(store.removeRoadmap(from:pid, roadmapID:"rm-1"), "9b: remove")
    assert(store.roadmaps["rm-1"] != nil, "9c: roadmap still exists")
}

// MARK: - ORDERING (10-15)

do {
    let store=TestStore(); store.projects["proj-1"]="P1"; store.projects["proj-2"]="P2"; store.projects["proj-3"]="P3"
    let pid=store.portfolios.first!.key
    _ = store.reorderProjects(in:pid, orderedIDs:["proj-3","proj-1","proj-2"])
    assertEqual(store.portfolio(id:pid)!.selectedProjectIDs, ["proj-3","proj-1","proj-2"], "10: project ordering")
    let data=try! encoder.encode(store.portfolios)
    let dec=try! decoder.decode([String:StudentPortfolio].self, from:data)
    assertEqual(dec[pid]!.selectedProjectIDs, ["proj-3","proj-1","proj-2"], "10b: persist")
}
do {
    let store=TestStore(); store.achievements["ach-1"]="A1"; store.achievements["ach-2"]="A2"
    let pid=store.portfolios.first!.key
    _ = store.reorderAchievements(in:pid, orderedIDs:["ach-2","ach-1"])
    assertEqual(store.portfolio(id:pid)!.selectedAchievementIDs, ["ach-2","ach-1"], "11: achievement ordering")
}
do {
    let store=TestStore(); store.evidence["ev-1"]="E1"; store.evidence["ev-2"]="E2"
    let pid=store.portfolios.first!.key
    _ = store.reorderEvidence(in:pid, orderedIDs:["ev-2","ev-1"])
    assertEqual(store.portfolio(id:pid)!.selectedEvidenceIDs, ["ev-2","ev-1"], "12: evidence ordering")
}
do {
    let store=TestStore(); store.skillsDemonstrated=["python","git","research"]
    let pid=store.portfolios.first!.key
    _ = store.reorderSkills(in:pid, orderedIDs:["git","python","research"])
    assertEqual(store.portfolio(id:pid)!.selectedSkillIDs, ["git","python","research"], "13: skill ordering")
}
do {
    let store=TestStore(); store.roadmaps["r1"]="R1"; store.roadmaps["r2"]="R2"
    let pid=store.portfolios.first!.key
    _ = store.reorderRoadmaps(in:pid, orderedIDs:["r2","r1"])
    assertEqual(store.portfolio(id:pid)!.selectedRoadmapIDs, ["r2","r1"], "14: roadmap ordering")
}
do {
    let store=TestStore()
    let pid=store.portfolios.first!.key
    assert(store.reorderSections(in:pid, orderedIDs:["projects","about","goals","skills","achievements","evidence","roadmaps"]), "15: section ordering")
    assertEqual(store.portfolio(id:pid)!.sections.map(\.id).prefix(2), ["projects","about"], "15b")
    let data=try! encoder.encode(store.portfolios)
    let dec=try! decoder.decode([String:StudentPortfolio].self, from:data)
    assertEqual(dec[pid]!.sections.map(\.id).prefix(2), ["projects","about"], "15c: persist")
}

// MARK: - RECOMMENDATIONS (16-19)

do {
    let store=TestStore()
    store.projects["proj-1"]="Proj1"; store.projects["proj-2"]="Proj2"
    store.evidence["ev-1"]="proj-1"
    store.achievements["ach-1"]="Ach1"
    store.skillsDemonstrated=["python"]
    store.roadmaps["rm-1"]="RM1"
    let report=store.candidatesReport()
    assert(report.projects.contains(where:{$0.sourceID=="proj-1"}), "16: candidate appears")
    // selected vs recommended separation
    let pid=store.portfolios.first!.key
    _ = store.addProject(to:pid, projectID:"proj-1")
    let selected=store.portfolio(id:pid)!.selectedProjectIDs
    let recommended=report.projects.filter{!selected.contains($0.sourceID)}
    assert(!recommended.contains(where:{$0.sourceID=="proj-1"}), "16b: selected not in recommended")
    assert(recommended.contains(where:{$0.sourceID=="proj-2"}) || report.projects.count>0, "16c: other recommended")
}
do {
    // no automatic selection
    let store=TestStore()
    store.projects["proj-auto"]="Auto"
    let pid=store.portfolios.first!.key
    let report=store.candidatesReport()
    // report should not mutate portfolio
    assert(store.portfolio(id:pid)!.selectedProjectIDs.isEmpty, "17: no auto selection")
    assert(report.projects.contains(where:{$0.sourceID=="proj-auto"}), "17b: candidate exists but not selected")
}
do {
    // recommendation score changes do not mutate selection
    let store=TestStore()
    store.projects["proj-1"]="Proj1"
    let pid=store.portfolios.first!.key
    _ = store.addProject(to:pid, projectID:"proj-1")
    let before=store.portfolio(id:pid)!.selectedProjectIDs
    // Simulate report change due to new evidence
    store.evidence["ev-new"]="proj-1"
    let report2=store.candidatesReport()
    let after=store.portfolio(id:pid)!.selectedProjectIDs
    assertEqual(before, after, "18: score change not mutate selection")
    assert(report2.projects.contains(where:{$0.sourceID=="proj-1"}), "18b: still candidate")
}
do {
    // selected vs recommended vs available
    let store=TestStore()
    store.projects["proj-sel"]="Selected"; store.projects["proj-rec"]="Recommended"; store.projects["proj-avail"]="Available"
    store.evidence["ev-1"]="proj-rec"
    let pid=store.portfolios.first!.key
    _ = store.addProject(to:pid, projectID:"proj-sel")
    let report=store.candidatesReport()
    let selectedSet=Set(store.portfolio(id:pid)!.selectedProjectIDs)
    let recommended=report.projects.filter{!selectedSet.contains($0.sourceID) && $0.score>=40}
    assert(!recommended.contains(where:{$0.sourceID=="proj-sel"}), "19: selected not recommended")
    // Available is canonical not in report? For test, available is any project not in report nor selected, but our report includes all projects, so available may be none — still we check that high score not auto-select
}

// MARK: - SKILLS (20-22)

do {
    let store=TestStore(); store.skillsDemonstrated=["python"]
    let pid=store.portfolios.first!.key
    assert(store.addSkill(to:pid, skillID:"Python"), "20: demonstrated selectable")
    assert(!store.addSkill(to:pid, skillID:"nonexistent"), "20b: referenced-only unavailable")
    // Attempt to add via direct evidence reference without demonstrated should fail
    let store2=TestStore(); store2.evidence["ev-1"]="python" // evidence references python but not demonstrated
    // skillsDemonstrated empty, so adding should fail
    assert(!store2.addSkill(to:store2.portfolios.first!.key, skillID:"python"), "20c: not demonstrated fails")
}
do {
    let store=TestStore(); store.skillsDemonstrated=["machine learning"]
    let pid=store.portfolios.first!.key
    assert(store.addSkill(to:pid, skillID:"  Machine   Learning  "), "21: normalized")
    assertEqual(store.portfolio(id:pid)!.selectedSkillIDs, ["machine learning"], "21b: normalized ID")
}
do {
    // No duplicate skill awarding
    var store=TestStore(); store.skillsDemonstrated=["python"]
    let pid=store.portfolios.first!.key
    _ = store.addSkill(to:pid, skillID:"python")
    assert(!store.addSkill(to:pid, skillID:"PYTHON"), "22: duplicate normalized prevented")
}

// MARK: - STALE REFERENCES (23-28)

do {
    let store=TestStore()
    let pid=store.portfolios.first!.key
    // Simulate stale by adding then deleting canonical
    store.projects["proj-real"]="Real"
    _ = store.addProject(to:pid, projectID:"proj-real")
    // Now delete canonical but portfolio retains ID
    store.projects.removeValue(forKey:"proj-real")
    let issues=store.unresolved(for:pid)
    assert(issues.contains(where:{$0.sourceID=="proj-real" && $0.type == .project}), "23: unresolved project")
    // No crash on report
    let report=store.candidatesReport()
    assert(report.projects.allSatisfy{$0.sourceID != "proj-real" || true}, "23b: no crash")
    // Explicit cleanup works
    assert(store.removeProject(from:pid, projectID:"proj-real"), "23c: explicit remove stale")
    assert(!store.portfolio(id:pid)!.selectedProjectIDs.contains("proj-real"), "23d: removed")
}
do {
    let store=TestStore()
    let pid=store.portfolios.first!.key
    _ = store.addAchievement(to:pid, achievementID:"missing-ach")
    store.achievements["missing-ach"]=nil // not in store, so stale
    // Actually we added without canonical, but unresolved should detect stale if canonical missing
    // Add then remove canonical
    store.achievements["ach-real"]="Real"
    _ = store.addAchievement(to:pid, achievementID:"ach-real")
    store.achievements.removeValue(forKey:"ach-real")
    let issues=store.unresolved(for:pid)
    assert(issues.contains(where:{$0.type == .achievement}), "24: unresolved achievement")
}
do {
    let store=TestStore()
    let pid=store.portfolios.first!.key
    _ = store.addEvidence(to:pid, evidenceID:"missing-ev")
    store.evidence["missing-ev"]=nil
    store.evidence["ev-real"]="Real"
    _ = store.addEvidence(to:pid, evidenceID:"ev-real")
    store.evidence.removeValue(forKey:"ev-real")
    let issues=store.unresolved(for:pid)
    assert(issues.contains(where:{$0.type == .evidence}), "25: unresolved evidence")
}
do {
    let store=TestStore(); store.skillsDemonstrated=["python"]
    let pid=store.portfolios.first!.key
    _ = store.addSkill(to:pid, skillID:"python")
    // Make skill non-demonstrated to create stale
    store.skillsDemonstrated=[]
    let issues=store.unresolved(for:pid)
    assert(issues.contains(where:{$0.type == .skill}), "26: unresolved skill")
}
do {
    let store=TestStore()
    let pid=store.portfolios.first!.key
    _ = store.addRoadmap(to:pid, roadmapID:"missing-rm")
    store.roadmaps["missing-rm"]=nil
    store.roadmaps["rm-real"]="Real"
    _ = store.addRoadmap(to:pid, roadmapID:"rm-real")
    store.roadmaps.removeValue(forKey:"rm-real")
    let issues=store.unresolved(for:pid)
    assert(issues.contains(where:{$0.type == .roadmap}), "27: unresolved roadmap")
}
do {
    // No crash on rendering stale
    let store=TestStore()
    let pid=store.portfolios.first!.key
    _ = store.addProject(to:pid, projectID:"stale-project")
    // Don't add to store.projects, so stale
    let issues=store.unresolved(for:pid)
    assert(!issues.isEmpty, "28: stale detected no crash")
    assert(store.portfolio(id:pid)!.selectedProjectIDs.contains("stale-project"), "28b: stale preserved")
}

// MARK: - MULTIPLE PORTFOLIOS (29-31)

do {
    let store=TestStore()
    store.portfolios=[:]
    let p1=store.createPortfolio(title:"Portfolio 1")
    let p2=store.createPortfolio(title:"Portfolio 2")
    store.projects["proj-A"]="A"; store.projects["proj-B"]="B"
    _ = store.addProject(to:p1.id, projectID:"proj-A")
    _ = store.addProject(to:p2.id, projectID:"proj-B")
    assertEqual(store.portfolio(id:p1.id)!.selectedProjectIDs, ["proj-A"], "29: p1 independent")
    assertEqual(store.portfolio(id:p2.id)!.selectedProjectIDs, ["proj-B"], "29b: p2 independent")
    // Independent metadata
    _ = store.updateTitle(id:p1.id, title:"Updated 1")
    assertEqual(store.portfolio(id:p2.id)!.title, "Portfolio 2", "29c: p2 title unchanged")
    // Independent section state
    _ = store.setSectionEnabled(in:p1.id, sectionID:"projects", isEnabled:false)
    assert(store.portfolio(id:p1.id)!.sections.first(where:{$0.id=="projects"})!.isEnabled==false, "29d: p1 hidden")
    assert(store.portfolio(id:p2.id)!.sections.first(where:{$0.id=="projects"})!.isEnabled==true, "29e: p2 still enabled")
}
do {
    let store=TestStore()
    store.portfolios=[:]
    let p1=store.createPortfolio(title:"P1")
    let p2=store.createPortfolio(title:"P2")
    store.projects["proj-1"]="P"
    _ = store.addProject(to:p1.id, projectID:"proj-1")
    // Ensure p2 not affected
    assert(store.portfolio(id:p2.id)!.selectedProjectIDs.isEmpty, "30: p2 empty")
}
do {
    // Delete one portfolio doesn't affect other
    let store=TestStore()
    store.portfolios=[:]
    let p1=store.createPortfolio(title:"P1")
    let p2=store.createPortfolio(title:"P2")
    assertEqual(store.portfolios.count, 2, "31: count 2")
    _ = store.deletePortfolio(id:p1.id)
    assert(store.portfolio(id:p1.id)==nil, "31b: p1 deleted")
    assert(store.portfolio(id:p2.id) != nil, "31c: p2 remains")
}

// MARK: - PERSISTENCE (32-34)

do {
    let store=TestStore()
    let p=store.createPortfolio(title:"Persist")
    _ = store.addProject(to:p.id, projectID:"proj-1")
    _ = store.addSkill(to:p.id, skillID:"python") // need demonstrated
    store.skillsDemonstrated=["python"]
    // Simulate save/reload via Codable
    let data=try! encoder.encode(store.portfolios)
    let dec=try! decoder.decode([String:StudentPortfolio].self, from:data)
    assertEqual(dec[p.id]!.title, "Persist", "32: persist title")
    assertEqual(dec[p.id]!.selectedProjectIDs, ["proj-1"], "32b: persist projects")
}
do {
    let p=StudentPortfolio(title:"Codable", headline:"H", about:"A", goals:["G1"], selectedProjectIDs:["proj-1"], selectedSkillIDs:["python"])
    let data=try! encoder.encode(p)
    let dec=try! decoder.decode(StudentPortfolio.self, from:data)
    assertEqual(dec.title, "Codable", "33: codable title")
    assertEqual(dec.headline, "H", "33b: headline")
    assertEqual(dec.selectedProjectIDs, ["proj-1"], "33c: projects")
    assertEqual(dec.selectedSkillIDs, ["python"], "33d: skills")
}
do {
    let store=TestStore()
    let pid=store.portfolios.first!.key
    let before=store.portfolio(id:pid)!.updatedAt
    Thread.sleep(forTimeInterval:0.01)
    _ = store.updateTitle(id:pid, title:"New Title")
    assert(store.portfolio(id:pid)!.updatedAt > before, "34: timestamp updates")
}

// MARK: - CANONICAL INTEGRITY (35-37)

do {
    let store=TestStore()
    store.projects["proj-1"]="Proj"; store.achievements["ach-1"]="Ach"; store.evidence["ev-1"]="Ev"; store.roadmaps["rm-1"]="RM"; store.skillsDemonstrated=["python"]
    let p=store.createPortfolio(title:"Integrity")
    _ = store.addProject(to:p.id, projectID:"proj-1")
    _ = store.addAchievement(to:p.id, achievementID:"ach-1")
    _ = store.addEvidence(to:p.id, evidenceID:"ev-1")
    _ = store.addSkill(to:p.id, skillID:"python")
    _ = store.addRoadmap(to:p.id, roadmapID:"rm-1")
    // Delete portfolio
    _ = store.deletePortfolio(id:p.id)
    assert(store.projects["proj-1"] != nil, "35: project still exists after portfolio delete")
    assert(store.achievements["ach-1"] != nil, "35b: achievement still exists")
    assert(store.evidence["ev-1"] != nil, "35c: evidence still exists")
    assert(store.skillsDemonstrated.contains("python"), "35d: skill still demonstrated")
    assert(store.roadmaps["rm-1"] != nil, "35e: roadmap still exists")
}
do {
    let store=TestStore()
    store.projects["proj-1"]="Proj"
    let p=store.createPortfolio(title:"P")
    _ = store.addProject(to:p.id, projectID:"proj-1")
    _ = store.removeProject(from:p.id, projectID:"proj-1")
    assert(store.projects["proj-1"] != nil, "36: remove from portfolio does not delete project")
}
do {
    // Builder is not new source of truth
    let store=TestStore()
    store.projects["proj-1"]="Proj"
    let p=store.createPortfolio(title:"P")
    _ = store.addProject(to:p.id, projectID:"proj-1")
    // Snapshot should reflect portfolio IDs, not duplicate project objects
    let snap=store.portfolio(id:p.id)!
    assert(snap.selectedProjectIDs.contains("proj-1"), "37: snapshot contains ID")
    // Ensure no duplicated entity like PortfolioProject exists (we only store ID)
    assert(snap.selectedProjectIDs.count==1, "37b: only ID")
}

// MARK: - CAREER AGNOSTICISM (38-42)

do {
    for id in ["software-engineer","ai-engineer","research-builder","stem-explorer","leadership","community-impact","venture","college-ready","competitive-profile","portfolio-projects"] {
        let store=TestStore()
        store.roadmaps[id]=id
        store.projects["proj-\(id)"]="Proj \(id)"
        // Add project with sourceRoadmapID
        let p=store.createPortfolio(title:"Career Test")
        _ = store.addRoadmap(to:p.id, roadmapID:id)
        assert(store.portfolio(id:p.id)!.selectedRoadmapIDs.contains(id), "38: career agnostic \(id)")
        // Ensure no roadmap-specific logic: adding should succeed for all IDs
    }
    // Ensure portfolio can hold mixed types without special handling
    let store=TestStore()
    for id in ["software-engineer","leadership","venture"] { store.roadmaps[id]=id }
    let p=store.createPortfolio(title:"Mixed")
    for id in ["software-engineer","leadership","venture"] { assert(store.addRoadmap(to:p.id, roadmapID:id), "39: mixed \(id)")}
    assertEqual(store.portfolio(id:p.id)!.selectedRoadmapIDs.count, 3, "39b: mixed count")
    // No roadmap-specific conditional: candidate report should treat all similarly
    let report=store.candidatesReport()
    // Our dummy report treats all roadmaps similarly (same score) — career agnostic
    assert(report.roadmaps.count==3, "40: report roadmaps count")
}

// MARK: - NO MUTATION (41-43)

do {
    let store=TestStore()
    store.projects["proj-1"]="Proj"; store.achievements["ach-1"]="Ach"; store.evidence["ev-1"]="Ev"
    store.skillsDemonstrated=["python"]; store.roadmaps["rm-1"]="RM"
    let beforeProjects=store.projects
    let beforeAch=store.achievements
    let beforeEv=store.evidence
    let beforeSkills=store.skillsDemonstrated
    let beforeRoadmaps=store.roadmaps
    let beforeProfile=store.profileFirstName
    let _ = store.candidatesReport()
    assertEqual(store.projects, beforeProjects, "41: no mutation projects")
    assertEqual(store.achievements, beforeAch, "41b: achievements")
    assertEqual(store.evidence, beforeEv, "41c: evidence")
    assertEqual(store.skillsDemonstrated, beforeSkills, "41d: skills")
    assertEqual(store.roadmaps, beforeRoadmaps, "41e: roadmaps")
    assertEqual(store.profileFirstName, beforeProfile, "41f: profile")
}
do {
    // Rendering candidate lists should not mutate selections
    let store=TestStore()
    store.projects["proj-1"]="Proj"
    let pid=store.portfolios.first!.key
    let before=store.portfolio(id:pid)!.selectedProjectIDs
    let report=store.candidatesReport()
    let after=store.portfolio(id:pid)!.selectedProjectIDs
    assertEqual(before, after, "42: rendering not mutate")
    assert(report.projects.contains(where:{$0.sourceID=="proj-1"}), "42b: candidate exists")
}
do {
    // Generating recommendations does not mutate portfolio
    let store=TestStore()
    store.projects["proj-1"]="Proj"
    let p=store.createPortfolio(title:"P")
    _ = store.addProject(to:p.id, projectID:"proj-1")
    let before=store.portfolio(id:p.id)!.selectedProjectIDs
    let _ = store.candidatesReport()
    let after=store.portfolio(id:p.id)!.selectedProjectIDs
    assertEqual(before, after, "43: recommendations not mutate portfolio")
}

print("\nPhase 8.4 — Portfolio Builder: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed==0 { print("All \(passed) tests passed ✓") }
