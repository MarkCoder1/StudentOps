

import SwiftUI
import RevenueCat

@main
struct StudentOpsApp: App {
    @StateObject private var store = AppDataStore()
    @StateObject private var revenueCatManager = RevenueCatManager()
    @StateObject private var appearanceManager = AppearanceManager()

    init() {
        // RevenueCat — Test Store configuration
        Purchases.configure(
            withAPIKey: "test_jsiMGczjRZOJPJVTyHRtYbJkjRM"
        )

        // ONE-TIME TESTING RESET v1 — legacy, keep flag to avoid re-trigger
        let resetFlag = "studentops.oneTimeResetDone_v1"
        if !UserDefaults.standard.bool(forKey: resetFlag) {
            UserDefaults.standard.removeObject(
                forKey: "studentops.onboardingCompleted"
            )
            UserDefaults.standard.removeObject(
                forKey: "studentops.profile"
            )
            UserDefaults.standard.set(true, forKey: resetFlag)

            print("[StudentOps] One-time onboarding reset v1 performed")
        }

        // ONE-TIME TESTING RESET v2 — requested reset for full onboarding re-test
        // Shows onboarding from Step 1 on NEXT launch only, then persists normally.
        // Do NOT make this run every launch.
        let resetFlag2 = "studentops.oneTimeResetDone_v2"
        if !UserDefaults.standard.bool(forKey: resetFlag2) {
            UserDefaults.standard.removeObject(
                forKey: "studentops.onboardingCompleted"
            )
            UserDefaults.standard.removeObject(
                forKey: "studentops.profile"
            )
            UserDefaults.standard.set(true, forKey: resetFlag2)

            print(
                "[StudentOps] One-time onboarding reset v2 performed — next launch will show Step 1 with all fields"
            )
        }

        // ONE-TIME RESET v3 — force intro onboarding from start (intro + profile)
        // Clears intro, profile, and all Student OPS persisted state so the app shows the 4-screen intro from Screen 1.
        // Runs once on next launch, then persists normally. Does NOT touch RevenueCat or appearance.
        let resetFlag3 = "studentops.oneTimeResetDone_v3"
        if !UserDefaults.standard.bool(forKey: resetFlag3) {
            let keysToClear = [
                "studentops.introOnboardingCompleted",
                "studentops.onboardingCompleted",
                "studentops.profile",
                "studentops.onboarding.projects",
                "studentops.roadmapProgress",
                "studentops.projectProgress",
                "studentops.portfolioProjectIDs",
                "studentops.customProjects",
                "studentops.projectNotes",
                "studentops.savedOpportunityIDs",
                "studentops.completedActionIDs",
                "studentops.validationAttempts",
                "studentops.evidenceRecords",
                "studentops.activeRoadmaps",
                "studentops.achievements",
                "studentops.portfolios",
                "studentops.opportunities",
                "studentops.projectExecutionStates",
                "studentops.adaptiveOverrides",
            ]
            for k in keysToClear { UserDefaults.standard.removeObject(forKey: k) }
            // Clear project images
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("StudentOps", isDirectory: true)
                .appendingPathComponent("ProjectImages", isDirectory: true)
            if let base { try? FileManager.default.removeItem(at: base) }
            UserDefaults.standard.set(true, forKey: resetFlag3)
            print("[StudentOps] One-time reset v3 performed — next launch will show intro onboarding Screen 1 → profile Step 1")
        }

        #if DEBUG
        BonjourDiscovery.shared.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(revenueCatManager)
                .environmentObject(appearanceManager)
                .preferredColorScheme(appearanceManager.preference.colorScheme)
        }
    }
}
