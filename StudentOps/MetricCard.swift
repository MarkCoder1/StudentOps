import SwiftUI

struct MetricCard: View {
    let metric: ProgressMetric
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.label.uppercased()).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
            Text(metric.value).font(DashFont.headlineSm()).fontWeight(.bold).foregroundColor(StudentOPSTheme.textPrimary)
            trendView
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: StudentOPSTheme.radiusCard).stroke(StudentOPSTheme.border.opacity(0.4)))
    }
    @ViewBuilder private var trendView: some View {
        switch metric.trendStyle {
        case .positiveGreen: HStack(spacing: 3) { Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold)); Text(metric.trendText) }.font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.success)
        case .starred: HStack(spacing: 3) { Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(StudentOPSTheme.warning); Text(metric.trendText).foregroundColor(StudentOPSTheme.warning) }.font(DashFont.captionMono())
        case .plain: Text(metric.trendText).font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary).lineLimit(1)
        }
    }
}
