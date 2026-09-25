import SwiftUI
import StoreKit
import RevenueCat

// MARK: - Subscription Status Section (Phase 4 UX)
// Polished subscription section for existing Profile/settings area (Progress).
// Shows Free vs Pro dynamically, uses only RevenueCat CustomerInfo, no hardcoded prices/dates.

struct SubscriptionStatusView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var showPaywall = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var isRestoring = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: revenueCatManager.isPro ? "crown.fill" : "crown")
                    .foregroundColor(revenueCatManager.isPro ? StudentOPSTheme.primaryDark : StudentOPSTheme.textSecondary)
                    .font(.system(size: 16, weight: .semibold))
                Text("Student OPS Pro")
                    .font(DashFont.titleMd())
                    .foregroundColor(StudentOPSTheme.textPrimary)
                Spacer()
                ProBadge(label: revenueCatManager.isPro ? "PRO" : "FREE")
                    .opacity(revenueCatManager.isPro ? 1 : 0.7)
            }

            // Status
            HStack(spacing: 6) {
                Circle()
                    .fill(revenueCatManager.isPro ? StudentOPSTheme.success : StudentOPSTheme.textSecondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(revenueCatManager.isPro ? "Pro" : "Free Plan")
                    .font(DashFont.labelMono())
                    .foregroundColor(revenueCatManager.isPro ? StudentOPSTheme.success : StudentOPSTheme.textSecondary)
                Spacer()
                if revenueCatManager.isLoading {
                    ProgressView().scaleEffect(0.8)
                    Text("Updating…").font(DashFont.captionMono()).foregroundColor(StudentOPSTheme.textSecondary)
                }
            }

            // Description — honest, not marketing heavy
            Text(revenueCatManager.isPro
                 ? "Your personalized Student OPS intelligence is unlocked."
                 : "Unlock personalized intelligence across your Student OPS.")
                .font(DashFont.bodySm())
                .foregroundColor(StudentOPSTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // CTA + Restore + Manage
            VStack(spacing: 8) {
                if revenueCatManager.isPro {
                    // Pro: Manage + Restore
                    Button {
                        Task { await openManageSubscriptions() }
                    } label: {
                        Label("Manage Subscription", systemImage: "gearshape")
                            .font(DashFont.labelMd())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(StudentOPSTheme.primaryDark)
                    .accessibilityLabel("Manage subscription")

                    Button {
                        Task { await performRestore() }
                    } label: {
                        HStack {
                            if isRestoring { ProgressView().scaleEffect(0.8) }
                            Text(isRestoring ? "Restoring purchases…" : "Restore Purchases")
                        }
                        .font(DashFont.labelMd())
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRestoring || revenueCatManager.isLoading)
                } else {
                    // Free: Explore Pro + Restore
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Text("Explore Pro").font(DashFont.labelMd())
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12).padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .background(StudentOPSTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Explore Pro subscription")

                    Button {
                        Task { await performRestore() }
                    } label: {
                        HStack {
                            if isRestoring { ProgressView().scaleEffect(0.8) }
                            Text(isRestoring ? "Restoring purchases…" : "Restore Purchases")
                        }
                        .font(DashFont.labelMd())
                        .foregroundColor(StudentOPSTheme.primaryDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(StudentOPSTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudentOPSTheme.border.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRestoring || revenueCatManager.isLoading)
                }

                if let error = revenueCatManager.error, !isRestoring {
                    Text(error.localizedDescription)
                        .font(DashFont.captionMono())
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(StudentOPSTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(StudentOPSTheme.border.opacity(0.4)))
        .shadow(color: StudentOPSTheme.shadow.opacity(0.06), radius: 6, y: 2)
        .sheet(isPresented: $showPaywall) {
            PaywallHostView().environmentObject(revenueCatManager)
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreMessage)
        }
        // Handle cancellation gracefully: no error-looking screen, just return
        .onChange(of: revenueCatManager.isPro) { _, _ in
            // If Pro becomes true after restore/purchase, the UI updates immediately
        }
    }

    @MainActor
    private func performRestore() async {
        guard !isRestoring else { return }
        isRestoring = true
        restoreMessage = ""
        // Use existing manager - do NOT create custom restore
        // Call async variant if available, otherwise completion handler
        // We use the callback version and observe result via manager state
        let wasProBefore = revenueCatManager.isPro
        revenueCatManager.restorePurchases()
        // Wait briefly for manager to update (CustomerInfo stream or callback)
        // Poll for up to 2 seconds for isLoading to become false
        var waited: Double = 0
        while revenueCatManager.isLoading && waited < 2.0 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            waited += 0.1
        }
        // Extra small delay for stream propagation
        try? await Task.sleep(nanoseconds: 300_000_000)
        isRestoring = false

        // Honest feedback based on actual entitlement state (Test Store may just return current CustomerInfo)
        if let error = revenueCatManager.error {
            restoreMessage = error.localizedDescription
            showRestoreAlert = true
            return
        }
        if revenueCatManager.isPro {
            restoreMessage = wasProBefore
                ? "Your Pro subscription is active."
                : "Your Pro subscription has been restored."
        } else {
            restoreMessage = "No active Pro subscription was found."
        }
        showRestoreAlert = true
    }

    @MainActor
    private func openManageSubscriptions() async {
        // Use official Apple flow if available, otherwise fallback to App Store URL
        if #available(iOS 15.0, *) {
            // Try AppStore.showManageSubscriptions (iOS 15+)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                do {
                    try await AppStore.showManageSubscriptions(in: windowScene)
                    return
                } catch {
                    // Fallback to URL
                    print("[Subscription] AppStore.showManageSubscriptions failed: \(error)")
                }
            }
        }
        // Fallback: open App Store subscriptions URL
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            await UIApplication.shared.open(url)
        }
    }
}
