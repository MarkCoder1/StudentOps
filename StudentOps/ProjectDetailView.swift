import SwiftUI

struct ProjectDetailView: View {
    let scoredProject: ScoredProject
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @Environment(\.dismiss) private var dismiss
    @State private var notesText: String
    @State private var showEvidenceForm = false
    @State private var selectedEvidence: EvidenceRecord?
    @State private var selectedAchievement: Achievement?
    @State private var selectedRankedOpportunity: RankedOpportunity?
    @State private var showProjectEditor = false
    private var project: Project { scoredProject.project }
    private var completedCount: Int { store.completedCount(for: project) }
    private var progress: Int { ProgressCalculator.percent(completed: completedCount, total: project.milestones.count) }
    private var isCustom: Bool { store.customProjects.contains(where: { $0.id == project.id }) }

    init(scoredProject: ScoredProject) {
        self.scoredProject = scoredProject
        _notesText = State(initialValue: "")
    }

    private var recommendation: ProjectRecommendation? {
        guard !isCustom else { return nil }
        let recs = ProjectRecommendationEngine.recommendations(for: store, limit: 50)
        return recs.first(where: { $0.project.id == project.id })
    }

    private var playbook: ProjectPlaybook? { ProjectExecutionService.playbook(for: project) }
    private var executionState: ProjectExecutionState? { store.executionState(for: project.id) }
    private var executionProgress: (completed: Int, total: Int, percent: Int) { store.executionProgress(for: project) }
    private var nextStep: ProjectPlaybookStep? { store.executionNextStep(for: project) }
    private var isCompleted: Bool { store.isProjectCompleted(project) }
    @State private var showingStartedProject: Project?
    private var existingStartedProject: Project? { store.existingStartedProject(for: project.id) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                overview
                if let rec = recommendation {
                    // PRO 3 — Smart Project Recommendations: personalized reasoning
                    PremiumFeatureGate(feature: .smartProjectRecommendations) {
                        recommendationSection(rec)
                    }
                }
                if !isCustom {
                    ProjectExplanationAIView(project: project).environmentObject(store)
                }
                // Rich sections (hidden when no data)
                if !project.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || project.detailedDescription != nil {
                    aboutSection
                }
                if let pb = playbook {
                    prerequisitesSection(pb)
                    if isCustom {
                        executionProgressSection(pb)
                        if !isCompleted, nextStep != nil {
                            ProjectCoachingAIView(project: project).environmentObject(store)
                        } else if isCompleted {
                            ProjectReflectionAIView(project: project).environmentObject(store)
                        }
                    }
                    playbookStepsSection(pb)
                    playbookResourcesSection(pb)
                    playbookDeliverablesSection(pb)
                    playbookCriteriaSection(pb)
                    if let effort = pb.estimatedEffort, let txt = effort.displayText, !txt.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ESTIMATED EFFORT").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                            Label(txt, systemImage: "clock").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                            if let hours = effort.estimatedHours { Text("\(Int(hours)) hours").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
                    }
                    if !pb.skillsDeveloped.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SKILLS YOU'LL PRACTICE").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                            FlowLayout(spacing: 6) {
                                ForEach(pb.skillsDeveloped, id: \.self) { s in
                                    Text(s).font(.system(size: 11, weight: .medium)).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 5).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                                }
                            }
                        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
                    }
                    // Skill explanation where gap exists (deterministic)
                    if let firstGap = store.activeSkillGapReports.first?.gaps.first {
                        SkillExplanationAIView(skillID: firstGap.skill.id).environmentObject(store)
                    }
                }
                if !project.skills.isEmpty {
                    skillsSection
                    careerConnectionsSection
                    // Phase 5: Project → Opportunity — where to apply this skill
                    relatedOpportunitySection
                }
                if project.outcome != nil || project.outcomeDetails != nil {
                    outcomeSection
                }
                if project.startDate != nil || project.completionDate != nil {
                    datesSection
                }
                if !project.links.isEmpty {
                    linksSection
                }
                if !project.imageReferences.isEmpty {
                    photosSection
                }
                // Old milestones/resources are hidden when playbook is authoritative to keep single source of truth
                if playbook == nil || !isCustom {
                    section(title: "PROJECT MILESTONES", icon: "point.3.connected.trianglepath.dotted") {
                        ForEach(Array(project.milestones.enumerated()), id: \.element.id) { index, milestone in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: index < completedCount ? "checkmark.circle.fill" : index == completedCount ? "circle.inset.filled" : "circle").foregroundColor(index < completedCount ? StudentOPSTheme.success : index == completedCount ? StudentOPSTheme.primary : StudentOPSTheme.border).font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 3) { Text(milestone.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary); Text(milestone.subtitle).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary); Text(milestone.estimatedTime).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                                Spacer()
                            }.padding(10).background(index == completedCount ? StudentOPSTheme.surface : Color.clear).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                if playbook == nil, !project.resources.isEmpty {
                    section(title: "RESOURCES", icon: "books.vertical") { ForEach(project.resources, id: \.self) { Text("• \($0)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) } }
                }
                section(title: "NOTES & DOCUMENTATION", icon: "note.text") { Text("Capture what you built, what changed, and what you learned as this project develops.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary); TextEditor(text: $notesText).frame(minHeight: 90).padding(6).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.5))) }
                if completedCount >= project.milestones.count || isCompleted { Button { store.togglePortfolio(project) } label: { Label(store.isInPortfolio(project) ? "Added to Portfolio" : "Add to Portfolio", systemImage: store.isInPortfolio(project) ? "checkmark.seal.fill" : "briefcase") .frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary) }
                Button { showEvidenceForm = true } label: { Label("Add Evidence", systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }.buttonStyle(.bordered).tint(StudentOPSTheme.primary)
                evidenceSection
                achievementsForProjectSection
                // Achievement linked via Project.achievementID (show if exists even if not in projectID reverse)
                if let achID = project.achievementID, let ach = store.achievementRecords[achID] {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LINKED ACHIEVEMENT").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                        Button { selectedAchievement = ach } label: { AchievementRowView(achievement: ach) }.buttonStyle(.plain)
                    }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
                }
                Button("Reset project progress") { store.resetProject(project) }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth: .infinity)
                if isCustom {
                    Button(role: .destructive) { _ = store.deleteCustomProject(id: project.id); dismiss() } label: { Label("Delete Project", systemImage: "trash").frame(maxWidth: .infinity) }.buttonStyle(.bordered).tint(.red)
                }
            }.padding(16)
        }.background(StudentOPSTheme.background.ignoresSafeArea()).navigationTitle("Project").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isCustom {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showProjectEditor = true } label: { Label("Edit", systemImage: "pencil") }
                    }
                }
            }
            .onAppear { notesText = store.note(for: project) }
            .onDisappear { store.saveNote(notesText, for: project) }
            .sheet(isPresented: $showEvidenceForm) { EvidenceFormView(initialProjectID: project.id).environmentObject(store) }
            .sheet(item: $selectedEvidence) { rec in EvidenceDetailSheet(record: rec).environmentObject(store) }
            .sheet(item: $selectedAchievement) { ach in NavigationStack { AchievementDetailView(achievement: ach).environmentObject(store) } }
            .sheet(isPresented: $showProjectEditor) { ProjectEditorView(editingProject: project).environmentObject(store) }
            .sheet(item: $showingStartedProject) { proj in
                NavigationStack {
                    let scored = ScoredProject(project: proj, matchScore: ProjectService.matchScore(for: proj, profile: store.profile), completedMilestones: store.completedCount(for: proj))
                    ProjectDetailView(scoredProject: scored).environmentObject(store).environmentObject(revenueCatManager)
                }
            }
            .sheet(item: $selectedRankedOpportunity) { ranked in
                NavigationStack { OpportunityDetailView(ranked: ranked).environmentObject(store).environmentObject(revenueCatManager) }
            }
    }

    private var achievementsForProjectSection: some View {
        let related = store.achievementRecords.values.filter { $0.projectID == project.id }.sorted { $0.createdAt > $1.createdAt }
        return Group {
            if !related.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ACHIEVEMENTS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(related.prefix(3)) { ach in
                        Button { selectedAchievement = ach } label: { AchievementRowView(achievement: ach) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isCustom {
                HStack {
                    Label("PROJECT IDEA", systemImage: "lightbulb").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.background).clipShape(Capsule()).overlay(Capsule().stroke(StudentOPSTheme.border))
                    Spacer()
                    Text("Not yet started").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Text("This is a project idea you can explore.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(8).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                HStack {
                    Label(project.category, systemImage: "hammer").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                    Spacer()
                    Text(project.status.displayName).font(DashFont.labelMono()).foregroundColor(statusColor).padding(.horizontal, 6).padding(.vertical, 2).background(statusColor.opacity(0.12)).clipShape(Capsule())
                }
            }
            HStack { Text(project.type).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary); Text("•").foregroundColor(StudentOPSTheme.textSecondary); Text(project.status.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary); Spacer(); Text("\(scoredProject.matchScore)% Match").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success) }
            Text(project.title).font(DashFont.headlineLgMobile()).foregroundColor(StudentOPSTheme.textPrimary)
            Text(project.goal).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
            if !project.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(project.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            // Progress display – playbook progress is source of truth when available
            let displayPercent: Int = {
                if ProjectExecutionService.hasPlaybook(for: project) {
                    return executionProgress.percent
                } else {
                    return progress
                }
            }()
            let displayProgressText: String = {
                if let pb = playbook {
                    return "\(executionProgress.completed) of \(executionProgress.total) steps"
                } else {
                    return "\(progress)% complete"
                }
            }()
            HStack { Text(displayProgressText).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark); Spacer(); Text(project.estimatedCompletion).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
            ProgressView(value: Double(displayPercent), total: 100).tint(displayPercent == 100 ? StudentOPSTheme.success : StudentOPSTheme.primary)
            if !project.skills.isEmpty {
                HStack(spacing: 5) { ForEach(project.skills, id: \.self) { Text($0).font(.system(size: 10, weight: .medium)).foregroundColor(StudentOPSTheme.textSecondary).padding(6).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 4)) } }
            }
            if isCustom {
                if let pb = playbook {
                    // Playbook progress already shown above; milestone button hidden to avoid dual progress
                    if isCompleted {
                        Label("Project completed", systemImage: "checkmark.seal.fill").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.success)
                    } else if let next = nextStep {
                        Text("Next: \(next.title)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.primaryDark)
                    }
                } else {
                    if let current = project.milestones.indices.contains(completedCount) ? project.milestones[completedCount] : nil {
                        Button { store.markProjectMilestoneComplete(for: project) } label: { Label("Complete: \(current.title)", systemImage: "checkmark").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary)
                    } else {
                        Label("Project complete", systemImage: "checkmark.seal.fill").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.success)
                    }
                }
            } else {
                // Catalog idea: explicit start action
                if let existing = existingStartedProject {
                    Button {
                        let scored = ScoredProject(project: existing, matchScore: ProjectService.matchScore(for: existing, profile: store.profile), completedMilestones: store.completedCount(for: existing))
                        showingStartedProject = existing
                        // Trigger navigation via sheet
                    } label: {
                        Label("View your project", systemImage: "arrow.right.circle").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary)
                } else {
                    Button {
                        if let newProj = store.startProject(from: project) {
                            showingStartedProject = newProj
                        }
                    } label: {
                        Label("Start this project", systemImage: "play.circle.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary)
                    .accessibilityLabel("Start this project")
                }
                Text("Opening this idea does not automatically start it. You must explicitly start it.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
    }

    private var statusColor: Color {
        switch project.status {
        case .planned: return StudentOPSTheme.textSecondary
        case .inProgress: return StudentOPSTheme.primaryDark
        case .completed: return StudentOPSTheme.success
        }
    }

    private func recommendationSection(_ rec: ProjectRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("RECOMMENDED FOR YOU", systemImage: "star.fill").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.primaryDark)
                Spacer()
                Text("\(rec.score) / 100").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.primary.opacity(0.12)).clipShape(Capsule())
            }
            if rec.isFallback {
                Text("Project idea").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                Text("Why this project:").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                ForEach(rec.reasons) { reason in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11, weight: .bold)).foregroundColor(StudentOPSTheme.success).padding(.top, 2)
                        Text(reason.message).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }
                // Compact score breakdown (optional)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Score breakdown").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.top, 4)
                    scoreBar(label: "Goal", value: rec.scoreBreakdown.goalAlignment)
                    scoreBar(label: "Skills", value: rec.scoreBreakdown.skillGapCoverage)
                    scoreBar(label: "Roadmap", value: rec.scoreBreakdown.roadmapAlignment)
                    scoreBar(label: "Continuity", value: rec.scoreBreakdown.skillContinuity)
                }
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.primary.opacity(0.15)))
    }

    private func scoreBar(label: String, value: Double) -> some View {
        HStack(spacing: 8) {
            Text(label).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).frame(width: 70, alignment: .leading)
            ProgressView(value: value).tint(StudentOPSTheme.primary).frame(height: 6)
            Text("\(Int(value*100))%").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Playbook Sections

    private func prerequisitesSection(_ pb: ProjectPlaybook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PREREQUISITES").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                let metCount = pb.prerequisites.filter { ProjectPlaybookService.prerequisiteStatus(for: $0, store: store) == .met }.count
                Text("\(pb.prerequisites.count) required · \(metCount) met").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            ForEach(pb.prerequisites) { prereq in
                let status = ProjectPlaybookService.prerequisiteStatus(for: prereq, store: store)
                HStack(spacing: 8) {
                    Image(systemName: status == .met ? "checkmark.circle.fill" : status == .notMet ? "circle" : "questionmark.circle").foregroundColor(status == .met ? StudentOPSTheme.success : StudentOPSTheme.textSecondary).font(.system(size: 14, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prereq.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                        if let desc = prereq.description { Text(desc).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                    Spacer()
                    Text(status.label).font(DashFont.labelMono()).foregroundColor(status == .met ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
                }.padding(8).background(status == .met ? StudentOPSTheme.primary.opacity(0.06) : StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(prereq.title), \(status.label)")
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private func executionProgressSection(_ pb: ProjectPlaybook) -> some View {
        let prog = executionProgress
        let summary = ProjectExecutionService.summary(for: project, state: executionState, store: store)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PROJECT PROGRESS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("\(prog.completed) of \(prog.total) steps").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
            }
            HStack { Text("\(prog.percent)%").font(DashFont.titleMd()).foregroundColor(prog.percent == 100 ? StudentOPSTheme.success : StudentOPSTheme.primaryDark); Spacer(); Text(isCompleted ? "Completed" : "In Progress").font(DashFont.labelMono()).foregroundColor(isCompleted ? StudentOPSTheme.success : StudentOPSTheme.textSecondary) }
            ProgressView(value: Double(prog.percent), total: 100).tint(prog.percent == 100 ? StudentOPSTheme.success : StudentOPSTheme.primary)
            if let next = nextStep {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current step").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text(next.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text(next.description).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                Button {
                    // Scroll to step is not implemented; for now just completes next step? spec says Continue should focus next step, not auto-complete
                } label: {
                    Label("Continue: \(next.title)", systemImage: "play.circle").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(StudentOPSTheme.primary).disabled(true)
                .accessibilityLabel("Continue project, current step \(next.title)")
            } else if isCompleted {
                VStack(spacing: 8) {
                    Label("Project completed", systemImage: "checkmark.seal.fill").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.success)
                    Text("\(summary.steps.completed) / \(summary.steps.total) steps  •  \(summary.deliverables.completed) / \(summary.deliverables.total) deliverables  •  \(summary.criteria.completed) / \(summary.criteria.total) criteria").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).multilineTextAlignment(.center)
                    Text("Skills practiced: \(summary.skills.prefix(3).joined(separator: ", "))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Evidence: \(summary.evidenceCount)  •  Achievements: \(summary.achievementCount)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }.padding(10).background(StudentOPSTheme.success.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(spacing: 8) {
                    Text("Next: Add evidence and achievement, then use in portfolio.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    Button { showEvidenceForm = true } label: { Label("Add Evidence", systemImage: "doc.badge.plus").frame(maxWidth: .infinity) }.buttonStyle(.bordered).tint(StudentOPSTheme.primary)
                }
            } else if prog.total == 0 {
                Text("No steps to track for this project.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Project progress \(prog.completed) of \(prog.total) steps, \(prog.percent) percent")
    }

    private func playbookStepsSection(_ pb: ProjectPlaybook) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PLAYBOOK — STEPS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            if let ov = pb.overview, !ov.isEmpty {
                Text(ov).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            ForEach(Array(pb.steps.enumerated()), id: \.element.id) { idx, step in
                let completed = executionState?.completedStepIDs.contains(step.id) ?? false
                let locked = isCustom && !completed && ProjectExecutionService.isStepLocked(step, state: executionState)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if isCustom {
                            Image(systemName: completed ? "checkmark.circle.fill" : locked ? "lock.circle" : "circle")
                                .foregroundColor(completed ? StudentOPSTheme.success : locked ? StudentOPSTheme.textSecondary : StudentOPSTheme.primary)
                                .font(.system(size: 20, weight: .semibold))
                        } else {
                            Text("\(idx+1)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textOnPrimary).frame(width: 24, height: 24).background(StudentOPSTheme.primaryDark).clipShape(Circle())
                        }
                        Text(step.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Spacer()
                        if let eff = step.estimatedEffort { Text(eff).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                    Text(step.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    if let obj = step.objective, !obj.isEmpty {
                        Text("Objective: \(obj)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                    }
                    if !step.requiredSkills.isEmpty {
                        Text(step.requiredSkills.joined(separator: " • ")).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    if !step.deliverableIDs.isEmpty {
                        let titles = step.deliverableIDs.compactMap { did in pb.deliverables.first(where: {$0.id==did})?.title }
                        if !titles.isEmpty {
                            Label("Deliverable: \(titles.joined(separator: ", "))", systemImage: "doc").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                    if !step.prerequisiteStepIDs.isEmpty {
                        let reqTitles = step.prerequisiteStepIDs.compactMap { sid in pb.steps.first(where: {$0.id==sid})?.title }
                        if !reqTitles.isEmpty {
                            Label("Requires: \(reqTitles.joined(separator: ", "))", systemImage: "link").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                    if isCustom {
                        if locked {
                            let reason = ProjectExecutionService.lockedReason(for: step, playbook: pb, state: executionState) ?? "Locked"
                            Label(reason, systemImage: "lock.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                .accessibilityLabel("Step \(step.title) is locked because \(reason)")
                        } else {
                            Button {
                                _ = store.toggleStep(step.id, for: project.id)
                            } label: {
                                Label(completed ? "Mark incomplete" : "Mark complete", systemImage: completed ? "arrow.uturn.backward.circle" : "checkmark.circle")
                                    .font(DashFont.labelMd()).foregroundColor(completed ? StudentOPSTheme.textSecondary : StudentOPSTheme.primaryDark)
                            }.buttonStyle(.bordered).tint(completed ? StudentOPSTheme.textSecondary : StudentOPSTheme.primary)
                            .accessibilityLabel(completed ? "Mark \(step.title) incomplete" : "Mark \(step.title) complete")
                        }
                    }
                }.padding(10).background(completed ? StudentOPSTheme.primary.opacity(0.06) : locked ? StudentOPSTheme.background.opacity(0.7) : StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(completed ? StudentOPSTheme.success.opacity(0.3) : StudentOPSTheme.border.opacity(0.3)))
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private func playbookResourcesSection(_ pb: ProjectPlaybook) -> some View {
        Group {
            if !pb.resources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RESOURCES").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(pb.resources) { res in
                        Link(destination: URL(string: res.url) ?? URL(string: "https://example.com")!) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(res.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.primaryDark)
                                    Text(res.type.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                    if let desc = res.description { Text(desc).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2) }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.circle").foregroundColor(StudentOPSTheme.primaryDark)
                            }.padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                        .accessibilityLabel("\(res.title), \(res.type.displayName)")
                    }
                }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
            }
        }
    }

    private func playbookDeliverablesSection(_ pb: ProjectPlaybook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DELIVERABLES").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            ForEach(pb.deliverables) { deliv in
                let completed = executionState?.completedDeliverableIDs.contains(deliv.id) ?? false
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle").font(.system(size: 14)).foregroundColor(completed ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deliv.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                        if let desc = deliv.description { Text(desc).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                        if let fmt = deliv.format { Text(fmt).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                    Spacer()
                    if isCustom {
                        Button {
                            if completed {
                                _ = store.uncompleteDeliverable(deliv.id, for: project.id)
                            } else {
                                _ = store.completeDeliverable(deliv.id, for: project.id)
                            }
                        } label: {
                            Text(completed ? "Undo" : "Done").font(DashFont.labelMono()).foregroundColor(completed ? StudentOPSTheme.textSecondary : StudentOPSTheme.primaryDark)
                        }.buttonStyle(.bordered).tint(completed ? StudentOPSTheme.textSecondary : StudentOPSTheme.primary)
                        .accessibilityLabel(completed ? "Mark \(deliv.title) incomplete" : "Mark \(deliv.title) complete")
                    }
                }.padding(6).background(completed ? StudentOPSTheme.primary.opacity(0.06) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 6))
            }
            if !isCustom {
                Text("Mark deliverables complete after you start the project.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private func playbookCriteriaSection(_ pb: ProjectPlaybook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMPLETION CRITERIA").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            Text("The project is ready to consider complete when:").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            ForEach(pb.completionCriteria) { crit in
                let confirmed = executionState?.confirmedCriterionIDs.contains(crit.id) ?? false
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: confirmed ? "checkmark.circle.fill" : "checkmark.circle").font(.system(size: 12)).foregroundColor(confirmed ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(crit.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                        if let desc = crit.description { Text(desc).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                    Spacer()
                    if isCustom {
                        Button {
                            if confirmed {
                                _ = store.unconfirmCriterion(crit.id, for: project.id)
                            } else {
                                _ = store.confirmCriterion(crit.id, for: project.id)
                            }
                        } label: {
                            Text(confirmed ? "Undo" : "Confirm").font(DashFont.labelMono()).foregroundColor(confirmed ? StudentOPSTheme.textSecondary : StudentOPSTheme.primaryDark)
                        }.buttonStyle(.bordered).tint(confirmed ? StudentOPSTheme.textSecondary : StudentOPSTheme.primary)
                        .accessibilityLabel(confirmed ? "Unconfirm \(crit.title)" : "Confirm \(crit.title)")
                    }
                }.padding(6).background(confirmed ? StudentOPSTheme.primary.opacity(0.06) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 6))
            }
            if !isCustom {
                Text("Confirm criteria after you start the project.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ABOUT").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            Text(project.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            if let dd = project.detailedDescription, !dd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(dd).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SKILLS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            FlowLayout(spacing: 6) {
                ForEach(project.skills, id: \.self) { skill in
                    Text(skill).font(.system(size: 11, weight: .medium)).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 5).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                }
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private var outcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OUTCOME").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            if let o = project.outcome { Text(o).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textPrimary) }
            if let od = project.outcomeDetails, !od.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(od).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATES").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            if let s = project.startDate {
                Label("Started \(dateString(s))", systemImage: "calendar").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            if let c = project.completionDate {
                Label("Completed \(dateString(c))", systemImage: "checkmark.circle").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.success)
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROJECT LINKS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            ForEach(project.links) { link in
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.label).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text(link.url).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.primaryDark).lineLimit(1)
                }.padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHOTOS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(project.imageReferences, id: \.self) { ref in
                        PhotoThumb(ref: ref, projectID: project.id).frame(width: 120, height: 120)
                    }
                }
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: d)
    }

    private struct PhotoThumb: View {
        let ref: String
        let projectID: String
        @State private var image: UIImage?
        var body: some View {
            Group {
                if let ui = image {
                    Image(uiImage: ui).resizable().scaledToFill().clipped()
                } else {
                    Rectangle().fill(StudentOPSTheme.background).overlay(Text("Photo").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary))
                }
            }.clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
            .onAppear { image = ProjectImageStore.loadImage(identifier: ref, projectID: projectID) }
        }
    }

    private var careerConnectionsSection: some View {
        let skillIDs = Set(project.skills.map { Skill.normalizeID($0) })
        let careerIDs = Set(skillIDs.flatMap { CareerSkillGraph.careerIDs(for: $0) })
        let careers = careerIDs.compactMap { CareerCatalog.career(for: $0) }.sorted { $0.title < $1.title }
        let activeGaps = Set(store.skillGaps().map(\.skillID))
        let helpsGap = !skillIDs.isDisjoint(with: activeGaps)
        return Group {
            if !careers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CAREER CONNECTIONS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(careers.prefix(3), id: \.id) { career in
                        NavigationLink(destination: CareerDetailView(career: career).environmentObject(store).environmentObject(revenueCatManager)) {
                            HStack { Text(career.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark); Spacer(); Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.textSecondary) }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                    if helpsGap {
                        Label("Helps develop your skill gap", systemImage: "arrow.up.circle.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
                    }
                    Text("Catalog data — skills from this project map to careers via CareerSkillGraph.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
            }
        }
    }

    private var relatedOpportunitySection: some View {
        // Phase 5: Project → Opportunity — where to apply this skill (deterministic)
        let skillIDs = Set(project.skills.map { Skill.normalizeID($0) })
        let ranked = store.rankedOpportunities().first(where: { r in
            !Set(r.opportunity.skills.map { Skill.normalizeID($0) }).isDisjoint(with: skillIDs)
        }) ?? store.rankedOpportunities().first
        guard let top = ranked else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("WHERE TO APPLY IT").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Button {
                    selectedRankedOpportunity = top
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(StudentOPSTheme.success.opacity(0.12)).frame(width: 36, height: 36).overlay(Image(systemName: "star.fill").foregroundColor(StudentOPSTheme.success).font(.system(size: 14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(top.opportunity.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                            Text("Builds \(project.skills.first ?? "skills") • \(top.eligibilityLabel)").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    .padding(12)
                    .background(StudentOPSTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.35)))
                }.buttonStyle(.plain)
                Text("Apply your project skills in a real opportunity.").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            .padding(12)
            .background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
        )
    }

    private var evidenceSection: some View {
        let related = store.allEvidenceSorted.filter { $0.projectID == project.id }
        return VStack(alignment: .leading, spacing: 10) {
            Text("EVIDENCE").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            if related.isEmpty {
                Text("No evidence for this project yet. Record work you have actually completed.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(related) { rec in
                    Button { selectedEvidence = rec } label: { EvidenceRowView(record: rec) }.buttonStyle(.plain)
                }
            }
            // Evidence skill connection
            let projSkills = Set(project.skills.map { Skill.normalizeID($0) })
            let demonstrated = Set(store.allEvidenceSorted.compactMap(\.skillIDs).flatMap { $0 })
            let overlap = projSkills.intersection(demonstrated)
            if !overlap.isEmpty, let first = overlap.first, let name = SkillCatalog.knownSkills[first]?.name {
                Text("\(name) ✓ Demonstrated in \(related.first?.title ?? "evidence")").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.success)
            }
        }
    }
    private func section<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 10) { Label(title, systemImage: icon).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary); content() }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)) }
}
