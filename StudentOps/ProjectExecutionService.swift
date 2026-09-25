import Foundation

// MARK: - Project Execution State (Phase 9.7)
//
// Persistent, per-project execution state for playbook steps/deliverables/criteria.
// Stored in AppDataStore via UserDefaults Codable, not in catalog.
// Deterministic, no AI.

// Execution state belongs to the student's custom project, not the static catalog.
struct ProjectExecutionState: Identifiable, Hashable, Codable {
    let projectID: String
    var completedStepIDs: Set<String>
    var completedDeliverableIDs: Set<String>
    var confirmedCriterionIDs: Set<String>
    var id: String { projectID }

    init(projectID: String, completedStepIDs: Set<String> = [], completedDeliverableIDs: Set<String> = [], confirmedCriterionIDs: Set<String> = []) {
        self.projectID = projectID
        self.completedStepIDs = completedStepIDs
        self.completedDeliverableIDs = completedDeliverableIDs
        self.confirmedCriterionIDs = confirmedCriterionIDs
    }

    enum CodingKeys: String, CodingKey { case projectID, completedStepIDs, completedDeliverableIDs, confirmedCriterionIDs }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projectID = (try? c.decode(String.self, forKey: .projectID)) ?? UUID().uuidString
        completedStepIDs = (try? c.decode(Set<String>.self, forKey: .completedStepIDs)) ?? []
        completedDeliverableIDs = (try? c.decode(Set<String>.self, forKey: .completedDeliverableIDs)) ?? []
        confirmedCriterionIDs = (try? c.decode(Set<String>.self, forKey: .confirmedCriterionIDs)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(projectID, forKey: .projectID)
        try c.encode(completedStepIDs, forKey: .completedStepIDs)
        try c.encode(completedDeliverableIDs, forKey: .completedDeliverableIDs)
        try c.encode(confirmedCriterionIDs, forKey: .confirmedCriterionIDs)
    }
}

// MARK: - Execution Service (deterministic, single source of truth)

enum ProjectExecutionService {

    // MARK: - Playbook resolution

    /// Returns the playbook for a custom project, using sourceProjectID when available (stable snapshot reference).
    static func playbook(for project: Project) -> ProjectPlaybook? {
        // Prefer sourceProjectID when project was started from catalog idea
        if let src = project.sourceProjectID?.trimmingCharacters(in: .whitespacesAndNewlines), !src.isEmpty {
            if let pb = ProjectPlaybookService.playbook(for: src) { return pb }
        }
        // Fallback to direct projectID (catalog ideas themselves or custom with direct playbook)
        return ProjectPlaybookService.playbook(for: project.id)
    }

    static func hasPlaybook(for project: Project) -> Bool { playbook(for: project) != nil }

    // MARK: - Progress

    /// Deterministic progress: completed required steps / total required steps. If no playbook or no steps, uses old milestone progress via fallback handler.
    /// Returns 0-100 percent, and counts.
    static func progress(for project: Project, state: ProjectExecutionState?) -> (completed: Int, total: Int, percent: Int) {
        if let pb = playbook(for: project), !pb.steps.isEmpty {
            let total = pb.steps.count
            let completed = pb.steps.filter { state?.completedStepIDs.contains($0.id) ?? false }.count
            let pct = total == 0 ? 0 : Int(round(Double(completed) / Double(total) * 100))
            return (completed, total, pct)
        }
        // No playbook: fallback to 0 until another mechanism exists (old milestones not duplicated)
        return (0, 0, 0)
    }

    /// Progress using AppDataStore (handles fallback to projectProgress for projects without playbooks if needed)
    static func progress(for project: Project, store: AppDataStore) -> (completed: Int, total: Int, percent: Int) {
        if let pb = playbook(for: project), !pb.steps.isEmpty {
            let state = store.executionState(for: project.id)
            return progress(for: project, state: state)
        }
        // Fallback to old milestone progress (so existing projects without playbooks still show something)
        let completed = store.completedCount(for: project)
        let total = project.milestones.count
        let pct = ProgressCalculator.percent(completed: completed, total: total)
        return (completed, total, pct)
    }

    // MARK: - Next Step

    /// First incomplete unlocked step (prerequisites satisfied), sorted by order.
    static func nextStep(for project: Project, state: ProjectExecutionState?) -> ProjectPlaybookStep? {
        guard let pb = playbook(for: project), !pb.steps.isEmpty else { return nil }
        let completed = state?.completedStepIDs ?? []
        // Find incomplete steps whose prerequisites are all completed
        let candidates = pb.steps.filter { !completed.contains($0.id) }.filter { step in
            step.prerequisiteStepIDs.allSatisfy { completed.contains($0) }
        }
        return candidates.sorted { $0.order < $1.order }.first
    }

    @MainActor
    static func nextStep(for project: Project, store: AppDataStore) -> ProjectPlaybookStep? {
        nextStep(for: project, state: store.executionState(for: project.id))
    }

    // MARK: - Step locking

    static func isStepLocked(_ step: ProjectPlaybookStep, state: ProjectExecutionState?) -> Bool {
        let completed = state?.completedStepIDs ?? []
        return !step.prerequisiteStepIDs.allSatisfy { completed.contains($0) }
    }

    static func lockedReason(for step: ProjectPlaybookStep, playbook: ProjectPlaybook, state: ProjectExecutionState?) -> String? {
        guard isStepLocked(step, state: state) else { return nil }
        let missing = step.prerequisiteStepIDs.filter { !(state?.completedStepIDs.contains($0) ?? false) }
        let titles = missing.compactMap { mid in playbook.steps.first(where: { $0.id == mid })?.title }
        if titles.isEmpty { return "Requires previous steps" }
        return "Requires: \(titles.joined(separator: ", "))"
    }

    // MARK: - Completion eligibility

    /// All required steps/deliverables/criteria must be complete.
    static func isCompleted(project: Project, state: ProjectExecutionState?) -> Bool {
        guard let pb = playbook(for: project) else {
            // No playbook: consider completed if status is .completed? But deterministic rule cannot be inferred, so false
            return false
        }
        // Steps: all required steps (all steps are required in current model)
        let allStepsDone = pb.steps.allSatisfy { state?.completedStepIDs.contains($0.id) ?? false }
        if !allStepsDone { return false }
        // Deliverables: all required deliverables
        let requiredDelivs = pb.deliverables.filter(\.required)
        if !requiredDelivs.allSatisfy({ state?.completedDeliverableIDs.contains($0.id) ?? false }) { return false }
        // Criteria: all required criteria
        let requiredCrit = pb.completionCriteria.filter(\.required)
        if !requiredCrit.allSatisfy({ state?.confirmedCriterionIDs.contains($0.id) ?? false }) { return false }
        return true
    }

    @MainActor
    static func isCompleted(project: Project, store: AppDataStore) -> Bool {
        isCompleted(project: project, state: store.executionState(for: project.id))
    }

    // MARK: - Status synchronization

    static func synchronizedStatus(for project: Project, state: ProjectExecutionState?) -> ProjectStatus {
        if isCompleted(project: project, state: state) { return .completed }
        if let s = state {
            let hasStarted = !s.completedStepIDs.isEmpty || !s.completedDeliverableIDs.isEmpty || !s.confirmedCriterionIDs.isEmpty
            if hasStarted { return .inProgress }
        }
        // If project already marked completed but not eligible, keep inProgress
        if project.status == .completed && !isCompleted(project: project, state: state) {
            return .inProgress
        }
        // Preserve existing status for projects without playbook
        if playbook(for: project) == nil {
            return project.status
        }
        // No execution yet -> planned
        return .planned
    }

    // MARK: - Validation / Repair

    static func validatedState(_ state: ProjectExecutionState, for project: Project) -> ProjectExecutionState {
        guard let pb = playbook(for: project) else { return state }
        let validStepIDs = Set(pb.steps.map(\.id))
        let validDelivIDs = Set(pb.deliverables.map(\.id))
        let validCritIDs = Set(pb.completionCriteria.map(\.id))
        var repaired = state
        repaired.completedStepIDs = state.completedStepIDs.intersection(validStepIDs)
        repaired.completedDeliverableIDs = state.completedDeliverableIDs.intersection(validDelivIDs)
        repaired.confirmedCriterionIDs = state.confirmedCriterionIDs.intersection(validCritIDs)
        return repaired
    }

    // MARK: - Summary

    struct CompletionSummary {
        let steps: (completed: Int, total: Int)
        let deliverables: (completed: Int, total: Int)
        let criteria: (completed: Int, total: Int)
        let skills: [String]
        let evidenceCount: Int
        let achievementCount: Int
        let isCompleted: Bool
    }

    static func summary(for project: Project, state: ProjectExecutionState?, store: AppDataStore) -> CompletionSummary {
        let pb = playbook(for: project)
        let steps = pb.map { ($0.steps.filter { state?.completedStepIDs.contains($0.id) ?? false }.count, $0.steps.count) } ?? (0,0)
        let requiredDelivs = pb?.deliverables.filter(\.required) ?? []
        let delivCompleted = requiredDelivs.filter { state?.completedDeliverableIDs.contains($0.id) ?? false }.count
        let critRequired = pb?.completionCriteria.filter(\.required) ?? []
        let critCompleted = critRequired.filter { state?.confirmedCriterionIDs.contains($0.id) ?? false }.count
        let skills = pb?.skillsDeveloped ?? project.skills
        let evCount = store.evidenceRecords.values.filter { $0.projectID == project.id }.count
        let achCount = store.achievementRecords.values.filter { $0.projectID == project.id }.count
        let completed = isCompleted(project: project, state: state)
        return CompletionSummary(
            steps: (steps.0, steps.1),
            deliverables: (delivCompleted, requiredDelivs.count),
            criteria: (critCompleted, critRequired.count),
            skills: skills,
            evidenceCount: evCount,
            achievementCount: achCount,
            isCompleted: completed
        )
    }
}
