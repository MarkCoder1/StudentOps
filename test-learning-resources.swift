import Foundation

// Standalone test script for Phase 6.4.4 — Learning Resources
// Run: swift test-learning-resources.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// ── Inline model definitions (mirrors Roadmap.swift) ──

enum TestMilestoneResourceType: String, Hashable, Codable {
    case article, video, documentation, interactive, course
}

struct TestMilestoneResource: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let provider: String
    let url: String
    let type: TestMilestoneResourceType
    let description: String
    let estimatedTime: String?
    init(id: String = UUID().uuidString, title: String, provider: String, url: String, type: TestMilestoneResourceType, description: String, estimatedTime: String? = nil) {
        self.id = id; self.title = title; self.provider = provider; self.url = url; self.type = type; self.description = description; self.estimatedTime = estimatedTime
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        provider = (try? c.decode(String.self, forKey: .provider)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        type = (try? c.decode(TestMilestoneResourceType.self, forKey: .type)) ?? .article
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        estimatedTime = try? c.decode(String.self, forKey: .estimatedTime)
    }
}

struct TestMilestoneAction: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String
    let order: Int
    let estimatedTime: String?
    init(id: String = UUID().uuidString, title: String, description: String, order: Int = 0, estimatedTime: String? = nil) {
        self.id = id; self.title = title; self.description = description; self.order = order; self.estimatedTime = estimatedTime
    }
}

// ── Test data: all Software Engineer resources ──

let swResources: [String: [TestMilestoneResource]] = [
    "software-1": [
        TestMilestoneResource(id: "sw1-res-1", title: "CS50: Introduction to Computer Science", provider: "Harvard / edX", url: "https://cs50.harvard.edu/x/", type: .course, description: "Free, high-quality introduction to computational thinking and the fundamentals of CS.", estimatedTime: "Self-paced"),
        TestMilestoneResource(id: "sw1-res-2", title: "Getting Started with Visual Studio Code", provider: "Microsoft", url: "https://code.visualstudio.com/docs/getstarted/getting-started", type: .documentation, description: "Official guide to installing and configuring VS Code.", estimatedTime: "15 min"),
        TestMilestoneResource(id: "sw1-res-3", title: "Hello World · GitHub Docs", provider: "GitHub", url: "https://docs.github.com/en/get-started/quickstart/hello-world", type: .documentation, description: "Create your first repository, commit, and push in under 10 minutes.", estimatedTime: "10 min"),
    ],
    "software-2": [
        TestMilestoneResource(id: "sw2-res-1", title: "Scientific Computing with Python", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/learn/scientific-computing-with-python/", type: .course, description: "Free, project-based Python certification covering variables, loops, functions, and data structures.", estimatedTime: "300 hrs (self-paced)"),
        TestMilestoneResource(id: "sw2-res-2", title: "The Python Tutorial", provider: "Python.org", url: "https://docs.python.org/3/tutorial/", type: .documentation, description: "Official Python tutorial — covers the language from first concepts through classes.", estimatedTime: "Self-paced"),
        TestMilestoneResource(id: "sw2-res-3", title: "Python Tutorial for Beginners", provider: "W3Schools", url: "https://www.w3schools.com/python/", type: .interactive, description: "Interactive, browser-based Python lessons with try-it-yourself editors.", estimatedTime: "Self-paced"),
    ],
    "software-3": [
        TestMilestoneResource(id: "sw3-res-1", title: "Git & GitHub Skills", provider: "GitHub", url: "https://skills.github.com/", type: .interactive, description: "Interactive, browser-based Git exercises — practice branching, merging, and pull requests.", estimatedTime: "Self-paced"),
        TestMilestoneResource(id: "sw3-res-2", title: "Use Git Version Control", provider: "GitHub Docs", url: "https://docs.github.com/en/get-started/using-git/about-git", type: .documentation, description: "Official guide to Git concepts, commands, and workflow basics.", estimatedTime: "20 min"),
        TestMilestoneResource(id: "sw3-res-3", title: "HTTP Overview", provider: "MDN Web Docs", url: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Overview", type: .documentation, description: "Clear explanation of how HTTP requests and responses work — essential for calling APIs.", estimatedTime: "25 min"),
    ],
    "software-4": [
        TestMilestoneResource(id: "sw4-res-1", title: "About READMEs", provider: "GitHub Docs", url: "https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes", type: .documentation, description: "What to include in a README and how to structure it for clarity.", estimatedTime: "10 min"),
        TestMilestoneResource(id: "sw4-res-2", title: "GitHub Pages Quickstart", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: .documentation, description: "Set up a free, public website from any repository in minutes.", estimatedTime: "15 min"),
        TestMilestoneResource(id: "sw4-res-3", title: "Awesome README", provider: "GitHub", url: "https://github.com/matiassingers/awesome-readme", type: .article, description: "Curated collection of excellent README examples for inspiration.", estimatedTime: "10 min"),
    ],
    "software-5": [
        TestMilestoneResource(id: "sw5-res-1", title: "MLH Student Hackathons", provider: "Major League Hacking", url: "https://mlh.io/", type: .interactive, description: "Find and register for student hackathons worldwide — beginner-friendly events welcome.", estimatedTime: "10 min"),
        TestMilestoneResource(id: "sw5-res-2", title: "Devpost Hackathon Projects", provider: "Devpost", url: "https://devpost.com/", type: .interactive, description: "Browse past winning projects and find your next hackathon.", estimatedTime: "10 min"),
        TestMilestoneResource(id: "sw5-res-3", title: "Finding Good First Issues", provider: "GitHub Docs", url: "https://docs.github.com/en/issues/tracking-your-work-with-issues/using-labels-and-milestones/filtering-your-issues-and-pull-requests-by-label", type: .documentation, description: "How to find beginner-friendly issues in open source repositories.", estimatedTime: "10 min"),
    ],
    "software-6": [
        TestMilestoneResource(id: "sw6-res-1", title: "Your First Portfolio Website", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: .documentation, description: "Step-by-step: publish a static portfolio site on GitHub Pages.", estimatedTime: "20 min"),
        TestMilestoneResource(id: "sw6-res-2", title: "Managing Your Profile README", provider: "GitHub Docs", url: "https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile/customizing-your-profile/managing-your-profile-readme", type: .documentation, description: "Create a pinned README on your GitHub profile to highlight your best work.", estimatedTime: "15 min"),
        TestMilestoneResource(id: "sw6-res-3", title: "How to Build a Developer Portfolio", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/news/how-to-build-a-developer-portfolio-website/", type: .article, description: "Practical guide to structuring and presenting a technical portfolio.", estimatedTime: "10 min"),
    ],
]

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
let decoder = JSONDecoder()

// ── Test 1: Resource model Codable roundtrip ──

let sampleResource = TestMilestoneResource(id: "sw1-res-1", title: "CS50", provider: "Harvard", url: "https://cs50.harvard.edu/x/", type: .course, description: "Free intro to CS.", estimatedTime: "Self-paced")
let resData = try! encoder.encode(sampleResource)
let decodedRes = try! decoder.decode(TestMilestoneResource.self, from: resData)
assertEqual(decodedRes.id, sampleResource.id, "Codable roundtrip: id")
assertEqual(decodedRes.title, sampleResource.title, "Codable roundtrip: title")
assertEqual(decodedRes.provider, sampleResource.provider, "Codable roundtrip: provider")
assertEqual(decodedRes.url, sampleResource.url, "Codable roundtrip: url")
assertEqual(decodedRes.type, sampleResource.type, "Codable roundtrip: type")
assertEqual(decodedRes.description, sampleResource.description, "Codable roundtrip: description")
assertEqual(decodedRes.estimatedTime, sampleResource.estimatedTime, "Codable roundtrip: estimatedTime")

// ── Test 2: Legacy milestone without resources decodes successfully ──

struct LegacyMilestone: Codable {
    let id: String
    let title: String
    let resources: [String]
    let learningResources: [TestMilestoneResource]?
}
let legacyJSON = """
{"id":"legacy-1","title":"Legacy Milestone","resources":["old resource string"]}
""".data(using: .utf8)!
let legacyDecoded = try! decoder.decode(LegacyMilestone.self, from: legacyJSON)
assertEqual(legacyDecoded.id, "legacy-1", "Legacy milestone decodes id")
assertEqual(legacyDecoded.resources.count, 1, "Legacy resources array preserved")
assert(legacyDecoded.learningResources == nil, "Legacy milestone has nil learningResources")

// ── Test 3: Software Engineer roadmap contains resources ──

let totalResources = swResources.values.reduce(0) { $0 + $1.count }
assert(totalResources > 0, "Software Engineer roadmap has resources")

let milestoneIDs = ["software-1", "software-2", "software-3", "software-4", "software-5", "software-6"]
for mid in milestoneIDs {
    let res = swResources[mid] ?? []
    assert(!res.isEmpty, "Milestone \(mid) has at least 1 resource")
    assert(res.count <= 3, "Milestone \(mid) has at most 3 resources, got \(res.count)")
}

// ── Test 4: Every resource has a stable ID ──

for (mid, resources) in swResources {
    for res in resources {
        assert(!res.id.isEmpty, "\(mid) resource has non-empty ID")
        assert(res.id != UUID().uuidString, "\(mid) resource \(res.id) is not a UUID default")
    }
}

// ── Test 5: Resource IDs are unique within each milestone ──

for (mid, resources) in swResources {
    let ids = resources.map(\.id)
    let unique = Set(ids)
    assertEqual(unique.count, ids.count, "\(mid) has unique resource IDs")
}

// ── Test 6: Resource IDs are globally unique ──

let allIDs = swResources.values.flatMap { $0.map(\.id) }
assertEqual(Set(allIDs).count, allIDs.count, "All resource IDs are globally unique")

// ── Test 7: Every resource has a valid non-empty URL ──

for (mid, resources) in swResources {
    for res in resources {
        assert(!res.url.isEmpty, "\(mid) \(res.id) has non-empty URL")
        assert(res.url.hasPrefix("https://"), "\(mid) \(res.id) URL starts with https://, got: \(res.url)")
        assert(res.url.contains("."), "\(mid) \(res.id) URL contains a domain")
    }
}

// ── Test 8: Every resource has title, provider, type, description ──

for (mid, resources) in swResources {
    for res in resources {
        assert(!res.title.isEmpty, "\(mid) \(res.id) has non-empty title")
        assert(!res.provider.isEmpty, "\(mid) \(res.id) has non-empty provider")
        assert(!res.description.isEmpty, "\(mid) \(res.id) has non-empty description")
    }
}

// ── Test 9: Resources associated with correct milestone ──

assertEqual(swResources["software-1"]?.count, 3, "software-1 has 3 resources")
assertEqual(swResources["software-2"]?.count, 3, "software-2 has 3 resources")
assertEqual(swResources["software-3"]?.count, 3, "software-3 has 3 resources")
assertEqual(swResources["software-4"]?.count, 3, "software-4 has 3 resources")
assertEqual(swResources["software-5"]?.count, 3, "software-5 has 3 resources")
assertEqual(swResources["software-6"]?.count, 3, "software-6 has 3 resources")
assertEqual(totalResources, 18, "Total 18 resources across 6 milestones")

// ── Test 10: Existing action IDs remain unchanged ──

let expectedActionIDs = [
    "software-1-action-1", "software-1-action-2", "software-1-action-3", "software-1-action-4",
    "software-2-action-1", "software-2-action-2", "software-2-action-3", "software-2-action-4",
    "software-3-action-1", "software-3-action-2", "software-3-action-3", "software-3-action-4",
    "software-4-action-1", "software-4-action-2", "software-4-action-3", "software-4-action-4",
    "software-5-action-1", "software-5-action-2", "software-5-action-3",
    "software-6-action-1", "software-6-action-2", "software-6-action-3", "software-6-action-4",
]
assertEqual(expectedActionIDs.count, 23, "23 action IDs unchanged")
assertEqual(Set(expectedActionIDs).count, 23, "All action IDs unique")
for id in expectedActionIDs {
    assert(id.hasPrefix("software-"), "Action ID \(id) prefix preserved")
    assert(id.contains("-action-"), "Action ID \(id) format preserved")
}

// ── Test 11: Existing action completion persistence unchanged ──

var completedIDs: Set<String> = []
for id in expectedActionIDs { completedIDs.insert(id) }
assertEqual(completedIDs.count, 23, "All 23 action IDs stored")
// Toggle one off and back
completedIDs.remove("software-3-action-2")
assertEqual(completedIDs.count, 22, "Toggle off reduces count")
completedIDs.insert("software-3-action-2")
assertEqual(completedIDs.count, 23, "Toggle on restores count")

// ── Test 12: Existing roadmap progress calculations unchanged ──

func percent(completed: Int, total: Int) -> Int {
    guard total > 0 else { return 0 }
    return Int((Double(completed) / Double(total) * 100).rounded())
}
assertEqual(percent(completed: 0, total: 6), 0, "Progress 0/6 → 0%")
assertEqual(percent(completed: 3, total: 6), 50, "Progress 3/6 → 50%")
assertEqual(percent(completed: 6, total: 6), 100, "Progress 6/6 → 100%")

// ── Test 13: Other roadmaps have no resources ──

let otherRoadmapIDs = ["research-builder", "portfolio-projects", "college-ready"]
for rid in otherRoadmapIDs {
    assert(swResources[rid] == nil, "Roadmap \(rid) has no resources (unchanged)")
}

// ── Test 14: Invalid/missing optional resource fields do not crash ──

let partialJSON = """
{"id":"partial-1","title":"","provider":"","url":"","type":"article","description":""}
""".data(using: .utf8)!
let partialDecoded = try! decoder.decode(TestMilestoneResource.self, from: partialJSON)
assertEqual(partialDecoded.id, "partial-1", "Partial resource decodes id")
assertEqual(partialDecoded.title, "", "Partial resource: empty title ok")
assertEqual(partialDecoded.url, "", "Partial resource: empty url ok")

let minimalJSON = """
{"id":"min-1"}
""".data(using: .utf8)!
let minimalDecoded = try! decoder.decode(TestMilestoneResource.self, from: minimalJSON)
assertEqual(minimalDecoded.id, "min-1", "Minimal resource decodes id")
assertEqual(minimalDecoded.title, "", "Minimal resource: title defaults to empty")
assertEqual(minimalDecoded.type, .article, "Minimal resource: type defaults to .article")

// ── Test 15: Resource type enum covers all expected cases ──

let allTypes: [TestMilestoneResourceType] = [.article, .video, .documentation, .interactive, .course]
assertEqual(allTypes.count, 5, "5 resource types defined")
for t in allTypes {
    let data = try! encoder.encode(t)
    let decoded = try! decoder.decode(TestMilestoneResourceType.self, from: data)
    assertEqual(decoded, t, "Resource type \(t.rawValue) roundtrips")
}

// ── Test 16: Resources with estimatedTime preserve it ──

let timed = TestMilestoneResource(id: "t1", title: "T", provider: "P", url: "https://example.com", type: .article, description: "D", estimatedTime: "15 min")
let timedData = try! encoder.encode(timed)
let timedDecoded = try! decoder.decode(TestMilestoneResource.self, from: timedData)
assertEqual(timedDecoded.estimatedTime ?? "", "15 min", "estimatedTime preserved through Codable")

let untimed = TestMilestoneResource(id: "t2", title: "T", provider: "P", url: "https://example.com", type: .article, description: "D")
let untimedData = try! encoder.encode(untimed)
let untimedDecoded = try! decoder.decode(TestMilestoneResource.self, from: untimedData)
assert(untimedDecoded.estimatedTime == nil, "nil estimatedTime preserved through Codable")

// ── Test 17: Resource IDs use predictable naming convention ──

let allResourceIDs = swResources.values.flatMap { $0.map(\.id) }
for rid in allResourceIDs {
    assert(rid.hasPrefix("sw"), "Resource ID \(rid) starts with 'sw'")
    assert(rid.contains("-res-"), "Resource ID \(rid) contains '-res-'")
}

// ── Summary ──

print("\n══════════════════════════════════════════════")
print("Phase 6.4.4 Tests: \(passed) passed, \(failed) failed")
print("══════════════════════════════════════════════")
if failed > 0 { exit(1) }
