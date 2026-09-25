import Combine
import Foundation

@MainActor
final class RoadmapProgressStore: ObservableObject {
    @Published private(set) var completedCounts: [String: Int]
    private let storageKey = "studentops.roadmapProgress"

    init() {
        completedCounts = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] ?? [:]
    }

    func completedCount(for roadmap: Roadmap) -> Int { min(completedCounts[roadmap.id] ?? 0, roadmap.milestones.count) }

    func markMilestoneComplete(for roadmap: Roadmap) {
        let nextCount = min(completedCount(for: roadmap) + 1, roadmap.milestones.count)
        completedCounts[roadmap.id] = nextCount
        UserDefaults.standard.set(completedCounts, forKey: storageKey)
    }

    func reset(_ roadmap: Roadmap) {
        completedCounts[roadmap.id] = 0
        UserDefaults.standard.set(completedCounts, forKey: storageKey)
    }
}
