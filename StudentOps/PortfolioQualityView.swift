import SwiftUI

// MARK: - Quality Summary (Builder concise)

struct PortfolioQualitySummaryView: View {
    let result: PortfolioQualityResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PORTFOLIO CHECK").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    Text("How complete and well-supported your portfolio is").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(result.percent)%").font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundColor(levelColor)
                    Text(result.overallLevel.displayName).font(DashFont.labelMono()).foregroundColor(levelColor)
                }.padding(.horizontal, 12).padding(.vertical, 8).background(levelColor.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(result.summary).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)

            GeometryReader { proxy in
                Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                    Capsule().fill(levelColor).frame(width: proxy.size.width * CGFloat(result.percent) / 100)
                }
            }.frame(height: 6).accessibilityLabel(Text("Portfolio quality \(result.percent) percent, \(result.overallLevel.displayName)"))

            if !result.strengths.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Strong").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.success)
                    ForEach(result.strengths.prefix(2), id: \.self) { s in
                        Label(s, systemImage: "checkmark.circle.fill").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                    }
                }
            }

            if !result.improvements.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Improve").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.warning)
                    ForEach(result.improvements.prefix(2), id: \.self) { imp in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: priorityIcon(imp.priority)).foregroundColor(priorityColor(imp.priority)).font(.system(size: 11, weight: .bold)).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(imp.title).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(2)
                                Text(imp.explanation).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                            }
                        }
                    }
                }
            }

            NavigationLink(destination: PortfolioQualityDetailView(result: result)) {
                Label("View details", systemImage: "chart.bar").font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).frame(maxWidth:.infinity).padding(.vertical, 10).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.5)))
        .shadow(color: StudentOPSTheme.shadow, radius: 4, y: 2)
    }

    private var levelColor: Color {
        switch result.overallLevel {
        case .strong: return StudentOPSTheme.success
        case .developing: return StudentOPSTheme.primaryDark
        case .basic: return StudentOPSTheme.warning
        }
    }
    private func priorityColor(_ p: PortfolioImprovementPriority) -> Color {
        switch p {
        case .high: return StudentOPSTheme.warning
        case .medium: return StudentOPSTheme.primaryDark
        case .low: return StudentOPSTheme.textSecondary
        }
    }
    private func priorityIcon(_ p: PortfolioImprovementPriority) -> String {
        switch p {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "arrow.up.circle.fill"
        case .low: return "arrow.right.circle"
        }
    }
}

// MARK: - Quality Detail

struct PortfolioQualityDetailView: View {
    let result: PortfolioQualityResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Portfolio Quality").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(StudentOPSTheme.textPrimary)
                    HStack(spacing: 12) {
                        VStack {
                            Text("\(result.overallScore)").font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundColor(levelColor)
                            Text("of \(result.maxScore)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.overallLevel.displayName).font(DashFont.titleMd()).foregroundColor(levelColor)
                            Text("\(result.percent)% — \(result.summary)").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(3)
                        }
                        Spacer()
                    }
                    GeometryReader { proxy in
                        Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                            Capsule().fill(levelColor).frame(width: proxy.size.width * CGFloat(result.percent) / 100)
                        }
                    }.frame(height: 8)
                    Text("Based on portfolio sections, selected work, evidence support, documentation, skills, and roadmap connections.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }.padding(16).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.4)))

                // Dimensions
                VStack(alignment: .leading, spacing: 12) {
                    Text("DIMENSIONS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                    ForEach(result.dimensions) { dim in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(dim.title).font(DashFont.labelMd()).foregroundColor(dim.relevant ? StudentOPSTheme.textPrimary : StudentOPSTheme.textSecondary)
                                Spacer()
                                Text("\(dim.score)/\(dim.maxScore)").font(DashFont.labelMono()).foregroundColor(dim.achieved ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
                                if dim.achieved && dim.relevant { Image(systemName: "checkmark.circle.fill").foregroundColor(StudentOPSTheme.success).font(.system(size: 12)) }
                            }
                            if dim.relevant {
                                GeometryReader { proxy in
                                    Capsule().fill(StudentOPSTheme.border).overlay(alignment: .leading) {
                                        Capsule().fill(dim.achieved ? StudentOPSTheme.success : StudentOPSTheme.primary).frame(width: proxy.size.width * CGFloat(dim.score) / CGFloat(max(1, dim.maxScore)))
                                    }
                                }.frame(height: 5)
                                Text(dim.description).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                                if let imp = dim.improvement {
                                    Text(imp).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.warning).lineLimit(2)
                                }
                            } else {
                                Text("Not relevant (section disabled)").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                        }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(dim.achieved ? StudentOPSTheme.success.opacity(0.3) : StudentOPSTheme.border.opacity(0.4)))
                    }
                }

                if !result.strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STRENGTHS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.success)
                        ForEach(result.strengths, id:\.self) { s in
                            Label(s, systemImage: "checkmark.circle.fill").font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textPrimary)
                        }
                    }.padding(14).background(StudentOPSTheme.success.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !result.improvements.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("IMPROVEMENTS").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.textSecondary)
                        ForEach(result.improvements) { imp in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label(imp.priority.rawValue, systemImage: priorityIcon(imp.priority)).font(DashFont.labelMono()).foregroundColor(priorityColor(imp.priority)).padding(.horizontal, 6).padding(.vertical, 3).background(priorityColor(imp.priority).opacity(0.12)).clipShape(Capsule())
                                    Spacer()
                                    Text(imp.destination).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary)
                                }
                                Text(imp.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                                Text(imp.explanation).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(3)
                                if !imp.relatedItemIDs.isEmpty {
                                    FlowLayout(spacing: 4) {
                                        ForEach(imp.relatedItemIDs.prefix(3), id:\.self) { id in
                                            Text(id).font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).padding(.horizontal, 6).padding(.vertical, 3).background(StudentOPSTheme.background).clipShape(Capsule()).overlay(Capsule().stroke(StudentOPSTheme.border))
                                        }
                                    }
                                }
                            }.padding(12).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
                        }
                    }
                }

                Text("This reflects portfolio construction, not your worth as a student.").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.textSecondary).multilineTextAlignment(.center).frame(maxWidth:.infinity).padding(.top, 8)
            }.padding(16)
        }
        .background(StudentOPSTheme.background.ignoresSafeArea())
        .navigationTitle("Portfolio Check")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var levelColor: Color {
        switch result.overallLevel {
        case .strong: return StudentOPSTheme.success
        case .developing: return StudentOPSTheme.primaryDark
        case .basic: return StudentOPSTheme.warning
        }
    }
    private func priorityColor(_ p: PortfolioImprovementPriority) -> Color {
        switch p {
        case .high: return StudentOPSTheme.warning
        case .medium: return StudentOPSTheme.primaryDark
        case .low: return StudentOPSTheme.textSecondary
        }
    }
    private func priorityIcon(_ p: PortfolioImprovementPriority) -> String {
        switch p {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "arrow.up.circle.fill"
        case .low: return "arrow.right.circle"
        }
    }
}


