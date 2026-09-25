import SwiftUI

struct NextStepCard: View {
    let task: NextStepTask
    let buttonState: DashboardViewModel.NextStepButtonState
    let onTap: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(StudentOPSTheme.primary).frame(width: 5)
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text(task.badge).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 3).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule()); Spacer(); HStack(spacing: 4) { Image(systemName: "clock").font(.system(size: 12)); Text(task.estimatedTime) }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 3).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 6)) }
                VStack(alignment: .leading, spacing: 4) { Text(task.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary); Text(task.subtitle).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                HStack(spacing: 8) { GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(StudentOPSTheme.border); Capsule().fill(StudentOPSTheme.primary).frame(width: geo.size.width * CGFloat(task.lessonsCompleted) / CGFloat(max(task.lessonsTotal, 1))) } }.frame(height: 6); Text("\(task.lessonsCompleted)/\(task.lessonsTotal) Lessons").font(.system(size: 11, weight: .medium)).foregroundColor(StudentOPSTheme.textSecondary).fixedSize() }
                Divider().padding(.top, 2)
                HStack { HStack(spacing: 6) { Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 16)).foregroundColor(StudentOPSTheme.success); Text(task.syncedToolName).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }; Spacer(); ctaButton }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
    }
    private var ctaButton: some View { Button(action: onTap) { HStack(spacing: 6) { switch buttonState { case .idle: Text("Start"); Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold)); case .loading: ProgressView().tint(StudentOPSTheme.textOnPrimary).scaleEffect(0.7); Text("Resuming..."); case .ready: Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)); Text("Ready") } }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textOnPrimary).padding(.horizontal, 16).padding(.vertical, 10).background(StudentOPSTheme.primary).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain).disabled(buttonState != .idle) }
}
