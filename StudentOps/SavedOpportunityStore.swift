import Combine
import Foundation

@MainActor
final class SavedOpportunityStore: ObservableObject {
    @Published private(set) var savedIDs: Set<String>
    private let storageKey = "studentops.savedOpportunityIDs"

    init() {
        savedIDs = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    func isSaved(_ opportunity: Opportunity) -> Bool { savedIDs.contains(opportunity.id) }

    func toggle(_ opportunity: Opportunity) {
        if savedIDs.contains(opportunity.id) { savedIDs.remove(opportunity.id) }
        else { savedIDs.insert(opportunity.id) }
        UserDefaults.standard.set(Array(savedIDs), forKey: storageKey)
    }
}
