import Foundation

// MARK: - Pure Deterministic Skill-Gap Engine

/// Pure, deterministic engine for calculating required skills, demonstrated skills,
/// and skill gaps for any roadmap in the Student OPS catalog.
///
/// Contains NO AI, NO network calls, NO database queries, and NO hardcoded career branches.
/// All logic is explainable, reproducible, and derived directly from structured roadmap
/// and student state.
enum SkillGapEngine {

    // MARK: - Skill ID Normalization

    /// Normalizes any raw skill string into a canonical identifier.
    static func normalizeSkillID(_ raw: String) -> String {
        Skill.normalizeID(raw)
    }

    // MARK: - Required Skills Derivation

    /// Extracts all required skills declared in a roadmap's structured milestones (`skillsDeveloped`).
    /// Deduplicates by canonical skill ID while preserving the order of appearance.
    ///
    /// Career-agnostic: extracts skills directly from the roadmap's milestone definitions.
    static func requiredSkills(for roadmap: Roadmap) -> [Skill] {
        var seenIDs = Set<String>()
        var result: [Skill] = []

        for milestone in roadmap.milestones {
            guard let skills = milestone.skillsDeveloped else { continue }
            for raw in skills {
                let norm = normalizeSkillID(raw)
                guard !norm.isEmpty else { continue }
                if !seenIDs.contains(norm) {
                    seenIDs.insert(norm)
                    result.append(Skill.canonical(from: raw))
                }
            }
        }

        return result
    }

    // MARK: - Student Demonstrated Skills

    /// Extracts the complete set of canonical skill IDs demonstrated by the student.
    ///
    /// Accounts for:
    /// 1. Profile strengths (`profile.strengths`)
    /// 2. Profile custom skills (`profile.customSkills`)
    /// 3. Skills acquired from completed roadmap milestones (`roadmap.milestones[0..<completedCount].skillsDeveloped`)
    /// 4. Skills linked through legitimate evidence records
    ///
    /// Rules:
    /// - Uncompleted milestones do NOT count as demonstrated.
    /// - Locked or future milestones do NOT count as demonstrated.
    /// - Non-roadmap skills (e.g. from onboarding or other paths) are fully preserved.
    static func demonstratedSkillIDs(
        profile: StudentProfile,
        roadmapProgress: [String: Int] = [:],
        catalog: [Roadmap]? = nil,
        evidenceRecords: [String: EvidenceRecord]? = nil
    ) -> Set<String> {
        var result = Set<String>()

        // 1. Profile strengths (contains onboarding strengths + acquired roadmap skills)
        for raw in profile.strengths {
            let norm = normalizeSkillID(raw)
            if !norm.isEmpty { result.insert(norm) }
        }

        // 2. Profile custom skills (contains onboarding custom skills + completed project skills)
        for raw in profile.customSkills {
            let norm = normalizeSkillID(raw)
            if !norm.isEmpty { result.insert(norm) }
        }

        // 3. Completed roadmap milestones from catalog
        if let catalog = catalog {
            for roadmap in catalog {
                let completedCount = min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
                guard completedCount > 0 else { continue }
                for idx in 0..<completedCount {
                    let milestone = roadmap.milestones[idx]
                    if let skills = milestone.skillsDeveloped {
                        for raw in skills {
                            let norm = normalizeSkillID(raw)
                            if !norm.isEmpty { result.insert(norm) }
                        }
                    }
                }
            }
        }

        // 4. Skills linked through evidence records
        if let evidence = evidenceRecords, let catalog = catalog {
            let catalogMap = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
            for record in evidence.values {
                if let roadmap = catalogMap[record.roadmapID],
                   let milestone = roadmap.milestones.first(where: { $0.id == record.milestoneID }),
                   let skills = milestone.skillsDeveloped {
                    for raw in skills {
                        let norm = normalizeSkillID(raw)
                        if !norm.isEmpty { result.insert(norm) }
                    }
                }
            }
        }

        return result
    }

    // MARK: - Core Evaluation

    /// Evaluates a roadmap against a student's profile and progress to produce a deterministic
    /// `RoadmapSkillGapReport`.
    ///
    /// Calculation:
    /// ```text
    /// requiredSkills(roadmap)
    ///         ↓
    /// studentDemonstratedSkills(profile + completed milestones)
    ///         ↓
    /// canonicalize
    ///         ↓
    /// set difference (required - demonstrated)
    ///         ↓
    /// map to developing milestones & actions
    ///         ↓
    /// calculate deterministic priority
    ///         ↓
    /// stable sort
    /// ```
    static func evaluate(
        roadmap: Roadmap,
        profile: StudentProfile,
        progress: [String: Int] = [:],
        catalog: [Roadmap]? = nil,
        evidenceRecords: [String: EvidenceRecord]? = nil
    ) -> RoadmapSkillGapReport {
        let allRequired = requiredSkills(for: roadmap)
        let demonstratedIDs = demonstratedSkillIDs(
            profile: profile,
            roadmapProgress: progress,
            catalog: catalog ?? [roadmap],
            evidenceRecords: evidenceRecords
        )

        var demonstrated: [Skill] = []
        var missingSkills: [Skill] = []

        for skill in allRequired {
            if demonstratedIDs.contains(skill.id) {
                demonstrated.append(skill)
            } else {
                missingSkills.append(skill)
            }
        }

        let completedCount = min(progress[roadmap.id] ?? 0, roadmap.milestones.count)
        let currentMilestoneIndex = completedCount // 0-based index of next milestone to do

        // Precompute dependency graph for priority scoring:
        // Map of prerequisiteMilestoneID -> count of milestones that depend on it
        var dependentCounts: [String: Int] = [:]
        for milestone in roadmap.milestones {
            for dep in milestone.dependencies ?? [] {
                dependentCounts[dep, default: 0] += 1
            }
        }

        var gaps: [SkillGap] = []

        for skill in missingSkills {
            // Find all milestones in this roadmap developing this skill
            var matchingMilestones: [RoadmapMilestone] = []
            var milestoneRefs: [MilestoneReference] = []

            for (idx, milestone) in roadmap.milestones.enumerated() {
                guard let dev = milestone.skillsDeveloped else { continue }
                let normalizedDev = dev.map(normalizeSkillID)
                if normalizedDev.contains(skill.id) {
                    matchingMilestones.append(milestone)
                    milestoneRefs.append(
                        MilestoneReference(
                            id: milestone.id,
                            milestoneNumber: idx + 1,
                            title: milestone.title
                        )
                    )
                }
            }

            let requiredByIDs = matchingMilestones.map(\.id)
            let relatedActions = matchingMilestones.flatMap { $0.actions ?? [] }

            // Priority Scoring
            let priorityInfo = calculatePriority(
                matchingMilestoneIDs: requiredByIDs,
                developingMilestones: milestoneRefs,
                actions: relatedActions,
                totalMilestones: roadmap.milestones.count,
                currentMilestoneIndex: currentMilestoneIndex,
                dependentCounts: dependentCounts,
                roadmap: roadmap
            )

            // Status: if developed in the immediate next milestone, mark as .developing
            let isCurrentMilestone = milestoneRefs.contains { $0.milestoneNumber - 1 == currentMilestoneIndex }
            let status: SkillStatus = isCurrentMilestone ? .developing : .gap

            // Reason explanation
            let reason: String
            if milestoneRefs.count == 1 {
                reason = "Develops in Milestone \(milestoneRefs[0].milestoneNumber): \(milestoneRefs[0].title)"
            } else if milestoneRefs.count > 1 {
                let numbers = milestoneRefs.map { "Milestone \($0.milestoneNumber)" }.joined(separator: ", ")
                reason = "Develops in \(numbers)"
            } else {
                reason = "Required by \(roadmap.title)"
            }

            gaps.append(
                SkillGap(
                    skill: skill,
                    status: status,
                    sourceRoadmapID: roadmap.id,
                    requiredByMilestoneIDs: requiredByIDs,
                    developingMilestones: milestoneRefs,
                    relatedActions: relatedActions,
                    priority: priorityInfo.priority,
                    priorityScore: priorityInfo.score,
                    reason: reason
                )
            )
        }

        // Stable deterministic sort:
        // 1. Priority score descending
        // 2. Earliest milestone number ascending
        // 3. Skill name alphabetically
        gaps.sort { lhs, rhs in
            if lhs.priorityScore != rhs.priorityScore {
                return lhs.priorityScore > rhs.priorityScore
            }
            let lhsEarliest = lhs.developingMilestones.first?.milestoneNumber ?? Int.max
            let rhsEarliest = rhs.developingMilestones.first?.milestoneNumber ?? Int.max
            if lhsEarliest != rhsEarliest {
                return lhsEarliest < rhsEarliest
            }
            return lhs.skillName.localizedCompare(rhs.skillName) == .orderedAscending
        }

        return RoadmapSkillGapReport(
            roadmapID: roadmap.id,
            roadmapTitle: roadmap.title,
            requiredSkills: allRequired,
            demonstratedSkills: demonstrated,
            gaps: gaps
        )
    }

    // MARK: - Priority Scoring

    /// Computes deterministic priority tier and numeric score for a skill gap.
    ///
    /// Formula:
    /// `priorityScore = earlinessScore + dependencyScore + frequencyScore + actionScore + activeMilestoneBonus`
    ///
    /// Signals:
    /// - **Earliness**: Skills in earlier milestones are needed sooner (`(totalMilestones - earliestIndex) * 10`).
    /// - **Dependencies**: Milestones that block other milestones give high priority (`dependentCount * 15`).
    /// - **Frequency**: Skills needed by multiple milestones are reinforced (`milestoneCount * 10`).
    /// - **Actions**: Skills backed by structured actions (`min(actionCount * 2, 10)`).
    /// - **Active Milestone**: Skills in the current milestone gain an immediate focus boost (`+15`).
    ///
    /// Tiers:
    /// - `score >= 60`: `.high`
    /// - `score >= 35`: `.medium`
    /// - `score < 35`: `.low`
    private static func calculatePriority(
        matchingMilestoneIDs: [String],
        developingMilestones: [MilestoneReference],
        actions: [MilestoneAction],
        totalMilestones: Int,
        currentMilestoneIndex: Int,
        dependentCounts: [String: Int],
        roadmap: Roadmap
    ) -> (priority: SkillGapPriority, score: Int) {
        let earliestMilestoneIndex = developingMilestones.first.map { $0.milestoneNumber - 1 } ?? 0

        // 1. Earliness score
        let earlinessScore = max(0, (totalMilestones - earliestMilestoneIndex) * 10)

        // 2. Dependency score (how many other milestones depend on milestones developing this skill)
        let totalDependents = matchingMilestoneIDs.reduce(0) { $0 + (dependentCounts[$1] ?? 0) }
        let dependencyScore = totalDependents * 15

        // 3. Frequency score (number of milestones developing this skill)
        let frequencyScore = matchingMilestoneIDs.count * 10

        // 4. Action score
        let actionScore = min(actions.count * 2, 10)

        // 5. Active milestone bonus (is this skill developed in the immediate next milestone?)
        let isCurrentMilestone = developingMilestones.contains { $0.milestoneNumber - 1 == currentMilestoneIndex }
        let activeMilestoneBonus = isCurrentMilestone ? 15 : 0

        let totalScore = earlinessScore + dependencyScore + frequencyScore + actionScore + activeMilestoneBonus

        let priority: SkillGapPriority
        if totalScore >= 60 {
            priority = .high
        } else if totalScore >= 35 {
            priority = .medium
        } else {
            priority = .low
        }

        return (priority, totalScore)
    }

    // MARK: - AppDataStore Convenience Helpers

    /// Evaluates skill gaps for a roadmap using live `AppDataStore` state.
    @MainActor
    static func evaluate(roadmap: Roadmap, store: AppDataStore) -> RoadmapSkillGapReport {
        let catalog = store.scoredRoadmaps.map(\.roadmap)
        return evaluate(
            roadmap: roadmap,
            profile: store.profile,
            progress: store.roadmapProgress,
            catalog: catalog,
            evidenceRecords: store.evidenceRecords
        )
    }

    /// Evaluates skill gaps for all currently active roadmaps independently.
    @MainActor
    static func evaluateActiveRoadmaps(store: AppDataStore) -> [RoadmapSkillGapReport] {
        store.activatedRoadmaps.map { scored in
            evaluate(roadmap: scored.roadmap, store: store)
        }
    }

    /// Returns all skill gaps developed by a specific milestone in a roadmap.
    @MainActor
    static func milestoneDevelopedGaps(
        milestone: RoadmapMilestone,
        roadmap: Roadmap,
        store: AppDataStore
    ) -> [SkillGap] {
        let report = evaluate(roadmap: roadmap, store: store)
        return report.gaps.filter { gap in
            gap.requiredByMilestoneIDs.contains(milestone.id)
        }
    }

    /// Returns the number of skill gaps developed by a specific milestone in a roadmap.
    @MainActor
    static func milestoneGapCount(
        milestone: RoadmapMilestone,
        roadmap: Roadmap,
        store: AppDataStore
    ) -> Int {
        milestoneDevelopedGaps(milestone: milestone, roadmap: roadmap, store: store).count
    }
}

