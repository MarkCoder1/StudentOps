import Foundation

// MARK: - Adaptive Roadmap Engine (Phase 12A)

/// Deterministic engine for computing adaptive roadmap recommendations.
/// Read-only, no mutation, grounded in existing canonical data.
/// Same inputs always produce the same result.
enum AdaptiveRoadmapEngine {

    // MARK: - Public API

    /// Computes the adaptive roadmap recommendation for a specific roadmap.
    /// - Parameters:
    ///   - roadmap: The canonical roadmap to adapt
    ///   - profile: The student's profile
    ///   - store: The app data store for accessing canonical state
    /// - Returns: An AdaptiveRoadmapResult with derived recommendations
    static func recommend(
        roadmap: Roadmap,
        profile: StudentProfile,
        store: AppDataStore
    ) -> AdaptiveRoadmapResult {
        // Build context from canonical student graph
        let context = buildContext(roadmap: roadmap, profile: profile, store: store)

        // Handle insufficient context early
        if context.hasInsufficientContext {
            return buildInsufficientContextResult(roadmap: roadmap, context: context, profile: profile)
        }

        // Compute core data
        let skillGaps = computeSkillGaps(roadmap: roadmap, profile: profile, store: store, context: context)
        let completedMilestoneIDs = context.completedMilestoneIDs
        let completedActionIDs = Set(context.completedActionIDs)
        let activeMilestoneIndex = completedMilestoneIDs.count

        // Locked actions due to milestone dependencies
        var lockedActionIDs = Set<String>()
        var lockedMilestoneBlockers: [String: [String]] = [:]
        for milestone in roadmap.milestones where !completedMilestoneIDs.contains(milestone.id) {
            if let deps = milestone.dependencies, !deps.isEmpty {
                let missing = deps.filter { !completedMilestoneIDs.contains($0) }
                if !missing.isEmpty {
                    for action in milestone.actions ?? [] {
                        lockedActionIDs.insert(action.id)
                        lockedMilestoneBlockers[action.id] = missing
                    }
                }
            }
        }

        var next: [AdaptiveRoadmapRecommendation] = []
        var blocked: [AdaptiveRoadmapRecommendation] = []
        var completed: [AdaptiveRoadmapRecommendation] = []
        var warnings: [String] = []

        func recID(type: AdaptiveRoadmapRecommendationType, id: String) -> String {
            "\(roadmap.id)-\(type.rawValue)-\(id)"
        }

        // Process skill gaps with transitive prerequisite analysis
        for gap in skillGaps {
            let trans = transitivePrereqs(for: gap)
            let missing = trans.filter { !context.currentSkills.contains($0) }

            if !missing.isEmpty {
                // Dependent skill is BLOCKED — find the first ready prerequisite to recommend
                var readyPrereq: String? = nil
                for p in missing {
                    let subP = CareerSkillGraph.prerequisites(for: p)
                    if subP.allSatisfy({ context.currentSkills.contains($0) }) {
                        readyPrereq = p
                        break
                    }
                }
                let targetPrereq = readyPrereq ?? missing.first!

                let warn = "\(gap) blocked by \(targetPrereq)"
                if !warnings.contains(warn) { warnings.append(warn) }

                // Blocked recommendation for the dependent skill
                let bID = recID(type: .blocked, id: gap)
                if !blocked.contains(where: { $0.id == bID }) {
                    blocked.append(AdaptiveRoadmapRecommendation(
                        id: bID,
                        type: .blocked,
                        title: displayName(for: gap),
                        reason: "Requires \(displayName(for: targetPrereq)).",
                        reasonCode: .blockedByPrerequisite,
                        priority: 10,
                        state: .blocked,
                        relatedSkillID: gap,
                        prerequisiteSkillIDs: trans,
                        relatedProjectID: nil,
                        relatedOpportunityID: nil,
                        relatedRoadmapActionID: nil,
                        evidenceSkillID: nil,
                        isBlocked: true,
                        blockedReason: "Requires \(displayName(for: targetPrereq))"
                    ))
                }

                // Recommend the ready prerequisite
                let pID = recID(type: .prerequisite, id: targetPrereq)
                if !next.contains(where: { $0.id == pID }) {
                    next.append(AdaptiveRoadmapRecommendation(
                        id: pID,
                        type: .prerequisite,
                        title: displayName(for: targetPrereq),
                        reason: "Prerequisite for \(displayName(for: gap)). \(displayName(for: gap)) requires \(displayName(for: targetPrereq)) first.",
                        reasonCode: .missingPrerequisite,
                        priority: 95,
                        state: .ready,
                        relatedSkillID: targetPrereq,
                        prerequisiteSkillIDs: CareerSkillGraph.prerequisites(for: targetPrereq),
                        relatedProjectID: nil,
                        relatedOpportunityID: nil,
                        relatedRoadmapActionID: nil,
                        evidenceSkillID: nil,
                        isBlocked: false,
                        blockedReason: nil
                    ))
                }
            } else {
                // Gap is ready — check if roadmap action exists for this skill
                var matchedAction: MilestoneAction? = nil
                var matchedMilestone: RoadmapMilestone? = nil
                for milestone in roadmap.milestones {
                    if let devs = milestone.skillsDeveloped,
                       devs.map({ Skill.normalizeID($0) }).contains(gap) {
                        matchedAction = milestone.actions?.first
                        matchedMilestone = milestone
                        break
                    }
                }

                if let action = matchedAction {
                    if completedActionIDs.contains(action.id) {
                        completed.append(AdaptiveRoadmapRecommendation(
                            id: recID(type: .skillGap, id: gap),
                            type: .skillGap,
                            title: displayName(for: gap),
                            reason: "Skill gap already addressed via completed action.",
                            reasonCode: .actionCompleted,
                            priority: 0,
                            state: .completed,
                            relatedSkillID: gap,
                            prerequisiteSkillIDs: trans,
                            relatedProjectID: nil,
                            relatedOpportunityID: nil,
                            relatedRoadmapActionID: action.id,
                            evidenceSkillID: nil,
                            isBlocked: false,
                            blockedReason: nil
                        ))
                        continue
                    }

                    if lockedActionIDs.contains(action.id) {
                        let blockers = lockedMilestoneBlockers[action.id]?.joined(separator: ", ") ?? "prerequisite milestone"
                        blocked.append(AdaptiveRoadmapRecommendation(
                            id: recID(type: .blocked, id: gap),
                            type: .blocked,
                            title: displayName(for: gap),
                            reason: "Blocked by roadmap milestone: \(blockers).",
                            reasonCode: .blockedByPrerequisite,
                            priority: 10,
                            state: .blocked,
                            relatedSkillID: gap,
                            prerequisiteSkillIDs: trans,
                            relatedProjectID: nil,
                            relatedOpportunityID: nil,
                            relatedRoadmapActionID: action.id,
                            evidenceSkillID: nil,
                            isBlocked: true,
                            blockedReason: blockers
                        ))
                        continue
                    }
                }

                // Active skill gap recommendation
                let gRecID = recID(type: .skillGap, id: gap)
                if !next.contains(where: { $0.id == gRecID }) {
                    next.append(AdaptiveRoadmapRecommendation(
                        id: gRecID,
                        type: .skillGap,
                        title: displayName(for: gap),
                        reason: "Core skill for \(roadmap.title) and an active skill gap.",
                        reasonCode: .activeSkillGap,
                        priority: 75,
                        state: .ready,
                        relatedSkillID: gap,
                        prerequisiteSkillIDs: trans,
                        relatedProjectID: nil,
                        relatedOpportunityID: nil,
                        relatedRoadmapActionID: matchedAction?.id,
                        evidenceSkillID: nil,
                        isBlocked: false,
                        blockedReason: nil
                    ))
                }
            }
        }

        // Ready roadmap actions (continue)
        for milestone in roadmap.milestones {
            guard !completedMilestoneIDs.contains(milestone.id) else { continue }
            let isLocked = (milestone.dependencies ?? []).contains { !completedMilestoneIDs.contains($0) }
            guard !isLocked else { continue }
            for action in milestone.actions ?? [] where !completedActionIDs.contains(action.id) {
                if next.contains(where: { $0.relatedRoadmapActionID == action.id }) { continue }
                next.append(AdaptiveRoadmapRecommendation(
                    id: recID(type: .continue, id: action.id),
                    type: .continue,
                    title: action.title,
                    reason: "Next roadmap action is ready.",
                    reasonCode: .actionIncomplete,
                    priority: 55,
                    state: .ready,
                    relatedSkillID: nil,
                    prerequisiteSkillIDs: [],
                    relatedProjectID: nil,
                    relatedOpportunityID: nil,
                    relatedRoadmapActionID: action.id,
                    evidenceSkillID: nil,
                    isBlocked: false,
                    blockedReason: nil
                ))
            }
        }

        // Relevant existing projects
        for gap in skillGaps.prefix(2) {
            for project in store.customProjects {
                let pSkills = Set(project.skills.map { Skill.normalizeID($0) })
                if pSkills.contains(gap) {
                    let inProg = (store.projectProgress[project.id] ?? 0) > 0
                    let pRecID = recID(type: .project, id: project.id)
                    if !next.contains(where: { $0.id == pRecID }) {
                        next.append(AdaptiveRoadmapRecommendation(
                            id: pRecID,
                            type: .project,
                            title: inProg ? "Continue \(project.title)" : "Start \(project.title)",
                            reason: "Builds \(displayName(for: gap)), an active career skill gap.",
                            reasonCode: .projectBuildsSkill,
                            priority: inProg ? 47 : 42,
                            state: inProg ? .inProgress : .ready,
                            relatedSkillID: gap,
                            prerequisiteSkillIDs: CareerSkillGraph.prerequisites(for: gap),
                            relatedProjectID: project.id,
                            relatedOpportunityID: nil,
                            relatedRoadmapActionID: nil,
                            evidenceSkillID: nil,
                            isBlocked: false,
                            blockedReason: nil
                        ))
                    }
                }
            }
        }

        // Relevant eligible opportunities
        for gap in skillGaps.prefix(2) {
            for opp in store.opportunities {
                let oSkills = Set(opp.skills.map { Skill.normalizeID($0) })
                let eligibility = store.eligibility(for: opp)
                if oSkills.contains(gap) && eligibility.isEligible {
                    let oRecID = recID(type: .opportunity, id: opp.id)
                    if !next.contains(where: { $0.id == oRecID }) {
                        next.append(AdaptiveRoadmapRecommendation(
                            id: oRecID,
                            type: .opportunity,
                            title: opp.title,
                            reason: "Eligible opportunity builds \(displayName(for: gap)).",
                            reasonCode: .opportunityBuildsSkill,
                            priority: 35,
                            state: .ready,
                            relatedSkillID: gap,
                            prerequisiteSkillIDs: [],
                            relatedProjectID: nil,
                            relatedOpportunityID: opp.id,
                            relatedRoadmapActionID: nil,
                            evidenceSkillID: nil,
                            isBlocked: false,
                            blockedReason: nil
                        ))
                    }
                }
            }
        }

        // Missing evidence for demonstrated skills
        for sid in context.currentSkills {
            let hasEv = store.evidenceRecords.values.contains { record in
                record.skillIDs?.contains(sid) ?? false
            }
            if !hasEv {
                let evRecID = recID(type: .evidence, id: sid)
                if !next.contains(where: { $0.id == evRecID }) {
                    next.append(AdaptiveRoadmapRecommendation(
                        id: evRecID,
                        type: .evidence,
                        title: "Document \(displayName(for: sid))",
                        reason: "Skill demonstrated but lacks evidence.",
                        reasonCode: .evidenceMissing,
                        priority: 22,
                        state: .ready,
                        relatedSkillID: sid,
                        prerequisiteSkillIDs: [],
                        relatedProjectID: nil,
                        relatedOpportunityID: nil,
                        relatedRoadmapActionID: nil,
                        evidenceSkillID: sid,
                        isBlocked: false,
                        blockedReason: nil
                    ))
                }
            }
        }

        // Completion detection
        let allMilestonesDone = !roadmap.milestones.isEmpty && completedMilestoneIDs.count >= roadmap.milestones.count
        if allMilestonesDone || (skillGaps.isEmpty && next.isEmpty) {
            let cRec = AdaptiveRoadmapRecommendation(
                id: "\(roadmap.id)-complete",
                type: .complete,
                title: "Roadmap complete",
                reason: "Target already covered via demonstrated skills and evidence.",
                reasonCode: .targetAlreadyCovered,
                priority: 0,
                state: .completed,
                relatedSkillID: nil,
                prerequisiteSkillIDs: [],
                relatedProjectID: nil,
                relatedOpportunityID: nil,
                relatedRoadmapActionID: nil,
                evidenceSkillID: nil,
                isBlocked: false,
                blockedReason: nil
            )
            completed.append(cRec)
            if next.isEmpty { next.append(cRec) }
        }

        // Stable deterministic sort
        next.sort { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            if a.type.rawValue != b.type.rawValue { return a.type.rawValue < b.type.rawValue }
            let keyA = a.relatedSkillID ?? a.relatedRoadmapActionID ?? a.relatedProjectID ?? a.id
            let keyB = b.relatedSkillID ?? b.relatedRoadmapActionID ?? b.relatedProjectID ?? b.id
            if keyA != keyB { return keyA < keyB }
            return a.id < b.id
        }

        blocked.sort { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            let keyA = a.relatedSkillID ?? a.id
            let keyB = b.relatedSkillID ?? b.id
            return keyA < keyB
        }

        // Build explanations
        var explanations: [String] = []
        if let top = next.first(where: { $0.type != .complete }) {
            explanations.append("Recommended next: \(top.title) — \(top.reason)")
        }
        for w in warnings {
            explanations.append("Blocked: \(w)")
        }
        if next.contains(where: { $0.type == .complete }) {
            explanations.append("Target already covered.")
        }

        return AdaptiveRoadmapResult(
            roadmapID: roadmap.id,
            roadmapTitle: roadmap.title,
            targetCareerID: context.targetCareerID,
            targetGoal: context.targetGoal,
            context: context,
            recommendedNext: Array(next.prefix(5)),
            blocked: blocked,
            completed: completed,
            skillGaps: skillGaps,
            prerequisiteWarnings: warnings,
            isInsufficientContext: false,
            explanations: explanations,
            generatedAt: Date()
        )
    }

    // MARK: - Context Building

    private static func buildContext(
        roadmap: Roadmap,
        profile: StudentProfile,
        store: AppDataStore
    ) -> AdaptiveRoadmapContext {
        // Current skills from profile + demonstrated via milestones/evidence
        var currentSkills = Set(profile.strengths.map { Skill.normalizeID($0) } + profile.customSkills.map { Skill.normalizeID($0) })

        // Add skills from evidence records
        for record in store.evidenceRecords.values {
            if let skillIDs = record.skillIDs {
                for sid in skillIDs {
                    currentSkills.insert(Skill.normalizeID(sid))
                }
            }
        }

        // Required skills from roadmap
        var roadmapSkills: [String] = []
        for milestone in roadmap.milestones {
            if let devs = milestone.skillsDeveloped {
                for d in devs {
                    let n = Skill.normalizeID(d)
                    if !roadmapSkills.contains(n) { roadmapSkills.append(n) }
                }
            }
        }

        let skillGaps = roadmapSkills.filter { !currentSkills.contains($0) }

        // Progress
        let completedCount = min(store.roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
        let completedMIDs = Set(roadmap.milestones.prefix(completedCount).map(\.id))

        // Target career/goal
        let targetCareer = profile.careers.first.map { Career.normalizeID(title: $0) }
        let targetGoal = profile.milestones.first ?? roadmap.goal

        // Completed/active projects
        let completedProjectIDs = store.customProjects.filter { proj in
            (store.projectProgress[proj.id] ?? 0) >= proj.milestones.count
        }.map(\.id).sorted()
        let activeProjectIDs = store.customProjects.filter { proj in
            (store.projectProgress[proj.id] ?? 0) < proj.milestones.count
        }.map(\.id).sorted()

        // Relevant opportunities (matching skill gaps)
        let relevantOpportunityIDs = store.opportunities.filter { opp in
            !Set(opp.skills.map { Skill.normalizeID($0) }).isDisjoint(with: Set(skillGaps))
        }.map(\.id).sorted()

        // Evidence skills
        let evidenceSkillIDs = store.evidenceRecords.values.flatMap { record in
            record.skillIDs?.map { Skill.normalizeID($0) } ?? []
        }.sorted()

        // Transitive prerequisites for all gaps
        var allRelevantPrereqs = Set<String>()
        for gap in skillGaps {
            for p in transitivePrereqs(for: gap) {
                allRelevantPrereqs.insert(p)
            }
        }

        // Insufficient context check
        let hasGoal = !(profile.careers.isEmpty && profile.fields.isEmpty && profile.milestones.isEmpty)
        let hasSkills = !currentSkills.isEmpty
        let hasActiveRoadmaps = !store.activeRoadmaps.isEmpty
        let isInsufficient = (!hasGoal && !hasSkills && !hasActiveRoadmaps) ||
                             (!store.activeRoadmaps.keys.contains(roadmap.id) && profile.careers.isEmpty && profile.fields.isEmpty) ||
                             roadmap.id.isEmpty

        return AdaptiveRoadmapContext(
            roadmapID: roadmap.id,
            roadmapTitle: roadmap.title,
            targetCareerID: targetCareer,
            targetGoal: targetGoal,
            currentSkills: currentSkills.sorted(),
            skillGaps: skillGaps.sorted(),
            completedActionIDs: store.completedActionIDs.sorted(),
            completedMilestoneIDs: completedMIDs.sorted(),
            activeRoadmapID: store.activeRoadmaps.keys.first,
            completedProjectIDs: completedProjectIDs,
            activeProjectIDs: activeProjectIDs,
            relevantOpportunityIDs: relevantOpportunityIDs,
            evidenceSkillIDs: evidenceSkillIDs,
            prerequisites: allRelevantPrereqs.sorted(),
            hasInsufficientContext: isInsufficient
        )
    }

    // MARK: - Skill Gap Computation

    private static func computeSkillGaps(
        roadmap: Roadmap,
        profile: StudentProfile,
        store: AppDataStore,
        context: AdaptiveRoadmapContext
    ) -> [String] {
        // Return normalized skill gaps from context (already computed)
        context.skillGaps
    }

    // MARK: - Insufficient Context Result

    private static func buildInsufficientContextResult(
        roadmap: Roadmap,
        context: AdaptiveRoadmapContext,
        profile: StudentProfile
    ) -> AdaptiveRoadmapResult {
        let msg = profile.careers.isEmpty && profile.fields.isEmpty
            ? "Choose a goal to adapt your roadmap."
            : "Build your skill profile to unlock more specific next steps."

        let rec = AdaptiveRoadmapRecommendation(
            id: "\(roadmap.id)-insufficient",
            type: .complete,
            title: "Choose a goal to adapt your roadmap",
            reason: msg,
            reasonCode: .insufficientContext,
            priority: 0,
            state: .notStarted,
            relatedSkillID: nil,
            prerequisiteSkillIDs: [],
            relatedProjectID: nil,
            relatedOpportunityID: nil,
            relatedRoadmapActionID: nil,
            evidenceSkillID: nil,
            isBlocked: false,
            blockedReason: nil
        )

        return AdaptiveRoadmapResult(
            roadmapID: roadmap.id,
            roadmapTitle: roadmap.title,
            targetCareerID: context.targetCareerID,
            targetGoal: context.targetGoal,
            context: context,
            recommendedNext: [rec],
            blocked: [],
            completed: [],
            skillGaps: context.skillGaps,
            prerequisiteWarnings: [],
            isInsufficientContext: true,
            explanations: [msg],
            generatedAt: Date()
        )
    }

    // MARK: - Prerequisite Resolution (using CareerSkillGraph)

    /// Returns transitive prerequisites for a skill (all ancestors in the prerequisite graph).
    private static func transitivePrereqs(for skillID: String) -> [String] {
        let sid = Skill.normalizeID(skillID)
        var result: [String] = []
        var visited = Set<String>()
        var inStack = Set<String>()

        func dfs(_ current: String) {
            if inStack.contains(current) || visited.contains(current) { return }
            inStack.insert(current)
            for p in CareerSkillGraph.prerequisites(for: current) {
                dfs(p)
            }
            inStack.remove(current)
            visited.insert(current)
            if current != sid && !result.contains(current) {
                result.append(current)
            }
        }

        dfs(sid)
        return result
    }

    // MARK: - Display Name Helper

    private static func displayName(for skillID: String) -> String {
        SkillCatalog.knownSkills[skillID]?.name ?? skillID.capitalized
    }
}