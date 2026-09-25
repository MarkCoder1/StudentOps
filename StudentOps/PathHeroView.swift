import SwiftUI

struct PathHeroView: View {
    let path: PathProgress
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CURRENT PATH")
                        .font(DashFont.labelMono())
                        .tracking(1)
                        .foregroundColor(StudentOPSTheme.lime)
                    Text(path.title)
                        .font(DashFont.headlineLgMobile())
                        .foregroundColor(.white)
                    Text(path.subtitle)
                        .font(DashFont.bodySm())
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(2)
                }
                Spacer()
                Text("\(path.percentComplete)%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(StudentOPSTheme.lime)
            }

            MilestoneTrackView(nodes: path.nodes, percentComplete: path.percentComplete)
                .padding(.vertical, 4)

            HStack {
                Text("\(path.milestonesCompleted) of \(path.milestonesTotal) milestones")
                    .font(DashFont.labelMd())
                    .foregroundColor(.white.opacity(0.72))
                Spacer()
                Button(action: action) {
                    Label("Open path", systemImage: "arrow.up.right")
                        .font(DashFont.labelMd())
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color(hex: "0F172A"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.08)))
    }
}
