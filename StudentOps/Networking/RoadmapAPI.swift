import Foundation

enum RoadmapAPIError: LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL."
        case .networkError(let msg): return msg
        case .httpError(_, let msg): return msg ?? "Request failed."
        case .decodingError(let msg): return "Invalid response: \(msg)"
        case .serverError(let msg): return msg
        }
    }
}

struct RoadmapAPI {
    private static let basePath = "/api/roadmaps/personalized"

    static func fetchPersonalized(
        student: RoadmapStudentContext,
        roadmaps: [RoadmapCatalogItem]
    ) async throws -> PersonalizedRoadmapResponse {
        let urlString = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + basePath
        guard let url = URL(string: urlString) else { throw RoadmapAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let body = PersonalizedRoadmapRequest(student: student, roadmaps: roadmaps)
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("[RoadmapAPI] POST \(url.absoluteString)")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw RoadmapAPIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw RoadmapAPIError.networkError("Invalid response")
        }

        if http.statusCode == 200 {
            do {
                return try JSONDecoder().decode(PersonalizedRoadmapResponse.self, from: data)
            } catch {
                throw RoadmapAPIError.decodingError(error.localizedDescription)
            }
        } else if http.statusCode == 429 {
            throw RoadmapAPIError.serverError("Rate limited. Try again in a moment.")
        } else {
            let message: String?
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                message = errorResponse.error.message
            } else {
                message = String(data: data, encoding: .utf8)
            }
            throw RoadmapAPIError.httpError(statusCode: http.statusCode, message: message)
        }
    }
}
