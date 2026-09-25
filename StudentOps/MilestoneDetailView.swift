import SwiftUI

struct MilestoneDetailView: View {
    let milestone: Milestone
    let status: MilestoneNodeView.MilestoneStatus
    var lockInfo: DependencyLockInfo? = nil
    var roadmap: Roadmap? = nil
    let onComplete: () -> Void
    @EnvironmentObject var store: AppDataStore
    @Environment(\.openURL) private var openURL

    @State private var validationPhase: ValidationPhase = .notStarted
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswers: [String: Int] = [:]
    @State private var showExplanation = false
    @State private var savedAttempt: ValidationAttempt?
    @State private var showEvidenceForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(status == .completed ? "Completed milestone" : status == .current ? "Current milestone" : "Locked milestone", systemImage: status == .completed ? "checkmark.circle.fill" : status == .current ? "circle.inset.filled" : "lock.fill")
                .font(DashFont.labelMono())
                .foregroundColor(status == .completed ? StudentOPSTheme.success : status == .current ? StudentOPSTheme.primary : StudentOPSTheme.textSecondary)
            Text(milestone.title).font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary)
            Text(milestone.subtitle).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textSecondary)
            if let roadmap = roadmap {
                let gaps = store.milestoneSkillGaps(milestone: milestone, in: roadmap)
                if !gaps.isEmpty {
                    skillGapsBadge(gaps)
                }
            }
            if let info = lockInfo, status == .locked { lockInfoSection(info) }
            if let goal = milestone.goal { detailSection(title: "Goal", icon: "target", text: goal) }
            detailSection(title: "What this accomplishes", icon: "lightbulb", text: milestone.whatItAccomplishes)
            detailSection(title: "Why it matters", icon: "sparkles", text: milestone.whyItMatters)
            if let actions = milestone.actions, !actions.isEmpty { actionsSection(actions) }
            if !milestone.recommendedActions.isEmpty { listSection(title: "Recommended actions", icon: "checklist", values: milestone.recommendedActions) }
            if let criteria = milestone.completionCriteria, !criteria.isEmpty { listSection(title: "Completion criteria", icon: "checkmark.seal", values: criteria) }
            if let lr = milestone.learningResources, !lr.isEmpty { learningResourcesSection(lr) }
            else if !milestone.resources.isEmpty { listSection(title: "Resources", icon: "books.vertical", values: milestone.resources) }
            if let projectAction = milestone.projectAction { detailSection(title: "Project action", icon: "hammer", text: projectAction) }
            if let assessment = milestone.assessment, !assessment.questions.isEmpty { validationSection(assessment) }
            Label("Estimated time: \(milestone.estimatedTime)", systemImage: "clock").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
            if status == .current { Button(action: onComplete) { Label("Mark Complete", systemImage: "checkmark").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary) }
            else if status == .completed { Label("This milestone is complete", systemImage: "checkmark.seal.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.success) }
            else { lockStatusLabel }
            milestoneEvidenceSection
        }
        .padding(16)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.45)))
        .sheet(isPresented: $showEvidenceForm) {
            if let roadmap = roadmap {
                EvidenceFormView(initialRoadmapID: roadmap.id, initialMilestoneID: milestone.id)
                    .environmentObject(store)
            } else {
                EvidenceFormView(initialMilestoneID: milestone.id)
                    .environmentObject(store)
            }
        }
    }

    @ViewBuilder
    private var milestoneEvidenceSection: some View {
        if let roadmap = roadmap {
            let related = store.allEvidenceSorted.filter { $0.roadmapID == roadmap.id && $0.milestoneID == milestone.id }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Evidence", systemImage: "doc.badge.ellipsis").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Spacer()
                    Button(action: { showEvidenceForm = true }) {
                        Label("Add", systemImage: "plus.circle.fill").font(DashFont.labelMd())
                    }.buttonStyle(.bordered).tint(StudentOPSTheme.primary)
                }
                if related.isEmpty {
                    Text("No evidence yet for this milestone. Record real work you completed.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ForEach(related.prefix(2)) { rec in
                        HStack {
                            Text(rec.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                            Spacer()
                            Text(rec.type.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    if related.count > 2 {
                        Text("+\(related.count - 2) more in Progress → Evidence").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Skill Gaps Badge

    @ViewBuilder
    private func skillGapsBadge(_ gaps: [SkillGap]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(StudentOPSTheme.primaryDark)
            VStack(alignment: .leading, spacing: 2) {
                Text("Develops \(gaps.count) skill gap\(gaps.count == 1 ? "" : "s")")
                    .font(DashFont.labelMd())
                    .foregroundColor(StudentOPSTheme.primaryDark)
                Text(gaps.map(\.skillName).joined(separator: " • "))
                    .font(DashFont.bodySm())
                    .foregroundColor(StudentOPSTheme.textSecondary)
            }
            Spacer()
        }
        .padding(10)
        .background(StudentOPSTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.primary.opacity(0.25)))
    }

    // MARK: - Lock Info Section

    @ViewBuilder
    private func lockInfoSection(_ info: DependencyLockInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("LOCKED", systemImage: "lock.fill").font(DashFont.labelMono()).tracking(0.7).foregroundColor(StudentOPSTheme.warning)
            VStack(alignment: .leading, spacing: 8) {
                Text("Complete prerequisites to unlock").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                ForEach(info.blockingPrerequisites, id: \.id) { prereq in
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill").font(.system(size: 14, weight: .semibold)).foregroundColor(StudentOPSTheme.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prereq.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                            Text("Tap to view prerequisite").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                    }.padding(10).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.warning.opacity(0.25)))
                }
                Text("Complete the prerequisite milestone(s) to unlock this step. Your progress is saved, so you can return anytime.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(.top, 2)
            }.padding(14).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.warning.opacity(0.2)))
        }
    }

    // MARK: - Lock Status Label (bottom)

    private var lockStatusLabel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Complete the prerequisite milestone(s) to unlock this step", systemImage: "lock.fill")
                .font(DashFont.bodySm())
                .foregroundColor(StudentOPSTheme.textSecondary)
            if let info = lockInfo {
                ForEach(info.blockingPrerequisites, id: \.id) { prereq in
                    Text("• \(prereq.title)")
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                        .padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private func actionsSection(_ actions: [MilestoneAction]) -> some View {
        let completedCount = RoadmapEngine.completedActionsCount(for: milestone, completedIDs: store.completedActionIDs)
        let totalCount = actions.count
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Actions", systemImage: "checklist.checked").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                Spacer()
                Text("\(completedCount) of \(totalCount)").font(DashFont.labelMd()).foregroundColor(completedCount == totalCount ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
            }
            ProgressView(value: Double(completedCount), total: Double(totalCount))
                .tint(completedCount == totalCount ? StudentOPSTheme.success : StudentOPSTheme.primary)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
            ForEach(actions.sorted(by: { $0.order < $1.order })) { action in
                ActionRow(action: action, isCompleted: store.isActionCompleted(action.id), onToggle: { store.toggleAction(action.id) })
            }
        }
    }

    // MARK: - Learning Resources Section

    @ViewBuilder
    private func learningResourcesSection(_ resources: [MilestoneResource]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Learning Resources", systemImage: "books.vertical").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            ForEach(resources) { resource in
                ResourceRow(resource: resource, onOpen: { openURL(URL(string: resource.url)!) })
            }
        }
    }

    // MARK: - Validation Section

    @ViewBuilder
    private func validationSection(_ assessment: MilestoneAssessment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Knowledge Check", systemImage: "questionmark.circle").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
            switch validationPhase {
            case .notStarted:
                ValidationStartView(
                    questionCount: assessment.questions.count,
                    passThreshold: assessment.passThreshold,
                    hasPassed: store.hasPassedValidation(assessment.id),
                    onStart: {
                        validationPhase = .inProgress
                        currentQuestionIndex = 0
                        selectedAnswers = [:]
                        showExplanation = false
                    }
                )
            case .inProgress:
                ValidationQuestionView(
                    question: assessment.questions[currentQuestionIndex],
                    questionNumber: currentQuestionIndex + 1,
                    totalQuestions: assessment.questions.count,
                    selectedAnswer: selectedAnswers[assessment.questions[currentQuestionIndex].id],
                    showExplanation: showExplanation,
                    onSelect: { index in
                        selectedAnswers[assessment.questions[currentQuestionIndex].id] = index
                        showExplanation = true
                    },
                    onNext: {
                        showExplanation = false
                        if currentQuestionIndex + 1 < assessment.questions.count {
                            currentQuestionIndex += 1
                        } else {
                            let score = RoadmapEngine.score(answers: selectedAnswers, questions: assessment.questions)
                            let pct = RoadmapEngine.percentage(score: score, total: assessment.questions.count)
                            let didPass = RoadmapEngine.passed(percentage: pct, threshold: assessment.passThreshold)
                            let attempt = ValidationAttempt(
                                validationID: assessment.id,
                                selectedAnswers: selectedAnswers,
                                score: score,
                                totalQuestions: assessment.questions.count,
                                percentage: pct,
                                passed: didPass
                            )
                            savedAttempt = attempt
                            store.saveValidationAttempt(attempt)
                            validationPhase = .completed
                        }
                    }
                )
            case .completed:
                if let attempt = savedAttempt {
                    ValidationResultView(
                        attempt: attempt,
                        questions: assessment.questions,
                        onRetry: {
                            validationPhase = .inProgress
                            currentQuestionIndex = 0
                            selectedAnswers = [:]
                            showExplanation = false
                            savedAttempt = nil
                        }
                    )
                }
            }
        }
    }

    private func detailSection(title: String, icon: String, text: String) -> some View { VStack(alignment: .leading, spacing: 5) { Label(title, systemImage: icon).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary); Text(text).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) } }
    private func listSection(title: String, icon: String, values: [String]) -> some View { VStack(alignment: .leading, spacing: 6) { Label(title, systemImage: icon).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary); ForEach(values, id: \.self) { value in Label(value, systemImage: "circle.fill").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).labelStyle(.titleAndIcon) } } }
}

// MARK: - Validation Phases

private enum ValidationPhase {
    case notStarted
    case inProgress
    case completed
}

// MARK: - Validation Start View

private struct ValidationStartView: View {
    let questionCount: Int
    let passThreshold: Int
    let hasPassed: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasPassed {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(StudentOPSTheme.success)
                    Text("You have already passed this validation.")
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.success)
                }
            }
            Text("\(questionCount) questions · \(passThreshold)% to pass")
                .font(DashFont.labelMono())
                .foregroundColor(StudentOPSTheme.textSecondary)
            Button(action: onStart) {
                Label(hasPassed ? "Retake Validation" : "Start Validation", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(hasPassed ? StudentOPSTheme.textSecondary : StudentOPSTheme.primary)
        }
    }
}

// MARK: - Validation Question View

private struct ValidationQuestionView: View {
    let question: ValidationQuestion
    let questionNumber: Int
    let totalQuestions: Int
    let selectedAnswer: Int?
    let showExplanation: Bool
    let onSelect: (Int) -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Question \(questionNumber) of \(totalQuestions)")
                    .font(DashFont.labelMono())
                    .foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                ProgressView(value: Double(questionNumber), total: Double(totalQuestions))
                    .frame(width: 80)
                    .tint(StudentOPSTheme.primary)
            }
            Text(question.question)
                .font(DashFont.bodyMd())
                .foregroundColor(StudentOPSTheme.textPrimary)
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                Button(action: { if !showExplanation { onSelect(index) } }) {
                    HStack(spacing: 10) {
                        Image(systemName: answerIcon(index: index))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(answerColor(index: index))
                            .frame(width: 24)
                        Text(choice)
                            .font(DashFont.bodySm())
                            .foregroundColor(StudentOPSTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(10)
                    .background(answerBackground(index: index))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(answerBorder(index: index), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .disabled(showExplanation)
            }
            if showExplanation {
                VStack(alignment: .leading, spacing: 4) {
                    Label(selectedAnswer == question.correctAnswer ? "Correct!" : "Not quite.", systemImage: selectedAnswer == question.correctAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(DashFont.labelMd())
                        .foregroundColor(selectedAnswer == question.correctAnswer ? StudentOPSTheme.success : .red)
                    Text(question.explanation)
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                }
                .padding(10)
                .background(StudentOPSTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Button(action: onNext) {
                    Text(questionNumber == totalQuestions ? "See Results" : "Next Question")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(StudentOPSTheme.primary)
            }
        }
    }

    private func answerIcon(index: Int) -> String {
        guard let selected = selectedAnswer else { return "circle" }
        if showExplanation && index == question.correctAnswer { return "checkmark.circle.fill" }
        if showExplanation && index == selected && index != question.correctAnswer { return "xmark.circle.fill" }
        return index == selected ? "checkmark.circle.fill" : "circle"
    }

    private func answerColor(index: Int) -> Color {
        guard let selected = selectedAnswer else { return StudentOPSTheme.textSecondary }
        if showExplanation && index == question.correctAnswer { return StudentOPSTheme.success }
        if showExplanation && index == selected && index != question.correctAnswer { return .red }
        return index == selected ? StudentOPSTheme.primary : StudentOPSTheme.textSecondary
    }

    private func answerBackground(index: Int) -> Color {
        guard let selected = selectedAnswer else { return StudentOPSTheme.background }
        if showExplanation && index == question.correctAnswer { return StudentOPSTheme.success.opacity(0.08) }
        if showExplanation && index == selected && index != question.correctAnswer { return Color.red.opacity(0.08) }
        return index == selected ? StudentOPSTheme.primary.opacity(0.08) : StudentOPSTheme.background
    }

    private func answerBorder(index: Int) -> Color {
        guard let selected = selectedAnswer else { return StudentOPSTheme.border.opacity(0.3) }
        if showExplanation && index == question.correctAnswer { return StudentOPSTheme.success.opacity(0.5) }
        if showExplanation && index == selected && index != question.correctAnswer { return Color.red.opacity(0.5) }
        return index == selected ? StudentOPSTheme.primary.opacity(0.5) : StudentOPSTheme.border.opacity(0.3)
    }
}

// MARK: - Validation Result View

private struct ValidationResultView: View {
    let attempt: ValidationAttempt
    let questions: [ValidationQuestion]
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: attempt.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundColor(attempt.passed ? StudentOPSTheme.success : .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attempt.passed ? "Validation Passed" : "Not Passed Yet")
                        .font(DashFont.headlineSm())
                        .foregroundColor(attempt.passed ? StudentOPSTheme.success : .red)
                    Text("\(attempt.score) / \(attempt.totalQuestions) correct")
                        .font(DashFont.labelMono())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
            }
            Text("\(attempt.percentage)%")
                .font(DashFont.headlineLgMobile())
                .foregroundColor(attempt.passed ? StudentOPSTheme.success : .red)
            ProgressView(value: Double(attempt.percentage), total: 100)
                .tint(attempt.passed ? StudentOPSTheme.success : .red)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
            ForEach(questions) { q in
                let wasCorrect = attempt.selectedAnswers[q.id] == q.correctAnswer
                HStack(spacing: 6) {
                    Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(wasCorrect ? StudentOPSTheme.success : .red)
                    Text(q.question)
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            if !attempt.passed {
                Button(action: onRetry) {
                    Label("Try Again", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(StudentOPSTheme.primary)
            }
        }
    }
}

// MARK: - Resource Row

private struct ResourceRow: View {
    let resource: MilestoneResource
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: typeIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(StudentOPSTheme.primaryDark)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(resource.title)
                        .font(DashFont.bodyMd())
                        .foregroundColor(StudentOPSTheme.textPrimary)
                        .lineLimit(2)
                    Text(resource.provider)
                        .font(DashFont.labelMono())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                    Text(resource.description)
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Label(resource.type.rawValue.capitalized, systemImage: "tag")
                        if let time = resource.estimatedTime { Label(time, systemImage: "clock") }
                    }
                    .font(DashFont.labelMono())
                    .foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(StudentOPSTheme.textSecondary)
            }
            .padding(10)
            .background(StudentOPSTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }

    private var typeIcon: String {
        switch resource.type {
        case .article: return "doc.text"
        case .video: return "play.rectangle"
        case .documentation: return "book"
        case .interactive: return "cursorarrow.click.2"
        case .course: return "graduationcap"
        }
    }
}

// MARK: - Action Row

private struct ActionRow: View {
    let action: MilestoneAction
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isCompleted ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(DashFont.bodyMd())
                        .foregroundColor(StudentOPSTheme.textPrimary)
                        .strikethrough(isCompleted, color: StudentOPSTheme.textSecondary)
                    Text(action.description)
                        .font(DashFont.bodySm())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let time = action.estimatedTime {
                        Label(time, systemImage: "clock")
                            .font(DashFont.labelMono())
                            .foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(10)
            .background(isCompleted ? StudentOPSTheme.success.opacity(0.06) : StudentOPSTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isCompleted ? StudentOPSTheme.success.opacity(0.3) : StudentOPSTheme.border.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }
}
