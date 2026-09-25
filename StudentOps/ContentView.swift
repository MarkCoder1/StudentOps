//
//  ContentView.swift
//  StudentOps
//
//  Created by Mark Adam on 9/7/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    @AppStorage("studentops.introOnboardingCompleted") private var introOnboardingCompleted = false
    @AppStorage("studentops.onboardingCompleted") private var onboardingCompleted = false
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var appearanceManager: AppearanceManager

    var body: some View {
        Group {
            if onboardingCompleted || viewModel.profile.onboardingCompleted || store.profile.onboardingCompleted {
                HomeDashboardView()
                    .environmentObject(store)
                    .onAppear {
                        // Sync AppStorage with profile flag after migration
                        if (viewModel.profile.onboardingCompleted || store.profile.onboardingCompleted) && !onboardingCompleted {
                            onboardingCompleted = true
                        }
                        // One-time sync: if onboarding just completed, ensure store has latest profile
                        if viewModel.profile.onboardingCompleted && !store.profile.onboardingCompleted {
                            store.profile = viewModel.profile
                        }
                    }
            } else if !introOnboardingCompleted {
                OnboardingContainerView(onFinish: handleIntroOnboardingFinish)
                    .environmentObject(store)
            } else if viewModel.currentStep <= viewModel.totalSteps {
                OnboardingStepView(viewModel: viewModel)
                    .environmentObject(store)
            } else {
                Step7SummaryView(viewModel: viewModel) {
                    viewModel.completeOnboarding()
                    // Single source: push completed profile into shared store
                    store.profile = viewModel.profile
                    // Migrate onboarding projects to store's customProjects
                    for proj in viewModel.onboardingProjects {
                        _ = store.addCustomProject(proj)
                    }
                    viewModel.clearOnboardingProjects()
                    onboardingCompleted = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
        .onAppear {
            // If profile was already completed but AppStorage was false (migration), fix routing
            if (viewModel.profile.onboardingCompleted || store.profile.onboardingCompleted) && !onboardingCompleted {
                onboardingCompleted = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("studentops.didResetEverything"))) { _ in
            introOnboardingCompleted = false
            onboardingCompleted = false
            viewModel.profile = StudentProfile()
            viewModel.currentStep = 1
            viewModel.validationMessage = nil
            viewModel.onboardingProjects = []
            UserDefaults.standard.removeObject(forKey: "studentops.introOnboardingCompleted")
            UserDefaults.standard.removeObject(forKey: "studentops.onboarding.projects")
            UserDefaults.standard.removeObject(forKey: "studentops.profile")
            UserDefaults.standard.removeObject(forKey: "studentops.onboardingCompleted")
        }
    }

    private func handleIntroOnboardingFinish() {
        // Intro 4-screen flow completed — advance to profile setup (step 1), do NOT mark final onboarding complete
        // No duplicate persistence: uses existing UserDefaults key "studentops.introOnboardingCompleted"
        introOnboardingCompleted = true
        UserDefaults.standard.set(true, forKey: "studentops.introOnboardingCompleted")
        // Ensure profile setup starts fresh at step 1
        viewModel.currentStep = 1
        viewModel.validationMessage = nil
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDataStore())
        .environmentObject(AppearanceManager())
}

// MARK: - Foundation (moved to StudentOPSTheme.swift)
// Color(hex:) now in StudentOPSTheme.swift — single source.

// (BrandColor shim removed — now using StudentOPSTheme directly)

enum AppFont {
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}

enum Radius {
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 18
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Profile and persistence

enum SchoolLevel: String, CaseIterable, Codable {
    case middleSchool = "Middle School"
    case highSchool = "High School"

    var availableGrades: [Grade] {
        switch self {
        case .middleSchool: return [.seventh, .eighth]
        case .highSchool: return [.ninth, .tenth, .eleventh, .twelfth]
        }
    }
}
enum Grade: String, CaseIterable, Codable {
    case seventh = "7th"
    case eighth = "8th"
    case ninth = "9th"
    case tenth = "10th"
    case eleventh = "11th"
    case twelfth = "12th"
}
struct AccomplishmentEntry: Identifiable, Hashable, Codable { let id: UUID; let title: String; let category: String; init(title: String, category: String) { id = UUID(); self.title = title; self.category = category } }
enum CollegePlan: String, CaseIterable, Codable {
    case yesDefinitely = "Yes, definitely"
    case probably = "Probably"
    case notSure = "Not sure"
    case no = "No"
    case exploringOthers = "Exploring other paths"
    // Backward compat: old value "I'm not sure yet" -> notSure
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        switch raw {
        case "Yes, definitely": self = .yesDefinitely
        case "Probably": self = .probably
        case "I'm not sure yet", "Not sure": self = .notSure
        case "No": self = .no
        case "Exploring others", "Exploring other paths": self = .exploringOthers
        default: self = .notSure
        }
    }
}

struct StudentProfile: Codable, Equatable {
    var id: UUID = UUID()
    var firstName = ""
    var age: String = ""
    var schoolLevel = SchoolLevel.highSchool
    var grade = Grade.ninth
    var location = ""
    var interests: [String] = []
    var customInterests: [String] = []
    var strengths: [String] = []
    var customSkills: [String] = []
    var notSureYet = false
    var careers: [String] = []
    var milestones: [String] = []
    var collegePlan = CollegePlan.notSure
    var fields: [String] = []
    var geography = ""
    var collegeType = ""
    var targetColleges: [String] = []
    var justGettingStarted = false
    var categories: [String: Int] = [:]
    var loggedEntries: [AccomplishmentEntry] = []
    var onboardingCompleted: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, firstName, age, schoolLevel, grade, location, interests, customInterests, strengths, customSkills, notSureYet, careers, milestones, collegePlan, fields, geography, collegeType, targetColleges, justGettingStarted, categories, loggedEntries, onboardingCompleted
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        firstName = (try? c.decode(String.self, forKey: .firstName)) ?? ""
        	// Age may historically be String or Int — handle both for migration
        if let str = try? c.decode(String.self, forKey: .age) {
            age = str
        } else if let intVal = try? c.decode(Int.self, forKey: .age) {
            age = String(intVal)
        } else {
            age = ""
        }
        schoolLevel = (try? c.decode(SchoolLevel.self, forKey: .schoolLevel)) ?? .highSchool
        // Migrate legacy grades that are no longer valid for current schoolLevel: will be fixed in UI
        grade = (try? c.decode(Grade.self, forKey: .grade)) ?? .ninth
        location = (try? c.decode(String.self, forKey: .location)) ?? ""
        interests = (try? c.decode([String].self, forKey: .interests)) ?? []
        customInterests = (try? c.decode([String].self, forKey: .customInterests)) ?? []
        // Migrate old custom interests that were stored directly in interests but not in customInterests: keep as-is; no auto-split.
        strengths = (try? c.decode([String].self, forKey: .strengths)) ?? []
        customSkills = (try? c.decode([String].self, forKey: .customSkills)) ?? []
        notSureYet = (try? c.decode(Bool.self, forKey: .notSureYet)) ?? false
        careers = (try? c.decode([String].self, forKey: .careers)) ?? []
        milestones = (try? c.decode([String].self, forKey: .milestones)) ?? []
        collegePlan = (try? c.decode(CollegePlan.self, forKey: .collegePlan)) ?? .notSure
        fields = (try? c.decode([String].self, forKey: .fields)) ?? []
        geography = (try? c.decode(String.self, forKey: .geography)) ?? ""
        collegeType = (try? c.decode(String.self, forKey: .collegeType)) ?? ""
        targetColleges = (try? c.decode([String].self, forKey: .targetColleges)) ?? []
        justGettingStarted = (try? c.decode(Bool.self, forKey: .justGettingStarted)) ?? false
        categories = (try? c.decode([String: Int].self, forKey: .categories)) ?? [:]
        loggedEntries = (try? c.decode([AccomplishmentEntry].self, forKey: .loggedEntries)) ?? []
            onboardingCompleted = (try? c.decode(Bool.self, forKey: .onboardingCompleted)) ?? false
    }
}

@MainActor final class OnboardingViewModel: ObservableObject {
    @Published var profile: StudentProfile
    @Published var currentStep = 1
    @Published var validationMessage: String?
    @Published var onboardingProjects: [Project] = []
    let totalSteps = 6
    private let onboardingProjectsKey = "studentops.onboarding.projects"

    let allInterests = ["💻 Technology", "🤖 AI", "⚙️ Engineering", "🔬 Science", "📊 Business", "🩺 Medicine", "🎨 Design", "🎭 Arts", "✍️ Writing", "⚖️ Law", "📚 Education", "🌱 Environment", "🚀 Entrepreneurship", "🏀 Sports"]
    let coreStrengths = ["Problem solving", "Programming", "Mathematics", "Building things", "Public speaking", "Creativity", "Leadership", "Research", "Writing", "Communication", "Teamwork"]
    let careers = ["Software Engineer", "AI Researcher", "Biomedical Engineer", "Product Designer"]
    let milestones = ["Build real projects", "Develop technical skills", "Prepare for college", "Find competitions & research labs"]
    let fields = ["Computer Science", "Engineering", "Biology", "Medicine", "Business", "Psychology", "Arts", "Law"]
    let geographies = ["In-state (Texas)", "Anywhere in U.S.", "Out-of-state", "Not sure yet"]
    let collegeTypes = ["4-year university", "Community college", "Technical/trade", "Not sure yet"]
    let categories = ["Projects", "Competitions", "Awards", "Volunteering", "Leadership", "Clubs", "Certifications", "Work/Job"]

    init() {
        if let data = UserDefaults.standard.data(forKey: "studentops.profile"), let saved = try? JSONDecoder().decode(StudentProfile.self, from: data) {
            profile = saved
            // Migrate old seeded data: if profile has no id or is still seeded Mark/Texas with onboarding not completed, keep as-is for existing users; otherwise use saved.
            // If there is an AppStorage flag but profile flag is out of sync, reconcile.
            let appFlag = UserDefaults.standard.bool(forKey: "studentops.onboardingCompleted")
            if appFlag && !profile.onboardingCompleted {
                profile.onboardingCompleted = true
            }
        } else {
            profile = StudentProfile()
        }
        if let data = UserDefaults.standard.data(forKey: onboardingProjectsKey), let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            onboardingProjects = decoded
        }
        // Ensure currentStep reflects completed state for relaunch
        if profile.onboardingCompleted {
            // Move past onboarding on next launch via ContentView check; keep step at 7 for consistency
            // currentStep stays 1 but ContentView will route to Home via onboardingCompleted flag
        }
    }

    func saveDraft() {
        if let data = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(data, forKey: "studentops.profile") }
        if let data = try? JSONEncoder().encode(onboardingProjects) { UserDefaults.standard.set(data, forKey: onboardingProjectsKey) }
    }

    func next() {
        if currentStep == 1 {
            if profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { validationMessage = "Please enter your first name."; return }
            if profile.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { validationMessage = "Please enter your location or state."; return }
        }
        validationMessage = nil
        saveDraft(); currentStep = min(currentStep + 1, totalSteps + 1)
    }

    func back() { validationMessage = nil; saveDraft(); currentStep = max(currentStep - 1, 1) }
    func completeOnboarding() {
        profile.onboardingCompleted = true
        saveDraft()
        UserDefaults.standard.set(true, forKey: "studentops.onboardingCompleted")
    }
    func toggle(_ value: String, in values: inout [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let index = values.firstIndex(of: trimmed) { values.remove(at: index) } else { values.append(trimmed) }
    }
    func addCustomInterest(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !interestsContain(trimmed) else { return }
        profile.customInterests.append(trimmed)
        profile.interests.append(trimmed)
        saveDraft()
    }
    func interestsContain(_ value: String) -> Bool {
        let lower = value.lowercased()
        return profile.interests.contains(where: { $0.lowercased() == lower }) || profile.customInterests.contains(where: { $0.lowercased() == lower })
    }
    func addCustomSkill(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !profile.customSkills.contains(where: { $0.lowercased() == trimmed.lowercased() }) && !profile.strengths.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        profile.customSkills.append(trimmed)
        saveDraft()
    }
    func addCustomCareer(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !profile.careers.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        profile.careers.append(trimmed)
        saveDraft()
    }
    func addCustomMilestone(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !profile.milestones.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        profile.milestones.append(trimmed)
        saveDraft()
    }
    func addCustomField(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !profile.fields.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        profile.fields.append(trimmed)
        saveDraft()
    }
    func addCollege(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !profile.targetColleges.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        profile.targetColleges.append(trimmed)
        saveDraft()
    }
    func addExperienceEntry(title: String, category: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Prevent duplicate title+category
        guard !profile.loggedEntries.contains(where: { $0.title.lowercased() == trimmed.lowercased() && $0.category == category }) else { return }
        profile.loggedEntries.append(AccomplishmentEntry(title: trimmed, category: category))
        // Also ensure categories map reflects used categories
        profile.categories[category] = (profile.categories[category] ?? 0) + 1
        saveDraft()
    }
    func removeExperienceEntry(_ entry: AccomplishmentEntry) {
        profile.loggedEntries.removeAll { $0.id == entry.id }
        // Decrement category count but keep at least 0
        if let count = profile.categories[entry.category] {
            if count <= 1 { profile.categories.removeValue(forKey: entry.category) } else { profile.categories[entry.category] = count - 1 }
        }
        saveDraft()
    }

    // MARK: - Onboarding Projects (Phase 9.3)

    func addOnboardingProject(_ project: Project) {
        let t = project.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        guard !onboardingProjects.contains(where: { $0.id == project.id }) else { return }
        onboardingProjects.append(project)
        saveDraft()
    }

    func updateOnboardingProject(_ project: Project) {
        guard let idx = onboardingProjects.firstIndex(where: { $0.id == project.id }) else { return }
        let t = project.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onboardingProjects[idx] = project
        saveDraft()
    }

    func removeOnboardingProject(id: String) {
        onboardingProjects.removeAll { $0.id == id }
        saveDraft()
    }

    func clearOnboardingProjects() {
        onboardingProjects.removeAll()
        UserDefaults.standard.removeObject(forKey: onboardingProjectsKey)
    }
}

// MARK: - Shared controls

struct TopNav: View {
    let step: Int; var showBack = true; var back: () -> Void
    var body: some View { HStack { if showBack { Button(action: back) { Label("Back", systemImage: "chevron.left").font(AppFont.inter(12, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary) } } else { Text("OPS").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.primaryDark).padding(8).background(StudentOPSTheme.primaryDark.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8)); Text("STUDENT PROFILE SETUP").font(AppFont.inter(11, weight: .bold)).tracking(0.5).foregroundColor(StudentOPSTheme.textSecondary) }; Spacer(); Text("Step \(step) of 6").font(AppFont.inter(11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 10).padding(.vertical, 4).background(StudentOPSTheme.background).clipShape(Capsule()) } }
}

struct StepScaffold<Content: View>: View {
    let step: Int; let title: String; let subtitle: String; let eyebrow: String; var showBack = true; var back: () -> Void; @ViewBuilder let content: Content; let nextTitle: String; let next: () -> Void
    var body: some View { VStack(spacing: 0) { VStack(alignment: .leading, spacing: 16) { TopNav(step: step, showBack: showBack, back: back); HStack(spacing: 6) { ForEach(1...6, id: \.self) { item in Capsule().fill(item < step ? StudentOPSTheme.primary : item == step ? StudentOPSTheme.primaryDark : StudentOPSTheme.background).frame(height: 6) } }; VStack(alignment: .leading, spacing: 6) { Text(eyebrow).font(AppFont.inter(11, weight: .bold)).tracking(0.5).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 10).padding(.vertical, 3).background(StudentOPSTheme.primaryDark.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 6)); Text(title).font(AppFont.inter(24, weight: .heavy)).foregroundColor(StudentOPSTheme.textPrimary); Text(subtitle).font(AppFont.inter(14)).foregroundColor(StudentOPSTheme.textSecondary) } }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8); ScrollView(showsIndicators: false) { VStack(alignment: .leading, spacing: 14) { content }.padding(.horizontal, 20).padding(.bottom, 16) }; HStack(spacing: 12) { if showBack { SecondaryButton(title: "Back", action: back) }; PrimaryButton(title: nextTitle, action: next) }.padding(20).background(StudentOPSTheme.surface.overlay(Rectangle().frame(height: 1).foregroundColor(StudentOPSTheme.border), alignment: .top)) }.background(StudentOPSTheme.surface) }
}

struct PrimaryButton: View { let title: String; var action: () -> Void; var body: some View { Button(action: action) { HStack { Spacer(); Text(title).font(AppFont.inter(15, weight: .bold)); Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold)); Spacer() }.foregroundColor(StudentOPSTheme.textOnPrimary).padding(.vertical, 16).background(StudentOPSTheme.primary).clipShape(RoundedRectangle(cornerRadius: Radius.xl)).shadow(color: StudentOPSTheme.primary.opacity(0.25), radius: 12, y: 6) }.buttonStyle(.plain) } }
struct SecondaryButton: View { let title: String; var action: () -> Void; var body: some View { Button(title, action: action).font(AppFont.inter(12, weight: .bold)).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 18).padding(.vertical, 16).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: Radius.xl).stroke(StudentOPSTheme.border)).buttonStyle(.plain) } }
struct SelectableChip: View { let title: String; let selected: Bool; var action: () -> Void; var body: some View { Button(action: action) { HStack(spacing: 6) { Text(title).font(AppFont.inter(12, weight: selected ? .bold : .medium)); if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) } }.foregroundColor(selected ? StudentOPSTheme.primaryDark : StudentOPSTheme.textPrimary).padding(.horizontal, 14).padding(.vertical, 8).background(selected ? StudentOPSTheme.primaryDark.opacity(0.05) : StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(selected ? StudentOPSTheme.primaryDark : StudentOPSTheme.border, lineWidth: selected ? 2 : 1)) }.buttonStyle(.plain) } }
struct BoxedField: View { let label: String; @Binding var text: String; var placeholder: String; var keyboardType: UIKeyboardType = .default; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(label).font(AppFont.inter(11, weight: .bold)).tracking(0.5).foregroundColor(StudentOPSTheme.textPrimary); TextField(placeholder, text: $text).font(AppFont.inter(16, weight: .semibold)).keyboardType(keyboardType) }.padding(14).background(StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(StudentOPSTheme.border)).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) } }

// MARK: - Steps

struct OnboardingStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var body: some View { Group { switch viewModel.currentStep { case 1: Step1View(vm: viewModel); case 2: Step2View(vm: viewModel); case 3: Step3View(vm: viewModel); case 4: Step4View(vm: viewModel); case 5: Step5View(vm: viewModel); default: Step6View(vm: viewModel) } }.alert("A little more information needed", isPresented: Binding(get: { viewModel.validationMessage != nil }, set: { if !$0 { viewModel.validationMessage = nil } })) { Button("OK") { viewModel.validationMessage = nil } } message: { Text(viewModel.validationMessage ?? "") } }
}

struct Step1View: View { @ObservedObject var vm: OnboardingViewModel; var body: some View { StepScaffold(step: 1, title: "About you", subtitle: "Let's calibrate your personalized roadmap, opportunities, and college tracks.", eyebrow: "FOUNDATION IDENTITY", showBack: false, back: {}, content: { BoxedField(label: "FIRST NAME", text: $vm.profile.firstName, placeholder: "e.g. Mark"); BoxedField(label: "AGE", text: $vm.profile.age, placeholder: "e.g. 15", keyboardType: .numberPad); PickerCard(label: "SCHOOL LEVEL", values: SchoolLevel.allCases.map(\.rawValue), selection: Binding(get: { vm.profile.schoolLevel.rawValue }, set: { newValue in
                    let newLevel = SchoolLevel(rawValue: newValue) ?? .highSchool
                    vm.profile.schoolLevel = newLevel
                    // Ensure grade is valid for new school level
                    if !newLevel.availableGrades.contains(vm.profile.grade) {
                        vm.profile.grade = newLevel.availableGrades.first ?? .ninth
                    }
                    vm.saveDraft()
                })); GradeCard(grade: $vm.profile.grade, schoolLevel: vm.profile.schoolLevel); BoxedField(label: "LOCATION OR STATE", text: $vm.profile.location, placeholder: "e.g. Austin, TX or California") }, nextTitle: "Continue to Interests", next: vm.next) } }
struct PickerCard: View { let label: String; let values: [String]; @Binding var selection: String; var body: some View { VStack(alignment: .leading, spacing: 10) { Text(label).font(AppFont.inter(11, weight: .bold)).tracking(0.5).foregroundColor(StudentOPSTheme.textPrimary); HStack { ForEach(values, id: \.self) { value in Button { selection = value } label: { Text(value).font(AppFont.inter(12, weight: .bold)).foregroundColor(selection == value ? StudentOPSTheme.primaryDark : StudentOPSTheme.textSecondary).frame(maxWidth: .infinity).padding(10).background(selection == value ? StudentOPSTheme.primaryDark.opacity(0.05) : StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(selection == value ? StudentOPSTheme.primaryDark : StudentOPSTheme.border, lineWidth: selection == value ? 2 : 1)) }.buttonStyle(.plain) } } }.padding(14).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) } }
struct GradeCard: View {
    @Binding var grade: Grade
    var schoolLevel: SchoolLevel
    var body: some View {
        let available = schoolLevel.availableGrades
        return PickerCard(label: "GRADE LEVEL", values: available.map(\.rawValue), selection: Binding(get: { grade.rawValue }, set: { newValue in
            grade = Grade(rawValue: newValue) ?? available.first ?? .ninth
        }))
    }
}

struct Step2View: View { @ObservedObject var vm: OnboardingViewModel; @State private var adding = false; @State private var custom = ""; var body: some View { StepScaffold(step: 2, title: "What are you interested in?", subtitle: "Select topics you find exciting. Choose as many as you like.", eyebrow: "EXPLORATION RADAR", back: vm.back, content: { LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) { ForEach(vm.allInterests, id: \.self) { interest in let title = interest.drop(while: { !$0.isWhitespace }).trimmingCharacters(in: .whitespaces); SelectableChip(title: interest, selected: vm.profile.interests.contains(title)) { vm.toggle(title, in: &vm.profile.interests); vm.saveDraft() } } }; if !vm.profile.customInterests.isEmpty { VStack(alignment: .leading, spacing: 6) { Text("YOUR CUSTOM INTERESTS").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary); FlowLayout(spacing: 6) { ForEach(vm.profile.customInterests, id: \.self) { item in Button { vm.profile.customInterests.removeAll { $0 == item }; vm.profile.interests.removeAll { $0 == item }; vm.saveDraft() } label: { Text("\(item) ×").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border)) }.buttonStyle(.plain) } } } }; Button { withAnimation { adding.toggle() } } label: { Text("✨  + Add other interest...").font(AppFont.inter(12, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary).padding(12).frame(maxWidth: .infinity, alignment: .leading).overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(StudentOPSTheme.border, style: StrokeStyle(lineWidth: 1, dash: [5]))) }.buttonStyle(.plain); if adding { HStack { TextField("e.g. Robotics, Film", text: $custom).textFieldStyle(.roundedBorder); Button("Add") { vm.addCustomInterest(custom); custom = ""; adding = false }.buttonStyle(.borderedProminent).disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty) }.onSubmit { vm.addCustomInterest(custom); custom = ""; adding = false } }; Text("\(vm.profile.interests.count) topics selected").font(AppFont.inter(12, weight: .medium)).foregroundColor(StudentOPSTheme.textSecondary) }, nextTitle: "Continue to Strengths", next: vm.next) } }

struct Step3View: View { @ObservedObject var vm: OnboardingViewModel; @State private var skill = ""; var body: some View { StepScaffold(step: 3, title: "What are you good at?", subtitle: "Select your natural strengths or technical skills, or add your own.", eyebrow: "COMPETENCY MATRIX", back: vm.back, content: { FlowLayout { ForEach(vm.coreStrengths, id: \.self) { item in SelectableChip(title: item, selected: vm.profile.strengths.contains(item)) { vm.toggle(item, in: &vm.profile.strengths); vm.saveDraft() } } }; VStack(alignment: .leading, spacing: 10) { Text("ADD YOUR OWN SKILLS & TOOLS").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary); HStack { TextField("e.g. Python, Figma, Video editing", text: $skill).textFieldStyle(.roundedBorder).onSubmit { vm.addCustomSkill(skill); skill = "" }; Button("Add") { vm.addCustomSkill(skill); skill = "" }.buttonStyle(.borderedProminent).disabled(skill.trimmingCharacters(in: .whitespaces).isEmpty) }; FlowLayout(spacing: 6) { ForEach(vm.profile.customSkills, id: \.self) { item in Button { vm.profile.customSkills.removeAll { $0 == item }; vm.saveDraft() } label: { Text("\(item) ×").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border)) }.buttonStyle(.plain) } } }.padding(14).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) }, nextTitle: "Continue to Goals", next: vm.next) } }

struct Step4View: View { @ObservedObject var vm: OnboardingViewModel; @State private var customCareer = ""; @State private var customMilestone = ""; var body: some View { StepScaffold(step: 4, title: "What do you want to work toward?", subtitle: "Select your current targets. No pressure to lock into a single career.", eyebrow: "TRAJECTORY VECTOR", back: vm.back, content: { Button { vm.profile.notSureYet.toggle(); vm.saveDraft() } label: { HStack { Text("💡  I'm not sure yet").font(AppFont.inter(12, weight: .bold)); Spacer(); Image(systemName: vm.profile.notSureYet ? "checkmark.circle.fill" : "circle").foregroundColor(StudentOPSTheme.primaryDark) }.foregroundColor(StudentOPSTheme.textPrimary).padding(14).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) }.buttonStyle(.plain); Text("CAREER & FIELD INTERESTS").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary); FlowLayout { ForEach(vm.careers, id: \.self) { item in SelectableChip(title: item, selected: vm.profile.careers.contains(item)) { vm.toggle(item, in: &vm.profile.careers); vm.saveDraft() } } }; HStack { TextField("Add career interest", text: $customCareer).textFieldStyle(.roundedBorder).onSubmit { vm.addCustomCareer(customCareer); customCareer = "" }; Button("Add") { vm.addCustomCareer(customCareer); customCareer = "" }.buttonStyle(.borderedProminent).disabled(customCareer.trimmingCharacters(in: .whitespaces).isEmpty) }; if !vm.profile.careers.filter({ !vm.careers.contains($0) }).isEmpty { FlowLayout(spacing: 6) { ForEach(vm.profile.careers.filter { !vm.careers.contains($0) }, id: \.self) { item in Button { vm.profile.careers.removeAll { $0 == item }; vm.saveDraft() } label: { Text("\(item) ×").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border)) }.buttonStyle(.plain) } } }; Text("PRIMARY MILESTONES").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary); ForEach(vm.milestones, id: \.self) { item in SelectableChip(title: item, selected: vm.profile.milestones.contains(item)) { vm.toggle(item, in: &vm.profile.milestones); vm.saveDraft() } }; HStack { TextField("Add personal goal", text: $customMilestone).textFieldStyle(.roundedBorder).onSubmit { vm.addCustomMilestone(customMilestone); customMilestone = "" }; Button("Add") { vm.addCustomMilestone(customMilestone); customMilestone = "" }.buttonStyle(.borderedProminent).disabled(customMilestone.trimmingCharacters(in: .whitespaces).isEmpty) }; if !vm.profile.milestones.filter({ !vm.milestones.contains($0) }).isEmpty { FlowLayout(spacing: 6) { ForEach(vm.profile.milestones.filter { !vm.milestones.contains($0) }, id: \.self) { item in Button { vm.profile.milestones.removeAll { $0 == item }; vm.saveDraft() } label: { Text("\(item) ×").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border)) }.buttonStyle(.plain) } } } }, nextTitle: "Continue to College Plans", next: vm.next) } }

struct Step5View: View { @ObservedObject var vm: OnboardingViewModel; @State private var search = ""; @State private var customField = ""; var body: some View { StepScaffold(step: 5, title: "Are you planning to go to college?", subtitle: "Your answers help Student OPS personalize opportunities without rigid pressure.", eyebrow: "ACADEMIC CALIBRATION", back: vm.back, content: { FlowLayout { ForEach(CollegePlan.allCases, id: \.rawValue) { plan in SelectableChip(title: plan.rawValue, selected: vm.profile.collegePlan == plan) { vm.profile.collegePlan = plan; vm.saveDraft() } } }; if vm.profile.collegePlan == .yesDefinitely || vm.profile.collegePlan == .probably { Text("WHAT ARE YOU INTERESTED IN STUDYING?").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary); FlowLayout(spacing: 6) { ForEach(vm.fields, id: \.self) { item in SelectableChip(title: item, selected: vm.profile.fields.contains(item)) { vm.toggle(item, in: &vm.profile.fields); vm.saveDraft() } } }; HStack { TextField("Add study area", text: $customField).textFieldStyle(.roundedBorder).onSubmit { vm.addCustomField(customField); customField = "" }; Button("Add") { vm.addCustomField(customField); customField = "" }.buttonStyle(.borderedProminent).disabled(customField.trimmingCharacters(in: .whitespaces).isEmpty) }; if !vm.profile.fields.filter({ !vm.fields.contains($0) }).isEmpty { FlowLayout(spacing: 6) { ForEach(vm.profile.fields.filter { !vm.fields.contains($0) }, id: \.self) { item in Button { vm.profile.fields.removeAll { $0 == item }; vm.saveDraft() } label: { Text("\(item) ×").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border)) }.buttonStyle(.plain) } } }; PickerCard(label: "WHERE ARE YOU THINKING ABOUT GOING?", values: vm.geographies, selection: Binding(get: { vm.profile.geography }, set: { vm.profile.geography = $0; vm.saveDraft() })); PickerCard(label: "WHAT TYPE OF COLLEGE ARE YOU CONSIDERING?", values: vm.collegeTypes, selection: Binding(get: { vm.profile.collegeType }, set: { vm.profile.collegeType = $0; vm.saveDraft() })); VStack(alignment: .leading, spacing: 8) { Text("SPECIFIC COLLEGES IN MIND? (OPTIONAL)").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary); HStack { TextField("Search e.g. UT Austin, MIT, Stanford...", text: $search).textFieldStyle(.roundedBorder).onSubmit { vm.addCollege(search); search = "" }; Button("Add") { vm.addCollege(search); search = "" }.buttonStyle(.borderedProminent).disabled(search.trimmingCharacters(in: .whitespaces).isEmpty) }; HStack { Button("+ UT Austin") { vm.addCollege("UT Austin") }.buttonStyle(.bordered); Button("+ Texas A&M") { vm.addCollege("Texas A&M") }.buttonStyle(.bordered) }; FlowLayout(spacing: 6) { ForEach(vm.profile.targetColleges, id: \.self) { item in Button { vm.profile.targetColleges.removeAll { $0 == item }; vm.saveDraft() } label: { Text("\(item) ×").font(AppFont.inter(11, weight: .semibold)).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border)) }.buttonStyle(.plain) } } }.padding(14).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) } else { Text("You can update college preferences anytime in your profile.").font(AppFont.inter(12)).foregroundColor(StudentOPSTheme.textSecondary).padding(12).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) } }, nextTitle: "Continue to Experience", next: vm.next) } }

struct Step6View: View {
    @ObservedObject var vm: OnboardingViewModel
    @EnvironmentObject var store: AppDataStore
    @State private var newTitle = ""
    @State private var newCategory = "Projects"
    @State private var quickProjectTitle = ""
    @State private var quickProjectType = "Project"
    @State private var showProjectEditor = false
    @State private var editingOnboardingProject: Project?

    var body: some View {
        StepScaffold(step: 6, title: "What have you already accomplished?", subtitle: "Add any past or ongoing activities and projects. It's totally okay if you're just getting started.", eyebrow: "TRACK RECORD", back: vm.back, content: {
            Button { vm.profile.justGettingStarted.toggle(); if vm.profile.justGettingStarted { vm.profile.categories = [:] }; vm.saveDraft() } label: { HStack { Text("🌱  I'm just getting started").font(AppFont.inter(12, weight: .bold)); Spacer(); Image(systemName: vm.profile.justGettingStarted ? "checkmark.circle.fill" : "circle").foregroundColor(StudentOPSTheme.primaryDark) }.foregroundColor(StudentOPSTheme.textPrimary).padding(14).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) }.buttonStyle(.plain)

            // MARK: Projects (Phase 9.3)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("YOUR PROJECTS").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary)
                    Spacer()
                    Button { editingOnboardingProject = nil; showProjectEditor = true } label: { Label("Add Project", systemImage: "plus.circle.fill").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.primaryDark) }.buttonStyle(.plain)
                }
                Text("Add a project you have actually done — Science Fair, Coding, Research, etc. Tap + to include details.").font(AppFont.inter(12)).foregroundColor(StudentOPSTheme.textSecondary)
                if vm.onboardingProjects.isEmpty {
                    Text("No projects yet. Add one or skip — you can add later in your profile.").font(AppFont.inter(12)).foregroundColor(StudentOPSTheme.textSecondary).padding(10).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: Radius.md)).overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(StudentOPSTheme.border))
                } else {
                    ForEach(vm.onboardingProjects) { proj in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(proj.title).font(AppFont.inter(12, weight: .semibold)).foregroundColor(StudentOPSTheme.textPrimary)
                                HStack(spacing: 6) {
                                    Text(proj.category).font(AppFont.inter(10, weight: .bold)).foregroundColor(StudentOPSTheme.primaryDark)
                                    Text("•").foregroundColor(StudentOPSTheme.textSecondary)
                                    Text(proj.status.displayName).font(AppFont.inter(10, weight: .medium)).foregroundColor(StudentOPSTheme.textSecondary)
                                    if !proj.skills.isEmpty { Text("• \(proj.skills.prefix(2).joined(separator: ", "))").font(AppFont.inter(10)).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1) }
                                }
                                if let out = proj.outcome, !out.isEmpty { Text(out).font(AppFont.inter(11)).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1) }
                            }
                            Spacer()
                            Button { editingOnboardingProject = proj; showProjectEditor = true } label: { Image(systemName: "pencil.circle").foregroundColor(StudentOPSTheme.primaryDark) }.buttonStyle(.plain)
                            Button { vm.removeOnboardingProject(id: proj.id) } label: { Image(systemName: "trash").foregroundColor(.red.opacity(0.8)) }.buttonStyle(.plain)
                        }.padding(10).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: Radius.md)).overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(StudentOPSTheme.border))
                    }
                }
                // Quick simple add row (minimal)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick add").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary)
                    HStack {
                        TextField("Project name", text: $quickProjectTitle).textFieldStyle(.roundedBorder)
                        Picker("Type", selection: $quickProjectType) { ForEach(Project.typeOptions.prefix(5), id: \.self) { Text($0).tag($0) } }.labelsHidden().pickerStyle(.menu)
                        Button("Add") { quickAdd() }.buttonStyle(.borderedProminent).disabled(quickProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("Use Add Project for  more details (description, skills, etc).").font(AppFont.inter(10)).foregroundColor(StudentOPSTheme.textSecondary)
                }
            }.padding(14).background(StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(StudentOPSTheme.border)).clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .sheet(isPresented: $showProjectEditor) {
                    Group {
                        if let editing = editingOnboardingProject {
                            ProjectEditorView(editingProject: editing, onSave: { updated in vm.updateOnboardingProject(updated) })
                                .environmentObject(store)
                        } else {
                            ProjectEditorView(onSave: { newProj in vm.addOnboardingProject(newProj) })
                                .environmentObject(store)
                        }
                    }
                }

            VStack(alignment: .leading, spacing: 8) { Text("ADD AN ACHIEVEMENT").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary); HStack { TextField("e.g. Science Fair Winner", text: $newTitle).textFieldStyle(.roundedBorder).onSubmit { addEntry() }; Picker("Category", selection: $newCategory) { ForEach(vm.categories, id: \.self) { Text($0).tag($0) } }.labelsHidden().pickerStyle(.menu); Button("Add") { addEntry() }.buttonStyle(.borderedProminent).disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty) } }.padding(14).background(StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(StudentOPSTheme.border)).clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            Text("SELECT CATEGORIES TO ADD").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary); FlowLayout { ForEach(vm.categories, id: \.self) { item in SelectableChip(title: item, selected: vm.profile.categories[item] != nil) { if vm.profile.categories[item] != nil { vm.profile.categories.removeValue(forKey: item) } else { vm.profile.categories[item] = 0 }; vm.saveDraft() } } }.opacity(vm.profile.justGettingStarted ? 0.5 : 1).disabled(vm.profile.justGettingStarted)
            if !vm.profile.loggedEntries.isEmpty { VStack(alignment: .leading, spacing: 8) { Text("LOGGED ENTRIES READY FOR VERIFICATION").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary); ForEach(vm.profile.loggedEntries) { entry in HStack { Text(entry.title).font(AppFont.inter(12, weight: .medium)); Spacer(); Text(entry.category).font(AppFont.inter(10, weight: .bold)).foregroundColor(StudentOPSTheme.primaryDark); Button { vm.removeExperienceEntry(entry) } label: { Image(systemName: "xmark.circle").foregroundColor(StudentOPSTheme.textSecondary) }.buttonStyle(.plain) }.padding(10).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(StudentOPSTheme.border)) } }.padding(14).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) } else { Text("No entries yet — add one above or continue if you're just getting started. You can skip this step.").font(AppFont.inter(12)).foregroundColor(StudentOPSTheme.textSecondary).padding(12).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) }
        }, nextTitle: vm.profile.justGettingStarted && vm.onboardingProjects.isEmpty ? "Continue — Just Getting Started" : "Complete & Review Profile", next: vm.next)
    }
    private func addEntry() { vm.addExperienceEntry(title: newTitle, category: newCategory); newTitle = "" }
    private func quickAdd() {
        let t = quickProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let cat = quickProjectType
        let proj = Project(id: "custom-\(UUID().uuidString)", title: t, category: cat, goal: "Complete this project", description: "A project added during onboarding.", skills: [], milestones: [ProjectMilestone(id: "custom-\(UUID().uuidString)-milestone", title: "Complete the project", subtitle: "Complete this project", estimatedTime: "Your timeline")], resources: [], estimatedCompletion: "Your timeline", relevantInterests: [], relevantSkills: [], relevantCareers: [], relevantFields: [], sourceRoadmapID: nil, status: .inProgress)
        vm.addOnboardingProject(proj)
        quickProjectTitle = ""
    }
}

// MARK: - Completion and main experience

struct Step7SummaryView: View { @ObservedObject var viewModel: OnboardingViewModel; let finish: () -> Void; var body: some View { VStack(spacing: 0) { VStack(alignment: .leading, spacing: 8) { Text("✓  ONBOARDING COMPLETE").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.primaryDark); Text("Your Student OPS profile is ready.").font(AppFont.inter(24, weight: .heavy)).foregroundColor(StudentOPSTheme.textPrimary); Text("Your answers personalize your roadmaps, opportunities, projects, and college preparation.").font(AppFont.inter(12)).foregroundColor(StudentOPSTheme.textSecondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(20); ScrollView { VStack(alignment: .leading, spacing: 12) { SummaryCard(title: "INTERESTS", values: viewModel.profile.interests); SummaryCard(title: "STRENGTHS & SKILLS", values: viewModel.profile.strengths + viewModel.profile.customSkills); SummaryCard(title: "GOALS & TRAJECTORY", values: viewModel.profile.careers + viewModel.profile.milestones); SummaryCard(title: "COLLEGE DIRECTION", values: [viewModel.profile.collegePlan.rawValue, viewModel.profile.geography, viewModel.profile.collegeType] + viewModel.profile.targetColleges) }.padding(20) }; PrimaryButton(title: "Build my path", action: finish).padding(20) }.background(StudentOPSTheme.surface) } }
struct SummaryCard: View { let title: String; let values: [String]; var body: some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textSecondary); FlowLayout(spacing: 6) { ForEach(values.filter { !$0.isEmpty }, id: \.self) { Text($0).font(AppFont.inter(12, weight: .semibold)).foregroundColor(StudentOPSTheme.textPrimary).padding(7).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 6).stroke(StudentOPSTheme.border)) } } }.padding(14).background(StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(StudentOPSTheme.border)).clipShape(RoundedRectangle(cornerRadius: Radius.lg)) } }
