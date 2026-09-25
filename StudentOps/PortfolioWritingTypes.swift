import Foundation

// MARK: - Writing Type (career-agnostic, factual)

enum PortfolioWritingType: String, CaseIterable, Codable, Hashable, Identifiable {
    case headline = "headline"
    case about = "about"
    case goal = "goal"
    case projectDescription = "projectDescription"
    case achievementDescription = "achievementDescription"
    case evidenceDescription = "evidenceDescription"
    case roadmapSummary = "roadmapSummary"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .headline: return "Headline"
        case .about: return "About"
        case .goal: return "Goal"
        case .projectDescription: return "Project Description"
        case .achievementDescription: return "Achievement Description"
        case .evidenceDescription: return "Evidence Description"
        case .roadmapSummary: return "Roadmap Summary"
        }
    }

    var maxLength: Int {
        switch self {
        case .headline: return 160
        case .about: return 1200
        case .goal: return 400
        case .projectDescription: return 1000
        case .achievementDescription: return 800
        case .evidenceDescription: return 800
        case .roadmapSummary: return 1000
        }
    }
}

enum PortfolioWritingTone: String, CaseIterable, Codable, Hashable {
    case professional = "professional"
    case concise = "concise"
    case confident = "confident"
    case natural = "natural"
    case technical = "technical"

    var displayName: String { rawValue.capitalized }
}

enum PortfolioWritingLength: String, CaseIterable, Codable, Hashable {
    case short = "short"
    case medium = "medium"
    case detailed = "detailed"

    var displayName: String { rawValue.capitalized }
}

// MARK: - Request / Response (iOS ↔ Server)

struct PortfolioWritingRequest: Codable, Hashable {
    let portfolioID: String
    let writingType: PortfolioWritingType
    let targetID: String?
    let currentText: String?
    let tone: PortfolioWritingTone
    let length: PortfolioWritingLength
    let context: PortfolioWritingContext
    let contextFingerprint: String?
}

struct PortfolioWritingContext: Codable, Hashable {
    struct PortfolioMeta: Codable, Hashable {
        let id: String
        let title: String
        let headline: String?
        let about: String?
        let goals: [String]
    }
    struct Student: Codable, Hashable {
        let displayName: String?
        let grade: String?
        let schoolLevel: String?
        let location: String?
    }
    struct Education: Codable, Hashable {
        let grade: String?
        let schoolLevel: String?
    }
    struct Project: Codable, Hashable {
        let id: String
        let title: String
        let description: String?
        let category: String?
        let goal: String?
        let skills: [String]
        let progress: Int?
        let isCompleted: Bool?
        let sourceRoadmapID: String?
        let evidenceCount: Int?
        let artifactURL: String?
    }
    struct Achievement: Codable, Hashable {
        let id: String
        let title: String
        let description: String?
        let type: String?
        let createdAt: String?
        let evidenceCount: Int?
        let skillIDs: [String]
        let roadmapID: String?
        let projectID: String?
    }
    struct Evidence: Codable, Hashable {
        let id: String
        let title: String
        let description: String?
        let type: String?
        let roadmapID: String?
        let milestoneID: String?
        let projectID: String?
        let skillIDs: [String]
        let artifactURL: String?
        let createdAt: String?
        let quality: String?
    }
    struct Skill: Codable, Hashable {
        let id: String
        let name: String
    }
    struct Roadmap: Codable, Hashable {
        let id: String
        let title: String
        let goal: String?
        let progress: Int?
        let isActive: Bool?
        let completedMilestones: Int?
        let totalMilestones: Int?
    }

    let portfolio: PortfolioMeta
    let student: Student
    let education: Education?
    let projects: [Project]
    let achievements: [Achievement]
    let evidence: [Evidence]
    let skills: [Skill]
    let roadmaps: [Roadmap]
    let constraints: Constraints?

    struct Constraints: Codable, Hashable {
        let writingType: PortfolioWritingType
        let targetID: String?
    }
}

struct PortfolioWritingResponse: Codable, Hashable {
    let draft: String
    let writingType: PortfolioWritingType
    let sourceIDs: [String]
    let factualClaims: [String]
    let warnings: [String]
    let needsMoreContext: Bool
    let contextFingerprint: String
    let model: String
    let provider: String
}

struct PortfolioWritingError: Codable, Hashable, Error {
    let code: String
    let message: String
}
