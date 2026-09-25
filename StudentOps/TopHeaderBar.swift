import SwiftUI

struct TopHeaderBar: View {
    var hasUnreadNotifications: Bool = true
    var onSearchTap: () -> Void = {}
    var onNotificationsTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8).fill(StudentOPSTheme.primaryDark.opacity(0.12)).frame(width: 32, height: 32).overlay(Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Student OPS").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text("HOME").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                }
            }
            Spacer()
            Button(action: onSearchTap) { Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .medium)).foregroundColor(StudentOPSTheme.textSecondary).frame(width: 44, height: 44) }.buttonStyle(.plain)
            Button(action: onNotificationsTap) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell").font(.system(size: 19, weight: .medium)).foregroundColor(StudentOPSTheme.textSecondary).frame(width: 44, height: 44)
                    if hasUnreadNotifications { Circle().fill(StudentOPSTheme.primaryDark).frame(width: 9, height: 9).overlay(Circle().stroke(StudentOPSTheme.background, lineWidth: 2)).offset(x: -9, y: 9) }
                }
            }.buttonStyle(.plain)
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(StudentOPSTheme.border).frame(width: 32, height: 32).overlay(Image(systemName: "person.fill").font(.system(size: 13)).foregroundColor(StudentOPSTheme.textSecondary)).overlay(Circle().stroke(StudentOPSTheme.primaryDark.opacity(0.3), lineWidth: 2))
                Circle().fill(StudentOPSTheme.success).frame(width: 10, height: 10).overlay(Circle().stroke(StudentOPSTheme.background, lineWidth: 2))
            }.padding(.leading, 2)
        }
        .padding(.horizontal, 16).frame(height: 64).background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundColor(StudentOPSTheme.shadow), alignment: .bottom)
    }
}
