import SwiftUI

struct RoadmapCard: View {
    let roadmap: ScoredRoadmap
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Label(roadmap.roadmap.category.rawValue, systemImage: roadmap.roadmap.category.icon).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                    Spacer()
                    Text("\(roadmap.matchScore)% Match").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
                }
                Text(roadmap.roadmap.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                Text(roadmap.roadmap.goal).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                HStack { Text("\(roadmap.progress)% complete").font(DashFont.labelMono()).foregroundColor(roadmap.isCompleted ? StudentOPSTheme.success : StudentOPSTheme.primary); Spacer(); Text("\(roadmap.completedMilestones)/\(roadmap.roadmap.milestones.count) milestones").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                ProgressView(value: Double(roadmap.progress), total: 100).tint(roadmap.isCompleted ? StudentOPSTheme.success : StudentOPSTheme.primary)
                HStack { Text(roadmap.isCompleted ? "Completed" : roadmap.currentMilestone?.title ?? "Ready to begin").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary); Spacer(); Image(systemName: "arrow.right").foregroundColor(StudentOPSTheme.primaryDark) }
            }
            .padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.5))).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
        }.buttonStyle(.plain)
    }
}
