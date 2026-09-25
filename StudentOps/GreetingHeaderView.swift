import SwiftUI

struct GreetingHeaderView: View {
    let dateLabel: String
    let firstName: String
    let statusSummary: String
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) { Circle().fill(StudentOPSTheme.success).frame(width: 8, height: 8); Text(dateLabel.uppercased()).font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary) }
                Text("Good afternoon, \(firstName)").font(DashFont.headlineLgMobile()).foregroundColor(StudentOPSTheme.textPrimary)
                Text(statusSummary).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            Spacer()
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(StudentOPSTheme.border).frame(width: 48, height: 48).overlay(Image(systemName: "person.fill").font(.system(size: 18)).foregroundColor(StudentOPSTheme.textSecondary)).shadow(color: StudentOPSTheme.shadowMedium, radius: 3, y: 1)
                Circle().fill(StudentOPSTheme.success).frame(width: 14, height: 14).overlay(Circle().fill(.white).frame(width: 6, height: 6)).overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
    }
}
