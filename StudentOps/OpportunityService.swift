import Foundation

struct OpportunityService {
    // These local records intentionally have no official URLs. The repository can be replaced by an API later without changing the Explore UI.
    static func opportunities(for profile: StudentProfile) -> [ScoredOpportunity] {
        localCatalog.map { opportunity in
            ScoredOpportunity(opportunity: opportunity, matchScore: matchScore(for: opportunity, profile: profile))
        }
        .sorted { $0.matchScore > $1.matchScore }
    }

    static func matchScore(for opportunity: Opportunity, profile: StudentProfile) -> Int {
        var score = 50
        score += profile.interests.filter { opportunity.relevantInterests.contains($0) }.count * 7
        score += (profile.strengths + profile.customSkills).filter { opportunity.relevantSkills.contains($0) }.count * 5
        score += profile.careers.filter { opportunity.relevantCareers.contains($0) }.count * 8
        score += profile.fields.filter { opportunity.relevantFields.contains($0) }.count * 8
        if opportunity.eligibleGrades.contains(profile.grade) { score += 8 }
        if profile.location.localizedCaseInsensitiveContains("Texas") && opportunity.relevantLocations.contains("Texas") { score += 6 }
        if profile.collegePlan == .yesDefinitely || profile.collegePlan == .probably { score += 3 }
        return min(max(score, 48), 99)
    }

    private static let localCatalog: [Opportunity] = [
        Opportunity(
            id: "stem-design-sprint", title: "Student STEM Design Sprint", organization: "Student OPS Local Catalog", category: .competitions,
            deadline: "October 14", location: "Online · U.S. students", eligibility: "Grades 9–12",
            description: "A project-based challenge for students who want to turn a technical idea into a clear prototype and short presentation.",
            whyItMatches: "Your interests and goals suggest a strong fit for technical project work and building a visible portfolio.",
            requirements: ["One project concept", "Short project outline", "Five-minute presentation"],
            importantDates: ["Registration closes: October 14", "Submission window: October 15–31"], officialURL: nil,
            relevantInterests: ["Technology", "AI", "Engineering", "Design"], relevantSkills: ["Problem solving", "Programming", "Building things", "Creativity"], relevantCareers: ["Software Engineer", "Biomedical Engineer", "Product Designer"], relevantFields: ["Computer Science", "Engineering", "Arts"], eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth], relevantLocations: ["Online"]
        ),
        Opportunity(
            id: "community-research-lab", title: "Community Research Lab Placement", organization: "Student OPS Local Catalog", category: .research,
            deadline: "November 2", location: "Texas · Hybrid", eligibility: "Grades 10–12",
            description: "A guided research experience pairing students with a local mentor to frame a question, document evidence, and share findings.",
            whyItMatches: "Your academic direction and interest in research align with a mentor-led experience that builds evidence-based work.",
            requirements: ["Interest statement", "Teacher or mentor reference", "Weekly availability"],
            importantDates: ["Interest form closes: November 2", "Placement conversations: November 9–16"], officialURL: nil,
            relevantInterests: ["Science", "Medicine", "Engineering", "Environment"], relevantSkills: ["Research", "Mathematics", "Communication"], relevantCareers: ["AI Researcher", "Biomedical Engineer"], relevantFields: ["Biology", "Medicine", "Engineering"], eligibleGrades: [.tenth, .eleventh, .twelfth], relevantLocations: ["Texas"]
        ),
        Opportunity(
            id: "future-leaders-cohort", title: "Future Leaders Cohort", organization: "Student OPS Local Catalog", category: .leadership,
            deadline: "December 8", location: "Online · U.S. students", eligibility: "Grades 9–12",
            description: "A small-group leadership program focused on communication, collaboration, and turning a community need into an action plan.",
            whyItMatches: "Your selected milestones and strengths point toward an opportunity to practice leadership while creating measurable impact.",
            requirements: ["Short leadership reflection", "One community challenge", "Four cohort sessions"],
            importantDates: ["Applications close: December 8", "Cohort begins: January 12"], officialURL: nil,
            relevantInterests: ["Business", "Entrepreneurship", "Education", "Environment"], relevantSkills: ["Leadership", "Communication", "Public speaking", "Teamwork"], relevantCareers: ["Product Designer"], relevantFields: ["Business", "Psychology", "Education"], eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth], relevantLocations: ["Online"]
        ),
        Opportunity(
            id: "summer-build-program", title: "Summer Build Program", organization: "Student OPS Local Catalog", category: .summerPrograms,
            deadline: "January 19", location: "U.S. · Location varies", eligibility: "Grades 9–11",
            description: "A structured summer program for students to learn a practical tool, build a project, and present what they made.",
            whyItMatches: "Your skills and project-building goals make a hands-on summer learning experience especially relevant.",
            requirements: ["Student profile", "Learning goal", "Project interest"],
            importantDates: ["Applications close: January 19", "Program dates: June–July"], officialURL: nil,
            relevantInterests: ["Technology", "Design", "Arts", "Entrepreneurship"], relevantSkills: ["Programming", "Building things", "Creativity", "Problem solving"], relevantCareers: ["Software Engineer", "Product Designer"], relevantFields: ["Computer Science", "Arts", "Business"], eligibleGrades: [.ninth, .tenth, .eleventh], relevantLocations: ["Online"]
        ),
        Opportunity(
            id: "service-studio", title: "Community Service Studio", organization: "Student OPS Local Catalog", category: .volunteering,
            deadline: "Rolling", location: "Texas · In person or hybrid", eligibility: "Grades 9–12",
            description: "A flexible service track where students choose a local organization, log contributions, and reflect on what they learned.",
            whyItMatches: "Your profile includes community-facing goals and strengths that can translate into a meaningful service project.",
            requirements: ["Choose a service focus", "Log participation", "Reflection summary"],
            importantDates: ["New placements reviewed monthly"], officialURL: nil,
            relevantInterests: ["Education", "Medicine", "Environment", "Sports"], relevantSkills: ["Communication", "Leadership", "Teamwork"], relevantCareers: [], relevantFields: ["Medicine", "Education", "Psychology"], eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth], relevantLocations: ["Texas"]
        )
    ]
}
