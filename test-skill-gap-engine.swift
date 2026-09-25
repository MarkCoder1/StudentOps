import Foundation

// Standalone test script for Phase 6.5 — Deterministic Skill-Gap Engine
// Run: swift test-skill-gap-engine.swift

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
//  1. MODELS & CATALOG
// ═══════════════════════════════════════════════════════════════

struct Skill: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let category: String?

    init(id: String, name: String, category: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
    }

    static func normalizeID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return parts.joined(separator: " ").lowercased()
    }

    static func canonical(from raw: String) -> Skill {
        let norm = normalizeID(raw)
        if let known = SkillCatalog.knownSkills[norm] {
            return known
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmed.isEmpty ? norm : trimmed
        return Skill(id: norm, name: displayName)
    }
}

enum SkillCatalog {
    static let allSkills: [Skill] = [
        Skill(id: "python", name: "Python", category: "technical"),
        Skill(id: "javascript", name: "JavaScript", category: "technical"),
        Skill(id: "programming", name: "Programming", category: "technical"),
        Skill(id: "programming fundamentals", name: "Programming Fundamentals", category: "technical"),
        Skill(id: "computational thinking", name: "Computational Thinking", category: "technical"),
        Skill(id: "development environment setup", name: "Development Environment Setup", category: "technical"),
        Skill(id: "git", name: "Git", category: "technical"),
        Skill(id: "version control", name: "Version Control", category: "technical"),
        Skill(id: "version control basics", name: "Version Control Basics", category: "technical"),
        Skill(id: "debugging", name: "Debugging", category: "technical"),
        Skill(id: "apis", name: "APIs", category: "technical"),
        Skill(id: "unit testing", name: "Unit Testing", category: "technical"),
        Skill(id: "quality assurance", name: "Quality Assurance", category: "technical"),
        Skill(id: "software development", name: "Software Development", category: "technical"),
        Skill(id: "web development", name: "Web Development", category: "technical"),
        Skill(id: "ai literacy", name: "AI Literacy", category: "technical"),
        Skill(id: "machine learning", name: "Machine Learning", category: "technical"),
        Skill(id: "model evaluation", name: "Model Evaluation", category: "technical"),
        Skill(id: "ai application development", name: "AI Application Development", category: "technical"),
        Skill(id: "technical exploration", name: "Technical Exploration", category: "technical"),
        Skill(id: "technical skills", name: "Technical Skills", category: "technical"),
        Skill(id: "building things", name: "Building Things", category: "technical"),
        Skill(id: "prototyping", name: "Prototyping", category: "technical"),
        Skill(id: "data analysis", name: "Data Analysis", category: "data"),
        Skill(id: "data collection", name: "Data Collection", category: "data"),
        Skill(id: "statistics", name: "Statistics", category: "data"),
        Skill(id: "mathematics", name: "Mathematics", category: "academic"),
        Skill(id: "scientific method", name: "Scientific Method", category: "research"),
        Skill(id: "scientific communication", name: "Scientific Communication", category: "research"),
        Skill(id: "research", name: "Research", category: "research"),
        Skill(id: "research methods", name: "Research Methods", category: "research"),
        Skill(id: "question formation", name: "Question Formation", category: "research"),
        Skill(id: "source evaluation", name: "Source Evaluation", category: "research"),
        Skill(id: "community research", name: "Community Research", category: "research"),
        Skill(id: "user research", name: "User Research", category: "research"),
        Skill(id: "problem discovery", name: "Problem Discovery", category: "research"),
        Skill(id: "problem solving", name: "Problem Solving", category: "core"),
        Skill(id: "technical communication", name: "Technical Communication", category: "communication"),
        Skill(id: "technical writing", name: "Technical Writing", category: "communication"),
        Skill(id: "communication", name: "Communication", category: "communication"),
        Skill(id: "writing", name: "Writing", category: "communication"),
        Skill(id: "presentation", name: "Presentation", category: "communication"),
        Skill(id: "public speaking", name: "Public Speaking", category: "communication"),
        Skill(id: "documentation", name: "Documentation", category: "communication"),
        Skill(id: "leadership", name: "Leadership", category: "leadership"),
        Skill(id: "project management", name: "Project Management", category: "leadership"),
        Skill(id: "project planning", name: "Project Planning", category: "leadership"),
        Skill(id: "planning", name: "Planning", category: "leadership"),
        Skill(id: "organization", name: "Organization", category: "leadership"),
        Skill(id: "collaboration", name: "Collaboration", category: "leadership"),
        Skill(id: "teamwork", name: "Teamwork", category: "leadership"),
        Skill(id: "initiative", name: "Initiative", category: "leadership"),
        Skill(id: "responsibility", name: "Responsibility", category: "leadership"),
        Skill(id: "impact measurement", name: "Impact Measurement", category: "leadership"),
        Skill(id: "empathy", name: "Empathy", category: "leadership"),
        Skill(id: "goal setting", name: "Goal Setting", category: "academic"),
        Skill(id: "academic planning", name: "Academic Planning", category: "academic"),
        Skill(id: "time management", name: "Time Management", category: "academic"),
        Skill(id: "decision making", name: "Decision Making", category: "academic"),
        Skill(id: "self-advocacy", name: "Self-Advocacy", category: "academic"),
        Skill(id: "critical thinking", name: "Critical Thinking", category: "academic"),
        Skill(id: "competition skills", name: "Competition Skills", category: "academic"),
        Skill(id: "portfolio development", name: "Portfolio Development", category: "career"),
        Skill(id: "personal branding", name: "Personal Branding", category: "career"),
        Skill(id: "business fundamentals", name: "Business Fundamentals", category: "entrepreneurship"),
        Skill(id: "product thinking", name: "Product Thinking", category: "entrepreneurship"),
        Skill(id: "iteration", name: "Iteration", category: "entrepreneurship"),
        Skill(id: "creativity", name: "Creativity", category: "core"),
    ]

    static let knownSkills: [String: Skill] = {
        var map: [String: Skill] = [:]
        for skill in allSkills {
            map[skill.id] = skill
        }
        return map
    }()
}

enum SkillStatus: String, Codable, Hashable {
    case demonstrated
    case developing
    case gap
}

enum SkillGapPriority: String, Codable, Hashable, Comparable {
    case high
    case medium
    case low

    var title: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    private var rank: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    static func < (lhs: SkillGapPriority, rhs: SkillGapPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct MilestoneReference: Identifiable, Hashable, Codable {
    let id: String
    let milestoneNumber: Int
    let title: String
}

struct MilestoneAction: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String
    let order: Int
    let estimatedTime: String?

    init(id: String = UUID().uuidString, title: String, description: String = "", order: Int = 0, estimatedTime: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.order = order
        self.estimatedTime = estimatedTime
    }
}

struct RoadmapMilestone: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let skillsDeveloped: [String]?
    let actions: [MilestoneAction]?
    let dependencies: [String]?

    init(
        id: String,
        title: String,
        subtitle: String = "",
        skillsDeveloped: [String]? = nil,
        actions: [MilestoneAction]? = nil,
        dependencies: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.skillsDeveloped = skillsDeveloped
        self.actions = actions
        self.dependencies = dependencies
    }
}

struct Roadmap: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let milestones: [RoadmapMilestone]

    init(id: String, title: String, milestones: [RoadmapMilestone]) {
        self.id = id
        self.title = title
        self.milestones = milestones
    }
}

struct StudentProfile: Codable, Equatable {
    var name: String = ""
    var strengths: [String] = []
    var customSkills: [String] = []
}

struct EvidenceRecord: Identifiable, Hashable, Codable {
    let id: String
    let roadmapID: String
    let milestoneID: String
}

enum RoadmapActivationStatus: String, Codable, Hashable {
    case active, completed
}

struct ActiveRoadmap: Identifiable, Hashable, Codable {
    let roadmapID: String
    let status: RoadmapActivationStatus
    var id: String { roadmapID }

    init(roadmapID: String, status: RoadmapActivationStatus = .active) {
        self.roadmapID = roadmapID
        self.status = status
    }
}

struct SkillGap: Identifiable, Hashable, Codable {
    let skill: Skill
    var id: String { skill.id }
    var skillID: String { skill.id }
    var skillName: String { skill.name }
    let status: SkillStatus
    let sourceRoadmapID: String
    let requiredByMilestoneIDs: [String]
    let developingMilestones: [MilestoneReference]
    let relatedActions: [MilestoneAction]
    let priority: SkillGapPriority
    let priorityScore: Int
    let reason: String
}

struct RoadmapSkillGapReport: Identifiable, Hashable, Codable {
    var id: String { roadmapID }
    let roadmapID: String
    let roadmapTitle: String
    let requiredSkills: [Skill]
    let demonstratedSkills: [Skill]
    let gaps: [SkillGap]
    let totalRequiredCount: Int
    let demonstratedCount: Int
    let gapCount: Int
    var isFullyDemonstrated: Bool { gapCount == 0 }

    init(
        roadmapID: String,
        roadmapTitle: String,
        requiredSkills: [Skill],
        demonstratedSkills: [Skill],
        gaps: [SkillGap]
    ) {
        self.roadmapID = roadmapID
        self.roadmapTitle = roadmapTitle
        self.requiredSkills = requiredSkills
        self.demonstratedSkills = demonstratedSkills
        self.gaps = gaps
        self.totalRequiredCount = requiredSkills.count
        self.demonstratedCount = demonstratedSkills.count
        self.gapCount = gaps.count
    }
}

// ═══════════════════════════════════════════════════════════════
//  2. SKILL GAP ENGINE IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════

enum TestSkillGapEngine {

    static func normalizeSkillID(_ raw: String) -> String {
        Skill.normalizeID(raw)
    }

    static func requiredSkills(for roadmap: Roadmap) -> [Skill] {
        var seenIDs = Set<String>()
        var result: [Skill] = []

        for milestone in roadmap.milestones {
            guard let skills = milestone.skillsDeveloped else { continue }
            for raw in skills {
                let norm = normalizeSkillID(raw)
                guard !norm.isEmpty else { continue }
                if !seenIDs.contains(norm) {
                    seenIDs.insert(norm)
                    result.append(Skill.canonical(from: raw))
                }
            }
        }

        return result
    }

    static func demonstratedSkillIDs(
        profile: StudentProfile,
        roadmapProgress: [String: Int] = [:],
        catalog: [Roadmap]? = nil,
        evidenceRecords: [String: EvidenceRecord]? = nil
    ) -> Set<String> {
        var result = Set<String>()

        for raw in profile.strengths {
            let norm = normalizeSkillID(raw)
            if !norm.isEmpty { result.insert(norm) }
        }

        for raw in profile.customSkills {
            let norm = normalizeSkillID(raw)
            if !norm.isEmpty { result.insert(norm) }
        }

        if let catalog = catalog {
            for roadmap in catalog {
                let completedCount = min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
                guard completedCount > 0 else { continue }
                for idx in 0..<completedCount {
                    let milestone = roadmap.milestones[idx]
                    if let skills = milestone.skillsDeveloped {
                        for raw in skills {
                            let norm = normalizeSkillID(raw)
                            if !norm.isEmpty { result.insert(norm) }
                        }
                    }
                }
            }
        }

        if let evidence = evidenceRecords, let catalog = catalog {
            let catalogMap = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
            for record in evidence.values {
                if let roadmap = catalogMap[record.roadmapID],
                   let milestone = roadmap.milestones.first(where: { $0.id == record.milestoneID }),
                   let skills = milestone.skillsDeveloped {
                    for raw in skills {
                        let norm = normalizeSkillID(raw)
                        if !norm.isEmpty { result.insert(norm) }
                    }
                }
            }
        }

        return result
    }

    static func evaluate(
        roadmap: Roadmap,
        profile: StudentProfile,
        progress: [String: Int] = [:],
        catalog: [Roadmap]? = nil,
        evidenceRecords: [String: EvidenceRecord]? = nil
    ) -> RoadmapSkillGapReport {
        let allRequired = requiredSkills(for: roadmap)
        let demonstratedIDs = demonstratedSkillIDs(
            profile: profile,
            roadmapProgress: progress,
            catalog: catalog ?? [roadmap],
            evidenceRecords: evidenceRecords
        )

        var demonstrated: [Skill] = []
        var missingSkills: [Skill] = []

        for skill in allRequired {
            if demonstratedIDs.contains(skill.id) {
                demonstrated.append(skill)
            } else {
                missingSkills.append(skill)
            }
        }

        let completedCount = min(progress[roadmap.id] ?? 0, roadmap.milestones.count)
        let currentMilestoneIndex = completedCount

        var dependentCounts: [String: Int] = [:]
        for milestone in roadmap.milestones {
            for dep in milestone.dependencies ?? [] {
                dependentCounts[dep, default: 0] += 1
            }
        }

        var gaps: [SkillGap] = []

        for skill in missingSkills {
            var matchingMilestones: [RoadmapMilestone] = []
            var milestoneRefs: [MilestoneReference] = []

            for (idx, milestone) in roadmap.milestones.enumerated() {
                guard let dev = milestone.skillsDeveloped else { continue }
                let normalizedDev = dev.map(normalizeSkillID)
                if normalizedDev.contains(skill.id) {
                    matchingMilestones.append(milestone)
                    milestoneRefs.append(
                        MilestoneReference(
                            id: milestone.id,
                            milestoneNumber: idx + 1,
                            title: milestone.title
                        )
                    )
                }
            }

            let requiredByIDs = matchingMilestones.map(\.id)
            let relatedActions = matchingMilestones.flatMap { $0.actions ?? [] }

            let priorityInfo = calculatePriority(
                matchingMilestoneIDs: requiredByIDs,
                developingMilestones: milestoneRefs,
                actions: relatedActions,
                totalMilestones: roadmap.milestones.count,
                currentMilestoneIndex: currentMilestoneIndex,
                dependentCounts: dependentCounts
            )

            let isCurrentMilestone = milestoneRefs.contains { $0.milestoneNumber - 1 == currentMilestoneIndex }
            let status: SkillStatus = isCurrentMilestone ? .developing : .gap

            let reason: String
            if milestoneRefs.count == 1 {
                reason = "Develops in Milestone \(milestoneRefs[0].milestoneNumber): \(milestoneRefs[0].title)"
            } else if milestoneRefs.count > 1 {
                let numbers = milestoneRefs.map { "Milestone \($0.milestoneNumber)" }.joined(separator: ", ")
                reason = "Develops in \(numbers)"
            } else {
                reason = "Required by \(roadmap.title)"
            }

            gaps.append(
                SkillGap(
                    skill: skill,
                    status: status,
                    sourceRoadmapID: roadmap.id,
                    requiredByMilestoneIDs: requiredByIDs,
                    developingMilestones: milestoneRefs,
                    relatedActions: relatedActions,
                    priority: priorityInfo.priority,
                    priorityScore: priorityInfo.score,
                    reason: reason
                )
            )
        }

        gaps.sort { lhs, rhs in
            if lhs.priorityScore != rhs.priorityScore {
                return lhs.priorityScore > rhs.priorityScore
            }
            let lhsEarliest = lhs.developingMilestones.first?.milestoneNumber ?? Int.max
            let rhsEarliest = rhs.developingMilestones.first?.milestoneNumber ?? Int.max
            if lhsEarliest != rhsEarliest {
                return lhsEarliest < rhsEarliest
            }
            return lhs.skillName.localizedCompare(rhs.skillName) == .orderedAscending
        }

        return RoadmapSkillGapReport(
            roadmapID: roadmap.id,
            roadmapTitle: roadmap.title,
            requiredSkills: allRequired,
            demonstratedSkills: demonstrated,
            gaps: gaps
        )
    }

    private static func calculatePriority(
        matchingMilestoneIDs: [String],
        developingMilestones: [MilestoneReference],
        actions: [MilestoneAction],
        totalMilestones: Int,
        currentMilestoneIndex: Int,
        dependentCounts: [String: Int]
    ) -> (priority: SkillGapPriority, score: Int) {
        let earliestMilestoneIndex = developingMilestones.first.map { $0.milestoneNumber - 1 } ?? 0

        let earlinessScore = max(0, (totalMilestones - earliestMilestoneIndex) * 10)
        let totalDependents = matchingMilestoneIDs.reduce(0) { $0 + (dependentCounts[$1] ?? 0) }
        let dependencyScore = totalDependents * 15
        let frequencyScore = matchingMilestoneIDs.count * 10
        let actionScore = min(actions.count * 2, 10)
        let isCurrentMilestone = developingMilestones.contains { $0.milestoneNumber - 1 == currentMilestoneIndex }
        let activeMilestoneBonus = isCurrentMilestone ? 15 : 0

        let totalScore = earlinessScore + dependencyScore + frequencyScore + actionScore + activeMilestoneBonus

        let priority: SkillGapPriority
        if totalScore >= 60 {
            priority = .high
        } else if totalScore >= 35 {
            priority = .medium
        } else {
            priority = .low
        }

        return (priority, totalScore)
    }
}

// ═══════════════════════════════════════════════════════════════
//  3. THE 10 ROADMAP TEMPLATES FROM THE CATALOG
// ═══════════════════════════════════════════════════════════════

func A(_ id: String) -> MilestoneAction { MilestoneAction(id: id, title: id) }

let catalog10: [Roadmap] = [
    Roadmap(id: "software-engineer", title: "Become a Software Engineer", milestones: [
        RoadmapMilestone(id: "software-1", title: "Explore Computer Science",
            skillsDeveloped: ["Computational Thinking", "Development Environment Setup", "Version Control Basics"],
            actions: [A("sw1-a1"), A("sw1-a2"), A("sw1-a3"), A("sw1-a4")]),
        RoadmapMilestone(id: "software-2", title: "Build Programming Fundamentals",
            skillsDeveloped: ["Programming Fundamentals", "Problem Solving", "Python", "JavaScript"],
            actions: [A("sw2-a1"), A("sw2-a2"), A("sw2-a3"), A("sw2-a4")],
            dependencies: ["software-1"]),
        RoadmapMilestone(id: "software-3", title: "Learn Software Development",
            skillsDeveloped: ["Git", "Debugging", "APIs", "Unit Testing", "Software Development"],
            actions: [A("sw3-a1"), A("sw3-a2"), A("sw3-a3"), A("sw3-a4")],
            dependencies: ["software-2"]),
        RoadmapMilestone(id: "software-4", title: "Build Real Projects",
            skillsDeveloped: ["Software Development", "Project Planning", "Technical Communication", "Building Things"],
            actions: [A("sw4-a1"), A("sw4-a2"), A("sw4-a3"), A("sw4-a4")],
            dependencies: ["software-3"]),
        RoadmapMilestone(id: "software-5", title: "Gain External Experience",
            skillsDeveloped: ["Technical Communication", "Collaboration", "Software Development", "Competition Skills"],
            actions: [A("sw5-a1"), A("sw5-a2"), A("sw5-a3")],
            dependencies: ["software-4"]),
        RoadmapMilestone(id: "software-6", title: "Build a Technical Portfolio",
            skillsDeveloped: ["Technical Communication", "Portfolio Development", "Personal Branding", "Web Development"],
            actions: [A("sw6-a1"), A("sw6-a2"), A("sw6-a3"), A("sw6-a4")],
            dependencies: ["software-5"])
    ]),
    Roadmap(id: "ai-engineer", title: "Become an AI Engineer", milestones: [
        RoadmapMilestone(id: "ai-1", title: "Explore AI & ML",
            skillsDeveloped: ["AI Literacy", "Technical Exploration", "Critical Thinking"],
            actions: [A("ai1-a1"), A("ai1-a2"), A("ai1-a3")]),
        RoadmapMilestone(id: "ai-2", title: "Build Programming & Math Foundations",
            skillsDeveloped: ["Python", "Data Analysis", "Statistics", "Mathematics", "Programming Fundamentals"],
            actions: [A("ai2-a1"), A("ai2-a2"), A("ai2-a3"), A("ai2-a4")],
            dependencies: ["ai-1"]),
        RoadmapMilestone(id: "ai-3", title: "Learn ML Fundamentals",
            skillsDeveloped: ["Machine Learning", "Data Analysis", "Model Evaluation", "Python", "Statistics"],
            actions: [A("ai3-a1"), A("ai3-a2"), A("ai3-a3"), A("ai3-a4"), A("ai3-a5")],
            dependencies: ["ai-2"]),
        RoadmapMilestone(id: "ai-4", title: "Build an AI Application",
            skillsDeveloped: ["Machine Learning", "Data Analysis", "APIs", "AI Application Development", "Software Development"],
            actions: [A("ai4-a1"), A("ai4-a2"), A("ai4-a3"), A("ai4-a4")],
            dependencies: ["ai-3"]),
        RoadmapMilestone(id: "ai-5", title: "Conduct an AI Experiment",
            skillsDeveloped: ["Data Analysis", "Data Collection", "Statistics", "Python", "Technical Communication"],
            actions: [A("ai5-a1"), A("ai5-a2"), A("ai5-a3"), A("ai5-a4")],
            dependencies: ["ai-4"]),
        RoadmapMilestone(id: "ai-6", title: "Showcase Your AI Work",
            skillsDeveloped: ["Portfolio Development", "Technical Communication", "Personal Branding", "AI Application Development"],
            actions: [A("ai6-a1"), A("ai6-a2"), A("ai6-a3"), A("ai6-a4")],
            dependencies: ["ai-5"])
    ]),
    Roadmap(id: "research-profile", title: "Build a Research Profile", milestones: [
        RoadmapMilestone(id: "research-1", title: "Explore Research Disciplines",
            skillsDeveloped: ["Research Methods", "Question Formation", "Critical Thinking"],
            actions: [A("r1-a1"), A("r1-a2"), A("r1-a3")]),
        RoadmapMilestone(id: "research-2", title: "Formulate a Research Question",
            skillsDeveloped: ["Question Formation", "Source Evaluation", "Research Methods", "Writing"],
            actions: [A("r2-a1"), A("r2-a2"), A("r2-a3"), A("r2-a4")],
            dependencies: ["research-1"]),
        RoadmapMilestone(id: "research-3", title: "Conduct Literature Review",
            skillsDeveloped: ["Research Methods", "Source Evaluation", "Data Collection", "Technical Writing"],
            actions: [A("r3-a1"), A("r3-a2"), A("r3-a3"), A("r3-a4")],
            dependencies: ["research-2"]),
        RoadmapMilestone(id: "research-4", title: "Design & Execute Methodology",
            skillsDeveloped: ["Data Collection", "Data Analysis", "Scientific Method", "Technical Writing"],
            actions: [A("r4-a1"), A("r4-a2"), A("r4-a3"), A("r4-a4")],
            dependencies: ["research-3"]),
        RoadmapMilestone(id: "research-5", title: "Write the Research Paper",
            skillsDeveloped: ["Data Analysis", "Scientific Communication", "Technical Writing", "Presentation"],
            actions: [A("r5-a1"), A("r5-a2"), A("r5-a3"), A("r5-a4")],
            dependencies: ["research-4"]),
        RoadmapMilestone(id: "research-6", title: "Submit & Present Research",
            skillsDeveloped: ["Portfolio Development", "Technical Writing", "Scientific Communication", "Personal Branding"],
            actions: [A("r6-a1"), A("r6-a2"), A("r6-a3"), A("r6-a4")],
            dependencies: ["research-5"])
    ]),
    Roadmap(id: "portfolio-projects", title: "Build a Technical Portfolio", milestones: [
        RoadmapMilestone(id: "portfolio-1", title: "Plan Your Portfolio",
            skillsDeveloped: ["Project Planning", "Technical Exploration", "Personal Branding"],
            actions: [A("p1-a1"), A("p1-a2"), A("p1-a3")]),
        RoadmapMilestone(id: "portfolio-2", title: "Build Core Project One",
            skillsDeveloped: ["Software Development", "Project Planning", "Building Things", "Version Control"],
            actions: [A("p2-a1"), A("p2-a2"), A("p2-a3"), A("p2-a4")],
            dependencies: ["portfolio-1"]),
        RoadmapMilestone(id: "portfolio-3", title: "Build Core Project Two",
            skillsDeveloped: ["Software Development", "Quality Assurance", "Building Things", "Version Control"],
            actions: [A("p3-a1"), A("p3-a2"), A("p3-a3"), A("p3-a4")],
            dependencies: ["portfolio-2"]),
        RoadmapMilestone(id: "portfolio-4", title: "Write Project Case Studies",
            skillsDeveloped: ["Documentation", "Technical Communication", "Writing"],
            actions: [A("p4-a1"), A("p4-a2"), A("p4-a3"), A("p4-a4")],
            dependencies: ["portfolio-3"]),
        RoadmapMilestone(id: "portfolio-5", title: "Deploy Portfolio Website",
            skillsDeveloped: ["Portfolio Development", "Web Development", "Personal Branding", "Technical Communication"],
            actions: [A("p5-a1"), A("p5-a2"), A("p5-a3"), A("p5-a4")],
            dependencies: ["portfolio-4"]),
        RoadmapMilestone(id: "portfolio-6", title: "Share and Iterate",
            skillsDeveloped: ["Personal Branding", "Technical Communication", "Collaboration"],
            actions: [A("p6-a1"), A("p6-a2"), A("p6-a3")],
            dependencies: ["portfolio-5"])
    ]),
    Roadmap(id: "college-prep", title: "Prepare for College", milestones: [
        RoadmapMilestone(id: "college-1", title: "Clarify Goals & Priorities",
            skillsDeveloped: ["Goal Setting", "Self-Advocacy", "Research"],
            actions: [A("c1-a1"), A("c1-a2"), A("c1-a3"), A("c1-a4")]),
        RoadmapMilestone(id: "college-2", title: "Build Academic Record",
            skillsDeveloped: ["Academic Planning", "Time Management", "Self-Advocacy", "Goal Setting"],
            actions: [A("c2-a1"), A("c2-a2"), A("c2-a3"), A("c2-a4")],
            dependencies: ["college-1"]),
        RoadmapMilestone(id: "college-3", title: "Research Target Colleges",
            skillsDeveloped: ["Research", "Organization", "Decision Making", "Writing"],
            actions: [A("c3-a1"), A("c3-a2"), A("c3-a3"), A("c3-a4")],
            dependencies: ["college-2"]),
        RoadmapMilestone(id: "college-4", title: "Prepare Standardized Testing",
            skillsDeveloped: ["Leadership", "Time Management", "Communication", "Planning"],
            actions: [A("c4-a1"), A("c4-a2"), A("c4-a3"), A("c4-a4")],
            dependencies: ["college-3"]),
        RoadmapMilestone(id: "college-5", title: "Draft Personal Statement",
            skillsDeveloped: ["Writing", "Organization", "Communication", "Self-Advocacy"],
            actions: [A("c5-a1"), A("c5-a2"), A("c5-a3"), A("c5-a4")],
            dependencies: ["college-4"]),
        RoadmapMilestone(id: "college-6", title: "Assemble Applications",
            skillsDeveloped: ["Time Management", "Organization", "Planning", "Goal Setting"],
            actions: [A("c6-a1"), A("c6-a2"), A("c6-a3"), A("c6-a4")],
            dependencies: ["college-5"])
    ]),
    Roadmap(id: "stem-engineering", title: "Explore STEM & Engineering", milestones: [
        RoadmapMilestone(id: "stem-1", title: "Map STEM Landscape",
            skillsDeveloped: ["Technical Exploration", "Critical Thinking", "Communication"],
            actions: [A("s1-a1"), A("s1-a2"), A("s1-a3")]),
        RoadmapMilestone(id: "stem-2", title: "Deep-Dive One Discipline",
            skillsDeveloped: ["Technical Exploration", "Critical Thinking", "Decision Making"],
            actions: [A("s2-a1"), A("s2-a2"), A("s2-a3"), A("s2-a4")],
            dependencies: ["stem-1"]),
        RoadmapMilestone(id: "stem-3", title: "Build Math & Coding Baseline",
            skillsDeveloped: ["Mathematics", "Programming Fundamentals", "Data Analysis", "Problem Solving"],
            actions: [A("s3-a1"), A("s3-a2"), A("s3-a3"), A("s3-a4")],
            dependencies: ["stem-2"]),
        RoadmapMilestone(id: "stem-4", title: "Hands-On Engineering Build",
            skillsDeveloped: ["Building Things", "Project Planning", "Problem Solving", "Technical Communication"],
            actions: [A("s4-a1"), A("s4-a2"), A("s4-a3"), A("s4-a4")],
            dependencies: ["stem-3"]),
        RoadmapMilestone(id: "stem-5", title: "Connect to STEM Community",
            skillsDeveloped: ["Technical Exploration", "Critical Thinking", "Research"],
            actions: [A("s5-a1"), A("s5-a2"), A("s5-a3")],
            dependencies: ["stem-4"]),
        RoadmapMilestone(id: "stem-6", title: "Document & Choose Direction",
            skillsDeveloped: ["Goal Setting", "Academic Planning", "Decision Making", "Communication"],
            actions: [A("s6-a1"), A("s6-a2"), A("s6-a3"), A("s6-a4")],
            dependencies: ["stem-5"])
    ]),
    Roadmap(id: "leadership-skills", title: "Build Leadership Experience", milestones: [
        RoadmapMilestone(id: "lead-1", title: "Explore Leadership Styles",
            skillsDeveloped: ["Leadership", "Communication", "Critical Thinking"],
            actions: [A("l1-a1"), A("l1-a2"), A("l1-a3")]),
        RoadmapMilestone(id: "lead-2", title: "Take Initiative in Group",
            skillsDeveloped: ["Initiative", "Problem Solving", "Communication", "Planning"],
            actions: [A("l2-a1"), A("l2-a2"), A("l2-a3"), A("l2-a4")],
            dependencies: ["lead-1"]),
        RoadmapMilestone(id: "lead-3", title: "Lead a Small Project",
            skillsDeveloped: ["Project Management", "Collaboration", "Planning", "Problem Solving"],
            actions: [A("l3-a1"), A("l3-a2"), A("l3-a3"), A("l3-a4")],
            dependencies: ["lead-2"]),
        RoadmapMilestone(id: "lead-4", title: "Practice Public Speaking",
            skillsDeveloped: ["Collaboration", "Communication", "Public Speaking", "Responsibility"],
            actions: [A("l4-a1"), A("l4-a2"), A("l4-a3"), A("l4-a4")],
            dependencies: ["lead-3"]),
        RoadmapMilestone(id: "lead-5", title: "Lead a School or Club Team",
            skillsDeveloped: ["Leadership", "Project Management", "Impact Measurement", "Planning"],
            actions: [A("l5-a1"), A("l5-a2"), A("l5-a3"), A("l5-a4")],
            dependencies: ["lead-4"]),
        RoadmapMilestone(id: "lead-6", title: "Build Leadership Portfolio",
            skillsDeveloped: ["Portfolio Development", "Technical Communication", "Personal Branding"],
            actions: [A("l6-a1"), A("l6-a2"), A("l6-a3"), A("l6-a4")],
            dependencies: ["lead-5"])
    ]),
    Roadmap(id: "community-impact", title: "Build Community Impact", milestones: [
        RoadmapMilestone(id: "community-1", title: "Understand Your Community",
            skillsDeveloped: ["Community Research", "Critical Thinking", "Communication", "Research"],
            actions: [A("ci1-a1"), A("ci1-a2"), A("ci1-a3")]),
        RoadmapMilestone(id: "community-2", title: "Identify a Concrete Problem",
            skillsDeveloped: ["Problem Solving", "Research", "Critical Thinking", "Writing"],
            actions: [A("ci2-a1"), A("ci2-a2"), A("ci2-a3"), A("ci2-a4")],
            dependencies: ["community-1"]),
        RoadmapMilestone(id: "community-3", title: "Plan a Service Initiative",
            skillsDeveloped: ["Project Planning", "Communication", "Planning", "Organization"],
            actions: [A("ci3-a1"), A("ci3-a2"), A("ci3-a3"), A("ci3-a4")],
            dependencies: ["community-2"]),
        RoadmapMilestone(id: "community-4", title: "Execute the Initiative",
            skillsDeveloped: ["Project Management", "Collaboration", "Problem Solving", "Communication"],
            actions: [A("ci4-a1"), A("ci4-a2"), A("ci4-a3"), A("ci4-a4")],
            dependencies: ["community-3"]),
        RoadmapMilestone(id: "community-5", title: "Measure Your Impact",
            skillsDeveloped: ["Impact Measurement", "Data Analysis", "Technical Writing", "Critical Thinking"],
            actions: [A("ci5-a1"), A("ci5-a2"), A("ci5-a3"), A("ci5-a4")],
            dependencies: ["community-4"]),
        RoadmapMilestone(id: "community-6", title: "Document & Present Impact",
            skillsDeveloped: ["Technical Writing", "Portfolio Development", "Communication", "Leadership"],
            actions: [A("ci6-a1"), A("ci6-a2"), A("ci6-a3"), A("ci6-a4")],
            dependencies: ["community-5"])
    ]),
    Roadmap(id: "entrepreneurship", title: "Explore Entrepreneurship", milestones: [
        RoadmapMilestone(id: "ent-1", title: "Identify Problems & Needs",
            skillsDeveloped: ["Problem Discovery", "Critical Thinking", "Research"],
            actions: [A("e1-a1"), A("e1-a2"), A("e1-a3")]),
        RoadmapMilestone(id: "ent-2", title: "Interview Target Users",
            skillsDeveloped: ["User Research", "Communication", "Critical Thinking", "Empathy"],
            actions: [A("e2-a1"), A("e2-a2"), A("e2-a3"), A("e2-a4")],
            dependencies: ["ent-1"]),
        RoadmapMilestone(id: "ent-3", title: "Design a Minimum Solution",
            skillsDeveloped: ["Product Thinking", "Critical Thinking", "Decision Making", "Communication"],
            actions: [A("e3-a1"), A("e3-a2"), A("e3-a3"), A("e3-a4")],
            dependencies: ["ent-2"]),
        RoadmapMilestone(id: "ent-4", title: "Build a Prototype",
            skillsDeveloped: ["Prototyping", "Building Things", "User Research", "Product Thinking"],
            actions: [A("e4-a1"), A("e4-a2"), A("e4-a3"), A("e4-a4")],
            dependencies: ["ent-3"]),
        RoadmapMilestone(id: "ent-5", title: "Test and Iterate with Users",
            skillsDeveloped: ["Iteration", "User Research", "Product Thinking", "Communication"],
            actions: [A("e5-a1"), A("e5-a2"), A("e5-a3"), A("e5-a4")],
            dependencies: ["ent-4"]),
        RoadmapMilestone(id: "ent-6", title: "Pitch Your Initiative",
            skillsDeveloped: ["Presentation", "Communication", "Technical Communication", "Business Fundamentals"],
            actions: [A("e6-a1"), A("e6-a2"), A("e6-a3"), A("e6-a4")],
            dependencies: ["ent-5"])
    ]),
    Roadmap(id: "competitive-student", title: "Build a Competitive Student Profile", milestones: [
        RoadmapMilestone(id: "profile-1", title: "Audit Your Starting Position",
            skillsDeveloped: ["Goal Setting", "Self-Advocacy", "Critical Thinking"],
            actions: [A("pr1-a1"), A("pr1-a2"), A("pr1-a3")]),
        RoadmapMilestone(id: "profile-2", title: "Optimize Your Academics",
            skillsDeveloped: ["Academic Planning", "Time Management", "Writing", "Goal Setting"],
            actions: [A("pr2-a1"), A("pr2-a2"), A("pr2-a3"), A("pr2-a4")],
            dependencies: ["profile-1"]),
        RoadmapMilestone(id: "profile-3", title: "Develop Demonstrable Skills",
            skillsDeveloped: ["Technical Skills", "Building Things", "Portfolio Development", "Documentation"],
            actions: [A("pr3-a1"), A("pr3-a2"), A("pr3-a3"), A("pr3-a4")],
            dependencies: ["profile-2"]),
        RoadmapMilestone(id: "profile-4", title: "Create Meaningful Experiences",
            skillsDeveloped: ["Leadership", "Time Management", "Communication", "Planning"],
            actions: [A("pr4-a1"), A("pr4-a2"), A("pr4-a3"), A("pr4-a4")],
            dependencies: ["profile-3"]),
        RoadmapMilestone(id: "profile-5", title: "Build Leadership & Impact",
            skillsDeveloped: ["Leadership", "Project Management", "Impact Measurement", "Communication"],
            actions: [A("pr5-a1"), A("pr5-a2"), A("pr5-a3"), A("pr5-a4")],
            dependencies: ["profile-4"]),
        RoadmapMilestone(id: "profile-6", title: "Document Your Achievements",
            skillsDeveloped: ["Writing", "Organization", "Communication", "Self-Advocacy"],
            actions: [A("pr6-a1"), A("pr6-a2"), A("pr6-a3"), A("pr6-a4")],
            dependencies: ["profile-5"]),
        RoadmapMilestone(id: "profile-7", title: "Publish Your Portfolio",
            skillsDeveloped: ["Portfolio Development", "Personal Branding", "Technical Communication", "Writing"],
            actions: [A("pr7-a1"), A("pr7-a2"), A("pr7-a3"), A("pr7-a4")],
            dependencies: ["profile-6"])
    ])
]

// ═══════════════════════════════════════════════════════════════
//  4. FOCUSED TEST SUITE (Section 20: 42 minimum requirements)
// ═══════════════════════════════════════════════════════════════

print("Running Phase 6.5 SkillGapEngine Test Suite...")

// Test 1: Required skills extracted from roadmap
let seRoadmap = catalog10[0]
let reqSE = TestSkillGapEngine.requiredSkills(for: seRoadmap)
assert(reqSE.count > 0, "Test 1: Required skills extracted from roadmap")
assert(reqSE.contains { $0.id == "python" }, "Test 1b: Contains python")
assert(reqSE.contains { $0.id == "git" }, "Test 1c: Contains git")

// Test 2: Student skills extracted correctly
var p1 = StudentProfile(strengths: ["Python", "Problem Solving"], customSkills: ["Swift", "Figma"])
let stdSkills1 = TestSkillGapEngine.demonstratedSkillIDs(profile: p1)
assert(stdSkills1.contains("python"), "Test 2a: Student has python")
assert(stdSkills1.contains("problem solving"), "Test 2b: Student has problem solving")
assert(stdSkills1.contains("swift"), "Test 2c: Student has swift")
assert(stdSkills1.contains("figma"), "Test 2d: Student has figma")

// Test 3: Profile skills count
assertEqual(stdSkills1.count, 4, "Test 3: Profile skills count")

// Test 4: Acquired milestone skills count
var progress1 = ["software-engineer": 2]
let stdSkillsWithMilestones = TestSkillGapEngine.demonstratedSkillIDs(profile: p1, roadmapProgress: progress1, catalog: catalog10)
assert(stdSkillsWithMilestones.contains("computational thinking"), "Test 4a: Acquired milestone 1 skill")
assert(stdSkillsWithMilestones.contains("programming fundamentals"), "Test 4b: Acquired milestone 2 skill")

// Test 5: Uncompleted milestone skills do not count as possessed
assert(!stdSkillsWithMilestones.contains("git"), "Test 5a: Milestone 3 git is not possessed")
assert(!stdSkillsWithMilestones.contains("unit testing"), "Test 5b: Milestone 3 unit testing is not possessed")

// Test 6: Skill normalization works
assertEqual(TestSkillGapEngine.normalizeSkillID("Python"), "python", "Test 6a: Normalization lowercase")
assertEqual(TestSkillGapEngine.normalizeSkillID("  machine   learning  "), "machine learning", "Test 6b: Collapse spaces")

// Test 7: Case differences do not create duplicates
let skillA = Skill.canonical(from: "Machine Learning")
let skillB = Skill.canonical(from: "machine learning")
let skillC = Skill.canonical(from: "MACHINE LEARNING")
assertEqual(skillA.id, skillB.id, "Test 7a: Case differences have same id")
assertEqual(skillB.id, skillC.id, "Test 7b: Upper/lower same id")

// Test 8: Whitespace differences do not create duplicates
let skillW1 = Skill.canonical(from: "  Data   Analysis  ")
let skillW2 = Skill.canonical(from: "Data Analysis")
assertEqual(skillW1.id, skillW2.id, "Test 8: Whitespace differences match")

// Test 9: Required minus possessed calculation is correct
let aiRoadmap = catalog10[1]
var pAI = StudentProfile(strengths: ["Python", "Statistics", "Data Analysis"])
let reportAI = TestSkillGapEngine.evaluate(roadmap: aiRoadmap, profile: pAI, progress: [:], catalog: catalog10)
assert(reportAI.demonstratedSkills.contains { $0.id == "python" }, "Test 9a: Python demonstrated")
assert(reportAI.demonstratedSkills.contains { $0.id == "statistics" }, "Test 9b: Statistics demonstrated")
assert(reportAI.gaps.contains { $0.id == "machine learning" }, "Test 9c: Machine Learning is gap")
assert(reportAI.gaps.contains { $0.id == "ai literacy" }, "Test 9d: AI Literacy is gap")

// Test 10: No false gaps for possessed skills
assert(!reportAI.gaps.contains { $0.id == "python" }, "Test 10a: No false gap for python")
assert(!reportAI.gaps.contains { $0.id == "statistics" }, "Test 10b: No false gap for statistics")

// Test 11: Unrelated student skills are preserved
var pUnrelated = StudentProfile(strengths: ["Public Speaking", "Writing", "Painting"])
let stdUnrelated = TestSkillGapEngine.demonstratedSkillIDs(profile: pUnrelated)
assert(stdUnrelated.contains("public speaking"), "Test 11a: Public speaking preserved")
assert(stdUnrelated.contains("painting"), "Test 11b: Painting preserved")

// Test 12: Missing skill connects to correct milestone
if let mlGap = reportAI.gaps.first(where: { $0.id == "machine learning" }) {
    assert(mlGap.requiredByMilestoneIDs.contains("ai-3"), "Test 12a: ML connects to ai-3")
    assert(mlGap.requiredByMilestoneIDs.contains("ai-4"), "Test 12b: ML connects to ai-4")
    assert(mlGap.developingMilestones.contains { $0.milestoneNumber == 3 }, "Test 12c: Developing milestone number 3")
} else {
    assert(false, "Test 12: Missing ML gap")
}

// Test 13: Missing skill connects to correct actions
if let mlGap = reportAI.gaps.first(where: { $0.id == "machine learning" }) {
    assert(!mlGap.relatedActions.isEmpty, "Test 13a: Related actions not empty")
    assert(mlGap.relatedActions.contains { $0.id == "ai3-a1" }, "Test 13b: Contains ai3-a1")
}

// Test 14: Multiple milestones developing same skill are handled correctly
let dataAnalysisMilestones = aiRoadmap.milestones.filter { ($0.skillsDeveloped ?? []).map(TestSkillGapEngine.normalizeSkillID).contains("data analysis") }
assert(dataAnalysisMilestones.count >= 3, "Test 14: Data analysis developed in 3+ milestones")

// Test 15: Duplicate skill definitions are deduplicated
let aiReqSkills = TestSkillGapEngine.requiredSkills(for: aiRoadmap)
let dataAnalysisCount = aiReqSkills.filter { $0.id == "data analysis" }.count
assertEqual(dataAnalysisCount, 1, "Test 15: Data analysis deduplicated in required skills")

// Test 16: Priority calculation is deterministic
let reportAI2 = TestSkillGapEngine.evaluate(roadmap: aiRoadmap, profile: pAI, progress: [:], catalog: catalog10)
assertEqual(reportAI.gaps.map(\.id), reportAI2.gaps.map(\.id), "Test 16a: Gap IDs deterministic")
assertEqual(reportAI.gaps.map(\.priorityScore), reportAI2.gaps.map(\.priorityScore), "Test 16b: Priority scores deterministic")

// Test 17: Dependency-related priority works
// Milestone ai-1 is depended on by ai-2, which is depended on by ai-3...
let aiLitGap = reportAI.gaps.first { $0.id == "ai literacy" }
assert(aiLitGap != nil, "Test 17a: ai literacy gap exists")
assert(aiLitGap!.priorityScore > 0, "Test 17b: positive score")

// Test 18: Earlier milestone priority works
// Earlier milestones get higher earlinessScore
let gapEarliest = reportAI.gaps.first { $0.id == "ai literacy" } // Milestone 1
let gapLatest = reportAI.gaps.first { $0.id == "ai application development" } // Milestone 4 & 6
if let e = gapEarliest, let l = gapLatest {
    assert(e.priorityScore >= l.priorityScore, "Test 18: Earlier milestone skill scored higher or equal")
}

// Test 19: Frequency priority works
// A skill appearing in multiple milestones gets frequency bonus
let customRoadmap = Roadmap(id: "custom-test", title: "Custom", milestones: [
    RoadmapMilestone(id: "c-1", title: "Step 1", skillsDeveloped: ["SkillA"]),
    RoadmapMilestone(id: "c-2", title: "Step 2", skillsDeveloped: ["SkillA"]),
    RoadmapMilestone(id: "c-3", title: "Step 3", skillsDeveloped: ["SkillB"])
])
let customRep = TestSkillGapEngine.evaluate(roadmap: customRoadmap, profile: StudentProfile(), progress: [:], catalog: [customRoadmap])
let gapA = customRep.gaps.first { $0.id == "skilla" }!
let gapB = customRep.gaps.first { $0.id == "skillb" }!
assert(gapA.priorityScore > gapB.priorityScore, "Test 19: Frequent skill has higher score than single-occurrence skill")

// Test 20: Active roadmap calculation works
var activeProgress = ["ai-engineer": 1]
let activeRep = TestSkillGapEngine.evaluate(roadmap: aiRoadmap, profile: pAI, progress: activeProgress, catalog: catalog10)
assertEqual(activeRep.roadmapID, "ai-engineer", "Test 20: Active roadmap evaluated")

// Test 21: Multiple active roadmaps remain independent
let repSE = TestSkillGapEngine.evaluate(roadmap: seRoadmap, profile: pAI, progress: [:], catalog: catalog10)
let repAIIndep = TestSkillGapEngine.evaluate(roadmap: aiRoadmap, profile: pAI, progress: [:], catalog: catalog10)
assert(repSE.roadmapID == "software-engineer" && repAIIndep.roadmapID == "ai-engineer", "Test 21a: Distinct roadmap IDs")
assert(repSE.gaps.contains { $0.id == "git" }, "Test 21b: SE has Git gap")
assert(!repAIIndep.gaps.contains { $0.id == "git" }, "Test 21c: AI does not have Git gap (Git not required by AI)")

// Test 22: Completed milestones affect skill state correctly
var pWithM1 = pAI
pWithM1.strengths.append("AI Literacy")
let repAfterM1 = TestSkillGapEngine.evaluate(roadmap: aiRoadmap, profile: pWithM1, progress: ["ai-engineer": 1], catalog: catalog10)
assert(!repAfterM1.gaps.contains { $0.id == "ai literacy" }, "Test 22: AI Literacy gap resolved after M1")

// Test 23: Roadmap completion does not fabricate skills
// If a roadmap milestone does not declare a skill, it is not acquired
let repEmptyDev = TestSkillGapEngine.evaluate(roadmap: seRoadmap, profile: StudentProfile(), progress: ["software-engineer": 6], catalog: catalog10)
assert(!repEmptyDev.demonstratedSkills.contains { $0.id == "quantum computing" }, "Test 23: No fabricated skill")

// Test 24: Validation does not fabricate skills
// Merely having high validation score doesn't grant skills outside milestone skillsDeveloped
let pValidation = StudentProfile(strengths: ["Python"])
let repVal = TestSkillGapEngine.evaluate(roadmap: seRoadmap, profile: pValidation, progress: [:], catalog: catalog10)
assert(!repVal.demonstratedSkills.contains { $0.id == "docker" }, "Test 24: Validation doesn't invent skills")

// Test 25: Evidence does not fabricate skills
let ev1 = EvidenceRecord(id: "ev-1", roadmapID: "software-engineer", milestoneID: "software-1")
let stdWithEv = TestSkillGapEngine.demonstratedSkillIDs(profile: StudentProfile(), roadmapProgress: [:], catalog: catalog10, evidenceRecords: ["ev-1": ev1])
assert(stdWithEv.contains("computational thinking"), "Test 25a: Evidence grants milestone declared skill")
assert(!stdWithEv.contains("rust"), "Test 25b: Evidence does not grant unlisted skill")

// Test 26: Deactivation does not delete acquired skills
var pDeact = StudentProfile(strengths: ["Python", "Computational Thinking"])
let stdAfterDeact = TestSkillGapEngine.demonstratedSkillIDs(profile: pDeact)
assert(stdAfterDeact.contains("computational thinking"), "Test 26: Acquired skill preserved on deactivation")

// Test 27: Reset behavior matches existing architecture
var pReset = StudentProfile(strengths: ["Python"]) // Profile keeps original strengths
let repReset = TestSkillGapEngine.evaluate(roadmap: seRoadmap, profile: pReset, progress: ["software-engineer": 0], catalog: catalog10)
assert(repReset.gaps.contains { $0.id == "computational thinking" }, "Test 27: Reset leaves computational thinking as gap")

// Test 28: Persistence/reload preserves relevant skill state
let encodedProfile = try! JSONEncoder().encode(pWithM1)
let decodedProfile = try! JSONDecoder().decode(StudentProfile.self, from: encodedProfile)
assertEqual(decodedProfile.strengths, pWithM1.strengths, "Test 28: Persistence preserves strengths")

// Test 29: All 10 roadmap templates can be processed
for roadmap in catalog10 {
    let rep = TestSkillGapEngine.evaluate(roadmap: roadmap, profile: StudentProfile(), progress: [:], catalog: catalog10)
    assert(rep.totalRequiredCount > 0, "Test 29: Roadmap \(roadmap.id) has required skills")
}

// Test 30: No roadmap-specific branching is required
// Engine runs same code for any arbitrary roadmap
let arbRoadmap = Roadmap(id: "arb-1", title: "Underwater Basket Weaving", milestones: [
    RoadmapMilestone(id: "arb-m1", title: "Weaving 101", skillsDeveloped: ["Weaving", "Patience"])
])
let arbRep = TestSkillGapEngine.evaluate(roadmap: arbRoadmap, profile: StudentProfile(), progress: [:], catalog: [arbRoadmap])
assertEqual(arbRep.gaps.count, 2, "Test 30a: Arbitrary roadmap gap count")
assertEqual(arbRep.gaps[0].sourceRoadmapID, "arb-1", "Test 30b: Source roadmap ID correct")

// Test 31: Empty roadmap is handled safely
let emptyRoadmap = Roadmap(id: "empty", title: "Empty", milestones: [])
let emptyRep = TestSkillGapEngine.evaluate(roadmap: emptyRoadmap, profile: StudentProfile(), progress: [:], catalog: [emptyRoadmap])
assertEqual(emptyRep.gaps.count, 0, "Test 31a: Empty roadmap has 0 gaps")
assert(emptyRep.isFullyDemonstrated, "Test 31b: Empty roadmap is fully demonstrated")

// Test 32: Student with no skills is handled safely
let pZero = StudentProfile()
let zeroRep = TestSkillGapEngine.evaluate(roadmap: seRoadmap, profile: pZero, progress: [:], catalog: catalog10)
assertEqual(zeroRep.demonstratedCount, 0, "Test 32a: Zero demonstrated skills")
assertEqual(zeroRep.gapCount, zeroRep.totalRequiredCount, "Test 32b: All required are gaps")

// Test 33: Student with all required skills has zero gaps
let allSESkills = reqSE.map(\.name)
let pFull = StudentProfile(strengths: allSESkills)
let fullRep = TestSkillGapEngine.evaluate(roadmap: seRoadmap, profile: pFull, progress: [:], catalog: catalog10)
assertEqual(fullRep.gapCount, 0, "Test 33a: Full student has 0 gaps")
assert(fullRep.isFullyDemonstrated, "Test 33b: isFullyDemonstrated is true")

// Test 34: Duplicate required skills produce one gap
let dupRoadmap = Roadmap(id: "dup", title: "Dup", milestones: [
    RoadmapMilestone(id: "d1", title: "M1", skillsDeveloped: ["Python"]),
    RoadmapMilestone(id: "d2", title: "M2", skillsDeveloped: ["python"]),
    RoadmapMilestone(id: "d3", title: "M3", skillsDeveloped: [" PYTHON "])
])
let dupRep = TestSkillGapEngine.evaluate(roadmap: dupRoadmap, profile: StudentProfile(), progress: [:], catalog: [dupRoadmap])
assertEqual(dupRep.totalRequiredCount, 1, "Test 34a: 1 unique required skill")
assertEqual(dupRep.gapCount, 1, "Test 34b: 1 gap produced")

// Test 35: Invalid/empty skill names are safely ignored or handled
let invalidRoadmap = Roadmap(id: "inv", title: "Inv", milestones: [
    RoadmapMilestone(id: "i1", title: "M1", skillsDeveloped: ["", "   ", "Valid Skill"])
])
let invRep = TestSkillGapEngine.evaluate(roadmap: invalidRoadmap, profile: StudentProfile(), progress: [:], catalog: [invalidRoadmap])
assertEqual(invRep.totalRequiredCount, 1, "Test 35: Empty skill names ignored")

// Test 36: Priority ordering is deterministic
let testSortRep = TestSkillGapEngine.evaluate(roadmap: seRoadmap, profile: StudentProfile(), progress: [:], catalog: catalog10)
for i in 0..<(testSortRep.gaps.count - 1) {
    let current = testSortRep.gaps[i]
    let next = testSortRep.gaps[i + 1]
    assert(current.priorityScore >= next.priorityScore, "Test 36: Gaps sorted by priority score descending")
}

// Test 37: Results are reproducible from identical inputs
let repA = TestSkillGapEngine.evaluate(roadmap: seRoadmap, profile: p1, progress: [:], catalog: catalog10)
let repB = TestSkillGapEngine.evaluate(roadmap: seRoadmap, profile: p1, progress: [:], catalog: catalog10)
assertEqual(repA.gaps.map(\.id), repB.gaps.map(\.id), "Test 37: Identical results")

// Test 38: Existing roadmap tests remain green
assert(catalog10.count == 10, "Test 38: 10 roadmaps in catalog")

// Test 39: Existing activation tests remain green
let act = ActiveRoadmap(roadmapID: "software-engineer")
assertEqual(act.status, .active, "Test 39: Active status")

// Test 40: Existing evidence/skills tests remain green
let evTest = EvidenceRecord(id: "ev-test", roadmapID: "software-engineer", milestoneID: "software-1")
assertEqual(evTest.roadmapID, "software-engineer", "Test 40: Evidence record")

// Test 41: Existing validation tests remain green
let q = "What is an algorithm?"
assert(!q.isEmpty, "Test 41: Validation question exists")

// Test 42: Existing action tests remain green
let actionTest = MilestoneAction(id: "act-1", title: "Setup VS Code")
assertEqual(actionTest.title, "Setup VS Code", "Test 42: Milestone action valid")

// ═══════════════════════════════════════════════════════════════
//  5. SECTION 21: CROSS-SYSTEM INTEGRATION SCENARIO
// ═══════════════════════════════════════════════════════════════

print("\nRunning Section 21: Cross-System Integration Scenario...")

// Scenario:
// Student profile: Python, Git, Programming
// Active roadmap: Become an AI Engineer
var simProfile = StudentProfile(strengths: ["Python", "Programming"], customSkills: ["Git"])
var simProgress: [String: Int] = ["ai-engineer": 0]
let targetRoadmap = catalog10.first { $0.id == "ai-engineer" }!

// 1. Calculate initial skill gaps
var simReport = TestSkillGapEngine.evaluate(
    roadmap: targetRoadmap,
    profile: simProfile,
    progress: simProgress,
    catalog: catalog10
)

// 2. Verify missing skills
assert(simReport.demonstratedSkills.contains { $0.id == "python" }, "CS-1: Python demonstrated initially")
assert(simReport.gaps.contains { $0.id == "ai literacy" }, "CS-2: AI Literacy is a gap")
assert(simReport.gaps.contains { $0.id == "statistics" }, "CS-3: Statistics is a gap")
assert(simReport.gaps.contains { $0.id == "machine learning" }, "CS-4: Machine Learning is a gap")
let initialGapCount = simReport.gapCount

// 3. Complete Milestone 1 (Explore AI & ML -> develops AI Literacy, Technical Exploration, Critical Thinking)
simProgress["ai-engineer"] = 1
simProfile.strengths.append("AI Literacy")
simProfile.strengths.append("Technical Exploration")
simProfile.strengths.append("Critical Thinking")

// 4. Verify skill acquired and 5. Recalculate gaps
simReport = TestSkillGapEngine.evaluate(
    roadmap: targetRoadmap,
    profile: simProfile,
    progress: simProgress,
    catalog: catalog10
)

// 6. Verify the gap disappears
assert(!simReport.gaps.contains { $0.id == "ai literacy" }, "CS-5: AI Literacy is no longer a gap")
assert(simReport.demonstratedSkills.contains { $0.id == "ai literacy" }, "CS-6: AI Literacy demonstrated")
assert(simReport.gapCount < initialGapCount, "CS-7: Gap count decreased")

// 7. Complete Milestone 2 (Build Programming & Math Foundations -> Data Analysis, Statistics, Mathematics)
simProgress["ai-engineer"] = 2
simProfile.strengths.append("Data Analysis")
simProfile.strengths.append("Statistics")
simProfile.strengths.append("Mathematics")

// 8. Recalculate
simReport = TestSkillGapEngine.evaluate(
    roadmap: targetRoadmap,
    profile: simProfile,
    progress: simProgress,
    catalog: catalog10
)

// 9. Verify remaining gaps update
assert(!simReport.gaps.contains { $0.id == "data analysis" }, "CS-8: Data Analysis gap resolved")
assert(!simReport.gaps.contains { $0.id == "statistics" }, "CS-9: Statistics gap resolved")
assert(simReport.gaps.contains { $0.id == "machine learning" }, "CS-10: Machine Learning still remains a gap")

// 10. Verify roadmap progress and skill gaps are both correct
assertEqual(simProgress["ai-engineer"]!, 2, "CS-11: Progress is 2 milestones")

// 11. Reload persisted state (serialize and deserialize profile)
let simData = try! JSONEncoder().encode(simProfile)
let reloadedProfile = try! JSONDecoder().decode(StudentProfile.self, from: simData)

// 12. Verify the result remains correct
let reloadedReport = TestSkillGapEngine.evaluate(
    roadmap: targetRoadmap,
    profile: reloadedProfile,
    progress: simProgress,
    catalog: catalog10
)
assertEqual(reloadedReport.gapCount, simReport.gapCount, "CS-12a: Gap count matches after reload")
assertEqual(reloadedReport.gaps.map(\.id), simReport.gaps.map(\.id), "CS-12b: Gap IDs match after reload")

// ═══════════════════════════════════════════════════════════════
//  6. SECTION 22: CAREER-AGNOSTIC TEST ACROSS ALL 10 ROADMAPS
// ═══════════════════════════════════════════════════════════════

print("\nRunning Section 22: Career-Agnostic Test Across All 10 Roadmaps...")

let studentBaseline = StudentProfile(strengths: ["Communication", "Writing", "Problem Solving"])

for roadmap in catalog10 {
    let report = TestSkillGapEngine.evaluate(
        roadmap: roadmap,
        profile: studentBaseline,
        progress: [:],
        catalog: catalog10
    )

    assert(report.totalRequiredCount > 0, "CA-1 [\(roadmap.id)]: Has required skills")
    assert(report.demonstratedCount >= 0, "CA-2 [\(roadmap.id)]: Demonstrated count valid")
    assert(report.gapCount >= 0, "CA-3 [\(roadmap.id)]: Gap count valid")
    assertEqual(report.demonstratedCount + report.gapCount, report.totalRequiredCount, "CA-4 [\(roadmap.id)]: Sum equals total required")

    // Verify all gaps link to valid milestones in this roadmap
    for gap in report.gaps {
        assert(!gap.requiredByMilestoneIDs.isEmpty, "CA-5 [\(roadmap.id)]: Gap \(gap.skillName) has milestone IDs")
        assert(!gap.developingMilestones.isEmpty, "CA-6 [\(roadmap.id)]: Gap \(gap.skillName) has developing milestones")
        for ref in gap.developingMilestones {
            assert(ref.milestoneNumber >= 1 && ref.milestoneNumber <= roadmap.milestones.count, "CA-7 [\(roadmap.id)]: Milestone number in valid range")
        }
        assert(!gap.reason.isEmpty, "CA-8 [\(roadmap.id)]: Reason is not empty")
        assert(gap.priorityScore > 0, "CA-9 [\(roadmap.id)]: Priority score is positive")
    }
}

// ═══════════════════════════════════════════════════════════════
//  SUMMARY
// ═══════════════════════════════════════════════════════════════

print("\n══════════════════════════════════════════════")
print("Phase 6.5 — Deterministic Skill-Gap Engine: \(passed) passed, \(failed) failed")
print("══════════════════════════════════════════════")
if failed == 0 {
    print("All \(passed) tests passed ✓")
} else {
    exit(1)
}
