import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @StateObject private var vm: DashboardViewModel
    @State private var selectedTab: DashboardTab = .home
    @State private var selectedAchievement: Achievement?
    @State private var selectedEvidence: EvidenceRecord?
    @State private var homePresentedProject: ScoredProject?
    @State private var homePresentedRoadmap: ScoredRoadmap?
    @State private var homePresentedSkill: Skill?
    @State private var homePresentedOpportunity: RankedOpportunity?
    @State private var homePresentedCareer: Career?
    #if DEBUG
    @State private var showPaywall = false
    #endif

    init() {
        _vm = StateObject(wrappedValue: DashboardViewModel(profile: StudentProfile()))
    }

    var body: some View {
        VStack(spacing: 0) {
            if selectedTab == .home {
                homeContent
            } else if selectedTab == .explore {
                ExploreView()
            } else if selectedTab == .roadmaps {
                RoadmapsView()
            } else if selectedTab == .projects {
                ProjectsView()
            } else if selectedTab == .progress {
                ProgressProfileView(profile: $store.profile)
            } else {
                dashboardTabPlaceholder
            }
            BottomTabBar(selectedTab: $selectedTab)
        }
        .background(StudentOPSTheme.background.ignoresSafeArea())
        .onAppear {
            vm.update(with: store)
        }
        .onChange(of: store.profile) { _, _ in
            vm.update(with: store)
        }
        .onChange(of: store.roadmapProgress) { _, _ in
            vm.update(with: store)
        }
        .onChange(of: store.projectProgress) { _, _ in
            vm.update(with: store)
        }
        .onChange(of: store.customProjects) { _, _ in
            vm.update(with: store)
        }
        .onChange(of: store.savedOpportunityIDs) { _, _ in
            vm.update(with: store)
        }
        .onChange(of: store.activeRoadmaps) { _, _ in
            vm.update(with: store)
        }
        .onChange(of: store.completedActionIDs) { _, _ in
            vm.update(with: store)
        }
    }

    private var homeContent: some View {
        VStack(spacing: 0) {
            TopHeaderBar(hasUnreadNotifications: vm.notificationsUnread)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: StudentOPSTheme.sectionSpacing) {
                    GreetingHeaderView(dateLabel: vm.dateLabel, firstName: vm.studentFirstName, statusSummary: vm.statusSummary)

                    // HERO: NEXT ACTION — single dominant card answers What should I do next?
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("UP NEXT").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                            Spacer()
                            Image(systemName: "arrow.down.right").foregroundColor(StudentOPSTheme.primaryDark.opacity(0.4))
                        }
                        if let next = vm.nextBestAction {
                            NextBestActionHeroCard(action: next) { handleNextBestTap(next) }
                            // Phase 5: Why this? — concrete connection: Goal → Gap → Project
                            if let gap = store.nextSkills(limit: 1).first {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.right.circle.fill").foregroundColor(StudentOPSTheme.primaryDark).font(.system(size: 11))
                                    Text("Why this? Builds \(gap.skillName) for \(store.profile.careers.first ?? "your goal")")
                                        .font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(StudentOPSTheme.primaryDark.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            // One secondary only, de-emphasized
                            if vm.nextBestActions.count > 1, let second = vm.nextBestActions.dropFirst().first {
                                Button { handleNextBestTap(second) } label: {
                                    HStack(spacing: 8) {
                                        Text("Next:").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                        Text(second.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .background(StudentOPSTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.35)))
                                }.buttonStyle(.plain)
                            }
                        } else {
                            NextStepCard(task: vm.nextStep, buttonState: vm.nextStepButtonState, onTap: vm.tapNextStepCta)
                        }
                    }

                    // YOUR FOCUS — single compact card replaces 3 equal-weight sections
                    yourFocusSection

                    // Demo story chain — makes Career → Skill → Roadmap → Project → Opportunity → Progress obvious
                    demoStoryChainSection

                    // CURRENT PATH — keep prominent but compact hero
                    PathHeroView(path: vm.path) { selectedTab = .roadmaps }

                    // PROGRESS — compact single line + metric strip (was 3 cards + portfolio banner competing)
                    progressCompactSection

                    // ONE OPPORTUNITY — compact, not large card deck
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("OPPORTUNITY").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                            Spacer()
                            Button("Explore") { selectedTab = .explore }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
                        }
                        OpportunityCardCompact(opportunity: vm.opportunity, onView: { selectedTab = .explore })
                    }

                    // Recent — single row each, not paired sections with equal weight
                    if !store.allAchievementsSorted.isEmpty || !store.allEvidenceSorted.isEmpty {
                        HStack(spacing: 12) {
                            if let ach = store.allAchievementsSorted.first {
                                Button { selectedAchievement = ach } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("ACHIEVEMENT").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                        Text(ach.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(2)
                                    }
                                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
                                }.buttonStyle(.plain)
                            }
                            if let ev = store.allEvidenceSorted.first {
                                Button { selectedEvidence = ev } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("EVIDENCE").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                        Text(ev.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(2)
                                    }
                                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
                                }.buttonStyle(.plain)
                            }
                        }
                    }

                    // #if DEBUG
                    // // Phase 2: DEBUG-only paywall test entry — isolated, not permanent Home UI for release
                    // VStack(alignment: .leading, spacing: 8) {
                    //     HStack {
                    //         Text("DEBUG — MONETIZATION").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    //         Spacer()
                    //         Text(revenueCatManager.isPro ? "Pro ✓" : "Free").font(DashFont.captionMono()).foregroundColor(revenueCatManager.isPro ? .green : .secondary)
                    //     }
                    //     Button {
                    //         showPaywall = true
                    //     } label: {
                    //         HStack {
                    //             Image(systemName: "creditcard")
                    //             Text("Test Paywall (sale)")
                    //             Spacer()
                    //             Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    //         }
                    //         .font(DashFont.labelMd())
                    //         .foregroundColor(StudentOPSTheme.textPrimary)
                    //         .padding(12)
                    //         .background(StudentOPSTheme.surface)
                    //         .clipShape(RoundedRectangle(cornerRadius: 10))
                    //         .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
                    //     }.buttonStyle(.plain)
                    //     Text("Offering: sale • Products: monthly_subscription, yearly_susbcription → studentops_pro")
                    //         .font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    // }
                    // .padding(12)
                    // .background(Color.yellow.opacity(0.08))
                    // .clipShape(RoundedRectangle(cornerRadius: 12))
                    // .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2)))
                    // #endif
                }.padding(.horizontal, StudentOPSTheme.gutter).padding(.top, 12).padding(.bottom, 24)
            }
            .sheet(item: $selectedAchievement) { ach in NavigationStack { AchievementDetailView(achievement: ach).environmentObject(store) } }
            .sheet(item: $selectedEvidence) { rec in EvidenceDetailSheet(record: rec).environmentObject(store) }
            .sheet(item: $homePresentedProject) { sp in NavigationStack { ProjectDetailView(scoredProject: sp).environmentObject(store).environmentObject(revenueCatManager) } }
            .sheet(item: $homePresentedRoadmap) { sr in NavigationStack { RoadmapDetailView(scoredRoadmap: sr).environmentObject(store).environmentObject(revenueCatManager) } }
            .sheet(item: $homePresentedSkill) { skill in NavigationStack { SkillDetailView(skill: skill).environmentObject(store).environmentObject(revenueCatManager) } }
            .sheet(item: $homePresentedCareer) { career in NavigationStack { CareerDetailView(career: career).environmentObject(store).environmentObject(revenueCatManager) } }
            .sheet(item: $homePresentedOpportunity) { ranked in NavigationStack { OpportunityDetailView(ranked: ranked).environmentObject(store).environmentObject(revenueCatManager) } }
            #if DEBUG
            .sheet(isPresented: $showPaywall) {
                PaywallHostView()
                    .environmentObject(revenueCatManager)
            }
            #endif
        }
    }

    private var yourFocusSection: some View {
        let career = store.profile.careers.first ?? store.profile.fields.first ?? "Explore direction"
        let nextSkill = store.nextSkills(limit: 1).first?.skillName ?? "Add interests to see next skill"
        return Button { selectedTab = .progress } label: {
            HStack(spacing: 12) {
                Circle().fill(StudentOPSTheme.primary.opacity(0.12)).frame(width: 36, height: 36).overlay(Image(systemName: "target").foregroundColor(StudentOPSTheme.primaryDark))
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOUR FOCUS").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text(career).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                    Text(nextSkill).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
            }
            .padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard)).overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard).stroke(StudentOPSTheme.border.opacity(0.4)))
        }.buttonStyle(.plain).accessibilityLabel(Text("Your focus: \(career)"))
    }

    private var demoStoryChainSection: some View {
        // Phase 5: Makes Career → Skill → Roadmap → Project → Opportunity → Progress obvious
        // Uses existing deterministic store data — for Alex this is SE → Data Structures → DS Project → DS Hackathon
        let careerTitle = store.profile.careers.first ?? "Software Engineering"
        let gap = store.nextSkills(limit: 1).first
        let gapName = gap?.skillName ?? "Data Structures"
        let gapSkill = gap.flatMap { SkillCatalog.knownSkills[$0.skillID] } ?? Skill(id: gap?.skillID ?? "data-structures", name: gapName)
        let projectRec = ProjectRecommendationEngine.recommendations(for: store, limit: 1).first
        let projectTitle = projectRec?.project.title ?? "DS Project"
        let projectScored: ScoredProject? = projectRec.map { ScoredProject(project: $0.project, matchScore: $0.score, completedMilestones: 0) } ?? store.scoredProjects.first(where: { $0.project.title == projectTitle })
        let rankedOpp = store.rankedOpportunities().first
        let opportunityTitle = rankedOpp?.opportunity.title ?? "DS Hackathon"
        let roadmapScored = store.activatedRoadmaps.first ?? store.scoredRoadmaps.first(where: { $0.id == "software-engineer" })
        let roadmapTitle = roadmapScored?.roadmap.title ?? "Software Engineering"
        let careerObj = CareerCatalog.career(for: "software-engineering") ?? CareerCatalog.all.first
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR PATH").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("Tap to explore").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            VStack(spacing: 0) {
                chainRow(icon: "briefcase", title: careerTitle, subtitle: "Career direction", color: StudentOPSTheme.primaryDark, action: {
                    if let c = careerObj { homePresentedCareer = c } else { selectedTab = .progress }
                })
                chainConnector
                chainRow(icon: "brain.head.profile", title: gapName, subtitle: "Next skill to learn", color: StudentOPSTheme.warning, action: {
                    homePresentedSkill = gapSkill
                })
                chainConnector
                chainRow(icon: "point.3.connected.trianglepath.dotted", title: roadmapTitle, subtitle: "1/6 milestones • Up Next: \(gapName)", color: StudentOPSTheme.primary, action: {
                    if let r = roadmapScored { homePresentedRoadmap = r } else { selectedTab = .roadmaps }
                })
                chainConnector
                chainRow(icon: "hammer", title: projectTitle, subtitle: "Builds \(gapName)", color: StudentOPSTheme.primaryDark, action: {
                    if let p = projectScored { homePresentedProject = p } else { selectedTab = .projects }
                })
                chainConnector
                chainRow(icon: "star", title: opportunityTitle, subtitle: "Apply your \(gapName) skills", color: StudentOPSTheme.success, action: {
                    if let o = rankedOpp { homePresentedOpportunity = o } else { selectedTab = .explore }
                })
            }
            .padding(12)
            .background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.35)))
        }
    }

    private var chainConnector: some View {
        HStack {
            Spacer().frame(width: 18)
            Rectangle().fill(StudentOPSTheme.border.opacity(0.4)).frame(width: 1, height: 10)
            Spacer()
        }
    }

    private func chainRow(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().fill(color.opacity(0.12)).frame(width: 28, height: 28).overlay(Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                    Text(subtitle).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.buttonStyle(.plain)
    }

    private var progressCompactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PROGRESS").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Button("View") { selectedTab = .progress }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                ForEach(vm.metrics.prefix(3)) { metric in MetricCard(metric: metric) }
            }
            // Portfolio CTA only when very low completeness, placed here low-visual-weight
            if shouldShowPortfolioCTA {
                Button { selectedTab = .progress } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.ellipsis").foregroundColor(StudentOPSTheme.primaryDark)
                        Text(portfolioCTASubtitle).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        Spacer()
                        Text("Build").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                    }.padding(.horizontal, 12).padding(.vertical, 10).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
                }.buttonStyle(.plain)
            }
        }
    }

    private var recentAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT ACHIEVEMENTS").font(DashFont.labelMono()).tracking(1).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                if store.achievementRecords.count > 2 {
                    Button("See All") { selectedTab = .progress }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
                }
            }
            if store.achievementRecords.isEmpty {
                Text("Complete milestones and projects to earn achievements.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(store.allAchievementsSorted.prefix(2)) { ach in
                    Button { selectedAchievement = ach } label: { AchievementRowView(achievement: ach) }.buttonStyle(.plain)
                }
            }
        }
    }

    private var recentEvidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT EVIDENCE").font(DashFont.labelMono()).tracking(1).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                if store.evidenceRecords.count > 2 {
                    Button("See All") { selectedTab = .progress }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
                }
            }
            if store.evidenceRecords.isEmpty {
                Text("No evidence yet.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                ForEach(store.allEvidenceSorted.prefix(2)) { rec in
                    Button { selectedEvidence = rec } label: { EvidenceRowView(record: rec) }.buttonStyle(.plain)
                }
            }
        }
    }

    private func handleNextBestTap(_ action: NextBestAction) {
        // Phase 5: Avoid dead-end cards — open actual project/roadmap directly when possible
        switch action.destinationEnum {
        case .roadmaps:
            selectedTab = .roadmaps
        case .roadmapDetail(let roadmapID):
            if let sr = store.scoredRoadmaps.first(where: { $0.id == roadmapID }) ?? store.activatedRoadmaps.first(where: { $0.id == roadmapID }) {
                homePresentedRoadmap = sr
            } else {
                selectedTab = .roadmaps
            }
        case .milestoneDetail(let roadmapID, _):
            if let sr = store.scoredRoadmaps.first(where: { $0.id == roadmapID }) ?? store.activatedRoadmaps.first(where: { $0.id == roadmapID }) {
                homePresentedRoadmap = sr
            } else {
                selectedTab = .roadmaps
            }
        case .projectDetail(let projectID):
            if let sp = store.scoredProjects.first(where: { $0.project.id == projectID }) {
                homePresentedProject = sp
            } else if let proj = store.customProjects.first(where: { $0.id == projectID }) {
                homePresentedProject = ScoredProject(project: proj, matchScore: ProjectService.matchScore(for: proj, profile: store.profile), completedMilestones: store.completedCount(for: proj))
            } else {
                selectedTab = .projects
            }
        case .opportunityDetail, .explore:
            selectedTab = .explore
        }
    }

    private var shouldShowPortfolioCTA: Bool {
        if store.allPortfoliosSorted.isEmpty { return true }
        guard let first = store.allPortfoliosSorted.first else { return false }
        let result = PortfolioQualityEngine.evaluate(for: first, store: store)
        return result.percent < 40
    }

    private var portfolioCTASubtitle: String {
        if store.allPortfoliosSorted.isEmpty { return "Create your first portfolio from real work." }
        return "Your portfolio could be stronger — add projects and evidence."
    }

    private var dashboardTabPlaceholder: some View {
        VStack(spacing: 12) {
            TopHeaderBar(hasUnreadNotifications: vm.notificationsUnread)
            Spacer()
            Image(systemName: selectedTab.icon).font(.system(size: 30)).foregroundColor(StudentOPSTheme.primaryDark)
            Text(selectedTab.title).font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary)
            Text("This Student OPS workspace is ready for your next move.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            Spacer()
        }
    }
}
