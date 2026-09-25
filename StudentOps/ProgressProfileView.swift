import SwiftUI

struct ProgressProfileView: View {
    @Binding var profile: StudentProfile
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @State private var showingEdit = false
    @State private var showEvidenceForm = false
    @State private var selectedEvidence: EvidenceRecord?
    @State private var selectedAchievement: Achievement?
    @State private var showAllEvidence = false
    @State private var showAllAchievements = false
    @State private var selectedProject: ScoredProject?
    @State private var selectedRoadmap: ScoredRoadmap?
    @State private var showAllProjects = false
    @State private var showAllRoadmaps = false
    @State private var showSettings = false

    private var legacyAchievements: [Achievement] { store.achievements }
    private var canonicalAchievements: [Achievement] { store.allAchievementsSorted }
    private var completedMilestones: Int { store.completedMilestonesTotal }
    private var activeRoadmaps: Int { store.activatedRoadmaps.count }
    private var completedProjects: Int { store.completedProjects.count }
    private var skillCount: Int { store.skillSet.count }

    // Derived snapshot (not persisted)
    private var snapshot: StudentProfileSnapshot {
        StudentProfileSnapshot.make(from: store)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: StudentOPSTheme.sectionSpacing) {
                    ProfileHeaderView(profile: profile, onEdit: { showingEdit = true }, onSettings: { showSettings = true })
                    // Phase 4: Clean subscription status (Free/Pro) in existing Profile area — not a new tab
                    SubscriptionStatusView()
                    completenessSection
                    yourProgressSection
                    // PRO 6 — Progress & Evidence Intelligence (skill coverage, gap connections, portfolio/evidence relationships)
                    PremiumFeatureGateWithPreview(feature: .progressEvidence, previewTitle: "Progress Intelligence", previewSubtitle: "Skill coverage and portfolio insights") {
                        skillIntelligenceCompact
                    }
                    activePathsSection
                    achievementsSection
                    evidenceSection
                    // Profile details behind single disclosure (was 4 separate blocks)
                    profileDetailsDisclosure
                    // Keep legacy hidden unless present
                    if !legacyAchievements.isEmpty { legacySection }
                }.padding(.horizontal, StudentOPSTheme.gutter).padding(.top, 12).padding(.bottom, 24)
            }
            .background(StudentOPSTheme.background.ignoresSafeArea())
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape").foregroundColor(StudentOPSTheme.textSecondary) }.accessibilityLabel("Open Settings")
                }
            }
            .sheet(isPresented: $showingEdit) { ProfileEditView(profile: $profile).environmentObject(store) }
            .sheet(isPresented: $showEvidenceForm) { EvidenceFormView().environmentObject(store) }
            .sheet(item: $selectedEvidence) { rec in EvidenceDetailSheet(record: rec).environmentObject(store) }
            .sheet(item: $selectedAchievement) { ach in
                NavigationStack { AchievementDetailView(achievement: ach).environmentObject(store) }
            }
            .sheet(item: $selectedProject) { sp in
                NavigationStack { ProjectDetailView(scoredProject: sp).environmentObject(store).environmentObject(revenueCatManager) }
            }
            .sheet(item: $selectedRoadmap) { sr in
                NavigationStack { RoadmapDetailView(scoredRoadmap: sr).environmentObject(store).environmentObject(revenueCatManager) }
            }
            .sheet(isPresented: $showAllEvidence) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.allEvidenceSorted) { rec in
                                Button { selectedEvidence = rec } label: { EvidenceRowView(record: rec) }.buttonStyle(.plain)
                            }
                        }.padding(16)
                    }
                    .background(StudentOPSTheme.background.ignoresSafeArea())
                    .navigationTitle("All Evidence")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showAllEvidence = false } } }
                }
            }
            .sheet(isPresented: $showAllAchievements) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(canonicalAchievements) { ach in
                                Button { selectedAchievement = ach } label: { AchievementRowView(achievement: ach) }.buttonStyle(.plain)
                            }
                        }.padding(16)
                    }
                    .background(StudentOPSTheme.background.ignoresSafeArea())
                    .navigationTitle("All Achievements")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showAllAchievements = false } } }
                }
            }
            .sheet(isPresented: $showAllProjects) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.scoredProjects) { sp in
                                ProjectProfileRow(project: sp)
                                    .onTapGesture { selectedProject = sp }
                            }
                        }.padding(16)
                    }
                    .background(StudentOPSTheme.background.ignoresSafeArea())
                    .navigationTitle("All Projects")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showAllProjects = false } } }
                }
            }
            .sheet(isPresented: $showAllRoadmaps) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.activatedRoadmaps) { sr in
                                RoadmapCard(roadmap: sr) { selectedRoadmap = sr }
                            }
                        }.padding(16)
                    }
                    .background(StudentOPSTheme.background.ignoresSafeArea())
                    .navigationTitle("Active Roadmaps")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showAllRoadmaps = false } } }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(revenueCatManager)
                    .environmentObject(appearanceManager)
            }
            .onAppear {
                store.refreshGeneratedAchievements()
                _ = store.reconcileEvidenceAchievements()
            }
        }
    }

    // MARK: - Completeness (deterministic, factual)

    private var completenessSection: some View {
        let c = snapshot.completeness
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PROFILE COMPLETENESS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("\(c.percent)%").font(DashFont.labelMono()).foregroundColor(c.isComplete ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
            }
            GeometryReader { proxy in
                Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                    Capsule().fill(c.isComplete ? StudentOPSTheme.success : StudentOPSTheme.primary).frame(width: proxy.size.width * CGFloat(c.percent) / 100)
                }
            }.frame(height: 6)
            FlowLayout(spacing: 6) {
                ForEach(c.dimensions) { dim in
                    HStack(spacing: 4) {
                        Image(systemName: dim.completed ? "checkmark.circle.fill" : "circle").font(.system(size: 10, weight: .bold)).foregroundColor(dim.completed ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
                        Text(dim.title).font(DashFont.labelMono()).foregroundColor(dim.completed ? StudentOPSTheme.textPrimary : StudentOPSTheme.textSecondary)
                    }.padding(.horizontal, 8).padding(.vertical, 5).background(dim.completed ? StudentOPSTheme.success.opacity(0.08) : StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 6).stroke(dim.completed ? StudentOPSTheme.success.opacity(0.3) : StudentOPSTheme.border))
                }
            }
            if c.percent < 100 {
                Text("Add interests, goals, or record work to grow your profile. Completeness reflects available information, not readiness.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.6)))
    }

    private var yourProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YOUR PROGRESS").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("\(snapshot.progress.overallProgress)% overall").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Milestones").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("\(snapshot.progress.completedMilestones) completed • \(snapshot.progress.totalMilestones - snapshot.progress.completedMilestones) remaining • \(snapshot.progress.totalMilestones) total").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textPrimary)
                    Spacer()
                }
                HStack(spacing: 6) {
                    Text("Projects").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("\(snapshot.progress.completedProjects) completed • \(snapshot.progress.activeProjects) active of \(snapshot.progress.totalProjects) total").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textPrimary)
                    Spacer()
                }
                if store.customProjects.contains(where: { $0.id == "demo-ds-project" }) && snapshot.progress.activeProjects > 0 {
                    Text("Includes DS Project (in progress)").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.35)))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ProgressMetricCard(label: "Achievements", value: "\(store.achievementRecords.count)", detail: "earned", icon: "star.fill", tint: StudentOPSTheme.warning).frame(width: 110)
                    ProgressMetricCard(label: "Evidence", value: "\(store.evidenceRecords.count)", detail: "recorded", icon: "doc.badge.ellipsis", tint: StudentOPSTheme.primary).frame(width: 110)
                    ProgressMetricCard(label: "Skills", value: "\(snapshot.demonstratedSkillIDs.count)", detail: "skills", icon: "checkmark.seal", tint: StudentOPSTheme.success).frame(width: 110)
                }
            }
        }
    }

    // Keep legacy name for compatibility but hide (not used now)
    private var metricsSection: some View { yourProgressSection }

    private var skillIntelligenceCompact: some View {
        let coverage = store.skillCoverage()
        let gaps = store.skillGaps()
        let next = store.nextSkills(limit: 1).first
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SKILL INTELLIGENCE").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("\(Int(coverage.coverage*100))% coverage").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark)
            }
            HStack(spacing: 8) {
                Text("\(coverage.coveredCount) developed").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.success)
                Text("•").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                Text("\(gaps.count) gaps").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.warning)
                if let n = next {
                    Text("•").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Next: \(n.skillName)").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 8).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.35)))
            if let gap = gaps.first {
                NavigationLink(destination: SkillDetailView(skill: SkillCatalog.knownSkills[gap.skillID] ?? Skill(id: gap.skillID, name: gap.skillName)).environmentObject(store)) {
                    HStack(spacing: 10) {
                        Circle().fill(StudentOPSTheme.warning).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Top gap: \(gap.skillName)").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                            Text(gap.gapReason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    .padding(10).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.warning.opacity(0.2)))
                }.buttonStyle(.plain)
            }
            if gaps.count > 1 || !coverage.coveredSkills.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        if !coverage.coveredSkills.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(coverage.coveredSkills.prefix(4), id: \.self) { sid in
                                    let name = SkillCatalog.knownSkills[sid]?.name ?? sid
                                    NavigationLink(destination: SkillDetailView(skill: SkillCatalog.knownSkills[sid] ?? Skill(id: sid, name: name)).environmentObject(store)) {
                                        Label(name, systemImage: "checkmark.circle.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.success).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.success.opacity(0.1)).clipShape(Capsule())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        if gaps.count > 1 {
                            ForEach(gaps.dropFirst().prefix(2), id: \.skillID) { gap in
                                NavigationLink(destination: SkillDetailView(skill: SkillCatalog.knownSkills[gap.skillID] ?? Skill(id: gap.skillID, name: gap.skillName)).environmentObject(store)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(gap.skillName).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                                        Text(gap.gapReason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                                    }
                                    .padding(8).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border.opacity(0.4)))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                } label: {
                    Text("See all skill details").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }.tint(StudentOPSTheme.textSecondary)
            }
            Text("Catalog data, not live labor-market").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
        }
        .padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
    }

    private var skillIntelligenceSection: some View { skillIntelligenceCompact }

    private var profileDetailsDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 16) {
                interestsSection
                careerDirectionSection
                goalsSection
                SkillsSection(profile: profile)
                PortfolioEntrySection()
            }
        } label: {
            HStack {
                Text("PROFILE DETAILS").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Image(systemName: "person.crop.circle").foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.tint(StudentOPSTheme.textSecondary)
        .padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.35)))
    }

    // MARK: - Interests

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("INTERESTS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Button("Edit") { showingEdit = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
            }
            if profile.interests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add topics you find exciting to personalize roadmaps and opportunities.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    Button("Edit interests") { showingEdit = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(profile.interests, id: \.self) { item in
                        Text(item).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textPrimary).padding(.horizontal, 10).padding(.vertical, 6).background(StudentOPSTheme.primary.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.primary.opacity(0.2)))
                    }
                }
                if !profile.customInterests.isEmpty {
                    Text("Custom: \(profile.customInterests.joined(separator: ", "))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
            }
        }
    }

    private var careerDirectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CAREER DIRECTION").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Button("Edit") { showingEdit = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
            }
            if profile.careers.isEmpty && profile.fields.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select career interests or fields of study to guide your path.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    Button("Edit career direction") { showingEdit = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                if !profile.careers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Careers").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        FlowLayout(spacing: 6) {
                            ForEach(profile.careers, id: \.self) { c in
                                Text(c).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textPrimary).padding(.horizontal, 10).padding(.vertical, 6).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border))
                            }
                        }
                    }
                }
                if !profile.fields.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fields").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        FlowLayout(spacing: 6) {
                            ForEach(profile.fields, id: \.self) { f in
                                Text(f).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textPrimary).padding(.horizontal, 10).padding(.vertical, 6).background(StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border))
                            }
                        }
                    }
                }
                if profile.notSureYet {
                    Label("Exploring options", systemImage: "lightbulb").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GOALS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Button("Edit") { showingEdit = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
            }
            if profile.milestones.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add goals like \"Build real projects\" or \"Prepare for college\" to shape your direction.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    Button("Edit goals") { showingEdit = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(profile.milestones, id: \.self) { g in
                        Label(g, systemImage: "target").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                    }
                }
                .padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if profile.collegePlan != .notSure || !profile.targetColleges.isEmpty || !profile.geography.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if profile.collegePlan != .notSure {
                        Text("College plan: \(profile.collegePlan.rawValue)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    if !profile.geography.isEmpty { Text("Location: \(profile.geography)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                    if !profile.collegeType.isEmpty { Text("Type: \(profile.collegeType)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                    if !profile.targetColleges.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(profile.targetColleges, id: \.self) { col in
                                Text(col).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textPrimary).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: 6).stroke(StudentOPSTheme.border))
                            }
                        }
                    }
                }.padding(12).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Active Roadmaps

    private var activePathsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACTIVE ROADMAPS").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Roadmaps you are actively working on").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
                if store.activatedRoadmaps.count > 2 {
                    Button("See All") { showAllRoadmaps = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            if store.activatedRoadmaps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No active roadmaps. Start a roadmap to see progress here.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    NavigationLink(destination: RoadmapsView().environmentObject(store)) {
                        Label("Explore roadmaps", systemImage: "point.3.connected.trianglepath.dotted").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                    }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(store.activatedRoadmaps.prefix(2)) { sr in
                    Button { selectedRoadmap = sr } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(sr.roadmap.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                                Spacer()
                                Text("\(sr.progress)%").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.primary.opacity(0.12)).clipShape(Capsule())
                            }
                            Text(sr.roadmap.goal).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                            GeometryReader { proxy in
                                Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                                    Capsule().fill(StudentOPSTheme.primary).frame(width: proxy.size.width * CGFloat(sr.progress) / 100)
                                }
                            }.frame(height: 6)
                            HStack {
                                Text("\(sr.completedMilestones) of \(sr.roadmap.milestones.count) milestones").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                Spacer()
                                if let current = sr.currentMilestone {
                                    Text("Next: \(current.title)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                                }
                            }
                        }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border))
                    }.buttonStyle(.plain)
                }
                if store.activatedRoadmaps.count > 2 {
                    Text("+\(store.activatedRoadmaps.count - 2) more active").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PROJECTS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Work you have started or completed").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
                if store.scoredProjects.count > 2 {
                    Button("See All") { showAllProjects = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            if store.scoredProjects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No projects yet. Projects help you turn skills into shareable work.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    NavigationLink(destination: ProjectsView().environmentObject(store)) {
                        Label("Add a project", systemImage: "hammer").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                    }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(store.scoredProjects.prefix(2)) { sp in
                    ProjectProfileRow(project: sp)
                        .onTapGesture { selectedProject = sp }
                }
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACHIEVEMENTS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Meaningful accomplishments backed by evidence").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
                if canonicalAchievements.count > 3 {
                    Button("See All") { showAllAchievements = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            if canonicalAchievements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complete milestones and projects to earn achievements.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    NavigationLink(destination: RoadmapsView().environmentObject(store)) {
                        Label("Explore Roadmaps", systemImage: "point.3.connected.trianglepath.dotted").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                    }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(canonicalAchievements.prefix(3)) { ach in
                    Button { selectedAchievement = ach } label: { AchievementRowView(achievement: ach) }.buttonStyle(.plain)
                }
                if canonicalAchievements.count > 3 {
                    Text("+\(canonicalAchievements.count - 3) more").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("EVIDENCE").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Proof of real work you have completed").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
                if store.allEvidenceSorted.count > 3 {
                    Button("See All") { showAllEvidence = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                } else {
                    Text("\(store.evidenceRecords.count) recorded").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
                }
            }
            Button(action: { showEvidenceForm = true }) {
                Label("Add Evidence", systemImage: "plus.circle.fill")
                    .font(DashFont.labelMd())
                    .foregroundColor(StudentOPSTheme.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(StudentOPSTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
            if store.allEvidenceSorted.isEmpty {
                Text("No evidence yet. Complete a roadmap milestone or record work you have actually done.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(store.allEvidenceSorted.prefix(3)) { rec in
                    Button { selectedEvidence = rec } label: { EvidenceRowView(record: rec) }
                        .buttonStyle(.plain)
                }
                if store.allEvidenceSorted.count > 3 {
                    Text("+\(store.allEvidenceSorted.count - 3) more").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var legacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ONBOARDING EXPERIENCES").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("\(legacyAchievements.count) recorded").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            ForEach(legacyAchievements) { AchievementRow(achievement: $0) }
        }
    }

    private var profileDirectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROFILE DIRECTION").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            if profile.careers.isEmpty && profile.fields.isEmpty && profile.milestones.isEmpty {
                Text("Add career interests and goals to shape your profile direction.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                Button("Edit profile") { showingEdit = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
            } else {
                if !profile.careers.isEmpty {
                    Text(profile.careers.joined(separator: " · ")).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                }
                if !profile.fields.isEmpty {
                    Text("Interested fields: \(profile.fields.joined(separator: ", "))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                if !profile.milestones.isEmpty {
                    Text("Goals: \(profile.milestones.joined(separator: " · "))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Text("College plan: \(profile.collegePlan.rawValue)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                if !profile.targetColleges.isEmpty {
                    Text("Colleges: \(profile.targetColleges.joined(separator: ", "))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.4)))
    }
}

// MARK: - Project Profile Row (deterministic, uses canonical ProjectEngine)

private struct ProjectProfileRow: View {
    let project: ScoredProject
    @EnvironmentObject var store: AppDataStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.project.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                Spacer()
                Text(project.isCompleted ? "Completed" : "\(project.progress)%").font(DashFont.labelMono()).foregroundColor(project.isCompleted ? StudentOPSTheme.success : StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 4).background((project.isCompleted ? StudentOPSTheme.success : StudentOPSTheme.primary).opacity(0.12)).clipShape(Capsule())
            }
            Text(project.project.goal).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
            GeometryReader { proxy in
                Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                    Capsule().fill(project.isCompleted ? StudentOPSTheme.success : StudentOPSTheme.primary).frame(width: proxy.size.width * CGFloat(project.progress) / 100)
                }
            }.frame(height: 6)
            HStack {
                Text("\(project.completedMilestones) of \(project.project.milestones.count) milestones").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                if let src = project.project.sourceRoadmapID, !src.isEmpty {
                    Label(src, systemImage: "link").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                }
            }
            if !project.project.skills.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(project.project.skills.prefix(3), id: \.self) { s in
                        Text(s).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 6).padding(.vertical, 3).background(StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: 6).stroke(StudentOPSTheme.border))
                    }
                }
            }
            let evCount = store.evidenceRecords.values.filter { $0.projectID == project.project.id }.count
            if evCount > 0 {
                Label("\(evCount) evidence", systemImage: "doc.badge.ellipsis").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border))
    }
}
