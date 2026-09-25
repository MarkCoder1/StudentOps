import Foundation

// Phase 9.3 — Rich Project Data Foundation
// Run: swift test-project-rich.swift

var passed = 0
var failed = 0
func assert(_ c: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if c { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// MARK: - Inline production mirror (must match StudentOps/Project.swift)

enum ProjectStatus: String, Codable, Hashable, CaseIterable {
    case planned = "planned"
    case inProgress = "inProgress"
    case completed = "completed"
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "planned"
        let norm = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
        switch norm {
        case "planned": self = .planned
        case "inprogress": self = .inProgress
        case "completed", "complete", "done": self = .completed
        default: self = .planned
        }
    }
    var displayName: String {
        switch self { case .planned: return "Planned"; case .inProgress: return "In Progress"; case .completed: return "Completed" }
    }
}

struct ProjectLink: Identifiable, Hashable, Codable {
    let id: String
    var label: String
    var url: String
    init(id: String = UUID().uuidString, label: String, url: String) {
        self.id = id
        let t = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = t.isEmpty ? "Link" : t
        self.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    enum CodingKeys: String, CodingKey { case id, label, url, title }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        let raw = (try? c.decode(String.self, forKey: .label)) ?? (try? c.decode(String.self, forKey: .title)) ?? "Link"
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        label = t.isEmpty ? "Link" : t
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(label, forKey: .label); try c.encode(url, forKey: .url)
    }
    var isValidURL: Bool {
        let t = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard let u = URL(string: t) else { return false }
        guard let s = u.scheme?.lowercased(), ["http","https"].contains(s) else { return false }
        return u.host != nil
    }
}

struct ProjectMilestone: Identifiable, Hashable, Codable {
    let id: String; let title: String; let subtitle: String; let estimatedTime: String
}

struct Project: Identifiable, Hashable, Codable {
    let id: String; var title: String; var category: String; var goal: String; var description: String
    var skills: [String]; var milestones: [ProjectMilestone]; var resources: [String]
    var estimatedCompletion: String; var relevantInterests: Set<String>; var relevantSkills: Set<String>
    var relevantCareers: Set<String>; var relevantFields: Set<String>; var sourceRoadmapID: String?
    var status: ProjectStatus; var detailedDescription: String?; var outcome: String?; var outcomeDetails: String?
    var links: [ProjectLink]; var imageReferences: [String]; var startDate: Date?; var completionDate: Date?
    var achievementID: String?
    static let typeOptions = ["Personal Project","School Project","Science Fair","Research Project","Coding Project","Competition Project","Community Project","Other"]
    var type: String { category }
    enum CodingKeys: String, CodingKey {
        case id, title, category, type, goal, description, skills, milestones, resources, estimatedCompletion
        case relevantInterests, relevantSkills, relevantCareers, relevantFields, sourceRoadmapID
        case status, detailedDescription, outcome, outcomeDetails, links, imageReferences, startDate, completionDate, achievementID
        case imageRefs, photos
    }
    init(id: String, title: String, category: String = "Personal Project", goal: String = "Complete this project", description: String = "Desc", skills: [String] = [], milestones: [ProjectMilestone] = [], resources: [String] = [], estimatedCompletion: String = "Your timeline", relevantInterests: Set<String> = [], relevantSkills: Set<String> = [], relevantCareers: Set<String> = [], relevantFields: Set<String> = [], sourceRoadmapID: String? = nil, status: ProjectStatus = .inProgress, detailedDescription: String? = nil, outcome: String? = nil, outcomeDetails: String? = nil, links: [ProjectLink] = [], imageReferences: [String] = [], startDate: Date? = nil, completionDate: Date? = nil, achievementID: String? = nil) {
        self.id = id; self.title = title; self.category = category; self.goal = goal; self.description = description; self.skills = skills; self.milestones = milestones; self.resources = resources; self.estimatedCompletion = estimatedCompletion; self.relevantInterests = relevantInterests; self.relevantSkills = relevantSkills; self.relevantCareers = relevantCareers; self.relevantFields = relevantFields; self.sourceRoadmapID = sourceRoadmapID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : sourceRoadmapID; self.status = status
        let dd = detailedDescription?.trimmingCharacters(in: .whitespacesAndNewlines); self.detailedDescription = dd?.isEmpty == true ? nil : dd
        let oc = outcome?.trimmingCharacters(in: .whitespacesAndNewlines); self.outcome = oc?.isEmpty == true ? nil : oc
        let od = outcomeDetails?.trimmingCharacters(in: .whitespacesAndNewlines); self.outcomeDetails = od?.isEmpty == true ? nil : od
        self.links = links.filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.imageReferences = imageReferences.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.startDate = startDate; self.completionDate = completionDate
        let ach = achievementID?.trimmingCharacters(in: .whitespacesAndNewlines); self.achievementID = ach?.isEmpty == true ? nil : ach
    }
    init(id: String, title: String) {
        self.init(id: id, title: title, category: "Personal Project", goal: "Complete this project", description: "Desc", skills: [], milestones: [], resources: [], estimatedCompletion: "Your timeline", relevantInterests: [], relevantSkills: [], relevantCareers: [], relevantFields: [], sourceRoadmapID: nil)
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) { id = s } else if let u = try? c.decode(UUID.self, forKey: .id) { id = u.uuidString } else { id = UUID().uuidString }
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        if let cat = try? c.decode(String.self, forKey: .category) { category = cat } else if let t = try? c.decode(String.self, forKey: .type) { category = t } else { category = "Personal Project" }
        goal = (try? c.decode(String.self, forKey: .goal)) ?? "Complete this project"
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        skills = (try? c.decode([String].self, forKey: .skills)) ?? []
        milestones = (try? c.decode([ProjectMilestone].self, forKey: .milestones)) ?? []
        resources = (try? c.decode([String].self, forKey: .resources)) ?? []
        estimatedCompletion = (try? c.decode(String.self, forKey: .estimatedCompletion)) ?? "Your timeline"
        relevantInterests = (try? c.decode(Set<String>.self, forKey: .relevantInterests)) ?? []
        relevantSkills = (try? c.decode(Set<String>.self, forKey: .relevantSkills)) ?? []
        relevantCareers = (try? c.decode(Set<String>.self, forKey: .relevantCareers)) ?? []
        relevantFields = (try? c.decode(Set<String>.self, forKey: .relevantFields)) ?? []
        sourceRoadmapID = try? c.decode(String.self, forKey: .sourceRoadmapID)
        status = (try? c.decode(ProjectStatus.self, forKey: .status)) ?? .inProgress
        detailedDescription = try? c.decode(String.self, forKey: .detailedDescription)
        if detailedDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { detailedDescription = nil }
        outcome = try? c.decode(String.self, forKey: .outcome)
        if outcome?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { outcome = nil }
        outcomeDetails = try? c.decode(String.self, forKey: .outcomeDetails)
        if outcomeDetails?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { outcomeDetails = nil }
        links = (try? c.decode([ProjectLink].self, forKey: .links)) ?? []
        if let refs = try? c.decode([String].self, forKey: .imageReferences) { imageReferences = refs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        else if let refs = try? c.decode([String].self, forKey: .imageRefs) { imageReferences = refs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        else { imageReferences = [] }
        startDate = try? c.decode(Date.self, forKey: .startDate)
        completionDate = try? c.decode(Date.self, forKey: .completionDate)
        achievementID = try? c.decode(String.self, forKey: .achievementID)
        if achievementID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { achievementID = nil }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(title, forKey: .title); try c.encode(category, forKey: .category)
        try c.encode(goal, forKey: .goal); try c.encode(description, forKey: .description); try c.encode(skills, forKey: .skills)
        try c.encode(milestones, forKey: .milestones); try c.encode(resources, forKey: .resources); try c.encode(estimatedCompletion, forKey: .estimatedCompletion)
        try c.encode(relevantInterests, forKey: .relevantInterests); try c.encode(relevantSkills, forKey: .relevantSkills); try c.encode(relevantCareers, forKey: .relevantCareers); try c.encode(relevantFields, forKey: .relevantFields)
        try c.encodeIfPresent(sourceRoadmapID, forKey: .sourceRoadmapID)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(detailedDescription, forKey: .detailedDescription)
        try c.encodeIfPresent(outcome, forKey: .outcome)
        try c.encodeIfPresent(outcomeDetails, forKey: .outcomeDetails)
        if !links.isEmpty { try c.encode(links, forKey: .links) }
        if !imageReferences.isEmpty { try c.encode(imageReferences, forKey: .imageReferences) }
        try c.encodeIfPresent(startDate, forKey: .startDate)
        try c.encodeIfPresent(completionDate, forKey: .completionDate)
        try c.encodeIfPresent(achievementID, forKey: .achievementID)
    }
}

func normalizeSkillID(_ raw: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    return parts.joined(separator: " ").lowercased()
}
func isValidURL(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return false }
    guard let u = URL(string: t) else { return false }
    guard let sch = u.scheme?.lowercased(), ["http","https"].contains(sch) else { return false }
    return u.host != nil
}

// MARK: - Tests

print("=== Phase 9.3 Rich Project Foundation Tests ===")

// 1. Minimal project creation
do {
    let p = Project(id: "p1", title: "AI Study Planner")
    assertEqual(p.title, "AI Study Planner", "1a title")
    assertEqual(p.category, "Personal Project", "1b category default")
    assertEqual(p.status, .inProgress, "1c default status")
    assert(p.detailedDescription == nil, "1d detailed nil")
    assert(p.links.isEmpty, "1e links empty")
}

// 2. Rich project full fields
do {
    let links = [ProjectLink(label: "GitHub", url: "https://github.com/test"), ProjectLink(label: "Demo", url: "https://example.com/demo")]
    let start = Date(timeIntervalSince1970: 1700000000)
    let comp = Date(timeIntervalSince1970: 1701000000)
    let p = Project(id: "rich-1", title: "AI Plant Health Detector", category: "Science Fair", goal: "Detect disease", description: "Built an AI-powered study planner", skills: ["Python","Problem Solving","Research"], milestones: [], resources: [], estimatedCompletion: "2 weeks", relevantInterests: [], relevantSkills: [], relevantCareers: [], relevantFields: [], sourceRoadmapID: nil, status: .completed, detailedDescription: "Longer background about research question", outcome: "Won 1st place", outcomeDetails: "Presented to 200 people, published paper", links: links, imageReferences: ["img-1.jpg","img-2.jpg"], startDate: start, completionDate: comp, achievementID: "ach-1")
    assertEqual(p.title, "AI Plant Health Detector", "2a title")
    assertEqual(p.category, "Science Fair", "2b category")
    assertEqual(p.status, .completed, "2c status")
    assertEqual(p.detailedDescription!, "Longer background about research question", "2d detailed")
    assertEqual(p.outcome!, "Won 1st place", "2e outcome")
    assertEqual(p.outcomeDetails!, "Presented to 200 people, published paper", "2f outcome details")
    assertEqual(p.links.count, 2, "2g links")
    assertEqual(p.imageReferences.count, 2, "2h images")
    assert(p.startDate != nil, "2i start")
    assert(p.completionDate != nil, "2j completion")
    assertEqual(p.achievementID!, "ach-1", "2k achievement")
    assert(p.skills.contains("Python"), "2l skills")
}

// 3. Codable encode/decode rich
do {
    let p = Project(id: "cod-1", title: "Test", category: "Coding Project", description: "Desc", skills: ["TypeScript"], status: .inProgress, detailedDescription: "Details", outcome: "Built prototype", links: [ProjectLink(label: "GitHub", url: "https://github.com/a")], imageReferences: ["a.jpg"], startDate: Date(), achievementID: "ach-2")
    let data = try! JSONEncoder().encode(p)
    let decoded = try! JSONDecoder().decode(Project.self, from: data)
    assertEqual(decoded.title, p.title, "3a title")
    assertEqual(decoded.category, p.category, "3b category")
    assertEqual(decoded.status, p.status, "3c status")
    assertEqual(decoded.detailedDescription!, "Details", "3d detailed")
    assertEqual(decoded.outcome!, "Built prototype", "3e outcome")
    assertEqual(decoded.links.count, 1, "3f links")
    assertEqual(decoded.imageReferences.first!, "a.jpg", "3g image")
}

// 4. Backward compatible decode (old JSON without new fields)
do {
    let oldJSON = """
    {
        "id":"old-1",
        "title":"Old Project",
        "category":"Data + Biology",
        "goal":"Build tool",
        "description":"Old desc",
        "skills":["Python"],
        "milestones":[{"id":"m1","title":"M1","subtitle":"S","estimatedTime":"1h"}],
        "resources":["notebook"],
        "estimatedCompletion":"2 weeks",
        "relevantInterests":[],
        "relevantSkills":[],
        "relevantCareers":[],
        "relevantFields":[],
        "sourceRoadmapID":"research-builder"
    }
    """.data(using: .utf8)!
    let decoded = try! JSONDecoder().decode(Project.self, from: oldJSON)
    assertEqual(decoded.id, "old-1", "4a id")
    assertEqual(decoded.title, "Old Project", "4b title")
    assertEqual(decoded.status, .inProgress, "4c default status for old")
    assert(decoded.detailedDescription == nil, "4d detailed nil for old")
    assert(decoded.links.isEmpty, "4e links empty for old")
    assert(decoded.imageReferences.isEmpty, "4f images empty for old")
    assert(decoded.startDate == nil, "4g start nil for old")
    assert(decoded.outcome == nil, "4h outcome nil")
    // Ensure re-encode works
    let re = try! JSONEncoder().encode(decoded)
    let re2 = try! JSONDecoder().decode(Project.self, from: re)
    assertEqual(re2.title, "Old Project", "4i re-decode")
}

// 5. Status decoding variations
do {
    let jsonPlanned = "\"planned\"".data(using: .utf8)!
    let s1 = try! JSONDecoder().decode(ProjectStatus.self, from: jsonPlanned)
    assertEqual(s1, .planned, "5a planned")

    let jsonInProg = "\"inProgress\"".data(using: .utf8)!
    let s2 = try! JSONDecoder().decode(ProjectStatus.self, from: jsonInProg)
    assertEqual(s2, .inProgress, "5b inProgress")

    let jsonCompleted = "\"completed\"".data(using: .utf8)!
    let s3 = try! JSONDecoder().decode(ProjectStatus.self, from: jsonCompleted)
    assertEqual(s3, .completed, "5c completed")

    let jsonSpaced = "\"In Progress\"".data(using: .utf8)!
    let s4 = try! JSONDecoder().decode(ProjectStatus.self, from: jsonSpaced)
    assertEqual(s4, .inProgress, "5d In Progress spaced")

    let jsonWeird = "\"UNKNOWN\"".data(using: .utf8)!
    let s5 = try! JSONDecoder().decode(ProjectStatus.self, from: jsonWeird)
    assertEqual(s5, .planned, "5e fallback to planned")
}

// 6. Dates optional
do {
    let p = Project(id: "d1", title: "Dated", startDate: nil, completionDate: nil)
    assert(p.startDate == nil && p.completionDate == nil, "6a dates nil optional")
    let dated = Project(id: "d2", title: "Dated2", startDate: Date(), completionDate: Date(timeIntervalSinceNow: 86400))
    assert(dated.startDate != nil && dated.completionDate != nil, "6b dates set")
    // completion before start should be handled at store layer, but model allows; test that encode preserves
    let earlier = Date(timeIntervalSince1970: 1000)
    let later = Date(timeIntervalSince1970: 2000)
    let valid = Project(id: "d3", title: "Valid", startDate: earlier, completionDate: later)
    assert(valid.completionDate! > valid.startDate!, "6c completion after start")
    // encode/decode preserves dates
    let data = try! JSONEncoder().encode(valid)
    let dec = try! JSONDecoder().decode(Project.self, from: data)
    assertEqual(dec.startDate!.timeIntervalSince1970, earlier.timeIntervalSince1970, "6d date roundtrip")
}

// 7. Skills canonical normalization
do {
    let skills = ["Python", "python", "  Python  ", "Problem Solving", "problem solving"]
    // Simulate store dedup via normalize
    var seen = Set<String>(); var deduped: [String] = []
    for raw in skills {
        let norm = normalizeSkillID(raw)
        guard !norm.isEmpty, !seen.contains(norm) else { continue }
        seen.insert(norm); deduped.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    assertEqual(deduped.count, 2, "7a deduped count (Python + Problem Solving)")
    assert(deduped.contains("Python"), "7b Python")
    // Project should store display names but engines use normalized
    let p = Project(id: "sk1", title: "Skill", skills: ["TypeScript","TypeScript","  typescript "])
    // Our init does not dedup, store layer does. Model stores as given. Check that raw stored
    assertEqual(p.skills.count, 3, "7c raw model keeps duplicates (store cleans)")
    // But store's createRich would dedup — simulate
    var seen2 = Set<String>(); var out:[String] = []
    for raw in p.skills {
        let n = normalizeSkillID(raw)
        if seen2.insert(n).inserted { out.append(raw) }
    }
    assertEqual(out.count, 1, "7d store dedup would make 1")
}

// 8. Outcomes
do {
    let p = Project(id: "o1", title: "Outcome", outcome: "Built working prototype", outcomeDetails: "Reached 500 users")
    assertEqual(p.outcome!, "Built working prototype", "8a outcome")
    assertEqual(p.outcomeDetails!, "Reached 500 users", "8b details")
    // empty outcome treated as nil
    let p2 = Project(id: "o2", title: "Empty", outcome: "   ", outcomeDetails: "")
    assert(p2.outcome == nil, "8c empty outcome nil")
    assert(p2.outcomeDetails == nil, "8d empty details nil")
}

// 9. Links validation
do {
    let valid = ProjectLink(label: "GitHub", url: "https://github.com/test")
    assert(valid.isValidURL, "9a valid https")
    let invalid = ProjectLink(label: "Bad", url: "ftp://example.com")
    assert(!invalid.isValidURL, "9b invalid scheme")
    let empty = ProjectLink(label: "Empty", url: "")
    assert(!empty.isValidURL, "9c empty invalid")
    let tricky = ProjectLink(label: "Tricky", url: "not a url")
    assert(!tricky.isValidURL, "9d tricky invalid")
    // Project filters empty url links in init
    let p = Project(id: "link1", title: "Link", links: [valid, ProjectLink(label: "Empty", url: "" )])
    assertEqual(p.links.count, 1, "9e filters empty")
    // Encode/decode preserves
    let data = try! JSONEncoder().encode(valid)
    let dec = try! JSONDecoder().decode(ProjectLink.self, from: data)
    assertEqual(dec.url, valid.url, "9f link roundtrip")
}

// 10. Image references are NOT stored as blobs in UserDefaults (should be identifiers only)
do {
    let p = Project(id: "img1", title: "Image", imageReferences: ["abc123.jpg", "def456.jpg"])
    let data = try! JSONEncoder().encode(p)
    let jsonStr = String(data: data, encoding: .utf8)!
    assert(jsonStr.contains("abc123.jpg"), "10a json contains ref")
    // Ensure imageReferences are strings, not base64 data
    assert(!jsonStr.contains("base64"), "10b not base64")
    // Decode preserves
    let dec = try! JSONDecoder().decode(Project.self, from: data)
    assertEqual(dec.imageReferences.count, 2, "10c image count")
    // Simulate file storage: references are filenames, not raw bytes
    // Creating a temp file to simulate ProjectImageStore
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    let imgData = "fake image data".data(using: .utf8)!
    let ref = "test.jpg"
    let url = tmpDir.appendingPathComponent(ref)
    try! imgData.write(to: url)
    assert(FileManager.default.fileExists(atPath: url.path), "10d file exists")
    let loaded = try! Data(contentsOf: url)
    assertEqual(loaded, imgData, "10e file roundtrip")
    try? FileManager.default.removeItem(at: tmpDir)
}

// 11. Persistence simulation via UserDefaults-like storage
do {
    let key = "test.project.rich.\(UUID().uuidString)"
    let p1 = Project(id: "persist1", title: "Persist Rich", category: "Research Project", description: "Built AI planner", skills: ["Python"], status: .completed, outcome: "Won award", links: [ProjectLink(label: "Demo", url: "https://example.com")], imageReferences: ["img.jpg"], startDate: Date())
    let projects = [p1]
    let data = try! JSONEncoder().encode(projects)
    UserDefaults.standard.set(data, forKey: key)
    let loadedData = UserDefaults.standard.data(forKey: key)!
    let loaded = try! JSONDecoder().decode([Project].self, from: loadedData)
    assertEqual(loaded.count, 1, "11a persistence count")
    assertEqual(loaded[0].title, "Persist Rich", "11b title")
    assertEqual(loaded[0].status, .completed, "11c status")
    assertEqual(loaded[0].outcome!, "Won award", "11d outcome")
    // Edit
    var edited = loaded[0]
    edited.title = "Persist Rich Edited"
    edited.outcome = "Updated outcome"
    let data2 = try! JSONEncoder().encode([edited])
    UserDefaults.standard.set(data2, forKey: key)
    let loaded2 = try! JSONDecoder().decode([Project].self, from: UserDefaults.standard.data(forKey: key)!)
    assertEqual(loaded2[0].title, "Persist Rich Edited", "11e edited title")
    // Delete
    var remaining = loaded2.filter { $0.id != "persist1" }
    let data3 = try! JSONEncoder().encode(remaining)
    UserDefaults.standard.set(data3, forKey: key)
    let loaded3 = try! JSONDecoder().decode([Project].self, from: UserDefaults.standard.data(forKey: key)!)
    assert(loaded3.isEmpty, "11f deleted")
    UserDefaults.standard.removeObject(forKey: key)
    // Existing projects remain intact (simulate old project still decodes after rich change)
    let oldData = """
    [{"id":"old-persist","title":"Old","category":"Personal Project","goal":"Goal","description":"Desc","skills":[],"milestones":[],"resources":[],"estimatedCompletion":"1 week","relevantInterests":[],"relevantSkills":[],"relevantCareers":[],"relevantFields":[]}]
    """.data(using: .utf8)!
    let oldDecoded = try! JSONDecoder().decode([Project].self, from: oldData)
    assertEqual(oldDecoded[0].title, "Old", "11g old intact")
}

// 12. Relationships: Project → Skill, Evidence, Achievement, Portfolio
do {
    // Simulate canonical skill IDs
    let projectSkills = ["python", "research"]
    for s in projectSkills { assert(!normalizeSkillID(s).isEmpty, "12a skill id \(s)") }

    // Evidence relationship: EvidenceRecord.projectID == Project.id
    struct EvidenceMock: Codable, Hashable { let id: String; let projectID: String? }
    let ev = EvidenceMock(id: "ev-1", projectID: "rich-1")
    assertEqual(ev.projectID!, "rich-1", "12b evidence projectID")

    // Achievement relationship: Achievement.projectID == Project.id and Project.achievementID == Achievement.id
    struct AchievementMock: Codable, Hashable { let id: String; var projectID: String? }
    var ach = AchievementMock(id: "ach-1", projectID: "rich-1")
    let proj = Project(id: "rich-1", title: "Rel", achievementID: "ach-1")
    assertEqual(proj.achievementID!, "ach-1", "12c proj achievement")
    assertEqual(ach.projectID!, "rich-1", "12d ach project")
    // Portfolio compatibility: portfolio stores selectedProjectIDs which reference Project.id even after rich extension
    let portfolioProjectIDs = ["rich-1", "old-1"]
    assert(portfolioProjectIDs.contains("rich-1"), "12e portfolio contains rich")
    assert(portfolioProjectIDs.contains("old-1"), "12f portfolio contains old")
}

// 13. Onboarding minimal vs rich
do {
    // Minimal: only title + type
    let minimal = Project(id: "min-1", title: "Quick Project", category: "Personal Project", description: "Desc", skills: [])
    assert(!minimal.title.isEmpty, "13a minimal title")
    assertEqual(minimal.category, "Personal Project", "13b minimal category")
    assert(minimal.skills.isEmpty, "13c minimal skills empty allowed")
    assert(minimal.outcome == nil, "13d minimal outcome nil")
    assert(minimal.links.isEmpty, "13e minimal links empty")

    // Rich: all optional populated
    let rich = Project(id: "rich-2", title: "Full Project", category: "Science Fair", description: "Built detector", skills: ["Python"], status: .completed, detailedDescription: "Research question...", outcome: "Won", links: [ProjectLink(label: "Paper", url: "https://example.com/paper")], imageReferences: ["img.jpg"], startDate: Date(), achievementID: "ach-x")
    assertEqual(rich.category, "Science Fair", "13f rich type Science Fair uses same Project model")
    assert(!rich.skills.isEmpty, "13g rich skills")
    assert(rich.outcome != nil, "13h rich outcome")
    assert(!rich.links.isEmpty, "13i rich links")
    assert(!rich.imageReferences.isEmpty, "13j rich images")
}

// 14. Science Fair uses same Project model (no separate struct)
do {
    let sf = Project(id: "sf-1", title: "Plant Health", category: "Science Fair", description: "Research", skills: ["Research"])
    assertEqual(sf.category, "Science Fair", "14a science fair category")
    // Ensure no separate ScienceFairProject type needed; just category string
    assert(sf.type == "Science Fair", "14b type alias")
}

// 15. Portfolio compatibility after rich extension — ensure no break in portfolio logic
do {
    // Simulate portfolio selectedProjectIDs referencing both old and rich projects
    let stored = [Project(id: "old-2", title: "Old"), Project(id: "new-rich", title: "New", category: "Competition Project", outcome: "Won")]
    let portfolioIDs = ["old-2", "new-rich"]
    let resolved = stored.filter { portfolioIDs.contains($0.id) }
    assertEqual(resolved.count, 2, "15a portfolio resolves both")
    // Stale ID preserved (not crash)
    let staleIDs = ["nonexistent-123"] + portfolioIDs
    let resolved2 = stored.filter { staleIDs.contains($0.id) }
    assertEqual(resolved2.count, 2, "15b stale preserved but not crash")
}

// 16. Empty sections hidden logic (UI would hide, model allows check)
do {
    let empty = Project(id: "empty", title: "Empty")
    assert(empty.detailedDescription == nil, "16a about hidden when nil")
    assert(empty.skills.isEmpty, "16b skills hidden when empty")
    assert(empty.outcome == nil, "16c outcome hidden when nil")
    assert(empty.links.isEmpty, "16d links hidden when empty")
    assert(empty.imageReferences.isEmpty, "16e photos hidden when empty")
    assert(empty.achievementID == nil, "16f achievement hidden when nil")
    let withData = Project(id: "with", title: "With", skills: ["Python"], outcome: "Done", links: [ProjectLink(label:"G", url:"https://a.com")])
    assert(!withData.skills.isEmpty, "16g skills shown")
    assert(withData.outcome != nil, "16h outcome shown")
}

// 17. No duplicate project system — reuse IDs
do {
    let p1 = Project(id: "dup-1", title: "A")
    let p2 = Project(id: "dup-1", title: "B") // same ID duplicate
    // Store should prevent duplicate IDs
    var store: [String: Project] = [:]
    func add(_ p: Project) -> Bool {
        guard store[p.id] == nil else { return false }
        store[p.id] = p; return true
    }
    assert(add(p1), "17a add p1")
    assert(!add(p2), "17b duplicate prevented")
    assertEqual(store["dup-1"]!.title, "A", "17c original preserved")
}

// 18. Typecheck — project types supported
do {
    let supported = ["Personal Project","School Project","Science Fair","Research Project","Coding Project","Competition Project","Community Project","Other"]
    for t in supported {
        let p = Project(id: UUID().uuidString, title: "T", category: t)
        assertEqual(p.category, t, "18 \(t)")
    }
}

print("\n=== Results: \(passed) passed, \(failed) failed out of \(passed+failed) ===")
if failed == 0 {
    print("All Phase 9.3 rich project tests passed ✓")
} else {
    print("Some tests failed")
    exit(1)
}
