import Foundation

// MARK: - Seed Data (Phase 10A)
// Deterministic, non-live, demo/test data. Clearly marked as seed.
// Do not claim demo data is real or live.

enum OpportunitySeedData {
    static let seedCatalog: [Opportunity] = {
        // Helper to create source
        func seedSource(id: String, name: String, url: String? = nil) -> OpportunitySource {
            OpportunitySource(sourceID: id, sourceName: name, sourceType: .staticSeed, sourceURL: url, retrievedAt: Date(timeIntervalSince1970: 1700000000), publisher: name)
        }

        // 1. Competition - STEM Design Sprint (fresh, free, online)
        let opp1 = Opportunity(
            id: "seed-student-innovation-challenge-2026",
            title: "Student Innovation Challenge (Demo)",
            organization: "Demo Organization - Student Innovation Challenge",
            organizationDescription: "Demo seed data for testing",
            opportunityType: .competition,
            description: "Demo: A project-based challenge for students to turn a technical idea into a prototype. For testing multiple opportunity types.",
            location: OpportunityLocation(type: "online", city: nil, state: nil, country: "USA", online: true, latitude: nil, longitude: nil),
            deliveryMode: .online,
            ageRange: OpportunityAgeRange(minAge: 13, maxAge: 18),
            gradeRange: OpportunityGradeRange(gradeMin: "9", gradeMax: "12", eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth]),
            eligibilityInfo: OpportunityEligibility(details: "Open to grades 9-12", requirements: ["Interest statement"]),
            applicationRequirements: [OpportunityRequirement(title: "Project outline"), OpportunityRequirement(title: "Short video")],
            deadlineInfo: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 60, to: Date()), type: .fixed, displayString: "2026-12-01"),
            costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true),
            skills: ["Problem solving", "Programming"],
            interests: ["Technology", "Engineering"],
            careerFields: ["Computer Science"],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog", url: "https://example.com/seed"),
            sourceURL: "https://example.com/opportunities/innovation-challenge",
            lastVerified: Date(),
            status: .active
        )

        // 2. Hackathon - remote
        let opp2 = Opportunity(
            id: "seed-hackathon-remote-2026",
            title: "Demo Hackathon - Remote (Seed)",
            organization: "Demo Hackathon Org",
            opportunityType: .hackathon,
            description: "Demo remote hackathon for testing deliveryMode online and skills.",
            location: OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true, latitude: nil, longitude: nil),
            deliveryMode: .online,
            ageRange: OpportunityAgeRange(minAge: 14, maxAge: 19),
            gradeRange: OpportunityGradeRange(gradeMin: "9", gradeMax: "12", eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth]),
            eligibilityInfo: nil, // unknown eligibility
            applicationRequirements: [OpportunityRequirement(title: "Team registration")],
            deadlineInfo: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 30, to: Date()), type: .fixed, displayString: "2026-11-15"),
            costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true),
            skills: ["JavaScript", "Python"],
            interests: ["Technology"],
            careerFields: ["Computer Science"],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"),
            sourceURL: "https://example.com/hackathon-remote",
            lastVerified: Date(),
            status: .active
        )

        // 3. Scholarship - known cost free
        let opp3 = Opportunity(
            id: "seed-scholarship-demo",
            title: "Demo Scholarship - Future Scholars (Seed)",
            organization: "Demo Scholarship Foundation",
            opportunityType: .scholarship,
            description: "Demo scholarship for testing cost free and grade requirements.",
            location: OpportunityLocation(type: "unknown", city: nil, state: nil, country: nil, online: nil, latitude: nil, longitude: nil),
            deliveryMode: .unknown,
            ageRange: nil, // unknown age
            gradeRange: OpportunityGradeRange(gradeMin: "11", gradeMax: "12", eligibleGrades: [.eleventh, .twelfth]),
            eligibilityInfo: OpportunityEligibility(details: "Grades 11-12, GPA 3.0+", requirements: ["Transcript", "Essay"]),
            applicationRequirements: [OpportunityRequirement(title: "Essay"), OpportunityRequirement(title: "Transcript")],
            deadlineInfo: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 90, to: Date()), type: .fixed, displayString: "2026-12-31"),
            costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true),
            skills: ["Writing"],
            interests: ["Education"],
            careerFields: ["Education"],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"),
            sourceURL: "https://example.com/scholarship-demo",
            lastVerified: Date(timeIntervalSinceNow: -10*24*3600), // 10 days ago -> fresh
            status: .active
        )

        // 4. Research program - inPerson, age 15-18, grade 10-12, paid cost
        let opp4 = Opportunity(
            id: "seed-research-program",
            title: "Demo Research Program (Seed)",
            organization: "Demo Research Institute",
            opportunityType: .research,
            description: "Demo research program for testing inPerson and paid cost.",
            location: OpportunityLocation(type: "inPerson", city: "Austin", state: "TX", country: "USA", online: false, latitude: 30.2672, longitude: -97.7431),
            deliveryMode: .inPerson,
            ageRange: OpportunityAgeRange(minAge: 15, maxAge: 18),
            gradeRange: OpportunityGradeRange(gradeMin: "10", gradeMax: "12", eligibleGrades: [.tenth, .eleventh, .twelfth]),
            eligibilityInfo: OpportunityEligibility(details: "Ages 15-18, grades 10-12", requirements: ["Research proposal"]),
            applicationRequirements: [OpportunityRequirement(title: "Research proposal")],
            deadlineInfo: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: -10, to: Date()), type: .fixed, displayString: "2026-09-01"), // expired
            costInfo: OpportunityCost(amount: 500, currency: "USD", isFree: false),
            skills: ["Research", "Data Analysis"],
            interests: ["Science"],
            careerFields: ["Biology"],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"),
            sourceURL: "https://example.com/research-program",
            lastVerified: Date(timeIntervalSinceNow: -100*24*3600), // 100 days ago -> stale
            status: .active
        )

        // 5. Internship - age 16+, grade 11-12, hybrid, unknown cost
        let opp5 = Opportunity(
            id: "seed-internship-demo",
            title: "Demo Internship - Community Tech (Seed)",
            organization: "Demo Community Org",
            opportunityType: .internship,
            description: "Demo internship for testing hybrid and unknown cost.",
            location: OpportunityLocation(type: "hybrid", city: "Seattle", state: "WA", country: "USA", online: nil, latitude: nil, longitude: nil),
            deliveryMode: .hybrid,
            ageRange: OpportunityAgeRange(minAge: 16, maxAge: nil), // min 16, unknown max
            gradeRange: OpportunityGradeRange(gradeMin: "11", gradeMax: "12", eligibleGrades: [.eleventh, .twelfth]),
            eligibilityInfo: nil,
            applicationRequirements: [OpportunityRequirement(title: "Resume")],
            deadlineInfo: nil, // unknown deadline
            costInfo: nil, // unknown cost
            skills: ["Communication", "Teamwork"],
            interests: ["Business"],
            careerFields: ["Business"],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"),
            sourceURL: "https://example.com/internship-demo",
            lastVerified: Date(),
            status: .active
        )

        // 6. Summer program - rolling deadline
        let opp6 = Opportunity(
            id: "seed-summer-program",
            title: "Demo Summer Program - Code Camp (Seed)",
            organization: "Demo Summer Org",
            opportunityType: .summerProgram,
            description: "Demo summer program with rolling deadline for testing.",
            location: OpportunityLocation(type: "inPerson", city: "Boston", state: "MA", country: "USA", online: false, latitude: nil, longitude: nil),
            deliveryMode: .inPerson,
            ageRange: OpportunityAgeRange(minAge: 14, maxAge: 17),
            gradeRange: OpportunityGradeRange(gradeMin: "9", gradeMax: "11", eligibleGrades: [.ninth, .tenth, .eleventh]),
            eligibilityInfo: OpportunityEligibility(details: "Grades 9-11", requirements: []),
            applicationRequirements: [OpportunityRequirement(title: "Application")],
            deadlineInfo: OpportunityDeadline(date: nil, type: .rolling, displayString: "Rolling"),
            costInfo: OpportunityCost(amount: 2000, currency: "USD", isFree: false),
            skills: ["Programming"],
            interests: ["Technology"],
            careerFields: ["Computer Science"],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog", url: "https://example.com/summer"),
            sourceURL: "https://example.com/summer-program",
            lastVerified: Date(timeIntervalSinceNow: -5*24*3600),
            status: .active
        )

        // 7. Volunteering - no deadline, free
        let opp7 = Opportunity(
            id: "seed-volunteering-demo",
            title: "Demo Volunteering - City Cleanup (Seed)",
            organization: "Demo Volunteer Network",
            opportunityType: .volunteering,
            description: "Demo volunteering for testing no deadline and multiple skills.",
            location: OpportunityLocation(type: "inPerson", city: "Portland", state: "OR", country: "USA", online: false, latitude: nil, longitude: nil),
            deliveryMode: .inPerson,
            ageRange: nil,
            gradeRange: nil,
            eligibilityInfo: nil,
            applicationRequirements: [OpportunityRequirement(title: "Sign up")],
            deadlineInfo: OpportunityDeadline(date: nil, type: .noDeadline, displayString: "No deadline"),
            costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true),
            skills: ["Leadership", "Teamwork", "Communication"],
            interests: ["Environment", "Community"],
            careerFields: ["Education"],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"),
            sourceURL: "https://example.com/volunteering-demo",
            lastVerified: Date(),
            status: .active
        )

        // 8. Leadership - fellowship hybrid
        let opp8 = Opportunity(
            id: "seed-leadership-fellowship",
            title: "Demo Leadership Fellowship (Seed)",
            organization: "Demo Leadership Org",
            opportunityType: .leadership,
            description: "Demo leadership for testing fellowship and career fields.",
            location: OpportunityLocation(type: "hybrid", city: nil, state: nil, country: nil, online: nil, latitude: nil, longitude: nil),
            deliveryMode: .hybrid,
            ageRange: OpportunityAgeRange(minAge: 15, maxAge: 18),
            gradeRange: OpportunityGradeRange(gradeMin: "10", gradeMax: "12", eligibleGrades: [.tenth, .eleventh, .twelfth]),
            eligibilityInfo: OpportunityEligibility(details: "Leadership experience", requirements: ["Essay", "Recommendation"]),
            applicationRequirements: [OpportunityRequirement(title: "Essay"), OpportunityRequirement(title: "Recommendation")],
            deadlineInfo: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 45, to: Date()), type: .fixed, displayString: "2026-11-30"),
            costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true),
            skills: ["Leadership", "Public speaking"],
            interests: ["Entrepreneurship"],
            careerFields: ["Business", "Psychology"],
            source: seedSource(id: "external-api", name: "External API Demo", url: "https://api.example.com/opportunities"),
            sourceURL: "https://example.com/leadership-fellowship",
            lastVerified: Date(timeIntervalSinceNow: -40*24*3600), // 40 days ago -> aging
            status: .active
        )

        // 9. Conference - duplicate test: same as opp1 but different source ID, same title/org/deadline -> should dedupe via normalized identity
        let opp9 = Opportunity(
            id: "duplicate-innovation-challenge",
            title: "Student Innovation Challenge (Demo)", // same title as opp1
            organization: "Demo Organization - Student Innovation Challenge", // same org
            opportunityType: .competition,
            description: "Duplicate of innovation challenge from different source.",
            location: OpportunityLocation(type: "online", city: nil, state: nil, country: "USA", online: true, latitude: nil, longitude: nil),
            deliveryMode: .online,
            ageRange: OpportunityAgeRange(minAge: 13, maxAge: 18),
            gradeRange: OpportunityGradeRange(gradeMin: "9", gradeMax: "12", eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth]),
            eligibilityInfo: OpportunityEligibility(details: "Open to grades 9-12", requirements: ["Interest statement"]),
            applicationRequirements: [OpportunityRequirement(title: "Project outline")],
            deadlineInfo: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 60, to: Date()), type: .fixed, displayString: "2026-12-01"), // same deadline as opp1
            costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true),
            skills: ["Problem solving", "Programming"],
            interests: ["Technology"],
            careerFields: ["Computer Science"],
            source: seedSource(id: "external-json", name: "External JSON Feed", url: "https://example.com/json"),
            sourceURL: "https://example.com/opportunities/innovation-challenge", // same URL as opp1 -> dedupe via URL
            lastVerified: Date(),
            status: .active
        )

        // 10. Expired record - same as opp4 but verified expired
        let opp10 = Opportunity(
            id: "seed-expired-demo",
            title: "Demo Expired Opportunity (Seed)",
            organization: "Demo Expired Org",
            opportunityType: .conference,
            description: "Demo expired for testing freshness expired.",
            location: OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true, latitude: nil, longitude: nil),
            deliveryMode: .online,
            ageRange: nil,
            gradeRange: nil,
            eligibilityInfo: nil,
            applicationRequirements: [],
            deadlineInfo: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: -30, to: Date()), type: .fixed, displayString: "2026-08-01"),
            costInfo: nil,
            skills: [],
            interests: [],
            careerFields: [],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"),
            sourceURL: "https://example.com/expired-demo",
            lastVerified: Date(timeIntervalSinceNow: -200*24*3600),
            status: .expired
        )

        // 11. Stale record - lastVerified 200 days ago, no deadline
        let opp11 = Opportunity(
            id: "seed-stale-demo",
            title: "Demo Stale Opportunity (Seed)",
            organization: "Demo Stale Org",
            opportunityType: .community,
            description: "Demo stale for testing freshness stale.",
            location: OpportunityLocation(type: "unknown", city: nil, state: nil, country: nil, online: nil, latitude: nil, longitude: nil),
            deliveryMode: .unknown,
            ageRange: nil,
            gradeRange: nil,
            eligibilityInfo: nil,
            applicationRequirements: [],
            deadlineInfo: nil,
            costInfo: nil,
            skills: [],
            interests: [],
            careerFields: [],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"),
            sourceURL: "https://example.com/stale-demo",
            lastVerified: Date(timeIntervalSinceNow: -200*24*3600),
            status: .active
        )

        // 12. Fresh record - verified today
        let opp12 = Opportunity(
            id: "seed-fresh-demo",
            title: "Demo Fresh Opportunity (Seed)",
            organization: "Demo Fresh Org",
            opportunityType: .other,
            description: "Demo fresh for testing.",
            location: OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true, latitude: nil, longitude: nil),
            deliveryMode: .online,
            ageRange: nil,
            gradeRange: nil,
            eligibilityInfo: nil,
            applicationRequirements: [],
            deadlineInfo: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 10, to: Date()), type: .fixed, displayString: "2026-10-01"),
            costInfo: nil,
            skills: ["Communication"],
            interests: ["Education"],
            careerFields: ["Psychology"],
            source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"),
            sourceURL: "https://example.com/fresh-demo",
            lastVerified: Date(),
            status: .active
        )

        return [opp1, opp2, opp3, opp4, opp5, opp6, opp7, opp8, opp9, opp10, opp11, opp12]
    }()

    // Deterministic ordering for repository
    static var sortedSeed: [Opportunity] {
        seedCatalog.sorted { a, b in
            if a.title.lowercased() != b.title.lowercased() { return a.title.lowercased() < b.title.lowercased() }
            if a.organization.lowercased() != b.organization.lowercased() { return a.organization.lowercased() < b.organization.lowercased() }
            return a.id < b.id
        }
    }
}
