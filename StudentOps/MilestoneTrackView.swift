import SwiftUI

struct MilestoneTrackView: View {
    let nodes: [MilestoneNode]
    let percentComplete: Int
    private let nodeSize: CGFloat = 24
    var body: some View {
        GeometryReader { geo in
            let usableWidth = max(geo.size.width - nodeSize, 0)
            ZStack(alignment: .leading) {
                Rectangle().fill(StudentOPSTheme.border).frame(width: usableWidth, height: 2).offset(x: nodeSize / 2)
                Rectangle().fill(StudentOPSTheme.success).frame(width: usableWidth * CGFloat(percentComplete) / 100, height: 2).offset(x: nodeSize / 2)
                HStack(spacing: 0) { ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in nodeView(for: node); if index < nodes.count - 1 { Spacer(minLength: 0) } } }
            }
        }.frame(height: nodeSize)
    }
    @ViewBuilder private func nodeView(for node: MilestoneNode) -> some View {
        switch node.status {
        case .completed: Circle().fill(StudentOPSTheme.success).frame(width: nodeSize, height: nodeSize).overlay(Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white))
        case .active: Circle().fill(StudentOPSTheme.primaryDark).frame(width: nodeSize, height: nodeSize).overlay(Circle().stroke(StudentOPSTheme.primaryDark.opacity(0.22), lineWidth: 4).frame(width: nodeSize + 8, height: nodeSize + 8)).overlay(Circle().fill(.white).frame(width: 8, height: 8))
        case .upcoming: Circle().fill(Color.white).frame(width: nodeSize, height: nodeSize).shadow(color: StudentOPSTheme.shadowMedium, radius: 1, y: 1).overlay(Circle().fill(StudentOPSTheme.border).frame(width: 8, height: 8))
        case .goal: Circle().fill(Color.white).frame(width: nodeSize, height: nodeSize).shadow(color: StudentOPSTheme.shadowMedium, radius: 1, y: 1).overlay(Image(systemName: "flag.fill").font(.system(size: 11)).foregroundColor(StudentOPSTheme.textSecondary))
        }
    }
}
