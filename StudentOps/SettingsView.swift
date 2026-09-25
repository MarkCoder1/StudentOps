import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) private var dismiss

    // Editors
    @State private var showNameEditor = false
    @State private var showAgeEditor = false
    @State private var showGradeEditor = false
    @State private var showCityEditor = false
    @State private var showInterestsEditor = false
    @State private var showCareerEditor = false
    @State private var showFieldsEditor = false
    @State private var showGoalsEditor = false
    @State private var showCollegePlanEditor = false
    @State private var showGeographyEditor = false
    @State private var showCollegeTypeEditor = false
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // ACCOUNT / PROFILE
                Section {
                    settingsRow(title: "Name", value: store.profile.firstName.isEmpty ? "Not set" : store.profile.firstName) { showNameEditor = true }
                    settingsRow(title: "Age", value: store.profile.age.isEmpty ? "Not set" : store.profile.age) { showAgeEditor = true }
                    settingsRow(title: "Grade", value: store.profile.grade.rawValue) { showGradeEditor = true }
                    settingsRow(title: "City", value: store.profile.location.isEmpty ? "Not set" : store.profile.location) { showCityEditor = true }
                    settingsRow(title: "Interests", value: interestsSummary) { showInterestsEditor = true }
                    settingsRow(title: "Career Direction", value: store.profile.careers.isEmpty ? "Not set" : store.profile.careers.joined(separator: ", ")) { showCareerEditor = true }
                    settingsRow(title: "Field of Study", value: store.profile.fields.isEmpty ? "Not set" : store.profile.fields.joined(separator: ", ")) { showFieldsEditor = true }
                    settingsRow(title: "Goals", value: store.profile.milestones.isEmpty ? "Not set" : store.profile.milestones.joined(separator: ", ")) { showGoalsEditor = true }
                    settingsRow(title: "College Plan", value: store.profile.collegePlan.rawValue) { showCollegePlanEditor = true }
                    settingsRow(title: "Location Preference", value: store.profile.geography.isEmpty ? "Not set" : store.profile.geography) { showGeographyEditor = true }
                    settingsRow(title: "College Type", value: store.profile.collegeType.isEmpty ? "Not set" : store.profile.collegeType) { showCollegeTypeEditor = true }
                } header: {
                    Text("Profile").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                } footer: {
                    Text("Changes update your Student OPS profile and personalize roadmaps, projects, and opportunities.").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.mutedText)
                }
                .listRowBackground(StudentOPSTheme.surface)

                // APPEARANCE
                Section {
                    Picker("Theme", selection: $appearanceManager.preference) {
                        ForEach(AppearancePreference.allCases) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(StudentOPSTheme.surface)
                } header: {
                    Text("Appearance").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                } footer: {
                    Text("Choose how Student OPS looks. System follows your device.").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.mutedText)
                }

                // SUBSCRIPTION — reuse existing SubscriptionStatusView (single source of truth)
                Section {
                    SubscriptionStatusView()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Subscription").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }

                // DATA / RESET
                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset Everything", systemImage: "trash")
                    }
                    .listRowBackground(StudentOPSTheme.surface)
                } header: {
                    Text("Data").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                } footer: {
                    Text("Deletes all Student OPS data and returns to onboarding. Start completely fresh, as if newly installed. Does not affect subscription.").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.mutedText)
                }

                // ABOUT
                Section {
                    HStack {
                        Text("Student OPS")
                        Spacer()
                        Text(appVersion).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    .listRowBackground(StudentOPSTheme.surface)
                    NavigationLink(destination: AboutView()) {
                        Text("About Student OPS")
                    }
                    .listRowBackground(StudentOPSTheme.surface)
                } header: {
                    Text("About").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(StudentOPSTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Editors
            .sheet(isPresented: $showNameEditor) { NameEditorView { showNameEditor = false } }
            .sheet(isPresented: $showAgeEditor) { AgeEditorView { showAgeEditor = false } }
            .sheet(isPresented: $showGradeEditor) { GradeEditorView { showGradeEditor = false } }
            .sheet(isPresented: $showCityEditor) { CityEditorView { showCityEditor = false } }
            .sheet(isPresented: $showInterestsEditor) { InterestsEditorView { showInterestsEditor = false } }
            .sheet(isPresented: $showCareerEditor) { CareerEditorView { showCareerEditor = false } }
            .sheet(isPresented: $showFieldsEditor) { FieldsEditorView { showFieldsEditor = false } }
            .sheet(isPresented: $showGoalsEditor) { GoalsEditorView { showGoalsEditor = false } }
            .sheet(isPresented: $showCollegePlanEditor) { CollegePlanEditorView { showCollegePlanEditor = false } }
            .sheet(isPresented: $showGeographyEditor) { GeographyEditorView { showGeographyEditor = false } }
            .sheet(isPresented: $showCollegeTypeEditor) { CollegeTypeEditorView { showCollegeTypeEditor = false } }
            .alert("Reset Everything?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset Everything", role: .destructive) { resetEverything() }
            } message: {
                Text("This will delete all profile, projects, achievements, evidence, roadmaps, progress, opportunities, adaptive state, and onboarding data and return to the first onboarding screen. This cannot be undone. Subscription is not affected.")
            }
        }
    }

    private var interestsSummary: String {
        let all = store.profile.interests
        if all.isEmpty { return "Not set" }
        return all.prefix(3).joined(separator: ", ") + (all.count > 3 ? " +\(all.count - 3)" : "")
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    private func resetEverything() {
        // Fresh-install reset — clears all Student OPS user data, no demo preload, survives restart, preserves RevenueCat
        store.resetEverything()
        // Dismiss settings after reset so onboarding is visible
        dismiss()
    }

    private func settingsRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text(value).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.mutedText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(title): \(value)"))
    }
}

// MARK: - Editors

private struct NameEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    var onDone: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("Not empty, trimmed.").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.mutedText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(StudentOPSTheme.background)
            .navigationTitle("Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss(); onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, trimmed.count <= 40 else { return }
                        var p = store.profile
                        p.firstName = trimmed
                        store.profile = p
                        dismiss(); onDone()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).count > 40)
                }
            }
            .onAppear { name = store.profile.firstName }
        }
    }
}

private struct AgeEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var age: String = ""
    var onDone: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                } footer: {
                    Text("Enter a number between 10 and 25.").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.mutedText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(StudentOPSTheme.background)
            .navigationTitle("Age")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss(); onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = age.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard let v = Int(trimmed), (10...25).contains(v) else { return }
                        var p = store.profile
                        p.age = String(v)
                        store.profile = p
                        dismiss(); onDone()
                    }
                    .disabled(Int(age.trimmingCharacters(in: .whitespacesAndNewlines)) == nil || !(10...25).contains(Int(age.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0))
                }
            }
            .onAppear { age = store.profile.age }
        }
    }
}

private struct GradeEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    var onDone: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Picker("Grade", selection: Binding(
                    get: { store.profile.grade },
                    set: { newGrade in
                        var p = store.profile
                        p.grade = newGrade
                        // Keep schoolLevel consistent
                        if !newGrade.isValid(for: p.schoolLevel) {
                            p.schoolLevel = newGrade.defaultSchoolLevel
                        }
                        store.profile = p
                    }
                )) {
                    ForEach(Grade.allCases, id: \.self) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.inline)
            }
            .scrollContentBackground(.hidden)
            .background(StudentOPSTheme.background)
            .navigationTitle("Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss(); onDone() } }
            }
        }
    }
}

private extension Grade {
    func isValid(for level: SchoolLevel) -> Bool {
        level.availableGrades.contains(self)
    }
    var defaultSchoolLevel: SchoolLevel {
        switch self {
        case .seventh, .eighth: return .middleSchool
        case .ninth, .tenth, .eleventh, .twelfth: return .highSchool
        }
    }
}

private struct CityEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var city: String = ""
    var onDone: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("City", text: $city)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("Stored as profile location. No precise location tracking.").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.mutedText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(StudentOPSTheme.background)
            .navigationTitle("City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss(); onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        var p = store.profile
                        p.location = trimmed
                        store.profile = p
                        dismiss(); onDone()
                    }
                    .disabled(city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { city = store.profile.location }
        }
    }
}

private struct InterestsEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var custom = ""
    private let allInterests = ["💻 Technology", "🤖 AI", "⚙️ Engineering", "🔬 Science", "📊 Business", "🩺 Medicine", "🎨 Design", "🎭 Arts", "✍️ Writing", "⚖️ Law", "📚 Education", "🌱 Environment", "🚀 Entrepreneurship", "🏀 Sports"]
    var onDone: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select interests").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(allInterests, id: \.self) { interest in
                            let title = interest.drop(while: { !$0.isWhitespace }).trimmingCharacters(in: .whitespaces).description
                            let isSelected = store.profile.interests.contains(title) || store.profile.interests.contains(interest)
                            SelectableChip(title: interest, selected: isSelected) {
                                var p = store.profile
                                let t = title
                                if let idx = p.interests.firstIndex(of: t) { p.interests.remove(at: idx) }
                                else if let idx2 = p.interests.firstIndex(of: interest) { p.interests.remove(at: idx2) }
                                else { p.interests.append(t) }
                                store.profile = p
                            }
                        }
                    }
                    if !store.profile.customInterests.isEmpty {
                        Text("Custom interests").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        FlowLayout(spacing: 6) {
                            ForEach(store.profile.customInterests, id: \.self) { item in
                                Button {
                                    var p = store.profile
                                    p.customInterests.removeAll { $0 == item }
                                    p.interests.removeAll { $0 == item }
                                    store.profile = p
                                } label: {
                                    Text("\(item) ×").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    HStack {
                        TextField("Add interest", text: $custom)
                        Button("Add") {
                            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            var p = store.profile
                            guard !p.interests.contains(where: { $0.lowercased() == t.lowercased() }) else { custom = ""; return }
                            p.customInterests.append(t)
                            p.interests.append(t)
                            store.profile = p
                            custom = ""
                        }.disabled(custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding()
            }
            .background(StudentOPSTheme.background)
            .navigationTitle("Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss(); onDone() } } }
        }
    }
}

private struct CareerEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var custom = ""
    private let careerOptions = ["Software Engineer", "AI Researcher", "Biomedical Engineer", "Product Designer"]
    var onDone: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Career direction").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(careerOptions, id: \.self) { c in
                            SelectableChip(title: c, selected: store.profile.careers.contains(c)) {
                                var p = store.profile
                                if let idx = p.careers.firstIndex(of: c) { p.careers.remove(at: idx) } else { p.careers.append(c) }
                                store.profile = p
                            }
                        }
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(store.profile.careers.filter { !careerOptions.contains($0) }, id: \.self) { item in
                            Button {
                                var p = store.profile
                                p.careers.removeAll { $0 == item }
                                store.profile = p
                            } label: {
                                Text("\(item) ×").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField("Add career", text: $custom)
                        Button("Add") {
                            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty, !store.profile.careers.contains(where: { $0.lowercased() == t.lowercased() }) else { custom = ""; return }
                            var p = store.profile
                            p.careers.append(t)
                            store.profile = p
                            custom = ""
                        }.disabled(custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("Changing career updates recommendations deterministically.").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.mutedText)
                }.padding()
            }
            .background(StudentOPSTheme.background)
            .navigationTitle("Career Direction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss(); onDone() } } }
        }
    }
}

private struct FieldsEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var custom = ""
    private let fieldOptions = ["Computer Science", "Engineering", "Biology", "Medicine", "Business", "Psychology", "Arts", "Law"]
    var onDone: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Field of study").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(fieldOptions, id: \.self) { f in
                            SelectableChip(title: f, selected: store.profile.fields.contains(f)) {
                                var p = store.profile
                                if let idx = p.fields.firstIndex(of: f) { p.fields.remove(at: idx) } else { p.fields.append(f) }
                                store.profile = p
                            }
                        }
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(store.profile.fields.filter { !fieldOptions.contains($0) }, id: \.self) { item in
                            Button {
                                var p = store.profile
                                p.fields.removeAll { $0 == item }
                                store.profile = p
                            } label: {
                                Text("\(item) ×").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField("Add field", text: $custom)
                        Button("Add") {
                            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty, !store.profile.fields.contains(where: { $0.lowercased() == t.lowercased() }) else { custom = ""; return }
                            var p = store.profile
                            p.fields.append(t)
                            store.profile = p
                            custom = ""
                        }.disabled(custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding()
            }
            .background(StudentOPSTheme.background)
            .navigationTitle("Field of Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss(); onDone() } } }
        }
    }
}

private struct GoalsEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var custom = ""
    private let milestoneOptions = ["Build real projects", "Develop technical skills", "Prepare for college", "Find competitions & research labs"]
    var onDone: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Goals").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(milestoneOptions, id: \.self) { m in
                            SelectableChip(title: m, selected: store.profile.milestones.contains(m)) {
                                var p = store.profile
                                if let idx = p.milestones.firstIndex(of: m) { p.milestones.remove(at: idx) } else { p.milestones.append(m) }
                                store.profile = p
                            }
                        }
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(store.profile.milestones.filter { !milestoneOptions.contains($0) }, id: \.self) { item in
                            Button {
                                var p = store.profile
                                p.milestones.removeAll { $0 == item }
                                store.profile = p
                            } label: {
                                Text("\(item) ×").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField("Add goal", text: $custom)
                        Button("Add") {
                            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty, !store.profile.milestones.contains(where: { $0.lowercased() == t.lowercased() }) else { custom = ""; return }
                            var p = store.profile
                            p.milestones.append(t)
                            store.profile = p
                            custom = ""
                        }.disabled(custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding()
            }
            .background(StudentOPSTheme.background)
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss(); onDone() } } }
        }
    }
}

private struct CollegePlanEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    var onDone: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("College Plan", selection: Binding(
                        get: { store.profile.collegePlan },
                        set: { newVal in var p = store.profile; p.collegePlan = newVal; store.profile = p }
                    )) {
                        ForEach(CollegePlan.allCases, id: \.self) { plan in
                            Text(plan.rawValue).tag(plan)
                        }
                    }.pickerStyle(.inline)
                }
            }
            .scrollContentBackground(.hidden)
            .background(StudentOPSTheme.background)
            .navigationTitle("College Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss(); onDone() } } }
        }
    }
}

private struct GeographyEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    var onDone: () -> Void
    private let options = ["In-state (Texas)", "Anywhere in U.S.", "Out-of-state", "Not sure yet"]
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Location Preference", selection: Binding(
                        get: { store.profile.geography },
                        set: { var p = store.profile; p.geography = $0; store.profile = p }
                    )) {
                        ForEach(options, id: \.self) { o in Text(o).tag(o) }
                        Text("Not set").tag("")
                    }.pickerStyle(.inline)
                    HStack {
                        TextField("Custom", text: $text)
                        Button("Set") {
                            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            var p = store.profile
                            p.geography = t
                            store.profile = p
                            text = ""
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(StudentOPSTheme.background)
            .navigationTitle("Location Preference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss(); onDone() } } }
            .onAppear { text = "" }
        }
    }
}

private struct CollegeTypeEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    var onDone: () -> Void
    private let options = ["4-year university", "Community college", "Technical/trade", "Not sure yet"]
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("College Type", selection: Binding(
                        get: { store.profile.collegeType },
                        set: { var p = store.profile; p.collegeType = $0; store.profile = p }
                    )) {
                        ForEach(options, id: \.self) { o in Text(o).tag(o) }
                        Text("Not set").tag("")
                    }.pickerStyle(.inline)
                }
            }
            .scrollContentBackground(.hidden)
            .background(StudentOPSTheme.background)
            .navigationTitle("College Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss(); onDone() } } }
        }
    }
}

private struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Student OPS").font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text("Student OPS connects your goals, skills, projects, opportunities, and progress into one personalized operating system.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.mutedText)
                }
                .listRowBackground(StudentOPSTheme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(StudentOPSTheme.background)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
