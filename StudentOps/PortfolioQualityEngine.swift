import Foundation

// MARK: - Quality Level

enum PortfolioQualityLevel: String, Codable, Hashable, CaseIterable {
    case basic = "Basic"
    case developing = "Developing"
    case strong = "Strong"

    var displayName: String { rawValue }

    init(score: Int, maxScore: Int) {
        guard maxScore > 0 else { self = .basic; return }
        let percent = Int((Double(score) / Double(maxScore) * 100).rounded())
        if percent >= 70 { self = .strong }
        else if percent >= 40 { self = .developing }
        else { self = .basic }
    }
}

// MARK: - Priority

enum PortfolioImprovementPriority: String, Codable, Hashable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

// MARK: - Dimension

struct PortfolioQualityDimension: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String
    let score: Int
    let maxScore: Int
    let achieved: Bool // score == maxScore
    let relevant: Bool
    let improvement: String? // nil if achieved or not relevant
}

// MARK: - Improvement

struct PortfolioQualityImprovement: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let explanation: String
    let priority: PortfolioImprovementPriority
    let relatedItemIDs: [String]
    let destination: String // e.g., "PortfolioBuilderView", "ProjectDetailView", "EvidenceFormView"
}

// MARK: - Result

struct PortfolioQualityResult: Hashable, Codable {
    let portfolioID: String
    let asOf: Date
    let evaluatedAt: Date
    let overallScore: Int
    let maxScore: Int
    let overallLevel: PortfolioQualityLevel
    let dimensions: [PortfolioQualityDimension]
    let strengths: [String] // titles of achieved dimensions
    let improvements: [PortfolioQualityImprovement]
    var percent: Int {
        guard maxScore > 0 else { return 0 }
        return Int((Double(overallScore) / Double(maxScore) * 100).rounded())
    }
    var summary: String {
        "Based on portfolio sections, selected work, evidence support, documentation, skills, and roadmap connections."
    }
}

// MARK: - Engine

enum PortfolioQualityEngine {

    // MARK: - Public API (AppDataStore convenience)

    @MainActor
    static func evaluate(for portfolio: StudentPortfolio, store: AppDataStore, asOf: Date = Date()) -> PortfolioQualityResult {
        let projects = Dictionary(uniqueKeysWithValues: store.scoredProjects.map { ($0.project.id, $0.project) })
        let roadmaps = Dictionary(uniqueKeysWithValues: RoadmapService.allRoadmaps.map { ($0.id, $0) })
        return evaluate(
            for: portfolio,
            evidenceRecords: store.evidenceRecords,
            achievementRecords: store.achievementRecords,
            projects: projects,
            roadmaps: roadmaps,
            roadmapProgress: store.roadmapProgress,
            activeRoadmapIDs: Set(store.activeRoadmaps.filter { $0.value.status == .active }.map(\.key)),
            asOf: asOf
        )
    }

    // MARK: - Pure Evaluation (deterministic, read-only)

    static func evaluate(
        for portfolio: StudentPortfolio,
        evidenceRecords: [String: EvidenceRecord],
        achievementRecords: [String: Achievement],
        projects: [String: Project],
        roadmaps: [String: Roadmap],
        roadmapProgress: [String: Int],
        activeRoadmapIDs: Set<String>,
        asOf: Date = Date()
    ) -> PortfolioQualityResult {
        // Determine section enablement
        func isEnabled(_ type: PortfolioSectionType) -> Bool {
            portfolio.sections.first(where: { $0.type == type })?.isEnabled ?? true
        }

        // Evidence report for connections
        let evidenceReport = PortfolioEvidenceEngine.report(
            for: portfolio,
            evidenceRecords: evidenceRecords,
            achievementRecords: achievementRecords,
            projects: projects,
            roadmaps: roadmaps,
            asOf: asOf
        )

        var dimensions: [PortfolioQualityDimension] = []
        var improvements: [PortfolioQualityImprovement] = []

        // MARK: A. Identity & Purpose — 10
        do {
            let id = "identity"
            let maxScore = 10
            var score = 0
            var missing: [String] = []

            let titleTrim = portfolio.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasTitle = !titleTrim.isEmpty && titleTrim != "My Portfolio"
            if hasTitle { score += 3 } else { missing.append("title") }

            let headlineTrim = portfolio.headline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasHeadline = !headlineTrim.isEmpty
            if hasHeadline { score += 3 } else { missing.append("headline") }

            let aboutTrim = portfolio.about?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasAbout = !aboutTrim.isEmpty
            if hasAbout { score += 2 } else { missing.append("about") }

            let hasGoals = !portfolio.goals.isEmpty
            if hasGoals { score += 2 } else { missing.append("goals") }

            let relevant = true
            let achieved = score == maxScore
            let improvement: String? = missing.isEmpty ? nil : "Add \(missing.joined(separator: ", ")) to give your portfolio clearer purpose."
            dimensions.append(PortfolioQualityDimension(id: id, title: "Identity & Purpose", description: "Portfolio has useful presentation metadata (title, headline, about, goals).", score: score, maxScore: maxScore, achieved: achieved, relevant: relevant, improvement: improvement))

            if !missing.isEmpty {
                let pri: PortfolioImprovementPriority = missing.contains("title") ? .high : (missing.contains("headline") ? .medium : .low)
                improvements.append(PortfolioQualityImprovement(
                    id: "identity-\(missing.joined(separator: "-"))",
                    title: "Add portfolio \(missing.first ?? "details")",
                    explanation: "Your portfolio is missing \(missing.joined(separator: ", ")). Adding them helps explain who you are and what you’re working toward.",
                    priority: pri,
                    relatedItemIDs: [],
                    destination: "PortfolioBuilderView"
                ))
            }
        }

        // MARK: B. Content Coverage — 15
        do {
            let id = "coverage"
            let maxScore = 15
            // Enabled content sections
            let contentTypes: [PortfolioSectionType] = [.projects, .achievements, .evidence, .skills, .roadmaps]
            let enabledTypes = contentTypes.filter { isEnabled($0) }
            let enabledCount = enabledTypes.count
            if enabledCount == 0 {
                dimensions.append(PortfolioQualityDimension(id: id, title: "Content Coverage", description: "Portfolio has useful selected content across enabled sections.", score: 0, maxScore: 0, achieved: true, relevant: false, improvement: nil))
            } else {
                var covered = 0
                for type in enabledTypes {
                    let hasContent: Bool
                    switch type {
                    case .projects: hasContent = !portfolio.selectedProjectIDs.isEmpty
                    case .achievements: hasContent = !portfolio.selectedAchievementIDs.isEmpty
                    case .evidence: hasContent = !portfolio.selectedEvidenceIDs.isEmpty
                    case .skills: hasContent = !portfolio.selectedSkillIDs.isEmpty
                    case .roadmaps: hasContent = !portfolio.selectedRoadmapIDs.isEmpty
                    default: hasContent = false
                    }
                    if hasContent { covered += 1 }
                }
                let score: Int
                switch covered {
                case 0: score = 0
                case 1: score = 5
                case 2: score = 10
                default: score = 15
                }
                let achieved = covered == enabledCount
                let improvement: String? = covered == enabledCount ? nil : "\(enabledCount - covered) enabled section(s) have no selected content."
                dimensions.append(PortfolioQualityDimension(id: id, title: "Content Coverage", description: "Portfolio has useful selected content across enabled sections (\(covered)/\(enabledCount) sections with content).", score: score, maxScore: maxScore, achieved: achieved, relevant: true, improvement: improvement))
                if covered < enabledCount {
                    let missingTypes = enabledTypes.filter { type in
                        switch type {
                        case .projects: return portfolio.selectedProjectIDs.isEmpty
                        case .achievements: return portfolio.selectedAchievementIDs.isEmpty
                        case .evidence: return portfolio.selectedEvidenceIDs.isEmpty
                        case .skills: return portfolio.selectedSkillIDs.isEmpty
                        case .roadmaps: return portfolio.selectedRoadmapIDs.isEmpty
                        default: return false
                        }
                    }.map { $0.displayName }.joined(separator: ", ")
                    improvements.append(PortfolioQualityImprovement(
                        id: "coverage-missing",
                        title: "Add content to \(missingTypes)",
                        explanation: "Your portfolio has \(covered) of \(enabledCount) enabled content sections with selections. Adding content to \(missingTypes) would make it more complete.",
                        priority: covered == 0 ? .high : .medium,
                        relatedItemIDs: [],
                        destination: "PortfolioBuilderView"
                    ))
                }
            }
        }

        // MARK: C. Project Documentation — 15
        do {
            let id = "projects"
            let maxScore = 15
            let relevant = isEnabled(.projects)
            if !relevant {
                dimensions.append(PortfolioQualityDimension(id: id, title: "Project Documentation", description: "Selected projects are well-documented.", score: 0, maxScore: 0, achieved: true, relevant: false, improvement: nil))
            } else if portfolio.selectedProjectIDs.isEmpty {
                dimensions.append(PortfolioQualityDimension(id: id, title: "Project Documentation", description: "Selected projects are well-documented.", score: 0, maxScore: maxScore, achieved: false, relevant: true, improvement: "No projects selected."))
                improvements.append(PortfolioQualityImprovement(
                    id: "projects-empty",
                    title: "Add a project",
                    explanation: "Your portfolio has no selected projects. Add a project to begin building your portfolio.",
                    priority: .high,
                    relatedItemIDs: [],
                    destination: "PortfolioBuilderView"
                ))
            } else {
                var totalScore = 0
                var projectCount = 0
                var withoutEvidence: [String] = []
                var withoutDescription: [String] = []
                for pid in portfolio.selectedProjectIDs {
                    guard let proj = projects[pid] else { continue } // stale handled elsewhere, skip scoring but count as 0
                    projectCount += 1
                    var s = 0
                    let desc = proj.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !desc.isEmpty && desc.count > 10 { s += 3 } else { withoutDescription.append(pid) }
                    if !proj.skills.isEmpty { s += 2 }
                    // progress info always exists via milestones count, give 1 if milestones non-empty
                    if !proj.milestones.isEmpty { s += 1 }
                    let evs = PortfolioEvidenceEngine.supportingEvidence(forProjectID: pid, evidenceRecords: evidenceRecords)
                    if !evs.isEmpty {
                        s += 5
                        if evs.contains(where: { $0.artifact != nil && $0.artifact?.url != nil }) { s += 2 }
                        // Quality already via evidence, but not double count
                    } else {
                        withoutEvidence.append(pid)
                    }
                    // Artifact via project skills? Already counted via evidence artifact
                    // Clamp per project to 13, then scale to 15? Actually per project max 3+2+1+5+2=13, we scale to 15 via average
                    totalScore += min(s, 13)
                }
                // If some stale projects were skipped, projectCount may be less than selected count; treat stale as 0
                let effectiveCount = max(projectCount, portfolio.selectedProjectIDs.count)
                let avg = effectiveCount > 0 ? Double(totalScore) / Double(effectiveCount) : 0
                // Scale 13 -> 15
                let scaled = Int((avg / 13.0 * Double(maxScore)).rounded())
                let score = min(scaled, maxScore)
                let achieved = score == maxScore
                let improvement: String? = withoutEvidence.isEmpty && withoutDescription.isEmpty ? nil : "Some selected projects lack \(withoutEvidence.isEmpty ? "" : "supporting evidence (\(withoutEvidence.count))")\(withoutEvidence.isEmpty || withoutDescription.isEmpty ? "" : ", ")\(withoutDescription.isEmpty ? "" : "descriptions (\(withoutDescription.count))")."
                dimensions.append(PortfolioQualityDimension(id: id, title: "Project Documentation", description: "Selected projects have descriptions, skills, progress, and supporting evidence.", score: score, maxScore: maxScore, achieved: achieved, relevant: true, improvement: improvement))
                if !withoutEvidence.isEmpty {
                    improvements.append(PortfolioQualityImprovement(
                        id: "projects-evidence-\(withoutEvidence.joined(separator: "-"))",
                        title: "Add evidence to \(withoutEvidence.count) project(s)",
                        explanation: "\(withoutEvidence.count) selected project(s) have no linked evidence. Add evidence where EvidenceRecord.projectID matches the project.",
                        priority: .high,
                        relatedItemIDs: withoutEvidence,
                        destination: "EvidenceFormView"
                    ))
                }
                if !withoutDescription.isEmpty && withoutDescription.count != withoutEvidence.count {
                    improvements.append(PortfolioQualityImprovement(
                        id: "projects-desc-\(withoutDescription.joined(separator: "-"))",
                        title: "Add descriptions to projects",
                        explanation: "\(withoutDescription.count) project(s) have no description. Adding a short description makes them more informative.",
                        priority: .medium,
                        relatedItemIDs: withoutDescription,
                        destination: "ProjectDetailView"
                    ))
                }
            }
        }

        // MARK: D. Evidence Support — 20
        do {
            let id = "evidence-support"
            let maxScore = 20
            // Always relevant
            let relevant = true
            var score = 0
            var missing: [String] = []

            // Selected evidence exists
            if !portfolio.selectedEvidenceIDs.isEmpty {
                score += 5
            } else {
                missing.append("selected evidence")
            }

            // Project evidence coverage
            let selectedProjects = portfolio.selectedProjectIDs
            if !selectedProjects.isEmpty {
                let withEvidence = selectedProjects.filter { pid in !PortfolioEvidenceEngine.supportingEvidence(forProjectID: pid, evidenceRecords: evidenceRecords).isEmpty }.count
                let coverage = Double(withEvidence) / Double(selectedProjects.count)
                // up to 5 points
                let pts = Int((coverage * 5).rounded())
                score += pts
                if withEvidence < selectedProjects.count {
                    missing.append("\(selectedProjects.count - withEvidence) project(s) without evidence")
                }
            } else {
                // No projects, no penalty for this sub-signal, but we already gave 0 for that part
            }

            // Achievement proof coverage
            let selectedAch = portfolio.selectedAchievementIDs
            if !selectedAch.isEmpty {
                let withProof = selectedAch.filter { aid in !PortfolioEvidenceEngine.supportingEvidence(forAchievementID: aid, achievementRecords: achievementRecords, evidenceRecords: evidenceRecords).isEmpty }.count
                let coverage = Double(withProof) / Double(selectedAch.count)
                let pts = Int((coverage * 5).rounded())
                score += pts
                if withProof < selectedAch.count {
                    missing.append("\(selectedAch.count - withProof) achievement(s) without proof")
                }
            }

            // Skill evidence coverage
            let selectedSkills = portfolio.selectedSkillIDs
            if !selectedSkills.isEmpty {
                let withEvidence = selectedSkills.filter { sid in !PortfolioEvidenceEngine.supportingEvidence(forSkillID: sid, evidenceRecords: evidenceRecords).isEmpty }.count
                let coverage = Double(withEvidence) / Double(selectedSkills.count)
                let pts = Int((coverage * 3).rounded())
                score += pts
                if withEvidence < selectedSkills.count {
                    missing.append("\(selectedSkills.count - withEvidence) skill(s) without evidence")
                }
            }

            // Roadmap evidence coverage
            let selectedRoadmaps = portfolio.selectedRoadmapIDs
            if !selectedRoadmaps.isEmpty {
                let withEvidence = selectedRoadmaps.filter { rid in !PortfolioEvidenceEngine.supportingEvidence(forRoadmapID: rid, evidenceRecords: evidenceRecords).isEmpty }.count
                let coverage = Double(withEvidence) / Double(selectedRoadmaps.count)
                let pts = Int((coverage * 2).rounded())
                score += pts
                if withEvidence < selectedRoadmaps.count {
                    missing.append("\(selectedRoadmaps.count - withEvidence) roadmap(s) without evidence")
                }
            }

            score = min(score, maxScore)
            let achieved = score == maxScore
            let improvement: String? = missing.isEmpty ? nil : "Some selected items have no supporting evidence: \(missing.joined(separator: ", "))."
            dimensions.append(PortfolioQualityDimension(id: id, title: "Evidence Support", description: "Selected projects, achievements, skills, and roadmaps have supporting evidence.", score: score, maxScore: maxScore, achieved: achieved, relevant: relevant, improvement: improvement))

            if score < maxScore {
                // Create one improvement per missing category
                if portfolio.selectedEvidenceIDs.isEmpty {
                    improvements.append(PortfolioQualityImprovement(
                        id: "evidence-support-none",
                        title: "Add evidence to your portfolio",
                        explanation: "Your portfolio has no selected evidence. Add evidence from work you’ve completed to support your selections.",
                        priority: .high,
                        relatedItemIDs: [],
                        destination: "EvidenceFormView"
                    ))
                }
                // For each category, if coverage low, add improvement
                if !selectedProjects.isEmpty {
                    let without = selectedProjects.filter { pid in PortfolioEvidenceEngine.supportingEvidence(forProjectID: pid, evidenceRecords: evidenceRecords).isEmpty }
                    if !without.isEmpty {
                        improvements.append(PortfolioQualityImprovement(
                            id: "evidence-support-projects-\(without.joined(separator: "-"))",
                            title: "Add evidence to \(without.count) project(s)",
                            explanation: "\(without.count) selected project(s) have no linked evidence.",
                            priority: .high,
                            relatedItemIDs: without,
                            destination: "ProjectDetailView"
                        ))
                    }
                }
                if !selectedAch.isEmpty {
                    let without = selectedAch.filter { aid in PortfolioEvidenceEngine.supportingEvidence(forAchievementID: aid, achievementRecords: achievementRecords, evidenceRecords: evidenceRecords).isEmpty }
                    if !without.isEmpty {
                        improvements.append(PortfolioQualityImprovement(
                            id: "evidence-support-achievements-\(without.joined(separator: "-"))",
                            title: "Add proof to \(without.count) achievement(s)",
                            explanation: "\(without.count) achievement(s) have no supporting evidence.",
                            priority: .high,
                            relatedItemIDs: without,
                            destination: "AchievementDetailView"
                        ))
                    }
                }
                if !selectedSkills.isEmpty {
                    let without = selectedSkills.filter { sid in PortfolioEvidenceEngine.supportingEvidence(forSkillID: sid, evidenceRecords: evidenceRecords).isEmpty }
                    if !without.isEmpty {
                        improvements.append(PortfolioQualityImprovement(
                            id: "evidence-support-skills-\(without.joined(separator: "-"))",
                            title: "Add evidence for \(without.count) skill(s)",
                            explanation: "\(without.count) selected skill(s) have no linked evidence.",
                            priority: .medium,
                            relatedItemIDs: without,
                            destination: "PortfolioBuilderView"
                        ))
                    }
                }
                if !selectedRoadmaps.isEmpty {
                    let without = selectedRoadmaps.filter { rid in PortfolioEvidenceEngine.supportingEvidence(forRoadmapID: rid, evidenceRecords: evidenceRecords).isEmpty }
                    if !without.isEmpty {
                        improvements.append(PortfolioQualityImprovement(
                            id: "evidence-support-roadmaps-\(without.joined(separator: "-"))",
                            title: "Add evidence to \(without.count) roadmap(s)",
                            explanation: "\(without.count) roadmap(s) have no evidence of progress.",
                            priority: .medium,
                            relatedItemIDs: without,
                            destination: "RoadmapDetailView"
                        ))
                    }
                }
            }
        }

        // MARK: E. Evidence Quality (reuse EvidenceQualityEngine) — part of Evidence Support? Actually separate dimension for quality of selected evidence
        // We will incorporate quality into Evidence Support already via supporting evidence, but we also want to evaluate quality of selected evidence itself
        // However spec says Evidence Quality is via EvidenceQualityEngine but keep separate from connection. We already have Evidence Support covering connections.
        // To avoid double counting, we will not create separate quality dimension; instead we include quality signal inside Evidence Support improvements if needed.
        // But we need a dimension for Evidence Quality? Spec says Evidence Support is one of most meaningful, and Evidence Quality via EvidenceQualityEngine is separate but we can include as part of Evidence Support.
        // For 8.7, we keep Evidence Support as 20 and not separate quality dimension, to keep total 100.

        // MARK: F. Achievement Documentation — 10
        do {
            let id = "achievements"
            let maxScore = 10
            let relevant = isEnabled(.achievements)
            if !relevant {
                dimensions.append(PortfolioQualityDimension(id: id, title: "Achievement Documentation", description: "Selected achievements have descriptions, supporting evidence, and context.", score: 0, maxScore: 0, achieved: true, relevant: false, improvement: nil))
            } else if portfolio.selectedAchievementIDs.isEmpty {
                dimensions.append(PortfolioQualityDimension(id: id, title: "Achievement Documentation", description: "Selected achievements have descriptions, supporting evidence, and context.", score: 0, maxScore: maxScore, achieved: false, relevant: true, improvement: "No achievements selected."))
                improvements.append(PortfolioQualityImprovement(
                    id: "achievements-empty",
                    title: "Add an achievement",
                    explanation: "Your portfolio has no selected achievements. Add an achievement that is supported by evidence.",
                    priority: .medium,
                    relatedItemIDs: [],
                    destination: "PortfolioBuilderView"
                ))
            } else {
                var total = 0
                var count = 0
                var withoutEvidence: [String] = []
                var withoutDesc: [String] = []
                for aid in portfolio.selectedAchievementIDs {
                    guard let ach = achievementRecords[aid] else { continue } // stale handled as 0
                    count += 1
                    var s = 0
                    let desc = ach.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !desc.isEmpty && desc.count > 10 { s += 2 } else { withoutDesc.append(aid) }
                    let evs = PortfolioEvidenceEngine.supportingEvidence(forAchievementID: aid, achievementRecords: achievementRecords, evidenceRecords: evidenceRecords)
                    if !evs.isEmpty {
                        s += 4
                        // quality of supporting evidence
                        let hasStrong = evs.contains { EvidenceQualityEngine.quality(for: $0).overallLevel == .strong }
                        if hasStrong { s += 1 }
                    } else { withoutEvidence.append(aid) }
                    if ach.skillIDs != nil && !(ach.skillIDs!.isEmpty) { s += 1 }
                    if ach.roadmapID != nil || ach.projectID != nil || ach.opportunityID != nil { s += 1 }
                    // max per achievement 4+2+1+1=8, scale to 10
                    total += min(s, 8)
                }
                let effectiveCount = max(count, portfolio.selectedAchievementIDs.count)
                let avg = effectiveCount > 0 ? Double(total) / Double(effectiveCount) : 0
                let scaled = Int((avg / 8.0 * Double(maxScore)).rounded())
                let score = min(scaled, maxScore)
                let achieved = score == maxScore
                let improvement: String? = withoutEvidence.isEmpty && withoutDesc.isEmpty ? nil : "Some achievements lack \(withoutEvidence.isEmpty ? "" : "supporting evidence (\(withoutEvidence.count))")\(withoutEvidence.isEmpty || withoutDesc.isEmpty ? "" : ", ")\(withoutDesc.isEmpty ? "" : "descriptions (\(withoutDesc.count))")."
                dimensions.append(PortfolioQualityDimension(id: id, title: "Achievement Documentation", description: "Selected achievements have descriptions, supporting evidence, and context.", score: score, maxScore: maxScore, achieved: achieved, relevant: true, improvement: improvement))
                if !withoutEvidence.isEmpty {
                    improvements.append(PortfolioQualityImprovement(
                        id: "achievements-evidence-\(withoutEvidence.joined(separator: "-"))",
                        title: "Add proof to \(withoutEvidence.count) achievement(s)",
                        explanation: "\(withoutEvidence.count) achievement(s) have no supporting evidence.",
                        priority: .high,
                        relatedItemIDs: withoutEvidence,
                        destination: "EvidenceFormView"
                    ))
                }
            }
        }

        // MARK: G. Skill Support — 10
        do {
            let id = "skills"
            let maxScore = 10
            let relevant = isEnabled(.skills)
            if !relevant {
                dimensions.append(PortfolioQualityDimension(id: id, title: "Skill Support", description: "Selected skills have supporting evidence.", score: 0, maxScore: 0, achieved: true, relevant: false, improvement: nil))
            } else if portfolio.selectedSkillIDs.isEmpty {
                dimensions.append(PortfolioQualityDimension(id: id, title: "Skill Support", description: "Selected skills have supporting evidence.", score: 0, maxScore: maxScore, achieved: false, relevant: true, improvement: "No skills selected."))
                improvements.append(PortfolioQualityImprovement(
                    id: "skills-empty",
                    title: "Add a demonstrated skill",
                    explanation: "Your portfolio has no selected skills. Add a skill you’ve demonstrated.",
                    priority: .medium,
                    relatedItemIDs: [],
                    destination: "PortfolioBuilderView"
                ))
            } else {
                var withEvidence = 0
                var without: [String] = []
                for raw in portfolio.selectedSkillIDs {
                    let norm = Skill.normalizeID(raw)
                    let evs = PortfolioEvidenceEngine.supportingEvidence(forSkillID: norm, evidenceRecords: evidenceRecords)
                    if !evs.isEmpty {
                        withEvidence += 1
                    } else {
                        without.append(raw)
                    }
                }
                let coverage = Double(withEvidence) / Double(portfolio.selectedSkillIDs.count)
                let score = Int((coverage * Double(maxScore)).rounded())
                let achieved = withEvidence == portfolio.selectedSkillIDs.count
                let improvement: String? = without.isEmpty ? nil : "\(without.count) skill(s) have no linked evidence."
                dimensions.append(PortfolioQualityDimension(id: id, title: "Skill Support", description: "Selected skills have supporting evidence (\(withEvidence)/\(portfolio.selectedSkillIDs.count)).", score: score, maxScore: maxScore, achieved: achieved, relevant: true, improvement: improvement))
                if !without.isEmpty {
                    improvements.append(PortfolioQualityImprovement(
                        id: "skills-evidence-\(without.joined(separator: "-"))",
                        title: "Add evidence for \(without.count) skill(s)",
                        explanation: "\(without.count) selected skill(s) have no linked evidence records.",
                        priority: .medium,
                        relatedItemIDs: without,
                        destination: "EvidenceFormView"
                    ))
                }
            }
        }

        // MARK: H. Roadmap / Direction — 10
        do {
            let id = "roadmaps"
            let maxScore = 10
            let relevant = isEnabled(.roadmaps)
            if !relevant {
                dimensions.append(PortfolioQualityDimension(id: id, title: "Roadmap / Direction", description: "Selected roadmaps show meaningful direction and progress.", score: 0, maxScore: 0, achieved: true, relevant: false, improvement: nil))
            } else if portfolio.selectedRoadmapIDs.isEmpty {
                dimensions.append(PortfolioQualityDimension(id: id, title: "Roadmap / Direction", description: "Selected roadmaps show meaningful direction and progress.", score: 0, maxScore: maxScore, achieved: false, relevant: true, improvement: "No roadmaps selected."))
                improvements.append(PortfolioQualityImprovement(
                    id: "roadmaps-empty",
                    title: "Add a roadmap to show direction",
                    explanation: "Your portfolio has no selected roadmaps. Add a roadmap to communicate what you’re working toward.",
                    priority: .low,
                    relatedItemIDs: [],
                    destination: "RoadmapsView"
                ))
            } else {
                var total = 0
                var count = 0
                var withoutEvidence: [String] = []
                var withoutProgress: [String] = []
                for rid in portfolio.selectedRoadmapIDs {
                    guard let rm = roadmaps[rid] else { continue } // stale handled as 0
                    count += 1
                    var s = 0
                    // exists
                    s += 2
                    let isActive = activeRoadmapIDs.contains(rid)
                    if isActive { s += 3 } else {
                        // even inactive with progress is okay, but active is stronger
                    }
                    let completed = min(roadmapProgress[rid] ?? 0, rm.milestones.count)
                    if completed > 0 {
                        s += 3
                    } else {
                        withoutProgress.append(rid)
                    }
                    let evs = PortfolioEvidenceEngine.supportingEvidence(forRoadmapID: rid, evidenceRecords: evidenceRecords)
                    if !evs.isEmpty {
                        s += 2
                    } else {
                        withoutEvidence.append(rid)
                    }
                    // max per roadmap 2+3+3+2=10
                    total += min(s, 10)
                }
                let effectiveCount = max(count, portfolio.selectedRoadmapIDs.count)
                let avg = effectiveCount > 0 ? Double(total) / Double(effectiveCount) : 0
                let score = Int(avg.rounded())
                let achieved = score == maxScore
                let improvement: String? = withoutEvidence.isEmpty && withoutProgress.isEmpty ? nil : "\(withoutProgress.isEmpty ? "" : "\(withoutProgress.count) roadmap(s) with no progress")\(withoutProgress.isEmpty || withoutEvidence.isEmpty ? "" : ", ")\(withoutEvidence.isEmpty ? "" : "\(withoutEvidence.count) without evidence")."
                dimensions.append(PortfolioQualityDimension(id: id, title: "Roadmap / Direction", description: "Selected roadmaps show meaningful direction and progress.", score: score, maxScore: maxScore, achieved: achieved, relevant: true, improvement: improvement))
                if !withoutEvidence.isEmpty {
                    improvements.append(PortfolioQualityImprovement(
                        id: "roadmaps-evidence-\(withoutEvidence.joined(separator: "-"))",
                        title: "Add evidence to \(withoutEvidence.count) roadmap(s)",
                        explanation: "\(withoutEvidence.count) roadmap(s) have no evidence of progress.",
                        priority: .low,
                        relatedItemIDs: withoutEvidence,
                        destination: "EvidenceFormView"
                    ))
                }
            }
        }

        // MARK: I. Internal Connections — 10
        do {
            let id = "connections"
            let maxScore = 10
            // Always relevant
            let relevant = true
            var score = 0
            var missing: [String] = []

            // Orphaned evidence
            let orphaned = evidenceReport.orphanedEvidenceIDs
            let selectedEvidenceCount = portfolio.selectedEvidenceIDs.count
            if selectedEvidenceCount == 0 {
                // No evidence, no orphaned penalty, but also no bonus
                // Score 0 for orphaned part, but we give 5 if no evidence? Actually no evidence means no orphaned, so we give 5
                score += 5
            } else if orphaned.isEmpty {
                score += 5
            } else {
                let orphanedRatio = Double(orphaned.count) / Double(selectedEvidenceCount)
                let pts = Int((5 * (1 - orphanedRatio)).rounded())
                score += pts
                missing.append("\(orphaned.count) standalone evidence")
            }

            // Evidence used by multiple items (coherence)
            let hasMulti = evidenceReport.evidenceUsageCount.values.contains(where: { $0 >= 2 })
            if hasMulti {
                score += 3
            } else {
                if selectedEvidenceCount > 0 && (portfolio.selectedProjectIDs.count + portfolio.selectedAchievementIDs.count + portfolio.selectedSkillIDs.count + portfolio.selectedRoadmapIDs.count) > 1 {
                    missing.append("no evidence reused across items")
                }
            }

            // At least 2 types of connections present
            var typesWithConnections = 0
            if !(evidenceReport.projectEvidence.values.flatMap({ $0 }).isEmpty) { typesWithConnections += 1 }
            if !(evidenceReport.achievementEvidence.values.flatMap({ $0 }).isEmpty) { typesWithConnections += 1 }
            if !(evidenceReport.skillEvidence.values.flatMap({ $0 }).isEmpty) { typesWithConnections += 1 }
            if !(evidenceReport.roadmapEvidence.values.flatMap({ $0 }).isEmpty) { typesWithConnections += 1 }
            if typesWithConnections >= 2 {
                score += 2
            } else if selectedEvidenceCount > 0 {
                missing.append("limited connection types (\(typesWithConnections))")
            }

            score = min(score, maxScore)
            let achieved = score == maxScore
            let improvement: String? = missing.isEmpty ? nil : "Internal connections could be stronger: \(missing.joined(separator: ", "))."
            dimensions.append(PortfolioQualityDimension(id: id, title: "Internal Connections", description: "Selected content connects together via evidence (orphaned evidence, reuse, multi-type connections).", score: score, maxScore: maxScore, achieved: achieved, relevant: relevant, improvement: improvement))

            if !orphaned.isEmpty {
                improvements.append(PortfolioQualityImprovement(
                    id: "connections-orphaned-\(orphaned.joined(separator: "-"))",
                    title: "Connect \(orphaned.count) standalone evidence",
                    explanation: "\(orphaned.count) selected evidence record(s) are not currently connected to another portfolio item. Consider linking them to a project, skill, or roadmap, or keep as standalone if intentional.",
                    priority: .low,
                    relatedItemIDs: orphaned,
                    destination: "PortfolioBuilderView"
                ))
            }
            if !hasMulti && selectedEvidenceCount > 0 {
                improvements.append(PortfolioQualityImprovement(
                    id: "connections-multi",
                    title: "Evidence reuse",
                    explanation: "No evidence is currently supporting multiple portfolio items. Evidence that supports multiple items can show coherence (e.g., a project linked to a skill and roadmap).",
                    priority: .low,
                    relatedItemIDs: [],
                    destination: "PortfolioBuilderView"
                ))
            }
        }

        // MARK: Unresolved references — affects overall score slightly via penalty, but also separate dimension?
        // We will not create separate dimension for unresolved, but we will add improvement and also deduct from overall if unresolved exists
        // Instead, we will treat unresolved as improvement and also lower overall score by 5 if any unresolved
        var overallScore = dimensions.filter(\.relevant).reduce(0) { $0 + $1.score }
        let maxScore = dimensions.filter(\.relevant).reduce(0) { $0 + $1.maxScore }

        // Deduct for unresolved references (reliability)
        let unresolvedCount = evidenceReport.unresolved.count
        // Also check stale project/achievement/roadmap references via evidenceReport? Already includes evidence unresolved, but also portfolio selected IDs that are stale (via PortfolioEngine unresolved)
        // For simplicity, check portfolio selected IDs that are stale via direct lookup: if project not in projects, etc.
        var staleSelectedCount = 0
        for pid in portfolio.selectedProjectIDs where projects[pid] == nil { staleSelectedCount += 1 }
        for aid in portfolio.selectedAchievementIDs where achievementRecords[aid] == nil { staleSelectedCount += 1 }
        for eid in portfolio.selectedEvidenceIDs where evidenceRecords[eid] == nil { staleSelectedCount += 1 }
        for rid in portfolio.selectedRoadmapIDs where roadmaps[rid] == nil { staleSelectedCount += 1 }
        // Skills: if selected skill not demonstrated? That's not stale per se, but we already handle via skill support
        let totalUnresolved = unresolvedCount + staleSelectedCount
        if totalUnresolved > 0 {
            let penalty = min(5, totalUnresolved * 2)
            overallScore = max(0, overallScore - penalty)
            improvements.append(PortfolioQualityImprovement(
                id: "unresolved-\(totalUnresolved)",
                title: "\(totalUnresolved) selected item(s) unavailable",
                explanation: "\(totalUnresolved) selected item(s) could not be resolved (missing project, achievement, evidence, or roadmap). Remove them to keep the portfolio reliable.",
                priority: .high,
                relatedItemIDs: [],
                destination: "PortfolioBuilderView"
            ))
            // Also add dimension for unresolved? We already have dimensions, but we will not add new dimension, just penalty
        }

        let overallLevel = PortfolioQualityLevel(score: overallScore, maxScore: maxScore)
        let strengths = dimensions.filter { $0.relevant && $0.achieved }.map { $0.title }
        // Sort improvements by priority (high->medium->low) then id
        let priorityRank: [PortfolioImprovementPriority: Int] = [.high: 0, .medium: 1, .low: 2]
        let sortedImprovements = improvements.sorted {
            if priorityRank[$0.priority] != priorityRank[$1.priority] {
                return priorityRank[$0.priority]! < priorityRank[$1.priority]!
            }
            return $0.id < $1.id
        }
        // Dedup improvements by id
        var seenImp = Set<String>()
        var dedupedImprovements: [PortfolioQualityImprovement] = []
        for imp in sortedImprovements where !seenImp.contains(imp.id) {
            seenImp.insert(imp.id)
            dedupedImprovements.append(imp)
        }

        return PortfolioQualityResult(
            portfolioID: portfolio.id,
            asOf: asOf,
            evaluatedAt: Date(),
            overallScore: overallScore,
            maxScore: maxScore,
            overallLevel: overallLevel,
            dimensions: dimensions,
            strengths: strengths,
            improvements: dedupedImprovements
        )
    }

    // MARK: - Helpers

    private static func isValidArtifact(_ artifact: EvidenceArtifact?) -> Bool {
        guard let art = artifact, let urlStr = art.url?.trimmingCharacters(in: .whitespacesAndNewlines), !urlStr.isEmpty else { return false }
        guard let url = URL(string: urlStr) else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
        return url.host != nil
    }
}
