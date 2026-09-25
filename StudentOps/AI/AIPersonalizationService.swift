import Foundation
import Combine

// MARK: - AI Personalization Service (Phase 9.8)
// Server-side Groq, structured JSON, validated. AI never decides eligibility/progress.
// Swift never holds API keys.

@MainActor
final class AIPersonalizationService: ObservableObject {
    static let shared = AIPersonalizationService()

    private let session: URLSession = .shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    // For testing: inject mock handler
    var mockHandler: ((AIPersonalizationOperation, Any) async throws -> Any)?

    private var inFlight = Set<String>()

    // MARK: - Project Explanation

    func projectExplanation(project: Project, store: AppDataStore) async throws -> AIProjectExplanationOutput {
        let context = AIContextBuilder.projectExplanationContext(project: project, store: store)
        // Validate fact preservation: recommendation score must be from deterministic engine, not recalculated
        let request = AIPersonalizationServerRequest(operation: .projectExplanation, context: context)
        let response: AIPersonalizationServerResponse<AIProjectExplanationOutput> = try await post(request: request)
        try validateProjectExplanation(response.data, context: context)
        return response.data
    }

    // MARK: - Project Coaching

    func projectCoaching(project: Project, store: AppDataStore) async throws -> AIProjectCoachingOutput {
        guard let context = AIContextBuilder.projectCoachingContext(project: project, store: store) else {
            throw AIError.invalidRequest("No playbook for this project")
        }
        let request = AIPersonalizationServerRequest(operation: .projectCoaching, context: context)
        let response: AIPersonalizationServerResponse<AIProjectCoachingOutput> = try await post(request: request)
        try validateCoaching(response.data)
        return response.data
    }

    // MARK: - Project Reflection

    func projectReflection(project: Project, store: AppDataStore) async throws -> AIProjectReflectionOutput {
        let context = AIContextBuilder.projectReflectionContext(project: project, store: store)
        let request = AIPersonalizationServerRequest(operation: .projectReflection, context: context)
        let response: AIPersonalizationServerResponse<AIProjectReflectionOutput> = try await post(request: request)
        try validateReflection(response.data)
        return response.data
    }

    // MARK: - Skill Explanation

    func skillExplanation(skillID: String, store: AppDataStore) async throws -> AISkillExplanationOutput {
        guard let context = AIContextBuilder.skillExplanationContext(skillID: skillID, store: store) else {
            throw AIError.invalidRequest("Invalid skill")
        }
        let request = AIPersonalizationServerRequest(operation: .skillExplanation, context: context)
        let response: AIPersonalizationServerResponse<AISkillExplanationOutput> = try await post(request: request)
        try validateSkill(response.data)
        return response.data
    }

    // MARK: - Roadmap Explanation

    func roadmapExplanation(roadmap: Roadmap, store: AppDataStore) async throws -> AIRoadmapExplanationOutput {
        let context = AIContextBuilder.roadmapExplanationContext(roadmap: roadmap, store: store)
        let request = AIPersonalizationServerRequest(operation: .roadmapExplanation, context: context)
        let response: AIPersonalizationServerResponse<AIRoadmapExplanationOutput> = try await post(request: request)
        try validateRoadmap(response.data)
        return response.data
    }

    // MARK: - Validation (length, not empty, no invented facts beyond context is prompt-level)

    private func validateProjectExplanation(_ data: AIProjectExplanationOutput, context: AIProjectExplanationContext) throws {
        guard data.summary.count >= 20 && data.summary.count <= 600 else { throw AIError.invalidResponse("summary length invalid") }
        guard data.reasons.count >= 2 && data.reasons.count <= 4 else { throw AIError.invalidResponse("reasons count invalid") }
        for r in data.reasons { guard r.count >= 10 && r.count <= 200 else { throw AIError.invalidResponse("reason length invalid") } }
        // Ensure summary doesn't contain invented numbers not in context (basic check is prompt-level, here we just validate length)
    }

    private func validateCoaching(_ data: AIProjectCoachingOutput) throws {
        guard data.focus.count >= 20 && data.focus.count <= 400 else { throw AIError.invalidResponse("focus length invalid") }
        guard data.actions.count >= 2 && data.actions.count <= 5 else { throw AIError.invalidResponse("actions count invalid") }
        if let c = data.caution, c.count > 200 { throw AIError.invalidResponse("caution too long") }
    }

    private func validateReflection(_ data: AIProjectReflectionOutput) throws {
        guard data.prompts.count >= 3 && data.prompts.count <= 5 else { throw AIError.invalidResponse("prompts count invalid") }
        if let d = data.draftReflection, d.count > 1200 { throw AIError.invalidResponse("draft too long") }
    }

    private func validateSkill(_ data: AISkillExplanationOutput) throws {
        guard data.summary.count >= 20 && data.summary.count <= 400 else { throw AIError.invalidResponse("summary length invalid") }
        guard data.howProjectHelps.count >= 20 && data.howProjectHelps.count <= 400 else { throw AIError.invalidResponse("howProjectHelps length invalid") }
    }

    private func validateRoadmap(_ data: AIRoadmapExplanationOutput) throws {
        guard data.summary.count >= 20 && data.summary.length <= 600 else { throw AIError.invalidResponse("summary length invalid") }
        guard data.focusAreas.count >= 2 && data.focusAreas.count <= 4 else { throw AIError.invalidResponse("focusAreas count invalid") }
    }

    // MARK: - Network

    private func post<T: Codable, U: Codable>(request: AIPersonalizationServerRequest<T>) async throws -> AIPersonalizationServerResponse<U> {
        // Mock for tests / offline
        if let mock = mockHandler {
            let result = try await mock(request.operation, request.context)
            guard let typed = result as? U else { throw AIError.invalidResponse("Mock type mismatch") }
            return AIPersonalizationServerResponse(operation: request.operation, data: typed, model: "mock", provider: "mock")
        }

        // Deduplication: avoid duplicate in-flight with same operation + project id fingerprint
        let key = "\(request.operation.rawValue)-\(AIContextBuilder.fingerprint(request.context))"
        if inFlight.contains(key) { throw AIError.networkFailure("Duplicate request") }
        inFlight.insert(key)
        defer { Task { @MainActor in self.inFlight.remove(key) } }

        let url = APIConfig.baseURL.appendingPathComponent("/api/ai/personalization")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)
        urlRequest.timeoutInterval = 30

        // Log without secrets
        #if DEBUG
        print("[AI] POST \(url.absoluteString) operation=\(request.operation.rawValue)")
        #endif

        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else { throw AIError.networkFailure("Invalid response") }

        if http.statusCode == 200 {
            do {
                return try decoder.decode(AIPersonalizationServerResponse<U>.self, from: data)
            } catch {
                throw AIError.invalidResponse("Invalid response format: \(error.localizedDescription)")
            }
        } else {
            if let err = try? decoder.decode(AIErrorResponse.self, from: data) {
                switch err.error.code {
                case "invalid_request": throw AIError.invalidRequest(err.error.message)
                case "insufficient_context": throw AIError.insufficientContext(err.error.message)
                case "ai_generation_failed": throw AIError.providerFailure(err.error.message)
                case "invalid_ai_response": throw AIError.invalidResponse(err.error.message)
                default: throw AIError.providerFailure(err.error.message)
                }
            }
            throw AIError.networkFailure("Request failed \(http.statusCode)")
        }
    }
}

struct AIErrorResponse: Codable {
    struct Err: Codable { let code: String; let message: String }
    let error: Err
}

// MARK: - Mock for Tests

final class MockAIClient {
    static var cannedProjectExplanation = AIProjectExplanationOutput(
        summary: "This project fits your software engineering goal and builds on your current roadmap.",
        reasons: ["Matches your Software Engineer goal", "Builds a current skill gap", "Supports your roadmap"]
    )
    static var cannedCoaching = AIProjectCoachingOutput(
        focus: "Focus on the core user flow before polishing.",
        actions: ["Run normal case", "Test missing input", "Record observations"],
        caution: "Don't change architecture yet."
    )
    static var cannedReflection = AIProjectReflectionOutput(
        prompts: ["What problem did you solve?", "Which part was hardest?", "What would you change?"],
        draftReflection: nil
    )
    static var cannedSkill = AISkillExplanationOutput(
        summary: "This skill is part of your current roadmap and not yet demonstrated.",
        howProjectHelps: "This project gives you practice with that skill in a real context."
    )
    static var cannedRoadmap = AIRoadmapExplanationOutput(
        summary: "Your roadmap has 2 milestones completed. Focus on the next active milestone.",
        focusAreas: ["Complete next milestone", "Practice missing skills", "Add project evidence"]
    )
}

// Extension for String length helper
private extension String {
    var length: Int { count }
}
