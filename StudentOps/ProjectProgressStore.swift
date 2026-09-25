import Combine
import Foundation

@MainActor
final class ProjectProgressStore: ObservableObject {
    @Published private(set) var completedCounts: [String: Int]
    @Published private(set) var portfolioProjectIDs: Set<String>
    @Published private(set) var customProjects: [Project]
    @Published private(set) var notes: [String: String]
    private let progressKey = "studentops.projectProgress"
    private let portfolioKey = "studentops.portfolioProjectIDs"
    private let customProjectsKey = "studentops.customProjects"
    private let notesKey = "studentops.projectNotes"

    init() {
        completedCounts = UserDefaults.standard.dictionary(forKey: progressKey) as? [String: Int] ?? [:]
        portfolioProjectIDs = Set(UserDefaults.standard.stringArray(forKey: portfolioKey) ?? [])
        if let data = UserDefaults.standard.data(forKey: customProjectsKey), let projects = try? JSONDecoder().decode([Project].self, from: data) { customProjects = projects }
        else { customProjects = [] }
        notes = UserDefaults.standard.dictionary(forKey: notesKey) as? [String: String] ?? [:]
    }

    func completedCount(for project: Project) -> Int { min(completedCounts[project.id] ?? 0, project.milestones.count) }
    func isInPortfolio(_ project: Project) -> Bool { portfolioProjectIDs.contains(project.id) }
    func note(for project: Project) -> String { notes[project.id] ?? "" }
    func saveNote(_ note: String, for project: Project) { notes[project.id] = note; UserDefaults.standard.set(notes, forKey: notesKey) }

    func markMilestoneComplete(for project: Project) {
        let next = min(completedCount(for: project) + 1, project.milestones.count)
        completedCounts[project.id] = next
        persist()
        if next == project.milestones.count { addCompletedSkillsToProfile(project.skills) }
    }

    func togglePortfolio(_ project: Project) {
        if portfolioProjectIDs.contains(project.id) { portfolioProjectIDs.remove(project.id) }
        else if completedCount(for: project) == project.milestones.count { portfolioProjectIDs.insert(project.id) }
        UserDefaults.standard.set(Array(portfolioProjectIDs), forKey: portfolioKey)
    }

    func reset(_ project: Project) {
        completedCounts[project.id] = 0
        portfolioProjectIDs.remove(project.id)
        persist()
        UserDefaults.standard.set(Array(portfolioProjectIDs), forKey: portfolioKey)
    }

    func create(title: String, goal: String) {
        let project = Project(
            id: "custom-\(UUID().uuidString)", title: title, category: "Personal Project", goal: goal,
            description: "A project created by you. Add evidence and notes as you make progress.",
            skills: [], milestones: [.init(id: "custom-\(UUID().uuidString)-milestone", title: "Complete the project", subtitle: goal, estimatedTime: "Your timeline")],
            resources: [], estimatedCompletion: "Your timeline", relevantInterests: [], relevantSkills: [], relevantCareers: [], relevantFields: [], sourceRoadmapID: nil
        )
        customProjects.append(project)
        if let data = try? JSONEncoder().encode(customProjects) { UserDefaults.standard.set(data, forKey: customProjectsKey) }
    }

    private func persist() { UserDefaults.standard.set(completedCounts, forKey: progressKey) }

    private func addCompletedSkillsToProfile(_ skills: [String]) {
        guard let data = UserDefaults.standard.data(forKey: "studentops.profile"), var profile = try? JSONDecoder().decode(StudentProfile.self, from: data) else { return }
        for skill in skills where !profile.customSkills.contains(skill) && !profile.strengths.contains(skill) { profile.customSkills.append(skill) }
        if let updated = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(updated, forKey: "studentops.profile") }
    }
}
