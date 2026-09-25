import Foundation
import Combine

struct MilestoneNode: Identifiable {
    enum Status { case completed, active, upcoming, goal }
    let id = UUID()
    let status: Status
}

struct PathProgress {
    var title: String
    var subtitle: String
    var percentComplete: Int
    var milestonesCompleted: Int
    var milestonesTotal: Int
    var nodes: [MilestoneNode]
    var trackLabels: [String]
}

struct NextStepTask {
    var badge: String
    var estimatedTime: String
    var title: String
    var subtitle: String
    var lessonsCompleted: Int
    var lessonsTotal: Int
    var syncedToolName: String
}

struct MatchedOpportunity {
    var matchPercent: Int
    var category: String
    var deadlineLabel: String
    var title: String
    var description: String
    var validatedSkills: [String]
}

struct ProgressMetric: Identifiable {
    enum TrendStyle { case positiveGreen, starred, plain }
    let id = UUID()
    var label: String
    var value: String
    var trendText: String
    var trendStyle: TrendStyle
}

enum DashboardTab: String, CaseIterable, Identifiable {
    case home, explore, roadmaps, projects, progress
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "Home"
        case .explore: return "Explore"
        case .roadmaps: return "Roadmaps"
        case .projects: return "Projects"
        case .progress: return "Progress"
        }
    }
    var icon: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .explore: return "safari"
        case .roadmaps: return "point.3.connected.trianglepath.dotted"
        case .projects: return "hammer"
        case .progress: return "chart.line.uptrend.xyaxis"
        }
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    enum NextStepButtonState { case idle, loading, ready }

    @Published var studentFirstName: String
    @Published var dateLabel: String = DashboardViewModel.formattedDateLabel()
    @Published var statusSummary: String
    @Published var notificationsUnread = true
    @Published var path: PathProgress
    @Published var nextStep: NextStepTask
    @Published var nextBestAction: NextBestAction?
    @Published var nextBestActions: [NextBestAction] = []
    @Published var opportunity: MatchedOpportunity
    @Published var metrics: [ProgressMetric]
    @Published var nextStepButtonState: NextStepButtonState = .idle

    private static func formattedDateLabel() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date()) + " • Active Path"
    }
    private static func statusSummary(for profile: StudentProfile, activeRoadmap: ScoredRoadmap?) -> String {
        if profile.justGettingStarted { return "You're just getting started — explore roadmaps to find your path." }
        if let r = activeRoadmap { return "Your trajectory is \(r.completedMilestones)/\(r.roadmap.milestones.count) milestones complete." }
        if profile.careers.isEmpty && profile.fields.isEmpty { return "No active roadmaps — choose a path to begin." }
        return "All roadmaps completed — add a project to keep building."
    }
    private static func matchedOpportunity(for profile: StudentProfile) -> MatchedOpportunity {
        if let scored = OpportunityService.opportunities(for: profile).first {
            let o = scored.opportunity
            return MatchedOpportunity(matchPercent: scored.matchScore, category: o.category.rawValue, deadlineLabel: o.deadline, title: o.title, description: o.description, validatedSkills: Array(o.relevantSkills.prefix(2)))
        }
        return MatchedOpportunity(matchPercent: 0, category: "Explore", deadlineLabel: "No deadline", title: "Explore opportunities matched to you", description: "Complete your profile to see personalized opportunities.", validatedSkills: [])
    }
    private static func metrics(for profile: StudentProfile) -> [ProgressMetric] {
        let achievements = profile.loggedEntries.count
        let skillCount = Set(profile.strengths + profile.customSkills).count
        let savedProgress = UserDefaults.standard.dictionary(forKey: "studentops.projectProgress") as? [String: Int] ?? [:]
        let savedData = UserDefaults.standard.data(forKey: "studentops.customProjects")
        let custom = savedData.flatMap { try? JSONDecoder().decode([Project].self, from: $0) } ?? []
        let completedProjects = ProjectService.projects(for: profile, progress: savedProgress, customProjects: custom).filter(\.isCompleted).count
        return [
            .init(label: "Projects", value: "\(completedProjects)", trendText: completedProjects > 0 ? "completed" : "in progress", trendStyle: .positiveGreen),
            .init(label: "Badges", value: "\(achievements)", trendText: achievements > 0 ? "\(achievements) recorded" : "start recording", trendStyle: .starred),
            .init(label: "Skills", value: "\(skillCount)", trendText: skillCount > 0 ? "developing" : "add strengths", trendStyle: .plain)
        ]
    }
    private static func metrics(for store: AppDataStore) -> [ProgressMetric] {
        let snap = ProgressEngine.snapshot(store: store)
        return [
            .init(label: "Projects", value: "\(snap.completedProjects)", trendText: snap.completedProjects > 0 ? "completed" : "in progress", trendStyle: .positiveGreen),
            .init(label: "Badges", value: "\(snap.achievementsCount)", trendText: snap.achievementsCount > 0 ? "\(snap.achievementsCount) recorded" : "start recording", trendStyle: .starred),
            .init(label: "Skills", value: "\(snap.skillCount)", trendText: snap.skillCount > 0 ? "developing" : "add strengths", trendStyle: .plain)
        ]
    }
    private static func nextStep(for profile: StudentProfile) -> NextStepTask {
        let savedProjectProgress = UserDefaults.standard.dictionary(forKey: "studentops.projectProgress") as? [String: Int] ?? [:]
        let savedProjectData = UserDefaults.standard.data(forKey: "studentops.customProjects")
        let customProjects = savedProjectData.flatMap { try? JSONDecoder().decode([Project].self, from: $0) } ?? []
        let projectSnapshot = ProjectService.projects(for: profile, progress: savedProjectProgress, customProjects: customProjects)
        if let activeProject = projectSnapshot.first(where: { !$0.isCompleted }), let m = activeProject.currentMilestone {
            return NextStepTask(badge: "PROJECT MILESTONE", estimatedTime: m.estimatedTime, title: m.title, subtitle: activeProject.project.title, lessonsCompleted: activeProject.completedMilestones, lessonsTotal: activeProject.project.milestones.count, syncedToolName: "Project workspace ready")
        }
        let savedProgress = UserDefaults.standard.dictionary(forKey: "studentops.roadmapProgress") as? [String: Int] ?? [:]
        if let activeRoadmap = RoadmapService.roadmaps(for: profile, progress: savedProgress).first(where: { !$0.isCompleted }), let m = activeRoadmap.currentMilestone {
            return NextStepTask(badge: "ROADMAP MILESTONE", estimatedTime: m.estimatedTime, title: m.title, subtitle: activeRoadmap.roadmap.title, lessonsCompleted: activeRoadmap.completedMilestones, lessonsTotal: activeRoadmap.roadmap.milestones.count, syncedToolName: "Roadmap in progress")
        }
        return NextStepTask(badge: "GET STARTED", estimatedTime: "~10 min", title: "Choose your first roadmap", subtitle: "Explore roadmaps matched to your interests.", lessonsCompleted: 0, lessonsTotal: 1, syncedToolName: "No active milestones")
    }
    private static func nextStep(for store: AppDataStore) -> NextStepTask {
        NextActionEngine.nextStepTask(for: NextActionEngine.nextAction(store: store))
    }

    private static func nextBest(for store: AppDataStore) -> NextBestAction? {
        store.nextBestAction
    }

    private static func nextBests(for store: AppDataStore) -> [NextBestAction] {
        Array(store.nextBestActions.prefix(3))
    }

    init(profile: StudentProfile) {
        studentFirstName = profile.firstName.isEmpty ? "Student" : profile.firstName
        statusSummary = Self.statusSummary(for: profile, activeRoadmap: RoadmapService.roadmaps(for: profile, progress: UserDefaults.standard.dictionary(forKey: "studentops.roadmapProgress") as? [String: Int] ?? [:]).first(where: { !$0.isCompleted }))
        let savedProgress = UserDefaults.standard.dictionary(forKey: "studentops.roadmapProgress") as? [String: Int] ?? [:]
        let activeRoadmap = RoadmapService.roadmaps(for: profile, progress: savedProgress).first(where: { !$0.isCompleted })
        let direction = activeRoadmap?.roadmap.title ?? profile.careers.first ?? profile.fields.first ?? "Your Student OPS"
        let completed = activeRoadmap?.completedMilestones ?? 0
        let total = activeRoadmap?.roadmap.milestones.count ?? 7
        let percent = ProgressCalculator.percent(completed: completed, total: total)
        path = PathProgress(
            title: direction,
            subtitle: activeRoadmap?.roadmap.goal ?? (profile.collegePlan == .notSure ? "Exploration & discovery path" : "Personalized Student OPS pathway"),
            percentComplete: percent, milestonesCompleted: completed, milestonesTotal: total,
            nodes: (0..<total).map { index in
                .init(status: RoadmapEngine.nodeStatus(index: index, completed: completed, total: total))
            },
            trackLabels: [activeRoadmap?.roadmap.milestones.first?.title ?? "Foundations", activeRoadmap?.currentMilestone?.title ?? "Skill building", "Next horizon"]
        )
        nextStep = Self.nextStep(for: profile)
        nextBestAction = nil
        nextBestActions = []
        opportunity = Self.matchedOpportunity(for: profile)
        metrics = Self.metrics(for: profile)
        dateLabel = Self.formattedDateLabel()
    }
    init(store: AppDataStore) {
        let profile = store.profile
        studentFirstName = profile.firstName.isEmpty ? "Student" : profile.firstName
        let activeRoadmap = store.activatedRoadmaps.first
        statusSummary = Self.statusSummary(for: profile, activeRoadmap: activeRoadmap)
        let completed = activeRoadmap?.completedMilestones ?? 0
        let total = activeRoadmap?.roadmap.milestones.count ?? store.scoredRoadmaps.first?.roadmap.milestones.count ?? 0
        let displayTotal = total > 0 ? total : 7
        let percent = ProgressCalculator.percent(completed: completed, total: activeRoadmap != nil ? total : 0)
        if let activeRoadmap = activeRoadmap {
            path = PathProgress(
                title: activeRoadmap.roadmap.title,
                subtitle: activeRoadmap.roadmap.goal,
                percentComplete: percent, milestonesCompleted: completed, milestonesTotal: total,
                nodes: (0..<total).map { index in .init(status: RoadmapEngine.nodeStatus(index: index, completed: completed, total: total)) },
                trackLabels: [activeRoadmap.roadmap.milestones.first?.title ?? "Foundations", activeRoadmap.currentMilestone?.title ?? "Skill building", "Next horizon"]
            )
        } else if let any = store.scoredRoadmaps.first {
            path = PathProgress(title: any.roadmap.title, subtitle: "All milestones completed", percentComplete: 100, milestonesCompleted: any.completedMilestones, milestonesTotal: any.roadmap.milestones.count, nodes: (0..<any.roadmap.milestones.count).map { _ in .init(status: .completed) }, trackLabels: ["Foundations", "Skill building", "Next horizon"])
        } else {
            let displayCompleted = 0
            path = PathProgress(title: profile.careers.first ?? profile.fields.first ?? "Your Student OPS", subtitle: profile.collegePlan == .notSure ? "Exploration & discovery path" : "Personalized Student OPS pathway", percentComplete: 0, milestonesCompleted: displayCompleted, milestonesTotal: displayTotal, nodes: (0..<displayTotal).map { .init(status: $0 == 0 ? .active : .upcoming) }, trackLabels: ["Foundations", "Skill building", "Next horizon"])
        }
        nextStep = Self.nextStep(for: store)
        nextBestAction = Self.nextBest(for: store)
        nextBestActions = Self.nextBests(for: store)
        opportunity = Self.matchedOpportunity(for: profile)
        metrics = Self.metrics(for: store)
        dateLabel = Self.formattedDateLabel()
    }

    func tapNextStepCta() {
        guard nextStepButtonState == .idle else { return }
        nextStepButtonState = .loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.nextStepButtonState = .ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { self?.nextStepButtonState = .idle }
        }
    }

    func update(with store: AppDataStore) {
        let profile = store.profile
        nextBestAction = Self.nextBest(for: store)
        nextBestActions = Self.nextBests(for: store)
        studentFirstName = profile.firstName.isEmpty ? "Student" : profile.firstName
        dateLabel = Self.formattedDateLabel()
        let activeRoadmap = store.activatedRoadmaps.first
        statusSummary = Self.statusSummary(for: profile, activeRoadmap: activeRoadmap)
        if let roadmap = activeRoadmap {
            path.title = roadmap.roadmap.title
            path.subtitle = roadmap.roadmap.goal
            path.milestonesCompleted = roadmap.completedMilestones
            path.milestonesTotal = roadmap.roadmap.milestones.count
            path.percentComplete = roadmap.progress
            path.nodes = (0..<roadmap.roadmap.milestones.count).map { index in
                .init(status: RoadmapEngine.nodeStatus(index: index, completed: roadmap.completedMilestones, total: roadmap.roadmap.milestones.count))
            }
            path.trackLabels = [roadmap.roadmap.milestones.first?.title ?? "Foundations", roadmap.currentMilestone?.title ?? "Skill building", "Next horizon"]
        } else if let completedRoadmap = store.scoredRoadmaps.first {
            path.title = completedRoadmap.roadmap.title
            path.subtitle = "All milestones completed"
            path.milestonesCompleted = completedRoadmap.completedMilestones
            path.milestonesTotal = completedRoadmap.roadmap.milestones.count
            path.percentComplete = 100
            path.nodes = (0..<completedRoadmap.roadmap.milestones.count).map { _ in .init(status: .completed) }
        } else {
            path.title = profile.careers.first ?? profile.fields.first ?? "Your Student OPS"
            path.subtitle = profile.collegePlan == .notSure ? "Exploration & discovery path" : "Personalized Student OPS pathway"
            path.milestonesCompleted = 0
            path.milestonesTotal = 7
            path.percentComplete = 0
        }
        nextStep = Self.nextStep(for: store)
        opportunity = Self.matchedOpportunity(for: profile)
        metrics = Self.metrics(for: store)
    }

    func updateProfile(_ profile: StudentProfile) {
        studentFirstName = profile.firstName.isEmpty ? "Student" : profile.firstName
        dateLabel = Self.formattedDateLabel()
        let activeRoadmap = RoadmapService.roadmaps(for: profile, progress: UserDefaults.standard.dictionary(forKey: "studentops.roadmapProgress") as? [String: Int] ?? [:]).first(where: { !$0.isCompleted })
        statusSummary = Self.statusSummary(for: profile, activeRoadmap: activeRoadmap)
        if let roadmap = activeRoadmap {
            path.title = roadmap.roadmap.title
            path.subtitle = roadmap.roadmap.goal
            path.milestonesCompleted = roadmap.completedMilestones
            path.milestonesTotal = roadmap.roadmap.milestones.count
            path.percentComplete = roadmap.progress
            path.nodes = (0..<roadmap.roadmap.milestones.count).map { index in
                .init(status: RoadmapEngine.nodeStatus(index: index, completed: roadmap.completedMilestones, total: roadmap.roadmap.milestones.count))
            }
            path.trackLabels = [roadmap.roadmap.milestones.first?.title ?? "Foundations", roadmap.currentMilestone?.title ?? "Skill building", "Next horizon"]
        } else if let completedRoadmap = RoadmapService.roadmaps(for: profile, progress: UserDefaults.standard.dictionary(forKey: "studentops.roadmapProgress") as? [String: Int] ?? [:]).first {
            path.title = completedRoadmap.roadmap.title
            path.subtitle = "All milestones completed"
            path.milestonesCompleted = completedRoadmap.completedMilestones
            path.milestonesTotal = completedRoadmap.roadmap.milestones.count
            path.percentComplete = 100
        }
        nextStep = Self.nextStep(for: profile)
        opportunity = Self.matchedOpportunity(for: profile)
        metrics = Self.metrics(for: profile)
    }
}
