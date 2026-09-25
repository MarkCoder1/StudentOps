import SwiftUI

// MARK: - Portfolio Presentation (Phase 8.5 — polished, read-only, no duplication)

struct PortfolioPresentationView: View {
    let portfolioID: String
    @EnvironmentObject var store: AppDataStore
    @State private var selectedProject: ScoredProject?
    @State private var selectedRoadmap: ScoredRoadmap?
    @State private var selectedAchievement: Achievement?
    @State private var selectedEvidence: EvidenceRecord?

    private var portfolio: StudentPortfolio? { store.portfolio(id: portfolioID) }
    private var snapshot: StudentProfileSnapshot { StudentProfileSnapshot.make(from: store) }

    var body: some View {
        Group {
            if let portfolio = portfolio {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        presentationHeader(portfolio: portfolio)
                        ForEach(portfolio.sections.filter(\.isEnabled), id: \.id) { section in
                            sectionContent(section: section, portfolio: portfolio)
                        }
                        // Subtle portfolio checks — not dashboards, just optional checks near existing Portfolio check
                        let quality = PortfolioQualityEngine.evaluate(for: portfolio, store: store)
                        NavigationLink(destination: PortfolioQualityDetailView(result: quality)) {
                            HStack(spacing: 10) {
                                Label("Portfolio check", systemImage: "chart.bar").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                Spacer()
                                Text("\(quality.percent)% • \(quality.overallLevel.displayName)").font(DashFont.labelMono()).foregroundColor(portfolioQualityColor(quality.overallLevel)).padding(.horizontal, 8).padding(.vertical, 4).background(portfolioQualityColor(quality.overallLevel).opacity(0.12)).clipShape(Capsule())
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                            }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
                        }.buttonStyle(.plain)
                        let integrity = PortfolioGraphIntegrityEngine.report(for: portfolio, store: store)
                        NavigationLink(destination: PortfolioGraphIntegrityDetailView(report: integrity)) {
                            HStack(spacing: 10) {
                                Label("Portfolio integrity", systemImage: "shield.lefthalf.filled").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                Spacer()
                                if integrity.isValid {
                                    Label("Valid", systemImage: "checkmark.seal.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
                                } else {
                                    Text("\(integrity.issueCount) issue\(integrity.issueCount==1 ? "" : "s")").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.warning.opacity(0.12)).clipShape(Capsule())
                                }
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                            }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(integrity.isValid ? StudentOPSTheme.success.opacity(0.2) : StudentOPSTheme.warning.opacity(0.2)))
                        }.buttonStyle(.plain)
                        // Edit action
                        NavigationLink(destination: PortfolioBuilderView(portfolioID: portfolio.id).environmentObject(store)) {
                            Label("Edit Portfolio", systemImage: "pencil").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textOnPrimary).frame(maxWidth:.infinity).padding(.vertical, 14).background(StudentOPSTheme.primaryDark).clipShape(RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain).padding(.top, 8)
                    }.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 32)
                }
                .background(StudentOPSTheme.background.ignoresSafeArea())
                .navigationTitle(portfolio.title)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(item: $selectedProject) { sp in NavigationStack{ ProjectDetailView(scoredProject: sp).environmentObject(store) } }
                .sheet(item: $selectedRoadmap) { sr in NavigationStack{ RoadmapDetailView(scoredRoadmap: sr).environmentObject(store) } }
                .sheet(item: $selectedAchievement) { ach in NavigationStack{ AchievementDetailView(achievement: ach).environmentObject(store) } }
                .sheet(item: $selectedEvidence) { rec in EvidenceDetailSheet(record: rec).environmentObject(store) }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.ellipsis").font(.system(size: 32)).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Portfolio not found").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text("It may have been deleted.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }.padding(32)
            }
        }
    }

    // MARK: Header

    private func presentationHeader(portfolio: StudentPortfolio) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Student identity (factual, from snapshot)
            HStack(spacing: 12) {
                Circle()
                    .fill(StudentOPSTheme.primaryDark)
                    .frame(width: 56, height: 56)
                    .overlay(Text(String(snapshot.displayName.prefix(1)).uppercased()).font(DashFont.headlineSm()).foregroundColor(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.displayName).font(DashFont.headlineSm()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text("\(snapshot.gradeLabel) · \(snapshot.schoolLevelLabel)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    if !snapshot.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(snapshot.location, systemImage: "mappin").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }
                Spacer()
            }

            // Portfolio identity
            VStack(alignment: .leading, spacing: 8) {
                Text(portfolio.title.isEmpty ? "My Portfolio" : portfolio.title)
                    .font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                if let h = portfolio.headline?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty {
                    Text(h).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
            }

            // Subtle metrics (factual, not gamified)
            let c = portfolioCounts(portfolio)
            if c.totalSelected > 0 {
                Text("\(c.projects) projects · \(c.achievements) achievements · \(c.skills) skills · \(c.evidence) evidence · \(c.roadmaps) roadmaps")
                    .font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
            }
        }
        .padding(18)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(StudentOPSTheme.border.opacity(0.6)))
        .shadow(color: StudentOPSTheme.shadow, radius: 8, y: 4)
    }

    private struct Counts { let projects:Int; let achievements:Int; let skills:Int; let evidence:Int; let roadmaps:Int; var totalSelected:Int { projects+achievements+skills+evidence+roadmaps } }
    private func portfolioCounts(_ p: StudentPortfolio) -> Counts {
        Counts(projects: p.selectedProjectIDs.count, achievements: p.selectedAchievementIDs.count, skills: p.selectedSkillIDs.count, evidence: p.selectedEvidenceIDs.count, roadmaps: p.selectedRoadmapIDs.count)
    }

    // MARK: Section Router

    @ViewBuilder
    private func sectionContent(section: PortfolioSection, portfolio: StudentPortfolio) -> some View {
        switch section.type {
        case .about: aboutSection(portfolio: portfolio, section: section)
        case .goals: goalsSection(portfolio: portfolio, section: section)
        case .skills: skillsSection(portfolio: portfolio, section: section)
        case .projects: projectsSection(portfolio: portfolio, section: section)
        case .achievements: achievementsSection(portfolio: portfolio, section: section)
        case .evidence: evidenceSection(portfolio: portfolio, section: section)
        case .roadmaps: roadmapsSection(portfolio: portfolio, section: section)
        }
    }

    private var sectionTitle: (PortfolioSection) -> String {
        { sec in
            let t = sec.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? sec.type.displayName : t
        }
    }

    // MARK: About

    @ViewBuilder
    private func aboutSection(portfolio: StudentPortfolio, section: PortfolioSection) -> some View {
        if let about = portfolio.about?.trimmingCharacters(in: .whitespacesAndNewlines), !about.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(sectionTitle(section).uppercased()).font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Text(about).font(DashFont.bodyMd()).foregroundColor(StudentOPSTheme.textPrimary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth:.infinity, alignment:.leading).padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.4)))
        }
    }

    // MARK: Goals

    @ViewBuilder
    private func goalsSection(portfolio: StudentPortfolio, section: PortfolioSection) -> some View {
        if !portfolio.goals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(sectionTitle(section).uppercased()).font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(portfolio.goals, id:\.self) { g in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(StudentOPSTheme.primary).frame(width: 6, height: 6).padding(.top, 6)
                            Text(g).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
            }
        }
    }

    // MARK: Skills

    @ViewBuilder
    private func skillsSection(portfolio: StudentPortfolio, section: PortfolioSection) -> some View {
        let ids = portfolio.selectedSkillIDs
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(sectionTitle(section).uppercased()).font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(ids, id:\.self) { raw in
                        let norm = Skill.normalizeID(raw)
                        let display = SkillCatalog.knownSkills[norm]?.name ?? raw
                        let isDemonstrated = snapshot.demonstratedSkillIDs.contains(norm)
                        HStack(spacing: 6) {
                            if isDemonstrated { Circle().fill(StudentOPSTheme.success).frame(width: 6, height: 6) }
                            Text(display).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        }.padding(.horizontal, 10).padding(.vertical, 7).background(StudentOPSTheme.surface).clipShape(Capsule()).overlay(Capsule().stroke(isDemonstrated ? StudentOPSTheme.success.opacity(0.3) : StudentOPSTheme.border))
                        .accessibilityLabel(Text(display))
                    }
                }
                // Evidence supporting each skill (derived, not mastery claim)
                ForEach(ids, id:\.self) { raw in
                    let norm = Skill.normalizeID(raw)
                    let display = SkillCatalog.knownSkills[norm]?.name ?? raw
                    let supporting = PortfolioEvidenceEngine.supportingEvidence(forSkillID: norm, evidenceRecords: store.evidenceRecords)
                    if !supporting.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text(display).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                                Text("·").foregroundColor(StudentOPSTheme.textSecondary)
                                Label("\(supporting.count) evidence", systemImage: "doc.badge.ellipsis").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                            ForEach(supporting.prefix(2), id:\.id) { rec in
                                Button { selectedEvidence = rec } label: {
                                    HStack(spacing: 8) {
                                        Text(rec.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                        let q = EvidenceQualityEngine.quality(for: rec)
                                        Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(qualityColor(q.overallLevel)).padding(.horizontal, 6).padding(.vertical, 2).background(qualityColor(q.overallLevel).opacity(0.12)).clipShape(Capsule())
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                                    }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border.opacity(0.5)))
                                }.buttonStyle(.plain).accessibilityLabel(Text("View evidence: \(rec.title)"))
                            }
                            if supporting.count > 2 {
                                Text("+\(supporting.count - 2) more").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                        }.padding(10).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
                    }
                }
            }
        }
    }

    // MARK: Projects

    @ViewBuilder
    private func projectsSection(portfolio: StudentPortfolio, section: PortfolioSection) -> some View {
        let ids = portfolio.selectedProjectIDs
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(sectionTitle(section).uppercased()).font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                ForEach(ids, id:\.self) { pid in
                    if let scored = store.scoredProjects.first(where: { $0.project.id == pid }) {
                        Button { selectedProject = scored } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label(scored.project.category, systemImage: "hammer").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                                    Spacer()
                                    Text(scored.isCompleted ? "Completed" : "\(scored.progress)%").font(DashFont.labelMono()).foregroundColor(scored.isCompleted ? StudentOPSTheme.success : StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4).background((scored.isCompleted ? StudentOPSTheme.success : StudentOPSTheme.border).opacity(0.12)).clipShape(Capsule())
                                }
                                Text(scored.project.title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(StudentOPSTheme.textPrimary).frame(maxWidth:.infinity, alignment:.leading).lineLimit(2)
                                if !scored.project.description.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
                                    Text(scored.project.description).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(3).frame(maxWidth:.infinity, alignment:.leading)
                                }
                                if !scored.project.skills.isEmpty {
                                    FlowLayout(spacing: 6) {
                                        ForEach(scored.project.skills.prefix(4), id:\.self) { s in
                                            Text(s).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.background).clipShape(Capsule()).overlay(Capsule().stroke(StudentOPSTheme.border))
                                        }
                                    }
                                }
                                HStack(spacing: 12) {
                                    Label("\(scored.completedMilestones)/\(scored.project.milestones.count) milestones", systemImage: "point.3.connected.trianglepath.dotted").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                    let evCount = store.evidenceRecords.values.filter { $0.projectID == pid }.count
                                    if evCount > 0 {
                                        Label("\(evCount) evidence", systemImage: "doc.badge.ellipsis").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                    }
                                    if let src = scored.project.sourceRoadmapID, !src.isEmpty {
                                        Label(src, systemImage: "link").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                                    }
                                }
                                // Supporting evidence (derived, not auto-selected)
                                let supporting = PortfolioEvidenceEngine.supportingEvidence(forProjectID: pid, evidenceRecords: store.evidenceRecords)
                                if !supporting.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Supporting evidence").font(DashFont.labelMono()).tracking(0.5).foregroundColor(StudentOPSTheme.textSecondary)
                                        ForEach(supporting.prefix(2), id: \.id) { rec in
                                            Button { selectedEvidence = rec } label: {
                                                HStack(spacing: 8) {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(rec.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                                        HStack(spacing: 6) {
                                                            let q = EvidenceQualityEngine.quality(for: rec)
                                                            Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(qualityColor(q.overallLevel)).padding(.horizontal, 6).padding(.vertical, 2).background(qualityColor(q.overallLevel).opacity(0.12)).clipShape(Capsule())
                                                            if rec.artifact != nil { Image(systemName: "link").font(.system(size: 10)).foregroundColor(StudentOPSTheme.textSecondary) }
                                                        }
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                                                }.padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.5)))
                                            }.buttonStyle(.plain).accessibilityLabel(Text("View evidence: \(rec.title)"))
                                        }
                                        if supporting.count > 2 {
                                            Text("+\(supporting.count - 2) more evidence").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                        }
                                    }
                                } else {
                                    Text("No evidence linked yet.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth:.infinity, alignment:.leading)
                                }
                                HStack {
                                    Text("View Project").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark)
                                    Spacer()
                                }
                            }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.5))).shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
                        }.buttonStyle(.plain).accessibilityLabel(Text(scored.project.title))
                    } else {
                        // Stale — subtle unavailable state
                        HStack {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(StudentOPSTheme.warning)
                            Text("Project unavailable").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
                            Text(pid).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        }.padding(12).frame(maxWidth:.infinity, alignment:.leading).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.warning.opacity(0.3))).accessibilityLabel(Text("Project unavailable \(pid)"))
                    }
                }
            }
        }
    }

    // MARK: Achievements

    @ViewBuilder
    private func achievementsSection(portfolio: StudentPortfolio, section: PortfolioSection) -> some View {
        let ids = portfolio.selectedAchievementIDs
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(sectionTitle(section).uppercased()).font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                ForEach(ids, id:\.self) { aid in
                    if let ach = store.achievementRecords[aid] {
                        Button { selectedAchievement = ach } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(ach.type.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.background).clipShape(Capsule())
                                    Spacer()
                                    Text(ach.dateLabel).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                }
                                Text(ach.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).frame(maxWidth:.infinity, alignment:.leading).lineLimit(2)
                                if let desc = ach.description?.trimmingCharacters(in:.whitespacesAndNewlines), !desc.isEmpty {
                                    Text(desc).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(3).frame(maxWidth:.infinity, alignment:.leading)
                                }
                                HStack(spacing: 12) {
                                    if !ach.evidenceIDs.isEmpty { Label("\(ach.evidenceIDs.count) evidence", systemImage: "doc.badge.ellipsis").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                                    if let sids = ach.skillIDs, !sids.isEmpty {
                                        FlowLayout(spacing: 4) {
                                            ForEach(sids.prefix(2), id:\.self) { sid in
                                                let name = SkillCatalog.knownSkills[sid]?.name ?? sid
                                                Text(name).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 6).padding(.vertical, 3).background(StudentOPSTheme.background).clipShape(Capsule())
                                            }
                                        }
                                    }
                                    Spacer()
                                    if let pid = ach.projectID, !pid.isEmpty { Image(systemName: "hammer").foregroundColor(StudentOPSTheme.textSecondary) }
                                    if let rid = ach.roadmapID, !rid.isEmpty { Image(systemName: "point.3.connected.trianglepath.dotted").foregroundColor(StudentOPSTheme.textSecondary) }
                                    if let oid = ach.opportunityID, !oid.isEmpty { Image(systemName: "briefcase").foregroundColor(StudentOPSTheme.textSecondary) }
                                }
                                // Proof — supporting evidence
                                let supporting = PortfolioEvidenceEngine.supportingEvidence(forAchievementID: aid, achievementRecords: store.achievementRecords, evidenceRecords: store.evidenceRecords)
                                if !supporting.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Proof").font(DashFont.labelMono()).tracking(0.5).foregroundColor(StudentOPSTheme.textSecondary)
                                        ForEach(supporting.prefix(2), id: \.id) { rec in
                                            Button { selectedEvidence = rec } label: {
                                                HStack(spacing: 8) {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(rec.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                                        let q = EvidenceQualityEngine.quality(for: rec)
                                                        HStack(spacing: 6) {
                                                            Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(qualityColor(q.overallLevel)).padding(.horizontal, 6).padding(.vertical, 2).background(qualityColor(q.overallLevel).opacity(0.12)).clipShape(Capsule())
                                                            if rec.artifact != nil { Image(systemName: "link").font(.system(size: 10)).foregroundColor(StudentOPSTheme.textSecondary) }
                                                        }
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                                                }.padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.5)))
                                            }.buttonStyle(.plain).accessibilityLabel(Text("View evidence: \(rec.title)"))
                                        }
                                        if supporting.count > 2 {
                                            Text("+\(supporting.count - 2) more evidence").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                        }
                                    }
                                } else {
                                    Text("No supporting evidence linked.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth:.infinity, alignment:.leading)
                                }
                                HStack {
                                    Text("View Achievement").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark)
                                    Spacer()
                                }
                            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.5))).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
                        }.buttonStyle(.plain).accessibilityLabel(Text(ach.title))
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(StudentOPSTheme.warning)
                            Text("Achievement unavailable").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
                            Text(aid).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        }.padding(12).frame(maxWidth:.infinity, alignment:.leading).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel(Text("Achievement unavailable"))
                    }
                }
            }
        }
    }

    // MARK: Evidence

    @ViewBuilder
    private func evidenceSection(portfolio: StudentPortfolio, section: PortfolioSection) -> some View {
        let ids = portfolio.selectedEvidenceIDs
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(sectionTitle(section).uppercased()).font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                ForEach(ids, id:\.self) { eid in
                    if let rec = store.evidenceRecords[eid] {
                        let q = EvidenceQualityEngine.quality(for: rec)
                        Button { selectedEvidence = rec } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(rec.type.displayName).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.background).clipShape(Capsule())
                                    Spacer()
                                    Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(qualityColor(q.overallLevel)).padding(.horizontal, 8).padding(.vertical, 4).background(qualityColor(q.overallLevel).opacity(0.12)).clipShape(Capsule()).accessibilityLabel(Text("Evidence strength \(q.overallLevel.rawValue)"))
                                    if rec.artifact != nil { Image(systemName: "link").font(.system(size: 11)).foregroundColor(StudentOPSTheme.textSecondary).accessibilityLabel(Text("Has artifact")) }
                                }
                                Text(rec.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).frame(maxWidth:.infinity, alignment:.leading).lineLimit(2)
                                if let desc = rec.description?.trimmingCharacters(in:.whitespacesAndNewlines), !desc.isEmpty {
                                    Text(desc).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(3).frame(maxWidth:.infinity, alignment:.leading)
                                }
                                HStack(spacing: 8) {
                                    Label(rec.occurredAt != nil ? dateLabel(rec.occurredAt!) : dateLabel(rec.createdAt), systemImage: "calendar").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                    if let pid = rec.projectID, !pid.isEmpty { Label(pid, systemImage: "hammer").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1) }
                                    if !rec.roadmapID.isEmpty { Label(rec.roadmapID, systemImage: "point.3.connected.trianglepath.dotted").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1) }
                                }
                                if let skills = rec.skillIDs, !skills.isEmpty {
                                    FlowLayout(spacing: 4) {
                                        ForEach(skills.prefix(3), id:\.self) { sid in
                                            let name = SkillCatalog.knownSkills[sid]?.name ?? sid
                                            Text(name).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 6).padding(.vertical, 3).background(StudentOPSTheme.background).clipShape(Capsule())
                                        }
                                    }
                                }
                                // Supports — which selected portfolio items does this evidence support? (derived, factual)
                                let supports = evidenceSupports(for: rec, portfolio: portfolio)
                                if !supports.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Supports").font(DashFont.labelMono()).tracking(0.5).foregroundColor(StudentOPSTheme.textSecondary)
                                        FlowLayout(spacing: 4) {
                                            ForEach(supports, id:\.self) { label in
                                                Text(label).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 6).padding(.vertical, 3).background(StudentOPSTheme.primary.opacity(0.08)).clipShape(Capsule()).overlay(Capsule().stroke(StudentOPSTheme.primary.opacity(0.2)))
                                            }
                                        }
                                    }
                                }
                                HStack {
                                    Text("View Evidence").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark)
                                    Spacer()
                                    if rec.validationPassed != nil { Image(systemName: rec.validationPassed == true ? "checkmark.seal.fill" : "xmark.seal").foregroundColor(rec.validationPassed == true ? StudentOPSTheme.success : StudentOPSTheme.warning).accessibilityLabel(Text(rec.validationPassed == true ? "Validated" : "Validation")) }
                                }
                            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.5))).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
                        }.buttonStyle(.plain).accessibilityLabel(Text(rec.title))
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(StudentOPSTheme.warning)
                            Text("Evidence unavailable").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
                            Text(eid).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        }.padding(12).frame(maxWidth:.infinity, alignment:.leading).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel(Text("Evidence unavailable"))
                    }
                }
            }
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: date)
    }
    private func qualityColor(_ level: EvidenceQualityLevel) -> Color {
        switch level {
        case .strong: return StudentOPSTheme.success
        case .solid: return StudentOPSTheme.primaryDark
        case .basic: return StudentOPSTheme.textSecondary
        }
    }
    private func portfolioQualityColor(_ level: PortfolioQualityLevel) -> Color {
        switch level {
        case .strong: return StudentOPSTheme.success
        case .developing: return StudentOPSTheme.primaryDark
        case .basic: return StudentOPSTheme.warning
        }
    }

    private func evidenceSupports(for rec: EvidenceRecord, portfolio: StudentPortfolio) -> [String] {
        var out: [String] = []
        if let pid = rec.projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty, portfolio.selectedProjectIDs.contains(pid) {
            if let proj = store.scoredProjects.first(where: { $0.project.id == pid })?.project {
                out.append(proj.title)
            } else {
                out.append(pid)
            }
        }
        if !rec.roadmapID.isEmpty, portfolio.selectedRoadmapIDs.contains(rec.roadmapID) {
            if let rm = RoadmapService.roadmap(for: rec.roadmapID) {
                out.append(rm.title)
            } else {
                out.append(rec.roadmapID)
            }
        }
        if !rec.milestoneID.isEmpty, !rec.roadmapID.isEmpty, let rm = RoadmapService.roadmap(for: rec.roadmapID), rm.milestones.contains(where: { $0.id == rec.milestoneID }), portfolio.selectedRoadmapIDs.contains(rec.roadmapID) {
            if let ms = rm.milestones.first(where: { $0.id == rec.milestoneID }) {
                out.append(ms.title)
            }
        }
        for aid in portfolio.selectedAchievementIDs where store.achievementRecords[aid]?.evidenceIDs.contains(rec.id) == true {
            if let ach = store.achievementRecords[aid] {
                out.append(ach.title)
            }
        }
        if let sids = rec.skillIDs {
            for raw in sids {
                let norm = Skill.normalizeID(raw)
                if portfolio.selectedSkillIDs.map({ Skill.normalizeID($0) }).contains(norm) {
                    out.append(SkillCatalog.knownSkills[norm]?.name ?? raw)
                }
            }
        }
        if let oid = rec.opportunityID?.trimmingCharacters(in: .whitespacesAndNewlines), !oid.isEmpty {
            out.append("Opportunity")
        }
        if rec.validationID != nil {
            out.append("Validation")
        }
        // Dedup and limit
        var seen = Set<String>()
        var deduped: [String] = []
        for s in out where !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.insert(t).inserted { deduped.append(t) }
        }
        return Array(deduped.prefix(3))
    }

    // MARK: Roadmaps

    @ViewBuilder
    private func roadmapsSection(portfolio: StudentPortfolio, section: PortfolioSection) -> some View {
        let ids = portfolio.selectedRoadmapIDs
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(sectionTitle(section).uppercased()).font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                ForEach(ids, id:\.self) { rid in
                    if let rm = RoadmapService.roadmap(for: rid) {
                        let scored = store.scoredRoadmaps.first(where: { $0.roadmap.id == rid })
                        let isActive = store.isRoadmapActivated(rid)
                        let completed = scored?.completedMilestones ?? store.completedCount(for: rm)
                        Button {
                            if let s = scored { selectedRoadmap = s } else { selectedRoadmap = ScoredRoadmap(roadmap: rm, matchScore: 0, completedMilestones: completed) }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label(rm.category.rawValue, systemImage: rm.category.icon).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                                    Spacer()
                                    if isActive { Text("Active").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success).padding(.horizontal, 8).padding(.vertical, 4).background(StudentOPSTheme.success.opacity(0.12)).clipShape(Capsule()).accessibilityLabel(Text("Active")) }
                                    else if completed >= rm.milestones.count { Text("Completed").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success) }
                                    else { Text("\(completed)/\(rm.milestones.count)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                                }
                                Text(rm.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary).frame(maxWidth:.infinity, alignment:.leading).lineLimit(2)
                                Text(rm.goal).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2).frame(maxWidth:.infinity, alignment:.leading)
                                GeometryReader { proxy in
                                    Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                                        Capsule().fill(isActive ? StudentOPSTheme.primary : StudentOPSTheme.success).frame(width: proxy.size.width * CGFloat(completed) / CGFloat(max(1, rm.milestones.count)))
                                    }
                                }.frame(height: 6).accessibilityLabel(Text("Progress \(completed) of \(rm.milestones.count)"))
                                if let s = scored, let current = s.currentMilestone {
                                    HStack {
                                        Text("Current: \(current.title)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                                        Spacer()
                                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark)
                                    }
                                } else if completed >= rm.milestones.count {
                                    Label("View Roadmap", systemImage: "arrow.right").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                                }
                                // Evidence of progress (derived, not auto-linked)
                                let supporting = PortfolioEvidenceEngine.supportingEvidence(forRoadmapID: rid, evidenceRecords: store.evidenceRecords)
                                if !supporting.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Evidence of progress").font(DashFont.labelMono()).tracking(0.5).foregroundColor(StudentOPSTheme.textSecondary)
                                        ForEach(supporting.prefix(2), id: \.id) { rec in
                                            Button { selectedEvidence = rec } label: {
                                                HStack(spacing: 8) {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(rec.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                                        HStack(spacing: 6) {
                                                            let q = EvidenceQualityEngine.quality(for: rec)
                                                            Text(q.overallLevel.rawValue).font(DashFont.labelMono()).foregroundColor(qualityColor(q.overallLevel)).padding(.horizontal, 6).padding(.vertical, 2).background(qualityColor(q.overallLevel).opacity(0.12)).clipShape(Capsule())
                                                            if !rec.milestoneID.isEmpty { Text(rec.milestoneID).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1) }
                                                        }
                                                    }
                                                    Spacer()
                                                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
                                                }.padding(10).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.5)))
                                            }.buttonStyle(.plain).accessibilityLabel(Text("View evidence: \(rec.title)"))
                                        }
                                        if supporting.count > 2 {
                                            Text("+\(supporting.count - 2) more evidence").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                        }
                                    }
                                } else {
                                    Text("No evidence linked yet.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).frame(maxWidth:.infinity, alignment:.leading)
                                }
                            }.padding(14).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.5))).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
                        }.buttonStyle(.plain).accessibilityLabel(Text(rm.title))
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(StudentOPSTheme.warning)
                            Text("Roadmap unavailable").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
                            Text(rid).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                        }.padding(12).frame(maxWidth:.infinity, alignment:.leading).background(StudentOPSTheme.warning.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel(Text("Roadmap unavailable"))
                    }
                }
            }
        }
    }
}
