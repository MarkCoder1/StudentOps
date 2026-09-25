import Foundation

// MARK: - iOS Context Builder (deterministic, minimal, career-agnostic)

@MainActor
enum PortfolioWritingContextBuilder {

    static func build(
        for portfolio: StudentPortfolio,
        store: AppDataStore,
        writingType: PortfolioWritingType,
        targetID: String?
    ) -> PortfolioWritingContext {
        let profile = store.profile
        let snapshot = StudentProfileSnapshot.make(from: store)

        let portfolioMeta = PortfolioWritingContext.PortfolioMeta(
            id: portfolio.id,
            title: portfolio.title,
            headline: portfolio.headline,
            about: portfolio.about,
            goals: portfolio.goals
        )

        let student = PortfolioWritingContext.Student(
            displayName: snapshot.displayName,
            grade: snapshot.gradeLabel,
            schoolLevel: snapshot.schoolLevelLabel,
            location: snapshot.location.isEmpty ? nil : snapshot.location
        )

        let education = PortfolioWritingContext.Education(
            grade: snapshot.gradeLabel,
            schoolLevel: snapshot.schoolLevelLabel
        )

        // Resolve target-specific context
        var projects: [PortfolioWritingContext.Project] = []
        var achievements: [PortfolioWritingContext.Achievement] = []
        var evidence: [PortfolioWritingContext.Evidence] = []
        var skills: [PortfolioWritingContext.Skill] = []
        var roadmaps: [PortfolioWritingContext.Roadmap] = []

        switch writingType {
        case .headline:
            // Portfolio-level: student + portfolio only, plus a sample of skills/projects for grounding
            skills = portfolio.selectedSkillIDs.prefix(6).compactMap { sid in
                let norm = Skill.normalizeID(sid)
                guard let s = SkillCatalog.knownSkills[norm] ?? Skill(id: norm, name: sid) as Skill? else { return nil }
                return PortfolioWritingContext.Skill(id: s.id, name: s.name)
            }
            // No projects/evidence needed for headline, keep minimal

        case .about:
            // Portfolio-level: student + portfolio + sample of selected work
            projects = portfolio.selectedProjectIDs.prefix(3).compactMap { pid in
                guard let sp = store.scoredProjects.first(where: { $0.project.id == pid }) else { return nil }
                let p = sp.project
                let evCount = store.evidenceRecords.values.filter { $0.projectID == pid }.count
                let artifact = store.evidenceRecords.values.first(where: { $0.projectID == pid })?.artifact?.url
                return PortfolioWritingContext.Project(
                    id: p.id, title: p.title, description: p.description, category: p.category, goal: p.goal,
                    skills: Array(p.skills.prefix(4)), progress: sp.progress, isCompleted: sp.isCompleted,
                    sourceRoadmapID: p.sourceRoadmapID, evidenceCount: evCount, artifactURL: artifact
                )
            }
            if projects.isEmpty {
                // Fallback to any projects if none selected
                projects = store.scoredProjects.prefix(2).map { sp in
                    let p = sp.project
                    return PortfolioWritingContext.Project(id: p.id, title: p.title, description: p.description, category: p.category, goal: p.goal, skills: Array(p.skills.prefix(4)), progress: sp.progress, isCompleted: sp.isCompleted, sourceRoadmapID: p.sourceRoadmapID, evidenceCount: nil, artifactURL: nil)
                }
            }
            achievements = portfolio.selectedAchievementIDs.prefix(2).compactMap { aid in
                guard let ach = store.achievementRecords[aid] else { return nil }
                return PortfolioWritingContext.Achievement(id: ach.id, title: ach.title, description: ach.description, type: ach.type.displayName, createdAt: ISO8601DateFormatter().string(from: ach.createdAt), evidenceCount: ach.evidenceIDs.count, skillIDs: ach.skillIDs ?? [], roadmapID: ach.roadmapID, projectID: ach.projectID)
            }
            skills = portfolio.selectedSkillIDs.prefix(6).compactMap { sid in
                let norm = Skill.normalizeID(sid)
                let s = SkillCatalog.knownSkills[norm] ?? Skill(id: norm, name: sid)
                return PortfolioWritingContext.Skill(id: s.id, name: s.name)
            }
            roadmaps = portfolio.selectedRoadmapIDs.prefix(2).compactMap { rid in
                guard let rm = RoadmapService.roadmap(for: rid) else { return nil }
                let scored = store.scoredRoadmaps.first(where: { $0.roadmap.id == rid })
                return PortfolioWritingContext.Roadmap(id: rm.id, title: rm.title, goal: rm.goal, progress: scored?.progress, isActive: store.isRoadmapActivated(rid), completedMilestones: scored?.completedMilestones, totalMilestones: rm.milestones.count)
            }

        case .goal:
            // Specific goal
            var targetGoal: String?
            if let tid = targetID {
                if let idx = Int(tid), portfolio.goals.indices.contains(idx) {
                    targetGoal = portfolio.goals[idx]
                } else if portfolio.goals.contains(tid) {
                    targetGoal = tid
                } else {
                    targetGoal = tid
                }
            }
            // For goal, keep portfolio goals as single target goal for minimal context
            if let tg = targetGoal {
                // Override portfolio goals to just target for context
                // We will handle this by creating a new portfolioMeta with single goal
                // But we already created portfolioMeta with all goals, so we will not override; instead we will keep all goals but the prompt will focus on targetID
                _ = tg
            }
            skills = portfolio.selectedSkillIDs.prefix(4).compactMap { sid in
                let norm = Skill.normalizeID(sid)
                let s = SkillCatalog.knownSkills[norm] ?? Skill(id: norm, name: sid)
                return PortfolioWritingContext.Skill(id: s.id, name: s.name)
            }

        case .projectDescription:
            guard let tid = targetID, let sp = store.scoredProjects.first(where: { $0.project.id == tid }) else { break }
            let p = sp.project
            let projEvidence = store.evidenceRecords.values.filter { $0.projectID == tid }.prefix(4)
            projects = [PortfolioWritingContext.Project(
                id: p.id, title: p.title, description: p.description, category: p.category, goal: p.goal,
                skills: Array(p.skills.prefix(4)), progress: sp.progress, isCompleted: sp.isCompleted,
                sourceRoadmapID: p.sourceRoadmapID, evidenceCount: projEvidence.count,
                artifactURL: projEvidence.first?.artifact?.url
            )]
            evidence = projEvidence.map { rec in
                let q = EvidenceQualityEngine.quality(for: rec)
                return PortfolioWritingContext.Evidence(
                    id: rec.id, title: rec.title, description: rec.description, type: rec.type.displayName,
                    roadmapID: rec.roadmapID.isEmpty ? nil : rec.roadmapID, milestoneID: rec.milestoneID.isEmpty ? nil : rec.milestoneID,
                    projectID: rec.projectID, skillIDs: rec.skillIDs ?? [], artifactURL: rec.artifact?.url,
                    createdAt: ISO8601DateFormatter().string(from: rec.createdAt), quality: q.overallLevel.rawValue
                )
            }
            skills = p.skills.prefix(4).map { raw in
                let norm = Skill.normalizeID(raw)
                let s = SkillCatalog.knownSkills[norm] ?? Skill(id: norm, name: raw)
                return PortfolioWritingContext.Skill(id: s.id, name: s.name)
            }
            if let src = p.sourceRoadmapID, let rm = RoadmapService.roadmap(for: src) {
                let scored = store.scoredRoadmaps.first(where: { $0.roadmap.id == src })
                roadmaps = [PortfolioWritingContext.Roadmap(id: rm.id, title: rm.title, goal: rm.goal, progress: scored?.progress, isActive: store.isRoadmapActivated(src), completedMilestones: scored?.completedMilestones, totalMilestones: rm.milestones.count)]
            }
            // Related achievements
            achievements = store.achievementRecords.values.filter { $0.projectID == tid }.prefix(2).map { ach in
                PortfolioWritingContext.Achievement(id: ach.id, title: ach.title, description: ach.description, type: ach.type.displayName, createdAt: ISO8601DateFormatter().string(from: ach.createdAt), evidenceCount: ach.evidenceIDs.count, skillIDs: ach.skillIDs ?? [], roadmapID: ach.roadmapID, projectID: ach.projectID)
            }

        case .achievementDescription:
            guard let tid = targetID, let ach = store.achievementRecords[tid] else { break }
            achievements = [PortfolioWritingContext.Achievement(
                id: ach.id, title: ach.title, description: ach.description, type: ach.type.displayName,
                createdAt: ISO8601DateFormatter().string(from: ach.createdAt), evidenceCount: ach.evidenceIDs.count,
                skillIDs: ach.skillIDs ?? [], roadmapID: ach.roadmapID, projectID: ach.projectID
            )]
            // Linked evidence
            let linkedEvidence = ach.evidenceIDs.compactMap { store.evidenceRecords[$0] }.prefix(4)
            evidence = linkedEvidence.map { rec in
                let q = EvidenceQualityEngine.quality(for: rec)
                return PortfolioWritingContext.Evidence(id: rec.id, title: rec.title, description: rec.description, type: rec.type.displayName, roadmapID: rec.roadmapID.isEmpty ? nil : rec.roadmapID, milestoneID: rec.milestoneID.isEmpty ? nil : rec.milestoneID, projectID: rec.projectID, skillIDs: rec.skillIDs ?? [], artifactURL: rec.artifact?.url, createdAt: ISO8601DateFormatter().string(from: rec.createdAt), quality: q.overallLevel.rawValue)
            }
            if evidence.isEmpty {
                // Fallback to any evidence referencing achievement via project/roadmap
                evidence = store.evidenceRecords.values.filter { rec in
                    if let pid = ach.projectID, rec.projectID == pid { return true }
                    if let rid = ach.roadmapID, rec.roadmapID == rid { return true }
                    return false
                }.prefix(2).map { rec in
                    let q = EvidenceQualityEngine.quality(for: rec)
                    return PortfolioWritingContext.Evidence(id: rec.id, title: rec.title, description: rec.description, type: rec.type.displayName, roadmapID: rec.roadmapID.isEmpty ? nil : rec.roadmapID, milestoneID: rec.milestoneID.isEmpty ? nil : rec.milestoneID, projectID: rec.projectID, skillIDs: rec.skillIDs ?? [], artifactURL: rec.artifact?.url, createdAt: ISO8601DateFormatter().string(from: rec.createdAt), quality: q.overallLevel.rawValue)
                }
            }
            if let pid = ach.projectID, let sp = store.scoredProjects.first(where: { $0.project.id == pid }) {
                let p = sp.project
                projects = [PortfolioWritingContext.Project(id: p.id, title: p.title, description: p.description, category: p.category, goal: p.goal, skills: Array(p.skills.prefix(4)), progress: sp.progress, isCompleted: sp.isCompleted, sourceRoadmapID: p.sourceRoadmapID, evidenceCount: nil, artifactURL: nil)]
            }
            if let rid = ach.roadmapID, let rm = RoadmapService.roadmap(for: rid) {
                let scored = store.scoredRoadmaps.first(where: { $0.roadmap.id == rid })
                roadmaps = [PortfolioWritingContext.Roadmap(id: rm.id, title: rm.title, goal: rm.goal, progress: scored?.progress, isActive: store.isRoadmapActivated(rid), completedMilestones: scored?.completedMilestones, totalMilestones: rm.milestones.count)]
            }
            if let sids = ach.skillIDs {
                skills = sids.prefix(4).compactMap { sid in
                    let norm = Skill.normalizeID(sid)
                    let s = SkillCatalog.knownSkills[norm] ?? Skill(id: norm, name: sid)
                    return PortfolioWritingContext.Skill(id: s.id, name: s.name)
                }
            }

        case .evidenceDescription:
            guard let tid = targetID, let rec = store.evidenceRecords[tid] else { break }
            let q = EvidenceQualityEngine.quality(for: rec)
            evidence = [PortfolioWritingContext.Evidence(
                id: rec.id, title: rec.title, description: rec.description, type: rec.type.displayName,
                roadmapID: rec.roadmapID.isEmpty ? nil : rec.roadmapID, milestoneID: rec.milestoneID.isEmpty ? nil : rec.milestoneID,
                projectID: rec.projectID, skillIDs: rec.skillIDs ?? [], artifactURL: rec.artifact?.url,
                createdAt: ISO8601DateFormatter().string(from: rec.createdAt), quality: q.overallLevel.rawValue
            )]
            if let pid = rec.projectID, let sp = store.scoredProjects.first(where: { $0.project.id == pid }) {
                let p = sp.project
                projects = [PortfolioWritingContext.Project(id: p.id, title: p.title, description: p.description, category: p.category, goal: p.goal, skills: Array(p.skills.prefix(4)), progress: sp.progress, isCompleted: sp.isCompleted, sourceRoadmapID: p.sourceRoadmapID, evidenceCount: nil, artifactURL: nil)]
            }
            if !rec.roadmapID.isEmpty, let rm = RoadmapService.roadmap(for: rec.roadmapID) {
                let scored = store.scoredRoadmaps.first(where: { $0.roadmap.id == rec.roadmapID })
                roadmaps = [PortfolioWritingContext.Roadmap(id: rm.id, title: rm.title, goal: rm.goal, progress: scored?.progress, isActive: store.isRoadmapActivated(rec.roadmapID), completedMilestones: scored?.completedMilestones, totalMilestones: rm.milestones.count)]
            }
            if let sids = rec.skillIDs {
                skills = sids.prefix(4).compactMap { sid in
                    let norm = Skill.normalizeID(sid)
                    let s = SkillCatalog.knownSkills[norm] ?? Skill(id: norm, name: sid)
                    return PortfolioWritingContext.Skill(id: s.id, name: s.name)
                }
            }

        case .roadmapSummary:
            guard let tid = targetID, let rm = RoadmapService.roadmap(for: tid) else { break }
            let scored = store.scoredRoadmaps.first(where: { $0.roadmap.id == tid })
            roadmaps = [PortfolioWritingContext.Roadmap(
                id: rm.id, title: rm.title, goal: rm.goal, progress: scored?.progress,
                isActive: store.isRoadmapActivated(tid), completedMilestones: scored?.completedMilestones, totalMilestones: rm.milestones.count
            )]
            evidence = store.evidenceRecords.values.filter { $0.roadmapID == tid }.prefix(4).map { rec in
                let q = EvidenceQualityEngine.quality(for: rec)
                return PortfolioWritingContext.Evidence(id: rec.id, title: rec.title, description: rec.description, type: rec.type.displayName, roadmapID: rec.roadmapID.isEmpty ? nil : rec.roadmapID, milestoneID: rec.milestoneID.isEmpty ? nil : rec.milestoneID, projectID: rec.projectID, skillIDs: rec.skillIDs ?? [], artifactURL: rec.artifact?.url, createdAt: ISO8601DateFormatter().string(from: rec.createdAt), quality: q.overallLevel.rawValue)
            }
            skills = rm.milestones.compactMap { $0.skillsDeveloped }.flatMap { $0 }.prefix(4).map { raw in
                let norm = Skill.normalizeID(raw)
                let s = SkillCatalog.knownSkills[norm] ?? Skill(id: norm, name: raw)
                return PortfolioWritingContext.Skill(id: s.id, name: s.name)
            }
        }

        return PortfolioWritingContext(
            portfolio: portfolioMeta,
            student: student,
            education: education,
            projects: projects,
            achievements: achievements,
            evidence: evidence,
            skills: skills,
            roadmaps: roadmaps,
            constraints: PortfolioWritingContext.Constraints(writingType: writingType, targetID: targetID)
        )
    }

    static func fingerprint(for context: PortfolioWritingContext) -> String {
        // Deterministic hash of relevant source IDs + key fields
        let payload: [String: Any] = [
            "portfolioID": context.portfolio.id,
            "headline": context.portfolio.headline ?? "",
            "about": context.portfolio.about ?? "",
            "goals": (context.portfolio.goals).sorted(),
            "projects": context.projects.map { $0.id }.sorted(),
            "achievements": context.achievements.map { $0.id }.sorted(),
            "evidence": context.evidence.map { $0.id }.sorted(),
            "skills": context.skills.map { $0.id }.sorted(),
            "roadmaps": context.roadmaps.map { $0.id }.sorted(),
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let str = String(data: data, encoding: .utf8) ?? ""
        // FNV-1a
        var hash: UInt32 = 2166136261
        for byte in str.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return String(format: "%08x", hash)
    }
}
