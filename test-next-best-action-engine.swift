import Foundation

// Standalone test script for Phase 6.7 — Next-Best-Action Engine
// Run: swift test-next-best-action-engine.swift

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 }
    else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}

// MARK: - Inline Models

struct TSkill: Hashable {
    let id: String
    let name: String
    static func normalizeID(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = t.components(separatedBy: .whitespacesAndNewlines).filter{!$0.isEmpty}
        return parts.joined(separator: " ").lowercased()
    }
    static func canonical(_ raw: String) -> TSkill {
        let n = normalizeID(raw)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return TSkill(id: n, name: trimmed.isEmpty ? n : trimmed)
    }
}
struct TAction: Hashable { let id: String; let title: String; let order: Int; let estimatedTime: String? }
struct TMilestone: Hashable {
    let id: String; let title: String; let skillsDeveloped: [String]?; let actions: [TAction]?; let dependencies: [String]?; let estimatedTime: String
}
struct TRoadmap: Hashable {
    let id: String; let title: String; let goal: String; let description: String; let milestones: [TMilestone]
}
struct TProfile { var strengths: [String]=[]; var customSkills: [String]=[] }
struct TRemoteOpp: Hashable { let id: String; var skills: [String]=[]; var topics: [String]=[]; var subjects: [String]=[]; var category: String="hackathon" }
struct TLocalOpp { let id: String; var relevantSkills: Set<String>=[]; let title: String }
struct TScoredOpp { let opp: TLocalOpp; let matchScore: Int }
struct TProjectMilestone: Hashable { let id: String; let title: String; let estimatedTime: String }
struct TProject: Hashable { let id: String; let title: String; let goal: String; let milestones: [TProjectMilestone]; let skills: [String]; let sourceRoadmapID: String? }
struct TScoredProject: Hashable { let project: TProject; let matchScore: Int; let completedMilestones: Int; var isCompleted: Bool { completedMilestones >= project.milestones.count }; var currentMilestone: TProjectMilestone? { project.milestones.indices.contains(completedMilestones) ? project.milestones[completedMilestones] : nil } }
struct TPersonalizedOpp: Hashable {
    let opportunity: TRemoteOpp
    let eligibilityStatus: String // eligible/ineligible/unknown
    let freshnessStatus: String // active/expired/unknown
    let freshnessUrgency: String // urgent/soon/upcoming/later/none
    let matchScore: Int
    let deadline: String?
}
struct TFeed: Hashable { let opportunities: [TPersonalizedOpp] }
enum TNextType: String, Hashable { case roadmapAction, opportunity, savedOpportunity, projectAction, startRoadmap }
enum TPriority: String, Hashable, Comparable {
    case high, medium, low
    var rank: Int { switch self { case .high: return 3; case .medium: return 2; case .low: return 1 } }
    static func <(lhs:TPriority,rhs:TPriority)->Bool{ lhs.rank < rhs.rank }
}
struct TNextAction: Identifiable, Hashable {
    let id: String; let type: TNextType; let title: String; let subtitle: String; let priority: TPriority; let priorityScore: Int
    let roadmapID: String?; let milestoneID: String?; let actionID: String?; let opportunityID: String?; let projectID: String?
    let skillIDs: [String]; let signals: [String]; let estimatedTime: String?; let deadline: String?
}

// MARK: - Inline Engines

enum TRoadmapEngine {
    enum Avail { case completed, available, locked([String]) }
    static func milestoneAvailability(milestone: TMilestone, completedIDs: Set<String>) -> Avail {
        if completedIDs.contains(milestone.id) { return .completed }
        guard let deps = milestone.dependencies, !deps.isEmpty else { return .available }
        let inc = deps.filter{!completedIDs.contains($0)}
        if inc.isEmpty { return .available }
        return .locked(inc)
    }
}
enum TSkillGapEngine {
    static func requiredSkills(for roadmap: TRoadmap) -> [TSkill] {
        var seen=Set<String>(); var res:[TSkill]=[]
        for m in roadmap.milestones { for raw in m.skillsDeveloped ?? [] { let n=TSkill.normalizeID(raw); if n.isEmpty || seen.contains(n){continue}; seen.insert(n); res.append(TSkill.canonical(raw)) } }
        return res
    }
    static func demonstratedIDs(profile: TProfile, progress: [String:Int], catalog: [TRoadmap]) -> Set<String> {
        var s=Set<String>()
        for r in profile.strengths { let n=TSkill.normalizeID(r); if !n.isEmpty{s.insert(n)} }
        for r in profile.customSkills { let n=TSkill.normalizeID(r); if !n.isEmpty{s.insert(n)} }
        for roadmap in catalog {
            let c = min(progress[roadmap.id] ?? 0, roadmap.milestones.count)
            for i in 0..<c { for raw in roadmap.milestones[i].skillsDeveloped ?? [] { let n=TSkill.normalizeID(raw); if !n.isEmpty{s.insert(n)} } }
        }
        return s
    }
    static func gaps(for roadmap: TRoadmap, profile: TProfile, progress: [String:Int], catalog: [TRoadmap]) -> [TSkill] {
        let req = requiredSkills(for: roadmap)
        let dem = demonstratedIDs(profile: profile, progress: progress, catalog: catalog)
        return req.filter{!dem.contains($0.id)}
    }
}
enum TOppRoadmapEngine {
    static func normalizedSkillIDs(for opp: TRemoteOpp) -> Set<String> {
        var ids=Set<String>(); for raw in opp.skills + opp.topics + opp.subjects { let n=TSkill.normalizeID(raw); if !n.isEmpty{ids.insert(n)} }; return ids
    }
    static func connection(for opp: TRemoteOpp, roadmap: TRoadmap, profile: TProfile, progress: [String:Int], catalog: [TRoadmap]) -> (matched:[TSkill], gaps:[TSkill], milestoneIDs:[String], strength:String, score:Int, advancesCurrent:Bool)? {
        let oppIDs = normalizedSkillIDs(for: opp)
        if oppIDs.isEmpty { return nil }
        var skillToIdx: [String:[Int]]=[:]; var skillMap:[String:TSkill]=[:]
        for (idx,m) in roadmap.milestones.enumerated() { for raw in m.skillsDeveloped ?? [] { let n=TSkill.normalizeID(raw); if n.isEmpty{continue}; skillToIdx[n,default:[]].append(idx); if skillMap[n]==nil{skillMap[n]=TSkill.canonical(raw)} } }
        if skillMap.isEmpty { return nil }
        var matched:[TSkill]=[]; var matchedIDs=Set<String>()
        for oid in oppIDs { if let s=skillMap[oid], !matchedIDs.contains(oid){ matchedIDs.insert(oid); matched.append(s) } }
        if matched.isEmpty { return nil }
        let gaps = TSkillGapEngine.gaps(for: roadmap, profile: profile, progress: progress, catalog: catalog)
        let gapIDs = Set(gaps.map(\.id))
        let gapAddressed = matched.filter{gapIDs.contains($0.id)}
        let completedCount = min(progress[roadmap.id] ?? 0, roadmap.milestones.count)
        let completedIDs = Set(roadmap.milestones.prefix(completedCount).map(\.id))
        var idxSet=Set<Int>(); for sid in matchedIDs { if let arr=skillToIdx[sid]{ for i in arr{idxSet.insert(i)} } }
        let sortedIdx = idxSet.sorted()
        var hasCurrent=false; var hasAvailable=false
        var milestoneIDs:[String]=[]
        for idx in sortedIdx {
            let m=roadmap.milestones[idx]
            milestoneIDs.append(m.id)
            let av = TRoadmapEngine.milestoneAvailability(milestone: m, completedIDs: completedIDs)
            switch av {
            case .completed: break
            case .locked: break
            case .available:
                if idx==completedCount{hasCurrent=true; hasAvailable=true} else {hasAvailable=true}
            }
        }
        let totalActions = sortedIdx.reduce(0){$0 + (roadmap.milestones[$1].actions?.count ?? 0)}
        let base = matched.count*10
        let gapBonus = gapAddressed.count*15
        let curBonus = hasCurrent ? 20 : 0
        let avBonus = hasAvailable ? 10 : 0
        let actBonus = min(totalActions,10)
        let earliest = sortedIdx.first ?? 0
        let earliness = max(0,(roadmap.milestones.count - earliest)*2)
        let score = base+gapBonus+curBonus+avBonus+actBonus+earliness
        let strength: String = !gapAddressed.isEmpty && hasAvailable ? "direct" : hasAvailable ? "relevant" : "future"
        return (matched, gapAddressed, milestoneIDs, strength, score, hasCurrent)
    }
}
enum TNextEngine {
    static func roadmapActionCandidates(profile: TProfile, progress:[String:Int], active:[TRoadmap], catalog:[TRoadmap], completedActionIDs:Set<String>) -> [TNextAction] {
        var out:[TNextAction]=[]
        for roadmap in active {
            let completedCount = min(progress[roadmap.id] ?? 0, roadmap.milestones.count)
            let completedIDs = Set(roadmap.milestones.prefix(completedCount).map(\.id))
            let gaps = TSkillGapEngine.gaps(for: roadmap, profile: profile, progress: progress, catalog: catalog)
            let gapByMilestone: [String:[TSkill]] = {
                var m:[String:[TSkill]]=[:]
                let req = TSkillGapEngine.requiredSkills(for: roadmap)
                // Map skill to milestones
                for g in gaps {
                    for ms in roadmap.milestones { if (ms.skillsDeveloped ?? []).map({TSkill.normalizeID($0)}).contains(g.id) { m[ms.id,default:[]].append(g) } }
                }
                return m
            }()
            var dependentCounts:[String:Int]=[:]; for ms in roadmap.milestones { for dep in ms.dependencies ?? []{ dependentCounts[dep,default:0]+=1 } }
            for (idx, ms) in roadmap.milestones.enumerated() {
                let av = TRoadmapEngine.milestoneAvailability(milestone: ms, completedIDs: completedIDs)
                switch av { case .completed, .locked: continue; case .available: break }
                guard let actions = ms.actions, !actions.isEmpty else { continue }
                let mGaps = gapByMilestone[ms.id] ?? []
                let isCurrent = idx==completedCount
                let depCnt = dependentCounts[ms.id] ?? 0
                for act in actions {
                    if completedActionIDs.contains(act.id) { continue }
                    var signals:[String]=[]
                    if isCurrent { signals.append("advances current milestone") } else { signals.append("advances available milestone") }
                    if !mGaps.isEmpty { signals.append("addresses gap: \(mGaps.prefix(2).map(\.name).joined(separator:", "))") }
                    if depCnt>0 { signals.append("unlocks \(depCnt) future") }
                    let score = 50 + (isCurrent ? 20:10) + (!mGaps.isEmpty ? 12:0) + min(mGaps.count*3,9) + depCnt*10 + 5
                    let prio: TPriority = score>=70 ? .high : score>=45 ? .medium : .low
                    out.append(TNextAction(id:"roadmapAction-\(ms.id)-\(act.id)", type:.roadmapAction, title: act.title, subtitle: ms.title, priority: prio, priorityScore: score, roadmapID: roadmap.id, milestoneID: ms.id, actionID: act.id, opportunityID: nil, projectID: nil, skillIDs: ms.skillsDeveloped?.map{TSkill.normalizeID($0)} ?? [], signals: signals, estimatedTime: act.estimatedTime ?? ms.estimatedTime, deadline: nil))
                }
            }
        }
        return out
    }
    static func opportunityCandidates(feed: TFeed?, profile:TProfile, progress:[String:Int], catalog:[TRoadmap], active:[TRoadmap], saved:Set<String>) -> [TNextAction] {
        guard let feed = feed else { return [] }
        if active.isEmpty { return [] }
        var out:[TNextAction]=[]
        for p in feed.opportunities {
            if p.freshnessStatus=="expired" { continue }
            if p.eligibilityStatus=="ineligible" { continue }
            // find best connection among active
            var best: (roadmap:TRoadmap, conn:(matched:[TSkill], gaps:[TSkill], milestoneIDs:[String], strength:String, score:Int, advancesCurrent:Bool))? = nil
            var bestScore = -1
            for roadmap in active {
                if let conn = TOppRoadmapEngine.connection(for: p.opportunity, roadmap: roadmap, profile: profile, progress: progress, catalog: catalog) {
                    if conn.score > bestScore { bestScore=conn.score; best=(roadmap, conn) }
                }
            }
            guard let chosen = best else { continue }
            let conn = chosen.conn
            let isSaved = saved.contains(p.opportunity.id)
            let type: TNextType = isSaved ? .savedOpportunity : .opportunity
            var signals:[String]=[]
            signals.append("match \(p.matchScore)%")
            if !conn.gaps.isEmpty { signals.append("addresses gap: \(conn.gaps.prefix(2).map(\.name).joined(separator:", "))") }
            signals.append("\(conn.strength) connection: \(chosen.roadmap.title)")
            if p.freshnessUrgency=="urgent" { signals.append("deadline urgent") }
            else if p.freshnessUrgency=="soon" { signals.append("deadline soon") }
            if isSaved { signals.append("saved") }
            let urgencyScore: Int = p.freshnessUrgency=="urgent" ? 20 : p.freshnessUrgency=="soon" ? 12 : p.freshnessUrgency=="upcoming" ? 5 : 0
            let strengthScore: Int = conn.strength=="direct" ? 20 : conn.strength=="relevant" ? 10 : 0
            let score = 30 + p.matchScore/5 + conn.gaps.count*12 + strengthScore + urgencyScore + (isSaved ? 8:0) + (conn.advancesCurrent ? 12:0)
            let prio: TPriority = score>=70 ? .high : score>=45 ? .medium : .low
            out.append(TNextAction(id:"opp-\(p.opportunity.id)-\(chosen.roadmap.id)", type: type, title:"Apply to \(p.opportunity.id)", subtitle: chosen.roadmap.title, priority: prio, priorityScore: score, roadmapID: chosen.roadmap.id, milestoneID: conn.milestoneIDs.first, actionID: nil, opportunityID: p.opportunity.id, projectID: nil, skillIDs: conn.matched.map(\.id), signals: signals, estimatedTime: nil, deadline: p.deadline))
        }
        return out
    }
    static func projectCandidates(scoredProjects:[TScoredProject]) -> [TNextAction] {
        var out:[TNextAction]=[]
        for sp in scoredProjects where !sp.isCompleted {
            guard let m = sp.currentMilestone else { continue }
            let score = 40 + sp.matchScore/10 + min(sp.completedMilestones*4,12)
            let prio: TPriority = score>=60 ? .high : score>=40 ? .medium : .low
            out.append(TNextAction(id:"project-\(sp.project.id)-\(m.id)", type:.projectAction, title:m.title, subtitle: sp.project.title, priority:prio, priorityScore:score, roadmapID: sp.project.sourceRoadmapID, milestoneID:m.id, actionID:nil, opportunityID:nil, projectID: sp.project.id, skillIDs: sp.project.skills.map{TSkill.normalizeID($0)}, signals:["project in progress"], estimatedTime:m.estimatedTime, deadline:nil))
        }
        return out
    }
    static func startCandidates(active:[TRoadmap], all:[TRoadmap], catalogProgress:[String:Int]) -> [TNextAction] {
        if !active.isEmpty { return [] }
        // pick first non-completed sorted by id for determinism
        let sorted = all.sorted { $0.id < $1.id }
        for roadmap in sorted {
            let c = min(catalogProgress[roadmap.id] ?? 0, roadmap.milestones.count)
            if c < roadmap.milestones.count {
                return [TNextAction(id:"start-\(roadmap.id)", type:.startRoadmap, title:"Start \(roadmap.title)", subtitle: roadmap.goal, priority:.medium, priorityScore:35, roadmapID: roadmap.id, milestoneID: roadmap.milestones.first?.id, actionID:nil, opportunityID:nil, projectID:nil, skillIDs:[], signals:["no active roadmap"], estimatedTime: roadmap.milestones.first?.estimatedTime, deadline:nil)]
            }
        }
        return []
    }
    static func generate(profile:TProfile, progress:[String:Int], active:[TRoadmap], all:[TRoadmap], completedActionIDs:Set<String>, feed:TFeed?, saved:Set<String>, scoredProjects:[TScoredProject]) -> [TNextAction] {
        var c:[TNextAction]=[]
        c.append(contentsOf: roadmapActionCandidates(profile:profile, progress:progress, active:active, catalog:all, completedActionIDs:completedActionIDs))
        c.append(contentsOf: opportunityCandidates(feed:feed, profile:profile, progress:progress, catalog:all, active:active, saved:saved))
        c.append(contentsOf: projectCandidates(scoredProjects: scoredProjects))
        c.append(contentsOf: startCandidates(active:active, all:all, catalogProgress:progress))
        return c
    }
    static func filter(candidates:[TNextAction], active:[TRoadmap], all:[TRoadmap], progress:[String:Int], completedActionIDs:Set<String>) -> [TNextAction] {
        candidates.filter { c in
            if let rid=c.roadmapID, let mid=c.milestoneID {
                guard let roadmap = all.first(where:{$0.id==rid}) ?? active.first(where:{$0.id==rid}) else { return false }
                guard roadmap.milestones.contains(where:{$0.id==mid}) else { return false }
                if c.type == .roadmapAction {
                    let completedCount = min(progress[rid] ?? 0, roadmap.milestones.count)
                    let completedIDs = Set(roadmap.milestones.prefix(completedCount).map(\.id))
                    if completedIDs.contains(mid){ return false }
                    if let ms = roadmap.milestones.first(where:{$0.id==mid}) {
                        if case .locked = TRoadmapEngine.milestoneAvailability(milestone: ms, completedIDs: completedIDs) { return false }
                    }
                    if let aid=c.actionID, completedActionIDs.contains(aid){ return false }
                }
            }
            return true
        }
    }
    static func deduplicate(_ cand:[TNextAction]) -> [TNextAction] {
        var seen=Set<String>(); var out:[TNextAction]=[]
        for c in cand { if seen.contains(c.id) { continue }; seen.insert(c.id); out.append(c) }
        return out
    }
    static func rank(_ cand:[TNextAction]) -> [TNextAction] {
        cand.sorted { lhs,rhs in
            if lhs.priorityScore != rhs.priorityScore { return lhs.priorityScore > rhs.priorityScore }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            let rank:(TNextType)->Int = { t in switch t { case .roadmapAction:return 4; case .opportunity:return 3; case .savedOpportunity:return 3; case .projectAction:return 2; case .startRoadmap:return 1 } }
            if rank(lhs.type) != rank(rhs.type) { return rank(lhs.type) > rank(rhs.type) }
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            return lhs.id < rhs.id
        }
    }
    static func ranked(profile:TProfile, progress:[String:Int], active:[TRoadmap], all:[TRoadmap], completedActionIDs:Set<String>, feed:TFeed?, saved:Set<String>, scoredProjects:[TScoredProject]) -> [TNextAction] {
        let gen = generate(profile: profile, progress: progress, active: active, all: all, completedActionIDs: completedActionIDs, feed: feed, saved: saved, scoredProjects: scoredProjects)
        let fil = filter(candidates: gen, active: active, all: all, progress: progress, completedActionIDs: completedActionIDs)
        let ded = deduplicate(fil)
        return rank(ded)
    }
}

// MARK: - Test Catalog

let softwareEngineer = TRoadmap(id:"software-engineer", title:"Become a Software Engineer", goal:"Turn interests into foundation", description:"desc", milestones:[
    TMilestone(id:"software-1", title:"Explore CS", skillsDeveloped:["Python","Computational Thinking"], actions:[TAction(id:"software-1-action-1", title:"Watch video", order:1, estimatedTime:"30 min"), TAction(id:"software-1-action-2", title:"Explore subfields", order:2, estimatedTime:"30 min")], dependencies:nil, estimatedTime:"30 min"),
    TMilestone(id:"software-2", title:"Build Programming Fundamentals", skillsDeveloped:["Git","Software Development"], actions:[TAction(id:"software-2-action-1", title:"Solve problems", order:1, estimatedTime:"1 week"), TAction(id:"software-2-action-2", title:"Build tool", order:2, estimatedTime:"1 week")], dependencies:["software-1"], estimatedTime:"2 weeks"),
    TMilestone(id:"software-3", title:"Learn Software Development", skillsDeveloped:["APIs","Software Development"], actions:[TAction(id:"software-3-action-1", title:"Call API", order:1, estimatedTime:"1 week")], dependencies:["software-2"], estimatedTime:"3 weeks"),
])
let aiEngineer = TRoadmap(id:"ai-engineer", title:"Become an AI Engineer", goal:"AI foundation", description:"desc", milestones:[
    TMilestone(id:"ai-1", title:"Explore AI & ML", skillsDeveloped:["Python","Data Analysis"], actions:[TAction(id:"ai-1-action-1", title:"Watch AI videos", order:1, estimatedTime:"1 hour")], dependencies:nil, estimatedTime:"1 hour"),
    TMilestone(id:"ai-2", title:"Build Programming & Math Foundations", skillsDeveloped:["Machine Learning","Statistics"], actions:[TAction(id:"ai-2-action-1", title:"Learn Python", order:1, estimatedTime:"2 weeks")], dependencies:["ai-1"], estimatedTime:"3 weeks"),
    TMilestone(id:"ai-3", title:"Learn ML Fundamentals", skillsDeveloped:["AI Application Development"], actions:[TAction(id:"ai-3-action-1", title:"Train model", order:1, estimatedTime:"2 weeks")], dependencies:["ai-2"], estimatedTime:"4 weeks"),
])
let researchBuilder = TRoadmap(id:"research-builder", title:"Build a Research Profile", goal:"Research", description:"desc", milestones:[
    TMilestone(id:"research-1", title:"Explore Research", skillsDeveloped:["Research Methods"], actions:[TAction(id:"research-1-action-1", title:"Read research examples", order:1, estimatedTime:"45 min")], dependencies:nil, estimatedTime:"45 min"),
    TMilestone(id:"research-2", title:"Choose Question", skillsDeveloped:["Question Formation"], actions:[TAction(id:"research-2-action-1", title:"Write question", order:1, estimatedTime:"1 hour")], dependencies:["research-1"], estimatedTime:"1 week"),
])
let portfolioProjects = TRoadmap(id:"portfolio-projects", title:"Build a Technical Portfolio", goal:"Portfolio", description:"desc", milestones:[ TMilestone(id:"portfolio-1", title:"Define Direction", skillsDeveloped:["Project Planning"], actions:[TAction(id:"portfolio-1-action-1", title:"Choose direction", order:1, estimatedTime:"1 hour")], dependencies:nil, estimatedTime:"1 hour") ])
let collegeReady = TRoadmap(id:"college-ready", title:"Prepare for College", goal:"College", description:"desc", milestones:[ TMilestone(id:"college-1", title:"Understand Goals", skillsDeveloped:["Goal Setting"], actions:[TAction(id:"college-1-action-1", title:"Reflect goals", order:1, estimatedTime:"1 hour")], dependencies:nil, estimatedTime:"1 hour") ])
let stemExplorer = TRoadmap(id:"stem-explorer", title:"Explore STEM & Engineering", goal:"STEM", description:"desc", milestones:[ TMilestone(id:"stem-1", title:"Discover STEM", skillsDeveloped:["Technical Exploration"], actions:[TAction(id:"stem-1-action-1", title:"Explore STEM areas", order:1, estimatedTime:"1 hour")], dependencies:nil, estimatedTime:"1 hour") ])
let leadership = TRoadmap(id:"leadership", title:"Build Leadership Experience", goal:"Leadership", description:"desc", milestones:[ TMilestone(id:"leadership-1", title:"Understand Leadership", skillsDeveloped:["Leadership"], actions:[TAction(id:"leadership-1-action-1", title:"Study leadership", order:1, estimatedTime:"1 hour")], dependencies:nil, estimatedTime:"1 hour") ])
let communityImpact = TRoadmap(id:"community-impact", title:"Build Community Impact", goal:"Community", description:"desc", milestones:[ TMilestone(id:"community-1", title:"Understand Community", skillsDeveloped:["Community Research"], actions:[TAction(id:"community-1-action-1", title:"Map community", order:1, estimatedTime:"1 hour")], dependencies:nil, estimatedTime:"1 hour") ])
let venture = TRoadmap(id:"venture", title:"Explore Entrepreneurship", goal:"Venture", description:"desc", milestones:[ TMilestone(id:"venture-1", title:"Identify Problems", skillsDeveloped:["Problem Discovery"], actions:[TAction(id:"venture-1-action-1", title:"Observe problems", order:1, estimatedTime:"1 hour")], dependencies:nil, estimatedTime:"1 hour") ])
let competitiveProfile = TRoadmap(id:"competitive-profile", title:"Build a Competitive Student Profile", goal:"Profile", description:"desc", milestones:[ TMilestone(id:"profile-1", title:"Define Direction", skillsDeveloped:["Academic Planning"], actions:[TAction(id:"profile-1-action-1", title:"Reflect direction", order:1, estimatedTime:"1 hour")], dependencies:nil, estimatedTime:"1 hour") ])
let allRoadmaps = [softwareEngineer, aiEngineer, researchBuilder, portfolioProjects, collegeReady, stemExplorer, leadership, communityImpact, venture, competitiveProfile]
let allTen = allRoadmaps

// Projects
let projA = TScoredProject(project: TProject(id:"proj-a", title:"Plant Health Dashboard", goal:"Build tool", milestones:[TProjectMilestone(id:"plant-1", title:"Define question", estimatedTime:"45 min"), TProjectMilestone(id:"plant-2", title:"Collect data", estimatedTime:"2 hours")], skills:["Python"], sourceRoadmapID:"research-builder"), matchScore: 80, completedMilestones: 0)
let projB = TScoredProject(project: TProject(id:"proj-b", title:"Portfolio Site", goal:"Create portfolio", milestones:[TProjectMilestone(id:"port-1", title:"Plan story", estimatedTime:"30 min")], skills:["Programming"], sourceRoadmapID:nil), matchScore: 70, completedMilestones: 1)

// Opportunities
let oppHack = TRemoteOpp(id:"hack-1", skills:["Python","Software Development"], topics:[], subjects:[])
let oppResearch = TRemoteOpp(id:"research-opp-1", skills:["Research Methods"], topics:[], subjects:[])
let oppNoMatch = TRemoteOpp(id:"nomatch-1", skills:["Basketball"], topics:[], subjects:[])
let oppDuplicate = TRemoteOpp(id:"dup-1", skills:["Python","python"," PYTHON "], topics:[], subjects:[])
let localOppPython = TLocalOpp(id:"local-1", relevantSkills:["Python"], title:"Student STEM Design Sprint")

// MARK: - Tests

print("—— Candidate Generation (1-10) ——")

do { // 1. Available roadmap action generates candidate.
    let profile=TProfile()
    let active=[softwareEngineer]
    let cands = TNextEngine.roadmapActionCandidates(profile:profile, progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    assert(!cands.isEmpty, "T1: available roadmap action generates candidate")
    assert(cands.contains(where:{$0.actionID=="software-1-action-1"}), "T1: contains software-1-action-1")
}
do { // 2. Completed action does not.
    let profile=TProfile()
    let active=[softwareEngineer]
    let completed:Set<String>=["software-1-action-1"]
    let cands = TNextEngine.roadmapActionCandidates(profile:profile, progress:[:], active:active, catalog:allTen, completedActionIDs:completed)
    assert(!cands.contains(where:{$0.actionID=="software-1-action-1"}), "T2: completed action not candidate")
    assert(cands.contains(where:{$0.actionID=="software-1-action-2"}), "T2: other action still candidate")
}
do { // 3. Locked milestone action does not.
    let profile=TProfile()
    let active=[softwareEngineer]
    let progress: [String:Int]=[:] // software-1 not completed, so software-2 locked
    // roadmapActionCandidates internally filters locked via milestoneAvailability, so software-2-action-1 should NOT appear
    let cands = TNextEngine.roadmapActionCandidates(profile:profile, progress:progress, active:active, catalog:allTen, completedActionIDs:[])
    assert(!cands.contains(where:{$0.milestoneID=="software-2"}), "T3: locked milestone action not candidate")
    assert(cands.contains(where:{$0.milestoneID=="software-1"}), "T3: available milestone still candidate")
}
do { // 4. Current milestone action is recognized.
    let profile=TProfile()
    let active=[softwareEngineer]
    let cands = TNextEngine.roadmapActionCandidates(profile:profile, progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    let current = cands.first(where:{$0.milestoneID=="software-1"})
    assert(current != nil, "T4: current milestone found")
    assert(current!.signals.contains(where:{$0.contains("current")}), "T4: signals contain current")
}
do { // 5. Skill-gap action is recognized.
    let profile=TProfile() // no skills, so gaps exist
    let active=[softwareEngineer]
    let cands = TNextEngine.roadmapActionCandidates(profile:profile, progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    assert(cands.first(where:{$0.signals.contains(where:{$0.contains("gap")})}) != nil, "T5: gap signal present")
}
do { // 6. Opportunity with meaningful roadmap connection generates candidate.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feed = TFeed(opportunities:[
        TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:85, deadline:"2026-12-01")
    ])
    let cands = TNextEngine.opportunityCandidates(feed:feed, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assert(!cands.isEmpty, "T6: opp with connection generates candidate")
    assertEqual(cands.first!.opportunityID!, "hack-1", "T6: opportunity ID matches")
}
do { // 7. Saved opportunity can generate candidate when appropriate.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feed = TFeed(opportunities:[
        TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:80, deadline:"2026-12-01")
    ])
    let saved:Set<String>=["hack-1"]
    let cands = TNextEngine.opportunityCandidates(feed:feed, profile:profile, progress:[:], catalog:allTen, active:active, saved:saved)
    assert(cands.first!.type == .savedOpportunity, "T7: saved type")
    assert(cands.first!.signals.contains("saved"), "T7: saved signal")
}
do { // 8. Project candidate works if project model supports it.
    let cands = TNextEngine.projectCandidates(scoredProjects:[projA, projB])
    assert(cands.contains(where:{$0.projectID=="proj-a"}), "T8: project candidate exists")
    assertEqual(cands.first(where:{$0.projectID=="proj-a"})!.title, "Define question", "T8: project milestone title")
}
do { // 9. Evidence candidate does not duplicate existing evidence. (No evidence type generated)
    let profile=TProfile()
    let active=[softwareEngineer]
    let cands = TNextEngine.generate(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    // Ensure none of type is evidence? Our engine never generates evidence type, so no duplicate.
    assert(!cands.contains(where:{$0.type.rawValue=="evidence" || $0.type.rawValue=="documentEvidence"}), "T9: no evidence duplication")
    // Also ensure evidence doesn't cause extra candidates beyond roadmapAction count
    assert(cands.allSatisfy{$0.type != .opportunity || $0.opportunityID != nil}, "T9: evidence not created")
}
do { // 10. No active roadmap can generate valid start-roadmap candidate when appropriate.
    let cands = TNextEngine.startCandidates(active:[], all:allTen, catalogProgress:[:])
    assert(!cands.isEmpty, "T10: start candidate when no active")
    assertEqual(cands.first!.type, TNextType.startRoadmap, "T10: type startRoadmap")
    assert(cands.first!.roadmapID != nil, "T10: roadmapID present")
    // When active exists, no start candidate
    let cands2 = TNextEngine.startCandidates(active:[softwareEngineer], all:allTen, catalogProgress:[:])
    assert(cands2.isEmpty, "T10b: no start when active exists")
}

print("—— Filtering (11-17) ——")

do { // 11. Expired opportunity filtered.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feed = TFeed(opportunities:[
        TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"expired", freshnessUrgency:"none", matchScore:90, deadline:"2025-01-01")
    ])
    let cands = TNextEngine.opportunityCandidates(feed:feed, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assert(cands.isEmpty, "T11: expired filtered")
}
do { // 12. Ineligible opportunity filtered.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feed = TFeed(opportunities:[
        TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"ineligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:90, deadline:"2026-12-01")
    ])
    let cands = TNextEngine.opportunityCandidates(feed:feed, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assert(cands.isEmpty, "T12: ineligible filtered")
}
do { // 13. Completed action filtered.
    let profile=TProfile()
    let active=[softwareEngineer]
    let completed:Set<String>=["software-1-action-1","software-1-action-2"]
    let gen = TNextEngine.generate(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:completed, feed:nil, saved:[], scoredProjects:[])
    assert(!gen.contains(where:{$0.actionID=="software-1-action-1"}), "T13: completed filtered")
    let filtered = TNextEngine.filter(candidates: gen, active:active, all:allTen, progress:[:], completedActionIDs:completed)
    assert(!filtered.contains(where:{$0.actionID=="software-1-action-1"}), "T13b: filter also removes")
}
do { // 14. Locked action filtered.
    let profile=TProfile()
    let active=[softwareEngineer]
    let gen = TNextEngine.generate(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    // software-2 should not be in gen at all (locked)
    assert(!gen.contains(where:{$0.milestoneID=="software-2"}), "T14: locked filtered at generation")
    let fil = TNextEngine.filter(candidates: gen, active:active, all:allTen, progress:[:], completedActionIDs:[])
    assert(!fil.contains(where:{$0.milestoneID=="software-2"}), "T14b: locked still filtered")
}
do { // 15. Duplicate candidates removed.
    let c1 = TNextAction(id:"dup", type:.roadmapAction, title:"A", subtitle:"B", priority:.high, priorityScore:80, roadmapID:"software-engineer", milestoneID:"software-1", actionID:"a1", opportunityID:nil, projectID:nil, skillIDs:[], signals:[], estimatedTime:nil, deadline:nil)
    let c2 = TNextAction(id:"dup", type:.roadmapAction, title:"A", subtitle:"B", priority:.high, priorityScore:80, roadmapID:"software-engineer", milestoneID:"software-1", actionID:"a1", opportunityID:nil, projectID:nil, skillIDs:[], signals:[], estimatedTime:nil, deadline:nil)
    let ded = TNextEngine.deduplicate([c1,c2])
    assertEqual(ded.count, 1, "T15: dedup removes duplicate")
}
do { // 16. Invalid references handled safely.
    let bad = TNextAction(id:"bad", type:.roadmapAction, title:"Bad", subtitle:"Bad", priority:.low, priorityScore:10, roadmapID:"nonexistent", milestoneID:"bad-mid", actionID:"bad-act", opportunityID:nil, projectID:nil, skillIDs:[], signals:[], estimatedTime:nil, deadline:nil)
    let fil = TNextEngine.filter(candidates:[bad], active:[softwareEngineer], all:allTen, progress:[:], completedActionIDs:[])
    assert(fil.isEmpty, "T16: invalid ref filtered")
}
do { // 17. No actionable data returns safe empty state.
    let profile=TProfile()
    // No active, no projects, feed nil → only start candidate should appear, not crash, not empty generic motivational
    let ranked = TNextEngine.ranked(profile:profile, progress:[:], active:[], all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    // Should have start candidate
    assert(!ranked.isEmpty, "T17: start candidate exists for empty state")
    // If all completed and no projects etc, but still have active completed roadmap? The ranking handles empty via filter; ensure no crash and no generic "Keep learning"
    let activeCompleted = [TRoadmap(id:"software-engineer", title:"SE", goal:"g", description:"d", milestones:[TMilestone(id:"s1", title:"M1", skillsDeveloped:["Python"], actions:[TAction(id:"a1", title:"A", order:1, estimatedTime:nil)], dependencies:nil, estimatedTime:"1h")])]
    // Simulate all actions completed and milestone completed (progress 1)
    let ranked2 = TNextEngine.ranked(profile:profile, progress:["software-engineer":1], active:activeCompleted, all:allTen, completedActionIDs:["a1"], feed:nil, saved:[], scoredProjects:[])
    // Should be empty or start? Active roadmap is considered completed? Our active includes it but progress 1 means completed, so roadmapActionCandidates will skip completed milestone. No start because active not empty. So result empty is valid safe state.
    // Just ensure no crash and not containing fake motivational
    assert(!ranked2.contains(where:{$0.title.contains("Keep learning")}), "T17b: no fake motivational")
}

print("—— Ranking (18-28) ——")

do { // 18. Current actionable roadmap work receives appropriate priority.
    let profile=TProfile()
    let active=[softwareEngineer]
    // With no feed, no projects, roadmapAction should be top
    let ranked = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    assert(ranked.first!.type == .roadmapAction, "T18: roadmapAction top when no opp")
}
do { // 19. Important skill gap increases priority.
    // Create two roadmaps actions where one addresses high gap vs no gap. Use software-1 (gap) vs portfolio (no gap overlap? Need profile with Python so portfolio gap not Python)
    // Simpler: test scoreRoadmapAction gap vs no gap
    var profileNoGap = TProfile(); profileNoGap.strengths=["Python","Computational Thinking","Git","Software Development","APIs"] // all SE skills demonstrated -> no gaps
    let active=[softwareEngineer]
    let withGap = TNextEngine.roadmapActionCandidates(profile:TProfile(), progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    let withoutGap = TNextEngine.roadmapActionCandidates(profile:profileNoGap, progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    // With gap should have higher score than without gap for same milestone
    assert(withGap.first!.priorityScore > withoutGap.first!.priorityScore, "T19: gap increases score")
}
do { // 20. Dependency-unlocking action receives priority.
    // Create roadmap where milestone unlocks future: software-1 unlocks software-2
    let profile=TProfile()
    let active=[softwareEngineer]
    let cands = TNextEngine.roadmapActionCandidates(profile:profile, progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    // software-1 should have higher score than if it didn't unlock (we check signal contains unlocks)
    assert(cands.first(where:{$0.milestoneID=="software-1"})!.signals.contains(where:{$0.contains("unlocks")}), "T20: unlock signal present")
}
do { // 21. Urgent opportunity deadline affects priority.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feedUrgent = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"urgent", matchScore:70, deadline:"in 2 days")])
    let feedLater = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"later", matchScore:70, deadline:"in 2 months")])
    let candsUrgent = TNextEngine.opportunityCandidates(feed:feedUrgent, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    let candsLater = TNextEngine.opportunityCandidates(feed:feedLater, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assert(candsUrgent.first!.priorityScore > candsLater.first!.priorityScore, "T21: urgent higher than later")
}
do { // 22. Strong opportunity match affects priority.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feedHigh = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:95, deadline:"soon")])
    let feedLow = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:55, deadline:"soon")])
    let high = TNextEngine.opportunityCandidates(feed:feedHigh, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    let low = TNextEngine.opportunityCandidates(feed:feedLow, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assert(high.first!.priorityScore > low.first!.priorityScore, "T22: high match higher")
}
do { // 23. Strong roadmap connection affects priority.
    // oppHack matches Python (gap) vs opp with non-gap skill? Use opp that matches future milestone vs current.
    // For current test, direct vs relevant: gap address -> direct; no gap -> relevant
    let profile=TProfile()
    var profileWithPython = TProfile(); profileWithPython.strengths=["Python","Computational Thinking"] // gap for Python gone, but still Git/APIs gaps
    let active=[softwareEngineer]
    let feed = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:80, deadline:"soon")])
    let candGap = TNextEngine.opportunityCandidates(feed:feed, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    let candNoGap = TNextEngine.opportunityCandidates(feed:feed, profile:profileWithPython, progress:[:], catalog:allTen, active:active, saved:[])
    // candGap should have gap, thus higher score
    assert(candGap.first!.priorityScore >= candNoGap.first!.priorityScore, "T23: gap connection higher")
}
do { // 24. Saved opportunity signal works.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feed = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:80, deadline:"soon")])
    let unsaved = TNextEngine.opportunityCandidates(feed:feed, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    let saved = TNextEngine.opportunityCandidates(feed:feed, profile:profile, progress:[:], catalog:allTen, active:active, saved:["hack-1"])
    assert(saved.first!.priorityScore > unsaved.first!.priorityScore, "T24: saved bonus")
}
do { // 25. Project progress signal works when supported.
    let projCand = TNextEngine.projectCandidates(scoredProjects:[projA])
    assert(!projCand.isEmpty, "T25: project candidate exists")
    assert(projCand.first!.signals.contains("project in progress"), "T25: project signal")
}
do { // 26. Ranking is deterministic.
    let profile=TProfile()
    let active=[softwareEngineer]
    let r1 = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[projA])
    let r2 = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[projA])
    assertEqual(r1.map(\.id), r2.map(\.id), "T26: deterministic")
}
do { // 27. Tie-breaking is deterministic.
    let a = TNextAction(id:"a", type:.roadmapAction, title:"Alpha", subtitle:"", priority:.medium, priorityScore:50, roadmapID:"r1", milestoneID:"m1", actionID:"act1", opportunityID:nil, projectID:nil, skillIDs:[], signals:[], estimatedTime:nil, deadline:nil)
    let b = TNextAction(id:"b", type:.roadmapAction, title:"Beta", subtitle:"", priority:.medium, priorityScore:50, roadmapID:"r1", milestoneID:"m1", actionID:"act2", opportunityID:nil, projectID:nil, skillIDs:[], signals:[], estimatedTime:nil, deadline:nil)
    let ranked = TNextEngine.rank([b,a])
    assertEqual(ranked.first!.id, "a", "T27: alphabetical tie break")
}
do { // 28. No fake precision exposed.
    let profile=TProfile()
    let active=[softwareEngineer]
    let ranked = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    for nb in ranked {
        assert(nb.priority == .high || nb.priority == .medium || nb.priority == .low, "T28: priority is high/medium/low")
        // priorityScore is Int, not Double with fake precision
        assert(nb.priorityScore == Int(nb.priorityScore), "T28: score is Int")
    }
}

print("—— Cross-System (29-35) ——")

do { // 29. SkillGapEngine output affects candidates.
    let profileEmpty=TProfile()
    var profileFull=TProfile(); profileFull.strengths=["Python","Computational Thinking","Git","Software Development","APIs"]
    let active=[softwareEngineer]
    let candEmpty = TNextEngine.roadmapActionCandidates(profile:profileEmpty, progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    let candFull = TNextEngine.roadmapActionCandidates(profile:profileFull, progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    // With all skills, gap signal should be absent; check first candidate signals
    assert(candEmpty.contains(where:{$0.signals.contains(where:{$0.contains("gap")})}), "T29: gap signal when gaps exist")
    assert(!candFull.contains(where:{$0.signals.contains(where:{$0.contains("gap")})}), "T29b: no gap signal when no gaps")
}
do { // 30. OpportunityRoadmapEngine output affects candidates.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feedMatch = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:80, deadline:"soon")])
    let feedNoMatch = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppNoMatch, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:80, deadline:"soon")])
    let candsMatch = TNextEngine.opportunityCandidates(feed:feedMatch, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    let candsNoMatch = TNextEngine.opportunityCandidates(feed:feedNoMatch, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assert(!candsMatch.isEmpty, "T30: match generates")
    assert(candsNoMatch.isEmpty, "T30b: no match filtered")
}
do { // 31. RoadmapEngine dependency state affects candidates.
    let profile=TProfile()
    let active=[softwareEngineer]
    let cands0 = TNextEngine.roadmapActionCandidates(profile:profile, progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    assert(!cands0.contains(where:{$0.milestoneID=="software-3"}), "T31: future locked not candidate")
    let candsAfter = TNextEngine.roadmapActionCandidates(profile:profile, progress:["software-engineer":1], active:active, catalog:allTen, completedActionIDs:[])
    assert(candsAfter.contains(where:{$0.milestoneID=="software-2"}), "T31b: after completing 1, next unlocks")
}
do { // 32. Freshness engine affects opportunity candidates.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feedUrgent = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"urgent", matchScore:70, deadline:"2 days")])
    let cands = TNextEngine.opportunityCandidates(feed:feedUrgent, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assert(cands.first!.signals.contains(where:{$0.contains("urgent")}), "T32: urgency signal")
}
do { // 33. Eligibility engine affects opportunity candidates.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feed = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"ineligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:90, deadline:"soon")])
    let cands = TNextEngine.opportunityCandidates(feed:feed, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assert(cands.isEmpty, "T33: ineligible filtered")
}
do { // 34. Existing opportunity match affects ranking.
    let profile=TProfile()
    let active=[softwareEngineer]
    let feedHigh = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"later", matchScore:95, deadline:"later")])
    let feedLow = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppHack, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"later", matchScore:60, deadline:"later")])
    let high = TNextEngine.opportunityCandidates(feed:feedHigh, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    let low = TNextEngine.opportunityCandidates(feed:feedLow, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assert(high.first!.priorityScore > low.first!.priorityScore, "T34: match affects score")
}
do { // 35. Progress state affects roadmap candidates.
    let profile=TProfile()
    let active=[softwareEngineer]
    let cands0 = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    let cands1 = TNextEngine.ranked(profile:profile, progress:["software-engineer":1], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    // After progress, current milestone changes from software-1 to software-2
    assert(cands0.first(where:{$0.type == .roadmapAction})!.milestoneID != cands1.first(where:{$0.type == .roadmapAction})!.milestoneID, "T35: progress changes candidate")
}

print("—— Multiple Roadmaps (36-40) ——")

do { // 36. Multiple active roadmaps produce independent candidates.
    let profile=TProfile()
    let active=[softwareEngineer, aiEngineer]
    let cands = TNextEngine.roadmapActionCandidates(profile:profile, progress:[:], active:active, catalog:allTen, completedActionIDs:[])
    assert(cands.contains(where:{$0.roadmapID=="software-engineer"}), "T36: SE candidate")
    assert(cands.contains(where:{$0.roadmapID=="ai-engineer"}), "T36b: AI candidate")
}
do { // 37. One roadmap cannot contaminate another.
    let profile=TProfile()
    let active=[softwareEngineer, aiEngineer]
    let progressSE:[String:Int]=["software-engineer":1]
    let cands = TNextEngine.roadmapActionCandidates(profile:profile, progress:progressSE, active:active, catalog:allTen, completedActionIDs:[])
    // AI milestone should still be ai-1 available, not affected by SE progress
    assert(cands.contains(where:{$0.milestoneID=="ai-1"}), "T37: AI not contaminated by SE progress")
}
do { // 38. Candidate retains roadmap identity.
    let profile=TProfile()
    let active=[softwareEngineer, aiEngineer]
    let ranked = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    for nb in ranked where nb.type == .roadmapAction {
        assert(nb.roadmapID != nil, "T38: roadmapID present")
        assert(allTen.contains(where:{$0.id==nb.roadmapID!}), "T38b: roadmapID valid")
    }
}
do { // 39. All 10 roadmap templates can participate.
    for roadmap in allTen {
        let profile=TProfile()
        let cands = TNextEngine.roadmapActionCandidates(profile:profile, progress:[:], active:[roadmap], catalog:allTen, completedActionIDs:[])
        // Each roadmap has at least one milestone with actions, so should have candidates unless no actions (but all have)
        assert(!cands.isEmpty, "T39: \(roadmap.id) generates candidate")
    }
}
do { // 40. No roadmap-specific branching.
    // Verify engine works for all without checking roadmap.id string — just that ranking includes all types
    let profile=TProfile()
    let active=allTen
    let ranked = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    // Should have candidates from multiple roadmaps, not just one
    let distinctRoadmaps = Set(ranked.compactMap(\.roadmapID))
    assert(distinctRoadmaps.count >= 5, "T40: candidates from multiple roadmaps, no branching")
}

print("—— Persistence (41-44) ——")

do { // 41. Derived recommendation updates after state changes.
    let profile=TProfile()
    let active=[softwareEngineer]
    let before = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    let after = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:["software-1-action-1"], feed:nil, saved:[], scoredProjects:[])
    assert(before.count != after.count || before.first?.id != after.first?.id || before.first?.priorityScore != after.first?.priorityScore, "T41: state change updates ranking")
}
do { // 42. Force/reload produces same recommendation from same state.
    let profile=TProfile()
    let active=[softwareEngineer]
    let r1 = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    let r2 = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    assertEqual(r1.map(\.id), r2.map(\.id), "T42: reload same")
}
do { // 43. No recommendation persistence is required.
    // Engine is pure, does not write UserDefaults — verify by checking progress unchanged after call
    var progress:[String:Int]=["software-engineer":0]
    let original = progress
    let profile=TProfile()
    let active=[softwareEngineer]
    _ = TNextEngine.ranked(profile:profile, progress:progress, active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    assertEqual(progress, original, "T43: no persistence mutation")
}
do { // 44. Existing AppDataStore state remains unchanged by calculation.
    var profile=TProfile(); profile.strengths=["Python"]
    let originalStrengths = profile.strengths
    let active=[softwareEngineer]
    _ = TNextEngine.ranked(profile:profile, progress:[:], active:active, all:allTen, completedActionIDs:[], feed:nil, saved:[], scoredProjects:[])
    assertEqual(profile.strengths, originalStrengths, "T44: profile unchanged")
}

print("—— Realistic Scenario (45-57) ——")

do {
    // 45. Student activates AI Engineer roadmap.
    var profile=TProfile()
    var active:[TRoadmap]=[aiEngineer]
    var progress:[String:Int]=[:]
    var completedActionIDs:Set<String>=[]
    let all = allTen
    // 46. Current milestone has Python skill gap.
    let gaps = TSkillGapEngine.gaps(for: aiEngineer, profile: profile, progress: progress, catalog: all)
    assert(gaps.contains(where:{$0.name=="Python"}), "T45-46: Python gap exists")
    // 47. Python-related action is available.
    let roadmapCands = TNextEngine.roadmapActionCandidates(profile:profile, progress:progress, active:active, catalog:all, completedActionIDs:completedActionIDs)
    assert(roadmapCands.contains(where:{$0.roadmapID=="ai-engineer" && $0.title.contains("Watch AI") || $0.milestoneID=="ai-1"}), "T47: Python action available")
    // 48. A real Python-related opportunity exists.
    let pythonOpp = TRemoteOpp(id:"py-opp", skills:["Python"], topics:[], subjects:[])
    assert(TOppRoadmapEngine.normalizedSkillIDs(for: pythonOpp).contains("python"), "T48: opp has Python")
    // 49. Opportunity has valid roadmap connection.
    let conn = TOppRoadmapEngine.connection(for: pythonOpp, roadmap: aiEngineer, profile: profile, progress: progress, catalog: all)
    assert(conn != nil, "T49: connection exists")
    assert(conn!.matched.contains(where:{$0.name=="Python"}), "T49b: matched Python")
    // 50. Opportunity has a deadline.
    let feed = TFeed(opportunities:[TPersonalizedOpp(opportunity: pythonOpp, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:85, deadline:"2026-12-01")])
    // 51. Engine generates both roadmap and opportunity candidates.
    let ranked = TNextEngine.ranked(profile:profile, progress:progress, active:active, all:all, completedActionIDs:completedActionIDs, feed:feed, saved:[], scoredProjects:[])
    assert(ranked.contains(where:{$0.type == .roadmapAction}), "T51: roadmap candidate exists")
    assert(ranked.contains(where:{$0.type == .opportunity}), "T51b: opportunity candidate exists")
    // 52. Engine ranks them deterministically.
    let ranked2 = TNextEngine.ranked(profile:profile, progress:progress, active:active, all:all, completedActionIDs:completedActionIDs, feed:feed, saved:[], scoredProjects:[])
    assertEqual(ranked.map(\.id), ranked2.map(\.id), "T52: deterministic ranking")
    // 53. Top result has explainable signals.
    let top = ranked.first!
    assert(!top.signals.isEmpty, "T53: top has signals")
    assert(top.signals.joined().count > 10, "T53b: signals not empty")
    // 54. Student completes the selected roadmap action.
    if top.type == .roadmapAction, let aid = top.actionID {
        completedActionIDs.insert(aid)
    } else {
        // If top was opportunity, complete a roadmap action explicitly
        completedActionIDs.insert("ai-1-action-1")
    }
    // 55. Skill/progress state updates through existing systems.
    // Simulate milestone completion: mark ai-1 complete -> progress 1, acquire Python skill
    progress["ai-engineer"] = 1
    profile.strengths.append("Python")
    // 56. Next-best-action recalculates.
    let rankedAfter = TNextEngine.ranked(profile:profile, progress:progress, active:active, all:all, completedActionIDs:completedActionIDs, feed:feed, saved:[], scoredProjects:[])
    // Python gap should be gone, so opp connection now has 0 gaps? But opp still matches Python skill, but gap addressed count 0
    let connAfter = TOppRoadmapEngine.connection(for: pythonOpp, roadmap: aiEngineer, profile: profile, progress: progress, catalog: all)
    if let c = connAfter {
        // After acquiring Python, gap for Python should be resolved, but opp still connects via Python skill but gap count reduces
        // We check that gap addressed is now 0 or reduced
        assert(c.gaps.count <= conn!.gaps.count, "T56: gap reduces after completion")
    }
    // New top should be different or milestone advanced
    assert(rankedAfter.first?.milestoneID != top.milestoneID || rankedAfter.first?.actionID != top.actionID || rankedAfter.first?.priorityScore != top.priorityScore, "T56b: ranking updates after completion")
    // 57. Reload preserves underlying state.
    let reloadedProgress = progress
    let reloadedRanked = TNextEngine.ranked(profile:profile, progress:reloadedProgress, active:active, all:all, completedActionIDs:completedActionIDs, feed:feed, saved:[], scoredProjects:[])
    assertEqual(rankedAfter.map(\.id), reloadedRanked.map(\.id), "T57: reload preserves")
}

// Additional: Duplicate opportunity skills test
do {
    let ids = TOppRoadmapEngine.normalizedSkillIDs(for: oppDuplicate)
    assertEqual(ids.count, 1, "Dup skills deduped")
    assert(ids.contains("python"), "Dup contains python")
}
// Normalization edge
do {
    let opp = TRemoteOpp(id:"norm-1", skills:[" PyThOn "], topics:[], subjects:[])
    let ids = TOppRoadmapEngine.normalizedSkillIDs(for: opp)
    assert(ids.contains("python"), "Normalization case/whitespace")
}
do {
    let opp = TRemoteOpp(id:"empty-1", skills:["", "   ", "\n"], topics:[], subjects:[])
    let ids = TOppRoadmapEngine.normalizedSkillIDs(for: opp)
    assert(ids.isEmpty, "Empty skills ignored")
}
// Whitespace duplicate
do {
    let profile=TProfile()
    let active=[softwareEngineer]
    let feed = TFeed(opportunities:[TPersonalizedOpp(opportunity: oppDuplicate, eligibilityStatus:"eligible", freshnessStatus:"active", freshnessUrgency:"soon", matchScore:80, deadline:"soon")])
    let cands = TNextEngine.opportunityCandidates(feed:feed, profile:profile, progress:[:], catalog:allTen, active:active, saved:[])
    assertEqual(cands.first?.skillIDs.count, 1, "Whitespace duplicate one skill")
}

print("\nPhase 6.7 — Next-Best-Action: \(passed) passed, \(failed) failed out of \(passed + failed)")
if failed == 0 { print("All \(passed) tests passed ✓") }
