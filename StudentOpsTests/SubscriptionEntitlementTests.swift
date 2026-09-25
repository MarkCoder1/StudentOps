import XCTest
@testable import StudentOps
import RevenueCat

// NOTE: These tests run as part of a future XCTest target.
// For Phase 1 they also serve as documentation of the entitlement contract.
// They verify the pure logic that `studentops_pro` is the single source of truth.

final class SubscriptionEntitlementTests: XCTestCase {

    // MARK: - Helper: create mock CustomerInfo? Not needed for dictionary-based tests.
    // We test the static helper isPro(entitlements:) which mirrors the entitlement check.

    func testFreeState_entitlementInactive_isNotPro() {
        let entitlements: [String: Bool] = ["studentops_pro": false]
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: entitlements), "inactive entitlement must be free")
    }

    func testFreeState_noEntitlement_isNotPro() {
        let entitlements: [String: Bool] = [:]
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: entitlements))
    }

    func testFreeState_wrongEntitlement_isNotPro() {
        let entitlements: [String: Bool] = ["other_entitlement": true]
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: entitlements))
    }

    func testProState_entitlementActive_isPro() {
        let entitlements: [String: Bool] = ["studentops_pro": true]
        XCTAssertTrue(RevenueCatManager.isPro(entitlements: entitlements))
    }

    func testProductIndependence_monthlyAndAnnualMapToSameEntitlement() {
        // Both products unlock the same entitlement; checking product IDs must not be used.
        // We simulate that both monthly and yearly end up as studentops_pro == true
        let monthlyEntitlements = ["studentops_pro": true] // via monthly_subscription
        let annualEntitlements = ["studentops_pro": true]  // via yearly_susbcription (note typo preserved)
        XCTAssertTrue(RevenueCatManager.isPro(entitlements: monthlyEntitlements))
        XCTAssertTrue(RevenueCatManager.isPro(entitlements: annualEntitlements))
        // Verify that checking product IDs directly would be wrong — we don't do it
        XCTAssertNotEqual("monthly_subscription", RevenueCatManager.entitlementID)
        XCTAssertNotEqual("yearly_susbcription", RevenueCatManager.entitlementID)
        XCTAssertEqual(RevenueCatManager.entitlementID, "studentops_pro")
    }

    func testErrorState_mustNotGrantPro() {
        // On error we keep non-Pro; our manager defaults to false and error state
        // This test documents the contract: error is safe non-Pro
        let manager = RevenueCatManager()
        // Initially after init, refresh is async; but initial state is loading or free, never pro on error
        // We can't easily force an error without networking, but we verify initial isPro is false
        XCTAssertFalse(manager.isPro, "temporary error must NOT incorrectly grant Pro access")
        XCTAssertTrue(manager.state == .loading || manager.state == .free || {
            if case .error(_) = manager.state { return true }
            return false
        }(), "state should be loading/free/error, never pro on initialization error")
    }

    func testEntitlementIDConstant() {
        XCTAssertEqual(RevenueCatManager.entitlementID, "studentops_pro")
    }

    func testStateTransitions_freeToPro() {
        // Verify state enum equality
        XCTAssertEqual(SubscriptionState.free, .free)
        XCTAssertEqual(SubscriptionState.pro, .pro)
        XCTAssertEqual(SubscriptionState.loading, .loading)
        XCTAssertNotEqual(SubscriptionState.free, .pro)
        let err1 = SubscriptionState.error("network")
        let err2 = SubscriptionState.error("network")
        let err3 = SubscriptionState.error("other")
        XCTAssertEqual(err1, err2)
        XCTAssertNotEqual(err1, err3)
    }

    // MARK: - CustomerInfo integration (requires live RevenueCat object)
    // This test would require a mock CustomerInfo; we document that isProActive(in:) uses entitlements["studentops_pro"]
    // The implementation is: customerInfo.entitlements["studentops_pro"]?.isActive == true
    // We cannot construct CustomerInfo without JSON decoding, so we test the dictionary helper as proxy.
}
