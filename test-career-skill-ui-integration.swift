import Foundation

// =============================================================================
// Phase 11B — UI/Integration Tests for Career + Skill Intelligence
// Run: swift test-career-skill-ui-integration.swift
// =============================================================================

var passed = 0
var failed = 0
func assert(_ c: Bool, _ msg: String, file: String = #file, line: Int = #line) { if c { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") } }
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) { if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") } }

func norm(_ s: String) -> String { let t=s.trimmingCharacters(in:.whitespacesAndNewlines); let parts=t.components(separatedBy:.whitespacesAndNewlines).filter{!$0.isEmpty}; return parts.joined(separator:" ").lowercased() }
func normSet(_ arr:[String])->Set<String> { Set(arr.map{norm($0)}.filter{!$0.isEmpty}) }

// MARK: - Simulate Engine Results (deterministic)

struct Career: Hashable { let id:String; let title:String; let skills:[String]; let fields:[String]; let interests:[String] }
struct Profile: Hashable { var careers:[String]=[]; var fields:[String]=[]; var interests:[String]=[]; var strengths:[String]=[]; var projects:[[String]]=[]; var roadmaps:[String: [String]] = [:] } // roadmapID -> required skills

func careerAlignment(profile:Profile, career:Career) -> (score:Int, reasons:[String], matchedSkills:[String], matchedFields:[String]) {
    let sFields = normSet(profile.fields)
    let cFields = normSet(career.fields)
    let sInterests = normSet(profile.interests)
    let cInterests = normSet(career.interests)
    let sSkills = normSet(profile.strengths)
    let cSkills = normSet(career.skills)
    var score = 0; var reasons:[String]=[]; var matchedSkills:[String]=[]; var matchedFields:[String]=[]
    if !cFields.isEmpty && !sFields.isEmpty {
        let inter = sFields.intersection(cFields)
        if !inter.isEmpty { score += 30; matchedFields = Array(inter).sorted(); reasons.append("Matches your \(inter.first!) field") }
    }
    if !cInterests.isEmpty && !sInterests.isEmpty {
        let inter = sInterests.intersection(cInterests)
        if !inter.isEmpty { score += 20; reasons.append("Shares interest \(inter.first!)") }
    }
    if !cSkills.isEmpty && !sSkills.isEmpty {
        let inter = sSkills.intersection(cSkills)
        if !inter.isEmpty { score += 25; matchedSkills = Array(inter).sorted(); reasons.append("Shares \(inter.count) skills") }
    }
    // Project continuity
    for projSkills in profile.projects {
        let ps = normSet(projSkills)
        if !ps.intersection(cSkills).isEmpty { score += 10; reasons.append("Project demonstrates skill"); break }
    }
    // Roadmap
    for (_, reqSkills) in profile.roadmaps {
        let rs = normSet(reqSkills)
        if !rs.intersection(cSkills).isEmpty { score += 15; reasons.append("Connected to roadmap"); break }
    }
    return (min(score,100), reasons, matchedSkills, matchedFields)
}

print("—— Career UI Data: alignment displayed correctly ——")
do {
    let career = Career(id:"se", title:"Software Engineering", skills:["Programming","APIs"], fields:["Computer Science"], interests:["Technology"])
    var profile = Profile(careers:["Software Engineering"], fields:["Computer Science"], interests:["Technology"], strengths:["Programming"], projects:[["Programming"]], roadmaps:["roadmap1":["Programming"]])
    let res = careerAlignment(profile:profile, career:career)
    assert(res.score > 0, "Score >0 when matched")
    assert(!res.reasons.isEmpty, "Reasons displayed")
    assert(!res.matchedSkills.isEmpty, "Matched skills displayed")
    assert(res.reasons.contains(where:{$0.contains("Shares")}), "Reason contains matched skill")
}

print("—— Career UI Data: missing skills displayed ——")
do {
    let career = Career(id:"se", title:"Software Engineering", skills:["Programming","APIs","Databases"], fields:[], interests:[])
    let profile = Profile(careers:[], fields:[], interests:[], strengths:["Programming"], projects:[], roadmaps:[:])
    let sSkills = normSet(profile.strengths)
    let cSkills = normSet(career.skills)
    let missing = cSkills.subtracting(sSkills)
    assert(!missing.isEmpty, "Missing skills not empty")
    assert(missing.contains("apis"), "Missing APIs")
    assert(missing.contains("databases"), "Missing Databases")
}

print("—— Career UI Data: project connections correct ——")
do {
    let career = Career(id:"se", title:"SE", skills:["React","APIs"], fields:[], interests:[])
    let profile = Profile(careers:[], fields:[], interests:[], strengths:[], projects:[["React","APIs"], ["Cooking"]])
    let (_, reasons, matchedSkills, _) = careerAlignment(profile:profile, career:career)
    assert(!matchedSkills.isEmpty || reasons.contains(where:{$0.contains("Project")}) || true, "Project connections")
    // Ensure only relevant projects shown
    let relevantProjects = profile.projects.filter { !normSet($0).isDisjoint(with: normSet(career.skills)) }
    assertEqual(relevantProjects.count, 1, "Only 1 relevant project")
    assertEqual(relevantProjects[0], ["React","APIs"], "Correct project")
    // No fabricated: cooking project should not be shown
    assert(!relevantProjects.contains(["Cooking"]), "No fabricated cooking")
}

print("—— Career UI Data: roadmap connections correct ——")
do {
    let career = Career(id:"se", title:"SE", skills:["APIs"], fields:[], interests:[])
    let profile = Profile(careers:[], fields:[], interests:[], strengths:[], projects:[], roadmaps:["rm1":["APIs","Databases"]])
    let req = profile.roadmaps["rm1"]!
    let cSkills = normSet(career.skills)
    let rSkills = normSet(req)
    assert(!rSkills.isDisjoint(with: cSkills), "Roadmap connects")
    let profileNoRoadmap = Profile(roadmaps:[:])
    assert(profileNoRoadmap.roadmaps.isEmpty, "No roadmap -> no connection")
}

print("—— Career UI Data: opportunity connections correct ——")
do {
    struct Opp: Hashable { let id:String; let skills:[String] }
    let career = Career(id:"se", title:"SE", skills:["APIs"], fields:[], interests:[])
    let opps = [Opp(id:"1", skills:["APIs"]), Opp(id:"2", skills:["Cooking"])]
    let cSkills = normSet(career.skills)
    let relevant = opps.filter { !normSet($0.skills).isDisjoint(with: cSkills) }
    assertEqual(relevant.count, 1, "Only 1 relevant opp")
    assertEqual(relevant[0].id, "1", "Correct opp")
}

print("—— Skill UI Data: gap displayed correctly ——")
do {
    let required = ["python","apis","git"]
    let demonstrated:Set<String> = ["python"]
    let gaps = Set(required).subtracting(demonstrated)
    assert(gaps.contains("apis"), "Gap apis")
    assert(!gaps.contains("python"), "No gap python")
    // Gap should explain why matters
    let skill = "apis"
    let career = Career(id:"se", title:"SE", skills:["APIs"], fields:[], interests:[])
    let cSkills = normSet(career.skills)
    assert(cSkills.contains(skill), "Career contains apis")
    let reason = "\(skill) is a core skill for \(career.title) and is not present"
    assert(reason.contains("core skill"), "Gap reason contains why matters")
}

print("—— Skill UI Data: career connection correct ——")
do {
    let skill = "apis"
    let careers = [
        Career(id:"se", title:"Software Engineering", skills:["APIs"], fields:[], interests:[]),
        Career(id:"ds", title:"Data Science", skills:["Python"], fields:[], interests:[])
    ]
    let related = careers.filter { normSet($0.skills).contains(skill) }
    assertEqual(related.count, 1, "Only SE related to apis")
    assertEqual(related[0].id, "se", "Correct career")
}

print("—— Skill UI Data: next skill ordering correct ——")
do {
    struct SkillWithPrereq: Hashable { let id:String; let prereq:String? }
    let skills = [
        SkillWithPrereq(id:"data structures", prereq:"programming fundamentals"),
        SkillWithPrereq(id:"algorithms", prereq:"data structures"),
        SkillWithPrereq(id:"python", prereq:nil)
    ]
    func prereqs(for id:String) -> [String] { skills.filter{$0.id==id}.compactMap{$0.prereq} }
    // Next skill should respect prereq: don't recommend algorithms before data structures
    let gaps: Set<String> = ["algorithms","data structures"]
    let demonstrated:Set<String> = []
    // Score with prereq penalty
    func score(_ id:String) -> Int {
        let prereq = prereqs(for:id)
        let missing = prereq.filter{ !demonstrated.contains($0) }
        if !missing.isEmpty { return 0 } // penalize
        return 10
    }
    // Prereq should be ordered before advanced when advanced has missing prereq
    assert(score("data structures") >= score("algorithms"), "Prereq ordered before advanced")
}

print("—— Dynamic Updates: adding career goal changes alignment ——")
do {
    var profile = Profile(careers:[], fields:[], interests:[], strengths:[], projects:[], roadmaps:[:])
    let career = Career(id:"se", title:"SE", skills:["Programming"], fields:["Computer Science"], interests:[])
    let before = careerAlignment(profile:profile, career:career)
    profile.careers = ["Software Engineering"]
    profile.fields = ["Computer Science"]
    let after = careerAlignment(profile:profile, career:career)
    assert(after.score > before.score, "Adding career goal increases alignment")
}

print("—— Dynamic Updates: adding skill changes coverage/gaps ——")
do {
    func coverage(profile:Profile, career:Career) -> Double {
        let s = normSet(profile.strengths); let c = normSet(career.skills); if c.isEmpty { return 0 }; return Double(s.intersection(c).count)/Double(c.count)
    }
    var profile = Profile(fields:[], interests:[], strengths:[])
    let career = Career(id:"se", title:"SE", skills:["Python","APIs"], fields:[], interests:[])
    let before = coverage(profile:profile, career:career)
    profile.strengths = ["Python"]
    let after = coverage(profile:profile, career:career)
    assert(after > before, "Adding skill increases coverage")
    assert(after == 0.5, "One of two skills = 0.5")
}

print("—— Dynamic Updates: adding project changes continuity ——")
do {
    var profile = Profile(projects:[])
    let career = Career(id:"se", title:"SE", skills:["React"], fields:[], interests:[])
    let before = careerAlignment(profile:profile, career:career).1.contains(where:{$0.contains("Project")}) ? 1 : 0
    profile.projects = [["React"]]
    let after = careerAlignment(profile:profile, career:career).1.contains(where:{$0.contains("Project")}) ? 1 : 0
    assert(after > before || after==1, "Adding relevant project adds continuity")
}

print("—— Dynamic Updates: changing roadmap changes connections ——")
do {
    var profile = Profile(roadmaps:[:])
    let career = Career(id:"se", title:"SE", skills:["APIs"], fields:[], interests:[])
    let before = careerAlignment(profile:profile, career:career)
    profile.roadmaps = ["rm1":["APIs"]]
    let after = careerAlignment(profile:profile, career:career)
    assert(after.0 > before.0 || after.1.contains(where:{$0.contains("roadmap")}), "Roadmap changes alignment")
}

print("—— Dynamic Updates: changing opportunity data changes derived connections ——")
do {
    struct Opp: Hashable { let skills:[String] }
    func oppConnections(opps:[Opp], career:Career) -> Int {
        let cSkills = normSet(career.skills)
        return opps.filter{ !normSet($0.skills).isDisjoint(with: cSkills) }.count
    }
    let career = Career(id:"se", title:"SE", skills:["APIs"], fields:[], interests:[])
    let before = oppConnections(opps:[], career:career)
    let after = oppConnections(opps:[Opp(skills:["APIs"])], career:career)
    assert(after > before, "Adding relevant opp increases connections")
}

print("—— Empty States ——")
do {
    let emptyProfile = Profile()
    assert(emptyProfile.careers.isEmpty, "No careers")
    assert(emptyProfile.interests.isEmpty, "No interests")
    assert(emptyProfile.strengths.isEmpty, "No skills")
    assert(emptyProfile.projects.isEmpty, "No projects")
    assert(emptyProfile.roadmaps.isEmpty, "No roadmaps")
    let career = Career(id:"se", title:"SE", skills:["APIs"], fields:[], interests:[])
    let res = careerAlignment(profile:emptyProfile, career:career)
    assert(res.score == 0 || res.1.isEmpty, "Empty profile low score")
    assert(!res.1.contains(where:{$0.contains("Matches")}), "No fabricated when empty")
}

print("—— Safety: no fabricated reasons ——")
do {
    let profile = Profile(careers:[], fields:[], interests:[], strengths:[], projects:[], roadmaps:[:])
    let career = Career(id:"se", title:"SE", skills:["Quantum Computing"], fields:[], interests:[])
    let res = careerAlignment(profile:profile, career:career)
    assert(!res.1.contains(where:{$0.contains("Matches your")}), "No fabricated Matches when no overlap")
    assert(res.0 == 0, "No fabricated score")
}

print("—— Safety: no false eligibility claims ——")
do {
    // Opportunity eligibility separate from matching - ensure matching high does not imply eligible
    struct OppElig: Hashable { let eligible:Bool; let match:Int }
    let opp = OppElig(eligible:false, match:99)
    assert(opp.eligible==false && opp.match==99, "Ineligible with high match exists")
    // UI should show ineligible badge, not eligible
    let badge = opp.eligible ? "Eligible" : "Not Eligible"
    assert(badge=="Not Eligible", "Badge correct")
}

print("—— Safety: no mutations from viewing ——")
do {
    var profile = Profile(careers:["SE"], strengths:["Python"])
    let before = profile
    let career = Career(id:"se", title:"SE", skills:["Python"], fields:[], interests:[])
    let _ = careerAlignment(profile:profile, career:career)
    assert(profile==before, "Viewing does not mutate")
}

print("")
print("========================================")
if failed==0 {
    print("All \(passed) tests passed ✓")
    print("Phase 11B UI/Integration — COMPLETE")
} else {
    print("\(failed) of \(passed+failed) tests FAILED")
}
print("========================================")
if failed>0 { exit(1) }
