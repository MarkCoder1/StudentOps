import SwiftUI

struct RoadmapProgressView: View {
    let completedCount: Int
    let totalCount: Int

    private var progress: Double { totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(Int((progress * 100).rounded()))% complete")
                    .font(DashFont.labelMono())
                    .foregroundColor(StudentOPSTheme.primaryDark)
                Spacer()
                Text("\(completedCount) of \(totalCount) milestones")
                    .font(DashFont.labelMono())
                    .foregroundColor(StudentOPSTheme.textSecondary)
            }
            ProgressView(value: progress)
                .tint(StudentOPSTheme.primary)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
        }
    }
}
