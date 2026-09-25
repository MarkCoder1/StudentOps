import Foundation

// Deterministic snapshot of shared data — no persistence, no hardcoded counts.
struct ProgressSnapshot {
    let completedMilestones: Int
    let totalMilestones: Int
    let milestoneProgress: Int
    let activeRoadmaps: Int
    let completedRoadmaps: Int
    let activeProjects: Int
    let completedProjects: Int
    let totalProjects: Int
    let projectProgress: Int
    let skillCount: Int
    let achievementsCount: Int
    let portfolioCount: Int
    let savedOpportunitiesCount: Int
    let overallProgress: Int
}

enum ProgressEngine {
    static func snapshot(store: AppDataStore) -> ProgressSnapshot {
        let roadmaps = store.scoredRoadmaps
        let projects = store.scoredProjects
        let completedMilestones = roadmaps.reduce(0) { $0 + $1.completedMilestones }
        let totalMilestones = roadmaps.reduce(0) { $0 + $1.roadmap.milestones.count }
        let milestoneProgress = ProgressCalculator.percent(completed: completedMilestones, total: totalMilestones)
        let activeRoadmaps = roadmaps.filter { !$0.isCompleted }.count
        let completedRoadmaps = roadmaps.filter(\.isCompleted).count
        let activeProjects = projects.filter { !$0.isCompleted }.count
        let completedProjects = projects.filter(\.isCompleted).count
        let totalProjects = projects.count
        let totalProjectMilestones = projects.reduce(0) { $0 + $1.project.milestones.count }
        let completedProjectMilestones = projects.reduce(0) { $0 + $1.completedMilestones }
        let projectProgress = ProgressCalculator.percent(completed: completedProjectMilestones, total: totalProjectMilestones)
        let skillCount = store.skillSet.count
        let achievementsCount = store.achievements.count
        let portfolioCount = store.portfolioIDs.count
        let savedCount = store.savedOpportunityIDs.count
        let overallCompleted = completedMilestones + completedProjectMilestones
        let overallTotal = totalMilestones + totalProjectMilestones
        let overallProgress = ProgressCalculator.percent(completed: overallCompleted, total: overallTotal)
        return ProgressSnapshot(
            completedMilestones: completedMilestones,
            totalMilestones: totalMilestones,
            milestoneProgress: milestoneProgress,
            activeRoadmaps: activeRoadmaps,
            completedRoadmaps: completedRoadmaps,
            activeProjects: activeProjects,
            completedProjects: completedProjects,
            totalProjects: totalProjects,
            projectProgress: projectProgress,
            skillCount: skillCount,
            achievementsCount: achievementsCount,
            portfolioCount: portfolioCount,
            savedOpportunitiesCount: savedCount,
            overallProgress: overallProgress
        )
    }
}
