import Foundation

enum RoadmapCategory: String, CaseIterable, Identifiable, Codable {
    case career = "Career"
    case skills = "Skills"
    case academic = "Academic"
    case projects = "Projects"
    case collegePreparation = "College Preparation"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .career: return "briefcase"
        case .skills: return "wrench.and.screwdriver"
        case .academic: return "graduationcap"
        case .projects: return "hammer"
        case .collegePreparation: return "building.columns"
        }
    }
}
