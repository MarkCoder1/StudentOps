import SwiftUI

struct SectionHeaderRow: View {
    let label: String
    var inlineBadge: String? = nil
    let trailingText: String
    var trailingIcon: String = "chevron.right"
    var trailingColor: Color = StudentOPSTheme.primaryDark
    var trailingAction: () -> Void = {}
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Text(label).font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                if let inlineBadge {
                    Text(inlineBadge).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(StudentOPSTheme.primary.opacity(0.12)).clipShape(Capsule())
                }
            }
            Spacer()
            Button(action: trailingAction) {
                HStack(spacing: 2) {
                    Text(trailingText)
                    Image(systemName: trailingIcon).font(.system(size: 11, weight: .semibold))
                }
                .font(DashFont.labelMd())
                .foregroundColor(trailingColor)
            }.buttonStyle(.plain)
        }
    }
}
