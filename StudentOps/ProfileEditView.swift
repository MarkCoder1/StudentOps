import SwiftUI

struct ProfileEditView: View {
    @Binding var profile: StudentProfile
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var newSkill = ""
    @State private var newInterest = ""
    @State private var newCareer = ""
    @State private var newMilestone = ""
    @State private var newField = ""
    @State private var newCollege = ""
    @State private var newExperience = ""
    @State private var experienceCategory = "Projects"
    @State private var showProjectEditor = false
    @State private var editingProject: Project?
    private let categories = ["Projects", "Competitions", "Awards", "Volunteering", "Leadership", "Clubs", "Certifications", "Work/Job"]
    private let interestOptions = ["Technology", "AI", "Engineering", "Science", "Business", "Medicine", "Design", "Arts", "Writing", "Law", "Education", "Environment", "Entrepreneurship", "Sports"]
    private let coreStrengths = ["Problem solving", "Programming", "Mathematics", "Building things", "Public speaking", "Creativity", "Leadership", "Research", "Writing", "Communication", "Teamwork"]
    private let careerOptions = ["Software Engineer", "AI Researcher", "Biomedical Engineer", "Product Designer"]
    private let milestoneOptions = ["Build real projects", "Develop technical skills", "Prepare for college", "Find competitions & research labs"]
    private let fieldOptions = ["Computer Science", "Engineering", "Biology", "Medicine", "Business", "Psychology", "Arts", "Law"]

    var body: some View {
        NavigationStack {
            Form {
                Section("About you") { TextField("First name", text: $profile.firstName); TextField("Location or state", text: $profile.location); Picker("School level", selection: $profile.schoolLevel) { ForEach(SchoolLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) } }; Picker("Grade", selection: $profile.grade) { ForEach(Grade.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                Section("Interests") {
                    FlowLayout(spacing: 6) { ForEach(interestOptions, id: \.self) { item in SelectableChip(title: item, selected: profile.interests.contains(item)) { toggle(item, in: &profile.interests) } } }
                    if !profile.customInterests.isEmpty {
                        FlowLayout(spacing: 6) { ForEach(profile.customInterests, id: \.self) { item in Button { profile.customInterests.removeAll { $0 == item }; profile.interests.removeAll { $0 == item } } label: { Text("\(item) ×").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(Color.white).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border)) }.buttonStyle(.plain) } }
                    }
                    HStack { TextField("Add interest", text: $newInterest); Button("Add") { addInterest() }.disabled(newInterest.trimmingCharacters(in: .whitespaces).isEmpty) }
                }
                Section("Strengths") { FlowLayout(spacing: 6) { ForEach(coreStrengths, id: \.self) { item in SelectableChip(title: item, selected: profile.strengths.contains(item)) { toggle(item, in: &profile.strengths) } } } }
                Section("Skills") { HStack { TextField("Add a skill", text: $newSkill); Button("Add") { addSkill() }.disabled(newSkill.trimmingCharacters(in: .whitespaces).isEmpty) }; ForEach(profile.customSkills, id: \.self) { skill in HStack { Text(skill); Spacer(); Button { profile.customSkills.removeAll { $0 == skill } } label: { Image(systemName: "xmark.circle") }.buttonStyle(.plain) } } }
                Section("Career interests") {
                    FlowLayout(spacing: 6) { ForEach(careerOptions, id: \.self) { item in SelectableChip(title: item, selected: profile.careers.contains(item)) { toggle(item, in: &profile.careers) } } }
                    FlowLayout(spacing: 6) { ForEach(profile.careers.filter { !careerOptions.contains($0) }, id: \.self) { item in Button { profile.careers.removeAll { $0 == item } } label: { Text("\(item) ×").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary).padding(6).background(Color.white).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border)) }.buttonStyle(.plain) } }
                    HStack { TextField("Add career", text: $newCareer); Button("Add") { addCareer() }.disabled(newCareer.trimmingCharacters(in: .whitespaces).isEmpty) }
                }
                Section("Goals & Milestones") {
                    FlowLayout(spacing: 6) { ForEach(milestoneOptions, id: \.self) { item in SelectableChip(title: item, selected: profile.milestones.contains(item)) { toggle(item, in: &profile.milestones) } } }
                    FlowLayout(spacing: 6) { ForEach(profile.milestones.filter { !milestoneOptions.contains($0) }, id: \.self) { item in Button { profile.milestones.removeAll { $0 == item } } label: { Text("\(item) ×").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary).padding(6).background(Color.white).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border)) }.buttonStyle(.plain) } }
                    HStack { TextField("Add goal", text: $newMilestone); Button("Add") { addMilestone() }.disabled(newMilestone.trimmingCharacters(in: .whitespaces).isEmpty) }
                    Toggle("I'm not sure yet", isOn: $profile.notSureYet)
                }
                Section("College plans") {
                    Picker("College plan", selection: $profile.collegePlan) { ForEach(CollegePlan.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    if profile.collegePlan == .yesDefinitely || profile.collegePlan == .probably {
                        FlowLayout(spacing: 6) { ForEach(fieldOptions, id: \.self) { item in SelectableChip(title: item, selected: profile.fields.contains(item)) { toggle(item, in: &profile.fields) } } }
                        FlowLayout(spacing: 6) { ForEach(profile.fields.filter { !fieldOptions.contains($0) }, id: \.self) { item in Button { profile.fields.removeAll { $0 == item } } label: { Text("\(item) ×") }.buttonStyle(.plain) } }
                        HStack { TextField("Add study area", text: $newField); Button("Add") { addField() }.disabled(newField.trimmingCharacters(in: .whitespaces).isEmpty) }
                        Picker("Location preference", selection: $profile.geography) { ForEach(["In-state (Texas)", "Anywhere in U.S.", "Out-of-state", "Not sure yet"], id: \.self) { Text($0).tag($0) } }
                        Picker("College type", selection: $profile.collegeType) { ForEach(["4-year university", "Community college", "Technical/trade", "Not sure yet"], id: \.self) { Text($0).tag($0) } }
                        HStack { TextField("Add college", text: $newCollege); Button("Add") { addCollege() }.disabled(newCollege.trimmingCharacters(in: .whitespaces).isEmpty) }
                        ForEach(profile.targetColleges, id: \.self) { c in HStack { Text(c); Spacer(); Button { profile.targetColleges.removeAll { $0 == c } } label: { Image(systemName: "xmark.circle") }.buttonStyle(.plain) } }
                    }
                }
                Section("Existing experience") {
                    Toggle("Just getting started", isOn: $profile.justGettingStarted)
                    HStack { TextField("Add an experience", text: $newExperience); Picker("Category", selection: $experienceCategory) { ForEach(categories, id: \.self) { Text($0).tag($0) } }.labelsHidden(); Button("Add") { addExperience() }.disabled(newExperience.trimmingCharacters(in: .whitespaces).isEmpty) }
                    ForEach(profile.loggedEntries) { entry in HStack { VStack(alignment: .leading) { Text(entry.title); Text(entry.category).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }; Spacer(); Button { profile.loggedEntries.removeAll { $0.id == entry.id } } label: { Image(systemName: "trash") }.buttonStyle(.plain) } }
                }

                // MARK: Your Projects (Phase 9.3 - Reuses ProjectEditorView)
                Section {
                    if store.customProjects.isEmpty {
                        Text("No projects yet. Add a rich project with details, skills, outcome, links, and photos.")
                            .font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    } else {
                        ForEach(store.customProjects) { proj in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(proj.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                                HStack(spacing: 6) {
                                    Text(proj.category).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                                    Text("•").foregroundColor(StudentOPSTheme.textSecondary)
                                    Text(proj.status.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                    if let out = proj.outcome, !out.isEmpty { Text("•").foregroundColor(StudentOPSTheme.textSecondary); Text(out).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1) }
                                }
                                if !proj.skills.isEmpty {
                                    Text(proj.skills.prefix(3).joined(separator: " • ")).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { editingProject = proj; showProjectEditor = true }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { _ = store.deleteCustomProject(id: proj.id) } label: { Label("Delete", systemImage: "trash") }
                                Button { editingProject = proj; showProjectEditor = true } label: { Label("Edit", systemImage: "pencil") }.tint(StudentOPSTheme.primary)
                            }
                        }
                    }
                    Button { editingProject = nil; showProjectEditor = true } label: { Label("Add Project", systemImage: "plus.circle.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark) }
                } header: {
                    Text("YOUR PROJECTS")
                } footer: {
                    Text("Projects use the same data foundation — Science Fair is just type = Science Fair. Links and photos are stored locally, evidence uses existing records.")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { save(); dismiss() } } }
            .sheet(isPresented: $showProjectEditor) {
                Group {
                    if let editing = editingProject {
                        ProjectEditorView(editingProject: editing)
                            .environmentObject(store)
                    } else {
                        ProjectEditorView()
                            .environmentObject(store)
                    }
                }
            }
        }
    }

    private func toggle(_ value: String, in values: inout [String]) { let t = value.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }; if let idx = values.firstIndex(of: t) { values.remove(at: idx) } else { values.append(t) } }
    private func addInterest() { let v = newInterest.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }; guard !profile.interests.contains(where: { $0.lowercased() == v.lowercased() }) else { newInterest=""; return }; profile.customInterests.append(v); profile.interests.append(v); newInterest="" }
    private func addSkill() { let v = newSkill.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }; guard !profile.customSkills.contains(where: { $0.lowercased() == v.lowercased() }) && !profile.strengths.contains(where: { $0.lowercased() == v.lowercased() }) else { newSkill=""; return }; profile.customSkills.append(v); newSkill = "" }
    private func addCareer() { let v = newCareer.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }; guard !profile.careers.contains(where: { $0.lowercased() == v.lowercased() }) else { newCareer=""; return }; profile.careers.append(v); newCareer="" }
    private func addMilestone() { let v = newMilestone.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }; guard !profile.milestones.contains(where: { $0.lowercased() == v.lowercased() }) else { newMilestone=""; return }; profile.milestones.append(v); newMilestone="" }
    private func addField() { let v = newField.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }; guard !profile.fields.contains(where: { $0.lowercased() == v.lowercased() }) else { newField=""; return }; profile.fields.append(v); newField="" }
    private func addCollege() { let v = newCollege.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }; guard !profile.targetColleges.contains(where: { $0.lowercased() == v.lowercased() }) else { newCollege=""; return }; profile.targetColleges.append(v); newCollege="" }
    private func addExperience() { let v = newExperience.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }; profile.loggedEntries.append(.init(title: v, category: experienceCategory)); newExperience = "" }
    private func save() {
        // Persist via canonical store when available; fallback to UserDefaults for standalone use (e.g., onboarding preview)
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "studentops.profile")
            // Keep onboarding flag in sync if profile says completed
            if profile.onboardingCompleted { UserDefaults.standard.set(true, forKey: "studentops.onboardingCompleted") }
        }
        // If presented from Progress (store exists), binding already updated store.profile via two-way binding.
        // No duplicate AppDataStore write needed; didSet on store.profile persists.
    }
}
