import SwiftUI

// MARK: - AI Writing Sheet (uncommitted draft, explicit approval)

struct PortfolioAIWritingView: View {
    let portfolioID: String
    let writingType: PortfolioWritingType
    let targetID: String?
    let currentText: String?
    var onAccept: (String, String) -> Void // (draft, fingerprint)

    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = PortfolioWritingService.shared

    @State private var tone: PortfolioWritingTone = .professional
    @State private var length: PortfolioWritingLength = .medium
    @State private var isGenerating = false
    @State private var draft: String? = nil
    @State private var draftFingerprint: String? = nil
    @State private var sourceIDs: [String] = []
    @State private var factualClaims: [String] = []
    @State private var warnings: [String] = []
    @State private var needsMoreContext = false
    @State private var errorMessage: String? = nil
    @State private var editedDraft: String = ""
    @State private var isEditingManually = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    currentTextSection
                    controlsSection
                    if isGenerating {
                        generatingSection
                    } else if let draft = draft {
                        draftSection(draft: draft)
                        provenanceSection
                        if !warnings.isEmpty {
                            warningsSection
                        }
                        actionSection
                    } else if let error = errorMessage {
                        errorSection(error: error)
                    }
                    disclosureSection
                }.padding(16)
            }
            .background(StudentOPSTheme.background.ignoresSafeArea())
            .navigationTitle(writingType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI writing assistant", systemImage: "sparkles").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
            Text("Generate polished wording from your verified portfolio facts. AI drafts are not saved until you tap Use this.")
                .font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            Label("AI-generated draft — review before using.", systemImage: "info.circle").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
        }.padding(12).background(StudentOPSTheme.primary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.primary.opacity(0.2)))
    }

    private var currentTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
            if let current = currentText, !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(current).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).padding(10).frame(maxWidth:.infinity, alignment:.leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
            } else {
                Text("No current text. AI will generate from your portfolio facts.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(maxWidth:.infinity, alignment:.leading).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tone").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    Picker("Tone", selection: $tone) {
                        ForEach(PortfolioWritingTone.allCases, id: \.self) { t in Text(t.displayName).tag(t) }
                    }.pickerStyle(.menu).labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Length").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    Picker("Length", selection: $length) {
                        ForEach(PortfolioWritingLength.allCases, id: \.self) { l in Text(l.displayName).tag(l) }
                    }.pickerStyle(.menu).labelsHidden()
                }
                Spacer()
            }
            Button(action: generate) {
                Label(isGenerating ? "Generating..." : "Generate", systemImage: "sparkles")
                    .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textOnPrimary)
                    .frame(maxWidth:.infinity).padding(.vertical, 12)
                    .background(isGenerating ? StudentOPSTheme.textSecondary : StudentOPSTheme.primaryDark)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }.disabled(isGenerating).buttonStyle(.plain)
            .accessibilityLabel(Text("Generate draft"))
        }
    }

    private var generatingSection: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2).tint(StudentOPSTheme.primaryDark)
            Text("Generating from verified facts...").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }.frame(maxWidth:.infinity).padding(20).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func draftSection(draft: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI DRAFT").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.primaryDark)
                Spacer()
                Text("\(draft.count) chars").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            if isEditingManually {
                TextEditor(text: $editedDraft).frame(minHeight: 100).padding(8).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
                HStack {
                    Button("Cancel edit") { isEditingManually = false; editedDraft = draft }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                    Spacer()
                    Button("Save edit") { isEditingManually = false }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }
            } else {
                Text(isEditingManually ? editedDraft : draft).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textPrimary).padding(12).frame(maxWidth:.infinity, alignment:.leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.primary.opacity(0.3)))
                Button("Edit manually") { editedDraft = draft; isEditingManually = true }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
            }
        }
    }

    private var provenanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Based on").font(DashFont.labelMono()).tracking(0.5).foregroundColor(StudentOPSTheme.textSecondary)
            if sourceIDs.isEmpty {
                Text("Generated from your saved portfolio data.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                Text(sourceIDs.prefix(5).joined(separator: " • ")).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                if factualClaims.isEmpty == false {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Factual claims used:").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        ForEach(factualClaims.prefix(3), id: \.self) { claim in
                            Label(claim, systemImage: "checkmark.circle.fill").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                        }
                    }
                }
            }
            if needsMoreContext {
                Label("More context would help improve this draft.", systemImage: "info.circle").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
            }
        }.padding(12).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Warnings").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
            ForEach(warnings, id: \.self) { w in
                Label(w, systemImage: "exclamationmark.triangle").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.warning)
            }
        }.padding(12).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorSection(error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Could not generate", systemImage: "exclamationmark.octagon").font(DashFont.titleMd()).foregroundColor(.red)
            Text(error).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            Button("Try again") { generate() }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).buttonStyle(.plain)
        }.padding(12).background(Color.red.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionSection: some View {
        VStack(spacing: 10) {
            Button(action: {
                let finalDraft = isEditingManually ? editedDraft : (draft ?? "")
                let fp = draftFingerprint ?? ""
                onAccept(finalDraft, fp)
                dismiss()
            }) {
                Label("Use this", systemImage: "checkmark.circle.fill").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textOnPrimary).frame(maxWidth:.infinity).padding(.vertical, 12).background(StudentOPSTheme.primaryDark).clipShape(RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityLabel(Text("Use this draft"))

            HStack(spacing: 12) {
                Button("Regenerate") { generate() }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).frame(maxWidth:.infinity).padding(.vertical, 10).background(StudentOPSTheme.primary.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10)).buttonStyle(.plain)
                Button("Cancel") { dismiss() }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth:.infinity).padding(.vertical, 10).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border)).buttonStyle(.plain)
            }
        }
    }

    private var disclosureSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How it works").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            Text("AI improves wording only. Your portfolio's selected projects, achievements, evidence, skills, and roadmaps remain the source of truth. Never invents facts — uses only verified context, and you review before saving.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        }.padding(12).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Generate

    private func generate() {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        draft = nil
        draftFingerprint = nil
        sourceIDs = []
        factualClaims = []
        warnings = []
        needsMoreContext = false

        Task {
            do {
                let result = try await service.generate(
                    portfolioID: portfolioID,
                    writingType: writingType,
                    targetID: targetID,
                    currentText: currentText,
                    tone: tone,
                    length: length,
                    store: store
                )
                await MainActor.run {
                    self.draft = result.draft
                    self.editedDraft = result.draft
                    self.draftFingerprint = result.contextFingerprint
                    self.sourceIDs = result.sourceIDs
                    self.factualClaims = result.factualClaims
                    self.warnings = result.warnings
                    self.needsMoreContext = result.needsMoreContext
                    self.isGenerating = false
                }
            } catch let err as PortfolioWritingError {
                await MainActor.run {
                    self.errorMessage = err.message
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
}
