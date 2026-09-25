import Foundation

// Pure calculations for projects — no UserDefaults.
enum ProjectEngine {
    static func completedCount(for project: Project, progress: [String: Int]) -> Int {
        min(progress[project.id] ?? 0, project.milestones.count)
    }

    static func progress(completed: Int, total: Int) -> Int {
        ProgressCalculator.percent(completed: completed, total: total)
    }

    static func status(index: Int, completed: Int) -> MilestoneStatus {
        if index < completed { return .completed }
        if index == completed { return .current }
        return .upcoming
    }

    enum MilestoneStatus { case completed, current, upcoming }

    static func scoredProjects(profile: StudentProfile, progress: [String: Int], customProjects: [Project], catalog: [Project]? = nil) -> [ScoredProject] {
        if let catalog = catalog {
            return (catalog + customProjects).map { project in
                ScoredProject(project: project, matchScore: ProjectService.matchScore(for: project, profile: profile), completedMilestones: min(progress[project.id] ?? 0, project.milestones.count))
            }.sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return lhs.matchScore > rhs.matchScore
            }
        }
        return ProjectService.projects(for: profile, progress: progress, customProjects: customProjects)
    }
}
