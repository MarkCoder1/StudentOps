import Foundation

// MARK: - Project Playbook Domain (Phase 9.6)
//
// Deterministic, static playbooks describing how a catalog project should be executed.
// Source of truth: static catalog metadata (ProjectService), not AI, not network, not persisted student state.
// Pipeline: Project Catalog → ProjectPlaybook → Views (ProjectDetailView)
// Playbook is supporting structured information associated with a Project (projectID), not a replacement.
//
// No mutation, no progress tracking, no evidence creation — those belong to Phase 9.7.
// No AI, no database.

// MARK: - Prerequisite Types

enum ProjectPrerequisiteType: String, Codable, Hashable, CaseIterable {
    case skill = "skill"
    case priorProject = "priorProject"
    case roadmap = "roadmap"
    case resource = "resource"
    case knowledge = "knowledge"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "skill"
        self = ProjectPrerequisiteType(rawValue: raw) ?? .skill
    }
}

enum PrerequisiteStatus: String, Codable, Hashable {
    case met = "met"
    case notMet = "notMet"
    case unknown = "unknown"

    var label: String {
        switch self {
        case .met: return "Met"
        case .notMet: return "Not detected"
        case .unknown: return "Unknown"
        }
    }
}

struct ProjectPrerequisite: Identifiable, Hashable, Codable {
    let id: String
    let type: ProjectPrerequisiteType
    let title: String
    let description: String?
    /// For skill: canonical skill ID (normalized). For priorProject: project ID. For roadmap: roadmap ID. For resource/knowledge: free text identifier.
    let referenceID: String?

    init(id: String = UUID().uuidString, type: ProjectPrerequisiteType, title: String, description: String? = nil, referenceID: String? = nil) {
        self.id = id
        self.type = type
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = desc?.isEmpty == true ? nil : desc
        let ref = referenceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.referenceID = ref?.isEmpty == true ? nil : ref
    }

    enum CodingKeys: String, CodingKey { case id, type, title, description, referenceID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        type = (try? c.decode(ProjectPrerequisiteType.self, forKey: .type)) ?? .skill
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        referenceID = try? c.decode(String.self, forKey: .referenceID)
    }
}

// MARK: - Resource

enum ProjectResourceType: String, Codable, Hashable, CaseIterable {
    case documentation = "documentation"
    case tutorial = "tutorial"
    case reference = "reference"
    case tool = "tool"
    case dataset = "dataset"
    case course = "course"
    case template = "template"
    case other = "other"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "other"
        self = ProjectResourceType(rawValue: raw) ?? .other
    }

    var displayName: String {
        switch self {
        case .documentation: return "Documentation"
        case .tutorial: return "Tutorial"
        case .reference: return "Reference"
        case .tool: return "Tool"
        case .dataset: return "Dataset"
        case .course: return "Course"
        case .template: return "Template"
        case .other: return "Other"
        }
    }
}

struct ProjectResource: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let type: ProjectResourceType
    let url: String
    let description: String?

    init(id: String = UUID().uuidString, title: String, type: ProjectResourceType, url: String, description: String? = nil) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
        self.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = desc?.isEmpty == true ? nil : desc
    }

    var isValidURL: Bool {
        let t = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard let u = URL(string: t) else { return false }
        guard let s = u.scheme?.lowercased(), ["http","https"].contains(s) else { return false }
        return u.host != nil
    }

    enum CodingKeys: String, CodingKey { case id, title, type, url, description }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        type = (try? c.decode(ProjectResourceType.self, forKey: .type)) ?? .other
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
    }
}

// MARK: - Deliverable

struct ProjectDeliverable: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String?
    let format: String?
    let required: Bool

    init(id: String = UUID().uuidString, title: String, description: String? = nil, format: String? = nil, required: Bool = true) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = desc?.isEmpty == true ? nil : desc
        let fmt = format?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.format = fmt?.isEmpty == true ? nil : fmt
        self.required = required
    }

    enum CodingKeys: String, CodingKey { case id, title, description, format, required }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        format = try? c.decode(String.self, forKey: .format)
        required = (try? c.decode(Bool.self, forKey: .required)) ?? true
    }
}

// MARK: - Completion Criterion

struct ProjectCompletionCriterion: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String?
    let required: Bool

    init(id: String = UUID().uuidString, title: String, description: String? = nil, required: Bool = true) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = desc?.isEmpty == true ? nil : desc
        self.required = required
    }

    enum CodingKeys: String, CodingKey { case id, title, description, required }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        required = (try? c.decode(Bool.self, forKey: .required)) ?? true
    }
}

// MARK: - Effort

struct ProjectEffort: Hashable, Codable {
    let estimatedHours: Double?
    let displayText: String?

    init(estimatedHours: Double? = nil, displayText: String? = nil) {
        self.estimatedHours = estimatedHours
        let txt = displayText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayText = txt?.isEmpty == true ? nil : txt
    }

    enum CodingKeys: String, CodingKey { case estimatedHours, displayText }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        estimatedHours = try? c.decode(Double.self, forKey: .estimatedHours)
        displayText = try? c.decode(String.self, forKey: .displayText)
    }
}

// MARK: - Playbook Step

struct ProjectPlaybookStep: Identifiable, Hashable, Codable {
    let id: String
    let order: Int
    let title: String
    let description: String
    let objective: String?
    let estimatedEffort: String?
    let requiredSkills: [String]
    let deliverableIDs: [String]
    let prerequisiteStepIDs: [String]

    init(
        id: String = UUID().uuidString,
        order: Int,
        title: String,
        description: String,
        objective: String? = nil,
        estimatedEffort: String? = nil,
        requiredSkills: [String] = [],
        deliverableIDs: [String] = [],
        prerequisiteStepIDs: [String] = []
    ) {
        self.id = id
        self.order = order
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let obj = objective?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.objective = obj?.isEmpty == true ? nil : obj
        let eff = estimatedEffort?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.estimatedEffort = eff?.isEmpty == true ? nil : eff
        // Normalize skill IDs, deduplicate
        var seen = Set<String>()
        var deduped: [String] = []
        for raw in requiredSkills {
            let nid = Skill.normalizeID(raw)
            guard !nid.isEmpty, !seen.contains(nid) else { continue }
            seen.insert(nid); deduped.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        self.requiredSkills = deduped
        self.deliverableIDs = deliverableIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.prerequisiteStepIDs = prerequisiteStepIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    enum CodingKeys: String, CodingKey { case id, order, title, description, objective, estimatedEffort, requiredSkills, deliverableIDs, prerequisiteStepIDs }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        order = (try? c.decode(Int.self, forKey: .order)) ?? 0
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        objective = try? c.decode(String.self, forKey: .objective)
        estimatedEffort = try? c.decode(String.self, forKey: .estimatedEffort)
        if let skills = try? c.decode([String].self, forKey: .requiredSkills) {
            var seen = Set<String>(); var deduped:[String]=[]
            for raw in skills { let nid=Skill.normalizeID(raw); guard !nid.isEmpty, !seen.contains(nid) else { continue }; seen.insert(nid); deduped.append(raw) }
            requiredSkills = deduped
        } else { requiredSkills = [] }
        deliverableIDs = (try? c.decode([String].self, forKey: .deliverableIDs)) ?? []
        prerequisiteStepIDs = (try? c.decode([String].self, forKey: .prerequisiteStepIDs)) ?? []
    }
}

// MARK: - Playbook

struct ProjectPlaybook: Identifiable, Hashable, Codable {
    let id: String // projectID
    var projectID: String { id }
    let overview: String?
    let prerequisites: [ProjectPrerequisite]
    let steps: [ProjectPlaybookStep]
    let resources: [ProjectResource]
    let deliverables: [ProjectDeliverable]
    let completionCriteria: [ProjectCompletionCriterion]
    let estimatedEffort: ProjectEffort?
    let skillsDeveloped: [String]

    init(
        id: String,
        overview: String? = nil,
        prerequisites: [ProjectPrerequisite] = [],
        steps: [ProjectPlaybookStep] = [],
        resources: [ProjectResource] = [],
        deliverables: [ProjectDeliverable] = [],
        completionCriteria: [ProjectCompletionCriterion] = [],
        estimatedEffort: ProjectEffort? = nil,
        skillsDeveloped: [String] = []
    ) {
        self.id = id
        let ov = overview?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.overview = ov?.isEmpty == true ? nil : ov
        self.prerequisites = prerequisites
        // Steps sorted by order deterministic
        self.steps = steps.sorted { $0.order < $1.order }
        self.resources = resources
        self.deliverables = deliverables
        self.completionCriteria = completionCriteria
        self.estimatedEffort = estimatedEffort
        // Normalize skills
        var seen = Set<String>(); var deduped:[String]=[]
        for raw in skillsDeveloped {
            let nid = Skill.normalizeID(raw)
            guard !nid.isEmpty, !seen.contains(nid) else { continue }
            seen.insert(nid); deduped.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        self.skillsDeveloped = deduped
    }

    enum CodingKeys: String, CodingKey { case id, projectID, overview, prerequisites, steps, resources, deliverables, completionCriteria, estimatedEffort, skillsDeveloped }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let pid = try? c.decode(String.self, forKey: .projectID) { id = pid }
        else if let pid = try? c.decode(String.self, forKey: .id) { id = pid }
        else { id = UUID().uuidString }
        overview = try? c.decode(String.self, forKey: .overview)
        prerequisites = (try? c.decode([ProjectPrerequisite].self, forKey: .prerequisites)) ?? []
        steps = (try? c.decode([ProjectPlaybookStep].self, forKey: .steps)) ?? []
        resources = (try? c.decode([ProjectResource].self, forKey: .resources)) ?? []
        deliverables = (try? c.decode([ProjectDeliverable].self, forKey: .deliverables)) ?? []
        completionCriteria = (try? c.decode([ProjectCompletionCriterion].self, forKey: .completionCriteria)) ?? []
        estimatedEffort = try? c.decode(ProjectEffort.self, forKey: .estimatedEffort)
        if let skills = try? c.decode([String].self, forKey: .skillsDeveloped) {
            var seen=Set<String>(); var dd:[String]=[]
            for raw in skills { let nid=Skill.normalizeID(raw); guard !nid.isEmpty, !seen.contains(nid) else { continue }; seen.insert(nid); dd.append(raw) }
            skillsDeveloped = dd
        } else { skillsDeveloped = [] }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(overview, forKey: .overview)
        try c.encode(prerequisites, forKey: .prerequisites)
        try c.encode(steps, forKey: .steps)
        try c.encode(resources, forKey: .resources)
        try c.encode(deliverables, forKey: .deliverables)
        try c.encode(completionCriteria, forKey: .completionCriteria)
        try c.encodeIfPresent(estimatedEffort, forKey: .estimatedEffort)
        try c.encode(skillsDeveloped, forKey: .skillsDeveloped)
    }
}

// MARK: - Validation

enum ProjectPlaybookValidationError: Error, Hashable, CustomStringConvertible {
    case emptyProjectID
    case duplicateStepID(String)
    case missingStepDependency(stepID: String, missing: String)
    case selfDependency(String)
    case circularDependency([String])
    case duplicateDeliverableID(String)
    case missingDeliverableReference(stepID: String, missing: String)
    case invalidResourceURL(resourceID: String, url: String)
    case duplicateResourceID(String)
    case duplicatePrerequisiteID(String)
    case duplicateCriterionID(String)
    case emptyTitle(String)

    var description: String {
        switch self {
        case .emptyProjectID: return "Playbook projectID is empty"
        case .duplicateStepID(let id): return "Duplicate step ID: \(id)"
        case .missingStepDependency(let s, let m): return "Step \(s) references missing prerequisite \(m)"
        case .selfDependency(let s): return "Step \(s) depends on itself"
        case .circularDependency(let cycle): return "Circular dependency: \(cycle.joined(separator: " -> "))"
        case .duplicateDeliverableID(let id): return "Duplicate deliverable ID: \(id)"
        case .missingDeliverableReference(let s, let m): return "Step \(s) references missing deliverable \(m)"
        case .invalidResourceURL(let id, let url): return "Resource \(id) has invalid URL: \(url)"
        case .duplicateResourceID(let id): return "Duplicate resource ID: \(id)"
        case .duplicatePrerequisiteID(let id): return "Duplicate prerequisite ID: \(id)"
        case .duplicateCriterionID(let id): return "Duplicate criterion ID: \(id)"
        case .emptyTitle(let id): return "Empty title for \(id)"
        }
    }
}

enum ProjectPlaybookValidator {
    static func validate(_ playbook: ProjectPlaybook) -> [ProjectPlaybookValidationError] {
        var errors: [ProjectPlaybookValidationError] = []
        if playbook.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyProjectID)
        }
        // Steps
        var stepIDs = Set<String>()
        for step in playbook.steps {
            if step.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyTitle(step.id))
            }
            if step.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyTitle("step:\(step.id)"))
            }
            if !stepIDs.insert(step.id).inserted {
                errors.append(.duplicateStepID(step.id))
            }
            if step.prerequisiteStepIDs.contains(step.id) {
                errors.append(.selfDependency(step.id))
            }
        }
        // Deliverables
        var delivIDs = Set<String>()
        for d in playbook.deliverables {
            if d.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyTitle("deliverable:\(d.id)"))
            }
            if !delivIDs.insert(d.id).inserted {
                errors.append(.duplicateDeliverableID(d.id))
            }
        }
        // Resources
        var resIDs = Set<String>()
        for r in playbook.resources {
            if r.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyTitle("resource:\(r.id)"))
            }
            if !r.isValidURL {
                errors.append(.invalidResourceURL(resourceID: r.id, url: r.url))
            }
            if !resIDs.insert(r.id).inserted {
                errors.append(.duplicateResourceID(r.id))
            }
        }
        // Prerequisites
        var prereqIDs = Set<String>()
        for p in playbook.prerequisites {
            if p.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyTitle("prerequisite:\(p.id)"))
            }
            if !prereqIDs.insert(p.id).inserted {
                errors.append(.duplicatePrerequisiteID(p.id))
            }
        }
        // Criteria
        var critIDs = Set<String>()
        for c in playbook.completionCriteria {
            if c.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyTitle("criterion:\(c.id)"))
            }
            if !critIDs.insert(c.id).inserted {
                errors.append(.duplicateCriterionID(c.id))
            }
        }

        // Reference checks
        for step in playbook.steps {
            for dep in step.prerequisiteStepIDs where !stepIDs.contains(dep) {
                errors.append(.missingStepDependency(stepID: step.id, missing: dep))
            }
            for del in step.deliverableIDs where !delivIDs.contains(del) {
                errors.append(.missingDeliverableReference(stepID: step.id, missing: del))
            }
        }

        // Circular dependency detection (DFS)
        if let cycle = findCycle(in: playbook.steps) {
            errors.append(.circularDependency(cycle))
        }

        return errors
    }

    static func isValid(_ playbook: ProjectPlaybook) -> Bool { validate(playbook).isEmpty }

    private static func findCycle(in steps: [ProjectPlaybookStep]) -> [String]? {
        var graph: [String: [String]] = [:]
        for s in steps { graph[s.id] = s.prerequisiteStepIDs }
        var visited = Set<String>()
        var stack = Set<String>()
        var path: [String] = []
        var found: [String]? = nil

        func dfs(_ node: String) {
            if found != nil { return }
            if stack.contains(node) {
                // cycle found: extract from path
                if let idx = path.firstIndex(of: node) {
                    found = Array(path[idx...]) + [node]
                } else {
                    found = [node, node]
                }
                return
            }
            if visited.contains(node) { return }
            visited.insert(node)
            stack.insert(node)
            path.append(node)
            for neighbor in graph[node] ?? [] {
                dfs(neighbor)
                if found != nil { return }
            }
            stack.remove(node)
            path.removeLast()
        }

        for s in steps where found == nil {
            dfs(s.id)
        }
        return found
    }
}

// MARK: - Service

enum ProjectPlaybookService {
    // Authoritative static playbooks for catalog projects
    private static let playbooks: [String: ProjectPlaybook] = {
        var map: [String: ProjectPlaybook] = [:]
        for pb in makePlaybooks() {
            // Validate on creation (assert in debug, but in production still store only valid)
            let errs = ProjectPlaybookValidator.validate(pb)
            assert(errs.isEmpty, "Invalid playbook \(pb.id): \(errs)")
            map[pb.id] = pb
        }
        return map
    }()

    static func playbook(for projectID: String) -> ProjectPlaybook? {
        let trimmed = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return playbooks[trimmed]
    }

    static var allPlaybooks: [ProjectPlaybook] { Array(playbooks.values).sorted { $0.id < $1.id } }

    static func isAvailable(for projectID: String) -> Bool { playbook(for: projectID) != nil }

    // Prerequisite status evaluation against Student Graph
    static func prerequisiteStatus(
        for prerequisite: ProjectPrerequisite,
        profile: StudentProfile,
        customProjects: [Project] = [],
        roadmapProgress: [String: Int] = [:],
        roadmapCatalog: [Roadmap] = []
    ) -> PrerequisiteStatus {
        switch prerequisite.type {
        case .skill:
            guard let ref = prerequisite.referenceID?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty else { return .unknown }
            let nid = Skill.normalizeID(ref)
            guard !nid.isEmpty else { return .unknown }
            // Demonstrated skills from profile + roadmap progress
            let demonstrated = SkillGapEngine.demonstratedSkillIDs(
                profile: profile,
                roadmapProgress: roadmapProgress,
                catalog: roadmapCatalog.isEmpty ? nil : roadmapCatalog,
                evidenceRecords: nil
            )
            // Also include custom project skills directly (they are added to profile.customSkills on completion, but also check directly)
            var extra = Set<String>()
            for p in customProjects { for s in p.skills { let n=Skill.normalizeID(s); if !n.isEmpty { extra.insert(n) } } }
            let all = demonstrated.union(extra)
            return all.contains(nid) ? .met : .notMet
        case .priorProject:
            guard let ref = prerequisite.referenceID, !ref.isEmpty else { return .unknown }
            // Check if student has a custom project with same ID or same category/title normalized
            let normRef = ref.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            for p in customProjects {
                if p.id == ref { return .met }
                if p.category.lowercased() == normRef { return .met }
                if p.title.lowercased() == normRef { return .met }
            }
            return .notMet
        case .roadmap:
            guard let ref = prerequisite.referenceID, !ref.isEmpty else { return .unknown }
            // Check if roadmap exists and progress >0 or completed
            if let prog = roadmapProgress[ref], prog > 0 { return .met }
            return .notMet
        case .resource, .knowledge:
            return .unknown
        }
    }

    @MainActor
    static func prerequisiteStatus(for prerequisite: ProjectPrerequisite, store: AppDataStore) -> PrerequisiteStatus {
        prerequisiteStatus(
            for: prerequisite,
            profile: store.profile,
            customProjects: store.customProjects,
            roadmapProgress: store.roadmapProgress,
            roadmapCatalog: RoadmapService.allRoadmaps
        )
    }

    // MARK: - Static Playbook Definitions (deterministic, no AI)

    private static func makePlaybooks() -> [ProjectPlaybook] {
        // Plant Health Dashboard
        let plantDeliverables = [
            ProjectDeliverable(id: "plant-deliv-1", title: "Working prototype", description: "A functional analysis or dashboard that demonstrates plant health signals.", format: "code + demo", required: true),
            ProjectDeliverable(id: "plant-deliv-2", title: "Data documentation", description: "Notes on dataset source, contents, and quality checks.", format: "document", required: true),
            ProjectDeliverable(id: "plant-deliv-3", title: "Project README", description: "Explanation of method, result, and next improvement.", format: "markdown", required: true)
        ]
        let plantResources = [
            ProjectResource(id: "plant-res-1", title: "Python Data Notebook Guide", type: .documentation, url: "https://pandas.pydata.org/docs/", description: "Official Pandas docs for inspecting and cleaning tabular data."),
            ProjectResource(id: "plant-res-2", title: "Data Quality Checklist", type: .template, url: "https://example.com/data-quality-checklist", description: "Template for documenting dataset source and limitations."),
            ProjectResource(id: "plant-res-3", title: "Project README Template", type: .template, url: "https://www.makeareadme.com/", description: "Structure for explaining your method and next steps.")
        ]
        let plantSteps = [
            ProjectPlaybookStep(id: "plant-step-1", order: 1, title: "Define the question", description: "Choose the plant signal and audience you want to support. Write a one-sentence problem statement.", objective: "Clear problem definition", estimatedEffort: "45 min", requiredSkills: ["Research"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "plant-step-2", order: 2, title: "Collect and inspect data", description: "Find a small dataset (public or collected) and document what it contains. Check for missing values and quality issues.", objective: "Documented dataset", estimatedEffort: "2–3 hours", requiredSkills: ["Data Collection", "Python"], deliverableIDs: ["plant-deliv-2"], prerequisiteStepIDs: ["plant-step-1"]),
            ProjectPlaybookStep(id: "plant-step-3", order: 3, title: "Build the first version", description: "Create a working analysis or dashboard view that surfaces the plant health insight. Keep scope small and testable.", objective: "Working prototype", estimatedEffort: "1–2 weeks", requiredSkills: ["Python", "Prototyping"], deliverableIDs: ["plant-deliv-1"], prerequisiteStepIDs: ["plant-step-2"]),
            ProjectPlaybookStep(id: "plant-step-4", order: 4, title: "Document the result", description: "Explain the method, result, and next improvement in a concise README. Include limitations and how you would improve with more data.", objective: "Shareable documentation", estimatedEffort: "1 hour", requiredSkills: ["Technical Writing"], deliverableIDs: ["plant-deliv-3"], prerequisiteStepIDs: ["plant-step-3"])
        ]
        let plantCriteria = [
            ProjectCompletionCriterion(id: "plant-crit-1", title: "Core analysis works", description: "The prototype correctly processes the dataset and displays a plant health insight without errors."),
            ProjectCompletionCriterion(id: "plant-crit-2", title: "Data documented", description: "Dataset source, contents, and quality notes are documented."),
            ProjectCompletionCriterion(id: "plant-crit-3", title: "README explains method and next step", description: "README contains method, result, limitations, and one concrete improvement.", required: true)
        ]
        let plantPrereqs = [
            ProjectPrerequisite(id: "plant-pre-1", type: .skill, title: "Python basics", description: "Variables, lists, and basic data handling", referenceID: "python"),
            ProjectPrerequisite(id: "plant-pre-2", type: .skill, title: "Research fundamentals", description: "Finding and evaluating a small dataset", referenceID: "research"),
            ProjectPrerequisite(id: "plant-pre-3", type: .knowledge, title: "Basic data literacy", description: "Understanding what a dataset row/column represents", referenceID: nil)
        ]
        let plantPlaybook = ProjectPlaybook(
            id: "plant-health-dashboard",
            overview: "Combine a real question, a simple data workflow, and a clear interface into a project you can explain and improve.",
            prerequisites: plantPrereqs,
            steps: plantSteps,
            resources: plantResources,
            deliverables: plantDeliverables,
            completionCriteria: plantCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 20, displayText: "2–3 weeks"),
            skillsDeveloped: ["Python", "Research", "Problem Solving", "Communication"]
        )

        // Portfolio Site
        let portfolioDeliverables = [
            ProjectDeliverable(id: "port-deliv-1", title: "Live portfolio site", description: "A published URL showcasing your work.", format: "website", required: true),
            ProjectDeliverable(id: "port-deliv-2", title: "Project case studies", description: "Concise write-ups for work you actually completed.", format: "markdown", required: true),
            ProjectDeliverable(id: "port-deliv-3", title: "Accessible navigation", description: "Site passes basic accessibility checks.", format: "checklist", required: false)
        ]
        let portfolioResources = [
            ProjectResource(id: "port-res-1", title: "Portfolio Case Study Template", type: .template, url: "https://example.com/portfolio-template", description: "Outline for describing problem, approach, and outcome."),
            ProjectResource(id: "port-res-2", title: "Accessibility Checklist", type: .reference, url: "https://www.w3.org/WAI/standards-guidelines/wcag/", description: "WCAG basics for making your site usable."),
            ProjectResource(id: "port-res-3", title: "GitHub Pages Docs", type: .documentation, url: "https://docs.github.com/en/pages", description: "Publishing a static site for free.")
        ]
        let portfolioSteps = [
            ProjectPlaybookStep(id: "port-step-1", order: 1, title: "Plan the story", description: "Choose what you want visitors to understand about you. List 2–3 projects to feature and the narrative that connects them.", estimatedEffort: "30 min", requiredSkills: ["Planning"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "port-step-2", order: 2, title: "Build the structure", description: "Create the pages and navigation for your first version. Focus on clear information hierarchy before styling.", estimatedEffort: "2–4 days", requiredSkills: ["Web Development"], deliverableIDs: [], prerequisiteStepIDs: ["port-step-1"]),
            ProjectPlaybookStep(id: "port-step-3", order: 3, title: "Add project evidence", description: "Write concise case studies for work you actually completed. Link to demos, repos, or artifacts where available.", estimatedEffort: "2–3 days", requiredSkills: ["Writing", "Technical Communication"], deliverableIDs: ["port-deliv-2"], prerequisiteStepIDs: ["port-step-2"]),
            ProjectPlaybookStep(id: "port-step-4", order: 4, title: "Publish and review", description: "Share the site and improve it from feedback. Test on mobile and run an accessibility check.", estimatedEffort: "1 day", requiredSkills: ["Communication"], deliverableIDs: ["port-deliv-1", "port-deliv-3"], prerequisiteStepIDs: ["port-step-3"])
        ]
        let portfolioCriteria = [
            ProjectCompletionCriterion(id: "port-crit-1", title: "Site is live", description: "Portfolio is accessible via a public URL."),
            ProjectCompletionCriterion(id: "port-crit-2", title: "Case studies explain projects", description: "At least two case studies describe what you did and what changed."),
            ProjectCompletionCriterion(id: "port-crit-3", title: "Navigation is clear", description: "Visitors can find projects in under 30 seconds.")
        ]
        let portfolioPrereqs = [
            ProjectPrerequisite(id: "port-pre-1", type: .skill, title: "Writing", referenceID: "writing"),
            ProjectPrerequisite(id: "port-pre-2", type: .knowledge, title: "Basic web structure", description: "Understanding of pages and navigation", referenceID: nil)
        ]
        let portfolioPlaybook = ProjectPlaybook(
            id: "portfolio-site",
            overview: "Turn your work into a clear, navigable story that a mentor, program, or college can understand quickly.",
            prerequisites: portfolioPrereqs,
            steps: portfolioSteps,
            resources: portfolioResources,
            deliverables: portfolioDeliverables,
            completionCriteria: portfolioCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 15, displayText: "1–2 weeks"),
            skillsDeveloped: ["Programming", "Writing", "Design", "Communication"]
        )

        // Sensor Study
        let sensorDeliverables = [
            ProjectDeliverable(id: "sensor-deliv-1", title: "Clean dataset", description: "Organized observations ready for analysis.", required: true),
            ProjectDeliverable(id: "sensor-deliv-2", title: "Analysis summary", description: "Patterns found without overstating results.", required: true),
            ProjectDeliverable(id: "sensor-deliv-3", title: "Short report", description: "Evidence, limits, and next question.", format: "report", required: true)
        ]
        let sensorResources = [
            ProjectResource(id: "sensor-res-1", title: "Research Question Guide", type: .reference, url: "https://example.com/research-guide", description: "How to frame a measurable question."),
            ProjectResource(id: "sensor-res-2", title: "Data Visualization Examples", type: .tutorial, url: "https://matplotlib.org/stable/tutorials/index.html", description: "Matplotlib tutorials for visualizing small datasets."),
            ProjectResource(id: "sensor-res-3", title: "Short Report Template", type: .template, url: "https://example.com/report-template", description: "Structure for communicating evidence and limits.")
        ]
        let sensorSteps = [
            ProjectPlaybookStep(id: "sensor-step-1", order: 1, title: "Choose a measurable question", description: "Define what you want to learn and how you will observe it. Write the question and the measurement plan.", estimatedEffort: "1 hour", requiredSkills: ["Research"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "sensor-step-2", order: 2, title: "Prepare the data", description: "Clean and organize the observations for analysis. Document cleaning decisions.", estimatedEffort: "2–3 hours", requiredSkills: ["Data Collection"], deliverableIDs: ["sensor-deliv-1"], prerequisiteStepIDs: ["sensor-step-1"]),
            ProjectPlaybookStep(id: "sensor-step-3", order: 3, title: "Analyze and interpret", description: "Look for patterns without overstating the result. Create one visualization that supports your interpretation.", estimatedEffort: "1 week", requiredSkills: ["Python", "Data Analysis"], deliverableIDs: ["sensor-deliv-2"], prerequisiteStepIDs: ["sensor-step-2"]),
            ProjectPlaybookStep(id: "sensor-step-4", order: 4, title: "Share a short report", description: "Communicate the evidence, limits, and next question. Share with one peer for feedback.", estimatedEffort: "2–3 hours", requiredSkills: ["Scientific Communication"], deliverableIDs: ["sensor-deliv-3"], prerequisiteStepIDs: ["sensor-step-3"])
        ]
        let sensorCriteria = [
            ProjectCompletionCriterion(id: "sensor-crit-1", title: "Question is measurable", description: "Report states a clear, observable question."),
            ProjectCompletionCriterion(id: "sensor-crit-2", title: "Data is prepared", description: "Dataset is cleaned and organized with notes."),
            ProjectCompletionCriterion(id: "sensor-crit-3", title: "Analysis is responsible", description: "Interpretation does not overstate beyond evidence and notes limits.")
        ]
        let sensorPrereqs = [
            ProjectPrerequisite(id: "sensor-pre-1", type: .skill, title: "Research methods", referenceID: "research"),
            ProjectPrerequisite(id: "sensor-pre-2", type: .skill, title: "Python basics", referenceID: "python")
        ]
        let sensorPlaybook = ProjectPlaybook(
            id: "sensor-study",
            overview: "Practice the complete research loop: question, evidence, analysis, and a responsible explanation of limits.",
            prerequisites: sensorPrereqs,
            steps: sensorSteps,
            resources: sensorResources,
            deliverables: sensorDeliverables,
            completionCriteria: sensorCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 12, displayText: "1–2 weeks"),
            skillsDeveloped: ["Research", "Python", "Mathematics", "Writing"]
        )

        // Community Problem Prototype
        let communityDeliverables = [
            ProjectDeliverable(id: "comm-deliv-1", title: "Problem framing notes", description: "What the community actually needs before building.", required: true),
            ProjectDeliverable(id: "comm-deliv-2", title: "Low-cost prototype", description: "A concrete, testable version of the idea.", format: "prototype", required: true),
            ProjectDeliverable(id: "comm-deliv-3", title: "Feedback log", description: "Record of what you learned from testing with feedback.", required: true)
        ]
        let communityResources = [
            ProjectResource(id: "comm-res-1", title: "Interview Question Prompts", type: .template, url: "https://example.com/interview-prompts", description: "Questions for learning community needs before building."),
            ProjectResource(id: "comm-res-2", title: "Prototype Planning Canvas", type: .template, url: "https://example.com/prototype-canvas", description: "Canvas for making the first idea concrete."),
            ProjectResource(id: "comm-res-3", title: "Feedback Log Template", type: .template, url: "https://example.com/feedback-log", description: "Structured log for recording what you learn.")
        ]
        let communitySteps = [
            ProjectPlaybookStep(id: "comm-step-1", order: 1, title: "Listen and frame", description: "Learn what the community actually needs before building. Interview 2–3 people affected.", estimatedEffort: "1 week", requiredSkills: ["Community Research", "Empathy"], deliverableIDs: ["comm-deliv-1"], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "comm-step-2", order: 2, title: "Sketch a solution", description: "Make the first idea concrete and easy to discuss. Create a simple sketch or storyboard.", estimatedEffort: "2 hours", requiredSkills: ["Design"], deliverableIDs: [], prerequisiteStepIDs: ["comm-step-1"]),
            ProjectPlaybookStep(id: "comm-step-3", order: 3, title: "Test with feedback", description: "Share a low-cost version and record what you learn. Note what worked and what to change.", estimatedEffort: "1 week", requiredSkills: ["Communication", "Iteration"], deliverableIDs: ["comm-deliv-2", "comm-deliv-3"], prerequisiteStepIDs: ["comm-step-2"])
        ]
        let communityCriteria = [
            ProjectCompletionCriterion(id: "comm-crit-1", title: "Needs understood", description: "Notes show you listened to the community before building."),
            ProjectCompletionCriterion(id: "comm-crit-2", title: "Prototype tested", description: "A low-cost version was shared and feedback recorded."),
            ProjectCompletionCriterion(id: "comm-crit-3", title: "Next improvement identified", description: "Feedback log contains at least one concrete next change.")
        ]
        let communityPrereqs = [
            ProjectPrerequisite(id: "comm-pre-1", type: .knowledge, title: "Community empathy", description: "Willingness to listen before solving", referenceID: nil),
            ProjectPrerequisite(id: "comm-pre-2", type: .skill, title: "Communication", referenceID: "communication")
        ]
        let communityPlaybook = ProjectPlaybook(
            id: "community-problem",
            overview: "Work from lived observation to a testable idea, then learn by listening to the people affected.",
            prerequisites: communityPrereqs,
            steps: communitySteps,
            resources: communityResources,
            deliverables: communityDeliverables,
            completionCriteria: communityCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 25, displayText: "2–3 weeks"),
            skillsDeveloped: ["Leadership", "Design", "Communication", "Teamwork"]
        )

        // MARK: - Data Structures Visualizer
        let dsVisDeliverables = [
            ProjectDeliverable(id: "ds-vis-deliv-1", title: "Data structure implementations", description: "Clean Python/JS implementations of linked list, stack, and BST with basic tests.", format: "code + tests", required: true),
            ProjectDeliverable(id: "ds-vis-deliv-2", title: "Interactive visualizer", description: "UI that lets users insert/delete/search and see step-by-step state.", format: "interactive demo", required: true),
            ProjectDeliverable(id: "ds-vis-deliv-3", title: "Complexity & demo docs", description: "README with operation table, examples, and a 2-min demo recording.", format: "markdown + video", required: true)
        ]
        let dsVisResources = [
            ProjectResource(id: "ds-vis-res-1", title: "VisuAlgo — Data Structure Visualizations", type: .reference, url: "https://visualgo.net/en", description: "Interactive visualizations of lists, stacks, trees, and sorting."),
            ProjectResource(id: "ds-vis-res-2", title: "Python Data Structures Tutorial — Real Python", type: .tutorial, url: "https://realpython.com/python-data-structures/", description: "Practical guide to lists, stacks, queues, and trees in Python."),
            ProjectResource(id: "ds-vis-res-3", title: "Big-O Cheat Sheet", type: .reference, url: "https://www.bigocheatsheet.com/", description: "Quick reference for time complexity of common structures.")
        ]
        let dsVisSteps = [
            ProjectPlaybookStep(id: "ds-vis-step-1", order: 1, title: "Design the operations", description: "Choose linked list, stack, and BST. List supported operations (insert, delete, search, traverse) and edge cases. Sketch the visual layout.", objective: "Clear operation spec", estimatedEffort: "1 hour", requiredSkills: ["Planning"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "ds-vis-step-2", order: 2, title: "Implement clean structures", description: "Code each structure without UI. Add simple tests for edge cases (empty, single node, duplicates). Keep functions small and readable.", objective: "Tested core logic", estimatedEffort: "1–2 weeks", requiredSkills: ["Data Structures", "Python"], deliverableIDs: ["ds-vis-deliv-1"], prerequisiteStepIDs: ["ds-vis-step-1"]),
            ProjectPlaybookStep(id: "ds-vis-step-3", order: 3, title: "Build interactive view", description: "Render structures with HTML/Canvas or terminal animation. Add controls for insert/delete/search and highlight the affected nodes at each step.", objective: "Working visualizer", estimatedEffort: "1–2 weeks", requiredSkills: ["Prototyping", "JavaScript"], deliverableIDs: ["ds-vis-deliv-2"], prerequisiteStepIDs: ["ds-vis-step-2"]),
            ProjectPlaybookStep(id: "ds-vis-step-4", order: 4, title: "Document and demo", description: "Write README with how to run, complexity table (O(1), O(log n), O(n)), examples, and a 2-min screen recording walking through each structure.", objective: "Shareable demo", estimatedEffort: "2 hours", requiredSkills: ["Technical Writing"], deliverableIDs: ["ds-vis-deliv-3"], prerequisiteStepIDs: ["ds-vis-step-3"])
        ]
        let dsVisCriteria = [
            ProjectCompletionCriterion(id: "ds-vis-crit-1", title: "Three structures work", description: "Linked list, stack, and BST support insert/delete/search without crashes."),
            ProjectCompletionCriterion(id: "ds-vis-crit-2", title: "Visualization is accurate", description: "UI correctly reflects the underlying structure after each operation."),
            ProjectCompletionCriterion(id: "ds-vis-crit-3", title: "Demo explains trade-offs", description: "README includes complexity table and when to use each structure.")
        ]
        let dsVisPrereqs = [
            ProjectPrerequisite(id: "ds-vis-pre-1", type: .skill, title: "Python basics", description: "Variables, lists, and functions", referenceID: "python"),
            ProjectPrerequisite(id: "ds-vis-pre-2", type: .skill, title: "Problem solving basics", description: "Breaking a task into small functions", referenceID: "problem solving"),
            ProjectPrerequisite(id: "ds-vis-pre-3", type: .knowledge, title: "Big-O intuition", description: "Idea that some operations are faster than others", referenceID: nil)
        ]
        let dsVisPlaybook = ProjectPlaybook(
            id: "ds-visualizer",
            overview: "Make data structures tangible — build a visual, interactive tool you can demo to classmates and mentors.",
            prerequisites: dsVisPrereqs,
            steps: dsVisSteps,
            resources: dsVisResources,
            deliverables: dsVisDeliverables,
            completionCriteria: dsVisCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 22, displayText: "2–3 weeks"),
            skillsDeveloped: ["Data Structures", "Python", "Problem Solving", "Technical Communication"]
        )

        // MARK: - CLI Task Manager with Git History
        let cliDeliverables = [
            ProjectDeliverable(id: "cli-deliv-1", title: "CLI commands working", description: "Add, list, complete, and archive tasks persisted to JSON.", format: "code", required: true),
            ProjectDeliverable(id: "cli-deliv-2", title: "Clean Git history", description: "Log shows meaningful commits, a feature branch, and a pull request.", format: "git log", required: true),
            ProjectDeliverable(id: "cli-deliv-3", title: "User guide", description: "README with install, usage examples, and help text.", format: "markdown", required: true)
        ]
        let cliResources = [
            ProjectResource(id: "cli-res-1", title: "GitHub Skills — Interactive Git", type: .course, url: "https://skills.github.com/", description: "Hands-on Git exercises: branching, commits, and pull requests."),
            ProjectResource(id: "cli-res-2", title: "Command Line Interface Guidelines", type: .reference, url: "https://clig.dev/", description: "Principles for designing humane, consistent CLI tools."),
            ProjectResource(id: "cli-res-3", title: "Python Argparse Tutorial", type: .documentation, url: "https://docs.python.org/3/howto/argparse.html", description: "Official guide to building CLIs with argparse.")
        ]
        let cliSteps = [
            ProjectPlaybookStep(id: "cli-step-1", order: 1, title: "Design the CLI", description: "Define commands (add/list/complete/archive), flags, and the JSON storage format. Sketch example usage.", estimatedEffort: "1 hour", requiredSkills: ["Planning"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "cli-step-2", order: 2, title: "Implement core commands", description: "Build add/list/complete/archive with file persistence, input validation, and --help output. Save tasks to tasks.json.", estimatedEffort: "1 week", requiredSkills: ["Python", "Software Development"], deliverableIDs: ["cli-deliv-1"], prerequisiteStepIDs: ["cli-step-1"]),
            ProjectPlaybookStep(id: "cli-step-3", order: 3, title: "Practice Git workflow", description: "Create a feature branch, make 5+ meaningful commits, and open a pull request for one feature. Write helpful commit messages.", estimatedEffort: "3–4 days", requiredSkills: ["Git", "Version Control Basics"], deliverableIDs: ["cli-deliv-2"], prerequisiteStepIDs: ["cli-step-2"]),
            ProjectPlaybookStep(id: "cli-step-4", order: 4, title: "Polish and release", description: "Add --help text, error messages, README with install steps, and a short terminal demo GIF.", estimatedEffort: "1 day", requiredSkills: ["Technical Writing"], deliverableIDs: ["cli-deliv-3"], prerequisiteStepIDs: ["cli-step-3"])
        ]
        let cliCriteria = [
            ProjectCompletionCriterion(id: "cli-crit-1", title: "Commands work reliably", description: "All four commands handle normal and invalid input without data loss."),
            ProjectCompletionCriterion(id: "cli-crit-2", title: "History is meaningful", description: "Git log shows logical commits and a merged branch."),
            ProjectCompletionCriterion(id: "cli-crit-3", title: "Guide lets others run it", description: "README lets a peer run the tool in under 3 minutes.")
        ]
        let cliPrereqs = [
            ProjectPrerequisite(id: "cli-pre-1", type: .skill, title: "Python basics", referenceID: "python"),
            ProjectPrerequisite(id: "cli-pre-2", type: .skill, title: "Git basics", referenceID: "git")
        ]
        let cliPlaybook = ProjectPlaybook(
            id: "cli-task-manager",
            overview: "Build a CLI you actually use — and demonstrate a professional Git workflow alongside it.",
            prerequisites: cliPrereqs,
            steps: cliSteps,
            resources: cliResources,
            deliverables: cliDeliverables,
            completionCriteria: cliCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 15, displayText: "1–2 weeks"),
            skillsDeveloped: ["Git", "Version Control Basics", "Software Development", "Project Planning"]
        )

        // MARK: - Habit Tracker REST API
        let habitDeliverables = [
            ProjectDeliverable(id: "habit-deliv-1", title: "Working API", description: "REST endpoints for habits, entries, and streaks with validation and persistence.", format: "API", required: true),
            ProjectDeliverable(id: "habit-deliv-2", title: "Unit test suite", description: "Tests covering success paths, errors, and edge cases.", format: "tests", required: true),
            ProjectDeliverable(id: "habit-deliv-3", title: "API documentation", description: "Short docs with endpoint list and curl examples.", format: "markdown", required: true)
        ]
        let habitResources = [
            ProjectResource(id: "habit-res-1", title: "MDN HTTP Overview", type: .documentation, url: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Overview", description: "How HTTP methods, status codes, and headers work."),
            ProjectResource(id: "habit-res-2", title: "REST API Design Checklist", type: .reference, url: "https://www.freecodecamp.org/news/rest-api-design-best-practices-build-a-rest-api/", description: "Best practices for resource naming, status codes, and validation."),
            ProjectResource(id: "habit-res-3", title: "pytest Getting Started", type: .documentation, url: "https://docs.pytest.org/en/stable/getting-started.html", description: "Writing and running unit tests in Python."),
            ProjectResource(id: "habit-res-4", title: "Jest Getting Started", type: .documentation, url: "https://jestjs.io/docs/getting-started", description: "JavaScript testing with Jest.")
        ]
        let habitSteps = [
            ProjectPlaybookStep(id: "habit-step-1", order: 1, title: "Design the API", description: "Sketch resources (/habits, /entries), HTTP methods, status codes, and JSON shape for habits and streaks.", estimatedEffort: "1 hour", requiredSkills: ["Planning"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "habit-step-2", order: 2, title: "Build the server", description: "Implement CRUD, input validation, and persistence (JSON file or SQLite). Add clear error messages.", estimatedEffort: "1–2 weeks", requiredSkills: ["APIs", "Software Development"], deliverableIDs: ["habit-deliv-1"], prerequisiteStepIDs: ["habit-step-1"]),
            ProjectPlaybookStep(id: "habit-step-3", order: 3, title: "Write tests and debug", description: "Write unit tests for each endpoint. Use the debugger to find and fix at least two bugs rather than print statements.", estimatedEffort: "1 week", requiredSkills: ["Unit Testing", "Debugging"], deliverableIDs: ["habit-deliv-2"], prerequisiteStepIDs: ["habit-step-2"]),
            ProjectPlaybookStep(id: "habit-step-4", order: 4, title: "Document and demo", description: "Publish a one-page API guide with endpoint table and curl/HTTPie examples. Record a short demo showing a habit streak updating.", estimatedEffort: "2 hours", requiredSkills: ["Technical Writing"], deliverableIDs: ["habit-deliv-3"], prerequisiteStepIDs: ["habit-step-3"])
        ]
        let habitCriteria = [
            ProjectCompletionCriterion(id: "habit-crit-1", title: "Endpoints behave correctly", description: "CRUD for habits and entries works with proper status codes and validation."),
            ProjectCompletionCriterion(id: "habit-crit-2", title: "Tests protect behavior", description: "At least 8 tests pass and cover errors and edge cases."),
            ProjectCompletionCriterion(id: "habit-crit-3", title: "Docs let a peer call the API", description: "Documentation lets someone create a habit with one curl command.")
        ]
        let habitPrereqs = [
            ProjectPrerequisite(id: "habit-pre-1", type: .skill, title: "Programming fundamentals", referenceID: "programming fundamentals"),
            ProjectPrerequisite(id: "habit-pre-2", type: .skill, title: "Python or JavaScript basics", referenceID: "python")
        ]
        let habitPlaybook = ProjectPlaybook(
            id: "habit-tracker-api",
            overview: "Go from API sketch to tested service — a real backend you can demo with curl.",
            prerequisites: habitPrereqs,
            steps: habitSteps,
            resources: habitResources,
            deliverables: habitDeliverables,
            completionCriteria: habitCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 22, displayText: "2–3 weeks"),
            skillsDeveloped: ["APIs", "Unit Testing", "Debugging", "JavaScript", "Software Development"]
        )

        // MARK: - Algorithm Performance Lab
        let algoLabDeliverables = [
            ProjectDeliverable(id: "algo-deliv-1", title: "Algorithm implementations", description: "Correct implementations of 4 sorts and 2 searches with verification tests.", required: true),
            ProjectDeliverable(id: "algo-deliv-2", title: "Benchmark harness", description: "Script that generates inputs and times each algorithm across sizes.", format: "code", required: true),
            ProjectDeliverable(id: "algo-deliv-3", title: "Performance report", description: "Charts (time vs n) annotated with big-O and a written analysis.", format: "report", required: true)
        ]
        let algoLabResources = [
            ProjectResource(id: "algo-res-1", title: "Big O Cheat Sheet", type: .reference, url: "https://www.bigocheatsheet.com/", description: "Complexity charts for sorting and searching."),
            ProjectResource(id: "algo-res-2", title: "Matplotlib Tutorial", type: .tutorial, url: "https://matplotlib.org/stable/tutorials/index.html", description: "Creating line and bar charts from benchmark data."),
            ProjectResource(id: "algo-res-3", title: "Python timeit Docs", type: .documentation, url: "https://docs.python.org/3/library/timeit.html", description: "Reliable timing for small code snippets.")
        ]
        let algoLabSteps = [
            ProjectPlaybookStep(id: "algo-step-1", order: 1, title: "Implement algorithms", description: "Code bubble, merge, quick, and insertion sort plus linear and binary search. Verify correctness on random inputs.", estimatedEffort: "1 week", requiredSkills: ["Data Structures", "Python"], deliverableIDs: ["algo-deliv-1"], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "algo-step-2", order: 2, title: "Build benchmark harness", description: "Generate inputs of increasing size (100 to 10k) and time each algorithm with timeit. Avoid measuring setup code.", estimatedEffort: "3 days", requiredSkills: ["Python", "Data Collection"], deliverableIDs: ["algo-deliv-2"], prerequisiteStepIDs: ["algo-step-1"]),
            ProjectPlaybookStep(id: "algo-step-3", order: 3, title: "Visualize results", description: "Plot time vs n for each algorithm. Annotate where O(n²) clearly diverges from O(n log n). Add a table of results.", estimatedEffort: "2–3 days", requiredSkills: ["Data Analysis", "Mathematics"], deliverableIDs: [], prerequisiteStepIDs: ["algo-step-2"]),
            ProjectPlaybookStep(id: "algo-step-4", order: 4, title: "Write analysis report", description: "Explain when each algorithm wins, why binary search requires sorted data, and limits of your benchmark.", estimatedEffort: "2 hours", requiredSkills: ["Technical Writing"], deliverableIDs: ["algo-deliv-3"], prerequisiteStepIDs: ["algo-step-3"])
        ]
        let algoLabCriteria = [
            ProjectCompletionCriterion(id: "algo-crit-1", title: "Algorithms are correct", description: "Each sorting algorithm produces sorted output on random tests."),
            ProjectCompletionCriterion(id: "algo-crit-2", title: "Benchmark is fair", description: "Timings exclude I/O and are averaged over multiple runs."),
            ProjectCompletionCriterion(id: "algo-crit-3", title: "Report explains trade-offs", description: "Report links observed times to big-O expectations with caveats.")
        ]
        let algoLabPrereqs = [
            ProjectPrerequisite(id: "algo-pre-1", type: .skill, title: "Python basics", referenceID: "python"),
            ProjectPrerequisite(id: "algo-pre-2", type: .skill, title: "Data structures intro", referenceID: "data structures"),
            ProjectPrerequisite(id: "algo-pre-3", type: .knowledge, title: "Big-O intuition", referenceID: nil)
        ]
        let algoLabPlaybook = ProjectPlaybook(
            id: "algo-performance-lab",
            overview: "See big-O in action — measure it, chart it, and explain it.",
            prerequisites: algoLabPrereqs,
            steps: algoLabSteps,
            resources: algoLabResources,
            deliverables: algoLabDeliverables,
            completionCriteria: algoLabCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 20, displayText: "2–3 weeks"),
            skillsDeveloped: ["Data Structures", "Python", "Data Analysis", "Mathematics"]
        )

        // MARK: - Personal Finance Data Analyzer
        let financeDeliverables = [
            ProjectDeliverable(id: "fin-deliv-1", title: "Clean finance dataset", description: "CSV with fixed types, handled missing values, and notes on cleaning.", required: true),
            ProjectDeliverable(id: "fin-deliv-2", title: "Analysis & visuals", description: "4–5 charts answering 3 money questions (spending by category, trends, etc).", format: "charts", required: true),
            ProjectDeliverable(id: "fin-deliv-3", title: "Insight report", description: "One-page report with findings, limits, and one actionable insight.", format: "report", required: true)
        ]
        let financeResources = [
            ProjectResource(id: "fin-res-1", title: "Kaggle Learn: Pandas", type: .course, url: "https://www.kaggle.com/learn/pandas", description: "Hands-on Pandas for cleaning and analyzing tabular data."),
            ProjectResource(id: "fin-res-2", title: "Pandas Documentation", type: .documentation, url: "https://pandas.pydata.org/docs/", description: "Reference for DataFrame operations."),
            ProjectResource(id: "fin-res-3", title: "Data Storytelling Guide", type: .reference, url: "https://www.storytellingwithdata.com/blog", description: "How to turn charts into a clear narrative.")
        ]
        let financeSteps = [
            ProjectPlaybookStep(id: "fin-step-1", order: 1, title: "Find and inspect data", description: "Pick a personal finance export or a public budget CSV. Document columns, rows, and any sensitive fields to exclude.", estimatedEffort: "1 hour", requiredSkills: ["Research"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "fin-step-2", order: 2, title: "Clean the dataset", description: "Handle missing values, fix types, remove duplicates, and document every cleaning choice.", estimatedEffort: "2–3 hours", requiredSkills: ["Python", "Data Collection"], deliverableIDs: ["fin-deliv-1"], prerequisiteStepIDs: ["fin-step-1"]),
            ProjectPlaybookStep(id: "fin-step-3", order: 3, title: "Analyze and visualize", description: "Answer 3 questions (e.g., top category, monthly trend, average transaction) with grouping and 4 charts.", estimatedEffort: "1 week", requiredSkills: ["Data Analysis", "Statistics"], deliverableIDs: ["fin-deliv-2"], prerequisiteStepIDs: ["fin-step-2"]),
            ProjectPlaybookStep(id: "fin-step-4", order: 4, title: "Publish a report", description: "Write a one-page report with your chart insights, limits, and one recommendation you would act on.", estimatedEffort: "2 hours", requiredSkills: ["Technical Communication"], deliverableIDs: ["fin-deliv-3"], prerequisiteStepIDs: ["fin-step-3"])
        ]
        let financeCriteria = [
            ProjectCompletionCriterion(id: "fin-crit-1", title: "Data is clean and documented", description: "Dataset has documented cleaning steps and no obvious type errors."),
            ProjectCompletionCriterion(id: "fin-crit-2", title: "Charts answer real questions", description: "At least 3 charts each answer a specific question with correct aggregations."),
            ProjectCompletionCriterion(id: "fin-crit-3", title: "Report has a takeaway", description: "Report closes with one actionable insight and a limit note.")
        ]
        let financePrereqs = [
            ProjectPrerequisite(id: "fin-pre-1", type: .skill, title: "Python basics", referenceID: "python"),
            ProjectPrerequisite(id: "fin-pre-2", type: .knowledge, title: "Basic budgeting familiarity", referenceID: nil)
        ]
        let financePlaybook = ProjectPlaybook(
            id: "finance-data-analyzer",
            overview: "Turn a messy money CSV into clear answers — and one decision you can act on.",
            prerequisites: financePrereqs,
            steps: financeSteps,
            resources: financeResources,
            deliverables: financeDeliverables,
            completionCriteria: financeCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 14, displayText: "1–2 weeks"),
            skillsDeveloped: ["Python", "Data Analysis", "Statistics", "Technical Communication"]
        )

        // MARK: - Campus FAQ Chatbot
        let chatbotDeliverables = [
            ProjectDeliverable(id: "chat-deliv-1", title: "FAQ dataset", description: "30–50 real Q&A pairs from your school or community.", format: "csv/json", required: true),
            ProjectDeliverable(id: "chat-deliv-2", title: "Working chatbot", description: "Rule-based baseline plus an ML-ranked version with accuracy comparison.", format: "code + demo", required: true),
            ProjectDeliverable(id: "chat-deliv-3", title: "Evaluation note", description: "Short note with accuracy, example successes/failures, and next improvement.", format: "report", required: true)
        ]
        let chatbotResources = [
            ProjectResource(id: "chat-res-1", title: "Scikit-learn: Working With Text Data", type: .tutorial, url: "https://scikit-learn.org/stable/tutorial/text_analytics/working_with_text_data.html", description: "TF-IDF and text classification workflow."),
            ProjectResource(id: "chat-res-2", title: "Streamlit Get Started", type: .documentation, url: "https://docs.streamlit.io/library/get-started/create-an-app", description: "Build a simple web UI for your bot in minutes."),
            ProjectResource(id: "chat-res-3", title: "Chatbot Evaluation Guide", type: .reference, url: "https://developers.google.com/machine-learning/guides/text-classification/step-3", description: "How to evaluate text models beyond accuracy.")
        ]
        let chatbotSteps = [
            ProjectPlaybookStep(id: "chat-step-1", order: 1, title: "Collect FAQ data", description: "Gather 30–50 question-answer pairs from school site, handbook, or interviews. Deduplicate and label clearly.", estimatedEffort: "2 hours", requiredSkills: ["Data Collection"], deliverableIDs: ["chat-deliv-1"], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "chat-step-2", order: 2, title: "Build rule-based baseline", description: "Implement keyword matching for top queries. Measure baseline accuracy on a held-out set.", estimatedEffort: "1 week", requiredSkills: ["Python", "AI Literacy"], deliverableIDs: [], prerequisiteStepIDs: ["chat-step-1"]),
            ProjectPlaybookStep(id: "chat-step-3", order: 3, title: "Try ML ranking", description: "Vectorize questions with TF-IDF or embeddings, rank answers by cosine similarity, and compare to baseline.", estimatedEffort: "1 week", requiredSkills: ["Machine Learning", "Python"], deliverableIDs: ["chat-deliv-2"], prerequisiteStepIDs: ["chat-step-2"]),
            ProjectPlaybookStep(id: "chat-step-4", order: 4, title: "Ship a demo UI", description: "Add a Streamlit or simple web UI that shows the question, answer, and confidence. Write a brief evaluation note.", estimatedEffort: "1 day", requiredSkills: ["Technical Communication"], deliverableIDs: ["chat-deliv-3"], prerequisiteStepIDs: ["chat-step-3"])
        ]
        let chatbotCriteria = [
            ProjectCompletionCriterion(id: "chat-crit-1", title: "FAQ covers real need", description: "At least 30 pairs are real questions from your audience."),
            ProjectCompletionCriterion(id: "chat-crit-2", title: "Two approaches compared", description: "Baseline and ML version have measured accuracy on same test set."),
            ProjectCompletionCriterion(id: "chat-crit-3", title: "Demo is usable", description: "A peer can ask a new question and get a relevant answer.")
        ]
        let chatbotPrereqs = [
            ProjectPrerequisite(id: "chat-pre-1", type: .skill, title: "Python basics", referenceID: "python"),
            ProjectPrerequisite(id: "chat-pre-2", type: .knowledge, title: "Curiosity about AI", referenceID: nil)
        ]
        let chatbotPlaybook = ProjectPlaybook(
            id: "campus-faq-chatbot",
            overview: "Help your community get answers faster — and learn how AI compares to rules.",
            prerequisites: chatbotPrereqs,
            steps: chatbotSteps,
            resources: chatbotResources,
            deliverables: chatbotDeliverables,
            completionCriteria: chatbotCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 20, displayText: "2–3 weeks"),
            skillsDeveloped: ["Python", "Machine Learning", "AI Literacy", "Technical Communication"]
        )

        // MARK: - Image Classifier — Pets vs Wildlife
        let imgDeliverables = [
            ProjectDeliverable(id: "img-deliv-1", title: "Labeled dataset split", description: "Organized train/test splits with balanced classes and documented source.", format: "dataset", required: true),
            ProjectDeliverable(id: "img-deliv-2", title: "Two trained models", description: "Baseline plus a stronger model with training metrics.", format: "models + logs", required: true),
            ProjectDeliverable(id: "img-deliv-3", title: "Model card", description: "One-page card with accuracy, confusion matrix, limits, and ethical note.", format: "report", required: true)
        ]
        let imgResources = [
            ProjectResource(id: "img-res-1", title: "Google ML Crash Course", type: .course, url: "https://developers.google.com/machine-learning/crash-course", description: "Free intro to training and evaluating ML models."),
            ProjectResource(id: "img-res-2", title: "Teachable Machine", type: .tool, url: "https://teachablemachine.withgoogle.com/", description: "Quick way to try image training without heavy setup."),
            ProjectResource(id: "img-res-3", title: "Scikit-learn Image Tutorial", type: .tutorial, url: "https://scikit-learn.org/stable/auto_examples/index.html", description: "Examples for working with image data in scikit-learn.")
        ]
        let imgSteps = [
            ProjectPlaybookStep(id: "img-step-1", order: 1, title: "Prepare the dataset", description: "Collect or download pet/wildlife images (50+ per class), organize folders, and split train/test without leakage.", estimatedEffort: "2–3 hours", requiredSkills: ["Data Collection"], deliverableIDs: ["img-deliv-1"], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "img-step-2", order: 2, title: "Train two models", description: "Train a simple baseline (e.g., color histogram or small CNN) and one stronger model (transfer or augmentation). Track training/validation scores.", estimatedEffort: "1–2 weeks", requiredSkills: ["Machine Learning", "Python"], deliverableIDs: ["img-deliv-2"], prerequisiteStepIDs: ["img-step-1"]),
            ProjectPlaybookStep(id: "img-step-3", order: 3, title: "Evaluate responsibly", description: "Compute accuracy, precision/recall, and a confusion matrix. Identify one failure mode with examples.", estimatedEffort: "1 day", requiredSkills: ["Model Evaluation", "Data Analysis"], deliverableIDs: [], prerequisiteStepIDs: ["img-step-2"]),
            ProjectPlaybookStep(id: "img-step-4", order: 4, title: "Publish model card", description: "Share a one-page model card covering intended use, performance, limits, and what you would improve with more data.", estimatedEffort: "2 hours", requiredSkills: ["Technical Writing"], deliverableIDs: ["img-deliv-3"], prerequisiteStepIDs: ["img-step-3"])
        ]
        let imgCriteria = [
            ProjectCompletionCriterion(id: "img-crit-1", title: "Splits are clean", description: "No image appears in both train and test sets."),
            ProjectCompletionCriterion(id: "img-crit-2", title: "Two models compared", description: "Both models report accuracy and one confusion matrix."),
            ProjectCompletionCriterion(id: "img-crit-3", title: "Card is honest", description: "Model card notes limits and one ethical consideration.")
        ]
        let imgPrereqs = [
            ProjectPrerequisite(id: "img-pre-1", type: .skill, title: "Python basics", referenceID: "python"),
            ProjectPrerequisite(id: "img-pre-2", type: .skill, title: "AI literacy", referenceID: "ai literacy")
        ]
        let imgPlaybook = ProjectPlaybook(
            id: "image-classifier-pets",
            overview: "From photos to predictions — train, evaluate, and communicate what your model actually does.",
            prerequisites: imgPrereqs,
            steps: imgSteps,
            resources: imgResources,
            deliverables: imgDeliverables,
            completionCriteria: imgCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 20, displayText: "2–3 weeks"),
            skillsDeveloped: ["Machine Learning", "Model Evaluation", "Python", "Data Analysis"]
        )

        // MARK: - Local-First Markdown Notes App
        let notesDeliverables = [
            ProjectDeliverable(id: "notes-deliv-1", title: "Working editor & preview", description: "Markdown editor with live preview and local persistence (localStorage or files).", format: "web app", required: true),
            ProjectDeliverable(id: "notes-deliv-2", title: "Search & tags", description: "Search across notes and filter by tags with keyboard shortcuts.", format: "feature", required: true),
            ProjectDeliverable(id: "notes-deliv-3", title: "Published site", description: "Deployed URL and README with usage GIF.", format: "website", required: true)
        ]
        let notesResources = [
            ProjectResource(id: "notes-res-1", title: "MDN Web Docs", type: .documentation, url: "https://developer.mozilla.org/", description: "Reference for HTML, CSS, and JavaScript."),
            ProjectResource(id: "notes-res-2", title: "GitHub Pages Docs", type: .documentation, url: "https://docs.github.com/en/pages", description: "Deploy your app for free on GitHub Pages."),
            ProjectResource(id: "notes-res-3", title: "Markdown Guide", type: .reference, url: "https://www.markdownguide.org/", description: "Syntax and examples for Markdown formatting.")
        ]
        let notesSteps = [
            ProjectPlaybookStep(id: "notes-step-1", order: 1, title: "Design the experience", description: "Sketch editor, preview, and search flows. Note accessibility needs (keyboard, focus, headings).", estimatedEffort: "1 hour", requiredSkills: ["Planning"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "notes-step-2", order: 2, title: "Build editor + preview", description: "Implement Markdown parsing (marked or similar), live preview, and save/load to localStorage. Keep state in one place.", estimatedEffort: "1–2 weeks", requiredSkills: ["Web Development", "JavaScript"], deliverableIDs: ["notes-deliv-1"], prerequisiteStepIDs: ["notes-step-1"]),
            ProjectPlaybookStep(id: "notes-step-3", order: 3, title: "Add search and tags", description: "Add full-text search, tag filtering, and shortcuts (Cmd/Ctrl+S, / to focus search). Write 5 sample notes to test.", estimatedEffort: "1 week", requiredSkills: ["Web Development", "Design"], deliverableIDs: ["notes-deliv-2"], prerequisiteStepIDs: ["notes-step-2"]),
            ProjectPlaybookStep(id: "notes-step-4", order: 4, title: "Polish and publish", description: "Test offline use, add empty states, write README with demo GIF, and deploy to GitHub Pages.", estimatedEffort: "1 day", requiredSkills: ["Technical Writing"], deliverableIDs: ["notes-deliv-3"], prerequisiteStepIDs: ["notes-step-3"])
        ]
        let notesCriteria = [
            ProjectCompletionCriterion(id: "notes-crit-1", title: "Edits persist offline", description: "Notes survive page reload without a backend."),
            ProjectCompletionCriterion(id: "notes-crit-2", title: "Preview is live and correct", description: "Markdown syntax renders correctly and updates as you type."),
            ProjectCompletionCriterion(id: "notes-crit-3", title: "Search finds notes quickly", description: "Search returns relevant notes in under a second for 30+ notes.")
        ]
        let notesPrereqs = [
            ProjectPrerequisite(id: "notes-pre-1", type: .knowledge, title: "Basic HTML/CSS/JS", description: "Understanding of DOM and events", referenceID: nil),
            ProjectPrerequisite(id: "notes-pre-2", type: .skill, title: "Web development intro", referenceID: "web development")
        ]
        let notesPlaybook = ProjectPlaybook(
            id: "markdown-notes-app",
            overview: "Your everyday tool — build the notes app you actually want to use, offline first.",
            prerequisites: notesPrereqs,
            steps: notesSteps,
            resources: notesResources,
            deliverables: notesDeliverables,
            completionCriteria: notesCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 18, displayText: "2–3 weeks"),
            skillsDeveloped: ["Web Development", "JavaScript", "Writing", "Design"]
        )

        // MARK: - Open-Source Good First Issue Sprint
        let ossDeliverables = [
            ProjectDeliverable(id: "oss-deliv-1", title: "First pull request", description: "Merged or reviewed PR with description, tests, and linked issue.", format: "PR", required: true),
            ProjectDeliverable(id: "oss-deliv-2", title: "Second pull request", description: "Second PR in a different repo or area, incorporating maintainer feedback.", format: "PR", required: true),
            ProjectDeliverable(id: "oss-deliv-3", title: "Reflection post", description: "Short write-up of what open collaboration taught you.", format: "post", required: true)
        ]
        let ossResources = [
            ProjectResource(id: "oss-res-1", title: "GitHub Skills", type: .course, url: "https://skills.github.com/", description: "Practice branching, forking, and pull requests."),
            ProjectResource(id: "oss-res-2", title: "Finding Good First Issues", type: .reference, url: "https://docs.github.com/en/issues/tracking-your-work-with-issues/using-labels-and-milestones/filtering-your-issues-and-pull-requests-by-label", description: "Filtering issues by 'good first issue' label."),
            ProjectResource(id: "oss-res-3", title: "How to Write a Great PR Description", type: .reference, url: "https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/getting-started/about-pull-requests", description: "What maintainers look for in a PR.")
        ]
        let ossSteps = [
            ProjectPlaybookStep(id: "oss-step-1", order: 1, title: "Find good issues", description: "Pick 2 repos you care about and 2 'good first issue' tickets you can realistically finish. Comment to claim one.", estimatedEffort: "2 hours", requiredSkills: ["Research"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "oss-step-2", order: 2, title: "Ship first PR", description: "Fork, branch, code, run tests locally, and open a PR with a clear title, description, and linked issue. Respond to feedback.", estimatedEffort: "1 week", requiredSkills: ["Git", "Collaboration"], deliverableIDs: ["oss-deliv-1"], prerequisiteStepIDs: ["oss-step-1"]),
            ProjectPlaybookStep(id: "oss-step-3", order: 3, title: "Ship second PR", description: "Repeat with a different repo or language. Apply what you learned from the first review.", estimatedEffort: "1 week", requiredSkills: ["Software Development", "Documentation"], deliverableIDs: ["oss-deliv-2"], prerequisiteStepIDs: ["oss-step-2"]),
            ProjectPlaybookStep(id: "oss-step-4", order: 4, title: "Reflect and share", description: "Write a 300-word post about what collaborating in the open taught you. Link both PRs.", estimatedEffort: "2 hours", requiredSkills: ["Technical Writing"], deliverableIDs: ["oss-deliv-3"], prerequisiteStepIDs: ["oss-step-3"])
        ]
        let ossCriteria = [
            ProjectCompletionCriterion(id: "oss-crit-1", title: "Two PRs opened", description: "At least two pull requests are opened with linked issues."),
            ProjectCompletionCriterion(id: "oss-crit-2", title: "Contribution is reviewed", description: "At least one PR received maintainer feedback and you responded."),
            ProjectCompletionCriterion(id: "oss-crit-3", title: "Learning is captured", description: "Reflection notes one concrete improvement for next time.")
        ]
        let ossPrereqs = [
            ProjectPrerequisite(id: "oss-pre-1", type: .skill, title: "Git basics", referenceID: "git"),
            ProjectPrerequisite(id: "oss-pre-2", type: .skill, title: "Collaboration willingness", referenceID: "collaboration")
        ]
        let ossPlaybook = ProjectPlaybook(
            id: "open-source-sprint",
            overview: "Learn in public — find real projects, ship real patches, and earn maintainers' trust.",
            prerequisites: ossPrereqs,
            steps: ossSteps,
            resources: ossResources,
            deliverables: ossDeliverables,
            completionCriteria: ossCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 18, displayText: "2–3 weeks"),
            skillsDeveloped: ["Git", "Collaboration", "Documentation", "Software Development"]
        )

        // MARK: - Job Market Web Scraper & Dashboard
        let scraperDeliverables = [
            ProjectDeliverable(id: "scrape-deliv-1", title: "Collected dataset", description: "200+ postings (or public sample) with cleaned, normalized fields.", format: "dataset", required: true),
            ProjectDeliverable(id: "scrape-deliv-2", title: "Trend dashboard", description: "3–5 charts: top skills, locations, and trend over time.", format: "dashboard", required: true),
            ProjectDeliverable(id: "scrape-deliv-3", title: "Insight report", description: "One-page report with methods, limits, and one career takeaway.", format: "report", required: true)
        ]
        let scraperResources = [
            ProjectResource(id: "scrape-res-1", title: "Beautiful Soup Documentation", type: .documentation, url: "https://www.crummy.com/software/BeautifulSoup/bs4/doc/", description: "Parsing HTML pages for scraping."),
            ProjectResource(id: "scrape-res-2", title: "Pandas Data Cleaning Guide", type: .tutorial, url: "https://pandas.pydata.org/docs/user_guide/missing_data.html", description: "Handling missing and inconsistent values."),
            ProjectResource(id: "scrape-res-3", title: "Data Visualization Guide — Matplotlib", type: .tutorial, url: "https://matplotlib.org/stable/tutorials/index.html", description: "Building clear charts from your data.")
        ]
        let scraperSteps = [
            ProjectPlaybookStep(id: "scrape-step-1", order: 1, title: "Plan respectful collection", description: "Check terms, rate limits, and robots.txt. Decide to scrape a small site or use a public dataset for reliability.", estimatedEffort: "1 hour", requiredSkills: ["Research"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "scrape-step-2", order: 2, title: "Collect and clean", description: "Gather 200+ postings or download a sample CSV. Normalize titles, skills, and locations. Drop duplicates.", estimatedEffort: "1 week", requiredSkills: ["Python", "Data Collection"], deliverableIDs: ["scrape-deliv-1"], prerequisiteStepIDs: ["scrape-step-1"]),
            ProjectPlaybookStep(id: "scrape-step-3", order: 3, title: "Analyze and visualize", description: "Count top skills and locations, chart trends, and calculate simple stats. Make each chart answer one question.", estimatedEffort: "1 week", requiredSkills: ["Data Analysis", "Python"], deliverableIDs: ["scrape-deliv-2"], prerequisiteStepIDs: ["scrape-step-2"]),
            ProjectPlaybookStep(id: "scrape-step-4", order: 4, title: "Publish insights", description: "Share a one-page report with methods, sampling limits, and one career-relevant takeaway (e.g., most requested skill).", estimatedEffort: "2 hours", requiredSkills: ["Technical Communication"], deliverableIDs: ["scrape-deliv-3"], prerequisiteStepIDs: ["scrape-step-3"])
        ]
        let scraperCriteria = [
            ProjectCompletionCriterion(id: "scrape-crit-1", title: "Dataset is documented", description: "Source, collection date, and cleaning steps are noted."),
            ProjectCompletionCriterion(id: "scrape-crit-2", title: "Visuals answer questions", description: "Three charts each have a clear question and answer."),
            ProjectCompletionCriterion(id: "scrape-crit-3", title: "Limits are acknowledged", description: "Report names one limit of the sample and how it could bias results.")
        ]
        let scraperPrereqs = [
            ProjectPrerequisite(id: "scrape-pre-1", type: .skill, title: "Python basics", referenceID: "python"),
            ProjectPrerequisite(id: "scrape-pre-2", type: .knowledge, title: "Web basics", description: "What HTML structure looks like", referenceID: nil)
        ]
        let scraperPlaybook = ProjectPlaybook(
            id: "job-market-scraper",
            overview: "Find what the job market actually values — with data you collected yourself, responsibly.",
            prerequisites: scraperPrereqs,
            steps: scraperSteps,
            resources: scraperResources,
            deliverables: scraperDeliverables,
            completionCriteria: scraperCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 20, displayText: "2–3 weeks"),
            skillsDeveloped: ["Python", "Data Collection", "Data Analysis", "Research"]
        )

        // MARK: - Debug & Test Legacy Codebase
        let debugDeliverables = [
            ProjectDeliverable(id: "debug-deliv-1", title: "Bug reproduction log", description: "Steps to reproduce 5 bugs consistently with before/after.", format: "log", required: true),
            ProjectDeliverable(id: "debug-deliv-2", title: "Fixed codebase", description: "Branch with fixes verified via debugger, not just prints.", format: "code", required: true),
            ProjectDeliverable(id: "debug-deliv-3", title: "Regression test suite", description: "8–10 unit tests that would have caught the bugs.", format: "tests", required: true)
        ]
        let debugResources = [
            ProjectResource(id: "debug-res-1", title: "VS Code Debugging Guide", type: .documentation, url: "https://code.visualstudio.com/docs/editor/debugging", description: "Breakpoints, stepping, and variable inspection in VS Code."),
            ProjectResource(id: "debug-res-2", title: "pytest Tutorial", type: .tutorial, url: "https://docs.pytest.org/en/latest/how-to/index.html", description: "Writing unit tests and fixtures with pytest."),
            ProjectResource(id: "debug-res-3", title: "Jest Docs", type: .documentation, url: "https://jestjs.io/docs/getting-started", description: "Testing JavaScript with Jest.")
        ]
        let debugSteps = [
            ProjectPlaybookStep(id: "debug-step-1", order: 1, title: "Reproduce the bugs", description: "Pick a small buggy app (sample repo or instructor bug list). Document steps to trigger each of 5 bugs.", estimatedEffort: "2 hours", requiredSkills: ["Quality Assurance"], deliverableIDs: ["debug-deliv-1"], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "debug-step-2", order: 2, title: "Fix with debugger", description: "Use breakpoints, step-through, and watch expressions to find root causes. Patch each with a minimal change.", estimatedEffort: "1 week", requiredSkills: ["Debugging", "Software Development"], deliverableIDs: ["debug-deliv-2"], prerequisiteStepIDs: ["debug-step-1"]),
            ProjectPlaybookStep(id: "debug-step-3", order: 3, title: "Add unit tests", description: "Write 8–10 tests that reproduce the bugs before the fix and pass after. Cover edge cases.", estimatedEffort: "1 week", requiredSkills: ["Unit Testing", "Quality Assurance"], deliverableIDs: ["debug-deliv-3"], prerequisiteStepIDs: ["debug-step-2"]),
            ProjectPlaybookStep(id: "debug-step-4", order: 4, title: "Document quality", description: "Write a quality log: bug, cause, fix, test, and prevention idea. Summarize time per bug.", estimatedEffort: "2 hours", requiredSkills: ["Technical Writing"], deliverableIDs: [], prerequisiteStepIDs: ["debug-step-3"])
        ]
        let debugCriteria = [
            ProjectCompletionCriterion(id: "debug-crit-1", title: "Bugs are reproducible", description: "Each bug has steps that fail before and pass after the fix."),
            ProjectCompletionCriterion(id: "debug-crit-2", title: "Debugger was used", description: "At least 3 fixes note the breakpoint or variable that revealed the bug."),
            ProjectCompletionCriterion(id: "debug-crit-3", title: "Tests prevent regression", description: "Tests fail on buggy code and pass after fixes.")
        ]
        let debugPrereqs = [
            ProjectPrerequisite(id: "debug-pre-1", type: .skill, title: "Git basics", referenceID: "git"),
            ProjectPrerequisite(id: "debug-pre-2", type: .skill, title: "Programming fundamentals", referenceID: "programming fundamentals")
        ]
        let debugPlaybook = ProjectPlaybook(
            id: "debug-legacy-codebase",
            overview: "Level up as a software engineer — hunt bugs with a debugger and lock fixes with tests.",
            prerequisites: debugPrereqs,
            steps: debugSteps,
            resources: debugResources,
            deliverables: debugDeliverables,
            completionCriteria: debugCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 20, displayText: "2–3 weeks"),
            skillsDeveloped: ["Debugging", "Unit Testing", "Quality Assurance", "Software Development"]
        )

        // MARK: - Accessibility Auditor Browser Extension
        let a11yDeliverables = [
            ProjectDeliverable(id: "a11y-deliv-1", title: "Working extension", description: "Browser extension that injects, audits, and shows a report.", format: "extension", required: true),
            ProjectDeliverable(id: "a11y-deliv-2", title: "Audit logs", description: "Results from testing on 5 real sites with actionable fixes.", format: "logs", required: true),
            ProjectDeliverable(id: "a11y-deliv-3", title: "Install guide", description: "Short guide for installing and interpreting results.", format: "guide", required: true)
        ]
        let a11yResources = [
            ProjectResource(id: "a11y-res-1", title: "WCAG Quick Reference", type: .reference, url: "https://www.w3.org/WAI/WCAG21/quickref/", description: "Key accessibility principles and success criteria."),
            ProjectResource(id: "a11y-res-2", title: "Chrome Extensions Docs", type: .documentation, url: "https://developer.chrome.com/docs/extensions", description: "Building and loading a browser extension."),
            ProjectResource(id: "a11y-res-3", title: "axe Accessibility Guide", type: .tutorial, url: "https://www.deque.com/axe/", description: "Automated accessibility checking concepts.")
        ]
        let a11ySteps = [
            ProjectPlaybookStep(id: "a11y-step-1", order: 1, title: "Learn accessibility basics", description: "Study WCAG quick reference and pick 5 checks: headings, alt text, form labels, contrast hints, and landmark roles.", estimatedEffort: "2 hours", requiredSkills: ["Research"], deliverableIDs: [], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "a11y-step-2", order: 2, title: "Build the extension", description: "Create manifest, content script to scan DOM, and popup to show a report with counts and fix hints.", estimatedEffort: "1–2 weeks", requiredSkills: ["Web Development", "JavaScript"], deliverableIDs: ["a11y-deliv-1"], prerequisiteStepIDs: ["a11y-step-1"]),
            ProjectPlaybookStep(id: "a11y-step-3", order: 3, title: "Test on real sites", description: "Audit 5 sites you use, log findings, and refine messages to be specific and kind.", estimatedEffort: "1 week", requiredSkills: ["Quality Assurance", "Empathy"], deliverableIDs: ["a11y-deliv-2"], prerequisiteStepIDs: ["a11y-step-2"]),
            ProjectPlaybookStep(id: "a11y-step-4", order: 4, title: "Publish and share", description: "Write install instructions (load unpacked), share with a teacher or peer, and record one improvement from feedback.", estimatedEffort: "1 day", requiredSkills: ["Technical Writing"], deliverableIDs: ["a11y-deliv-3"], prerequisiteStepIDs: ["a11y-step-3"])
        ]
        let a11yCriteria = [
            ProjectCompletionCriterion(id: "a11y-crit-1", title: "Extension runs on any page", description: "Popup shows results after clicking on a normal website."),
            ProjectCompletionCriterion(id: "a11y-crit-2", title: "Five checks are accurate", description: "Manual spot-check confirms no false positives on headings/alt text."),
            ProjectCompletionCriterion(id: "a11y-crit-3", title: "Report helps users fix", description: "Each finding links to a short fix hint.")
        ]
        let a11yPrereqs = [
            ProjectPrerequisite(id: "a11y-pre-1", type: .knowledge, title: "Basic HTML familiarity", referenceID: nil),
            ProjectPrerequisite(id: "a11y-pre-2", type: .skill, title: "Web development intro", referenceID: "web development")
        ]
        let a11yPlaybook = ProjectPlaybook(
            id: "accessibility-auditor",
            overview: "Make the web more usable — build an audit tool that teaches you accessibility as you build it.",
            prerequisites: a11yPrereqs,
            steps: a11ySteps,
            resources: a11yResources,
            deliverables: a11yDeliverables,
            completionCriteria: a11yCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 18, displayText: "2–3 weeks"),
            skillsDeveloped: ["Web Development", "Quality Assurance", "Technical Writing", "Empathy"]
        )

        // MARK: - Secure Password Vault
        let vaultDeliverables = [
            ProjectDeliverable(id: "vault-deliv-1", title: "Threat model note", description: "Written threat model: what you protect, from whom, and explicit non-goals.", format: "document", required: true),
            ProjectDeliverable(id: "vault-deliv-2", title: "Encrypted vault", description: "Local vault with add/get, master password hashing, and encryption for stored secrets.", format: "code", required: true),
            ProjectDeliverable(id: "vault-deliv-3", title: "Generator & security docs", description: "Strong generator with strength checks and README covering usage and limits.", format: "docs + code", required: true)
        ]
        let vaultResources = [
            ProjectResource(id: "vault-res-1", title: "OWASP Password Storage Cheat Sheet", type: .reference, url: "https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html", description: "Best practices for hashing and protecting passwords."),
            ProjectResource(id: "vault-res-2", title: "Python cryptography docs", type: .documentation, url: "https://cryptography.io/en/latest/", description: "Libraries for encryption and secure hashing."),
            ProjectResource(id: "vault-res-3", title: "Threat Modeling Guide — OWASP", type: .reference, url: "https://owasp.org/www-project-threat-dragon/docs-1/threat-modeling/", description: "How to frame a lightweight threat model.")
        ]
        let vaultSteps = [
            ProjectPlaybookStep(id: "vault-step-1", order: 1, title: "Design the threat model", description: "Decide what you protect against (local attacker with file access vs. network) and what you explicitly do not (e.g., cloud sync). Write a half-page note.", estimatedEffort: "1 hour", requiredSkills: ["Critical Thinking"], deliverableIDs: ["vault-deliv-1"], prerequisiteStepIDs: []),
            ProjectPlaybookStep(id: "vault-step-2", order: 2, title: "Build encrypted storage", description: "Implement vault with a KDF (e.g., PBKDF2/bcrypt) and symmetric encryption (Fernet or similar). Handle wrong master password gracefully.", estimatedEffort: "1–2 weeks", requiredSkills: ["Python", "Problem Solving"], deliverableIDs: ["vault-deliv-2"], prerequisiteStepIDs: ["vault-step-1"]),
            ProjectPlaybookStep(id: "vault-step-3", order: 3, title: "Add generator and checks", description: "Create a generator with length/charset options and a strength meter that explains rules (length, variety, not common passwords).", estimatedEffort: "1 week", requiredSkills: ["Problem Solving", "Critical Thinking"], deliverableIDs: [], prerequisiteStepIDs: ["vault-step-2"]),
            ProjectPlaybookStep(id: "vault-step-4", order: 4, title: "Document security", description: "Write a README with usage, how encryption works at a high level, known risks (e.g., clipboard, shoulder surfing), and how you would improve with a security review.", estimatedEffort: "2 hours", requiredSkills: ["Documentation"], deliverableIDs: ["vault-deliv-3"], prerequisiteStepIDs: ["vault-step-3"])
        ]
        let vaultCriteria = [
            ProjectCompletionCriterion(id: "vault-crit-1", title: "Threat model is explicit", description: "Doc states at least one in-scope and one out-of-scope threat."),
            ProjectCompletionCriterion(id: "vault-crit-2", title: "Encryption is actually used", description: "Stored passwords are encrypted at rest and require correct master password."),
            ProjectCompletionCriterion(id: "vault-crit-3", title: "README is honest", description: "README names at least one limitation and one next hardening step.")
        ]
        let vaultPrereqs = [
            ProjectPrerequisite(id: "vault-pre-1", type: .skill, title: "Python basics", referenceID: "python"),
            ProjectPrerequisite(id: "vault-pre-2", type: .skill, title: "Problem solving", referenceID: "problem solving")
        ]
        let vaultPlaybook = ProjectPlaybook(
            id: "secure-password-vault",
            overview: "Practice security thinking — build a local vault that explains its own limits.",
            prerequisites: vaultPrereqs,
            steps: vaultSteps,
            resources: vaultResources,
            deliverables: vaultDeliverables,
            completionCriteria: vaultCriteria,
            estimatedEffort: ProjectEffort(estimatedHours: 20, displayText: "2–3 weeks"),
            skillsDeveloped: ["Python", "Problem Solving", "Critical Thinking", "Documentation"]
        )

        return [plantPlaybook, portfolioPlaybook, sensorPlaybook, communityPlaybook,
                dsVisPlaybook, cliPlaybook, habitPlaybook, algoLabPlaybook,
                financePlaybook, chatbotPlaybook, imgPlaybook, notesPlaybook,
                ossPlaybook, scraperPlaybook, debugPlaybook, a11yPlaybook, vaultPlaybook]
    }
}
