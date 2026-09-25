import Foundation

// MARK: - Personalized Roadmap Recommendation (mirrors server roadmaps/types.ts)

struct PersonalizedRoadmapRecommendation: Codable, Hashable, Identifiable {
    let roadmapId: String
    let fitScore: Int
    let reason: String

    var id: String { roadmapId }
}

struct PersonalizedRoadmapResponse: Codable {
    let recommendations: [PersonalizedRoadmapRecommendation]
}

// MARK: - Roadmap Catalog Item (sent from iOS to server)

struct RoadmapCatalogItem: Codable {
    let id: String
    let title: String
    let goal: String
    let category: String
    let description: String
    let milestoneCount: Int
    let completedMilestones: Int
    let relevantInterests: [String]
    let relevantSkills: [String]
    let relevantCareers: [String]
    let relevantFields: [String]
    let matchScore: Int

    init(from roadmap: Roadmap, matchScore: Int, completedMilestones: Int) {
        self.id = roadmap.id
        self.title = roadmap.title
        self.goal = roadmap.goal
        self.category = roadmap.category.rawValue
        self.description = roadmap.description
        self.milestoneCount = roadmap.milestones.count
        self.completedMilestones = completedMilestones
        self.relevantInterests = Array(roadmap.relevantInterests)
        self.relevantSkills = Array(roadmap.relevantSkills)
        self.relevantCareers = Array(roadmap.relevantCareers)
        self.relevantFields = Array(roadmap.relevantFields)
        self.matchScore = matchScore
    }
}

// MARK: - Roadmap Student Context (sent from iOS to server)

struct RoadmapStudentContext: Codable {
    let firstName: String?
    let age: String?
    let schoolLevel: String?
    let grade: String?
    let interests: [String]
    let skills: [String]
    let careers: [String]
    let fields: [String]
    let goals: [String]
    let projects: [RoadmapProjectContext]
    let achievements: [RoadmapAchievementContext]
    let completedRoadmapCount: Int
    let activeRoadmapCount: Int

    init(
        profile: StudentProfile,
        achievements: [Achievement],
        completedRoadmapCount: Int,
        activeRoadmapCount: Int
    ) {
        self.firstName = profile.firstName.isEmpty ? nil : profile.firstName
        self.age = profile.age.isEmpty ? nil : profile.age
        self.schoolLevel = profile.schoolLevel.rawValue
        self.grade = profile.grade.rawValue
        self.interests = profile.interests + profile.customInterests
        self.skills = profile.strengths + profile.customSkills
        self.careers = profile.careers
        self.fields = profile.fields
        self.goals = profile.milestones
        self.projects = [] // No projects stored yet; will be populated if customProjects exist
        self.achievements = achievements.map { RoadmapAchievementContext(title: $0.title, category: $0.category) }
        self.completedRoadmapCount = completedRoadmapCount
        self.activeRoadmapCount = activeRoadmapCount
    }
}

struct RoadmapProjectContext: Codable {
    let title: String
    let category: String
    let skills: [String]
}

struct RoadmapAchievementContext: Codable {
    let title: String
    let category: String
}

// MARK: - Request Body

struct PersonalizedRoadmapRequest: Codable {
    let student: RoadmapStudentContext
    let roadmaps: [RoadmapCatalogItem]
}
