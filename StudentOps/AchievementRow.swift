import SwiftUI

struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(StudentOPSTheme.lime).frame(width: 34, height: 34).overlay(Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(StudentOPSTheme.success))
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(achievement.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary); Spacer(); Text(achievement.dateLabel).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                Text(achievement.category).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                if let desc = achievement.description, !desc.isEmpty {
                    Text(desc).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                if achievement.evidenceURL != nil { Label("Evidence attached", systemImage: "link").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success) }
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
    }

    private var icon: String {
        switch achievement.category.lowercased() {
        case let category where category.contains("project"): return "hammer"
        case let category where category.contains("competition"): return "trophy"
        case let category where category.contains("volunteer"): return "hands.sparkles"
        case let category where category.contains("leadership"): return "person.2"
        default: return "star"
        }
    }
}
