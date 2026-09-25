import SwiftUI

struct PathProgressCard: View {
    let path: PathProgress
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) { Image(systemName: "location.north.circle.fill").font(.system(size: 14)).foregroundColor(StudentOPSTheme.primaryDark); Text("Your personalized path").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark) }.padding(.horizontal, 10).padding(.vertical, 5).background(StudentOPSTheme.surface).clipShape(Capsule())
                Spacer()
                Button(action: {}) { Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary).padding(6) }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) { Text(path.title).font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary); Text(path.subtitle).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }.padding(.top, 10)
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("\(path.percentComplete)% completed").font(DashFont.labelMono()).fontWeight(.semibold).foregroundColor(StudentOPSTheme.success); Spacer(); Text("\(path.milestonesCompleted) of \(path.milestonesTotal) milestones reached").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                MilestoneTrackView(nodes: path.nodes, percentComplete: path.percentComplete)
                HStack { ForEach(Array(path.trackLabels.enumerated()), id: \.offset) { index, label in Text(label).font(.system(size: 10, weight: index == 1 ? .semibold : .regular)).foregroundColor(index == 1 ? StudentOPSTheme.primary : StudentOPSTheme.textSecondary); if index < path.trackLabels.count - 1 { Spacer() } } }
            }.padding(.top, 16)
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
    }
}
