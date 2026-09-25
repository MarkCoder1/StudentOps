import Foundation

// MARK: - AI Context Builder (Phase 9.8)
// Deterministic, minimal, data-minimized. AI never replaces engines.

@MainActor
enum AIContextBuilder {

    // MARK: - Project Explanation

    static func projectExplanationContext(
        project: Project,
        store: AppDataStore
    ) -> AIProjectExplanationContext {
        let profile = store.profile

        // Student minimal
        let student = AIProjectExplanationContext.Student(
            goals: Array((profile.careers + profile.milestones + profile.fields).prefix(5)),
            interests: Array((profile.interests + profile.customInterests).prefix(5)),
            skills: Array((profile.strengths + profile.customSkills).prefix(8))
        )

        // Project minimal
        let proj = AIProjectExplanationContext.Project(
            id: project.id,
            title: project.title,
            description: project.description,
            category: project.category,
            skills: Array(project.skills.prefix(6))
        )

        // Recommendation from deterministic engine (limit 50, find this project)
        let recs = ProjectRecommendationEngine.recommendations(for: store, limit: 50)
        let rec = recs.first(where: { $0.project.id == project.id })
        let score = rec?.score ?? 0
        let reasons = rec?.reasons.map(\.message) ?? []
        let breakdown = rec?.scoreBreakdown ?? .zero
        let recommendation = AIProjectExplanationContext.Recommendation(
            score: score,
            reasons: Array(reasons.prefix(4)),
            breakdown: .init(
                goalAlignment: breakdown.goalAlignment,
                skillGapCoverage: breakdown.skillGapCoverage,
                roadmapAlignment: breakdown.roadmapAlignment,
                interestAlignment: breakdown.interestAlignment
            )
        )

        // Skill gaps from active roadmaps
        let gaps = SkillGapEngine.evaluateActiveRoadmaps(store: store).flatMap { $0.gaps }.map { $0.skill.name }
        let skillGaps = Array(gaps.prefix(6))

        // Active roadmap (first)
        let roadmap: AIProjectExplanationContext.Roadmap? = {
            guard let active = store.activatedRoadmaps.first else { return nil }
            return .init(id: active.roadmap.id, title: active.roadmap.title, active: true)
        }()

        return AIProjectExplanationContext(
            student: student,
            project: proj,
            recommendation: recommendation,
            skillGaps: skillGaps,
            roadmap: roadmap,
            contextVersion: "9.8"
        )
    }

    // MARK: - Project Coaching

    static func projectCoachingContext(
        project: Project,
        store: AppDataStore
    ) -> AIProjectCoachingContext? {
        guard let playbook = ProjectExecutionService.playbook(for: project) else { return nil }
        let execution = store.executionProgress(for: project)
        let state = store.executionState(for: project.id)
        let next = store.executionNextStep(for: project)
        let current: AIProjectCoachingContext.Step? = {
            guard let ns = next else { return nil }
            return .init(
                id: ns.id,
                title: ns.title,
                description: ns.description,
                objective: ns.objective,
                requiredSkills: ns.requiredSkills,
                estimatedEffort: ns.estimatedEffort
            )
        }()
        // For coaching, "nextStep" is same as current next incomplete; we duplicate for prompt clarity
        let nextCtx: AIProjectCoachingContext.Step? = current

        let playbookCtx: AIProjectCoachingContext.Playbook? = .init(
            overview: playbook.overview,
            steps: playbook.steps.map { .init(id: $0.id, title: $0.title, order: $0.order) },
            skillsDeveloped: playbook.skillsDeveloped
        )

        let exec = AIProjectCoachingContext.Execution(
            completedStepIDs: Array(state?.completedStepIDs ?? []),
            totalSteps: playbook.steps.count,
            percent: execution.percent
        )

        let student = AIProjectCoachingContext.Student(
            goals: Array((store.profile.careers + store.profile.milestones).prefix(4)),
            skills: Array((store.profile.strengths + store.profile.customSkills).prefix(6))
        )
        let gaps = SkillGapEngine.evaluateActiveRoadmaps(store: store).flatMap { $0.gaps }.map { $0.skill.name }

        return AIProjectCoachingContext(
            project: .init(id: project.id, title: project.title, goal: project.goal, description: project.description),
            playbook: playbookCtx,
            execution: exec,
            currentStep: current,
            nextStep: nextCtx,
            student: student,
            skillGaps: Array(gaps.prefix(6)),
            contextVersion: "9.8"
        )
    }

    // MARK: - Project Reflection

    static func projectReflectionContext(
        project: Project,
        store: AppDataStore
    ) -> AIProjectReflectionContext {
        let playbook = ProjectExecutionService.playbook(for: project)
        let state = store.executionState(for: project.id)
        let isCompleted = store.isProjectCompleted(project)
        let evidence = store.evidenceRecords.values.filter { $0.projectID == project.id }.prefix(4).map { AIProjectReflectionContext.Evidence(id: $0.id, title: $0.title) }
        let achievements = store.achievementRecords.values.filter { $0.projectID == project.id }.prefix(4).map { AIProjectReflectionContext.Achievement(id: $0.id, title: $0.title) }

        return AIProjectReflectionContext(
            project: .init(id: project.id, title: project.title, description: project.description, outcome: project.outcome, skills: Array(project.skills.prefix(6))),
            playbook: playbook.map { pb in
                .init(
                    steps: pb.steps.map { .init(id: $0.id, title: $0.title) },
                    deliverables: pb.deliverables.map { .init(id: $0.id, title: $0.title) },
                    criteria: pb.completionCriteria.map { .init(id: $0.id, title: $0.title) }
                )
            },
            execution: .init(
                completedStepIDs: Array(state?.completedStepIDs ?? []),
                completedDeliverableIDs: Array(state?.completedDeliverableIDs ?? []),
                confirmedCriterionIDs: Array(state?.confirmedCriterionIDs ?? []),
                isCompleted: isCompleted
            ),
            evidence: Array(evidence),
            achievements: Array(achievements),
            contextVersion: "9.8"
        )
    }

    // MARK: - Skill Explanation

    static func skillExplanationContext(
        skillID: String,
        store: AppDataStore
    ) -> AISkillExplanationContext? {
        let norm = Skill.normalizeID(skillID)
        guard !norm.isEmpty else { return nil }
        let skill = SkillCatalog.knownSkills[norm] ?? Skill(id: norm, name: skillID)
        // Find gap report for this skill
        let reports = SkillGapEngine.evaluateActiveRoadmaps(store: store)
        var gapReason = "Skill not yet demonstrated"
        var roadmap: AISkillExplanationContext.Roadmap? = nil
        for report in reports {
            if let gap = report.gaps.first(where: { $0.skill.id == norm }) {
                gapReason = gap.reason
                roadmap = .init(id: report.roadmapID, title: report.roadmapTitle)
                break
            }
        }
        // Find a project that teaches this skill (from recommendations)
        let recs = ProjectRecommendationEngine.recommendations(for: store, limit: 20)
        var proj: AISkillExplanationContext.Project? = nil
        for rec in recs where rec.project.skills.map({ Skill.normalizeID($0) }).contains(norm) {
            proj = .init(id: rec.project.id, title: rec.project.title, skills: rec.project.skills)
            break
        }
        let goal = store.profile.careers.first ?? store.profile.milestones.first
        return AISkillExplanationContext(
            skill: .init(id: skill.id, name: skill.name),
            gapReason: gapReason,
            roadmap: roadmap,
            project: proj,
            studentGoal: goal,
            contextVersion: "9.8"
        )
    }

    // MARK: - Roadmap Explanation

    static func roadmapExplanationContext(
        roadmap: Roadmap,
        store: AppDataStore
    ) -> AIRoadmapExplanationContext {
        let completed = store.completedCount(for: roadmap)
        let total = roadmap.milestones.count
        let percent = ProgressCalculator.percent(completed: completed, total: total)
        let isActive = store.isRoadmapActivated(roadmap.id)
        let nextMilestone: AIRoadmapExplanationContext.Milestone? = {
            guard completed < total else { return nil }
            let m = roadmap.milestones[completed]
            return .init(id: m.id, title: m.title)
        }()
        let gaps = SkillGapEngine.evaluate(roadmap: roadmap, store: store).gaps.map { $0.skill.name }
        let relevantProjects = store.scoredProjects.filter { sp in
            let req = Set(SkillGapEngine.requiredSkills(for: roadmap).map(\.id))
            let projSkills = Set(sp.project.skills.map { Skill.normalizeID($0) })
            return !req.intersection(projSkills).isEmpty
        }.prefix(4).map { AIRoadmapExplanationContext.Project(id: $0.project.id, title: $0.project.title) }

        return AIRoadmapExplanationContext(
            roadmap: .init(id: roadmap.id, title: roadmap.title, goal: roadmap.goal),
            progress: .init(completedMilestones: completed, totalMilestones: total, percent: percent, isActive: isActive),
            nextMilestone: nextMilestone,
            skillGaps: Array(gaps.prefix(8)),
            relevantProjects: Array(relevantProjects),
            contextVersion: "9.8"
        )
    }

    // MARK: - Fingerprint (for staleness)

    static func fingerprint<T: Codable>(_ context: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(context) else { return "unknown" }
        let str = String(data: data, encoding: .utf8) ?? ""
        var hash: UInt32 = 2166136261
        for byte in str.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return String(format: "%08x", hash)
    }
}
