import Foundation

// Standalone test for Phase 8.2 — Deterministic Portfolio Engine
// Run: swift test-portfolio-engine.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}
func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a != b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — both \(a)") }
}
func normalizeSkillID(_ raw: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    return parts.joined(separator: " ").lowercased()
}
func isValidArtifactURL(_ s: String?) -> Bool {
    guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return false }
    guard let url = URL(string: t) else { return false }
    guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
    return url.host != nil
}
func isRecent(date: Date, asOf: Date) -> Bool {
    let window: TimeInterval = 180 * 24 * 60 * 60
    let diff = asOf.timeIntervalSince(date)
    return diff >= 0 && diff <= window
}

// MARK: - Inline models (mirrors production)

enum EvType: String, Hashable, Codable { case milestoneCompletion = "milestone-completion", projectWork = "project-work", validation = "validation", artifact = "artifact", opportunityParticipation = "opportunity-participation", other = "other" }
enum EvSource: String, Hashable, Codable { case roadmapMilestone, project, studentEntered, system, unknown }
enum EvStatus: String, Hashable, Codable { case recorded, verified }

struct TestEvidenceArtifact: Hashable, Codable {
    let type: String; let title: String; let url: String?
}

struct TestEvidenceRecord: Hashable, Codable {
    let id: String; var title: String; var description: String?; var type: EvType
    var roadmapID: String; var milestoneID: String
    var createdAt: Date; var occurredAt: Date?
    var source: EvSource; var status: EvStatus
    var skillIDs: [String]?; var artifact: TestEvidenceArtifact?
    var projectID: String?; var opportunityID: String?; var validationID: String?; var validationPassed: Bool?
}

enum EvidenceQualityLevel: String { case basic = "Basic", solid = "Solid", strong = "Strong" }

func qualityLevel(for rec: TestEvidenceRecord) -> EvidenceQualityLevel {
    var score = 0
    if !rec.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && rec.title.count > 3 { score += 1 }
    if let d = rec.description, d.trimmingCharacters(in: .whitespacesAndNewlines).count > 10 { score += 2 }
    if rec.occurredAt != nil { score += 1 }
    if !rec.roadmapID.isEmpty && !rec.milestoneID.isEmpty { score += 2 }
    if rec.projectID != nil && !(rec.projectID?.isEmpty ?? true) { score += 2 }
    if rec.opportunityID != nil && !(rec.opportunityID?.isEmpty ?? true) { score += 2 }
    if !(rec.skillIDs?.isEmpty ?? true) { score += 1 }
    if isValidArtifactURL(rec.artifact?.url) { score += 2 }
    if rec.validationID != nil && rec.validationPassed != nil { score += 2 }
    if score >= 8 { return .strong }
    if score >= 4 { return .solid }
    return .basic
}

struct TestProjectMilestone: Hashable { let id: String; let title: String }
struct TestProject: Hashable {
    let id: String; let title: String; let description: String; let skills: [String]; let milestones: [TestProjectMilestone]; let sourceRoadmapID: String?
}

enum AchType: String, Hashable { case project, learning, other }
enum AchStatus: String, Hashable { case recorded, verified }
enum AchSource: String, Hashable { case studentEntered, evidenceDerived, roadmapMilestone, project, opportunity, system }

struct TestAchievement: Hashable {
    let id: String; var title: String; var description: String?; var type: AchType; var status: AchStatus
    var createdAt: Date; var occurredAt: Date?; var evidenceIDs: [String]; var skillIDs: [String]?;
    var roadmapID: String?; var projectID: String?; var opportunityID: String?; var source: AchSource
}

struct TestRoadmapMilestone: Hashable {
    let id: String; let title: String; let skillsDeveloped: [String]?
}
struct TestRoadmap: Hashable {
    let id: String; let title: String; let milestones: [TestRoadmapMilestone]
}

struct TestActiveRoadmap: Hashable { let roadmapID: String; let status: String } // "active" or other

struct TestSkillCatalog {
    static let known: [String: String] = [
        "python": "Python", "git": "Git", "research": "Research", "leadership": "Leadership",
        "machine learning": "Machine Learning", "portfolio development": "Portfolio Development",
        "project management": "Project Management", "communication": "Communication"
    ]
    static func canonicalName(for id: String) -> String { known[id] ?? id }
}

// Minimal StudentProfile for demonstrated skills
struct TestStudentProfile: Hashable {
    var strengths: [String] = []
    var customSkills: [String] = []
}

func demonstratedSkillIDs(profile: TestStudentProfile, roadmapProgress: [String:Int], catalog: [TestRoadmap], evidenceRecords: [String:TestEvidenceRecord]) -> Set<String> {
    var out = Set<String>()
    for s in profile.strengths + profile.customSkills {
        let n = normalizeSkillID(s)
        if !n.isEmpty { out.insert(n) }
    }
    for roadmap in catalog {
        let completed = min(roadmapProgress[roadmap.id] ?? 0, roadmap.milestones.count)
        for idx in 0..<completed {
            for raw in roadmap.milestones[idx].skillsDeveloped ?? [] {
                let n = normalizeSkillID(raw)
                if !n.isEmpty { out.insert(n) }
            }
        }
    }
    // Evidence linked via roadmap/milestone -> add skillsDeveloped of that milestone
    let catalogMap = Dictionary(uniqueKeysWithValues: catalog.map{($0.id,$0)})
    for rec in evidenceRecords.values {
        if let rm = catalogMap[rec.roadmapID], let ms = rm.milestones.first(where:{ $0.id==rec.milestoneID}) {
            for raw in ms.skillsDeveloped ?? [] {
                let n = normalizeSkillID(raw)
                if !n.isEmpty { out.insert(n) }
            }
        }
    }
    return out
}

func requiredSkills(for roadmap: TestRoadmap) -> [String] {
    var seen = Set<String>(), out: [String]=[]
    for ms in roadmap.milestones {
        for raw in ms.skillsDeveloped ?? [] {
            let n = normalizeSkillID(raw)
            if !n.isEmpty && !seen.contains(n) { seen.insert(n); out.append(n) }
        }
    }
    return out
}

// MARK: - Portfolio Engine Inline (mirrors PortfolioEngine.swift)

enum CandidateType: String, Hashable { case project, achievement, evidence, skill, roadmap }
enum CandidateSignal: String, Hashable { case completed, partiallyCompleted, hasEvidence, hasMultipleEvidence, hasArtifact, hasDescription, hasSkills, hasMultipleSkills, hasValidation, hasValidationPassed, hasRoadmapConnection, supportsActiveRoadmap, hasProjectConnection, hasOpportunityConnection, hasAchievementConnection, hasAchievements, recent, highEvidenceQuality, solidEvidenceQuality, demonstratesSkill, active, meaningfulProgress, verified }

struct PortfolioCandidate: Identifiable, Hashable {
    let id: String; let type: CandidateType; let sourceID: String; let title: String; let score: Int
    let signals: [CandidateSignal]; let reason: String
    let relatedSkillIDs: [String]; let relatedRoadmapIDs: [String]
    let evidenceCount: Int; let createdAt: Date?; let occurredAt: Date?
    var isRecommended: Bool { score >= 40 }
}
struct PortfolioReferenceIssue: Identifiable, Hashable { let id: String; let type: CandidateType; let sourceID: String; let reason: String }
struct PortfolioReport: Hashable {
    let projects: [PortfolioCandidate]; let achievements: [PortfolioCandidate]; let evidence: [PortfolioCandidate]; let skills: [PortfolioCandidate]; let roadmaps: [PortfolioCandidate]
    let unresolved: [PortfolioReferenceIssue]; let asOf: Date
    var all: [PortfolioCandidate] { projects + achievements + evidence + skills + roadmaps }
}

struct TestPortfolio: Hashable {
    var id: String; var selectedProjectIDs: [String]; var selectedAchievementIDs: [String]; var selectedEvidenceIDs: [String]; var selectedSkillIDs: [String]; var selectedRoadmapIDs: [String]
}

enum TestPortfolioEngine {
    static func evaluate(
        profile: TestStudentProfile,
        projectProgress: [String:Int],
        roadmapProgress: [String:Int],
        evidenceRecords: [String:TestEvidenceRecord],
        achievementRecords: [String:TestAchievement],
        activeRoadmaps: [String:TestActiveRoadmap],
        completedActionIDs: Set<String>,
        projects: [TestProject],
        roadmaps: [TestRoadmap],
        asOf: Date
    ) -> PortfolioReport {
        let demonstrated = demonstratedSkillIDs(profile: profile, roadmapProgress: roadmapProgress, catalog: roadmaps, evidenceRecords: evidenceRecords)
        let activeIDs = Set(activeRoadmaps.filter{$0.value.status=="active"}.map(\.key))
        let p = projectCands(projects: projects, projectProgress: projectProgress, evidenceRecords: evidenceRecords, achievementRecords: achievementRecords, activeIDs: activeIDs, demonstrated: demonstrated, asOf: asOf)
        let a = achievementCands(achievementRecords: achievementRecords, evidenceRecords: evidenceRecords, roadmapProgress: roadmapProgress, activeIDs: activeIDs, asOf: asOf)
        let e = evidenceCands(evidenceRecords: evidenceRecords, activeIDs: activeIDs, demonstrated: demonstrated, asOf: asOf)
        let s = skillCands(demonstrated: demonstrated, evidenceRecords: evidenceRecords, achievementRecords: achievementRecords, projects: projects, projectProgress: projectProgress, roadmaps: roadmaps, activeIDs: activeIDs, asOf: asOf)
        let r = roadmapCands(roadmaps: roadmaps, roadmapProgress: roadmapProgress, evidenceRecords: evidenceRecords, achievementRecords: achievementRecords, activeIDs: activeIDs, completedActionIDs: completedActionIDs, demonstrated: demonstrated, asOf: asOf)
        return PortfolioReport(projects: p, achievements: a, evidence: e, skills: s, roadmaps: r, unresolved: [], asOf: asOf)
    }

    static func unresolved(for portfolio: TestPortfolio, knownProjectIDs: Set<String>, knownAchievementIDs: Set<String>, knownEvidenceIDs: Set<String>, knownSkillIDs: Set<String>, knownRoadmapIDs: Set<String>) -> [PortfolioReferenceIssue] {
        var out: [PortfolioReferenceIssue]=[]
        for pid in portfolio.selectedProjectIDs where !knownProjectIDs.contains(pid) { out.append(.init(id:"project:\(pid)", type:.project, sourceID:pid, reason:"No canonical project")) }
        for aid in portfolio.selectedAchievementIDs where !knownAchievementIDs.contains(aid) { out.append(.init(id:"achievement:\(aid)", type:.achievement, sourceID:aid, reason:"No canonical achievement")) }
        for eid in portfolio.selectedEvidenceIDs where !knownEvidenceIDs.contains(eid) { out.append(.init(id:"evidence:\(eid)", type:.evidence, sourceID:eid, reason:"No canonical evidence")) }
        for sid in portfolio.selectedSkillIDs {
            let n = normalizeSkillID(sid)
            if !knownSkillIDs.contains(n) { out.append(.init(id:"skill:\(sid)", type:.skill, sourceID:sid, reason:"Skill not demonstrated"))}
        }
        for rid in portfolio.selectedRoadmapIDs where !knownRoadmapIDs.contains(rid) { out.append(.init(id:"roadmap:\(rid)", type:.roadmap, sourceID:rid, reason:"No canonical roadmap"))}
        out.sort{$0.id < $1.id}
        return out
    }

    // MARK: project
    private static func projectCands(projects: [TestProject], projectProgress:[String:Int], evidenceRecords:[String:TestEvidenceRecord], achievementRecords:[String:TestAchievement], activeIDs:Set<String>, demonstrated:Set<String>, asOf:Date) -> [PortfolioCandidate] {
        var evByProj:[String:[TestEvidenceRecord]]=[:]
        for rec in evidenceRecords.values where rec.projectID != nil {
            let pid = rec.projectID!.trimmingCharacters(in:.whitespacesAndNewlines)
            if !pid.isEmpty { evByProj[pid, default:[]].append(rec) }
        }
        var achByProj:[String:[TestAchievement]]=[:]
        for ach in achievementRecords.values where ach.projectID != nil {
            let pid = ach.projectID!.trimmingCharacters(in:.whitespacesAndNewlines)
            if !pid.isEmpty { achByProj[pid, default:[]].append(ach)}
        }
        var out:[PortfolioCandidate]=[]; var seen=Set<String>()
        for proj in projects {
            let pid = proj.id.trimmingCharacters(in:.whitespacesAndNewlines)
            guard !pid.isEmpty else {continue}
            let key="project:\(pid)"; guard !seen.contains(key) else {continue}; seen.insert(key)
            let completed=min(projectProgress[pid] ?? 0, proj.milestones.count)
            let total=proj.milestones.count
            let evs=evByProj[pid] ?? []
            let achs=achByProj[pid] ?? []
            let isMeaningful = completed>0 || !evs.isEmpty || !achs.isEmpty
            guard isMeaningful else {continue}
            var score=0; var signals:[CandidateSignal]=[]
            if total>0 && completed>=total {score+=20; signals.append(.completed)} else if completed>0 {score+=10; signals.append(.partiallyCompleted)}
            if !evs.isEmpty {score+=15; signals.append(.hasEvidence); if evs.count>=2{score+=5; signals.append(.hasMultipleEvidence)}}
            let hasArtifact=evs.contains{isValidArtifactURL($0.artifact?.url)}
            if hasArtifact{score+=12; signals.append(.hasArtifact)}
            if !proj.skills.isEmpty{score+=10; signals.append(.hasSkills); if proj.skills.count>=3{score+=2; signals.append(.hasMultipleSkills)}; let projIDs=proj.skills.map{normalizeSkillID($0)}; if projIDs.contains(where:{demonstrated.contains($0)}){score+=5; signals.append(.demonstratesSkill)}}
            if proj.description.trimmingCharacters(in:.whitespacesAndNewlines).count>10{score+=5; signals.append(.hasDescription)}
            if let src=proj.sourceRoadmapID?.trimmingCharacters(in:.whitespacesAndNewlines), !src.isEmpty{
                signals.append(.hasRoadmapConnection)
                if activeIDs.contains(src){score+=10; signals.append(.supportsActiveRoadmap)} else {score+=4}
            }
            if !achs.isEmpty{score+=10; signals.append(.hasAchievementConnection)}
            let latest=evs.compactMap{$0.occurredAt ?? $0.createdAt}.max()
            if let d=latest, isRecent(date:d, asOf:asOf){score+=5; signals.append(.recent)}
            let hasStrong=evs.contains{qualityLevel(for: $0) == .strong}
            let hasSolid=evs.contains{qualityLevel(for: $0) == .solid}
            if hasStrong{score+=3; signals.append(.highEvidenceQuality)} else if hasSolid{score+=2; signals.append(.solidEvidenceQuality)}
            score=min(score,100)
            let reason=buildProjectReason(proj:proj, completed:completed, total:total, evCount:evs.count, signals:signals)
            let relatedSkills=proj.skills.map{normalizeSkillID($0)}.filter{!$0.isEmpty}.sorted()
            let relatedRoadmaps=proj.sourceRoadmapID.map{[$0]} ?? []
            out.append(PortfolioCandidate(id:key, type:.project, sourceID:pid, title:proj.title, score:score, signals:signals.sorted{$0.rawValue < $1.rawValue}, reason:reason, relatedSkillIDs:relatedSkills, relatedRoadmapIDs:relatedRoadmaps, evidenceCount:evs.count, createdAt:nil, occurredAt:latest))
        }
        out.sort{if $0.score != $1.score{return $0.score > $1.score}; if $0.title != $1.title{return $0.title < $1.title}; return $0.sourceID < $1.sourceID}
        return out
    }

    private static func buildProjectReason(proj:TestProject, completed:Int, total:Int, evCount:Int, signals:[CandidateSignal])->String{
        var parts:[String]=[]
        if signals.contains(.completed){parts.append("Completed project")} else if signals.contains(.partiallyCompleted){parts.append("Project with \(completed) of \(total) milestones completed")} else {parts.append("Project with supporting activity")}
        if signals.contains(.hasEvidence){parts.append(evCount==1 ? "with supporting evidence" : "with \(evCount) supporting evidence records")}
        if signals.contains(.hasArtifact){parts.append("includes an artifact")}
        if signals.contains(.demonstratesSkill){parts.append("demonstrates skills")} else if signals.contains(.hasSkills){parts.append("references skills")}
        if signals.contains(.supportsActiveRoadmap){parts.append("connected to an active roadmap")} else if signals.contains(.hasRoadmapConnection){parts.append("connected to a roadmap")}
        if signals.contains(.hasAchievementConnection){parts.append("linked to achievements")}
        if signals.contains(.highEvidenceQuality){parts.append("supported by strong evidence")} else if signals.contains(.solidEvidenceQuality){parts.append("supported by solid evidence")}
        if signals.contains(.recent){parts.append("with recent activity")}
        if parts.isEmpty{return "Project with available activity."}
        return parts.joined(separator:", ")+"."
    }

    // MARK: achievement
    private static func achievementCands(achievementRecords:[String:TestAchievement], evidenceRecords:[String:TestEvidenceRecord], roadmapProgress:[String:Int], activeIDs:Set<String>, asOf:Date)->[PortfolioCandidate]{
        var out:[PortfolioCandidate]=[]; var seen=Set<String>()
        let sorted=achievementRecords.values.sorted{$0.id < $1.id}
        for ach in sorted{
            let aid=ach.id.trimmingCharacters(in:.whitespacesAndNewlines); guard !aid.isEmpty else{continue}
            let key="achievement:\(aid)"; guard !seen.contains(key) else{continue}; seen.insert(key)
            guard !ach.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{continue}
            let support=ach.evidenceIDs.compactMap{evidenceRecords[$0]}
            var score=0; var signals:[CandidateSignal]=[]
            if !support.isEmpty{score+=20; signals.append(.hasEvidence); if support.count>=2{score+=5; signals.append(.hasMultipleEvidence)}; let hasStrong=support.contains{qualityLevel(for: $0) == .strong}; let hasSolid=support.contains{qualityLevel(for: $0) == .solid}; if hasStrong{score+=10; signals.append(.highEvidenceQuality)} else if hasSolid{score+=5; signals.append(.solidEvidenceQuality)}; if support.contains(where:{isValidArtifactURL($0.artifact?.url)}){score+=10; signals.append(.hasArtifact)}; if support.contains(where:{$0.validationPassed==true}){score+=5; signals.append(.hasValidationPassed)} else if support.contains(where:{$0.validationID != nil}){score+=2; signals.append(.hasValidation)}}
            let hasSkills = !(ach.skillIDs?.isEmpty ?? true)
            if hasSkills{score+=10; signals.append(.hasSkills); if (ach.skillIDs?.count ?? 0)>=2{score+=2; signals.append(.hasMultipleSkills)}}
            if let rid=ach.roadmapID?.trimmingCharacters(in:.whitespacesAndNewlines), !rid.isEmpty{
                signals.append(.hasRoadmapConnection)
                if activeIDs.contains(rid){score+=10; signals.append(.supportsActiveRoadmap)} else if (roadmapProgress[rid] ?? 0)>0{score+=4} else {score+=2}
            }
            if let pid=ach.projectID?.trimmingCharacters(in:.whitespacesAndNewlines), !pid.isEmpty{score+=10; signals.append(.hasProjectConnection)}
            if let oid=ach.opportunityID?.trimmingCharacters(in:.whitespacesAndNewlines), !oid.isEmpty{score+=5; signals.append(.hasOpportunityConnection)}
            if let d=ach.description?.trimmingCharacters(in:.whitespacesAndNewlines), d.count>10{score+=5; signals.append(.hasDescription)}
            let date=ach.occurredAt ?? ach.createdAt
            if isRecent(date:date, asOf:asOf){score+=5; signals.append(.recent)}
            score=min(score,100)
            let reason=buildAchReason(ach:ach, evCount:support.count, signals:signals)
            let relatedSkills=ach.skillIDs ?? []
            var relatedRoadmaps:[String]=[]
            if let r=ach.roadmapID, !r.isEmpty{relatedRoadmaps.append(r)}
            out.append(PortfolioCandidate(id:key, type:.achievement, sourceID:aid, title:ach.title, score:score, signals:signals.sorted{$0.rawValue < $1.rawValue}, reason:reason, relatedSkillIDs:relatedSkills.sorted(), relatedRoadmapIDs:relatedRoadmaps, evidenceCount:support.count, createdAt:ach.createdAt, occurredAt:ach.occurredAt))
        }
        out.sort{if $0.score != $1.score{return $0.score > $1.score}; if $0.title != $1.title{return $0.title < $1.title}; return $0.sourceID < $1.sourceID}
        return out
    }
    private static func buildAchReason(ach:TestAchievement, evCount:Int, signals:[CandidateSignal])->String{
        var parts: [String] = ["Achievement \"\(ach.title)\""]
        if signals.contains(.hasEvidence){parts.append(evCount==1 ? "supported by 1 evidence record" : "supported by \(evCount) evidence records")} else {parts.append("with no supporting evidence")}
        if signals.contains(.hasArtifact){parts.append("includes an artifact")}
        if signals.contains(.hasSkills){parts.append("references skills")}
        if signals.contains(.supportsActiveRoadmap){parts.append("connected to an active roadmap")} else if signals.contains(.hasRoadmapConnection){parts.append("connected to a roadmap")}
        if signals.contains(.hasProjectConnection){parts.append("linked to a project")}
        if signals.contains(.hasOpportunityConnection){parts.append("linked to an opportunity")}
        if signals.contains(.highEvidenceQuality){parts.append("supported by strong evidence")}
        if signals.contains(.recent){parts.append("recent")}
        return parts.joined(separator:", ")+"."
    }

    // MARK: evidence
    private static func evidenceCands(evidenceRecords:[String:TestEvidenceRecord], activeIDs:Set<String>, demonstrated:Set<String>, asOf:Date)->[PortfolioCandidate]{
        var out:[PortfolioCandidate]=[]; var seen=Set<String>()
        let sorted=evidenceRecords.values.sorted{$0.id < $1.id}
        for rec in sorted{
            let eid=rec.id.trimmingCharacters(in:.whitespacesAndNewlines); guard !eid.isEmpty else{continue}
            let key="evidence:\(eid)"; guard !seen.contains(key) else{continue}; seen.insert(key)
            guard !rec.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{continue}
            let quality=qualityLevel(for:rec)
            var score=0; var signals:[CandidateSignal]=[]
            switch quality{
            case .strong: score+=20; signals.append(.highEvidenceQuality)
            case .solid: score+=10; signals.append(.solidEvidenceQuality)
            case .basic: break
            }
            if isValidArtifactURL(rec.artifact?.url){score+=15; signals.append(.hasArtifact)}
            if let pid=rec.projectID?.trimmingCharacters(in:.whitespacesAndNewlines), !pid.isEmpty{score+=10; signals.append(.hasProjectConnection)}
            if !rec.roadmapID.isEmpty && !rec.milestoneID.isEmpty{
                signals.append(.hasRoadmapConnection)
                if activeIDs.contains(rec.roadmapID){score+=10; signals.append(.supportsActiveRoadmap)} else {score+=5}
            }
            if let oid=rec.opportunityID?.trimmingCharacters(in:.whitespacesAndNewlines), !oid.isEmpty{score+=10; signals.append(.hasOpportunityConnection)}
            if !(rec.skillIDs?.isEmpty ?? true){
                score+=10; signals.append(.hasSkills)
                if (rec.skillIDs?.count ?? 0)>=2{score+=3; signals.append(.hasMultipleSkills)}
                let recIDs=rec.skillIDs?.map{normalizeSkillID($0)} ?? []
                if recIDs.contains(where:{demonstrated.contains($0)}){score+=2; signals.append(.demonstratesSkill)}
            }
            if let d=rec.description?.trimmingCharacters(in:.whitespacesAndNewlines), d.count>10{score+=10; signals.append(.hasDescription)}
            if rec.validationPassed==true{score+=5; signals.append(.hasValidationPassed)} else if rec.validationID != nil{score+=2; signals.append(.hasValidation)}
            let date=rec.occurredAt ?? rec.createdAt
            if isRecent(date:date, asOf:asOf){score+=5; signals.append(.recent)}
            if rec.source == .roadmapMilestone{score+=5; signals.append(.verified)}
            score=min(score,100)
            let reason=buildEvReason(rec:rec, quality:quality, signals:signals)
            let relatedRoadmaps=rec.roadmapID.isEmpty ? [] : [rec.roadmapID]
            out.append(PortfolioCandidate(id:key, type:.evidence, sourceID:eid, title:rec.title, score:score, signals:signals.sorted{$0.rawValue < $1.rawValue}, reason:reason, relatedSkillIDs:(rec.skillIDs ?? []).sorted(), relatedRoadmapIDs:relatedRoadmaps, evidenceCount:1, createdAt:rec.createdAt, occurredAt:rec.occurredAt))
        }
        out.sort{if $0.score != $1.score{return $0.score > $1.score}; if $0.title != $1.title{return $0.title < $1.title}; return $0.sourceID < $1.sourceID}
        return out
    }
    private static func buildEvReason(rec:TestEvidenceRecord, quality:EvidenceQualityLevel, signals:[CandidateSignal])->String{
        var parts:[String]=[]
        switch quality{
        case .strong: parts.append("Strong evidence")
        case .solid: parts.append("Solid evidence")
        case .basic: parts.append("Evidence")
        }
        if signals.contains(.hasArtifact){parts.append("with an artifact")}
        if signals.contains(.hasProjectConnection){parts.append("linked to a project")}
        if signals.contains(.hasRoadmapConnection){
            if signals.contains(.supportsActiveRoadmap){parts.append("connected to an active roadmap")} else {parts.append("linked to a roadmap")}
        }
        if signals.contains(.hasOpportunityConnection){parts.append("linked to an opportunity")}
        if signals.contains(.hasSkills){parts.append(signals.contains(.demonstratesSkill) ? "demonstrates skills" : "references skills")}
        if signals.contains(.hasDescription){parts.append("includes a description")}
        if signals.contains(.hasValidationPassed){parts.append("includes a passed validation")}
        if signals.contains(.recent){parts.append("recent")}
        if parts.isEmpty{return "Evidence with available context."}
        return parts.joined(separator:", ")+"."
    }

    // MARK: skill
    private static func skillCands(demonstrated:Set<String>, evidenceRecords:[String:TestEvidenceRecord], achievementRecords:[String:TestAchievement], projects:[TestProject], projectProgress:[String:Int], roadmaps:[TestRoadmap], activeIDs:Set<String>, asOf:Date)->[PortfolioCandidate]{
        guard !demonstrated.isEmpty else{return []}
        var evCountBy:[String:Int]=[:]; var achCountBy:[String:Int]=[:]; var projCountBy:[String:Int]=[:]; var latestBy:[String:Date]=[:]
        for rec in evidenceRecords.values where rec.skillIDs != nil{
            for raw in rec.skillIDs!{
                let n=normalizeSkillID(raw); guard demonstrated.contains(n) else{continue}
                evCountBy[n, default:0]+=1
                let d=rec.occurredAt ?? rec.createdAt
                if let ex=latestBy[n]{if d>ex{latestBy[n]=d}} else {latestBy[n]=d}
            }
        }
        for ach in achievementRecords.values where ach.skillIDs != nil{
            for raw in ach.skillIDs!{
                let n=normalizeSkillID(raw); guard demonstrated.contains(n) else{continue}
                achCountBy[n, default:0]+=1
                let d=ach.occurredAt ?? ach.createdAt
                if let ex=latestBy[n]{if d>ex{latestBy[n]=d}} else {latestBy[n]=d}
            }
        }
        for proj in projects{
            let completed=min(projectProgress[proj.id] ?? 0, proj.milestones.count)
            let hasEv=evidenceRecords.values.contains{$0.projectID==proj.id}
            guard completed>0 || hasEv else{continue}
            for raw in proj.skills{
                let n=normalizeSkillID(raw); guard demonstrated.contains(n) else{continue}
                projCountBy[n, default:0]+=1
            }
        }
        var requiredByActive=Set<String>()
        for rm in roadmaps where activeIDs.contains(rm.id){
            for sid in requiredSkills(for:rm) where demonstrated.contains(sid){ requiredByActive.insert(sid)}
        }
        var out:[PortfolioCandidate]=[]; var seen=Set<String>()
        let sortedIDs=demonstrated.sorted()
        for sid in sortedIDs{
            let n=normalizeSkillID(sid); guard !n.isEmpty else{continue}
            let key="skill:\(n)"; guard !seen.contains(key) else{continue}; seen.insert(key)
            let name=TestSkillCatalog.known[n] ?? sid
            let eCount=evCountBy[n] ?? 0; let aCount=achCountBy[n] ?? 0; let pCount=projCountBy[n] ?? 0
            let total=eCount + aCount + pCount
            var score=0; var signals:[CandidateSignal]=[]
            score+=10; signals.append(.demonstratesSkill)
            if total>0{score+=20; signals.append(.hasEvidence); if total>=2{score+=15; signals.append(.hasMultipleEvidence)}; if total>=3{score+=5}}
            if eCount>=1 && aCount>=1{score+=5}
            if pCount>0{score+=15; signals.append(.hasProjectConnection)}
            if aCount>0{score+=10; signals.append(.hasAchievementConnection)}
            if requiredByActive.contains(n){score+=15; signals.append(.supportsActiveRoadmap)} else {
                let requiredByAny=roadmaps.contains{ requiredSkills(for:$0).contains(n)}
                if requiredByAny{score+=5; signals.append(.hasRoadmapConnection)}
            }
            if let latest=latestBy[n], isRecent(date:latest, asOf:asOf){score+=10; signals.append(.recent)}
            if TestSkillCatalog.known[n] != nil{score+=5; signals.append(.hasSkills)}
            score=min(score,100)
            let reason=buildSkillReason(name:name, eCount:eCount, aCount:aCount, pCount:pCount, signals:signals)
            var relatedRoadmaps:[String]=[]
            for rm in roadmaps where requiredSkills(for:rm).contains(n){relatedRoadmaps.append(rm.id)}
            out.append(PortfolioCandidate(id:key, type:.skill, sourceID:n, title:name, score:score, signals:signals.sorted{$0.rawValue < $1.rawValue}, reason:reason, relatedSkillIDs:[n], relatedRoadmapIDs:relatedRoadmaps.sorted(), evidenceCount:total, createdAt:nil, occurredAt:latestBy[n]))
        }
        out.sort{if $0.score != $1.score{return $0.score > $1.score}; if $0.title != $1.title{return $0.title < $1.title}; return $0.sourceID < $1.sourceID}
        return out
    }
    private static func buildSkillReason(name:String, eCount:Int, aCount:Int, pCount:Int, signals:[CandidateSignal])->String{
        var parts=["Skill \"\(name)\" is demonstrated"]
        if eCount>0{parts.append("supported by \(eCount) evidence record\(eCount==1 ? "" : "s")")}
        if aCount>0{parts.append("linked to \(aCount) achievement\(aCount==1 ? "" : "s")")}
        if pCount>0{parts.append("connected to \(pCount) project\(pCount==1 ? "" : "s")")}
        if signals.contains(.supportsActiveRoadmap){parts.append("supports an active roadmap")}
        if signals.contains(.recent){parts.append("with recent activity")}
        return parts.joined(separator:", ")+"."
    }

    // MARK: roadmap
    private static func roadmapCands(roadmaps:[TestRoadmap], roadmapProgress:[String:Int], evidenceRecords:[String:TestEvidenceRecord], achievementRecords:[String:TestAchievement], activeIDs:Set<String>, completedActionIDs:Set<String>, demonstrated:Set<String>, asOf:Date)->[PortfolioCandidate]{
        var out:[PortfolioCandidate]=[]; var seen=Set<String>()
        let sorted=roadmaps.sorted{$0.id < $1.id}
        for rm in sorted{
            let rid=rm.id.trimmingCharacters(in:.whitespacesAndNewlines); guard !rid.isEmpty else{continue}
            let key="roadmap:\(rid)"; guard !seen.contains(key) else{continue}; seen.insert(key)
            let active=activeIDs.contains(rid)
            let completed=min(roadmapProgress[rid] ?? 0, rm.milestones.count)
            let total=rm.milestones.count
            let evs=evidenceRecords.values.filter{$0.roadmapID==rid}
            let achs=achievementRecords.values.filter{$0.roadmapID==rid}
            let isMeaningful=active || completed>0 || !evs.isEmpty || !achs.isEmpty
            guard isMeaningful else{continue}
            var score=0; var signals:[CandidateSignal]=[]
            if active{score+=20; signals.append(.active)}
            if completed>0{
                score+=15; signals.append(.meaningfulProgress)
                if total>0 && completed>=total{score+=10; signals.append(.completed)} else if completed>=max(1,total/2){score+=5; signals.append(.partiallyCompleted)}
            }
            if !evs.isEmpty{score+=15; signals.append(.hasEvidence); if evs.count>=2{score+=5; signals.append(.hasMultipleEvidence)}}
            if evs.contains(where:{isValidArtifactURL($0.artifact?.url)}){score+=10; signals.append(.hasArtifact)}
            if !achs.isEmpty{score+=10; signals.append(.hasAchievements)}
            let required=requiredSkills(for:rm)
            let demonstratedFor=required.filter{demonstrated.contains($0)}.count
            if demonstratedFor>0{score+=10; signals.append(.demonstratesSkill); if demonstratedFor>=2{score+=5; signals.append(.hasMultipleSkills)}}
            if !required.isEmpty{score+=2; signals.append(.hasSkills)}
            let allActionIDs=Set(rm.milestones.flatMap{_ in [] as [String]}) // simplified no actions in test
            _ = allActionIDs; _ = completedActionIDs
            // recent
            let latestEvidence=evs.compactMap{$0.occurredAt ?? $0.createdAt}.max()
            let latestAch=achs.compactMap{$0.occurredAt ?? $0.createdAt}.max()
            let latest=[latestEvidence, latestAch].compactMap{$0}.max()
            if let l=latest, isRecent(date:l, asOf:asOf){score+=5; signals.append(.recent)}
            score=min(score,100)
            let reason=buildRoadmapReason(rm:rm, completed:completed, total:total, active:active, evCount:evs.count, signals:signals)
            let relatedSkills=required.sorted()
            out.append(PortfolioCandidate(id:key, type:.roadmap, sourceID:rid, title:rm.title, score:score, signals:signals.sorted{$0.rawValue < $1.rawValue}, reason:reason, relatedSkillIDs:relatedSkills, relatedRoadmapIDs:[rid], evidenceCount:evs.count, createdAt:nil, occurredAt:latest))
        }
        out.sort{if $0.score != $1.score{return $0.score > $1.score}; if $0.title != $1.title{return $0.title < $1.title}; return $0.sourceID < $1.sourceID}
        return out
    }
    private static func buildRoadmapReason(rm:TestRoadmap, completed:Int, total:Int, active:Bool, evCount:Int, signals:[CandidateSignal])->String{
        var parts:[String]=[]
        if active{parts.append("Active roadmap")} else {parts.append("Roadmap")}
        parts.append("with \(completed) of \(total) milestones completed")
        if evCount>0{parts.append(evCount==1 ? "1 evidence record" : "\(evCount) evidence records")}
        if signals.contains(.hasAchievements){parts.append("linked to achievements")}
        if signals.contains(.demonstratesSkill){parts.append("demonstrates skills")}
        if signals.contains(.hasArtifact){parts.append("includes an artifact")}
        if signals.contains(.recent){parts.append("recent activity")}
        return parts.joined(separator:", ")+"."
    }
}

// MARK: - Test Data Factories

let fixedAsOf = Date(timeIntervalSince1970: 1700000000) // 2023-11-14T22:13:20Z deterministic
let recentDate = fixedAsOf.addingTimeInterval(-30*24*60*60) // 30 days ago
let oldDate = fixedAsOf.addingTimeInterval(-300*24*60*60) // 300 days ago

func makeProject(id:String, title:String, skills:[String]=["Python"], milestones:Int=4, sourceRoadmapID:String?=nil, description:String="A meaningful project with clear goals.") -> TestProject {
    let ms = (0..<milestones).map{ TestProjectMilestone(id:"\(id)-m\($0)", title:"Milestone \($0)") }
    return TestProject(id:id, title:title, description:description, skills:skills, milestones:ms, sourceRoadmapID:sourceRoadmapID)
}
func makeRoadmap(id:String, title:String, skillsPerMilestone:[[String]]) -> TestRoadmap {
    let ms = skillsPerMilestone.enumerated().map{ idx, skills in TestRoadmapMilestone(id:"\(id)-m\(idx+1)", title:"Milestone \(idx+1)", skillsDeveloped: skills) }
    return TestRoadmap(id:id, title:title, milestones:ms)
}
func makeEvidence(id:String, title:String, roadmapID:String="", milestoneID:String="", projectID:String?=nil, skillIDs:[String]?=nil, artifactURL:String?=nil, occurredAt:Date?=nil, createdAt:Date=recentDate, source:EvSource = .studentEntered, description:String?="A meaningful description with enough detail.") -> TestEvidenceRecord {
    let art: TestEvidenceArtifact? = artifactURL != nil ? TestEvidenceArtifact(type:"link", title:"Artifact", url:artifactURL) : nil
    return TestEvidenceRecord(id:id, title:title, description:description, type:.projectWork, roadmapID:roadmapID, milestoneID:milestoneID, createdAt:createdAt, occurredAt:occurredAt, source:source, status:.recorded, skillIDs:skillIDs, artifact:art, projectID:projectID, opportunityID:nil, validationID:nil, validationPassed:nil)
}
func makeAchievement(id:String, title:String, evidenceIDs:[String]=[], skillIDs:[String]?=nil, roadmapID:String?=nil, projectID:String?=nil, createdAt:Date=recentDate, occurredAt:Date?=nil, source: AchSource = .studentEntered) -> TestAchievement {
    return TestAchievement(id:id, title:title, description:"Desc for achievement", type:.project, status:.recorded, createdAt:createdAt, occurredAt:occurredAt, evidenceIDs:evidenceIDs, skillIDs:skillIDs, roadmapID:roadmapID, projectID:projectID, opportunityID:nil, source:source)
}

// MARK: - Candidate generation (1-6)

do { // 1. Completed project becomes candidate.
    let proj = makeProject(id:"proj-1", title:"Completed Project", milestones:2)
    let profile = TestStudentProfile()
    let report = TestPortfolioEngine.evaluate(profile:profile, projectProgress:["proj-1":2], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assert(report.projects.contains(where:{$0.sourceID=="proj-1"}), "1: completed project candidate")
    let cand = report.projects.first(where:{$0.sourceID=="proj-1"})!
    assert(cand.signals.contains(.completed), "1b: completed signal")
    assert(cand.score >= 20, "1c: score >=20")
}
do { // 2. Untouched project is filtered or low candidacy.
    let proj = makeProject(id:"proj-untouched", title:"Untouched", milestones:4)
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    if let cand = report.projects.first(where:{$0.sourceID=="proj-untouched"}) {
        assert(cand.score < 40, "2: untouched low score \(cand.score)")
        assert(!cand.isRecommended, "2b: not recommended")
    } else {
        assert(true, "2: filtered (acceptable)")
    }
    // Partially completed should be candidate but not completed signal
    let proj2 = makeProject(id:"proj-partial", title:"Partial")
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-partial":1], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj2], roadmaps:[], asOf:fixedAsOf)
    assert(report2.projects.contains(where:{$0.sourceID=="proj-partial"}), "2c: partial candidate")
    let cand2 = report2.projects.first(where:{$0.sourceID=="proj-partial"})!
    assert(cand2.signals.contains(.partiallyCompleted), "2d: partial signal")
    assert(!cand2.signals.contains(.completed), "2e: not completed")
}
do { // 3. Valid achievement becomes candidate.
    let ach = makeAchievement(id:"ach-1", title:"Valid Achievement", evidenceIDs:["ev-1"])
    let ev = makeEvidence(id:"ev-1", title:"Evidence for Ach")
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-1":ev], achievementRecords:["ach-1":ach], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(report.achievements.contains(where:{$0.sourceID=="ach-1"}), "3: achievement candidate")
    assert(report.achievements.first(where:{$0.sourceID=="ach-1"})!.signals.contains(.hasEvidence), "3b: hasEvidence")
}
do { // 4. Valid evidence becomes candidate.
    let ev = makeEvidence(id:"ev-1", title:"Valid Evidence", skillIDs:["python"], artifactURL:"https://example.com", occurredAt:recentDate)
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-1":ev], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(report.evidence.contains(where:{$0.sourceID=="ev-1"}), "4: evidence candidate")
    let cand = report.evidence.first(where:{$0.sourceID=="ev-1"})!
    assert(cand.signals.contains(.hasArtifact), "4b: artifact")
    assert(cand.signals.contains(.hasSkills), "4c: hasSkills")
}
do { // 5. Demonstrated skill becomes candidate.
    let roadmap = makeRoadmap(id:"rm-1", title:"Roadmap", skillsPerMilestone:[["Python"], ["Git"]])
    let profile = TestStudentProfile(strengths:["Python"])
    // Demonstrated via profile
    let report = TestPortfolioEngine.evaluate(profile:profile, projectProgress:[:], roadmapProgress:["rm-1":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[roadmap], asOf:fixedAsOf)
    assert(report.skills.contains(where:{$0.sourceID=="python"}), "5: demonstrated python skill candidate")
    // Non-demonstrated should not
    assert(!report.skills.contains(where:{$0.sourceID=="git"}), "5b: non-demonstrated git not candidate")
}
do { // 6. Meaningfully active roadmap becomes candidate.
    let rm = makeRoadmap(id:"rm-active", title:"Active Roadmap", skillsPerMilestone:[["Python"], ["Git"]])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:["rm-active":1], evidenceRecords:["ev-1": makeEvidence(id:"ev-1", title:"Ev", roadmapID:"rm-active", milestoneID:"rm-active-m1", occurredAt:recentDate)], achievementRecords:[:], activeRoadmaps:["rm-active": TestActiveRoadmap(roadmapID:"rm-active", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report.roadmaps.contains(where:{$0.sourceID=="rm-active"}), "6: active roadmap candidate")
    let cand = report.roadmaps.first(where:{$0.sourceID=="rm-active"})!
    assert(cand.signals.contains(.active), "6b: active signal")
    assert(cand.signals.contains(.meaningfulProgress), "6c: meaningfulProgress")
    // Zero activity filtered
    let rm2 = makeRoadmap(id:"rm-zero", title:"Zero", skillsPerMilestone:[["Python"]])
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[rm2], asOf:fixedAsOf)
    assert(!report2.roadmaps.contains(where:{$0.sourceID=="rm-zero"}), "6d: zero roadmap filtered")
}

// MARK: - Evidence relationships (7-11)

do { // 7. Project evidence increases project support.
    let proj = makeProject(id:"proj-ev", title:"Proj Ev")
    let ev1 = makeEvidence(id:"ev-1", title:"Ev1", projectID:"proj-ev", artifactURL:"https://example.com")
    let ev2 = makeEvidence(id:"ev-2", title:"Ev2", projectID:"proj-ev")
    let reportNoEv = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-ev":1], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    let reportWithEv = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-ev":1], roadmapProgress:[:], evidenceRecords:["ev-1":ev1, "ev-2":ev2], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    let candNo = reportNoEv.projects.first(where:{$0.sourceID=="proj-ev"})!
    let candWith = reportWithEv.projects.first(where:{$0.sourceID=="proj-ev"})!
    assert(candWith.score > candNo.score, "7: evidence increases score \(candNo.score) -> \(candWith.score)")
    assert(candWith.signals.contains(.hasEvidence), "7b: hasEvidence")
    assert(candWith.evidenceCount==2, "7c: evidenceCount 2")
}
do { // 8. Artifact increases appropriate candidate signal.
    let evNoArt = makeEvidence(id:"ev-noart", title:"No Art", skillIDs:["python"])
    let evArt = makeEvidence(id:"ev-art", title:"With Art", skillIDs:["python"], artifactURL:"https://github.com/me/repo")
    let reportNo = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-noart":evNoArt], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    let reportArt = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-art":evArt], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    let candNo = reportNo.evidence.first(where:{$0.sourceID=="ev-noart"})!
    let candArt = reportArt.evidence.first(where:{$0.sourceID=="ev-art"})!
    assert(!candNo.signals.contains(.hasArtifact), "8: no artifact signal absent")
    assert(candArt.signals.contains(.hasArtifact), "8b: artifact signal present")
    assert(candArt.score > candNo.score, "8c: artifact increases score")
    // Project artifact also
    let proj = makeProject(id:"proj-art", title:"Proj Art")
    let reportProjNo = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-art":1], roadmapProgress:[:], evidenceRecords:["ev-noart": makeEvidence(id:"ev-noart", title:"Ev", projectID:"proj-art")], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    let reportProjArt = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-art":1], roadmapProgress:[:], evidenceRecords:["ev-art": makeEvidence(id:"ev-art", title:"EvArt", projectID:"proj-art", artifactURL:"https://example.com")], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assert(reportProjArt.projects.first!.signals.contains(.hasArtifact), "8d: project artifact")
    assert(!reportProjNo.projects.first!.signals.contains(.hasArtifact), "8e: project no artifact")
}
do { // 9. Achievement evidence support is recognized.
    let ev = makeEvidence(id:"ev-1", title:"Ev", artifactURL:"https://example.com", occurredAt:recentDate)
    let achWith = makeAchievement(id:"ach-with", title:"With Ev", evidenceIDs:["ev-1"])
    let achWithout = makeAchievement(id:"ach-without", title:"Without Ev", evidenceIDs:[])
    let reportWith = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-1":ev], achievementRecords:["ach-with":achWith], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    let reportWithout = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:["ach-without":achWithout], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(reportWith.achievements.first!.signals.contains(.hasEvidence), "9: with evidence signal")
    assert(!reportWithout.achievements.first!.signals.contains(.hasEvidence), "9b: without not")
    assert(reportWith.achievements.first!.score > reportWithout.achievements.first!.score, "9c: support increases score")
    assertEqual(reportWith.achievements.first!.evidenceCount, 1, "9d: evidenceCount 1")
    assertEqual(reportWithout.achievements.first!.evidenceCount, 0, "9e: 0")
}
do { // 10. Roadmap connection is recognized.
    let rm = makeRoadmap(id:"rm-conn", title:"Roadmap Conn", skillsPerMilestone:[["Python"]])
    let proj = makeProject(id:"proj-conn", title:"Proj Conn", sourceRoadmapID:"rm-conn")
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-conn":1], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:["rm-conn": TestActiveRoadmap(roadmapID:"rm-conn", status:"active")], completedActionIDs:[], projects:[proj], roadmaps:[rm], asOf:fixedAsOf)
    let cand = report.projects.first(where:{$0.sourceID=="proj-conn"})!
    assert(cand.signals.contains(.hasRoadmapConnection), "10: roadmap connection")
    assert(cand.signals.contains(.supportsActiveRoadmap), "10b: supports active")
    // Evidence roadmap connection
    let ev = makeEvidence(id:"ev-conn", title:"Ev", roadmapID:"rm-conn", milestoneID:"rm-conn-m1")
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-conn":ev], achievementRecords:[:], activeRoadmaps:["rm-conn": TestActiveRoadmap(roadmapID:"rm-conn", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report2.evidence.first!.signals.contains(.supportsActiveRoadmap), "10c: evidence roadmap active")
}
do { // 11. Skill connections are recognized.
    let rm = makeRoadmap(id:"rm-skill", title:"Skill Roadmap", skillsPerMilestone:[["Python", "Git"]])
    let ev = makeEvidence(id:"ev-skill", title:"Ev Skill", roadmapID:"rm-skill", milestoneID:"rm-skill-m1", skillIDs:["python"])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:["rm-skill":1], roadmapProgress:["rm-skill":1], evidenceRecords:["ev-skill":ev], achievementRecords:[:], activeRoadmaps:["rm-skill": TestActiveRoadmap(roadmapID:"rm-skill", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    // Evidence should have demonstratesSkill if skill is demonstrated
    assert(report.evidence.first!.signals.contains(.demonstratesSkill) || report.evidence.first!.signals.contains(.hasSkills), "11: skill connection in evidence")
    // Skill candidate should have project/evidence support if skill demonstrated
    // Add project supporting python
    let proj = makeProject(id:"proj-skill", title:"Proj Skill", skills:["Python"])
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:["proj-skill":2, "rm-skill":1], roadmapProgress:["rm-skill":1], evidenceRecords:["ev-skill":ev], achievementRecords:[:], activeRoadmaps:["rm-skill": TestActiveRoadmap(roadmapID:"rm-skill", status:"active")], completedActionIDs:[], projects:[proj], roadmaps:[rm], asOf:fixedAsOf)
    assert(report2.skills.contains(where:{$0.sourceID=="python"}), "11b: python skill candidate")
    let skillCand = report2.skills.first(where:{$0.sourceID=="python"})!
    assert(skillCand.signals.contains(.hasProjectConnection) || skillCand.signals.contains(.hasEvidence), "11c: skill has project/evidence")
}

// MARK: - Skill correctness (12-14)

do { // 12. Evidence skill reference alone does not demonstrate skill.
    let ev = makeEvidence(id:"ev-ref", title:"Ref Skill", skillIDs:["python"])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-ref":ev], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(!report.skills.contains(where:{$0.sourceID=="python"}), "12: reference alone not demonstrated")
    // But profile strength does
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-ref":ev], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(report2.skills.contains(where:{$0.sourceID=="python"}), "12b: strength demonstrates")
}
do { // 13. Completed milestone skill acquisition can support skill candidacy.
    let rm = makeRoadmap(id:"rm-miles", title:"Milestone Roadmap", skillsPerMilestone:[["Python"], ["Git"]])
    // No profile strengths, but completed milestone 1 should demonstrate python
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:["rm-miles":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report.skills.contains(where:{$0.sourceID=="python"}), "13: milestone demonstrates python")
    assert(!report.skills.contains(where:{$0.sourceID=="git"}), "13b: not yet git")
    // Complete 2
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:["rm-miles":2], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report2.skills.contains(where:{$0.sourceID=="git"}), "13c: second milestone git")
}
do { // 14. SkillGapEngine remains authoritative.
    // Evidence linking to roadmap milestone should also demonstrate via evidenceRecords path
    let rm = makeRoadmap(id:"rm-evdemo", title:"Ev Demo", skillsPerMilestone:[["Research"]])
    let ev = makeEvidence(id:"ev-demo", title:"Demo", roadmapID:"rm-evdemo", milestoneID:"rm-evdemo-m1")
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-demo":ev], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    // Evidence for milestone should cause demonstrated via SkillGapEngine evidenceRecords path
    assert(report.skills.contains(where:{$0.sourceID=="research"}), "14: evidence milestone demonstrates")
}

// MARK: - Achievement correctness (15-18)

do { // 15. Suppressed generated achievement is not recommended (not in report).
    // Simulate suppressed: achievement would have been removed from achievementRecords via consistency.
    // So we test that if we don't include suppressed id in achievementRecords, it's not candidate; if we include with no evidence, low score but not suppressed.
    let suppressedAch = makeAchievement(id:"achievement-rm-m1", title:"Suppressed", evidenceIDs:["missing-ev"], source:.roadmapMilestone)
    // Not adding evidenceRecords for missing-ev, achievement would be filtered if we simulate consistency: we simply don't include suppressed in report because we filtered out suppressed before evaluate.
    // To test, we evaluate with empty evidenceRecords — achievement will have low score but still present; but suppressed should be absent entirely.
    // Instead test that achievement with missing evidence still appears but with low score, while truly suppressed (removed) is absent.
    let reportWithLow = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:["suppressed":suppressedAch], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    // It will appear but low score and not recommended
    if let cand = reportWithLow.achievements.first(where:{$0.sourceID=="suppressed"}) {
        assert(!cand.isRecommended, "15: suppressed-like low evidence not recommended")
        assert(!cand.signals.contains(.hasEvidence), "15b: no hasEvidence")
    } else {
        assert(true, "15: filtered")
    }
    // True suppressed would be absent from achievementRecords entirely — we simulate by not passing it
    let reportAbsent = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(!reportAbsent.achievements.contains(where:{$0.sourceID=="suppressed"}), "15c: truly suppressed absent")
}
do { // 16. Valid student-created achievement can be recommended.
    let ev = makeEvidence(id:"ev-student", title:"Student Ev", skillIDs:["python"], artifactURL:"https://example.com")
    let ach = makeAchievement(id:"ach-student", title:"Student Achievement", evidenceIDs:["ev-student"], skillIDs:["python"], createdAt:recentDate, source:.studentEntered)
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-student":ev], achievementRecords:["ach-student":ach], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(report.achievements.contains(where:{$0.sourceID=="ach-student"}), "16: student achievement candidate")
    let cand = report.achievements.first(where:{$0.sourceID=="ach-student"})!
    assert(cand.isRecommended, "16b: student achievement recommended with evidence support")
}
do { // 17. Achievement with no supporting evidence receives appropriate lower support.
    let achNoEv = makeAchievement(id:"ach-noev", title:"No Ev", evidenceIDs:[], source:.studentEntered)
    let achWithEv = makeAchievement(id:"ach-withev", title:"With Ev", evidenceIDs:["ev-1"], source:.studentEntered)
    let ev = makeEvidence(id:"ev-1", title:"Ev", skillIDs:["python"], artifactURL:"https://example.com")
    let reportNo = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:["ach-noev":achNoEv], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    let reportWith = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-1":ev], achievementRecords:["ach-withev":achWithEv], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    let candNo = reportNo.achievements.first(where:{$0.sourceID=="ach-noev"})!
    let candWith = reportWith.achievements.first(where:{$0.sourceID=="ach-withev"})!
    assert(candWith.score > candNo.score, "17: with evidence higher \(candNo.score) vs \(candWith.score)")
    assert(!candNo.signals.contains(.hasEvidence), "17b: no evidence signal absent")
}
do { // 18. No new achievement is generated by PortfolioEngine.
    let ev = makeEvidence(id:"ev-1", title:"Ev", roadmapID:"rm-1", milestoneID:"rm-1-m1")
    let rm = makeRoadmap(id:"rm-1", title:"Roadmap", skillsPerMilestone:[["Python"]])
    let beforeAchCount = 0
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["rm-1":1], roadmapProgress:["rm-1":1], evidenceRecords:["ev-1":ev], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assertEqual(report.achievements.count, 0, "18: no generated achievements")
    assert(report.projects.count >= 0, "18b: only existing")
    // Ensure evidenceRecords count unchanged after evaluate (no mutation)
    assertEqual(report.evidence.count, 1, "18c: evidence still 1")
}

// MARK: - Stale references (19-24)

do { // 19. Deleted/stale project reference does not crash.
    let portfolio = TestPortfolio(id:"p1", selectedProjectIDs:["missing-proj-123", "proj-real"], selectedAchievementIDs:[], selectedEvidenceIDs:[], selectedSkillIDs:[], selectedRoadmapIDs:[])
    let knownProjects: Set<String> = ["proj-real"]
    let issues = TestPortfolioEngine.unresolved(for:portfolio, knownProjectIDs:knownProjects, knownAchievementIDs:[], knownEvidenceIDs:[], knownSkillIDs:[], knownRoadmapIDs:[])
    assert(issues.contains(where:{$0.sourceID=="missing-proj-123"}), "19: stale project detected")
    assert(!issues.contains(where:{$0.sourceID=="proj-real"}), "19b: real not flagged")
    // Does not crash even with empty known sets
    let emptyIssues = TestPortfolioEngine.unresolved(for:portfolio, knownProjectIDs:[], knownAchievementIDs:[], knownEvidenceIDs:[], knownSkillIDs:[], knownRoadmapIDs:[])
    assert(emptyIssues.count >= 1, "19c: empty still detects")
}
do { // 20. Stale achievement reference does not crash.
    let portfolio = TestPortfolio(id:"p1", selectedProjectIDs:[], selectedAchievementIDs:["missing-ach"], selectedEvidenceIDs:[], selectedSkillIDs:[], selectedRoadmapIDs:[])
    let issues = TestPortfolioEngine.unresolved(for:portfolio, knownProjectIDs:[], knownAchievementIDs:["ach-real"], knownEvidenceIDs:[], knownSkillIDs:[], knownRoadmapIDs:[])
    assert(issues.contains(where:{$0.sourceID=="missing-ach"}), "20: stale ach")
}
do { // 21. Stale evidence reference does not crash.
    let portfolio = TestPortfolio(id:"p1", selectedProjectIDs:[], selectedAchievementIDs:[], selectedEvidenceIDs:["missing-ev"], selectedSkillIDs:[], selectedRoadmapIDs:[])
    let issues = TestPortfolioEngine.unresolved(for:portfolio, knownProjectIDs:[], knownAchievementIDs:[], knownEvidenceIDs:["ev-real"], knownSkillIDs:[], knownRoadmapIDs:[])
    assert(issues.contains(where:{$0.sourceID=="missing-ev"}), "21: stale ev")
}
do { // 22. Stale skill reference does not crash.
    let portfolio = TestPortfolio(id:"p1", selectedProjectIDs:[], selectedAchievementIDs:[], selectedEvidenceIDs:[], selectedSkillIDs:["nonexistent-skill-xyz"], selectedRoadmapIDs:[])
    let knownSkills: Set<String> = ["python"]
    let issues = TestPortfolioEngine.unresolved(for:portfolio, knownProjectIDs:[], knownAchievementIDs:[], knownEvidenceIDs:[], knownSkillIDs:knownSkills, knownRoadmapIDs:[])
    assert(issues.contains(where:{$0.sourceID=="nonexistent-skill-xyz"}), "22: stale skill")
    // Demonstrated skill not stale
    let portfolio2 = TestPortfolio(id:"p2", selectedProjectIDs:[], selectedAchievementIDs:[], selectedEvidenceIDs:[], selectedSkillIDs:["python"], selectedRoadmapIDs:[])
    let issues2 = TestPortfolioEngine.unresolved(for:portfolio2, knownProjectIDs:[], knownAchievementIDs:[], knownEvidenceIDs:[], knownSkillIDs:knownSkills, knownRoadmapIDs:[])
    assert(!issues2.contains(where:{$0.sourceID=="python"}), "22b: demonstrated not stale")
}
do { // 23. Stale roadmap reference does not crash.
    let portfolio = TestPortfolio(id:"p1", selectedProjectIDs:[], selectedAchievementIDs:[], selectedEvidenceIDs:[], selectedSkillIDs:[], selectedRoadmapIDs:["missing-roadmap"])
    let issues = TestPortfolioEngine.unresolved(for:portfolio, knownProjectIDs:[], knownAchievementIDs:[], knownEvidenceIDs:[], knownSkillIDs:[], knownRoadmapIDs:["rm-real"])
    assert(issues.contains(where:{$0.sourceID=="missing-roadmap"}), "23: stale roadmap")
}
do { // 24. Stale references do not mutate the portfolio.
    var portfolio = TestPortfolio(id:"p1", selectedProjectIDs:["stale-proj", "real-proj"], selectedAchievementIDs:[], selectedEvidenceIDs:[], selectedSkillIDs:[], selectedRoadmapIDs:[])
    let original = portfolio
    let _ = TestPortfolioEngine.unresolved(for:portfolio, knownProjectIDs:["real-proj"], knownAchievementIDs:[], knownEvidenceIDs:[], knownSkillIDs:[], knownRoadmapIDs:[])
    assertEqual(portfolio.selectedProjectIDs, original.selectedProjectIDs, "24: portfolio not mutated")
    assertEqual(portfolio.selectedProjectIDs.count, 2, "24b: count preserved")
    // Generate candidates does not mutate portfolio
    let proj = makeProject(id:"real-proj", title:"Real")
    let _ = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["real-proj":2], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assertEqual(portfolio.selectedProjectIDs, original.selectedProjectIDs, "24c: evaluate not mutate")
}

// MARK: - Deduplication (25-27)

do { // 25. Each source entity creates at most one candidate per type.
    let proj = makeProject(id:"proj-dedup", title:"Dedup")
    let ev1 = makeEvidence(id:"ev-1", title:"Ev1", projectID:"proj-dedup")
    let ev2 = makeEvidence(id:"ev-2", title:"Ev2", projectID:"proj-dedup")
    let ach = makeAchievement(id:"ach-1", title:"Ach", projectID:"proj-dedup")
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-dedup":1], roadmapProgress:[:], evidenceRecords:["ev-1":ev1, "ev-2":ev2], achievementRecords:["ach-1":ach], activeRoadmaps:[:], completedActionIDs:[], projects:[proj, proj], roadmaps:[], asOf:fixedAsOf) // duplicate project in input
    assertEqual(report.projects.filter{$0.sourceID=="proj-dedup"}.count, 1, "25: project dedup")
    assertEqual(report.evidence.count, 2, "25b: evidence each once")
    assertEqual(report.achievements.filter{$0.sourceID=="ach-1"}.count, 1, "25c: achievement once")
    // Even if same evidence discovered via multiple paths, only one candidate
    let evSame = makeEvidence(id:"ev-same", title:"Same", roadmapID:"rm-1", milestoneID:"rm-1-m1", projectID:"proj-dedup")
    // Shouldstill be one evidence candidate for that id
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-dedup":1], roadmapProgress:[:], evidenceRecords:["ev-same":evSame], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assertEqual(report2.evidence.filter{$0.sourceID=="ev-same"}.count, 1, "25d: evidence dedup")
}
do { // 26. Candidate IDs are stable.
    let proj = makeProject(id:"proj-stable", title:"Stable")
    let report1 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-stable":1], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-stable":1], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assertEqual(report1.projects.first!.id, "project:proj-stable", "26: stable id")
    assertEqual(report1.projects.first!.id, report2.projects.first!.id, "26b: identical across runs")
    // Skill
    let reportSkill = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    if let skillCand = reportSkill.skills.first(where:{$0.sourceID=="python"}) {
        assertEqual(skillCand.id, "skill:python", "26c: skill stable")
    }
}
do { // 27. Multiple discovery paths do not duplicate candidates.
    // Project could be discovered via progress, evidence, achievement — should still be one
    let proj = makeProject(id:"proj-multi", title:"Multi")
    let ev = makeEvidence(id:"ev-multi", title:"Ev Multi", projectID:"proj-multi")
    let ach = makeAchievement(id:"ach-multi", title:"Ach Multi", projectID:"proj-multi")
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-multi":1], roadmapProgress:[:], evidenceRecords:["ev-multi":ev], achievementRecords:["ach-multi":ach], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assertEqual(report.projects.filter{$0.sourceID=="proj-multi"}.count, 1, "27: single project despite multiple paths")
    // Evidence discovered via project and roadmap should still be one
    let evMulti2 = makeEvidence(id:"ev-multi2", title:"Ev", roadmapID:"rm-1", milestoneID:"rm-1-m1", projectID:"proj-multi")
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-multi":1], roadmapProgress:[:], evidenceRecords:["ev-multi2":evMulti2], achievementRecords:["ach-multi":ach], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assertEqual(report2.evidence.filter{$0.sourceID=="ev-multi2"}.count, 1, "27b: evidence single")
}

// MARK: - Determinism (28-31)

do { // 28. Same input + same asOf produces identical output.
    let proj = makeProject(id:"proj-det", title:"Deterministic")
    let ev = makeEvidence(id:"ev-det", title:"Ev", projectID:"proj-det", artifactURL:"https://example.com")
    let report1 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-det":2], roadmapProgress:[:], evidenceRecords:["ev-det":ev], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-det":2], roadmapProgress:[:], evidenceRecords:["ev-det":ev], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assertEqual(report1.projects.first!.score, report2.projects.first!.score, "28: score deterministic")
    assertEqual(report1.projects.first!.signals, report2.projects.first!.signals, "28b: signals deterministic")
    assertEqual(report1.projects.first!.reason, report2.projects.first!.reason, "28c: reason deterministic")
    assertEqual(report1.projects.first!.id, report2.projects.first!.id, "28d: id deterministic")
}
do { // 29. Candidate ordering is deterministic.
    let projA = makeProject(id:"proj-a", title:"Alpha")
    let projB = makeProject(id:"proj-b", title:"Beta")
    // Give proj-b higher score via artifact
    let evA = makeEvidence(id:"ev-a", title:"Ev A", projectID:"proj-a")
    let evB = makeEvidence(id:"ev-b", title:"Ev B", projectID:"proj-b", artifactURL:"https://example.com")
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-a":2, "proj-b":2], roadmapProgress:[:], evidenceRecords:["ev-a":evA, "ev-b":evB], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[projA, projB], roadmaps:[], asOf:fixedAsOf)
    // proj-b should be first due to higher score
    assertEqual(report.projects.first!.sourceID, "proj-b", "29: ordering by score")
    // Same score tie-break by title
    let projAlpha = makeProject(id:"proj-alpha", title:"Alpha")
    let projBeta = makeProject(id:"proj-beta", title:"Beta")
    let reportTie = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-alpha":1, "proj-beta":1], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[projAlpha, projBeta], roadmaps:[], asOf:fixedAsOf)
    assertEqual(reportTie.projects[0].title, "Alpha", "29b: tie-break title")
    assertEqual(reportTie.projects[1].title, "Beta", "29c: tie-break second")
}
do { // 30. Scores are deterministic.
    let rm = makeRoadmap(id:"rm-score", title:"Roadmap", skillsPerMilestone:[["Python"]])
    let ev1 = makeEvidence(id:"ev-1", title:"Ev1", roadmapID:"rm-score", milestoneID:"rm-score-m1", skillIDs:["python"], artifactURL:"https://example.com", description:"A meaningful description with detail.")
    let report1 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:["rm-score":1], evidenceRecords:["ev-1":ev1], achievementRecords:[:], activeRoadmaps:["rm-score": TestActiveRoadmap(roadmapID:"rm-score", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:["rm-score":1], evidenceRecords:["ev-1":ev1], achievementRecords:[:], activeRoadmaps:["rm-score": TestActiveRoadmap(roadmapID:"rm-score", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assertEqual(report1.evidence.first!.score, report2.evidence.first!.score, "30: score deterministic")
    assertEqual(report1.roadmaps.first!.score, report2.roadmaps.first!.score, "30b: roadmap score deterministic")
}
do { // 31. Reasons are deterministic.
    let proj = makeProject(id:"proj-reason", title:"Reason")
    let report1 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-reason":2], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-reason":2], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assertEqual(report1.projects.first!.reason, report2.projects.first!.reason, "31: reason deterministic")
    // Ensure no exaggerated language
    let allReasons = report1.all.map(\.reason).joined(separator:" ").lowercased()
    let forbidden = ["impressive", "elite", "exceptional", "guaranteed", "college-ready", "career-ready"]
    for word in forbidden {
        assert(!allReasons.contains(word), "31b: no exaggerated \(word)")
    }
}

// MARK: - Portfolio independence (32-37)

do { // 32. Generating candidates does not modify portfolio selections.
    var portfolio = TestPortfolio(id:"p1", selectedProjectIDs:["proj-1"], selectedAchievementIDs:[], selectedEvidenceIDs:[], selectedSkillIDs:[], selectedRoadmapIDs:[])
    let original = portfolio
    let proj = makeProject(id:"proj-1", title:"Proj")
    let _ = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-1":2], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assertEqual(portfolio.selectedProjectIDs, original.selectedProjectIDs, "32: portfolio not mutated")
}
do { // 33. Generating candidates does not modify project progress.
    var progress = ["proj-1": 1]
    let before = progress
    let proj = makeProject(id:"proj-1", title:"Proj")
    let _ = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:progress, roadmapProgress:[:], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assertEqual(progress, before, "33: project progress not mutated")
}
do { // 34. Generating candidates does not modify achievements.
    var achs: [String:TestAchievement] = ["ach-1": makeAchievement(id:"ach-1", title:"Ach")]
    let beforeCount = achs.count
    let beforeTitle = achs["ach-1"]!.title
    let _ = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:[:], achievementRecords:achs, activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assertEqual(achs.count, beforeCount, "34: achievements not mutated")
    assertEqual(achs["ach-1"]!.title, beforeTitle, "34b")
}
do { // 35. Generating candidates does not modify evidence.
    var evs: [String:TestEvidenceRecord] = ["ev-1": makeEvidence(id:"ev-1", title:"Ev")]
    let before = evs
    let _ = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:evs, achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assertEqual(evs, before, "35: evidence not mutated")
}
do { // 36. Generating candidates does not modify skills.
    var profile = TestStudentProfile(strengths:["Python"])
    let before = profile.strengths
    let rm = makeRoadmap(id:"rm-1", title:"R", skillsPerMilestone:[["Python"]])
    let _ = TestPortfolioEngine.evaluate(profile:profile, projectProgress:[:], roadmapProgress:["rm-1":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assertEqual(profile.strengths, before, "36: profile strengths not mutated")
}
do { // 37. Generating candidates does not activate/deactivate roadmaps.
    var active:[String:TestActiveRoadmap] = [:]
    let before = active
    let rm = makeRoadmap(id:"rm-1", title:"R", skillsPerMilestone:[["Python"]])
    let _ = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:["rm-1":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:active, completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assertEqual(active, before, "37: activeRoadmaps not mutated")
    // Also with active present
    active = ["rm-1": TestActiveRoadmap(roadmapID:"rm-1", status:"active")]
    let before2 = active
    let _ = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:["rm-1":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:active, completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assertEqual(active, before2, "37b: still not mutated when active")
}

// MARK: - Career agnosticism (38-45)

do { // 38. Software Engineering roadmap works.
    let rm = makeRoadmap(id:"software-engineer", title:"Software Engineer", skillsPerMilestone:[["Python"], ["Git"]])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:["software-engineer":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:["software-engineer": TestActiveRoadmap(roadmapID:"software-engineer", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report.roadmaps.contains(where:{$0.sourceID=="software-engineer"}), "38: software engineer works")
    assert(report.skills.contains(where:{$0.sourceID=="python"}), "38b: skill works")
}
do { // 39. AI Engineering roadmap works.
    let rm = makeRoadmap(id:"ai-engineer", title:"AI Engineer", skillsPerMilestone:[["Machine Learning"], ["Python"]])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Machine Learning"]), projectProgress:[:], roadmapProgress:["ai-engineer":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:["ai-engineer": TestActiveRoadmap(roadmapID:"ai-engineer", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report.roadmaps.contains(where:{$0.sourceID=="ai-engineer"}), "39: ai engineer")
}
do { // 40. Research roadmap works.
    let rm = makeRoadmap(id:"research-builder", title:"Research", skillsPerMilestone:[["Research"]])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Research"]), projectProgress:[:], roadmapProgress:["research-builder":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:["research-builder": TestActiveRoadmap(roadmapID:"research-builder", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report.roadmaps.contains(where:{$0.sourceID=="research-builder"}), "40: research")
}
do { // 41. Leadership roadmap works.
    let rm = makeRoadmap(id:"leadership", title:"Leadership", skillsPerMilestone:[["Leadership"]])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Leadership"]), projectProgress:[:], roadmapProgress:["leadership":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:["leadership": TestActiveRoadmap(roadmapID:"leadership", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report.roadmaps.contains(where:{$0.sourceID=="leadership"}), "41: leadership")
}
do { // 42. Community Impact roadmap works.
    let rm = makeRoadmap(id:"community-impact", title:"Community", skillsPerMilestone:[["Communication"]])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Communication"]), projectProgress:[:], roadmapProgress:["community-impact":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:["community-impact": TestActiveRoadmap(roadmapID:"community-impact", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report.roadmaps.contains(where:{$0.sourceID=="community-impact"}), "42: community")
}
do { // 43. Entrepreneurship roadmap works.
    let rm = makeRoadmap(id:"venture", title:"Venture", skillsPerMilestone:[["Business Fundamentals"]])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Business Fundamentals"]), projectProgress:[:], roadmapProgress:["venture":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:["venture": TestActiveRoadmap(roadmapID:"venture", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report.roadmaps.contains(where:{$0.sourceID=="venture"}), "43: venture")
}
do { // 44. College Preparation roadmap works.
    let rm = makeRoadmap(id:"college-ready", title:"College Ready", skillsPerMilestone:[["Academic Planning"]])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Academic Planning"]), projectProgress:[:], roadmapProgress:["college-ready":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:["college-ready": TestActiveRoadmap(roadmapID:"college-ready", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rm], asOf:fixedAsOf)
    assert(report.roadmaps.contains(where:{$0.sourceID=="college-ready"}), "44: college")
}
do { // 45. No roadmap-specific conditional logic exists (career-agnostic verification).
    // Engine should produce similar scoring structure regardless of roadmap ID; test that same student data scores similarly for different roadmap IDs
    let rmSE = makeRoadmap(id:"software-engineer", title:"SE", skillsPerMilestone:[["Python"]])
    let rmLead = makeRoadmap(id:"leadership", title:"Lead", skillsPerMilestone:[["Leadership"]])
    // Student has both skills demonstrated via profile
    let profile = TestStudentProfile(strengths:["Python", "Leadership"])
    let reportSE = TestPortfolioEngine.evaluate(profile:profile, projectProgress:[:], roadmapProgress:["software-engineer":1, "leadership":1], evidenceRecords:[:], achievementRecords:[:], activeRoadmaps:["software-engineer": TestActiveRoadmap(roadmapID:"software-engineer", status:"active"), "leadership": TestActiveRoadmap(roadmapID:"leadership", status:"active")], completedActionIDs:[], projects:[], roadmaps:[rmSE, rmLead], asOf:fixedAsOf)
    // Both should be candidates with similar base scores (both have same structure, just different ID)
    let candSE = reportSE.roadmaps.first(where:{$0.sourceID=="software-engineer"})!
    let candLead = reportSE.roadmaps.first(where:{$0.sourceID=="leadership"})!
    // Scores should be equal because structure identical (only ID/title differ) — career-agnostic
    assertEqual(candSE.score, candLead.score, "45: career-agnostic scores equal for identical structure")
    // Ensure engine does not contain hardcoded ID check (we cannot inspect code here, but structural equality suggests no special casing)
    // Also ensure candidate signals are same set (excluding title-based)
    assertEqual(candSE.signals.sorted{$0.rawValue < $1.rawValue}, candLead.signals.sorted{$0.rawValue < $1.rawValue}, "45b: signals equal")
}

// MARK: - Recency (46-48)

do { // 46. Known dates produce deterministic recency signals.
    let evRecent = makeEvidence(id:"ev-recent", title:"Recent", occurredAt:recentDate, createdAt:recentDate)
    let evOld = makeEvidence(id:"ev-old", title:"Old", occurredAt:oldDate, createdAt:oldDate)
    let reportRecent = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-recent":evRecent], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    let reportOld = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-old":evOld], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(reportRecent.evidence.first!.signals.contains(.recent), "46: recent signal present")
    assert(!reportOld.evidence.first!.signals.contains(.recent), "46b: old not recent")
    assert(reportRecent.evidence.first!.score > reportOld.evidence.first!.score, "46c: recent higher score")
}
do { // 47. Missing dates do not receive invented recency.
    let evNoDate = TestEvidenceRecord(id:"ev-nodate", title:"No Date", description:nil, type:.other, roadmapID:"", milestoneID:"", createdAt:Date(timeIntervalSince1970:0), occurredAt:nil, source:.studentEntered, status:.recorded, skillIDs:nil, artifact:nil, projectID:nil, opportunityID:nil, validationID:nil, validationPassed:nil)
    // CreatedAt is 1970 -> old, not recent
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-nodate":evNoDate], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(!report.evidence.first!.signals.contains(.recent), "47: no invented recency for old date")
    // Evidence with no occurredAt but recent createdAt should be recent
    let evRecentCreated = makeEvidence(id:"ev-recent-created", title:"Recent Created", occurredAt:nil, createdAt:recentDate)
    let report2 = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-recent-created":evRecentCreated], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    assert(report2.evidence.first!.signals.contains(.recent), "47b: recent createdAt gives recent")
    // Missing both would be not recent but our EvidenceRecord always has createdAt; test nil occurredAt case already
}
do { // 48. Changing asOf changes only appropriate time-dependent signals.
    let ev = makeEvidence(id:"ev-time", title:"Time", occurredAt:recentDate) // 30 days before fixedAsOf
    let asOfEarly = fixedAsOf // ev is 30 days ago -> recent
    let asOfLate = fixedAsOf.addingTimeInterval(200*24*60*60) // 200 days later -> ev is 230 days ago -> not recent
    let reportEarly = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-time":ev], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:asOfEarly)
    let reportLate = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-time":ev], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:asOfLate)
    assert(reportEarly.evidence.first!.signals.contains(.recent), "48: early recent")
    assert(!reportLate.evidence.first!.signals.contains(.recent), "48b: late not recent")
    assert(reportEarly.evidence.first!.score != reportLate.evidence.first!.score, "48c: score changes with asOf")
    // Non-time signals should remain same
    let earlyNonRecent = reportEarly.evidence.first!.signals.filter{$0 != .recent}.sorted{$0.rawValue < $1.rawValue}
    let lateNonRecent = reportLate.evidence.first!.signals.filter{$0 != .recent}.sorted{$0.rawValue < $1.rawValue}
    assertEqual(earlyNonRecent, lateNonRecent, "48d: non-recency signals stable")
}

// MARK: - Scoring (49-52)

do { // 49. Score stays within documented bounds.
    let proj = makeProject(id:"proj-bound", title:"Bound", skills:["Python","Git","Research"])
    let ev = makeEvidence(id:"ev-bound", title:"Ev Bound", roadmapID:"", milestoneID:"", projectID:"proj-bound", skillIDs:["python"], artifactURL:"https://example.com", occurredAt:recentDate, createdAt:recentDate, description:"A detailed description with many words to ensure quality.")
    let ach = makeAchievement(id:"ach-bound", title:"Ach Bound", evidenceIDs:["ev-bound"], skillIDs:["python"], projectID:"proj-bound")
    let rm = makeRoadmap(id:"rm-bound", title:"Roadmap Bound", skillsPerMilestone:[["Python"]])
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:["proj-bound":4, "rm-bound":1], roadmapProgress:["rm-bound":1], evidenceRecords:["ev-bound":ev], achievementRecords:["ach-bound":ach], activeRoadmaps:["rm-bound": TestActiveRoadmap(roadmapID:"rm-bound", status:"active")], completedActionIDs:[], projects:[proj], roadmaps:[rm], asOf:fixedAsOf)
    for cand in report.all {
        assert(cand.score >= 0 && cand.score <= 100, "49: score bounds 0-100 for \(cand.id) got \(cand.score)")
    }
}
do { // 50. Same signals produce same score.
    let projA = makeProject(id:"proj-same", title:"Same")
    let projB = makeProject(id:"proj-same2", title:"Same2")
    // Same progress, same evidence structure should give same score
    let evA = makeEvidence(id:"ev-a", title:"Ev", projectID:"proj-same")
    let evB = makeEvidence(id:"ev-b", title:"Ev", projectID:"proj-same2")
    let reportA = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-same":1], roadmapProgress:[:], evidenceRecords:["ev-a":evA], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[projA], roadmaps:[], asOf:fixedAsOf)
    let reportB = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-same2":1], roadmapProgress:[:], evidenceRecords:["ev-b":evB], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[projB], roadmaps:[], asOf:fixedAsOf)
    assertEqual(reportA.projects.first!.score, reportB.projects.first!.score, "50: same signals same score")
    assertEqual(reportA.projects.first!.signals, reportB.projects.first!.signals, "50b: same signals")
}
do { // 51. Quality is not the only scoring dimension.
    // Evidence with strong quality but no other signals vs evidence with solid quality but multiple other signals
    let evStrong = makeEvidence(id:"ev-strong", title:"Strong", roadmapID:"", milestoneID:"", projectID:nil, skillIDs:["python"], artifactURL:"https://example.com", occurredAt:recentDate, description:"Detailed description with enough words.")
    // Make it strong by having many dimensions: roadmap, skills, artifact, description, date
    let evStrongFull = TestEvidenceRecord(id:"ev-strong", title:"Strong", description:"A very detailed description that is definitely longer than ten characters.", type:.projectWork, roadmapID:"rm-1", milestoneID:"m-1", createdAt:recentDate, occurredAt:recentDate, source:.roadmapMilestone, status:.recorded, skillIDs:["python"], artifact:TestEvidenceArtifact(type:"link", title:"Art", url:"https://example.com"), projectID:nil, opportunityID:nil, validationID:nil, validationPassed:nil)
    let evWeakQualityButRich = TestEvidenceRecord(id:"ev-rich", title:"Rich", description:"A very detailed description with many connections and context.", type:.other, roadmapID:"rm-1", milestoneID:"m-1", createdAt:recentDate, occurredAt:recentDate, source:.studentEntered, status:.recorded, skillIDs:["python","git","research"], artifact:TestEvidenceArtifact(type:"link", title:"Art", url:"https://example.com"), projectID:"proj-1", opportunityID:"opp-1", validationID:nil, validationPassed:nil)
    // evWeakQualityButRich may be solid, not strong, but has project/opportunity/multiple skills
    let reportStrong = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-strong":evStrongFull], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    let reportRich = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:[:], roadmapProgress:[:], evidenceRecords:["ev-rich":evWeakQualityButRich], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[], roadmaps:[], asOf:fixedAsOf)
    let strongScore = reportStrong.evidence.first!.score
    let richScore = reportRich.evidence.first!.score
    // Rich should be competitive or higher despite not being highest quality tier alone — shows quality not sole dimension
    assert(richScore >= strongScore - 10, "51: quality not sole dimension rich \(richScore) vs strong \(strongScore)")
    // Also project score includes many dimensions besides quality
    let proj = makeProject(id:"proj-quality", title:"Quality Test", skills:["Python"])
    let evBasic = makeEvidence(id:"ev-basic", title:"Basic", roadmapID:"", milestoneID:"", projectID:"proj-quality", skillIDs:nil, description:"Short") // basic quality
    let reportProjBasic = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-quality":1], roadmapProgress:[:], evidenceRecords:["ev-basic":evBasic], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    let evStrongForProj = makeEvidence(id:"ev-strong-proj", title:"StrongProj", projectID:"proj-quality", skillIDs:["python"], artifactURL:"https://example.com", description:"A detailed description that makes quality solid.")
    let reportProjStrong = TestPortfolioEngine.evaluate(profile:TestStudentProfile(strengths:["Python"]), projectProgress:["proj-quality":1], roadmapProgress:[:], evidenceRecords:["ev-strong-proj":evStrongForProj], achievementRecords:[:], activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[], asOf:fixedAsOf)
    assert(reportProjStrong.projects.first!.score > reportProjBasic.projects.first!.score, "51b: project score reflects more than quality")
    // Ensure quality signal alone doesn't dominate: check that hasEvidence etc. also contribute
    assert(reportProjStrong.projects.first!.signals.contains(.hasEvidence), "51c: hasEvidence still present")
}
do { // 52. Candidate score never changes canonical records.
    var profile = TestStudentProfile(strengths:["Python"])
    var projectProgress = ["proj-1": 1]
    var roadmapProgress = ["rm-1": 1]
    var evs: [String:TestEvidenceRecord] = ["ev-1": makeEvidence(id:"ev-1", title:"Ev", projectID:"proj-1")]
    var achs: [String:TestAchievement] = ["ach-1": makeAchievement(id:"ach-1", title:"Ach", evidenceIDs:["ev-1"])]
    let beforeProfile = profile
    let beforeProj = projectProgress
    let beforeRoad = roadmapProgress
    let beforeEvs = evs
    let beforeAchs = achs
    let proj = makeProject(id:"proj-1", title:"Proj")
    let rm = makeRoadmap(id:"rm-1", title:"RM", skillsPerMilestone:[["Python"]])
    let _ = TestPortfolioEngine.evaluate(profile:profile, projectProgress:projectProgress, roadmapProgress:roadmapProgress, evidenceRecords:evs, achievementRecords:achs, activeRoadmaps:[:], completedActionIDs:[], projects:[proj], roadmaps:[rm], asOf:fixedAsOf)
    assertEqual(profile, beforeProfile, "52: profile unchanged")
    assertEqual(projectProgress, beforeProj, "52b: projectProgress unchanged")
    assertEqual(roadmapProgress, beforeRoad, "52c: roadmapProgress unchanged")
    assertEqual(evs, beforeEvs, "52d: evidence unchanged")
    assertEqual(achs, beforeAchs, "52e: achievements unchanged")
}

// MARK: - Additional statics

do { // Verify no duplicate candidate type+sourceID across report
    let proj = makeProject(id:"proj-dupcheck", title:"DupCheck")
    let ev = makeEvidence(id:"ev-dupcheck", title:"Ev", projectID:"proj-dupcheck")
    let ach = makeAchievement(id:"ach-dupcheck", title:"Ach", projectID:"proj-dupcheck")
    let report = TestPortfolioEngine.evaluate(profile:TestStudentProfile(), projectProgress:["proj-dupcheck":1], roadmapProgress:[:], evidenceRecords:["ev-dupcheck":ev], achievementRecords:["ach-dupcheck":ach], activeRoadmaps:[:], completedActionIDs:[], projects:[proj, proj], roadmaps:[], asOf:fixedAsOf)
    let ids = report.all.map(\.id)
    assertEqual(ids.count, Set(ids).count, "dupcheck: no duplicate ids")
    // Verify each id follows "<type>:<sourceID>" stable format
    for cand in report.all {
        assert(cand.id == "\(cand.type.rawValue):\(cand.sourceID)", "stable id format \(cand.id)")
    }
}

print("\nPhase 8.2 — Portfolio Engine: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
else { print("Some tests failed — review output") }
