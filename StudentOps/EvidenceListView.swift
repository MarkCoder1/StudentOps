import SwiftUI

struct EvidenceRowView: View {
    let record: EvidenceRecord
    private var quality: EvidenceQualityResult { EvidenceQualityEngine.quality(for: record) }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.type.displayName)
                    .font(DashFont.labelMono())
                    .foregroundColor(StudentOPSTheme.primaryDark)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(StudentOPSTheme.primary.opacity(0.1))
                    .clipShape(Capsule())
                Text(quality.overallLevel.displayName)
                    .font(DashFont.labelMono())
                    .foregroundColor(qualityColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(qualityColor.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Text(record.status == .verified ? "Verified" : "Recorded")
                    .font(DashFont.labelMono())
                    .foregroundColor(record.status == .verified ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
                Text(Self.dateString(record.createdAt))
                    .font(DashFont.labelMono())
                    .foregroundColor(StudentOPSTheme.textSecondary)
            }
            Text(record.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            if let desc = record.description, !desc.isEmpty {
                Text(desc).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
            }
            HStack(spacing: 8) {
                if !record.roadmapID.isEmpty {
                    Label(record.roadmapID, systemImage: "point.3.connected.trianglepath.dotted").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                if let pid = record.projectID, !pid.isEmpty {
                    Label("Project", systemImage: "hammer").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                if record.artifact != nil {
                    Label("Link", systemImage: "link").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }
                if let skills = record.skillIDs, !skills.isEmpty {
                    let display = skills.prefix(2).map { sid in SkillCatalog.knownSkills[sid]?.name ?? sid }.joined(separator: ", ")
                    Text(display).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                }
            }
            if let opp = record.opportunityID, !opp.isEmpty {
                Label("Opportunity: \(opp)", systemImage: "star").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
            }
            // Quality indicators
            HStack(spacing: 6) {
                if record.artifact != nil { Label("Has artifact", systemImage: "link").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark) }
                if let desc = record.description, !desc.isEmpty { Label("Has description", systemImage: "text.alignleft").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                if let skills = record.skillIDs, !skills.isEmpty { Label("\(skills.count) skills", systemImage: "checkmark.seal").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
            }
        }
        .padding(12)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
    }
    private var qualityColor: Color {
        switch quality.overallLevel {
        case .basic: return StudentOPSTheme.textSecondary
        case .solid: return StudentOPSTheme.primaryDark
        case .strong: return StudentOPSTheme.success
        }
    }
    static func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: d)
    }
}

struct EvidenceDetailSheet: View {
    let record: EvidenceRecord
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var selectedAchievement: Achievement?

    var isSystem: Bool { store.isSystemGeneratedEvidence(record) }
    private var quality: EvidenceQualityResult { EvidenceQualityEngine.quality(for: record) }

    private var supportingAchievements: [Achievement] {
        store.achievementRecords.values.filter { $0.evidenceIDs.contains(record.id) }.sorted { $0.createdAt > $1.createdAt }
    }

    private var portfolioSupports: [(portfolio: StudentPortfolio, supports: [String])] {
        store.allPortfoliosSorted.compactMap { portfolio in
            var supports: [String] = []
            if portfolio.selectedEvidenceIDs.contains(record.id) {
                supports.append("Portfolio • \(portfolio.title)")
            }
            let report = PortfolioEvidenceEngine.report(for: portfolio, store: store)
            for conn in report.connections where conn.evidenceID == record.id {
                switch conn.targetType {
                case .project:
                    if let proj = store.scoredProjects.first(where: { $0.project.id == conn.targetID })?.project ?? store.customProjects.first(where: { $0.id == conn.targetID }) {
                        supports.append("Project • \(proj.title)")
                    } else {
                        supports.append("Project • \(conn.targetID)")
                    }
                case .achievement:
                    if let ach = store.achievementRecords[conn.targetID] {
                        supports.append("Achievement • \(ach.title)")
                    }
                case .skill:
                    let name = SkillCatalog.knownSkills[conn.targetID]?.name ?? conn.targetID
                    supports.append("Skill • \(name)")
                case .roadmap:
                    if let rm = RoadmapService.roadmap(for: conn.targetID) {
                        supports.append("Roadmap • \(rm.title)")
                    }
                case .milestone:
                    supports.append("Milestone • \(conn.targetID)")
                case .opportunity:
                    supports.append("Opportunity • \(conn.targetID)")
                case .validation:
                    supports.append("Validation • \(conn.targetID)")
                }
            }
            let deduped = Array(Set(supports)).sorted()
            if deduped.isEmpty { return nil }
            return (portfolio, deduped)
        }
    }

    private var portfolioSupportsSection: some View {
        Group {
            if !portfolioSupports.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Portfolio Supports", systemImage: "doc.badge.ellipsis").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text("This evidence supports selected portfolio items. Read-only presentation — no automatic selection.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(portfolioSupports, id: \.portfolio.id) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(entry.portfolio.title, systemImage: "doc").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                            ForEach(entry.supports, id: \.self) { support in
                                Label(support, systemImage: "arrow.right.circle").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                        }.padding(10).background(StudentOPSTheme.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.primary.opacity(0.15)))
                    }
                }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.title).font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary)
                        if let desc = record.description { Text(desc).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                        HStack {
                            Text(record.type.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                            Text("•").foregroundColor(StudentOPSTheme.textSecondary)
                            Text(record.source.rawValue).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                            Text("•").foregroundColor(StudentOPSTheme.textSecondary)
                            Text(record.status.rawValue).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                        Text("Created \(EvidenceRowView.dateString(record.createdAt))").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                        if let occ = record.occurredAt { Text("Occurred \(EvidenceRowView.dateString(occ))").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary) }
                        Text(EvidenceQualityEngine.provenanceDescription(for: record)).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Evidence Strength").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            Spacer()
                            Text(quality.overallLevel.displayName).font(DashFont.labelMono()).foregroundColor(qualityColor(quality.overallLevel)).padding(.horizontal, 8).padding(.vertical, 4).background(qualityColor(quality.overallLevel).opacity(0.12)).clipShape(Capsule())
                        }
                        Text(quality.scoreExplanation).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        if !quality.strengths.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(quality.strengths, id: \.self) { s in
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11, weight: .bold)).foregroundColor(StudentOPSTheme.success)
                                        Text(s).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                                    }
                                }
                            }
                        }
                        if !quality.improvements.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Could improve").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                                ForEach(quality.improvements, id: \.self) { imp in
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.circle").font(.system(size: 11, weight: .bold)).foregroundColor(StudentOPSTheme.warning)
                                        Text(imp).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }.padding(12).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3))).clipShape(RoundedRectangle(cornerRadius: 12))
                    if let art = record.artifact {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Artifact", systemImage: "link").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            Text(art.title).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            if let url = art.url { Link(url, destination: URL(string: url) ?? URL(string: "https://example.com")!).font(DashFont.bodySm()) }
                            if let d = art.description { Text(d).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                        }.padding(12).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if let skills = record.skillIDs, !skills.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Associated Skills", systemImage: "checkmark.seal").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            Text("Referenced skills — not automatically awarded").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                            let displaySkills = skills.map { sid in SkillCatalog.knownSkills[sid]?.name ?? sid }
                            Text(displaySkills.joined(separator: " • ")).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                        }.padding(12).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if !supportingAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Supports \(supportingAchievements.count) achievement\(supportingAchievements.count == 1 ? "" : "s")", systemImage: "star.fill").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            ForEach(supportingAchievements) { ach in
                                Button { selectedAchievement = ach } label: {
                                    HStack {
                                        Text(ach.title).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                                    }.padding(10).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.3)))
                                }.buttonStyle(.plain)
                            }
                        }.padding(12).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if !record.roadmapID.isEmpty || !record.milestoneID.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Roadmap Relationship", systemImage: "point.3.connected.trianglepath.dotted").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            if !record.roadmapID.isEmpty {
                                if let roadmap = RoadmapService.roadmap(for: record.roadmapID) {
                                    Text(roadmap.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                                } else {
                                    Text("Roadmap: \(record.roadmapID)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                                }
                            }
                            if !record.milestoneID.isEmpty {
                                if let roadmap = RoadmapService.roadmap(for: record.roadmapID), let ms = roadmap.milestones.first(where: { $0.id == record.milestoneID }) {
                                    Text("Milestone: \(ms.title)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                                } else {
                                    Text("Milestone: \(record.milestoneID)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                                }
                            }
                            if let aid = record.actionID { Text("Action: \(aid)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                        }
                    }
                    if let pid = record.projectID {
                        if let proj = store.scoredProjects.first(where: { $0.project.id == pid })?.project ?? store.customProjects.first(where: { $0.id == pid }) {
                            Label(proj.title, systemImage: "hammer").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                        } else {
                            Label("Project: \(pid)", systemImage: "hammer").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                    portfolioSupportsSection
                    if let oid = record.opportunityID {
                        Label("Opportunity: \(oid)", systemImage: "star").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    if let vid = record.validationID {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Validation", systemImage: "checkmark.shield").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            Text(vid).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                            if let s = record.validationScore {
                                Label(s == 1 ? "Score: \(s)" : "Score: \(s) \(record.validationPassed == true ? "✓ Passed" : "✗")", systemImage: record.validationPassed == true ? "checkmark.seal.fill" : "xmark.seal.fill").font(DashFont.bodySm()).foregroundColor(record.validationPassed == true ? StudentOPSTheme.success : .red)
                                if let pct = record.validationPercentage { Text("\(pct)%").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                            }
                        }
                    }
                    if isSystem {
                        Text("System-generated evidence cannot be edited or deleted. It reflects roadmap completion.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }.padding(16)
            }
            .background(StudentOPSTheme.background.ignoresSafeArea())
            .navigationTitle("Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if !isSystem {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit") { showEdit = true }
                            Button("Delete", role: .destructive) { showDeleteConfirm = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                EvidenceFormView(editingRecord: record)
                    .environmentObject(store)
            }
            .sheet(item: $selectedAchievement) { ach in
                NavigationStack { AchievementDetailView(achievement: ach).environmentObject(store) }
            }
            .alert("Delete Evidence?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    _ = store.deleteEvidence(id: record.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this evidence. This cannot be undone and will not affect roadmap progress or skills.")
            }
        }
    }

    private func qualityColor(_ level: EvidenceQualityLevel) -> Color {
        switch level {
        case .basic: return StudentOPSTheme.textSecondary
        case .solid: return StudentOPSTheme.primaryDark
        case .strong: return StudentOPSTheme.success
        }
    }
}
