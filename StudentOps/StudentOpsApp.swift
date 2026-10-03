

import SwiftUI
import RevenueCat

@main
struct StudentOpsApp: App {
    @StateObject private var store: AppDataStore
    @StateObject private var revenueCatManager: RevenueCatManager
    @StateObject private var appearanceManager: AppearanceManager

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

        // ONE-TIME RESET v4 / DEMO — ensure welcome screen is first on every fresh launch for demo
        // Shows intro onboarding 1 of 4 first, then Next through existing onboarding screens step-by-step.
        // Does NOT change onboarding UI, data models, or features—only resets entry-point routing flags.
        // In DEBUG (simulator/demo) it runs on every launch so every fresh launch starts at welcome.
        // In Release it runs once to guarantee the demo build shows welcome.
        #if DEBUG
        // Demo: always start at welcome for every fresh launch
        // Force-clear onboarding flags via multiple methods to handle simulator global vs container mismatch
        // This ensures welcome screen (1 of 4) is first, then Next through existing onboarding step-by-step
        UserDefaults.standard.set(false, forKey: "studentops.introOnboardingCompleted")
        UserDefaults.standard.set(false, forKey: "studentops.onboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "studentops.introOnboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "studentops.onboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "studentops.profile")
        UserDefaults.standard.removeObject(forKey: "studentops.onboarding.projects")
        // Also clear persistent domain and global plist file (simulator)
        if let bid = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bid)
            // Re-apply the oneTime flags so v1/v2/v3 don't re-trigger unnecessarily, but keep onboarding cleared
            UserDefaults.standard.set(true, forKey: "studentops.oneTimeResetDone_v1")
            UserDefaults.standard.set(true, forKey: "studentops.oneTimeResetDone_v2")
            UserDefaults.standard.set(true, forKey: "studentops.oneTimeResetDone_v3")
            UserDefaults.standard.set(false, forKey: "studentops.introOnboardingCompleted")
            UserDefaults.standard.set(false, forKey: "studentops.onboardingCompleted")
        }
        // Direct file deletion for simulator global location (outside container)
        let fm = FileManager.default
        if let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
            // lib is .../data/Containers/Data/Application/<UUID>/Library
            var globalURL = lib
            for _ in 0..<5 { globalURL = globalURL.deletingLastPathComponent() } // up to .../data
            globalURL = globalURL.appendingPathComponent("Library/Preferences/com.markhabib.StudentOps.plist")
            try? fm.removeItem(at: globalURL)
            // Also ensure container prefs is cleared
            let containerPrefs = lib.appendingPathComponent("Preferences/com.markhabib.StudentOps.plist")
            // If container still has onboarding keys, remove them via dictionary
            if let data = try? Data(contentsOf: containerPrefs), var plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                plist.removeValue(forKey: "studentops.introOnboardingCompleted")
                plist.removeValue(forKey: "studentops.onboardingCompleted")
                plist.removeValue(forKey: "studentops.profile")
                plist.removeValue(forKey: "studentops.onboarding.projects")
                if let newData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) {
                    try? newData.write(to: containerPrefs)
                }
            }
        }
        UserDefaults.standard.synchronize()
        print("[StudentOps] Demo reset: welcome onboarding will be first screen (DEBUG)")
        #else
        let resetFlag4 = "studentops.oneTimeResetDone_v4"
        if !UserDefaults.standard.bool(forKey: resetFlag4) {
            UserDefaults.standard.removeObject(forKey: "studentops.introOnboardingCompleted")
            UserDefaults.standard.removeObject(forKey: "studentops.onboardingCompleted")
            UserDefaults.standard.removeObject(forKey: "studentops.profile")
            UserDefaults.standard.removeObject(forKey: "studentops.onboarding.projects")
            UserDefaults.standard.set(true, forKey: resetFlag4)
            print("[StudentOps] One-time reset v4 performed — welcome screen first for demo")
        }
        #endif

        // Initialize store AFTER clearing UserDefaults so every fresh launch starts at welcome
        // This guarantees ContentView sees introOnboardingCompleted == false and shows OnboardingContainerView 1 of 4 first,
        // then Next advances step-by-step through existing onboarding screens without altering UI/data design.
        _store = StateObject(wrappedValue: AppDataStore())
        _revenueCatManager = StateObject(wrappedValue: RevenueCatManager())
        _appearanceManager = StateObject(wrappedValue: AppearanceManager())

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
