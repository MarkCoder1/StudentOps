import Foundation

// Standalone test script for Phase 6.4.9 — Expanded Roadmap Catalog
// Run: swift test-roadmap-catalog.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// ── Inline model types ──

struct TestAction { let id: String; let title: String }
struct TestResource { let id: String }
struct TestQuestion { let id: String }
struct TestAssessment { let id: String; let questions: [TestQuestion] }
struct TestMilestone {
    let id: String; let title: String; let subtitle: String
    let goal: String; let whatItAccomplishes: String; let whyItMatters: String
    let actions: [TestAction]; let skillsDeveloped: [String]
    let completionCriteria: [String]; let dependencies: [String]
    let learningResources: [TestResource]; let assessment: TestAssessment?
}
struct TestRoadmap { let id: String; let title: String; let milestones: [TestMilestone] }

// ── Activation models ──

enum ActivationStatus: String, Hashable { case active, completed }
struct ActiveRoadmap: Identifiable, Hashable {
    let roadmapID: String; let status: ActivationStatus; let startedAt: TimeInterval
    var id: String { roadmapID }
}
class SimulatedStore {
    var activeRoadmaps: [String: ActiveRoadmap] = [:]
    var roadmapProgress: [String: Int] = [:]
    func isActivated(_ id: String) -> Bool { activeRoadmaps[id]?.status == .active }
    func completedCount(for roadmap: TestRoadmap) -> Int {
        min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
    }
    func startRoadmap(_ roadmap: TestRoadmap) {
        guard activeRoadmaps[roadmap.id]?.status != .active else { return }
        let existing = activeRoadmaps[roadmap.id]
        activeRoadmaps[roadmap.id] = ActiveRoadmap(
            roadmapID: roadmap.id, status: .active,
            startedAt: existing?.startedAt ?? Date().timeIntervalSince1970)
    }
    func deactivateRoadmap(_ id: String) { activeRoadmaps.removeValue(forKey: id) }
}

func A(_ id: String) -> TestAction { TestAction(id: id, title: id) }
func R(_ id: String) -> TestResource { TestResource(id: id) }
func Q(_ id: String) -> TestQuestion { TestQuestion(id: id) }

let D = "" // empty dependency shorthand

let catalog: [TestRoadmap] = [

    // ── 1. Software Engineer (6 milestones) ──
    TestRoadmap(id: "software-engineer", title: "Become a Software Engineer", milestones: [
        TestMilestone(id: "software-1", title: "Explore Computer Science", subtitle: "Map concepts",
            goal: "Develop a clear picture of what software engineering involves.",
            whatItAccomplishes: "Build a mental model.", whyItMatters: "Understanding the landscape helps.",
            actions: [A("software-1-action-1"),A("software-1-action-2"),A("software-1-action-3"),A("software-1-action-4")],
            skillsDeveloped: ["Computational Thinking","Development Environment Setup","Version Control Basics"],
            completionCriteria: ["Complete all four actions.","Articulate what SE means.","Identify subfields.","Have editor and GitHub."],
            dependencies: [], learningResources: [R("sw1-res-1"),R("sw1-res-2"),R("sw1-res-3")],
            assessment: TestAssessment(id: "sw1-assessment", questions: [Q("sw1-q1"),Q("sw1-q2"),Q("sw1-q3")])),
        TestMilestone(id: "software-2", title: "Build Programming Fundamentals", subtitle: "Core patterns",
            goal: "Write programs using variables, conditions, loops, functions.",
            whatItAccomplishes: "Develop fluency with core patterns.", whyItMatters: "Every language builds on these.",
            actions: [A("software-2-action-1"),A("software-2-action-2"),A("software-2-action-3"),A("software-2-action-4")],
            skillsDeveloped: ["Programming Fundamentals","Problem Solving","Python","JavaScript"],
            completionCriteria: ["Complete all four actions.","Write program with conditionals/loops/functions.","Solve 10 problems.","Explain a function."],
            dependencies: ["software-1"], learningResources: [R("sw2-res-1"),R("sw2-res-2"),R("sw2-res-3")],
            assessment: TestAssessment(id: "sw2-assessment", questions: [Q("sw2-q1"),Q("sw2-q2"),Q("sw2-q3"),Q("sw2-q4")])),
        TestMilestone(id: "software-3", title: "Learn Software Development", subtitle: "Real software",
            goal: "Use Git, debug, call an API, write a basic test.",
            whatItAccomplishes: "Move from scripts to software systems.", whyItMatters: "These practices separate student from pro.",
            actions: [A("software-3-action-1"),A("software-3-action-2"),A("software-3-action-3"),A("software-3-action-4")],
            skillsDeveloped: ["Git","Debugging","APIs","Unit Testing","Software Development"],
            completionCriteria: ["Complete all four actions.","5+ commits with clear messages.","Retrieve data from API.","Write 3+ passing tests."],
            dependencies: ["software-2"], learningResources: [R("sw3-res-1"),R("sw3-res-2"),R("sw3-res-3")],
            assessment: TestAssessment(id: "sw3-assessment", questions: [Q("sw3-q1"),Q("sw3-q2"),Q("sw3-q3"),Q("sw3-q4")])),
        TestMilestone(id: "software-4", title: "Build Real Projects", subtitle: "Real problem",
            goal: "Complete and ship one functional project.",
            whatItAccomplishes: "Apply everything to a real project.", whyItMatters: "A project teaches more than tutorials.",
            actions: [A("software-4-action-1"),A("software-4-action-2"),A("software-4-action-3"),A("software-4-action-4")],
            skillsDeveloped: ["Software Development","Project Planning","Technical Communication","Building Things"],
            completionCriteria: ["Complete all four actions.","Project runs.","10+ Git commits.","Clear README."],
            dependencies: ["software-3"], learningResources: [R("sw4-res-1"),R("sw4-res-2"),R("sw4-res-3")],
            assessment: TestAssessment(id: "sw4-assessment", questions: [Q("sw4-q1"),Q("sw4-q2"),Q("sw4-q3"),Q("sw4-q4")])),
        TestMilestone(id: "software-5", title: "Gain External Experience", subtitle: "Real-world",
            goal: "Participate in at least one external coding event.",
            whatItAccomplishes: "Build credibility externally.", whyItMatters: "External experience shows real-world capability.",
            actions: [A("software-5-action-1"),A("software-5-action-2"),A("software-5-action-3")],
            skillsDeveloped: ["Technical Communication","Collaboration","Software Development","Competition Skills"],
            completionCriteria: ["Complete all three actions.","Submit to hackathon or have PR.","Publish public explanation."],
            dependencies: ["software-4"], learningResources: [R("sw5-res-1"),R("sw5-res-2"),R("sw5-res-3")],
            assessment: TestAssessment(id: "sw5-assessment", questions: [Q("sw5-q1"),Q("sw5-q2"),Q("sw5-q3")])),
        TestMilestone(id: "software-6", title: "Build a Technical Portfolio", subtitle: "Document work",
            goal: "Have a live portfolio showcasing 2+ projects.",
            whatItAccomplishes: "Create a polished portfolio.", whyItMatters: "A portfolio turns projects into a story.",
            actions: [A("software-6-action-1"),A("software-6-action-2"),A("software-6-action-3"),A("software-6-action-4")],
            skillsDeveloped: ["Technical Communication","Portfolio Development","Personal Branding","Web Development"],
            completionCriteria: ["Complete all four actions.","Portfolio is live.","2+ projects with case studies.","GitHub has README and pinned repos."],
            dependencies: ["software-5"], learningResources: [R("sw6-res-1"),R("sw6-res-2"),R("sw6-res-3")],
            assessment: TestAssessment(id: "sw6-assessment", questions: [Q("sw6-q1"),Q("sw6-q2"),Q("sw6-q3")]))
    ]),

    // ── 2. AI Engineer (6 milestones) ──
    TestRoadmap(id: "ai-engineer", title: "Become an AI Engineer", milestones: [
        TestMilestone(id: "ai-1", title: "Explore AI & ML", subtitle: "Understand AI",
            goal: "Explain AI and ML, name 5 applications, identify areas.",
            whatItAccomplishes: "Build a mental model of AI.", whyItMatters: "Understanding helps focus.",
            actions: [A("ai-1-action-1"),A("ai-1-action-2"),A("ai-1-action-3")],
            skillsDeveloped: ["AI Literacy","Technical Exploration","Critical Thinking"],
            completionCriteria: ["Complete all three actions.","Name 3+ applications.","Identify 1-2 areas."],
            dependencies: [], learningResources: [R("ai1-res-1"),R("ai1-res-2"),R("ai1-res-3")],
            assessment: TestAssessment(id: "ai1-assessment", questions: [Q("ai1-q1"),Q("ai1-q2"),Q("ai1-q3")])),
        TestMilestone(id: "ai-2", title: "Build Programming & Math Foundations", subtitle: "Python and math",
            goal: "Write Python programs and explain basic math for AI.",
            whatItAccomplishes: "Gain fluency in Python and core math.", whyItMatters: "AI libraries are in Python; ML relies on math.",
            actions: [A("ai-2-action-1"),A("ai-2-action-2"),A("ai-2-action-3"),A("ai-2-action-4")],
            skillsDeveloped: ["Python","Data Analysis","Statistics","Mathematics","Programming Fundamentals"],
            completionCriteria: ["Complete all four actions.","Write Python without tutorial.","Load and analyze dataset.","Explain what a matrix is."],
            dependencies: ["ai-1"], learningResources: [R("ai2-res-1"),R("ai2-res-2"),R("ai2-res-3")],
            assessment: TestAssessment(id: "ai2-assessment", questions: [Q("ai2-q1"),Q("ai2-q2"),Q("ai2-q3")])),
        TestMilestone(id: "ai-3", title: "Learn ML Fundamentals", subtitle: "How machines learn",
            goal: "Explain supervised vs. unsupervised, train a model, evaluate it.",
            whatItAccomplishes: "Learn core ML concepts.", whyItMatters: "Understanding separates users from builders.",
            actions: [A("ai-3-action-1"),A("ai-3-action-2"),A("ai-3-action-3"),A("ai-3-action-4"),A("ai-3-action-5")],
            skillsDeveloped: ["Machine Learning","Data Analysis","Model Evaluation","Python","Statistics"],
            completionCriteria: ["Complete all five actions.","Train classifier with 80%+ accuracy.","Explain overfitting.","Use confusion matrix."],
            dependencies: ["ai-2"], learningResources: [R("ai3-res-1"),R("ai3-res-2"),R("ai3-res-3")],
            assessment: TestAssessment(id: "ai3-assessment", questions: [Q("ai3-q1"),Q("ai3-q2"),Q("ai3-q3"),Q("ai3-q4")])),
        TestMilestone(id: "ai-4", title: "Build AI Applications", subtitle: "Real-world tools",
            goal: "Build and deploy at least one working AI application.",
            whatItAccomplishes: "Build working AI applications.", whyItMatters: "Building teaches what tutorials cannot.",
            actions: [A("ai-4-action-1"),A("ai-4-action-2"),A("ai-4-action-3"),A("ai-4-action-4")],
            skillsDeveloped: ["Machine Learning","Data Analysis","APIs","AI Application Development","Software Development"],
            completionCriteria: ["Complete all four actions.","Train model on real data.","Build working interface.","Compare 2+ algorithms."],
            dependencies: ["ai-3"], learningResources: [R("ai4-res-1"),R("ai4-res-2"),R("ai4-res-3")],
            assessment: TestAssessment(id: "ai4-assessment", questions: [Q("ai4-q1"),Q("ai4-q2"),Q("ai4-q3")])),
        TestMilestone(id: "ai-5", title: "Work With Real Data", subtitle: "Data at scale",
            goal: "Find, clean, analyze, and visualize a real-world dataset.",
            whatItAccomplishes: "Develop real-world data skills.", whyItMatters: "Data prep takes 80% of AI project time.",
            actions: [A("ai-5-action-1"),A("ai-5-action-2"),A("ai-5-action-3"),A("ai-5-action-4")],
            skillsDeveloped: ["Data Analysis","Data Collection","Statistics","Python","Technical Communication"],
            completionCriteria: ["Complete all four actions.","Clean 1000+ row dataset.","Create 3+ visualizations.","Write findings report."],
            dependencies: ["ai-4"], learningResources: [R("ai5-res-1"),R("ai5-res-2"),R("ai5-res-3")],
            assessment: TestAssessment(id: "ai5-assessment", questions: [Q("ai5-q1"),Q("ai5-q2"),Q("ai5-q3")])),
        TestMilestone(id: "ai-6", title: "Build an AI Portfolio", subtitle: "Showcase skills",
            goal: "Have a live portfolio presenting 2+ AI projects.",
            whatItAccomplishes: "Create a polished AI portfolio.", whyItMatters: "A portfolio is the strongest evidence.",
            actions: [A("ai-6-action-1"),A("ai-6-action-2"),A("ai-6-action-3"),A("ai-6-action-4")],
            skillsDeveloped: ["Portfolio Development","Technical Communication","Personal Branding","AI Application Development"],
            completionCriteria: ["Complete all four actions.","Portfolio is live.","2+ AI projects with case studies.","GitHub highlights AI work."],
            dependencies: ["ai-5"], learningResources: [R("ai6-res-1"),R("ai6-res-2")], assessment: nil)
    ]),

    // ── 3. Research Builder (6 milestones) ──
    TestRoadmap(id: "research-builder", title: "Build a Research Profile", milestones: [
        TestMilestone(id: "research-1", title: "Explore Research", subtitle: "Understand research",
            goal: "Explain research, identify 2-3 topics, understand basic steps.",
            whatItAccomplishes: "Build mental model of research.", whyItMatters: "Understanding helps choose a topic.",
            actions: [A("research-1-action-1"),A("research-1-action-2"),A("research-1-action-3")],
            skillsDeveloped: ["Research Methods","Question Formation","Critical Thinking"],
            completionCriteria: ["Complete all three actions.","List 5+ questions.","Explain what makes research different."],
            dependencies: [], learningResources: [R("r1-res-1"),R("r1-res-2")], assessment: nil),
        TestMilestone(id: "research-2", title: "Choose a Research Question", subtitle: "Narrow curiosity",
            goal: "Refine a curiosity into a focused research question.",
            whatItAccomplishes: "Transform broad interest into specific question.", whyItMatters: "A well-formed question is most important.",
            actions: [A("research-2-action-1"),A("research-2-action-2"),A("research-2-action-3"),A("research-2-action-4")],
            skillsDeveloped: ["Question Formation","Source Evaluation","Research Methods","Writing"],
            completionCriteria: ["Complete all four actions.","Read 3+ sources.","Write one-page proposal.","Receive feedback."],
            dependencies: ["research-1"], learningResources: [R("r2-res-1"),R("r2-res-2")], assessment: nil),
        TestMilestone(id: "research-3", title: "Learn Research Methods", subtitle: "Evidence and sources",
            goal: "Choose a method, evaluate 5+ sources, write a methods plan.",
            whatItAccomplishes: "Learn ethical data collection.", whyItMatters: "Good methods make research credible.",
            actions: [A("research-3-action-1"),A("research-3-action-2"),A("research-3-action-3"),A("research-3-action-4")],
            skillsDeveloped: ["Research Methods","Source Evaluation","Data Collection","Technical Writing"],
            completionCriteria: ["Complete all four actions.","Choose and justify method.","Evaluate 5+ sources.","Write methods plan and ethics statement."],
            dependencies: ["research-2"], learningResources: [R("r3-res-1"),R("r3-res-2")], assessment: nil),
        TestMilestone(id: "research-4", title: "Conduct an Investigation", subtitle: "Collect data",
            goal: "Collect data, organize it, and begin identifying patterns.",
            whatItAccomplishes: "Execute research plan with real data.", whyItMatters: "This is where research becomes real.",
            actions: [A("research-4-action-1"),A("research-4-action-2"),A("research-4-action-3"),A("research-4-action-4")],
            skillsDeveloped: ["Data Collection","Data Analysis","Scientific Method","Technical Writing"],
            completionCriteria: ["Complete all four actions.","Collect data per plan.","Organize in structured format.","Write a reflection."],
            dependencies: ["research-3"], learningResources: [R("r4-res-1"),R("r4-res-2")], assessment: nil),
        TestMilestone(id: "research-5", title: "Analyze & Communicate Findings", subtitle: "Clear argument",
            goal: "Complete analysis, draw conclusions, create a presentation.",
            whatItAccomplishes: "Turn data into clear argument.", whyItMatters: "Research is only valuable if others understand it.",
            actions: [A("research-5-action-1"),A("research-5-action-2"),A("research-5-action-3"),A("research-5-action-4")],
            skillsDeveloped: ["Data Analysis","Scientific Communication","Technical Writing","Presentation"],
            completionCriteria: ["Complete all four actions.","Present in poster/paper/slides.","Include question, methods, results, discussion.","Practice presenting."],
            dependencies: ["research-4"], learningResources: [R("r5-res-1"),R("r5-res-2")], assessment: nil),
        TestMilestone(id: "research-6", title: "Build a Research Portfolio", subtitle: "Document experience",
            goal: "Have a documented research portfolio.",
            whatItAccomplishes: "Create polished record of research.", whyItMatters: "A portfolio turns a project into demonstrated skill.",
            actions: [A("research-6-action-1"),A("research-6-action-2"),A("research-6-action-3")],
            skillsDeveloped: ["Portfolio Development","Technical Writing","Scientific Communication","Personal Branding"],
            completionCriteria: ["Complete all three actions.","Written research summary.","Digital portfolio.","Growth reflection."],
            dependencies: ["research-5"], learningResources: [R("r6-res-1"),R("r6-res-2")], assessment: nil)
    ]),

    // ── 4. Portfolio Projects (6 milestones) ──
    TestRoadmap(id: "portfolio-projects", title: "Build a Technical Portfolio", milestones: [
        TestMilestone(id: "portfolio-1", title: "Define Your Technical Direction", subtitle: "Choose direction",
            goal: "Identify 2-3 technical areas and decide what projects to build.",
            whatItAccomplishes: "Identify what portfolio should highlight.", whyItMatters: "Without direction it is just a collection.",
            actions: [A("portfolio-1-action-1"),A("portfolio-1-action-2"),A("portfolio-1-action-3")],
            skillsDeveloped: ["Project Planning","Technical Exploration","Personal Branding"],
            completionCriteria: ["Complete all three actions.","List current skills.","Review 3+ portfolios.","Write direction paragraph."],
            dependencies: [], learningResources: [R("p1-res-1"),R("p1-res-2")], assessment: nil),
        TestMilestone(id: "portfolio-2", title: "Build Strong Projects", subtitle: "Demonstrate skills",
            goal: "Complete 2-3 projects demonstrating different skills.",
            whatItAccomplishes: "Build meaningful projects.", whyItMatters: "Projects are the core of any portfolio.",
            actions: [A("portfolio-2-action-1"),A("portfolio-2-action-2"),A("portfolio-2-action-3"),A("portfolio-2-action-4")],
            skillsDeveloped: ["Software Development","Project Planning","Building Things","Version Control"],
            completionCriteria: ["Complete all four actions.","Build 2+ projects.","Different skills per project.","Get feedback."],
            dependencies: ["portfolio-1"], learningResources: [R("p2-res-1"),R("p2-res-2")], assessment: nil),
        TestMilestone(id: "portfolio-3", title: "Improve Project Quality", subtitle: "Polish projects",
            goal: "Improve at least 2 projects to professional standards.",
            whatItAccomplishes: "Refine to professional quality.", whyItMatters: "The difference between good and great is polish.",
            actions: [A("portfolio-3-action-1"),A("portfolio-3-action-2"),A("portfolio-3-action-3"),A("portfolio-3-action-4")],
            skillsDeveloped: ["Software Development","Quality Assurance","Building Things","Version Control"],
            completionCriteria: ["Complete all four actions.","No critical bugs.","Clean code.","Projects feel polished."],
            dependencies: ["portfolio-2"], learningResources: [R("p3-res-1"),R("p3-res-2")], assessment: nil),
        TestMilestone(id: "portfolio-4", title: "Document Your Work", subtitle: "Write explanations",
            goal: "Write complete documentation for each project.",
            whatItAccomplishes: "Create thorough documentation.", whyItMatters: "Documentation shows communication skill.",
            actions: [A("portfolio-4-action-1"),A("portfolio-4-action-2"),A("portfolio-4-action-3")],
            skillsDeveloped: ["Documentation","Technical Communication","Writing"],
            completionCriteria: ["Complete all three actions.","Each project has README.","Code has helpful comments.","Screenshots or demo."],
            dependencies: ["portfolio-3"], learningResources: [R("p4-res-1"),R("p4-res-2")], assessment: nil),
        TestMilestone(id: "portfolio-5", title: "Publish Your Portfolio", subtitle: "Make it live",
            goal: "Have a live portfolio accessible via URL.",
            whatItAccomplishes: "Create a live shareable portfolio.", whyItMatters: "A portfolio no one can see does not help.",
            actions: [A("portfolio-5-action-1"),A("portfolio-5-action-2"),A("portfolio-5-action-3"),A("portfolio-5-action-4")],
            skillsDeveloped: ["Portfolio Development","Web Development","Personal Branding","Technical Communication"],
            completionCriteria: ["Complete all four actions.","Portfolio is live.","All links work.","Looks good on mobile and desktop."],
            dependencies: ["portfolio-4"], learningResources: [R("p5-res-1"),R("p5-res-2")], assessment: nil),
        TestMilestone(id: "portfolio-6", title: "Build a Public Technical Presence", subtitle: "Share work",
            goal: "Publish at least one post and engage with a technical community.",
            whatItAccomplishes: "Build public technical identity.", whyItMatters: "Portfolio plus presence is more powerful.",
            actions: [A("portfolio-6-action-1"),A("portfolio-6-action-2"),A("portfolio-6-action-3")],
            skillsDeveloped: ["Personal Branding","Technical Communication","Collaboration"],
            completionCriteria: ["Complete all three actions.","Publish one post.","Join a community.","Contribute to discussion."],
            dependencies: ["portfolio-5"], learningResources: [R("p6-res-1"),R("p6-res-2")], assessment: nil)
    ]),

    // ── 5. College Ready (6 milestones) ──
    TestRoadmap(id: "college-ready", title: "Prepare for College", milestones: [
        TestMilestone(id: "college-1", title: "Understand Your Goals", subtitle: "Clarify goals",
            goal: "Identify top 3 interests, write a goal statement.",
            whatItAccomplishes: "Reflect on interests and goals.", whyItMatters: "College prep without clear goals wastes time.",
            actions: [A("college-1-action-1"),A("college-1-action-2"),A("college-1-action-3"),A("college-1-action-4")],
            skillsDeveloped: ["Goal Setting","Self-Advocacy","Research"],
            completionCriteria: ["Complete all four actions.","Identify top 3 interests.","Write goal statement.","Understand college types."],
            dependencies: [], learningResources: [R("c1-res-1"),R("c1-res-2")], assessment: nil),
        TestMilestone(id: "college-2", title: "Strengthen Academic Foundations", subtitle: "Academic record",
            goal: "Identify strengths/weaknesses, create improvement plan.",
            whatItAccomplishes: "Understand what colleges look for.", whyItMatters: "Academic record is critical.",
            actions: [A("college-2-action-1"),A("college-2-action-2"),A("college-2-action-3"),A("college-2-action-4")],
            skillsDeveloped: ["Academic Planning","Time Management","Self-Advocacy","Goal Setting"],
            completionCriteria: ["Complete all four actions.","Review transcript.","Plan courses.","Establish study routine."],
            dependencies: ["college-1"], learningResources: [R("c2-res-1"),R("c2-res-2")], assessment: nil),
        TestMilestone(id: "college-3", title: "Explore Colleges & Programs", subtitle: "Research schools",
            goal: "Research 5+ colleges, compare programs and costs.",
            whatItAccomplishes: "Research and compare colleges.", whyItMatters: "Finding the right fit matters more than prestige.",
            actions: [A("college-3-action-1"),A("college-3-action-2"),A("college-3-action-3"),A("college-3-action-4"),A("college-3-action-5")],
            skillsDeveloped: ["Research","Organization","Decision Making","Writing"],
            completionCriteria: ["Complete all five actions.","Research 5+ colleges.","Compare costs and aid.","Create preliminary list."],
            dependencies: ["college-2"], learningResources: [R("c3-res-1"),R("c3-res-2")], assessment: nil),
        TestMilestone(id: "college-4", title: "Build Experiences", subtitle: "Activities record",
            goal: "Participate in 2-3 meaningful activities with leadership.",
            whatItAccomplishes: "Build meaningful experiences.", whyItMatters: "Colleges want students who contribute.",
            actions: [A("college-4-action-1"),A("college-4-action-2"),A("college-4-action-3"),A("college-4-action-4")],
            skillsDeveloped: ["Leadership","Time Management","Communication","Planning"],
            completionCriteria: ["Complete all four actions.","Participate in 2+ activities.","Take leadership role.","Document activities."],
            dependencies: ["college-3"], learningResources: [R("c4-res-1"),R("c4-res-2")], assessment: nil),
        TestMilestone(id: "college-5", title: "Prepare Your Application Profile", subtitle: "Organize everything",
            goal: "Create complete application profile with personal statement.",
            whatItAccomplishes: "Create complete application profile.", whyItMatters: "Organization makes the process less stressful.",
            actions: [A("college-5-action-1"),A("college-5-action-2"),A("college-5-action-3"),A("college-5-action-4")],
            skillsDeveloped: ["Writing","Organization","Communication","Self-Advocacy"],
            completionCriteria: ["Complete all four actions.","Complete activities list.","First draft personal statement.","Identify recommenders."],
            dependencies: ["college-4"], learningResources: [R("c5-res-1"),R("c5-res-2")], assessment: nil),
        TestMilestone(id: "college-6", title: "Plan Your Application Process", subtitle: "Timeline",
            goal: "Create complete timeline with all deadlines.",
            whatItAccomplishes: "Build a complete application timeline.", whyItMatters: "Missing a deadline can cost an opportunity.",
            actions: [A("college-6-action-1"),A("college-6-action-2"),A("college-6-action-3"),A("college-6-action-4")],
            skillsDeveloped: ["Time Management","Organization","Planning","Goal Setting"],
            completionCriteria: ["Complete all four actions.","Complete timeline.","Register for tests.","Schedule check-ins."],
            dependencies: ["college-5"], learningResources: [R("c6-res-1"),R("c6-res-2")], assessment: nil)
    ]),

    // ── 6. STEM Explorer (6 milestones) ──
    TestRoadmap(id: "stem-explorer", title: "Explore STEM & Engineering", milestones: [
        TestMilestone(id: "stem-1", title: "Discover STEM Fields", subtitle: "Learn what STEM involves",
            goal: "Name 6+ STEM subfields, identify 2-3 interests.",
            whatItAccomplishes: "Understand major STEM fields.", whyItMatters: "STEM is enormous; landscape helps focus.",
            actions: [A("stem-1-action-1"),A("stem-1-action-2"),A("stem-1-action-3")],
            skillsDeveloped: ["Technical Exploration","Critical Thinking","Communication"],
            completionCriteria: ["Complete all three actions.","Name 6+ subfields.","Create connecting diagram.","Identify 2-3 areas."],
            dependencies: [], learningResources: [R("st1-res-1"),R("st1-res-2")], assessment: nil),
        TestMilestone(id: "stem-2", title: "Identify Areas of Interest", subtitle: "Narrow exploration",
            goal: "Research 2-3 STEM areas in depth.",
            whatItAccomplishes: "Dig deeper into top interests.", whyItMatters: "General interest becomes motivation.",
            actions: [A("stem-2-action-1"),A("stem-2-action-2"),A("stem-2-action-3")],
            skillsDeveloped: ["Technical Exploration","Critical Thinking","Decision Making"],
            completionCriteria: ["Complete all three actions.","Research 2-3 areas.","Try beginner activities.","Rank interests."],
            dependencies: ["stem-1"], learningResources: [R("st2-res-1"),R("st2-res-2")], assessment: nil),
        TestMilestone(id: "stem-3", title: "Build Technical Foundations", subtitle: "Math and coding",
            goal: "Solve math problems, write programs, apply both.",
            whatItAccomplishes: "Build foundational math and programming.", whyItMatters: "Math and programming are the language of STEM.",
            actions: [A("stem-3-action-1"),A("stem-3-action-2"),A("stem-3-action-3"),A("stem-3-action-4")],
            skillsDeveloped: ["Mathematics","Programming Fundamentals","Data Analysis","Problem Solving"],
            completionCriteria: ["Complete all four actions.","Solve algebra and statistics.","Write programs.","Apply both to interest."],
            dependencies: ["stem-2"], learningResources: [R("st3-res-1"),R("st3-res-2"),R("st3-res-3")], assessment: nil),
        TestMilestone(id: "stem-4", title: "Complete Hands-On Projects", subtitle: "Build real things",
            goal: "Complete 2-3 hands-on projects.",
            whatItAccomplishes: "Apply foundations to projects.", whyItMatters: "Projects are where learning becomes real.",
            actions: [A("stem-4-action-1"),A("stem-4-action-2"),A("stem-4-action-3"),A("stem-4-action-4")],
            skillsDeveloped: ["Building Things","Project Planning","Problem Solving","Technical Communication"],
            completionCriteria: ["Complete all four actions.","Build 2+ projects.","Document each project.","Receive and apply feedback."],
            dependencies: ["stem-3"], learningResources: [R("st4-res-1"),R("st4-res-2")], assessment: nil),
        TestMilestone(id: "stem-5", title: "Explore Real-World Applications", subtitle: "See STEM in careers",
            goal: "Research 2-3 real-world STEM applications.",
            whatItAccomplishes: "Connect skills to real-world.", whyItMatters: "Real-world applications motivate learning.",
            actions: [A("stem-5-action-1"),A("stem-5-action-2"),A("stem-5-action-3")],
            skillsDeveloped: ["Technical Exploration","Critical Thinking","Research"],
            completionCriteria: ["Complete all three actions.","Research 2-3 careers.","Identify community applications.","Connect projects to careers."],
            dependencies: ["stem-4"], learningResources: [R("st5-res-1"),R("st5-res-2")], assessment: nil),
        TestMilestone(id: "stem-6", title: "Choose a Direction", subtitle: "Commit to focus",
            goal: "Choose one STEM area and write a development plan.",
            whatItAccomplishes: "Make an informed decision.", whyItMatters: "Commitment leads to expertise.",
            actions: [A("stem-6-action-1"),A("stem-6-action-2"),A("stem-6-action-3"),A("stem-6-action-4")],
            skillsDeveloped: ["Goal Setting","Academic Planning","Decision Making","Communication"],
            completionCriteria: ["Complete all four actions.","Choose one area.","Write 3-6 month plan.","Discuss with at least one person."],
            dependencies: ["stem-5"], learningResources: [R("st6-res-1")], assessment: nil)
    ]),

    // ── 7. Leadership (6 milestones) ──
    TestRoadmap(id: "leadership", title: "Build Leadership Experience", milestones: [
        TestMilestone(id: "leadership-1", title: "Understand Leadership", subtitle: "Beyond titles",
            goal: "Explain leadership and identify 3 examples.",
            whatItAccomplishes: "Understand leadership is influence and initiative.", whyItMatters: "True leadership is a skill, not a position.",
            actions: [A("leadership-1-action-1"),A("leadership-1-action-2"),A("leadership-1-action-3")],
            skillsDeveloped: ["Leadership","Communication","Critical Thinking"],
            completionCriteria: ["Complete all three actions.","Identify 3 admired leaders.","Write leadership philosophy."],
            dependencies: [], learningResources: [R("l1-res-1"),R("l1-res-2")], assessment: nil),
        TestMilestone(id: "leadership-2", title: "Take Initiative", subtitle: "Start something",
            goal: "Identify a need and take concrete action.",
            whatItAccomplishes: "Practice taking initiative.", whyItMatters: "Initiative is the foundation of leadership.",
            actions: [A("leadership-2-action-1"),A("leadership-2-action-2"),A("leadership-2-action-3"),A("leadership-2-action-4")],
            skillsDeveloped: ["Initiative","Problem Solving","Communication","Planning"],
            completionCriteria: ["Complete all four actions.","Identify a real need.","Take concrete action.","Recruit at least one helper."],
            dependencies: ["leadership-1"], learningResources: [R("l2-res-1")], assessment: nil),
        TestMilestone(id: "leadership-3", title: "Lead a Small Project", subtitle: "Organize and deliver",
            goal: "Plan and complete a project with 2+ other people.",
            whatItAccomplishes: "Practice leading a project.", whyItMatters: "Leading teaches skills no reading can.",
            actions: [A("leadership-3-action-1"),A("leadership-3-action-2"),A("leadership-3-action-3"),A("leadership-3-action-4")],
            skillsDeveloped: ["Project Management","Collaboration","Planning","Problem Solving"],
            completionCriteria: ["Complete all four actions.","Write one-page plan.","Lead 2+ people.","Write a reflection."],
            dependencies: ["leadership-2"], learningResources: [R("l3-res-1"),R("l3-res-2")], assessment: nil),
        TestMilestone(id: "leadership-4", title: "Work With Others", subtitle: "Collaborate",
            goal: "Work with a diverse group and practice collaboration.",
            whatItAccomplishes: "Practice working with diverse people.", whyItMatters: "Leadership is about working with people.",
            actions: [A("leadership-4-action-1"),A("leadership-4-action-2"),A("leadership-4-action-3"),A("leadership-4-action-4")],
            skillsDeveloped: ["Collaboration","Communication","Public Speaking","Responsibility"],
            completionCriteria: ["Complete all four actions.","Join a group.","Practice active listening.","Give constructive feedback."],
            dependencies: ["leadership-3"], learningResources: [R("l4-res-1")], assessment: nil),
        TestMilestone(id: "leadership-5", title: "Create Measurable Impact", subtitle: "Make a difference",
            goal: "Lead an initiative creating a measurable positive outcome.",
            whatItAccomplishes: "Lead an initiative with measurable impact.", whyItMatters: "Impact is the ultimate measure of leadership.",
            actions: [A("leadership-5-action-1"),A("leadership-5-action-2"),A("leadership-5-action-3"),A("leadership-5-action-4")],
            skillsDeveloped: ["Leadership","Project Management","Impact Measurement","Planning"],
            completionCriteria: ["Complete all four actions.","Set measurable goals.","Execute initiative.","Document and report results."],
            dependencies: ["leadership-4"], learningResources: [R("l5-res-1"),R("l5-res-2")], assessment: nil),
        TestMilestone(id: "leadership-6", title: "Document Your Leadership", subtitle: "Record experience",
            goal: "Create a leadership portfolio documenting growth.",
            whatItAccomplishes: "Create documented record of leadership.", whyItMatters: "Undocumented experience is invisible.",
            actions: [A("leadership-6-action-1"),A("leadership-6-action-2"),A("leadership-6-action-3")],
            skillsDeveloped: ["Portfolio Development","Technical Communication","Personal Branding"],
            completionCriteria: ["Complete all three actions.","Write leadership summary.","Collect 3+ pieces of evidence.","Create shareable record."],
            dependencies: ["leadership-5"], learningResources: [R("l6-res-1"),R("l6-res-2")], assessment: nil)
    ]),

    // ── 8. Community Impact (6 milestones) ──
    TestRoadmap(id: "community-impact", title: "Build Community Impact", milestones: [
        TestMilestone(id: "community-1", title: "Understand Your Community", subtitle: "Real needs",
            goal: "Identify 3 real needs and understand the people affected.",
            whatItAccomplishes: "Understand real community needs.", whyItMatters: "Effective community work starts with understanding.",
            actions: [A("community-1-action-1"),A("community-1-action-2"),A("community-1-action-3"),A("community-1-action-4")],
            skillsDeveloped: ["Community Research","Critical Thinking","Communication","Research"],
            completionCriteria: ["Complete all four actions.","Identify 3 needs.","Talk to 3+ members.","Create resource map."],
            dependencies: [], learningResources: [R("cm1-res-1"),R("cm1-res-2")], assessment: nil),
        TestMilestone(id: "community-2", title: "Identify a Real Need", subtitle: "Focus on one",
            goal: "Select one need, research it, write a needs assessment.",
            whatItAccomplishes: "Choose one specific achievable problem.", whyItMatters: "Focusing is more effective.",
            actions: [A("community-2-action-1"),A("community-2-action-2"),A("community-2-action-3"),A("community-2-action-4")],
            skillsDeveloped: ["Problem Solving","Research","Critical Thinking","Writing"],
            completionCriteria: ["Complete all four actions.","Write problem statement.","Research existing solutions.","Write needs assessment."],
            dependencies: ["community-1"], learningResources: [R("cm2-res-1")], assessment: nil),
        TestMilestone(id: "community-3", title: "Design a Response", subtitle: "Plan a project",
            goal: "Create detailed project plan with goals, timeline, resources.",
            whatItAccomplishes: "Design a realistic project plan.", whyItMatters: "Good planning prevents wasted effort.",
            actions: [A("community-3-action-1"),A("community-3-action-2"),A("community-3-action-3"),A("community-3-action-4")],
            skillsDeveloped: ["Project Planning","Communication","Planning","Organization"],
            completionCriteria: ["Complete all four actions.","Write detailed plan.","Identify resources.","Get approval or support."],
            dependencies: ["community-2"], learningResources: [R("cm3-res-1")], assessment: nil),
        TestMilestone(id: "community-4", title: "Execute a Project", subtitle: "Make a difference",
            goal: "Execute the project and deliver measurable outcome.",
            whatItAccomplishes: "Execute project and manage team.", whyItMatters: "Execution is where plans become reality.",
            actions: [A("community-4-action-1"),A("community-4-action-2"),A("community-4-action-3"),A("community-4-action-4")],
            skillsDeveloped: ["Project Management","Collaboration","Problem Solving","Communication"],
            completionCriteria: ["Complete all four actions.","Execute from start to finish.","Document challenges.","Collect results."],
            dependencies: ["community-3"], learningResources: [R("cm4-res-1")], assessment: nil),
        TestMilestone(id: "community-5", title: "Measure the Impact", subtitle: "Assess results",
            goal: "Measure impact, collect feedback, write impact report.",
            whatItAccomplishes: "Evaluate project impact.", whyItMatters: "Without measurement you cannot know if you helped.",
            actions: [A("community-5-action-1"),A("community-5-action-2"),A("community-5-action-3"),A("community-5-action-4")],
            skillsDeveloped: ["Impact Measurement","Data Analysis","Technical Writing","Critical Thinking"],
            completionCriteria: ["Complete all four actions.","Collect quantitative and qualitative data.","Get beneficiary feedback.","Write impact report."],
            dependencies: ["community-4"], learningResources: [R("cm5-res-1")], assessment: nil),
        TestMilestone(id: "community-6", title: "Document & Continue the Work", subtitle: "Preserve work",
            goal: "Create documentation and plan for sustaining work.",
            whatItAccomplishes: "Document so others can learn or continue.", whyItMatters: "Impact can last if documented.",
            actions: [A("community-6-action-1"),A("community-6-action-2"),A("community-6-action-3")],
            skillsDeveloped: ["Technical Writing","Portfolio Development","Communication","Leadership"],
            completionCriteria: ["Complete all three actions.","Write project summary.","Create handoff document.","Share story with audience."],
            dependencies: ["community-5"], learningResources: [R("cm6-res-1")], assessment: nil)
    ]),

    // ── 9. Venture (6 milestones) ──
    TestRoadmap(id: "venture", title: "Explore Entrepreneurship", milestones: [
        TestMilestone(id: "venture-1", title: "Identify Problems", subtitle: "See problems",
            goal: "Identify 5 real problems and evaluate which are worth solving.",
            whatItAccomplishes: "Train yourself to notice problems.", whyItMatters: "Entrepreneurship starts with noticing.",
            actions: [A("venture-1-action-1"),A("venture-1-action-2"),A("venture-1-action-3")],
            skillsDeveloped: ["Problem Discovery","Critical Thinking","Research"],
            completionCriteria: ["Complete all three actions.","Identify 10+ problems.","Evaluate with criteria.","Research existing solutions."],
            dependencies: [], learningResources: [R("v1-res-1"),R("v1-res-2")], assessment: nil),
        TestMilestone(id: "venture-2", title: "Understand Users", subtitle: "Who you build for",
            goal: "Interview 3-5 people about a problem.",
            whatItAccomplishes: "Develop understanding of users.", whyItMatters: "Building something nobody wants is the most common failure.",
            actions: [A("venture-2-action-1"),A("venture-2-action-2"),A("venture-2-action-3"),A("venture-2-action-4")],
            skillsDeveloped: ["User Research","Communication","Critical Thinking","Empathy"],
            completionCriteria: ["Complete all four actions.","Interview 3+ people.","Document needs and pain points.","Validate the problem."],
            dependencies: ["venture-1"], learningResources: [R("v2-res-1")], assessment: nil),
        TestMilestone(id: "venture-3", title: "Develop Solutions", subtitle: "Brainstorm solutions",
            goal: "Generate 5+ solutions, evaluate them, select the most promising.",
            whatItAccomplishes: "Generate and evaluate solutions.", whyItMatters: "The first idea is rarely the best.",
            actions: [A("venture-3-action-1"),A("venture-3-action-2"),A("venture-3-action-3"),A("venture-3-action-4")],
            skillsDeveloped: ["Product Thinking","Critical Thinking","Decision Making","Communication"],
            completionCriteria: ["Complete all four actions.","Generate 5+ solutions.","Evaluate each idea.","Write value proposition."],
            dependencies: ["venture-2"], learningResources: [R("v3-res-1")], assessment: nil),
        TestMilestone(id: "venture-4", title: "Build a Prototype", subtitle: "Create minimum version",
            goal: "Build a working prototype someone can interact with.",
            whatItAccomplishes: "Build a basic prototype.", whyItMatters: "A prototype lets you test quickly.",
            actions: [A("venture-4-action-1"),A("venture-4-action-2"),A("venture-4-action-3"),A("venture-4-action-4")],
            skillsDeveloped: ["Prototyping","Building Things","User Research","Product Thinking"],
            completionCriteria: ["Complete all four actions.","Build interactive prototype.","Test with at least one person.","Document feedback."],
            dependencies: ["venture-3"], learningResources: [R("v4-res-1"),R("v4-res-2")], assessment: nil),
        TestMilestone(id: "venture-5", title: "Test & Iterate", subtitle: "Improve with feedback",
            goal: "Get feedback from 3-5 people, improve prototype.",
            whatItAccomplishes: "Gather feedback and iterate.", whyItMatters: "Iteration is how good ideas become great.",
            actions: [A("venture-5-action-1"),A("venture-5-action-2"),A("venture-5-action-3"),A("venture-5-action-4")],
            skillsDeveloped: ["Iteration","User Research","Product Thinking","Communication"],
            completionCriteria: ["Complete all four actions.","Get feedback from 3+ people.","Make 2+ improvements.","Test with new people."],
            dependencies: ["venture-4"], learningResources: [R("v5-res-1")], assessment: nil),
        TestMilestone(id: "venture-6", title: "Present the Venture", subtitle: "Communicate the idea",
            goal: "Create and deliver a clear venture presentation.",
            whatItAccomplishes: "Create a clear compelling presentation.", whyItMatters: "Even the best idea fails if you cannot explain it.",
            actions: [A("venture-6-action-1"),A("venture-6-action-2"),A("venture-6-action-3"),A("venture-6-action-4")],
            skillsDeveloped: ["Presentation","Communication","Technical Communication","Business Fundamentals"],
            completionCriteria: ["Complete all four actions.","Write venture description.","Create 5-10 slide presentation.","Present and get feedback."],
            dependencies: ["venture-5"], learningResources: [R("v6-res-1"),R("v6-res-2")], assessment: nil)
    ]),

    // ── 10. Competitive Profile (7 milestones) ──
    TestRoadmap(id: "competitive-profile", title: "Build a Competitive Student Profile", milestones: [
        TestMilestone(id: "profile-1", title: "Define Your Direction", subtitle: "Understand uniqueness",
            goal: "Identify top 3 interests, strongest skills, write mission statement.",
            whatItAccomplishes: "Clarify interests, strengths, goals.", whyItMatters: "Direction prevents scattered effort.",
            actions: [A("profile-1-action-1"),A("profile-1-action-2"),A("profile-1-action-3")],
            skillsDeveloped: ["Goal Setting","Self-Advocacy","Critical Thinking"],
            completionCriteria: ["Complete all three actions.","Identify top 3 interests and strengths.","Research competitive profiles.","Write mission statement."],
            dependencies: [], learningResources: [R("pr1-res-1")], assessment: nil),
        TestMilestone(id: "profile-2", title: "Build Strong Foundations", subtitle: "Academic record",
            goal: "Improve weakest academic areas and establish study habits.",
            whatItAccomplishes: "Ensure academic record is strong.", whyItMatters: "Strong academics are the foundation.",
            actions: [A("profile-2-action-1"),A("profile-2-action-2"),A("profile-2-action-3"),A("profile-2-action-4")],
            skillsDeveloped: ["Academic Planning","Time Management","Writing","Goal Setting"],
            completionCriteria: ["Complete all four actions.","Address weakest areas.","Take challenging courses.","Establish study system."],
            dependencies: ["profile-1"], learningResources: [R("pr2-res-1"),R("pr2-res-2")], assessment: nil),
        TestMilestone(id: "profile-3", title: "Develop Demonstrable Skills", subtitle: "Prove through work",
            goal: "Develop 2-3 demonstrable skills with evidence.",
            whatItAccomplishes: "Build specific demonstrable skills.", whyItMatters: "Claims are weak; evidence is strong.",
            actions: [A("profile-3-action-1"),A("profile-3-action-2"),A("profile-3-action-3"),A("profile-3-action-4")],
            skillsDeveloped: ["Technical Skills","Building Things","Portfolio Development","Documentation"],
            completionCriteria: ["Complete all four actions.","Develop 2-3 skills.","Create evidence of each.","Document skills inventory."],
            dependencies: ["profile-2"], learningResources: [R("pr3-res-1"),R("pr3-res-2")], assessment: nil),
        TestMilestone(id: "profile-4", title: "Create Meaningful Experiences", subtitle: "Activities record",
            goal: "Participate in 2-3 meaningful activities with leadership.",
            whatItAccomplishes: "Participate in meaningful activities.", whyItMatters: "Activities show who you are beyond grades.",
            actions: [A("profile-4-action-1"),A("profile-4-action-2"),A("profile-4-action-3"),A("profile-4-action-4")],
            skillsDeveloped: ["Leadership","Time Management","Communication","Planning"],
            completionCriteria: ["Complete all four actions.","Participate in 2-3 activities.","Take leadership role.","Document all experiences."],
            dependencies: ["profile-3"], learningResources: [R("pr4-res-1"),R("pr4-res-2")], assessment: nil),
        TestMilestone(id: "profile-5", title: "Build Leadership & Impact", subtitle: "Create change",
            goal: "Lead at least one initiative with measurable outcome.",
            whatItAccomplishes: "Lead projects creating measurable impact.", whyItMatters: "Leadership separates good from exceptional.",
            actions: [A("profile-5-action-1"),A("profile-5-action-2"),A("profile-5-action-3"),A("profile-5-action-4")],
            skillsDeveloped: ["Leadership","Project Management","Impact Measurement","Communication"],
            completionCriteria: ["Complete all four actions.","Lead from planning to completion.","Measure and document impact.","Reflect on growth."],
            dependencies: ["profile-4"], learningResources: [R("pr5-res-1")], assessment: nil),
        TestMilestone(id: "profile-6", title: "Document Your Achievements", subtitle: "Compelling narrative",
            goal: "Create complete achievements portfolio with narrative.",
            whatItAccomplishes: "Create complete record telling a story.", whyItMatters: "Undocumented achievements are invisible.",
            actions: [A("profile-6-action-1"),A("profile-6-action-2"),A("profile-6-action-3"),A("profile-6-action-4")],
            skillsDeveloped: ["Writing","Organization","Communication","Self-Advocacy"],
            completionCriteria: ["Complete all four actions.","Complete activities list.","Compelling personal statement.","Prepare recommenders and resume."],
            dependencies: ["profile-5"], learningResources: [R("pr6-res-1"),R("pr6-res-2")], assessment: nil),
        TestMilestone(id: "profile-7", title: "Build a Strong Student Portfolio", subtitle: "Polished presentation",
            goal: "Have a complete polished portfolio presenting your profile.",
            whatItAccomplishes: "Create comprehensive polished portfolio.", whyItMatters: "A complete portfolio turns achievements into power.",
            actions: [A("profile-7-action-1"),A("profile-7-action-2"),A("profile-7-action-3"),A("profile-7-action-4")],
            skillsDeveloped: ["Portfolio Development","Personal Branding","Technical Communication","Writing"],
            completionCriteria: ["Complete all four actions.","Complete portfolio with all sections.","Polished and error-free.","Get feedback and improve."],
            dependencies: ["profile-6"], learningResources: [R("pr7-res-1"),R("pr7-res-2")], assessment: nil)
    ])
]

// ── Derived flat data ──

let allRoadmapIDs = catalog.map { $0.id }
let allMilestoneIDs: [String] = catalog.flatMap { $0.milestones.map { $0.id } }
let allMilestoneIDsByRoadmap: [String: [String]] = Dictionary(
    uniqueKeysWithValues: catalog.map { ($0.id, $0.milestones.map { $0.id }) })
let allActionIDs: [String] = catalog.flatMap { $0.milestones.flatMap { $0.actions.map { $0.id } } }
let allResourceIDs: [String] = catalog.flatMap { $0.milestones.flatMap { $0.learningResources.map { $0.id } } }
let allAssessmentIDs: [String] = catalog.flatMap { roadmap in
    roadmap.milestones.compactMap { $0.assessment?.id }
}
let allQuestionIDs: [String] = catalog.flatMap { roadmap in
    roadmap.milestones.compactMap { milestone in
        milestone.assessment?.questions.map { $0.id }
    }.flatMap { $0 }
}
let allDependencyPairs: [(milestone: String, dependsOn: String)] = catalog.flatMap { roadmap in
    roadmap.milestones.flatMap { milestone in milestone.dependencies.map { (milestone.id, $0) } }
}
let allMilestoneIDSet: Set<String> = Set(allMilestoneIDs)
var allSkillNames: Set<String> = []
for roadmap in catalog {
    for milestone in roadmap.milestones {
        for skill in milestone.skillsDeveloped { allSkillNames.insert(skill) }
    }
}

let seRoadmap = catalog.first { $0.id == "software-engineer" }!
let seMilestoneIDs = seRoadmap.milestones.map { $0.id }
let seActionIDs = seRoadmap.milestones.flatMap { $0.actions.map { $0.id } }

// ══════════════════════════════════════════════
//  CATEGORY 1: Structure Tests (1–11)
// ══════════════════════════════════════════════

print("Structure Tests...")

// 1. All 10 roadmap IDs exist
assertEqual(allRoadmapIDs.count, 10, "1. Exactly 10 roadmaps exist")
for id in ["software-engineer","ai-engineer","research-builder","portfolio-projects",
           "college-ready","stem-explorer","leadership","community-impact",
           "venture","competitive-profile"] {
    assert(allRoadmapIDs.contains(id), "1. Roadmap '\(id)' exists")
}

// 2–11. Milestone counts and IDs per roadmap
let expectedMilestoneIDs: [String: [String]] = [
    "software-engineer": ["software-1","software-2","software-3","software-4","software-5","software-6"],
    "ai-engineer":       ["ai-1","ai-2","ai-3","ai-4","ai-5","ai-6"],
    "research-builder":  ["research-1","research-2","research-3","research-4","research-5","research-6"],
    "portfolio-projects":["portfolio-1","portfolio-2","portfolio-3","portfolio-4","portfolio-5","portfolio-6"],
    "college-ready":     ["college-1","college-2","college-3","college-4","college-5","college-6"],
    "stem-explorer":     ["stem-1","stem-2","stem-3","stem-4","stem-5","stem-6"],
    "leadership":        ["leadership-1","leadership-2","leadership-3","leadership-4","leadership-5","leadership-6"],
    "community-impact":  ["community-1","community-2","community-3","community-4","community-5","community-6"],
    "venture":           ["venture-1","venture-2","venture-3","venture-4","venture-5","venture-6"],
    "competitive-profile":["profile-1","profile-2","profile-3","profile-4","profile-5","profile-6","profile-7"]
]

for (roadmapID, expectedIDs) in expectedMilestoneIDs {
    let actual = allMilestoneIDsByRoadmap[roadmapID] ?? []
    assertEqual(actual, expectedIDs, "Milestone IDs for \(roadmapID)")
}

// ══════════════════════════════════════════════
//  CATEGORY 2: Content Quality Tests (12–16)
// ══════════════════════════════════════════════

print("Content Quality Tests...")

for roadmap in catalog {
    for milestone in roadmap.milestones {
        let p = "\(roadmap.id)/\(milestone.id)"
        // 12. Non-empty content fields
        assert(!milestone.title.isEmpty, "12. \(p) title non-empty")
        assert(!milestone.subtitle.isEmpty, "12. \(p) subtitle non-empty")
        assert(!milestone.goal.isEmpty, "12. \(p) goal non-empty")
        assert(!milestone.whatItAccomplishes.isEmpty, "12. \(p) whatItAccomplishes non-empty")
        assert(!milestone.whyItMatters.isEmpty, "12. \(p) whyItMatters non-empty")
        // 13. Actions 3–5
        let ac = milestone.actions.count
        assert(ac >= 3 && ac <= 5, "13. \(p) has \(ac) actions (need 3–5)")
        // 14. Skills >= 1
        assert(milestone.skillsDeveloped.count >= 1, "14. \(p) has \(milestone.skillsDeveloped.count) skills")
        // 15. Completion criteria >= 1
        assert(milestone.completionCriteria.count >= 1, "15. \(p) has \(milestone.completionCriteria.count) criteria")
        // 16. Learning resources >= 1
        assert(milestone.learningResources.count >= 1, "16. \(p) has \(milestone.learningResources.count) resources")
    }
}

// ══════════════════════════════════════════════
//  CATEGORY 3: ID Uniqueness Tests (17–20)
// ══════════════════════════════════════════════

print("ID Uniqueness Tests...")

func checkUniqueness(_ ids: [String], _ label: String) {
    var seen = Set<String>()
    var dupes: [String] = []
    for id in ids {
        if seen.contains(id) { dupes.append(id) }
        seen.insert(id)
    }
    assert(dupes.isEmpty, "\(label): duplicate IDs: \(dupes)")
}
checkUniqueness(allActionIDs, "17. Action IDs")
checkUniqueness(allResourceIDs, "18. Resource IDs")
checkUniqueness(allAssessmentIDs, "19. Assessment IDs")
checkUniqueness(allQuestionIDs, "20. Question IDs")

// ══════════════════════════════════════════════
//  CATEGORY 4: Dependency Tests (21–24)
// ══════════════════════════════════════════════

print("Dependency Tests...")

// 21. Every dependency ref points to an existing milestone
for (ms, dep) in allDependencyPairs {
    assert(allMilestoneIDSet.contains(dep), "21. \(ms) depends on '\(dep)' which does not exist")
}

// 22. No self-dependencies
for (ms, dep) in allDependencyPairs {
    assert(ms != dep, "22. \(ms) does not depend on itself")
}

// 23. No duplicate dependencies within a milestone
for roadmap in catalog {
    for milestone in roadmap.milestones {
        assert(Set(milestone.dependencies).count == milestone.dependencies.count,
               "23. \(milestone.id) has duplicate dependencies")
    }
}

// 24. No dependency cycles (DFS)
func hasCycle(_ graph: [String: [String]]) -> Bool {
    enum State { case unvisited, inProgress, done }
    var states: [String: State] = [:]
    for node in graph.keys { states[node] = .unvisited }
    func dfs(_ node: String) -> Bool {
        if states[node] == .inProgress { return true }
        if states[node] == .done { return false }
        states[node] = .inProgress
        for dep in graph[node] ?? [] { if dfs(dep) { return true } }
        states[node] = .done
        return false
    }
    for node in graph.keys {
        if states[node] == .unvisited && dfs(node) { return true }
    }
    return false
}
var depGraph: [String: [String]] = [:]
for roadmap in catalog {
    for milestone in roadmap.milestones { depGraph[milestone.id] = milestone.dependencies }
}
assert(!hasCycle(depGraph), "24. No dependency cycles")

// ══════════════════════════════════════════════
//  CATEGORY 5: Activation Tests (25–28)
// ══════════════════════════════════════════════

print("Activation Tests...")

// 25. All 10 can be activated, startRoadmap is idempotent
let store25 = SimulatedStore()
for roadmap in catalog { store25.startRoadmap(roadmap) }
for roadmap in catalog {
    assert(store25.isActivated(roadmap.id), "25. '\(roadmap.id)' activated")
}
assertEqual(store25.activeRoadmaps.count, 10, "25. All 10 active")
for roadmap in catalog { store25.startRoadmap(roadmap) }
assertEqual(store25.activeRoadmaps.count, 10, "25. Idempotent: still 10")

// 26. Activation persists across simulated reload
let store26 = SimulatedStore()
for roadmap in catalog { store26.startRoadmap(roadmap) }
let persisted = store26.activeRoadmaps
let store26b = SimulatedStore()
store26b.activeRoadmaps = persisted
for roadmap in catalog {
    assert(store26b.isActivated(roadmap.id), "26. '\(roadmap.id)' persists")
}

// 27. Deactivation preserves progress
let store27 = SimulatedStore()
store27.roadmapProgress["software-engineer"] = 3
store27.startRoadmap(seRoadmap)
assertEqual(store27.completedCount(for: seRoadmap), 3, "27. Progress before deactivate")
store27.deactivateRoadmap("software-engineer")
assert(!store27.isActivated("software-engineer"), "27. Deactivated")
assertEqual(store27.completedCount(for: seRoadmap), 3, "27. Progress preserved after deactivate")

// 28. All SE milestone IDs preserved exactly
assertEqual(seMilestoneIDs, ["software-1","software-2","software-3","software-4","software-5","software-6"],
            "28. SE milestone IDs preserved")
let expectedSEActions = [
    "software-1-action-1","software-1-action-2","software-1-action-3","software-1-action-4",
    "software-2-action-1","software-2-action-2","software-2-action-3","software-2-action-4",
    "software-3-action-1","software-3-action-2","software-3-action-3","software-3-action-4",
    "software-4-action-1","software-4-action-2","software-4-action-3","software-4-action-4",
    "software-5-action-1","software-5-action-2","software-5-action-3",
    "software-6-action-1","software-6-action-2","software-6-action-3","software-6-action-4"
]
assertEqual(seActionIDs, expectedSEActions, "28. SE action IDs preserved")

// ══════════════════════════════════════════════
//  CATEGORY 6: Skill Consistency Test (29)
// ══════════════════════════════════════════════

print("Skill Consistency Tests...")

// 29. No near-duplicate skill names
// Group skills by first word, check for 3+ communication/writing/presentation variants
let commSynonyms: Set<String> = ["communication","writing","presentation","speaking","documentation","expression"]
var skillsByFirstWord: [String: [String]] = [:]
for skill in allSkillNames {
    let words = skill.lowercased().split(separator: " ").map(String.init)
    if words.count >= 2 {
        skillsByFirstWord[words[0], default: []].append(skill)
    }
}
for (firstWord, skills) in skillsByFirstWord {
    let commSkills = skills.filter { skill in
        let words = skill.lowercased().split(separator: " ").map(String.init)
        return words.count >= 2 && commSynonyms.contains(words[1])
    }
    assert(commSkills.count < 3,
           "29. Too many communication-type skills starting with '\(firstWord)': \(commSkills)")
}

// ══════════════════════════════════════════════
//  CATEGORY 7: Backward Compatibility (30)
// ══════════════════════════════════════════════

print("Backward Compatibility Tests...")

// 30. Original software-engineer IDs exactly preserved
let expectedSEIDs = ["software-1","software-2","software-3","software-4","software-5","software-6"]
assertEqual(seMilestoneIDs, expectedSEIDs, "30. SE milestone IDs unchanged")
assertEqual(seRoadmap.id, "software-engineer", "30. SE roadmap ID unchanged")
assertEqual(seRoadmap.title, "Become a Software Engineer", "30. SE roadmap title unchanged")

// Verify SE assessment IDs
let seAssessments = seRoadmap.milestones.compactMap { $0.assessment?.id }
let expectedSEAssessments = ["sw1-assessment","sw2-assessment","sw3-assessment","sw4-assessment","sw5-assessment","sw6-assessment"]
assertEqual(seAssessments, expectedSEAssessments, "30. SE assessment IDs unchanged")

// Verify SE resource IDs
let seResources = seRoadmap.milestones.flatMap { $0.learningResources.map { $0.id } }
let expectedSEResources = [
    "sw1-res-1","sw1-res-2","sw1-res-3",
    "sw2-res-1","sw2-res-2","sw2-res-3",
    "sw3-res-1","sw3-res-2","sw3-res-3",
    "sw4-res-1","sw4-res-2","sw4-res-3",
    "sw5-res-1","sw5-res-2","sw5-res-3",
    "sw6-res-1","sw6-res-2","sw6-res-3"
]
assertEqual(seResources, expectedSEResources, "30. SE resource IDs unchanged")

// Verify SE question IDs
let seQuestions = seRoadmap.milestones.compactMap { $0.assessment?.questions.map { $0.id } }
let flatSEQuestions = seQuestions.flatMap { $0 }
let expectedSEQuestions = [
    "sw1-q1","sw1-q2","sw1-q3",
    "sw2-q1","sw2-q2","sw2-q3","sw2-q4",
    "sw3-q1","sw3-q2","sw3-q3","sw3-q4",
    "sw4-q1","sw4-q2","sw4-q3","sw4-q4",
    "sw5-q1","sw5-q2","sw5-q3",
    "sw6-q1","sw6-q2","sw6-q3"
]
assertEqual(flatSEQuestions, expectedSEQuestions, "30. SE question IDs unchanged")

// ══════════════════════════════════════════════
//  SUMMARY
// ══════════════════════════════════════════════

print("\nPhase 6.4.9 — Expanded Roadmap Catalog: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
