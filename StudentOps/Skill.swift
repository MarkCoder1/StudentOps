import Foundation

// MARK: - Canonical Skill Model

/// A canonical skill representation used across Student OPS.
/// Normalized by ID to prevent duplicates caused by casing, leading/trailing whitespace,
/// or formatting differences.
struct Skill: Identifiable, Hashable, Codable {
    /// Canonical identifier (lowercase, trimmed, collapsed whitespace).
    let id: String
    /// Display name with appropriate capitalization (e.g. "Python", "Machine Learning", "APIs").
    let name: String
    /// Optional high-level skill domain or category (e.g. "technical", "research", "leadership").
    let category: String?

    init(id: String, name: String, category: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
    }

    /// Normalizes any raw string into a canonical skill ID:
    /// - trims whitespace and newlines
    /// - collapses internal whitespace sequences into single spaces
    /// - converts to lowercase
    static func normalizeID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return parts.joined(separator: " ").lowercased()
    }

    /// Resolves a raw string into a canonical `Skill`.
    /// If the skill is in `SkillCatalog`, uses the catalog's canonical display name and category.
    /// Otherwise, creates a `Skill` using the trimmed input as the display name.
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

// MARK: - Skill Catalog

/// Canonical registry of skills defined across the 10 roadmap templates and core onboarding strengths.
enum SkillCatalog {
    static let allSkills: [Skill] = [
        // Technical / Programming / AI
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

        // Data / Math / Science
        Skill(id: "data analysis", name: "Data Analysis", category: "data"),
        Skill(id: "data collection", name: "Data Collection", category: "data"),
        Skill(id: "statistics", name: "Statistics", category: "data"),
        Skill(id: "mathematics", name: "Mathematics", category: "academic"),
        Skill(id: "scientific method", name: "Scientific Method", category: "research"),
        Skill(id: "scientific communication", name: "Scientific Communication", category: "research"),

        // Research & Problem Discovery
        Skill(id: "research", name: "Research", category: "research"),
        Skill(id: "research methods", name: "Research Methods", category: "research"),
        Skill(id: "question formation", name: "Question Formation", category: "research"),
        Skill(id: "source evaluation", name: "Source Evaluation", category: "research"),
        Skill(id: "community research", name: "Community Research", category: "research"),
        Skill(id: "user research", name: "User Research", category: "research"),
        Skill(id: "problem discovery", name: "Problem Discovery", category: "research"),
        Skill(id: "problem solving", name: "Problem Solving", category: "core"),

        // Communication & Writing
        Skill(id: "technical communication", name: "Technical Communication", category: "communication"),
        Skill(id: "technical writing", name: "Technical Writing", category: "communication"),
        Skill(id: "communication", name: "Communication", category: "communication"),
        Skill(id: "writing", name: "Writing", category: "communication"),
        Skill(id: "presentation", name: "Presentation", category: "communication"),
        Skill(id: "public speaking", name: "Public Speaking", category: "communication"),
        Skill(id: "documentation", name: "Documentation", category: "communication"),

        // Leadership, Impact & Management
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

        // Academic & Career Strategy
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

// MARK: - Skill Status

/// The status of a skill relative to a student and roadmap.
enum SkillStatus: String, Codable, Hashable {
    /// The student has demonstrated or acquired this skill (onboarding, milestone completion, project evidence).
    case demonstrated
    /// The skill is missing, but is developed by the student's currently active/available milestone.
    case developing
    /// The skill is missing and will be developed in future or locked milestones.
    case gap
}

// MARK: - Priority

/// Deterministic priority tier for a skill gap based on objective roadmap structure.
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

// MARK: - Milestone Reference

/// Reference to a milestone that develops a skill gap, including its position in the roadmap sequence.
struct MilestoneReference: Identifiable, Hashable, Codable {
    let id: String
    let milestoneNumber: Int
    let title: String
}

// MARK: - SkillGap Result

/// A structured result representing a required skill that has not yet been demonstrated by the student.
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

    init(
        skill: Skill,
        status: SkillStatus,
        sourceRoadmapID: String,
        requiredByMilestoneIDs: [String],
        developingMilestones: [MilestoneReference],
        relatedActions: [MilestoneAction],
        priority: SkillGapPriority,
        priorityScore: Int,
        reason: String
    ) {
        self.skill = skill
        self.status = status
        self.sourceRoadmapID = sourceRoadmapID
        self.requiredByMilestoneIDs = requiredByMilestoneIDs
        self.developingMilestones = developingMilestones
        self.relatedActions = relatedActions
        self.priority = priority
        self.priorityScore = priorityScore
        self.reason = reason
    }
}

// MARK: - Roadmap Skill-Gap Report

/// Comprehensive deterministic report of a roadmap's required skills vs. a student's demonstrated skills.
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

