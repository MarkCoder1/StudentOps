import SwiftUI

enum OpportunityCategory: String, CaseIterable, Identifiable, Codable {
    case all = "More"
    case competitions = "Competitions"
    case scholarships = "Scholarships"
    case research = "Research"
    case volunteering = "Volunteering"
    case leadership = "Leadership"
    case summerPrograms = "Summer Programs"
    case academicPrograms = "Academic Programs"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .competitions: return "trophy"
        case .scholarships: return "banknote"
        case .research: return "flask"
        case .volunteering: return "hands.sparkles"
        case .leadership: return "person.2"
        case .summerPrograms: return "sun.max"
        case .academicPrograms: return "graduationcap"
        }
    }
}
