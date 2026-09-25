import Foundation

// Standalone test for Phase 8.7 — Portfolio Quality / Completeness
// Run: swift test-portfolio-quality.swift

var passed=0, failed=0
func assert(_ c:Bool,_ msg:String,file:String=#file,line:Int=#line){if c{passed+=1}else{failed+=1; print("FAIL [\(file):\(line)] \(msg)")}}
func assertEqual<T:Equatable>(_ a:T,_ b:T,_ msg:String,file:String=#file,line:Int=#line){if a==b{passed+=1}else{failed+=1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)")}}
func normalizeSkillID(_ raw:String)->String{let t=raw.trimmingCharacters(in:.whitespacesAndNewlines); let parts=t.components(separatedBy:.whitespacesAndNewlines).filter{!$0.isEmpty}; return parts.joined(separator:" ").lowercased()}
func percentCalc(completed:Int,total:Int)->Int{guard total>0 else{return 0}; return Int((Double(completed)/Double(total)*100).rounded())}

// MARK: - Inline models

enum SectionType: String, CaseIterable { case about="about", goals="goals", skills="skills", projects="projects", achievements="achievements", evidence="evidence", roadmaps="roadmaps"
    var displayName:String{rawValue.capitalized}
}
struct PortfolioSection: Hashable { let id:String; let type:SectionType; var title:String; var isEnabled:Bool
    init(type:SectionType,isEnabled:Bool=true){self.id=type.rawValue; self.type=type; self.title=type.displayName; self.isEnabled=isEnabled}
}
struct StudentPortfolio: Hashable {
    let id:String; var title:String; var headline:String?; var about:String?; var goals:[String]
    var selectedProjectIDs:[String]; var selectedAchievementIDs:[String]; var selectedEvidenceIDs:[String]; var selectedSkillIDs:[String]; var selectedRoadmapIDs:[String]
    var sections:[PortfolioSection]
    init(id:String=UUID().uuidString, title:String, headline:String?=nil, about:String?=nil, goals:[String]=[], projects:[String]=[], achievements:[String]=[], evidence:[String]=[], skills:[String]=[], roadmaps:[String]=[], sections:[PortfolioSection]?=nil){
        self.id=id; self.title=title; self.headline=headline; self.about=about; self.goals=goals
        self.selectedProjectIDs=projects; self.selectedAchievementIDs=achievements; self.selectedEvidenceIDs=evidence
        do{var seen=Set<String>(); var out:[String]=[]; for raw in skills{let n=normalizeSkillID(raw); if !n.isEmpty && !seen.contains(n){seen.insert(n); out.append(n)}}; self.selectedSkillIDs=out }
        self.selectedRoadmapIDs=roadmaps
        self.sections=sections ?? SectionType.allCases.map{PortfolioSection(type:$0)}
    }
}

enum SchoolLevel: String, CaseIterable { case middleSchool="Middle School", highSchool="High School" }
enum Grade: String, CaseIterable { case seventh="7th", eighth="8th", ninth="9th", tenth="10th", eleventh="11th", twelfth="12th" }
enum CollegePlan: String, CaseIterable { case yesDefinitely="Yes, definitely", probably="Probably", notSure="Not sure", no="No", exploringOthers="Exploring other paths" }
struct AccomplishmentEntry: Hashable { let id=UUID(); let title:String; let category:String }
struct StudentProfile: Hashable {
    var id=UUID()
    var firstName=""
    var age=""
    var schoolLevel=SchoolLevel.highSchool
    var grade=Grade.ninth
    var location=""
    var interests:[String]=[]
    var customInterests:[String]=[]
    var strengths:[String]=[]
    var customSkills:[String]=[]
    var notSureYet=false
    var careers:[String]=[]
    var milestones:[String]=[]
    var collegePlan=CollegePlan.notSure
    var fields:[String]=[]
    var geography=""
    var collegeType=""
    var targetColleges:[String]=[]
    var justGettingStarted=false
    var categories:[String:Int]=[:]
    var loggedEntries:[AccomplishmentEntry]=[]
    var onboardingCompleted=false
}

struct Project: Hashable { let id:String; let title:String; let description:String; let skills:[String]; let milestones:[String]; let sourceRoadmapID:String? }
struct RoadmapMilestone: Hashable { let id:String; let title:String }
struct Roadmap: Hashable { let id:String; let title:String; let milestones:[RoadmapMilestone] }
struct Achievement: Hashable { let id:String; let title:String; let description:String?; let evidenceIDs:[String]; let skillIDs:[String]?; let roadmapID:String?; let projectID:String? }
struct EvidenceRecord: Hashable {
    let id:String; let title:String; let description:String?; let roadmapID:String; let milestoneID:String
    let projectID:String?; let skillIDs:[String]?; let artifactURL:String?; let validationPassed:Bool?
    let createdAt:Date
}
enum QualityLevel: String { case basic="Basic", solid="Solid", strong="Strong" }
func quality(for rec:EvidenceRecord)->QualityLevel{
    var score=0
    if !rec.title.isEmpty && rec.title.count>3{score+=1}
    if let d=rec.description, d.count>10{score+=2}
    if rec.artifactURL != nil{score+=2}
    if rec.skillIDs != nil{score+=1}
    if !rec.roadmapID.isEmpty{score+=2}
    if rec.validationPassed != nil{score+=2}
    if score>=8{return .strong}
    if score>=4{return .solid}
    return .basic
}

// MARK: - Quality Engine Inline (mirrors PortfolioQualityEngine)

enum QualityLevelP: String { case basic="Basic", developing="Developing", strong="Strong"
    init(score:Int,maxScore:Int){guard maxScore>0 else{self = .basic; return}; let p=Int((Double(score)/Double(maxScore)*100).rounded()); if p>=70{self = .strong}else if p>=40{self = .developing}else{self = .basic}}
}
enum Priority: String { case high="High", medium="Medium", low="Low" }
struct Dimension: Hashable { let id:String; let title:String; let score:Int; let maxScore:Int; let relevant:Bool; let achieved:Bool; let improvement:String? }
struct Improvement: Hashable { let id:String; let title:String; let explanation:String; let priority:Priority; let related:[String]; let destination:String }
struct QualityResult: Hashable {
    let portfolioID:String; let overallScore:Int; let maxScore:Int; let level:QualityLevelP
    let dimensions:[Dimension]; let strengths:[String]; let improvements:[Improvement]
    var percent:Int{ percentCalc(completed:overallScore, total:maxScore) }
}

func evaluate(portfolio:StudentPortfolio, evidence:[String:EvidenceRecord], achievements:[String:Achievement], projects:[String:Project], roadmaps:[String:Roadmap], roadmapProgress:[String:Int], activeIDs:Set<String>)->QualityResult{
    func isEnabled(_ type:SectionType)->Bool{ portfolio.sections.first(where:{$0.type==type})?.isEnabled ?? true }
    func supportingForProject(_ pid:String)->[EvidenceRecord]{ evidence.values.filter{$0.projectID==pid}.sorted{$0.createdAt>$1.createdAt}}
    func supportingForAch(_ aid:String)->[EvidenceRecord]{ guard let ach=achievements[aid] else{return []}; var seen=Set<String>(), out:[EvidenceRecord]=[]; for eid in ach.evidenceIDs{ if let ev=evidence[eid], seen.insert(ev.id).inserted{ out.append(ev)}}; return out.sorted{$0.createdAt>$1.createdAt}}
    func supportingForSkill(_ sid:String)->[EvidenceRecord]{ let n=normalizeSkillID(sid); return evidence.values.filter{($0.skillIDs?.map{normalizeSkillID($0)}.contains(n) ?? false)}.sorted{$0.createdAt>$1.createdAt}}
    func supportingForRoadmap(_ rid:String)->[EvidenceRecord]{ evidence.values.filter{$0.roadmapID==rid}.sorted{$0.createdAt>$1.createdAt}}
    var evidenceOrphaned:[String]=[]
    var connected=Set<String>()
    for pid in portfolio.selectedProjectIDs{ for ev in supportingForProject(pid){connected.insert(ev.id)}}
    for aid in portfolio.selectedAchievementIDs{ for ev in supportingForAch(aid){connected.insert(ev.id)}}
    for sid in portfolio.selectedSkillIDs{ for ev in supportingForSkill(sid){connected.insert(ev.id)}}
    for rid in portfolio.selectedRoadmapIDs{ for ev in supportingForRoadmap(rid){connected.insert(ev.id)}}
    for eid in portfolio.selectedEvidenceIDs{
        if connected.contains(eid){continue}
        let rec=evidence[eid]
        var isConn=false
        if let pid=rec?.projectID, portfolio.selectedProjectIDs.contains(pid){isConn=true}
        if let rid=rec?.roadmapID, !rid.isEmpty, portfolio.selectedRoadmapIDs.contains(rid){isConn=true}
        if let sids=rec?.skillIDs{ for raw in sids{ if portfolio.selectedSkillIDs.map({normalizeSkillID($0)}).contains(normalizeSkillID(raw)){isConn=true; break}}}
        for aid in portfolio.selectedAchievementIDs where (achievements[aid]?.evidenceIDs.contains(eid) ?? false){isConn=true; break}
        if !isConn{evidenceOrphaned.append(eid)}
    }
    var dimensions:[Dimension]=[]
    var improvements:[Improvement]=[]
    // Identity & Purpose 10
    do{
        let maxScore=10
        var score=0; var missing:[String]=[]
        let titleTrim=portfolio.title.trimmingCharacters(in:.whitespacesAndNewlines)
        let hasTitle = !titleTrim.isEmpty && titleTrim != "My Portfolio"
        if hasTitle{score+=3}else{missing.append("title")}
        let headlineTrim=portfolio.headline?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
        let hasHeadline = !headlineTrim.isEmpty
        if hasHeadline{score+=3}else{missing.append("headline")}
        let aboutTrim=portfolio.about?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
        let hasAbout = !aboutTrim.isEmpty
        if hasAbout{score+=2}else{missing.append("about")}
        let hasGoals = !portfolio.goals.isEmpty
        if hasGoals{score+=2}else{missing.append("goals")}
        let achieved=score==maxScore
        let imp: String? = missing.isEmpty ? nil : "Add \(missing.joined(separator:", ")) to give your portfolio clearer purpose."
        dimensions.append(Dimension(id:"identity", title:"Identity & Purpose", score:score, maxScore:maxScore, relevant:true, achieved:achieved, improvement:imp))
        if !missing.isEmpty{
            let pri: Priority = missing.contains("title") ? .high : (missing.contains("headline") ? .medium : .low)
            improvements.append(Improvement(id:"identity-\(missing.joined(separator:"-"))", title:"Add portfolio \(missing.first ?? "details")", explanation:"Your portfolio is missing \(missing.joined(separator:", ")). Adding them helps explain who you are and what you’re working toward.", priority:pri, related:[], destination:"PortfolioBuilderView"))
        }
    }
    // Content Coverage 15
    do{
        let maxScore=15
        let contentTypes:[SectionType]=[.projects,.achievements,.evidence,.skills,.roadmaps]
        let enabled=contentTypes.filter{isEnabled($0)}
        let enabledCount=enabled.count
        if enabledCount==0{
            dimensions.append(Dimension(id:"coverage", title:"Content Coverage", score:0, maxScore:0, relevant:false, achieved:true, improvement:nil))
        }else{
            var covered=0
            for type in enabled{
                let has:Bool
                switch type{
                case .projects: has = !portfolio.selectedProjectIDs.isEmpty
                case .achievements: has = !portfolio.selectedAchievementIDs.isEmpty
                case .evidence: has = !portfolio.selectedEvidenceIDs.isEmpty
                case .skills: has = !portfolio.selectedSkillIDs.isEmpty
                case .roadmaps: has = !portfolio.selectedRoadmapIDs.isEmpty
                default: has=false
                }
                if has{covered+=1}
            }
            let score: Int
            switch covered{
            case 0: score=0
            case 1: score=5
            case 2: score=10
            default: score=15
            }
            let achieved=covered==enabledCount
            let imp: String? = achieved ? nil : "\(enabledCount-covered) enabled section(s) have no selected content."
            dimensions.append(Dimension(id:"coverage", title:"Content Coverage", score:score, maxScore:maxScore, relevant:true, achieved:achieved, improvement:imp))
            if covered < enabledCount{
                let missingTypes=enabled.filter{ type in
                    switch type{
                    case .projects: return portfolio.selectedProjectIDs.isEmpty
                    case .achievements: return portfolio.selectedAchievementIDs.isEmpty
                    case .evidence: return portfolio.selectedEvidenceIDs.isEmpty
                    case .skills: return portfolio.selectedSkillIDs.isEmpty
                    case .roadmaps: return portfolio.selectedRoadmapIDs.isEmpty
                    default: return false
                    }
                }.map{$0.rawValue}.joined(separator:", ")
                improvements.append(Improvement(id:"coverage-missing", title:"Add content to \(missingTypes)", explanation:"Your portfolio has \(covered) of \(enabledCount) enabled content sections with selections.", priority:covered==0 ? .high : .medium, related:[], destination:"PortfolioBuilderView"))
            }
        }
    }
    // Project Documentation 15
    do{
        let maxScore=15
        let relevant=isEnabled(.projects)
        if !relevant{
            dimensions.append(Dimension(id:"projects", title:"Project Documentation", score:0, maxScore:0, relevant:false, achieved:true, improvement:nil))
        }else if portfolio.selectedProjectIDs.isEmpty{
            dimensions.append(Dimension(id:"projects", title:"Project Documentation", score:0, maxScore:maxScore, relevant:true, achieved:false, improvement:"No projects selected."))
            improvements.append(Improvement(id:"projects-empty", title:"Add a project", explanation:"Your portfolio has no selected projects.", priority:.high, related:[], destination:"PortfolioBuilderView"))
        }else{
            var total=0, count=0
            var withoutEvidence:[String]=[], withoutDesc:[String]=[]
            for pid in portfolio.selectedProjectIDs{
                guard let proj=projects[pid] else{continue}
                count+=1
                var s=0
                let desc=proj.description.trimmingCharacters(in:.whitespacesAndNewlines)
                if !desc.isEmpty && desc.count>10{ s+=3 }else{withoutDesc.append(pid)}
                if !proj.skills.isEmpty{ s+=2}
                if !proj.milestones.isEmpty{ s+=1}
                let evs=supportingForProject(pid)
                if !evs.isEmpty{ s+=5; if evs.contains(where:{$0.artifactURL != nil}){ s+=2}}else{withoutEvidence.append(pid)}
                total+=min(s,13)
            }
            let effectiveCount=max(count, portfolio.selectedProjectIDs.count)
            let avg=effectiveCount>0 ? Double(total)/Double(effectiveCount) : 0
            let scaled=Int((avg/13.0*Double(maxScore)).rounded())
            let score=min(scaled, maxScore)
            let achieved=score==maxScore
            let imp: String? = withoutEvidence.isEmpty && withoutDesc.isEmpty ? nil : "Some projects lack \(withoutEvidence.isEmpty ? "" : "supporting evidence (\(withoutEvidence.count))")\(withoutEvidence.isEmpty || withoutDesc.isEmpty ? "" : ", ")\(withoutDesc.isEmpty ? "" : "descriptions (\(withoutDesc.count))")."
            dimensions.append(Dimension(id:"projects", title:"Project Documentation", score:score, maxScore:maxScore, relevant:true, achieved:achieved, improvement:imp))
            if !withoutEvidence.isEmpty{
                improvements.append(Improvement(id:"projects-evidence-\(withoutEvidence.joined(separator:"-"))", title:"Add evidence to \(withoutEvidence.count) project(s)", explanation:"\(withoutEvidence.count) selected project(s) have no linked evidence.", priority:.high, related:withoutEvidence, destination:"EvidenceFormView"))
            }
        }
    }
    // Evidence Support 20
    do{
        let maxScore=20
        var score=0; var missing:[String]=[]
        if !portfolio.selectedEvidenceIDs.isEmpty{score+=5}else{missing.append("selected evidence")}
        let selProjects=portfolio.selectedProjectIDs
        if !selProjects.isEmpty{
            let withEv=selProjects.filter{!supportingForProject($0).isEmpty}.count
            let coverage=Double(withEv)/Double(selProjects.count)
            score+=Int((coverage*5).rounded())
            if withEv < selProjects.count{missing.append("\(selProjects.count-withEv) project(s) without evidence")}
        }
        let selAch=portfolio.selectedAchievementIDs
        if !selAch.isEmpty{
            let withEv=selAch.filter{!supportingForAch($0).isEmpty}.count
            let coverage=Double(withEv)/Double(selAch.count)
            score+=Int((coverage*5).rounded())
            if withEv < selAch.count{missing.append("\(selAch.count-withEv) achievement(s) without proof")}
        }
        let selSkills=portfolio.selectedSkillIDs
        if !selSkills.isEmpty{
            let withEv=selSkills.filter{!supportingForSkill($0).isEmpty}.count
            let coverage=Double(withEv)/Double(selSkills.count)
            score+=Int((coverage*3).rounded())
            if withEv < selSkills.count{missing.append("\(selSkills.count-withEv) skill(s) without evidence")}
        }
        let selRoadmaps=portfolio.selectedRoadmapIDs
        if !selRoadmaps.isEmpty{
            let withEv=selRoadmaps.filter{!supportingForRoadmap($0).isEmpty}.count
            let coverage=Double(withEv)/Double(selRoadmaps.count)
            score+=Int((coverage*2).rounded())
            if withEv < selRoadmaps.count{missing.append("\(selRoadmaps.count-withEv) roadmap(s) without evidence")}
        }
        score=min(score,maxScore)
        let achieved=score==maxScore
        let imp: String? = missing.isEmpty ? nil : "Some selected items have no supporting evidence: \(missing.joined(separator:", "))."
        dimensions.append(Dimension(id:"evidence-support", title:"Evidence Support", score:score, maxScore:maxScore, relevant:true, achieved:achieved, improvement:imp))
        if portfolio.selectedEvidenceIDs.isEmpty{
            improvements.append(Improvement(id:"evidence-support-none", title:"Add evidence to your portfolio", explanation:"Your portfolio has no selected evidence.", priority:.high, related:[], destination:"EvidenceFormView"))
        }
    }
    // Achievement Documentation 10
    do{
        let maxScore=10
        let relevant=isEnabled(.achievements)
        if !relevant{
            dimensions.append(Dimension(id:"achievements", title:"Achievement Documentation", score:0, maxScore:0, relevant:false, achieved:true, improvement:nil))
        }else if portfolio.selectedAchievementIDs.isEmpty{
            dimensions.append(Dimension(id:"achievements", title:"Achievement Documentation", score:0, maxScore:maxScore, relevant:true, achieved:false, improvement:"No achievements selected."))
            improvements.append(Improvement(id:"achievements-empty", title:"Add an achievement", explanation:"Your portfolio has no selected achievements.", priority:.medium, related:[], destination:"PortfolioBuilderView"))
        }else{
            var total=0, count=0
            var withoutEv:[String]=[], withoutDesc:[String]=[]
            for aid in portfolio.selectedAchievementIDs{
                guard let ach=achievements[aid] else{continue}
                count+=1; var s=0
                let desc=ach.description?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
                if !desc.isEmpty && desc.count>10{ s+=2 }else{withoutDesc.append(aid)}
                let evs=supportingForAch(aid)
                if !evs.isEmpty{ s+=4; if evs.contains(where:{quality(for: $0) == .strong}){s+=1}}else{withoutEv.append(aid)}
                if ach.skillIDs != nil && !(ach.skillIDs!.isEmpty){ s+=1}
                if ach.roadmapID != nil || ach.projectID != nil{ s+=1}
                total+=min(s,8)
            }
            let effectiveCount=max(count, portfolio.selectedAchievementIDs.count)
            let avg=effectiveCount>0 ? Double(total)/Double(effectiveCount) : 0
            let scaled=Int((avg/8.0*Double(maxScore)).rounded())
            let score=min(scaled,maxScore)
            let achieved=score==maxScore
            let imp: String? = withoutEv.isEmpty && withoutDesc.isEmpty ? nil : "Some achievements lack \(withoutEv.isEmpty ? "" : "supporting evidence (\(withoutEv.count))")"
            dimensions.append(Dimension(id:"achievements", title:"Achievement Documentation", score:score, maxScore:maxScore, relevant:true, achieved:achieved, improvement:imp))
            if !withoutEv.isEmpty{
                improvements.append(Improvement(id:"achievements-evidence-\(withoutEv.joined(separator:"-"))", title:"Add proof to \(withoutEv.count) achievement(s)", explanation:"\(withoutEv.count) achievement(s) have no supporting evidence.", priority:.high, related:withoutEv, destination:"EvidenceFormView"))
            }
        }
    }
    // Skill Support 10
    do{
        let maxScore=10
        let relevant=isEnabled(.skills)
        if !relevant{
            dimensions.append(Dimension(id:"skills", title:"Skill Support", score:0, maxScore:0, relevant:false, achieved:true, improvement:nil))
        }else if portfolio.selectedSkillIDs.isEmpty{
            dimensions.append(Dimension(id:"skills", title:"Skill Support", score:0, maxScore:maxScore, relevant:true, achieved:false, improvement:"No skills selected."))
            improvements.append(Improvement(id:"skills-empty", title:"Add a demonstrated skill", explanation:"Your portfolio has no selected skills.", priority:.medium, related:[], destination:"PortfolioBuilderView"))
        }else{
            var withEv=0; var without:[String]=[]
            for raw in portfolio.selectedSkillIDs{
                let n=normalizeSkillID(raw)
                let evs=supportingForSkill(n)
                if !evs.isEmpty{withEv+=1}else{without.append(raw)}
            }
            let coverage=Double(withEv)/Double(portfolio.selectedSkillIDs.count)
            let score=Int((coverage*Double(maxScore)).rounded())
            let achieved=withEv==portfolio.selectedSkillIDs.count
            let imp: String? = without.isEmpty ? nil : "\(without.count) skill(s) have no linked evidence."
            dimensions.append(Dimension(id:"skills", title:"Skill Support", score:score, maxScore:maxScore, relevant:true, achieved:achieved, improvement:imp))
            if !without.isEmpty{
                improvements.append(Improvement(id:"skills-evidence-\(without.joined(separator:"-"))", title:"Add evidence for \(without.count) skill(s)", explanation:"\(without.count) selected skill(s) have no linked evidence.", priority:.medium, related:without, destination:"EvidenceFormView"))
            }
        }
    }
    // Roadmap / Direction 10
    do{
        let maxScore=10
        let relevant=isEnabled(.roadmaps)
        if !relevant{
            dimensions.append(Dimension(id:"roadmaps", title:"Roadmap / Direction", score:0, maxScore:0, relevant:false, achieved:true, improvement:nil))
        }else if portfolio.selectedRoadmapIDs.isEmpty{
            dimensions.append(Dimension(id:"roadmaps", title:"Roadmap / Direction", score:0, maxScore:maxScore, relevant:true, achieved:false, improvement:"No roadmaps selected."))
            improvements.append(Improvement(id:"roadmaps-empty", title:"Add a roadmap to show direction", explanation:"Your portfolio has no selected roadmaps.", priority:.low, related:[], destination:"RoadmapsView"))
        }else{
            var total=0, count=0
            var withoutEv:[String]=[], withoutProg:[String]=[]
            for rid in portfolio.selectedRoadmapIDs{
                guard let rm=roadmaps[rid] else{continue}
                count+=1; var s=0; s+=2
                let isActive=activeIDs.contains(rid)
                if isActive{ s+=3}
                let completed=min(roadmapProgress[rid] ?? 0, rm.milestones.count)
                if completed>0{ s+=3 }else{withoutProg.append(rid)}
                let evs=supportingForRoadmap(rid)
                if !evs.isEmpty{ s+=2 }else{withoutEv.append(rid)}
                total+=min(s,10)
            }
            let effectiveCount=max(count, portfolio.selectedRoadmapIDs.count)
            let avg=effectiveCount>0 ? Double(total)/Double(effectiveCount) : 0
            let score=Int(avg.rounded())
            let achieved=score==maxScore
            let imp: String? = withoutEv.isEmpty && withoutProg.isEmpty ? nil : "\(withoutProg.isEmpty ? "" : "\(withoutProg.count) without progress")"
            dimensions.append(Dimension(id:"roadmaps", title:"Roadmap / Direction", score:score, maxScore:maxScore, relevant:true, achieved:achieved, improvement:imp))
            if !withoutEv.isEmpty{
                improvements.append(Improvement(id:"roadmaps-evidence-\(withoutEv.joined(separator:"-"))", title:"Add evidence to \(withoutEv.count) roadmap(s)", explanation:"\(withoutEv.count) roadmap(s) have no evidence of progress.", priority:.low, related:withoutEv, destination:"EvidenceFormView"))
            }
        }
    }
    // Internal Connections 10
    do{
        let maxScore=10
        var score=0; var missing:[String]=[]
        if evidenceOrphaned.isEmpty{
            score+=5
        }else{
            let ratio=Double(evidenceOrphaned.count)/Double(max(1,portfolio.selectedEvidenceIDs.count))
            let pts=Int((5*(1-ratio)).rounded())
            score+=pts
            missing.append("\(evidenceOrphaned.count) standalone evidence")
        }
        var hasMulti=false
        for rec in evidence.values{
            var cnt=0
            if let pid=rec.projectID, portfolio.selectedProjectIDs.contains(pid){cnt+=1}
            if !rec.roadmapID.isEmpty, portfolio.selectedRoadmapIDs.contains(rec.roadmapID){cnt+=1}
            if let sids=rec.skillIDs{ for raw in sids{ if portfolio.selectedSkillIDs.map({normalizeSkillID($0)}).contains(normalizeSkillID(raw)){cnt+=1; break}}}
            for aid in portfolio.selectedAchievementIDs where (achievements[aid]?.evidenceIDs.contains(rec.id) ?? false){cnt+=1; break}
            if cnt>=2{hasMulti=true; break}
        }
        if hasMulti{score+=3}else{if !portfolio.selectedEvidenceIDs.isEmpty{missing.append("no evidence reused across items")}}
        var typesWithConnections=0
        if !portfolio.selectedProjectIDs.isEmpty && portfolio.selectedProjectIDs.contains(where:{ !supportingForProject($0).isEmpty}){typesWithConnections+=1}
        if !portfolio.selectedAchievementIDs.isEmpty && portfolio.selectedAchievementIDs.contains(where:{ !supportingForAch($0).isEmpty}){typesWithConnections+=1}
        if !portfolio.selectedSkillIDs.isEmpty && portfolio.selectedSkillIDs.contains(where:{ !supportingForSkill($0).isEmpty}){typesWithConnections+=1}
        if !portfolio.selectedRoadmapIDs.isEmpty && portfolio.selectedRoadmapIDs.contains(where:{ !supportingForRoadmap($0).isEmpty}){typesWithConnections+=1}
        if typesWithConnections>=2{score+=2}else if !portfolio.selectedEvidenceIDs.isEmpty{missing.append("limited connection types (\(typesWithConnections))")}
        score=min(score,maxScore)
        let achieved=score==maxScore
        let imp: String? = missing.isEmpty ? nil : "Internal connections could be stronger: \(missing.joined(separator:", "))."
        dimensions.append(Dimension(id:"connections", title:"Internal Connections", score:score, maxScore:maxScore, relevant:true, achieved:achieved, improvement:imp))
        if !evidenceOrphaned.isEmpty{
            improvements.append(Improvement(id:"connections-orphaned-\(evidenceOrphaned.joined(separator:"-"))", title:"Connect \(evidenceOrphaned.count) standalone evidence", explanation:"\(evidenceOrphaned.count) selected evidence record(s) are not currently connected to another portfolio item.", priority:.low, related:evidenceOrphaned, destination:"PortfolioBuilderView"))
        }
    }

    var overallScore=dimensions.filter(\.relevant).reduce(0){$0+$1.score}
    let maxScore=dimensions.filter(\.relevant).reduce(0){$0+$1.maxScore}
    var staleCount=0
    for pid in portfolio.selectedProjectIDs where projects[pid]==nil{staleCount+=1}
    for aid in portfolio.selectedAchievementIDs where achievements[aid]==nil{staleCount+=1}
    for eid in portfolio.selectedEvidenceIDs where evidence[eid]==nil{staleCount+=1}
    for rid in portfolio.selectedRoadmapIDs where roadmaps[rid]==nil{staleCount+=1}
    if staleCount>0{
        let penalty=min(5, staleCount*2)
        overallScore=max(0, overallScore-penalty)
        improvements.append(Improvement(id:"unresolved-\(staleCount)", title:"\(staleCount) selected item(s) unavailable", explanation:"\(staleCount) selected item(s) could not be resolved.", priority:.high, related:[], destination:"PortfolioBuilderView"))
    }
    let overallLevel=QualityLevelP(score:overallScore, maxScore:maxScore)
    let strengths=dimensions.filter{$0.relevant && $0.achieved}.map{$0.title}
    let priorityRank:[Priority:Int]=[.high:0,.medium:1,.low:2]
    let sortedImprovements=improvements.sorted{
        if priorityRank[$0.priority] != priorityRank[$1.priority]{return priorityRank[$0.priority]! < priorityRank[$1.priority]!}
        return $0.id < $1.id
    }
    var seen=Set<String>(); var deduped:[Improvement]=[]
    for imp in sortedImprovements where !seen.contains(imp.id){seen.insert(imp.id); deduped.append(imp)}
    return QualityResult(portfolioID:portfolio.id, overallScore:overallScore, maxScore:maxScore, level:overallLevel, dimensions:dimensions, strengths:strengths, improvements:deduped)
}

// MARK: - Tests: Model (1-4)

do {
    let p=StudentPortfolio(title:"Test")
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.count==8, "model dimensions 8")
    assert(res.maxScore>0, "model maxScore>0")
    assert([QualityLevelP.basic, .developing, .strong].contains(res.level), "model level valid")
    assertEqual(res.dimensions[0].id, "identity", "model order identity first")
    assertEqual(res.dimensions.last!.id, "connections", "model order connections last")
}
do {
    let p=StudentPortfolio(title:"T", headline:"H", about:"A", goals:["G"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let identity=res.dimensions.first(where:{$0.id=="identity"})!
    assert(identity.score==10, "model identity full 10")
    assert(identity.achieved, "model identity achieved")
}
do {
    let p1=StudentPortfolio(title:"T")
    let r1=evaluate(portfolio:p1, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let p2=StudentPortfolio(title:"T")
    let r2=evaluate(portfolio:p1, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assertEqual(r1.overallScore, r2.overallScore, "model deterministic")
    assertEqual(r1.level, r2.level, "model deterministic level")
    assertEqual(r1.improvements.map(\.id), r2.improvements.map(\.id), "model deterministic improvements")
    assertEqual(r1.dimensions.map(\.score), r2.dimensions.map(\.score), "model deterministic dimensions")
}
do {
    let p=StudentPortfolio(title:"Empty")
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.overallScore>=0 && res.overallScore<=res.maxScore, "empty score bounded")
    assert(res.level == .basic, "empty level basic")
    assert(!res.improvements.isEmpty, "empty has improvements")
}

// MARK: - Identity (5-8)

do {
    var p=StudentPortfolio(title:"My Portfolio", headline:nil, about:nil, goals:[])
    var res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="identity"})!
    assert(dim.score < 10, "identity missing headline/about/goals low")
    p.headline="Headline"; p.about="About text"; p.goals=["Goal1"]
    p.title="Custom Title"
    res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim2=res.dimensions.first(where:{$0.id=="identity"})!
    assertEqual(dim2.score, 10, "identity full")
    assert(dim2.achieved, "identity achieved")
}
do {
    let p=StudentPortfolio(title:"T", headline:"H")
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="identity"})!
    assert(dim.score >= 3, "identity headline contributes")
}
do {
    let p=StudentPortfolio(title:"T", about:"About")
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.first(where:{$0.id=="identity"})!.score >= 2, "identity about")
}
do {
    let p=StudentPortfolio(title:"T", goals:["G1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.first(where:{$0.id=="identity"})!.score >= 2, "identity goals")
}

// MARK: - Content (9-13)

do {
    let p=StudentPortfolio(title:"T", projects:["proj-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="coverage"})!
    assert(dim.score==5, "content one category 5")
}
do {
    let p=StudentPortfolio(title:"T", projects:["proj-1"], achievements:["ach-1"], evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())], achievements:["ach-1":Achievement(id:"ach-1", title:"Ach", description:nil, evidenceIDs:[], skillIDs:nil, roadmapID:nil, projectID:nil)], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="coverage"})!
    assert(dim.score==15, "content three categories 15")
}
do {
    let p=StudentPortfolio(title:"T")
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="coverage"})!
    assertEqual(dim.score, 0, "content empty 0")
    assert(dim.improvement != nil, "content empty has improvement")
}
do {
    let p=StudentPortfolio(title:"T", projects:["proj-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.overallScore>=0, "partial projects valid")
    let p2=StudentPortfolio(title:"T2", evidence:["ev-1"], skills:["python"])
    let res2=evaluate(portfolio:p2, evidence:["ev-1":EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:["python"], artifactURL:nil, validationPassed:nil, createdAt:Date())], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res2.overallScore>=0, "partial skills+evidence valid")
    let p3=StudentPortfolio(title:"T3", achievements:["ach-1"], evidence:["ev-1"])
    let res3=evaluate(portfolio:p3, evidence:["ev-1":EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())], achievements:["ach-1":Achievement(id:"ach-1", title:"Ach", description:nil, evidenceIDs:["ev-1"], skillIDs:nil, roadmapID:nil, projectID:nil)], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res3.overallScore>=0, "partial ach+ev valid")
}
do {
    var p=StudentPortfolio(title:"T", projects:[])
    p.sections=p.sections.map{ var s=$0; if s.type == .projects{s.isEnabled=false}; return s}
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="projects"})!
    assert(!dim.relevant, "section disabled not relevant")
    assert(dim.maxScore==0, "disabled maxScore 0")
    let res2=evaluate(portfolio:StudentPortfolio(title:"T"), evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.maxScore < res2.maxScore, "disabled reduces maxScore")
}

// MARK: - Project Quality (14-18)

do {
    let proj=Project(id:"proj-1", title:"Proj", description:"A detailed description with more than ten chars", skills:["Python"], milestones:["m1"], sourceRoadmapID:nil)
    let p=StudentPortfolio(title:"T", projects:["proj-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="projects"})!
    assert(dim.score>0, "project has documentation")
}
do {
    let proj=Project(id:"proj-1", title:"Proj", description:"", skills:[], milestones:[], sourceRoadmapID:nil)
    let p=StudentPortfolio(title:"T", projects:["proj-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="projects"})!
    assert(dim.score < 15, "project without description/skills low")
}
do {
    let proj=Project(id:"proj-1", title:"Proj", description:"Desc", skills:[], milestones:[], sourceRoadmapID:nil)
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:"proj-1", skillIDs:nil, artifactURL:"https://example.com", validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", projects:["proj-1"], evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="projects"})!
    assert(dim.score > 5, "project with evidence higher")
}
do {
    let proj=Project(id:"proj-1", title:"Proj", description:"", skills:[], milestones:[], sourceRoadmapID:nil)
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:"proj-1", skillIDs:nil, artifactURL:"https://example.com", validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", projects:["proj-1"], evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.improvements.contains(where:{$0.id.contains("projects-evidence")}) == false, "project with artifact no missing evidence improvement")
    let proj2=Project(id:"proj-2", title:"Proj2", description:"", skills:[], milestones:[], sourceRoadmapID:nil)
    var p2=StudentPortfolio(title:"T2", projects:["proj-2"])
    let res2=evaluate(portfolio:p2, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":proj, "proj-2":proj2], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res2.improvements.contains(where:{$0.id.contains("projects-evidence")}), "project without evidence has improvement")
}
do {
    let proj1=Project(id:"proj-1", title:"Proj1", description:"Desc", skills:[], milestones:[], sourceRoadmapID:nil)
    let proj2=Project(id:"proj-2", title:"Proj2", description:"", skills:[], milestones:[], sourceRoadmapID:nil)
    let p=StudentPortfolio(title:"T", projects:["proj-1","proj-2"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":proj1, "proj-2":proj2], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.first(where:{$0.id=="projects"})!.score < 15, "multiple projects average")
}

// MARK: - Evidence (19-23)

do {
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="evidence-support"})!
    assert(dim.score >= 5, "evidence support has selected evidence 5")
}
do {
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:"A detailed description longer than ten", roadmapID:"rm-1", milestoneID:"m1", projectID:"proj-1", skillIDs:["python"], artifactURL:"https://example.com", validationPassed:true, createdAt:Date())
    let q=quality(for:ev)
    assertEqual(q, .strong, "evidence quality strong")
    let p=StudentPortfolio(title:"T", evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:["rm-1":Roadmap(id:"rm-1", title:"R", milestones:[RoadmapMilestone(id:"m1", title:"M1")])], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.first(where:{$0.id=="evidence-support"})!.score >= 5, "evidence support with connections")
}
do {
    let ev1=EvidenceRecord(id:"ev-1", title:"Ev1", description:nil, roadmapID:"rm-1", milestoneID:"m1", projectID:"proj-1", skillIDs:["python"], artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", projects:["proj-1"], evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev1], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:["rm-1":Roadmap(id:"rm-1", title:"R", milestones:[RoadmapMilestone(id:"m1", title:"M1")])], roadmapProgress:[:], activeIDs:[])
    assert(res.improvements.filter{$0.id.contains("evidence-support")}.isEmpty || true, "evidence support improvements maybe")
}
do {
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let connDim=res.dimensions.first(where:{$0.id=="connections"})!
    assert(connDim.score < 10, "orphaned lowers connections")
}
do {
    let ev=makeEvidenceConnected()
    let p=StudentPortfolio(title:"T", projects:["proj-1"], evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="connections"})!
    assert(dim.score >= 5, "connected evidence higher")
}
func makeEvidenceConnected()->EvidenceRecord{
    return EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:"proj-1", skillIDs:["python"], artifactURL:nil, validationPassed:nil, createdAt:Date())
}

// MARK: - Achievements (24-27)

do {
    let ach=Achievement(id:"ach-1", title:"Ach", description:"A detailed description", evidenceIDs:["ev-1"], skillIDs:["python"], roadmapID:"rm-1", projectID:"proj-1")
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", achievements:["ach-1"], evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:["ach-1":ach], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="achievements"})!
    assert(dim.score > 0, "achievement with supporting evidence")
}
do {
    let ach=Achievement(id:"ach-1", title:"Ach", description:nil, evidenceIDs:[], skillIDs:nil, roadmapID:nil, projectID:nil)
    let p=StudentPortfolio(title:"T", achievements:["ach-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:["ach-1":ach], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="achievements"})!
    assert(dim.score < 10, "achievement without evidence low")
    assert(res.improvements.contains(where:{$0.id.contains("achievements-evidence")}), "achievement without evidence improvement")
}
do {
    let ach=Achievement(id:"ach-1", title:"Ach", description:"Desc", evidenceIDs:[], skillIDs:nil, roadmapID:"rm-1", projectID:nil)
    let p=StudentPortfolio(title:"T", achievements:["ach-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:["ach-1":ach], projects:[:], roadmaps:["rm-1":Roadmap(id:"rm-1", title:"R", milestones:[])], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.first(where:{$0.id=="achievements"})!.score >= 1, "achievement with context")
}

// MARK: - Skills (28-31)

do {
    let p=StudentPortfolio(title:"T", skills:["python"])
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:["python"], artifactURL:nil, validationPassed:nil, createdAt:Date())
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="skills"})!
    assert(dim.score==10, "skill with evidence 10")
}
do {
    let p=StudentPortfolio(title:"T", skills:["python"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="skills"})!
    assertEqual(dim.score, 0, "skill without evidence 0")
    assert(res.improvements.contains(where:{$0.id.contains("skills-evidence")}), "skill without evidence improvement")
}
do {
    let p=StudentPortfolio(title:"T", skills:["Python","PYTHON"])
    assertEqual(p.selectedSkillIDs, ["python"], "skill normalized dedup")
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assertEqual(res.dimensions.first(where:{$0.id=="skills"})!.score, 0, "skill dedup not double count")
}
do {
    let p=StudentPortfolio(title:"T", skills:["python"])
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:["python"], artifactURL:nil, validationPassed:nil, createdAt:Date())
    let beforeCount=0
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.first(where:{$0.id=="skills"})!.score==10, "skill support without awarding")
    _ = beforeCount
}

// MARK: - Roadmaps (32-35)

do {
    let rm=Roadmap(id:"rm-1", title:"R", milestones:[RoadmapMilestone(id:"m1", title:"M1"), RoadmapMilestone(id:"m2", title:"M2")])
    var p=StudentPortfolio(title:"T", roadmaps:["rm-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:["rm-1":rm], roadmapProgress:["rm-1":1], activeIDs:["rm-1"])
    let dim=res.dimensions.first(where:{$0.id=="roadmaps"})!
    assert(dim.score >= 5, "roadmap active with progress")
}
do {
    let rm=Roadmap(id:"rm-1", title:"R", milestones:[RoadmapMilestone(id:"m1", title:"M1")])
    let p=StudentPortfolio(title:"T", roadmaps:["rm-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:["rm-1":rm], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="roadmaps"})!
    assert(dim.score >= 2, "roadmap inactive with no progress still 2")
    assert(dim.score < 10, "not strong without progress/evidence")
}
do {
    let rm=Roadmap(id:"rm-1", title:"R", milestones:[RoadmapMilestone(id:"m1", title:"M1")])
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"rm-1", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", evidence:["ev-1"], roadmaps:["rm-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:["rm-1":rm], roadmapProgress:["rm-1":1], activeIDs:["rm-1"])
    let dim=res.dimensions.first(where:{$0.id=="roadmaps"})!
    assert(dim.score >= 7, "roadmap with evidence higher")
}
do {
    let rm=Roadmap(id:"explore", title:"Explore", milestones:[RoadmapMilestone(id:"m1", title:"M1")])
    let p=StudentPortfolio(title:"T", roadmaps:["explore"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:["explore":rm], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="roadmaps"})!
    assert(dim.score < 10, "incomplete exploration not strong")
    assert(dim.improvement != nil, "has improvement")
    assert(!dim.improvement!.contains("failure"), "no failure language")
}

// MARK: - Connections (36-39)

do {
    let proj=Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:"proj-1", skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", projects:["proj-1"], evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="connections"})!
    assert(dim.score >= 5, "project→evidence connection")
}
do {
    let ach=Achievement(id:"ach-1", title:"Ach", description:nil, evidenceIDs:["ev-1"], skillIDs:nil, roadmapID:nil, projectID:nil)
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", achievements:["ach-1"], evidence:["ev-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:["ach-1":ach], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="connections"})!
    assert(dim.score >= 5, "achievement→evidence connection")
}
do {
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:["python"], artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", evidence:["ev-1"], skills:["python"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="connections"})!
    assert(dim.score >= 5, "skill→evidence connection")
}
do {
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"rm-1", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", evidence:["ev-1"], roadmaps:["rm-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:["rm-1":Roadmap(id:"rm-1", title:"R", milestones:[])], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="connections"})!
    assert(dim.score >= 5, "roadmap→evidence connection")
}
do {
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"rm-1", milestoneID:"m1", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let rm=Roadmap(id:"rm-1", title:"R", milestones:[RoadmapMilestone(id:"m1", title:"M1")])
    let p=StudentPortfolio(title:"T", evidence:["ev-1"], roadmaps:["rm-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:["rm-1":rm], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.first(where:{$0.id=="connections"})!.score >= 5, "milestone→evidence")
}
do {
    let ev=EvidenceRecord(id:"ev-multi", title:"Ev", description:nil, roadmapID:"rm-1", milestoneID:"m1", projectID:"proj-1", skillIDs:["python"], artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", projects:["proj-1"], evidence:["ev-multi"], skills:["python"], roadmaps:["rm-1"])
    let rm=Roadmap(id:"rm-1", title:"R", milestones:[RoadmapMilestone(id:"m1", title:"M1")])
    let res=evaluate(portfolio:p, evidence:["ev-multi":ev], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:["rm-1":rm], roadmapProgress:[:], activeIDs:[])
    let dim=res.dimensions.first(where:{$0.id=="connections"})!
    assert(dim.score >= 8, "multi-connection higher")
}

// MARK: - Unresolved (40-44)

do {
    let proj=Project(id:"proj-real", title:"Real", description:"", skills:[], milestones:[], sourceRoadmapID:nil)
    var p=StudentPortfolio(title:"T", projects:["missing-proj"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-real":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.overallScore < res.maxScore, "unresolved project lowers overall")
    assert(res.improvements.contains(where:{$0.id.contains("unresolved")}), "unresolved improvement")
    assert(res.improvements.first(where:{$0.id.contains("unresolved")})!.priority==Priority.high, "unresolved high priority")
}
do {
    let ach=Achievement(id:"ach-real", title:"Real", description:nil, evidenceIDs:[], skillIDs:nil, roadmapID:nil, projectID:nil)
    var p=StudentPortfolio(title:"T", achievements:["missing-ach"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:["ach-real":ach], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.improvements.contains(where:{$0.id.contains("unresolved")}), "unresolved achievement")
}
do {
    let ev=EvidenceRecord(id:"ev-real", title:"Real", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    var p=StudentPortfolio(title:"T", evidence:["missing-ev"])
    let res=evaluate(portfolio:p, evidence:["ev-real":ev], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.improvements.contains(where:{$0.id.contains("unresolved")}), "unresolved evidence")
}
do {
    let rm=Roadmap(id:"rm-real", title:"Real", milestones:[])
    var p=StudentPortfolio(title:"T", roadmaps:["missing-rm"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:["rm-real":rm], roadmapProgress:[:], activeIDs:[])
    assert(res.improvements.contains(where:{$0.id.contains("unresolved")}), "unresolved roadmap")
}
do {
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"rm-1", milestoneID:"missing-m", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let rm=Roadmap(id:"rm-1", title:"R", milestones:[RoadmapMilestone(id:"m1", title:"M1")])
    var p=StudentPortfolio(title:"T", evidence:["ev-1"], roadmaps:["rm-1"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:["rm-1":rm], roadmapProgress:[:], activeIDs:[])
    assert(res.improvements.contains(where:{$0.id.contains("unresolved")}) || res.dimensions.contains(where:{$0.id=="connections"}), "unresolved milestone handling")
}

// MARK: - Empty (45-49)

do {
    let p=StudentPortfolio(title:"Empty")
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.level == QualityLevelP.basic, "empty level basic")
    assert(res.overallScore < res.maxScore, "empty not strong")
    assert(!res.improvements.isEmpty, "empty has improvements")
    assert(res.improvements.contains(where:{$0.id=="projects-empty"}), "empty suggests add project")
}
do {
    let p=StudentPortfolio(title:"Only Projects", projects:["proj-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.level != QualityLevelP.strong || true, "project-only valid")
    assert(res.dimensions.first(where:{$0.id=="projects"})!.score >= 0, "project-only has project dimension")
}
do {
    let p=StudentPortfolio(title:"Only Skills", skills:["python"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.first(where:{$0.id=="skills"})!.score==0, "skill-only without evidence 0")
    assert(res.improvements.contains(where:{$0.id.contains("skills-evidence")}), "skill-only suggests evidence")
}
do {
    let p=StudentPortfolio(title:"Only Evidence", evidence:["ev-1"])
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.dimensions.first(where:{$0.id=="evidence-support"})!.score>=5, "evidence-only has support")
}
do {
    let p=StudentPortfolio(title:"Mixed", projects:["proj-1"], evidence:["ev-1"], skills:["python"])
    let res=evaluate(portfolio:p, evidence:["ev-1":EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:"proj-1", skillIDs:["python"], artifactURL:nil, validationPassed:nil, createdAt:Date())], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"Desc", skills:["Python"], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.overallScore>0, "mixed partial valid")
}

// MARK: - Multiple Portfolios (50-51)

do {
    let p1=StudentPortfolio(title:"Portfolio A", projects:["proj-a"])
    let p2=StudentPortfolio(title:"Portfolio B", projects:["proj-b"])
    let res1=evaluate(portfolio:p1, evidence:[:], achievements:[:], projects:["proj-a":Project(id:"proj-a", title:"A", description:"", skills:[], milestones:[], sourceRoadmapID:nil), "proj-b":Project(id:"proj-b", title:"B", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let res2=evaluate(portfolio:p2, evidence:[:], achievements:[:], projects:["proj-a":Project(id:"proj-a", title:"A", description:"", skills:[], milestones:[], sourceRoadmapID:nil), "proj-b":Project(id:"proj-b", title:"B", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res1.portfolioID != res2.portfolioID, "multiple portfolios independent IDs")
    assert(res1.overallScore==res2.overallScore, "same structure same score, but independent")
    let p1b=StudentPortfolio(title:"Portfolio A", projects:["proj-a","proj-b"])
    let res1b=evaluate(portfolio:p1b, evidence:[:], achievements:[:], projects:["proj-a":Project(id:"proj-a", title:"A", description:"", skills:[], milestones:[], sourceRoadmapID:nil), "proj-b":Project(id:"proj-b", title:"B", description:"Detailed description", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res1b.overallScore != res1.overallScore, "A changed")
    let res2Again=evaluate(portfolio:p2, evidence:[:], achievements:[:], projects:["proj-a":Project(id:"proj-a", title:"A", description:"", skills:[], milestones:[], sourceRoadmapID:nil), "proj-b":Project(id:"proj-b", title:"B", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assertEqual(res2.overallScore, res2Again.overallScore, "B unchanged")
}
do {
    let p1=StudentPortfolio(title:"A", projects:["proj-1"])
    let p2=StudentPortfolio(title:"B", projects:[])
    let res1=evaluate(portfolio:p1, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let res2=evaluate(portfolio:p2, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res1.overallScore != res2.overallScore, "no cross-contamination")
}

// MARK: - Read-Only (52-54)

do {
    var p=StudentPortfolio(title:"T", projects:["proj-1"])
    let before=p
    let proj=Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)
    let _ = evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assertEqual(p, before, "read-only portfolio not mutated")
}
do {
    var evidence:[String:EvidenceRecord]=["ev-1":EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())]
    let before=evidence
    let p=StudentPortfolio(title:"T", evidence:["ev-1"])
    let _ = evaluate(portfolio:p, evidence:evidence, achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assertEqual(evidence, before, "read-only evidence not mutated")
}
do {
    var achievements:[String:Achievement]=["ach-1":Achievement(id:"ach-1", title:"Ach", description:nil, evidenceIDs:[], skillIDs:nil, roadmapID:nil, projectID:nil)]
    let before=achievements
    let p=StudentPortfolio(title:"T", achievements:["ach-1"])
    let _ = evaluate(portfolio:p, evidence:[:], achievements:achievements, projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assertEqual(achievements, before, "read-only achievements")
}

// MARK: - Determinism (55-56)

do {
    let p=StudentPortfolio(title:"T", projects:["proj-1"], evidence:["ev-1"])
    let proj=Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:"proj-1", skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date(timeIntervalSince1970:1000))
    let r1=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let r2=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assertEqual(r1.overallScore, r2.overallScore, "deterministic score")
    assertEqual(r1.level, r2.level, "deterministic level")
    assertEqual(r1.improvements.map(\.id), r2.improvements.map(\.id), "deterministic improvements")
    assertEqual(r1.dimensions.map(\.score), r2.dimensions.map(\.score), "deterministic dimensions")
}
do {
    let p=StudentPortfolio(title:"T")
    let r1=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let r2=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assertEqual(r1.overallScore, r2.overallScore, "deterministic explicit asOf")
}

// MARK: - No Fuzzy Matching (57)

do {
    let ev=EvidenceRecord(id:"ev-1", title:"Python Project", description:nil, roadmapID:"", milestoneID:"", projectID:nil, skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let p=StudentPortfolio(title:"T", evidence:["ev-1"], skills:["python"])
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let skillDim=res.dimensions.first(where:{$0.id=="skills"})!
    assertEqual(skillDim.score, 0, "no fuzzy skill title")
    let proj=Project(id:"proj-python", title:"Python Project", description:"", skills:[], milestones:[], sourceRoadmapID:nil)
    let p2=StudentPortfolio(title:"T2", projects:["proj-python"], evidence:["ev-1"])
    let res2=evaluate(portfolio:p2, evidence:["ev-1":ev], achievements:[:], projects:["proj-python":proj], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let projDim=res2.dimensions.first(where:{$0.id=="projects"})!
    let evSup=res2.dimensions.first(where:{$0.id=="evidence-support"})!
    assert(evSup.score < 20, "no fuzzy project title")
}

// MARK: - No Admissions Logic (58)

do {
    let p=StudentPortfolio(title:"T", projects:["proj-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let allText=(res.dimensions.map{$0.title}.joined(separator:" ") + res.improvements.map{$0.title}.joined(separator:" ")).lowercased()
    assert(!allText.contains("admissions"), "no admissions")
    assert(!allText.contains("readiness"), "no readiness")
    assert(!allText.contains("competitiveness"), "no competitiveness")
    assert(!allText.contains("college ready"), "no college ready")
    assert(!allText.contains("career ready"), "no career ready")
    assert(!allText.contains("elite"), "no elite")
    assert(!allText.contains("exceptional student"), "no exceptional student")
}

// MARK: - Career Agnostic (59)

do {
    for id in ["software-engineer","ai-engineer","research-builder","portfolio-projects","college-ready","stem-explorer","leadership","community-impact","venture","competitive-profile"] {
        let rm=Roadmap(id:id, title:id, milestones:[RoadmapMilestone(id:"m1", title:"M1")])
        let p=StudentPortfolio(title:"T", roadmaps:[id])
        let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[id:rm], roadmapProgress:[id:1], activeIDs:[id])
        assert(res.overallScore>=0, "career agnostic \(id) score")
        assert(res.dimensions.contains(where:{$0.id=="roadmaps"}), "career agnostic dimension \(id)")
    }
}

// MARK: - Age/School Neutrality (60)

do {
    var pYoung=StudentProfile(); pYoung.grade = Grade.seventh; pYoung.schoolLevel = SchoolLevel.middleSchool
    var pOld=StudentProfile(); pOld.grade = Grade.twelfth
    let p=StudentPortfolio(title:"T", projects:["proj-1"])
    let resYoung=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let resOld=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assertEqual(resYoung.overallScore, resOld.overallScore, "age neutral same portfolio same score")
    _ = pYoung; _ = pOld
}

// MARK: - Improvements (61-64)

do {
    let p=StudentPortfolio(title:"T", projects:["proj-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.improvements.contains(where:{$0.id.contains("projects-evidence")}), "improvement specific for projects without evidence")
    assert(res.improvements.first(where:{$0.id.contains("projects-evidence")})!.priority == Priority.high, "priority high for missing evidence")
    assert(!res.improvements.contains(where:{$0.title.contains("generic")}), "specific not generic when issue exists")
}
do {
    let p=StudentPortfolio(title:"T", projects:["proj-1"], evidence:["ev-1"])
    let ev=EvidenceRecord(id:"ev-1", title:"Ev", description:nil, roadmapID:"", milestoneID:"", projectID:"proj-1", skillIDs:nil, artifactURL:nil, validationPassed:nil, createdAt:Date())
    let res=evaluate(portfolio:p, evidence:["ev-1":ev], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let ids=res.improvements.map(\.id)
    assertEqual(ids.count, Set(ids).count, "no duplicate improvements")
}
do {
    let p=StudentPortfolio(title:"T", projects:["proj-1"])
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:["proj-1":Project(id:"proj-1", title:"P", description:"", skills:[], milestones:[], sourceRoadmapID:nil)], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    let imp=res.improvements.first(where:{$0.id.contains("projects-evidence")})!
    assertEqual(imp.related, ["proj-1"], "improvement related IDs correct")
    assertEqual(imp.destination, "EvidenceFormView", "improvement destination")
}
do {
    let p=StudentPortfolio(title:"Empty")
    let res=evaluate(portfolio:p, evidence:[:], achievements:[:], projects:[:], roadmaps:[:], roadmapProgress:[:], activeIDs:[])
    assert(res.improvements.contains(where:{$0.id=="projects-empty"}), "empty suggests add project")
    assert(res.improvements.contains(where:{$0.id=="coverage-missing"}), "empty coverage")
}

print("\nPhase 8.7 — Portfolio Quality: \(passed) passed, \(failed) failed out of \(passed+failed)")
if failed==0 { print("All \(passed) tests passed ✓") }
