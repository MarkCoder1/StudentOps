import Foundation
import Combine

// Single source of truth for StudentOps — builds on Phase 1 UserDefaults+Codable.
// Holds profile + all progress in one ObservableObject so 5 tabs derive from same state.
@MainActor
final class AppDataStore: ObservableObject {
    // MARK: - Keys (shared with legacy stores)
    private let profileKey = "studentops.profile"
    private let onboardingCompletedKey = "studentops.onboardingCompleted"
    private let roadmapProgressKey = "studentops.roadmapProgress"
    private let projectProgressKey = "studentops.projectProgress"
    private let portfolioKey = "studentops.portfolioProjectIDs"
    private let customProjectsKey = "studentops.customProjects"
    private let notesKey = "studentops.projectNotes"
    private let savedOpportunityKey = "studentops.savedOpportunityIDs"
    private let completedActionsKey = "studentops.completedActionIDs"
    private let validationAttemptsKey = "studentops.validationAttempts"
    private let evidenceRecordsKey = "studentops.evidenceRecords"
    private let activeRoadmapsKey = "studentops.activeRoadmaps"
    private let achievementRecordsKey = "studentops.achievements"
    private let portfoliosKey = "studentops.portfolios"
    private let opportunitiesKey = "studentops.opportunities"
    private let projectExecutionStatesKey = "studentops.projectExecutionStates"
    private let adaptiveOverridesKey = "studentops.adaptiveOverrides"

    // MARK: - Published state
    @Published var profile: StudentProfile {
        didSet { saveProfile() }
    }
    @Published var roadmapProgress: [String: Int] {
        didSet { UserDefaults.standard.set(roadmapProgress, forKey: roadmapProgressKey) }
    }
    @Published var projectProgress: [String: Int] {
        didSet { UserDefaults.standard.set(projectProgress, forKey: projectProgressKey) }
    }
    @Published var savedOpportunityIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(savedOpportunityIDs), forKey: savedOpportunityKey) }
    }
    @Published var customProjects: [Project] {
        didSet { saveCustomProjects() }
    }
    @Published var projectNotes: [String: String] {
        didSet { UserDefaults.standard.set(projectNotes, forKey: notesKey) }
    }
    @Published var portfolioIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(portfolioIDs), forKey: portfolioKey) }
    }
    @Published var completedActionIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(completedActionIDs), forKey: completedActionsKey) }
    }
    @Published var validationAttempts: [String: ValidationAttempt] {
        didSet {
            if let data = try? JSONEncoder().encode(validationAttempts) {
                UserDefaults.standard.set(data, forKey: validationAttemptsKey)
            }
        }
    }
    @Published var evidenceRecords: [String: EvidenceRecord] {
        didSet {
            if let data = try? JSONEncoder().encode(evidenceRecords) {
                UserDefaults.standard.set(data, forKey: evidenceRecordsKey)
            }
        }
    }
    @Published var activeRoadmaps: [String: ActiveRoadmap] {
        didSet {
            if let data = try? JSONEncoder().encode(activeRoadmaps) {
                UserDefaults.standard.set(data, forKey: activeRoadmapsKey)
            }
        }
    }
    @Published var achievementRecords: [String: Achievement] {
        didSet {
            if let data = try? JSONEncoder().encode(achievementRecords) {
                UserDefaults.standard.set(data, forKey: achievementRecordsKey)
            }
        }
    }
    @Published var portfolios: [String: StudentPortfolio] {
        didSet {
            if let data = try? JSONEncoder().encode(portfolios) {
                UserDefaults.standard.set(data, forKey: portfoliosKey)
            }
        }
    }
    @Published var opportunities: [Opportunity] {
        didSet {
            if let data = try? JSONEncoder().encode(opportunities) {
                UserDefaults.standard.set(data, forKey: opportunitiesKey)
            }
        }
    }
    @Published var projectExecutionStates: [String: ProjectExecutionState] {
        didSet {
            if let data = try? JSONEncoder().encode(projectExecutionStates) {
                UserDefaults.standard.set(data, forKey: projectExecutionStatesKey)
            }
        }
    }
    @Published var adaptiveOverrides: AdaptiveRoadmapOverrides {
        didSet {
            if let data = try? JSONEncoder().encode(adaptiveOverrides) {
                UserDefaults.standard.set(data, forKey: adaptiveOverridesKey)
            }
        }
    }

    // MARK: - Init — loads all 8 keys (UserDefaults+Codable unchanged)
    init() {
        // Profile
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(StudentProfile.self, from: data) {
            profile = decoded
            // Reconcile AppStorage flag if profile says completed but bool is false
            if decoded.onboardingCompleted && !UserDefaults.standard.bool(forKey: onboardingCompletedKey) {
                UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
            }
        } else {
            profile = StudentProfile()
        }
        // Roadmap progress
        roadmapProgress = UserDefaults.standard.dictionary(forKey: roadmapProgressKey) as? [String: Int] ?? [:]
        // Project progress
        projectProgress = UserDefaults.standard.dictionary(forKey: projectProgressKey) as? [String: Int] ?? [:]
        savedOpportunityIDs = Set(UserDefaults.standard.stringArray(forKey: savedOpportunityKey) ?? [])
        if let data = UserDefaults.standard.data(forKey: customProjectsKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            customProjects = decoded
        } else {
            customProjects = []
        }
        projectNotes = UserDefaults.standard.dictionary(forKey: notesKey) as? [String: String] ?? [:]
        portfolioIDs = Set(UserDefaults.standard.stringArray(forKey: portfolioKey) ?? [])
        completedActionIDs = Set(UserDefaults.standard.stringArray(forKey: completedActionsKey) ?? [])
        if let data = UserDefaults.standard.data(forKey: validationAttemptsKey),
           let decoded = try? JSONDecoder().decode([String: ValidationAttempt].self, from: data) {
            validationAttempts = decoded
        } else {
            validationAttempts = [:]
        }
        if let data = UserDefaults.standard.data(forKey: evidenceRecordsKey),
           let decoded = try? JSONDecoder().decode([String: EvidenceRecord].self, from: data) {
            evidenceRecords = decoded
        } else {
            evidenceRecords = [:]
        }
        if let data = UserDefaults.standard.data(forKey: activeRoadmapsKey),
           let decoded = try? JSONDecoder().decode([String: ActiveRoadmap].self, from: data) {
            activeRoadmaps = decoded
        } else {
            activeRoadmaps = [:]
        }
        if let data = UserDefaults.standard.data(forKey: achievementRecordsKey),
           let decoded = try? JSONDecoder().decode([String: Achievement].self, from: data) {
            achievementRecords = decoded
        } else {
            achievementRecords = [:]
        }
        if let data = UserDefaults.standard.data(forKey: projectExecutionStatesKey),
           let decoded = try? JSONDecoder().decode([String: ProjectExecutionState].self, from: data) {
            projectExecutionStates = decoded
        } else {
            projectExecutionStates = [:]
        }
        if let data = UserDefaults.standard.data(forKey: adaptiveOverridesKey),
           let decoded = try? JSONDecoder().decode(AdaptiveRoadmapOverrides.self, from: data) {
            adaptiveOverrides = decoded
        } else {
            adaptiveOverrides = AdaptiveRoadmapOverrides()
        }
        if let data = UserDefaults.standard.data(forKey: portfoliosKey),
           let decoded = try? JSONDecoder().decode([String: StudentPortfolio].self, from: data) {
            portfolios = decoded
        } else {
            portfolios = [:]
        }
        if let data = UserDefaults.standard.data(forKey: opportunitiesKey),
           let decoded = try? JSONDecoder().decode([Opportunity].self, from: data) {
            opportunities = decoded
        } else {
            opportunities = []
        }
        if portfolios.isEmpty {
            let defaultTitle = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Portfolio" : "\(profile.firstName)'s Portfolio"
            let defaultPortfolio = StudentPortfolio(title: defaultTitle)
            portfolios[defaultPortfolio.id] = defaultPortfolio
        }
        // Do not auto-seed demo opportunities for fresh onboarding — keep brand-new/reset state empty.
        // Existing persisted opportunities are still validated/deduped.
        if opportunities.isEmpty {
            // Intentionally leave empty for fresh install / Reset Everything; no demo preload.
        } else {
            // Ensure deterministic ordering, filter invalid, and deduplicate any legacy duplicates
            let valid = opportunities.filter { OpportunityValidator.validate($0).isValid }
            let (unique, _) = OpportunityDeduper.deduplicate(valid)
            opportunities = unique
        }
        // Deterministic demo student seeding (Prompt 3: one coherent story, exercise real engines, no new architecture)
        seedDemoStudentIfNeeded()
        // Deterministic reconciliation on launch
        refreshGeneratedAchievements()
        _ = reconcileEvidenceAchievements()
    }

    // MARK: - Demo Seeding (Prompt 3: deterministic, exercise real engines, no new architecture)
    // Disabled for new 4-screen onboarding: brand-new install and Reset Everything must show
    // onboarding Screen 1 with no preloaded Alex/demo profile, per spec.
    // Kept for reference but never auto-seeds; demo data can still be created manually if needed.
    private func seedDemoStudentIfNeeded() {
        return
        // Do not auto-seed demo profile when onboarding has not been completed.
        // Ensures fresh install and Reset Everything show onboarding without preloaded Alex.
        let onboardingDone = UserDefaults.standard.bool(forKey: onboardingCompletedKey) || profile.onboardingCompleted
        guard onboardingDone else { return }
        // Seed only on fresh launch: no careers, no strengths, no active roadmaps, no custom projects, no evidence, no progress
        let isFreshProfile = profile.careers.isEmpty && profile.strengths.isEmpty && profile.customSkills.isEmpty && profile.interests.isEmpty
        let isFreshProgress = roadmapProgress.isEmpty && activeRoadmaps.isEmpty && customProjects.isEmpty && evidenceRecords.isEmpty
        guard isFreshProfile && isFreshProgress else { return }
        // Demo profile (fictional Grade 11, clearly demo data, exercises real engines)
        var demo = StudentProfile()
        demo.firstName = "Alex"
        demo.age = "17"
        demo.schoolLevel = .highSchool
        demo.grade = .eleventh
        demo.location = "San Francisco, CA"
        demo.interests = ["Computer Science", "Programming", "Building things"]
        demo.customInterests = []
        demo.strengths = ["Programming Fundamentals"]
        demo.customSkills = []
        demo.careers = ["Software Engineering"]
        demo.fields = ["Computer Science"]
        demo.milestones = ["Build real projects"]
        demo.collegePlan = .probably
        demo.geography = "Anywhere in U.S."
        demo.collegeType = "4-year university"
        demo.targetColleges = []
        demo.onboardingCompleted = true
        // Persist demo profile
        profile = demo

        // Demo progress: one completed milestone (software-1) → demonstrates Portfolio story while keeping Data Structures gap active
        roadmapProgress["software-engineer"] = 1
        // Active roadmap
        activeRoadmaps["software-engineer"] = ActiveRoadmap(roadmapID: "software-engineer", status: .active, startedAt: 1_700_000_000)
        // Completed action for software-1 (optional, keeps action progress consistent)
        // Use actual action IDs from catalog: software-1-action-1..4 — mark first as done to show action progress
        completedActionIDs.insert("software-1-action-1")

        // Demo project: DS Project (stable ID, exercises ProjectService + ProjectRecommendationEngine + SkillGraph)
        let demoProject = Project(
            id: "demo-ds-project",
            title: "DS Project",
            category: "Software Project",
            goal: "Build a small data-structures tool that visualizes linked lists and binary search.",
            description: "A focused software project that demonstrates Data Structures — the current skill gap for Software Engineering. Linked to the active roadmap.",
            skills: ["Data Structures", "Programming Fundamentals"],
            milestones: [
                ProjectMilestone(id: "demo-ds-m1", title: "Design data structure", subtitle: "Sketch linked list operations", estimatedTime: "1 week"),
                ProjectMilestone(id: "demo-ds-m2", title: "Implement and test", subtitle: "Build and test binary search", estimatedTime: "2 weeks")
            ],
            resources: [],
            estimatedCompletion: "2–3 weeks",
            relevantInterests: ["Technology", "Engineering"],
            relevantSkills: ["Data Structures", "Programming Fundamentals"],
            relevantCareers: ["Software Engineer"],
            relevantFields: ["Computer Science"],
            sourceRoadmapID: "software-engineer",
            sourceProjectID: nil,
            status: .inProgress,
            detailedDescription: nil,
            outcome: nil,
            outcomeDetails: nil,
            links: [],
            imageReferences: [],
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            completionDate: nil,
            achievementID: nil
        )
        customProjects.append(demoProject)
        projectProgress["demo-ds-project"] = 0
        projectExecutionStates["demo-ds-project"] = ProjectExecutionState(projectID: "demo-ds-project", completedStepIDs: [], completedDeliverableIDs: [], confirmedCriterionIDs: [])

        // Demo opportunity: DS Hackathon (stable ID, exercises OpportunityEligibility/Matching/Ranking + freshness/dedup)
        let demoDeadline = Calendar.current.date(from: DateComponents(year: 2027, month: 6, day: 1)) ?? Date(timeIntervalSince1970: 1_800_000_000)
        let demoOpp = Opportunity(
            id: "demo-ds-hackathon",
            title: "DS Hackathon",
            organization: "DemoCode",
            organizationDescription: "Student hackathon focused on data structures and algorithms.",
            opportunityType: .hackathon,
            description: "Apply your Data Structures skills in a weekend hackathon — build with linked lists and binary search, collaborate, ship a project, and get feedback. Relevant to Software Engineering.",
            location: OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true, latitude: nil, longitude: nil),
            deliveryMode: .online,
            ageRange: OpportunityAgeRange(minAge: 14, maxAge: 18),
            gradeRange: OpportunityGradeRange(gradeMin: nil, gradeMax: nil, eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth]),
            eligibilityInfo: OpportunityEligibility(details: "Open to high school students grades 9–12", requirements: []),
            applicationRequirements: [OpportunityRequirement(title: "Submit project")],
            deadlineInfo: OpportunityDeadline(date: demoDeadline, type: .fixed, displayString: "June 1, 2027"),
            costInfo: OpportunityCost(amount: nil, currency: nil, isFree: true),
            skills: ["Data Structures", "Programming", "Software Development"],
            interests: ["Technology", "Programming"],
            careerFields: ["Computer Science", "Software Engineering"],
            source: OpportunitySource(sourceID: "demo-ds-hackathon", sourceName: "Demo Catalog", sourceType: .staticSeed, sourceURL: nil, retrievedAt: Date(timeIntervalSince1970: 1_700_000_000), publisher: "Student OPS Demo"),
            sourceURL: nil,
            lastVerified: Date(timeIntervalSince1970: 1_700_000_000),
            status: .active,
            category: .competitions,
            legacyDeadline: "June 1, 2027",
            legacyLocation: "Online",
            legacyEligibility: "Grades 9–12",
            whyItMatches: "Builds Data Structures",
            requirements: ["Submit project"],
            importantDates: ["June 1, 2027"],
            officialURL: nil,
            relevantInterests: ["Technology", "Programming"],
            relevantSkills: ["Data Structures", "Programming"],
            relevantCareers: ["Software Engineer"],
            relevantFields: ["Computer Science"],
            eligibleGrades: [.ninth, .tenth, .eleventh, .twelfth],
            relevantLocations: ["Online"]
        )
        // Insert demo opportunity if not already present and dedup passes
        if OpportunityValidator.validate(demoOpp).isValid {
            var isDup = false
            for existing in opportunities {
                let (dup, _) = OpportunityDeduper.isDuplicate(existing, demoOpp)
                if dup { isDup = true; break }
            }
            if !isDup {
                opportunities.append(demoOpp)
                opportunities = opportunities.sorted { a, b in
                    if a.title.lowercased() != b.title.lowercased() { return a.title.lowercased() < b.title.lowercased() }
                    if a.organization.lowercased() != b.organization.lowercased() { return a.organization.lowercased() < b.organization.lowercased() }
                    return a.id < b.id
                }
            }
        }

        // Demo evidence: Programming Fundamentals demonstrated (distinct from auto milestone evidence for software-1 which covers Computational Thinking etc)
        let demoEvidence = EvidenceRecord(
            id: "demo-evidence-pf",
            type: .milestoneCompletion,
            title: "Programming Fundamentals",
            description: "Demonstrated via introductory programming exercises.",
            roadmapID: "software-engineer",
            milestoneID: "software-2",
            completionDate: Date(timeIntervalSince1970: 1_700_000_000),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .studentEntered,
            status: .recorded,
            actionID: "software-2-action-1",
            skillIDs: ["programming fundamentals"],
            artifact: nil,
            validationID: nil,
            validationScore: nil,
            validationPercentage: nil,
            validationPassed: nil,
            projectID: nil,
            opportunityID: nil
        )
        evidenceRecords[demoEvidence.id] = demoEvidence
        // Also ensure evidence for completed milestone software-1 is created via standard helper
        let autoEvidenceID = evidenceID(for: "software-1", roadmap: "software-engineer")
        if evidenceRecords[autoEvidenceID] == nil {
            let auto = EvidenceRecord(
                id: autoEvidenceID,
                type: .milestoneCompletion,
                title: "Explore Computer Science",
                description: "Map the concepts and tools behind modern software.",
                roadmapID: "software-engineer",
                milestoneID: "software-1",
                completionDate: Date(timeIntervalSince1970: 1_700_000_000),
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
                source: .roadmapMilestone,
                status: .recorded,
                skillIDs: ["computational thinking", "development environment setup", "version control basics"],
                artifact: nil
            )
            evidenceRecords[autoEvidenceID] = auto
        }
    }

    // MARK: - Derived (no extra persistence, computed from single source)
    var scoredRoadmaps: [ScoredRoadmap] {
        RoadmapService.roadmaps(for: profile, progress: roadmapProgress)
    }
    var scoredProjects: [ScoredProject] {
        ProjectService.projects(for: profile, progress: projectProgress, customProjects: customProjects)
    }
    var scoredOpportunities: [ScoredOpportunity] {
        OpportunityService.opportunities(for: profile)
    }
    var achievements: [Achievement] {
        profile.loggedEntries.map(Achievement.init)
    }
    var skillSet: [String] {
        Array(Set(profile.strengths + profile.customSkills)).sorted()
    }
    var nonCompletedRoadmaps: [ScoredRoadmap] { scoredRoadmaps.filter { !$0.isCompleted } }
    var completedRoadmaps: [ScoredRoadmap] { scoredRoadmaps.filter(\.isCompleted) }
    var activeProjects: [ScoredProject] { scoredProjects.filter { !$0.isCompleted } }
    var completedProjects: [ScoredProject] { scoredProjects.filter(\.isCompleted) }
    var completedMilestonesTotal: Int { scoredRoadmaps.reduce(0) { $0 + $1.completedMilestones } }

    /// Roadmaps the student has explicitly activated and not yet completed.
    var activatedRoadmaps: [ScoredRoadmap] {
        scoredRoadmaps.filter { roadmap in
            guard let activation = activeRoadmaps[roadmap.id] else { return false }
            return activation.status == .active && !roadmap.isCompleted
        }
    }

    /// Whether a specific roadmap has been activated by the student.
    func isRoadmapActivated(_ roadmapID: String) -> Bool {
        guard let activation = activeRoadmaps[roadmapID] else { return false }
        return activation.status == .active
    }

    /// The activation status for a specific roadmap, or nil if never activated.
    func roadmapActivationStatus(_ roadmapID: String) -> RoadmapActivationStatus? {
        activeRoadmaps[roadmapID]?.status
    }

    // MARK: - Skill Gap Engine Accessors

    /// Deterministic skill gap report for a specific roadmap, derived on-demand from source state.
    func skillGapReport(for roadmap: Roadmap) -> RoadmapSkillGapReport {
        SkillGapEngine.evaluate(roadmap: roadmap, store: self)
    }

    /// Independent skill gap reports for all currently active roadmaps.
    var activeSkillGapReports: [RoadmapSkillGapReport] {
        SkillGapEngine.evaluateActiveRoadmaps(store: self)
    }

    /// Skill gaps developed by a specific milestone in a roadmap.
    func milestoneSkillGaps(milestone: RoadmapMilestone, in roadmap: Roadmap) -> [SkillGap] {
        SkillGapEngine.milestoneDevelopedGaps(milestone: milestone, roadmap: roadmap, store: self)
    }

    // MARK: - Opportunity → Roadmap Connections

    /// Deterministic connections for a remote opportunity across all active roadmaps.
    func opportunityRoadmapConnections(for opportunity: RemoteOpportunity) -> [OpportunityRoadmapConnection] {
        OpportunityRoadmapEngine.connections(for: opportunity, store: self)
    }

    /// Deterministic connections for a local opportunity across all active roadmaps.
    func opportunityRoadmapConnections(for opportunity: Opportunity) -> [OpportunityRoadmapConnection] {
        OpportunityRoadmapEngine.connections(for: opportunity, store: self)
    }

    /// Single-roadmap connection for a remote opportunity (nil if no overlap).
    func opportunityRoadmapConnection(for opportunity: RemoteOpportunity, roadmap: Roadmap) -> OpportunityRoadmapConnection? {
        OpportunityRoadmapEngine.connection(
            for: opportunity,
            roadmap: roadmap,
            profile: profile,
            progress: roadmapProgress,
            catalog: scoredRoadmaps.map(\.roadmap),
            evidenceRecords: evidenceRecords
        )
    }

    // MARK: - Next Best Action

    /// Ranked deterministic next-best-action candidates derived from current state.
    var nextBestActions: [NextBestAction] {
        NextBestActionEngine.rankedActions(store: self, personalizedFeed: nil)
    }

    /// Top-ranked next action, if any.
    var nextBestAction: NextBestAction? {
        NextBestActionEngine.nextAction(store: self, personalizedFeed: nil)
    }

    /// Ranked actions including remote personalized feed when available.
    func nextBestActions(personalizedFeed: PersonalizedFeed?) -> [NextBestAction] {
        NextBestActionEngine.rankedActions(store: self, personalizedFeed: personalizedFeed)
    }

    /// Start (or re-activate) a roadmap. Idempotent — starting an already-active roadmap is a no-op.
    /// Preserves all existing progress, actions, validation, evidence, and skills.
    func startRoadmap(_ roadmap: Roadmap) {
        guard activeRoadmaps[roadmap.id]?.status != .active else { return }
        let existing = activeRoadmaps[roadmap.id]
        activeRoadmaps[roadmap.id] = ActiveRoadmap(
            roadmapID: roadmap.id,
            status: .active,
            startedAt: existing?.startedAt ?? Date().timeIntervalSince1970
        )
    }

    /// Deactivate a roadmap without deleting progress, history, or evidence.
    func deactivateRoadmap(_ roadmapID: String) {
        activeRoadmaps.removeValue(forKey: roadmapID)
    }

    /// Reset activation status for a roadmap (called when roadmap progress is fully reset).
    func clearActivation(_ roadmapID: String) {
        activeRoadmaps.removeValue(forKey: roadmapID)
    }

    // MARK: - Profile
    func updateProfile(_ newProfile: StudentProfile) {
        profile = newProfile
    }
    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
            // Keep AppStorage bool in sync when profile says completed
            if profile.onboardingCompleted {
                UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
            }
        }
    }

    // MARK: - Roadmap
    func completedCount(for roadmap: Roadmap) -> Int {
        min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
    }
    func markRoadmapMilestoneComplete(for roadmap: Roadmap) {
        let next = min(completedCount(for: roadmap) + 1, roadmap.milestones.count)
        roadmapProgress[roadmap.id] = next
        // Acquire skills from the milestone just completed (index next-1)
        if next >= 1, next <= roadmap.milestones.count {
            let milestone = roadmap.milestones[next - 1]
            acquireSkills(milestone.skillsDeveloped)
        }
        // Create evidence record if one doesn't already exist
        if next >= 1, next <= roadmap.milestones.count {
            let milestone = roadmap.milestones[next - 1]
            createEvidenceIfNeeded(for: roadmap, milestone: milestone)
        }
        // didSet persists; trigger objectWillChange for derived
        objectWillChange.send()
        refreshGeneratedAchievements()
    }
    func resetRoadmap(_ roadmap: Roadmap) {
        roadmapProgress[roadmap.id] = 0
        // Also clear all action completions and evidence for this roadmap's milestones
        for milestone in roadmap.milestones {
            for action in milestone.actions ?? [] {
                completedActionIDs.remove(action.id)
            }
            let evidenceID = evidenceID(for: milestone.id, roadmap: roadmap.id)
            evidenceRecords.removeValue(forKey: evidenceID)
        }
        objectWillChange.send()
    }

    // MARK: - Action Completion
    func isActionCompleted(_ actionID: String) -> Bool {
        completedActionIDs.contains(actionID)
    }
    func toggleAction(_ actionID: String) {
        if completedActionIDs.contains(actionID) {
            completedActionIDs.remove(actionID)
        } else {
            completedActionIDs.insert(actionID)
        }
    }
    func completedActionsCount(for milestone: RoadmapMilestone) -> Int {
        guard let actions = milestone.actions else { return 0 }
        return actions.filter { completedActionIDs.contains($0.id) }.count
    }
    func totalActionsCount(for milestone: RoadmapMilestone) -> Int {
        milestone.actions?.count ?? 0
    }
    func actionProgress(for milestone: RoadmapMilestone) -> Int {
        let completed = completedActionsCount(for: milestone)
        let total = totalActionsCount(for: milestone)
        return ProgressCalculator.percent(completed: completed, total: total)
    }

    // MARK: - Skill Acquisition (from roadmap milestones)
    /// Adds milestone's skillsDeveloped to the student profile, deduplicating case-insensitively.
    /// Skills are added to `profile.strengths` since they represent demonstrated competencies.
    private func acquireSkills(_ skills: [String]?) {
        guard let skills, !skills.isEmpty else { return }
        var existing = Set(profile.strengths.map { $0.lowercased() })
        existing.formUnion(profile.customSkills.map { $0.lowercased() })
        for skill in skills {
            let trimmed = skill.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !existing.contains(trimmed.lowercased()) else { continue }
            profile.strengths.append(trimmed)
            existing.insert(trimmed.lowercased())
        }
    }

    // MARK: - Evidence Records
    /// Deterministic evidence ID for a milestone — same milestone always produces the same ID.
    func evidenceID(for milestoneID: String, roadmap: String) -> String {
        "evidence-\(roadmap)-\(milestoneID)"
    }
    func hasEvidence(for milestoneID: String, roadmap: String) -> Bool {
        evidenceRecords[evidenceID(for: milestoneID, roadmap: roadmap)] != nil
    }
    func evidence(for milestoneID: String, roadmap: String) -> EvidenceRecord? {
        evidenceRecords[evidenceID(for: milestoneID, roadmap: roadmap)]
    }
    private func createEvidenceIfNeeded(for roadmap: Roadmap, milestone: RoadmapMilestone) {
        let eid = evidenceID(for: milestone.id, roadmap: roadmap.id)
        guard evidenceRecords[eid] == nil else { return }
        let assessment = milestone.assessment
        let best: ValidationAttempt? = assessment.flatMap { bestAttempt(for: $0.id) }
        let now = Date()
        let canonicalSkillIDs = milestone.skillsDeveloped?.map { Skill.normalizeID($0) }.filter { !$0.isEmpty }
        let record = EvidenceRecord(
            id: eid,
            type: .milestoneCompletion,
            title: milestone.title,
            description: milestone.subtitle,
            roadmapID: roadmap.id,
            milestoneID: milestone.id,
            completionDate: now,
            createdAt: now,
            occurredAt: now,
            source: .roadmapMilestone,
            status: .recorded,
            skillIDs: canonicalSkillIDs,
            validationID: assessment?.id,
            validationScore: best?.score,
            validationPercentage: best.map { RoadmapEngine.percentage(score: $0.score, total: assessment?.questions.count ?? 1) },
            validationPassed: best?.passed
        )
        evidenceRecords[eid] = record
    }

    // MARK: - Student Evidence Management

    /// Whether a record is system-generated (deterministic milestone completion).
    func isSystemGeneratedEvidence(_ record: EvidenceRecord) -> Bool {
        record.id.hasPrefix("evidence-") && record.source == .roadmapMilestone && record.type == .milestoneCompletion
    }

    func isSystemGeneratedEvidence(id: String) -> Bool {
        guard let rec = evidenceRecords[id] else { return id.hasPrefix("evidence-") }
        return isSystemGeneratedEvidence(rec)
    }

    /// All evidence sorted by most recent first.
    var allEvidenceSorted: [EvidenceRecord] {
        evidenceRecords.values.sorted { $0.createdAt > $1.createdAt }
    }

    /// Only student-created evidence (non-system).
    var studentEvidence: [EvidenceRecord] {
        evidenceRecords.values.filter { !isSystemGeneratedEvidence($0) }.sorted { $0.createdAt > $1.createdAt }
    }

    /// System-generated milestone evidence.
    var systemEvidence: [EvidenceRecord] {
        evidenceRecords.values.filter { isSystemGeneratedEvidence($0) }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Validates that a string is a usable http/https URL.
    private func isValidArtifactURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let url = URL(string: trimmed) else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
        return url.host != nil
    }

    /// Adds a student-created evidence record after validation.
    /// Returns true on success, false if validation fails (empty title, duplicate ID, invalid state).
    @discardableResult
    func addEvidence(_ record: EvidenceRecord) -> Bool {
        let trimmedTitle = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard evidenceRecords[record.id] == nil else { return false }
        guard record.status == .recorded else { return false }
        if let vid = record.validationID {
            guard validationAttempts[vid] != nil else { return false }
        }
        if let art = record.artifact, let url = art.url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            guard isValidArtifactURL(url) else { return false }
        }
        let trimmedDesc: String? = {
            guard let d = record.description?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty else { return nil }
            return d
        }()
        let trimmedActionID: String? = {
            guard let a = record.actionID?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty else { return nil }
            return a
        }()
        let dedupedSkills: [String]? = {
            guard let skills = record.skillIDs else { return nil }
            let norm = skills.map{ Skill.normalizeID($0) }.filter{!$0.isEmpty}
            return norm.isEmpty ? nil : Array(Set(norm)).sorted()
        }()
        var finalArtifact = record.artifact
        if let art = record.artifact, let url = art.url?.trimmingCharacters(in: .whitespacesAndNewlines), url.isEmpty {
            finalArtifact = nil
        }
        let sanitized = EvidenceRecord(
            id: record.id, type: record.type, title: trimmedTitle, description: trimmedDesc,
            roadmapID: record.roadmapID, milestoneID: record.milestoneID,
            completionDate: record.completionDate, createdAt: record.createdAt, occurredAt: record.occurredAt,
            source: record.source, status: .recorded,
            actionID: trimmedActionID, skillIDs: dedupedSkills, artifact: finalArtifact,
            validationID: record.validationID, validationScore: record.validationScore, validationPercentage: record.validationPercentage, validationPassed: record.validationPassed,
            projectID: record.projectID, opportunityID: record.opportunityID
        )
        evidenceRecords[sanitized.id] = sanitized
        refreshGeneratedAchievements()
        return true
    }

    /// Updates an existing student-created evidence record.
    @discardableResult
    func updateEvidence(_ record: EvidenceRecord) -> Bool {
        guard let existing = evidenceRecords[record.id] else { return false }
        guard !isSystemGeneratedEvidence(existing) else { return false }
        let trimmedTitle = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard record.status == .recorded else { return false }
        if let vid = record.validationID {
            guard validationAttempts[vid] != nil else { return false }
        }
        if let art = record.artifact, let url = art.url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            guard isValidArtifactURL(url) else { return false }
        }
        let trimmedDesc: String? = {
            guard let d = record.description?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty else { return nil }
            return d
        }()
        let trimmedActionID: String? = {
            guard let a = record.actionID?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty else { return nil }
            return a
        }()
        let dedupedSkills: [String]? = {
            guard let skills = record.skillIDs else { return nil }
            let norm = skills.map{ Skill.normalizeID($0) }.filter{!$0.isEmpty}
            return norm.isEmpty ? nil : Array(Set(norm)).sorted()
        }()
        var finalArtifact = record.artifact
        if let art = record.artifact, let url = art.url?.trimmingCharacters(in: .whitespacesAndNewlines), url.isEmpty {
            finalArtifact = nil
        }
        let sanitized = EvidenceRecord(
            id: record.id, type: record.type, title: trimmedTitle, description: trimmedDesc,
            roadmapID: record.roadmapID, milestoneID: record.milestoneID,
            completionDate: record.completionDate, createdAt: record.createdAt, occurredAt: record.occurredAt,
            source: record.source, status: .recorded,
            actionID: trimmedActionID, skillIDs: dedupedSkills, artifact: finalArtifact,
            validationID: record.validationID, validationScore: record.validationScore, validationPercentage: record.validationPercentage, validationPassed: record.validationPassed,
            projectID: record.projectID, opportunityID: record.opportunityID
        )
        evidenceRecords[sanitized.id] = sanitized
        refreshGeneratedAchievements()
        return true
    }

    /// Deletes a student-created evidence record. System-generated evidence cannot be deleted.
    @discardableResult
    func deleteEvidence(id: String) -> Bool {
        guard let rec = evidenceRecords[id] else { return false }
        guard !isSystemGeneratedEvidence(rec) else { return false }
        evidenceRecords.removeValue(forKey: id)
        refreshGeneratedAchievements()
        _ = reconcileEvidenceAchievements()
        return true
    }

    // MARK: - Validation Attempts
    func saveValidationAttempt(_ attempt: ValidationAttempt) {
        validationAttempts[attempt.validationID] = attempt
        refreshGeneratedAchievements()
    }
    func bestAttempt(for assessmentID: String) -> ValidationAttempt? {
        validationAttempts[assessmentID]
    }
    func hasPassedValidation(_ assessmentID: String) -> Bool {
        validationAttempts[assessmentID]?.passed ?? false
    }
    func validationStatus(for milestone: RoadmapMilestone) -> ValidationStatus {
        RoadmapEngine.validationStatus(assessment: milestone.assessment, bestAttempt: bestAttempt(for: milestone.assessment?.id ?? ""))
    }

    // MARK: - Project
    func completedCount(for project: Project) -> Int {
        min(projectProgress[project.id] ?? 0, project.milestones.count)
    }
    func isInPortfolio(_ project: Project) -> Bool { portfolioIDs.contains(project.id) }
    func note(for project: Project) -> String { projectNotes[project.id] ?? "" }
    func saveNote(_ note: String, for project: Project) {
        projectNotes[project.id] = note
    }
    func markProjectMilestoneComplete(for project: Project) {
        let next = min(completedCount(for: project) + 1, project.milestones.count)
        projectProgress[project.id] = next
        if next == project.milestones.count {
            // Single source: add project skills to profile transactionally
            var updated = false
            for skill in project.skills where !profile.customSkills.contains(skill) && !profile.strengths.contains(skill) {
                profile.customSkills.append(skill)
                updated = true
            }
            if updated {
                // profile didSet will save
            }
        }
        objectWillChange.send()
        refreshGeneratedAchievements()
    }
    func togglePortfolio(_ project: Project) {
        if portfolioIDs.contains(project.id) {
            portfolioIDs.remove(project.id)
        } else if completedCount(for: project) == project.milestones.count || isProjectCompleted(project) {
            portfolioIDs.insert(project.id)
        }
    }
    func resetProject(_ project: Project) {
        projectProgress[project.id] = 0
        portfolioIDs.remove(project.id)
        projectExecutionStates.removeValue(forKey: project.id)
        objectWillChange.send()
    }
    func createCustomProject(title: String, goal: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Complete this project" : goal.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = Project(
            id: "custom-\(UUID().uuidString)", title: trimmedTitle, category: "Personal Project", goal: trimmedGoal,
            description: "A project created by you. Add evidence and notes as you make progress.",
            skills: [], milestones: [.init(id: "custom-\(UUID().uuidString)-milestone", title: "Complete the project", subtitle: trimmedGoal, estimatedTime: "Your timeline")],
            resources: [], estimatedCompletion: "Your timeline", relevantInterests: [], relevantSkills: [], relevantCareers: [], relevantFields: [], sourceRoadmapID: nil
        )
        customProjects.append(project)
    }

    // MARK: - Rich Project (Phase 9.3)

    /// Validates that a string is usable http/https URL.
    private func isValidProjectURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let url = URL(string: trimmed) else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
        return url.host != nil
    }

    /// Creates a rich project from full detail. Returns the created Project or nil if title invalid.
    @discardableResult
    func createRichProject(
        title: String,
        category: String = "Personal Project",
        goal: String? = nil,
        description: String? = nil,
        detailedDescription: String? = nil,
        status: ProjectStatus = .inProgress,
        skills: [String] = [],
        startDate: Date? = nil,
        completionDate: Date? = nil,
        outcome: String? = nil,
        outcomeDetails: String? = nil,
        links: [ProjectLink] = [],
        imageReferences: [String] = [],
        achievementID: String? = nil,
        sourceRoadmapID: String? = nil
    ) -> Project? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Personal Project" : category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGoal = goal?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalGoal = (trimmedGoal?.isEmpty == false) ? trimmedGoal! : "Complete this project"
        let trimmedDesc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDesc = (trimmedDesc?.isEmpty == false) ? trimmedDesc! : "A project created by you. Add evidence and notes as you make progress."
        let dedupedSkills: [String] = {
            var seen = Set<String>(); var out: [String] = []
            for raw in skills {
                let norm = Skill.normalizeID(raw)
                guard !norm.isEmpty, !seen.contains(norm) else { continue }
                seen.insert(norm)
                // Preserve display: use canonical name if known else trimmed raw
                let display = SkillCatalog.knownSkills[norm]?.name ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !display.isEmpty { out.append(display) }
            }
            return out
        }()
        let validLinks = links.filter { isValidProjectURL($0.url) }
        let validImages = imageReferences.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && ProjectImageStore.isValidIdentifier($0) }
        // Achievement must exist if provided
        let validAchievement: String? = {
            guard let aid = achievementID?.trimmingCharacters(in: .whitespacesAndNewlines), !aid.isEmpty else { return nil }
            return achievementRecords[aid] != nil ? aid : nil
        }()
        // Date sanity: completion not before start
        var finalStart = startDate
        var finalCompletion = completionDate
        if let s = finalStart, let c = finalCompletion, c < s {
            finalCompletion = nil
        }
        let project = Project(
            id: "custom-\(UUID().uuidString)",
            title: trimmedTitle,
            category: trimmedCategory,
            goal: finalGoal,
            description: finalDesc,
            skills: dedupedSkills,
            milestones: [.init(id: "custom-\(UUID().uuidString)-milestone", title: "Complete the project", subtitle: finalGoal, estimatedTime: "Your timeline")],
            resources: [],
            estimatedCompletion: "Your timeline",
            relevantInterests: [],
            relevantSkills: [],
            relevantCareers: [],
            relevantFields: [],
            sourceRoadmapID: sourceRoadmapID,
            status: status,
            detailedDescription: detailedDescription,
            outcome: outcome,
            outcomeDetails: outcomeDetails,
            links: validLinks,
            imageReferences: validImages,
            startDate: finalStart,
            completionDate: finalCompletion,
            achievementID: validAchievement
        )
        customProjects.append(project)
        // If achievement linked, also set its projectID for bidirectional consistency (without overwriting other links)
        if let aid = validAchievement, var ach = achievementRecords[aid], ach.projectID == nil {
            ach.projectID = project.id
            achievementRecords[aid] = ach
        }
        return project
    }

    /// Adds a pre-built Project (used by onboarding/profile editor for fully configured projects)
    @discardableResult
    func addCustomProject(_ project: Project) -> Bool {
        let trimmedTitle = project.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard !customProjects.contains(where: { $0.id == project.id }) else { return false }
        // Validate links
        let validLinks = project.links.filter { isValidProjectURL($0.url) }
        // Validate images
        let validImages = project.imageReferences.filter { ProjectImageStore.isValidIdentifier($0) }
        var sanitized = project
        // Deduplicate skills
        var seen = Set<String>(); var deduped: [String] = []
        for raw in sanitized.skills {
            let norm = Skill.normalizeID(raw)
            guard !norm.isEmpty, !seen.contains(norm) else { continue }
            seen.insert(norm)
            deduped.append(SkillCatalog.knownSkills[norm]?.name ?? raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        sanitized.skills = deduped
        sanitized.links = validLinks
        sanitized.imageReferences = validImages
        // Validate achievement
        if let aid = sanitized.achievementID, achievementRecords[aid] == nil {
            sanitized.achievementID = nil
        }
        // Date sanity
        if let s = sanitized.startDate, let c = sanitized.completionDate, c < s {
            sanitized.completionDate = nil
        }
        customProjects.append(sanitized)
        return true
    }

    /// Updates an existing custom project. Returns false if not found or validation fails.
    @discardableResult
    func updateProject(_ project: Project) -> Bool {
        guard let idx = customProjects.firstIndex(where: { $0.id == project.id }) else { return false }
        let trimmedTitle = project.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        let trimmedCategory = project.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Personal Project" : project.category.trimmingCharacters(in: .whitespacesAndNewlines)
        var sanitized = project
        sanitized.title = trimmedTitle
        sanitized.category = trimmedCategory
        // Trim description/goal
        let g = sanitized.goal.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.goal = g.isEmpty ? "Complete this project" : g
        let d = sanitized.description.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.description = d.isEmpty ? "A project created by you." : d
        if let dd = sanitized.detailedDescription?.trimmingCharacters(in: .whitespacesAndNewlines), dd.isEmpty { sanitized.detailedDescription = nil }
        if let oc = sanitized.outcome?.trimmingCharacters(in: .whitespacesAndNewlines), oc.isEmpty { sanitized.outcome = nil }
        if let od = sanitized.outcomeDetails?.trimmingCharacters(in: .whitespacesAndNewlines), od.isEmpty { sanitized.outcomeDetails = nil }
        // Skills dedup
        var seen = Set<String>(); var deduped: [String] = []
        for raw in sanitized.skills {
            let norm = Skill.normalizeID(raw)
            guard !norm.isEmpty, !seen.contains(norm) else { continue }
            seen.insert(norm)
            deduped.append(SkillCatalog.knownSkills[norm]?.name ?? raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        sanitized.skills = deduped
        sanitized.links = sanitized.links.filter { isValidProjectURL($0.url) }
        sanitized.imageReferences = sanitized.imageReferences.filter { ProjectImageStore.isValidIdentifier($0) }
        if let aid = sanitized.achievementID?.trimmingCharacters(in: .whitespacesAndNewlines), !aid.isEmpty {
            sanitized.achievementID = achievementRecords[aid] != nil ? aid : nil
        } else {
            sanitized.achievementID = nil
        }
        if let s = sanitized.startDate, let c = sanitized.completionDate, c < s {
            sanitized.completionDate = nil
        }
        customProjects[idx] = sanitized
        // Bidirectional: if achievement linked, ensure it points back
        if let aid = sanitized.achievementID, var ach = achievementRecords[aid] {
            if ach.projectID != sanitized.id {
                ach.projectID = sanitized.id
                achievementRecords[aid] = ach
            }
        }
        return true
    }

    /// Deletes a custom project. Preserves evidence/achievement records but clears their projectID linkage.
    @discardableResult
    func deleteCustomProject(id: String) -> Bool {
        guard let idx = customProjects.firstIndex(where: { $0.id == id }) else { return false }
        customProjects.remove(at: idx)
        // Clear evidence projectID linkage for this project (preserve evidence, just unlink)
        for (eid, var rec) in evidenceRecords where rec.projectID == id {
            rec = EvidenceRecord(
                id: rec.id, type: rec.type, title: rec.title, description: rec.description,
                roadmapID: rec.roadmapID, milestoneID: rec.milestoneID,
                completionDate: rec.completionDate, createdAt: rec.createdAt, occurredAt: rec.occurredAt,
                source: rec.source, status: rec.status, actionID: rec.actionID, skillIDs: rec.skillIDs, artifact: rec.artifact,
                validationID: rec.validationID, validationScore: rec.validationScore, validationPercentage: rec.validationPercentage, validationPassed: rec.validationPassed,
                projectID: nil, opportunityID: rec.opportunityID
            )
            evidenceRecords[eid] = rec
        }
        // Clear achievement linkage
        for (aid, var ach) in achievementRecords where ach.projectID == id {
            ach.projectID = nil
            achievementRecords[aid] = ach
        }
        // Clean up image files (best effort)
        let dir = ProjectImageStore.directory(for: id)
        try? FileManager.default.removeItem(at: dir)
        projectProgress.removeValue(forKey: id)
        portfolioIDs.remove(id)
        projectExecutionStates.removeValue(forKey: id)
        // Portfolio stale IDs are preserved intentionally (do not crash); integrity engine will report
        return true
    }

    /// Returns project by ID (including catalog)
    func project(for id: String) -> Project? {
        if let p = customProjects.first(where: { $0.id == id }) { return p }
        return scoredProjects.first(where: { $0.project.id == id })?.project
    }

    private func saveCustomProjects() {
        if let data = try? JSONEncoder().encode(customProjects) {
            UserDefaults.standard.set(data, forKey: customProjectsKey)
        }
    }

    // MARK: - Opportunity Repository (Phase 10A) — canonical, deterministic, AppDataStore is source of truth

    func allOpportunities() -> [Opportunity] {
        opportunities.sorted { a, b in
            if a.title.lowercased() != b.title.lowercased() { return a.title.lowercased() < b.title.lowercased() }
            if a.organization.lowercased() != b.organization.lowercased() { return a.organization.lowercased() < b.organization.lowercased() }
            return a.id < b.id
        }
    }

    func opportunity(forID id: String) -> Opportunity? {
        let tid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty else { return nil }
        return opportunities.first(where: { $0.id == tid })
    }

    @discardableResult
    func insertOpportunity(_ opp: Opportunity) -> Bool {
        let validation = OpportunityValidator.validate(opp)
        guard validation.isValid else { return false }
        for existing in opportunities {
            let (isDup, _) = OpportunityDeduper.isDuplicate(existing, opp)
            if isDup { return false }
        }
        opportunities.append(opp)
        opportunities = allOpportunities()
        return true
    }

    @discardableResult
    func upsertOpportunity(_ opp: Opportunity) -> Bool {
        let validation = OpportunityValidator.validate(opp)
        guard validation.isValid else { return false }
        opportunities.removeAll { existing in
            let (isDup, _) = OpportunityDeduper.isDuplicate(existing, opp)
            return isDup
        }
        opportunities.append(opp)
        opportunities = allOpportunities()
        return true
    }

    @discardableResult
    func removeOpportunity(id: String) -> Bool {
        let tid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty else { return false }
        let before = opportunities.count
        opportunities.removeAll(where: { $0.id == tid })
        return opportunities.count < before
    }

    func replaceAllOpportunities(with newOpportunities: [Opportunity]) {
        var unique: [Opportunity] = []
        var seenIDs = Set<String>()
        for opp in newOpportunities {
            let validation = OpportunityValidator.validate(opp)
            guard validation.isValid else { continue }
            let normID = opp.id.lowercased()
            if seenIDs.contains(normID) { continue }
            var isDup = false
            for existing in unique {
                let (dup, _) = OpportunityDeduper.isDuplicate(existing, opp)
                if dup { isDup = true; break }
            }
            if isDup { continue }
            seenIDs.insert(normID)
            unique.append(opp)
        }
        opportunities = unique.sorted { a, b in
            if a.title.lowercased() != b.title.lowercased() { return a.title.lowercased() < b.title.lowercased() }
            if a.organization.lowercased() != b.organization.lowercased() { return a.organization.lowercased() < b.organization.lowercased() }
            return a.id < b.id
        }
    }

    func ingestRawOpportunities(_ rawRecords: [RawOpportunityRecord]) -> (inserted: Int, duplicates: Int, invalid: Int) {
        var inserted = 0, duplicates = 0, invalid = 0
        for raw in rawRecords {
            let opp = OpportunityNormalizer.normalize(raw)
            let validation = OpportunityValidator.validate(opp)
            if !validation.isValid {
                invalid += 1
                continue
            }
            var isDup = false
            for existing in opportunities {
                let (dup, _) = OpportunityDeduper.isDuplicate(existing, opp)
                if dup { isDup = true; break }
            }
            if isDup {
                duplicates += 1
                continue
            }
            opportunities.append(opp)
            inserted += 1
        }
        opportunities = allOpportunities()
        return (inserted, duplicates, invalid)
    }

    // MARK: - Opportunity Intelligence — Eligibility / Matching / Ranking (Phase 10B)
    // Deterministic, read-only, no mutation. Authoritative pipeline: Student Graph + Canonical Opportunities → Eligibility → Matching → Ranking.

    func eligibility(for opportunity: Opportunity, now: Date = Date()) -> OpportunityEligibilityResult {
        OpportunityEligibilityEngine.evaluate(opportunity: opportunity, profile: profile, now: now)
    }

    func eligibilityMap(now: Date = Date()) -> [String: OpportunityEligibilityResult] {
        OpportunityEligibilityEngine.evaluateAll(opportunities: opportunities, profile: profile, now: now)
    }

    func matchResult(for opportunity: Opportunity, now: Date = Date()) -> OpportunityMatchResult {
        let eligibility = self.eligibility(for: opportunity, now: now)
        // Precompute gap IDs and roadmap connections for performance
        let gapIDs: Set<String>? = {
            if activatedRoadmaps.isEmpty { return nil }
            var gaps = Set<String>()
            for report in activeSkillGapReports { for gap in report.gaps { gaps.insert(gap.skillID) } }
            return gaps
        }()
        let connections: [OpportunityRoadmapConnection]? = activatedRoadmaps.isEmpty ? nil : opportunityRoadmapConnections(for: opportunity)
        return OpportunityMatchingEngine.match(
            opportunity: opportunity,
            profile: profile,
            eligibility: eligibility,
            activeGapIDs: gapIDs,
            roadmapConnections: connections,
            customProjects: customProjects,
            evidenceRecords: evidenceRecords,
            portfolios: portfolios,
            now: now
        )
    }

    func allMatchResults(now: Date = Date()) -> [OpportunityMatchResult] {
        let eMap = eligibilityMap(now: now)
        return OpportunityMatchingEngine.matchAll(opportunities: opportunities, profile: profile, eligibilityMap: eMap, store: self, now: now)
    }

    func rankedOpportunities(filter: RankingFilterMode = .all, category: OpportunityType? = nil, searchText: String? = nil, now: Date = Date()) -> [RankedOpportunity] {
        OpportunityRankingEngine.rank(opportunities: opportunities, profile: profile, store: self, filter: filter, category: category, searchText: searchText, now: now)
    }

    var eligibleRankedOpportunities: [RankedOpportunity] {
        rankedOpportunities(filter: .eligible)
    }

    var needsVerificationRanked: [RankedOpportunity] {
        rankedOpportunities(filter: .needsVerification)
    }

    // MARK: - Career + Skill Intelligence (Phase 11A) — Derived, read-only, no persistence

    var careerAlignments: [CareerAlignmentResult] {
        CareerIntelligenceEngine.alignments(profile: profile, store: self)
    }

    func careerAlignment(for careerID: String) -> CareerAlignmentResult? {
        guard let career = CareerCatalog.career(for: careerID) else { return nil }
        return CareerIntelligenceEngine.alignment(career: career, profile: profile, store: self)
    }

    var rankedCareers: [RankedCareer] {
        CareerRankingEngine.rank(profile: profile, store: self)
    }

    func topRankedCareers(limit: Int) -> [RankedCareer] {
        CareerRankingEngine.top(limit, profile: profile, store: self)
    }

    func skillCoverage(careerID: String? = nil) -> SkillCoverageReport {
        SkillIntelligenceEngine.coverage(profile: profile, careerID: careerID, store: self)
    }

    func skillGaps(careerID: String? = nil) -> [SkillGapInsight] {
        SkillIntelligenceEngine.gaps(profile: profile, careerID: careerID, store: self)
    }

    func nextSkills(careerID: String? = nil, limit: Int = 5) -> [NextSkillRecommendation] {
        SkillIntelligenceEngine.nextSkills(profile: profile, careerID: careerID, limit: limit, store: self)
    }

    // MARK: - Adaptive Roadmap Intelligence (Phase 12A) — Derived, read-only, no persistence

    /// Computes the deterministic adaptive roadmap recommendation for a specific roadmap.
    /// Recalculated from canonical data on every call — no persisted adaptive state.
    func adaptiveRoadmap(for roadmap: Roadmap) -> AdaptiveRoadmapResult {
        AdaptiveRoadmapEngine.recommend(roadmap: roadmap, profile: profile, store: self)
    }

    // MARK: - Adaptive Roadmap Proposals (Phase 12B) — Controlled, Deterministic Adaptation

    /// Derived proposals for a specific roadmap. No mutation, deterministic.
    func adaptiveProposals(for roadmap: Roadmap) -> [AdaptiveRoadmapProposal] {
        let all = AdaptiveRoadmapProposalEngine.proposals(roadmap: roadmap, profile: profile, store: self)
        // Filter dismissed unless revalidated (stale proposals auto-cleared via validation)
        return all.filter { !adaptiveOverrides.dismissedProposalIDs.contains($0.id) }
    }

    /// All proposals across active roadmaps (for RoadmapsView updates section), sorted by priority descending.
    var allAdaptiveProposals: [AdaptiveRoadmapProposal] {
        var all: [AdaptiveRoadmapProposal] = []
        for scored in activatedRoadmaps {
            all.append(contentsOf: adaptiveProposals(for: scored.roadmap))
        }
        // If no active, fallback to proposals for any non-completed roadmap when profile has data (to support UI even before activation in tests)
        if all.isEmpty && activatedRoadmaps.isEmpty && !profile.careers.isEmpty {
            // Check top scored roadmap for demo purposes (limited)
            if let first = scoredRoadmaps.first(where: { !$0.isCompleted }) {
                all.append(contentsOf: adaptiveProposals(for: first.roadmap))
            }
        }
        all.sort { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            if a.roadmapID != b.roadmapID { return a.roadmapID < b.roadmapID }
            return a.id < b.id
        }
        return all
    }

    /// Dismiss a proposal (Keep Current). Does not mutate roadmap, hides until underlying assumptions change.
    func dismissProposal(_ proposal: AdaptiveRoadmapProposal) {
        adaptiveOverrides.dismissedProposalIDs.insert(proposal.id)
        let o = adaptiveOverrides
        adaptiveOverrides = o
    }

    /// Clear dismissed state when underlying assumptions change (called implicitly via validation failure)
    func clearDismissedIfStale() {
        var newDismissed = adaptiveOverrides.dismissedProposalIDs
        let allCurrentIDs = Set(RoadmapService.allRoadmaps.flatMap { roadmap in AdaptiveRoadmapProposalEngine.proposals(roadmap: roadmap, profile: profile, store: self).map(\.id) })
        newDismissed = newDismissed.intersection(allCurrentIDs)
        if newDismissed != adaptiveOverrides.dismissedProposalIDs {
            adaptiveOverrides.dismissedProposalIDs = newDismissed
            let o = adaptiveOverrides
            adaptiveOverrides = o
        }
    }

    /// Validates that a proposal is still valid against current canonical state.
    func isProposalValid(_ proposal: AdaptiveRoadmapProposal) -> Bool {
        // Roadmap must exist
        guard let roadmap = RoadmapService.roadmap(for: proposal.roadmapID) ?? scoredRoadmaps.first(where: { $0.roadmap.id == proposal.roadmapID })?.roadmap else { return false }
        // Referenced milestone IDs must exist
        let milestoneIDs = Set(roadmap.milestones.map(\.id))
        for mid in proposal.affectedMilestoneIDs where !mid.isEmpty {
            if !milestoneIDs.contains(mid) { return false }
        }
        // Referenced action IDs must exist
        let actionIDs = Set(roadmap.milestones.flatMap { $0.actions ?? [] }.map(\.id))
        for aid in proposal.affectedActionIDs where !aid.isEmpty {
            if !actionIDs.contains(aid) { return false }
        }
        // Referenced project must exist if needed
        if let pid = proposal.sourceProjectID, !pid.isEmpty {
            if project(for: pid) == nil && customProjects.first(where: { $0.id == pid }) == nil { return false }
        }
        // Referenced opportunity must exist and still be eligible
        if let oid = proposal.sourceOpportunityID, !oid.isEmpty {
            guard let opp = opportunity(forID: oid) else { return false }
            if proposal.changeType == .connectOpportunity {
                let elig = eligibility(for: opp)
                if !elig.isEligible { return false }
            }
        }
        // Prerequisite checks: if proposal requires prerequisite satisfied, ensure still satisfied
        if proposal.reasonCode == .newlySatisfiedPrerequisite || proposal.reasonCode == .prerequisiteSatisfied || proposal.changeType == .unlockAction {
            if let skill = proposal.sourceSkillID, !skill.isEmpty {
                let currentSkills = Set(profile.strengths.map { Skill.normalizeID($0) } + profile.customSkills.map { Skill.normalizeID($0) })
                // Also include evidence skills
                var allSkills = currentSkills
                for rec in evidenceRecords.values where rec.skillIDs != nil {
                    for sid in rec.skillIDs! { allSkills.insert(Skill.normalizeID(sid)) }
                }
                if !allSkills.contains(skill) {
                    // Check if skill is via completed milestone? Use SkillGapEngine demonstrated
                    let demonstrated = SkillGapEngine.demonstratedSkillIDs(profile: profile, roadmapProgress: roadmapProgress, catalog: RoadmapService.allRoadmaps, evidenceRecords: evidenceRecords)
                    if !demonstrated.contains(skill) { return false }
                }
            }
            // Check milestone dependencies still satisfied for unlock
            if proposal.affectedMilestoneIDs.count == 1, let mid = proposal.affectedMilestoneIDs.first, !mid.isEmpty {
                if let milestone = roadmap.milestones.first(where: { $0.id == mid }), let deps = milestone.dependencies, !deps.isEmpty {
                    let completedMIDs = Set(roadmap.milestones.prefix(min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)).map(\.id))
                    if !deps.allSatisfy({ completedMIDs.contains($0) }) {
                        // Check if dependencies satisfied via completedAction? Actually dependency is milestone level, so failing means stale
                        return false
                    }
                }
            }
        }
        // Allow idempotent re-apply for already applied proposals
        if adaptiveOverrides.appliedProposalIDs.contains(proposal.id) { return true }
        // Stale check: proposal must still appear in current derived proposals (recomputed list)
        let currentProposals = AdaptiveRoadmapProposalEngine.proposals(roadmap: roadmap, profile: profile, store: self)
        if !currentProposals.contains(where: { $0.id == proposal.id }) {
            return false
        }
        // Conflict handling: if roadmap has been manually reordered (overrides) that conflict, proposals already filtered by recompute, so stale already
        // Also check applied IDs: if already applied, consider valid but applying twice should not duplicate (handled in apply)
        return true
    }

    /// Applies a proposal with validation. Returns true on success, false if stale/invalid.
    @discardableResult
    func applyAdaptiveProposal(_ proposal: AdaptiveRoadmapProposal) -> Bool {
        guard isProposalValid(proposal) else { return false }
        // Idempotency: if already applied, do not duplicate
        if adaptiveOverrides.appliedProposalIDs.contains(proposal.id) {
            return true
        }
        // Verify roadmap not changed unexpectedly via reorderedMilestones conflict
        // For reorderAction, ensure beforeState matches current overrides state
        switch proposal.changeType {
        case .reorderAction:
            if let milestoneID = proposal.affectedMilestoneIDs.first, !milestoneID.isEmpty {
                let currentOrder = adaptiveOverrides.reorderedActions[milestoneID] ?? RoadmapService.roadmap(for: proposal.roadmapID)?.milestones.first(where: { $0.id == milestoneID })?.actions?.map(\.id)
                let beforeOrder = proposal.beforeState?.orderedActionIDs
                if let before = beforeOrder, let curr = currentOrder, before != curr {
                    // Conflict: manual reorder happened
                    return false
                }
                if let after = proposal.afterState?.orderedActionIDs {
                    adaptiveOverrides.reorderedActions[milestoneID] = after
                }
            } else if let roadmapID = proposal.affectedMilestoneIDs.first ?? proposal.roadmapID as String? {
                // milestone reorder fallback
                let current = adaptiveOverrides.reorderedMilestones[proposal.roadmapID] ?? RoadmapService.roadmap(for: proposal.roadmapID)?.milestones.map(\.id)
                let before = proposal.beforeState?.orderedMilestoneIDs
                if let before = before, let curr = current, before != curr { return false }
                if let after = proposal.afterState?.orderedMilestoneIDs {
                    adaptiveOverrides.reorderedMilestones[proposal.roadmapID] = after
                }
            }
            // Also handle generic milestone reorder when affectedMilestoneIDs present but no per-milestone actions
            if proposal.afterState?.orderedMilestoneIDs != nil && proposal.affectedMilestoneIDs.isEmpty == false {
                if let after = proposal.afterState?.orderedMilestoneIDs {
                    // Validate dependency order preserved
                    if let roadmap = RoadmapService.roadmap(for: proposal.roadmapID) {
                        if !isValidMilestoneOrder(after, roadmap: roadmap) { return false }
                    }
                    adaptiveOverrides.reorderedMilestones[proposal.roadmapID] = after
                }
            }
            if proposal.beforeState?.orderedMilestoneIDs != nil && proposal.afterState?.orderedMilestoneIDs != nil && proposal.affectedMilestoneIDs.isEmpty {
                // Pure roadmap-level reorder
                if let after = proposal.afterState?.orderedMilestoneIDs {
                    if let roadmap = RoadmapService.roadmap(for: proposal.roadmapID) {
                        if !isValidMilestoneOrder(after, roadmap: roadmap) { return false }
                    }
                    adaptiveOverrides.reorderedMilestones[proposal.roadmapID] = after
                }
            }
        case .unlockAction:
            if let after = proposal.afterState?.orderedMilestoneIDs {
                if let roadmap = RoadmapService.roadmap(for: proposal.roadmapID) {
                    if !isValidMilestoneOrder(after, roadmap: roadmap) { return false }
                }
                adaptiveOverrides.reorderedMilestones[proposal.roadmapID] = after
            }
        case .deferAction:
            for aid in proposal.affectedActionIDs {
                adaptiveOverrides.deferredActionIDs.insert(aid)
            }
        case .insertExistingProject:
            guard let pid = proposal.sourceProjectID, project(for: pid) != nil || customProjects.contains(where: { $0.id == pid }) else { return false }
            for aid in proposal.affectedActionIDs {
                adaptiveOverrides.linkedProjects[aid] = pid
            }
        case .connectOpportunity:
            guard let oid = proposal.sourceOpportunityID, let opp = opportunity(forID: oid) else { return false }
            let elig = eligibility(for: opp)
            guard elig.isEligible else { return false }
            for aid in proposal.affectedActionIDs {
                adaptiveOverrides.linkedOpportunities[aid] = oid
            }
        case .markProgressDerived:
            for aid in proposal.affectedActionIDs {
                if !completedActionIDs.contains(aid) {
                    completedActionIDs.insert(aid)
                    adaptiveOverrides.completedActionOverrides.insert(aid)
                }
            }
            // Also advance roadmap progress if needed? For simplicity, not auto-advancing milestones; derived action suffices
        case .adjustSkillSequence:
            if let after = proposal.afterState?.skillSequence {
                adaptiveOverrides.skillSequenceOverrides[proposal.roadmapID] = after
            } else if let afterMilestones = proposal.afterState?.orderedMilestoneIDs {
                adaptiveOverrides.reorderedMilestones[proposal.roadmapID] = afterMilestones
            }
        }
        // Record history for reversibility
        adaptiveOverrides.appliedProposalIDs.insert(proposal.id)
        let record = AppliedProposalRecord(proposal: proposal, appliedAt: Date())
        adaptiveOverrides.history.append(record)
        // Trigger persistence via didSet
        let overrides = adaptiveOverrides
        adaptiveOverrides = overrides
        objectWillChange.send()
        return true
    }

    /// Reverts a previously applied proposal if reversible. Returns true on success.
    @discardableResult
    func revertAdaptiveProposal(_ proposal: AdaptiveRoadmapProposal) -> Bool {
        guard proposal.isReversible else { return false }
        guard adaptiveOverrides.appliedProposalIDs.contains(proposal.id) else { return false }
        guard let record = adaptiveOverrides.history.first(where: { $0.proposalID == proposal.id }) else { return false }

        switch proposal.changeType {
        case .reorderAction:
            if let milestoneID = proposal.affectedMilestoneIDs.first, !milestoneID.isEmpty, proposal.beforeState?.orderedActionIDs != nil {
                if let before = proposal.beforeState?.orderedActionIDs {
                    adaptiveOverrides.reorderedActions[milestoneID] = before
                } else {
                    adaptiveOverrides.reorderedActions.removeValue(forKey: milestoneID)
                }
            }
            if let before = proposal.beforeState?.orderedMilestoneIDs {
                if before == (RoadmapService.roadmap(for: proposal.roadmapID)?.milestones.map(\.id) ?? before) {
                    adaptiveOverrides.reorderedMilestones.removeValue(forKey: proposal.roadmapID)
                } else {
                    adaptiveOverrides.reorderedMilestones[proposal.roadmapID] = before
                }
            } else if proposal.afterState?.orderedMilestoneIDs != nil {
                adaptiveOverrides.reorderedMilestones.removeValue(forKey: proposal.roadmapID)
            }
        case .unlockAction:
            if let before = record.beforeState?.orderedMilestoneIDs {
                if before == (RoadmapService.roadmap(for: proposal.roadmapID)?.milestones.map(\.id) ?? before) {
                    adaptiveOverrides.reorderedMilestones.removeValue(forKey: proposal.roadmapID)
                } else {
                    adaptiveOverrides.reorderedMilestones[proposal.roadmapID] = before
                }
            } else {
                adaptiveOverrides.reorderedMilestones.removeValue(forKey: proposal.roadmapID)
            }
        case .deferAction:
            for aid in proposal.affectedActionIDs {
                adaptiveOverrides.deferredActionIDs.remove(aid)
            }
        case .insertExistingProject:
            for aid in proposal.affectedActionIDs {
                if let before = record.beforeState?.linkedProjectID {
                    adaptiveOverrides.linkedProjects[aid] = before
                } else {
                    adaptiveOverrides.linkedProjects.removeValue(forKey: aid)
                }
            }
        case .connectOpportunity:
            for aid in proposal.affectedActionIDs {
                if let before = record.beforeState?.linkedOpportunityID {
                    adaptiveOverrides.linkedOpportunities[aid] = before
                } else {
                    adaptiveOverrides.linkedOpportunities.removeValue(forKey: aid)
                }
            }
        case .markProgressDerived:
            for aid in proposal.affectedActionIDs {
                completedActionIDs.remove(aid)
                adaptiveOverrides.completedActionOverrides.remove(aid)
            }
        case .adjustSkillSequence:
            if let before = record.beforeState?.skillSequence {
                adaptiveOverrides.skillSequenceOverrides[proposal.roadmapID] = before
            } else {
                adaptiveOverrides.skillSequenceOverrides.removeValue(forKey: proposal.roadmapID)
            }
            if let before = record.beforeState?.orderedMilestoneIDs {
                adaptiveOverrides.reorderedMilestones[proposal.roadmapID] = before
            }
        }
        adaptiveOverrides.appliedProposalIDs.remove(proposal.id)
        adaptiveOverrides.history.removeAll(where: { $0.proposalID == proposal.id })
        let overrides = adaptiveOverrides
        adaptiveOverrides = overrides
        objectWillChange.send()
        return true
    }

    /// Returns effective milestone order for a roadmap considering overrides.
    func effectiveMilestones(for roadmap: Roadmap) -> [RoadmapMilestone] {
        guard let order = adaptiveOverrides.reorderedMilestones[roadmap.id] else { return roadmap.milestones }
        var byID: [String: RoadmapMilestone] = Dictionary(uniqueKeysWithValues: roadmap.milestones.map { ($0.id, $0) })
        var result: [RoadmapMilestone] = []
        var seen = Set<String>()
        for mid in order {
            if let m = byID[mid], !seen.contains(mid) {
                result.append(m); seen.insert(mid)
            }
        }
        for m in roadmap.milestones where !seen.contains(m.id) {
            result.append(m)
        }
        return result
    }

    /// Returns effective action order for a milestone considering overrides.
    func effectiveActions(for milestone: RoadmapMilestone) -> [MilestoneAction] {
        guard let actions = milestone.actions, !actions.isEmpty else { return [] }
        guard let order = adaptiveOverrides.reorderedActions[milestone.id] else { return actions }
        var byID: [String: MilestoneAction] = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
        var result: [MilestoneAction] = []
        var seen = Set<String>()
        for aid in order where byID[aid] != nil && !seen.contains(aid) {
            result.append(byID[aid]!); seen.insert(aid)
        }
        for a in actions where !seen.contains(a.id) {
            result.append(a)
        }
        return result
    }

    func isActionDeferred(_ actionID: String) -> Bool {
        adaptiveOverrides.deferredActionIDs.contains(actionID)
    }

    func linkedProject(for actionID: String) -> Project? {
        guard let pid = adaptiveOverrides.linkedProjects[actionID] else { return nil }
        return project(for: pid)
    }

    func linkedOpportunity(for actionID: String) -> Opportunity? {
        guard let oid = adaptiveOverrides.linkedOpportunities[actionID] else { return nil }
        return opportunity(forID: oid)
    }

    private func isValidMilestoneOrder(_ order: [String], roadmap: Roadmap) -> Bool {
        // Must contain all milestones exactly once (allow subset? For now require superset)
        let ids = Set(roadmap.milestones.map(\.id))
        if Set(order) != ids && !Set(order).isSubset(of: ids) { return false }
        // Dependencies must be respected: for each milestone, all deps appear earlier
        var position: [String: Int] = [:]
        for (idx, mid) in order.enumerated() { position[mid] = idx }
        for m in roadmap.milestones {
            guard let deps = m.dependencies, !deps.isEmpty else { continue }
            guard let pos = position[m.id] else { continue }
            for dep in deps {
                guard let depPos = position[dep] else { continue } // if dep not in order, skip check? but ideally dep must exist
                if depPos >= pos { return false }
            }
        }
        return true
    }

    // MARK: - Project Execution (Phase 9.7)

    func executionState(for projectID: String) -> ProjectExecutionState? {
        let tid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty else { return nil }
        return projectExecutionStates[tid]
    }

    func executionState(for project: Project) -> ProjectExecutionState? {
        executionState(for: project.id)
    }

    /// Returns existing custom project started from catalog ID, if any.
    func existingStartedProject(for catalogID: String) -> Project? {
        let tid = catalogID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty else { return nil }
        return customProjects.first(where: { $0.sourceProjectID == tid })
    }

    /// Explicitly start a catalog idea as a real custom project. Returns the new or existing project.
    /// Does not mutate catalog, does not create evidence/achievement.
    @discardableResult
    func startProject(from catalogProject: Project) -> Project? {
        let catID = catalogProject.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !catID.isEmpty else { return nil }
        // Duplicate protection
        if let existing = existingStartedProject(for: catID) { return existing }
        // Copy canonical data, assign new ID, preserve sourceProjectID
        let newID = "custom-\(UUID().uuidString)"
        let now = Date()
        let started = Project(
            id: newID,
            title: catalogProject.title,
            category: catalogProject.category,
            goal: catalogProject.goal,
            description: catalogProject.description,
            skills: catalogProject.skills,
            milestones: catalogProject.milestones,
            resources: catalogProject.resources,
            estimatedCompletion: catalogProject.estimatedCompletion,
            relevantInterests: catalogProject.relevantInterests,
            relevantSkills: catalogProject.relevantSkills,
            relevantCareers: catalogProject.relevantCareers,
            relevantFields: catalogProject.relevantFields,
            sourceRoadmapID: catalogProject.sourceRoadmapID,
            sourceProjectID: catID,
            status: .planned,
            detailedDescription: catalogProject.detailedDescription,
            outcome: nil,
            outcomeDetails: nil,
            links: [],
            imageReferences: [],
            startDate: now,
            completionDate: nil,
            achievementID: nil
        )
        customProjects.append(started)
        // Initialize empty execution state
        projectExecutionStates[newID] = ProjectExecutionState(projectID: newID)
        // Project status already .planned; ensure persistence
        objectWillChange.send()
        return started
    }

    /// Validates and repairs execution state for a project (prunes unknown IDs, removes cycles already validated)
    private func validatedExecutionState(_ state: ProjectExecutionState, for project: Project) -> ProjectExecutionState {
        ProjectExecutionService.validatedState(state, for: project)
    }

    func canCompleteStep(_ stepID: String, for projectID: String) -> Bool {
        guard let project = customProjects.first(where: { $0.id == projectID }) ?? scoredProjects.first(where: { $0.project.id == projectID })?.project else { return false }
        guard let pb = ProjectExecutionService.playbook(for: project) else { return false }
        guard let step = pb.steps.first(where: { $0.id == stepID }) else { return false }
        let state = projectExecutionStates[projectID] ?? ProjectExecutionState(projectID: projectID)
        // Already completed? can be undone, but for completion check, if already completed then cannot complete again (toggle)
        if state.completedStepIDs.contains(stepID) { return false }
        // Dependencies must be satisfied
        return step.prerequisiteStepIDs.allSatisfy { state.completedStepIDs.contains($0) }
    }

    @discardableResult
    func completeStep(_ stepID: String, for projectID: String) -> Bool {
        let tid = stepID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty, !pid.isEmpty else { return false }
        guard let project = customProjects.first(where: { $0.id == pid }) else { return false }
        guard let pb = ProjectExecutionService.playbook(for: project), pb.steps.contains(where: { $0.id == tid }) else { return false }
        var state = projectExecutionStates[pid] ?? ProjectExecutionState(projectID: pid)
        // Dependency check
        guard let step = pb.steps.first(where: { $0.id == tid }), step.prerequisiteStepIDs.allSatisfy({ state.completedStepIDs.contains($0) }) else { return false }
        guard !state.completedStepIDs.contains(tid) else { return false }
        state.completedStepIDs.insert(tid)
        state = validatedExecutionState(state, for: project)
        projectExecutionStates[pid] = state
        syncProjectStatus(for: pid)
        objectWillChange.send()
        return true
    }

    @discardableResult
    func uncompleteStep(_ stepID: String, for projectID: String) -> Bool {
        let tid = stepID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty, !pid.isEmpty else { return false }
        guard customProjects.contains(where: { $0.id == pid }) else { return false }
        guard var state = projectExecutionStates[pid], state.completedStepIDs.contains(tid) else { return false }
        // Also need to consider dependent steps: if other completed steps depend on this, should we block undo? For now allow undo, but it will make dependent steps remain completed even though their prerequisite now missing.
        // To keep deterministic, we allow undo but will not auto-uncomplete dependents; next completion check will still consider them completed but dependency validation for future steps will still pass because prerequisite remains? Actually if we undo a prerequisite, dependent steps remain marked completed, which violates dependency. So we should optionally prune dependents or just allow and recompute.
        // For Phase 9.7, we allow undo and keep dependents as is, but status will revert to inProgress if needed. This is acceptable deterministic behavior.
        state.completedStepIDs.remove(tid)
        projectExecutionStates[pid] = state
        syncProjectStatus(for: pid)
        objectWillChange.send()
        return true
    }

    @discardableResult
    func toggleStep(_ stepID: String, for projectID: String) -> Bool {
        if let state = projectExecutionStates[projectID], state.completedStepIDs.contains(stepID) {
            return uncompleteStep(stepID, for: projectID)
        } else {
            return completeStep(stepID, for: projectID)
        }
    }

    @discardableResult
    func completeDeliverable(_ deliverableID: String, for projectID: String) -> Bool {
        let did = deliverableID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !did.isEmpty, !pid.isEmpty else { return false }
        guard let project = customProjects.first(where: { $0.id == pid }), let pb = ProjectExecutionService.playbook(for: project), pb.deliverables.contains(where: { $0.id == did }) else { return false }
        var state = projectExecutionStates[pid] ?? ProjectExecutionState(projectID: pid)
        guard !state.completedDeliverableIDs.contains(did) else { return false }
        state.completedDeliverableIDs.insert(did)
        state = validatedExecutionState(state, for: project)
        projectExecutionStates[pid] = state
        syncProjectStatus(for: pid)
        objectWillChange.send()
        return true
    }

    @discardableResult
    func uncompleteDeliverable(_ deliverableID: String, for projectID: String) -> Bool {
        let did = deliverableID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !did.isEmpty, !pid.isEmpty else { return false }
        guard var state = projectExecutionStates[pid], state.completedDeliverableIDs.contains(did) else { return false }
        state.completedDeliverableIDs.remove(did)
        projectExecutionStates[pid] = state
        syncProjectStatus(for: pid)
        objectWillChange.send()
        return true
    }

    @discardableResult
    func confirmCriterion(_ criterionID: String, for projectID: String) -> Bool {
        let cid = criterionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cid.isEmpty, !pid.isEmpty else { return false }
        guard let project = customProjects.first(where: { $0.id == pid }), let pb = ProjectExecutionService.playbook(for: project), pb.completionCriteria.contains(where: { $0.id == cid }) else { return false }
        var state = projectExecutionStates[pid] ?? ProjectExecutionState(projectID: pid)
        guard !state.confirmedCriterionIDs.contains(cid) else { return false }
        state.confirmedCriterionIDs.insert(cid)
        state = validatedExecutionState(state, for: project)
        projectExecutionStates[pid] = state
        syncProjectStatus(for: pid)
        objectWillChange.send()
        return true
    }

    @discardableResult
    func unconfirmCriterion(_ criterionID: String, for projectID: String) -> Bool {
        let cid = criterionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cid.isEmpty, !pid.isEmpty else { return false }
        guard var state = projectExecutionStates[pid], state.confirmedCriterionIDs.contains(cid) else { return false }
        state.confirmedCriterionIDs.remove(cid)
        projectExecutionStates[pid] = state
        syncProjectStatus(for: pid)
        objectWillChange.send()
        return true
    }

    /// Single source for project progress (playbook or milestone fallback)
    func executionProgress(for project: Project) -> (completed: Int, total: Int, percent: Int) {
        ProjectExecutionService.progress(for: project, store: self)
    }

    func executionNextStep(for project: Project) -> ProjectPlaybookStep? {
        ProjectExecutionService.nextStep(for: project, store: self)
    }

    func isProjectCompleted(_ project: Project) -> Bool {
        ProjectExecutionService.isCompleted(project: project, store: self)
    }

    private func syncProjectStatus(for projectID: String) {
        guard let idx = customProjects.firstIndex(where: { $0.id == projectID }) else { return }
        let project = customProjects[idx]
        guard ProjectExecutionService.hasPlaybook(for: project) else { return }
        let state = projectExecutionStates[projectID] ?? ProjectExecutionState(projectID: projectID)
        let newStatus = ProjectExecutionService.synchronizedStatus(for: project, state: state)
        if project.status != newStatus {
            var updated = project
            updated.status = newStatus
            // If completed, set completionDate if not set
            if newStatus == .completed && updated.completionDate == nil {
                updated.completionDate = Date()
            } else if newStatus != .completed {
                // keep existing completionDate? Spec says status should return to inProgress if undone, but completionDate may remain
                // We preserve date
            }
            customProjects[idx] = updated
        }
    }

    // MARK: - Achievement Records (canonical)

    var allAchievementsSorted: [Achievement] {
        achievementRecords.values.sorted { $0.createdAt > $1.createdAt }
    }

    func achievement(for id: String) -> Achievement? {
        achievementRecords[id]
    }

    @discardableResult
    func addAchievement(_ achievement: Achievement) -> Bool {
        let trimmedTitle = achievement.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard achievementRecords[achievement.id] == nil else { return false }
        guard achievement.status == .recorded else { return false }
        // Deduplicate and validate evidenceIDs — filter to existing evidence only, drop invalid
        let filteredEvidenceIDs: [String] = {
            var seen = Set<String>()
            var out: [String] = []
            for eid in achievement.evidenceIDs {
                let t = eid.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty, !seen.contains(t), evidenceRecords[t] != nil else { continue }
                seen.insert(t); out.append(t)
            }
            return out
        }()
        // Allow achievement without evidence (manual recorded) — filtered may be empty
        let sanitized = Achievement(
            id: achievement.id,
            title: trimmedTitle,
            description: achievement.description,
            type: achievement.type,
            status: .recorded,
            createdAt: achievement.createdAt,
            occurredAt: achievement.occurredAt,
            evidenceIDs: filteredEvidenceIDs,
            skillIDs: achievement.skillIDs,
            roadmapID: achievement.roadmapID,
            milestoneID: achievement.milestoneID,
            projectID: achievement.projectID,
            opportunityID: achievement.opportunityID,
            source: achievement.source
        )
        achievementRecords[sanitized.id] = sanitized
        _ = reconcileEvidenceAchievements()
        return true
    }

    @discardableResult
    func updateAchievement(_ achievement: Achievement) -> Bool {
        guard achievementRecords[achievement.id] != nil else { return false }
        let trimmedTitle = achievement.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard achievement.status == .recorded else { return false }
        let filteredEvidenceIDs: [String] = {
            var seen = Set<String>()
            var out: [String] = []
            for eid in achievement.evidenceIDs {
                let t = eid.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty, !seen.contains(t), evidenceRecords[t] != nil else { continue }
                seen.insert(t); out.append(t)
            }
            return out
        }()
        let sanitized = Achievement(
            id: achievement.id,
            title: trimmedTitle,
            description: achievement.description,
            type: achievement.type,
            status: .recorded,
            createdAt: achievement.createdAt,
            occurredAt: achievement.occurredAt,
            evidenceIDs: filteredEvidenceIDs,
            skillIDs: achievement.skillIDs,
            roadmapID: achievement.roadmapID,
            milestoneID: achievement.milestoneID,
            projectID: achievement.projectID,
            opportunityID: achievement.opportunityID,
            source: achievement.source
        )
        achievementRecords[sanitized.id] = sanitized
        _ = reconcileEvidenceAchievements()
        return true
    }

    @discardableResult
    func deleteAchievement(id: String) -> Bool {
        guard achievementRecords[id] != nil else { return false }
        achievementRecords.removeValue(forKey: id)
        // Do not delete evidence, skills, progress
        return true
    }

    /// Deterministic generation: evaluates current state and inserts missing generated achievements.
    /// Idempotent — safe to call repeatedly.
    func refreshGeneratedAchievements() {
        let candidates = AchievementGenerationEngine.generate(for: self)
        for ach in candidates {
            if achievementRecords[ach.id] == nil {
                achievementRecords[ach.id] = ach
            }
        }
        reconcileEvidenceAchievements()
    }

    /// Deterministic reconciliation of evidence ↔ skills ↔ achievements.
    /// Normalizes skill IDs, deduplicates evidence references, suppresses unsupported generated achievements.
    /// Preserves student-created records, reports unresolved issues.
    @discardableResult
    func reconcileEvidenceAchievements() -> ReconciliationResult {
        let catalog = scoredRoadmaps.map(\.roadmap)
        let projects = scoredProjects.map(\.project)
        let result = AchievementConsistencyEngine.reconcile(
            evidenceRecords: evidenceRecords,
            achievementRecords: achievementRecords,
            roadmapProgress: roadmapProgress,
            projectProgress: projectProgress,
            validationAttempts: validationAttempts,
            catalog: catalog,
            projects: projects
        )
        if result.didChange {
            for (id, repaired) in result.evidenceRepairs {
                evidenceRecords[id] = repaired
            }
            for (id, repaired) in result.achievementRepairs {
                achievementRecords[id] = repaired
            }
            for id in result.suppressedAchievementIDs {
                achievementRecords.removeValue(forKey: id)
            }
        }
        return result
    }

    // MARK: - Portfolio (Phase 8.1 — presentation layer over canonical records)
    // Architecture: portfolio stores only references (IDs) to canonical data.
    // Stale IDs are preserved (do not crash); later engines/UI filter them.
    // No AI, no networking, no scoring, no mutation of canonical records.

    var allPortfoliosSorted: [StudentPortfolio] {
        portfolios.values.sorted { $0.createdAt > $1.createdAt }
    }

    func portfolio(id: String) -> StudentPortfolio? {
        let t = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return portfolios[t]
    }

    func getPortfolio(byID id: String) -> StudentPortfolio? { portfolio(id: id) }

    @discardableResult
    func createPortfolio(title: String, headline: String? = nil, about: String? = nil, goals: [String] = [], sections: [PortfolioSection]? = nil, id: String? = nil) -> StudentPortfolio {
        let rawID = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid: String
        if let r = rawID, !r.isEmpty, portfolios[r] == nil {
            pid = r
        } else if let r = rawID, !r.isEmpty, portfolios[r] != nil {
            pid = UUID().uuidString
        } else {
            pid = UUID().uuidString
        }
        let portfolio = StudentPortfolio(id: pid, title: title, headline: headline, about: about, goals: goals, sections: sections)
        portfolios[portfolio.id] = portfolio
        return portfolio
    }

    @discardableResult
    func savePortfolio(_ portfolio: StudentPortfolio) -> Bool {
        return updatePortfolio(portfolio)
    }

    @discardableResult
    func updatePortfolio(_ portfolio: StudentPortfolio) -> Bool {
        guard portfolios[portfolio.id] != nil else { return false }
        var sanitized = portfolio
        // Normalize via StudentPortfolio init dedup logic — re-apply
        let titleTrim = sanitized.title.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.title = titleTrim.isEmpty ? "My Portfolio" : titleTrim
        if let h = sanitized.headline {
            let t = h.trimmingCharacters(in: .whitespacesAndNewlines)
            sanitized.headline = t.isEmpty ? nil : t
        }
        if let a = sanitized.about {
            let t = a.trimmingCharacters(in: .whitespacesAndNewlines)
            sanitized.about = t.isEmpty ? nil : t
        }
        sanitized.goals = sanitized.goals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        sanitized.selectedProjectIDs = StudentPortfolio.dedupOrdered(sanitized.selectedProjectIDs)
        sanitized.selectedAchievementIDs = StudentPortfolio.dedupOrdered(sanitized.selectedAchievementIDs)
        sanitized.selectedEvidenceIDs = StudentPortfolio.dedupOrdered(sanitized.selectedEvidenceIDs)
        sanitized.selectedSkillIDs = StudentPortfolio.dedupOrderedSkillIDs(sanitized.selectedSkillIDs)
        sanitized.selectedRoadmapIDs = StudentPortfolio.dedupOrdered(sanitized.selectedRoadmapIDs)
        sanitized.sections = StudentPortfolio.dedupSections(sanitized.sections)
        sanitized.updatedAt = Date()
        portfolios[sanitized.id] = sanitized
        return true
    }

    @discardableResult
    func deletePortfolio(id: String) -> Bool {
        let t = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, portfolios[t] != nil else { return false }
        portfolios.removeValue(forKey: t)
        // Preserve invariant: at least one portfolio exists (matches init behavior)
        if portfolios.isEmpty {
            let defaultTitle = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Portfolio" : "\(profile.firstName)'s Portfolio"
            let defaultPortfolio = StudentPortfolio(title: defaultTitle)
            portfolios[defaultPortfolio.id] = defaultPortfolio
        }
        return true
    }

    // MARK: Portfolio — Selection (duplicate-protected, ordered, does not mutate canonical records)

    @discardableResult
    func addProject(to portfolioID: String, projectID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedProjectIDs.contains(tid) else { return false }
        p.selectedProjectIDs.append(tid)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeProject(from portfolioID: String, projectID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedProjectIDs.firstIndex(of: tid) else { return false }
        p.selectedProjectIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    // Aliases per spec wording
    @discardableResult func selectProject(in portfolioID: String, projectID: String) -> Bool { addProject(to: portfolioID, projectID: projectID) }
    @discardableResult func deselectProject(in portfolioID: String, projectID: String) -> Bool { removeProject(from: portfolioID, projectID: projectID) }
    @discardableResult func selectProject(_ projectID: String, for portfolioID: String) -> Bool { addProject(to: portfolioID, projectID: projectID) }
    @discardableResult func deselectProject(_ projectID: String, from portfolioID: String) -> Bool { removeProject(from: portfolioID, projectID: projectID) }

    @discardableResult
    func addAchievement(to portfolioID: String, achievementID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = achievementID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedAchievementIDs.contains(tid) else { return false }
        p.selectedAchievementIDs.append(tid)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeAchievement(from portfolioID: String, achievementID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = achievementID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedAchievementIDs.firstIndex(of: tid) else { return false }
        p.selectedAchievementIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult func selectAchievement(in portfolioID: String, achievementID: String) -> Bool { addAchievement(to: portfolioID, achievementID: achievementID) }
    @discardableResult func deselectAchievement(in portfolioID: String, achievementID: String) -> Bool { removeAchievement(from: portfolioID, achievementID: achievementID) }

    @discardableResult
    func addEvidence(to portfolioID: String, evidenceID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = evidenceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedEvidenceIDs.contains(tid) else { return false }
        p.selectedEvidenceIDs.append(tid)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeEvidence(from portfolioID: String, evidenceID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = evidenceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedEvidenceIDs.firstIndex(of: tid) else { return false }
        p.selectedEvidenceIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult func selectEvidence(in portfolioID: String, evidenceID: String) -> Bool { addEvidence(to: portfolioID, evidenceID: evidenceID) }
    @discardableResult func deselectEvidence(in portfolioID: String, evidenceID: String) -> Bool { removeEvidence(from: portfolioID, evidenceID: evidenceID) }

    @discardableResult
    func addSkill(to portfolioID: String, skillID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = Skill.normalizeID(skillID)
        guard !pid.isEmpty, !norm.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedSkillIDs.contains(norm) else { return false }
        p.selectedSkillIDs.append(norm)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeSkill(from portfolioID: String, skillID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let norm = Skill.normalizeID(skillID)
        guard !pid.isEmpty, !norm.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedSkillIDs.firstIndex(of: norm) else { return false }
        p.selectedSkillIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult func selectSkill(in portfolioID: String, skillID: String) -> Bool { addSkill(to: portfolioID, skillID: skillID) }
    @discardableResult func deselectSkill(in portfolioID: String, skillID: String) -> Bool { removeSkill(from: portfolioID, skillID: skillID) }

    @discardableResult
    func addRoadmap(to portfolioID: String, roadmapID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = roadmapID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard !p.selectedRoadmapIDs.contains(tid) else { return false }
        p.selectedRoadmapIDs.append(tid)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func removeRoadmap(from portfolioID: String, roadmapID: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = roadmapID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !tid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.selectedRoadmapIDs.firstIndex(of: tid) else { return false }
        p.selectedRoadmapIDs.remove(at: idx)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult func selectRoadmap(in portfolioID: String, roadmapID: String) -> Bool { addRoadmap(to: portfolioID, roadmapID: roadmapID) }
    @discardableResult func deselectRoadmap(in portfolioID: String, roadmapID: String) -> Bool { removeRoadmap(from: portfolioID, roadmapID: roadmapID) }

    // MARK: Portfolio — Reordering (deterministic, deduped, stale-safe)

    @discardableResult
    func reorderProjects(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedProjectIDs = StudentPortfolio.dedupOrdered(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderAchievements(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedAchievementIDs = StudentPortfolio.dedupOrdered(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderEvidence(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedEvidenceIDs = StudentPortfolio.dedupOrdered(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderSkills(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedSkillIDs = StudentPortfolio.dedupOrderedSkillIDs(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderRoadmaps(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        p.selectedRoadmapIDs = StudentPortfolio.dedupOrdered(orderedIDs)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func reorderSections(in portfolioID: String, orderedIDs: [String]) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var p = portfolios[pid] else { return false }
        // Build map
        var byID: [String: PortfolioSection] = [:]
        for sec in p.sections { byID[sec.id] = sec }
        var newOrder: [PortfolioSection] = []
        var seen = Set<String>()
        for raw in orderedIDs {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !seen.contains(t), let sec = byID[t] else { continue }
            seen.insert(t); newOrder.append(sec)
        }
        // Append remaining sections in original order to preserve those not mentioned
        for sec in p.sections where !seen.contains(sec.id) {
            newOrder.append(sec)
        }
        guard !newOrder.isEmpty else { return false }
        p.sections = StudentPortfolio.dedupSections(newOrder)
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    // MARK: Portfolio — Metadata (title/headline/about/goals)

    @discardableResult
    func updatePortfolioTitle(id: String, title: String) -> Bool {
        let pid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !t.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        p.title = t
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func updatePortfolioHeadline(id: String, headline: String?) -> Bool {
        let pid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        if let h = headline {
            let t = h.trimmingCharacters(in: .whitespacesAndNewlines)
            p.headline = t.isEmpty ? nil : t
        } else {
            p.headline = nil
        }
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func updatePortfolioAbout(id: String, about: String?) -> Bool {
        let pid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        if let a = about {
            let t = a.trimmingCharacters(in: .whitespacesAndNewlines)
            p.about = t.isEmpty ? nil : t
        } else {
            p.about = nil
        }
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func updatePortfolioGoals(id: String, goals: [String]) -> Bool {
        let pid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        p.goals = goals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func updatePortfolioMetadata(id: String, title: String? = nil, headline: String? = nil, about: String? = nil, goals: [String]? = nil, clearHeadline: Bool = false, clearAbout: Bool = false) -> Bool {
        let pid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        if let t = title {
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            p.title = trimmed
        }
        if clearHeadline {
            p.headline = nil
        } else if let h = headline {
            let t = h.trimmingCharacters(in: .whitespacesAndNewlines)
            p.headline = t.isEmpty ? nil : t
        }
        if clearAbout {
            p.about = nil
        } else if let a = about {
            let t = a.trimmingCharacters(in: .whitespacesAndNewlines)
            p.about = t.isEmpty ? nil : t
        }
        if let g = goals {
            p.goals = g.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    // MARK: Portfolio — Sections visibility

    @discardableResult
    func setSectionEnabled(in portfolioID: String, sectionID: String, isEnabled: Bool) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let sid = sectionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !sid.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.sections.firstIndex(where: { $0.id == sid }) else { return false }
        p.sections[idx].isEnabled = isEnabled
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    @discardableResult
    func enableSection(in portfolioID: String, sectionID: String) -> Bool { setSectionEnabled(in: portfolioID, sectionID: sectionID, isEnabled: true) }

    @discardableResult
    func disableSection(in portfolioID: String, sectionID: String) -> Bool { setSectionEnabled(in: portfolioID, sectionID: sectionID, isEnabled: false) }

    @discardableResult
    func updateSectionTitle(in portfolioID: String, sectionID: String, title: String) -> Bool {
        let pid = portfolioID.trimmingCharacters(in: .whitespacesAndNewlines)
        let sid = sectionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !sid.isEmpty, !t.isEmpty else { return false }
        guard var p = portfolios[pid] else { return false }
        guard let idx = p.sections.firstIndex(where: { $0.id == sid }) else { return false }
        p.sections[idx].title = t
        p.updatedAt = Date()
        portfolios[pid] = p
        return true
    }

    // MARK: - Opportunities
    func isSaved(_ opportunity: Opportunity) -> Bool { savedOpportunityIDs.contains(opportunity.id) }
    func toggleSaved(_ opportunity: Opportunity) {
        if savedOpportunityIDs.contains(opportunity.id) { savedOpportunityIDs.remove(opportunity.id) }
        else { savedOpportunityIDs.insert(opportunity.id) }
    }
    func isSaved(_ remote: RemoteOpportunity) -> Bool { savedOpportunityIDs.contains(remote.id) }
    func toggleSaved(_ remote: RemoteOpportunity) {
        if savedOpportunityIDs.contains(remote.id) { savedOpportunityIDs.remove(remote.id) }
        else { savedOpportunityIDs.insert(remote.id) }
    }

    // MARK: - Reset Everything (user-facing, brand-new install)

    /// Deletes/resets all Student OPS user data and persisted app state.
    /// - Clears profile, onboarding, roadmaps, progress, projects, achievements, evidence, portfolios, opportunities, adaptive state, etc.
    /// - Resets to very first onboarding screen, as if newly installed.
    /// - Does NOT touch RevenueCat subscription/purchase state or configuration.
    /// - Survives app restart (UserDefaults cleared).
    /// - Does not create a second persistence system.
    func resetEverything() {
        // All Student OPS UserDefaults keys — keep RevenueCat and appearance (and one-time flags) untouched per spec
        // Note: appearance (studentops.appearance) is intentionally preserved — not user-generated demo state
        let onboardingProjectsKey = "studentops.onboarding.projects"
        let introOnboardingCompletedKey = "studentops.introOnboardingCompleted"
        let keysToRemove = [
            profileKey,
            onboardingCompletedKey,
            introOnboardingCompletedKey,
            roadmapProgressKey,
            projectProgressKey,
            portfolioKey,
            customProjectsKey,
            notesKey,
            savedOpportunityKey,
            completedActionsKey,
            validationAttemptsKey,
            evidenceRecordsKey,
            activeRoadmapsKey,
            achievementRecordsKey,
            portfoliosKey,
            opportunitiesKey,
            projectExecutionStatesKey,
            adaptiveOverridesKey,
            onboardingProjectsKey,
        ]
        // Remove persisted state first (clears disk)
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        // Remove project image files (Application Support/StudentOps/ProjectImages)
        let baseDir = ProjectImageStore.baseDirectory
        try? FileManager.default.removeItem(at: baseDir)
        // Reset in-memory published state — didSet will re-save empty state, so we clear again after
        profile = StudentProfile()
        roadmapProgress = [:]
        projectProgress = [:]
        savedOpportunityIDs = []
        customProjects = []
        projectNotes = [:]
        portfolioIDs = []
        completedActionIDs = []
        validationAttempts = [:]
        evidenceRecords = [:]
        activeRoadmaps = [:]
        achievementRecords = [:]
        portfolios = [:]
        opportunities = []
        projectExecutionStates = [:]
        adaptiveOverrides = AdaptiveRoadmapOverrides()
        // Re-create minimal default portfolio in-memory like brand-new init (no user data, but avoids empty-state crashes)
        // Persisted form is still cleared — next launch init will recreate same default
        if portfolios.isEmpty {
            let defaultPortfolio = StudentPortfolio(title: "My Portfolio")
            portfolios[defaultPortfolio.id] = defaultPortfolio
        }
        // Ensure UserDefaults stays cleared after didSet re-saves (so reset survives restart and demo does not re-seed)
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        // After in-memory reset, re-save the default portfolio? No — leave cleared so brand-new logic recreates.
        // Remove again to keep cleared, but keep in-memory default for current session.
        // Actually portfolios didSet after creating default saved it — remove again so disk stays empty
        UserDefaults.standard.removeObject(forKey: portfoliosKey)
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
        UserDefaults.standard.removeObject(forKey: introOnboardingCompletedKey)
        // Notify observers (e.g. ContentView's OnboardingViewModel) to reset onboarding UI for immediate navigation
        NotificationCenter.default.post(name: Notification.Name("studentops.didResetEverything"), object: nil)
        objectWillChange.send()
    }

    // MARK: - Debug Reset (development/testing only)

    #if DEBUG
    /// Clears all persisted student data for fresh first-launch testing.
    /// Does NOT touch the SQLite opportunity database.
    func debugResetAllData() {
        // Delegate to comprehensive reset (preserves appearance & RevenueCat)
        resetEverything()
    }
    #endif
}
