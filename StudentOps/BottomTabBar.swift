import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: DashboardTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases) { tab in
                let isActive = tab == selectedTab
                Button { selectedTab = tab } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon).font(.system(size: 20, weight: isActive ? .semibold : .regular))
                        Text(tab.title).font(DashFont.labelMd())
                    }
                    .foregroundColor(isActive ? StudentOPSTheme.primary : StudentOPSTheme.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4).padding(.top, 8).padding(.bottom, 4).background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundColor(StudentOPSTheme.shadow), alignment: .top)
    }
}
