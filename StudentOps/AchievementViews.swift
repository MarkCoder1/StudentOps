import SwiftUI

// MARK: - Achievement Row

struct AchievementRowView: View {
    let achievement: Achievement
    @EnvironmentObject var store: AppDataStore

    private var isGenerated: Bool { achievement.source != .studentEntered }
    private var evidenceCount: Int { achievement.evidenceIDs.count }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(isGenerated ? StudentOPSTheme.lime : StudentOPSTheme.primary.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(isGenerated ? StudentOPSTheme.success : StudentOPSTheme.primaryDark))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(achievement.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                    Spacer()
                    Text(achievement.type.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                if let desc = achievement.description, !desc.isEmpty {
                    Text(desc).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                }
                HStack(spacing: 8) {
                    Label(isGenerated ? "Earned from your progress" : "Added by you", systemImage: isGenerated ? "sparkles" : "person.crop.circle")
                        .font(DashFont.labelMono()).foregroundColor(isGenerated ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
                    if evidenceCount > 0 {
                        Label("\(evidenceCount) evidence", systemImage: "doc.badge.ellipsis").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                    }
                    Spacer()
                    Text(dateString).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                if let roadmapID = achievement.roadmapID, let roadmap = RoadmapService.roadmap(for: roadmapID) {
                    Label(roadmap.title, systemImage: "point.3.connected.trianglepath.dotted").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                } else if let projectID = achievement.projectID, let project = store.scoredProjects.first(where: { $0.project.id == projectID })?.project ?? store.customProjects.first(where: { $0.id == projectID }) {
                    Label(project.title, systemImage: "hammer").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                } else if let oppID = achievement.opportunityID {
                    Label(oppID, systemImage: "star").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
    }

    private var icon: String {
        switch achievement.type {
        case .project: return "hammer"
        case .research: return "doc.text.magnifyingglass"
        case .competition: return "trophy"
        case .leadership: return "person.2"
        case .communityImpact: return "hands.sparkles"
        case .technical: return "chevron.left.forwardslash.chevron.right"
        case .academic: return "graduationcap"
        case .milestone: return "flag.checkered"
        case .learning: return "book"
        case .other: return "star"
        }
    }

    private var dateString: String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: achievement.occurredAt ?? achievement.createdAt)
    }
}

// MARK: - Achievement Detail

struct AchievementDetailView: View {
    let achievement: Achievement
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEvidence: EvidenceRecord?

    private var supportingEvidence: [EvidenceRecord] {
        achievement.evidenceIDs.compactMap { store.evidenceRecords[$0] }
    }

    private var relatedAchievementsForEvidence: [Achievement] {
        // Not used here; for evidence detail
        []
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let desc = achievement.description, !desc.isEmpty {
                    Text(desc).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                proofSection
                if let skills = achievement.skillIDs, !skills.isEmpty {
                    skillsSection(skills)
                }
                connectionsSection
                statusSection
            }.padding(16)
        }
        .background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("Achievement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        .sheet(item: $selectedEvidence) { rec in
            EvidenceDetailSheet(record: rec).environmentObject(store)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(achievement.type.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                Text(achievement.status.rawValue.capitalized).font(DashFont.labelMono()).foregroundColor(achievement.status == .verified ? StudentOPSTheme.success : StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4).background(achievement.status == .verified ? StudentOPSTheme.success.opacity(0.12) : StudentOPSTheme.background).clipShape(Capsule())
                Spacer()
            }
            Text(achievement.title).font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary)
            HStack(spacing: 8) {
                Label(achievement.source == .studentEntered ? "Added by you" : "Earned from your progress", systemImage: achievement.source == .studentEntered ? "person.crop.circle" : "sparkles")
                    .font(DashFont.labelMd()).foregroundColor(achievement.source == .studentEntered ? StudentOPSTheme.textSecondary : StudentOPSTheme.success)
                Spacer()
                Text(dateString).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }
    }

    private var proofSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Proof", systemImage: "doc.badge.ellipsis").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                Spacer()
                Text("\(supportingEvidence.count) evidence").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            if supportingEvidence.isEmpty {
                Text("No supporting evidence yet. Add evidence that proves this achievement.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(supportingEvidence) { rec in
                    let quality = EvidenceQualityEngine.quality(for: rec)
                    Button { selectedEvidence = rec } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "doc.fill").foregroundColor(StudentOPSTheme.primaryDark)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rec.title).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(rec.type.displayName + " • " + EvidenceRowView.dateString(rec.createdAt)).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                    Text(quality.overallLevel.displayName).font(DashFont.labelMono()).foregroundColor(qualityColor(quality.overallLevel)).padding(.horizontal, 6).padding(.vertical, 2).background(qualityColor(quality.overallLevel).opacity(0.12)).clipShape(Capsule())
                                }
                                if let art = rec.artifact, art.url != nil {
                                    Label("Has artifact", systemImage: "link").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                        }.padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.3)))
                    }.buttonStyle(.plain)
                }
            }
            if let firstEvidence = supportingEvidence.first, supportingEvidence.count == 1, firstEvidence.validationID != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let passed = firstEvidence.validationPassed {
                        Label(passed ? "Passed — \(firstEvidence.validationPercentage ?? 0)%" : "Validation — \(firstEvidence.validationPercentage ?? 0)%", systemImage: passed ? "checkmark.seal.fill" : "xmark.seal.fill").font(DashFont.labelMd()).foregroundColor(passed ? StudentOPSTheme.success : .red)
                    }
                }
            }
        }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func skillsSection(_ skillIDs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Associated Skills", systemImage: "checkmark.seal").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            Text("Referenced skills — not automatically awarded").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            WrappingSkillsView(skillIDs: skillIDs)
        }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Connections", systemImage: "link").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            if let rid = achievement.roadmapID, let roadmap = RoadmapService.roadmap(for: rid) {
                HStack { Image(systemName: "point.3.connected.trianglepath.dotted"); Text(roadmap.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary); Spacer() }
            }
            if let mid = achievement.milestoneID { HStack { Image(systemName: "flag"); Text(mid).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary); Spacer() } }
            if let pid = achievement.projectID {
                let title = store.scoredProjects.first(where: { $0.project.id == pid })?.project.title ?? store.customProjects.first(where: { $0.id == pid })?.title ?? pid
                HStack { Image(systemName: "hammer"); Text(title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary); Spacer() }
            }
            if let oid = achievement.opportunityID {
                HStack { Image(systemName: "star"); Text(oid).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1); Spacer() }
            }
            if achievement.roadmapID == nil && achievement.projectID == nil && achievement.opportunityID == nil {
                Text("No specific roadmap/project/opportunity linked.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(achievement.status == .verified ? "Verified" : "Recorded", systemImage: achievement.status == .verified ? "checkmark.seal.fill" : "doc.badge.ellipsis").font(DashFont.labelMd()).foregroundColor(achievement.status == .verified ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
            Text(achievement.status == .verified ? "This achievement has been verified." : "This achievement is recorded based on your evidence. Verification would require an external verifier.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }.padding(12).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dateString: String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: achievement.occurredAt ?? achievement.createdAt)
    }
}

    private func qualityColor(_ level: EvidenceQualityLevel) -> Color {
        switch level {
        case .basic: return StudentOPSTheme.textSecondary
        case .solid: return StudentOPSTheme.primaryDark
        case .strong: return StudentOPSTheme.success
        }
    }

private struct WrappingSkillsView: View {
    let skillIDs: [String]
    var body: some View {
        // Use SkillCatalog display names where possible
        let chips: [(id: String, name: String)] = skillIDs.map { sid in
            if let s = SkillCatalog.knownSkills[sid] { return (sid, s.name) }
            return (sid, sid)
        }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(chips, id: \.id) { chip in
                    Text(chip.name).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                }
            }
        }
    }
}
