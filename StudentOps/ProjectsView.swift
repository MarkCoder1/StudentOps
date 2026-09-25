import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var searchText = ""
    @State private var selectedProject: ScoredProject?
    @State private var selectedRecommendation: ProjectRecommendation?
    @State private var showingNewProject = false

    // MARK: - Data

    private var customProjectsFiltered: [Project] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return store.customProjects }
        return store.customProjects.filter { p in
            let fields = [
                p.title,
                p.category,
                p.type,
                p.description,
                p.detailedDescription ?? "",
                p.outcome ?? "",
                p.outcomeDetails ?? "",
                p.status.displayName,
                p.skills.joined(separator: " "),
                p.links.map { $0.label + " " + $0.url }.joined(separator: " ")
            ].joined(separator: " ")
            return fields.localizedCaseInsensitiveContains(query)
        }
    }

    // Recommendations (ranked, filtered by search)
    private var allRecommendations: [ProjectRecommendation] {
        ProjectRecommendationEngine.recommendations(for: store, limit: 50)
    }

    private var recommendationsFiltered: [ProjectRecommendation] {
        // Deduplicate: hide ideas whose title already exists as a custom project (prevents exact duplicate display)
        let customTitles = Set(store.customProjects.map { $0.title.lowercased().trimmingCharacters(in: .whitespaces) })
        let deduped = allRecommendations.filter { !customTitles.contains($0.project.title.lowercased().trimmingCharacters(in: .whitespaces)) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return Array(deduped.prefix(5))
        }
        return deduped.filter { rec in recommendationMatches(rec, query: query) }
    }

    private func recommendationMatches(_ rec: ProjectRecommendation, query: String) -> Bool {
        let p = rec.project
        let pb = ProjectPlaybookService.playbook(for: p.id)
        var parts: [String] = []
        parts.append(p.title)
        parts.append(p.category)
        parts.append(p.description)
        if let d = p.detailedDescription { parts.append(d) }
        parts.append(p.skills.joined(separator: " "))
        parts.append(p.estimatedCompletion)
        parts.append(rec.reasons.map(\.message).joined(separator: " "))
        if let pb = pb {
            parts.append(pb.steps.map(\.title).joined(separator: " "))
            parts.append(pb.deliverables.map(\.title).joined(separator: " "))
            parts.append(pb.resources.map(\.title).joined(separator: " "))
            parts.append(pb.completionCriteria.map(\.title).joined(separator: " "))
        }
        let fields = parts.joined(separator: " ")
        return fields.localizedCaseInsensitiveContains(query)
    }

    // Legacy fallback for counts (catalog size)
    private var customCount: Int { customProjectsFiltered.count }
    private var ideaCount: Int { recommendationsFiltered.count }
    private var totalCustomCount: Int { store.customProjects.count }
    private var totalIdeaCount: Int {
        let customIDs = Set(store.customProjects.map(\.id))
        return ProjectService.catalogProjects.filter { !customIDs.contains($0.id) }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    yourProjectsSection
                    // PRO 3 — Smart Project Recommendations (gate personalized ideas, not create/manage)
                    PremiumFeatureGateWithPreview(feature: .smartProjectRecommendations, previewTitle: "Smart Project Ideas", previewSubtitle: "Personalized projects for your goals and skill gaps") {
                        projectIdeasSection
                    }
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
            }
            .background(StudentOPSTheme.background.ignoresSafeArea())
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedProject) { project in
                ProjectDetailView(scoredProject: project).environmentObject(store).environmentObject(revenueCatManager)
            }
            .navigationDestination(item: $selectedRecommendation) { rec in
                // Wrap recommendation project as ScoredProject for existing detail, but detail will detect recommendation context
                let scored = ScoredProject(project: rec.project, matchScore: rec.score, completedMilestones: 0)
                ProjectDetailView(scoredProject: scored).environmentObject(store).environmentObject(revenueCatManager)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Projects").font(DashFont.heroTitle()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text("Build things that prove what you can do.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
                Button { showingNewProject = true } label: {
                    Label("Add", systemImage: "plus").font(DashFont.labelMd()).foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 8).background(StudentOPSTheme.primary).clipShape(Capsule())
                }.buttonStyle(.plain).accessibilityLabel("Add project")
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(StudentOPSTheme.textSecondary)
                TextField("Search projects", text: $searchText).font(DashFont.bodySm()).autocorrectionDisabled()
            }
            .padding(.horizontal, 12).frame(height: 42).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.5))).clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .sheet(isPresented: $showingNewProject) { ProjectEditorView().environmentObject(store) }
    }

    // MARK: - YOUR PROJECTS

    private var yourProjectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("YOUR PROJECTS").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Text("\(customCount)").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 6).padding(.vertical, 2).background(StudentOPSTheme.surface).clipShape(Capsule()).overlay(Capsule().stroke(StudentOPSTheme.border.opacity(0.4)))
                Spacer()
            }
            if store.customProjects.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyYourProjects
            } else if customProjectsFiltered.isEmpty {
                noResultsYourProjects
            } else {
                ForEach(customProjectsFiltered) { project in
                    StudentProjectCard(project: project, store: store) {
                        let scored = ScoredProject(
                            project: project,
                            matchScore: ProjectService.matchScore(for: project, profile: store.profile),
                            completedMilestones: store.completedCount(for: project)
                        )
                        selectedProject = scored
                    }
                }
            }
        }
    }

    private var emptyYourProjects: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You haven't added any projects yet.").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            Text("Projects you build can become evidence for your skills, roadmaps, achievements, and portfolio.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            Button { showingNewProject = true } label: {
                Label("Add your first project", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary)
        }
        .padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.5))).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
    }

    private var noResultsYourProjects: some View {
        VStack(spacing: 6) {
            Text("No matching projects").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            Text("Try another search or add a new project.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 20)
    }

    // MARK: - PROJECT IDEAS (Recommended)

    private var projectIdeasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PROJECT IDEAS").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                if totalIdeaCount > 5 && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Top 5").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            if recommendationsFiltered.isEmpty && totalIdeaCount == 0 {
                Text("No project ideas are currently available.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
            } else if recommendationsFiltered.isEmpty {
                VStack(spacing: 6) {
                    Text("No ideas match that search").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text("Try another term.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(recommendationsFiltered) { rec in
                    RecommendationIdeaCard(recommendation: rec) { selectedRecommendation = rec }
                }
                if recommendationsFiltered.count < 5 && recommendationsFiltered.count < totalIdeaCount {
                    Text("Showing top \(recommendationsFiltered.count) ideas").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Student Project Card

private struct StudentProjectCard: View {
    let project: Project
    @ObservedObject var store: AppDataStore
    let onTap: () -> Void

    private var hasPlaybook: Bool { ProjectExecutionService.hasPlaybook(for: project) }
    private var execProgress: (completed: Int, total: Int, percent: Int) { store.executionProgress(for: project) }
    private var milestoneProgress: Int {
        ProgressCalculator.percent(completed: store.completedCount(for: project), total: project.milestones.count)
    }
    private var progress: Int { hasPlaybook ? execProgress.percent : milestoneProgress }
    private var progressText: String {
        if hasPlaybook && execProgress.total > 0 {
            return "\(execProgress.completed)/\(execProgress.total) steps"
        } else {
            return "\(progress)% complete"
        }
    }
    private var statusColor: Color {
        switch project.status {
        case .planned: return StudentOPSTheme.textSecondary
        case .inProgress: return StudentOPSTheme.primaryDark
        case .completed: return StudentOPSTheme.success
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(project.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                    Spacer()
                    StatusPill(text: project.status.displayName, color: statusColor)
                }
                Text(project.category).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                HStack(spacing: 6) {
                    Text(progressText).font(DashFont.captionMono()).foregroundColor(progress == 100 ? StudentOPSTheme.success : StudentOPSTheme.primaryDark)
                    ProgressView(value: Double(progress), total: 100).tint(progress == 100 ? StudentOPSTheme.success : StudentOPSTheme.primary).frame(height: 4)
                }
                if let firstSkill = project.skills.first {
                    Text(firstSkill).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark).lineLimit(1)
                }
                HStack {
                    Spacer()
                    Text("Open →").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            .padding(14).background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard).stroke(StudentOPSTheme.border.opacity(0.4)))
        }.buttonStyle(.plain)
    }
}

// MARK: - Recommendation Idea Card (Phase 9.5)

private struct RecommendationIdeaCard: View {
    let recommendation: ProjectRecommendation
    let onTap: () -> Void
    private var project: Project { recommendation.project }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(project.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                    Spacer()
                    StatusPill(text: "\(recommendation.score)% Match", color: StudentOPSTheme.primaryDark)
                }
                Text(project.category).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                if let reason = recommendation.reasons.first?.message, !recommendation.isFallback {
                    Text(reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                }
                if let firstSkill = project.skills.first {
                    Text(firstSkill).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.primaryDark).lineLimit(1)
                }
                HStack {
                    Spacer()
                    Text("Explore →").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            .padding(14).background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard).stroke(StudentOPSTheme.border.opacity(0.4)))
        }.buttonStyle(.plain)
    }
}

// MARK: - Project Idea Card (Legacy - kept for reference)

private struct ProjectIdeaCard: View {
    let scoredProject: ScoredProject
    let isPortfolioReady: Bool
    let onTap: () -> Void

    private var project: Project { scoredProject.project }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PROJECT IDEA").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.textSecondary)
                        Label(project.category, systemImage: "lightbulb").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                    }
                    Spacer()
                    if isPortfolioReady {
                        Label("Portfolio ready", systemImage: "checkmark.seal.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
                    } else {
                        Text("\(scoredProject.matchScore)% Match").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
                    }
                }
                Text(project.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                Text(project.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                if !project.estimatedCompletion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(project.estimatedCompletion, systemImage: "clock").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                if !project.skills.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(project.skills.prefix(3)), id: \.self) { skill in
                            Text(skill).font(.system(size: 10, weight: .medium)).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 6).padding(.vertical, 3).background(StudentOPSTheme.background).clipShape(Capsule()).overlay(Capsule().stroke(StudentOPSTheme.border.opacity(0.6)))
                        }
                    }
                }
                HStack {
                    Text("Explore idea").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.right").foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            .padding(16).background(StudentOPSTheme.surface.opacity(0.92)).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.4))).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 1)
        }.buttonStyle(.plain)
    }
}

private struct NewProjectView: View {
    let onCreate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var goal = ""
    var body: some View { NavigationStack { Form { Section("Project") { TextField("Project title", text: $title); TextField("What do you want to build?", text: $goal) }; Section { Text("Your project starts with one milestone. You can add evidence and notes as you work.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) } }.navigationTitle("New Project").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onCreate(title.trimmingCharacters(in: .whitespacesAndNewlines), goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Complete this project" : goal); dismiss() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } } }
}
