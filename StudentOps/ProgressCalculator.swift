import Foundation

// Deduplicates progress math used in Roadmap.swift:59, Project.swift:32, RoadmapProgressView.swift:7, DashboardModels.swift:139
enum ProgressCalculator {
    static func percent(completed: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(completed) / Double(total) * 100).rounded())
    }
    static func fraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    static func isCompleted(completed: Int, total: Int) -> Bool {
        total > 0 && completed >= total
    }
}

protocol ScoredProgress {
    var completedMilestones: Int { get }
    var totalMilestones: Int { get }
    var progress: Int { get }
    var isCompleted: Bool { get }
}

extension ScoredRoadmap: ScoredProgress {
    var totalMilestones: Int { roadmap.milestones.count }
}
extension ScoredProject: ScoredProgress {
    var totalMilestones: Int { project.milestones.count }
}
