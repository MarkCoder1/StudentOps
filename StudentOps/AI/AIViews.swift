import SwiftUI

// MARK: - AI Views (Phase 9.8)
// Contextual, explicit user action, structured, validated, with deterministic fallbacks.

// Shared loading/error UI helpers

private struct AIHeaderView: View {
    let title: String
    var body: some View {
        Label(title, systemImage: "sparkles").font(DashFont.labelMono()).tracking(0.6).foregroundColor(StudentOPSTheme.primaryDark)
    }
}

private struct AILoadingView: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().tint(StudentOPSTheme.primaryDark)
            Text(message).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }.padding(12).background(StudentOPSTheme.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel(Text(message))
    }
}

private struct AIErrorView: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Guidance unavailable.", systemImage: "exclamationmark.triangle").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
            Text(message).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            Button("Try again", action: onRetry).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
        }.padding(12).background(StudentOPSTheme.warning.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Project Explanation

struct ProjectExplanationAIView: View {
    let project: Project
    @EnvironmentObject var store: AppDataStore
    @State private var isLoading = false
    @State private var output: AIProjectExplanationOutput?
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    // Deterministic fallback reasons (from engine) - always shown if AI fails
    private var fallbackReasons: [String] {
        let recs = ProjectRecommendationEngine.recommendations(for: store, limit: 50)
        return recs.first(where: { $0.project.id == project.id })?.reasons.map(\.message) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIHeaderView(title: "WHY THIS PROJECT?")
            // Deterministic reasons always visible (source of truth)
            if !fallbackReasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended because:").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    ForEach(fallbackReasons, id: \.self) { r in
                        Label(r, systemImage: "checkmark.circle.fill").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }.padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let out = output {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Personalized Explanation", systemImage: "sparkles").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                    Text(out.summary).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).fixedSize(horizontal: false, vertical: true)
                    ForEach(out.reasons, id: \.self) { r in
                        Label(r, systemImage: "arrow.right.circle").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }.padding(12).background(StudentOPSTheme.primary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(Text("Personalized explanation: \(out.summary)"))
            } else if isLoading {
                AILoadingView(message: "Getting a personalized explanation…")
            } else if let err = error {
                AIErrorView(message: err) { Task { await explain() } }
                // Fallback deterministic already shown above
            } else {
                Button {
                    Task { await explain() }
                } label: {
                    Label("Show explanation", systemImage: "sparkles").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(StudentOPSTheme.primaryDark)
                .accessibilityLabel(Text("Show explanation"))
            }
        }
        .padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
        .onDisappear { task?.cancel() }
    }

    private func explain() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; output = nil
        task = Task {
            do {
                let result = try await AIPersonalizationService.shared.projectExplanation(project: project, store: store)
                await MainActor.run {
                    self.output = result
                    self.isLoading = false
                }
            } catch let e as AIError {
                await MainActor.run {
                    self.error = e.localizedDescription
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
        await task?.value
    }
}

// MARK: - Project Coaching

struct ProjectCoachingAIView: View {
    let project: Project
    @EnvironmentObject var store: AppDataStore
    @State private var isLoading = false
    @State private var output: AIProjectCoachingOutput?
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    private var nextStep: ProjectPlaybookStep? { store.executionNextStep(for: project) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIHeaderView(title: "NEED HELP WITH THIS STEP?")
            if let step = nextStep {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current step: \(step.title)").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text(step.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(3)
                }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No next step — check deliverables and criteria.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }

            if let out = output {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Next Steps", systemImage: "sparkles").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                    Text(out.focus).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Try this:").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        ForEach(Array(out.actions.enumerated()), id: \.offset) { idx, act in
                            Label(act, systemImage: "\(idx+1).circle").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }
                    if let c = out.caution, !c.isEmpty {
                        Label(c, systemImage: "exclamationmark.triangle").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
                    }
                }.padding(12).background(StudentOPSTheme.primary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(Text("Guidance: \(out.focus)"))
            } else if isLoading {
                AILoadingView(message: "Getting guidance…")
            } else if let err = error {
                AIErrorView(message: err) { Task { await coach() } }
                // Deterministic fallback: show step objective
                if let step = nextStep, let obj = step.objective {
                    Text("Next step objective: \(obj)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
            } else {
                Button {
                    Task { await coach() }
                } label: {
                    Label("Get guidance", systemImage: "sparkles").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(StudentOPSTheme.primaryDark)
                .accessibilityLabel(Text("Get guidance for \(nextStep?.title ?? "next step")"))
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
        .onDisappear { task?.cancel() }
    }

    private func coach() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; output = nil
        task = Task {
            do {
                let result = try await AIPersonalizationService.shared.projectCoaching(project: project, store: store)
                await MainActor.run { self.output = result; self.isLoading = false }
            } catch let e as AIError {
                await MainActor.run { self.error = e.localizedDescription; self.isLoading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
            }
        }
        await task?.value
    }
}

// MARK: - Project Reflection

struct ProjectReflectionAIView: View {
    let project: Project
    @EnvironmentObject var store: AppDataStore
    @State private var isLoading = false
    @State private var output: AIProjectReflectionOutput?
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIHeaderView(title: "REFLECT ON THIS PROJECT")
            if let out = output {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Reflection Prompts", systemImage: "sparkles").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                    ForEach(out.prompts, id: \.self) { p in
                        Label(p, systemImage: "questionmark.circle").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    if let draft = out.draftReflection, !draft.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Draft Reflection").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                            Text(draft).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Review before saving — Draft is not saved until you confirm.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
                        }
                    }
                }.padding(12).background(StudentOPSTheme.primary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
            } else if isLoading {
                AILoadingView(message: "Generating reflection prompts…")
            } else if let err = error {
                AIErrorView(message: err) { Task { await reflect() } }
            } else {
                Button {
                    Task { await reflect() }
                } label: {
                    Label("Generate reflection", systemImage: "sparkles").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(StudentOPSTheme.primaryDark)
                .accessibilityLabel(Text("Generate reflection"))
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
        .onDisappear { task?.cancel() }
    }

    private func reflect() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; output = nil
        task = Task {
            do {
                let result = try await AIPersonalizationService.shared.projectReflection(project: project, store: store)
                await MainActor.run { self.output = result; self.isLoading = false }
            } catch let e as AIError {
                await MainActor.run { self.error = e.localizedDescription; self.isLoading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
            }
        }
        await task?.value
    }
}

// MARK: - Skill Explanation

struct SkillExplanationAIView: View {
    let skillID: String
    @EnvironmentObject var store: AppDataStore
    @State private var isLoading = false
    @State private var output: AISkillExplanationOutput?
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    private var skillName: String { SkillCatalog.knownSkills[Skill.normalizeID(skillID)]?.name ?? skillID }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIHeaderView(title: "WHY THIS SKILL?")
            Text(skillName).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            if let out = output {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Personalized Explanation", systemImage: "sparkles").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                    Text(out.summary).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text(out.howProjectHelps).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }.padding(10).background(StudentOPSTheme.primary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
            } else if isLoading {
                AILoadingView(message: "Explaining skill…")
            } else if let err = error {
                AIErrorView(message: err) { Task { await explain() } }
            } else {
                Button {
                    Task { await explain() }
                } label: {
                    Label("Show explanation", systemImage: "sparkles").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(StudentOPSTheme.primaryDark)
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
        .onDisappear { task?.cancel() }
    }

    private func explain() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; output = nil
        task = Task {
            do {
                let result = try await AIPersonalizationService.shared.skillExplanation(skillID: skillID, store: store)
                await MainActor.run { self.output = result; self.isLoading = false }
            } catch let e as AIError {
                await MainActor.run { self.error = e.localizedDescription; self.isLoading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
            }
        }
        await task?.value
    }
}

// MARK: - Roadmap Explanation

struct RoadmapExplanationAIView: View {
    let roadmap: Roadmap
    @EnvironmentObject var store: AppDataStore
    @State private var isLoading = false
    @State private var output: AIRoadmapExplanationOutput?
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIHeaderView(title: "UNDERSTAND YOUR ROADMAP")
            Text(roadmap.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            if let out = output {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Personalized Explanation", systemImage: "sparkles").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                    Text(out.summary).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(out.focusAreas, id: \.self) { fa in
                        Label(fa, systemImage: "target").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }.padding(10).background(StudentOPSTheme.primary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
            } else if isLoading {
                AILoadingView(message: "Explaining roadmap…")
            } else if let err = error {
                AIErrorView(message: err) { Task { await explain() } }
            } else {
                Button {
                    Task { await explain() }
                } label: {
                    Label("Show explanation", systemImage: "sparkles").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(StudentOPSTheme.primaryDark)
            }
        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
        .onDisappear { task?.cancel() }
    }

    private func explain() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; output = nil
        task = Task {
            do {
                let result = try await AIPersonalizationService.shared.roadmapExplanation(roadmap: roadmap, store: store)
                await MainActor.run { self.output = result; self.isLoading = false }
            } catch let e as AIError {
                await MainActor.run { self.error = e.localizedDescription; self.isLoading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
            }
        }
        await task?.value
    }
}
