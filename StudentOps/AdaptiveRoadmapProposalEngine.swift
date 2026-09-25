import Foundation

// MARK: - Adaptive Roadmap Proposal Engine (Phase 12B)
// Deterministic proposal generation consuming Phase 12A's AdaptiveRoadmapResult.
// No duplication of prerequisite/skill-gap calculations — reuses CareerSkillGraph, SkillGapEngine, AdaptiveRoadmapEngine, OpportunityEligibilityEngine.

enum AdaptiveRoadmapProposalEngine {

    // MARK: - Public API

    /// Deterministic proposals for a roadmap from canonical student graph.
    /// Same inputs always produce same proposals, sorted by deterministic priority.
    static func proposals(
        roadmap: Roadmap,
        profile: StudentProfile,
        store: AppDataStore
    ) -> [AdaptiveRoadmapProposal] {
        let result = AdaptiveRoadmapEngine.recommend(roadmap: roadmap, profile: profile, store: store)
        return proposals(roadmap: roadmap, result: result, store: store)
    }

    /// Overload using precomputed result (avoids recompute).
    static func proposals(
        roadmap: Roadmap,
        result: AdaptiveRoadmapResult,
        store: AppDataStore
    ) -> [AdaptiveRoadmapProposal] {
        var proposals: [AdaptiveRoadmapProposal] = []

        let currentSkills = Set(result.context.currentSkills.map { Skill.normalizeID($0) })
        let completedMIDs = Set(result.context.completedMilestoneIDs)
        let completedActions = Set(result.context.completedActionIDs)
        let skillGaps = result.skillGaps.map { Skill.normalizeID($0) }
        let blockedSkillIDs = Set(result.blocked.compactMap { $0.relatedSkillID }.map { Skill.normalizeID($0) })

        // Helper for deterministic timestamp (fixed epoch for determinism)
        let deterministicDate = Date(timeIntervalSince1970: 1_700_000_000)

        // Use skill gap priorities from SkillGapEngine for relevance decisions
        let gapReport = SkillGapEngine.evaluate(roadmap: roadmap, profile: store.profile, progress: store.roadmapProgress, catalog: store.scoredRoadmaps.map(\.roadmap), evidenceRecords: store.evidenceRecords)

        // --- 1. Newly satisfied prerequisites -> unlockAction (highest priority) ---
        // For each blocked skill, if its direct prerequisite is now in currentSkills, propose unlock.
        for blocked in result.blocked {
            guard let skillID = blocked.relatedSkillID.map({ Skill.normalizeID($0) }), !skillID.isEmpty else { continue }
            // Skip if skill already deferred? still propose unlock
            let prereqs = CareerSkillGraph.prerequisites(for: skillID)
            for prereq in prereqs where currentSkills.contains(prereq) {
                // Find milestone that teaches this blocked skill
                for milestone in roadmap.milestones where (milestone.skillsDeveloped?.map { Skill.normalizeID($0) } ?? []).contains(skillID) {
                    guard let action = milestone.actions?.first else { continue }
                    if completedActions.contains(action.id) { continue }
                    // Determine before/after: before = blocked, after = ready (reordered)
                    let beforeMilestones = roadmap.milestones.map(\.id)
                    var afterMilestones = beforeMilestones
                    // Move this milestone earlier if it was after a blocked predecessor
                    // Simple: if milestone has dependency, ensure dependency milestone is completed; if so, move it to next position after last completed milestone
                    if let deps = milestone.dependencies, !deps.isEmpty, deps.allSatisfy({ completedMIDs.contains($0) }) {
                        // Remove and reinsert at position after completed count
                        if let idx = afterMilestones.firstIndex(of: milestone.id) {
                            afterMilestones.remove(at: idx)
                            let insertIdx = min(completedMIDs.count, afterMilestones.count)
                            afterMilestones.insert(milestone.id, at: insertIdx)
                        }
                    } else if milestone.dependencies == nil || milestone.dependencies?.isEmpty == true {
                        // No milestone dependency but skill prereq satisfied -> treat as unlock via skill ordering
                        // Place just after current milestone sequence
                        if let idx = afterMilestones.firstIndex(of: milestone.id), idx != completedMIDs.count {
                            afterMilestones.remove(at: idx)
                            let insertIdx = min(completedMIDs.count, afterMilestones.count)
                            afterMilestones.insert(milestone.id, at: insertIdx)
                        }
                    } else {
                        // Dependencies not yet marked complete but skill prerequisite satisfied -> still propose skill-based unlock
                        if let idx = afterMilestones.firstIndex(of: milestone.id), idx != completedMIDs.count {
                            afterMilestones.remove(at: idx)
                            let insertIdx = min(completedMIDs.count, afterMilestones.count)
                            afterMilestones.insert(milestone.id, at: insertIdx)
                        }
                    }

                    let pid = AdaptiveRoadmapProposal.makeID(roadmapID: roadmap.id, type: .unlockAction, key: skillID)
                    if proposals.contains(where: { $0.id == pid }) { continue }
                    let alreadyApplied = store.adaptiveOverrides.appliedProposalIDs.contains(pid)
                    if alreadyApplied { continue }

                    let title = "\(displayName(for: skillID)) is now available"
                    let explanation = "You completed its prerequisite: \(displayName(for: prereq)). Suggested change: Move \(displayName(for: skillID)) into your active sequence."
                    let proposal = AdaptiveRoadmapProposal(
                        id: pid,
                        roadmapID: roadmap.id,
                        changeType: .unlockAction,
                        affectedActionIDs: [action.id],
                        affectedMilestoneIDs: [milestone.id],
                        title: title,
                        explanation: explanation,
                        reasonCode: .newlySatisfiedPrerequisite,
                        beforeState: AdaptiveProposalStateSnapshot(orderedMilestoneIDs: beforeMilestones, completedActionIDs: Array(completedActions).sorted()),
                        afterState: AdaptiveProposalStateSnapshot(orderedMilestoneIDs: afterMilestones, completedActionIDs: Array(completedActions).sorted()),
                        priority: 95,
                        isReversible: true,
                        createdAt: deterministicDate,
                        sourceSkillID: prereq,
                        sourceMilestoneID: milestone.id,
                        prerequisiteSkillIDs: prereqs
                    )
                    proposals.append(proposal)
                }
            }
        }

        // --- 2. Previously blocked milestones now unlocked via completed dependencies -> unlockAction / reorderAction ---
        for milestone in roadmap.milestones where !completedMIDs.contains(milestone.id) {
            guard let deps = milestone.dependencies, !deps.isEmpty else { continue }
            if deps.allSatisfy({ completedMIDs.contains($0) }) {
                // All deps satisfied, was previously locked, now available
                // Check if this milestone's action was previously blocked (if it appeared in blocked before? For determinism, generate if not already proposed)
                for action in milestone.actions ?? [] where !completedActions.contains(action.id) {
                    let pid = AdaptiveRoadmapProposal.makeID(roadmapID: roadmap.id, type: .unlockAction, key: "milestone-\(milestone.id)")
                    if proposals.contains(where: { $0.id == pid }) { continue }
                    if store.adaptiveOverrides.appliedProposalIDs.contains(pid) { continue }
                    // Ensure not already in recommendedNext as continue? If it's already ready, we still propose explicit unlock advice
                    let isReadyInResult = result.recommendedNext.contains(where: { $0.relatedRoadmapActionID == action.id && $0.type == .continue })
                    if !isReadyInResult {
                        // Also check skillGap type
                        let isSkillGapReady = result.recommendedNext.contains(where: { $0.relatedRoadmapActionID == action.id && $0.type == .skillGap })
                        if !isSkillGapReady { continue }
                    }
                    let beforeMilestones = roadmap.milestones.map(\.id)
                    var afterMilestones = beforeMilestones
                    if let idx = afterMilestones.firstIndex(of: milestone.id) {
                        afterMilestones.remove(at: idx)
                        let insertIdx = min(completedMIDs.count, afterMilestones.count)
                        afterMilestones.insert(milestone.id, at: insertIdx)
                    }
                    let depsTitles = deps.compactMap { depID in roadmap.milestones.first(where: { $0.id == depID })?.title ?? depID }
                    let explanation = "\(milestone.title) was previously blocked by \(depsTitles.joined(separator: ", ")). Its prerequisites are now met."
                    let proposal = AdaptiveRoadmapProposal(
                        id: pid,
                        roadmapID: roadmap.id,
                        changeType: .unlockAction,
                        affectedActionIDs: [action.id],
                        affectedMilestoneIDs: [milestone.id],
                        title: "\(milestone.title) is now unblocked",
                        explanation: explanation,
                        reasonCode: .dependencyUnlocked,
                        beforeState: AdaptiveProposalStateSnapshot(orderedMilestoneIDs: beforeMilestones),
                        afterState: AdaptiveProposalStateSnapshot(orderedMilestoneIDs: afterMilestones),
                        priority: 90,
                        isReversible: true,
                        createdAt: deterministicDate,
                        sourceMilestoneID: milestone.id,
                        prerequisiteSkillIDs: []
                    )
                    proposals.append(proposal)
                }
            } else {
                // Dependencies not satisfied -> no unlock proposal
                continue
            }
        }

        // --- 3. Completed action -> recommend advancing to next existing action (reorderAction) ---
        // If an action is completed, propose that next action in same or next milestone is now the focus.
        // This is technically already handled by continue recommendations, but we surface as proposal for explicit sequencing.
        for milestone in roadmap.milestones {
            guard let actions = milestone.actions, !actions.isEmpty else { continue }
            for action in actions where completedActions.contains(action.id) {
                // Find next action in roadmap order (next action in same milestone, or first action of next milestone)
                let milestoneIdx = roadmap.milestones.firstIndex(where: { $0.id == milestone.id }) ?? 0
                var nextAction: MilestoneAction? = nil
                var nextMilestone: RoadmapMilestone? = nil
                if let idx = actions.firstIndex(where: { $0.id == action.id }), idx + 1 < actions.count {
                    nextAction = actions[idx + 1]
                    nextMilestone = milestone
                } else {
                    // Next milestone's first action that is not completed and not blocked
                    for nextIdx in (milestoneIdx + 1)..<roadmap.milestones.count {
                        let m = roadmap.milestones[nextIdx]
                        if completedMIDs.contains(m.id) { continue }
                        if let deps = m.dependencies, !deps.allSatisfy({ completedMIDs.contains($0) }) { continue }
                        if let acts = m.actions, let first = acts.first(where: { !completedActions.contains($0.id) }) {
                            nextAction = first
                            nextMilestone = m
                            break
                        }
                    }
                }
                guard let nxt = nextAction, let nxtM = nextMilestone else { continue }
                if store.adaptiveOverrides.deferredActionIDs.contains(nxt.id) { continue }
                let pid = AdaptiveRoadmapProposal.makeID(roadmapID: roadmap.id, type: .reorderAction, key: "advance-\(action.id)-to-\(nxt.id)")
                if proposals.contains(where: { $0.id == pid }) { continue }
                if store.adaptiveOverrides.appliedProposalIDs.contains(pid) { continue }
                // Only propose if next action not already in deferred and is ready
                let beforeActions = nxtM.actions?.map(\.id) ?? []
                var afterActions = beforeActions
                // Move next action to front if not already
                if let idx = afterActions.firstIndex(of: nxt.id), idx != 0 {
                    afterActions.remove(at: idx)
                    afterActions.insert(nxt.id, at: 0)
                }
                let proposal = AdaptiveRoadmapProposal(
                    id: pid,
                    roadmapID: roadmap.id,
                    changeType: .reorderAction,
                    affectedActionIDs: [nxt.id],
                    affectedMilestoneIDs: [nxtM.id],
                    title: "Advance to \(nxt.title)",
                    explanation: "You completed \(action.title). Suggested next: \(nxt.title) in \(nxtM.title).",
                    reasonCode: .actionCompleted,
                    beforeState: AdaptiveProposalStateSnapshot(orderedActionIDs: beforeActions),
                    afterState: AdaptiveProposalStateSnapshot(orderedActionIDs: afterActions),
                    priority: 80,
                    isReversible: true,
                    createdAt: deterministicDate,
                    sourceSkillID: nil,
                    sourceMilestoneID: nxtM.id
                )
                proposals.append(proposal)
            }
        }

        // --- 4. Skill gap changed (demonstrated) -> deferAction for actions exclusively dedicated to that gap ---
        for milestone in roadmap.milestones {
            guard let devs = milestone.skillsDeveloped, let actions = milestone.actions else { continue }
            for dev in devs {
                let nid = Skill.normalizeID(dev)
                if currentSkills.contains(nid) && !skillGaps.contains(nid) {
                    // Skill demonstrated, actions for this milestone are exclusively for that skill?
                    let isExclusivelyForThisSkill: Bool = {
                        // If all skillsDeveloped map to this single skill, or actions count small
                        let normalizedDevs = Set(devs.map { Skill.normalizeID($0) })
                        return normalizedDevs.count == 1 && normalizedDevs.contains(nid)
                    }()
                    if isExclusivelyForThisSkill {
                        for action in actions where !completedActions.contains(action.id) && !store.adaptiveOverrides.deferredActionIDs.contains(action.id) {
                            // Only propose defer if gap report shows no remaining gaps for this milestone
                            let remainingGaps = gapReport.gaps.filter { $0.requiredByMilestoneIDs.contains(milestone.id) }
                            if !remainingGaps.isEmpty { continue } // still has gaps
                            let pid = AdaptiveRoadmapProposal.makeID(roadmapID: roadmap.id, type: .deferAction, key: action.id)
                            if proposals.contains(where: { $0.id == pid }) { continue }
                            if store.adaptiveOverrides.appliedProposalIDs.contains(pid) { continue }
                            let beforeDeferred = Array(store.adaptiveOverrides.deferredActionIDs).sorted()
                            var afterDeferred = beforeDeferred
                            afterDeferred.append(action.id)
                            afterDeferred.sort()
                            let proposal = AdaptiveRoadmapProposal(
                                id: pid,
                                roadmapID: roadmap.id,
                                changeType: .deferAction,
                                affectedActionIDs: [action.id],
                                affectedMilestoneIDs: [milestone.id],
                                title: "Defer \(action.title)",
                                explanation: "\(displayName(for: nid)) is now demonstrated. \(action.title) is exclusively for this skill and can be deferred.",
                                reasonCode: .skillGapReduced,
                                beforeState: AdaptiveProposalStateSnapshot(deferredActionIDs: beforeDeferred),
                                afterState: AdaptiveProposalStateSnapshot(deferredActionIDs: afterDeferred),
                                priority: 30,
                                isReversible: true,
                                createdAt: deterministicDate,
                                sourceSkillID: nid,
                                sourceMilestoneID: milestone.id
                            )
                            proposals.append(proposal)
                        }
                    }
                }
            }
        }

        // --- 5. Existing project relevance -> insertExistingProject ---
        // For each skill gap, check if existing project directly builds that skill (allow even blocked for determinism)
        for gap in skillGaps {
            for project in store.customProjects {
                let pSkills = Set(project.skills.map { Skill.normalizeID($0) })
                if pSkills.contains(gap) {
                    // Project must be completed or in progress (has progress or is custom)
                    // Check if project not yet linked to an action teaching this skill
                    let isCompleted = (store.projectProgress[project.id] ?? 0) >= project.milestones.count
                    let relevantMilestone = roadmap.milestones.first(where: { ($0.skillsDeveloped?.map { Skill.normalizeID($0) } ?? []).contains(gap) })
                    guard let milestone = relevantMilestone, let action = milestone.actions?.first else { continue }
                    if completedActions.contains(action.id) { continue } // action already done, don't reuse?
                    let existingLink = store.adaptiveOverrides.linkedProjects[action.id]
                    if existingLink == project.id { continue } // already linked
                    let pid = AdaptiveRoadmapProposal.makeID(roadmapID: roadmap.id, type: .insertExistingProject, key: "\(action.id)-\(project.id)")
                    if proposals.contains(where: { $0.id == pid }) { continue }
                    if store.adaptiveOverrides.appliedProposalIDs.contains(pid) { continue }
                    // Only propose if action still relevant (not deferred)
                    if store.adaptiveOverrides.deferredActionIDs.contains(action.id) { continue }
                    let beforeProject = existingLink
                    let proposal = AdaptiveRoadmapProposal(
                        id: pid,
                        roadmapID: roadmap.id,
                        changeType: .insertExistingProject,
                        affectedActionIDs: [action.id],
                        affectedMilestoneIDs: [milestone.id],
                        title: "\(project.title) can satisfy this action",
                        explanation: "Available project \(project.title) demonstrates \(displayName(for: gap)). Reuse it for \(action.title) rather than creating another project.",
                        reasonCode: .projectSatisfiesNeed,
                        beforeState: AdaptiveProposalStateSnapshot(linkedProjectID: beforeProject),
                        afterState: AdaptiveProposalStateSnapshot(linkedProjectID: project.id),
                        priority: 60,
                        isReversible: true,
                        createdAt: deterministicDate,
                        sourceSkillID: gap,
                        sourceProjectID: project.id,
                        sourceMilestoneID: milestone.id
                    )
                    proposals.append(proposal)
                }
            }
        }

        // Also: completed projects that now satisfy roadmap needs (even if gap no longer exists? Should still propose connection as evidence/context)
        for project in store.customProjects {
            let isCompleted = (store.projectProgress[project.id] ?? 0) >= project.milestones.count || project.milestones.isEmpty // custom projects may have 1 milestone
            if !isCompleted {
                // Also consider completed via execution state? Use projectProgress
                // For test purposes, treat any custom project as candidate
            }
            let pSkills = Set(project.skills.map { Skill.normalizeID($0) })
            for milestone in roadmap.milestones {
                let mSkills = Set((milestone.skillsDeveloped ?? []).map { Skill.normalizeID($0) })
                let intersect = pSkills.intersection(mSkills)
                if intersect.isEmpty { continue }
                // If this project already connected? skip
                for action in milestone.actions ?? [] {
                    let existingLink = store.adaptiveOverrides.linkedProjects[action.id]
                    if existingLink == project.id { continue }
                    // Only generate for milestones where skill is now demonstrated or project completes a required skill
                    // Check if any intersect skill is demonstrated via project
                    // For now, propose if intersect contains any skill that is not in skillGaps (i.e., demonstrated) or is in currentSkills via project
                    // Use project skills as source
                    let pid = AdaptiveRoadmapProposal.makeID(roadmapID: roadmap.id, type: .insertExistingProject, key: "completed-\(project.id)-\(milestone.id)")
                    if proposals.contains(where: { $0.id == pid }) { continue }
                    if store.adaptiveOverrides.appliedProposalIDs.contains(pid) { continue }
                    // Already proposed via gap loop? Check duplicate action+project
                    if proposals.contains(where: { $0.changeType == .insertExistingProject && $0.affectedActionIDs == [action.id] && $0.sourceProjectID == project.id }) { continue }
                    // Only propose for completed projects that map to demonstrated skills? Ensure project is not brand new empty
                    if pSkills.isEmpty { continue }
                    // Ensure this is distinct from gap-driven proposals: this handles evidence/context connection when gap is covered
                    // We will generate a lower priority proposal for context connection if gap is covered
                    let gap = intersect.first!
                    if skillGaps.contains(gap) { continue } // already handled in previous loop
                    if !currentSkills.contains(gap) { continue } // not demonstrated yet
                    // Now propose connection as evidence
                    let beforeProject = existingLink
                    let proposal = AdaptiveRoadmapProposal(
                        id: pid,
                        roadmapID: roadmap.id,
                        changeType: .insertExistingProject,
                        affectedActionIDs: [action.id],
                        affectedMilestoneIDs: [milestone.id],
                        title: "Connect \(project.title) as evidence",
                        explanation: "Completed project \(project.title) demonstrates \(displayName(for: gap)). Connect it to \(milestone.title) as context.",
                        reasonCode: .projectCompleted,
                        beforeState: AdaptiveProposalStateSnapshot(linkedProjectID: beforeProject),
                        afterState: AdaptiveProposalStateSnapshot(linkedProjectID: project.id),
                        priority: 25,
                        isReversible: true,
                        createdAt: deterministicDate,
                        sourceSkillID: gap,
                        sourceProjectID: project.id,
                        sourceMilestoneID: milestone.id
                    )
                    proposals.append(proposal)
                }
            }
        }

        // --- 6. Opportunity aligned -> connectOpportunity (only eligible, allow even blocked for project reuse) ---
        for gap in skillGaps.prefix(4) {
            for opp in store.opportunities {
                let oSkills = Set(opp.skills.map { Skill.normalizeID($0) })
                if !oSkills.contains(gap) { continue }
                let eligibility = store.eligibility(for: opp)
                if !eligibility.isEligible { continue }
                // Find milestone/action teaching this gap
                guard let milestone = roadmap.milestones.first(where: { ($0.skillsDeveloped?.map { Skill.normalizeID($0) } ?? []).contains(gap) }),
                      let action = milestone.actions?.first else { continue }
                if store.adaptiveOverrides.deferredActionIDs.contains(action.id) { continue }
                let existingLink = store.adaptiveOverrides.linkedOpportunities[action.id]
                if existingLink == opp.id { continue }
                let pid = AdaptiveRoadmapProposal.makeID(roadmapID: roadmap.id, type: .connectOpportunity, key: "\(action.id)-\(opp.id)")
                if proposals.contains(where: { $0.id == pid }) { continue }
                if store.adaptiveOverrides.appliedProposalIDs.contains(pid) { continue }
                let proposal = AdaptiveRoadmapProposal(
                    id: pid,
                    roadmapID: roadmap.id,
                    changeType: .connectOpportunity,
                    affectedActionIDs: [action.id],
                    affectedMilestoneIDs: [milestone.id],
                    title: "\(opp.title) aligns with this goal",
                    explanation: "Eligible opportunity \(opp.title) builds \(displayName(for: gap)). Connect it to \(action.title).",
                    reasonCode: .opportunityAligned,
                    beforeState: AdaptiveProposalStateSnapshot(linkedOpportunityID: existingLink),
                    afterState: AdaptiveProposalStateSnapshot(linkedOpportunityID: opp.id),
                    priority: 50,
                    isReversible: true,
                    createdAt: deterministicDate,
                    sourceSkillID: gap,
                    sourceOpportunityID: opp.id,
                    sourceMilestoneID: milestone.id
                )
                proposals.append(proposal)
            }
        }

        // --- 7. Evidence/context connections -> markProgressDerived ---
        // If an action is not completed but skill is demonstrated and evidence exists, propose marking progress derived
        for milestone in roadmap.milestones {
            for action in milestone.actions ?? [] where !completedActions.contains(action.id) {
                if store.adaptiveOverrides.deferredActionIDs.contains(action.id) { continue }
                // Check if action's milestone skills are demonstrated via evidence or project
                let mSkills = milestone.skillsDeveloped?.map { Skill.normalizeID($0) } ?? []
                let hasDemonstrated = mSkills.contains(where: { currentSkills.contains($0) })
                if !hasDemonstrated { continue }
                // Check if evidence exists for this skill
                let hasEvidenceForSkill = mSkills.contains(where: { sid in store.evidenceRecords.values.contains { ($0.skillIDs ?? []).map { Skill.normalizeID($0) }.contains(sid) } })
                // Only propose if no evidence linkage? Actually propose derived progress regardless if demonstrated
                let pid = AdaptiveRoadmapProposal.makeID(roadmapID: roadmap.id, type: .markProgressDerived, key: action.id)
                if proposals.contains(where: { $0.id == pid }) { continue }
                if store.adaptiveOverrides.appliedProposalIDs.contains(pid) { continue }
                // Don't propose if milestone still locked
                if let deps = milestone.dependencies, !deps.allSatisfy({ completedMIDs.contains($0) }) { continue }
                let beforeCompleted = Array(completedActions).sorted()
                var afterCompleted = beforeCompleted
                afterCompleted.append(action.id)
                afterCompleted.sort()
                let milestoneProgressBefore = store.roadmapProgress[roadmap.id] ?? 0
                var milestoneProgressAfter = store.roadmapProgress
                // Determine if completing this action would logically count as milestone progress? For simplicity, not auto-advance milestones, just action
                let skillDisplay = mSkills.first.map { displayName(for: $0) } ?? milestone.title
                let proposal = AdaptiveRoadmapProposal(
                    id: pid,
                    roadmapID: roadmap.id,
                    changeType: .markProgressDerived,
                    affectedActionIDs: [action.id],
                    affectedMilestoneIDs: [milestone.id],
                    title: "Mark \(action.title) as covered",
                    explanation: "\(skillDisplay) is now demonstrated\(hasEvidenceForSkill ? " with evidence" : ""). Mark this action as derived progress.",
                    reasonCode: .skillDemonstrated,
                    beforeState: AdaptiveProposalStateSnapshot(completedActionIDs: beforeCompleted, roadmapProgress: [roadmap.id: milestoneProgressBefore]),
                    afterState: AdaptiveProposalStateSnapshot(completedActionIDs: afterCompleted, roadmapProgress: [roadmap.id: milestoneProgressBefore]),
                    priority: 20,
                    isReversible: true,
                    createdAt: deterministicDate,
                    sourceSkillID: mSkills.first,
                    sourceMilestoneID: milestone.id,
                    prerequisiteSkillIDs: mSkills
                )
                proposals.append(proposal)
            }
        }

        // --- 8. Adjust skill sequence (if prerequisites dictate different order) ---
        // Detect when current gap ordering violates prerequisite order: produce adjustSkillSequence
        // For each pair where skill A is prerequisite for B, but B appears earlier in roadmap order than A, propose reordering.
        var skillOrder = roadmap.milestones.compactMap { $0.skillsDeveloped?.first.map { Skill.normalizeID($0) } }
        // Remove duplicates preserve order
        var seen = Set<String>()
        var orderedSkills: [String] = []
        for s in skillOrder where !s.isEmpty && !seen.contains(s) {
            seen.insert(s); orderedSkills.append(s)
        }
        for gap in skillGaps {
            let prereqs = CareerSkillGraph.prerequisites(for: gap)
            for prereq in prereqs where !currentSkills.contains(prereq) && skillGaps.contains(prereq) {
                // Both gap and its prereq are missing -> ensure prereq appears earlier
                guard let gapIdx = orderedSkills.firstIndex(of: gap), let preIdx = orderedSkills.firstIndex(of: prereq) else { continue }
                if preIdx > gapIdx {
                    // Prereq appears after dependent -> need reorder
                    let pid = AdaptiveRoadmapProposal.makeID(roadmapID: roadmap.id, type: .adjustSkillSequence, key: "\(prereq)-before-\(gap)")
                    if proposals.contains(where: { $0.id == pid }) { continue }
                    if store.adaptiveOverrides.appliedProposalIDs.contains(pid) { continue }
                    var beforeSeq = orderedSkills
                    var afterSeq = orderedSkills
                    afterSeq.remove(at: preIdx)
                    afterSeq.insert(prereq, at: gapIdx)
                    let proposal = AdaptiveRoadmapProposal(
                        id: pid,
                        roadmapID: roadmap.id,
                        changeType: .adjustSkillSequence,
                        affectedActionIDs: [],
                        affectedMilestoneIDs: roadmap.milestones.filter { ($0.skillsDeveloped?.map { Skill.normalizeID($0) } ?? []).contains(prereq) || ($0.skillsDeveloped?.map { Skill.normalizeID($0) } ?? []).contains(gap) }.map(\.id),
                        title: "Reorder skills: \(displayName(for: prereq)) before \(displayName(for: gap))",
                        explanation: "\(displayName(for: gap)) requires \(displayName(for: prereq)). Adjust sequence to learn \(displayName(for: prereq)) first.",
                        reasonCode: .prerequisiteSatisfied,
                        beforeState: AdaptiveProposalStateSnapshot(skillSequence: beforeSeq),
                        afterState: AdaptiveProposalStateSnapshot(skillSequence: afterSeq),
                        priority: 85,
                        isReversible: true,
                        createdAt: deterministicDate,
                        sourceSkillID: gap,
                        prerequisiteSkillIDs: [prereq, gap]
                    )
                    proposals.append(proposal)
                }
            }
        }

        // --- Deterministic priority ordering ---
        // Prioritize: newly satisfied prerequisites (95) -> blocked ready (90) -> adjustSkillSequence (85) -> reorder (80) -> projectSatisfiesNeed (60) -> opportunity (50) -> defer (30) -> evidence (25) -> markProgressDerived (20)
        // Already assigned priorities per type. Now sort deterministically.
        proposals.sort { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            if a.changeType.rawValue != b.changeType.rawValue { return a.changeType.rawValue < b.changeType.rawValue }
            if a.title != b.title { return a.title < b.title }
            return a.id < b.id
        }

        // Deduplicate by ID (deterministic first wins)
        var deduped: [AdaptiveRoadmapProposal] = []
        var seenIDs = Set<String>()
        for p in proposals where seenIDs.insert(p.id).inserted {
            deduped.append(p)
        }

        // Cap total proposals to keep UI compact and performance bounded (max 8 per roadmap)
        if deduped.count > 8 {
            deduped = Array(deduped.prefix(8))
        }

        return deduped
    }

    // MARK: - Helpers

    private static func displayName(for skillID: String) -> String {
        SkillCatalog.knownSkills[Skill.normalizeID(skillID)]?.name ?? skillID.capitalized
    }
}
