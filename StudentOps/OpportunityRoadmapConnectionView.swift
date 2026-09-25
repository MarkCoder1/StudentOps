import SwiftUI

// MARK: - Opportunity Roadmap Connection Section

struct OpportunityRoadmapConnectionSection: View {
    let connections: [OpportunityRoadmapConnection]

    var body: some View {
        if connections.isEmpty {
            // Do not force a connection — omit section when no active roadmaps or no overlap.
            // Still show a lightweight placeholder for credibility when active roadmaps exist
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("How this advances your path", systemImage: "signpost.right")
                    .font(DashFont.titleMd())
                    .foregroundColor(StudentOPSTheme.textPrimary)

                ForEach(connections) { conn in
                    connectionCard(conn)
                }
            }
            .padding(16)
            .background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func connectionCard(_ conn: OpportunityRoadmapConnection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conn.roadmapTitle)
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.textPrimary)
                    Text(conn.strength.title + " connection")
                        .font(DashFont.labelMono())
                        .foregroundColor(strengthColor(conn.strength))
                }
                Spacer()
                Text("\(conn.score)")
                    .font(DashFont.labelMono())
                    .foregroundColor(StudentOPSTheme.textSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(StudentOPSTheme.background)
                    .clipShape(Capsule())
            }

            if !conn.matchedSkills.isEmpty {
                WrappingHStack(items: conn.matchedSkills) { skill in
                    Text(skill.name)
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.primaryDark)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(StudentOPSTheme.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if !conn.gapSkillsAddressed.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(conn.gapSkillsAddressed) { gap in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(StudentOPSTheme.success)
                            Text("Addresses gap: \(gap.name)")
                                .font(DashFont.bodySm())
                                .foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                }
            }

            if !conn.milestoneLinks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(conn.milestoneLinks) { link in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: statusIcon(link.status))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(statusColor(link.status))
                                .frame(width: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(link.title)
                                        .font(DashFont.bodySm())
                                        .foregroundColor(StudentOPSTheme.textPrimary)
                                    Text(statusLabel(link.status))
                                        .font(DashFont.labelMono())
                                        .foregroundColor(statusColor(link.status))
                                }
                                if !link.actionTitles.isEmpty {
                                    Text("\(link.actionTitles.count) related action\(link.actionTitles.count == 1 ? "" : "s")")
                                        .font(DashFont.labelMd())
                                        .foregroundColor(StudentOPSTheme.textSecondary)
                                    ForEach(Array(link.actionTitles.prefix(3)), id: \.self) { t in
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(StudentOPSTheme.textSecondary)
                                            Text(t)
                                                .font(DashFont.bodySm())
                                                .foregroundColor(StudentOPSTheme.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if conn.advancesCurrentMilestone {
                Label("Advances your current milestone", systemImage: "flag.checkered")
                    .font(DashFont.labelMd())
                    .foregroundColor(StudentOPSTheme.primaryDark)
            }
        }
        .padding(12)
        .background(StudentOPSTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.5)))
    }

    private func strengthColor(_ s: OpportunityRoadmapConnectionStrength) -> Color {
        switch s {
        case .direct: return StudentOPSTheme.success
        case .relevant: return StudentOPSTheme.primaryDark
        case .future: return StudentOPSTheme.textSecondary
        }
    }

    private func statusIcon(_ s: MilestoneLinkStatus) -> String {
        switch s {
        case .current: return "arrow.right.circle.fill"
        case .available: return "circle.dashed"
        case .locked: return "lock.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private func statusColor(_ s: MilestoneLinkStatus) -> Color {
        switch s {
        case .current: return StudentOPSTheme.primaryDark
        case .available: return StudentOPSTheme.primary
        case .locked: return StudentOPSTheme.textSecondary
        case .completed: return StudentOPSTheme.success
        }
    }

    private func statusLabel(_ s: MilestoneLinkStatus) -> String {
        switch s {
        case .current: return "current"
        case .available: return "available"
        case .locked: return "locked"
        case .completed: return "completed"
        }
    }
}

// Simple wrapping HStack for skill pills
private struct WrappingHStack<Item: Identifiable & Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        // Use FlowLayout-like wrapping via flexible HStack with line breaks
        // Simplified: horizontal scroll if many items — keeps layout deterministic
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    content(item)
                }
            }
        }
    }
}


