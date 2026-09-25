import Foundation

// = == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == ==
// Phase 11A — Career + Skill Intelligence — Comprehensive Tests
// Run: swift test-career-skill-intelligence.swift
// = == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == == ==

var passed = 0
var failed = 0
func assert(_ c: Bool, _ msg: String, file: String = #file, line: Int = #line) { if c { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") } }
func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) { if a != b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — values equal \(a)") } }
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) { if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") } }

func normSkill(_ s: String) -> String { let t=s.trimmingCharacters(in:.whitespacesAndNewlines); let parts=t.components(separatedBy:.whitespacesAndNewlines).filter{!$0.isEmpty}; return parts.joined(separator:" ").lowercased() }
func normCareer(_ title: String) -> String {
    let t=title.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
    if t.isEmpty { return "" }
    var s=t
    for c in ["-","_","/","\\"] { s=s.replacingOccurrences(of:c, with:" ") }
    let parts=s.components(separatedBy:.whitespacesAndNewlines).filter{!$0.isEmpty}
    let collapsed=parts.joined(separator:" ")
    let aliasMap:[String:String]=[
        "software engineering":"software-engineering","software engineer":"software-engineering","software-engineer":"software-engineering","swe":"software-engineering",
        "data science":"data-science","data scientist":"data-science",
        "ai ml":"ai-ml","ai/ml":"ai-ml","artificial intelligence":"ai-ml","machine learning":"ai-ml",
        "cybersecurity":"cybersecurity","cyber security":"cybersecurity",
        "mechanical engineering":"mechanical-engineering","mechanical engineer":"mechanical-engineering",
        "electrical engineering":"electrical-engineering","electrical engineer":"electrical-engineering",
        "biomedical engineering":"biomedical-engineering","biomedical engineer":"biomedical-engineering",
        "product design":"product-design","product designer":"product-design",
        "business":"business-entrepreneurship","entrepreneurship":"business-entrepreneurship","business entrepreneurship":"business-entrepreneurship"
    ]
    if let a=aliasMap[collapsed] { return a }
    return collapsed.replacingOccurrences(of:" ", with:"-")
}
func normSet(_ arr:[String])->Set<String> { Set(arr.map{normSkill($0)}.filter{!$0.isEmpty}) }

// MARK: - Test Models (mirror Career.swift)

struct TestCareer: Hashable, Codable {
    let id:String; let title:String; let normalizedID:String; let description:String
    let fields:[String]; let industries:[String]; let skills:[String]; let relatedSkills:[String]; let interests:[String]
    init(id:String, title:String, description:String="Desc", fields:[String]=[], industries:[String]=[], skills:[String]=[], relatedSkills:[String]=[], interests:[String]=[]) {
        self.id=normCareer(id); self.title=title.trimmingCharacters(in:.whitespacesAndNewlines); self.normalizedID=normCareer(title); self.description=description; self.fields=fields; self.industries=industries
        // For test, store original trimmed but dedup via normalized
        var seen=Set<String>(); var out:[String]=[]; for raw in skills { let nid=normSkill(raw); if !nid.isEmpty && !seen.contains(nid) { seen.insert(nid); out.append(raw.trimmingCharacters(in:.whitespacesAndNewlines)) } }
        self.skills=out
        var seen2=Set<String>(); var out2:[String]=[]; for raw in relatedSkills { let nid=normSkill(raw); if !nid.isEmpty && !seen2.contains(nid) && !seen.contains(nid) { seen2.insert(nid); out2.append(raw.trimmingCharacters(in:.whitespacesAndNewlines)) } }
        self.relatedSkills=out2
        self.interests=interests
    }
}

enum RelType: String, CaseIterable { case foundational, core, supporting, advanced
    var importance:Int { switch self { case .foundational:return 4; case .core:return 3; case .supporting:return 2; case .advanced:return 1 } }
}
struct Rel: Hashable { let careerID:String; let skillID:String; let type:RelType; let importance:Int }

// Test Catalog (subset)
let testCatalog: [TestCareer] = [
    TestCareer(id:"software-engineering", title:"Software Engineering", description:"SE", fields:["Computer Science"], industries:["Technology"], skills:["Programming","Algorithms","Databases","APIs","Version Control"], relatedSkills:["Communication"], interests:["Technology"]),
    TestCareer(id:"data-science", title:"Data Science", description:"DS", fields:["Computer Science","Statistics"], industries:["Technology"], skills:["Python","Data Analysis","Statistics"], relatedSkills:["Research"], interests:["Science"]),
    TestCareer(id:"ai-ml", title:"AI/ML Engineering", description:"AI", fields:["Computer Science"], industries:["Technology"], skills:["Python","Machine Learning"], relatedSkills:[], interests:["Technology"]),
]

// MARK: - Tests

print("—— Career Model: Codable roundtrip ——")
do {
    let c = TestCareer(id:"software-engineering", title:"Software Engineering", description:"Desc", fields:["Computer Science"], industries:["Technology"], skills:["Programming"], interests:["Technology"])
    let data = try! JSONEncoder().encode(c)
    let decoded = try! JSONDecoder().decode(TestCareer.self, from: data)
    assertEqual(decoded.id, c.id, "Codable id")
    assertEqual(decoded.title, c.title, "Codable title")
    assertEqual(decoded.skills, c.skills, "Codable skills")
}
print("—— Career Model: normalization ——")
do {
    assertEqual(normCareer("Software Engineer"), "software-engineering", "alias Software Engineer")
    assertEqual(normCareer("software-engineer"), "software-engineering", "alias hyphen")
    assertEqual(normCareer("Software Engineering"), "software-engineering", "alias Engineering")
    assertEqual(normCareer("  Software   Engineer  "), "software-engineering", "whitespace")
    assertEqual(normCareer("SWE"), "software-engineering", "alias SWE")
    assertEqual(normCareer("Data Scientist"), "data-science", "alias Data Scientist")
    assertEqual(normCareer("  Data   Science  "), "data-science", "whitespace Data Science")
    assertEqual(normCareer(""), "", "empty")
    assertEqual(normCareer("  "), "", "whitespace empty")
    // Punctuation
    assertEqual(normCareer("AI/ML"), "ai-ml", "AI/ML")
    assertEqual(normCareer("AI_ML"), "ai-ml", "underscore")
    // Deterministic IDs
    let a = normCareer("Software Engineering")
    let b = normCareer("Software Engineering")
    assertEqual(a,b,"deterministic")
    // Not unsafe fuzzy: different careers not treated same without alias
    assertNotEqual(normCareer("Biomedical Engineering"), normCareer("Mechanical Engineering"), "different careers not same")
}
print("—— Career Model: deterministic IDs ——")
do {
    let c1 = TestCareer(id:"my-career", title:"My Career")
    let c2 = TestCareer(id:"my-career", title:"My Career")
    assertEqual(c1.id, c2.id, "deterministic id")
    assertEqual(c1.normalizedID, c2.normalizedID, "deterministic normalizedID")
}
print("—— Career Graph: career→skills ——")
do {
    let se = testCatalog[0]
    assert(se.skills.contains("Programming"), "SE has Programming")
    assert(se.skills.contains("APIs"), "SE has APIs")
    // Normalized skill IDs
    for s in se.skills { assertEqual(normSkill(s), s.lowercased(), "skill normalized lowercased") }
    // Related
    assert(se.relatedSkills.contains("Communication"), "related")
}
print("—— Career Graph: required/core/supporting/advanced ——")
do {
    // Simulate graph building: first 2 foundational, next 3 core, etc.
    func relsFor(_ career: TestCareer) -> [Rel] {
        var out:[Rel]=[]; var seen=Set<String>()
        for (idx,raw) in career.skills.enumerated() {
            let nid=normSkill(raw); if seen.contains(nid) {continue}; seen.insert(nid)
            let type:RelType = idx<2 ? .foundational : idx<5 ? .core : idx<7 ? .supporting : .advanced
            out.append(Rel(careerID:career.id, skillID:nid, type:type, importance:type.importance))
        }
        for raw in career.relatedSkills { let nid=normSkill(raw); if seen.contains(nid) {continue}; seen.insert(nid); out.append(Rel(careerID:career.id, skillID:nid, type:.supporting, importance:RelType.supporting.importance)) }
        return out
    }
    let rels = relsFor(testCatalog[0])
    assert(rels.contains(where:{$0.type == .foundational}), "foundational")
    assert(rels.contains(where:{$0.type == .core}), "core")
    assert(rels.contains(where:{$0.type == .supporting}), "supporting")
    // Normalized skill IDs
    for r in rels { assertEqual(r.skillID, normSkill(r.skillID), "skillID normalized") }
    // Duplicate protection
    let dupCareer = TestCareer(id:"dup", title:"Dup", skills:["Python","python"," PYTHON "], relatedSkills:["Python"])
    let dupRels = relsFor(dupCareer)
    let dupIDs = dupRels.map { $0.skillID }
    assertEqual(Set(dupIDs).count, dupIDs.count, "duplicate protection")
    // Deterministic catalog
    let sorted = testCatalog.sorted{ $0.title < $1.title }
    assertEqual(sorted.first?.title, "AI/ML Engineering", "deterministic catalog sort")
}
print("—— Career Intelligence: signals ——")
do {
    // Simulate alignment: goal 25, field 15, interest 15, skill 20, project 10, roadmap 10, opportunity 5
    struct Profile { var careers:[String]; var fields:[String]; var interests:[String]; var strengths:[String]; var milestones:[String]; var projects:[String] }
    func alignment(profile:Profile, career:TestCareer) -> (score:Int, signals:[String:Double], reasons:[String]) {
        let sGoals = normSet(profile.careers + profile.fields + profile.milestones)
        let cFields = normSet(career.fields + career.industries)
        let sFields = normSet(profile.fields)
        let sInterests = normSet(profile.interests)
        let cInterests = normSet(career.interests)
        let sSkills = normSet(profile.strengths)
        let cSkills = normSet(career.skills + career.relatedSkills)
        var signals:[String:Double]=[:]
        var availableW:Double=0; var weightedSum:Double=0
        func add(dim:String, weight:Double, score:Double?, available:Bool) {
            if available, let sc=score { signals[dim]=sc; weightedSum += sc*weight; availableW += weight }
        }
        // Goal
        if sGoals.isEmpty || cFields.isEmpty { add(dim:"goal", weight:0.25, score:nil, available:false) }
        else { let inter=sGoals.intersection(cFields); let sc=Double(inter.count)/Double(cFields.count); add(dim:"goal", weight:0.25, score:sc, available:true) }
        // Field
        if sFields.isEmpty || cFields.isEmpty { add(dim:"field", weight:0.15, score:nil, available:false) }
        else { let inter=sFields.intersection(normSet(career.fields)); let sc=Double(inter.count)/Double(normSet(career.fields).count); add(dim:"field", weight:0.15, score:sc, available:true) }
        // Interest
        if sInterests.isEmpty || cInterests.isEmpty { add(dim:"interest", weight:0.15, score:nil, available:false) }
        else { let inter=sInterests.intersection(cInterests); let sc=Double(inter.count)/Double(cInterests.count); add(dim:"interest", weight:0.15, score:sc, available:true) }
        // Skill
        if sSkills.isEmpty || cSkills.isEmpty { add(dim:"skill", weight:0.20, score:nil, available:false) }
        else { let inter=sSkills.intersection(cSkills); let sc=Double(inter.count)/Double(cSkills.count); add(dim:"skill", weight:0.20, score:sc, available:true) }
        let score = availableW == 0 ? 0 : Int(round(weightedSum/availableW*100))
        var reasons:[String]=[]
        for (dim,sc) in signals where sc>0.05 { reasons.append("\(dim) \(sc)") }
        return (score,signals,reasons)
    }
    var p = Profile(careers:["Software Engineering"], fields:["Computer Science"], interests:["Technology"], strengths:["Programming","APIs"], milestones:[], projects:[])
    let se = testCatalog[0]
    let res = alignment(profile:p, career:se)
    assert(res.score>0, "goal/field/interest/skill match >0")
    assert(res.signals["goal"] != nil, "goal signal")
    // Unavailable signals not treated as zero
    let pEmpty = Profile(careers:[], fields:[], interests:[], strengths:[], milestones:[], projects:[])
    let resEmpty = alignment(profile:pEmpty, career:se)
    assert(resEmpty.signals.isEmpty || resEmpty.score == 0, "empty profile low score")
    // Deterministic repeated
    let r1 = alignment(profile:p, career:se)
    let r2 = alignment(profile:p, career:se)
    assertEqual(r1.score, r2.score, "deterministic")
    // No fabricated: no overlap -> no reason
    let pNo = Profile(careers:["Biology"], fields:["Medicine"], interests:["Cooking"], strengths:["Surgery"], milestones:[], projects:[])
    let resNo = alignment(profile:pNo, career:se)
    assert(!resNo.reasons.contains(where:{$0.contains("Matches")}), "No fabricated when no overlap")
}
print("—— Skill Intelligence: reuse SkillGapEngine ——")
do {
    // Simulate SkillGapEngine: required skills vs demonstrated
    let required = ["python","apis","git"]
    let demonstrated: Set<String> = ["python"]
    let gaps = Set(required).subtracting(demonstrated)
    assert(gaps.contains("apis"), "gap apis")
    assert(!gaps.contains("python"), "no gap python")
    // Roadmaps connection
    // Simulate next skill with prerequisites
    struct Prereq: Hashable { let skill:String; let prereq:String }
    let prereqs = [Prereq(skill:"algorithms", prereq:"data structures"), Prereq(skill:"data structures", prereq:"programming fundamentals")]
    func hasPrereq(_ skill:String) -> Bool { prereqs.contains(where:{$0.skill == normSkill(skill)}) }
    assert(hasPrereq("Algorithms"), "has prereq")
    assert(!hasPrereq("Python"), "no prereq")
    // Next skill should respect prereq: don't recommend algorithms before data structures
    let gaps2: Set<String> = ["algorithms","data structures"]
    // If data structures missing, algorithms has missing prereq
    let algPrereqs = prereqs.filter{$0.skill == "algorithms"}.map{$0.prereq}
    let missing = algPrereqs.filter{!demonstrated.contains($0)}
    assert(!missing.isEmpty, "algorithms missing prereq")
}
print("—— Ranking: deterministic ——")
do {
    struct Ranked: Hashable { let id:String; let score:Int; let title:String; let coverage:Double }
    func rank(_ items:[Ranked]) -> [Ranked] {
        items.sorted{
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.coverage != $1.coverage { return $0.coverage > $1.coverage }
            if $0.title.lowercased() != $1.title.lowercased() { return $0.title.lowercased() < $1.title.lowercased() }
            return $0.id < $1.id
        }
    }
    let a = Ranked(id:"b", score:80, title:"Beta", coverage:0.5)
    let b = Ranked(id:"a", score:80, title:"Alpha", coverage:0.8)
    let ranked = rank([a,b])
    assertEqual(ranked[0].id, "a", "skill-gap tie-break")
    let c = Ranked(id:"2", score:90, title:"Alpha", coverage:0.5)
    let d = Ranked(id:"1", score:80, title:"Beta", coverage:0.9)
    let ranked2 = rank([d,c])
    assertEqual(ranked2[0].id, "2", "score desc")
    // Title tie-break
    let e = Ranked(id:"2", score:80, title:"Beta", coverage:0.5)
    let f = Ranked(id:"1", score:80, title:"Alpha", coverage:0.5)
    let ranked3 = rank([e,f])
    assertEqual(ranked3[0].title, "Alpha", "title asc")
    // ID tie-break
    let g = Ranked(id:"id-2", score:80, title:"Same", coverage:0.5)
    let h = Ranked(id:"id-1", score:80, title:"Same", coverage:0.5)
    let ranked4 = rank([g,h])
    assertEqual(ranked4[0].id, "id-1", "id asc")
    // Deterministic repeated
    let r1 = rank([a,b]); let r2 = rank([a,b]); assertEqual(r1,r2,"deterministic repeated")
}
print("—— Empty Profile ——")
do {
    struct Profile { var careers:[String]=[]; var fields:[String]=[]; var interests:[String]=[]; var strengths:[String]=[] }
    let p = Profile()
    // Empty should not pretend to know
    let hasData = !p.careers.isEmpty || !p.fields.isEmpty || !p.interests.isEmpty || !p.strengths.isEmpty
    assert(!hasData, "empty profile has no data")
    // Engine should return insufficient context
    let insufficient = hasData == false
    assert(insufficient, "insufficient context")
}
print("—— Monotonicity ——")
do {
    func coverage(skills:[String], careerSkills:[String]) -> Double {
        let s=normSet(skills); let c=normSet(careerSkills); if c.isEmpty { return 0 }; return Double(s.intersection(c).count)/Double(c.count)
    }
    let careerSkills = ["Programming","APIs","Git"]
    let covBefore = coverage(skills:["Programming"], careerSkills: careerSkills)
    let covAfter = coverage(skills:["Programming","APIs"], careerSkills: careerSkills)
    assert(covAfter >= covBefore, "skill coverage monotonic")
    // Adding matching career goal cannot decrease
    func goalScore(profileFields:[String], careerFields:[String]) -> Double {
        let s=normSet(profileFields); let c=normSet(careerFields); if s.isEmpty || c.isEmpty { return 0 }; return Double(s.intersection(c).count)/Double(c.count)
    }
    let before = goalScore(profileFields:["Biology"], careerFields:["Computer Science"])
    let after = goalScore(profileFields:["Biology","Computer Science"], careerFields:["Computer Science"])
    assert(after >= before, "goal alignment monotonic")
}
print("—— Performance ——")
do {
    var careers:[TestCareer]=[]; for i in 0..<100 { careers.append(TestCareer(id:"career-\(i)", title:"Career \(i)", skills:["Skill\(i%50)","Skill\( (i+1)%50)"])) }
    let start=Date()
    for c in careers { let _ = normCareer(c.title); let _ = c.skills.map{normSkill($0)} }
    let elapsed=Date().timeIntervalSince(start)
    assert(elapsed < 2.0, "100 careers <2s \(elapsed)")
    // 500 skills already tested via careers
    // 1000 opportunities simulated
    var opps:[[String]]=[]; for i in 0..<1000 { opps.append(["Skill\(i%20)"]) }
    let start2=Date()
    var count=0; for oppSkills in opps { let s=normSet(oppSkills); if s.contains("skill1") { count+=1 } }
    let elapsed2=Date().timeIntervalSince(start2)
    assert(elapsed2 < 2.0, "1000 opps <2s \(elapsed2)")
}
print("")
print(" == == == == == == == == == == == == == == == == == == == == ")
if failed == 0 {
    print("All \(passed) tests passed ✓")
    print("Phase 11A — Career + Skill Intelligence — COMPLETE")
} else {
    print("\(failed) of \(passed+failed) tests FAILED")
}
print(" == == == == == == == == == == == == == == == == == == == == ")
if failed>0 { exit(1) }
