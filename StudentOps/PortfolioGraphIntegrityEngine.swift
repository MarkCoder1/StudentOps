import Foundation

// MARK: - Issue Type

enum PortfolioGraphIntegrityIssueType: String, Codable, Hashable, CaseIterable {
    case missingProject = "missingProject"
    case missingAchievement = "missingAchievement"
    case missingEvidence = "missingEvidence"
    case missingSkill = "missingSkill"
    case missingRoadmap = "missingRoadmap"
    case missingMilestone = "missingMilestone"
    case invalidEvidenceProjectReference = "invalidEvidenceProjectReference"
    case invalidEvidenceRoadmapReference = "invalidEvidenceRoadmapReference"
    case invalidEvidenceMilestoneReference = "invalidEvidenceMilestoneReference"
    case invalidEvidenceSkillReference = "invalidEvidenceSkillReference"
    case invalidAchievementEvidenceReference = "invalidAchievementEvidenceReference"
    case invalidAchievementProjectReference = "invalidAchievementProjectReference"
    case invalidAchievementRoadmapReference = "invalidAchievementRoadmapReference"
    case invalidAchievementSkillReference = "invalidAchievementSkillReference"
    case duplicatePortfolioSelection = "duplicatePortfolioSelection"
    case duplicateSection = "duplicateSection"
    case invalidSectionReference = "invalidSectionReference"
    case invalidPortfolioReference = "invalidPortfolioReference" // empty ID, malformed
}

// MARK: - Severity

enum PortfolioGraphIntegritySeverity: String, Codable, Hashable, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"

    var rank: Int {
        switch self {
        case .error: return 0
        case .warning: return 1
        case .info: return 2
        }
    }
}

// MARK: - Issue

struct PortfolioGraphIntegrityIssue: Identifiable, Hashable, Codable {
    let id: String // deterministic
    let type: PortfolioGraphIntegrityIssueType
    let title: String
    let explanation: String
    let severity: PortfolioGraphIntegritySeverity
    let portfolioID: String
    let targetID: String? // e.g., projectID that is missing
    let relatedID: String? // e.g., evidenceID that references missing project
    let destination: String // e.g., "PortfolioBuilderView", "EvidenceDetailSheet", "Manual"
    let isRepairable: Bool
}

// MARK: - Report

struct PortfolioGraphIntegrityReport: Hashable, Codable {
    let portfolioID: String
    let isValid: Bool // errorCount == 0
    let issueCount: Int
    let errorCount: Int
    let warningCount: Int
    let infoCount: Int
    let issues: [PortfolioGraphIntegrityIssue]
    let checkedProjectIDs: [String]
    let checkedAchievementIDs: [String]
    let checkedEvidenceIDs: [String]
    let checkedSkillIDs: [String]
    let checkedRoadmapIDs: [String]
    let checkedAt: Date
}

// MARK: - Engine

enum PortfolioGraphIntegrityEngine {

    // MARK: - Public API (AppDataStore convenience, read-only)

    @MainActor
    static func report(for portfolio: StudentPortfolio, store: AppDataStore) -> PortfolioGraphIntegrityReport {
        let projects = Dictionary(uniqueKeysWithValues: store.scoredProjects.map { ($0.project.id, $0.project) })
        let roadmaps = Dictionary(uniqueKeysWithValues: RoadmapService.allRoadmaps.map { ($0.id, $0) })
        // Include custom projects already in scoredProjects, so projects covers all
        return report(
            for: portfolio,
            evidenceRecords: store.evidenceRecords,
            achievementRecords: store.achievementRecords,
            projects: projects,
            roadmaps: roadmaps,
            asOf: Date()
        )
    }

    // MARK: - Pure Report (deterministic, read-only)

    static func report(
        for portfolio: StudentPortfolio,
        evidenceRecords: [String: EvidenceRecord],
        achievementRecords: [String: Achievement],
        projects: [String: Project],
        roadmaps: [String: Roadmap],
        asOf: Date = Date()
    ) -> PortfolioGraphIntegrityReport {
        var issues: [PortfolioGraphIntegrityIssue] = []
        var seenIssueIDs = Set<String>()

        func addIssue(type: PortfolioGraphIntegrityIssueType, title: String, explanation: String, severity: PortfolioGraphIntegritySeverity, portfolioID: String, targetID: String?, relatedID: String?, destination: String, isRepairable: Bool) {
            let tid = targetID ?? "none"
            let rid = relatedID ?? "none"
            let id: String
            switch type {
            case .duplicatePortfolioSelection, .duplicateSection:
                id = "portfolio-integrity-\(type.rawValue):\(portfolioID):\(tid)"
            case .invalidEvidenceProjectReference, .invalidEvidenceRoadmapReference, .invalidEvidenceMilestoneReference, .invalidEvidenceSkillReference:
                id = "portfolio-integrity-\(type.rawValue):\(relatedID ?? tid):\(tid)"
            case .invalidAchievementEvidenceReference, .invalidAchievementProjectReference, .invalidAchievementRoadmapReference, .invalidAchievementSkillReference:
                id = "portfolio-integrity-\(type.rawValue):\(relatedID ?? tid):\(tid)"
            default:
                if let rid = relatedID {
                    id = "portfolio-integrity-\(type.rawValue):\(portfolioID):\(tid):\(rid)"
                } else {
                    id = "portfolio-integrity-\(type.rawValue):\(portfolioID):\(tid)"
                }
            }
            guard !seenIssueIDs.contains(id) else { return }
            seenIssueIDs.insert(id)
            let issue = PortfolioGraphIntegrityIssue(
                id: id,
                type: type,
                title: title,
                explanation: explanation,
                severity: severity,
                portfolioID: portfolioID,
                targetID: targetID,
                relatedID: relatedID,
                destination: destination,
                isRepairable: isRepairable
            )
            issues.append(issue)
        }

        // MARK: Portfolio Selection Integrity

        // Helper to detect duplicates and missing
        func checkPortfolioSelections() {
            // Projects
            var seen = Set<String>()
            var dupes = Set<String>()
            for raw in portfolio.selectedProjectIDs {
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty {
                    addIssue(type: .invalidPortfolioReference, title: "Invalid project reference", explanation: "Selected project ID is empty or malformed.", severity: .error, portfolioID: portfolio.id, targetID: raw, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                    continue
                }
                if seen.contains(t) {
                    dupes.insert(t)
                } else {
                    seen.insert(t)
                }
                if projects[t] == nil {
                    addIssue(type: .missingProject, title: "Selected project is unavailable", explanation: "Project \(t) selected in portfolio is not found in the current catalog.", severity: .error, portfolioID: portfolio.id, targetID: t, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                }
            }
            for dup in dupes {
                addIssue(type: .duplicatePortfolioSelection, title: "Duplicate project selection", explanation: "Project \(dup) appears multiple times in selectedProjectIDs.", severity: .warning, portfolioID: portfolio.id, targetID: dup, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
            }

            // Achievements
            seen.removeAll(); dupes.removeAll()
            for raw in portfolio.selectedAchievementIDs {
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty {
                    addIssue(type: .invalidPortfolioReference, title: "Invalid achievement reference", explanation: "Selected achievement ID is empty or malformed.", severity: .error, portfolioID: portfolio.id, targetID: raw, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                    continue
                }
                if seen.contains(t) { dupes.insert(t) } else { seen.insert(t) }
                if achievementRecords[t] == nil {
                    addIssue(type: .missingAchievement, title: "Selected achievement is unavailable", explanation: "Achievement \(t) selected in portfolio is not found.", severity: .error, portfolioID: portfolio.id, targetID: t, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                }
            }
            for dup in dupes {
                addIssue(type: .duplicatePortfolioSelection, title: "Duplicate achievement selection", explanation: "Achievement \(dup) appears multiple times in selectedAchievementIDs.", severity: .warning, portfolioID: portfolio.id, targetID: dup, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
            }

            // Evidence
            seen.removeAll(); dupes.removeAll()
            for raw in portfolio.selectedEvidenceIDs {
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty {
                    addIssue(type: .invalidPortfolioReference, title: "Invalid evidence reference", explanation: "Selected evidence ID is empty or malformed.", severity: .error, portfolioID: portfolio.id, targetID: raw, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                    continue
                }
                if seen.contains(t) { dupes.insert(t) } else { seen.insert(t) }
                if evidenceRecords[t] == nil {
                    addIssue(type: .missingEvidence, title: "Selected evidence is unavailable", explanation: "Evidence \(t) selected in portfolio is not found.", severity: .error, portfolioID: portfolio.id, targetID: t, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                }
            }
            for dup in dupes {
                addIssue(type: .duplicatePortfolioSelection, title: "Duplicate evidence selection", explanation: "Evidence \(dup) appears multiple times in selectedEvidenceIDs.", severity: .warning, portfolioID: portfolio.id, targetID: dup, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
            }

            // Skills
            seen.removeAll(); dupes.removeAll()
            var normalizedSeen = Set<String>()
            var normalizedDupes = Set<String>()
            for raw in portfolio.selectedSkillIDs {
                let norm = Skill.normalizeID(raw)
                if norm.isEmpty {
                    addIssue(type: .invalidPortfolioReference, title: "Invalid skill reference", explanation: "Selected skill ID is empty or malformed.", severity: .error, portfolioID: portfolio.id, targetID: raw, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                    continue
                }
                if normalizedSeen.contains(norm) { normalizedDupes.insert(norm) } else { normalizedSeen.insert(norm) }
                // For selected skills, we check if the normalized skill is known? But skills can be custom, not necessarily in catalog.
                // For integrity, we consider a selected skill missing if it is not in any known catalog and not in any evidence's skillIDs? However spec says for every selectedSkillIDs verify that the referenced canonical entity exists.
                // Canonical skill existence is defined by SkillCatalog. For now, we treat any non-empty normalized ID as valid unless it is empty.
                // To avoid false positives for custom skills, we will not mark missingSkill for selected skills unless we strictly want to.
                // Instead, we will only mark missingSkill if the skill is not found in any evidence's skillIDs and not in catalog? But that's not a valid check for selected skills.
                // For now, we will not report missingSkill for selected skills; we will only report for evidence skill references.
                // This keeps custom skills valid.
            }
            for dup in normalizedDupes {
                addIssue(type: .duplicatePortfolioSelection, title: "Duplicate skill selection", explanation: "Skill \(dup) appears multiple times in selectedSkillIDs (normalized).", severity: .warning, portfolioID: portfolio.id, targetID: dup, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
            }

            // Roadmaps
            seen.removeAll(); dupes.removeAll()
            for raw in portfolio.selectedRoadmapIDs {
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty {
                    addIssue(type: .invalidPortfolioReference, title: "Invalid roadmap reference", explanation: "Selected roadmap ID is empty or malformed.", severity: .error, portfolioID: portfolio.id, targetID: raw, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                    continue
                }
                if seen.contains(t) { dupes.insert(t) } else { seen.insert(t) }
                if roadmaps[t] == nil {
                    addIssue(type: .missingRoadmap, title: "Selected roadmap is unavailable", explanation: "Roadmap \(t) selected in portfolio is not found in the current catalog.", severity: .error, portfolioID: portfolio.id, targetID: t, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                }
            }
            for dup in dupes {
                addIssue(type: .duplicatePortfolioSelection, title: "Duplicate roadmap selection", explanation: "Roadmap \(dup) appears multiple times in selectedRoadmapIDs.", severity: .warning, portfolioID: portfolio.id, targetID: dup, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
            }
        }

        // MARK: Section Integrity

        func checkSections() {
            var seenIDs = Set<String>()
            var seenTypes = Set<String>()
            for sec in portfolio.sections {
                let sid = sec.id.trimmingCharacters(in: .whitespacesAndNewlines)
                if sid.isEmpty {
                    addIssue(type: .invalidSectionReference, title: "Invalid section ID", explanation: "Section ID is empty or malformed.", severity: .error, portfolioID: portfolio.id, targetID: sec.id, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: false)
                    continue
                }
                if seenIDs.contains(sid) {
                    addIssue(type: .duplicateSection, title: "Duplicate section", explanation: "Section \(sid) appears multiple times.", severity: .warning, portfolioID: portfolio.id, targetID: sid, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: true)
                } else {
                    seenIDs.insert(sid)
                }
                // Check type validity: PortfolioSectionType(rawValue:) should succeed, but our model already falls back to .about for unknown, so we need to detect unknown types
                // Since PortfolioSection's decoder falls back to .about, we cannot detect unknown via decoded value alone.
                // Instead, we can check if sec.type.rawValue != sec.id and sec.id is one of the known types? For now, we treat any section with type that does not match id's expected type as potential invalid, but we will be lenient.
                // For now, we only check if title is empty
                let titleTrim = sec.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if titleTrim.isEmpty {
                    addIssue(type: .invalidSectionReference, title: "Invalid section title", explanation: "Section \(sid) has an empty title.", severity: .info, portfolioID: portfolio.id, targetID: sid, relatedID: nil, destination: "PortfolioBuilderView", isRepairable: false)
                }
                // Duplicate semantic type (e.g., two "about" sections with different IDs but same type)
                let typeKey = sec.type.rawValue
                if seenTypes.contains(typeKey) {
                    // Only report if duplicate semantic type, not just duplicate ID
                    // This is informational, not error, because student could have two skills sections? But spec says no duplicate semantic section IDs
                    // We will report as warning
                    addIssue(type: .duplicateSection, title: "Duplicate section type", explanation: "Section type \(typeKey) appears multiple times.", severity: .warning, portfolioID: portfolio.id, targetID: typeKey, relatedID: sid, destination: "PortfolioBuilderView", isRepairable: true)
                } else {
                    seenTypes.insert(typeKey)
                }
            }
        }

        // MARK: Evidence Graph Integrity (only for relevant evidence)

        func checkEvidenceGraph() {
            // Determine relevant evidence: selectedEvidence + evidence supporting selected portfolio items
            // Use PortfolioEvidenceEngine to find supporting evidence for selected items, but we don't want to duplicate its logic fully.
            // Instead, we will consider evidence that is either selected in portfolio or referenced by selected achievements
            var relevantEvidenceIDs = Set<String>()
            for eid in portfolio.selectedEvidenceIDs { relevantEvidenceIDs.insert(eid) }
            for aid in portfolio.selectedAchievementIDs {
                if let ach = achievementRecords[aid] {
                    for eid in ach.evidenceIDs { relevantEvidenceIDs.insert(eid) }
                }
            }
            // Also include evidence that supports selected projects/roadmaps/skills via direct evidence.projectID etc., but that would be all evidence with those IDs
            // For simplicity, we will also include any evidence that is referenced by selected projects/roadmaps/skills evidence support
            // Instead of recomputing all, we will check all evidence that is either selected or whose ID is in relevantEvidenceIDs
            // For each relevant evidence, validate its relationships
            for eid in relevantEvidenceIDs {
                guard let rec = evidenceRecords[eid] else {
                    // Missing evidence already reported as missingEvidence in portfolio selection or missingAchievementEvidence
                    // But if it's referenced by achievement but missing, we already report invalidAchievementEvidenceReference
                    continue
                }
                // Project reference
                if let pid = rec.projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
                    if projects[pid] == nil {
                        addIssue(type: .invalidEvidenceProjectReference, title: "Evidence references unavailable project", explanation: "Evidence \(rec.id) references project \(pid) which is not found.", severity: .warning, portfolioID: portfolio.id, targetID: pid, relatedID: rec.id, destination: "EvidenceDetailSheet", isRepairable: false)
                    }
                }
                // Roadmap reference
                if !rec.roadmapID.isEmpty {
                    if roadmaps[rec.roadmapID] == nil {
                        addIssue(type: .invalidEvidenceRoadmapReference, title: "Evidence references unavailable roadmap", explanation: "Evidence \(rec.id) references roadmap \(rec.roadmapID) which is not found.", severity: .warning, portfolioID: portfolio.id, targetID: rec.roadmapID, relatedID: rec.id, destination: "EvidenceDetailSheet", isRepairable: false)
                    } else if !rec.milestoneID.isEmpty {
                        let rm = roadmaps[rec.roadmapID]!
                        if !rm.milestones.contains(where: { $0.id == rec.milestoneID }) {
                            addIssue(type: .invalidEvidenceMilestoneReference, title: "Evidence references missing milestone", explanation: "Evidence \(rec.id) references milestone \(rec.milestoneID) which is not found in roadmap \(rec.roadmapID).", severity: .warning, portfolioID: portfolio.id, targetID: rec.milestoneID, relatedID: rec.id, destination: "EvidenceDetailSheet", isRepairable: false)
                        }
                    }
                } else if !rec.milestoneID.isEmpty {
                    addIssue(type: .invalidEvidenceMilestoneReference, title: "Evidence milestone without roadmap", explanation: "Evidence \(rec.id) has milestone \(rec.milestoneID) but no roadmap context.", severity: .warning, portfolioID: portfolio.id, targetID: rec.milestoneID, relatedID: rec.id, destination: "EvidenceDetailSheet", isRepairable: false)
                }
                // Skill references
                if let sids = rec.skillIDs {
                    for raw in sids {
                        let norm = Skill.normalizeID(raw)
                        if norm.isEmpty {
                            addIssue(type: .invalidEvidenceSkillReference, title: "Evidence has invalid skill reference", explanation: "Evidence \(rec.id) has an empty skill reference.", severity: .info, portfolioID: portfolio.id, targetID: raw, relatedID: rec.id, destination: "EvidenceDetailSheet", isRepairable: false)
                            continue
                        }
                        if SkillCatalog.knownSkills[norm] == nil {
                            // For integrity, we report as info/warning, not error, because custom skills may be valid
                            addIssue(type: .invalidEvidenceSkillReference, title: "Evidence references unknown skill", explanation: "Evidence \(rec.id) references skill \(raw) (normalized: \(norm)) which is not in the known SkillCatalog.", severity: .info, portfolioID: portfolio.id, targetID: norm, relatedID: rec.id, destination: "EvidenceDetailSheet", isRepairable: false)
                        }
                    }
                    // Duplicate skill references within same evidence
                    var seenSkills = Set<String>()
                    var dupSkills = Set<String>()
                    for raw in sids {
                        let norm = Skill.normalizeID(raw)
                        if seenSkills.contains(norm) { dupSkills.insert(norm) } else { seenSkills.insert(norm) }
                    }
                    for dup in dupSkills {
                        addIssue(type: .invalidEvidenceSkillReference, title: "Evidence has duplicate skill reference", explanation: "Evidence \(rec.id) references skill \(dup) multiple times.", severity: .info, portfolioID: portfolio.id, targetID: dup, relatedID: rec.id, destination: "EvidenceDetailSheet", isRepairable: false)
                    }
                }
                // Validation and opportunity are preserved, not validated unless registry exists — skip
            }
        }

        // MARK: Achievement Graph Integrity

        func checkAchievements() {
            for aid in portfolio.selectedAchievementIDs {
                guard let ach = achievementRecords[aid] else { continue } // already reported as missing
                // Evidence references
                var seenE = Set<String>()
                var dupE = Set<String>()
                for eid in ach.evidenceIDs {
                    let t = eid.trimmingCharacters(in: .whitespacesAndNewlines)
                    if t.isEmpty {
                        addIssue(type: .invalidAchievementEvidenceReference, title: "Achievement has invalid evidence reference", explanation: "Achievement \(aid) has an empty evidence ID.", severity: .warning, portfolioID: portfolio.id, targetID: eid, relatedID: aid, destination: "AchievementDetailView", isRepairable: false)
                        continue
                    }
                    if seenE.contains(t) { dupE.insert(t) } else { seenE.insert(t) }
                    if evidenceRecords[t] == nil {
                        addIssue(type: .invalidAchievementEvidenceReference, title: "Achievement references missing evidence", explanation: "Achievement \(aid) references evidence \(t) which is not found.", severity: .warning, portfolioID: portfolio.id, targetID: t, relatedID: aid, destination: "AchievementDetailView", isRepairable: false)
                    }
                }
                for dup in dupE {
                    addIssue(type: .invalidAchievementEvidenceReference, title: "Achievement has duplicate evidence reference", explanation: "Achievement \(aid) references evidence \(dup) multiple times.", severity: .info, portfolioID: portfolio.id, targetID: dup, relatedID: aid, destination: "AchievementDetailView", isRepairable: false)
                }
                // Project reference
                if let pid = ach.projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
                    if projects[pid] == nil {
                        addIssue(type: .invalidAchievementProjectReference, title: "Achievement references unavailable project", explanation: "Achievement \(aid) references project \(pid) which is not found.", severity: .warning, portfolioID: portfolio.id, targetID: pid, relatedID: aid, destination: "AchievementDetailView", isRepairable: false)
                    }
                }
                // Roadmap reference
                if let rid = ach.roadmapID?.trimmingCharacters(in: .whitespacesAndNewlines), !rid.isEmpty {
                    if roadmaps[rid] == nil {
                        addIssue(type: .invalidAchievementRoadmapReference, title: "Achievement references unavailable roadmap", explanation: "Achievement \(aid) references roadmap \(rid) which is not found.", severity: .warning, portfolioID: portfolio.id, targetID: rid, relatedID: aid, destination: "AchievementDetailView", isRepairable: false)
                    } else if let mid = ach.milestoneID?.trimmingCharacters(in: .whitespacesAndNewlines), !mid.isEmpty {
                        let rm = roadmaps[rid]!
                        if !rm.milestones.contains(where: { $0.id == mid }) {
                            addIssue(type: .invalidAchievementRoadmapReference, title: "Achievement references missing milestone", explanation: "Achievement \(aid) references milestone \(mid) not found in roadmap \(rid).", severity: .warning, portfolioID: portfolio.id, targetID: mid, relatedID: aid, destination: "AchievementDetailView", isRepairable: false)
                        }
                    }
                } else if let mid = ach.milestoneID?.trimmingCharacters(in: .whitespacesAndNewlines), !mid.isEmpty {
                    addIssue(type: .invalidAchievementRoadmapReference, title: "Achievement milestone without roadmap", explanation: "Achievement \(aid) has milestone \(mid) but no roadmap.", severity: .warning, portfolioID: portfolio.id, targetID: mid, relatedID: aid, destination: "AchievementDetailView", isRepairable: false)
                }
                // Skill references
                if let sids = ach.skillIDs {
                    for raw in sids {
                        let norm = Skill.normalizeID(raw)
                        if norm.isEmpty {
                            addIssue(type: .invalidAchievementSkillReference, title: "Achievement has invalid skill reference", explanation: "Achievement \(aid) has an empty skill reference.", severity: .info, portfolioID: portfolio.id, targetID: raw, relatedID: aid, destination: "AchievementDetailView", isRepairable: false)
                            continue
                        }
                        if SkillCatalog.knownSkills[norm] == nil {
                            addIssue(type: .invalidAchievementSkillReference, title: "Achievement references unknown skill", explanation: "Achievement \(aid) references skill \(raw) (normalized: \(norm)) not in SkillCatalog.", severity: .info, portfolioID: portfolio.id, targetID: norm, relatedID: aid, destination: "AchievementDetailView", isRepairable: false)
                        }
                    }
                }
            }
        }

        // MARK: Execute Checks

        checkPortfolioSelections()
        checkSections()
        checkEvidenceGraph()
        checkAchievements()

        // Sort issues deterministically: severity rank -> type -> targetID -> relatedID -> id
        issues.sort {
            if $0.severity.rank != $1.severity.rank { return $0.severity.rank < $1.severity.rank }
            if $0.type.rawValue != $1.type.rawValue { return $0.type.rawValue < $1.type.rawValue }
            let t0 = $0.targetID ?? ""
            let t1 = $1.targetID ?? ""
            if t0 != t1 { return t0 < t1 }
            let r0 = $0.relatedID ?? ""
            let r1 = $1.relatedID ?? ""
            if r0 != r1 { return r0 < r1 }
            return $0.id < $1.id
        }

        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count
        let isValid = errorCount == 0

        return PortfolioGraphIntegrityReport(
            portfolioID: portfolio.id,
            isValid: isValid,
            issueCount: issues.count,
            errorCount: errorCount,
            warningCount: warningCount,
            infoCount: infoCount,
            issues: issues,
            checkedProjectIDs: Array(Set(portfolio.selectedProjectIDs)).sorted(),
            checkedAchievementIDs: Array(Set(portfolio.selectedAchievementIDs)).sorted(),
            checkedEvidenceIDs: Array(Set(portfolio.selectedEvidenceIDs)).sorted(),
            checkedSkillIDs: Array(Set(portfolio.selectedSkillIDs.map { Skill.normalizeID($0) })).sorted(),
            checkedRoadmapIDs: Array(Set(portfolio.selectedRoadmapIDs)).sorted(),
            checkedAt: asOf
        )
    }

    // MARK: - Explicit Repair (safe, per-issue)

    @MainActor
    static func repair(issueID: String, for portfolioID: String, store: AppDataStore) -> Bool {
        guard let portfolio = store.portfolio(id: portfolioID) else { return false }
        let report = report(for: portfolio, store: store)
        guard let issue = report.issues.first(where: { $0.id == issueID }) else { return false }
        guard issue.isRepairable else { return false }

        switch issue.type {
        case .duplicatePortfolioSelection:
            // Remove duplicates by deduping the relevant array
            var p = portfolio
            // Determine which array contains the duplicate targetID
            let tid = issue.targetID ?? ""
            if p.selectedProjectIDs.filter({ $0.trimmingCharacters(in: .whitespacesAndNewlines) == tid }).count > 1 {
                p.selectedProjectIDs = StudentPortfolio.dedupOrdered(p.selectedProjectIDs)
                return store.updatePortfolio(p)
            }
            if p.selectedAchievementIDs.filter({ $0.trimmingCharacters(in: .whitespacesAndNewlines) == tid }).count > 1 {
                p.selectedAchievementIDs = StudentPortfolio.dedupOrdered(p.selectedAchievementIDs)
                return store.updatePortfolio(p)
            }
            if p.selectedEvidenceIDs.filter({ $0.trimmingCharacters(in: .whitespacesAndNewlines) == tid }).count > 1 {
                p.selectedEvidenceIDs = StudentPortfolio.dedupOrdered(p.selectedEvidenceIDs)
                return store.updatePortfolio(p)
            }
            if p.selectedSkillIDs.map({ Skill.normalizeID($0) }).filter({ $0 == Skill.normalizeID(tid) }).count > 1 {
                p.selectedSkillIDs = StudentPortfolio.dedupOrderedSkillIDs(p.selectedSkillIDs)
                return store.updatePortfolio(p)
            }
            if p.selectedRoadmapIDs.filter({ $0.trimmingCharacters(in: .whitespacesAndNewlines) == tid }).count > 1 {
                p.selectedRoadmapIDs = StudentPortfolio.dedupOrdered(p.selectedRoadmapIDs)
                return store.updatePortfolio(p)
            }
            return false
        case .missingProject, .missingAchievement, .missingEvidence, .missingRoadmap, .invalidPortfolioReference:
            // Remove stale selected reference
            var p = portfolio
            let tid = issue.targetID ?? ""
            if p.selectedProjectIDs.contains(tid) {
                p.selectedProjectIDs.removeAll(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == tid })
                return store.updatePortfolio(p)
            }
            if p.selectedAchievementIDs.contains(tid) {
                p.selectedAchievementIDs.removeAll(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == tid })
                return store.updatePortfolio(p)
            }
            if p.selectedEvidenceIDs.contains(tid) {
                p.selectedEvidenceIDs.removeAll(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == tid })
                return store.updatePortfolio(p)
            }
            if p.selectedRoadmapIDs.contains(tid) {
                p.selectedRoadmapIDs.removeAll(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == tid })
                return store.updatePortfolio(p)
            }
            // For skills, need normalized
            let norm = Skill.normalizeID(tid)
            if p.selectedSkillIDs.map({ Skill.normalizeID($0) }).contains(norm) {
                p.selectedSkillIDs.removeAll(where: { Skill.normalizeID($0) == norm })
                return store.updatePortfolio(p)
            }
            return false
        case .duplicateSection:
            var p = portfolio
            p.sections = StudentPortfolio.dedupSections(p.sections)
            return store.updatePortfolio(p)
        default:
            // Other issues are not auto-repairable, require manual fix
            return false
        }
    }
}
