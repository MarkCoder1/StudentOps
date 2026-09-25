import SwiftUI
import RevenueCat
import RevenueCatUI

// MARK: - RevenueCat IDs (Phase 2 contract)
// Keep these exact — do not "correct" the typo in yearly_susbcription.
enum RevenueCatConstants {
    static let entitlementID = "studentops_pro" // from RevenueCatManager.entitlementID
    static let offeringID = "sale"
    static let monthlyProductID = "monthly_subscription"
    static let annualProductID = "yearly_susbcription"
}

// MARK: - Paywall Presentation Layer (Phase 2)
// Small reusable mechanism for presenting the RevenueCat paywall.
// Uses existing RevenueCatManager, presents RevenueCat PaywallView with the `sale` offering,
// displays prices from RevenueCat (no hardcoded $4.99 etc.), handles restore via RevenueCatUI,
// and dismisses when the user becomes Pro.

struct PaywallHostView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @Environment(\.dismiss) private var dismiss

    @State private var offering: Offering?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        Group {
            if let offering {
                // RevenueCatUI paywall — uses dashboard-configured packages for sale
                // This will show monthly_subscription and yearly_susbcription with their configured prices
                PaywallView(offering: offering, displayCloseButton: true)
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading paywall…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Offering unavailable — safe error state, do NOT grant Pro, allow app to continue
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Paywall unavailable")
                        .font(.system(size: 16, weight: .semibold))
                    if let loadError {
                        Text(loadError)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Text("Please try again later.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Button("Close") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .task {
            await loadSaleOffering()
        }
        // Dismiss when the user becomes Pro — purchase or restore updates CustomerInfo via stream
        .onChange(of: revenueCatManager.isPro) { _, isPro in
            if isPro {
                dismiss()
            }
        }
        // Also observe state == .pro for faster dismiss
        .onChange(of: revenueCatManager.state) { _, state in
            if state == .pro {
                dismiss()
            }
        }
    }

    @MainActor
    private func loadSaleOffering() async {
        isLoading = true
        loadError = nil
        do {
            let offerings = try await Purchases.shared.offerings()
            // Explicitly use the `sale` offering — do not silently substitute current/default
            if let sale = offerings.offering(identifier: RevenueCatConstants.offeringID) {
                offering = sale
                // Validate that expected products are present for logging (not hardcoding prices)
                #if DEBUG
                let productIDs = sale.availablePackages.map { $0.storeProduct.productIdentifier }
                if !productIDs.contains(RevenueCatConstants.monthlyProductID) {
                    print("[Paywall] Warning: sale offering missing \(RevenueCatConstants.monthlyProductID) — found \(productIDs)")
                }
                if !productIDs.contains(RevenueCatConstants.annualProductID) {
                    print("[Paywall] Warning: sale offering missing \(RevenueCatConstants.annualProductID) — found \(productIDs)")
                }
                #endif
            } else {
                // Offering unavailable — safe error, don't crash, don't grant Pro
                loadError = "Offering '\(RevenueCatConstants.offeringID)' not found. Available: \(offerings.all.keys.sorted().joined(separator: ", "))"
                print("[Paywall] \(loadError ?? "")")
                offering = nil
            }
        } catch {
            // Purchase failure / network error — preserve current state, don't grant Pro
            loadError = error.localizedDescription
            print("[Paywall] Failed to load offerings: \(error)")
            offering = nil
        }
        isLoading = false
    }
}

// MARK: - Convenience sheet modifier for DEBUG / isolated testing

struct PaywallSheetModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            PaywallHostView()
        }
    }
}

extension View {
    func paywallSheet(isPresented: Binding<Bool>) -> some View {
        modifier(PaywallSheetModifier(isPresented: isPresented))
    }
}

// MARK: - Programmatic presenter (for non-View contexts if needed)

@MainActor
enum PaywallPresentation {
    // Offering / product / entitlement IDs are intentionally exposed as constants for tests
    static let offeringID = RevenueCatConstants.offeringID
    static let entitlementID = RevenueCatConstants.entitlementID
    static let monthlyProductID = RevenueCatConstants.monthlyProductID
    static let annualProductID = RevenueCatConstants.annualProductID

    /// Fetch the `sale` offering. Returns nil if unavailable — caller must handle error state.
    static func fetchSaleOffering() async -> Offering? {
        do {
            let offerings = try await Purchases.shared.offerings()
            return offerings.offering(identifier: offeringID)
        } catch {
            print("[PaywallPresentation] offerings fetch error: \(error)")
            return nil
        }
    }
}
