import SwiftUI

struct RoadmapDetailView: View {
    let scoredRoadmap: ScoredRoadmap
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var selectedMilestoneID: String?
    @State private var selectedAchievement: Achievement?
    @State private var selectedEvidence: EvidenceRecord?
    @State private var selectedProposal: AdaptiveRoadmapProposal?
    @State private var showProposalSheet = false

    private var roadmap: Roadmap { scoredRoadmap.roadmap }
    private var completedCount: Int { store.completedCount(for: roadmap) }
    private var selectedMilestone: Milestone? { roadmap.milestones.first { $0.id == selectedMilestoneID } }
    private var isActivated: Bool { store.isRoadmapActivated(roadmap.id) }

    /// Set of completed milestone IDs for dependency calculations.
    private var completedMilestoneIDs: Set<String> {
        let count = completedCount
        return Set(roadmap.milestones.prefix(count).map(\.id))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: StudentOPSTheme.sectionSpacing) {
                    overview
                    activationBanner
                    roadmapPathSection(proxy: proxy)
                    // PRO 5 — Adaptive Roadmaps: UP NEXT + updates (gate adaptive intelligence, not basic roadmap)
                    PremiumFeatureGateWithPreview(feature: .adaptiveRoadmaps, previewTitle: "Adaptive Up Next", previewSubtitle: "Dependency-aware next steps and roadmap updates") {
                        VStack(alignment: .leading, spacing: 12) {
                            upNextSection
                            if !store.adaptiveProposals(for: roadmap).isEmpty {
                                let proposals = store.adaptiveProposals(for: roadmap)
                                Button { selectedProposal = proposals.first; showProposalSheet = true } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.triangle.branch").font(.system(size: 12, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark)
                                        Text("\(proposals.count) roadmap update\(proposals.count == 1 ? "" : "s") available").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.primaryDark)
                                    }
                                    .padding(12).background(StudentOPSTheme.primary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.primary.opacity(0.2)))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    // PRO 2 — Skill Gap Intelligence (gate detailed gap analysis, free sees basic roadmap)
                    PremiumFeatureGateWithPreview(feature: .skillGapIntelligence, previewTitle: "Skill Gap Intelligence", previewSubtitle: "Data Structures • Your next recommended skill") {
                        skillGapsCompactSection
                    }
                    // Secondary — collapsed behind disclosure
                    DisclosureGroup {
                        VStack(spacing: 12) {
                            RoadmapExplanationAIView(roadmap: roadmap).environmentObject(store)
                            achievementsForRoadmapSection
                            evidenceForRoadmapSection
                        }
                    } label: {
                        Text("MORE DETAILS").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                    }.tint(StudentOPSTheme.textSecondary)
                    if isActivated {
                        Button("Deactivate roadmap") { store.deactivateRoadmap(roadmap.id) }
                            .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth: .infinity).padding(.top, 4)
                    }
                    Button("Reset roadmap progress") { store.resetRoadmap(roadmap); store.clearActivation(roadmap.id); selectedMilestoneID = roadmap.milestones.first?.id }
                        .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth: .infinity).padding(.top, 4)
                }
                .padding(StudentOPSTheme.gutter)
            }
            .background(StudentOPSTheme.background.ignoresSafeArea())
            .navigationTitle("Roadmap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Text("\(scoredRoadmap.matchScore)% Match").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success) } }
            .onAppear {
                if selectedMilestoneID == nil {
                    selectedMilestoneID = roadmap.milestones.indices.contains(completedCount) ? roadmap.milestones[completedCount].id : roadmap.milestones.last?.id
                }
            }
            .sheet(item: $selectedAchievement) { ach in NavigationStack { AchievementDetailView(achievement: ach).environmentObject(store) } }
            .sheet(item: $selectedEvidence) { rec in EvidenceDetailSheet(record: rec).environmentObject(store) }
            .sheet(isPresented: $showProposalSheet) {
                if let proposal = selectedProposal {
                    AdaptiveProposalReviewSheet(
                        proposal: proposal,
                        roadmap: roadmap,
                        onApply: { _ = store.applyAdaptiveProposal(proposal) },
                        onDismiss: { store.dismissProposal(proposal) },
                        onKeepCurrent: { store.dismissProposal(proposal) }
                    ).environmentObject(store)
                }
            }
        }
    }

    // MARK: - Adaptive Updates Section (Phase 12B)

    @ViewBuilder
    private var adaptiveUpdatesSection: some View {
        let proposals = store.adaptiveProposals(for: roadmap)
        if !proposals.isEmpty {
            AdaptiveRoadmapUpdatesSection(proposals: proposals) { proposal in
                selectedProposal = proposal
                showProposalSheet = true
            }
        }
    }

    // MARK: - Activation Banner

    @ViewBuilder
    private var activationBanner: some View {
        if isActivated {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(StudentOPSTheme.success)
                Text("Active roadmap")
                    .font(DashFont.labelMd())
                    .foregroundColor(StudentOPSTheme.success)
                Spacer()
                if !scoredRoadmap.isCompleted {
                    Text("\(completedCount)/\(roadmap.milestones.count) milestones")
                        .font(DashFont.labelMono())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                }
            }
            .padding(12)
            .background(StudentOPSTheme.success.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if scoredRoadmap.isCompleted {
            // No banner for completed — already shown in overview
            EmptyView()
        } else {
            Button(action: { store.startRoadmap(roadmap) }) {
                HStack {
                    Spacer()
                    Label("Start Roadmap", systemImage: "play.fill")
                        .font(DashFont.labelMd())
                    Spacer()
                }
                .foregroundColor(StudentOPSTheme.textOnPrimary)
                .padding(.vertical, 14)
                .background(StudentOPSTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Label(roadmap.category.rawValue, systemImage: roadmap.category.icon).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark); Spacer(); Text(roadmap.isEmpty ? "" : "LOCAL ROADMAP").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary) }
            Text(roadmap.title).font(DashFont.heroTitle()).foregroundColor(StudentOPSTheme.textPrimary)
            Text(roadmap.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
            RoadmapProgressView(completedCount: completedCount, totalCount: roadmap.milestones.count)
        }
        .padding(16)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusHero))
        .overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusHero).stroke(StudentOPSTheme.border.opacity(0.4)))
    }

    private func roadmapPathSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR ROADMAP PATH").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
            ForEach(Array(roadmap.milestones.enumerated()), id: \.element.id) { index, milestone in
                let depStatus = RoadmapEngine.dependencyStatus(milestone: milestone, completedIDs: completedMilestoneIDs, milestones: roadmap.milestones)
                let lockInfo = RoadmapEngine.lockedExplanation(milestone: milestone, milestones: roadmap.milestones, completedIDs: completedMilestoneIDs)
                MilestoneNodeView(milestone: milestone, index: index, status: depStatus, isLast: index == roadmap.milestones.count - 1) {
                    selectedMilestoneID = milestone.id
                    withAnimation { proxy.scrollTo(milestone.id, anchor: .center) }
                }.id(milestone.id)
                if selectedMilestoneID == milestone.id {
                    MilestoneDetailView(milestone: milestone, status: depStatus, lockInfo: lockInfo, roadmap: roadmap) {
                        store.markRoadmapMilestoneComplete(for: roadmap)
                        selectedMilestoneID = roadmap.milestones.indices.contains(completedCount + 1) ? roadmap.milestones[completedCount + 1].id : nil
                    }.transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private var upNextSection: some View {
        let adaptive = store.adaptiveRoadmap(for: roadmap)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("UP NEXT").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                if !adaptive.isInsufficientContext { Text("Up Next").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primary) }
            }
            if adaptive.isInsufficientContext {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle").foregroundColor(StudentOPSTheme.primary)
                    Text(adaptive.explanations.first ?? "Activate this roadmap to adapt recommendations.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10))
            } else if adaptive.recommendedNext.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(StudentOPSTheme.success)
                    Text("Roadmap target is fully covered.").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.success)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.success.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                // Show hero first recommendation + compact list for rest behind disclosure
                let first = adaptive.recommendedNext.first!
                VStack(alignment: .leading, spacing: 10) {
                    // Hero recommendation
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(first.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            Spacer()
                            StatusPill(text: first.type.rawValue, color: typeColor(first.type))
                        }
                        Text(first.reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                        if let blocked = first.blockedReason {
                            Label(blocked, systemImage: "lock.fill").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.warning)
                        }
                    }
                    .padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.35)))
                    if adaptive.recommendedNext.count > 1 {
                        DisclosureGroup {
                            VStack(spacing: 8) {
                                ForEach(adaptive.recommendedNext.dropFirst().prefix(4), id: \.id) { rec in
                                    HStack(spacing: 8) {
                                        Text(rec.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                        Spacer()
                                        Text(rec.type.rawValue).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border.opacity(0.25)))
                                }
                            }
                        } label: {
                            Text("+\(adaptive.recommendedNext.count - 1) more suggestions").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                        }.tint(StudentOPSTheme.textSecondary)
                    }
                }
            }
            if !adaptive.prerequisiteWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(adaptive.prerequisiteWarnings.prefix(2), id: \.self) { w in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)).foregroundColor(StudentOPSTheme.warning)
                            Text(w).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var skillGapsCompactSection: some View {
        let report = store.skillGapReport(for: roadmap)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SKILL GAPS").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("\(report.demonstratedCount)/\(report.totalRequiredCount)").font(DashFont.captionMono()).foregroundColor(report.isFullyDemonstrated ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
            }
            if report.isFullyDemonstrated {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(StudentOPSTheme.success)
                    Text("All required skills demonstrated!").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.success.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("\(report.gapCount) skills to develop").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                VStack(spacing: 8) {
                    ForEach(report.gaps.prefix(2)) { gap in
                        NavigationLink(destination: SkillDetailView(skill: gap.skill).environmentObject(store)) {
                            HStack(spacing: 10) {
                                Circle().fill(priorityColor(gap.priority)).frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(gap.skillName).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                                        Spacer()
                                        StatusPill(text: gap.priority.title, color: priorityColor(gap.priority))
                                    }
                                    Text(gap.reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                                }
                            }
                            .padding(10).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.35)))
                        }.buttonStyle(.plain)
                    }
                    if report.gaps.count > 2 {
                        NavigationLink(destination: SkillDetailView(skill: report.gaps[2].skill).environmentObject(store)) {
                            Text("See all \(report.gapCount) skills →").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Skill Gaps Section

    @ViewBuilder
    private var skillGapsSection: some View {
        let report = store.skillGapReport(for: roadmap)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SKILLS TO DEVELOP")
                    .font(DashFont.labelMono())
                    .tracking(0.8)
                    .foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("\(report.demonstratedCount)/\(report.totalRequiredCount) demonstrated")
                    .font(DashFont.labelMono())
                    .foregroundColor(report.isFullyDemonstrated ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
            }

            if report.isFullyDemonstrated {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(StudentOPSTheme.success)
                    Text("All required skills demonstrated for this roadmap!")
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudentOPSTheme.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    ForEach(report.gaps) { gap in
                        NavigationLink(destination: SkillDetailView(skill: gap.skill).environmentObject(store)) {
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(priorityColor(gap.priority))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 5)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(gap.skillName)
                                            .font(DashFont.titleMd())
                                            .foregroundColor(StudentOPSTheme.textPrimary)
                                        Spacer()
                                        Text(gap.priority.title)
                                            .font(DashFont.labelMono())
                                            .foregroundColor(priorityColor(gap.priority))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(priorityColor(gap.priority).opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                    Text(gap.reason)
                                        .font(DashFont.bodySm())
                                        .foregroundColor(StudentOPSTheme.textSecondary)
                                    // Career connection (deterministic, only if exists)
                                    let relatedCareers = CareerSkillGraph.careerIDs(for: gap.skillID)
                                    if !relatedCareers.isEmpty, let first = relatedCareers.first, let career = CareerCatalog.career(for: first) {
                                        Text("Supports \(career.title)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                                    }
                                    // Next action via SkillIntelligenceEngine
                                    if let next = store.nextSkills(limit: 10).first(where: { $0.skillID == gap.skillID }), let reason = next.reasons.first {
                                        Text(reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                                    }
                                }
                            }
                            .padding(10)
                            .background(StudentOPSTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
                        }.buttonStyle(.plain)
                    }
                }
            }
            // Career connections for roadmap (Phase 11B)
            let careerConnections = CareerCatalog.all.filter { career in
                let cs = Set(CareerSkillGraph.skills(for: career.id))
                let req = Set(SkillGapEngine.requiredSkills(for: roadmap).map(\.id))
                return !cs.isDisjoint(with: req)
            }.prefix(2)
            if !careerConnections.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CAREER CONNECTIONS").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(Array(careerConnections), id: \.id) { career in
                        NavigationLink(destination: CareerDetailView(career: career).environmentObject(store)) {
                            HStack {
                                Text(career.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.textSecondary)
                            }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var achievementsForRoadmapSection: some View {
        let related = store.achievementRecords.values.filter { $0.roadmapID == roadmap.id }.sorted { $0.createdAt > $1.createdAt }
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("ACHIEVEMENTS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                ForEach(related.prefix(3)) { ach in
                    Button { selectedAchievement = ach } label: { AchievementRowView(achievement: ach) }.buttonStyle(.plain)
                }
                if related.count > 3 {
                    Text("+\(related.count - 3) more in Progress").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var evidenceForRoadmapSection: some View {
        let related = store.evidenceRecords.values.filter { $0.roadmapID == roadmap.id }.sorted { $0.createdAt > $1.createdAt }
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("EVIDENCE FOR THIS ROADMAP").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                ForEach(related.prefix(3)) { rec in
                    Button { selectedEvidence = rec } label: { EvidenceRowView(record: rec) }.buttonStyle(.plain)
                }
                if related.count > 3 {
                    Text("+\(related.count - 3) more in Progress").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func priorityColor(_ priority: SkillGapPriority) -> Color {
        switch priority {
        case .high: return StudentOPSTheme.warning
        case .medium: return StudentOPSTheme.primaryDark
        case .low: return StudentOPSTheme.textSecondary
        }
    }

    // MARK: - Adaptive Next Section (Phase 12A)

    @ViewBuilder
    private var adaptiveNextSection: some View {
        let adaptive = store.adaptiveRoadmap(for: roadmap)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ADAPTIVE NEXT")
                    .font(DashFont.labelMono())
                    .tracking(0.8)
                    .foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("Derived Intelligence")
                    .font(DashFont.labelMono())
                    .foregroundColor(StudentOPSTheme.primary)
            }

            if adaptive.isInsufficientContext {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundColor(StudentOPSTheme.primary)
                    Text(adaptive.explanations.first ?? "Activate this roadmap to adapt recommendations.")
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudentOPSTheme.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if adaptive.recommendedNext.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(StudentOPSTheme.success)
                    Text("Roadmap target is fully covered.")
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.success)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudentOPSTheme.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(adaptive.recommendedNext.enumerated()), id: \.element.id) { index, rec in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(DashFont.labelMono())
                                .foregroundColor(StudentOPSTheme.primary)
                                .frame(width: 22, height: 22)
                                .background(StudentOPSTheme.primary.opacity(0.12))
                                .clipShape(Circle())
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(rec.title)
                                        .font(DashFont.titleMd())
                                        .foregroundColor(StudentOPSTheme.textPrimary)
                                    Spacer()
                                    Text(rec.type.rawValue.uppercased())
                                        .font(DashFont.labelMono())
                                        .foregroundColor(typeColor(rec.type))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(typeColor(rec.type).opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                Text(rec.reason)
                                    .font(DashFont.bodySm())
                                    .foregroundColor(StudentOPSTheme.textSecondary)

                                if let blockedReason = rec.blockedReason {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(StudentOPSTheme.warning)
                                        Text(blockedReason)
                                            .font(DashFont.labelMono())
                                            .foregroundColor(StudentOPSTheme.warning)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                        .padding(12)
                        .background(StudentOPSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
                    }
                }
            }

            if !adaptive.prerequisiteWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(adaptive.prerequisiteWarnings, id: \.self) { warning in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(StudentOPSTheme.warning)
                            Text(warning)
                                .font(DashFont.bodySm())
                                .foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func typeColor(_ type: AdaptiveRoadmapRecommendationType) -> Color {
        switch type {
        case .prerequisite: return StudentOPSTheme.warning
        case .skillGap: return StudentOPSTheme.primary
        case .project: return StudentOPSTheme.primaryDark
        case .opportunity: return StudentOPSTheme.success
        case .evidence: return Color.purple
        case .continue: return StudentOPSTheme.primaryDark
        case .review, .complete: return StudentOPSTheme.success
        case .blocked: return StudentOPSTheme.textSecondary
        }
    }
}

private extension Roadmap {
    var isEmpty: Bool { milestones.isEmpty }
}
