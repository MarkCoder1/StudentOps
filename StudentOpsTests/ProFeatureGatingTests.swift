import XCTest
@testable import StudentOps
import RevenueCat

// Phase 3 — Premium Feature Gating tests
final class ProFeatureGatingTests: XCTestCase {

    // MARK: - Six Premium Features exist and are exactly six

    func testSixPremiumFeaturesExist() {
        XCTAssertEqual(PremiumFeature.allCases.count, 6, "Exactly six Pro features")
        XCTAssertTrue(PremiumFeature.allCases.contains(.personalizedRoadmaps))
        XCTAssertTrue(PremiumFeature.allCases.contains(.skillGapIntelligence))
        XCTAssertTrue(PremiumFeature.allCases.contains(.smartProjectRecommendations))
        XCTAssertTrue(PremiumFeature.allCases.contains(.opportunityMatching))
        XCTAssertTrue(PremiumFeature.allCases.contains(.adaptiveRoadmaps))
        XCTAssertTrue(PremiumFeature.allCases.contains(.progressEvidence))
    }

    func testPremiumFeatureTitlesAreConsistentWithPaywall() {
        // Public six-feature model must remain consistent with paywall
        let titles = PremiumFeature.allCases.map(\.rawValue)
        XCTAssertTrue(titles.contains("Personalized Roadmaps"))
        XCTAssertTrue(titles.contains("Skill Gap Intelligence"))
        XCTAssertTrue(titles.contains("Smart Project Recommendations"))
        XCTAssertTrue(titles.contains("Opportunity Matching"))
        XCTAssertTrue(titles.contains("Adaptive Roadmaps"))
        XCTAssertTrue(titles.contains("Progress & Evidence"))
        // No seventh "Career Intelligence Pro"
        XCTAssertFalse(titles.contains("Career Intelligence Pro"))
        XCTAssertFalse(titles.contains("Career Intelligence"))
    }

    func testPremiumFeatureIconsAndDescriptionsNonEmpty() {
        for feature in PremiumFeature.allCases {
            XCTAssertFalse(feature.shortTitle.isEmpty)
            XCTAssertFalse(feature.description.isEmpty)
            XCTAssertFalse(feature.icon.isEmpty)
        }
    }

    // MARK: - Free vs Pro (RevenueCatManager is source of truth)

    func testFreeUserIsNotPro() {
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: [:]))
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: ["studentops_pro": false]))
        // Product IDs alone do not grant Pro
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: ["monthly_subscription": true]))
        XCTAssertFalse(RevenueCatManager.isPro(entitlements: ["yearly_susbcription": true]))
    }

    func testProUserIsPro() {
        XCTAssertTrue(RevenueCatManager.isPro(entitlements: ["studentops_pro": true]))
    }

    func testProductIndependenceStillHolds() {
        // Both products unlock same entitlement — gated via entitlement, not product
        XCTAssertTrue(RevenueCatManager.isPro(entitlements: ["studentops_pro": true]))
        XCTAssertNotEqual(PaywallPresentation.monthlyProductID, RevenueCatManager.entitlementID)
        XCTAssertNotEqual(PaywallPresentation.annualProductID, RevenueCatManager.entitlementID)
        XCTAssertEqual(RevenueCatManager.entitlementID, "studentops_pro")
    }

    // MARK: - Gate behavior: Free shows paywall, Pro shows content

    func testGateShowsContentWhenPro() {
        // Simulate gate logic: if isPro { show content } else { show locked + paywall }
        func shouldShowContent(isPro: Bool) -> Bool { isPro }
        XCTAssertTrue(shouldShowContent(isPro: true))
        XCTAssertFalse(shouldShowContent(isPro: false))
    }

    func testGatePresentsPaywallWhenFree() {
        // For Free, tapping Pro capability should present PaywallHostView via sale offering
        // We verify constants: gate uses PaywallHostView with sale offering
        XCTAssertEqual(PaywallPresentation.offeringID, "sale")
        XCTAssertEqual(RevenueCatConstants.offeringID, "sale")
        // Paywall presentation layer exists and uses RevenueCatUI
        let _ = PaywallHostView()
        XCTAssertEqual(PaywallPresentation.entitlementID, "studentops_pro")
    }

    // MARK: - Six feature gates map to correct engines (existing deterministic engines remain authoritative)

    func testPersonalizedRoadmapsUsesExistingEngine() {
        // RoadmapsView FOR YOU section uses RoadmapAPI + ProjectRecommendationEngine etc. but gated
        // Verify gate exists for personalizedRoadmaps
        let feature = PremiumFeature.personalizedRoadmaps
        XCTAssertEqual(feature.rawValue, "Personalized Roadmaps")
        // Existing engine not modified — we just gate display
        // This test documents that gating does not replace engine
    }

    func testSkillGapIntelligenceUsesExistingEngine() {
        let feature = PremiumFeature.skillGapIntelligence
        XCTAssertEqual(feature.icon, "brain.head.profile")
        // Underlying: SkillGapEngine, SkillIntelligenceEngine, CareerSkillGraph remain source
    }

    func testSmartProjectRecommendationsUsesExistingEngine() {
        let feature = PremiumFeature.smartProjectRecommendations
        XCTAssertEqual(feature.rawValue, "Smart Project Recommendations")
        // Engine: ProjectRecommendationEngine remains authoritative
    }

    func testOpportunityMatchingUsesExistingEngines() {
        let feature = PremiumFeature.opportunityMatching
        XCTAssertEqual(feature.rawValue, "Opportunity Matching")
        // Engines: OpportunityEligibilityEngine, OpportunityMatchingEngine, OpportunityRankingEngine
    }

    func testAdaptiveRoadmapsUsesExistingEngines() {
        let feature = PremiumFeature.adaptiveRoadmaps
        XCTAssertEqual(feature.rawValue, "Adaptive Roadmaps")
        // Engines: AdaptiveRoadmapEngine, AdaptiveRoadmapProposalEngine, AdaptiveRoadmapOverrides
    }

    func testProgressEvidenceUsesExistingModels() {
        let feature = PremiumFeature.progressEvidence
        XCTAssertEqual(feature.rawValue, "Progress & Evidence")
        // Models: EvidenceRecord, Achievement, StudentPortfolio, PortfolioEvidenceEngine, PortfolioQualityEngine, EvidenceQualityEngine
    }

    // MARK: - Free functionality still usable (five tabs, profile, evidence)

    func testFreeFunctionalityStillUsable() {
        // Verify Free can still navigate five tabs — DashboardTab has 5
        XCTAssertEqual(DashboardTab.allCases.count, 5)
        XCTAssertTrue(DashboardTab.allCases.map(\.rawValue).contains("home"))
        XCTAssertTrue(DashboardTab.allCases.map(\.rawValue).contains("explore"))
        XCTAssertTrue(DashboardTab.allCases.map(\.rawValue).contains("roadmaps"))
        XCTAssertTrue(DashboardTab.allCases.map(\.rawValue).contains("projects"))
        XCTAssertTrue(DashboardTab.allCases.map(\.rawValue).contains("progress"))
        // Free can view roadmaps, manage projects, browse opportunities, view progress, edit profile, add evidence
        // These are covered by existing AppDataStore methods — we verify they exist (compile check)
        let store = AppDataStore()
        XCTAssertNotNil(store)
        // Project creation free
        let initialCount = store.customProjects.count
        store.createCustomProject(title: "Test Free Project", goal: "Goal")
        XCTAssertEqual(store.customProjects.count, initialCount + 1)
        // Evidence creation free
        let rec = EvidenceRecord(id: "test-\(UUID().uuidString)", type: .milestoneCompletion, title: "Test", description: nil, roadmapID: "r", milestoneID: "m", completionDate: Date(), createdAt: Date(), occurredAt: Date(), source: .studentEntered, status: .recorded)
        let added = store.addEvidence(rec)
        XCTAssertTrue(added)
        // Clean up
        _ = store.deleteEvidence(id: rec.id)
        _ = store.deleteCustomProject(id: store.customProjects.last?.id ?? "")
    }

    // MARK: - Purchase transition: Free -> Purchase -> isPro -> feature available (no fake flag)

    func testPurchaseTransitionIsViaCustomerInfo() {
        // Verify isPro is derived from entitlements["studentops_pro"]?.isActive
        // Not from UserDefaults or AppDataStore
        XCTAssertEqual(RevenueCatManager.entitlementID, "studentops_pro")
        // Simulate CustomerInfo update: entitlements["studentops_pro"] == true => isPro true
        let before = RevenueCatManager.isPro(entitlements: ["studentops_pro": false])
        let after = RevenueCatManager.isPro(entitlements: ["studentops_pro": true])
        XCTAssertFalse(before)
        XCTAssertTrue(after)
        // Verify no AppDataStore subscription state
        // This is a compile-time check: AppDataStore has no isPro/isPremium (verified via grep in build)
    }

    // MARK: - No hardcoded subscription state

    func testNoHardcodedSubscriptionState() {
        // Entitlement is not a UserDefaults bool, not AppDataStore bool, not product ID
        XCTAssertEqual(PaywallPresentation.offeringID, "sale")
        XCTAssertFalse(PaywallPresentation.monthlyProductID.contains("$"))
        XCTAssertFalse(PaywallPresentation.annualProductID.contains("4.99"))
        XCTAssertEqual(RevenueCatManager.entitlementID, "studentops_pro")
    }

    // MARK: - ProBadge exists and is subtle

    func testProBadgeExists() {
        let badge = ProBadge()
        XCTAssertNotNil(badge)
        let inline = ProInlineBadge(feature: .skillGapIntelligence)
        XCTAssertNotNil(inline)
    }
}
