import SwiftUI

// MARK: - Adaptive Roadmap Updates Section (Phase 12B)
// Compact section for Roadmaps tab and roadmap detail.
// No new tab. Shows deterministic proposals requiring explicit user review.

struct AdaptiveRoadmapUpdatesSection: View {
    @EnvironmentObject var store: AppDataStore
    var proposals: [AdaptiveRoadmapProposal]
    var onSelect: (AdaptiveRoadmapProposal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ROADMAP UPDATES")
                    .font(DashFont.labelMono())
                    .tracking(0.8)
                    .foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("\(proposals.count) update\(proposals.count == 1 ? "" : "s") available")
                    .font(DashFont.labelMono())
                    .foregroundColor(StudentOPSTheme.primary)
            }
            VStack(spacing: 8) {
                ForEach(proposals.prefix(3)) { proposal in
                    Button(action: { onSelect(proposal) }) {
                        HStack(alignment: .top, spacing: 10) {
                            icon(for: proposal.changeType)
                                .frame(width: 22, height: 22)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(proposal.title)
                                    .font(DashFont.titleMd())
                                    .foregroundColor(StudentOPSTheme.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(rowSubtitle(for: proposal))
                                    .font(DashFont.bodySm())
                                    .foregroundColor(StudentOPSTheme.textSecondary)
                                    .lineLimit(2)
                                Text("Review suggested change")
                                    .font(DashFont.labelMd())
                                    .foregroundColor(StudentOPSTheme.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(StudentOPSTheme.textSecondary)
                                .padding(.top, 6)
                        }
                        .padding(12)
                        .background(StudentOPSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                }
                if proposals.count > 3 {
                    Text("+\(proposals.count - 3) more in roadmap detail")
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func icon(for type: AdaptiveProposalChangeType) -> some View {
        let name: String
        let color: Color
        switch type {
        case .unlockAction: name = "lock.open.fill"; color = StudentOPSTheme.success
        case .reorderAction: name = "arrow.up.arrow.down.circle.fill"; color = StudentOPSTheme.primary
        case .deferAction: name = "clock.arrow.circlepath"; color = StudentOPSTheme.warning
        case .insertExistingProject: name = "hammer.fill"; color = StudentOPSTheme.primaryDark
        case .connectOpportunity: name = "star.fill"; color = StudentOPSTheme.warning
        case .markProgressDerived: name = "checkmark.circle.fill"; color = StudentOPSTheme.success
        case .adjustSkillSequence: name = "list.number"; color = StudentOPSTheme.primary
        }
        return Image(systemName: name).foregroundColor(color).font(.system(size: 14))
    }

    private func rowSubtitle(for p: AdaptiveRoadmapProposal) -> String {
        switch p.changeType {
        case .unlockAction: return "Review suggested sequence"
        case .reorderAction: return "Review suggested ordering"
        case .deferAction: return "Review de-prioritization"
        case .insertExistingProject: return "Review connection"
        case .connectOpportunity: return "Review connection"
        case .markProgressDerived: return "Review progress update"
        case .adjustSkillSequence: return "Review skill ordering"
        }
    }
}

// MARK: - Proposal Review Sheet

struct AdaptiveProposalReviewSheet: View {
    @EnvironmentObject var store: AppDataStore
    let proposal: AdaptiveRoadmapProposal
    let roadmap: Roadmap?
    var onApply: () -> Void
    var onDismiss: () -> Void
    var onKeepCurrent: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let roadmap = roadmap {
                        currentVsProposed(for: roadmap)
                    } else {
                        Text(proposal.explanation)
                            .font(DashFont.bodyMd())
                            .foregroundColor(StudentOPSTheme.textPrimary)
                    }
                    whySection
                    reversibleNote
                    actionButtons
                }
                .padding(16)
            }
            .background(StudentOPSTheme.background.ignoresSafeArea())
            .navigationTitle("Roadmap Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.font(DashFont.labelMd())
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROADMAP UPDATE")
                .font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.primary)
            Text(proposal.title)
                .font(DashFont.heroTitle()).foregroundColor(StudentOPSTheme.textPrimary)
            HStack(spacing: 6) {
                Text(proposal.changeType.rawValue)
                    .font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(StudentOPSTheme.surface).clipShape(Capsule())
                Text(proposal.reasonCode.rawValue)
                    .font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                if proposal.isReversible {
                    Text("Reversible")
                        .font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(StudentOPSTheme.success.opacity(0.08)).clipShape(Capsule())
                }
            }
        }
    }

    private func currentVsProposed(for roadmap: Roadmap) -> some View {
        let currentMilestones: [String] = proposal.beforeState?.orderedMilestoneIDs ?? roadmap.milestones.map(\.title)
        let proposedMilestones: [String] = proposal.afterState?.orderedMilestoneIDs ?? roadmap.milestones.map(\.title)
        // Map IDs to titles when possible
        let currentTitles = currentMilestones.map { id in roadmap.milestones.first(where: { $0.id == id })?.title ?? id }
        let proposedTitles = proposedMilestones.map { id in roadmap.milestones.first(where: { $0.id == id })?.title ?? id }

        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CURRENT").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(Array(currentTitles.enumerated()), id: \.offset) { _, title in
                        HStack(spacing: 6) {
                            Circle().fill(StudentOPSTheme.border).frame(width: 6, height: 6)
                            Text(title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(StudentOPSTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.3)))

                Image(systemName: "arrow.right").foregroundColor(StudentOPSTheme.primary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("PROPOSED").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primary)
                    ForEach(Array(proposedTitles.enumerated()), id: \.offset) { _, title in
                        HStack(spacing: 6) {
                            Circle().fill(StudentOPSTheme.primary).frame(width: 6, height: 6)
                            Text(title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(StudentOPSTheme.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.primary.opacity(0.2)))
            }

            // Action-level change view if applicable
            if let beforeActions = proposal.beforeState?.orderedActionIDs, let afterActions = proposal.afterState?.orderedActionIDs, beforeActions != afterActions {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACTION ORDER").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(beforeActions.joined(separator: " → ")).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                        Image(systemName: "arrow.right").font(.system(size: 10)).foregroundColor(StudentOPSTheme.primary).padding(.top, 3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(afterActions.joined(separator: " → ")).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                        }
                    }
                    .padding(10)
                    .background(StudentOPSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHY").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            Text(proposal.explanation)
                .font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textPrimary)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.3)))
        }
    }

    private var reversibleNote: some View {
        HStack(spacing: 8) {
            Image(systemName: proposal.isReversible ? "arrow.uturn.backward.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(proposal.isReversible ? StudentOPSTheme.success : StudentOPSTheme.warning)
            Text(proposal.isReversible ? "This change is reversible. You can undo it after applying." : "This change cannot be automatically reversed.")
                .font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }
        .padding(10).background((proposal.isReversible ? StudentOPSTheme.success : StudentOPSTheme.warning).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { onApply(); dismiss() }) {
                HStack { Spacer(); Text("Apply Update").font(DashFont.labelMd()).fontWeight(.semibold); Spacer() }
                    .foregroundColor(.white)
                    .padding(.vertical, 14).background(StudentOPSTheme.primary).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Button(action: { onKeepCurrent(); dismiss() }) {
                    Text("Keep Current")
                        .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
                }
                .buttonStyle(.plain)
                Button(action: { onDismiss(); dismiss() }) {
                    Text("Dismiss")
                        .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
