import SwiftUI

// MARK: - Portfolio Entry (inside ProgressProfileView)

struct PortfolioEntrySection: View {
  @EnvironmentObject var store: AppDataStore
  @State private var showingCreate = false
  @State private var newTitle = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("PORTFOLIO").font(DashFont.labelMono()).tracking(0.8).foregroundColor(
            StudentOPSTheme.textSecondary)
          Text("Build your presentation from real work").font(DashFont.bodySm()).foregroundColor(
            StudentOPSTheme.textSecondary)
        }
        Spacer()
        Button {
          showingCreate = true
        } label: {
          Label("New", systemImage: "plus").font(DashFont.labelMd()).foregroundColor(
            StudentOPSTheme.primaryDark)
        }.buttonStyle(.plain)
      }

      if store.allPortfoliosSorted.isEmpty {
        Text("No portfolio yet. Create one to start selecting your best work.").font(
          DashFont.bodySm()
        ).foregroundColor(StudentOPSTheme.textSecondary).padding(12).frame(
          maxWidth: .infinity, alignment: .leading
        ).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
      } else {
        ForEach(store.allPortfoliosSorted) { portfolio in
          VStack(alignment: .leading, spacing: 10) {
            NavigationLink(
              destination: PortfolioBuilderView(portfolioID: portfolio.id).environmentObject(store)
            ) {
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(portfolio.title).font(DashFont.titleMd()).foregroundColor(
                    StudentOPSTheme.textPrimary
                  ).lineLimit(1)
                  Spacer()
                  Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundColor(StudentOPSTheme.textSecondary)
                }
                if let headline = portfolio.headline, !headline.isEmpty {
                  Text(headline).font(DashFont.bodySm()).foregroundColor(
                    StudentOPSTheme.textSecondary
                  ).lineLimit(2)
                }
                HStack(spacing: 8) {
                  Label("\(portfolio.selectedProjectIDs.count) Projects", systemImage: "hammer")
                    .font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                  Text("·").foregroundColor(StudentOPSTheme.textSecondary)
                  Label(
                    "\(portfolio.selectedAchievementIDs.count) Achievements", systemImage: "star"
                  ).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                HStack(spacing: 8) {
                  Label("\(portfolio.selectedSkillIDs.count) Skills", systemImage: "checkmark.seal")
                    .font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                  Text("·").foregroundColor(StudentOPSTheme.textSecondary)
                  Label("\(portfolio.selectedEvidenceIDs.count) Evidence", systemImage: "doc").font(
                    DashFont.labelMono()
                  ).foregroundColor(StudentOPSTheme.textSecondary)
                  Text("·").foregroundColor(StudentOPSTheme.textSecondary)
                  Label(
                    "\(portfolio.selectedRoadmapIDs.count) Roadmaps",
                    systemImage: "point.3.connected.trianglepath.dotted"
                  ).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Text(
                  "\(portfolio.selectedProjectIDs.count) projects · \(portfolio.selectedAchievementIDs.count) achievements · \(portfolio.selectedSkillIDs.count) skills · \(portfolio.selectedEvidenceIDs.count) evidence · \(portfolio.selectedRoadmapIDs.count) roadmaps"
                )
                .font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                .lineLimit(2)
              }.padding(14).background(StudentOPSTheme.surface).clipShape(
                RoundedRectangle(cornerRadius: 12)
              ).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border))
            }.buttonStyle(.plain)
            HStack(spacing: 12) {
              NavigationLink(
                destination: PortfolioPresentationView(portfolioID: portfolio.id).environmentObject(
                  store)
              ) {
                Label("View Portfolio", systemImage: "eye")
                  .font(DashFont.labelMd())
                  .foregroundColor(.white)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(StudentOPSTheme.textPrimary)
                  .clipShape(Capsule())
              }.buttonStyle(.plain)
              Spacer()
              Text("Tap card to Build").font(DashFont.labelMono()).foregroundColor(
                StudentOPSTheme.textSecondary)
            }
          }
        }
      }
    }
    .sheet(isPresented: $showingCreate) {
      NavigationStack {
        Form {
          Section("Portfolio title") {
            TextField("e.g. My Portfolio", text: $newTitle)
          }
        }
        .navigationTitle("New Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              showingCreate = false
              newTitle = ""
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Create") {
              let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
              guard !title.isEmpty else { return }
              _ = store.createPortfolio(title: title)
              showingCreate = false
              newTitle = ""
            }.disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
    }
  }
}

// MARK: - Portfolio Builder

struct PortfolioBuilderView: View {
  let portfolioID: String
  @EnvironmentObject var store: AppDataStore
  @Environment(\.dismiss) private var dismiss
  @State private var showingMetadataEdit = false
  @State private var showingPreview = false
  @State private var showingSectionsEdit = false
  @State private var selectedProject: ScoredProject?
  @State private var selectedRoadmap: ScoredRoadmap?
  @State private var selectedAchievement: Achievement?
  @State private var selectedEvidence: EvidenceRecord?
  @State private var showAllProjectsAdd = false
  @State private var showAllAchievementsAdd = false
  @State private var showAllEvidenceAdd = false
  @State private var showAllSkillsAdd = false
  @State private var showAllRoadmapsAdd = false

  private var portfolio: StudentPortfolio? { store.portfolio(id: portfolioID) }
  private var asOf: Date { Date() }
  private var report: PortfolioCandidateReport { store.candidatesReport(asOf: asOf) }
  private var evidenceReport: PortfolioEvidenceReport? {
    guard let p = portfolio else { return nil }
    return PortfolioEvidenceEngine.report(for: p, store: store)
  }

  var body: some View {
    Group {
      if let portfolio = portfolio {
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 20) {
            headerSection(portfolio: portfolio)
            countsSection(portfolio: portfolio)
            qualitySection(portfolio: portfolio)
            integritySection(portfolio: portfolio)
            sectionsOrderSection(portfolio: portfolio)
            projectsBuilderSection(portfolio: portfolio)
            achievementsBuilderSection(portfolio: portfolio)
            skillsBuilderSection(portfolio: portfolio)
            evidenceBuilderSection(portfolio: portfolio)
            roadmapsBuilderSection(portfolio: portfolio)
            unresolvedSection(portfolio: portfolio)
            previewButton(portfolio: portfolio)
            deleteSection(portfolio: portfolio)
          }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
        }
        .background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("Portfolio Builder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button("Preview") { showingPreview = true }.font(DashFont.labelMd()).foregroundColor(
              StudentOPSTheme.primaryDark)
          }
        }
        .sheet(isPresented: $showingMetadataEdit) {
          if let p = store.portfolio(id: portfolioID) {
            PortfolioMetadataEditorView(portfolio: p).environmentObject(store)
          }
        }
        .sheet(isPresented: $showingSectionsEdit) {
          if let p = store.portfolio(id: portfolioID) {
            PortfolioSectionsEditorView(portfolio: p).environmentObject(store)
          }
        }
        .sheet(isPresented: $showingPreview) {
          if let p = store.portfolio(id: portfolioID) {
            NavigationStack {
              PortfolioPresentationView(portfolioID: p.id).environmentObject(store)
                .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showingPreview = false }
                  }
                }
            }
          }
        }
        .sheet(item: $selectedProject) { sp in
          NavigationStack { ProjectDetailView(scoredProject: sp).environmentObject(store) }
        }
        .sheet(item: $selectedRoadmap) { sr in
          NavigationStack { RoadmapDetailView(scoredRoadmap: sr).environmentObject(store) }
        }
        .sheet(item: $selectedAchievement) { ach in
          NavigationStack { AchievementDetailView(achievement: ach).environmentObject(store) }
        }
        .sheet(item: $selectedEvidence) { rec in
          EvidenceDetailSheet(record: rec).environmentObject(store)
        }
        .sheet(isPresented: $showAllProjectsAdd) { allProjectsSheet }
        .sheet(isPresented: $showAllAchievementsAdd) { allAchievementsSheet }
        .sheet(isPresented: $showAllEvidenceAdd) { allEvidenceSheet }
        .sheet(isPresented: $showAllSkillsAdd) { allSkillsSheet }
        .sheet(isPresented: $showAllRoadmapsAdd) { allRoadmapsSheet }
      } else {
        VStack(spacing: 12) {
          Text("Portfolio not found").font(DashFont.titleMd()).foregroundColor(
            StudentOPSTheme.textPrimary)
          Text("It may have been deleted.").font(DashFont.bodySm()).foregroundColor(
            StudentOPSTheme.textSecondary)
          Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(StudentOPSTheme.primary)
        }.padding(24)
      }
    }
  }

  // MARK: Header
  private func headerSection(portfolio: StudentPortfolio) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(portfolio.title).font(DashFont.headlineSm()).foregroundColor(
            StudentOPSTheme.textPrimary)
          if let h = portfolio.headline, !h.isEmpty {
            Text(h).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
              .lineLimit(2)
          }
          if let a = portfolio.about, !a.isEmpty {
            Text(a).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
              .lineLimit(3)
          }
          if !portfolio.goals.isEmpty {
            FlowLayout(spacing: 6) {
              ForEach(portfolio.goals, id: \.self) { g in
                Text(g).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                  .padding(.horizontal, 8).padding(.vertical, 4).background(
                    StudentOPSTheme.background
                  ).clipShape(Capsule())
              }
            }
          }
        }
        Spacer()
      }
      Button(action: { showingMetadataEdit = true }) {
        Label("Edit title, headline, about, goals", systemImage: "pencil").font(DashFont.labelMd())
          .foregroundColor(StudentOPSTheme.primaryDark)
      }.buttonStyle(.plain)
    }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border))
  }

  private func countsSection(portfolio: StudentPortfolio) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("STRUCTURAL COUNTS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(
        StudentOPSTheme.textSecondary)
      Text(
        "\(portfolio.selectedProjectIDs.count) projects · \(portfolio.selectedAchievementIDs.count) achievements · \(portfolio.selectedSkillIDs.count) skills · \(portfolio.selectedEvidenceIDs.count) evidence · \(portfolio.selectedRoadmapIDs.count) roadmaps"
      )
      .font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
      Text("Counts reflect structural selection, not a quality score.").font(DashFont.labelMono())
        .foregroundColor(StudentOPSTheme.textSecondary)
    }
  }

  private func qualitySection(portfolio: StudentPortfolio) -> some View {
    let result = PortfolioQualityEngine.evaluate(for: portfolio, store: store)
    return PortfolioQualitySummaryView(result: result)
  }

  private func integritySection(portfolio: StudentPortfolio) -> some View {
    let report = PortfolioGraphIntegrityEngine.report(for: portfolio, store: store)
    return PortfolioGraphIntegritySummaryView(report: report)
  }

  private func sectionsOrderSection(portfolio: StudentPortfolio) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("SECTIONS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(
          StudentOPSTheme.textSecondary)
        Spacer()
        Button("Edit sections") { showingSectionsEdit = true }.font(DashFont.labelMd())
          .foregroundColor(StudentOPSTheme.primaryDark)
      }
      VStack(spacing: 6) {
        ForEach(Array(portfolio.sections.enumerated()), id: \.element.id) { idx, sec in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(sec.title).font(DashFont.labelMd()).foregroundColor(
                sec.isEnabled ? StudentOPSTheme.textPrimary : StudentOPSTheme.textSecondary)
              Text(sec.type.rawValue).font(DashFont.labelMono()).foregroundColor(
                StudentOPSTheme.textSecondary)
            }
            Spacer()
            if !sec.isEnabled {
              Text("Hidden").font(DashFont.labelMono()).foregroundColor(
                StudentOPSTheme.textSecondary
              ).padding(.horizontal, 6).padding(.vertical, 3).background(StudentOPSTheme.background)
                .clipShape(Capsule())
            }
            Text("#\(idx+1)").font(DashFont.labelMono()).foregroundColor(
              StudentOPSTheme.textSecondary)
          }.padding(8).background(StudentOPSTheme.surface).clipShape(
            RoundedRectangle(cornerRadius: 8)
          ).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border.opacity(0.5)))
        }
      }
    }
  }

  // MARK: Projects Builder

  private func projectsBuilderSection(portfolio: StudentPortfolio) -> some View {
    let selected = portfolio.selectedProjectIDs
    let reportProjects = report.projects
    let selectedSet = Set(selected)
    let recommended = reportProjects.filter { !selectedSet.contains($0.sourceID) }.prefix(5)
    let unresolved = store.unresolvedIssues(for: portfolio).filter { $0.type == .project }

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("PROJECTS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(
          StudentOPSTheme.textSecondary)
        Spacer()
        Text("\(selected.count) selected").font(DashFont.labelMono()).foregroundColor(
          StudentOPSTheme.textSecondary)
      }

      // Selected
      VStack(alignment: .leading, spacing: 8) {
        Text("Selected").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
        if selected.isEmpty {
          Text("No projects selected. Add from recommended below.").font(DashFont.bodySm())
            .foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(
              maxWidth: .infinity, alignment: .leading
            ).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(selected.enumerated()), id: \.element) { idx, pid in
            if let scored = store.scoredProjects.first(where: { $0.project.id == pid }) {
              VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(scored.project.title).font(DashFont.labelMd()).foregroundColor(
                      StudentOPSTheme.textPrimary
                    ).lineLimit(1)
                    Text(scored.project.category).font(DashFont.labelMono()).foregroundColor(
                      StudentOPSTheme.textSecondary)
                    Text(
                      "\(scored.progress)% • \(scored.completedMilestones)/\(scored.project.milestones.count) milestones"
                    ).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                  }
                  Spacer()
                  Button {
                    _ = store.removeProject(from: portfolio.id, projectID: pid)
                  } label: {
                    Image(systemName: "minus.circle.fill").foregroundColor(StudentOPSTheme.warning)
                  }.buttonStyle(.plain)
                  VStack(spacing: 4) {
                    Button {
                      moveProject(portfolio: portfolio, from: idx, to: max(0, idx - 1))
                    } label: {
                      Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold))
                    }.disabled(idx == 0)
                    Button {
                      moveProject(
                        portfolio: portfolio, from: idx, to: min(selected.count - 1, idx + 1))
                    } label: {
                      Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }.disabled(idx == selected.count - 1)
                  }.foregroundColor(StudentOPSTheme.textSecondary)
                }
                .onTapGesture { selectedProject = scored }
                // Supporting evidence (derived, not auto-selected)
                let supporting = PortfolioEvidenceEngine.supportingEvidence(
                  forProjectID: pid, evidenceRecords: store.evidenceRecords)
                if !supporting.isEmpty {
                  VStack(alignment: .leading, spacing: 6) {
                    Label(
                      "Supporting evidence (\(supporting.count))", systemImage: "doc.badge.ellipsis"
                    ).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(supporting.prefix(2), id: \.id) { rec in
                      Button {
                        selectedEvidence = rec
                      } label: {
                        HStack(spacing: 6) {
                          Text(rec.title).font(DashFont.bodySm()).foregroundColor(
                            StudentOPSTheme.textPrimary
                          ).lineLimit(1)
                          let q = EvidenceQualityEngine.quality(for: rec)
                          Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(
                            qualityColor(q.overallLevel)
                          ).padding(.horizontal, 6).padding(.vertical, 2).background(
                            qualityColor(q.overallLevel).opacity(0.12)
                          ).clipShape(Capsule())
                          if rec.artifact != nil {
                            Image(systemName: "link").font(.system(size: 10)).foregroundColor(
                              StudentOPSTheme.textSecondary)
                          }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                      }.buttonStyle(.plain)
                    }
                    if supporting.count > 2 {
                      Text("+\(supporting.count - 2) more evidence").font(DashFont.labelMono())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                    }
                  }.padding(8).background(StudentOPSTheme.background).clipShape(
                    RoundedRectangle(cornerRadius: 8))
                } else {
                  Text("No evidence linked yet.").font(DashFont.labelMono()).foregroundColor(
                    StudentOPSTheme.textSecondary)
                }
              }.padding(10).background(StudentOPSTheme.surface).clipShape(
                RoundedRectangle(cornerRadius: 10)
              ).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
            } else {
              // Stale
              HStack {
                VStack(alignment: .leading, spacing: 3) {
                  Label("Missing project", systemImage: "exclamationmark.triangle").font(
                    DashFont.labelMd()
                  ).foregroundColor(StudentOPSTheme.warning)
                  Text(pid).font(DashFont.labelMono()).foregroundColor(
                    StudentOPSTheme.textSecondary
                  ).lineLimit(1)
                }
                Spacer()
                Button("Remove") { _ = store.removeProject(from: portfolio.id, projectID: pid) }
                  .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
              }.padding(10).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(
                RoundedRectangle(cornerRadius: 10)
              ).overlay(
                RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.warning.opacity(0.3)))
            }
          }
        }
      }

      // Recommended
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Recommended").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
          Spacer()
          if reportProjects.count > 5 {
            Button("See all") { showAllProjectsAdd = true }.font(DashFont.labelMd())
              .foregroundColor(StudentOPSTheme.primaryDark)
          }
        }
        if recommended.isEmpty {
          Text("No recommendations. Complete projects or add evidence to generate candidates.")
            .font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(10)
            .frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(recommended), id: \.id) { cand in
            CandidateRow(candidate: cand, isSelected: false) {
              _ = store.addProject(to: portfolio.id, projectID: cand.sourceID)
            } onDetail: {
              if let sp = store.scoredProjects.first(where: { $0.project.id == cand.sourceID }) {
                selectedProject = sp
              }
            }
          }
        }
      }

      if !unresolved.isEmpty {
        ForEach(unresolved, id: \.id) { issue in
          Text(issue.reason).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
        }
      }
    }
  }

  private func moveProject(portfolio: StudentPortfolio, from: Int, to: Int) {
    guard from != to, from >= 0, to >= 0, from < portfolio.selectedProjectIDs.count,
      to < portfolio.selectedProjectIDs.count
    else { return }
    var ids = portfolio.selectedProjectIDs
    let item = ids.remove(at: from)
    ids.insert(item, at: to)
    _ = store.reorderProjects(in: portfolio.id, orderedIDs: ids)
  }

  // MARK: Achievements Builder

  private func achievementsBuilderSection(portfolio: StudentPortfolio) -> some View {
    let selected = portfolio.selectedAchievementIDs
    let reportAchs = report.achievements
    let selectedSet = Set(selected)
    let recommended = reportAchs.filter { !selectedSet.contains($0.sourceID) }.prefix(5)
    let unresolved = store.unresolvedIssues(for: portfolio).filter { $0.type == .achievement }

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("ACHIEVEMENTS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(
          StudentOPSTheme.textSecondary)
        Spacer()
        Text("\(selected.count) selected").font(DashFont.labelMono()).foregroundColor(
          StudentOPSTheme.textSecondary)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Selected").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
        if selected.isEmpty {
          Text("No achievements selected. Add from recommended.").font(DashFont.bodySm())
            .foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(
              maxWidth: .infinity, alignment: .leading
            ).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(selected.enumerated()), id: \.element) { idx, aid in
            if let ach = store.achievementRecords[aid] {
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(ach.title).font(DashFont.labelMd()).foregroundColor(
                      StudentOPSTheme.textPrimary
                    ).lineLimit(1)
                    Text(ach.type.displayName).font(DashFont.labelMono()).foregroundColor(
                      StudentOPSTheme.textSecondary)
                    Text("\(ach.evidenceIDs.count) evidence • \(ach.skillIDs?.count ?? 0) skills")
                      .font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                  }
                  Spacer()
                  Button {
                    _ = store.removeAchievement(from: portfolio.id, achievementID: aid)
                  } label: {
                    Image(systemName: "minus.circle.fill").foregroundColor(StudentOPSTheme.warning)
                  }.buttonStyle(.plain)
                  VStack(spacing: 4) {
                    Button {
                      moveAchievement(portfolio: portfolio, from: idx, to: max(0, idx - 1))
                    } label: {
                      Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold))
                    }.disabled(idx == 0)
                    Button {
                      moveAchievement(
                        portfolio: portfolio, from: idx, to: min(selected.count - 1, idx + 1))
                    } label: {
                      Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }.disabled(idx == selected.count - 1)
                  }.foregroundColor(StudentOPSTheme.textSecondary)
                }
                .onTapGesture { selectedAchievement = ach }
                // Supporting evidence (proof)
                let supporting = PortfolioEvidenceEngine.supportingEvidence(
                  forAchievementID: aid, achievementRecords: store.achievementRecords,
                  evidenceRecords: store.evidenceRecords)
                if !supporting.isEmpty {
                  VStack(alignment: .leading, spacing: 6) {
                    Label(
                      "Supporting evidence (\(supporting.count))", systemImage: "doc.badge.ellipsis"
                    ).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(supporting.prefix(2), id: \.id) { rec in
                      Button {
                        selectedEvidence = rec
                      } label: {
                        HStack(spacing: 6) {
                          Text(rec.title).font(DashFont.bodySm()).foregroundColor(
                            StudentOPSTheme.textPrimary
                          ).lineLimit(1)
                          let q = EvidenceQualityEngine.quality(for: rec)
                          Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(
                            qualityColor(q.overallLevel)
                          ).padding(.horizontal, 6).padding(.vertical, 2).background(
                            qualityColor(q.overallLevel).opacity(0.12)
                          ).clipShape(Capsule())
                        }.frame(maxWidth: .infinity, alignment: .leading)
                      }.buttonStyle(.plain)
                    }
                    if supporting.count > 2 {
                      Text("+\(supporting.count - 2) more").font(DashFont.labelMono())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                    }
                  }.padding(8).background(StudentOPSTheme.background).clipShape(
                    RoundedRectangle(cornerRadius: 8))
                } else {
                  Text("No supporting evidence linked.").font(DashFont.labelMono()).foregroundColor(
                    StudentOPSTheme.textSecondary)
                }
              }.padding(10).background(StudentOPSTheme.surface).clipShape(
                RoundedRectangle(cornerRadius: 10)
              ).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
            } else {
              HStack {
                Label("Missing achievement", systemImage: "exclamationmark.triangle").font(
                  DashFont.labelMd()
                ).foregroundColor(StudentOPSTheme.warning)
                Spacer()
                Button("Remove") {
                  _ = store.removeAchievement(from: portfolio.id, achievementID: aid)
                }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
              }.padding(10).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(
                RoundedRectangle(cornerRadius: 10)
              ).overlay(
                RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.warning.opacity(0.3)))
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Recommended").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
          Spacer()
          if reportAchs.count > 5 {
            Button("See all") { showAllAchievementsAdd = true }.font(DashFont.labelMd())
              .foregroundColor(StudentOPSTheme.primaryDark)
          }
        }
        if recommended.isEmpty {
          Text("No recommendations. Build evidence to generate achievement candidates.").font(
            DashFont.bodySm()
          ).foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(
            maxWidth: .infinity, alignment: .leading
          ).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(recommended), id: \.id) { cand in
            CandidateRow(candidate: cand, isSelected: false) {
              _ = store.addAchievement(to: portfolio.id, achievementID: cand.sourceID)
            } onDetail: {
              if let ach = store.achievementRecords[cand.sourceID] { selectedAchievement = ach }
            }
          }
        }
      }

      if !unresolved.isEmpty {
        ForEach(unresolved, id: \.id) { issue in
          Text(issue.reason).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
        }
      }
    }
  }

  private func moveAchievement(portfolio: StudentPortfolio, from: Int, to: Int) {
    guard from != to, from >= 0, to >= 0, from < portfolio.selectedAchievementIDs.count,
      to < portfolio.selectedAchievementIDs.count
    else { return }
    var ids = portfolio.selectedAchievementIDs
    let item = ids.remove(at: from)
    ids.insert(item, at: to)
    _ = store.reorderAchievements(in: portfolio.id, orderedIDs: ids)
  }

  // MARK: Skills Builder

  private func skillsBuilderSection(portfolio: StudentPortfolio) -> some View {
    let selected = portfolio.selectedSkillIDs
    let reportSkills = report.skills
    let selectedSet = Set(selected.map { Skill.normalizeID($0) })
    let recommended = reportSkills.filter { !selectedSet.contains(Skill.normalizeID($0.sourceID)) }
      .prefix(5)
    let unresolved = store.unresolvedIssues(for: portfolio).filter { $0.type == .skill }

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("SKILLS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(
          StudentOPSTheme.textSecondary)
        Spacer()
        Text("\(selected.count) selected").font(DashFont.labelMono()).foregroundColor(
          StudentOPSTheme.textSecondary)
      }
      Text(
        "Only demonstrated skills are available. A skill mentioned in evidence alone does not count until your activity shows it."
      ).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)

      VStack(alignment: .leading, spacing: 8) {
        Text("Selected").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
        if selected.isEmpty {
          Text("No skills selected. Add demonstrated skills from recommended.").font(
            DashFont.bodySm()
          ).foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(
            maxWidth: .infinity, alignment: .leading
          ).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(selected.enumerated()), id: \.element) { idx, sid in
            let display = SkillCatalog.knownSkills[Skill.normalizeID(sid)]?.name ?? sid
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text(display).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                Text(Skill.normalizeID(sid)).font(DashFont.labelMono()).foregroundColor(
                  StudentOPSTheme.textSecondary)
                Spacer()
                Button {
                  _ = store.removeSkill(from: portfolio.id, skillID: sid)
                } label: {
                  Image(systemName: "minus.circle.fill").foregroundColor(StudentOPSTheme.warning)
                }.buttonStyle(.plain)
                VStack(spacing: 4) {
                  Button {
                    moveSkill(portfolio: portfolio, from: idx, to: max(0, idx - 1))
                  } label: {
                    Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold))
                  }.disabled(idx == 0)
                  Button {
                    moveSkill(portfolio: portfolio, from: idx, to: min(selected.count - 1, idx + 1))
                  } label: {
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                  }.disabled(idx == selected.count - 1)
                }.foregroundColor(StudentOPSTheme.textSecondary)
              }
              let supporting = PortfolioEvidenceEngine.supportingEvidence(
                forSkillID: sid, evidenceRecords: store.evidenceRecords)
              if !supporting.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                  Label(
                    "Evidence for this skill (\(supporting.count))",
                    systemImage: "doc.badge.ellipsis"
                  ).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                  ForEach(supporting.prefix(2), id: \.id) { rec in
                    Button {
                      selectedEvidence = rec
                    } label: {
                      HStack(spacing: 6) {
                        Text(rec.title).font(DashFont.bodySm()).foregroundColor(
                          StudentOPSTheme.textPrimary
                        ).lineLimit(1)
                        let q = EvidenceQualityEngine.quality(for: rec)
                        Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(
                          qualityColor(q.overallLevel)
                        ).padding(.horizontal, 6).padding(.vertical, 2).background(
                          qualityColor(q.overallLevel).opacity(0.12)
                        ).clipShape(Capsule())
                      }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                  }
                  if supporting.count > 2 {
                    Text("+\(supporting.count - 2) more").font(DashFont.labelMono())
                      .foregroundColor(StudentOPSTheme.textSecondary)
                  }
                }.padding(8).background(StudentOPSTheme.background).clipShape(
                  RoundedRectangle(cornerRadius: 8))
              } else {
                Text("No evidence references this skill yet.").font(DashFont.labelMono())
                  .foregroundColor(StudentOPSTheme.textSecondary)
              }
            }.padding(10).background(StudentOPSTheme.surface).clipShape(
              RoundedRectangle(cornerRadius: 10)
            ).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Recommended").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
          Spacer()
          if reportSkills.count > 5 {
            Button("See all") { showAllSkillsAdd = true }.font(DashFont.labelMd()).foregroundColor(
              StudentOPSTheme.primaryDark)
          }
        }
        if recommended.isEmpty {
          Text("No demonstrated skills yet. Complete roadmap milestones to demonstrate skills.")
            .font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(10)
            .frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(recommended), id: \.id) { cand in
            CandidateRow(candidate: cand, isSelected: false) {
              _ = store.addSkill(to: portfolio.id, skillID: cand.sourceID)
            } onDetail: {
            }
          }
        }
      }

      // Available non-demonstrated should not be selectable — we show nothing, but if store has non-demonstrated skill IDs in portfolio they appear as unresolved
      if !unresolved.isEmpty {
        ForEach(unresolved, id: \.id) { issue in
          HStack {
            Text(issue.reason).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
            Spacer()
            Button("Remove") { _ = store.removeSkill(from: portfolio.id, skillID: issue.sourceID) }
              .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
          }
        }
      }
    }
  }

  private func moveSkill(portfolio: StudentPortfolio, from: Int, to: Int) {
    guard from != to, from >= 0, to >= 0, from < portfolio.selectedSkillIDs.count,
      to < portfolio.selectedSkillIDs.count
    else { return }
    var ids = portfolio.selectedSkillIDs
    let item = ids.remove(at: from)
    ids.insert(item, at: to)
    _ = store.reorderSkills(in: portfolio.id, orderedIDs: ids)
  }

  // MARK: Evidence Builder

  private func evidenceBuilderSection(portfolio: StudentPortfolio) -> some View {
    let selected = portfolio.selectedEvidenceIDs
    let reportEvs = report.evidence
    let selectedSet = Set(selected)
    let recommended = reportEvs.filter { !selectedSet.contains($0.sourceID) }.prefix(5)
    let unresolved = store.unresolvedIssues(for: portfolio).filter { $0.type == .evidence }

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("EVIDENCE").font(DashFont.labelMono()).tracking(0.8).foregroundColor(
          StudentOPSTheme.textSecondary)
        Spacer()
        Text("\(selected.count) selected").font(DashFont.labelMono()).foregroundColor(
          StudentOPSTheme.textSecondary)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Selected").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
        if selected.isEmpty {
          Text("No evidence selected. Add proof of real work you completed.").font(
            DashFont.bodySm()
          ).foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(
            maxWidth: .infinity, alignment: .leading
          ).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(selected.enumerated()), id: \.element) { idx, eid in
            if let rec = store.evidenceRecords[eid] {
              let quality = EvidenceQualityEngine.quality(for: rec)
              HStack {
                VStack(alignment: .leading, spacing: 3) {
                  Text(rec.title).font(DashFont.labelMd()).foregroundColor(
                    StudentOPSTheme.textPrimary
                  ).lineLimit(1)
                  HStack(spacing: 6) {
                    Text(quality.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(
                      qualityColor(quality.overallLevel)
                    ).padding(.horizontal, 6).padding(.vertical, 2).background(
                      qualityColor(quality.overallLevel).opacity(0.12)
                    ).clipShape(Capsule())
                    if rec.artifact != nil {
                      Image(systemName: "link").font(.system(size: 10)).foregroundColor(
                        StudentOPSTheme.textSecondary)
                    }
                    if rec.skillIDs != nil {
                      Text("\(rec.skillIDs!.count) skills").font(DashFont.labelMono())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                    }
                  }
                }
                Spacer()
                Button {
                  _ = store.removeEvidence(from: portfolio.id, evidenceID: eid)
                } label: {
                  Image(systemName: "minus.circle.fill").foregroundColor(StudentOPSTheme.warning)
                }.buttonStyle(.plain)
                VStack(spacing: 4) {
                  Button {
                    moveEvidence(portfolio: portfolio, from: idx, to: max(0, idx - 1))
                  } label: {
                    Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold))
                  }.disabled(idx == 0)
                  Button {
                    moveEvidence(
                      portfolio: portfolio, from: idx, to: min(selected.count - 1, idx + 1))
                  } label: {
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                  }.disabled(idx == selected.count - 1)
                }.foregroundColor(StudentOPSTheme.textSecondary)
              }.padding(10).background(StudentOPSTheme.surface).clipShape(
                RoundedRectangle(cornerRadius: 10)
              ).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
                .onTapGesture { selectedEvidence = rec }
            } else {
              HStack {
                Label("Missing evidence", systemImage: "exclamationmark.triangle").font(
                  DashFont.labelMd()
                ).foregroundColor(StudentOPSTheme.warning)
                Spacer()
                Button("Remove") { _ = store.removeEvidence(from: portfolio.id, evidenceID: eid) }
                  .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
              }.padding(10).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(
                RoundedRectangle(cornerRadius: 10)
              ).overlay(
                RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.warning.opacity(0.3)))
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Recommended").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
          Spacer()
          if reportEvs.count > 5 {
            Button("See all") { showAllEvidenceAdd = true }.font(DashFont.labelMd())
              .foregroundColor(StudentOPSTheme.primaryDark)
          }
        }
        if recommended.isEmpty {
          Text(
            "No recommendations. Add evidence with artifacts and skills for stronger candidates."
          ).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(10)
            .frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(recommended), id: \.id) { cand in
            CandidateRow(candidate: cand, isSelected: false) {
              _ = store.addEvidence(to: portfolio.id, evidenceID: cand.sourceID)
            } onDetail: {
              if let rec = store.evidenceRecords[cand.sourceID] { selectedEvidence = rec }
            }
          }
        }
      }

      if !unresolved.isEmpty {
        ForEach(unresolved, id: \.id) { issue in
          Text(issue.reason).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
        }
      }
    }
  }

  private func qualityColor(_ level: EvidenceQualityLevel) -> Color {
    switch level {
    case .strong: return StudentOPSTheme.success
    case .solid: return StudentOPSTheme.primaryDark
    case .basic: return StudentOPSTheme.textSecondary
    }
  }

  private func moveEvidence(portfolio: StudentPortfolio, from: Int, to: Int) {
    guard from != to, from >= 0, to >= 0, from < portfolio.selectedEvidenceIDs.count,
      to < portfolio.selectedEvidenceIDs.count
    else { return }
    var ids = portfolio.selectedEvidenceIDs
    let item = ids.remove(at: from)
    ids.insert(item, at: to)
    _ = store.reorderEvidence(in: portfolio.id, orderedIDs: ids)
  }

  // MARK: Roadmaps Builder

  private func roadmapsBuilderSection(portfolio: StudentPortfolio) -> some View {
    let selected = portfolio.selectedRoadmapIDs
    let reportRMs = report.roadmaps
    let selectedSet = Set(selected)
    let recommended = reportRMs.filter { !selectedSet.contains($0.sourceID) }.prefix(5)
    let unresolved = store.unresolvedIssues(for: portfolio).filter { $0.type == .roadmap }

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("ROADMAPS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(
          StudentOPSTheme.textSecondary)
        Spacer()
        Text("\(selected.count) selected").font(DashFont.labelMono()).foregroundColor(
          StudentOPSTheme.textSecondary)
      }
      Text("Include roadmaps to communicate direction and progression.").font(DashFont.bodySm())
        .foregroundColor(StudentOPSTheme.textSecondary)

      VStack(alignment: .leading, spacing: 8) {
        Text("Selected").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
        if selected.isEmpty {
          Text("No roadmaps selected. Add an active roadmap to show direction.").font(
            DashFont.bodySm()
          ).foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(
            maxWidth: .infinity, alignment: .leading
          ).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(selected.enumerated()), id: \.element) { idx, rid in
            if let rm = RoadmapService.roadmap(for: rid) {
              let scored = store.scoredRoadmaps.first(where: { $0.roadmap.id == rid })
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(rm.title).font(DashFont.labelMd()).foregroundColor(
                      StudentOPSTheme.textPrimary
                    ).lineLimit(1)
                    Text(rm.goal).font(DashFont.labelMono()).foregroundColor(
                      StudentOPSTheme.textSecondary
                    ).lineLimit(1)
                    if let s = scored {
                      Text("\(s.progress)% • \(s.completedMilestones)/\(rm.milestones.count)").font(
                        DashFont.labelMono()
                      ).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                  }
                  Spacer()
                  Button {
                    _ = store.removeRoadmap(from: portfolio.id, roadmapID: rid)
                  } label: {
                    Image(systemName: "minus.circle.fill").foregroundColor(StudentOPSTheme.warning)
                  }.buttonStyle(.plain)
                  VStack(spacing: 4) {
                    Button {
                      moveRoadmap(portfolio: portfolio, from: idx, to: max(0, idx - 1))
                    } label: {
                      Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold))
                    }.disabled(idx == 0)
                    Button {
                      moveRoadmap(
                        portfolio: portfolio, from: idx, to: min(selected.count - 1, idx + 1))
                    } label: {
                      Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }.disabled(idx == selected.count - 1)
                  }.foregroundColor(StudentOPSTheme.textSecondary)
                }
                .onTapGesture {
                  if let s = store.scoredRoadmaps.first(where: { $0.roadmap.id == rid }) {
                    selectedRoadmap = s
                  }
                }
                let supporting = PortfolioEvidenceEngine.supportingEvidence(
                  forRoadmapID: rid, evidenceRecords: store.evidenceRecords)
                if !supporting.isEmpty {
                  VStack(alignment: .leading, spacing: 6) {
                    Label(
                      "Evidence of progress (\(supporting.count))",
                      systemImage: "doc.badge.ellipsis"
                    ).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(supporting.prefix(2), id: \.id) { rec in
                      Button {
                        selectedEvidence = rec
                      } label: {
                        HStack(spacing: 6) {
                          Text(rec.title).font(DashFont.bodySm()).foregroundColor(
                            StudentOPSTheme.textPrimary
                          ).lineLimit(1)
                          let q = EvidenceQualityEngine.quality(for: rec)
                          Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(
                            qualityColor(q.overallLevel)
                          ).padding(.horizontal, 6).padding(.vertical, 2).background(
                            qualityColor(q.overallLevel).opacity(0.12)
                          ).clipShape(Capsule())
                        }.frame(maxWidth: .infinity, alignment: .leading)
                      }.buttonStyle(.plain)
                    }
                    if supporting.count > 2 {
                      Text("+\(supporting.count - 2) more").font(DashFont.labelMono())
                        .foregroundColor(StudentOPSTheme.textSecondary)
                    }
                  }.padding(8).background(StudentOPSTheme.background).clipShape(
                    RoundedRectangle(cornerRadius: 8))
                } else {
                  Text("No evidence linked yet.").font(DashFont.labelMono()).foregroundColor(
                    StudentOPSTheme.textSecondary)
                }
              }.padding(10).background(StudentOPSTheme.surface).clipShape(
                RoundedRectangle(cornerRadius: 10)
              ).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border))
            } else {
              HStack {
                Label("Missing roadmap", systemImage: "exclamationmark.triangle").font(
                  DashFont.labelMd()
                ).foregroundColor(StudentOPSTheme.warning)
                Spacer()
                Button("Remove") { _ = store.removeRoadmap(from: portfolio.id, roadmapID: rid) }
                  .font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
              }.padding(10).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(
                RoundedRectangle(cornerRadius: 10)
              ).overlay(
                RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.warning.opacity(0.3)))
            }
          }
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Recommended").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
          Spacer()
          if reportRMs.count > 5 {
            Button("See all") { showAllRoadmapsAdd = true }.font(DashFont.labelMd())
              .foregroundColor(StudentOPSTheme.primaryDark)
          }
        }
        if recommended.isEmpty {
          Text("No roadmap recommendations. Start a roadmap to generate candidates.").font(
            DashFont.bodySm()
          ).foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(
            maxWidth: .infinity, alignment: .leading
          ).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
          ForEach(Array(recommended), id: \.id) { cand in
            CandidateRow(candidate: cand, isSelected: false) {
              _ = store.addRoadmap(to: portfolio.id, roadmapID: cand.sourceID)
            } onDetail: {
              if let s = store.scoredRoadmaps.first(where: { $0.roadmap.id == cand.sourceID }) {
                selectedRoadmap = s
              }
            }
          }
        }
      }

      if !unresolved.isEmpty {
        ForEach(unresolved, id: \.id) { issue in
          Text(issue.reason).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
        }
      }
    }
  }

  private func moveRoadmap(portfolio: StudentPortfolio, from: Int, to: Int) {
    guard from != to, from >= 0, to >= 0, from < portfolio.selectedRoadmapIDs.count,
      to < portfolio.selectedRoadmapIDs.count
    else { return }
    var ids = portfolio.selectedRoadmapIDs
    let item = ids.remove(at: from)
    ids.insert(item, at: to)
    _ = store.reorderRoadmaps(in: portfolio.id, orderedIDs: ids)
  }

  // MARK: Unresolved

  private func unresolvedSection(portfolio: StudentPortfolio) -> some View {
    let issues = store.unresolvedIssues(for: portfolio)
    if issues.isEmpty { return AnyView(EmptyView()) }
    return AnyView(
      VStack(alignment: .leading, spacing: 8) {
        Text("UNRESOLVED REFERENCES").font(DashFont.labelMono()).tracking(0.8).foregroundColor(
          StudentOPSTheme.warning)
        Text(
          "Some selected items no longer exist. Remove them to clean the portfolio. The portfolio preserves stale IDs until you choose to remove."
        ).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        ForEach(issues, id: \.id) { issue in
          HStack {
            Text("\(issue.type.rawValue): \(issue.sourceID)").font(DashFont.labelMono())
              .foregroundColor(StudentOPSTheme.warning).lineLimit(1)
            Spacer()
            Button("Remove") {
              switch issue.type {
              case .project: _ = store.removeProject(from: portfolio.id, projectID: issue.sourceID)
              case .achievement:
                _ = store.removeAchievement(from: portfolio.id, achievementID: issue.sourceID)
              case .evidence:
                _ = store.removeEvidence(from: portfolio.id, evidenceID: issue.sourceID)
              case .skill: _ = store.removeSkill(from: portfolio.id, skillID: issue.sourceID)
              case .roadmap: _ = store.removeRoadmap(from: portfolio.id, roadmapID: issue.sourceID)
              }
            }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
          }.padding(8).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(
            RoundedRectangle(cornerRadius: 8))
        }
      }.padding(12).background(StudentOPSTheme.surface).clipShape(
        RoundedRectangle(cornerRadius: 12)
      ).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.warning.opacity(0.3))))
  }

  private func previewButton(portfolio: StudentPortfolio) -> some View {
    Button(action: { showingPreview = true }) {
      Label("Preview portfolio structure", systemImage: "eye")
        .font(DashFont.labelMd())
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(StudentOPSTheme.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }.buttonStyle(.plain)
  }

  private func deleteSection(portfolio: StudentPortfolio) -> some View {
    VStack(spacing: 10) {
      Button(role: .destructive) {
        _ = store.deletePortfolio(id: portfolio.id)
        dismiss()
      } label: {
        Label("Delete portfolio", systemImage: "trash").font(DashFont.labelMd()).foregroundColor(
          StudentOPSTheme.warning
        ).frame(maxWidth: .infinity).padding(.vertical, 10).background(
          StudentOPSTheme.warning.opacity(0.08)
        ).clipShape(RoundedRectangle(cornerRadius: 10))
      }.buttonStyle(.plain)
      Text(
        "Deleting the portfolio does not delete projects, achievements, evidence, skills, or roadmaps. Only the presentation selection is removed."
      ).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
        .multilineTextAlignment(.center)
    }
  }

  // MARK: - See All sheets

  private var allProjectsSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 10) {
          ForEach(report.projects) { cand in
            let isSelected = portfolio?.selectedProjectIDs.contains(cand.sourceID) ?? false
            CandidateRow(candidate: cand, isSelected: isSelected) {
              if let pid = portfolio?.id { _ = store.addProject(to: pid, projectID: cand.sourceID) }
            } onDetail: {
              if let sp = store.scoredProjects.first(where: { $0.project.id == cand.sourceID }) {
                selectedProject = sp
              }
            }
          }
        }.padding(16)
      }.background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("All Project Candidates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { showAllProjectsAdd = false }
          }
        }
    }
  }

  private var allAchievementsSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 10) {
          ForEach(report.achievements) { cand in
            let isSelected = portfolio?.selectedAchievementIDs.contains(cand.sourceID) ?? false
            CandidateRow(candidate: cand, isSelected: isSelected) {
              if let pid = portfolio?.id {
                _ = store.addAchievement(to: pid, achievementID: cand.sourceID)
              }
            } onDetail: {
              if let ach = store.achievementRecords[cand.sourceID] { selectedAchievement = ach }
            }
          }
        }.padding(16)
      }.background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("All Achievement Candidates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { showAllAchievementsAdd = false }
          }
        }
    }
  }

  private var allEvidenceSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 10) {
          ForEach(report.evidence) { cand in
            let isSelected = portfolio?.selectedEvidenceIDs.contains(cand.sourceID) ?? false
            CandidateRow(candidate: cand, isSelected: isSelected) {
              if let pid = portfolio?.id {
                _ = store.addEvidence(to: pid, evidenceID: cand.sourceID)
              }
            } onDetail: {
              if let rec = store.evidenceRecords[cand.sourceID] { selectedEvidence = rec }
            }
          }
        }.padding(16)
      }.background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("All Evidence Candidates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { showAllEvidenceAdd = false }
          }
        }
    }
  }

  private var allSkillsSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 10) {
          ForEach(report.skills) { cand in
            let isSelected =
              portfolio?.selectedSkillIDs.contains(Skill.normalizeID(cand.sourceID)) ?? false
            CandidateRow(candidate: cand, isSelected: isSelected) {
              if let pid = portfolio?.id { _ = store.addSkill(to: pid, skillID: cand.sourceID) }
            } onDetail: {
            }
          }
        }.padding(16)
      }.background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("All Skill Candidates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { showAllSkillsAdd = false }
          }
        }
    }
  }

  private var allRoadmapsSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 10) {
          ForEach(report.roadmaps) { cand in
            let isSelected = portfolio?.selectedRoadmapIDs.contains(cand.sourceID) ?? false
            CandidateRow(candidate: cand, isSelected: isSelected) {
              if let pid = portfolio?.id { _ = store.addRoadmap(to: pid, roadmapID: cand.sourceID) }
            } onDetail: {
              if let s = store.scoredRoadmaps.first(where: { $0.roadmap.id == cand.sourceID }) {
                selectedRoadmap = s
              }
            }
          }
        }.padding(16)
      }.background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("All Roadmap Candidates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Done") { showAllRoadmapsAdd = false }
          }
        }
    }
  }
}

// MARK: - Candidate Row (factual, no exaggerated language)

private struct CandidateRow: View {
  let candidate: PortfolioCandidate
  let isSelected: Bool
  let onAdd: () -> Void
  let onDetail: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(candidate.title).font(DashFont.labelMd()).foregroundColor(
            StudentOPSTheme.textPrimary
          ).lineLimit(1)
          HStack(spacing: 6) {
            Text(candidate.type.rawValue).font(DashFont.labelMono()).foregroundColor(
              StudentOPSTheme.textSecondary
            ).padding(.horizontal, 6).padding(.vertical, 2).background(StudentOPSTheme.background)
              .clipShape(Capsule())
            Text("Portfolio fit \(candidate.score)").font(DashFont.labelMono()).foregroundColor(
              StudentOPSTheme.primaryDark
            ).padding(.horizontal, 6).padding(.vertical, 2).background(
              StudentOPSTheme.primary.opacity(0.12)
            ).clipShape(Capsule())
            if candidate.evidenceCount > 0 {
              Text("\(candidate.evidenceCount) evidence").font(DashFont.labelMono())
                .foregroundColor(StudentOPSTheme.textSecondary)
            }
          }
        }
        Spacer()
        if isSelected {
          Label("Selected", systemImage: "checkmark.circle.fill").font(DashFont.labelMono())
            .foregroundColor(StudentOPSTheme.success)
        } else {
          Button(action: onAdd) {
            Label("Add", systemImage: "plus.circle.fill").font(DashFont.labelMd()).foregroundColor(
              StudentOPSTheme.textOnPrimary
            ).padding(.horizontal, 12).padding(.vertical, 6).background(StudentOPSTheme.primary)
              .clipShape(Capsule())
          }.buttonStyle(.plain)
        }
      }
      Text(candidate.reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
        .lineLimit(3)
      if !candidate.relatedSkillIDs.isEmpty {
        FlowLayout(spacing: 4) {
          ForEach(candidate.relatedSkillIDs.prefix(3), id: \.self) { sid in
            Text(SkillCatalog.knownSkills[sid]?.name ?? sid).font(DashFont.labelMono())
              .foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 6).padding(
                .vertical, 3
              ).background(StudentOPSTheme.background).overlay(
                RoundedRectangle(cornerRadius: 6).stroke(StudentOPSTheme.border))
          }
        }
      }
      if isSelected {
        Text("Already selected").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
      } else if candidate.isRecommended {
        Text("Recommended").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
      } else {
        Text("Available").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
      }
    }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12).stroke(
          isSelected ? StudentOPSTheme.success.opacity(0.3) : StudentOPSTheme.border.opacity(0.6))
      )
      .onTapGesture(perform: onDetail)
  }
}

// MARK: - AppDataStore helpers for PortfolioEngine asOf

extension AppDataStore {
  func candidatesReport(asOf: Date) -> PortfolioCandidateReport {
    PortfolioEngine.candidates(store: self, asOf: asOf)
  }
  func unresolvedIssues(for portfolio: StudentPortfolio) -> [PortfolioReferenceIssue] {
    PortfolioEngine.unresolvedReferences(for: portfolio, store: self)
  }
}

// MARK: - Metadata Editor

struct PortfolioMetadataEditorView: View {
  let portfolio: StudentPortfolio
  @EnvironmentObject var store: AppDataStore
  @Environment(\.dismiss) private var dismiss
  @State private var title: String = ""
  @State private var headline: String = ""
  @State private var about: String = ""
  @State private var goalsText: String = ""
  @State private var showingHeadlineAI = false
  @State private var showingAboutAI = false
  @State private var showingGoalsAI = false

  var body: some View {
    NavigationStack {
      Form {
        Section("Title") {
          TextField("Portfolio title", text: $title)
        }
        Section(
          header: HStack {
            Text("Headline (optional)")
            Spacer()
            Button(action: { showingHeadlineAI = true }) {
              Label("Improve with AI", systemImage: "sparkles").font(DashFont.labelMono())
                .foregroundColor(StudentOPSTheme.primaryDark)
            }
          }
        ) {
          TextField("e.g. 9th grade student in Austin...", text: $headline)
        }
        .sheet(isPresented: $showingHeadlineAI) {
          PortfolioAIWritingView(
            portfolioID: portfolio.id, writingType: .headline, targetID: nil, currentText: headline,
            onAccept: { draft, _ in headline = draft }
          ).environmentObject(store)
        }
        Section(
          header: HStack {
            Text("About (optional)")
            Spacer()
            Button(action: { showingAboutAI = true }) {
              Label("Draft with AI", systemImage: "sparkles").font(DashFont.labelMono())
                .foregroundColor(StudentOPSTheme.primaryDark)
            }
          }
        ) {
          TextEditor(text: $about).frame(minHeight: 80)
        }
        .sheet(isPresented: $showingAboutAI) {
          PortfolioAIWritingView(
            portfolioID: portfolio.id, writingType: .about, targetID: nil, currentText: about,
            onAccept: { draft, _ in about = draft }
          ).environmentObject(store)
        }
        Section(
          header: HStack {
            Text("Goals (one per line)")
            Spacer()
            Button(action: { showingGoalsAI = true }) {
              Label("Clarify with AI", systemImage: "sparkles").font(DashFont.labelMono())
                .foregroundColor(StudentOPSTheme.primaryDark)
            }
          }
        ) {
          TextEditor(text: $goalsText).frame(minHeight: 90)
          Text("Goals are stored as separate items. Blank lines are ignored.").font(
            DashFont.labelMono()
          ).foregroundColor(StudentOPSTheme.textSecondary)
        }
        .sheet(isPresented: $showingGoalsAI) {
          // For goals, we send the whole goalsText as currentText for the first goal, or portfolio-level
          PortfolioAIWritingView(
            portfolioID: portfolio.id, writingType: .goal, targetID: portfolio.goals.first,
            currentText: goalsText,
            onAccept: { draft, _ in
              // AI returns a single clarified goal; we replace the first line or append
              var goals = goalsText.components(separatedBy: .newlines).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
              }.filter { !$0.isEmpty }
              if goals.isEmpty {
                goalsText = draft
              } else {
                // Replace first goal with draft (or append if draft is new)
                goals[0] = draft
                goalsText = goals.joined(separator: "\n")
              }
            }
          ).environmentObject(store)
        }
      }
      .navigationTitle("Edit Portfolio")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            var updated = portfolio
            updated.title = t
            updated.headline =
              headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              ? nil : headline.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.about =
              about.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              ? nil : about.trimmingCharacters(in: .whitespacesAndNewlines)
            let goals = goalsText.components(separatedBy: .newlines).map {
              $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            updated.goals = goals
            _ = store.updatePortfolio(updated)
            dismiss()
          }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onAppear {
        title = portfolio.title
        headline = portfolio.headline ?? ""
        about = portfolio.about ?? ""
        goalsText = portfolio.goals.joined(separator: "\n")
      }
    }
  }
}

// MARK: - Sections Editor

struct PortfolioSectionsEditorView: View {
  let portfolio: StudentPortfolio
  @EnvironmentObject var store: AppDataStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        ForEach(Array(portfolio.sections.enumerated()), id: \.element.id) { idx, sec in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(sec.title).font(DashFont.labelMd()).foregroundColor(
                sec.isEnabled ? StudentOPSTheme.textPrimary : StudentOPSTheme.textSecondary)
              Text(sec.type.rawValue).font(DashFont.labelMono()).foregroundColor(
                StudentOPSTheme.textSecondary)
            }
            Spacer()
            Button(sec.isEnabled ? "Hide" : "Show") {
              _ = store.setSectionEnabled(
                in: portfolio.id, sectionID: sec.id, isEnabled: !sec.isEnabled)
            }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
          }
        }
        .onMove { from, to in
          var ids = portfolio.sections.map(\.id)
          ids.move(fromOffsets: from, toOffset: to)
          _ = store.reorderSections(in: portfolio.id, orderedIDs: ids)
        }
        Section {
          Text("Reorder with drag handle. Hide/show affects preview.").font(DashFont.labelMono())
            .foregroundColor(StudentOPSTheme.textSecondary)
        }
      }
      .navigationTitle("Edit Sections")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
        ToolbarItem(placement: .primaryAction) { EditButton() }
      }
    }
  }
}

// MARK: - Preview

struct PortfolioPreviewView: View {
  let portfolio: StudentPortfolio
  @EnvironmentObject var store: AppDataStore

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
          Text(portfolio.title).font(DashFont.headlineSm()).foregroundColor(
            StudentOPSTheme.textPrimary)
          if let h = portfolio.headline, !h.isEmpty {
            Text(h).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
          }
          if let a = portfolio.about, !a.isEmpty {
            Text(a).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
          }
          if !portfolio.goals.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Text("GOALS").font(DashFont.labelMono()).foregroundColor(
                StudentOPSTheme.textSecondary)
              ForEach(portfolio.goals, id: \.self) { g in
                Text("• \(g)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
              }
            }
          }
        }.padding(16).background(StudentOPSTheme.surface).clipShape(
          RoundedRectangle(cornerRadius: 16))

        ForEach(portfolio.sections.filter(\.isEnabled), id: \.id) { sec in
          VStack(alignment: .leading, spacing: 10) {
            Text(sec.title.uppercased()).font(DashFont.labelMono()).tracking(0.8).foregroundColor(
              StudentOPSTheme.textSecondary)
            switch sec.type {
            case .about:
              if let a = portfolio.about, !a.isEmpty {
                Text(a).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
              } else {
                Text("No about provided.").font(DashFont.bodySm()).foregroundColor(
                  StudentOPSTheme.textSecondary)
              }
            case .goals:
              if portfolio.goals.isEmpty {
                Text("No goals.").font(DashFont.bodySm()).foregroundColor(
                  StudentOPSTheme.textSecondary)
              } else {
                ForEach(portfolio.goals, id: \.self) { g in
                  Text("• \(g)").font(DashFont.bodySm()).foregroundColor(
                    StudentOPSTheme.textPrimary)
                }
              }
            case .skills:
              if portfolio.selectedSkillIDs.isEmpty {
                Text("No skills selected.").font(DashFont.bodySm()).foregroundColor(
                  StudentOPSTheme.textSecondary)
              } else {
                FlowLayout(spacing: 6) {
                  ForEach(portfolio.selectedSkillIDs, id: \.self) { sid in
                    let name = SkillCatalog.knownSkills[Skill.normalizeID(sid)]?.name ?? sid
                    Text(name).font(DashFont.labelMono()).foregroundColor(
                      StudentOPSTheme.textPrimary
                    ).padding(.horizontal, 8).padding(.vertical, 4).background(
                      StudentOPSTheme.background
                    ).overlay(RoundedRectangle(cornerRadius: 6).stroke(StudentOPSTheme.border))
                  }
                }
              }
            case .projects:
              if portfolio.selectedProjectIDs.isEmpty {
                Text("No projects selected.").font(DashFont.bodySm()).foregroundColor(
                  StudentOPSTheme.textSecondary)
              } else {
                ForEach(portfolio.selectedProjectIDs, id: \.self) { pid in
                  if let sp = store.scoredProjects.first(where: { $0.project.id == pid }) {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(sp.project.title).font(DashFont.labelMd()).foregroundColor(
                        StudentOPSTheme.textPrimary)
                      Text(sp.project.goal).font(DashFont.bodySm()).foregroundColor(
                        StudentOPSTheme.textSecondary
                      ).lineLimit(2)
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(
                      StudentOPSTheme.surface
                    ).clipShape(RoundedRectangle(cornerRadius: 10))
                  } else {
                    Text("Missing project: \(pid)").font(DashFont.labelMono()).foregroundColor(
                      StudentOPSTheme.warning)
                  }
                }
              }
            case .achievements:
              if portfolio.selectedAchievementIDs.isEmpty {
                Text("No achievements selected.").font(DashFont.bodySm()).foregroundColor(
                  StudentOPSTheme.textSecondary)
              } else {
                ForEach(portfolio.selectedAchievementIDs, id: \.self) { aid in
                  if let ach = store.achievementRecords[aid] {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(ach.title).font(DashFont.labelMd()).foregroundColor(
                        StudentOPSTheme.textPrimary)
                      Text(ach.type.displayName).font(DashFont.labelMono()).foregroundColor(
                        StudentOPSTheme.textSecondary)
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(
                      StudentOPSTheme.surface
                    ).clipShape(RoundedRectangle(cornerRadius: 10))
                  } else {
                    Text("Missing achievement: \(aid)").font(DashFont.labelMono()).foregroundColor(
                      StudentOPSTheme.warning)
                  }
                }
              }
            case .evidence:
              if portfolio.selectedEvidenceIDs.isEmpty {
                Text("No evidence selected.").font(DashFont.bodySm()).foregroundColor(
                  StudentOPSTheme.textSecondary)
              } else {
                ForEach(portfolio.selectedEvidenceIDs, id: \.self) { eid in
                  if let rec = store.evidenceRecords[eid] {
                    let q = EvidenceQualityEngine.quality(for: rec)
                    VStack(alignment: .leading, spacing: 4) {
                      Text(rec.title).font(DashFont.labelMd()).foregroundColor(
                        StudentOPSTheme.textPrimary)
                      Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(
                        StudentOPSTheme.textSecondary)
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(
                      StudentOPSTheme.surface
                    ).clipShape(RoundedRectangle(cornerRadius: 10))
                  } else {
                    Text("Missing evidence: \(eid)").font(DashFont.labelMono()).foregroundColor(
                      StudentOPSTheme.warning)
                  }
                }
              }
            case .roadmaps:
              if portfolio.selectedRoadmapIDs.isEmpty {
                Text("No roadmaps selected.").font(DashFont.bodySm()).foregroundColor(
                  StudentOPSTheme.textSecondary)
              } else {
                ForEach(portfolio.selectedRoadmapIDs, id: \.self) { rid in
                  if let rm = RoadmapService.roadmap(for: rid) {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(rm.title).font(DashFont.labelMd()).foregroundColor(
                        StudentOPSTheme.textPrimary)
                      Text(rm.goal).font(DashFont.bodySm()).foregroundColor(
                        StudentOPSTheme.textSecondary
                      ).lineLimit(2)
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(
                      StudentOPSTheme.surface
                    ).clipShape(RoundedRectangle(cornerRadius: 10))
                  } else {
                    Text("Missing roadmap: \(rid)").font(DashFont.labelMono()).foregroundColor(
                      StudentOPSTheme.warning)
                  }
                }
              }
            }
          }
        }
      }.padding(16)
    }
    .background(StudentOPSTheme.background.ignoresSafeArea())
    .navigationTitle("Preview")
    .navigationBarTitleDisplayMode(.inline)
  }
}
