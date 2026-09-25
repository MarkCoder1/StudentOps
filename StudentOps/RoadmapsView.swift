import SwiftUI

struct RoadmapsView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var searchText = ""
    @State private var selectedCategory: RoadmapCategory?
    @State private var selectedRoadmap: ScoredRoadmap?
    @State private var selectedProposal: AdaptiveRoadmapProposal?
    @State private var showProposalSheet = false

    // MARK: - AI Personalization State
    @State private var personalized: PersonalizedRoadmapResponse?
    @State private var personalizedLoading = false
    @State private var personalizedError: String?
    @State private var hasFetchedPersonalized = false

    private var roadmaps: [ScoredRoadmap] {
        store.scoredRoadmaps.filter { roadmap in
            let categoryMatches = selectedCategory == nil || roadmap.roadmap.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatches = query.isEmpty || [roadmap.roadmap.title, roadmap.roadmap.goal, roadmap.roadmap.category.rawValue].joined(separator: " ").localizedCaseInsensitiveContains(query)
            return categoryMatches && searchMatches
        }
    }
    private var activated: [ScoredRoadmap] { store.activatedRoadmaps }
    private var active: [ScoredRoadmap] { roadmaps.filter { !$0.isCompleted } }
    private var completed: [ScoredRoadmap] { roadmaps.filter { $0.isCompleted } }
    private var recommended: [ScoredRoadmap] { Array(active.dropFirst()) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: StudentOPSTheme.sectionSpacing) {
                    header
                    if let first = activated.first {
                        sectionHeader(title: "YOUR ACTIVE ROADMAP", subtitle: "Current position → next milestone")
                        RoadmapJourneyView(roadmap: first) { selectedRoadmap = first }
                        // PRO 5 — Adaptive Roadmaps: updates badge (gate proposals, not basic roadmap)
                        let updates = store.allAdaptiveProposals.filter { $0.roadmapID == first.id }
                        if !updates.isEmpty {
                            PremiumFeatureGateWithPreview(feature: .adaptiveRoadmaps, previewTitle: "Adaptive Updates", previewSubtitle: "\(updates.count) roadmap update\(updates.count==1 ? "" : "s") ready to review") {
                                Button { selectedProposal = updates.first; showProposalSheet = true } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.triangle.branch").font(.system(size: 12, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark)
                                        Text("\(updates.count) update\(updates.count==1 ? "" : "s") available").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                        Spacer()
                                        Text("Review").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primary)
                                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.primary)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(StudentOPSTheme.primary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.primary.opacity(0.2)))
                            }.buttonStyle(.plain)
                            }
                        }
                    } else if let first = active.first {
                        sectionHeader(title: "SUGGESTED PATH", subtitle: "Start this roadmap to begin your journey")
                        RoadmapJourneyView(roadmap: first) { selectedRoadmap = first }
                    }
                    if !recommended.isEmpty {
                        sectionHeader(title: "MORE ROADMAPS", subtitle: "Explore more paths")
                        ForEach(recommended.prefix(3)) { roadmap in
                            RoadmapCard(roadmap: roadmap) { selectedRoadmap = roadmap }
                        }
                        if recommended.count > 3 {
                            Button { } label: { Text("See all \(recommended.count) roadmaps").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark) }.buttonStyle(.plain).frame(maxWidth: .infinity)
                        }
                    }
                    // Personalized recommendations — PRO 1: Personalized Roadmaps (gate intelligence, not tab)
                    PremiumFeatureGateWithPreview(feature: .personalizedRoadmaps, previewTitle: "Personalized Roadmaps", previewSubtitle: "Recommended for you • Based on your profile") {
                        Group {
                            if personalizedLoading {
                                HStack(spacing: 8) { ProgressView().tint(StudentOPSTheme.primaryDark); Text("Finding your best-fit paths…").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                            } else if let recs = personalized?.recommendations, !recs.isEmpty {
                                DisclosureGroup {
                                    ForEach(recs.prefix(3), id: \.roadmapId) { rec in
                                        if let scored = store.scoredRoadmaps.first(where: { $0.id == rec.roadmapId }) {
                                            RoadmapRecommendationCard(scoredRoadmap: scored, recommendation: rec) { selectedRoadmap = scored }
                                        }
                                    }
                                } label: {
                                    sectionHeader(title: "FOR YOU", subtitle: "Recommended for you • Based on your skills and goals")
                                }
                            }
                        }
                    }
                    categorySection
                    if !completed.isEmpty {
                        DisclosureGroup {
                            ForEach(completed.prefix(3)) { roadmap in RoadmapCard(roadmap: roadmap) { selectedRoadmap = roadmap } }
                        } label: {
                            sectionHeader(title: "COMPLETED", subtitle: "Paths you have finished")
                        }
                    }
                    if active.isEmpty && completed.isEmpty { emptyState }
                }.padding(.horizontal, StudentOPSTheme.gutter).padding(.top, 12).padding(.bottom, 24)
            }.background(StudentOPSTheme.background.ignoresSafeArea()).navigationTitle("Roadmaps").navigationBarTitleDisplayMode(.inline).navigationDestination(item: $selectedRoadmap) { roadmap in RoadmapDetailView(scoredRoadmap: roadmap).environmentObject(store).environmentObject(revenueCatManager) }
        }
        .task { await fetchPersonalizedIfNeeded() }
        .sheet(isPresented: $showProposalSheet) {
            if let proposal = selectedProposal {
                let roadmap = RoadmapService.roadmap(for: proposal.roadmapID)
                AdaptiveProposalReviewSheet(
                    proposal: proposal,
                    roadmap: roadmap,
                    onApply: { _ = store.applyAdaptiveProposal(proposal) },
                    onDismiss: { store.dismissProposal(proposal) },
                    onKeepCurrent: { store.dismissProposal(proposal) }
                ).environmentObject(store)
            }
        }
        .onAppear {
            if selectedRoadmap == nil {
                selectedRoadmap = store.scoredRoadmaps.first
            }
        }
    }

    // MARK: - AI Personalized Section

    @ViewBuilder
    private var personalizedSection: some View {
        if personalizedLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(StudentOPSTheme.primaryDark)
                Text("Finding your best-fit paths…")
                    .font(DashFont.bodySm())
                    .foregroundColor(StudentOPSTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        } else if personalizedError != nil {
            // Silent fallback — don't show error, just skip section
            EmptyView()
        } else if let recs = personalized?.recommendations, !recs.isEmpty {
            sectionHeader(title: "FOR YOU", subtitle: "AI-ranked paths based on your profile")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recs) { rec in
                        if let scored = store.scoredRoadmaps.first(where: { $0.id == rec.roadmapId }) {
                            RoadmapRecommendationCard(scoredRoadmap: scored, recommendation: rec) {
                                selectedRoadmap = scored
                            }
                            .frame(width: 300)
                        }
                    }
                }
            }
        }
    }

    private func fetchPersonalizedIfNeeded() async {
        guard !hasFetchedPersonalized else { return }
        hasFetchedPersonalized = true

        let profile = store.profile
        let allScored = RoadmapService.roadmaps(for: profile, progress: store.roadmapProgress)
        let catalog = allScored.map {
            RoadmapCatalogItem(
                from: $0.roadmap,
                matchScore: $0.matchScore,
                completedMilestones: $0.completedMilestones
            )
        }
        guard !catalog.isEmpty else { return }

        let completedCount = allScored.filter(\.isCompleted).count
        let activeCount = allScored.filter { !$0.isCompleted }.count

        let student = RoadmapStudentContext(
            profile: profile,
            achievements: store.achievements,
            completedRoadmapCount: completedCount,
            activeRoadmapCount: activeCount
        )

        personalizedLoading = true
        do {
            let response = try await RoadmapAPI.fetchPersonalized(student: student, roadmaps: catalog)
            personalized = response
        } catch {
            #if DEBUG
            print("[RoadmapAPI] Error: \(error.localizedDescription)")
            #endif
            personalizedError = error.localizedDescription
        }
        personalizedLoading = false
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Build your path").font(DashFont.heroTitle()).foregroundColor(StudentOPSTheme.textPrimary)
            Text("From where you are to where you want to go.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(StudentOPSTheme.textSecondary)
                    TextField("Search roadmaps", text: $searchText).font(DashFont.bodySm())
                }.padding(.horizontal, 12).frame(height: 42).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.5))).clipShape(RoundedRectangle(cornerRadius: 10))
                Menu { Button("All categories") { selectedCategory = nil }; ForEach(RoadmapCategory.allCases) { category in Button(category.rawValue) { selectedCategory = category } } } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle").font(.system(size: 18, weight: .medium)).foregroundColor(StudentOPSTheme.primaryDark).frame(width: 42, height: 42).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.5)))
                }
            }
            if let selectedCategory { Button { self.selectedCategory = nil } label: { Label("\(selectedCategory.rawValue) · Clear", systemImage: "xmark.circle.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark) }.buttonStyle(.plain) }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXPLORE ROADMAPS").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RoadmapCategory.allCases) { category in
                        Button { selectedCategory = category } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon).font(.system(size: 12))
                                Text(category.rawValue).font(DashFont.labelMd())
                            }
                            .foregroundColor(selectedCategory == category ? .white : StudentOPSTheme.textPrimary)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(selectedCategory == category ? StudentOPSTheme.primary : StudentOPSTheme.surface)
                            .clipShape(Capsule()).overlay(Capsule().stroke(StudentOPSTheme.border.opacity(0.4)))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
            Text(subtitle).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }
    }
    private var emptyState: some View { VStack(spacing: 10) { Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 26)).foregroundColor(StudentOPSTheme.primaryDark); Text("No roadmaps match that search").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary); Text("Try another keyword or category.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }.frame(maxWidth: .infinity).padding(.vertical, 60) }
}

// MARK: - AI Recommendation Card

private struct RoadmapRecommendationCard: View {
    let scoredRoadmap: ScoredRoadmap
    let recommendation: PersonalizedRoadmapRecommendation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(StudentOPSTheme.primaryDark)
                    Text(scoredRoadmap.roadmap.title)
                        .font(DashFont.titleMd())
                        .foregroundColor(StudentOPSTheme.textPrimary)
                        .lineLimit(2)
                    Spacer()
                    fitBadge
                }
                Text(recommendation.reason)
                    .font(DashFont.bodySm())
                    .foregroundColor(StudentOPSTheme.textSecondary)
                    .lineLimit(3)
                HStack {
                    Text(scoredRoadmap.roadmap.category.rawValue)
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.primaryDark)
                    Spacer()
                    Text("\(scoredRoadmap.progress)% complete")
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                }
            }
            .padding(16)
            .background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }

    private var fitBadge: some View {
        Text("\(recommendation.fitScore)%")
            .font(DashFont.labelMd())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fitColor)
            .clipShape(Capsule())
    }

    private var fitColor: Color {
        if recommendation.fitScore >= 80 { return .green }
        if recommendation.fitScore >= 60 { return StudentOPSTheme.warning }
        return .gray
    }
}
