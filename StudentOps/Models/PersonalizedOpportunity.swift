import Foundation

// MARK: - Personalized Opportunity (mirrors server personalization/types.ts)

struct PersonalizedOpportunity: Identifiable, Hashable, Codable {
    let opportunity: RemoteOpportunity
    let eligibility: PersonalizedEligibility
    let match: PersonalizedMatch
    let freshness: PersonalizedFreshness
    let rankScore: Int
    let badges: [String]

    var id: String { opportunity.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PersonalizedOpportunity, rhs: PersonalizedOpportunity) -> Bool { lhs.id == rhs.id }
}

struct PersonalizedEligibility: Hashable, Codable {
    let status: String // "eligible", "ineligible", "unknown"
    let reasons: [EligibilityReason]
}

struct EligibilityReason: Hashable, Codable {
    let dimension: String
    let message: String
}

struct PersonalizedMatch: Hashable, Codable {
    let score: Int // 0-100
    let label: String
    let reasons: [String]
    let signals: [PersonalizedSignal]
}

struct PersonalizedSignal: Hashable, Codable {
    let dimension: String
    let score: Double // 0, 0.5, 1.0
    let reason: String
    let available: Bool
}

struct PersonalizedFreshness: Hashable, Codable {
    let status: String // "active", "upcoming", "expired", "unknown"
    let urgency: String // "urgent", "soon", "upcoming", "later", "none"
    let daysUntilDeadline: Int?
    let deadline: String?
    let reason: String
}

// MARK: - Feed Sections

struct PersonalizedFeed: Codable {
    let opportunities: [PersonalizedOpportunity]
    let sections: [FeedSection]
    let stats: FeedStats
}

struct FeedSection: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let opportunities: [PersonalizedOpportunity]
}

struct FeedStats: Codable {
    let total: Int
    let eligible: Int
    let ineligible: Int
    let unknown: Int
    let avgMatchScore: Int
}

// MARK: - Profile for Personalization

struct PersonalizationProfile: Codable {
    var age: String = ""
    var dateOfBirth: String? = nil
    var grade: String? = nil
    var schoolLevel: String? = nil
    var location: String? = nil
    var city: String? = nil
    var state: String? = nil
    var country: String? = nil
    var interests: [String] = []
    var customInterests: [String] = []
    var strengths: [String] = []
    var customSkills: [String] = []
    var careers: [String] = []
    var fields: [String] = []
    var milestones: [String] = []
    var skills: [String] = []

    // Build from StudentProfile
    init(from profile: StudentProfile) {
        self.age = profile.age
        self.grade = profile.grade.rawValue
        self.schoolLevel = profile.schoolLevel.rawValue
        self.location = profile.location
        self.interests = profile.interests
        self.customInterests = profile.customInterests
        self.strengths = profile.strengths
        self.customSkills = profile.customSkills
        self.careers = profile.careers
        self.fields = profile.fields
        self.milestones = profile.milestones
        self.skills = profile.strengths + profile.customSkills
    }

    init() {}
}

// MARK: - AI Opportunity Explanation (Phase 6.2)

struct OpportunityExplanation: Codable, Hashable {
    let whyThisFits: String
    let roadmapConnection: String
    let nextStep: String
}

struct ExplanationResponse: Codable {
    let explanation: OpportunityExplanation
}
