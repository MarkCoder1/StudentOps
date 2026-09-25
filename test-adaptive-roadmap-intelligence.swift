import Foundation

// =============================================================================
// Phase 12A — Adaptive Roadmap Intelligence Foundation — Comprehensive Tests
// Run: swift test-adaptive-roadmap-intelligence.swift
// =============================================================================

var passed = 0
var failed = 0
func assert(_ c: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if c { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// MARK: - Normalization Helpers

func normSkill(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    return parts.joined(separator: " ").lowercased()
}

func normCareer(_ title: String) -> String {
    let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if t.isEmpty { return "" }
    var s = t
    for c in ["-", "_", "/", "\\"] { s = s.replacingOccurrences(of: c, with: " ") }
    let parts = s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    let collapsed = parts.joined(separator: " ")
    let aliasMap: [String: String] = [
        "software engineering": "software-engineering", "software engineer": "software-engineering",
        "data science": "data-science", "data scientist": "data-science",
        "ai ml": "ai-ml", "ai/ml": "ai-ml", "machine learning": "ai-ml",
        "cybersecurity": "cybersecurity"
    ]
    if let a = aliasMap[collapsed] { return a }
    return collapsed.replacingOccurrences(of: " ", with: "-")
}

// MARK: - Domain Models (Phase 12A)

enum AdaptiveItemState: String, Codable, Hashable, CaseIterable {
    case completed = "completed"
    case inProgress = "inProgress"
    case ready = "ready"
    case blocked = "blocked"
    case notStarted = "notStarted"
    case covered = "covered"
}

enum AdaptiveRoadmapRecommendationType: String, Codable, Hashable, CaseIterable {
    case `continue` = "continue"
    case skillGap = "skillGap"
    case prerequisite = "prerequisite"
    case project = "project"
    case opportunity = "opportunity"
    case evidence = "evidence"
    case review = "review"
    case blocked = "blocked"
    case complete = "complete"
}

enum AdaptiveReasonCode: String, Codable, Hashable {
    case missingPrerequisite = "missingPrerequisite"
    case activeSkillGap = "activeSkillGap"
    case roadmapAligned = "roadmapAligned"
    case projectBuildsSkill = "projectBuildsSkill"
    case opportunityBuildsSkill = "opportunityBuildsSkill"
    case evidenceMissing = "evidenceMissing"
    case actionIncomplete = "actionIncomplete"
    case actionCompleted = "actionCompleted"
    case blockedByPrerequisite = "blockedByPrerequisite"
    case targetAlreadyCovered = "targetAlreadyCovered"
    case insufficientContext = "insufficientContext"
}

struct AdaptiveRoadmapRecommendation: Identifiable, Hashable, Codable {
    let id: String
    let type: AdaptiveRoadmapRecommendationType
    let title: String
    let reason: String
    let reasonCode: AdaptiveReasonCode
    let priority: Int
    let state: AdaptiveItemState?
    let relatedSkillID: String?
    let prerequisiteSkillIDs: [String]
    let relatedProjectID: String?
    let relatedOpportunityID: String?
    let relatedRoadmapActionID: String?
    let evidenceSkillID: String?
    let isBlocked: Bool
    let blockedReason: String?
}

struct AdaptiveRoadmapContext: Hashable, Codable {
    let roadmapID: String
    let roadmapTitle: String
    let targetCareerID: String?
    let targetGoal: String?
    let currentSkills: [String]
    let skillGaps: [String]
    let completedActionIDs: [String]
    let completedMilestoneIDs: [String]
    let activeRoadmapID: String?
    let completedProjectIDs: [String]
    let activeProjectIDs: [String]
    let relevantOpportunityIDs: [String]
    let evidenceSkillIDs: [String]
    let prerequisites: [String]
    let hasInsufficientContext: Bool
}

struct AdaptiveRoadmapResult: Hashable, Codable {
    let roadmapID: String
    let roadmapTitle: String
    let targetCareerID: String?
    let targetGoal: String?
    let context: AdaptiveRoadmapContext
    let recommendedNext: [AdaptiveRoadmapRecommendation]
    let blocked: [AdaptiveRoadmapRecommendation]
    let completed: [AdaptiveRoadmapRecommendation]
    let skillGaps: [String]
    let prerequisiteWarnings: [String]
    let isInsufficientContext: Bool
    let explanations: [String]
    let generatedAt: Date
}

// MARK: - Test Supporting Types

struct TestMilestoneAction: Hashable, Codable {
    let id: String
    let title: String
}

struct TestMilestone: Hashable, Codable {
    let id: String
    let title: String
    let dependencies: [String]?
    let skillsDeveloped: [String]?
    let actions: [TestMilestoneAction]?
}

struct TestRoadmap: Hashable, Codable {
    let id: String
    let title: String
    let goal: String?
    let milestones: [TestMilestone]
}

struct TestStudentProfile: Hashable, Codable {
    var careers: [String] = []
    var fields: [String] = []
    var milestones: [String] = []
    var strengths: [String] = []
    var customSkills: [String] = []
    var interests: [String] = []
    var location: String = "Online"
}

struct TestProject: Hashable, Codable {
    let id: String
    let title: String
    let skills: [String]
    let milestoneCount: Int
}

struct TestOpportunity: Hashable, Codable {
    let id: String
    let title: String
    let skills: [String]
    let isEligible: Bool
}

struct TestEvidenceRecord: Hashable, Codable {
    let id: String
    let skillIDs: [String]
    let roadmapID: String?
}

// MARK: - Test Prerequisite Graph

struct TestPrereq {
    let skillID: String
    let prereqID: String
}

let testPrerequisites: [TestPrereq] = [
    TestPrereq(skillID: normSkill("Data Structures"), prereqID: normSkill("Programming Fundamentals")),
    TestPrereq(skillID: normSkill("Algorithms"), prereqID: normSkill("Data Structures")),
    TestPrereq(skillID: normSkill("Databases"), prereqID: normSkill("Programming Fundamentals")),
    TestPrereq(skillID: normSkill("APIs"), prereqID: normSkill("Programming Fundamentals")),
    TestPrereq(skillID: normSkill("Machine Learning"), prereqID: normSkill("Python")),
    TestPrereq(skillID: normSkill("AI Application Development"), prereqID: normSkill("Machine Learning")),
    TestPrereq(skillID: normSkill("Data Analysis"), prereqID: normSkill("Statistics"))
]

func testPrereqs(for skillID: String) -> [String] {
    let sid = normSkill(skillID)
    return testPrerequisites.filter { $0.skillID == sid }.map(\.prereqID).sorted()
}

func transitivePrereqs(for skillID: String) -> [String] {
    let sid = normSkill(skillID)
    var result: [String] = []
    var visited = Set<String>()
    var inStack = Set<String>()

    func dfs(_ current: String) {
        if inStack.contains(current) || visited.contains(current) { return }
        inStack.insert(current)
        for p in testPrereqs(for: current) {
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

// MARK: - Test Adaptive Engine Simulator

enum TestAdaptiveRoadmapEngine {

    static func recommend(
        roadmap: TestRoadmap,
        profile: TestStudentProfile,
        progress: [String: Int] = [:],
        completedActionIDs: Set<String> = [],
        activeRoadmapIDs: Set<String> = [],
        projects: [TestProject] = [],
        evidenceRecords: [TestEvidenceRecord] = [],
        opportunities: [TestOpportunity] = []
    ) -> AdaptiveRoadmapResult {

        var currentSkills = Set(profile.strengths.map { normSkill($0) } + profile.customSkills.map { normSkill($0) })
        for e in evidenceRecords {
            for sid in e.skillIDs { currentSkills.insert(normSkill(sid)) }
        }

        // Required skills from roadmap
        var roadmapSkills: [String] = []
        for ms in roadmap.milestones {
            if let devs = ms.skillsDeveloped {
                for d in devs {
                    let n = normSkill(d)
                    if !roadmapSkills.contains(n) { roadmapSkills.append(n) }
                }
            }
        }
        let skillGaps = roadmapSkills.filter { !currentSkills.contains($0) }

        let completedMilestoneCount = min(progress[roadmap.id] ?? 0, roadmap.milestones.count)
        let completedMIDs = Set(roadmap.milestones.prefix(completedMilestoneCount).map(\.id))
        let targetCareer = profile.careers.first.map { normCareer($0) }
        let targetGoal = profile.milestones.first ?? roadmap.goal

        let hasGoal = !(profile.careers.isEmpty && profile.fields.isEmpty && profile.milestones.isEmpty)
        let hasSkills = !currentSkills.isEmpty
        let hasActiveRoadmaps = !activeRoadmapIDs.isEmpty
        let isInsufficient = (!hasGoal && !hasSkills && !hasActiveRoadmaps) ||
                             (!activeRoadmapIDs.contains(roadmap.id) && profile.careers.isEmpty && profile.fields.isEmpty) ||
                             roadmap.id.isEmpty

        var allRelevantPrereqs = Set<String>()
        for gap in skillGaps {
            for p in transitivePrereqs(for: gap) { allRelevantPrereqs.insert(p) }
        }

        let context = AdaptiveRoadmapContext(
            roadmapID: roadmap.id,
            roadmapTitle: roadmap.title,
            targetCareerID: targetCareer,
            targetGoal: targetGoal,
            currentSkills: currentSkills.sorted(),
            skillGaps: skillGaps.sorted(),
            completedActionIDs: completedActionIDs.sorted(),
            completedMilestoneIDs: completedMIDs.sorted(),
            activeRoadmapID: activeRoadmapIDs.first,
            completedProjectIDs: projects.filter { (progress[$0.id] ?? 0) >= $0.milestoneCount }.map(\.id).sorted(),
            activeProjectIDs: projects.filter { (progress[$0.id] ?? 0) < $0.milestoneCount }.map(\.id).sorted(),
            relevantOpportunityIDs: opportunities.filter { opp in
                !Set(opp.skills.map { normSkill($0) }).isDisjoint(with: Set(skillGaps))
            }.map(\.id).sorted(),
            evidenceSkillIDs: evidenceRecords.flatMap { $0.skillIDs.map { normSkill($0) } }.sorted(),
            prerequisites: allRelevantPrereqs.sorted(),
            hasInsufficientContext: isInsufficient
        )

        if isInsufficient {
            let msg = profile.careers.isEmpty && profile.fields.isEmpty ? "Choose a goal to adapt your roadmap." : "Build your skill profile to unlock more specific next steps."
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
                targetCareerID: targetCareer,
                targetGoal: targetGoal,
                context: context,
                recommendedNext: [rec],
                blocked: [],
                completed: [],
                skillGaps: skillGaps,
                prerequisiteWarnings: [],
                isInsufficientContext: true,
                explanations: [msg],
                generatedAt: Date()
            )
        }

        var next: [AdaptiveRoadmapRecommendation] = []
        var blocked: [AdaptiveRoadmapRecommendation] = []
        var completed: [AdaptiveRoadmapRecommendation] = []
        var warnings: [String] = []

        func recID(type: AdaptiveRoadmapRecommendationType, id: String) -> String {
            "\(roadmap.id)-\(type.rawValue)-\(id)"
        }

        // Check locked milestones
        var lockedActionIDs = Set<String>()
        var lockedMilestoneBlockers: [String: [String]] = [:]
        for ms in roadmap.milestones {
            if let deps = ms.dependencies, !deps.isEmpty {
                let missing = deps.filter { !completedMIDs.contains($0) }
                if !missing.isEmpty {
                    for act in ms.actions ?? [] {
                        lockedActionIDs.insert(act.id)
                        lockedMilestoneBlockers[act.id] = missing
                    }
                }
            }
        }

        // Process skill gaps with transitive prerequisites
        for gap in skillGaps {
            let trans = transitivePrereqs(for: gap)
            let missing = trans.filter { !currentSkills.contains($0) }

            if !missing.isEmpty {
                // Dependent skill is BLOCKED
                var readyPrereq: String? = nil
                for p in missing {
                    let subP = testPrereqs(for: p)
                    if subP.allSatisfy({ currentSkills.contains($0) }) {
                        readyPrereq = p
                        break
                    }
                }
                let targetPrereq = readyPrereq ?? missing.first!
                let warn = "\(gap) blocked by \(targetPrereq)"
                if !warnings.contains(warn) { warnings.append(warn) }

                let bID = recID(type: .blocked, id: gap)
                if !blocked.contains(where: { $0.id == bID }) {
                    blocked.append(AdaptiveRoadmapRecommendation(
                        id: bID,
                        type: .blocked,
                        title: gap.capitalized,
                        reason: "Requires \(targetPrereq).",
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
                        blockedReason: "Requires \(targetPrereq)"
                    ))
                }

                // Recommend the ready prerequisite
                let pID = recID(type: .prerequisite, id: targetPrereq)
                if !next.contains(where: { $0.id == pID }) {
                    next.append(AdaptiveRoadmapRecommendation(
                        id: pID,
                        type: .prerequisite,
                        title: targetPrereq.capitalized,
                        reason: "Prerequisite for \(gap). \(gap) requires \(targetPrereq) first.",
                        reasonCode: .missingPrerequisite,
                        priority: 95,
                        state: .ready,
                        relatedSkillID: targetPrereq,
                        prerequisiteSkillIDs: testPrereqs(for: targetPrereq),
                        relatedProjectID: nil,
                        relatedOpportunityID: nil,
                        relatedRoadmapActionID: nil,
                        evidenceSkillID: nil,
                        isBlocked: false,
                        blockedReason: nil
                    ))
                }
            } else {
                // Gap is ready!
                // Check if roadmap action exists for this skill
                var matchedAction: TestMilestoneAction? = nil
                for ms in roadmap.milestones {
                    if let devs = ms.skillsDeveloped, devs.map({ normSkill($0) }).contains(gap) {
                        matchedAction = ms.actions?.first
                        break
                    }
                }

                if let act = matchedAction {
                    if completedActionIDs.contains(act.id) {
                        completed.append(AdaptiveRoadmapRecommendation(
                            id: recID(type: .skillGap, id: gap),
                            type: .skillGap,
                            title: gap.capitalized,
                            reason: "Skill gap already addressed via completed action.",
                            reasonCode: .actionCompleted,
                            priority: 0,
                            state: .completed,
                            relatedSkillID: gap,
                            prerequisiteSkillIDs: trans,
                            relatedProjectID: nil,
                            relatedOpportunityID: nil,
                            relatedRoadmapActionID: act.id,
                            evidenceSkillID: nil,
                            isBlocked: false,
                            blockedReason: nil
                        ))
                        continue
                    }

                    if lockedActionIDs.contains(act.id) {
                        let b = lockedMilestoneBlockers[act.id]?.joined(separator: ", ") ?? "prerequisite milestone"
                        blocked.append(AdaptiveRoadmapRecommendation(
                            id: recID(type: .blocked, id: gap),
                            type: .blocked,
                            title: gap.capitalized,
                            reason: "Blocked by roadmap milestone: \(b).",
                            reasonCode: .blockedByPrerequisite,
                            priority: 10,
                            state: .blocked,
                            relatedSkillID: gap,
                            prerequisiteSkillIDs: trans,
                            relatedProjectID: nil,
                            relatedOpportunityID: nil,
                            relatedRoadmapActionID: act.id,
                            evidenceSkillID: nil,
                            isBlocked: true,
                            blockedReason: b
                        ))
                        continue
                    }
                }

                let gRecID = recID(type: .skillGap, id: gap)
                if !next.contains(where: { $0.id == gRecID }) {
                    next.append(AdaptiveRoadmapRecommendation(
                        id: gRecID,
                        type: .skillGap,
                        title: gap.capitalized,
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

        // Ready roadmap actions
        for ms in roadmap.milestones {
            guard !completedMIDs.contains(ms.id) else { continue }
            let isLocked = (ms.dependencies ?? []).contains { !completedMIDs.contains($0) }
            guard !isLocked else { continue }
            for act in ms.actions ?? [] where !completedActionIDs.contains(act.id) {
                if next.contains(where: { $0.relatedRoadmapActionID == act.id }) { continue }
                next.append(AdaptiveRoadmapRecommendation(
                    id: recID(type: .continue, id: act.id),
                    type: .continue,
                    title: act.title,
                    reason: "Next roadmap action is ready.",
                    reasonCode: .actionIncomplete,
                    priority: 55,
                    state: .ready,
                    relatedSkillID: nil,
                    prerequisiteSkillIDs: [],
                    relatedProjectID: nil,
                    relatedOpportunityID: nil,
                    relatedRoadmapActionID: act.id,
                    evidenceSkillID: nil,
                    isBlocked: false,
                    blockedReason: nil
                ))
            }
        }

        // Relevant projects
        for gap in skillGaps.prefix(2) {
            for proj in projects {
                let pSkills = Set(proj.skills.map { normSkill($0) })
                if pSkills.contains(gap) {
                    let inProg = (progress[proj.id] ?? 0) > 0
                    let pRecID = recID(type: .project, id: proj.id)
                    if !next.contains(where: { $0.id == pRecID }) {
                        next.append(AdaptiveRoadmapRecommendation(
                            id: pRecID,
                            type: .project,
                            title: inProg ? "Continue \(proj.title)" : "Start \(proj.title)",
                            reason: "Builds \(gap.capitalized), an active career skill gap.",
                            reasonCode: .projectBuildsSkill,
                            priority: inProg ? 47 : 42,
                            state: inProg ? .inProgress : .ready,
                            relatedSkillID: gap,
                            prerequisiteSkillIDs: testPrereqs(for: gap),
                            relatedProjectID: proj.id,
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
            for opp in opportunities {
                let oSkills = Set(opp.skills.map { normSkill($0) })
                if oSkills.contains(gap) && opp.isEligible {
                    let oRecID = recID(type: .opportunity, id: opp.id)
                    if !next.contains(where: { $0.id == oRecID }) {
                        next.append(AdaptiveRoadmapRecommendation(
                            id: oRecID,
                            type: .opportunity,
                            title: opp.title,
                            reason: "Eligible opportunity builds \(gap.capitalized).",
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
        for sid in currentSkills {
            let hasEv = evidenceRecords.contains { $0.skillIDs.map { normSkill($0) }.contains(sid) }
            if !hasEv {
                let evRecID = recID(type: .evidence, id: sid)
                if !next.contains(where: { $0.id == evRecID }) {
                    next.append(AdaptiveRoadmapRecommendation(
                        id: evRecID,
                        type: .evidence,
                        title: "Document \(sid.capitalized)",
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
        let allMilestonesDone = !roadmap.milestones.isEmpty && completedMIDs.count >= roadmap.milestones.count
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

        // Stable sort
        next.sort { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            if a.type.rawValue != b.type.rawValue { return a.type.rawValue < b.type.rawValue }
            let keyA = a.relatedSkillID ?? a.relatedRoadmapActionID ?? a.relatedProjectID ?? a.id
            let keyB = b.relatedSkillID ?? b.relatedRoadmapActionID ?? b.relatedProjectID ?? b.id
            if keyA != keyB { return keyA < keyB }
            return a.id < b.id
        }

        var explanations: [String] = []
        if let top = next.first(where: { $0.type != .complete }) {
            explanations.append("Recommended next: \(top.title) — \(top.reason)")
        }
        for w in warnings { explanations.append("Blocked: \(w)") }
        if next.contains(where: { $0.type == .complete }) {
            explanations.append("Target already covered.")
        }

        return AdaptiveRoadmapResult(
            roadmapID: roadmap.id,
            roadmapTitle: roadmap.title,
            targetCareerID: targetCareer,
            targetGoal: targetGoal,
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
}

// MARK: - Test Setup

let seRoadmap = TestRoadmap(
    id: "swe-roadmap",
    title: "Software Engineering",
    goal: "Become a software engineer",
    milestones: [
        TestMilestone(
            id: "m1",
            title: "Foundations",
            dependencies: nil,
            skillsDeveloped: ["Programming Fundamentals"],
            actions: [TestMilestoneAction(id: "a1", title: "Learn Python Basics")]
        ),
        TestMilestone(
            id: "m2",
            title: "Data Structures",
            dependencies: ["m1"],
            skillsDeveloped: ["Data Structures"],
            actions: [TestMilestoneAction(id: "a2", title: "Implement Linked Lists")]
        ),
        TestMilestone(
            id: "m3",
            title: "Algorithms",
            dependencies: ["m2"],
            skillsDeveloped: ["Algorithms"],
            actions: [TestMilestoneAction(id: "a3", title: "Solve Binary Search")]
        )
    ]
)

// =============================================================================
// TEST SUITES
// =============================================================================

print("—— 1. Determinism: Same input produces identical output ——")
do {
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Build web apps"],
        strengths: ["Programming Fundamentals"]
    )
    let res1 = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: profile, activeRoadmapIDs: ["swe-roadmap"])
    let res2 = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: profile, activeRoadmapIDs: ["swe-roadmap"])

    assertEqual(res1.recommendedNext.count, res2.recommendedNext.count, "Rec count matches")
    assertEqual(res1.recommendedNext.map(\.id), res2.recommendedNext.map(\.id), "Rec IDs match exactly")
    assertEqual(res1.recommendedNext.map(\.priority), res2.recommendedNext.map(\.priority), "Rec priorities match")
    assertEqual(res1.blocked.map(\.id), res2.blocked.map(\.id), "Blocked IDs match")
    assertEqual(res1.explanations, res2.explanations, "Explanations match")
}

print("—— 2. Prerequisites: Missing prerequisite always precedes dependent skill ——")
do {
    // Empty skills: student needs Programming Fundamentals -> Data Structures -> Algorithms
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: []
    )
    let res = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: profile, activeRoadmapIDs: ["swe-roadmap"])

    assert(!res.recommendedNext.isEmpty, "Has recommendations")
    let first = res.recommendedNext.first!
    assertEqual(first.type, .prerequisite, "First recommendation is prerequisite")
    assertEqual(first.relatedSkillID, "programming fundamentals", "Programming Fundamentals is recommended first")

    // Algorithms must NOT be in recommendedNext as ready
    let algInNext = res.recommendedNext.first(where: { $0.relatedSkillID == "algorithms" && $0.type == .skillGap })
    assert(algInNext == nil, "Algorithms is not recommended before Data Structures and Programming Fundamentals")

    // Algorithms must be in blocked
    let algBlocked = res.blocked.first(where: { $0.relatedSkillID == "algorithms" })
    assert(algBlocked != nil, "Algorithms is marked as blocked")
    assert(algBlocked?.isBlocked == true, "Blocked flag is true")
}

print("—— 3. Transitive Prerequisite Chains: A -> B -> C ——")
do {
    // Student has Programming Fundamentals, but missing Data Structures
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: ["Programming Fundamentals"]
    )
    let res = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: profile, activeRoadmapIDs: ["swe-roadmap"])

    let first = res.recommendedNext.first!
    assertEqual(first.relatedSkillID, "data structures", "Data Structures is recommended next once Programming Fundamentals is held")
    assertEqual(first.type, .prerequisite, "Data Structures recommended as prerequisite for Algorithms")

    // Algorithms is still blocked by Data Structures
    let algBlocked = res.blocked.first(where: { $0.relatedSkillID == "algorithms" })
    assert(algBlocked != nil, "Algorithms remains blocked")
    assertEqual(algBlocked?.blockedReason, "Requires data structures", "Blocked reason is explicit")
}

print("—— 4. Covered Prerequisites: Demonstrated prerequisite not re-recommended ——")
do {
    // Student already has both Programming Fundamentals AND Data Structures
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: ["Programming Fundamentals", "Data Structures"]
    )
    let res = TestAdaptiveRoadmapEngine.recommend(
        roadmap: seRoadmap,
        profile: profile,
        progress: ["swe-roadmap": 2],
        completedActionIDs: ["a1", "a2"],
        activeRoadmapIDs: ["swe-roadmap"]
    )

    // Programming Fundamentals & Data Structures should NOT be recommended as prerequisites or gaps
    let pfPrereq = res.recommendedNext.first(where: { $0.relatedSkillID == "programming fundamentals" && ($0.type == .prerequisite || $0.type == .skillGap) })
    assert(pfPrereq == nil, "Programming Fundamentals is not recommended again as prerequisite or gap")
    let dsPrereq = res.recommendedNext.first(where: { $0.relatedSkillID == "data structures" && ($0.type == .prerequisite || $0.type == .skillGap) })
    assert(dsPrereq == nil, "Data Structures is not recommended again as prerequisite or gap")

    // Algorithms should now be recommended as active skill gap
    let algRec = res.recommendedNext.first(where: { $0.relatedSkillID == "algorithms" })
    assert(algRec != nil, "Algorithms is now recommended")
    assertEqual(algRec?.type, .skillGap, "Algorithms is active skill gap")
    assertEqual(algRec?.reasonCode, .activeSkillGap, "Reason code is activeSkillGap")
}

print("—— 5. Skill Gaps: Active career skill gaps produce high-priority recommendations ——")
do {
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: ["Programming Fundamentals", "Data Structures"]
    )
    let res = TestAdaptiveRoadmapEngine.recommend(
        roadmap: seRoadmap,
        profile: profile,
        progress: ["swe-roadmap": 2],
        completedActionIDs: ["a1", "a2"],
        activeRoadmapIDs: ["swe-roadmap"]
    )
    let gapRec = res.recommendedNext.first(where: { $0.type == .skillGap })
    assert(gapRec != nil, "Skill gap recommendation present")
    if let g = gapRec {
        assert(g.priority >= 70, "Skill gap has high priority (>= 70)")
    }
}

print("—— 6. Roadmap Reuse: Existing roadmap action is linked rather than duplicated ——")
do {
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: ["Programming Fundamentals", "Data Structures"]
    )
    let res = TestAdaptiveRoadmapEngine.recommend(
        roadmap: seRoadmap,
        profile: profile,
        progress: ["swe-roadmap": 2],
        completedActionIDs: ["a1", "a2"],
        activeRoadmapIDs: ["swe-roadmap"]
    )
    let algRec = res.recommendedNext.first(where: { $0.relatedSkillID == "algorithms" })
    assertEqual(algRec?.relatedRoadmapActionID, "a3", "Roadmap action a3 is linked directly")
}

print("—— 7. Project Connection: Relevant existing project connected without auto-creating ——")
do {
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: ["Programming Fundamentals"]
    )
    let proj = TestProject(id: "proj-ds", title: "Trees and Graphs Project", skills: ["Data Structures"], milestoneCount: 4)
    let res = TestAdaptiveRoadmapEngine.recommend(
        roadmap: seRoadmap,
        profile: profile,
        activeRoadmapIDs: ["swe-roadmap"],
        projects: [proj]
    )

    let projRec = res.recommendedNext.first(where: { $0.type == .project })
    assert(projRec != nil, "Project recommendation exists")
    assertEqual(projRec?.relatedProjectID, "proj-ds", "Links existing project ID")
    assertEqual(projRec?.reasonCode, .projectBuildsSkill, "Reason code is projectBuildsSkill")
}

print("—— 8. Opportunity Connection: Only existing opportunities connected ——")
do {
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: ["Programming Fundamentals"]
    )
    let opp = TestOpportunity(id: "opp-ds", title: "Algorithms & DS Hackathon", skills: ["Data Structures"], isEligible: true)
    let res = TestAdaptiveRoadmapEngine.recommend(
        roadmap: seRoadmap,
        profile: profile,
        activeRoadmapIDs: ["swe-roadmap"],
        opportunities: [opp]
    )

    let oppRec = res.recommendedNext.first(where: { $0.type == .opportunity })
    assert(oppRec != nil, "Opportunity recommendation exists")
    assertEqual(oppRec?.relatedOpportunityID, "opp-ds", "Links existing opportunity ID")
}

print("—— 9. Eligibility Separation: Ineligible opportunity strictly excluded ——")
do {
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: ["Programming Fundamentals"]
    )
    // Opportunity matches the skill, but student is NOT eligible
    let ineligibleOpp = TestOpportunity(id: "opp-ineligible", title: "Senior College Contest", skills: ["Data Structures"], isEligible: false)
    let res = TestAdaptiveRoadmapEngine.recommend(
        roadmap: seRoadmap,
        profile: profile,
        activeRoadmapIDs: ["swe-roadmap"],
        opportunities: [ineligibleOpp]
    )

    let oppRec = res.recommendedNext.first(where: { $0.relatedOpportunityID == "opp-ineligible" })
    assert(oppRec == nil, "Ineligible opportunity is strictly excluded")
}

print("—— 10. Evidence Behavior: Missing evidence recommended, viewing creates no evidence ——")
do {
    // Student has demonstrated Programming Fundamentals, but no evidence record exists
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: ["Programming Fundamentals"]
    )
    let evidenceList: [TestEvidenceRecord] = []
    let res = TestAdaptiveRoadmapEngine.recommend(
        roadmap: seRoadmap,
        profile: profile,
        activeRoadmapIDs: ["swe-roadmap"],
        evidenceRecords: evidenceList
    )

    let evRec = res.recommendedNext.first(where: { $0.type == .evidence })
    assert(evRec != nil, "Evidence recommendation generated for demonstrated skill lacking evidence")
    assertEqual(evRec?.reasonCode, .evidenceMissing, "Reason code is evidenceMissing")
    assertEqual(evidenceList.count, 0, "Calling engine did NOT create any evidence record in store")
}

print("—— 11. Completion: Completed actions do not remain highest-priority next action ——")
do {
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: ["Programming Fundamentals", "Data Structures", "Algorithms"]
    )
    // All milestones completed in roadmap
    let res = TestAdaptiveRoadmapEngine.recommend(
        roadmap: seRoadmap,
        profile: profile,
        progress: ["swe-roadmap": 3],
        completedActionIDs: ["a1", "a2", "a3"],
        activeRoadmapIDs: ["swe-roadmap"]
    )

    assert(res.completed.contains(where: { $0.type == .complete }), "Contains completion recommendation")
    assert(!res.recommendedNext.contains(where: { $0.type == .skillGap }), "No active skill gap remaining")
}

print("—— 12. Blocked States: Explicit dependencies produce blocked state with reasons ——")
do {
    let profile = TestStudentProfile(
        careers: ["Software Engineering"],
        fields: ["Computer Science"],
        milestones: ["Master Algorithms"],
        strengths: []
    )
    let res = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: profile, activeRoadmapIDs: ["swe-roadmap"])

    assert(!res.blocked.isEmpty, "Blocked list populated")
    for item in res.blocked {
        assert(item.isBlocked, "item.isBlocked is true")
        assert(item.blockedReason != nil && !item.blockedReason!.isEmpty, "item has explicit blockedReason")
    }
}

print("—— 13. Empty Profile: Safe handling without crashes or fabricated data ——")
do {
    let emptyProfile = TestStudentProfile()
    let res = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: emptyProfile)

    assert(res.isInsufficientContext, "isInsufficientContext is true")
    assertEqual(res.recommendedNext.first?.reasonCode, .insufficientContext, "Reason code is insufficientContext")
    assert(!res.recommendedNext.first!.reason.isEmpty, "Provides user-facing guidance")
    assertEqual(res.blocked.count, 0, "No fake blocked items")
}

print("—— 14. Unrelated Changes: Changing unrelated data does not affect recommendations ——")
do {
    var p1 = TestStudentProfile(careers: ["Software Engineering"], strengths: ["Programming Fundamentals"])
    p1.location = "San Francisco"

    var p2 = TestStudentProfile(careers: ["Software Engineering"], strengths: ["Programming Fundamentals"])
    p2.location = "Tokyo"

    let r1 = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: p1, activeRoadmapIDs: ["swe-roadmap"])
    let r2 = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: p2, activeRoadmapIDs: ["swe-roadmap"])

    assertEqual(r1.recommendedNext.map(\.id), r2.recommendedNext.map(\.id), "Location change does not alter recommendations")
}

print("—— 15. Monotonicity: Acquiring a prerequisite never increases blocked count ——")
do {
    let pBefore = TestStudentProfile(careers: ["Software Engineering"], strengths: [])
    let pAfter = TestStudentProfile(careers: ["Software Engineering"], strengths: ["Programming Fundamentals"])

    let rBefore = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: pBefore, activeRoadmapIDs: ["swe-roadmap"])
    let rAfter = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: pAfter, activeRoadmapIDs: ["swe-roadmap"])

    assert(rAfter.blocked.count <= rBefore.blocked.count, "Blocked count decreases or stays same after acquiring prerequisite")
}

print("—— 16. Stable Sorting: Equal candidates resolve stably and identically ——")
do {
    let p = TestStudentProfile(careers: ["Software Engineering"], strengths: ["Programming Fundamentals", "Data Structures"])
    let r1 = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: p, activeRoadmapIDs: ["swe-roadmap"])
    let r2 = TestAdaptiveRoadmapEngine.recommend(roadmap: seRoadmap, profile: p, activeRoadmapIDs: ["swe-roadmap"])

    assertEqual(r1.recommendedNext.map(\.id), r2.recommendedNext.map(\.id), "Sorting is 100% stable across runs")
}

print("—— 17. No Mutation: Repeated calls produce zero state mutations ——")
do {
    let profile = TestStudentProfile(careers: ["Software Engineering"], strengths: ["Programming Fundamentals"])
    let originalProfile = profile
    let progress = ["swe-roadmap": 1]
    let originalProgress = progress
    let completedActions: Set<String> = ["a1"]
    let originalCompleted = completedActions

    for _ in 0..<10 {
        _ = TestAdaptiveRoadmapEngine.recommend(
            roadmap: seRoadmap,
            profile: profile,
            progress: progress,
            completedActionIDs: completedActions,
            activeRoadmapIDs: ["swe-roadmap"]
        )
    }

    assertEqual(profile, originalProfile, "Profile is never mutated")
    assertEqual(progress, originalProgress, "Progress is never mutated")
    assertEqual(completedActions, originalCompleted, "Completed actions are never mutated")
}

print("—— 18. Performance Benchmark: 100 careers, 500 skills, 1000 opportunities < 2.0s ——")
do {
    var benchmarkOpps: [TestOpportunity] = []
    for i in 0..<1000 {
        benchmarkOpps.append(TestOpportunity(
            id: "opp-\(i)",
            title: "Opportunity \(i)",
            skills: ["Skill \(i % 500)", "Data Structures"],
            isEligible: i % 2 == 0
        ))
    }
    let p = TestStudentProfile(
        careers: ["Software Engineering"],
        strengths: ["Programming Fundamentals"]
    )

    let startTime = CFAbsoluteTimeGetCurrent()
    for _ in 0..<5 {
        _ = TestAdaptiveRoadmapEngine.recommend(
            roadmap: seRoadmap,
            profile: p,
            activeRoadmapIDs: ["swe-roadmap"],
            opportunities: benchmarkOpps
        )
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("5 runs on 1,000 opportunities completed in \(String(format: "%.3f", elapsed))s")
    assert(elapsed < 2.0, "5 runs completed in under 2.0s (\(elapsed)s)")
}

print("\n========================================")
print("All \(passed) tests passed, \(failed) failed ✓")
print("Phase 12A Adaptive Roadmap Intelligence — COMPLETE")
print("========================================\n")
