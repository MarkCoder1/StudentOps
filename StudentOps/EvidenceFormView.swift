import SwiftUI

struct EvidenceFormView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss

    // Editing mode: if non-nil, we are editing that record
    var editingRecord: EvidenceRecord?

    // Contextual prepopulation
    var initialProjectID: String? = nil
    var initialRoadmapID: String? = nil
    var initialMilestoneID: String? = nil
    var initialOpportunityID: String? = nil
    var initialSkillIDs: [String]? = nil

    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var selectedType: EvidenceType = .other
    @State private var occurredDate: Date = Date()
    @State private var includeOccurredDate: Bool = false

    @State private var artifactTitle: String = ""
    @State private var artifactURL: String = ""
    @State private var artifactType: String = "link"
    @State private var includeArtifact: Bool = false

    @State private var skillsText: String = ""

    @State private var selectedProjectID: String? = nil
    @State private var selectedRoadmapID: String? = nil
    @State private var selectedMilestoneID: String? = nil
    @State private var opportunityIDText: String = ""

    @State private var showError: String?

    private var isEditing: Bool { editingRecord != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title *", text: $title)
                    TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Type", selection: $selectedType) {
                        ForEach(EvidenceType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    Toggle("Set occurred date", isOn: $includeOccurredDate)
                    if includeOccurredDate {
                        DatePicker("Occurred on", selection: $occurredDate, displayedComponents: .date)
                    }
                }
                Section(header: Text("Artifact / Link (optional)")) {
                    Toggle("Include link", isOn: $includeArtifact)
                    if includeArtifact {
                        TextField("Link title", text: $artifactTitle)
                        TextField("URL (https://...)", text: $artifactURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                        if !artifactURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isValidURL(artifactURL) {
                            Text("Invalid URL — must start with http:// or https://").font(DashFont.bodySm()).foregroundColor(.red)
                        }
                        Picker("Link type", selection: $artifactType) {
                            Text("Link").tag("link")
                            Text("GitHub").tag("github")
                            Text("Document").tag("document")
                            Text("Presentation").tag("presentation")
                            Text("Website").tag("website")
                            Text("Other").tag("other")
                        }
                    }
                }
                Section(header: Text("Skills (optional)")) {
                    TextField("Comma-separated (e.g., Python, Git)", text: $skillsText)
                    if !skillsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let preview = skillsText.split(separator: ",").map{ Skill.normalizeID(String($0)) }.filter{!$0.isEmpty}
                        Text("Will store: \(preview.joined(separator: ", "))")
                            .font(DashFont.bodySm())
                            .foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }
                Section(header: Text("Relationships (optional)")) {
                    Picker("Project", selection: $selectedProjectID) {
                        Text("None").tag(String?.none)
                        ForEach(store.scoredProjects, id: \.project.id) { sp in
                            Text(sp.project.title).tag(Optional(sp.project.id))
                        }
                    }
                    Picker("Roadmap", selection: $selectedRoadmapID) {
                        Text("None").tag(String?.none)
                        ForEach(RoadmapService.allRoadmaps, id: \.id) { rm in
                            Text(rm.title).tag(Optional(rm.id))
                        }
                    }
                    if let rid = selectedRoadmapID, let roadmap = RoadmapService.roadmap(for: rid) {
                        Picker("Milestone", selection: $selectedMilestoneID) {
                            Text("None").tag(String?.none)
                            ForEach(roadmap.milestones, id: \.id) { ms in
                                Text(ms.title).tag(Optional(ms.id))
                            }
                        }
                    }
                    TextField("Opportunity ID (only if you actually participated)", text: $opportunityIDText)
                        .autocapitalization(.none)
                    Text("Only set opportunityID for real participation, not saved/viewed.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                if let err = showError {
                    Section { Text(err).foregroundColor(.red).font(DashFont.bodySm()) }
                }
            }
            .navigationTitle(isEditing ? "Edit Evidence" : "Add Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { populate() }
        }
    }

    private func populate() {
        if let rec = editingRecord {
            title = rec.title
            descriptionText = rec.description ?? ""
            selectedType = rec.type
            if let occ = rec.occurredAt {
                occurredDate = occ
                includeOccurredDate = true
            }
            if let art = rec.artifact {
                includeArtifact = true
                artifactTitle = art.title
                artifactURL = art.url ?? ""
                artifactType = art.type
            }
            skillsText = rec.skillIDs?.joined(separator: ", ") ?? ""
            selectedProjectID = rec.projectID
            selectedRoadmapID = rec.roadmapID.isEmpty ? nil : rec.roadmapID
            selectedMilestoneID = rec.milestoneID.isEmpty ? nil : rec.milestoneID
            opportunityIDText = rec.opportunityID ?? ""
        } else {
            selectedProjectID = initialProjectID
            selectedRoadmapID = initialRoadmapID
            selectedMilestoneID = initialMilestoneID
            opportunityIDText = initialOpportunityID ?? ""
            if let skills = initialSkillIDs, !skills.isEmpty {
                skillsText = skills.joined(separator: ", ")
            }
            // Default type based on context
            if initialProjectID != nil { selectedType = .projectWork }
            else if initialOpportunityID != nil { selectedType = .opportunityParticipation }
            else if initialRoadmapID != nil { selectedType = .milestoneCompletion }
        }
    }

    private func isValidURL(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard let url = URL(string: t) else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme) else { return false }
        return url.host != nil
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { showError = "Title is required."; return }

        var artifact: EvidenceArtifact? = nil
        if includeArtifact {
            let urlTrim = artifactURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !urlTrim.isEmpty {
                guard isValidURL(urlTrim) else { showError = "Invalid URL. Use http:// or https:// with a valid host."; return }
                let atTitle = artifactTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Link" : artifactTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                artifact = EvidenceArtifact(type: artifactType, title: atTitle, url: urlTrim, description: nil)
            } else if !artifactTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Title without URL — treat as no artifact (blank URL becomes nil per integrity)
                artifact = nil
            }
        }

        let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc: String? = trimmedDesc.isEmpty ? nil : trimmedDesc

        let skillIDs: [String]? = {
            let raw = skillsText.split(separator: ",").map{ String($0) }
            let norm = raw.map{ Skill.normalizeID($0) }.filter{ !$0.isEmpty }
            if norm.isEmpty { return nil }
            return Array(Set(norm)).sorted()
        }()

        let oppID: String? = {
            let t = opportunityIDText.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }()

        let roadmapID = selectedRoadmapID ?? ""
        let milestoneID = selectedMilestoneID ?? ""

        if let editing = editingRecord {
            // Update existing
            let updated = EvidenceRecord(
                id: editing.id,
                type: selectedType,
                title: trimmedTitle,
                description: desc,
                roadmapID: roadmapID,
                milestoneID: milestoneID,
                completionDate: editing.completionDate,
                createdAt: editing.createdAt,
                occurredAt: includeOccurredDate ? occurredDate : nil,
                source: editing.source, // preserve original source
                status: .recorded,
                actionID: editing.actionID,
                skillIDs: skillIDs,
                artifact: artifact,
                validationID: editing.validationID,
                validationScore: editing.validationScore,
                validationPercentage: editing.validationPercentage,
                validationPassed: editing.validationPassed,
                projectID: selectedProjectID,
                opportunityID: oppID
            )
            if store.updateEvidence(updated) {
                dismiss()
            } else {
                showError = "Unable to save. Check validation or duplicate."
            }
        } else {
            let now = Date()
            let new = EvidenceRecord(
                id: UUID().uuidString,
                type: selectedType,
                title: trimmedTitle,
                description: desc,
                roadmapID: roadmapID,
                milestoneID: milestoneID,
                completionDate: now,
                createdAt: now,
                occurredAt: includeOccurredDate ? occurredDate : nil,
                source: .studentEntered,
                status: .recorded,
                skillIDs: skillIDs,
                artifact: artifact,
                projectID: selectedProjectID,
                opportunityID: oppID
            )
            if store.addEvidence(new) {
                dismiss()
            } else {
                showError = "Unable to save. Title required and must be unique."
            }
        }
    }
}


