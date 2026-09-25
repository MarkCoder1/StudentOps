import SwiftUI
import PhotosUI
import UIKit

/// Reusable project editor for onboarding and profile editing.
/// Handles rich project fields with progressive disclosure.
struct ProjectEditorView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss

    var editingProject: Project? = nil
    var onSave: ((Project) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    // MARK: - State

    @State private var title = ""
    @State private var category = "Personal Project"
    @State private var customCategory = ""
    @State private var status: ProjectStatus = .inProgress
    @State private var descriptionText = ""
    @State private var detailedDescription = ""
    @State private var skillsInput = ""
    @State private var selectedSkills: [String] = []
    @State private var outcome = ""
    @State private var outcomeDetails = ""
    @State private var startDate = Date()
    @State private var includeStartDate = false
    @State private var completionDate = Date()
    @State private var includeCompletionDate = false
    @State private var links: [ProjectLink] = []
    @State private var newLinkLabel = ""
    @State private var newLinkURL = ""
    @State private var imageReferences: [String] = []
    @State private var stagedImages: [UIImage] = []
    @State private var stagedImageItems: [PhotosPickerItem] = []
    @State private var achievementID: String? = nil
    @State private var showMoreDetails = false
    @State private var showValidationError: String?
    @State private var isSaving = false

    private var isEditing: Bool { editingProject != nil }

    // MARK: - Helpers

    private var effectiveCategory: String {
        if category == "Other" {
            let t = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "Other" : t
        }
        return category
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var urlInvalid: Bool {
        let t = newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard let url = URL(string: t) else { return true }
        guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return true }
        return url.host == nil
    }

    private func isValidURL(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard let url = URL(string: t) else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
        return url.host != nil
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    projectSection
                    aboutSection
                    disclosureToggle
                    if showMoreDetails {
                        skillsSection
                        outcomeSection
                        datesSection
                        linksSection
                        photosSection
                        achievementSection
                        evidenceInfoSection
                    }
                    if let err = showValidationError {
                        Text(err).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.error).padding(10).background(Color.red.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }.padding(16)
            }
            .background(StudentOPSTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Project" : "Add Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel?(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(trimmedTitle.isEmpty || isSaving)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { populate() }
            .onChange(of: stagedImageItems) { _, newItems in
                Task { await loadStagedImages(from: newItems) }
            }
        }
    }

    // MARK: - Sections

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PROJECT").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("Title *").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                TextField("e.g. AI Study Planner", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.words)
                Text("Project type").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                Picker("Type", selection: $category) {
                    ForEach(Project.typeOptions, id: \.self) { t in Text(t).tag(t) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(StudentOPSTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
                if category == "Other" {
                    TextField("Enter custom type", text: $customCategory)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Status").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                Picker("Status", selection: $status) {
                    ForEach(ProjectStatus.allCases, id: \.self) { s in Text(s.displayName).tag(s) }
                }
                .pickerStyle(.segmented)
            }
            .padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ABOUT").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            VStack(alignment: .leading, spacing: 10) {
                Text("What did you actually build/do?").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                TextField("Short description", text: $descriptionText, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                Text("Brief — what someone should understand in one sentence.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                // Longer details shown when disclosure expanded or when value exists
                if showMoreDetails || !detailedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TextField("Longer details/background (optional)", text: $detailedDescription, axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.roundedBorder)
                    Text("Optional background — keep concise.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
            }
            .padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
    }

    private var disclosureToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showMoreDetails.toggle() }
        } label: {
            HStack {
                Label(showMoreDetails ? "Show less" : "Add more details", systemImage: showMoreDetails ? "chevron.up" : "plus.circle.fill")
                    .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                Spacer()
                Text(showMoreDetails ? "Hide optional fields" : "Skills, dates, outcome, links, photos")
                    .font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            .padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
        }.buttonStyle(.plain)
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SKILLS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            VStack(alignment: .leading, spacing: 10) {
                Text("Which skills did you use or develop?").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                // Selected chips
                if !selectedSkills.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(selectedSkills, id: \.self) { skill in
                            Button {
                                selectedSkills.removeAll { $0 == skill }
                            } label: {
                                Text("\(skill) ×").font(AppFont.inter(11, weight: .bold)).foregroundColor(StudentOPSTheme.textPrimary).padding(.horizontal, 8).padding(.vertical, 6).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                // Quick picks from catalog
                Text("Quick add:").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                FlowLayout(spacing: 6) {
                    ForEach(Array(SkillCatalog.allSkills.prefix(16)), id: \.id) { skill in
                        let already = selectedSkills.contains { Skill.normalizeID($0) == skill.id }
                        Button {
                            if already {
                                selectedSkills.removeAll { Skill.normalizeID($0) == skill.id }
                            } else {
                                selectedSkills.append(skill.name)
                            }
                        } label: {
                            Text(skill.name).font(AppFont.inter(11, weight: already ? .bold : .medium)).foregroundColor(already ? StudentOPSTheme.primaryDark : StudentOPSTheme.textPrimary).padding(.horizontal, 8).padding(.vertical, 6).background(already ? StudentOPSTheme.primary.opacity(0.12) : StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: 10).stroke(already ? StudentOPSTheme.primaryDark : StudentOPSTheme.border, lineWidth: already ? 1.5 : 1))
                        }.buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("Add skill (e.g. Python, Research)", text: $skillsInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addSkill() }
                    Button("Add") { addSkill() }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary).disabled(skillsInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text("Skills use canonical IDs. Duplicates are removed automatically.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
    }

    private var outcomeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OUTCOME").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            VStack(alignment: .leading, spacing: 10) {
                Text("What did you accomplish?").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                TextField("e.g. Built a working prototype and presented at science fair", text: $outcome, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                TextField("Longer impact description (optional)", text: $outcomeDetails, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
    }

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DATES").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Set start date", isOn: $includeStartDate).tint(StudentOPSTheme.primary)
                if includeStartDate {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                Toggle("Set completion date", isOn: $includeCompletionDate).tint(StudentOPSTheme.primary)
                if includeCompletionDate {
                    DatePicker("Completed", selection: $completionDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                if includeStartDate && includeCompletionDate && completionDate < startDate {
                    Text("Completion date cannot be before start date.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.error)
                }
                Text("Dates are optional. Leave blank if not relevant.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LINKS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            VStack(alignment: .leading, spacing: 10) {
                if !links.isEmpty {
                    ForEach(links) { link in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(link.label).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                                Text(link.url).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark).lineLimit(1)
                            }
                            Spacer()
                            Button { links.removeAll { $0.id == link.id } } label: { Image(systemName: "trash").foregroundColor(StudentOPSTheme.error) }.buttonStyle(.plain)
                        }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    Text("No links yet. Add GitHub, demo, paper, etc.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                TextField("Label (e.g. GitHub Repository)", text: $newLinkLabel).textFieldStyle(.roundedBorder)
                TextField("URL https://...", text: $newLinkURL).textFieldStyle(.roundedBorder).keyboardType(.URL).autocapitalization(.none)
                if urlInvalid {
                    Text("Invalid URL — must start with http:// or https://").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.error)
                }
                Button {
                    addLink()
                } label: {
                    Label("Add Link", systemImage: "link").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(StudentOPSTheme.primary)
                .disabled(newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newLinkLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || urlInvalid)
                Text("Links are validated but not opened automatically.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PHOTOS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            VStack(alignment: .leading, spacing: 10) {
                if imageReferences.isEmpty && stagedImages.isEmpty {
                    Text("No photos yet. Add a screenshot, prototype, or presentation photo.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // Existing references thumbnails
                            ForEach(imageReferences, id: \.self) { ref in
                                ExistingImageThumb(ref: ref, projectID: editingProject?.id ?? "temp", onDelete: {
                                    imageReferences.removeAll { $0 == ref }
                                    if let pid = editingProject?.id {
                                        _ = ProjectImageStore.deleteImage(identifier: ref, projectID: pid)
                                    }
                                })
                            }
                            // Staged images
                            ForEach(Array(stagedImages.enumerated()), id: \.offset) { idx, img in
                                Image(uiImage: img).resizable().scaledToFill().frame(width: 80, height: 80).clipped().clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border)).overlay(alignment: .topTrailing) {
                                    Button { stagedImages.remove(at: idx) } label: { Image(systemName: "xmark.circle.fill").foregroundColor(StudentOPSTheme.error).background(Color.white.clipShape(Circle())) }.padding(2)
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                }
                PhotosPicker(selection: $stagedImageItems, maxSelectionCount: 5, matching: .images) {
                    Label("Add Photos", systemImage: "photo.on.rectangle.angled").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(StudentOPSTheme.primary)
                Text("Photos are stored locally as files, not in UserDefaults. They stay on your device.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
    }

    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACHIEVEMENT").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            VStack(alignment: .leading, spacing: 8) {
                Picker("Related achievement", selection: $achievementID) {
                    Text("None").tag(String?.none)
                    ForEach(store.achievementRecords.values.sorted { $0.createdAt > $1.createdAt }) { ach in
                        Text(ach.title).tag(Optional(ach.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(StudentOPSTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
                Text("Optionally link this project to an achievement like “1st Place — Science Fair”.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
    }

    private var evidenceInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EVIDENCE").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            VStack(alignment: .leading, spacing: 6) {
                let count = editingProject != nil ? store.evidenceRecords.values.filter { $0.projectID == editingProject!.id }.count : 0
                if count > 0 {
                    Text("\(count) evidence record\(count == 1 ? "" : "s") linked to this project.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                } else {
                    Text("Evidence for this project will appear in Project Detail. Add evidence from the project detail page after saving.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Text("Evidence connections use existing EvidenceRecord architecture via projectID.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
    }

    // MARK: - Populate

    private func populate() {
        if let p = editingProject {
            title = p.title
            // Try to match category to options
            if Project.typeOptions.contains(p.category) {
                category = p.category
            } else {
                // If custom, use Other
                if p.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    category = "Personal Project"
                } else {
                    // If not in options, select Other and set custom
                    category = "Other"
                    customCategory = p.category
                }
            }
            status = p.status
            descriptionText = p.description
            detailedDescription = p.detailedDescription ?? ""
            selectedSkills = p.skills
            outcome = p.outcome ?? ""
            outcomeDetails = p.outcomeDetails ?? ""
            if let s = p.startDate { startDate = s; includeStartDate = true }
            if let c = p.completionDate { completionDate = c; includeCompletionDate = true }
            links = p.links
            imageReferences = p.imageReferences
            achievementID = p.achievementID
            // If any rich fields populated, expand disclosure
            if !(p.detailedDescription?.isEmpty ?? true) || !p.skills.isEmpty || p.outcome != nil || !p.links.isEmpty || !p.imageReferences.isEmpty || p.startDate != nil || p.completionDate != nil || p.achievementID != nil {
                showMoreDetails = true
            }
        } else {
            // New project defaults
            title = ""
            category = "Personal Project"
            status = .inProgress
            descriptionText = ""
        }
    }

    // MARK: - Actions

    private func addSkill() {
        let raw = skillsInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        // Support comma separated
        let parts = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for part in (parts.isEmpty ? [raw] : parts) {
            let norm = Skill.normalizeID(part)
            guard !norm.isEmpty else { continue }
            guard !selectedSkills.contains(where: { Skill.normalizeID($0) == norm }) else { continue }
            let display = SkillCatalog.knownSkills[norm]?.name ?? part
            selectedSkills.append(display)
        }
        skillsInput = ""
    }

    private func addLink() {
        let label = newLinkLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, isValidURL(url) else { return }
        links.append(ProjectLink(label: label, url: url))
        newLinkLabel = ""
        newLinkURL = ""
    }

    private func loadStagedImages(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                images.append(img)
            }
        }
        await MainActor.run {
            stagedImages.append(contentsOf: images)
            stagedImageItems.removeAll()
        }
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { showValidationError = "Project title is required."; return }
        if let s = startDate as Date?, let c = completionDate as Date?, includeStartDate && includeCompletionDate && c < s {
            showValidationError = "Completion date cannot be before start date."
            return
        }
        // Validate links
        for link in links where !link.isValidURL {
            showValidationError = "One or more links have invalid URLs. Use http:// or https://."
            return
        }
        isSaving = true
        showValidationError = nil

        // Determine projectID for image storage
        let targetID = editingProject?.id ?? "custom-\(UUID().uuidString)"
        var finalImageRefs = imageReferences

        // Save staged images to disk
        for img in stagedImages {
            if let ref = ProjectImageStore.saveImage(img, forProjectID: targetID) {
                finalImageRefs.append(ref)
            }
        }
        // If new project, we haven't saved yet, but we used temp ID above. We'll preserve refs.

        let effectiveCat = effectiveCategory
        let goalTrim = editingProject?.goal ?? "Complete this project"
        let descTrim = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDesc = descTrim.isEmpty ? "A project created by you." : descTrim

        if var editing = editingProject {
            // Update existing
            editing.title = trimmedTitle
            editing.category = effectiveCat
            editing.status = status
            editing.description = finalDesc
            let dd = detailedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.detailedDescription = dd.isEmpty ? nil : dd
            editing.skills = selectedSkills
            let oc = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.outcome = oc.isEmpty ? nil : oc
            let od = outcomeDetails.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.outcomeDetails = od.isEmpty ? nil : od
            editing.links = links
            editing.imageReferences = finalImageRefs
            editing.startDate = includeStartDate ? startDate : nil
            editing.completionDate = includeCompletionDate ? completionDate : nil
            editing.achievementID = achievementID

            // If caller provided onSave, delegate to it (onboarding case). Otherwise use store.
            if let handler = onSave {
                handler(editing)
                dismiss()
                return
            }
            let success = store.updateProject(editing)
            if success {
                dismiss()
            } else {
                showValidationError = "Unable to save project. Check title and fields."
                isSaving = false
            }
        } else {
            let newProject = Project(
                id: targetID,
                title: trimmedTitle,
                category: effectiveCat,
                goal: "Complete this project",
                description: finalDesc,
                skills: selectedSkills,
                milestones: [ProjectMilestone(id: "custom-\(UUID().uuidString)-milestone", title: "Complete the project", subtitle: goalTrim, estimatedTime: "Your timeline")],
                resources: [],
                estimatedCompletion: "Your timeline",
                relevantInterests: [],
                relevantSkills: [],
                relevantCareers: [],
                relevantFields: [],
                sourceRoadmapID: nil,
                status: status,
                detailedDescription: detailedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : detailedDescription,
                outcome: outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : outcome,
                outcomeDetails: outcomeDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : outcomeDetails,
                links: links,
                imageReferences: finalImageRefs,
                startDate: includeStartDate ? startDate : nil,
                completionDate: includeCompletionDate ? completionDate : nil,
                achievementID: achievementID
            )
            if let handler = onSave {
                handler(newProject)
                dismiss()
                return
            }
            let added = store.addCustomProject(newProject)
            if added {
                dismiss()
            } else {
                showValidationError = "Unable to add project. Title must be unique and non-empty."
                isSaving = false
            }
        }
    }
}

private struct ExistingImageThumb: View {
    let ref: String
    let projectID: String
    var onDelete: () -> Void
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let ui = image {
                    Image(uiImage: ui).resizable().scaledToFill().frame(width: 80, height: 80).clipped()
                } else {
                    Rectangle().fill(StudentOPSTheme.background).frame(width: 80, height: 80).overlay(Text("IMG").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill").foregroundColor(StudentOPSTheme.error).background(Color.white.clipShape(Circle()))
            }.padding(2)
        }
        .onAppear {
            // Load async? Simple sync for now
            image = ProjectImageStore.loadImage(identifier: ref, projectID: projectID)
        }
    }
}
