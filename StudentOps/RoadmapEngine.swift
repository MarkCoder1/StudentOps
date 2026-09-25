import Foundation
import SwiftUI

// Pure calculations for roadmaps — no UserDefaults, no @Published.
// Single source: AppDataStore.roadmapProgress + profile.
enum RoadmapEngine {
    static func completedCount(for roadmap: Roadmap, progress: [String: Int]) -> Int {
        min(progress[roadmap.id] ?? 0, roadmap.milestones.count)
    }

    static func progress(completed: Int, total: Int) -> Int {
        ProgressCalculator.percent(completed: completed, total: total)
    }

    // MARK: - Dependency-Aware Milestone Status

    /// The availability state of a milestone, computed from dependencies and completion.
    enum MilestoneAvailability: Equatable {
        /// The milestone is already completed.
        case completed
        /// The milestone is not completed and all prerequisites are met.
        case available
        /// The milestone is not completed and at least one prerequisite is incomplete.
        case locked(blockingIDs: [String])
    }

    /// Determines the availability of a single milestone.
    /// - Parameters:
    ///   - milestone: The milestone to evaluate.
    ///   - completedIDs: Set of milestone IDs that are completed.
    ///   - milestones: All milestones in the roadmap (for looking up titles).
    /// - Returns: A `MilestoneAvailability` value.
    static func milestoneAvailability(
        milestone: RoadmapMilestone,
        completedIDs: Set<String>,
        milestones: [RoadmapMilestone]
    ) -> MilestoneAvailability {
        if completedIDs.contains(milestone.id) {
            return .completed
        }
        guard let deps = milestone.dependencies, !deps.isEmpty else {
            return .available
        }
        let incomplete = deps.filter { !completedIDs.contains($0) }
        if incomplete.isEmpty {
            return .available
        }
        return .locked(blockingIDs: incomplete)
    }

    /// Returns the title for a milestone ID, or the ID itself if not found.
    static func milestoneTitle(for id: String, milestones: [RoadmapMilestone]) -> String {
        milestones.first(where: { $0.id == id })?.title ?? id
    }

    /// Returns structured blocking information for a locked milestone.
    static func lockedExplanation(
        milestone: RoadmapMilestone,
        milestones: [RoadmapMilestone],
        completedIDs: Set<String>
    ) -> DependencyLockInfo? {
        guard case .locked(let blockingIDs) = milestoneAvailability(milestone: milestone, completedIDs: completedIDs, milestones: milestones) else {
            return nil
        }
        let blockingTitles = blockingIDs.map { DependencyLockInfo.BlockingPrerequisite(id: $0, title: milestoneTitle(for: $0, milestones: milestones)) }
        return DependencyLockInfo(blockingPrerequisites: blockingTitles)
    }

    /// Maps the old index-based status to dependency-aware availability.
    /// Used by MilestoneNodeView and MilestoneDetailView.
    static func status(index: Int, completed: Int, total: Int) -> MilestoneNodeView.MilestoneStatus {
        if index < completed { return .completed }
        if index == completed { return .current }
        return .locked
    }

    /// Dependency-aware status for a specific milestone in context.
    static func dependencyStatus(
        milestone: RoadmapMilestone,
        completedIDs: Set<String>,
        milestones: [RoadmapMilestone]
    ) -> MilestoneNodeView.MilestoneStatus {
        switch milestoneAvailability(milestone: milestone, completedIDs: completedIDs, milestones: milestones) {
        case .completed: return .completed
        case .available: return .current
        case .locked: return .locked
        }
    }

    // Legacy MilestoneStatus for Journey views (separate enum)
    static func nodeStatus(index: Int, completed: Int, total: Int) -> MilestoneNode.Status {
        if index < completed { return .completed }
        if index == completed { return .active }
        if index == total - 1 { return .goal }
        return .upcoming
    }

    static func scoredRoadmaps(profile: StudentProfile, progress: [String: Int], catalog: [Roadmap]? = nil) -> [ScoredRoadmap] {
        // Reuse RoadmapService for scoring/sorting to avoid duplication
        if let catalog = catalog {
            // Custom catalog path (for testing) — replicate RoadmapService logic
            return catalog.map { roadmap in
                ScoredRoadmap(roadmap: roadmap, matchScore: RoadmapService.matchScore(for: roadmap, profile: profile), completedMilestones: min(progress[roadmap.id] ?? 0, roadmap.milestones.count))
            }.sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return lhs.matchScore > rhs.matchScore
            }
        }
        return RoadmapService.roadmaps(for: profile, progress: progress)
    }

    // MARK: - Action Progress

    static func completedActionsCount(for milestone: RoadmapMilestone, completedIDs: Set<String>) -> Int {
        guard let actions = milestone.actions else { return 0 }
        return actions.filter { completedIDs.contains($0.id) }.count
    }

    static func totalActionsCount(for milestone: RoadmapMilestone) -> Int {
        milestone.actions?.count ?? 0
    }

    static func actionProgress(for milestone: RoadmapMilestone, completedIDs: Set<String>) -> Int {
        let completed = completedActionsCount(for: milestone, completedIDs: completedIDs)
        let total = totalActionsCount(for: milestone)
        return ProgressCalculator.percent(completed: completed, total: total)
    }

    static func allActionsCompleted(for milestone: RoadmapMilestone, completedIDs: Set<String>) -> Bool {
        guard let actions = milestone.actions, !actions.isEmpty else { return false }
        return actions.allSatisfy { completedIDs.contains($0.id) }
    }

    // MARK: - Validation Engine

    static func score(answers: [String: Int], questions: [ValidationQuestion]) -> Int {
        guard !questions.isEmpty else { return 0 }
        return questions.filter { q in
            if let selected = answers[q.id] { return selected == q.correctAnswer }
            return false
        }.count
    }

    static func percentage(score: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100).rounded())
    }

    static func passed(percentage: Int, threshold: Int) -> Bool {
        percentage >= threshold
    }

    static func validationStatus(assessment: MilestoneAssessment?, bestAttempt: ValidationAttempt?) -> ValidationStatus {
        guard let assessment = assessment, !assessment.questions.isEmpty else { return .notAvailable }
        guard let attempt = bestAttempt else { return .notStarted }
        return attempt.passed ? .passed : .notPassed
    }

    static func explanations(for answers: [String: Int], questions: [ValidationQuestion]) -> [String: String] {
        var result: [String: String] = [:]
        for q in questions {
            result[q.id] = q.explanation
        }
        return result
    }

    // MARK: - Dependency Validation

    /// Validates the dependency graph of a roadmap.
    /// Returns a result indicating whether the graph is valid, with specific errors if not.
    static func validateDependencies(for roadmap: Roadmap) -> DependencyValidationResult {
        var errors: [DependencyValidationError] = []
        let milestoneIDs = Set(roadmap.milestones.map(\.id))

        for milestone in roadmap.milestones {
            guard let deps = milestone.dependencies else { continue }

            // Check for empty/whitespace-only dependency IDs
            for dep in deps {
                let trimmed = dep.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    errors.append(.emptyDependencyID(milestoneID: milestone.id))
                }
            }

            // Check for duplicate dependency IDs
            let uniqueDeps = Set(deps)
            if uniqueDeps.count != deps.count {
                errors.append(.duplicateDependencies(milestoneID: milestone.id))
            }

            // Check for self-dependency
            if deps.contains(milestone.id) {
                errors.append(.selfDependency(milestoneID: milestone.id))
            }

            // Check for references to nonexistent milestones
            for dep in deps {
                if !milestoneIDs.contains(dep) {
                    errors.append(.invalidReference(milestoneID: milestone.id, referencedID: dep))
                }
            }
        }

        // Cycle detection using DFS
        let cycleErrors = detectCycles(in: roadmap)
        errors.append(contentsOf: cycleErrors)

        return DependencyValidationResult(errors: errors)
    }

    /// Detects cycles in the dependency graph using DFS.
    private static func detectCycles(in roadmap: Roadmap) -> [DependencyValidationError] {
        var errors: [DependencyValidationError] = []
        let milestoneIDs = Set(roadmap.milestones.map(\.id))

        // Build adjacency list (only valid references)
        var graph: [String: [String]] = [:]
        for milestone in roadmap.milestones {
            let validDeps = (milestone.dependencies ?? []).filter { milestoneIDs.contains($0) }
            graph[milestone.id] = validDeps
        }

        // DFS with three states: unvisited, in-progress, completed
        var state: [String: Int] = [:] // 0 = unvisited, 1 = in-progress, 2 = completed
        for id in milestoneIDs { state[id] = 0 }

        func dfs(_ node: String, _ path: inout [String]) -> Bool {
            state[node] = 1
            path.append(node)
            for neighbor in (graph[node] ?? []) {
                if state[neighbor] == 1 {
                    // Found a cycle — extract cycle path
                    if let cycleStart = path.firstIndex(of: neighbor) {
                        let cycle = Array(path[cycleStart...]) + [neighbor]
                        let cycleTitles = cycle.map { milestoneTitle(for: $0, milestones: roadmap.milestones) }
                        errors.append(.cyclicDependency(cycleIDs: cycle, cycleTitles: cycleTitles))
                    }
                    return true
                }
                if state[neighbor] == 0 {
                    if dfs(neighbor, &path) { return true }
                }
            }
            path.removeLast()
            state[node] = 2
            return false
        }

        for id in milestoneIDs where state[id] == 0 {
            var path: [String] = []
            _ = dfs(id, &path)
        }

        return errors
    }
}

// MARK: - Dependency Validation Types

/// The result of validating a roadmap's dependency graph.
struct DependencyValidationResult {
    let errors: [DependencyValidationError]
    var isValid: Bool { errors.isEmpty }
}

/// Specific errors that can be found in a dependency graph.
enum DependencyValidationError: Equatable {
    /// A milestone references a dependency ID that does not exist in the roadmap.
    case invalidReference(milestoneID: String, referencedID: String)
    /// A milestone depends on itself.
    case selfDependency(milestoneID: String)
    /// A milestone has the same dependency ID listed more than once.
    case duplicateDependencies(milestoneID: String)
    /// A milestone has an empty or whitespace-only dependency ID.
    case emptyDependencyID(milestoneID: String)
    /// A cycle exists in the dependency graph.
    case cyclicDependency(cycleIDs: [String], cycleTitles: [String])
}

/// Information about why a milestone is locked.
struct DependencyLockInfo: Equatable {
    let blockingPrerequisites: [BlockingPrerequisite]

    struct BlockingPrerequisite: Equatable {
        let id: String
        let title: String
    }
}

enum ValidationStatus {
    case notAvailable
    case notStarted
    case notPassed
    case passed
}
