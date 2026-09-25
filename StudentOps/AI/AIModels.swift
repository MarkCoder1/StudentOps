import Foundation

// MARK: - AI Personalization Models (Phase 9.8)
// Structured, validated, server-side Groq. AI is not source of truth.

enum AIPersonalizationOperation: String, Codable, Hashable, CaseIterable {
    case projectExplanation = "projectExplanation"
    case projectCoaching = "projectCoaching"
    case projectReflection = "projectReflection"
    case skillExplanation = "skillExplanation"
    case roadmapExplanation = "roadmapExplanation"
}

// MARK: - Contexts (minimal, data-minimized)

struct AIProjectExplanationContext: Codable, Hashable {
    struct Student: Codable, Hashable {
        let goals: [String]
        let interests: [String]
        let skills: [String]
    }
    struct Project: Codable, Hashable {
        let id: String
        let title: String
        let description: String?
        let category: String?
        let skills: [String]
    }
    struct Recommendation: Codable, Hashable {
        let score: Int
        let reasons: [String]
        let breakdown: Breakdown
        struct Breakdown: Codable, Hashable {
            let goalAlignment: Double
            let skillGapCoverage: Double
            let roadmapAlignment: Double
            let interestAlignment: Double
        }
    }
    let student: Student
    let project: Project
    let recommendation: Recommendation
    let skillGaps: [String]
    let roadmap: Roadmap?
    struct Roadmap: Codable, Hashable { let id: String; let title: String; let active: Bool }
    let contextVersion: String?
}

struct AIProjectCoachingContext: Codable, Hashable {
    struct Project: Codable, Hashable { let id: String; let title: String; let goal: String?; let description: String? }
    struct Playbook: Codable, Hashable { let overview: String?; let steps: [Step]; let skillsDeveloped: [String]; struct Step: Codable, Hashable { let id: String; let title: String; let order: Int } }
    struct Execution: Codable, Hashable { let completedStepIDs: [String]; let totalSteps: Int; let percent: Int }
    struct Step: Codable, Hashable { let id: String; let title: String; let description: String; let objective: String?; let requiredSkills: [String]; let estimatedEffort: String? }
    let project: Project
    let playbook: Playbook?
    let execution: Execution
    let currentStep: Step?
    let nextStep: Step?
    struct Student: Codable, Hashable { let goals: [String]; let skills: [String] }
    let student: Student
    let skillGaps: [String]
    let contextVersion: String?
}

struct AIProjectReflectionContext: Codable, Hashable {
    struct Project: Codable, Hashable { let id: String; let title: String; let description: String?; let outcome: String?; let skills: [String] }
    struct Playbook: Codable, Hashable { let steps: [Step]; let deliverables: [Deliverable]; let criteria: [Criterion]; struct Step: Codable, Hashable { let id: String; let title: String }; struct Deliverable: Codable, Hashable { let id: String; let title: String }; struct Criterion: Codable, Hashable { let id: String; let title: String } }
    struct Execution: Codable, Hashable { let completedStepIDs: [String]; let completedDeliverableIDs: [String]; let confirmedCriterionIDs: [String]; let isCompleted: Bool }
    struct Evidence: Codable, Hashable { let id: String; let title: String }
    struct Achievement: Codable, Hashable { let id: String; let title: String }
    let project: Project
    let playbook: Playbook?
    let execution: Execution
    let evidence: [Evidence]
    let achievements: [Achievement]
    let contextVersion: String?
}

struct AISkillExplanationContext: Codable, Hashable {
    struct Skill: Codable, Hashable { let id: String; let name: String }
    let skill: Skill
    let gapReason: String
    struct Roadmap: Codable, Hashable { let id: String; let title: String }
    let roadmap: Roadmap?
    struct Project: Codable, Hashable { let id: String; let title: String; let skills: [String] }
    let project: Project?
    let studentGoal: String?
    let contextVersion: String?
}

struct AIRoadmapExplanationContext: Codable, Hashable {
    struct Roadmap: Codable, Hashable { let id: String; let title: String; let goal: String? }
    struct Progress: Codable, Hashable { let completedMilestones: Int; let totalMilestones: Int; let percent: Int; let isActive: Bool }
    struct Milestone: Codable, Hashable { let id: String; let title: String }
    let roadmap: Roadmap
    let progress: Progress
    let nextMilestone: Milestone?
    let skillGaps: [String]
    let relevantProjects: [Project]
    struct Project: Codable, Hashable { let id: String; let title: String }
    let contextVersion: String?
}

// MARK: - Outputs (structured, validated)

struct AIProjectExplanationOutput: Codable, Hashable {
    let summary: String
    let reasons: [String]
}

struct AIProjectCoachingOutput: Codable, Hashable {
    let focus: String
    let actions: [String]
    let caution: String?
}

struct AIProjectReflectionOutput: Codable, Hashable {
    let prompts: [String]
    let draftReflection: String?
}

struct AISkillExplanationOutput: Codable, Hashable {
    let summary: String
    let howProjectHelps: String
}

struct AIRoadmapExplanationOutput: Codable, Hashable {
    let summary: String
    let focusAreas: [String]
}

// MARK: - Generic Request/Response

struct AIPersonalizationRequest: Codable {
    let operation: AIPersonalizationOperation
    let context: AnyCodable // Encoded as generic JSON
    let contextFingerprint: String?
}

// Helper for AnyCodable
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { value = v; return }
        if let v = try? c.decode(Int.self) { value = v; return }
        if let v = try? c.decode(Double.self) { value = v; return }
        if let v = try? c.decode(String.self) { value = v; return }
        if let v = try? c.decode([AnyCodable].self) { value = v.map(\.value); return }
        if let v = try? c.decode([String: AnyCodable].self) { value = v.mapValues(\.value); return }
        value = ()
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        case let v as [Any]: try c.encode(v.map{AnyCodable($0)})
        case let v as [String: Any]: try c.encode(v.mapValues{AnyCodable($0)})
        default: try c.encodeNil()
        }
    }
}

// Concrete typed request/response wrappers for Swift client

struct AIPersonalizationServerRequest<T: Codable>: Codable {
    let operation: AIPersonalizationOperation
    let context: T
}

struct AIPersonalizationServerResponse<T: Codable>: Codable {
    let operation: AIPersonalizationOperation
    let data: T
    let model: String
    let provider: String
}

// MARK: - Errors

enum AIError: Error, LocalizedError, Codable, Hashable {
    case invalidRequest(String)
    case insufficientContext(String)
    case networkFailure(String)
    case providerFailure(String)
    case invalidResponse(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidRequest(let m): return m
        case .insufficientContext(let m): return m
        case .networkFailure(let m): return m
        case .providerFailure(let m): return m
        case .invalidResponse(let m): return m
        case .cancelled: return "Cancelled"
        }
    }

    var code: String {
        switch self {
        case .invalidRequest: return "invalid_request"
        case .insufficientContext: return "insufficient_context"
        case .networkFailure: return "networkFailure"
        case .providerFailure: return "providerFailure"
        case .invalidResponse: return "invalidResponse"
        case .cancelled: return "cancelled"
        }
    }
}
