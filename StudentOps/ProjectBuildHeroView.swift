import SwiftUI

struct ProjectBuildHeroView: View {
    let project: ScoredProject
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.project.category.uppercased()).font(DashFont.labelMono()).tracking(1).foregroundColor(StudentOPSTheme.primaryDark)
                    Text(project.project.title).font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text(project.project.goal).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: "hammer.fill").font(.system(size: 22)).foregroundColor(StudentOPSTheme.primaryDark).frame(width: 44, height: 44).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(project.progress)%").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(StudentOPSTheme.textPrimary)
                    Text(project.currentMilestone?.title ?? "Project complete").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
                Text("\(project.completedMilestones)/\(project.project.milestones.count) steps").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            ProgressView(value: Double(project.progress), total: 100).tint(StudentOPSTheme.primary).scaleEffect(x: 1, y: 1.5)
            HStack { Text("Next action").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary); Spacer(); Text(project.project.estimatedCompletion).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
            Button(action: onOpen) { HStack { Text(project.isCompleted ? "Review project" : "Continue building"); Spacer(); Image(systemName: "arrow.right") }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textOnPrimary).padding(.horizontal, 14).padding(.vertical, 12).background(StudentOPSTheme.primary).clipShape(RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain)
        }
        .padding(18).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(StudentOPSTheme.primary.opacity(0.18))).shadow(color: StudentOPSTheme.shadow, radius: 8, y: 3)
    }
}
