import Foundation

// MARK: - Quality Level

enum EvidenceQualityLevel: String, Codable, Hashable, CaseIterable {
    case basic = "Basic"
    case solid = "Solid"
    case strong = "Strong"

    var displayName: String { rawValue }

    init(score: Int) {
        // Thresholds: 0-3 Basic, 4-7 Solid, 8+ Strong (max ~16)
        if score >= 8 { self = .strong }
        else if score >= 4 { self = .solid }
        else { self = .basic }
    }
}

// MARK: - Quality Dimension

struct EvidenceQualityDimension: Hashable, Codable {
    let id: String
    let title: String
    let achieved: Bool
    let weight: Int
    let relevant: Bool
}

// MARK: - Quality Result

struct EvidenceQualityResult: Hashable, Codable {
    let overallLevel: EvidenceQualityLevel
    let score: Int
    let maxScore: Int
    let dimensions: [EvidenceQualityDimension]
    let strengths: [String]
    let improvements: [String]
    let provenanceDescription: String

    var scoreExplanation: String { "\(score) of \(maxScore) quality signals" }
}

// MARK: - Engine

enum EvidenceQualityEngine {

    // MARK: - Public API

    static func quality(for record: EvidenceRecord) -> EvidenceQualityResult {
        let dimensions = buildDimensions(for: record)
        let score = dimensions.filter { $0.achieved && $0.relevant }.reduce(0) { $0 + $1.weight }
        let maxScore = dimensions.filter { $0.relevant }.reduce(0) { $0 + $1.weight }
        let level = EvidenceQualityLevel(score: score)
        let strengths = dimensions.filter { $0.achieved && $0.relevant }.map { $0.title }
        let improvements = suggestedImprovements(for: record, dimensions: dimensions)
        let provenance = provenanceDescription(for: record)
        return EvidenceQualityResult(
            overallLevel: level,
            score: score,
            maxScore: maxScore,
            dimensions: dimensions,
            strengths: strengths,
            improvements: improvements,
            provenanceDescription: provenance
        )
    }

    static func provenanceDescription(for record: EvidenceRecord) -> String {
        switch record.source {
        case .roadmapMilestone:
            return "Recorded by Student OPS from milestone completion"
        case .project:
            return "Linked to project activity"
        case .validation:
            return "Includes validation result"
        case .opportunity:
            return "Linked to opportunity participation"
        case .studentEntered:
            return "Added by you"
        case .system:
            return "Recorded by Student OPS"
        case .unknown:
            return "Source unknown"
        }
    }

    // MARK: - Dimensions

    private static func buildDimensions(for record: EvidenceRecord) -> [EvidenceQualityDimension] {
        let relevant = relevantDimensionIDs(for: record.type)

        func isRelevant(_ id: String) -> Bool { relevant.contains(id) }

        var dims: [EvidenceQualityDimension] = []

        // Title - always relevant
        let hasTitle = !record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && record.title.count > 3
        dims.append(EvidenceQualityDimension(id: "title", title: "Has a specific title", achieved: hasTitle, weight: 1, relevant: isRelevant("title")))

        // Description
        let hasDescription = (record.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) && (record.description?.count ?? 0) > 10
        dims.append(EvidenceQualityDimension(id: "description", title: "Includes a description", achieved: hasDescription, weight: 2, relevant: isRelevant("description")))

        // Date - occurredAt preferred, else completionDate always exists but we consider occurredAt as meaningful
        let hasDate = record.occurredAt != nil
        dims.append(EvidenceQualityDimension(id: "date", title: "Has an activity date", achieved: hasDate, weight: 1, relevant: isRelevant("date")))

        // Roadmap/milestone context
        let hasRoadmap = !record.roadmapID.isEmpty && !record.milestoneID.isEmpty
        dims.append(EvidenceQualityDimension(id: "roadmap", title: "Linked to a roadmap", achieved: hasRoadmap, weight: 2, relevant: isRelevant("roadmap")))

        // Project context
        let hasProject = !(record.projectID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        dims.append(EvidenceQualityDimension(id: "project", title: "Linked to a project", achieved: hasProject, weight: 2, relevant: isRelevant("project")))

        // Opportunity context
        let hasOpportunity = !(record.opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        dims.append(EvidenceQualityDimension(id: "opportunity", title: "Linked to an opportunity", achieved: hasOpportunity, weight: 2, relevant: isRelevant("opportunity")))

        // Action context
        let hasAction = !(record.actionID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        dims.append(EvidenceQualityDimension(id: "action", title: "Linked to an action", achieved: hasAction, weight: 1, relevant: isRelevant("action")))

        // Skills
        let hasSkills = !(record.skillIDs?.isEmpty ?? true)
        dims.append(EvidenceQualityDimension(id: "skills", title: hasSkills ? "References \(record.skillIDs?.count ?? 0) skill\(record.skillIDs?.count == 1 ? "" : "s")" : "References skills", achieved: hasSkills, weight: 1, relevant: isRelevant("skills")))

        // Artifact
        let hasArtifact: Bool = {
            guard let art = record.artifact, let url = art.url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else { return false }
            guard let u = URL(string: url), let scheme = u.scheme?.lowercased(), ["http","https"].contains(scheme), u.host != nil else { return false }
            return true
        }()
        dims.append(EvidenceQualityDimension(id: "artifact", title: "Includes an artifact", achieved: hasArtifact, weight: 2, relevant: isRelevant("artifact")))

        // Validation
        let hasValidation = !(record.validationID?.isEmpty ?? true) && record.validationPassed != nil
        dims.append(EvidenceQualityDimension(id: "validation", title: record.validationPassed == true ? "Includes a passed validation result" : "Includes a validation result", achieved: hasValidation, weight: 2, relevant: isRelevant("validation")))

        return dims
    }

    private static func relevantDimensionIDs(for type: EvidenceType) -> Set<String> {
        switch type {
        case .milestoneCompletion:
            return ["title","description","date","roadmap","skills","validation","artifact","action"]
        case .projectWork:
            return ["title","description","project","skills","date","artifact"]
        case .opportunityParticipation:
            return ["title","description","opportunity","date","artifact","skills"]
        case .validation:
            return ["title","description","roadmap","skills","date","validation"]
        case .learning:
            return ["title","description","skills","date","artifact","validation"]
        case .leadershipActivity:
            return ["title","description","date","skills","artifact"]
        case .communityActivity:
            return ["title","description","date","skills","artifact"]
        case .artifact:
            return ["title","description","artifact","date","skills"]
        case .other:
            return ["title","description","date","skills","artifact"]
        }
    }

    private static func suggestedImprovements(for record: EvidenceRecord, dimensions: [EvidenceQualityDimension]) -> [String] {
        var out: [String] = []
        for dim in dimensions where dim.relevant && !dim.achieved {
            switch dim.id {
            case "description":
                out.append("Add a short description of what you did.")
            case "date":
                out.append("Add when the activity happened if you know it.")
            case "roadmap":
                if record.type == .milestoneCompletion {
                    out.append("Link this evidence to a roadmap and milestone.")
                } else {
                    out.append("Link this evidence to a roadmap, milestone, project, or opportunity.")
                }
            case "project":
                out.append("Add a project link or other artifact if available.")
            case "opportunity":
                out.append("Link this evidence to an opportunity if it was part of one.")
            case "skills":
                out.append("Add the skills this evidence demonstrates or relates to.")
            case "artifact":
                // Only suggest artifact for types where it's relevant and expected
                if [.projectWork, .artifact, .opportunityParticipation].contains(record.type) {
                    out.append("Add a project link or other artifact if available.")
                } else if record.type == .learning {
                    out.append("Add a resource or artifact if available.")
                }
                // For milestone, don't always suggest artifact
            case "validation":
                if record.type == .milestoneCompletion || record.type == .learning || record.type == .validation {
                    // Only suggest validation if relevant and missing
                    // Don't suggest if not expected
                }
            default:
                break
            }
        }
        // Special handling for title (should always have, but if missing)
        if let titleDim = dimensions.first(where: { $0.id == "title" }), !titleDim.achieved {
            out.insert("Add a specific title.", at: 0)
        }
        // Deduplicate
        var seen = Set<String>()
        var deduped: [String] = []
        for s in out where seen.insert(s).inserted { deduped.append(s) }
        return deduped
    }
}
