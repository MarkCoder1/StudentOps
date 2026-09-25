import Foundation
import SwiftUI

// Deterministic next-action engine — no AI, no UserDefaults, pure store snapshot.
// Priority: project milestone > roadmap milestone > start project > saved opportunity > get started.
enum NextActionEngine {
    enum Action {
        case projectMilestone(ProjectMilestone, ScoredProject)
        case roadmapMilestone(RoadmapMilestone, ScoredRoadmap)
        case startProject(ScoredProject)
        case reviewSaved(ScoredOpportunity)
        case getStarted
    }

    static func nextAction(store: AppDataStore) -> Action {
        // 1. Incomplete project milestone (highest priority — evidence)
        if let proj = store.scoredProjects.first(where: { !$0.isCompleted }),
           let mile = proj.currentMilestone {
            return .projectMilestone(mile, proj)
        }
        // 2. Incomplete roadmap milestone
        if let road = store.scoredRoadmaps.first(where: { !$0.isCompleted }),
           let mile = road.currentMilestone {
            return .roadmapMilestone(mile, road)
        }
        // 3. Start an unfinished project not started (0 completed)
        if let notStarted = store.scoredProjects.first(where: { $0.completedMilestones == 0 && !$0.isCompleted }) {
            return .startProject(notStarted)
        }
        // 4. Review saved opportunity
        if let savedId = store.savedOpportunityIDs.first,
           let opp = store.scoredOpportunities.first(where: { $0.opportunity.id == savedId }) {
            return .reviewSaved(opp)
        }
        // Also try any top opportunity if no saved
        // 5. Fallback
        return .getStarted
    }

    static func nextStepTask(for action: Action) -> NextStepTask {
        switch action {
        case .projectMilestone(let mile, let proj):
            return NextStepTask(
                badge: "PROJECT MILESTONE",
                estimatedTime: mile.estimatedTime,
                title: mile.title,
                subtitle: proj.project.title,
                lessonsCompleted: proj.completedMilestones,
                lessonsTotal: proj.project.milestones.count,
                syncedToolName: "Project workspace ready"
            )
        case .roadmapMilestone(let mile, let road):
            return NextStepTask(
                badge: "ROADMAP MILESTONE",
                estimatedTime: mile.estimatedTime,
                title: mile.title,
                subtitle: road.roadmap.title,
                lessonsCompleted: road.completedMilestones,
                lessonsTotal: road.roadmap.milestones.count,
                syncedToolName: "Roadmap in progress"
            )
        case .startProject(let proj):
            return NextStepTask(
                badge: "START PROJECT",
                estimatedTime: proj.project.estimatedCompletion,
                title: proj.project.title,
                subtitle: proj.project.goal,
                lessonsCompleted: 0,
                lessonsTotal: max(proj.project.milestones.count, 1),
                syncedToolName: "Ready to begin"
            )
        case .reviewSaved(let opp):
            return NextStepTask(
                badge: "SAVED OPPORTUNITY",
                estimatedTime: opp.opportunity.deadline,
                title: opp.opportunity.title,
                subtitle: opp.opportunity.organization,
                lessonsCompleted: 0,
                lessonsTotal: 1,
                syncedToolName: "Review and apply"
            )
        case .getStarted:
            return NextStepTask(
                badge: "GET STARTED",
                estimatedTime: "~10 min",
                title: "Choose your first roadmap",
                subtitle: "Explore roadmaps matched to your interests.",
                lessonsCompleted: 0,
                lessonsTotal: 1,
                syncedToolName: "No active milestones"
            )
        }
    }
}
