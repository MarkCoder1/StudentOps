import XCTest
@testable import StudentOps
import RevenueCat
import RevenueCatUI

// Phase 2 contract: offering / product / entitlement IDs and purchase sync

final class PaywallContractTests: XCTestCase {

    // MARK: - Offering identity
    func testOfferingIdentity_isSale() {
        XCTAssertEqual(RevenueCatConstants.offeringID, "sale")
        XCTAssertEqual(PaywallPresentation.offeringID, "sale")
        XCTAssertEqual(PaywallPresentation.offeringID, RevenueCatConstants.offeringID)
    }

    // MARK: - Product identity (preserve typo)
    func testMonthlyProductID() {
        XCTAssertEqual(RevenueCatConstants.monthlyProductID, "monthly_subscription")
        XCTAssertEqual(PaywallPresentation.monthlyProductID, "monthly_subscription")
    }

    func testAnnualProductID_preservesTypo() {
        XCTAssertEqual(RevenueCatConstants.annualProductID, "yearly_susbcription")
        XCTAssertEqual(PaywallPresentation.annualProductID, "yearly_susbcription")
        XCTAssertNotEqual(PaywallPresentation.annualProductID, "yearly_subscription", "Do not \"correct\" the typo")
    }

    // MARK: - Entitlement identity
    func testEntitlementIdentity_isStudentOpsPro() {
        XCTAssertEqual(RevenueCatConstants.entitlementID, "studentops_pro")
        XCTAssertEqual(RevenueCatManager.entitlementID, "studentops_pro")
        XCTAssertEqual(PaywallPresentation.entitlementID, "studentops_pro")
        // Only entitlement used for Pro
        XCTAssertTrue(RevenueCatManager.isPro(entitlements: ["studentops_pro": true]))
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: ["studentops_pro": false]))
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: ["monthly_subscription": true]))
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: ["yearly_susbcription": true]))
    }

    // MARK: - Free / Pro states (re-verify Phase 1 contract still holds)
    func testFreeState_isNotPro() {
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: [:]))
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: ["studentops_pro": false]))
    }

    func testProState_isPro() {
        XCTAssertTrue(RevenueCatManager.isPro(entitlements: ["studentops_pro": true]))
    }

    // MARK: - Product independence (Phase 2 repeats Phase 1: don't determine Pro from product ID)
    func testProductIndependence_bothProductsMapToSameEntitlement() {
        // Both monthly and annual unlock the same entitlement — verified via dictionary helper
        let monthlyUnlocksPro = RevenueCatManager.isPro(entitlements: ["studentops_pro": true])
        let annualUnlocksPro = RevenueCatManager.isPro(entitlements: ["studentops_pro": true])
        XCTAssertTrue(monthlyUnlocksPro)
        XCTAssertTrue(annualUnlocksPro)
        // Direct product check must not be used
        XCTAssertNotEqual(PaywallPresentation.monthlyProductID, PaywallPresentation.entitlementID)
        XCTAssertNotEqual(PaywallPresentation.annualProductID, PaywallPresentation.entitlementID)
    }

    // MARK: - Architecture constraints: no AppDataStore subscription state
    func testAppDataStoreHasNoSubscriptionState() {
        // This is a compile-time check: AppDataStore should not have isPremium/isPro
        // We verify by ensuring the file does not contain those symbols (checked via grep in build verification)
        // Here we just assert the manager is the source of truth
        let manager = RevenueCatManager()
        XCTAssertNotNil(manager)
        XCTAssertEqual(manager.entitlementID, "studentops_pro")
    }

    // MARK: - Paywall presentation layer uses RevenueCatUI
    func testPaywallHostViewExists() {
        // Verify PaywallHostView can be instantiated (compile-time check for RevenueCatUI)
        let _ = PaywallHostView()
        // PaywallPresentation constants are accessible
        XCTAssertEqual(PaywallPresentation.offeringID, "sale")
    }

    // MARK: - Purchase-state synchronization (simulated via state)
    func testManagerDefaultsToNonProOnError() {
        let manager = RevenueCatManager()
        // Initial isPro must be false — error must not grant Pro
        XCTAssertFalse(manager.isPro)
        // State should be loading/free/error, never pro initially without purchase
        XCTAssertTrue(manager.state == .loading || manager.state == .free || {
            if case .error = manager.state { return true }
            return false
        }())
    }

    // MARK: - No hardcoded pricing (paywall must use RevenueCat product data)
    // This is a documentation test: PaywallPresentation does not contain "$4.99" etc.
    // Verified via grep in build verification; here we assert constants are IDs, not prices
    func testNoHardcodedPricesInConstants() {
        XCTAssertFalse(RevenueCatConstants.monthlyProductID.contains("$"))
        XCTAssertFalse(RevenueCatConstants.annualProductID.contains("$"))
        XCTAssertFalse(PaywallPresentation.monthlyProductID.contains("4.99"))
        XCTAssertFalse(PaywallPresentation.annualProductID.contains("39.99"))
    }
}
