import Foundation
import Combine
import RevenueCat

/// Subscription state - clean representation separate from AppDataStore.
/// RevenueCat remains the authoritative source for entitlement status.
enum SubscriptionState: Equatable {
    case loading
    case free
    case pro
    case error(String)

    static func == (lhs: SubscriptionState, rhs: SubscriptionState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.free, .free), (.pro, .pro): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

/// Single source of truth for subscription status.
/// Entitlement ID: `studentops_pro` — both `monthly_subscription` and `yearly_susbcription` unlock this entitlement.
@MainActor
final class RevenueCatManager: ObservableObject {
    // MARK: - Constants
    static let entitlementID = "studentops_pro"

    // MARK: - Published State
    @Published private(set) var isPro: Bool = false
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    @Published private(set) var state: SubscriptionState = .loading

    // MARK: - Private
    private var customerInfoStreamTask: Task<Void, Never>?

    // MARK: - Init
    init() {
        refresh()
        observeCustomerInfoStream()
    }

    deinit {
        customerInfoStreamTask?.cancel()
    }

    // MARK: - Public API

    /// Refreshes CustomerInfo from RevenueCat and re-evaluates `studentops_pro`.
    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        state = .loading

        Purchases.shared.getCustomerInfo { [weak self] info, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.error = error
                    self.customerInfo = nil
                    self.isPro = false
                    self.state = .error(error.localizedDescription)
                    return
                }
                guard let info else {
                    self.error = nil
                    self.customerInfo = nil
                    self.isPro = false
                    self.state = .free
                    return
                }
                self.customerInfo = info
                self.error = nil
                self.updateProStatus(from: info)
            }
        }
    }

    /// Async variant for Swift concurrency callers.
    func refreshAsync() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        state = .loading
        do {
            let info = try await Purchases.shared.customerInfo()
            customerInfo = info
            error = nil
            updateProStatus(from: info)
        } catch {
            self.error = error
            self.customerInfo = nil
            self.isPro = false
            self.state = .error(error.localizedDescription)
        }
        isLoading = false
    }

    /// Restores purchases using RevenueCat's current API.
    /// After restoration: obtains updated CustomerInfo, re-evaluates entitlement, updates isPro.
    func restorePurchases() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Purchases.shared.restorePurchases { [weak self] info, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.error = error
                    // Do NOT grant Pro on error; keep current isPro (safe non-Pro if unknown)
                    // If we had no prior info, ensure non-Pro
                    if self.customerInfo == nil {
                        self.isPro = false
                        self.state = .error(error.localizedDescription)
                    }
                    return
                }
                guard let info else {
                    self.error = nil
                    // No info and no error -> treat as free (safe)
                    self.isPro = false
                    self.state = .free
                    return
                }
                self.customerInfo = info
                self.error = nil
                self.updateProStatus(from: info)
            }
        }
    }

    /// Async variant of restore.
    func restorePurchasesAsync() async throws -> CustomerInfo {
        guard !isLoading else { throw CancellationError() }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            customerInfo = info
            error = nil
            updateProStatus(from: info)
            return info
        } catch {
            self.error = error
            if customerInfo == nil {
                isPro = false
                state = .error(error.localizedDescription)
            }
            throw error
        }
    }

    // MARK: - Entitlement Logic

    /// The authoritative check — do NOT check product IDs directly.
    static func isProActive(in customerInfo: CustomerInfo) -> Bool {
        customerInfo.entitlements[entitlementID]?.isActive == true
    }

    /// Helper for tests / product-independence verification without needing a live CustomerInfo.
    /// Evaluates whether a dictionary of entitlementID -> isActive represents Pro.
    static func isPro(entitlements: [String: Bool]) -> Bool {
        entitlements[entitlementID] == true
    }

    private func updateProStatus(from customerInfo: CustomerInfo) {
        let active = Self.isProActive(in: customerInfo)
        isPro = active
        state = active ? .pro : .free
    }

    // MARK: - Stream Observation

    private func observeCustomerInfoStream() {
        // RevenueCat 5.90.2 exposes customerInfoStream as AsyncStream<CustomerInfo>
        customerInfoStreamTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard let self else { return }
                await MainActor.run {
                    self.customerInfo = info
                    self.error = nil
                    self.updateProStatus(from: info)
                }
            }
        }
    }
}
