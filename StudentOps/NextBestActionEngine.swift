import Foundation

// MARK: - Action Type

enum NextBestActionType: String, Codable, Hashable {
    case roadmapAction = "roadmapAction"
    case opportunity = "opportunity"
    case savedOpportunity = "savedOpportunity"
    case projectAction = "projectAction"
    case startRoadmap = "startRoadmap"
}

// MARK: - Priority

enum NextBestActionPriority: String, Codable, Hashable, Comparable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    private var rank: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    static func < (lhs: NextBestActionPriority, rhs: NextBestActionPriority) -> Bool { lhs.rank < rhs.rank }
}

// MARK: - Destination

enum NextBestActionDestination: Hashable, Codable {
    case roadmaps
    case roadmapDetail(roadmapID: String)
    case milestoneDetail(roadmapID: String, milestoneID: String)
    case opportunityDetail(opportunityID: String)
    case projectDetail(projectID: String)
    case explore
}

// MARK: - Next Best Action

struct NextBestAction: Identifiable, Hashable, Codable {
    let id: String
    let type: NextBestActionType
    let title: String
    let subtitle: String
    let detail: String?
    let priority: NextBestActionPriority
    let priorityScore: Int
    let roadmapID: String?
    let milestoneID: String?
    let actionID: String?
    let opportunityID: String?
    let projectID: String?
    let skillIDs: [String]
    let signals: [String]
    let estimatedTime: String?
    let deadline: String?
    let destination: DestinationCodable

    // Codable wrapper for destination
    enum DestinationCodable: Hashable, Codable {
        case roadmaps
        case roadmapDetail(roadmapID: String)
        case milestoneDetail(roadmapID: String, milestoneID: String)
        case opportunityDetail(opportunityID: String)
        case projectDetail(projectID: String)
        case explore
    }

    var destinationEnum: NextBestActionDestination {
        switch destination {
        case .roadmaps: return .roadmaps
        case .roadmapDetail(let id): return .roadmapDetail(roadmapID: id)
        case .milestoneDetail(let r, let m): return .milestoneDetail(roadmapID: r, milestoneID: m)
        case .opportunityDetail(let id): return .opportunityDetail(opportunityID: id)
        case .projectDetail(let id): return .projectDetail(projectID: id)
        case .explore: return .explore
        }
    }
}

// MARK: - Pure Engine

enum NextBestActionEngine {

    // MARK: Public API

    /// All ranked candidates for the current store state.
    /// `personalizedFeed` is optional — when supplied, opportunity candidates use its eligibility/freshness/match.
    @MainActor
    static func rankedActions(store: AppDataStore, personalizedFeed: PersonalizedFeed? = nil) -> [NextBestAction] {
        let candidates = generateCandidates(store: store, personalizedFeed: personalizedFeed)
        let filtered = filter(candidates: candidates, store: store, personalizedFeed: personalizedFeed)
        let deduped = deduplicate(candidates: filtered)
        return rank(candidates: deduped)
    }

    /// Top-ranked action, if any.
    @MainActor
    static func nextAction(store: AppDataStore, personalizedFeed: PersonalizedFeed? = nil) -> NextBestAction? {
        rankedActions(store: store, personalizedFeed: personalizedFeed).first
    }

    /// Pure ranking (deterministic sort).
    static func rank(candidates: [NextBestAction]) -> [NextBestAction] {
        candidates.sorted { lhs, rhs in
            if lhs.priorityScore != rhs.priorityScore { return lhs.priorityScore > rhs.priorityScore }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            // Type precedence for deterministic tie-break
            let typeRank: (NextBestActionType) -> Int = { t in
                switch t {
                case .roadmapAction: return 4
                case .opportunity: return 3
                case .savedOpportunity: return 3
                case .projectAction: return 2
                case .startRoadmap: return 1
                }
            }
            if typeRank(lhs.type) != typeRank(rhs.type) { return typeRank(lhs.type) > typeRank(rhs.type) }
            if lhs.title != rhs.title { return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }
    }

    // MARK: - Candidate Generation

    @MainActor
    static func generateCandidates(store: AppDataStore, personalizedFeed: PersonalizedFeed?) -> [NextBestAction] {
        var out: [NextBestAction] = []
        out.append(contentsOf: roadmapActionCandidates(store: store))
        out.append(contentsOf: opportunityCandidates(store: store, personalizedFeed: personalizedFeed))
        out.append(contentsOf: savedOpportunityCandidates(store: store, personalizedFeed: personalizedFeed))
        out.append(contentsOf: projectCandidates(store: store))
        out.append(contentsOf: startRoadmapCandidates(store: store))
        return out
    }

    // MARK: Roadmap Action Candidates

    @MainActor
    private static func roadmapActionCandidates(store: AppDataStore) -> [NextBestAction] {
        var result: [NextBestAction] = []
        let catalog = store.scoredRoadmaps.map(\.roadmap)
        // dependency count map per roadmap
        for scored in store.activatedRoadmaps {
            let roadmap = scored.roadmap
            let completedCount = min(store.roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
            let completedIDs = Set(roadmap.milestones.prefix(completedCount).map(\.id))
            // gaps for this roadmap
            let gapReport = SkillGapEngine.evaluate(roadmap: roadmap, store: store)
            let gapByMilestone: [String: [SkillGap]] = {
                var m: [String: [SkillGap]] = [:]
                for g in gapReport.gaps {
                    for mid in g.requiredByMilestoneIDs { m[mid, default: []].append(g) }
                }
                return m
            }()
            // dependentCounts
            var dependentCounts: [String: Int] = [:]
            for ms in roadmap.milestones { for dep in ms.dependencies ?? [] { dependentCounts[dep, default: 0] += 1 } }

            for (idx, milestone) in roadmap.milestones.enumerated() {
                let availability = RoadmapEngine.milestoneAvailability(milestone: milestone, completedIDs: completedIDs, milestones: roadmap.milestones)
                switch availability {
                case .completed, .locked: continue
                case .available: break
                }
                guard let actions = milestone.actions, !actions.isEmpty else { continue }
                let milestoneGaps = gapByMilestone[milestone.id] ?? []
                let addressesGap = !milestoneGaps.isEmpty
                let isCurrent = idx == completedCount
                let dependentBonus = dependentCounts[milestone.id] ?? 0
                for action in actions {
                    if store.isActionCompleted(action.id) { continue }
                    var signals: [String] = []
                    if isCurrent { signals.append("advances current milestone") }
                    else { signals.append("advances available milestone") }
                    if addressesGap {
                        let names = milestoneGaps.prefix(2).map(\.skillName).joined(separator: ", ")
                        signals.append("addresses skill gap: \(names)")
                    }
                    if dependentBonus > 0 { signals.append("unlocks \(dependentBonus) future milestone(s)") }
                    signals.append("roadmap: \(roadmap.title)")
                    let priorityInfo = scoreRoadmapAction(
                        isCurrent: isCurrent,
                        gapCount: milestoneGaps.count,
                        gapPriority: milestoneGaps.first?.priority,
                        dependentCount: dependentBonus,
                        hasActions: true
                    )
                    let nb = NextBestAction(
                        id: "roadmapAction-\(milestone.id)-\(action.id)",
                        type: .roadmapAction,
                        title: action.title,
                        subtitle: milestone.title,
                        detail: roadmap.title,
                        priority: priorityInfo.priority,
                        priorityScore: priorityInfo.score,
                        roadmapID: roadmap.id,
                        milestoneID: milestone.id,
                        actionID: action.id,
                        opportunityID: nil,
                        projectID: nil,
                        skillIDs: milestone.skillsDeveloped?.map { Skill.normalizeID($0) }.filter { !$0.isEmpty } ?? [],
                        signals: signals,
                        estimatedTime: action.estimatedTime ?? milestone.estimatedTime,
                        deadline: nil,
                        destination: .milestoneDetail(roadmapID: roadmap.id, milestoneID: milestone.id)
                    )
                    result.append(nb)
                }
            }
        }
        return result
    }

    private static func scoreRoadmapAction(isCurrent: Bool, gapCount: Int, gapPriority: SkillGapPriority?, dependentCount: Int, hasActions: Bool) -> (priority: NextBestActionPriority, score: Int) {
        var score = 50
        if isCurrent { score += 20 } else { score += 10 }
        if gapCount > 0 {
            switch gapPriority {
            case .high: score += 15
            case .medium: score += 10
            case .low: score += 5
            default: score += 8
            }
            score += min(gapCount * 3, 9)
        }
        score += dependentCount * 10
        if hasActions { score += 5 }
        let priority: NextBestActionPriority = score >= 70 ? .high : score >= 45 ? .medium : .low
        return (priority, score)
    }

    // MARK: Opportunity Candidates (from personalized feed or local)

    @MainActor
    private static func opportunityCandidates(store: AppDataStore, personalizedFeed: PersonalizedFeed?) -> [NextBestAction] {
        guard let feed = personalizedFeed else {
            // Fallback: local scored opportunities
            return localOpportunityCandidates(store: store)
        }
        var result: [NextBestAction] = []
        let seen = Set(store.activatedRoadmaps.map(\.roadmap.id))
        guard !seen.isEmpty else { return [] } // need active roadmap for meaningful connection
        for p in feed.opportunities {
            // Filters
            if p.freshness.status == "expired" { continue }
            if p.eligibility.status == "ineligible" { continue }
            // Connection
            let conns = OpportunityRoadmapEngine.connections(for: p.opportunity, store: store)
            guard let best = conns.first else { continue }
            // Require at least relevant strength to avoid weak future noise
            // But allow future if direct gap? Our engine already sets future when locked. Skip future if we have better candidates? Keep but lower priority.
            // We'll include all but score will be low.

            var signals: [String] = []
            signals.append("match \(p.match.score)%")
            if best.addressesGap {
                let names = best.gapSkillsAddressed.prefix(2).map(\.name).joined(separator: ", ")
                signals.append("addresses gap: \(names)")
            }
            signals.append("\(best.strength.title) roadmap connection: \(best.roadmapTitle)")
            if let ms = best.milestoneLinks.first { signals.append("milestone: \(ms.title)") }
            if p.freshness.urgency == "urgent" { signals.append("deadline urgent") }
            else if p.freshness.urgency == "soon" { signals.append("deadline soon") }
            else if let d = p.freshness.deadline { signals.append("deadline \(d)") }
            if store.isSaved(p.opportunity) { signals.append("saved") }

            let isSaved = store.isSaved(p.opportunity)
            let type: NextBestActionType = isSaved ? .savedOpportunity : .opportunity
            // Deadline urgency score
            let urgencyScore: Int = {
                switch p.freshness.urgency {
                case "urgent": return 20
                case "soon": return 12
                case "upcoming": return 5
                default: return 0
                }
            }()
            let strengthScore: Int = {
                switch best.strength {
                case .direct: return 20
                case .relevant: return 10
                case .future: return 0
                }
            }()
            let score = 30 + (p.match.score / 5) + (best.gapSkillsAddressed.count * 12) + strengthScore + urgencyScore + (isSaved ? 8 : 0) + (best.advancesCurrentMilestone ? 12 : 0) + min(best.milestoneLinks.flatMap(\.actionIDs).count, 8)
            let priority: NextBestActionPriority = score >= 70 ? .high : score >= 45 ? .medium : .low

            let nb = NextBestAction(
                id: "opp-\(p.opportunity.id)-\(best.roadmapID)",
                type: type,
                title: "Apply to \(p.opportunity.title)",
                subtitle: best.roadmapTitle,
                detail: p.opportunity.organization ?? p.opportunity.category,
                priority: priority,
                priorityScore: score,
                roadmapID: best.roadmapID,
                milestoneID: best.milestoneLinks.first?.id,
                actionID: nil,
                opportunityID: p.opportunity.id,
                projectID: nil,
                skillIDs: best.matchedSkills.map(\.id),
                signals: signals,
                estimatedTime: nil,
                deadline: p.freshness.deadline ?? p.opportunity.deadline,
                destination: .opportunityDetail(opportunityID: p.opportunity.id)
            )
            result.append(nb)
        }
        return result
    }

    @MainActor
    private static func localOpportunityCandidates(store: AppDataStore) -> [NextBestAction] {
        guard !store.activatedRoadmaps.isEmpty else { return [] }
        var result: [NextBestAction] = []
        for scored in store.scoredOpportunities.prefix(5) {
            // For local, assume eligible and not expired
            let conns = OpportunityRoadmapEngine.connections(for: scored.opportunity, store: store)
            guard let best = conns.first else { continue }
            var signals: [String] = []
            signals.append("match \(scored.matchScore)%")
            if best.addressesGap {
                signals.append("addresses gap: \(best.gapSkillsAddressed.prefix(2).map(\.name).joined(separator: ", "))")
            }
            signals.append("\(best.strength.title) connection: \(best.roadmapTitle)")
            let strengthScore: Int = {
                switch best.strength {
                case .direct: return 20
                case .relevant: return 10
                case .future: return 0
                }
            }()
            let score = 30 + (scored.matchScore / 6) + (best.gapSkillsAddressed.count * 12) + strengthScore + (best.advancesCurrentMilestone ? 12 : 0)
            let priority: NextBestActionPriority = score >= 65 ? .high : score >= 40 ? .medium : .low
            let isSaved = store.isSaved(scored.opportunity)
            let nb = NextBestAction(
                id: "opp-local-\(scored.opportunity.id)-\(best.roadmapID)",
                type: isSaved ? .savedOpportunity : .opportunity,
                title: "Explore \(scored.opportunity.title)",
                subtitle: best.roadmapTitle,
                detail: scored.opportunity.organization,
                priority: priority,
                priorityScore: score + (isSaved ? 6 : 0),
                roadmapID: best.roadmapID,
                milestoneID: best.milestoneLinks.first?.id,
                actionID: nil,
                opportunityID: scored.opportunity.id,
                projectID: nil,
                skillIDs: best.matchedSkills.map(\.id),
                signals: signals,
                estimatedTime: nil,
                deadline: scored.opportunity.deadline,
                destination: .opportunityDetail(opportunityID: scored.opportunity.id)
            )
            result.append(nb)
        }
        return result
    }

    @MainActor
    private static func savedOpportunityCandidates(store: AppDataStore, personalizedFeed: PersonalizedFeed?) -> [NextBestAction] {
        // Already covered in opportunityCandidates via saved bonus.
        // Additionally, if feed is nil and saved local opportunity not in top 5 but still eligible, surface it.
        // For now, no extra generation; deduplication handles it.
        return []
    }

    // MARK: Project Candidates

    @MainActor
    private static func projectCandidates(store: AppDataStore) -> [NextBestAction] {
        var result: [NextBestAction] = []
        for scored in store.scoredProjects where !scored.isCompleted {
            guard let milestone = scored.currentMilestone else { continue }
            var signals: [String] = []
            signals.append("project in progress")
            if let src = scored.project.sourceRoadmapID { signals.append("linked to roadmap \(src)") }
            signals.append("\(scored.completedMilestones)/\(scored.project.milestones.count) milestones")
            let score = 40 + (scored.matchScore / 10) + min(scored.completedMilestones * 4, 12)
            let priority: NextBestActionPriority = score >= 60 ? .high : score >= 40 ? .medium : .low
            let nb = NextBestAction(
                id: "project-\(scored.project.id)-\(milestone.id)",
                type: .projectAction,
                title: milestone.title,
                subtitle: scored.project.title,
                detail: scored.project.goal,
                priority: priority,
                priorityScore: score,
                roadmapID: scored.project.sourceRoadmapID,
                milestoneID: milestone.id,
                actionID: nil,
                opportunityID: nil,
                projectID: scored.project.id,
                skillIDs: scored.project.skills.map { Skill.normalizeID($0) }.filter { !$0.isEmpty },
                signals: signals,
                estimatedTime: milestone.estimatedTime,
                deadline: nil,
                destination: .projectDetail(projectID: scored.project.id)
            )
            result.append(nb)
        }
        return result
    }

    // MARK: Start Roadmap Candidates

    @MainActor
    private static func startRoadmapCandidates(store: AppDataStore) -> [NextBestAction] {
        guard store.activatedRoadmaps.isEmpty else { return [] }
        // Pick top recommended non-completed roadmap
        guard let top = store.scoredRoadmaps.first(where: { !$0.isCompleted }) else { return [] }
        let roadmap = top.roadmap
        var signals: [String] = ["no active roadmap", "recommended (\(top.matchScore)%)"]
        let nb = NextBestAction(
            id: "start-\(roadmap.id)",
            type: .startRoadmap,
            title: "Start \(roadmap.title)",
            subtitle: roadmap.goal,
            detail: roadmap.description,
            priority: .medium,
            priorityScore: 35,
            roadmapID: roadmap.id,
            milestoneID: roadmap.milestones.first?.id,
            actionID: nil,
            opportunityID: nil,
            projectID: nil,
            skillIDs: [],
            signals: signals,
            estimatedTime: roadmap.milestones.first?.estimatedTime,
            deadline: nil,
            destination: .roadmapDetail(roadmapID: roadmap.id)
        )
        return [nb]
    }

    // MARK: Filtering

    static func filter(candidates: [NextBestAction], store: AppDataStore, personalizedFeed: PersonalizedFeed?) -> [NextBestAction] {
        candidates.filter { c in
            // Completed/locked already filtered at generation; double-check invalid refs
            if let rid = c.roadmapID, let mid = c.milestoneID {
                guard let roadmap = RoadmapService.roadmap(for: rid) else { return false }
                guard roadmap.milestones.contains(where: { $0.id == mid }) else { return false }
                // For roadmapAction, ensure milestone still not completed/locked
                if c.type == .roadmapAction {
                    let completedCount = store.roadmapProgress[rid] ?? 0
                    let completedIDs = Set(roadmap.milestones.prefix(min(completedCount, roadmap.milestones.count)).map(\.id))
                    if completedIDs.contains(mid) { return false }
                    if let ms = roadmap.milestones.first(where: { $0.id == mid }) {
                        if case .locked = RoadmapEngine.milestoneAvailability(milestone: ms, completedIDs: completedIDs, milestones: roadmap.milestones) { return false }
                    }
                    if let aid = c.actionID, store.isActionCompleted(aid) { return false }
                }
            }
            // Opportunity expired/ineligible already filtered; generic check for local deadline parsing not needed
            return true
        }
    }

    static func deduplicate(candidates: [NextBestAction]) -> [NextBestAction] {
        var seen = Set<String>()
        var out: [NextBestAction] = []
        for c in candidates {
            if seen.contains(c.id) { continue }
            seen.insert(c.id)
            out.append(c)
        }
        return out
    }
}
