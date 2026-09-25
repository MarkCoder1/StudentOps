import Foundation
import Combine

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published var feed: PersonalizedFeed?
    @Published var opportunities: [RemoteOpportunity] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var hasMore = true

    private var currentOffset = 0
    private let limit = 50

    func loadInitial(profile: StudentProfile) async {
        currentOffset = 0
        opportunities = []
        feed = nil
        hasMore = true
        await fetchPersonalized(profile: profile)
    }

    func loadMoreIfNeeded(profile: StudentProfile) async {
        guard hasMore, !isLoading else { return }
        currentOffset += limit
        await fetchPersonalized(profile: profile)
    }

    func refresh(profile: StudentProfile) async {
        await loadInitial(profile: profile)
    }

    private func fetchPersonalized(profile: StudentProfile) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let personalizationProfile = PersonalizationProfile(from: profile)
            let result = try await OpportunityAPI.fetchPersonalized(profile: personalizationProfile)
            feed = result
            opportunities = result.opportunities.map { $0.opportunity }
            hasMore = false // personalized endpoint returns full set
        } catch let error as OpportunityAPIError {
            errorMessage = error.localizedDescription
            // Fallback to basic fetch if personalized fails
            await fetchBasic()
        } catch {
            errorMessage = error.localizedDescription
            await fetchBasic()
        }
        isLoading = false
    }

    private func fetchBasic() async {
        do {
            let response = try await OpportunityAPI.fetchOpportunities(
                limit: limit,
                offset: currentOffset,
                onlyActive: true
            )
            if currentOffset == 0 {
                opportunities = response.data
            } else {
                let existingIds = Set(opportunities.map { $0.id })
                let new = response.data.filter { !existingIds.contains($0.id) }
                opportunities.append(contentsOf: new)
            }
            hasMore = opportunities.count < response.pagination.total
        } catch {
            // Already have error message from personalized attempt
        }
    }
}
