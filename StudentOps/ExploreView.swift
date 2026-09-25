import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @StateObject private var viewModel = ExploreViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: OpportunityCategory = .all
    @State private var selectedFilter: ExploreFilter = .all
    @State private var showFilters = false
    @State private var selectedPersonalized: PersonalizedOpportunity?
    @State private var selectedOpportunity: RemoteOpportunity?
    @State private var selectedRanked: RankedOpportunity?
    @State private var selectedRankedFilter: RankingFilterMode = .all
    @State private var selectedOpportunityType: OpportunityType? = nil
    @State private var showPaywall = false

    enum ExploreFilter: String, CaseIterable {
        case all = "All"
        case free = "Free"
        case scholarships = "Scholarships"
        case competitions = "Competitions"
        case hackathons = "Hackathons"
        case online = "Online"
    }

    // MARK: - Canonical Ranked Opportunities (Phase 10B)

    private var rankedOpportunities: [RankedOpportunity] {
        store.rankedOpportunities(
            filter: selectedRankedFilter,
            category: selectedOpportunityType,
            searchText: searchText.isEmpty ? nil : searchText
        )
    }

    private var rankedStats: (total: Int, eligible: Int, unknown: Int, ineligible: Int, avg: Int) {
        let all = store.rankedOpportunities(filter: .all, searchText: searchText.isEmpty ? nil : searchText)
        let eligible = all.filter { $0.eligibilityStatus == .eligible }.count
        let unknown = all.filter { $0.eligibilityStatus == .unknown }.count
        let ineligible = all.filter { $0.eligibilityStatus == .ineligible }.count
        let avg = all.isEmpty ? 0 : all.map(\.rankScore).reduce(0, +) / all.count
        return (all.count, eligible, unknown, ineligible, avg)
    }

    private var hasLocalOpportunities: Bool { !store.opportunities.isEmpty }

    // Legacy remote feed
    private var feed: PersonalizedFeed? { viewModel.feed }

    private var sections: [FeedSection] {
        guard let feed = feed else { return [] }
        var result = feed.sections
        if selectedCategory != .all {
            result = result.map { section in
                let filtered = section.opportunities.filter { p in matchesCategory(p.opportunity, selectedCategory) }
                return FeedSection(id: section.id, title: section.title, subtitle: section.subtitle, opportunities: filtered)
            }.filter { !$0.opportunities.isEmpty }
        }
        if selectedFilter != .all {
            result = result.map { section in
                let filtered = section.opportunities.filter { p in matchesFilter(p) }
                return FeedSection(id: section.id, title: section.title, subtitle: section.subtitle, opportunities: filtered)
            }.filter { !$0.opportunities.isEmpty }
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            result = result.map { section in
                let filtered = section.opportunities.filter { p in
                    let haystack = [p.opportunity.title, p.opportunity.organization ?? "", p.opportunity.category, p.opportunity.description ?? ""].joined(separator: " ").lowercased()
                    return haystack.contains(search)
                }
                return FeedSection(id: section.id, title: section.title, subtitle: section.subtitle, opportunities: filtered)
            }.filter { !$0.opportunities.isEmpty }
        }
        return result
    }

    private var totalCount: Int {
        hasLocalOpportunities ? rankedStats.total : (feed?.opportunities.count ?? 0)
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasLocalOpportunities {
                    localContent
                } else if viewModel.isLoading && viewModel.opportunities.isEmpty {
                    loadingState
                } else if let error = viewModel.errorMessage, viewModel.opportunities.isEmpty {
                    errorState(message: error)
                } else if sections.isEmpty {
                    emptyState
                } else {
                    remoteContent
                }
            }
            .background(StudentOPSTheme.background.ignoresSafeArea())
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFilters) { OpportunityFilterView(selectedCategory: $selectedCategory, categories: OpportunityCategory.allCases, onClear: { selectedCategory = .all; showFilters = false }) }
            .navigationDestination(item: $selectedPersonalized) { p in OpportunityDetailView(personalizedOpportunity: p).environmentObject(store).environmentObject(revenueCatManager) }
            .navigationDestination(item: $selectedOpportunity) { opp in OpportunityDetailView(remoteOpportunity: opp).environmentObject(store).environmentObject(revenueCatManager) }
            .navigationDestination(item: $selectedRanked) { ranked in OpportunityDetailView(ranked: ranked).environmentObject(store).environmentObject(revenueCatManager) }
            .task { await viewModel.loadInitial(profile: store.profile) }
        }
    }

    // MARK: - Local Content (Phase 10B)

    private var localContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                localHeader
                localStatsBar
                localFilterChips
                if rankedOpportunities.isEmpty {
                    localEmpty
                } else {
                    localRankedSection
                }
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
        }
        .refreshable { await viewModel.refresh(profile: store.profile) }
    }

    private var localHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recommended for you").font(DashFont.heroTitle()).foregroundColor(StudentOPSTheme.textPrimary)
                Spacer()
                Text("\(totalCount) opportunities").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            Text("Eligible opportunities ranked by your goals, skills, and roadmap.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(StudentOPSTheme.textSecondary)
                    TextField("Search opportunities", text: $searchText).font(DashFont.bodySm())
                }.padding(.horizontal, 12).frame(height: 42).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.5))).clipShape(RoundedRectangle(cornerRadius: 10))
                Button { showFilters = true } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle").font(.system(size: 18, weight: .medium)).foregroundColor(StudentOPSTheme.primaryDark).frame(width: 42, height: 42).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.5)))
                }.buttonStyle(.plain)
            }
            if selectedRankedFilter != .all || selectedOpportunityType != nil {
                Button { selectedRankedFilter = .all; selectedOpportunityType = nil; searchText = "" } label: {
                    Label("Clear filters", systemImage: "xmark.circle.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }.buttonStyle(.plain)
            }
        }
    }

    private var localStatsBar: some View {
        // Compact single line per spec: Eligible • Match% • Needs Info — Pro 4 gates match
        HStack(spacing: 8) {
            Text("\(rankedStats.eligible) Eligible").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.success)
            if revenueCatManager.isPro {
                Text("•").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                Text("\(rankedStats.avg)% Match").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark)
            } else {
                Text("•").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                HStack(spacing: 4) {
                    Text("Match").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    ProBadge()
                }
            }
            if rankedStats.unknown > 0 {
                Text("•").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                Text("\(rankedStats.unknown) Needs Info").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.warning)
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border.opacity(0.35)))
    }

    private var localFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RankingFilterMode.allCases, id: \.self) { mode in
                    Button { selectedRankedFilter = mode } label: {
                        Text(mode.rawValue)
                            .font(DashFont.labelMd())
                            .foregroundColor(selectedRankedFilter == mode ? StudentOPSTheme.textOnPrimary : StudentOPSTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(selectedRankedFilter == mode ? StudentOPSTheme.primary : StudentOPSTheme.surface)
                            .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
                Menu {
                    Button("All Types") { selectedOpportunityType = nil }
                    ForEach(OpportunityType.allCases, id: \.self) { t in
                        Button(t.rawValue.capitalized) { selectedOpportunityType = t }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedOpportunityType?.rawValue.capitalized ?? "Type")
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }
                    .font(DashFont.labelMd())
                    .foregroundColor(selectedOpportunityType != nil ? StudentOPSTheme.textOnPrimary : StudentOPSTheme.textPrimary)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(selectedOpportunityType != nil ? StudentOPSTheme.primary : StudentOPSTheme.surface)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var localRankedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECOMMENDED").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                if !revenueCatManager.isPro {
                    ProBadge()
                }
            }
            // PRO 4 — Opportunity Matching: gate match intelligence, keep browse facts free
            if revenueCatManager.isPro {
                ForEach(rankedOpportunities) { ranked in
                    OpportunityCard(ranked: ranked, isSaved: store.isSaved(ranked.opportunity), onSave: { store.toggleSaved(ranked.opportunity) }, onView: { selectedRanked = ranked })
                }
            } else {
                // Free: show locked preview + factual list (no match %)
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill").foregroundColor(StudentOPSTheme.primaryDark)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Opportunity Matching").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            Text("See why this fits you • Career & skill alignment").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                        Spacer()
                        ProBadge()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    .padding(12)
                    .background(StudentOPSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
                }.buttonStyle(.plain)
                ForEach(rankedOpportunities.prefix(5)) { ranked in
                    // Fact-only card for Free (no match %)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(ranked.opportunity.opportunityType.rawValue.capitalized).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 7).padding(.vertical, 3).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                            Spacer()
                            Text(ranked.opportunity.legacyDeadline).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        }
                        Text(ranked.opportunity.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(2)
                        if !ranked.opportunity.organization.isEmpty {
                            Text(ranked.opportunity.organization).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).lineLimit(1)
                        }
                        Text(ranked.opportunity.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                        HStack {
                            Text(ranked.opportunity.legacyLocation).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                            Spacer()
                            Button { selectedRanked = ranked } label: {
                                Text("View").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                            }.buttonStyle(.plain)
                            Button { store.toggleSaved(ranked.opportunity) } label: {
                                Image(systemName: store.isSaved(ranked.opportunity) ? "bookmark.fill" : "bookmark").foregroundColor(StudentOPSTheme.primaryDark)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(StudentOPSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallHostView().environmentObject(revenueCatManager)
        }
    }

    private var localEmpty: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 26)).foregroundColor(StudentOPSTheme.primaryDark)
            Text("No opportunities match your filters").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            Text("Try adjusting your search or filters.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            Button { selectedRankedFilter = .all; selectedOpportunityType = nil; searchText = "" } label: {
                Text("Clear Filters").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
            }.buttonStyle(.plain).padding(.top, 4)
        }.frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    // MARK: - Remote Content (legacy fallback)

    private var remoteContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                statsBar
                filterChips
                ForEach(sections) { section in
                    exploreSection(section)
                }
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
        }
        .refreshable { await viewModel.refresh(profile: store.profile) }
    }

    // MARK: - Legacy Header/Sections (preserved)

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Opportunities matched to your goals").font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary)
                Spacer()
                Text("\(totalCount) paths").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(StudentOPSTheme.textSecondary)
                    TextField("Search opportunities", text: $searchText).font(DashFont.bodySm())
                }.padding(.horizontal, 12).frame(height: 44).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.55))).clipShape(RoundedRectangle(cornerRadius: 12))
                Button { showFilters = true } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle").font(.system(size: 19, weight: .medium)).foregroundColor(StudentOPSTheme.primaryDark).frame(width: 44, height: 44).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.55)))
                }.buttonStyle(.plain)
            }
            if selectedCategory != .all {
                Button { selectedCategory = .all } label: {
                    Label("\(selectedCategory.rawValue) · Clear", systemImage: "xmark.circle.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }.buttonStyle(.plain)
            }
        }
    }

    private var statsBar: some View {
        guard let stats = feed?.stats else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(spacing: 12) {
                statPill(label: "Eligible", value: "\(stats.eligible)", color: StudentOPSTheme.success)
                statPill(label: "Match", value: "\(stats.avgMatchScore)%", color: StudentOPSTheme.primaryDark)
                statPill(label: "Unknown", value: "\(stats.unknown)", color: StudentOPSTheme.warning)
            }
        )
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value).font(DashFont.labelMono()).foregroundColor(color)
            Text(label).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
        }.padding(.horizontal, 10).padding(.vertical, 5).background(StudentOPSTheme.surface).clipShape(Capsule())
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExploreFilter.allCases, id: \.self) { filter in
                    Button { selectedFilter = filter } label: {
                        Text(filter.rawValue)
                            .font(DashFont.labelMd())
                            .foregroundColor(selectedFilter == filter ? StudentOPSTheme.textOnPrimary : StudentOPSTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(selectedFilter == filter ? StudentOPSTheme.primary : StudentOPSTheme.surface)
                            .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func exploreSection(_ section: FeedSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: section.title, subtitle: section.subtitle)
            if section.id == "forYou" || section.id == "deadlineSoon" {
                ForEach(section.opportunities.prefix(5)) { p in
                    OpportunityCard(personalized: p, isSaved: store.isSaved(p.opportunity), onSave: { store.toggleSaved(p.opportunity) }, onView: { selectedPersonalized = p })
                }
                if section.opportunities.count > 5 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(section.opportunities.dropFirst(5)) { p in
                                OpportunityCard(personalized: p, isSaved: store.isSaved(p.opportunity), onSave: { store.toggleSaved(p.opportunity) }, onView: { selectedPersonalized = p }).frame(width: 310)
                            }
                        }
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(section.opportunities.prefix(10)) { p in
                            OpportunityCard(personalized: p, isSaved: store.isSaved(p.opportunity), onSave: { store.toggleSaved(p.opportunity) }, onView: { selectedPersonalized = p }).frame(width: 310)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(DashFont.labelMono()).tracking(1).foregroundColor(StudentOPSTheme.textSecondary)
            Text(subtitle).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }
    }

    private func matchesCategory(_ opp: RemoteOpportunity, _ category: OpportunityCategory) -> Bool {
        if category == .all { return true }
        let backendCat = opp.category.lowercased()
        switch category {
        case .competitions: return backendCat == "competition"
        case .scholarships: return backendCat == "scholarship"
        case .research: return backendCat == "research"
        case .volunteering: return backendCat == "volunteering"
        case .leadership: return backendCat == "leadership"
        case .summerPrograms: return backendCat == "summerprogram"
        case .academicPrograms: return backendCat == "academicprogram"
        default: return backendCat == category.rawValue.lowercased()
        }
    }

    private func matchesFilter(_ p: PersonalizedOpportunity) -> Bool {
        switch selectedFilter {
        case .all: return true
        case .free: return p.opportunity.cost.isFree == true
        case .scholarships: return p.opportunity.category.lowercased() == "scholarship"
        case .competitions: return p.opportunity.category.lowercased() == "competition"
        case .hackathons: return p.opportunity.category.lowercased() == "hackathon"
        case .online: return p.opportunity.location.online == true || p.opportunity.location.type == "online"
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(StudentOPSTheme.primaryDark).scaleEffect(1.2)
            Text("Loading opportunities…").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 60)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 26)).foregroundColor(StudentOPSTheme.primaryDark)
            Text("Unable to load opportunities.").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            Text(message).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 24)
            Button { Task { await viewModel.loadInitial(profile: store.profile) } } label: {
                Text("Try Again").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textOnPrimary).padding(.horizontal, 20).padding(.vertical, 10).background(StudentOPSTheme.primary).clipShape(Capsule())
            }.buttonStyle(.plain)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 26)).foregroundColor(StudentOPSTheme.primaryDark)
            Text("No opportunities match your filters").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            Text("Try adjusting your search or filters.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            Button { selectedCategory = .all; selectedFilter = .all; searchText = "" } label: {
                Text("Clear Filters").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
            }.buttonStyle(.plain).padding(.top, 4)
        }.frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}
