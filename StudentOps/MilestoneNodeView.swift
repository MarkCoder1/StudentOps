import SwiftUI

struct MilestoneNodeView: View {
    let milestone: Milestone
    let index: Int
    let status: MilestoneStatus
    let isLast: Bool
    let onTap: () -> Void

    enum MilestoneStatus { case completed, current, locked }

    var isCurrent: Bool { status == .current }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Button(action: onTap) {
                    ZStack {
                        Circle()
                            .fill(backgroundColor)
                            .frame(width: isCurrent ? 44 : 36, height: isCurrent ? 44 : 36)
                            .shadow(color: isCurrent ? StudentOPSTheme.primary.opacity(0.25) : .clear, radius: isCurrent ? 6 : 0, y: isCurrent ? 2 : 0)
                        if status == .completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: isCurrent ? 16 : 14, weight: .bold))
                                .foregroundColor(.white)
                        } else if status == .current {
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                    .overlay(Circle().stroke(status == .current ? StudentOPSTheme.primaryDark.opacity(0.28) : .clear, lineWidth: isCurrent ? 6 : 5).frame(width: isCurrent ? 54 : 46, height: isCurrent ? 54 : 46))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Milestone \(index + 1) \(statusLabel)"))
                if !isLast {
                    Rectangle()
                        .fill(status == .completed ? StudentOPSTheme.success : status == .current ? StudentOPSTheme.primary.opacity(0.5) : StudentOPSTheme.border.opacity(0.55))
                        .frame(width: isCurrent ? 3 : 2, height: isCurrent ? 80 : 72)
                        .padding(.vertical, 4)
                }
            }
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: isCurrent ? 8 : 7) {
                    HStack {
                        Text("STEP \(index + 1)")
                            .font(isCurrent ? DashFont.labelMd() : DashFont.labelMono())
                            .tracking(0.7)
                            .foregroundColor(status == .current ? StudentOPSTheme.primaryDark : StudentOPSTheme.textSecondary)
                        Spacer()
                        Text(statusLabel)
                            .font(DashFont.labelMono())
                            .foregroundColor(statusColor)
                            .padding(.horizontal, isCurrent ? 8 : 0).padding(.vertical, isCurrent ? 3 : 0)
                            .background(isCurrent ? statusColor.opacity(0.12) : Color.clear).clipShape(Capsule())
                    }
                    Text(milestone.title)
                        .font(isCurrent ? .system(size: 16, weight: .bold) : DashFont.titleMd())
                        .foregroundColor(StudentOPSTheme.textPrimary)
                    Text(milestone.subtitle)
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(milestone.estimatedTime, systemImage: "clock")
                        .font(DashFont.labelMono())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                    if isCurrent, let goal = milestone.goal, !goal.isEmpty {
                        Text(goal).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.primaryDark).lineLimit(2).padding(.top, 2)
                    }
                }
                .padding(isCurrent ? 16 : 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(status == .current ? StudentOPSTheme.primary.opacity(0.08) : StudentOPSTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: isCurrent ? 16 : 14))
                .overlay(RoundedRectangle(cornerRadius: isCurrent ? 16 : 14).stroke(status == .current ? StudentOPSTheme.primary.opacity(0.4) : StudentOPSTheme.border.opacity(0.45), lineWidth: isCurrent ? 1.5 : 1))
                .shadow(color: isCurrent ? StudentOPSTheme.primary.opacity(0.12) : StudentOPSTheme.shadow, radius: isCurrent ? 8 : 6, y: isCurrent ? 3 : 2)
            }
            .buttonStyle(.plain)
            .opacity(status == .locked ? 0.68 : 1)
            .scaleEffect(isCurrent ? 1.02 : 1.0)
        }
        .padding(.vertical, isCurrent ? 2 : 0)
    }

    private var backgroundColor: Color {
        switch status {
        case .completed: return StudentOPSTheme.success
        case .current: return StudentOPSTheme.primaryDark
        case .locked: return StudentOPSTheme.border
        }
    }

    private var statusLabel: String {
        switch status {
        case .completed: return "COMPLETED"
        case .current: return "CURRENT"
        case .locked: return "LOCKED"
        }
    }

    private var statusColor: Color {
        switch status {
        case .completed: return StudentOPSTheme.success
        case .current: return StudentOPSTheme.primaryDark
        case .locked: return StudentOPSTheme.textSecondary
        }
    }
}
