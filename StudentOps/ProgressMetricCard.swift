import SwiftUI

struct ProgressMetricCard: View {
    let label: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(tint)
            Text(value).font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary)
            Text(label.uppercased()).font(DashFont.labelMono()).tracking(0.5).foregroundColor(StudentOPSTheme.textSecondary)
            Text(detail).font(.system(size: 10, weight: .medium)).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.45))).shadow(color: StudentOPSTheme.shadow, radius: 5, y: 2)
    }
}
