import SwiftUI

struct RoadmapJourneyView: View {
    let roadmap: ScoredRoadmap
    @EnvironmentObject var store: AppDataStore
    let onOpen: () -> Void

    private var isActivated: Bool { store.isRoadmapActivated(roadmap.roadmap.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(roadmap.roadmap.category.rawValue.uppercased())
                            .font(DashFont.labelMono())
                            .tracking(1)
                            .foregroundColor(StudentOPSTheme.primaryDark)
                        if isActivated {
                            Text("ACTIVE")
                                .font(DashFont.labelMono())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(StudentOPSTheme.success)
                                .clipShape(Capsule())
                        }
                    }
                    Text(roadmap.roadmap.title)
                        .font(DashFont.headlineSm())
                        .foregroundColor(StudentOPSTheme.textPrimary)
                    Text(roadmap.roadmap.goal)
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(roadmap.progress)%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(StudentOPSTheme.primaryDark)
            }
            RoadmapProgressView(completedCount: roadmap.completedMilestones, totalCount: roadmap.roadmap.milestones.count)
            VStack(spacing: 0) {
                ForEach(Array(roadmap.roadmap.milestones.enumerated()), id: \.element.id) { index, milestone in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(index < roadmap.completedMilestones ? StudentOPSTheme.success : index == roadmap.completedMilestones ? StudentOPSTheme.primaryDark : StudentOPSTheme.border)
                            .frame(width: 12, height: 12)
                            .overlay(index < roadmap.completedMilestones ? Image(systemName: "checkmark").font(.system(size: 7, weight: .bold)).foregroundColor(.white) : nil)
                        Text(milestone.title)
                            .font(DashFont.bodySm())
                            .foregroundColor(index == roadmap.completedMilestones ? StudentOPSTheme.textPrimary : StudentOPSTheme.textSecondary)
                            .fontWeight(index == roadmap.completedMilestones ? .semibold : .regular)
                        Spacer()
                        if index == roadmap.completedMilestones { Text("NEXT").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark) }
                    }
                    if index < roadmap.roadmap.milestones.count - 1 {
                        Rectangle().fill(index < roadmap.completedMilestones ? StudentOPSTheme.success : StudentOPSTheme.border.opacity(0.5)).frame(width: 2, height: 18).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 5)
                    }
                }
            }
            Button(action: onOpen) {
                HStack { Text(roadmap.isCompleted ? "Review roadmap" : isActivated ? "Continue roadmap" : "Start roadmap"); Spacer(); Image(systemName: "arrow.right") }
                    .font(DashFont.labelMd())
                    .foregroundColor(StudentOPSTheme.textOnPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(StudentOPSTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
        }
        .padding(18)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(StudentOPSTheme.primary.opacity(0.18)))
        .shadow(color: StudentOPSTheme.shadow, radius: 8, y: 3)
    }
}
