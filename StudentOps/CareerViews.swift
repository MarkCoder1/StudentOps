import SwiftUI

// MARK: - Career Direction (Home)

struct CareerDirectionSection: View {
    @EnvironmentObject var store: AppDataStore
    @State private var selectedCareer: Career?

    private var ranked: [RankedCareer] { store.rankedCareers }
    private var top: RankedCareer? { ranked.first }
    private var hasCareerGoal: Bool { !store.profile.careers.isEmpty || !store.profile.fields.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CAREER DIRECTION").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                if hasCareerGoal, let _ = top {
                    Text("See all").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark)
                }
            }
            if !hasCareerGoal {
                // Empty career state
                VStack(alignment: .leading, spacing: 10) {
                    Text("EXPLORE CAREER PATHS").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text("Add a career goal to see how your skills, projects, and interests connect.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    NavigationLink(destination: ProfileEditView(profile: $store.profile).environmentObject(store)) {
                        Label("Add career goal", systemImage: "plus.circle.fill").font(DashFont.labelMd()).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8).background(StudentOPSTheme.primary).clipShape(Capsule())
                    }.buttonStyle(.plain)
                    Text("Demo career data — catalog, not live labor-market").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
            } else if let top = top {
                // Selected/current career
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(top.career.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Spacer()
                        Text("\(top.score)%").font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundColor(top.score >= 70 ? StudentOPSTheme.success : StudentOPSTheme.primaryDark)
                    }
                    HStack {
                        Text("\(top.score)% alignment").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        Spacer()
                        Text(top.career.status == .catalog ? "Catalog data" : "Verified").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    if let reason = top.alignment.reasons.first {
                        HStack(alignment: .top, spacing: 6) { Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.success); Text(reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                    // Next skills
                    let next = store.nextSkills(careerID: top.career.id, limit: 3)
                    if !next.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Next skills to develop").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            ForEach(next, id: \.skillID) { rec in
                                HStack(spacing: 6) {
                                    Circle().fill(rec.hasPrerequisiteMissing ? StudentOPSTheme.warning : StudentOPSTheme.primaryDark).frame(width: 6, height: 6)
                                    Text(rec.skillName).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                                    if rec.hasPrerequisiteMissing { Text("needs prereq").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning) }
                                }
                            }
                        }.padding(8).background(StudentOPSTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button { selectedCareer = top.career } label: {
                        HStack { Text("View career details"); Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)) }.font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).frame(maxWidth: .infinity).padding(.vertical, 8).background(StudentOPSTheme.primary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("\(top.career.title), \(top.score) percent career alignment"))
            } else {
                Text("No career matches yet — add interests and skills.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            }
        }
        .sheet(item: $selectedCareer) { career in NavigationStack { CareerDetailView(career: career).environmentObject(store) } }
    }
}

struct CareerMatchesSection: View {
    @EnvironmentObject var store: AppDataStore
    @State private var selectedCareer: Career?

    private var ranked: [RankedCareer] { Array(store.rankedCareers.prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CAREER MATCHES").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("Career alignment").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            if ranked.isEmpty || ranked.allSatisfy({ $0.score == 0 }) {
                Text("Add career goals, fields, and interests to see matches.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(ranked, id: \.career.id) { ranked in
                    Button { selectedCareer = ranked.career } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(ranked.career.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary)
                                Spacer()
                                Text("\(ranked.score)%").font(DashFont.labelMono()).foregroundColor(ranked.score >= 70 ? StudentOPSTheme.success : StudentOPSTheme.primaryDark)
                            }
                            if let reason = ranked.alignment.reasons.first {
                                Text(reason).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                            }
                            if let topSkill = ranked.alignment.missingSkills.first {
                                Text("Top skill: \(SkillCatalog.knownSkills[topSkill]?.name ?? topSkill)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                            if let roadmapID = ranked.alignment.roadmapConnections.first, let rm = RoadmapService.allRoadmaps.first(where: { $0.id == roadmapID }) {
                                Label("Connected to \(rm.title)", systemImage: "map").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                            }
                        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.3)))
                    }.buttonStyle(.plain).accessibilityLabel(Text("\(ranked.career.title), \(ranked.score) percent alignment"))
                }
            }
            Text("Demo career data — catalog, not live labor-market").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
        }
        .sheet(item: $selectedCareer) { career in NavigationStack { CareerDetailView(career: career).environmentObject(store) } }
    }
}

// MARK: - Next Skills Compact

struct NextSkillsCompactSection: View {
    @EnvironmentObject var store: AppDataStore
    @State private var selectedSkill: Skill?

    private var next: [NextSkillRecommendation] { store.nextSkills(limit: 3) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NEXT SKILLS TO DEVELOP").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                Spacer()
                Text("Via SkillIntelligenceEngine").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
            }
            if next.isEmpty {
                Text("No next skills — add a career or complete roadmaps to see recommendations.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                ForEach(next, id: \.skillID) { rec in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(rec.skillName).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                            Spacer()
                            if rec.hasPrerequisiteMissing {
                                Label("Needs prereq", systemImage: "exclamationmark.triangle.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
                            }
                        }
                        ForEach(rec.reasons.prefix(2), id: \.self) { r in
                            HStack(alignment: .top, spacing: 6) { Image(systemName: "arrow.right.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.primaryDark).frame(width: 14, height: 14); Text(r).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary) }
                        }
                        if !rec.prerequisites.isEmpty {
                            Text("Prerequisites: \(rec.prerequisites.joined(separator: ", "))").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                    }.padding(10).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
                        .onTapGesture { selectedSkill = SkillCatalog.knownSkills[rec.skillID] ?? Skill(id: rec.skillID, name: rec.skillName) }
                }
            }
        }
        .sheet(item: $selectedSkill) { skill in SkillDetailView(skill: skill).environmentObject(store) }
    }
}
