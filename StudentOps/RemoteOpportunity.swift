import Foundation

// MARK: - Backend Canonical Opportunity (Phase 5.2 normalized, Phase 5.7 SQLite, Phase 5.8 API)
// Matches src/server/opportunities/models/opportunity.ts exactly (camelCase)
struct RemoteOpportunity: Identifiable, Hashable, Codable {
    let id: String
    let source: String
    let externalId: String
    let title: String
    let description: String?
    let organization: String?
    let officialUrl: String?
    let applicationUrl: String?
    let sourceUrl: String?
    let category: String
    let sourceCategory: String?
    let subjects: [String]
    let topics: [String]
    let skills: [String]
    let deadline: String?
    let startDate: String?
    let endDate: String?
    let location: RemoteLocation
    let cost: RemoteCost
    let benefits: RemoteBenefits
    let eligibility: RemoteEligibility
    let provenance: RemoteProvenance
    let sourceMetadata: [String: JSONValue]?
    let sourceRecords: [SourceRecord]?

    // For Hashable/Equatable via id
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RemoteOpportunity, rhs: RemoteOpportunity) -> Bool { lhs.id == rhs.id }
}

struct RemoteLocation: Hashable, Codable {
    let type: String // online, inPerson, hybrid, unknown
    let city: String?
    let state: String?
    let country: String?
    let online: Bool?
    let latitude: Double?
    let longitude: Double?
}

struct RemoteCost: Hashable, Codable {
    let amount: Double?
    let currency: String?
    let isFree: Bool?
}

struct RemoteBenefits: Hashable, Codable {
    let awardText: String?
    let awardAmount: Double?
    let awardCurrency: String?
    let prizeText: String?
}

struct RemoteEligibility: Hashable, Codable {
    let minAge: Int?
    let maxAge: Int?
    let gradeMin: String?
    let gradeMax: String?
    let countries: [String]?
    let geographicRestrictions: String?
    let enrollmentLevels: [String]?
    let majors: [String]?
    let requirements: [String]?
}

struct RemoteProvenance: Hashable, Codable {
    let source: String
    let externalId: String
    let fetchedAt: String
    let sourceUpdatedAt: String?
}

struct SourceRecord: Hashable, Codable {
    let source: String
    let externalId: String
}

// Helper to allow [String: Any] decoding for sourceMetadata
enum JSONValue: Hashable, Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? container.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - API Responses

struct OpportunitiesResponse: Codable {
    let data: [RemoteOpportunity]
    let pagination: APIPagination
}

struct APIPagination: Codable {
    let limit: Int
    let offset: Int
    let total: Int
}

struct OpportunityResponse: Codable {
    let data: RemoteOpportunity
}

struct APIErrorResponse: Codable {
    let error: APIError
}

struct APIError: Codable {
    let code: String
    let message: String
}

// MARK: - Preview Helpers (not used in production Explore path)

extension RemoteOpportunity {
    static var preview: RemoteOpportunity {
        RemoteOpportunity(
            id: "studentSuite:preview",
            source: "studentSuite",
            externalId: "preview",
            title: "Preview Opportunity",
            description: "This is preview data only.",
            organization: "Preview Org",
            officialUrl: "https://example.com",
            applicationUrl: "https://example.com/apply",
            sourceUrl: "https://example.com/source",
            category: "competition",
            sourceCategory: "STEM",
            subjects: ["AI"],
            topics: ["Machine Learning"],
            skills: ["Python"],
            deadline: "2026-12-01",
            startDate: nil,
            endDate: nil,
            location: RemoteLocation(type: "online", city: nil, state: nil, country: nil, online: true, latitude: nil, longitude: nil),
            cost: RemoteCost(amount: 0, currency: "USD", isFree: true),
            benefits: RemoteBenefits(awardText: "$1000", awardAmount: 1000, awardCurrency: "USD", prizeText: "$1000"),
            eligibility: RemoteEligibility(minAge: 13, maxAge: 18, gradeMin: nil, gradeMax: nil, countries: ["US"], geographicRestrictions: nil, enrollmentLevels: nil, majors: nil, requirements: nil),
            provenance: RemoteProvenance(source: "studentSuite", externalId: "preview", fetchedAt: "2026-09-12T00:00:00.000Z", sourceUpdatedAt: nil),
            sourceMetadata: [:],
            sourceRecords: nil
        )
    }
}
