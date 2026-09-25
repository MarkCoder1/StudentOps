import SwiftUI

// MARK: - Integrity Summary (Builder concise)

struct PortfolioGraphIntegritySummaryView: View {
    let report: PortfolioGraphIntegrityReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PORTFOLIO INTEGRITY").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    Text(report.isValid ? "Portfolio is structurally consistent" : "\(report.issueCount) issue\(report.issueCount==1 ? "" : "s") found")
                        .font(DashFont.bodySm()).foregroundColor(report.isValid ? StudentOPSTheme.success : StudentOPSTheme.warning)
                }
                Spacer()
                if report.isValid {
                    Label("Valid", systemImage: "checkmark.seal.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success).padding(.horizontal, 10).padding(.vertical, 6).background(StudentOPSTheme.success.opacity(0.12)).clipShape(Capsule())
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        if report.errorCount > 0 { Text("\(report.errorCount) error\(report.errorCount==1 ? "" : "s")").font(DashFont.labelMono()).foregroundColor(.red) }
                        if report.warningCount > 0 { Text("\(report.warningCount) warning\(report.warningCount==1 ? "" : "s")").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning) }
                        if report.infoCount > 0 { Text("\(report.infoCount) info").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary) }
                    }
                }
            }

            if report.isValid {
                Label("No structural issues. Selected items reference existing canonical data.", systemImage: "checkmark.circle").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.issues.prefix(2), id: \.id) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: icon(for: issue.severity)).foregroundColor(color(for: issue.severity)).font(.system(size: 11, weight: .bold)).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(2)
                                Text(issue.explanation).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                            }
                        }
                    }
                    if report.issues.count > 2 {
                        Text("+\(report.issues.count - 2) more").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                }
            }

            NavigationLink(destination: PortfolioGraphIntegrityDetailView(report: report)) {
                Label("View details", systemImage: "shield.lefthalf.filled").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).frame(maxWidth:.infinity).padding(.vertical, 10).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(report.isValid ? StudentOPSTheme.success.opacity(0.06) : StudentOPSTheme.warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(report.isValid ? StudentOPSTheme.success.opacity(0.3) : StudentOPSTheme.warning.opacity(0.3)))
    }

    private func icon(for severity: PortfolioGraphIntegritySeverity) -> String {
        switch severity {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    private func color(for severity: PortfolioGraphIntegritySeverity) -> Color {
        switch severity {
        case .error: return .red
        case .warning: return StudentOPSTheme.warning
        case .info: return StudentOPSTheme.textSecondary
        }
    }
}

// MARK: - Integrity Detail

struct PortfolioGraphIntegrityDetailView: View {
    let report: PortfolioGraphIntegrityReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Portfolio Integrity").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(StudentOPSTheme.textPrimary)
                        Spacer()
                        Text(report.isValid ? "Valid" : "Issues Found").font(DashFont.labelMono()).foregroundColor(report.isValid ? StudentOPSTheme.success : StudentOPSTheme.warning).padding(.horizontal, 10).padding(.vertical, 6).background((report.isValid ? StudentOPSTheme.success : StudentOPSTheme.warning).opacity(0.12)).clipShape(Capsule())
                    }
                    HStack(spacing: 12) {
                        Label("\(report.errorCount) errors", systemImage: "xmark.octagon.fill").font(DashFont.labelMono()).foregroundColor(.red)
                        Label("\(report.warningCount) warnings", systemImage: "exclamationmark.triangle.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
                        Label("\(report.infoCount) info", systemImage: "info.circle.fill").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    }
                    Text("Checked \(report.checkedProjectIDs.count) projects, \(report.checkedAchievementIDs.count) achievements, \(report.checkedEvidenceIDs.count) evidence, \(report.checkedSkillIDs.count) skills, \(report.checkedRoadmapIDs.count) roadmaps.")
                        .font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Checked at \(Self.dateString(report.checkedAt))").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("Portfolio integrity checks structural consistency with canonical data. Warnings and info do not make the portfolio invalid.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.4)))

                if report.issues.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 32)).foregroundColor(StudentOPSTheme.success)
                        Text("No issues found").font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                        Text("All selected items reference existing canonical data. Your portfolio structure is valid.").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).multilineTextAlignment(.center)
                    }.frame(maxWidth:.infinity).padding(20).background(StudentOPSTheme.success.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ISSUES (\(report.issueCount))").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                        ForEach(report.issues) { issue in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label(issue.severity.rawValue.capitalized, systemImage: icon(for: issue.severity)).font(DashFont.labelMono()).foregroundColor(color(for: issue.severity)).padding(.horizontal, 6).padding(.vertical, 3).background(color(for: issue.severity).opacity(0.12)).clipShape(Capsule())
                                    Text(issue.type.rawValue).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                                    Spacer()
                                    if issue.isRepairable {
                                        Text("Repairable").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 6).padding(.vertical, 3).background(StudentOPSTheme.primary.opacity(0.12)).clipShape(Capsule())
                                    }
                                }
                                Text(issue.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                                Text(issue.explanation).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
                                if let tid = issue.targetID {
                                    HStack {
                                        Text("Target:").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                        Text(tid).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                    }
                                }
                                if let rid = issue.relatedID {
                                    HStack {
                                        Text("Related:").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                        Text(rid).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                                    }
                                }
                                HStack {
                                    Label(issue.destination, systemImage: "arrow.right.circle").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                    Spacer()
                                    if issue.isRepairable {
                                        Text("Manual fix in \(issue.destination)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.primaryDark)
                                    } else {
                                        Text("Manual review").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                    }
                                }
                                Text("ID: \(issue.id)").font(.system(size: 8, weight: .regular, design: .monospaced)).foregroundColor(StudentOPSTheme.textSecondary.opacity(0.6)).lineLimit(1)
                            }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(color(for: issue.severity).opacity(0.3)))
                        }
                    }
                }

                Text("This reflects structural consistency, not quality or completeness. A portfolio can be valid but low completeness, or high quality but structurally inconsistent are different concepts.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).multilineTextAlignment(.center).frame(maxWidth:.infinity).padding(.top, 8)
            }.padding(16)
        }
        .background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("Integrity Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func icon(for severity: PortfolioGraphIntegritySeverity) -> String {
        switch severity {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    private func color(for severity: PortfolioGraphIntegritySeverity) -> Color {
        switch severity {
        case .error: return .red
        case .warning: return StudentOPSTheme.warning
        case .info: return StudentOPSTheme.textSecondary
        }
    }
    static func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }
}
