import Foundation
import SwiftUI

// MARK: - Profile Completeness (deterministic, factual)

struct ProfileCompletenessDimension: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let completed: Bool
    let weight: Int
}

struct ProfileCompleteness: Hashable, Codable {
    let dimensions: [ProfileCompletenessDimension]
    var totalWeight: Int { dimensions.reduce(0) { $0 + $1.weight } }
    var completedWeight: Int { dimensions.filter(\.completed).reduce(0) { $0 + $1.weight } }
    var percent: Int { ProgressCalculator.percent(completed: completedWeight, total: totalWeight) }
    var isComplete: Bool { percent >= 80 }

    /// Deterministic evaluation from canonical profile + store-derived experience.
    static func evaluate(profile: StudentProfile, store: AppDataStore) -> ProfileCompleteness {
        let identityCompleted = !profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !profile.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let educationCompleted = !profile.grade.rawValue.isEmpty && !profile.schoolLevel.rawValue.isEmpty // always true for valid profile
        let interestsPresent = !profile.interests.isEmpty
        let strengthsPresent = !(profile.strengths + profile.customSkills).isEmpty
        let careerDirectionPresent = !profile.careers.isEmpty || !profile.fields.isEmpty
        let goalsPresent = !profile.milestones.isEmpty || profile.collegePlan != .notSure || !profile.targetColleges.isEmpty
        // Experience uses canonical store, not just profile.loggedEntries
        let hasExperience = !store.achievementRecords.isEmpty || !store.evidenceRecords.isEmpty || !store.completedProjects.isEmpty || store.completedMilestonesTotal > 0 || !store.activatedRoadmaps.isEmpty

        let dims: [ProfileCompletenessDimension] = [
            .init(id: "identity", title: "Identity", completed: identityCompleted, weight: 2),
            .init(id: "education", title: "Education", completed: educationCompleted, weight: 1),
            .init(id: "interests", title: "Interests", completed: interestsPresent, weight: 1),
            .init(id: "strengths", title: "Strengths", completed: strengthsPresent, weight: 1),
            .init(id: "career", title: "Career direction", completed: careerDirectionPresent, weight: 2),
            .init(id: "goals", title: "Goals", completed: goalsPresent, weight: 1),
            .init(id: "experience", title: "Experience", completed: hasExperience, weight: 2),
        ]
        return ProfileCompleteness(dimensions: dims)
    }

    /// Pure evaluation for testing with explicit counts
    static func evaluate(profile: StudentProfile, achievementsCount: Int, evidenceCount: Int, completedProjects: Int, completedMilestones: Int, hasActiveRoadmap: Bool) -> ProfileCompleteness {
        let identityCompleted = !profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !profile.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let educationCompleted = !profile.grade.rawValue.isEmpty && !profile.schoolLevel.rawValue.isEmpty
        let interestsPresent = !profile.interests.isEmpty
        let strengthsPresent = !(profile.strengths + profile.customSkills).isEmpty
        let careerDirectionPresent = !profile.careers.isEmpty || !profile.fields.isEmpty
        let goalsPresent = !profile.milestones.isEmpty || profile.collegePlan != .notSure || !profile.targetColleges.isEmpty
        let hasExperience = achievementsCount > 0 || evidenceCount > 0 || completedProjects > 0 || completedMilestones > 0 || hasActiveRoadmap

        let dims: [ProfileCompletenessDimension] = [
            .init(id: "identity", title: "Identity", completed: identityCompleted, weight: 2),
            .init(id: "education", title: "Education", completed: educationCompleted, weight: 1),
            .init(id: "interests", title: "Interests", completed: interestsPresent, weight: 1),
            .init(id: "strengths", title: "Strengths", completed: strengthsPresent, weight: 1),
            .init(id: "career", title: "Career direction", completed: careerDirectionPresent, weight: 2),
            .init(id: "goals", title: "Goals", completed: goalsPresent, weight: 1),
            .init(id: "experience", title: "Experience", completed: hasExperience, weight: 2),
        ]
        return ProfileCompleteness(dimensions: dims)
    }
}

// MARK: - Student Profile Snapshot (derived, not persisted)

/// Derived presentation data — contains references/IDs, not duplicated canonical entities.
/// Compute from AppDataStore via `StudentProfileSnapshot.make(from:)`.
struct StudentProfileSnapshot {
    let displayName: String
    let factualHeadline: String?
    let age: String
    let gradeLabel: String
    let schoolLevelLabel: String
    let location: String
    let interests: [String]
    let customInterests: [String]
    let strengths: [String]
    let customSkills: [String]
    let demonstratedSkillIDs: [String] // sorted, normalized
    let demonstratedSkills: [Skill] // canonical
    let careerInterests: [String]
    let fields: [String]
    let goals: [String] // milestones
    let collegePlan: CollegePlan
    let geography: String
    let collegeType: String
    let targetColleges: [String]
    let activeRoadmapIDs: [String]
    let projectIDs: [String]
    let achievementIDs: [String]
    let evidenceIDs: [String]
    let completeness: ProfileCompleteness
    let progress: ProgressSnapshot

    /// Factual deterministic headline, or nil if insufficient data.
    /// Never uses evaluative language like "elite"/"exceptional"/"college-ready".
    static func factualHeadline(for profile: StudentProfile) -> String? {
        let grade = profile.grade.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let loc = profile.location.trimmingCharacters(in: .whitespacesAndNewlines)
        let interests = profile.interests.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let school = profile.schoolLevel.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if !grade.isEmpty && !loc.isEmpty && !interests.isEmpty {
            let top = interests.prefix(2).map { $0.replacingOccurrences(of: "💻 ", with: "").replacingOccurrences(of: "🤖 ", with: "").replacingOccurrences(of: "⚙️ ", with: "").replacingOccurrences(of: "🔬 ", with: "").trimmingCharacters(in: .whitespaces) }.joined(separator: " · ")
            return "\(grade) student in \(loc) exploring \(top)"
        }
        if !grade.isEmpty && !loc.isEmpty {
            return "\(grade) student in \(loc)"
        }
        if !grade.isEmpty && !interests.isEmpty {
            let top = interests.prefix(2).map { $0.replacingOccurrences(of: "💻 ", with: "").replacingOccurrences(of: "🤖 ", with: "").replacingOccurrences(of: "⚙️ ", with: "").replacingOccurrences(of: "🔬 ", with: "").trimmingCharacters(in: .whitespaces) }.joined(separator: " · ")
            return "\(grade) student exploring \(top)"
        }
        if !interests.isEmpty {
            let top = interests.prefix(2).joined(separator: " · ")
            return "Student exploring \(top)"
        }
        return nil
    }

    static func displayName(for profile: StudentProfile) -> String {
        let n = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Student" : n
    }

    /// Primary factory — deterministic, read-only, no persistence.
    @MainActor
    static func make(from store: AppDataStore) -> StudentProfileSnapshot {
        let profile = store.profile
        let displayName = displayName(for: profile)
        let headline = factualHeadline(for: profile)
        let gradeLabel = profile.grade.rawValue
        let schoolLabel = profile.schoolLevel.rawValue
        let location = profile.location
        let interests = profile.interests
        let customInterests = profile.customInterests
        let strengths = profile.strengths
        let customSkills = profile.customSkills

        // Demonstrated skills via SkillGapEngine (authoritative, not reference)
        let catalog = RoadmapService.allRoadmaps
        let demonstratedIDs = SkillGapEngine.demonstratedSkillIDs(profile: profile, roadmapProgress: store.roadmapProgress, catalog: catalog, evidenceRecords: store.evidenceRecords)
        let demonstratedSkills = demonstratedIDs.sorted().compactMap { SkillCatalog.knownSkills[$0] ?? Skill(id: $0, name: $0) }
        let demonstratedSkillIDs = demonstratedIDs.sorted()

        let careerInterests = profile.careers
        let fields = profile.fields
        let goals = profile.milestones
        let activeRoadmapIDs = store.activatedRoadmaps.map(\.id).sorted()
        let projectIDs = store.scoredProjects.map(\.id)
        let achievementIDs = store.allAchievementsSorted.map(\.id)
        let evidenceIDs = store.allEvidenceSorted.map(\.id)
        let completeness = ProfileCompleteness.evaluate(profile: profile, store: store)
        let progress = ProgressEngine.snapshot(store: store)

        return StudentProfileSnapshot(
            displayName: displayName,
            factualHeadline: headline,
            age: profile.age,
            gradeLabel: gradeLabel,
            schoolLevelLabel: schoolLabel,
            location: location,
            interests: interests,
            customInterests: customInterests,
            strengths: strengths,
            customSkills: customSkills,
            demonstratedSkillIDs: demonstratedSkillIDs,
            demonstratedSkills: demonstratedSkills,
            careerInterests: careerInterests,
            fields: fields,
            goals: goals,
            collegePlan: profile.collegePlan,
            geography: profile.geography,
            collegeType: profile.collegeType,
            targetColleges: profile.targetColleges,
            activeRoadmapIDs: activeRoadmapIDs,
            projectIDs: projectIDs,
            achievementIDs: achievementIDs,
            evidenceIDs: evidenceIDs,
            completeness: completeness,
            progress: progress
        )
    }

    /// Pure factory for tests
    static func make(profile: StudentProfile, demonstratedSkillIDs: Set<String>, activeRoadmapIDs: [String], projectIDs: [String], achievementIDs: [String], evidenceIDs: [String], progress: ProgressSnapshot, completeness: ProfileCompleteness) -> StudentProfileSnapshot {
        let displayName = displayName(for: profile)
        let headline = factualHeadline(for: profile)
        let demSkills = demonstratedSkillIDs.sorted().compactMap { SkillCatalog.knownSkills[$0] ?? Skill(id: $0, name: $0) }
        return StudentProfileSnapshot(
            displayName: displayName,
            factualHeadline: headline,
            age: profile.age,
            gradeLabel: profile.grade.rawValue,
            schoolLevelLabel: profile.schoolLevel.rawValue,
            location: profile.location,
            interests: profile.interests,
            customInterests: profile.customInterests,
            strengths: profile.strengths,
            customSkills: profile.customSkills,
            demonstratedSkillIDs: demonstratedSkillIDs.sorted(),
            demonstratedSkills: demSkills,
            careerInterests: profile.careers,
            fields: profile.fields,
            goals: profile.milestones,
            collegePlan: profile.collegePlan,
            geography: profile.geography,
            collegeType: profile.collegeType,
            targetColleges: profile.targetColleges,
            activeRoadmapIDs: activeRoadmapIDs.sorted(),
            projectIDs: projectIDs,
            achievementIDs: achievementIDs,
            evidenceIDs: evidenceIDs,
            completeness: completeness,
            progress: progress
        )
    }
}
