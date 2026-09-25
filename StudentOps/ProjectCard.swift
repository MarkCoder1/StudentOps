import SwiftUI

struct ProjectCard: View {
    let project: ScoredProject
    let isPortfolioReady: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top) {
                    Label(project.project.category, systemImage: "hammer").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                    Spacer()
                    if project.isCompleted && isPortfolioReady { Label("Portfolio ready", systemImage: "checkmark.seal.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success) }
                    else { Text("\(project.matchScore)% Match").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success) }
                }
                Text(project.project.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                Text(project.project.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                HStack { Text("\(project.progress)% complete").font(DashFont.labelMono()).foregroundColor(project.isCompleted ? StudentOPSTheme.success : StudentOPSTheme.primary); Spacer(); Text(project.project.estimatedCompletion).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                ProgressView(value: Double(project.progress), total: 100).tint(project.isCompleted ? StudentOPSTheme.success : StudentOPSTheme.primary)
                HStack(spacing: 5) { ForEach(Array(project.project.skills.prefix(3)), id: \.self) { skill in Text(skill).font(.system(size: 10, weight: .medium)).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 6).padding(.vertical, 3).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 4)) } }
                HStack { Text(project.isCompleted ? "Completed" : project.currentMilestone?.title ?? "Ready to begin").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary); Spacer(); Image(systemName: "arrow.right").foregroundColor(StudentOPSTheme.primaryDark) }
            }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.5))).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
        }.buttonStyle(.plain)
    }
}
