import Foundation

enum OpportunityAPIError: LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case httpError(statusCode: Int, code: String?, message: String?)
    case decodingError(String)
    case notFound
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL."
        case .networkError(let msg): return msg
        case .httpError(_, _, let msg): return msg ?? "Request failed."
        case .decodingError(let msg): return "Invalid response: \(msg)"
        case .notFound: return "Opportunity not found."
        case .serverError(let msg): return msg
        }
    }
}

struct OpportunityAPI {
    // MARK: - Fetch Personalized Feed
    static func fetchPersonalized(profile: PersonalizationProfile) async throws -> PersonalizedFeed {
        let urlString = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + APIConfig.opportunitiesBasePath + "/personalized"
        guard let url = URL(string: urlString) else { throw OpportunityAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let body = ["profile": profile]
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("[OpportunityAPI] POST \(url.absoluteString)")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpportunityAPIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpportunityAPIError.networkError("Invalid response")
        }

        if http.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(PersonalizedFeed.self, from: data)
            } catch {
                throw OpportunityAPIError.decodingError(error.localizedDescription)
            }
        } else if http.statusCode == 400 {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw OpportunityAPIError.httpError(statusCode: 400, code: apiError.error.code, message: apiError.error.message)
            }
            throw OpportunityAPIError.httpError(statusCode: 400, code: nil, message: "Bad request")
        } else if (500...599).contains(http.statusCode) {
            throw OpportunityAPIError.serverError("Server error (\(http.statusCode))")
        } else {
            throw OpportunityAPIError.httpError(statusCode: http.statusCode, code: nil, message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }

    // MARK: - Fetch List
    static func fetchOpportunities(
        limit: Int = 50,
        offset: Int = 0,
        source: String? = nil,
        category: String? = nil,
        onlyActive: Bool? = nil
    ) async throws -> OpportunitiesResponse {
        var components = URLComponents(url: APIConfig.baseURL.appendingPathComponent(APIConfig.opportunitiesBasePath), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))
        if let source = source, !source.isEmpty { queryItems.append(URLQueryItem(name: "source", value: source)) }
        if let category = category, !category.isEmpty { queryItems.append(URLQueryItem(name: "category", value: category)) }
        if let onlyActive = onlyActive { queryItems.append(URLQueryItem(name: "onlyActive", value: onlyActive ? "true" : "false")) }
        components?.queryItems = queryItems

        guard let url = components?.url else { throw OpportunityAPIError.invalidURL }

        #if DEBUG
        print("[OpportunityAPI] GET \(url.absoluteString)")
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpportunityAPIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpportunityAPIError.networkError("Invalid response")
        }

        if http.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                // Backend uses camelCase, no key conversion needed, but handle snake_case fallback via custom keys
                return try decoder.decode(OpportunitiesResponse.self, from: data)
            } catch {
                throw OpportunityAPIError.decodingError(error.localizedDescription)
            }
        } else if http.statusCode == 400 {
            // Try to decode error code
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw OpportunityAPIError.httpError(statusCode: 400, code: apiError.error.code, message: apiError.error.message)
            }
            throw OpportunityAPIError.httpError(statusCode: 400, code: nil, message: "Bad request")
        } else if http.statusCode == 404 {
            throw OpportunityAPIError.notFound
        } else if (500...599).contains(http.statusCode) {
            throw OpportunityAPIError.serverError("Server error (\(http.statusCode))")
        } else {
            throw OpportunityAPIError.httpError(statusCode: http.statusCode, code: nil, message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }

    // MARK: - Fetch One
    static func fetchOpportunity(id: String) async throws -> RemoteOpportunity {
        // ID may contain : / - _  — must be percent-encoded for path
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let urlString = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + APIConfig.opportunitiesBasePath + "/" + encoded
        guard let url = URL(string: urlString) else { throw OpportunityAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpportunityAPIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpportunityAPIError.networkError("Invalid response")
        }

        if http.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                let wrapper = try decoder.decode(OpportunityResponse.self, from: data)
                return wrapper.data
            } catch {
                throw OpportunityAPIError.decodingError(error.localizedDescription)
            }
        } else if http.statusCode == 404 {
            throw OpportunityAPIError.notFound
        } else if http.statusCode == 400 {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw OpportunityAPIError.httpError(statusCode: 400, code: apiError.error.code, message: apiError.error.message)
            }
            throw OpportunityAPIError.httpError(statusCode: 400, code: nil, message: "Bad request")
        } else {
            throw OpportunityAPIError.httpError(statusCode: http.statusCode, code: nil, message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }

    // MARK: - Fetch AI Explanation

    static func fetchOpportunityExplanation(
        opportunityID: String,
        profile: PersonalizationProfile
    ) async throws -> OpportunityExplanation {
        let encoded = opportunityID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? opportunityID
        let urlString = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + APIConfig.opportunitiesBasePath + "/" + encoded + "/explanation"
        guard let url = URL(string: urlString) else { throw OpportunityAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let body = ["profile": profile]
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("[OpportunityAPI] POST \(url.absoluteString)")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpportunityAPIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpportunityAPIError.networkError("Invalid response")
        }

        if http.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                let wrapper = try decoder.decode(ExplanationResponse.self, from: data)
                return wrapper.explanation
            } catch {
                throw OpportunityAPIError.decodingError(error.localizedDescription)
            }
        } else if http.statusCode == 404 {
            throw OpportunityAPIError.notFound
        } else if http.statusCode == 400 {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw OpportunityAPIError.httpError(statusCode: 400, code: apiError.error.code, message: apiError.error.message)
            }
            throw OpportunityAPIError.httpError(statusCode: 400, code: nil, message: "Bad request")
        } else if (500...599).contains(http.statusCode) {
            // AI errors (503, 504, 429) all land here — treat as server error
            throw OpportunityAPIError.serverError("Explanation unavailable (server error \(http.statusCode))")
        } else {
            throw OpportunityAPIError.httpError(statusCode: http.statusCode, code: nil, message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }
}
