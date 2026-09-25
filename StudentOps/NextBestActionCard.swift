import SwiftUI

struct NextBestActionCard: View {
    let action: NextBestAction
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(StudentOPSTheme.primary).frame(width: 5)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(badgeText).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.primaryDark).padding(.horizontal, 8).padding(.vertical, 3).background(StudentOPSTheme.primary.opacity(0.1)).clipShape(Capsule())
                    Spacer()
                    HStack(spacing: 4) {
                        if let time = action.estimatedTime {
                            Image(systemName: "clock").font(.system(size: 12))
                            Text(time).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textSecondary)
                        } else if let dl = action.deadline {
                            Image(systemName: "calendar").font(.system(size: 12))
                            Text(dl).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.warning)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3).background(StudentOPSTheme.surface).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title).font(DashFont.titleMd()).foregroundColor(StudentOPSTheme.textPrimary)
                    Text(action.subtitle).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                    if let detail = action.detail, !detail.isEmpty {
                        Text(detail).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(2)
                    }
                }
                if !action.signals.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(action.signals.prefix(3), id: \.self) { sig in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.success).frame(width: 14)
                                Text(sig).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary)
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    Text("\(action.priority.rawValue) priority").font(DashFont.labelMono()).foregroundColor(priorityColor)
                    Spacer()
                    Button(action: onTap) {
                        HStack(spacing: 6) {
                            Text(ctaLabel)
                            Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold))
                        }
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.textOnPrimary)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(StudentOPSTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: StudentOPSTheme.shadow, radius: 6, y: 2)
    }

    private var badgeText: String {
        switch action.type {
        case .roadmapAction: return "NEXT STEP"
        case .opportunity: return "OPPORTUNITY"
        case .savedOpportunity: return "SAVED OPPORTUNITY"
        case .projectAction: return "PROJECT"
        case .startRoadmap: return "START PATH"
        }
    }

    private var ctaLabel: String {
        switch action.type {
        case .roadmapAction: return "Continue"
        case .opportunity, .savedOpportunity: return "View"
        case .projectAction: return "Open"
        case .startRoadmap: return "Start"
        }
    }

    private var priorityColor: Color {
        switch action.priority {
        case .high: return StudentOPSTheme.success
        case .medium: return StudentOPSTheme.primaryDark
        case .low: return StudentOPSTheme.textSecondary
        }
    }
}

struct NextBestActionHeroCard: View {
    let action: NextBestAction
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("NEXT ACTION", systemImage: "bolt.fill").font(DashFont.labelMono()).tracking(0.8).foregroundColor(StudentOPSTheme.lime)
                Spacer()
                Text("\(action.priority.rawValue) priority").font(DashFont.labelMono()).foregroundColor(action.priority == .high ? StudentOPSTheme.success : StudentOPSTheme.lime).padding(.horizontal, 8).padding(.vertical, 4).background((action.priority == .high ? StudentOPSTheme.success : StudentOPSTheme.primary).opacity(0.15)).clipShape(Capsule())
            }
            Text(action.title).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(.white).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            if let detail = action.detail, !detail.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Why this matters").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.lime.opacity(0.9))
                    Text(detail).font(DashFont.bodySm()).foregroundColor(.white.opacity(0.85)).lineLimit(3)
                }
            }
            if !action.subtitle.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Related").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.lime.opacity(0.9))
                    Text(action.subtitle).font(DashFont.bodySm()).foregroundColor(.white.opacity(0.85)).lineLimit(2)
                }
            }
            if !action.signals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Progress").font(DashFont.labelMono()).foregroundColor(StudentOPSTheme.lime.opacity(0.9))
                    ForEach(action.signals.prefix(2), id: \.self) { sig in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(StudentOPSTheme.lime)
                            Text(sig).font(DashFont.bodySm()).foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Spacer()
                    Text(ctaLabel).font(DashFont.labelMd()).fontWeight(.bold)
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold))
                    Spacer()
                }.foregroundColor(StudentOPSTheme.textPrimary).padding(.vertical, 14).background(StudentOPSTheme.lime).clipShape(RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
            .accessibilityLabel(Text("Continue: \(action.title)"))
        }
        .padding(18)
        .background(Color(hex: "0F172A"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private var ctaLabel: String {
        switch action.type {
        case .roadmapAction: return "Continue"
        case .opportunity, .savedOpportunity: return "View"
        case .projectAction: return "Open"
        case .startRoadmap: return "Start"
        }
    }
}

struct NextBestActionSecondaryRow: View {
    let action: NextBestAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(StudentOPSTheme.primary.opacity(0.15)).frame(width: 28, height: 28).overlay(Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(StudentOPSTheme.primaryDark))
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title).font(DashFont.labelMd()).foregroundColor(StudentOPSTheme.textPrimary).lineLimit(1)
                    Text(action.subtitle).font(DashFont.bodySm()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(StudentOPSTheme.textSecondary)
            }
            .padding(12)
            .background(StudentOPSTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(StudentOPSTheme.border.opacity(0.4)))
        }.buttonStyle(.plain)
    }

    private var icon: String {
        switch action.type {
        case .roadmapAction: return "signpost.right"
        case .opportunity, .savedOpportunity: return "star"
        case .projectAction: return "hammer"
        case .startRoadmap: return "point.3.connected.trianglepath.dotted"
        }
    }
}
