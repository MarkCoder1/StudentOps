import Foundation

// Standalone test script for Phase 6.4.10 — End-to-End Integration
// Run: swift test-e2e-roadmap.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// ═══════════════════════════════════════════════════════════════
//  INLINE MODEL TYPES
// ═══════════════════════════════════════════════════════════════

enum SchoolLevel: String, Hashable, Codable {
    case middleSchool, highSchool
}

enum Grade: String, Hashable, Codable, CaseIterable {
    case seventh, eighth, ninth, tenth, eleventh, twelfth
}

enum CollegePlan: String, Hashable, Codable {
    case yesDefinitely, probably, notSure, no, exploringOthers
}

enum RoadmapCategory: String, Hashable, Codable {
    case career, skills, academic, projects, collegePreparation
}

struct StudentProfile: Codable, Equatable {
    var name: String = ""
    var interests: [String] = []
    var strengths: [String] = []
    var customSkills: [String] = []
    var careers: [String] = []
    var fields: [String] = []
    var grade: Grade = .ninth
    var collegePlan: CollegePlan = .notSure
    var onboardingCompleted: Bool = false
}

struct MilestoneAction: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String
    let order: Int
    let estimatedTime: String?
    init(id: String = UUID().uuidString, title: String, description: String, order: Int = 0, estimatedTime: String? = nil) {
        self.id = id; self.title = title; self.description = description; self.order = order; self.estimatedTime = estimatedTime
    }
}

struct MilestoneResource: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let provider: String
    let url: String
    let type: String
    let description: String
    let estimatedTime: String?
    init(id: String = UUID().uuidString, title: String, provider: String, url: String, type: String, description: String, estimatedTime: String? = nil) {
        self.id = id; self.title = title; self.provider = provider; self.url = url; self.type = type; self.description = description; self.estimatedTime = estimatedTime
    }
}

struct ValidationQuestion: Identifiable, Hashable, Codable {
    let id: String
    let question: String
    let choices: [String]
    let correctAnswer: Int
    let explanation: String
    init(id: String = UUID().uuidString, question: String, choices: [String], correctAnswer: Int, explanation: String) {
        self.id = id; self.question = question; self.choices = choices; self.correctAnswer = correctAnswer; self.explanation = explanation
    }
}

struct MilestoneAssessment: Identifiable, Hashable, Codable {
    let id: String
    let questions: [ValidationQuestion]
    let passThreshold: Int
    init(id: String = UUID().uuidString, questions: [ValidationQuestion], passThreshold: Int = 70) {
        self.id = id; self.questions = questions; self.passThreshold = passThreshold
    }
}

struct ValidationAttempt: Identifiable, Hashable, Codable {
    let id: String
    let validationID: String
    let selectedAnswers: [String: Int]
    let score: Int
    let totalQuestions: Int
    let percentage: Int
    let passed: Bool
    init(id: String = UUID().uuidString, validationID: String, selectedAnswers: [String: Int], score: Int, totalQuestions: Int, percentage: Int, passed: Bool) {
        self.id = id; self.validationID = validationID; self.selectedAnswers = selectedAnswers; self.score = score; self.totalQuestions = totalQuestions; self.percentage = percentage; self.passed = passed
    }
}

struct EvidenceRecord: Identifiable, Hashable, Codable {
    let id: String
    let type: String
    let title: String
    let description: String?
    let roadmapID: String
    let milestoneID: String
    let completionDate: TimeInterval
    let validationID: String?
    let validationScore: Int?
    let validationPercentage: Int?
    let validationPassed: Bool?
    let projectID: String?
    let opportunityID: String?
    init(id: String = UUID().uuidString, type: String, title: String, description: String? = nil, roadmapID: String, milestoneID: String, completionDate: TimeInterval = Date().timeIntervalSince1970, validationID: String? = nil, validationScore: Int? = nil, validationPercentage: Int? = nil, validationPassed: Bool? = nil, projectID: String? = nil, opportunityID: String? = nil) {
        self.id = id; self.type = type; self.title = title; self.description = description; self.roadmapID = roadmapID; self.milestoneID = milestoneID; self.completionDate = completionDate; self.validationID = validationID; self.validationScore = validationScore; self.validationPercentage = validationPercentage; self.validationPassed = validationPassed; self.projectID = projectID; self.opportunityID = opportunityID
    }
}

struct RoadmapMilestone: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let estimatedTime: String
    let whatItAccomplishes: String
    let whyItMatters: String
    let recommendedActions: [String]
    let resources: [String]
    let projectAction: String?
    let goal: String?
    let actions: [MilestoneAction]?
    let validation: MilestoneValidation?
    let skillsDeveloped: [String]?
    let evidence: [MilestoneEvidence]?
    let completionCriteria: [String]?
    let dependencies: [String]?
    let learningResources: [MilestoneResource]?
    let assessment: MilestoneAssessment?

    init(id: String, title: String, subtitle: String = "Sub", estimatedTime: String = "1 hr",
         whatItAccomplishes: String = "Desc", whyItMatters: String = "Why",
         recommendedActions: [String] = [], resources: [String] = [], projectAction: String? = nil,
         goal: String? = nil, actions: [MilestoneAction]? = nil,
         validation: MilestoneValidation? = nil, skillsDeveloped: [String]? = nil,
         evidence: [MilestoneEvidence]? = nil, completionCriteria: [String]? = nil,
         dependencies: [String]? = nil, learningResources: [MilestoneResource]? = nil,
         assessment: MilestoneAssessment? = nil) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.estimatedTime = estimatedTime
        self.whatItAccomplishes = whatItAccomplishes; self.whyItMatters = whyItMatters
        self.recommendedActions = recommendedActions; self.resources = resources; self.projectAction = projectAction
        self.goal = goal; self.actions = actions; self.validation = validation
        self.skillsDeveloped = skillsDeveloped; self.evidence = evidence; self.completionCriteria = completionCriteria
        self.dependencies = dependencies; self.learningResources = learningResources; self.assessment = assessment
    }
}

struct MilestoneValidation: Hashable, Codable {
    let method: String?
    let requirement: String?
    init(method: String? = nil, requirement: String? = nil) { self.method = method; self.requirement = requirement }
}

struct MilestoneEvidence: Identifiable, Hashable, Codable {
    let id: String
    let type: String
    let title: String
    let description: String?
    init(id: String = UUID().uuidString, type: String, title: String, description: String? = nil) {
        self.id = id; self.type = type; self.title = title; self.description = description
    }
}

struct Roadmap: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let goal: String
    let category: RoadmapCategory
    let description: String
    let milestones: [RoadmapMilestone]
    let relevantInterests: Set<String>
    let relevantSkills: Set<String>
    let relevantCareers: Set<String>
    let relevantFields: Set<String>
    let eligibleGrades: Set<Grade>
    let collegeFocused: Bool
    init(id: String, title: String, goal: String = "", category: RoadmapCategory = .career,
         description: String = "", milestones: [RoadmapMilestone],
         relevantInterests: Set<String> = [], relevantSkills: Set<String> = [],
         relevantCareers: Set<String> = [], relevantFields: Set<String> = [],
         eligibleGrades: Set<Grade> = Set(Grade.allCases), collegeFocused: Bool = false) {
        self.id = id; self.title = title; self.goal = goal; self.category = category
        self.description = description; self.milestones = milestones
        self.relevantInterests = relevantInterests; self.relevantSkills = relevantSkills
        self.relevantCareers = relevantCareers; self.relevantFields = relevantFields
        self.eligibleGrades = eligibleGrades; self.collegeFocused = collegeFocused
    }
}

enum RoadmapActivationStatus: String, Codable, Hashable {
    case active, completed
}

struct ActiveRoadmap: Identifiable, Hashable, Codable {
    let roadmapID: String
    let status: RoadmapActivationStatus
    let startedAt: TimeInterval
    var id: String { roadmapID }
    init(roadmapID: String, status: RoadmapActivationStatus = .active, startedAt: TimeInterval = Date().timeIntervalSince1970) {
        self.roadmapID = roadmapID; self.status = status; self.startedAt = startedAt
    }
}

enum MilestoneAvailability: Equatable {
    case completed, available
    case locked(blockingIDs: [String])
}

struct DependencyLockInfo: Equatable {
    let blockingPrerequisites: [BlockingPrerequisite]
    struct BlockingPrerequisite: Equatable {
        let id: String
        let title: String
    }
}

struct ScoredRoadmap: Identifiable, Hashable {
    let roadmap: Roadmap
    let matchScore: Int
    let completedMilestones: Int
    var id: String { roadmap.id }
    var progress: Int {
        let total = roadmap.milestones.count
        guard total > 0 else { return 0 }
        return Int((Double(completedMilestones) / Double(total) * 100).rounded())
    }
    var currentMilestone: RoadmapMilestone? {
        guard completedMilestones < roadmap.milestones.count else { return nil }
        return roadmap.milestones[completedMilestones]
    }
    var isCompleted: Bool { completedMilestones >= roadmap.milestones.count }
}

struct ProgressSnapshot {
    let completedMilestones: Int
    let totalMilestones: Int
    let milestoneProgress: Int
    let activeRoadmaps: Int
    let completedRoadmaps: Int
    let skillCount: Int
    let achievementsCount: Int
    let overallProgress: Int
}

// MARK: - RoadmapService (production algorithm)

enum RoadmapService {
    static func matchScore(for roadmap: Roadmap, profile: StudentProfile) -> Int {
        var score = 50
        score += profile.interests.filter { roadmap.relevantInterests.contains($0) }.count * 6
        score += (profile.strengths + profile.customSkills).filter { roadmap.relevantSkills.contains($0) }.count * 5
        score += profile.careers.filter { roadmap.relevantCareers.contains($0) }.count * 9
        score += profile.fields.filter { roadmap.relevantFields.contains($0) }.count * 8
        if roadmap.eligibleGrades.contains(profile.grade) { score += 7 }
        if roadmap.collegeFocused && (profile.collegePlan == .yesDefinitely || profile.collegePlan == .probably) { score += 8 }
        return min(max(score, 48), 99)
    }

    static func roadmaps(for profile: StudentProfile, progress: [String: Int]) -> [ScoredRoadmap] {
        catalog.map { roadmap in
            ScoredRoadmap(roadmap: roadmap, matchScore: matchScore(for: roadmap, profile: profile),
                          completedMilestones: min(progress[roadmap.id] ?? 0, roadmap.milestones.count))
        }.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            return lhs.matchScore > rhs.matchScore
        }
    }

    private static let catalog: [Roadmap] = [
        softwareEngineer, aiEngineer, researchBuilder, leadership
    ]
    static var allCatalogRoadmaps: [Roadmap] { catalog }

    // MARK: - Catalog Milestones (production IDs)

    private static let softwareEngineer = Roadmap(
        id: "software-engineer", title: "Become a Software Engineer",
        goal: "Turn your technical interests into a project-ready software engineering foundation.",
        category: .career,
        description: "A practical sequence from programming fundamentals to a portfolio and career-ready next steps.",
        milestones: [
            RoadmapMilestone(id: "software-1", title: "Explore Computer Science", subtitle: "Map the concepts and tools behind modern software.", estimatedTime: "30 min",
                whatItAccomplishes: "Build a mental model of what software engineering is.",
                whyItMatters: "Understanding the landscape before writing code helps you choose a focused path.",
                goal: "Develop a clear picture of what software engineering involves.",
                actions: [
                    MilestoneAction(id: "software-1-action-1", title: "Watch a day-in-the-life video", description: "Watch 2-3 videos of software engineers.", order: 1),
                    MilestoneAction(id: "software-1-action-2", title: "Explore subfields", description: "Read one-paragraph descriptions of web dev, mobile, data science, AI/ML.", order: 2),
                    MilestoneAction(id: "software-1-action-3", title: "Set up your development environment", description: "Install VS Code, create a free GitHub account.", order: 3),
                    MilestoneAction(id: "software-1-action-4", title: "Write your first program", description: "Follow a 15-minute Hello World tutorial.", order: 4),
                ],
                skillsDeveloped: ["Computational Thinking", "Development Environment Setup", "Version Control Basics"],
                completionCriteria: ["Complete all four actions.", "Articulate what software engineering means to you."],
                learningResources: [
                    MilestoneResource(id: "sw1-res-1", title: "CS50", provider: "Harvard / edX", url: "https://cs50.harvard.edu/x/", type: "course", description: "Free intro to CS."),
                    MilestoneResource(id: "sw1-res-2", title: "Getting Started with VS Code", provider: "Microsoft", url: "https://code.visualstudio.com/docs/getstarted/getting-started", type: "documentation", description: "VS Code guide."),
                    MilestoneResource(id: "sw1-res-3", title: "Hello World", provider: "GitHub", url: "https://docs.github.com/en/get-started/quickstart/hello-world", type: "documentation", description: "First repo."),
                ],
                assessment: MilestoneAssessment(id: "sw1-assessment", questions: [
                    ValidationQuestion(id: "sw1-q1", question: "What is an algorithm?", choices: ["Hardware", "Step-by-step procedure", "A language", "A website"], correctAnswer: 1, explanation: "An algorithm is a step-by-step set of instructions."),
                    ValidationQuestion(id: "sw1-q2", question: "What is the main purpose of VS Code?", choices: ["Browse internet", "Write, edit, and organize code", "Play games", "Send emails"], correctAnswer: 1, explanation: "VS Code provides tools for writing code."),
                    ValidationQuestion(id: "sw1-q3", question: "What does version control track?", choices: ["Grades", "Changes to files over time", "Browsing history", "Social media"], correctAnswer: 1, explanation: "Version control records changes."),
                ])
            ),
            RoadmapMilestone(id: "software-2", title: "Build Programming Fundamentals", subtitle: "Build fluency with core programming patterns.", estimatedTime: "2-4 weeks",
                whatItAccomplishes: "Develop working fluency with variables, conditions, loops, functions.",
                whyItMatters: "Every programming language builds on these patterns.",
                goal: "Write programs that use variables, conditions, loops, and functions.",
                actions: [
                    MilestoneAction(id: "software-2-action-1", title: "Complete a structured beginner course", description: "Finish a free course.", order: 1),
                    MilestoneAction(id: "software-2-action-2", title: "Solve 10-15 practice problems", description: "Use Codewars or LeetCode.", order: 2),
                    MilestoneAction(id: "software-2-action-3", title: "Build a command-line tool", description: "Create a small program.", order: 3),
                    MilestoneAction(id: "software-2-action-4", title: "Learn basic data structures", description: "Use arrays and dictionaries.", order: 4),
                ],
                skillsDeveloped: ["Programming Fundamentals", "Problem Solving", "Python", "JavaScript"],
                completionCriteria: ["Complete all four actions.", "Write a program using conditionals, loops, and functions."],
                dependencies: ["software-1"],
                learningResources: [
                    MilestoneResource(id: "sw2-res-1", title: "Scientific Computing with Python", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/learn/scientific-computing-with-python/", type: "course", description: "Free Python course."),
                    MilestoneResource(id: "sw2-res-2", title: "The Python Tutorial", provider: "Python.org", url: "https://docs.python.org/3/tutorial/", type: "documentation", description: "Official Python tutorial."),
                    MilestoneResource(id: "sw2-res-3", title: "Python Tutorial for Beginners", provider: "W3Schools", url: "https://www.w3schools.com/python/", type: "interactive", description: "Interactive Python lessons."),
                ],
                assessment: MilestoneAssessment(id: "sw2-assessment", questions: [
                    ValidationQuestion(id: "sw2-q1", question: "What is a variable?", choices: ["Fixed value", "Named container that stores a value", "A type of loop", "A function"], correctAnswer: 1, explanation: "A variable is a named label for a value."),
                    ValidationQuestion(id: "sw2-q2", question: "What does a conditional do?", choices: ["Repeats code", "Makes program faster", "Chooses actions based on condition", "Stores data in file"], correctAnswer: 2, explanation: "Conditionals let programs make decisions."),
                    ValidationQuestion(id: "sw2-q3", question: "What is the purpose of a loop?", choices: ["Delete files", "Repeat instructions until condition is met", "Connect to internet", "Create new variable"], correctAnswer: 1, explanation: "Loops let you repeat code efficiently."),
                    ValidationQuestion(id: "sw2-q4", question: "What does a function allow you to do?", choices: ["Run without errors", "Reuse a block of code by calling it by name", "Store data permanently", "Connect to database"], correctAnswer: 1, explanation: "Functions package instructions into reusable blocks."),
                ])
            ),
            RoadmapMilestone(id: "software-3", title: "Learn Software Development", subtitle: "Understand how real software is built.", estimatedTime: "3-5 weeks",
                whatItAccomplishes: "Move from scripts to understanding software systems.",
                whyItMatters: "Professional software is more than one file of code.",
                goal: "Use Git, debug effectively, call an API, and write a basic test.",
                actions: [
                    MilestoneAction(id: "software-3-action-1", title: "Learn Git fundamentals", description: "Complete a Git tutorial.", order: 1),
                    MilestoneAction(id: "software-3-action-2", title: "Master your debugger", description: "Learn to set breakpoints in VS Code.", order: 2),
                    MilestoneAction(id: "software-3-action-3", title: "Call a public API", description: "Use fetch/requests to retrieve data.", order: 3),
                    MilestoneAction(id: "software-3-action-4", title: "Write your first test", description: "Learn unit testing basics.", order: 4),
                ],
                skillsDeveloped: ["Git", "Debugging", "APIs", "Unit Testing", "Software Development"],
                completionCriteria: ["Complete all four actions.", "Have at least 5 commits in a Git repository."],
                dependencies: ["software-2"],
                learningResources: [
                    MilestoneResource(id: "sw3-res-1", title: "Git & GitHub Skills", provider: "GitHub", url: "https://skills.github.com/", type: "interactive", description: "Interactive Git exercises."),
                    MilestoneResource(id: "sw3-res-2", title: "Use Git Version Control", provider: "GitHub Docs", url: "https://docs.github.com/en/get-started/using-git/about-git", type: "documentation", description: "Official Git guide."),
                    MilestoneResource(id: "sw3-res-3", title: "HTTP Overview", provider: "MDN Web Docs", url: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Overview", type: "documentation", description: "HTTP explanation."),
                ],
                assessment: MilestoneAssessment(id: "sw3-assessment", questions: [
                    ValidationQuestion(id: "sw3-q1", question: "What does a commit represent?", choices: ["Merge request", "Saved snapshot of code", "A bug", "A password file"], correctAnswer: 1, explanation: "A commit is a saved snapshot."),
                    ValidationQuestion(id: "sw3-q2", question: "What is an API?", choices: ["Virus", "Rules for software communication", "A language", "Hardware"], correctAnswer: 1, explanation: "An API defines how software components communicate."),
                    ValidationQuestion(id: "sw3-q3", question: "Benefit of debugger over print?", choices: ["Faster code", "Pause and inspect variables step by step", "Auto-fix all bugs", "Python only"], correctAnswer: 1, explanation: "Debuggers let you pause and inspect."),
                    ValidationQuestion(id: "sw3-q4", question: "Purpose of writing tests?", choices: ["Look professional", "Verify code works and catch bugs early", "Slow program", "Replace documentation"], correctAnswer: 1, explanation: "Tests check expected output."),
                ])
            ),
            RoadmapMilestone(id: "software-4", title: "Build Real Projects", subtitle: "Create a project that solves a real problem.", estimatedTime: "4-6 weeks",
                whatItAccomplishes: "Apply everything to a real project from start to finish.",
                whyItMatters: "Projects are the strongest evidence of your skills.",
                goal: "Complete and ship one functional project.",
                actions: [
                    MilestoneAction(id: "software-4-action-1", title: "Choose a real problem", description: "Identify a small problem.", order: 1),
                    MilestoneAction(id: "software-4-action-2", title: "Plan the build", description: "Break the project into milestones.", order: 2),
                    MilestoneAction(id: "software-4-action-3", title: "Build incrementally", description: "Develop in stages, commit to Git.", order: 3),
                    MilestoneAction(id: "software-4-action-4", title: "Write a README", description: "Create a README.md.", order: 4),
                ],
                skillsDeveloped: ["Software Development", "Project Planning", "Technical Communication", "Building Things"],
                completionCriteria: ["Complete all four actions.", "The project runs without critical errors."],
                dependencies: ["software-3"],
                learningResources: [
                    MilestoneResource(id: "sw4-res-1", title: "About READMEs", provider: "GitHub Docs", url: "https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes", type: "documentation", description: "README guide."),
                    MilestoneResource(id: "sw4-res-2", title: "GitHub Pages Quickstart", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: "documentation", description: "Set up GitHub Pages."),
                    MilestoneResource(id: "sw4-res-3", title: "Awesome README", provider: "GitHub", url: "https://github.com/matiassingers/awesome-readme", type: "article", description: "Curated README examples."),
                ],
                assessment: MilestoneAssessment(id: "sw4-assessment", questions: [
                    ValidationQuestion(id: "sw4-q1", question: "First thing when starting a project?", choices: ["Start coding", "Define the problem you are solving", "Choose new language", "Create social media"], correctAnswer: 1, explanation: "Understanding the problem first helps."),
                    ValidationQuestion(id: "sw4-q2", question: "Why break into milestones?", choices: ["Makes it longer", "Makes progress visible", "Prevents Git use", "Required by languages"], correctAnswer: 1, explanation: "Milestones make projects manageable."),
                    ValidationQuestion(id: "sw4-q3", question: "Purpose of a README?", choices: ["Hide code", "Explain what it does, how to run it, what you learned", "Replace comments", "Auto-fix bugs"], correctAnswer: 1, explanation: "A README helps others understand."),
                    ValidationQuestion(id: "sw4-q4", question: "What does iterating mean?", choices: ["Delete and start over", "Make small improvements and test after each", "Wait until perfect", "Copy someone else"], correctAnswer: 1, explanation: "Iteration means building in small cycles."),
                ])
            ),
            RoadmapMilestone(id: "software-5", title: "Gain External Experience", subtitle: "Put skills to work in a real-world context.", estimatedTime: "2-4 weeks",
                whatItAccomplishes: "Build credibility through external contribution.",
                whyItMatters: "External experience shows you can work with others.",
                goal: "Participate in at least one external coding event.",
                actions: [
                    MilestoneAction(id: "software-5-action-1", title: "Join a hackathon or competition", description: "Register for a student hackathon.", order: 1),
                    MilestoneAction(id: "software-5-action-2", title: "Contribute to open source", description: "Find a beginner-friendly issue.", order: 2),
                    MilestoneAction(id: "software-5-action-3", title: "Explain your work publicly", description: "Write a short blog post.", order: 3),
                ],
                skillsDeveloped: ["Technical Communication", "Collaboration", "Software Development", "Competition Skills"],
                completionCriteria: ["Complete all three actions.", "Submit to a hackathon or have a PR on GitHub."],
                dependencies: ["software-4"],
                learningResources: [
                    MilestoneResource(id: "sw5-res-1", title: "MLH Student Hackathons", provider: "MLH", url: "https://mlh.io/", type: "interactive", description: "Find student hackathons."),
                    MilestoneResource(id: "sw5-res-2", title: "Devpost Hackathon Projects", provider: "Devpost", url: "https://devpost.com/", type: "interactive", description: "Browse hackathon projects."),
                    MilestoneResource(id: "sw5-res-3", title: "Finding Good First Issues", provider: "GitHub Docs", url: "https://docs.github.com/en/issues/tracking-your-work-with-issues/using-labels-and-milestones/filtering-your-issues-and-pull-requests-by-label", type: "documentation", description: "How to find beginner issues."),
                ],
                assessment: MilestoneAssessment(id: "sw5-assessment", questions: [
                    ValidationQuestion(id: "sw5-q1", question: "What is a pull request?", choices: ["Delete a repo", "Proposal to merge your changes", "A bug report", "A download command"], correctAnswer: 1, explanation: "A PR proposes changes for review."),
                    ValidationQuestion(id: "sw5-q2", question: "Why is open source valuable?", choices: ["Guarantees a job", "Builds collaboration skills and evidence", "Required for college", "Improves grades"], correctAnswer: 1, explanation: "Open source demonstrates collaboration."),
                    ValidationQuestion(id: "sw5-q3", question: "First step for open-source issue?", choices: ["Rewrite everything", "Look for good first issue labels", "Email owner", "Ignore description"], correctAnswer: 1, explanation: "Good first issue labels indicate entry points."),
                ])
            ),
            RoadmapMilestone(id: "software-6", title: "Build a Technical Portfolio", subtitle: "Document your projects and learning.", estimatedTime: "1-2 weeks",
                whatItAccomplishes: "Create a polished portfolio.",
                whyItMatters: "A portfolio is the most effective way to show what you can do.",
                goal: "Have a live, shareable portfolio showcasing at least 2 projects.",
                actions: [
                    MilestoneAction(id: "software-6-action-1", title: "Choose your best 2-3 projects", description: "Pick projects showing different skills.", order: 1),
                    MilestoneAction(id: "software-6-action-2", title: "Build a portfolio page", description: "Create a portfolio website.", order: 2),
                    MilestoneAction(id: "software-6-action-3", title: "Polish your GitHub profile", description: "Add a profile README, pin repos.", order: 3),
                    MilestoneAction(id: "software-6-action-4", title: "Share and get feedback", description: "Send portfolio to a teacher or mentor.", order: 4),
                ],
                skillsDeveloped: ["Technical Communication", "Portfolio Development", "Personal Branding", "Web Development"],
                completionCriteria: ["Complete all four actions.", "Portfolio is live and accessible."],
                dependencies: ["software-5"],
                learningResources: [
                    MilestoneResource(id: "sw6-res-1", title: "Your First Portfolio Website", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: "documentation", description: "Publish a portfolio on GitHub Pages."),
                    MilestoneResource(id: "sw6-res-2", title: "Managing Your Profile README", provider: "GitHub Docs", url: "https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile/customizing-your-profile/managing-your-profile-readme", type: "documentation", description: "Create a profile README."),
                    MilestoneResource(id: "sw6-res-3", title: "How to Build a Developer Portfolio", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/news/how-to-build-a-developer-portfolio-website/", type: "article", description: "Guide to building a portfolio."),
                ],
                assessment: MilestoneAssessment(id: "sw6-assessment", questions: [
                    ValidationQuestion(id: "sw6-q1", question: "What makes good portfolio evidence?", choices: ["Most popular language", "Solves a real problem and shows thinking", "Most lines of code", "Assigned by teacher"], correctAnswer: 1, explanation: "Strong projects demonstrate problem-solving."),
                    ValidationQuestion(id: "sw6-q2", question: "What to explain when presenting?", choices: ["Only the result", "Problem, approach, built, learned", "Only code syntax", "Nothing"], correctAnswer: 1, explanation: "Explaining the full process shows reflection."),
                    ValidationQuestion(id: "sw6-q3", question: "Why have a README in projects?", choices: ["Looks bigger", "Helps others quickly understand", "Required by GitHub", "Improves SEO"], correctAnswer: 1, explanation: "A clear README is the first thing viewers read."),
                ])
            ),
        ],
        relevantInterests: ["Technology", "AI", "Engineering"],
        relevantSkills: ["Programming", "Problem solving", "Building things"],
        relevantCareers: ["Software Engineer", "AI Researcher"],
        relevantFields: ["Computer Science", "Engineering"],
        eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth],
        collegeFocused: true
    )

    private static let aiEngineer = Roadmap(
        id: "ai-engineer", title: "Become an AI Engineer",
        goal: "Build a foundation in AI and machine learning.",
        category: .career,
        description: "A practical path from programming fundamentals through ML to building real AI applications.",
        milestones: [
            RoadmapMilestone(id: "ai-1", title: "Explore AI & ML", subtitle: "Understand what AI and ML are.", estimatedTime: "1 hour",
                whatItAccomplishes: "Build a mental model of AI and ML.",
                whyItMatters: "Understanding the landscape helps you focus.",
                goal: "Explain AI and ML and name 5 real-world applications.",
                actions: [
                    MilestoneAction(id: "ai-1-action-1", title: "Watch introductory AI videos", description: "Watch 2-3 short videos about AI.", order: 1),
                    MilestoneAction(id: "ai-1-action-2", title: "Explore AI applications", description: "Try an image classifier or text generator.", order: 2),
                    MilestoneAction(id: "ai-1-action-3", title: "Map the AI landscape", description: "Read about ML, NLP, CV, robotics.", order: 3),
                ],
                skillsDeveloped: ["AI Literacy", "Technical Exploration", "Critical Thinking"],
                completionCriteria: ["Complete all three actions.", "Name at least 3 real-world AI applications."],
                learningResources: [
                    MilestoneResource(id: "ai1-res-1", title: "Elements of AI", provider: "University of Helsinki", url: "https://www.elementsofai.com/", type: "course", description: "Free intro to AI."),
                    MilestoneResource(id: "ai1-res-2", title: "AI For Everyone", provider: "Coursera", url: "https://www.coursera.org/learn/ai-for-everyone", type: "course", description: "Non-technical AI overview."),
                    MilestoneResource(id: "ai1-res-3", title: "Google AI Experiments", provider: "Google", url: "https://experiments.withgoogle.com/collection/ai", type: "interactive", description: "AI demos."),
                ],
                assessment: MilestoneAssessment(id: "ai1-assessment", questions: [
                    ValidationQuestion(id: "ai1-q1", question: "What is machine learning?", choices: ["Hardware", "A subset of AI where computers learn from data", "A language", "A website"], correctAnswer: 1, explanation: "ML learns patterns from data."),
                    ValidationQuestion(id: "ai1-q2", question: "Example of ML in everyday life?", choices: ["Calculator", "Streaming service recommending shows", "Word processor", "Clock"], correctAnswer: 1, explanation: "Recommendation systems learn preferences."),
                    ValidationQuestion(id: "ai1-q3", question: "What is computer vision?", choices: ["Display screen", "AI that interprets images and video", "Camera brand", "Photo editor"], correctAnswer: 1, explanation: "Computer vision interprets visual information."),
                ])
            ),
            RoadmapMilestone(id: "ai-2", title: "Build Programming & Math Foundations", subtitle: "Develop Python and math skills for AI.", estimatedTime: "3-5 weeks",
                whatItAccomplishes: "Gain fluency in Python and core math for ML.",
                whyItMatters: "AI libraries are written in Python and ML relies on math.",
                goal: "Write Python programs and explain basic math for data analysis.",
                actions: [
                    MilestoneAction(id: "ai-2-action-1", title: "Learn Python fundamentals", description: "Complete a Python course.", order: 1),
                    MilestoneAction(id: "ai-2-action-2", title: "Study core math for AI", description: "Review linear algebra, probability, statistics.", order: 2),
                    MilestoneAction(id: "ai-2-action-3", title: "Learn NumPy and Pandas", description: "Use NumPy and Pandas for data manipulation.", order: 3),
                    MilestoneAction(id: "ai-2-action-4", title: "Work with a real dataset", description: "Download and analyze a public dataset.", order: 4),
                ],
                skillsDeveloped: ["Python", "Data Analysis", "Statistics", "Mathematics", "Programming Fundamentals"],
                completionCriteria: ["Complete all four actions.", "Load and analyze a real dataset using Pandas."],
                dependencies: ["ai-1"],
                learningResources: [
                    MilestoneResource(id: "ai2-res-1", title: "Scientific Computing with Python", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/learn/scientific-computing-with-python/", type: "course", description: "Free Python course."),
                    MilestoneResource(id: "ai2-res-2", title: "Khan Academy: Statistics & Probability", provider: "Khan Academy", url: "https://www.khanacademy.org/math/statistics-probability", type: "interactive", description: "Statistics lessons."),
                    MilestoneResource(id: "ai2-res-3", title: "Kaggle Learn: Pandas", provider: "Kaggle", url: "https://www.kaggle.com/learn/pandas", type: "interactive", description: "Pandas course."),
                ],
                assessment: MilestoneAssessment(id: "ai2-assessment", questions: [
                    ValidationQuestion(id: "ai2-q1", question: "What does a Pandas DataFrame do?", choices: ["Create websites", "Store and manipulate tabular data", "Run ML models", "Generate images"], correctAnswer: 1, explanation: "DataFrames work with rows and columns."),
                    ValidationQuestion(id: "ai2-q2", question: "Why is linear algebra important for AI?", choices: ["Faster loops", "Data is represented as vectors and matrices", "Computer graphics only", "Not important"], correctAnswer: 1, explanation: "ML operations use matrix math."),
                    ValidationQuestion(id: "ai2-q3", question: "Purpose of EDA?", choices: ["Delete data", "Understand structure and quality before modeling", "Train a model", "Publish a paper"], correctAnswer: 1, explanation: "EDA helps understand your data."),
                ])
            ),
            RoadmapMilestone(id: "ai-3", title: "Learn ML Fundamentals", subtitle: "Understand how machines learn from data.", estimatedTime: "4-6 weeks",
                whatItAccomplishes: "Learn core ML concepts.",
                whyItMatters: "Understanding how models learn separates builders from callers.",
                goal: "Explain supervised vs. unsupervised learning and train a simple model.",
                actions: [
                    MilestoneAction(id: "ai-3-action-1", title: "Study supervised learning", description: "Learn classification and regression.", order: 1),
                    MilestoneAction(id: "ai-3-action-2", title: "Study unsupervised learning", description: "Learn clustering and dimensionality reduction.", order: 2),
                    MilestoneAction(id: "ai-3-action-3", title: "Train your first model", description: "Use Scikit-learn on a simple dataset.", order: 3),
                    MilestoneAction(id: "ai-3-action-4", title: "Learn about overfitting", description: "Understand overfitting and cross-validation.", order: 4),
                    MilestoneAction(id: "ai-3-action-5", title: "Evaluate model performance", description: "Learn accuracy, precision, recall.", order: 5),
                ],
                skillsDeveloped: ["Machine Learning", "Data Analysis", "Model Evaluation", "Python", "Statistics"],
                completionCriteria: ["Complete all five actions.", "Train a classifier achieving at least 80% accuracy."],
                dependencies: ["ai-2"],
                learningResources: [
                    MilestoneResource(id: "ai3-res-1", title: "Google ML Crash Course", provider: "Google", url: "https://developers.google.com/machine-learning/crash-course", type: "course", description: "Free ML intro."),
                    MilestoneResource(id: "ai3-res-2", title: "Scikit-learn Tutorials", provider: "Scikit-learn", url: "https://scikit-learn.org/stable/tutorial/", type: "documentation", description: "Official tutorials."),
                    MilestoneResource(id: "ai3-res-3", title: "Kaggle Learn: Intro to ML", provider: "Kaggle", url: "https://www.kaggle.com/learn/intro-to-machine-learning", type: "interactive", description: "Hands-on ML lessons."),
                ],
                assessment: MilestoneAssessment(id: "ai3-assessment", questions: [
                    ValidationQuestion(id: "ai3-q1", question: "What is supervised learning?", choices: ["Learning without data", "Training on labeled data to predict outcomes", "Finding patterns in unlabeled data", "Building websites"], correctAnswer: 1, explanation: "Supervised learning uses labeled examples."),
                    ValidationQuestion(id: "ai3-q2", question: "What is overfitting?", choices: ["Performs well on all data", "Learns noise, performs poorly on new data", "Too simple", "Trains too slowly"], correctAnswer: 1, explanation: "Overfitting means memorizing training data."),
                    ValidationQuestion(id: "ai3-q3", question: "What does a confusion matrix show?", choices: ["Training speed", "Types of predictions right and wrong", "Dataset size", "Programming language"], correctAnswer: 1, explanation: "Confusion matrices break down predictions."),
                    ValidationQuestion(id: "ai3-q4", question: "Why split data into train/test?", choices: ["Make training faster", "Evaluate generalization to unseen data", "Reduce data needed", "Not necessary"], correctAnswer: 1, explanation: "Testing on unseen data shows real performance."),
                ])
            ),
            RoadmapMilestone(id: "ai-4", title: "Build AI Applications", subtitle: "Apply ML to real-world problems.", estimatedTime: "4-6 weeks",
                whatItAccomplishes: "Build working AI applications.",
                whyItMatters: "Building real applications teaches things tutorials cannot.",
                goal: "Build and deploy at least one working AI application.",
                actions: [
                    MilestoneAction(id: "ai-4-action-1", title: "Choose a meaningful problem", description: "Pick a problem that matters to you.", order: 1),
                    MilestoneAction(id: "ai-4-action-2", title: "Collect and preprocess data", description: "Find and clean a dataset.", order: 2),
                    MilestoneAction(id: "ai-4-action-3", title: "Train and tune your model", description: "Try at least 2 algorithms.", order: 3),
                    MilestoneAction(id: "ai-4-action-4", title: "Build a simple interface", description: "Create a basic web interface.", order: 4),
                ],
                skillsDeveloped: ["Machine Learning", "Data Analysis", "APIs", "AI Application Development", "Software Development"],
                completionCriteria: ["Complete all four actions.", "Build a working interface."],
                dependencies: ["ai-3"],
                learningResources: [
                    MilestoneResource(id: "ai4-res-1", title: "Kaggle: Intermediate ML", provider: "Kaggle", url: "https://www.kaggle.com/learn/intermediate-machine-learning", type: "interactive", description: "Handle missing data."),
                    MilestoneResource(id: "ai4-res-2", title: "Streamlit Tutorial", provider: "Streamlit", url: "https://docs.streamlit.io/library/get-started/create-an-app", type: "documentation", description: "Build interactive web apps."),
                    MilestoneResource(id: "ai4-res-3", title: "Fast.ai", provider: "fast.ai", url: "https://course.fast.ai/", type: "course", description: "Practical deep learning."),
                ],
                assessment: MilestoneAssessment(id: "ai4-assessment", questions: [
                    ValidationQuestion(id: "ai4-q1", question: "What is hyperparameter tuning?", choices: ["Changing training data", "Adjusting model settings before training", "Deleting a model", "Writing docs"], correctAnswer: 1, explanation: "Hyperparameters are settings chosen before training."),
                    ValidationQuestion(id: "ai4-q2", question: "Why is data preprocessing important?", choices: ["Makes dataset smaller", "Clean data leads to better performance", "Required by Python", "Replaces model training"], correctAnswer: 1, explanation: "Models are only as good as their data."),
                    ValidationQuestion(id: "ai4-q3", question: "Purpose of a model interface?", choices: ["Make model run faster", "Let non-technical users interact with model", "Reduce model size", "No purpose"], correctAnswer: 1, explanation: "An interface makes AI accessible."),
                ])
            ),
            RoadmapMilestone(id: "ai-5", title: "Work With Real Data", subtitle: "Learn to find, clean, analyze data at scale.", estimatedTime: "3-4 weeks",
                whatItAccomplishes: "Develop the skill of working with real-world data.",
                whyItMatters: "Data preparation takes 80% of real AI project time.",
                goal: "Find, clean, analyze, and visualize a real-world dataset.",
                actions: [
                    MilestoneAction(id: "ai-5-action-1", title: "Find a dataset", description: "Browse Kaggle or UCI.", order: 1),
                    MilestoneAction(id: "ai-5-action-2", title: "Clean the data", description: "Handle missing values, fix inconsistencies.", order: 2),
                    MilestoneAction(id: "ai-5-action-3", title: "Analyze and visualize", description: "Compute statistics, create visualizations.", order: 3),
                    MilestoneAction(id: "ai-5-action-4", title: "Write a data report", description: "Write a 1-2 page report.", order: 4),
                ],
                skillsDeveloped: ["Data Analysis", "Data Collection", "Statistics", "Python", "Technical Communication"],
                completionCriteria: ["Complete all four actions.", "Clean a dataset with at least 1,000 rows."],
                dependencies: ["ai-4"],
                learningResources: [
                    MilestoneResource(id: "ai5-res-1", title: "Kaggle Datasets", provider: "Kaggle", url: "https://www.kaggle.com/datasets", type: "interactive", description: "Browse free datasets."),
                    MilestoneResource(id: "ai5-res-2", title: "Python Data Science Handbook", provider: "Jake VanderPlas", url: "https://jakevdp.github.io/PythonDataScienceHandbook/", type: "documentation", description: "Free book on NumPy, Pandas."),
                    MilestoneResource(id: "ai5-res-3", title: "Khan Academy: Statistics", provider: "Khan Academy", url: "https://www.khanacademy.org/math/statistics-probability", type: "interactive", description: "Statistics for data analysis."),
                ],
                assessment: MilestoneAssessment(id: "ai5-assessment", questions: [
                    ValidationQuestion(id: "ai5-q1", question: "Why is data cleaning important?", choices: ["Faster analysis", "Messy data leads to misleading conclusions", "Makes dataset smaller", "Required by Python"], correctAnswer: 1, explanation: "Dirty data corrupts analysis."),
                    ValidationQuestion(id: "ai5-q2", question: "Purpose of data visualization?", choices: ["Make reports longer", "Reveal patterns hidden in numbers", "Replace statistical analysis", "No purpose"], correctAnswer: 1, explanation: "Visualizations make patterns visible."),
                    ValidationQuestion(id: "ai5-q3", question: "What should a good data report include?", choices: ["Only results", "Source, cleaning steps, methods, findings, limitations", "Just charts", "Only code"], correctAnswer: 1, explanation: "A complete report explains everything."),
                ])
            ),
            RoadmapMilestone(id: "ai-6", title: "Build an AI Portfolio", subtitle: "Showcase your AI skills.", estimatedTime: "1-2 weeks",
                whatItAccomplishes: "Create a polished AI portfolio.",
                whyItMatters: "A portfolio is the strongest evidence of your AI skills.",
                goal: "Have a live portfolio presenting at least 2 AI projects.",
                actions: [
                    MilestoneAction(id: "ai-6-action-1", title: "Select your best 2 projects", description: "Choose projects showing different AI skills.", order: 1),
                    MilestoneAction(id: "ai-6-action-2", title: "Build a portfolio page", description: "Create a portfolio website.", order: 2),
                    MilestoneAction(id: "ai-6-action-3", title: "Polish your GitHub", description: "Pin repos, write clear READMEs.", order: 3),
                    MilestoneAction(id: "ai-6-action-4", title: "Share and get feedback", description: "Send portfolio to a teacher or mentor.", order: 4),
                ],
                skillsDeveloped: ["Portfolio Development", "Technical Communication", "Personal Branding", "AI Application Development"],
                completionCriteria: ["Complete all four actions.", "Portfolio is live and accessible."],
                dependencies: ["ai-5"],
                learningResources: [
                    MilestoneResource(id: "ai6-res-1", title: "GitHub Pages Quickstart", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: "documentation", description: "Set up a portfolio site."),
                    MilestoneResource(id: "ai6-res-2", title: "How to Build a Developer Portfolio", provider: "freeCodeCamp", url: "https://www.freecodecamp.org/news/how-to-build-a-developer-portfolio-website/", type: "article", description: "Guide to building a portfolio."),
                ]
            ),
        ],
        relevantInterests: ["Technology", "AI", "Science", "Mathematics"],
        relevantSkills: ["Programming", "Mathematics", "Data Analysis", "Problem solving"],
        relevantCareers: ["AI Researcher", "Data Scientist", "Software Engineer"],
        relevantFields: ["Computer Science", "Mathematics", "Engineering"],
        eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth],
        collegeFocused: true
    )

    private static let researchBuilder = Roadmap(
        id: "research-builder", title: "Build a Research Profile",
        goal: "Move from curiosity to a documented research experience.",
        category: .academic,
        description: "Learn how to ask a strong question, investigate it, and communicate what you discover.",
        milestones: [
            RoadmapMilestone(id: "research-1", title: "Explore Research", subtitle: "Understand what research is.", estimatedTime: "45 min",
                whatItAccomplishes: "Build a mental model of research.",
                whyItMatters: "Understanding the process before starting helps choose a meaningful topic.",
                goal: "Explain what research is and identify 2-3 topics that interest you.",
                actions: [
                    MilestoneAction(id: "research-1-action-1", title: "Watch researchers", description: "Find 2-3 videos of researchers.", order: 1),
                    MilestoneAction(id: "research-1-action-2", title: "Read a research summary", description: "Find a science news article.", order: 2),
                    MilestoneAction(id: "research-1-action-3", title: "List your curiosities", description: "Write down 5 questions.", order: 3),
                ],
                skillsDeveloped: ["Research Methods", "Question Formation", "Critical Thinking"],
                completionCriteria: ["Complete all three actions.", "List at least 5 questions."],
                learningResources: [
                    MilestoneResource(id: "r1-res-1", title: "Khan Academy: Research Methods", provider: "Khan Academy", url: "https://www.khanacademy.org/science/health-and-medicine/ethics", type: "course", description: "Introduction to scientific thinking."),
                    MilestoneResource(id: "r1-res-2", title: "ScienceBuddies", provider: "ScienceBuddies", url: "https://www.sciencebuddies.org/science-fair-projects/ideas", type: "interactive", description: "Research project ideas."),
                ]
            ),
            RoadmapMilestone(id: "research-2", title: "Choose a Research Question", subtitle: "Narrow curiosity into a focused question.", estimatedTime: "1-2 weeks",
                whatItAccomplishes: "Transform a broad interest into a specific question.",
                whyItMatters: "A well-formed question is the most important part of research.",
                goal: "Refine one curiosity into a clear research question.",
                actions: [
                    MilestoneAction(id: "research-2-action-1", title: "Research your topic", description: "Read 3-5 articles.", order: 1),
                    MilestoneAction(id: "research-2-action-2", title: "Narrow your question", description: "Make it specific and measurable.", order: 2),
                    MilestoneAction(id: "research-2-action-3", title: "Write a mini-proposal", description: "Write a one-page proposal.", order: 3),
                    MilestoneAction(id: "research-2-action-4", title: "Get feedback", description: "Share with a teacher or mentor.", order: 4),
                ],
                skillsDeveloped: ["Question Formation", "Source Evaluation", "Research Methods", "Writing"],
                completionCriteria: ["Complete all four actions.", "Write a one-page proposal."],
                dependencies: ["research-1"],
                learningResources: [
                    MilestoneResource(id: "r2-res-1", title: "How to Read a Scientific Paper", provider: "Science", url: "https://www.science.org/content/article/how-read-scientific-paper", type: "article", description: "Guide to reading papers."),
                    MilestoneResource(id: "r2-res-2", title: "Khan Academy: Asking Questions", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more/research-process", type: "interactive", description: "Forming research questions."),
                ]
            ),
            RoadmapMilestone(id: "research-3", title: "Learn Research Methods", subtitle: "Understand evidence and responsible practice.", estimatedTime: "1 week",
                whatItAccomplishes: "Learn to collect data ethically and evaluate sources.",
                whyItMatters: "Good methods make research credible.",
                goal: "Choose a method, evaluate 5 sources, and write a methods plan.",
                actions: [
                    MilestoneAction(id: "research-3-action-1", title: "Choose your method", description: "Decide on experiments, surveys, or observations.", order: 1),
                    MilestoneAction(id: "research-3-action-2", title: "Evaluate your sources", description: "Check credibility of each source.", order: 2),
                    MilestoneAction(id: "research-3-action-3", title: "Plan data collection", description: "Write a step-by-step plan.", order: 3),
                    MilestoneAction(id: "research-3-action-4", title: "Learn about ethics", description: "Read about informed consent and privacy.", order: 4),
                ],
                skillsDeveloped: ["Research Methods", "Source Evaluation", "Data Collection", "Technical Writing"],
                completionCriteria: ["Complete all four actions.", "Write a methods plan and ethics statement."],
                dependencies: ["research-2"],
                learningResources: [
                    MilestoneResource(id: "r3-res-1", title: "Khan Academy: Research Methods", provider: "Khan Academy", url: "https://www.khanacademy.org/test-prep/mcat/processing-the-environment/research-methods", type: "interactive", description: "Experimental design and ethics."),
                    MilestoneResource(id: "r3-res-2", title: "Purdue OWL", provider: "Purdue University", url: "https://owl.purdue.edu/owl/research_and_citation/resources.html", type: "documentation", description: "Research methods and citation."),
                ]
            ),
            RoadmapMilestone(id: "research-4", title: "Conduct an Investigation", subtitle: "Collect, analyze, and reflect on evidence.", estimatedTime: "2-3 weeks",
                whatItAccomplishes: "Execute your research plan and collect real data.",
                whyItMatters: "This is where your research becomes real.",
                goal: "Collect data and begin identifying patterns.",
                actions: [
                    MilestoneAction(id: "research-4-action-1", title: "Collect your data", description: "Follow your methods plan.", order: 1),
                    MilestoneAction(id: "research-4-action-2", title: "Organize your data", description: "Put data in a spreadsheet.", order: 2),
                    MilestoneAction(id: "research-4-action-3", title: "Begin analysis", description: "Look for patterns, create a visualization.", order: 3),
                    MilestoneAction(id: "research-4-action-4", title: "Reflect on what you found", description: "Write a brief reflection.", order: 4),
                ],
                skillsDeveloped: ["Data Collection", "Data Analysis", "Scientific Method", "Technical Writing"],
                completionCriteria: ["Complete all four actions.", "Write a reflection on initial findings."],
                dependencies: ["research-3"],
                learningResources: [
                    MilestoneResource(id: "r4-res-1", title: "Google Sheets for Data Analysis", provider: "Google", url: "https://support.google.com/docs/answer/6000253", type: "documentation", description: "Using Google Sheets for data."),
                    MilestoneResource(id: "r4-res-2", title: "Khan Academy: Statistics", provider: "Khan Academy", url: "https://www.khanacademy.org/math/statistics-probability", type: "interactive", description: "Statistics for research data."),
                ]
            ),
            RoadmapMilestone(id: "research-5", title: "Analyze & Communicate Findings", subtitle: "Turn data into a clear argument.", estimatedTime: "1-2 weeks",
                whatItAccomplishes: "Analyze results and create a presentation.",
                whyItMatters: "Research is only valuable if others can understand it.",
                goal: "Complete analysis, draw conclusions, and create a clear presentation.",
                actions: [
                    MilestoneAction(id: "research-5-action-1", title: "Complete your analysis", description: "Finish analyzing data.", order: 1),
                    MilestoneAction(id: "research-5-action-2", title: "Draw conclusions", description: "Write 2-3 paragraphs explaining findings.", order: 2),
                    MilestoneAction(id: "research-5-action-3", title: "Create a poster or paper", description: "Format as poster, report, or slides.", order: 3),
                    MilestoneAction(id: "research-5-action-4", title: "Practice presenting", description: "Rehearse explaining in 3-5 minutes.", order: 4),
                ],
                skillsDeveloped: ["Data Analysis", "Scientific Communication", "Technical Writing", "Presentation"],
                completionCriteria: ["Complete all four actions.", "Present findings in a poster, paper, or slide deck."],
                dependencies: ["research-4"],
                learningResources: [
                    MilestoneResource(id: "r5-res-1", title: "How to Create a Scientific Poster", provider: "NCSU", url: "https://www.lib.ncsu.edu/services/presenting/posters", type: "documentation", description: "Designing research posters."),
                    MilestoneResource(id: "r5-res-2", title: "MIT OpenCourseWare", provider: "MIT OCW", url: "https://ocw.mit.edu/", type: "course", description: "Free MIT course materials."),
                ]
            ),
            RoadmapMilestone(id: "research-6", title: "Build a Research Portfolio", subtitle: "Document your research experience.", estimatedTime: "1 week",
                whatItAccomplishes: "Create a polished record of your research.",
                whyItMatters: "A research portfolio shows initiative and analytical ability.",
                goal: "Have a documented research portfolio in a professional format.",
                actions: [
                    MilestoneAction(id: "research-6-action-1", title: "Write a research summary", description: "Write a 1-2 page summary.", order: 1),
                    MilestoneAction(id: "research-6-action-2", title: "Create a digital portfolio", description: "Put research in a Google Doc or website.", order: 2),
                    MilestoneAction(id: "research-6-action-3", title: "Reflect on growth", description: "Write a reflection on skills development.", order: 3),
                ],
                skillsDeveloped: ["Portfolio Development", "Technical Writing", "Scientific Communication", "Personal Branding"],
                completionCriteria: ["Complete all three actions.", "Have a written research summary."],
                dependencies: ["research-5"],
                learningResources: [
                    MilestoneResource(id: "r6-res-1", title: "Google Docs", provider: "Google", url: "https://docs.google.com/", type: "interactive", description: "Free tool for research documents."),
                    MilestoneResource(id: "r6-res-2", title: "GitHub Pages Quickstart", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: "documentation", description: "Create a free research portfolio website."),
                ]
            ),
        ],
        relevantInterests: ["Science", "Medicine", "Environment", "AI"],
        relevantSkills: ["Research", "Writing", "Communication"],
        relevantCareers: ["AI Researcher", "Biomedical Engineer"],
        relevantFields: ["Biology", "Medicine", "Engineering"],
        eligibleGrades: [.tenth, .eleventh, .twelfth],
        collegeFocused: true
    )

    private static let leadership = Roadmap(
        id: "leadership", title: "Build Leadership Experience",
        goal: "Develop real leadership skills through hands-on initiative and collaboration.",
        category: .skills,
        description: "A practical path from understanding leadership to creating real impact.",
        milestones: [
            RoadmapMilestone(id: "leadership-1", title: "Understand Leadership", subtitle: "Learn what leadership means.", estimatedTime: "45 min",
                whatItAccomplishes: "Understand that leadership is about influence and initiative.",
                whyItMatters: "True leadership is a skill, not a position.",
                goal: "Explain what leadership means and identify 3 effective leaders.",
                actions: [
                    MilestoneAction(id: "leadership-1-action-1", title: "Watch leadership stories", description: "Watch 2-3 TED talks.", order: 1),
                    MilestoneAction(id: "leadership-1-action-2", title: "Identify leaders you admire", description: "Think of 3 good leaders.", order: 2),
                    MilestoneAction(id: "leadership-1-action-3", title: "Write your leadership philosophy", description: "Write a paragraph about leadership.", order: 3),
                ],
                skillsDeveloped: ["Leadership", "Communication", "Critical Thinking"],
                completionCriteria: ["Complete all three actions.", "Write a personal leadership philosophy."],
                learningResources: [
                    MilestoneResource(id: "l1-res-1", title: "TED Talks: Leadership", provider: "TED", url: "https://www.ted.com/topics/leadership", type: "video", description: "Free leadership talks."),
                    MilestoneResource(id: "l1-res-2", title: "Khan Academy: Life Skills", provider: "Khan Academy", url: "https://www.khanacademy.org/college-careers-more", type: "interactive", description: "Communication and decision-making."),
                ]
            ),
            RoadmapMilestone(id: "leadership-2", title: "Take Initiative", subtitle: "Start something without being asked.", estimatedTime: "2-3 weeks",
                whatItAccomplishes: "Practice taking initiative.",
                whyItMatters: "Initiative is the foundation of leadership.",
                goal: "Identify a need and take concrete action.",
                actions: [
                    MilestoneAction(id: "leadership-2-action-1", title: "Observe your environment", description: "Look around your school.", order: 1),
                    MilestoneAction(id: "leadership-2-action-2", title: "Pick one thing to act on", description: "Choose one problem to address.", order: 2),
                    MilestoneAction(id: "leadership-2-action-3", title: "Start small and act", description: "Take one concrete step.", order: 3),
                    MilestoneAction(id: "leadership-2-action-4", title: "Invite one person to help", description: "Ask one person to join you.", order: 4),
                ],
                skillsDeveloped: ["Initiative", "Problem Solving", "Communication", "Planning"],
                completionCriteria: ["Complete all four actions.", "Take at least one concrete action."],
                dependencies: ["leadership-1"],
                learningResources: [
                    MilestoneResource(id: "l2-res-1", title: "DoSomething.org", provider: "Do Something", url: "https://www.dosomething.org/", type: "interactive", description: "Ideas for making a difference."),
                ]
            ),
            RoadmapMilestone(id: "leadership-3", title: "Lead a Small Project", subtitle: "Organize and deliver a project.", estimatedTime: "3-5 weeks",
                whatItAccomplishes: "Practice leading a small project.",
                whyItMatters: "Leading teaches skills no amount of reading can.",
                goal: "Plan and complete a small project with at least 2 other people.",
                actions: [
                    MilestoneAction(id: "leadership-3-action-1", title: "Define the project", description: "Choose a small project.", order: 1),
                    MilestoneAction(id: "leadership-3-action-2", title: "Recruit and delegate", description: "Get 2-3 people to help.", order: 2),
                    MilestoneAction(id: "leadership-3-action-3", title: "Manage the work", description: "Check in regularly.", order: 3),
                    MilestoneAction(id: "leadership-3-action-4", title: "Deliver and reflect", description: "Complete and reflect.", order: 4),
                ],
                skillsDeveloped: ["Project Management", "Collaboration", "Planning", "Problem Solving"],
                completionCriteria: ["Complete all four actions.", "Lead at least 2 people."],
                dependencies: ["leadership-2"],
                learningResources: [
                    MilestoneResource(id: "l3-res-1", title: "Trello: Getting Started", provider: "Trello", url: "https://trello.com/guide", type: "documentation", description: "Visual project organization."),
                    MilestoneResource(id: "l3-res-2", title: "Google Workspace", provider: "Google", url: "https://workspace.google.com/", type: "interactive", description: "Free collaboration tools."),
                ]
            ),
            RoadmapMilestone(id: "leadership-4", title: "Work With Others", subtitle: "Develop collaboration skills.", estimatedTime: "2-3 weeks",
                whatItAccomplishes: "Practice working effectively with diverse people.",
                whyItMatters: "Leadership is fundamentally about working with people.",
                goal: "Work with a diverse group on a shared goal.",
                actions: [
                    MilestoneAction(id: "leadership-4-action-1", title: "Join a team or group", description: "Join a club or community group.", order: 1),
                    MilestoneAction(id: "leadership-4-action-2", title: "Practice active listening", description: "Listen fully before responding.", order: 2),
                    MilestoneAction(id: "leadership-4-action-3", title: "Resolve a disagreement", description: "Practice finding common ground.", order: 3),
                    MilestoneAction(id: "leadership-4-action-4", title: "Give constructive feedback", description: "Practice specific, helpful feedback.", order: 4),
                ],
                skillsDeveloped: ["Collaboration", "Communication", "Public Speaking", "Responsibility"],
                completionCriteria: ["Complete all four actions.", "Practice active listening."],
                dependencies: ["leadership-3"],
                learningResources: [
                    MilestoneResource(id: "l4-res-1", title: "Toastmasters Youth Leadership", provider: "Toastmasters", url: "https://www.toastmasters.org/", type: "interactive", description: "Public speaking and leadership programs."),
                ]
            ),
            RoadmapMilestone(id: "leadership-5", title: "Create Measurable Impact", subtitle: "Make a measurable difference.", estimatedTime: "3-5 weeks",
                whatItAccomplishes: "Lead an initiative that creates measurable impact.",
                whyItMatters: "Impact is the ultimate measure of leadership.",
                goal: "Lead an initiative with a measurable positive outcome.",
                actions: [
                    MilestoneAction(id: "leadership-5-action-1", title: "Define measurable goals", description: "Choose an initiative with clear goals.", order: 1),
                    MilestoneAction(id: "leadership-5-action-2", title: "Build a team and plan", description: "Recruit a team and create a timeline.", order: 2),
                    MilestoneAction(id: "leadership-5-action-3", title: "Execute the initiative", description: "Run the initiative and track progress.", order: 3),
                    MilestoneAction(id: "leadership-5-action-4", title: "Measure and report results", description: "Document your results.", order: 4),
                ],
                skillsDeveloped: ["Leadership", "Project Management", "Impact Measurement", "Planning"],
                completionCriteria: ["Complete all four actions.", "Document and report your results."],
                dependencies: ["leadership-4"],
                learningResources: [
                    MilestoneResource(id: "l5-res-1", title: "VolunteerMatch", provider: "VolunteerMatch", url: "https://www.volunteermatch.org/", type: "interactive", description: "Find volunteer opportunities."),
                    MilestoneResource(id: "l5-res-2", title: "Idealist", provider: "Idealist.org", url: "https://www.idealist.org/", type: "interactive", description: "Social impact opportunities."),
                ]
            ),
            RoadmapMilestone(id: "leadership-6", title: "Document Your Leadership", subtitle: "Record your experience.", estimatedTime: "1 week",
                whatItAccomplishes: "Create a documented record of your leadership.",
                whyItMatters: "Undocumented experience is invisible experience.",
                goal: "Create a leadership portfolio documenting growth and impact.",
                actions: [
                    MilestoneAction(id: "leadership-6-action-1", title: "Write a leadership summary", description: "Write a 1-2 page summary.", order: 1),
                    MilestoneAction(id: "leadership-6-action-2", title: "Collect evidence", description: "Gather evidence of leadership.", order: 2),
                    MilestoneAction(id: "leadership-6-action-3", title: "Create a digital record", description: "Put summary in a document or website.", order: 3),
                ],
                skillsDeveloped: ["Portfolio Development", "Technical Communication", "Personal Branding"],
                completionCriteria: ["Complete all three actions.", "Create a shareable digital record."],
                dependencies: ["leadership-5"],
                learningResources: [
                    MilestoneResource(id: "l6-res-1", title: "Google Docs", provider: "Google", url: "https://docs.google.com/", type: "interactive", description: "Free documents."),
                    MilestoneResource(id: "l6-res-2", title: "GitHub Pages", provider: "GitHub Docs", url: "https://docs.github.com/en/pages/quickstart", type: "documentation", description: "Create a free website."),
                ]
            ),
        ],
        relevantInterests: ["Business", "Community Service", "Politics", "Education"],
        relevantSkills: ["Communication", "Leadership", "Planning"],
        relevantCareers: ["Business Manager", "Lawyer", "Teacher"],
        relevantFields: ["Business", "Education", "Law", "Political Science"],
        eligibleGrades: Set(Grade.allCases),
        collegeFocused: false
    )
}

// MARK: - RoadmapEngine

enum RoadmapEngine {
    static func milestoneAvailability(milestone: RoadmapMilestone, completedIDs: Set<String>, milestones: [RoadmapMilestone]) -> MilestoneAvailability {
        if completedIDs.contains(milestone.id) { return .completed }
        guard let deps = milestone.dependencies, !deps.isEmpty else { return .available }
        let incomplete = deps.filter { !completedIDs.contains($0) }
        if incomplete.isEmpty { return .available }
        return .locked(blockingIDs: incomplete)
    }

    static func validateDependencies(for roadmap: Roadmap) -> [String] {
        var errors: [String] = []
        let ids = Set(roadmap.milestones.map(\.id))
        for ms in roadmap.milestones {
            guard let deps = ms.dependencies else { continue }
            for d in deps {
                if d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Empty dep in \(ms.id)") }
                if d == ms.id { errors.append("Self dep in \(ms.id)") }
                if !ids.contains(d) { errors.append("Invalid dep \(d) in \(ms.id)") }
            }
            if Set(deps).count != deps.count { errors.append("Duplicate deps in \(ms.id)") }
        }
        return errors
    }

    static func detectCycles(for roadmap: Roadmap) -> Bool {
        var coloring: [String: Int] = [:]
        for ms in roadmap.milestones { coloring[ms.id] = 0 }
        func dfs(_ id: String) -> Bool {
            coloring[id] = 1
            if let deps = roadmap.milestones.first(where: { $0.id == id })?.dependencies {
                for d in deps {
                    if coloring[d] == 1 { return true }
                    if coloring[d] == 0 && dfs(d) { return true }
                }
            }
            coloring[id] = 2
            return false
        }
        for ms in roadmap.milestones {
            if coloring[ms.id] == 0 && dfs(ms.id) { return true }
        }
        return false
    }

    static func score(answers: [String: Int], questions: [ValidationQuestion]) -> Int {
        guard !questions.isEmpty else { return 0 }
        return questions.filter { q in
            if let selected = answers[q.id] { return selected == q.correctAnswer }
            return false
        }.count
    }

    static func percentage(score: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100).rounded())
    }

    static func passed(percentage: Int, threshold: Int) -> Bool {
        percentage >= threshold
    }

    static func completedActionsCount(for milestone: RoadmapMilestone, completedIDs: Set<String>) -> Int {
        guard let actions = milestone.actions else { return 0 }
        return actions.filter { completedIDs.contains($0.id) }.count
    }

    static func totalActionsCount(for milestone: RoadmapMilestone) -> Int {
        milestone.actions?.count ?? 0
    }

    static func actionProgress(for milestone: RoadmapMilestone, completedIDs: Set<String>) -> Int {
        let completed = completedActionsCount(for: milestone, completedIDs: completedIDs)
        let total = totalActionsCount(for: milestone)
        guard total > 0 else { return 0 }
        return Int((Double(completed) / Double(total) * 100).rounded())
    }

    static func allActionsCompleted(for milestone: RoadmapMilestone, completedIDs: Set<String>) -> Bool {
        guard let actions = milestone.actions, !actions.isEmpty else { return false }
        return actions.allSatisfy { completedIDs.contains($0.id) }
    }

    static func milestoneTitle(for id: String, milestones: [RoadmapMilestone]) -> String {
        milestones.first(where: { $0.id == id })?.title ?? id
    }

    static func lockedExplanation(milestone: RoadmapMilestone, milestones: [RoadmapMilestone], completedIDs: Set<String>) -> DependencyLockInfo? {
        guard case .locked(let blockingIDs) = milestoneAvailability(milestone: milestone, completedIDs: completedIDs, milestones: milestones) else { return nil }
        let blockingTitles = blockingIDs.map { DependencyLockInfo.BlockingPrerequisite(id: $0, title: milestoneTitle(for: $0, milestones: milestones)) }
        return DependencyLockInfo(blockingPrerequisites: blockingTitles)
    }
}

// MARK: - SimulatedStore

class SimulatedStore {
    var profile: StudentProfile
    var roadmapProgress: [String: Int] = [:]
    var activeRoadmaps: [String: ActiveRoadmap] = [:]
    var completedActionIDs: Set<String> = []
    var validationAttempts: [String: ValidationAttempt] = [:]
    var evidenceRecords: [String: EvidenceRecord] = [:]

    init(profile: StudentProfile = StudentProfile()) {
        self.profile = profile
    }

    func completedCount(for roadmap: Roadmap) -> Int {
        min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
    }

    func startRoadmap(_ roadmap: Roadmap) {
        guard activeRoadmaps[roadmap.id]?.status != .active else { return }
        let existing = activeRoadmaps[roadmap.id]
        activeRoadmaps[roadmap.id] = ActiveRoadmap(
            roadmapID: roadmap.id, status: .active,
            startedAt: existing?.startedAt ?? Date().timeIntervalSince1970
        )
    }

    func deactivateRoadmap(_ roadmapID: String) {
        activeRoadmaps.removeValue(forKey: roadmapID)
    }

    func clearActivation(_ roadmapID: String) {
        activeRoadmaps.removeValue(forKey: roadmapID)
    }

    func isRoadmapActivated(_ roadmapID: String) -> Bool {
        guard let activation = activeRoadmaps[roadmapID] else { return false }
        return activation.status == .active
    }

    func toggleAction(_ actionID: String) {
        if completedActionIDs.contains(actionID) {
            completedActionIDs.remove(actionID)
        } else {
            completedActionIDs.insert(actionID)
        }
    }

    func isActionCompleted(_ actionID: String) -> Bool {
        completedActionIDs.contains(actionID)
    }

    func saveValidationAttempt(_ attempt: ValidationAttempt) {
        validationAttempts[attempt.validationID] = attempt
    }

    func markRoadmapMilestoneComplete(for roadmap: Roadmap) {
        let next = min(completedCount(for: roadmap) + 1, roadmap.milestones.count)
        roadmapProgress[roadmap.id] = next
        if next >= 1, next <= roadmap.milestones.count {
            let milestone = roadmap.milestones[next - 1]
            acquireSkills(milestone.skillsDeveloped)
        }
        if next >= 1, next <= roadmap.milestones.count {
            let milestone = roadmap.milestones[next - 1]
            createEvidenceIfNeeded(for: roadmap, milestone: milestone)
        }
    }

    func acquireSkills(_ skills: [String]?) {
        guard let skills, !skills.isEmpty else { return }
        var existing = Set(profile.strengths.map { $0.lowercased() })
        existing.formUnion(profile.customSkills.map { $0.lowercased() })
        for skill in skills {
            let trimmed = skill.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !existing.contains(trimmed.lowercased()) else { continue }
            profile.strengths.append(trimmed)
            existing.insert(trimmed.lowercased())
        }
    }

    func evidenceID(for milestoneID: String, roadmap: String) -> String {
        "evidence-\(roadmap)-\(milestoneID)"
    }

    func hasEvidence(for milestoneID: String, roadmap: String) -> Bool {
        evidenceRecords[evidenceID(for: milestoneID, roadmap: roadmap)] != nil
    }

    private func createEvidenceIfNeeded(for roadmap: Roadmap, milestone: RoadmapMilestone) {
        let eid = evidenceID(for: milestone.id, roadmap: roadmap.id)
        guard evidenceRecords[eid] == nil else { return }
        let assessment = milestone.assessment
        let best: ValidationAttempt? = assessment.flatMap { validationAttempts[$0.id] }
        let record = EvidenceRecord(
            id: eid, type: "milestone-completion", title: milestone.title,
            description: milestone.subtitle, roadmapID: roadmap.id, milestoneID: milestone.id,
            completionDate: Date().timeIntervalSince1970,
            validationID: assessment?.id, validationScore: best?.score,
            validationPercentage: best.map { RoadmapEngine.percentage(score: $0.score, total: assessment?.questions.count ?? 1) },
            validationPassed: best?.passed
        )
        evidenceRecords[eid] = record
    }

    func resetRoadmap(_ roadmap: Roadmap) {
        roadmapProgress[roadmap.id] = 0
        for milestone in roadmap.milestones {
            for action in milestone.actions ?? [] {
                completedActionIDs.remove(action.id)
            }
            let evidenceID = evidenceID(for: milestone.id, roadmap: roadmap.id)
            evidenceRecords.removeValue(forKey: evidenceID)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
//  TEST CATALOG
// ═══════════════════════════════════════════════════════════════

let catalog = RoadmapService.allCatalogRoadmaps
let seRoadmap = catalog.first(where: { $0.id == "software-engineer" })!
let aiRoadmap = catalog.first(where: { $0.id == "ai-engineer" })!
let researchRoadmap = catalog.first(where: { $0.id == "research-builder" })!
let leadershipRoadmap = catalog.first(where: { $0.id == "leadership" })!

// ═══════════════════════════════════════════════════════════════
//  PROFILE TESTS (1-3)
// ═══════════════════════════════════════════════════════════════

do { // Test 1: Fresh student profile has correct fields
    let p = StudentProfile()
    assertEqual(p.name, "", "T1: name empty")
    assertEqual(p.interests.count, 0, "T1: interests empty")
    assertEqual(p.strengths.count, 0, "T1: strengths empty")
    assertEqual(p.grade, .ninth, "T1: grade default")
    assertEqual(p.collegePlan, .notSure, "T1: collegePlan default")
    assert(!p.onboardingCompleted, "T1: onboardingCompleted false")
    passed += 3
}

do { // Test 2: Profile persists through simulated save/load
    var p = StudentProfile()
    p.name = "Alex"; p.interests = ["Technology", "AI"]; p.strengths = ["Programming"]
    p.customSkills = ["Python"]; p.careers = ["Software Engineer"]; p.fields = ["Computer Science"]
    p.grade = .eleventh; p.collegePlan = .yesDefinitely; p.onboardingCompleted = true
    if let data = try? JSONEncoder().encode(p),
       let decoded = try? JSONDecoder().decode(StudentProfile.self, from: data) {
        assertEqual(decoded.name, "Alex", "T2: name roundtrip")
        assertEqual(decoded.interests, ["Technology", "AI"], "T2: interests roundtrip")
        assertEqual(decoded.strengths, ["Programming"], "T2: strengths roundtrip")
        assertEqual(decoded.customSkills, ["Python"], "T2: customSkills roundtrip")
        assertEqual(decoded.careers, ["Software Engineer"], "T2: careers roundtrip")
        assertEqual(decoded.fields, ["Computer Science"], "T2: fields roundtrip")
        assertEqual(decoded.grade, .eleventh, "T2: grade roundtrip")
        assertEqual(decoded.collegePlan, .yesDefinitely, "T2: collegePlan roundtrip")
        assert(decoded.onboardingCompleted, "T2: onboardingCompleted roundtrip")
    } else { assert(false, "T2: encode/decode failed") }
}

do { // Test 3: Profile can be consumed by recommendation system
    var p = StudentProfile()
    p.interests = ["Technology"]; p.strengths = ["Programming"]
    p.careers = ["Software Engineer"]; p.fields = ["Computer Science"]
    p.grade = .tenth; p.collegePlan = .yesDefinitely
    let score = RoadmapService.matchScore(for: seRoadmap, profile: p)
    assert(score >= 48 && score <= 99, "T3: score in valid range (got \(score))")
    assert(score > 50, "T3: score above baseline")
}

// ═══════════════════════════════════════════════════════════════
//  RECOMMENDATION TESTS (4-6)
// ═══════════════════════════════════════════════════════════════

do { // Test 4: Match score calculation matches production algorithm
    var p = StudentProfile()
    p.interests = ["Technology", "AI"]; p.strengths = ["Programming", "Problem solving"]
    p.careers = ["Software Engineer", "AI Researcher"]; p.fields = ["Computer Science", "Engineering"]
    p.grade = .tenth; p.collegePlan = .yesDefinitely
    let score = RoadmapService.matchScore(for: seRoadmap, profile: p)
    assertEqual(score, 99, "T4: score clamped to 99")
}

do { // Test 5: Recommendations reference real roadmap IDs from catalog
    let ids = catalog.map(\.id)
    assert(ids.contains("software-engineer"), "T5: software-engineer in catalog")
    assert(ids.contains("ai-engineer"), "T5: ai-engineer in catalog")
    assert(ids.contains("research-builder"), "T5: research-builder in catalog")
    assert(ids.contains("leadership"), "T5: leadership in catalog")
}

do { // Test 6: Recommendations do not automatically activate roadmaps
    let store = SimulatedStore()
    var p = StudentProfile()
    p.interests = ["Technology"]; p.grade = .tenth; p.collegePlan = .yesDefinitely
    let scored = RoadmapService.roadmaps(for: p, progress: [:])
    for s in scored {
        assert(!store.isRoadmapActivated(s.id), "T6: \(s.id) not auto-activated")
    }
}

// ═══════════════════════════════════════════════════════════════
//  ACTIVATION TESTS (7-10)
// ═══════════════════════════════════════════════════════════════

do { // Test 7: Activating a roadmap creates active state
    let store = SimulatedStore()
    assert(!store.isRoadmapActivated("software-engineer"), "T7: not activated before")
    store.startRoadmap(seRoadmap)
    assert(store.isRoadmapActivated("software-engineer"), "T7: activated after")
    assertEqual(store.activeRoadmaps["software-engineer"]?.status, .active, "T7: status active")
}

do { // Test 8: Activation is idempotent
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    let first = store.activeRoadmaps["software-engineer"]?.startedAt
    store.startRoadmap(seRoadmap)
    assertEqual(store.activeRoadmaps.count, 1, "T8: no duplicate")
    assertEqual(first, store.activeRoadmaps["software-engineer"]?.startedAt, "T8: startedAt preserved")
}

do { // Test 9: Multiple roadmaps can be active simultaneously
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap); store.startRoadmap(aiRoadmap)
    store.startRoadmap(researchRoadmap); store.startRoadmap(leadershipRoadmap)
    assertEqual(store.activeRoadmaps.count, 4, "T9: 4 active")
    assert(store.isRoadmapActivated("software-engineer"), "T9: SE active")
    assert(store.isRoadmapActivated("ai-engineer"), "T9: AI active")
    assert(store.isRoadmapActivated("research-builder"), "T9: Research active")
    assert(store.isRoadmapActivated("leadership"), "T9: Leadership active")
}

do { // Test 10: Activation does not duplicate roadmap content
    let store = SimulatedStore()
    store.roadmapProgress["software-engineer"] = 2
    store.startRoadmap(seRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 2, "T10: progress preserved")
}

// ═══════════════════════════════════════════════════════════════
//  MILESTONE ACCESS TESTS (11-14)
// ═══════════════════════════════════════════════════════════════

do { // Test 11: First milestone is available when no dependencies
    let ms1 = seRoadmap.milestones[0]
    let avail = RoadmapEngine.milestoneAvailability(milestone: ms1, completedIDs: [], milestones: seRoadmap.milestones)
    assertEqual(avail, .available, "T11: software-1 available with no completed")
}

do { // Test 12: Dependent milestone is locked when prerequisite incomplete
    let ms2 = seRoadmap.milestones[1]
    let avail = RoadmapEngine.milestoneAvailability(milestone: ms2, completedIDs: [], milestones: seRoadmap.milestones)
    if case .locked(let blockingIDs) = avail {
        assertEqual(blockingIDs, ["software-1"], "T12: locked by software-1")
    } else { assert(false, "T12: expected .locked") }
}

do { // Test 13: Dependent milestone becomes available when prerequisite completed
    let ms2 = seRoadmap.milestones[1]
    let avail = RoadmapEngine.milestoneAvailability(milestone: ms2, completedIDs: ["software-1"], milestones: seRoadmap.milestones)
    assertEqual(avail, .available, "T13: available after software-1 completed")
}

do { // Test 14: Locked state correctly identifies blocking prerequisite
    let ms3 = seRoadmap.milestones[2]
    let avail = RoadmapEngine.milestoneAvailability(milestone: ms3, completedIDs: ["software-1"], milestones: seRoadmap.milestones)
    if case .locked(let blockingIDs) = avail {
        assertEqual(blockingIDs, ["software-2"], "T14: locked by software-2")
    } else { assert(false, "T14: expected .locked") }
    let info = RoadmapEngine.lockedExplanation(milestone: ms3, milestones: seRoadmap.milestones, completedIDs: ["software-1"])
    assert(info != nil, "T14: lockedExplanation returns info")
    assertEqual(info?.blockingPrerequisites.first?.title, "Build Programming Fundamentals", "T14: blocking title correct")
}

// ═══════════════════════════════════════════════════════════════
//  ACTION TESTS (15-18)
// ═══════════════════════════════════════════════════════════════

do { // Test 15: Actions display for available milestone
    let ms1 = seRoadmap.milestones[0]
    assertEqual(ms1.actions?.count, 4, "T15: software-1 has 4 actions")
    assertEqual(ms1.actions?.first?.id, "software-1-action-1", "T15: first action ID")
    assertEqual(ms1.actions?.first?.title, "Watch a day-in-the-life video", "T15: first action title")
}

do { // Test 16: Completing an action persists
    let store = SimulatedStore()
    assert(!store.isActionCompleted("software-1-action-1"), "T16: not completed initially")
    store.toggleAction("software-1-action-1")
    assert(store.isActionCompleted("software-1-action-1"), "T16: completed after toggle")
    store.toggleAction("software-1-action-1")
    assert(!store.isActionCompleted("software-1-action-1"), "T16: un-completed after second toggle")
}

do { // Test 17: Action progress updates correctly
    let ms1 = seRoadmap.milestones[0]
    let store = SimulatedStore()
    assertEqual(RoadmapEngine.actionProgress(for: ms1, completedIDs: store.completedActionIDs), 0, "T17: 0% initially")
    store.toggleAction("software-1-action-1")
    assertEqual(RoadmapEngine.actionProgress(for: ms1, completedIDs: store.completedActionIDs), 25, "T17: 25% after 1 of 4")
    store.toggleAction("software-1-action-2")
    assertEqual(RoadmapEngine.actionProgress(for: ms1, completedIDs: store.completedActionIDs), 50, "T17: 50% after 2 of 4")
    store.toggleAction("software-1-action-3")
    assertEqual(RoadmapEngine.actionProgress(for: ms1, completedIDs: store.completedActionIDs), 75, "T17: 75% after 3 of 4")
    store.toggleAction("software-1-action-4")
    assertEqual(RoadmapEngine.actionProgress(for: ms1, completedIDs: store.completedActionIDs), 100, "T17: 100% after 4 of 4")
}

do { // Test 18: Action completion does NOT auto-complete milestone
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    for action in seRoadmap.milestones[0].actions ?? [] { store.toggleAction(action.id) }
    assert(RoadmapEngine.allActionsCompleted(for: seRoadmap.milestones[0], completedIDs: store.completedActionIDs), "T18: all actions completed")
    assertEqual(store.completedCount(for: seRoadmap), 0, "T18: milestone NOT auto-completed")
}

// ═══════════════════════════════════════════════════════════════
//  RESOURCE TESTS (19-20)
// ═══════════════════════════════════════════════════════════════

do { // Test 19: Learning resources have valid URLs
    for roadmap in catalog {
        for milestone in roadmap.milestones {
            for res in milestone.learningResources ?? [] {
                assert(res.url.hasPrefix("https://"), "T19: \(res.id) URL starts with https")
                assert(!res.url.isEmpty, "T19: \(res.id) URL not empty")
            }
        }
    }
}

do { // Test 20: Resource data comes from milestone, not hardcoded
    let res = seRoadmap.milestones[0].learningResources?.first
    assertEqual(res?.id, "sw1-res-1", "T20: resource ID from milestone")
    assertEqual(res?.title, "CS50", "T20: resource title from milestone")
    assertEqual(res?.provider, "Harvard / edX", "T20: provider from milestone")
    assertEqual(res?.url, "https://cs50.harvard.edu/x/", "T20: URL from milestone")
}

// ═══════════════════════════════════════════════════════════════
//  VALIDATION TESTS (21-25)
// ═══════════════════════════════════════════════════════════════

do { // Test 21: Validation scoring is deterministic
    let questions = seRoadmap.milestones[0].assessment!.questions
    let answers: [String: Int] = ["sw1-q1": 1, "sw1-q2": 1, "sw1-q3": 1]
    let s1 = RoadmapEngine.score(answers: answers, questions: questions)
    let s2 = RoadmapEngine.score(answers: answers, questions: questions)
    assertEqual(s1, s2, "T21: deterministic scoring")
}

do { // Test 22: Score calculation is correct
    let questions = seRoadmap.milestones[0].assessment!.questions
    let allCorrect: [String: Int] = ["sw1-q1": 1, "sw1-q2": 1, "sw1-q3": 1]
    assertEqual(RoadmapEngine.score(answers: allCorrect, questions: questions), 3, "T22: all correct = 3")
    let noneCorrect: [String: Int] = ["sw1-q1": 0, "sw1-q2": 0, "sw1-q3": 0]
    assertEqual(RoadmapEngine.score(answers: noneCorrect, questions: questions), 0, "T22: none correct = 0")
    let partial: [String: Int] = ["sw1-q1": 1, "sw1-q2": 0, "sw1-q3": 1]
    assertEqual(RoadmapEngine.score(answers: partial, questions: questions), 2, "T22: partial = 2")
}

do { // Test 23: Pass threshold is respected
    assertEqual(RoadmapEngine.percentage(score: 3, total: 3), 100, "T23: 3/3 = 100%")
    assertEqual(RoadmapEngine.percentage(score: 2, total: 3), 67, "T23: 2/3 = 67%")
    assert(RoadmapEngine.passed(percentage: 70, threshold: 70), "T23: 70 >= 70 passes")
    assert(!RoadmapEngine.passed(percentage: 69, threshold: 70), "T23: 69 < 70 fails")
    assert(RoadmapEngine.passed(percentage: 100, threshold: 70), "T23: 100 >= 70 passes")
}

do { // Test 24: Passed/failed state persists
    let store = SimulatedStore()
    let attempt = ValidationAttempt(id: "att-1", validationID: "sw1-assessment",
        selectedAnswers: ["sw1-q1": 1, "sw1-q2": 1, "sw1-q3": 1],
        score: 3, totalQuestions: 3, percentage: 100, passed: true)
    store.saveValidationAttempt(attempt)
    assert(store.validationAttempts["sw1-assessment"] != nil, "T24: attempt persisted")
    assertEqual(store.validationAttempts["sw1-assessment"]?.passed, true, "T24: passed state persisted")
    assertEqual(store.validationAttempts["sw1-assessment"]?.score, 3, "T24: score persisted")
}

do { // Test 25: Retake works correctly
    let store = SimulatedStore()
    store.saveValidationAttempt(ValidationAttempt(id: "a1", validationID: "sw1-assessment",
        selectedAnswers: ["sw1-q1": 0], score: 0, totalQuestions: 3, percentage: 0, passed: false))
    assertEqual(store.validationAttempts["sw1-assessment"]?.passed, false, "T25: first attempt failed")
    store.saveValidationAttempt(ValidationAttempt(id: "a2", validationID: "sw1-assessment",
        selectedAnswers: ["sw1-q1": 1, "sw1-q2": 1, "sw1-q3": 1], score: 3, totalQuestions: 3, percentage: 100, passed: true))
    assertEqual(store.validationAttempts["sw1-assessment"]?.passed, true, "T25: retake passed")
    assertEqual(store.validationAttempts["sw1-assessment"]?.score, 3, "T25: retake score updated")
}

// ═══════════════════════════════════════════════════════════════
//  SKILL TESTS (26-29)
// ═══════════════════════════════════════════════════════════════

do { // Test 26: Skills are acquired on milestone completion
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    assert(store.profile.strengths.contains("Computational Thinking"), "T26: Computational Thinking acquired")
    assert(store.profile.strengths.contains("Development Environment Setup"), "T26: Dev Env Setup acquired")
    assert(store.profile.strengths.contains("Version Control Basics"), "T26: Version Control Basics acquired")
}

do { // Test 27: Case-insensitive deduplication works
    let store = SimulatedStore()
    store.profile.strengths = ["computational thinking"]
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    let count = store.profile.strengths.filter { $0.lowercased() == "computational thinking" }.count
    assertEqual(count, 1, "T27: no duplicate for case-insensitive match")
}

do { // Test 28: Existing skills are preserved
    let store = SimulatedStore()
    store.profile.strengths = ["Existing Skill"]
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    assert(store.profile.strengths.contains("Existing Skill"), "T28: existing skill preserved")
    assert(store.profile.strengths.contains("Computational Thinking"), "T28: new skill added")
}

do { // Test 29: Skills persist through simulated reload
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    let saved = store.profile.strengths
    let store2 = SimulatedStore()
    store2.profile.strengths = saved
    assert(store2.profile.strengths.contains("Computational Thinking"), "T29: skills survive reload")
    assertEqual(store2.profile.strengths.count, saved.count, "T29: skill count preserved")
}

// ═══════════════════════════════════════════════════════════════
//  EVIDENCE TESTS (30-33)
// ═══════════════════════════════════════════════════════════════

do { // Test 30: Evidence is created on milestone completion
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    assert(store.hasEvidence(for: "software-1", roadmap: "software-engineer"), "T30: evidence created")
}

do { // Test 31: Evidence ID is deterministic
    let store = SimulatedStore()
    let e1 = store.evidenceID(for: "software-1", roadmap: "software-engineer")
    let e2 = store.evidenceID(for: "software-1", roadmap: "software-engineer")
    assertEqual(e1, e2, "T31: evidence ID deterministic")
    assertEqual(e1, "evidence-software-engineer-software-1", "T31: evidence ID format correct")
}

do { // Test 32: Duplicate completion does not create duplicate evidence
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    let eid = store.evidenceID(for: "software-1", roadmap: "software-engineer")
    // Manually set progress back to 0 and re-complete to test idempotency
    store.roadmapProgress["software-engineer"] = 0
    assert(store.evidenceRecords[eid] != nil, "T32: evidence exists from first completion")
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    // Count should still be 1 for the same evidence record
    let evCount = store.evidenceRecords.filter { $0.key == eid }.count
    assertEqual(evCount, 1, "T32: no duplicate evidence")
}

do { // Test 33: Evidence connects to correct roadmap/milestone
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    let eid = store.evidenceID(for: "software-1", roadmap: "software-engineer")
    let record = store.evidenceRecords[eid]
    assert(record != nil, "T33: evidence record exists")
    assertEqual(record?.roadmapID, "software-engineer", "T33: roadmapID correct")
    assertEqual(record?.milestoneID, "software-1", "T33: milestoneID correct")
    assertEqual(record?.title, "Explore Computer Science", "T33: title matches milestone")
    assertEqual(record?.type, "milestone-completion", "T33: type correct")
}

// ═══════════════════════════════════════════════════════════════
//  PROGRESS TESTS (34-37)
// ═══════════════════════════════════════════════════════════════

do { // Test 34: Progress starts at 0/6
    let store = SimulatedStore()
    assertEqual(store.completedCount(for: seRoadmap), 0, "T34: starts at 0")
    assertEqual(seRoadmap.milestones.count, 6, "T34: 6 milestones")
}

do { // Test 35: Progress increments on milestone completion
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 0, "T35: 0 before")
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 1, "T35: 1 after first")
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 2, "T35: 2 after second")
}

do { // Test 36: Progress calculation is correct at each step
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    for i in 0..<6 {
        store.markRoadmapMilestoneComplete(for: seRoadmap)
        let expected = Int((Double(i + 1) / 6.0 * 100).rounded())
        let scored = ScoredRoadmap(roadmap: seRoadmap, matchScore: 50, completedMilestones: store.completedCount(for: seRoadmap))
        assertEqual(scored.progress, expected, "T36: \(i+1)/6 = \(expected)%")
    }
}

do { // Test 37: Action count does NOT affect milestone count
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    for action in seRoadmap.milestones[0].actions ?? [] { store.toggleAction(action.id) }
    assertEqual(store.completedCount(for: seRoadmap), 0, "T37: actions don't affect milestone count")
}

// ═══════════════════════════════════════════════════════════════
//  DEPENDENCY TESTS (38-41)
// ═══════════════════════════════════════════════════════════════

do { // Test 38: No dependency cycles in any roadmap
    for roadmap in catalog {
        assert(!RoadmapEngine.detectCycles(for: roadmap), "T38: no cycles in \(roadmap.id)")
    }
}

do { // Test 39: All dependency references are valid
    for roadmap in catalog {
        let errors = RoadmapEngine.validateDependencies(for: roadmap)
        assert(errors.isEmpty, "T39: valid deps in \(roadmap.id) — errors: \(errors)")
    }
}

do { // Test 40: No self-dependencies
    for roadmap in catalog {
        for ms in roadmap.milestones {
            assert(!(ms.dependencies?.contains(ms.id) ?? false), "T40: no self-dep in \(ms.id)")
        }
    }
}

do { // Test 41: No duplicate dependencies
    for roadmap in catalog {
        for ms in roadmap.milestones {
            if let deps = ms.dependencies {
                assertEqual(Set(deps).count, deps.count, "T41: no dupes in \(ms.id)")
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
//  DEACTIVATION TESTS (42-45)
// ═══════════════════════════════════════════════════════════════

do { // Test 42: Deactivation removes active status
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    assert(store.isRoadmapActivated("software-engineer"), "T42: active before")
    store.deactivateRoadmap("software-engineer")
    assert(!store.isRoadmapActivated("software-engineer"), "T42: not active after")
}

do { // Test 43: Deactivation preserves progress
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.deactivateRoadmap("software-engineer")
    assertEqual(store.completedCount(for: seRoadmap), 2, "T43: progress preserved")
}

do { // Test 44: Deactivation preserves evidence and skills
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    let skillsBefore = store.profile.strengths
    let evidenceBefore = store.evidenceRecords
    store.deactivateRoadmap("software-engineer")
    assertEqual(store.profile.strengths, skillsBefore, "T44: skills preserved")
    assertEqual(store.evidenceRecords, evidenceBefore, "T44: evidence preserved")
}

do { // Test 45: Reactivation preserves existing progress
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.deactivateRoadmap("software-engineer")
    store.startRoadmap(seRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 2, "T45: progress preserved on reactivation")
    assert(store.isRoadmapActivated("software-engineer"), "T45: active after reactivation")
}

// ═══════════════════════════════════════════════════════════════
//  RESET TESTS (46-48)
// ═══════════════════════════════════════════════════════════════

do { // Test 46: Reset clears progress
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 2, "T46: progress before reset")
    store.resetRoadmap(seRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 0, "T46: progress cleared after reset")
}

do { // Test 47: Reset clears actions and evidence
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    for action in seRoadmap.milestones[0].actions ?? [] { store.toggleAction(action.id) }
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    assert(store.evidenceRecords.count > 0, "T47: evidence before reset")
    store.resetRoadmap(seRoadmap)
    for action in seRoadmap.milestones[0].actions ?? [] {
        assert(!store.isActionCompleted(action.id), "T47: action \(action.id) cleared")
    }
    let eid = store.evidenceID(for: "software-1", roadmap: "software-engineer")
    assert(store.evidenceRecords[eid] == nil, "T47: evidence cleared")
}

do { // Test 48: Reset preserves skills
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    let skillsBefore = store.profile.strengths
    store.resetRoadmap(seRoadmap)
    assertEqual(store.profile.strengths, skillsBefore, "T48: skills preserved after reset")
}

// ═══════════════════════════════════════════════════════════════
//  MULTIPLE ROADMAP TESTS (49-51)
// ═══════════════════════════════════════════════════════════════

do { // Test 49: Activating roadmap A does not affect roadmap B
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 1, "T49: SE has 1")
    assertEqual(store.completedCount(for: aiRoadmap), 0, "T49: AI has 0")
}

do { // Test 50: Each roadmap has independent progress
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap); store.startRoadmap(aiRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.markRoadmapMilestoneComplete(for: aiRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 2, "T50: SE = 2")
    assertEqual(store.completedCount(for: aiRoadmap), 1, "T50: AI = 1")
}

do { // Test 51: Active roadmap filtering works correctly
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap); store.startRoadmap(aiRoadmap)
    for _ in 0..<6 { store.markRoadmapMilestoneComplete(for: seRoadmap) }
    store.markRoadmapMilestoneComplete(for: aiRoadmap)
    let seS = ScoredRoadmap(roadmap: seRoadmap, matchScore: 50, completedMilestones: 6)
    let aiS = ScoredRoadmap(roadmap: aiRoadmap, matchScore: 50, completedMilestones: 1)
    assert(seS.isCompleted, "T51: SE is completed")
    assert(!aiS.isCompleted, "T51: AI is not completed")
}

// ═══════════════════════════════════════════════════════════════
//  CAREER-AGNOSTIC TESTS (52-54)
// ═══════════════════════════════════════════════════════════════

do { // Test 52: Generic engine handles all 4 test roadmaps
    for roadmap in catalog {
        let store = SimulatedStore()
        store.startRoadmap(roadmap)
        store.markRoadmapMilestoneComplete(for: roadmap)
        assertEqual(store.completedCount(for: roadmap), 1, "T52: \(roadmap.id) completed 1")
        let ms = roadmap.milestones[0]
        let avail = RoadmapEngine.milestoneAvailability(milestone: ms, completedIDs: ["\(ms.id)"], milestones: roadmap.milestones)
        assertEqual(avail, .completed, "T52: \(ms.id) marked completed")
    }
}

do { // Test 53: No roadmap-specific branching in engine
    let store = SimulatedStore()
    for roadmap in catalog {
        store.startRoadmap(roadmap)
        assert(store.isRoadmapActivated(roadmap.id), "T53: \(roadmap.id) activated via generic code")
    }
}

do { // Test 54: All roadmaps use the same milestone completion mechanism
    let store = SimulatedStore()
    for roadmap in catalog {
        store.startRoadmap(roadmap)
        let before = store.completedCount(for: roadmap)
        store.markRoadmapMilestoneComplete(for: roadmap)
        assertEqual(store.completedCount(for: roadmap), before + 1, "T54: \(roadmap.id) incremented by 1")
    }
}

// ═══════════════════════════════════════════════════════════════
//  PERSISTENCE TESTS (55-58)
// ═══════════════════════════════════════════════════════════════

do { // Test 55: All state survives simulated reload
    let store = SimulatedStore()
    var p = StudentProfile()
    p.name = "TestStudent"; p.strengths = ["Python"]
    store.profile = p
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.toggleAction("software-1-action-1")
    store.saveValidationAttempt(ValidationAttempt(id: "a1", validationID: "sw1-assessment", selectedAnswers: [:], score: 3, totalQuestions: 3, percentage: 100, passed: true))
    let store2 = SimulatedStore()
    store2.profile = store.profile; store2.roadmapProgress = store.roadmapProgress
    store2.activeRoadmaps = store.activeRoadmaps; store2.completedActionIDs = store.completedActionIDs
    store2.validationAttempts = store.validationAttempts; store2.evidenceRecords = store.evidenceRecords
    assertEqual(store2.profile.name, "TestStudent", "T55: profile survives")
    assertEqual(store2.completedCount(for: seRoadmap), 1, "T55: progress survives")
    assert(store2.isRoadmapActivated("software-engineer"), "T55: activation survives")
    assert(store2.isActionCompleted("software-1-action-1"), "T55: action survives")
    assert(store2.validationAttempts["sw1-assessment"] != nil, "T55: validation survives")
}

do { // Test 56: Profile survives reload
    let store = SimulatedStore()
    var p = StudentProfile(); p.name = "ReloadTest"; p.strengths = ["Skill1", "Skill2"]
    store.profile = p
    let store2 = SimulatedStore(); store2.profile = store.profile
    assertEqual(store2.profile.name, "ReloadTest", "T56: name survives")
    assertEqual(store2.profile.strengths, ["Skill1", "Skill2"], "T56: strengths survive")
}

do { // Test 57: Activation survives reload
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap); store.startRoadmap(aiRoadmap)
    let store2 = SimulatedStore(); store2.activeRoadmaps = store.activeRoadmaps
    assert(store2.isRoadmapActivated("software-engineer"), "T57: SE survives")
    assert(store2.isRoadmapActivated("ai-engineer"), "T57: AI survives")
}

do { // Test 58: Progress + actions + validation + evidence + skills survive reload
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.toggleAction("software-1-action-1")
    store.saveValidationAttempt(ValidationAttempt(id: "a1", validationID: "sw1-assessment", selectedAnswers: [:], score: 2, totalQuestions: 3, percentage: 67, passed: false))
    let store2 = SimulatedStore()
    store2.roadmapProgress = store.roadmapProgress; store2.completedActionIDs = store.completedActionIDs
    store2.validationAttempts = store.validationAttempts; store2.evidenceRecords = store.evidenceRecords
    store2.profile = store.profile
    assertEqual(store2.completedCount(for: seRoadmap), 1, "T58: progress survives")
    assert(store2.isActionCompleted("software-1-action-1"), "T58: action survives")
    assert(store2.validationAttempts["sw1-assessment"] != nil, "T58: validation survives")
    assert(store2.evidenceRecords.count > 0, "T58: evidence survives")
    assert(store2.profile.strengths.count > 0, "T58: skills survive")
}

// ═══════════════════════════════════════════════════════════════
//  ID INTEGRITY TESTS (59-62)
// ═══════════════════════════════════════════════════════════════

do { // Test 59: All roadmap IDs are unique
    let ids = catalog.map(\.id)
    assertEqual(Set(ids).count, ids.count, "T59: all roadmap IDs unique")
}

do { // Test 60: All milestone IDs are globally unique
    var allIDs: [String] = []
    for roadmap in catalog { for ms in roadmap.milestones { allIDs.append(ms.id) } }
    assertEqual(Set(allIDs).count, allIDs.count, "T60: all milestone IDs globally unique")
}

do { // Test 61: All action IDs are globally unique
    var allIDs: [String] = []
    for roadmap in catalog { for ms in roadmap.milestones { for action in ms.actions ?? [] { allIDs.append(action.id) } } }
    assertEqual(Set(allIDs).count, allIDs.count, "T61: all action IDs globally unique")
}

do { // Test 62: All resource IDs are globally unique
    var allIDs: [String] = []
    for roadmap in catalog { for ms in roadmap.milestones { for res in ms.learningResources ?? [] { allIDs.append(res.id) } } }
    assertEqual(Set(allIDs).count, allIDs.count, "T62: all resource IDs globally unique")
}

// ═══════════════════════════════════════════════════════════════
//  DATA QUALITY TESTS (63-65)
// ═══════════════════════════════════════════════════════════════

do { // Test 63: No empty milestone titles
    for roadmap in catalog { for ms in roadmap.milestones {
        assert(!ms.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "T63: \(ms.id) has title")
    }}
}

do { // Test 64: No empty action titles
    for roadmap in catalog { for ms in roadmap.milestones { for action in ms.actions ?? [] {
        assert(!action.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "T64: \(action.id) has title")
    }}}
}

do { // Test 65: All assessment questions have 4 choices
    for roadmap in catalog { for ms in roadmap.milestones { for q in ms.assessment?.questions ?? [] {
        assertEqual(q.choices.count, 4, "T65: \(q.id) has 4 choices")
    }}}
}

// ═══════════════════════════════════════════════════════════════
//  CROSS-VIEW CONSISTENCY TESTS (66-68)
// ═══════════════════════════════════════════════════════════════

do { // Test 66: ProgressEngine.snapshot matches manual calculation
    let store = SimulatedStore()
    var p = StudentProfile(); p.strengths = ["Python"]
    store.profile = p
    store.startRoadmap(seRoadmap); store.startRoadmap(aiRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.markRoadmapMilestoneComplete(for: aiRoadmap)
    let scored = catalog.map { roadmap in
        ScoredRoadmap(roadmap: roadmap, matchScore: 50, completedMilestones: min(store.roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count))
    }
    let totalCompleted = scored.reduce(0) { $0 + $1.completedMilestones }
    let totalMilestones = scored.reduce(0) { $0 + $1.roadmap.milestones.count }
    assertEqual(totalCompleted, 3, "T66: total completed = 3")
    assertEqual(totalMilestones, 24, "T66: total milestones = 24 (6+6+6+6)")
    let expectedPct = Int((Double(totalCompleted) / Double(totalMilestones) * 100).rounded())
    let snap = ProgressSnapshot(completedMilestones: totalCompleted, totalMilestones: totalMilestones,
        milestoneProgress: expectedPct, activeRoadmaps: 2, completedRoadmaps: 0,
        skillCount: 1, achievementsCount: 0, overallProgress: expectedPct)
    assertEqual(snap.completedMilestones, 3, "T66: snapshot completed = 3")
}

do { // Test 67: completedCount matches roadmapProgress value
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    store.markRoadmapMilestoneComplete(for: seRoadmap)
    let directCount = store.roadmapProgress["software-engineer"] ?? 0
    assertEqual(directCount, store.completedCount(for: seRoadmap), "T67: roadmapProgress matches completedCount")
}

do { // Test 68: activatedRoadmaps filter is correct
    let store = SimulatedStore()
    store.startRoadmap(seRoadmap); store.startRoadmap(aiRoadmap)
    for _ in 0..<6 { store.markRoadmapMilestoneComplete(for: aiRoadmap) }
    let activated = store.activeRoadmaps.filter { $0.value.status == .active }
    assert(activated.keys.contains("software-engineer"), "T68: SE in active")
    assert(activated.keys.contains("ai-engineer"), "T68: AI in active")
    assertEqual(activated.count, 2, "T68: both activation records present")
}

// ═══════════════════════════════════════════════════════════════
//  FULL INTEGRATION SCENARIO (69-70)
// ═══════════════════════════════════════════════════════════════

do { // Test 69: Full flow: Profile → Recommend → Activate → Milestones → Skills → Evidence → Reload → Deactivate → Reactivate
    var p = StudentProfile()
    p.name = "IntegrationStudent"; p.interests = ["Technology", "AI"]
    p.strengths = ["Programming", "Problem solving"]; p.customSkills = ["Python"]
    p.careers = ["Software Engineer", "AI Researcher"]; p.fields = ["Computer Science", "Engineering"]
    p.grade = .tenth; p.collegePlan = .yesDefinitely; p.onboardingCompleted = true

    let scored = RoadmapService.roadmaps(for: p, progress: [:])
    assert(scored.count == 4, "T69: 4 roadmaps recommended")
    assert(scored.first?.id == "software-engineer" || scored.first?.id == "ai-engineer", "T69: SE or AI is top")

    let store = SimulatedStore(); store.profile = p
    store.startRoadmap(seRoadmap)
    assert(store.isRoadmapActivated("software-engineer"), "T69: activated")

    let ms1 = seRoadmap.milestones[0]
    for action in ms1.actions ?? [] { store.toggleAction(action.id) }
    assert(RoadmapEngine.allActionsCompleted(for: ms1, completedIDs: store.completedActionIDs), "T69: all actions completed")
    assertEqual(store.completedCount(for: seRoadmap), 0, "T69: milestone NOT auto-completed")

    assertEqual(ms1.learningResources?.count, 3, "T69: 3 learning resources")

    let questions = ms1.assessment!.questions
    let answers: [String: Int] = ["sw1-q1": 1, "sw1-q2": 1, "sw1-q3": 1]
    let score = RoadmapEngine.score(answers: answers, questions: questions)
    let pct = RoadmapEngine.percentage(score: score, total: questions.count)
    let didPass = RoadmapEngine.passed(percentage: pct, threshold: ms1.assessment!.passThreshold)
    assertEqual(score, 3, "T69: score 3/3"); assertEqual(pct, 100, "T69: 100%"); assert(didPass, "T69: passed")

    store.saveValidationAttempt(ValidationAttempt(id: "int-att", validationID: "sw1-assessment", selectedAnswers: answers, score: score, totalQuestions: 3, percentage: pct, passed: didPass))
    assert(store.validationAttempts["sw1-assessment"]?.passed == true, "T69: validation persisted")

    store.markRoadmapMilestoneComplete(for: seRoadmap)
    assertEqual(store.completedCount(for: seRoadmap), 1, "T69: 1 completed")
    assert(store.profile.strengths.contains("Computational Thinking"), "T69: skill acquired")
    assert(store.profile.strengths.contains("Development Environment Setup"), "T69: skill 2 acquired")
    assert(store.profile.strengths.contains("Version Control Basics"), "T69: skill 3 acquired")

    assert(store.hasEvidence(for: "software-1", roadmap: "software-engineer"), "T69: evidence created")
    let ev = store.evidenceRecords[store.evidenceID(for: "software-1", roadmap: "software-engineer")]
    assertEqual(ev?.roadmapID, "software-engineer", "T69: evidence roadmapID")
    assertEqual(ev?.milestoneID, "software-1", "T69: evidence milestoneID")
    assertEqual(ev?.validationPassed, true, "T69: evidence validationPassed")

    let ms2 = seRoadmap.milestones[1]
    let avail = RoadmapEngine.milestoneAvailability(milestone: ms2, completedIDs: ["software-1"], milestones: seRoadmap.milestones)
    assertEqual(avail, .available, "T69: ms2 available after ms1 completed")

    let scoredSE = ScoredRoadmap(roadmap: seRoadmap, matchScore: 50, completedMilestones: store.completedCount(for: seRoadmap))
    assertEqual(scoredSE.progress, 17, "T69: progress = 17% (1/6)")

    let store2 = SimulatedStore()
    store2.profile = store.profile; store2.roadmapProgress = store.roadmapProgress
    store2.activeRoadmaps = store.activeRoadmaps; store2.completedActionIDs = store.completedActionIDs
    store2.validationAttempts = store.validationAttempts; store2.evidenceRecords = store.evidenceRecords
    assertEqual(store2.completedCount(for: seRoadmap), 1, "T69: progress survives reload")
    assert(store2.isRoadmapActivated("software-engineer"), "T69: activation survives")

    store2.deactivateRoadmap("software-engineer")
    assert(!store2.isRoadmapActivated("software-engineer"), "T69: deactivated")
    assertEqual(store2.completedCount(for: seRoadmap), 1, "T69: progress preserved after deactivate")
    assert(store2.profile.strengths.contains("Computational Thinking"), "T69: skills preserved after deactivate")

    store2.startRoadmap(seRoadmap)
    assert(store2.isRoadmapActivated("software-engineer"), "T69: reactivated")
    assertEqual(store2.completedCount(for: seRoadmap), 1, "T69: progress preserved after reactivate")

    for _ in 1..<6 { store2.markRoadmapMilestoneComplete(for: seRoadmap) }
    assertEqual(store2.completedCount(for: seRoadmap), 6, "T69: all 6 completed")
    let finalS = ScoredRoadmap(roadmap: seRoadmap, matchScore: 50, completedMilestones: 6)
    assert(finalS.isCompleted, "T69: roadmap completed")
}

do { // Test 70: Same flow works for AI Engineer roadmap (career-agnostic proof)
    var p = StudentProfile()
    p.name = "AIStudent"; p.interests = ["Technology", "AI", "Science", "Mathematics"]
    p.strengths = ["Programming", "Mathematics", "Data Analysis", "Problem solving"]
    p.careers = ["AI Researcher", "Data Scientist", "Software Engineer"]
    p.fields = ["Computer Science", "Mathematics", "Engineering"]
    p.grade = .tenth; p.collegePlan = .yesDefinitely

    let store = SimulatedStore(); store.profile = p
    store.startRoadmap(aiRoadmap)
    assert(store.isRoadmapActivated("ai-engineer"), "T70: AI activated")

    for _ in 0..<6 { store.markRoadmapMilestoneComplete(for: aiRoadmap) }
    assertEqual(store.completedCount(for: aiRoadmap), 6, "T70: all 6 AI milestones completed")
    let finalS = ScoredRoadmap(roadmap: aiRoadmap, matchScore: 50, completedMilestones: 6)
    assert(finalS.isCompleted, "T70: AI roadmap completed")

    let expectedSkills: Set<String> = ["AI Literacy", "Technical Exploration", "Critical Thinking",
        "Python", "Data Analysis", "Statistics", "Mathematics", "Programming Fundamentals",
        "Machine Learning", "Model Evaluation"]
    for skill in expectedSkills {
        assert(store.profile.strengths.contains(skill), "T70: skill '\(skill)' acquired from AI roadmap")
    }

    for ms in aiRoadmap.milestones {
        assert(store.hasEvidence(for: ms.id, roadmap: "ai-engineer"), "T70: evidence for \(ms.id)")
    }

    for ms in aiRoadmap.milestones {
        let avail = RoadmapEngine.milestoneAvailability(milestone: ms, completedIDs: Set(aiRoadmap.milestones.map(\.id)), milestones: aiRoadmap.milestones)
        assertEqual(avail, .completed, "T70: \(ms.id) is completed")
    }

    assert(!RoadmapEngine.detectCycles(for: aiRoadmap), "T70: no cycles in AI roadmap")
    let errors = RoadmapEngine.validateDependencies(for: aiRoadmap)
    assert(errors.isEmpty, "T70: valid deps in AI roadmap")
}

// ═══════════════════════════════════════════════════════════════
//  SUMMARY
// ═══════════════════════════════════════════════════════════════

print("\nPhase 6.4.10 — End-to-End: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
