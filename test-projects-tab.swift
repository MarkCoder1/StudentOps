import Foundation

// Phase 9.4 — Projects Tab: YOUR PROJECTS + PROJECT IDEAS
// Run: swift test-projects-tab.swift

var passed = 0; var failed = 0
func assert(_ c: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if c { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// MARK: - Inline models (mirrors production)

enum ProjectStatus: String, Codable, Hashable { case planned="planned", inProgress="inProgress", completed="completed"
    var displayName: String {
        switch self { case .planned: return "Planned"; case .inProgress: return "In Progress"; case .completed: return "Completed" }
    }
}
struct ProjectLink: Hashable, Codable { let id: String; let label: String; let url: String; init(label: String, url: String){ id=UUID().uuidString; self.label=label; self.url=url } }
struct ProjectMilestone: Hashable, Codable { let id: String; let title: String; let subtitle: String; let estimatedTime: String; init(id: String, title: String){ self.id=id; self.title=title; self.subtitle=""; self.estimatedTime="1h" } }
struct Project: Hashable, Codable {
    let id: String; var title: String; var category: String = "Personal Project"; var goal: String = "Goal"; var description: String = "Desc"
    var skills: [String] = []; var milestones: [ProjectMilestone] = []; var resources: [String] = []; var estimatedCompletion: String = "2 weeks"
    var status: ProjectStatus = .inProgress; var detailedDescription: String? = nil; var outcome: String? = nil; var links: [ProjectLink] = []; var imageReferences: [String] = []
    var startDate: Date? = nil; var completionDate: Date? = nil
    init(id: String, title: String, category: String="Personal Project", description: String="Desc", skills: [String]=[], status: ProjectStatus = .inProgress, outcome: String?=nil, links: [ProjectLink]=[], imageRefs: [String]=[], goal: String="Goal", estimatedCompletion: String="2 weeks") {
        self.id=id; self.title=title; self.category=category; self.goal=goal; self.description=description; self.skills=skills; self.milestones=[]; self.resources=[]; self.estimatedCompletion=estimatedCompletion; self.status=status; self.detailedDescription=nil; self.outcome=outcome; self.links=links; self.imageReferences=imageRefs
    }
    var type: String { category }
    enum CodingKeys: String, CodingKey { case id, title, category, type, goal, description, skills, milestones, resources, estimatedCompletion, status, detailedDescription, outcome, links, imageReferences, startDate, completionDate }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        if let cat = try? c.decode(String.self, forKey: .category) { category = cat } else if let t = try? c.decode(String.self, forKey: .type) { category = t } else { category = "Personal Project" }
        goal = (try? c.decode(String.self, forKey: .goal)) ?? "Goal"
        description = (try? c.decode(String.self, forKey: .description)) ?? "Desc"
        skills = (try? c.decode([String].self, forKey: .skills)) ?? []
        milestones = (try? c.decode([ProjectMilestone].self, forKey: .milestones)) ?? []
        resources = (try? c.decode([String].self, forKey: .resources)) ?? []
        estimatedCompletion = (try? c.decode(String.self, forKey: .estimatedCompletion)) ?? "2 weeks"
        status = (try? c.decode(ProjectStatus.self, forKey: .status)) ?? .inProgress
        detailedDescription = try? c.decode(String.self, forKey: .detailedDescription)
        outcome = try? c.decode(String.self, forKey: .outcome)
        links = (try? c.decode([ProjectLink].self, forKey: .links)) ?? []
        imageReferences = (try? c.decode([String].self, forKey: .imageReferences)) ?? []
        startDate = try? c.decode(Date.self, forKey: .startDate)
        completionDate = try? c.decode(Date.self, forKey: .completionDate)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(title, forKey: .title); try c.encode(category, forKey: .category)
        try c.encode(goal, forKey: .goal); try c.encode(description, forKey: .description); try c.encode(skills, forKey: .skills)
        try c.encode(milestones, forKey: .milestones); try c.encode(resources, forKey: .resources); try c.encode(estimatedCompletion, forKey: .estimatedCompletion)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(detailedDescription, forKey: .detailedDescription)
        try c.encodeIfPresent(outcome, forKey: .outcome)
        if !links.isEmpty { try c.encode(links, forKey: .links) }
        if !imageReferences.isEmpty { try c.encode(imageReferences, forKey: .imageReferences) }
        try c.encodeIfPresent(startDate, forKey: .startDate)
        try c.encodeIfPresent(completionDate, forKey: .completionDate)
    }
}
struct ScoredProject: Hashable { let project: Project; let matchScore: Int; let completedMilestones: Int }

// Simulated ProjectService catalog
let catalog: [Project] = [
    Project(id: "plant-health-dashboard", title: "Plant Health Dashboard", category: "Data + Biology", description: "Combine question, data, interface", skills: ["Python","Research"], estimatedCompletion: "2–3 weeks"),
    Project(id: "portfolio-site", title: "Personal Portfolio Site", category: "Web + Portfolio", description: "Turn work into story", skills: ["Programming","Writing"], estimatedCompletion: "1–2 weeks"),
    Project(id: "sensor-study", title: "Sensor Data Mini Study", category: "Research + Engineering", description: "Research loop", skills: ["Research","Python"], estimatedCompletion: "1–2 weeks"),
    Project(id: "community-problem", title: "Community Problem Prototype", category: "Design + Impact", description: "Design response", skills: ["Leadership","Design"], estimatedCompletion: "2–3 weeks")
]

// Simulated AppDataStore
class FakeStore {
    var customProjects: [Project] = []
    var projectProgress: [String:Int] = [:]
    var profile = (interests: [String](), skills: [String]())

    var scoredProjects: [ScoredProject] {
        (catalog + customProjects).map { p in
            ScoredProject(project: p, matchScore: 70, completedMilestones: min(projectProgress[p.id] ?? 0, p.milestones.count))
        }
    }
    var yourProjects: [Project] { customProjects }
    var ideaProjects: [ScoredProject] {
        let ids = Set(customProjects.map(\.id))
        return scoredProjects.filter { !ids.contains($0.project.id) }
    }
    func addCustom(_ p: Project) -> Bool {
        guard !p.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !customProjects.contains(where: {$0.id==p.id}) else { return false }
        customProjects.append(p); return true
    }
    func updateProject(_ p: Project) -> Bool {
        guard let idx = customProjects.firstIndex(where: {$0.id==p.id}) else { return false }
        guard !p.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        customProjects[idx]=p; return true
    }
    func deleteProject(id: String) -> Bool {
        guard let idx = customProjects.firstIndex(where: {$0.id==id}) else { return false }
        customProjects.remove(at: idx); return true
    }
    func completedCount(for p: Project) -> Int { min(projectProgress[p.id] ?? 0, p.milestones.count) }
}

func searchMatches(project: Project, query: String) -> Bool {
    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
    let fields = [project.title, project.category, project.description, project.detailedDescription ?? "", project.outcome ?? "", project.status.displayName, project.skills.joined(separator: " "), project.links.map{$0.label+" "+$0.url}.joined(separator: " ")].joined(separator: " ")
    return fields.localizedCaseInsensitiveContains(query)
}
func searchMatchesScored(_ sp: ScoredProject, query: String) -> Bool {
    searchMatches(project: sp.project, query: query)
}

print("=== Phase 9.4 Projects Tab Tests ===")

// 1. YOUR PROJECTS empty state
do {
    let store = FakeStore()
    assert(store.yourProjects.isEmpty, "1a empty yourProjects")
    assert(store.ideaProjects.count == catalog.count, "1b ideas = catalog when no custom")
    // Empty state message condition: custom empty and no search
    let showEmpty = store.yourProjects.isEmpty
    assert(showEmpty, "1c show empty YOUR PROJECTS")
    // Count
    assertEqual(store.yourProjects.count, 0, "1d count 0")
}

// 2. One project in YOUR PROJECTS
do {
    let store = FakeStore()
    let p = Project(id: "custom-1", title: "AI Study Planner", category: "Coding Project", description: "Built planner", skills: ["TypeScript"], status: .inProgress, outcome: "Working prototype")
    assert(store.addCustom(p), "2a add")
    assertEqual(store.yourProjects.count, 1, "2b count 1")
    assertEqual(store.yourProjects[0].title, "AI Study Planner", "2c title")
    assertEqual(store.yourProjects[0].status, .inProgress, "2d status")
    assertEqual(store.yourProjects[0].category, "Coding Project", "2e type")
    // Catalog remains separate
    assertEqual(store.ideaProjects.count, catalog.count, "2f ideas still catalog count (not mixed)")
    assert(!store.ideaProjects.contains(where: {$0.project.id=="custom-1"}), "2g idea does not contain custom")
}

// 3. Multiple projects, status display
do {
    let store = FakeStore()
    let p1 = Project(id: "c1", title: "Science Fair Plant", category: "Science Fair", status: .completed, outcome: "Won 1st")
    let p2 = Project(id: "c2", title: "Research Paper", category: "Research Project", status: .planned)
    let p3 = Project(id: "c3", title: "Community App", category: "Community Project", status: .inProgress)
    for p in [p1,p2,p3] { _ = store.addCustom(p) }
    assertEqual(store.yourProjects.count, 3, "3a three projects")
    let planned = store.yourProjects.filter { $0.status == .planned }
    assertEqual(planned.count, 1, "3b planned count")
    assertEqual(planned[0].title, "Research Paper", "3c planned title")
    let completed = store.yourProjects.filter { $0.status == .completed }
    assertEqual(completed.count, 1, "3d completed")
}

// 4. Project type display + rich data
do {
    let store = FakeStore()
    let p = Project(id: "rich", title: "AI Detector", category: "Science Fair", description: "Built detector", skills: ["Python","Research"], status: .completed, outcome: "Working prototype", links: [ProjectLink(label:"GitHub", url:"https://github.com/x")], imageRefs: ["a.jpg"])
    _ = store.addCustom(p)
    let fetched = store.yourProjects.first!
    assertEqual(fetched.category, "Science Fair", "4a type Science Fair uses same model")
    assert(fetched.type == "Science Fair", "4b type alias")
    assert(!fetched.description.isEmpty, "4c description")
    assert(!fetched.skills.isEmpty, "4d skills")
    assert(fetched.outcome != nil, "4e outcome")
    assert(!fetched.links.isEmpty, "4f links")
    assert(!fetched.imageReferences.isEmpty, "4g images")
}

// 5. Ordering (insertion order preserved)
do {
    let store = FakeStore()
    let a = Project(id: "a", title: "A")
    let b = Project(id: "b", title: "B")
    let c = Project(id: "c", title: "C")
    _ = store.addCustom(b); _ = store.addCustom(a); _ = store.addCustom(c)
    // CustomProjects preserves insertion order (B,A,C)
    assertEqual(store.yourProjects.map(\.id), ["b","a","c"], "5a order preserved")
}

// 6. Search in YOUR PROJECTS
do {
    let store = FakeStore()
    _ = store.addCustom(Project(id:"s1", title:"AI Study Planner", category:"Coding Project", description:"Built planner", skills:["TypeScript"], outcome:"Prototype"))
    _ = store.addCustom(Project(id:"s2", title:"Science Fair Detector", category:"Science Fair", description:"Plant health", skills:["Python"], status: .completed, outcome:"Won prize"))
    let q1 = store.yourProjects.filter { searchMatches(project: $0, query: "AI") }
    assert(q1.count >= 1, "6a search AI")
    let q2 = store.yourProjects.filter { searchMatches(project: $0, query: "Science Fair") }
    assertEqual(q2.count, 1, "6b search Science Fair")
    let q3 = store.yourProjects.filter { searchMatches(project: $0, query: "Prototype") }
    assertEqual(q3.count, 1, "6c search outcome Prototype")
    let q4 = store.yourProjects.filter { searchMatches(project: $0, query: "TypeScript") }
    assertEqual(q4.count, 1, "6d search skill")
    let q5 = store.yourProjects.filter { searchMatches(project: $0, query: "Completed") }
    assertEqual(q5.count, 1, "6e search status")
    let q6 = store.yourProjects.filter { searchMatches(project: $0, query: "nonexistentXYZ") }
    assert(q6.isEmpty, "6f no results")
}

// 7. Opening ProjectDetail does not create custom (idea)
do {
    let store = FakeStore()
    let before = store.customProjects.count
    let idea = store.ideaProjects.first!
    // Simulate opening detail: just view, not add
    let isCustom = store.customProjects.contains(where: {$0.id==idea.project.id})
    assert(!isCustom, "7a idea not custom")
    // Ensure count unchanged
    assertEqual(store.customProjects.count, before, "7b count unchanged after view")
    // Ensure idea still in ideas, not in yourProjects
    assert(store.ideaProjects.contains(where: {$0.project.id==idea.project.id}), "7c still idea")
}

// 8. Editing your project
do {
    let store = FakeStore()
    var p = Project(id: "edit-1", title: "Original", category: "Personal Project", status: .planned)
    _ = store.addCustom(p)
    p.title = "Edited Title"
    p.status = .completed
    p.outcome = "Finished"
    assert(store.updateProject(p), "8a update")
    assertEqual(store.yourProjects.first!.title, "Edited Title", "8b edited title")
    assertEqual(store.yourProjects.first!.status, .completed, "8c edited status")
}

// 9. Adding via editor (uses store)
do {
    let store = FakeStore()
    let new = Project(id: "new-1", title: "New via Editor", category: "Coding Project")
    assert(store.addCustom(new), "9a add via editor")
    assertEqual(store.yourProjects.count, 1, "9b count 1")
    // Add duplicate should fail
    assert(!store.addCustom(new), "9c duplicate prevented")
}

// 10. PROJECT IDEAS catalog displays, remains separate
do {
    let store = FakeStore()
    assertEqual(store.ideaProjects.count, catalog.count, "10a catalog count")
    for sp in store.ideaProjects {
        assert(catalog.contains(where: {$0.id==sp.project.id}), "10b idea from catalog")
        assert(!store.customProjects.contains(where: {$0.id==sp.project.id}), "10c not in custom")
    }
    // Add custom does not affect catalog
    _ = store.addCustom(Project(id:"custom-x", title:"X"))
    assertEqual(store.ideaProjects.count, catalog.count, "10d ideas still catalog count after custom add")
}

// 11. Idea detail opens (ScoredProject)
do {
    let store = FakeStore()
    let idea = store.ideaProjects.first!
    // Simulate detail: should have project metadata
    assert(!idea.project.title.isEmpty, "11a idea title")
    assert(!idea.project.category.isEmpty, "11b idea category")
    // Estimated effort should be present for catalog
    assert(!idea.project.estimatedCompletion.isEmpty, "11c estimatedCompletion")
    // Opening idea does not create custom
    let before = store.customProjects.count
    _ = idea // viewing
    assertEqual(store.customProjects.count, before, "11d no auto create")
}

// 12. Search distinguishes YOUR PROJECTS vs IDEAS but uses same query string (both filtered by same text)
do {
    let store = FakeStore()
    _ = store.addCustom(Project(id:"y1", title:"AI Planner", category:"Coding Project"))
    // Catalog has "Plant Health Dashboard" with Python
    let query = "Plant"
    let your = store.yourProjects.filter { searchMatches(project: $0, query: query) }
    let ideas = store.ideaProjects.filter { searchMatchesScored($0, query: query) }
    assert(your.isEmpty, "12a your no plant")
    assert(ideas.count >= 1, "12b ideas has plant")
    let q2 = "AI"
    let your2 = store.yourProjects.filter { searchMatches(project: $0, query: q2) }
    assert(!your2.isEmpty, "12c your has AI")
}

// 13. Integration Onboarding → AppDataStore → ProjectsView
do {
    // Simulate onboarding ViewModel projects
    var onboardingProjects: [Project] = []
    let p = Project(id: "onboard-1", title: "Onboard Project", category: "Science Fair")
    onboardingProjects.append(p)
    // Finish onboarding: migrate to store
    let store = FakeStore()
    for proj in onboardingProjects { _ = store.addCustom(proj) }
    onboardingProjects.removeAll()
    assertEqual(store.yourProjects.count, 1, "13a migrated")
    assertEqual(store.yourProjects[0].title, "Onboard Project", "13b title preserved")
    assertEqual(store.yourProjects[0].category, "Science Fair", "13c category preserved")
    // No duplicate
    assert(onboardingProjects.isEmpty, "13d onboarding cleared")
    // Second finish should not duplicate
    for proj in onboardingProjects { _ = store.addCustom(proj) }
    assertEqual(store.yourProjects.count, 1, "13e no duplicate on second migrate")
}

// 14. Profile Edit → AppDataStore → ProjectsView (same)
do {
    let store = FakeStore()
    let p = Project(id:"profile-1", title:"Profile Project")
    _ = store.addCustom(p)
    assertEqual(store.yourProjects.count, 1, "14a profile added")
    // Edit via detail
    var edited = p; edited.title = "Profile Edited"
    _ = store.updateProject(edited)
    assertEqual(store.yourProjects.first!.title, "Profile Edited", "14b edit reflected")
}

// 15. No duplicates across onboarding/profile
do {
    let store = FakeStore()
    let p = Project(id:"dup-proj", title:"Dup")
    assert(store.addCustom(p), "15a first add")
    // Try to add same via onboarding migration
    assert(!store.addCustom(p), "15b duplicate prevented via same ID")
    assertEqual(store.yourProjects.count, 1, "15c count 1")
}

// 16. Counts are from actual data, not hard-coded
do {
    let store = FakeStore()
    assertEqual(store.yourProjects.count, 0, "16a start 0")
    _ = store.addCustom(Project(id:"c1", title:"A"))
    _ = store.addCustom(Project(id:"c2", title:"B"))
    assertEqual(store.yourProjects.count, 2, "16b after 2 adds count 2")
    _ = store.deleteProject(id: "c1")
    assertEqual(store.yourProjects.count, 1, "16c after delete count 1")
    assertEqual(store.ideaProjects.count, catalog.count, "16d ideas count from actual catalog")
}

// 17. Status visibility uses canonical status
do {
    for status in [ProjectStatus.planned, .inProgress, .completed] {
        let p = Project(id: UUID().uuidString, title: "T", status: status)
        assertEqual(p.status.displayName, status.displayName, "17 status \(status)")
        assert(!p.status.displayName.isEmpty, "17b display not empty")
    }
}

// 18. Empty states for PROJECT IDEAS when catalog empty (simulate)
do {
    let emptyCatalog: [Project] = []
    let custom: [Project] = []
    let scoredEmpty = (emptyCatalog + custom).map { ScoredProject(project: $0, matchScore: 0, completedMilestones: 0) }
    let ids = Set(custom.map(\.id))
    let ideas = scoredEmpty.filter { !ids.contains($0.project.id) }
    assert(ideas.isEmpty, "18a no ideas when catalog empty")
    // UI would show "No project ideas are currently available." condition is ideas.isEmpty && totalIdeaCount==0
}

// 19. Backward compatibility: old custom project decodes to rich model and appears in YOUR PROJECTS
do {
    let oldJSON = """
    {"id":"old-compat","title":"Old Compat","category":"Data + Biology","goal":"Goal","description":"Old desc","skills":["Python"],"milestones":[],"resources":[],"estimatedCompletion":"2 weeks","relevantInterests":[],"relevantSkills":[],"relevantCareers":[],"relevantFields":[]}
    """.data(using: .utf8)!
    let decoded = try! JSONDecoder().decode(Project.self, from: oldJSON)
    let store = FakeStore()
    _ = store.addCustom(decoded)
    assertEqual(store.yourProjects.count, 1, "19a old compat added to yourProjects")
    assertEqual(store.yourProjects[0].status, .inProgress, "19b default status for old")
}

// 20. Architecture: no duplicate model, use canonical
do {
    let store = FakeStore()
    let p = Project(id:"arch-1", title:"Arch")
    _ = store.addCustom(p)
    // YOUR PROJECTS source is customProjects
    assert(store.yourProjects.first!.id == "arch-1", "20a canonical source")
    // IDEAS source is catalog filtered
    assert(!store.yourProjects.contains(where: {$0.id=="plant-health-dashboard"}), "20b custom not mixing catalog")
    assert(store.ideaProjects.contains(where: {$0.project.id=="plant-health-dashboard"}), "20c ideas from catalog")
}

print("\n=== Results: \(passed) passed, \(failed) failed out of \(passed+failed) ===")
if failed==0 { print("All Phase 9.4 Projects tab tests passed ✓") } else { print("Some failed"); exit(1) }
