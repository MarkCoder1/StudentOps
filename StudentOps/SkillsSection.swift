import SwiftUI

struct SkillsSection: View {
    let profile: StudentProfile
    @EnvironmentObject var store: AppDataStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Strengths (student-entered)
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR STRENGTHS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                if enteredSkills.isEmpty {
                    Text("Add strengths or skills you bring to your work.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(enteredSkills, id: \.self) { skill in
                            Text(skill).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textPrimary).padding(.horizontal, 10).padding(.vertical, 6).background(StudentOPSTheme.surface).overlay(RoundedRectangle(cornerRadius: 8).stroke(StudentOPSTheme.border))
                        }
                    }
                }
            }

            // Demonstrated skills (authoritative via SkillGapEngine)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DEMONSTRATED SKILLS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    Spacer()
                    Text("\(demonstratedSkills.count) demonstrated").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
                }
                Text("Skills you have demonstrated through completed milestones and evidence. A skill mentioned in evidence alone does not count until your activity shows it.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                if demonstratedSkills.isEmpty {
                    Text("Complete roadmap milestones to demonstrate skills. Your progress builds this section.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ForEach(Array(demonstratedSkills.enumerated()), id: \.element.id) { index, skill in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(skill.name).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                                Spacer()
                                Text(categoryLabel(for: skill)).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                            // Deterministic visual: demonstrated skills show solid fill, not artificial progress %
                            Capsule().fill(StudentOPSTheme.success).frame(height: 5).opacity(0.9)
                        }
                        if index < demonstratedSkills.count - 1 { Divider().padding(.vertical, 2) }
                    }
                }
            }

            // Developing (gap) hint — optional, shows next skills from active roadmaps without implying mastery
            if !developingSkills.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DEVELOPING NEXT (ACTIVE ROADMAPS)").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    FlowLayout(spacing: 6) {
                        ForEach(developingSkills.prefix(6), id: \.self) { name in
                            Text(name).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 8).padding(.vertical, 5).background(StudentOPSTheme.background).overlay(RoundedRectangle(cornerRadius: 6).stroke(StudentOPSTheme.border))
                        }
                    }
                }
            }
        }
    }

    private var enteredSkills: [String] { Array(Set(profile.strengths + profile.customSkills)).sorted() }

    private var demonstratedSkills: [Skill] {
        let catalog = RoadmapService.allRoadmaps
        let ids = SkillGapEngine.demonstratedSkillIDs(profile: profile, roadmapProgress: store.roadmapProgress, catalog: catalog, evidenceRecords: store.evidenceRecords)
        return ids.sorted().compactMap { SkillCatalog.knownSkills[$0] ?? Skill(id: $0, name: $0) }
    }

    private var developingSkills: [String] {
        // Next gap skills from active roadmaps (deterministic, up to 6)
        let gaps = store.activeSkillGapReports.flatMap(\.gaps).filter { $0.status == .developing }
        let names = gaps.map(\.skillName)
        var seen = Set<String>()
        var out: [String] = []
        for n in names where !seen.contains(n) {
            seen.insert(n); out.append(n)
        }
        return out
    }

    private func categoryLabel(for skill: Skill) -> String {
        if let cat = skill.category { return cat }
        return "Demonstrated"
    }
}
