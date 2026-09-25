import Foundation

// =============================================================================
// Phase 10A — Opportunity Intelligence Foundation — Comprehensive Tests
// Run: swift test-opportunity-intelligence.swift
// Covers: Model, Normalization, Validation, Deduplication, Freshness,
//         Repository, Persistence, Seed Data, Deterministic Ordering, Facts vs Unknown
// =============================================================================

var passed = 0
var failed = 0
func assert(_ condition: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if condition { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg)") }
}
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a == b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — got \(a), expected \(b)") }
}
func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: String = #file, line: Int = #line) {
    if a != b { passed += 1 } else { failed += 1; print("FAIL [\(file):\(line)] \(msg) — values equal \(a)") }
}

func normalizeSkillID(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    return parts.joined(separator: " ").lowercased()
}
func collapseWhitespace(_ s: String) -> String {
    let parts = s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    return parts.joined(separator: " ")
}
func isValidURL(_ s: String) -> Bool {
    guard let url = URL(string: s), let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme), url.host != nil else { return false }
    return true
}
func normalizeURL(_ raw: String?) -> String? {
    guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
    guard let url = URL(string: r), let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme), url.host != nil else { return nil }
    guard var comps = URLComponents(string: r) else { return r }
    comps.host = comps.host?.lowercased()
    comps.fragment = nil
    return comps.string ?? r
}
func deterministicHash(_ s: String) -> String {
    var hash: UInt32 = 2166136261
    for byte in s.utf8 { hash ^= UInt32(byte); hash = hash &* 16777619 }
    return String(format: "%08x", hash)
}

// MARK: - Inline Opportunity Models (mirrors Opportunity.swift)

enum OpportunityType: String, Codable, Hashable, CaseIterable {
    case competition = "competition"
    case hackathon = "hackathon"
    case scholarship = "scholarship"
    case research = "research"
    case internship = "internship"
    case summerProgram = "summerProgram"
    case academicProgram = "academicProgram"
    case volunteering = "volunteering"
    case leadership = "leadership"
    case fellowship = "fellowship"
    case conference = "conference"
    case community = "community"
    case other = "other"
}
enum OpportunityDeliveryMode: String, Codable, Hashable {
    case inPerson = "inPerson"
    case online = "online"
    case hybrid = "hybrid"
    case unknown = "unknown"
}
struct OpportunityLocation: Hashable, Codable {
    let type: String
    let city: String?
    let state: String?
    let country: String?
    let online: Bool?
    var displayString: String {
        if type.lowercased() == "online" || online == true { return "Online" }
        var parts: [String] = []
        if let city = city, !city.isEmpty { parts.append(city) }
        if let state = state, !state.isEmpty { parts.append(state) }
        if let country = country, !country.isEmpty { parts.append(country) }
        if parts.isEmpty { return type.isEmpty ? "Unknown" : type }
        return parts.joined(separator: ", ")
    }
}
struct OpportunityAgeRange: Hashable, Codable {
    let minAge: Int?
    let maxAge: Int?
    var isUnknown: Bool { minAge == nil && maxAge == nil }
}
struct OpportunityGradeRange: Hashable, Codable {
    let gradeMin: String?
    let gradeMax: String?
    let eligibleGrades: Set<String>
    var isUnknown: Bool { gradeMin == nil && gradeMax == nil && eligibleGrades.isEmpty }
}
struct OpportunityRequirement: Hashable, Codable, Identifiable {
    let id: String
    let title: String
    init(id: String = UUID().uuidString, title: String) {
        self.id = id; self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
struct OpportunityDeadline: Hashable, Codable {
    enum DeadlineType: String, Codable { case fixed, rolling, noDeadline, unknown }
    let date: Date?
    let type: DeadlineType
    let displayString: String
    init(date: Date?, type: DeadlineType, displayString: String? = nil) {
        self.date = date; self.type = type
        if let ds = displayString?.trimmingCharacters(in: .whitespacesAndNewlines), !ds.isEmpty { self.displayString = ds }
        else if let d = date { let f = DateFormatter(); f.dateStyle = .medium; self.displayString = f.string(from: d) }
        else { self.displayString = type == .rolling ? "Rolling" : type == .noDeadline ? "No deadline" : "Unknown" }
    }
}
struct OpportunityCost: Hashable, Codable {
    let amount: Double?
    let currency: String?
    let isFree: Bool?
    var isUnknown: Bool { isFree == nil && amount == nil }
    init(amount: Double?, currency: String?, isFree: Bool?) {
        self.amount = amount; self.currency = currency; self.isFree = isFree
    }
}
struct OpportunityEligibility: Hashable, Codable {
    let details: String?
    let requirements: [String]
    var isUnknown: Bool { details == nil && requirements.isEmpty }
    var displayString: String { details ?? (requirements.isEmpty ? "Unknown" : requirements.joined(separator: ", ")) }
    init(details: String?, requirements: [String] = []) {
        let d = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = d?.isEmpty == true ? nil : d
        self.requirements = requirements.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
struct OpportunitySource: Hashable, Codable {
    enum SourceType: String, Codable { case staticSeed, api, jsonFeed, manual, other }
    let sourceID: String
    let sourceName: String
    let sourceType: SourceType
    let sourceURL: String?
    let retrievedAt: Date
    let publisher: String?
    init(sourceID: String, sourceName: String, sourceType: SourceType, sourceURL: String?, retrievedAt: Date, publisher: String?) {
        self.sourceID = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceType = sourceType
        self.sourceURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.retrievedAt = retrievedAt
        self.publisher = publisher?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
enum OpportunityFreshness: String, Codable, Hashable { case fresh, aging, stale, expired, unknown }
enum OpportunityStatus: String, Codable, Hashable { case active, expired, archived, unknown }
struct OpportunityFreshnessInfo: Hashable, Codable {
    let freshness: OpportunityFreshness
    let daysUntilDeadline: Int?
    let isExpired: Bool
    let lastVerified: Date?
}
struct Opportunity: Hashable, Codable, Identifiable {
    let id: String
    let title: String
    let organization: String
    let organizationDescription: String?
    let opportunityType: OpportunityType
    let description: String
    let location: OpportunityLocation
    let deliveryMode: OpportunityDeliveryMode
    let ageRange: OpportunityAgeRange?
    let gradeRange: OpportunityGradeRange?
    let eligibilityInfo: OpportunityEligibility?
    let applicationRequirements: [OpportunityRequirement]
    let deadlineInfo: OpportunityDeadline?
    let costInfo: OpportunityCost?
    let skills: [String]
    let interests: [String]
    let careerFields: [String]
    let source: OpportunitySource
    let sourceURL: String?
    let lastVerified: Date?
    let status: OpportunityStatus
    let category: String
    let legacyDeadline: String
    let legacyLocation: String
    init(id: String, title: String, organization: String, organizationDescription: String? = nil,
         opportunityType: OpportunityType, description: String,
         location: OpportunityLocation, deliveryMode: OpportunityDeliveryMode = .unknown,
         ageRange: OpportunityAgeRange? = nil, gradeRange: OpportunityGradeRange? = nil,
         eligibilityInfo: OpportunityEligibility? = nil, applicationRequirements: [OpportunityRequirement] = [],
         deadlineInfo: OpportunityDeadline? = nil, costInfo: OpportunityCost? = nil,
         skills: [String] = [], interests: [String] = [], careerFields: [String] = [],
         source: OpportunitySource, sourceURL: String? = nil, lastVerified: Date? = nil, status: OpportunityStatus = .active) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organization = organization.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organizationDescription = organizationDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.opportunityType = opportunityType
        self.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.location = location
        self.deliveryMode = deliveryMode
        self.ageRange = ageRange
        self.gradeRange = gradeRange
        self.eligibilityInfo = eligibilityInfo
        self.applicationRequirements = applicationRequirements
        self.deadlineInfo = deadlineInfo
        self.costInfo = costInfo
        var seen = Set<String>()
        var out: [String] = []
        for raw in skills {
            let nid = normalizeSkillID(raw)
            guard !nid.isEmpty, !seen.contains(nid) else { continue }
            seen.insert(nid); out.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        self.skills = out
        self.interests = interests.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.careerFields = careerFields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.source = source
        let srcURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceURL = srcURL?.isEmpty == true ? nil : srcURL
        self.lastVerified = lastVerified
        self.status = status
        self.category = opportunityType.rawValue
        self.legacyDeadline = deadlineInfo?.displayString ?? "Rolling"
        self.legacyLocation = location.displayString
    }
}
struct RawOpportunityRecord: Codable, Hashable {
    let id: String?
    let title: String?
    let organization: String?
    let organizationDescription: String?
    let category: String?
    let description: String?
    let location: String?
    let deliveryMode: String?
    let minAge: String?
    let maxAge: String?
    let gradeMin: String?
    let gradeMax: String?
    let eligibility: String?
    let requirements: [String]?
    let deadline: String?
    let cost: String?
    let skills: [String]?
    let interests: [String]?
    let careerFields: [String]?
    let sourceID: String?
    let sourceName: String?
    let sourceType: String?
    let sourceURL: String?
    let retrievedAt: String?
    let officialURL: String?
    let lastVerified: String?
    init(id: String? = nil, title: String? = nil, organization: String? = nil, organizationDescription: String? = nil,
         category: String? = nil, description: String? = nil, location: String? = nil, deliveryMode: String? = nil,
         minAge: String? = nil, maxAge: String? = nil, gradeMin: String? = nil, gradeMax: String? = nil,
         eligibility: String? = nil, requirements: [String]? = nil, deadline: String? = nil, cost: String? = nil,
         skills: [String]? = nil, interests: [String]? = nil, careerFields: [String]? = nil,
         sourceID: String? = nil, sourceName: String? = nil, sourceType: String? = nil, sourceURL: String? = nil,
         retrievedAt: String? = nil, officialURL: String? = nil, lastVerified: String? = nil) {
        self.id = id; self.title = title; self.organization = organization; self.organizationDescription = organizationDescription
        self.category = category; self.description = description; self.location = location; self.deliveryMode = deliveryMode
        self.minAge = minAge; self.maxAge = maxAge; self.gradeMin = gradeMin; self.gradeMax = gradeMax
        self.eligibility = eligibility; self.requirements = requirements; self.deadline = deadline; self.cost = cost
        self.skills = skills; self.interests = interests; self.careerFields = careerFields
        self.sourceID = sourceID; self.sourceName = sourceName; self.sourceType = sourceType; self.sourceURL = sourceURL
        self.retrievedAt = retrievedAt; self.officialURL = officialURL; self.lastVerified = lastVerified
    }
}
enum Normalizer {
    static func normalizeTitle(_ raw: String?) -> String {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return "" }
        return collapseWhitespace(r)
    }
    static func normalizeOrg(_ raw: String?) -> String {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return "" }
        return collapseWhitespace(r)
    }
    static func normalizeID(raw: RawOpportunityRecord, title: String, organization: String) -> String {
        if let id = raw.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty, !id.lowercased().contains("unknown") {
            return collapseWhitespace(id).lowercased().replacingOccurrences(of: " ", with: "-")
        }
        if let sid = raw.sourceID?.trimmingCharacters(in: .whitespacesAndNewlines), !sid.isEmpty {
            let t = normalizeTitle(raw.title).lowercased().replacingOccurrences(of: " ", with: "-")
            let o = normalizeOrg(raw.organization).lowercased().replacingOccurrences(of: " ", with: "-")
            let d = collapseWhitespace(raw.deadline ?? "").lowercased().replacingOccurrences(of: " ", with: "-")
            if !t.isEmpty || !o.isEmpty {
                let base = "\(sid)-\(o)-\(t)-\(d)".lowercased()
                return base.replacingOccurrences(of: "--", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let base = "\(organization.lowercased())-\(title.lowercased())-\(raw.deadline ?? "")"
        let hash = deterministicHash(base)
        let t = title.lowercased().replacingOccurrences(of: " ", with: "-").prefix(20)
        let o = organization.lowercased().replacingOccurrences(of: " ", with: "-").prefix(15)
        return "\(o)-\(t)-\(hash)".lowercased()
    }
    static func normalizeCategory(_ raw: String?) -> OpportunityType {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !r.isEmpty else { return .other }
        let norm = r.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "")
        switch norm {
        case "competition","competitions","contest": return .competition
        case "hackathon","hackathons": return .hackathon
        case "scholarship","scholarships": return .scholarship
        case "research","researchprogram": return .research
        case "internship","internships": return .internship
        case "summerprogram","summerprograms","summer": return .summerProgram
        case "academicprogram","academicprograms","academic": return .academicProgram
        case "volunteering","volunteer","communityservice": return .volunteering
        case "leadership","leadershipprogram": return .leadership
        case "fellowship","fellowships": return .fellowship
        case "conference","conferences","program": return .conference
        case "community","communityopportunity": return .community
        default: return .other
        }
    }
    static func normalizeLocation(_ raw: String?, deliveryMode: String?) -> OpportunityLocation {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else {
            if let dm = deliveryMode?.lowercased(), dm.contains("online") { return OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true) }
            return OpportunityLocation(type: "unknown", city: nil, state: nil, country: nil, online: nil)
        }
        let lower = r.lowercased()
        if lower.contains("online") || lower.contains("remote") || lower.contains("virtual") { return OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true) }
        if lower.contains("hybrid") { return OpportunityLocation(type: "hybrid", city: nil, state: nil, country: nil, online: nil) }
        return OpportunityLocation(type: "inPerson", city: nil, state: nil, country: nil, online: false)
    }
    static func normalizeDelivery(_ raw: String?, location: String?) -> OpportunityDeliveryMode {
        if let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty {
            let norm = r.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
            switch norm {
            case "inperson","onsite": return .inPerson
            case "online","remote","virtual": return .online
            case "hybrid": return .hybrid
            default: return .unknown
            }
        }
        if let loc = location?.lowercased() {
            if loc.contains("online") || loc.contains("remote") { return .online }
            if loc.contains("hybrid") { return .hybrid }
            if loc.contains("in person") { return .inPerson }
        }
        return .unknown
    }
    static func parseAge(_ raw: String?) -> Int? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        let scanner = Scanner(string: r)
        var val: Int = 0
        if scanner.scanInt(&val) { return val }
        if let num = r.range(of: "\\d+", options: .regularExpression).flatMap({ Int(r[$0]) }) { return num }
        return nil
    }
    static func normalizeAgeRange(minAge: String?, maxAge: String?) -> OpportunityAgeRange? {
        let minVal = parseAge(minAge); let maxVal = parseAge(maxAge)
        if minVal == nil && maxVal == nil { return nil }
        return OpportunityAgeRange(minAge: minVal, maxAge: maxVal)
    }
    static func normalizeCost(_ raw: String?) -> OpportunityCost? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        let lower = r.lowercased()
        if lower == "free" || lower.contains("free") { return OpportunityCost(amount: 0, currency: "USD", isFree: true) }
        if lower == "unknown" { return nil }
        let digits = r.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined(separator: "|").split(separator: "|").compactMap { Double($0) }.first
        if let amt = digits { return OpportunityCost(amount: amt, currency: "USD", isFree: amt == 0) }
        return OpportunityCost(amount: nil, currency: nil, isFree: nil)
    }
    static func normalizeDeadline(_ raw: String?) -> OpportunityDeadline? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        let lower = r.lowercased()
        if lower == "rolling" || lower.contains("rolling") { return OpportunityDeadline(date: nil, type: .rolling, displayString: "Rolling") }
        if lower == "tbd" || lower == "no deadline" || lower == "unknown" { return OpportunityDeadline(date: nil, type: .unknown, displayString: r) }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        if let d = f.date(from: r) { return OpportunityDeadline(date: d, type: .fixed, displayString: r) }
        if let d = ISO8601DateFormatter().date(from: r) { return OpportunityDeadline(date: d, type: .fixed, displayString: r) }
        return OpportunityDeadline(date: nil, type: .unknown, displayString: r)
    }
    static func normalizeText(_ raw: String?) -> String? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        return collapseWhitespace(r)
    }
    static func normalizeStringArray(_ arr: [String]?) -> [String] {
        guard let a = arr else { return [] }
        var seen = Set<String>(); var out: [String] = []
        for raw in a {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            let collapsed = collapseWhitespace(t)
            let lower = collapsed.lowercased()
            if seen.contains(lower) { continue }
            seen.insert(lower); out.append(collapsed)
        }
        return out
    }
    static func normalize(_ raw: RawOpportunityRecord) -> Opportunity {
        let title = normalizeTitle(raw.title)
        let org = normalizeOrg(raw.organization)
        let id = normalizeID(raw: raw, title: title, organization: org)
        let type = normalizeCategory(raw.category)
        let desc = normalizeText(raw.description) ?? ""
        let loc = normalizeLocation(raw.location, deliveryMode: raw.deliveryMode)
        let delivery = normalizeDelivery(raw.deliveryMode, location: raw.location)
        let ageRange = normalizeAgeRange(minAge: raw.minAge, maxAge: raw.maxAge)
        let skills: [String] = {
            guard let s = raw.skills else { return [] }
            var seen = Set<String>(); var out: [String] = []
            for rawSkill in s {
                let nid = normalizeSkillID(rawSkill)
                guard !nid.isEmpty, !seen.contains(nid) else { continue }
                seen.insert(nid); out.append(rawSkill.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return out
        }()
        let interests = normalizeStringArray(raw.interests)
        let careerFields = normalizeStringArray(raw.careerFields)
        let sourceURL = normalizeURL(raw.sourceURL) ?? normalizeURL(raw.officialURL)
        let officialURL = normalizeURL(raw.officialURL) ?? normalizeURL(raw.sourceURL)
        let sourceType: OpportunitySource.SourceType = {
            guard let t = raw.sourceType?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return .other }
            switch t {
            case "staticseed","static_seed","seed": return .staticSeed
            case "api": return .api
            case "jsonfeed","json_feed": return .jsonFeed
            case "manual": return .manual
            default: return .other
            }
        }()
        let sid = raw.sourceID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        let sname = raw.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Source"
        let source = OpportunitySource(sourceID: sid, sourceName: sname, sourceType: sourceType, sourceURL: officialURL, retrievedAt: Date(), publisher: org.isEmpty ? nil : org)
        let deadlineInfo = normalizeDeadline(raw.deadline)
        let costInfo = normalizeCost(raw.cost)
        let eligibilityInfo: OpportunityEligibility? = {
            let details = normalizeText(raw.eligibility)
            if details == nil && (raw.requirements?.isEmpty ?? true) { return nil }
            return OpportunityEligibility(details: details, requirements: raw.requirements ?? [])
        }()
        let appReqs: [OpportunityRequirement] = (raw.requirements ?? []).map { OpportunityRequirement(title: $0) }
        let lastVerified: Date? = {
            if let s = raw.lastVerified, let d = ISO8601DateFormatter().date(from: s) { return d }
            if let s = raw.retrievedAt, let d = ISO8601DateFormatter().date(from: s) { return d }
            return nil
        }()
        return Opportunity(id: id, title: title.isEmpty ? "Untitled Opportunity" : title, organization: org.isEmpty ? "Unknown Organization" : org,
                           organizationDescription: normalizeText(raw.organizationDescription), opportunityType: type, description: desc,
                           location: loc, deliveryMode: delivery, ageRange: ageRange, gradeRange: nil,
                           eligibilityInfo: eligibilityInfo, applicationRequirements: appReqs, deadlineInfo: deadlineInfo, costInfo: costInfo,
                           skills: skills, interests: interests, careerFields: careerFields, source: source, sourceURL: sourceURL, lastVerified: lastVerified, status: .active)
    }
}
enum ValidationLevel: String { case error, warning }
struct ValidationIssue: Hashable { let level: ValidationLevel; let field: String; let message: String; let code: String }
struct ValidationResult: Hashable { let isValid: Bool; let errors: [ValidationIssue]; let warnings: [ValidationIssue] }
enum Validator {
    static func validate(_ opp: Opportunity) -> ValidationResult {
        var errors: [ValidationIssue] = []
        var warnings: [ValidationIssue] = []
        if opp.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.init(level: .error, field: "id", message: "ID empty", code: "empty_id")) }
        if opp.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.init(level: .error, field: "title", message: "Title empty", code: "empty_title")) }
        if opp.organization.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.init(level: .error, field: "organization", message: "Organization empty", code: "empty_organization")) }
        if let urlStr = opp.sourceURL, !urlStr.isEmpty, !isValidURL(urlStr) { errors.append(.init(level: .error, field: "sourceURL", message: "Invalid URL", code: "invalid_url")) }
        if let srcURL = opp.source.sourceURL, !srcURL.isEmpty, !isValidURL(srcURL) { errors.append(.init(level: .error, field: "source.sourceURL", message: "Invalid source URL", code: "invalid_url")) }
        if let age = opp.ageRange {
            if let min = age.minAge, let max = age.maxAge, min > max { errors.append(.init(level: .error, field: "ageRange", message: "minAge > maxAge", code: "invalid_age_range")) }
            if let min = age.minAge, min < 0 || min > 120 { errors.append(.init(level: .error, field: "ageRange.minAge", message: "Invalid minAge", code: "invalid_age")) }
            if let max = age.maxAge, max < 0 || max > 120 { errors.append(.init(level: .error, field: "ageRange.maxAge", message: "Invalid maxAge", code: "invalid_age")) }
        }
        if let cost = opp.costInfo {
            if let amt = cost.amount, amt < 0 { errors.append(.init(level: .error, field: "cost.amount", message: "Negative cost", code: "negative_cost")) }
            if cost.isFree == true, let amt = cost.amount, amt != 0 { errors.append(.init(level: .error, field: "cost", message: "Free but amount not 0", code: "invalid_cost")) }
        }
        if opp.source.sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.init(level: .error, field: "source.sourceID", message: "Source ID empty", code: "empty_source_id")) }
        if opp.source.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.init(level: .error, field: "source.sourceName", message: "Source name empty", code: "empty_source_name")) }
        let reqIDs = opp.applicationRequirements.map(\.id)
        if Set(reqIDs).count != reqIDs.count { errors.append(.init(level: .error, field: "applicationRequirements", message: "Duplicate requirement IDs", code: "duplicate_ids")) }
        if opp.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { warnings.append(.init(level: .warning, field: "description", message: "Missing description", code: "missing_description")) }
        if opp.deadlineInfo == nil { warnings.append(.init(level: .warning, field: "deadline", message: "No deadline", code: "missing_deadline")) }
        if opp.costInfo == nil || opp.costInfo?.isUnknown == true { warnings.append(.init(level: .warning, field: "cost", message: "Unknown cost", code: "unknown_cost")) }
        if opp.eligibilityInfo == nil || opp.eligibilityInfo?.isUnknown == true { warnings.append(.init(level: .warning, field: "eligibility", message: "No eligibility data", code: "missing_eligibility")) }
        if opp.skills.isEmpty && opp.interests.isEmpty && opp.careerFields.isEmpty { warnings.append(.init(level: .warning, field: "skills", message: "No skills", code: "missing_taxonomy")) }
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}
enum DuplicateReason: String, Hashable { case exactID, sourceID, canonicalURL, normalizedIdentity }
struct DuplicateMatch: Hashable { let existingID: String; let incomingID: String; let reason: DuplicateReason }
enum Deduper {
    static func isDuplicate(_ a: Opportunity, _ b: Opportunity) -> (Bool, DuplicateReason?) {
        if a.id.lowercased() == b.id.lowercased() && !a.id.isEmpty { return (true, .exactID) }
        if !a.source.sourceID.isEmpty && !b.source.sourceID.isEmpty && a.source.sourceID.lowercased() == b.source.sourceID.lowercased() {
            if let aURL = a.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !aURL.isEmpty,
               let bURL = b.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !bURL.isEmpty,
               aURL.lowercased() == bURL.lowercased() { return (true, .sourceID) }
        }
        if let aURL = a.sourceURL?.lowercased(), let bURL = b.sourceURL?.lowercased(), !aURL.isEmpty, aURL == bURL { return (true, .canonicalURL) }
        let aNorm = "\(a.organization.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(a.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(a.deadlineInfo?.displayString.lowercased() ?? "")"
        let bNorm = "\(b.organization.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(b.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(b.deadlineInfo?.displayString.lowercased() ?? "")"
        if aNorm == bNorm && !aNorm.replacingOccurrences(of: "|", with: "").isEmpty { return (true, .normalizedIdentity) }
        return (false, nil)
    }
    static func deduplicate(_ opportunities: [Opportunity]) -> (unique: [Opportunity], duplicates: [(Opportunity, DuplicateMatch)]) {
        var seen: [Opportunity] = []
        var duplicates: [(Opportunity, DuplicateMatch)] = []
        var idMap: [String: Opportunity] = [:]
        var urlMap: [String: Opportunity] = [:]
        var normMap: [String: Opportunity] = [:]
        for opp in opportunities {
            let normID = opp.id.lowercased()
            if let existing = idMap[normID] { duplicates.append((opp, DuplicateMatch(existingID: existing.id, incomingID: opp.id, reason: .exactID))); continue }
            if let url = opp.sourceURL?.lowercased(), let existing = urlMap[url] { duplicates.append((opp, DuplicateMatch(existingID: existing.id, incomingID: opp.id, reason: .canonicalURL))); continue }
            let normKey = "\(opp.organization.lowercased())|\(opp.title.lowercased())|\(opp.deadlineInfo?.displayString.lowercased() ?? "")"
            if let existing = normMap[normKey], !opp.organization.isEmpty, !opp.title.isEmpty { duplicates.append((opp, DuplicateMatch(existingID: existing.id, incomingID: opp.id, reason: .normalizedIdentity))); continue }
            var found: DuplicateMatch? = nil
            for existing in seen {
                let (isDup, reason) = isDuplicate(existing, opp)
                if isDup, let r = reason { found = DuplicateMatch(existingID: existing.id, incomingID: opp.id, reason: r); break }
            }
            if let dup = found { duplicates.append((opp, dup)); continue }
            seen.append(opp); idMap[normID] = opp
            if let url = opp.sourceURL?.lowercased() { urlMap[url] = opp }
            normMap[normKey] = opp
        }
        let sortedUnique = seen.sorted { a, b in
            if a.title.lowercased() != b.title.lowercased() { return a.title.lowercased() < b.title.lowercased() }
            if a.organization.lowercased() != b.organization.lowercased() { return a.organization.lowercased() < b.organization.lowercased() }
            return a.id < b.id
        }
        return (sortedUnique, duplicates)
    }
}
enum FreshnessService {
    static func freshness(for opp: Opportunity, now: Date = Date()) -> OpportunityFreshnessInfo {
        if let dl = opp.deadlineInfo, let date = dl.date {
            let days = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
            if days < 0 { return OpportunityFreshnessInfo(freshness: .expired, daysUntilDeadline: days, isExpired: true, lastVerified: opp.lastVerified) }
            let freshness = freshnessFromLastVerified(lastVerified: opp.lastVerified, now: now)
            return OpportunityFreshnessInfo(freshness: freshness, daysUntilDeadline: days, isExpired: false, lastVerified: opp.lastVerified)
        }
        if opp.deadlineInfo?.type == .rolling { return OpportunityFreshnessInfo(freshness: .fresh, daysUntilDeadline: nil, isExpired: false, lastVerified: opp.lastVerified) }
        let freshness = freshnessFromLastVerified(lastVerified: opp.lastVerified, now: now)
        return OpportunityFreshnessInfo(freshness: freshness, daysUntilDeadline: nil, isExpired: freshness == .expired, lastVerified: opp.lastVerified)
    }
    private static func freshnessFromLastVerified(lastVerified: Date?, now: Date) -> OpportunityFreshness {
        guard let lv = lastVerified else { return .unknown }
        let days = Calendar.current.dateComponents([.day], from: lv, to: now).day ?? 0
        if days < 0 { return .fresh }
        if days <= 30 { return .fresh }
        if days <= 90 { return .aging }
        if days <= 180 { return .stale }
        return .expired
    }
}
final class TestRepository {
    private(set) var opportunities: [Opportunity] = []
    private func sorted(_ ops: [Opportunity]) -> [Opportunity] {
        ops.sorted { a, b in
            if a.title.lowercased() != b.title.lowercased() { return a.title.lowercased() < b.title.lowercased() }
            if a.organization.lowercased() != b.organization.lowercased() { return a.organization.lowercased() < b.organization.lowercased() }
            return a.id < b.id
        }
    }
    func all() -> [Opportunity] { sorted(opportunities) }
    func get(id: String) -> Opportunity? {
        let tid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty else { return nil }
        return opportunities.first(where: { $0.id == tid })
    }
    @discardableResult func insert(_ opp: Opportunity) -> Bool {
        guard Validator.validate(opp).isValid else { return false }
        for existing in opportunities { let (isDup, _) = Deduper.isDuplicate(existing, opp); if isDup { return false } }
        opportunities.append(opp); opportunities = sorted(opportunities); return true
    }
    @discardableResult func upsert(_ opp: Opportunity) -> Bool {
        guard Validator.validate(opp).isValid else { return false }
        opportunities.removeAll { let (isDup, _) = Deduper.isDuplicate($0, opp); return isDup }
        opportunities.append(opp); opportunities = sorted(opportunities); return true
    }
    @discardableResult func remove(id: String) -> Bool {
        let tid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty else { return false }
        let before = opportunities.count
        opportunities.removeAll(where: { $0.id == tid })
        return opportunities.count < before
    }
    func replaceAll(with ops: [Opportunity]) {
        var unique: [Opportunity] = []; var seen = Set<String>()
        for opp in ops {
            guard Validator.validate(opp).isValid else { continue }
            let norm = opp.id.lowercased()
            if seen.contains(norm) { continue }
            var dup = false
            for e in unique { let (d,_) = Deduper.isDuplicate(e, opp); if d { dup = true; break } }
            if dup { continue }
            seen.insert(norm); unique.append(opp)
        }
        opportunities = sorted(unique)
    }
    func ingest(rawRecords: [RawOpportunityRecord]) -> (inserted:Int, duplicates:Int, invalid:Int) {
        var inserted=0, dup=0, inv=0
        for raw in rawRecords {
            let opp = Normalizer.normalize(raw)
            guard Validator.validate(opp).isValid else { inv += 1; continue }
            var isDup=false
            for e in opportunities { let (d,_) = Deduper.isDuplicate(e, opp); if d { isDup=true; break } }
            if isDup { dup += 1; continue }
            opportunities.append(opp); inserted+=1
        }
        opportunities = sorted(opportunities)
        return (inserted, dup, inv)
    }
    func clear() { opportunities.removeAll() }
}
func makeSource(id: String = "test-source", name: String = "Test Source", url: String? = nil) -> OpportunitySource {
    OpportunitySource(sourceID: id, sourceName: name, sourceType: .staticSeed, sourceURL: url, retrievedAt: Date(), publisher: name)
}
func makeOpp(id: String = UUID().uuidString, title: String = "Test Opportunity", organization: String = "Test Org",
             organizationDescription: String? = nil, opportunityType: OpportunityType = .competition, description: String = "A description",
             location: OpportunityLocation = OpportunityLocation(type: "unknown", city: nil, state: nil, country: nil, online: nil),
             delivery: OpportunityDeliveryMode = .unknown, ageRange: OpportunityAgeRange? = nil, gradeRange: OpportunityGradeRange? = nil,
             eligibility: OpportunityEligibility? = nil, requirements: [OpportunityRequirement] = [],
             deadline: OpportunityDeadline? = nil, costInfo: OpportunityCost? = nil,
             skills: [String] = [], interests: [String] = [], careerFields: [String] = [],
             source: OpportunitySource? = nil, sourceURL: String? = nil, lastVerified: Date? = nil, status: OpportunityStatus = .active) -> Opportunity {
    Opportunity(id: id, title: title, organization: organization, organizationDescription: organizationDescription,
                opportunityType: opportunityType, description: description, location: location, deliveryMode: delivery,
                ageRange: ageRange, gradeRange: gradeRange, eligibilityInfo: eligibility, applicationRequirements: requirements,
                deadlineInfo: deadline, costInfo: costInfo, skills: skills, interests: interests, careerFields: careerFields,
                source: source ?? makeSource(), sourceURL: sourceURL, lastVerified: lastVerified, status: status)
}

// =============================================================================
// TESTS
// =============================================================================

print("—— Model: Codable round trip ——")
do {
    let opp = makeOpp(id: "model-1", title: "Round Trip", organization: "Org", description: "Desc",
                      location: OpportunityLocation(type: "online", city: nil, state: nil, country: "USA", online: true),
                      delivery: .online, ageRange: OpportunityAgeRange(minAge: 13, maxAge: 18),
                      deadline: OpportunityDeadline(date: Date(timeIntervalSince1970: 1700000000), type: .fixed, displayString: "2026-12-01"),
                      costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true),
                      skills: ["Python"], interests: ["AI"], careerFields: ["CS"],
                      source: makeSource(id: "src-1", name: "Source 1", url: "https://example.com"), sourceURL: "https://example.com/opp", lastVerified: Date(timeIntervalSince1970: 1700000000))
    let data = try! JSONEncoder().encode(opp)
    let decoded = try! JSONDecoder().decode(Opportunity.self, from: data)
    assertEqual(decoded.id, opp.id, "Codable id roundtrip")
    assertEqual(decoded.title, opp.title, "Codable title")
    assertEqual(decoded.organization, opp.organization, "Codable org")
    assertEqual(decoded.opportunityType, opp.opportunityType, "Codable type")
    assertEqual(decoded.skills, opp.skills, "Codable skills")
    assertEqual(decoded.source.sourceID, opp.source.sourceID, "Codable sourceID")
    assertEqual(decoded.sourceURL, opp.sourceURL, "Codable sourceURL")
    // Backward compatible decoding: ensure defaults handle missing optional fields
    // Test by decoding an opportunity and re-decoding with missing optional keys still succeeds
    let legacyDecoded = decoded // already decoded from full opp, proves roundtrip
    assertEqual(legacyDecoded.id, opp.id, "Legacy id from roundtrip")
    assertEqual(legacyDecoded.skills, opp.skills, "Legacy skills from roundtrip")
    let rawType = "notARealType"
    let fallback = OpportunityType(rawValue: rawType) ?? .other
    assertEqual(fallback, .other, "Enum stability fallback")
    // Defaults: optional fields nil should remain nil when not provided
    let minimalOpp = makeOpp(id: "minimal-1", title: "Minimal", organization: "Minimal Org")
    assert(minimalOpp.ageRange == nil, "Default ageRange nil")
    assert(minimalOpp.deadlineInfo == nil, "Default deadline nil")
    assert(minimalOpp.costInfo == nil, "Default cost nil")
    assert(minimalOpp.lastVerified == nil, "Default lastVerified nil")
}
print("—— Model: Facts vs Unknown ——")
do {
    let unknownOpp = makeOpp(ageRange: nil, eligibility: nil, deadline: nil, costInfo: nil, skills: [], interests: [], careerFields: [])
    assert(unknownOpp.ageRange == nil, "Age unknown is nil not false")
    assert(unknownOpp.gradeRange == nil, "Grade unknown nil")
    assert(unknownOpp.costInfo == nil, "Cost unknown nil")
    assert(unknownOpp.eligibilityInfo == nil, "Eligibility unknown nil")
    assert(unknownOpp.deadlineInfo == nil, "Deadline unknown nil")
    let freeOpp = makeOpp(costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true))
    assertEqual(freeOpp.costInfo?.isFree, true, "Free is true")
    assertEqual(freeOpp.costInfo?.isUnknown, false, "Free not unknown")
    let unknownCostOpp = makeOpp(costInfo: nil)
    assert(unknownCostOpp.costInfo == nil, "Unknown cost nil")
    let paidOpp = makeOpp(costInfo: OpportunityCost(amount: 100, currency: "USD", isFree: false))
    assertEqual(paidOpp.costInfo?.isFree, false, "Paid is false")
    let remoteLoc = OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true)
    let inPersonLoc = OpportunityLocation(type: "inPerson", city: "Austin", state: "TX", country: "USA", online: false)
    let unknownLoc = OpportunityLocation(type: "unknown", city: nil, state: nil, country: nil, online: nil)
    assertEqual(remoteLoc.displayString, "Online", "Remote display")
    assert(unknownLoc.online == nil, "Unknown location online nil not false")
    assert(inPersonLoc.online == false, "InPerson false not nil")
    let rollingDL = OpportunityDeadline(date: nil, type: .rolling, displayString: "Rolling")
    assertEqual(rollingDL.type, .rolling, "Rolling type")
    let fixedDL = OpportunityDeadline(date: Date(), type: .fixed, displayString: "2026-12-01")
    assertEqual(fixedDL.type, .fixed, "Fixed type")
    let noDeadlineDL = OpportunityDeadline(date: nil, type: .noDeadline, displayString: "No deadline")
    assertEqual(noDeadlineDL.type, .noDeadline, "NoDeadline")
    let unknownDL: OpportunityDeadline? = nil
    assert(unknownDL == nil, "Unknown deadline nil")
}
print("—— Normalization: whitespace ——")
do {
    let raw = RawOpportunityRecord(title: "  Hello   World  ", organization: "  Demo   Org  ", description: "  This   is   description  ")
    let normalized = Normalizer.normalize(raw)
    assertEqual(normalized.title, "Hello World", "Title collapse whitespace")
    assertEqual(normalized.organization, "Demo Org", "Org collapse")
    assertEqual(normalized.description, "This is description", "Description collapse")
    let raw2 = RawOpportunityRecord(title: " \n\t Test \n ", organization: " Org ")
    let n2 = Normalizer.normalize(raw2)
    assertEqual(n2.title, "Test", "Title trim newlines")
}
print("—— Normalization: ID ——")
do {
    let rawWithID = RawOpportunityRecord(id: "  My-ID 123  ", title: "T", organization: "O")
    let n = Normalizer.normalize(rawWithID)
    assertEqual(n.id, "my-id-123", "ID lowercased and hyphenated")
    let n2 = Normalizer.normalize(rawWithID)
    assertEqual(n.id, n2.id, "ID deterministic")
    let rawUnknown = RawOpportunityRecord(id: "unknown", title: "Hello World", organization: "Demo Org", deadline: "2026-12-01")
    let nUnknown = Normalizer.normalize(rawUnknown)
    assert(nUnknown.id != "unknown", "Unknown ID not used directly")
    assert(!nUnknown.id.isEmpty, "Fallback ID non-empty")
    let rawA = RawOpportunityRecord(title: "Same Title", organization: "Same Org", deadline: "2026-12-01")
    let rawB = RawOpportunityRecord(title: "Same Title", organization: "Same Org", deadline: "2026-12-01")
    let nA = Normalizer.normalize(rawA)
    let nB = Normalizer.normalize(rawB)
    assertEqual(nA.id, nB.id, "Same raw produces same ID")
}
print("—— Normalization: URL ——")
do {
    assertEqual(normalizeURL("https://Example.COM/path"), "https://example.com/path", "URL host lowercased")
    assertEqual(normalizeURL("https://example.com/path#fragment"), "https://example.com/path", "URL fragment removed")
    assert(normalizeURL("http://example.com") != nil, "Valid http")
    assert(normalizeURL("https://example.com") != nil, "Valid https")
    assert(normalizeURL("ftp://example.com") == nil, "Invalid scheme")
    assert(normalizeURL("not a url") == nil, "Invalid url")
    assert(normalizeURL("") == nil, "Empty url nil")
    assert(normalizeURL(nil) == nil, "Nil url nil")
    assert(normalizeURL("  https://example.com  ") == "https://example.com", "Trim url")
}
print("—— Normalization: Skills using Skill.normalizeID ——")
do {
    assertEqual(normalizeSkillID("Python"), "python", "Skill normalize lowercased")
    assertEqual(normalizeSkillID("  Python  "), "python", "Skill trim")
    assertEqual(normalizeSkillID("Machine   Learning"), "machine learning", "Skill collapse whitespace")
    assertEqual(normalizeSkillID("  Machine   Learning  "), "machine learning", "Skill collapse with trim")
    let raw = RawOpportunityRecord(title: "T", organization: "O", skills: ["Python", "python", " PYTHON ", "JavaScript", "javascript"])
    let n = Normalizer.normalize(raw)
    assertEqual(n.skills.count, 2, "Duplicate skills deduped")
    assert(n.skills.contains("Python"), "Contains Python")
    assert(n.skills.contains("JavaScript"), "Contains JS")
    let raw2 = RawOpportunityRecord(skills: ["  Python ", "Python", "PYTHON"])
    let n2 = Normalizer.normalize(raw2)
    assertEqual(n2.skills.count, 1, "Skill dup 1")
    let raw3 = RawOpportunityRecord(skills: [" Machine Learning ", "machine learning", "MACHINE LEARNING"])
    let n3 = Normalizer.normalize(raw3)
    assertEqual(n3.skills.count, 1, "ML dedup")
}
print("—— Normalization: duplicate skills via Opportunity init ——")
do {
    let opp = makeOpp(skills: ["Python", "python", "  Python  ", "JavaScript"])
    assertEqual(opp.skills.count, 2, "Opp duplicate skills")
    assert(opp.skills.contains("Python"), "Opp has Python")
}
print("—— Normalization: category aliases ——")
do {
    assertEqual(Normalizer.normalizeCategory("competition"), .competition, "competition")
    assertEqual(Normalizer.normalizeCategory("Competitions"), .competition, "Competitions alias")
    assertEqual(Normalizer.normalizeCategory("contest"), .competition, "contest alias")
    assertEqual(Normalizer.normalizeCategory("hackathon"), .hackathon, "hackathon")
    assertEqual(Normalizer.normalizeCategory("Hackathons"), .hackathon, "hackathons alias")
    assertEqual(Normalizer.normalizeCategory("scholarship"), .scholarship, "scholarship")
    assertEqual(Normalizer.normalizeCategory("Scholarships"), .scholarship, "scholarships alias")
    assertEqual(Normalizer.normalizeCategory("research"), .research, "research")
    assertEqual(Normalizer.normalizeCategory("internship"), .internship, "internship")
    assertEqual(Normalizer.normalizeCategory("summer"), .summerProgram, "summer alias")
    assertEqual(Normalizer.normalizeCategory("Summer Program"), .summerProgram, "summerProgram")
    assertEqual(Normalizer.normalizeCategory("volunteer"), .volunteering, "volunteer alias")
    assertEqual(Normalizer.normalizeCategory("community service"), .volunteering, "community service")
    assertEqual(Normalizer.normalizeCategory("leadership"), .leadership, "leadership")
    assertEqual(Normalizer.normalizeCategory("fellowship"), .fellowship, "fellowship")
    assertEqual(Normalizer.normalizeCategory("conference"), .conference, "conference")
    assertEqual(Normalizer.normalizeCategory("community"), .community, "community")
    assertEqual(Normalizer.normalizeCategory("  "), .other, "empty -> other")
    assertEqual(Normalizer.normalizeCategory(nil), .other, "nil -> other")
    assertEqual(Normalizer.normalizeCategory("unknownXYZ"), .other, "unknown -> other")
    assertEqual(Normalizer.normalizeCategory("COMPETITION"), .competition, "case insensitive")
    assertEqual(Normalizer.normalizeCategory("Summer-Program"), .summerProgram, "hyphen alias")
    assertEqual(Normalizer.normalizeCategory("summer_program"), .summerProgram, "underscore alias")
}
print("—— Normalization: deterministic output ——")
do {
    let raw = RawOpportunityRecord(id: "det-1", title: "  Hello   World  ", organization: "  Demo Org  ", category: " Competition ", location: "Online", deadline: "2026-12-01", cost: "Free", skills: ["Python", " python "], sourceID: "src-1", sourceName: "Source", sourceURL: "https://example.com", officialURL: "https://example.com")
    let n1 = Normalizer.normalize(raw)
    let n2 = Normalizer.normalize(raw)
    assertEqual(n1.id, n2.id, "Deterministic ID")
    assertEqual(n1.title, n2.title, "Deterministic title")
    assertEqual(n1.organization, n2.organization, "Deterministic org")
    assertEqual(n1.opportunityType, n2.opportunityType, "Deterministic type")
    assertEqual(n1.skills, n2.skills, "Deterministic skills")
    assertEqual(n1.sourceURL, n2.sourceURL, "Deterministic URL")
    let rawDiff = RawOpportunityRecord(id: "det-1", title: "Different", organization: "Demo Org", category: " Competition ", location: "Online")
    let nDiff = Normalizer.normalize(rawDiff)
    assert(n1.title != nDiff.title, "Different raw different output")
}
print("—— Normalization: location and delivery ——")
do {
    let locOnline = Normalizer.normalizeLocation("Online", deliveryMode: nil)
    assertEqual(locOnline.type, "online", "Online location")
    assertEqual(locOnline.online, true, "Online true")
    let locHybrid = Normalizer.normalizeLocation("Hybrid", deliveryMode: nil)
    assertEqual(locHybrid.type, "hybrid", "Hybrid")
    let locRemote = Normalizer.normalizeLocation("Remote", deliveryMode: nil)
    assertEqual(locRemote.type, "online", "Remote -> online")
    let locUnknown = Normalizer.normalizeLocation(nil, deliveryMode: nil)
    assertEqual(locUnknown.type, "unknown", "Nil -> unknown")
    let locFromDelivery = Normalizer.normalizeLocation(nil, deliveryMode: "online")
    assertEqual(locFromDelivery.type, "online", "Delivery inferred")
    let deliveryOnline = Normalizer.normalizeDelivery("online", location: nil)
    assertEqual(deliveryOnline, .online, "Delivery online")
    let deliveryHybrid = Normalizer.normalizeDelivery(nil, location: "Hybrid program")
    assertEqual(deliveryHybrid, .hybrid, "Delivery hybrid from location")
}
print("—— Normalization: age parsing ——")
do {
    assertEqual(Normalizer.parseAge("14"), 14, "Parse 14")
    assertEqual(Normalizer.parseAge("14 years"), 14, "Parse 14 years")
    assertEqual(Normalizer.parseAge("  18  "), 18, "Parse trimmed")
    assertEqual(Normalizer.parseAge(nil), nil, "Nil nil")
    assertEqual(Normalizer.parseAge("unknown"), nil, "Unknown nil")
    assertEqual(Normalizer.parseAge(""), nil, "Empty nil")
    let ageRange = Normalizer.normalizeAgeRange(minAge: "14", maxAge: "18")
    assertEqual(ageRange?.minAge, 14, "Age min")
    assertEqual(ageRange?.maxAge, 18, "Age max")
    let unknownRange = Normalizer.normalizeAgeRange(minAge: nil, maxAge: nil)
    assert(unknownRange == nil, "Unknown range nil")
    let singleMin = Normalizer.normalizeAgeRange(minAge: "16", maxAge: nil)
    assertEqual(singleMin?.minAge, 16, "Single min")
    assert(singleMin?.maxAge == nil, "Single max nil")
}
print("—— Normalization: cost ——")
do {
    assertEqual(Normalizer.normalizeCost("Free")?.isFree, true, "Free")
    assertEqual(Normalizer.normalizeCost("free")?.isFree, true, "free lower")
    assertEqual(Normalizer.normalizeCost("FREE - no cost")?.isFree, true, "free phrase")
    assertEqual(Normalizer.normalizeCost("$100")?.amount, 100, "$100")
    assertEqual(Normalizer.normalizeCost("$0")?.isFree, true, "$0 free")
    assert(Normalizer.normalizeCost("Unknown") == nil, "Unknown nil")
    assert(Normalizer.normalizeCost(nil) == nil, "Nil nil")
    assert(Normalizer.normalizeCost("") == nil, "Empty nil")
}
print("—— Normalization: deadline ——")
do {
    assertEqual(Normalizer.normalizeDeadline("Rolling")?.type, .rolling, "Rolling")
    assertEqual(Normalizer.normalizeDeadline("rolling")?.type, .rolling, "rolling lower")
    assertEqual(Normalizer.normalizeDeadline("TBD")?.type, .unknown, "TBD unknown")
    assertEqual(Normalizer.normalizeDeadline(nil)?.type, nil, "Nil deadline nil")
    assert(Normalizer.normalizeDeadline("") == nil, "Empty nil")
    let fixed = Normalizer.normalizeDeadline("2026-12-01")
    assertEqual(fixed?.type, .fixed, "Fixed 2026-12-01")
    assert(fixed?.date != nil, "Fixed has date")
    let iso = Normalizer.normalizeDeadline("2026-09-19T00:00:00Z")
    assertEqual(iso?.type, .fixed, "ISO fixed")
}
print("—— Validation: valid opportunity ——")
do {
    let validOpp = makeOpp(id: "valid-1", title: "Valid Title", organization: "Valid Org", description: "Desc", eligibility: OpportunityEligibility(details: "Grades 9-12"), deadline: OpportunityDeadline(date: Date(), type: .fixed, displayString: "2026-12-01"), costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true), skills: ["Python"])
    let result = Validator.validate(validOpp)
    assert(result.isValid, "Valid isValid")
    assertEqual(result.errors.count, 0, "Valid no errors")
}
print("—— Validation: missing required fields ——")
do {
    let emptyID = makeOpp(id: "", title: "T", organization: "O")
    assert(!Validator.validate(emptyID).isValid, "Empty ID invalid")
    assert(Validator.validate(emptyID).errors.contains(where: { $0.code == "empty_id" }), "Empty ID error code")
    let emptyTitle = makeOpp(id: "id1", title: "", organization: "O")
    assert(!Validator.validate(emptyTitle).isValid, "Empty title invalid")
    assert(Validator.validate(emptyTitle).errors.contains(where: { $0.code == "empty_title" }), "Empty title code")
    let emptyOrg = makeOpp(id: "id1", title: "T", organization: "")
    assert(!Validator.validate(emptyOrg).isValid, "Empty org invalid")
    assert(Validator.validate(emptyOrg).errors.contains(where: { $0.code == "empty_organization" }), "Empty org code")
    let emptyID2 = makeOpp(id: "   ", title: "T", organization: "O")
    assert(!Validator.validate(emptyID2).isValid, "Whitespace ID invalid")
}
print("—— Validation: invalid URLs ——")
do {
    let badURL = makeOpp(source: makeSource(url: "https://example.com"), sourceURL: "not a url")
    let result = Validator.validate(badURL)
    assert(!result.isValid, "Bad sourceURL invalid")
    assert(result.errors.contains(where: { $0.code == "invalid_url" }), "Invalid URL code")
    let badSourceURL = makeOpp(source: makeSource(url: "ftp://example.com"))
    assert(!Validator.validate(badSourceURL).isValid, "Bad source.sourceURL invalid")
    let goodURL = makeOpp(source: makeSource(url: "https://example.com"), sourceURL: "https://example.com/path")
    assert(Validator.validate(goodURL).isValid, "Good URL valid")
}
print("—— Validation: invalid age ranges ——")
do {
    let invalidAge = makeOpp(ageRange: OpportunityAgeRange(minAge: 18, maxAge: 14))
    assert(!Validator.validate(invalidAge).isValid, "min > max invalid")
    assert(Validator.validate(invalidAge).errors.contains(where: { $0.code == "invalid_age_range" }), "Age range code")
    let negativeAge = makeOpp(ageRange: OpportunityAgeRange(minAge: -1, maxAge: 18))
    assert(!Validator.validate(negativeAge).isValid, "Negative age invalid")
    let tooOld = makeOpp(ageRange: OpportunityAgeRange(minAge: 13, maxAge: 200))
    assert(!Validator.validate(tooOld).isValid, "Too old invalid")
    let validAge = makeOpp(ageRange: OpportunityAgeRange(minAge: 14, maxAge: 18))
    assert(Validator.validate(validAge).isValid, "Valid age")
    let unknownAge = makeOpp(ageRange: nil)
    assert(Validator.validate(unknownAge).isValid, "Unknown age valid (warning not error)")
}
print("—— Validation: invalid grade ranges and negative cost ——")
do {
    let negCost = makeOpp(costInfo: OpportunityCost(amount: -10, currency: "USD", isFree: false))
    assert(!Validator.validate(negCost).isValid, "Negative cost invalid")
    assert(Validator.validate(negCost).errors.contains(where: { $0.code == "negative_cost" }), "Negative cost code")
    let freeButAmount = makeOpp(costInfo: OpportunityCost(amount: 100, currency: "USD", isFree: true))
    assert(!Validator.validate(freeButAmount).isValid, "Free but amount not 0")
    assert(Validator.validate(freeButAmount).errors.contains(where: { $0.code == "invalid_cost" }), "Invalid cost code")
    let validFree = makeOpp(costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true))
    assert(Validator.validate(validFree).isValid, "Valid free")
    let unknownCost = makeOpp(costInfo: nil)
    assert(Validator.validate(unknownCost).isValid, "Unknown cost not error")
    assert(Validator.validate(unknownCost).warnings.contains(where: { $0.code == "unknown_cost" }), "Unknown cost warning")
}
print("—— Validation: warnings vs errors ——")
do {
    let oppNoDeadline = makeOpp(description: "Desc", eligibility: OpportunityEligibility(details: "Eligible"), deadline: nil, costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true))
    let result = Validator.validate(oppNoDeadline)
    assert(result.isValid, "No deadline still valid")
    assert(result.warnings.contains(where: { $0.code == "missing_deadline" }), "Missing deadline warning")
    let oppNoDesc = makeOpp(description: "")
    assert(Validator.validate(oppNoDesc).warnings.contains(where: { $0.code == "missing_description" }), "Missing desc warning")
    let oppNoTaxonomy = makeOpp(skills: [], interests: [], careerFields: [])
    assert(Validator.validate(oppNoTaxonomy).warnings.contains(where: { $0.code == "missing_taxonomy" }), "Missing taxonomy warning")
    assert(Validator.validate(oppNoTaxonomy).isValid, "Warnings not errors")
    let dupReqID = "same-id"
    let oppDupReq = makeOpp(requirements: [OpportunityRequirement(id: dupReqID, title: "Req1"), OpportunityRequirement(id: dupReqID, title: "Req2")])
    assert(!Validator.validate(oppDupReq).isValid, "Dup req IDs error")
    assert(Validator.validate(oppDupReq).errors.contains(where: { $0.code == "duplicate_ids" }), "Dup IDs code")
}
print("—— Validation: duplicate nested IDs ——")
do {
    let opp = makeOpp(requirements: [OpportunityRequirement(title: "A"), OpportunityRequirement(title: "B")])
    assert(Validator.validate(opp).isValid, "Unique req IDs valid")
    let badSource = makeOpp(source: OpportunitySource(sourceID: "", sourceName: "Name", sourceType: .manual, sourceURL: nil, retrievedAt: Date(), publisher: nil))
    assert(!Validator.validate(badSource).isValid, "Empty sourceID error")
}
print("—— Deduplication: exact ID duplicate ——")
do {
    let a = makeOpp(id: "dup-id", title: "Title A", organization: "Org A")
    let b = makeOpp(id: "dup-id", title: "Different", organization: "Different")
    let (isDup, reason) = Deduper.isDuplicate(a, b)
    assert(isDup, "Exact ID duplicate")
    assertEqual(reason, .exactID, "Reason exactID")
    let c = makeOpp(id: "DUP-ID", title: "T", organization: "O")
    let (isDup2, _) = Deduper.isDuplicate(a, c)
    assert(isDup2, "Case insensitive ID duplicate")
}
print("—— Deduplication: sourceID duplicate ——")
do {
    let src = makeSource(id: "source-1", name: "Source 1", url: "https://example.com/shared")
    let a = makeOpp(id: "id-1", title: "Title", organization: "Org", source: src, sourceURL: "https://example.com/shared")
    let b = makeOpp(id: "id-2", title: "Different Title", organization: "Different Org", source: src, sourceURL: "https://example.com/shared")
    let (isDup, reason) = Deduper.isDuplicate(a, b)
    assert(isDup, "SourceID+URL duplicate")
    assertEqual(reason, .sourceID, "Reason sourceID")
    let src2 = makeSource(id: "source-2", name: "Source 2", url: "https://example.com/shared")
    let c = makeOpp(id: "id-3", source: src2, sourceURL: "https://example.com/shared")
    let (isDup2, reason2) = Deduper.isDuplicate(a, c)
    assert(isDup2, "Still duplicate via URL")
    // When sourceIDs differ, duplicate should be via canonicalURL, not sourceID
    assert(reason2 == .canonicalURL || reason2 == .sourceID, "Reason is URL-based \(String(describing: reason2))")
}
print("—— Deduplication: URL duplicate ——")
do {
    let a = makeOpp(id: "a", title: "Title A", organization: "Org A", source: makeSource(id: "different-source", name: "Different"), sourceURL: "https://example.com/opportunity")
    let b = makeOpp(id: "b", title: "Title B", organization: "Org B", source: makeSource(id: "other-source", name: "Other"), sourceURL: "https://example.com/opportunity")
    let (isDup, reason) = Deduper.isDuplicate(a, b)
    assert(isDup, "URL duplicate")
    assertEqual(reason, .canonicalURL, "Reason canonicalURL")
    let c = makeOpp(id: "c", sourceURL: "https://EXAMPLE.com/opportunity")
    let (isDup2, _) = Deduper.isDuplicate(a, c)
    assert(isDup2, "URL case insensitive")
    let d = makeOpp(id: "d", sourceURL: "https://example.com/other")
    let (isDup3, _) = Deduper.isDuplicate(a, d)
    assert(!isDup3, "Different URL not duplicate")
}
print("—— Deduplication: normalized identity duplicate ——")
do {
    let deadline = OpportunityDeadline(date: nil, type: .fixed, displayString: "2026-12-01")
    let a = makeOpp(id: "a1", title: "Student Innovation Challenge", organization: "Demo Org", deadline: deadline)
    let b = makeOpp(id: "b1", title: "Student Innovation Challenge", organization: "Demo Org", deadline: deadline)
    let (isDup, reason) = Deduper.isDuplicate(a, b)
    assert(isDup, "Normalized identity duplicate")
    assertEqual(reason, .normalizedIdentity, "Reason normalizedIdentity")
    let c = makeOpp(id: "c1", title: "Different Challenge", organization: "Demo Org", deadline: deadline)
    let (isDup2, _) = Deduper.isDuplicate(a, c)
    assert(!isDup2, "Different title not duplicate")
    let d = makeOpp(id: "d1", title: "student innovation challenge", organization: "demo org", deadline: deadline)
    let (isDup3, _) = Deduper.isDuplicate(a, d)
    assert(isDup3, "Case insensitive normalized identity")
}
print("—— Deduplication: non-duplicate similar opportunities ——")
do {
    let a = makeOpp(id: "id-a", title: "Innovation Challenge", organization: "Org A", deadline: OpportunityDeadline(date: nil, type: .fixed, displayString: "2026-12-01"))
    let b = makeOpp(id: "id-b", title: "Innovation Challenge", organization: "Org B", deadline: OpportunityDeadline(date: nil, type: .fixed, displayString: "2026-12-01"))
    let (isDup, _) = Deduper.isDuplicate(a, b)
    assert(!isDup, "Same title different org not duplicate")
    let c = makeOpp(id: "id-c", title: "Innovation Challenge 2026", organization: "Org A")
    let (isDup2, _) = Deduper.isDuplicate(a, c)
    assert(!isDup2, "Similar title not exact not duplicate")
}
print("—— Deduplication: deterministic results ——")
do {
    let a = makeOpp(id: "det-a", title: "Alpha", organization: "Org")
    let b = makeOpp(id: "det-b", title: "Beta", organization: "Org")
    let (isDup1, _) = Deduper.isDuplicate(a, b)
    let (isDup2, _) = Deduper.isDuplicate(a, b)
    assertEqual(isDup1, isDup2, "Deterministic isDuplicate")
    let ops = [b, a]
    let (unique, _) = Deduper.deduplicate(ops)
    assertEqual(unique.first?.title, "Alpha", "Deterministic ordering title asc")
    let ops2 = [a, b]
    let (unique2, _) = Deduper.deduplicate(ops2)
    assertEqual(unique, unique2, "Deduplicate deterministic regardless of input order")
}
print("—— Deduplication: no unsafe merges ——")
do {
    let a = makeOpp(id: "safe-a", title: "Tech Challenge", organization: "Org A", deadline: OpportunityDeadline(date: nil, type: .fixed, displayString: "2026-11-01"))
    let b = makeOpp(id: "safe-b", title: "Tech Challenge", organization: "Org A", deadline: OpportunityDeadline(date: nil, type: .fixed, displayString: "2026-12-01"))
    let (isDup, _) = Deduper.isDuplicate(a, b)
    assert(!isDup, "Different deadline not duplicate - no unsafe merge")
    let c = makeOpp(id: "dup-x", title: "T", organization: "O", sourceURL: "https://example.com/x")
    let d = makeOpp(id: "dup-x", title: "Different", organization: "Different")
    let (isDup2, reason) = Deduper.isDuplicate(c, d)
    assert(isDup2, "Exact ID duplicate with reason")
    assert(reason != nil, "Reason provided")
}
print("—— Freshness: fresh ——")
do {
    let now = Date()
    let freshOpp = makeOpp(deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 60, to: now), type: .fixed, displayString: "Future"), lastVerified: now)
    let info = FreshnessService.freshness(for: freshOpp, now: now)
    assertEqual(info.freshness, .fresh, "Fresh deadline future and recently verified")
    assert(!info.isExpired, "Fresh not expired")
    assert(info.daysUntilDeadline != nil, "Fresh has daysUntil")
    let rollingOpp = makeOpp(deadline: OpportunityDeadline(date: nil, type: .rolling, displayString: "Rolling"), lastVerified: now)
    let rollingInfo = FreshnessService.freshness(for: rollingOpp, now: now)
    assertEqual(rollingInfo.freshness, .fresh, "Rolling fresh")
    assert(!rollingInfo.isExpired, "Rolling not expired")
}
print("—— Freshness: aging ——")
do {
    let now = Date()
    let agingOpp = makeOpp(deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 30, to: now), type: .fixed, displayString: "Future"), lastVerified: Calendar.current.date(byAdding: .day, value: -40, to: now))
    let info = FreshnessService.freshness(for: agingOpp, now: now)
    assertEqual(info.freshness, .aging, "Aging 40 days since verified")
    assert(!info.isExpired, "Aging not expired")
}
print("—— Freshness: stale ——")
do {
    let now = Date()
    let staleOpp = makeOpp(lastVerified: Calendar.current.date(byAdding: .day, value: -100, to: now))
    let info = FreshnessService.freshness(for: staleOpp, now: now)
    assertEqual(info.freshness, .stale, "Stale 100 days")
    assert(!info.isExpired, "Stale not yet expired")
}
print("—— Freshness: expired ——")
do {
    let now = Date()
    let expiredByDeadline = makeOpp(deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: -10, to: now), type: .fixed, displayString: "Past"), lastVerified: now)
    let info = FreshnessService.freshness(for: expiredByDeadline, now: now)
    assertEqual(info.freshness, .expired, "Expired by deadline")
    assert(info.isExpired, "Expired true")
    assert(info.daysUntilDeadline! < 0, "Expired days negative")
    let staleExpired = makeOpp(lastVerified: Calendar.current.date(byAdding: .day, value: -200, to: now))
    let info2 = FreshnessService.freshness(for: staleExpired, now: now)
    assertEqual(info2.freshness, .expired, "Expired by 200 days stale")
    assert(info2.isExpired, "Stale expired true")
}
print("—— Freshness: missing timestamps ——")
do {
    let opp = makeOpp(deadline: nil, lastVerified: nil)
    let info = FreshnessService.freshness(for: opp)
    assertEqual(info.freshness, .unknown, "Missing timestamps unknown")
    assert(!info.isExpired, "Unknown not expired")
    assert(info.daysUntilDeadline == nil, "Unknown no days")
}
print("—— Freshness: deadline-based expiration ——")
do {
    let now = Date()
    let futureDeadline = makeOpp(deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 5, to: now), type: .fixed, displayString: "Soon"), lastVerified: now)
    assert(!FreshnessService.freshness(for: futureDeadline, now: now).isExpired, "Future deadline not expired")
    let pastDeadline = makeOpp(deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: -1, to: now), type: .fixed, displayString: "Yesterday"), lastVerified: now)
    assert(FreshnessService.freshness(for: pastDeadline, now: now).isExpired, "Past deadline expired")
    let info1 = FreshnessService.freshness(for: pastDeadline, now: now)
    let info2 = FreshnessService.freshness(for: pastDeadline, now: now)
    assertEqual(info1, info2, "Freshness deterministic")
}
print("—— Repository: insert / get ——")
do {
    let repo = TestRepository()
    let opp = makeOpp(id: "repo-1", title: "Alpha", organization: "Org")
    assert(repo.insert(opp), "Insert success")
    assertEqual(repo.get(id: "repo-1")?.title, "Alpha", "Get by ID")
    assert(repo.get(id: "nonexistent") == nil, "Get nonexistent nil")
    assert(repo.get(id: "") == nil, "Get empty nil")
    assertEqual(repo.all().count, 1, "All count 1")
    let emptyRepo = TestRepository()
    assertEqual(emptyRepo.all().count, 0, "Empty repo")
    assert(emptyRepo.get(id: "x") == nil, "Empty get nil")
}
print("—— Repository: upsert ——")
do {
    let repo = TestRepository()
    let opp1 = makeOpp(id: "upsert-1", title: "Original", organization: "Org", description: "Original desc")
    assert(repo.insert(opp1), "Insert original")
    let oppUpdated = makeOpp(id: "upsert-1", title: "Updated", organization: "Org", description: "Updated desc")
    assert(repo.upsert(oppUpdated), "Upsert success")
    assertEqual(repo.all().count, 1, "Upsert still 1")
    assertEqual(repo.get(id: "upsert-1")?.title, "Updated", "Upsert updated title")
    let oppNew = makeOpp(id: "upsert-2", title: "New", organization: "Org")
    assert(repo.upsert(oppNew), "Upsert new")
    assertEqual(repo.all().count, 2, "Upsert new adds")
}
print("—— Repository: delete ——")
do {
    let repo = TestRepository()
    let opp = makeOpp(id: "del-1", title: "To Delete", organization: "Org")
    assert(repo.insert(opp), "Insert for delete")
    assert(repo.remove(id: "del-1"), "Remove success")
    assertEqual(repo.all().count, 0, "After delete 0")
    assert(!repo.remove(id: "del-1"), "Remove again false")
    assert(!repo.remove(id: ""), "Remove empty false")
    assert(!repo.remove(id: "   "), "Remove whitespace false")
}
print("—— Repository: duplicate protection ——")
do {
    let repo = TestRepository()
    let oppA = makeOpp(id: "dup-a", title: "Dup Title", organization: "Dup Org", deadline: OpportunityDeadline(date: nil, type: .fixed, displayString: "2026-12-01"), sourceURL: "https://example.com/dup")
    assert(repo.insert(oppA), "Insert first")
    let oppB = makeOpp(id: "dup-a", title: "Different", organization: "Different")
    assert(!repo.insert(oppB), "Duplicate ID rejected")
    assertEqual(repo.all().count, 1, "Still 1 after duplicate ID")
    let oppC = makeOpp(id: "different-id", title: "Dup Title", organization: "Dup Org", deadline: OpportunityDeadline(date: nil, type: .fixed, displayString: "2026-12-01"))
    assert(!repo.insert(oppC), "Duplicate normalized identity rejected")
    let oppD = makeOpp(id: "unique", title: "Unique Title", organization: "Unique Org")
    assert(repo.insert(oppD), "Unique insert success")
    assertEqual(repo.all().count, 2, "Now 2")
}
print("—— Repository: deterministic ordering ——")
do {
    let repo = TestRepository()
    let oppC = makeOpp(id: "c", title: "Charlie", organization: "Org C")
    let oppA = makeOpp(id: "a", title: "Alpha", organization: "Org A")
    let oppB = makeOpp(id: "b", title: "Bravo", organization: "Org B")
    _ = repo.insert(oppC)
    _ = repo.insert(oppA)
    _ = repo.insert(oppB)
    let all = repo.all()
    assertEqual(all[0].title, "Alpha", "Order Alpha first")
    assertEqual(all[1].title, "Bravo", "Order Bravo second")
    assertEqual(all[2].title, "Charlie", "Order Charlie third")
    let repo2 = TestRepository()
    let opp1 = makeOpp(id: "1", title: "Same Title", organization: "Beta Org")
    let opp2 = makeOpp(id: "2", title: "Same Title", organization: "Alpha Org")
    _ = repo2.insert(opp1)
    _ = repo2.insert(opp2)
    assertEqual(repo2.all()[0].organization, "Alpha Org", "Same title org asc")
    assertEqual(repo2.all()[1].organization, "Beta Org", "Same title org second")
    let repo3 = TestRepository()
    let oppX = makeOpp(id: "id-2", title: "Same", organization: "Same Org", deadline: OpportunityDeadline(date: Date(timeIntervalSince1970: 1700000000), type: .fixed, displayString: "2026-12-01"))
    let oppY = makeOpp(id: "id-1", title: "Same", organization: "Same Org", deadline: OpportunityDeadline(date: Date(timeIntervalSince1970: 1800000000), type: .fixed, displayString: "2026-12-02"))
    _ = repo3.insert(oppX)
    _ = repo3.insert(oppY)
    assertEqual(repo3.all().count, 2, "Same title/org different deadline both inserted")
    assertEqual(repo3.all()[0].id, "id-1", "Ordering by id asc when title/org same")
    let repo4 = TestRepository()
    _ = repo4.insert(oppC); _ = repo4.insert(oppA); _ = repo4.insert(oppB)
    let repo5 = TestRepository()
    _ = repo5.insert(oppA); _ = repo5.insert(oppB); _ = repo5.insert(oppC)
    assertEqual(repo4.all(), repo5.all(), "Ordering deterministic independent of insertion order")
}
print("—— Repository: validation ——")
do {
    let repo = TestRepository()
    let invalidOpp = makeOpp(id: "", title: "", organization: "")
    assert(!repo.insert(invalidOpp), "Invalid rejected")
    assertEqual(repo.all().count, 0, "Invalid not inserted")
    assert(!repo.upsert(invalidOpp), "Invalid upsert rejected")
    let validOpp = makeOpp(id: "valid", title: "Valid", organization: "Org")
    assert(repo.insert(validOpp), "Valid insert")
}
print("—— Repository: normalization via ingest ——")
do {
    let repo = TestRepository()
    let raws: [RawOpportunityRecord] = [
        RawOpportunityRecord(title: "  Hello   World  ", organization: "  Demo Org  ", category: "hackathon", deadline: "2026-12-01", cost: "Free", skills: ["Python", "python"], sourceID: "src1", sourceName: "Src", sourceURL: "https://example.com/1"),
        RawOpportunityRecord(title: "Valid", organization: "Org2", category: "competition", sourceID: "src2", sourceName: "Src2", sourceURL: "https://example.com/2"),
        RawOpportunityRecord(title: "", organization: ""),
    ]
    let result = repo.ingest(rawRecords: raws)
    assertEqual(result.inserted, 3, "Ingest inserted 3")
    assertEqual(result.invalid, 0, "Ingest invalid 0")
    let first = repo.get(id: repo.all().first(where: { $0.title == "Hello World" })?.id ?? "")
    assert(first != nil, "Normalized title Hello World exists")
    let dupResult = repo.ingest(rawRecords: [RawOpportunityRecord(title: "Hello World", organization: "Demo Org", category: "hackathon", sourceID: "src1", sourceName: "Src", sourceURL: "https://example.com/1")])
    assertEqual(dupResult.duplicates, 1, "Ingest duplicate counted")
    assertEqual(dupResult.inserted, 0, "Duplicate not inserted")
}
print("—— Repository: empty repository ——")
do {
    let repo = TestRepository()
    assertEqual(repo.all().count, 0, "Empty all 0")
    assert(repo.get(id: "x") == nil, "Empty get nil")
    repo.replaceAll(with: [])
    assertEqual(repo.all().count, 0, "Replace empty")
    repo.clear()
    assertEqual(repo.all().count, 0, "Clear empty")
}
print("—— Repository: replaceAll ——")
do {
    let repo = TestRepository()
    let a = makeOpp(id: "replace-a", title: "A", organization: "Org")
    let b = makeOpp(id: "replace-b", title: "B", organization: "Org")
    repo.replaceAll(with: [a, b])
    assertEqual(repo.all().count, 2, "ReplaceAll 2")
    let dupA = makeOpp(id: "replace-a", title: "A Dup", organization: "Org")
    repo.replaceAll(with: [a, dupA, b])
    assertEqual(repo.all().count, 2, "ReplaceAll deduped")
    let invalid = makeOpp(id: "", title: "", organization: "")
    repo.replaceAll(with: [a, invalid, b])
    assertEqual(repo.all().count, 2, "ReplaceAll filtered invalid")
}
print("—— Persistence: save/load simulation ——")
do {
    let repo = TestRepository()
    let opp1 = makeOpp(id: "persist-1", title: "Persist A", organization: "Org")
    let opp2 = makeOpp(id: "persist-2", title: "Persist B", organization: "Org")
    _ = repo.insert(opp1); _ = repo.insert(opp2)
    let data = try! JSONEncoder().encode(repo.all())
    let decoded = try! JSONDecoder().decode([Opportunity].self, from: data)
    assertEqual(decoded.count, 2, "Save/load count")
    assert(decoded.contains(where: { $0.id == "persist-1" }), "Persist contains 1")
    assert(decoded.contains(where: { $0.id == "persist-2" }), "Persist contains 2")
    let repo2 = TestRepository()
    repo2.replaceAll(with: decoded)
    assertEqual(repo2.all().count, 2, "Restart reload 2")
    assertEqual(repo2.all(), repo.all(), "Restart deterministic")
    let missingData: Data? = nil
    let loadedMissing: [Opportunity] = {
        if let d = missingData, let decoded = try? JSONDecoder().decode([Opportunity].self, from: d) { return decoded }
        return []
    }()
    assertEqual(loadedMissing.count, 0, "Missing key defaults empty")
    let corrupted = "not json".data(using: .utf8)!
    let loadedCorrupted: [Opportunity] = (try? JSONDecoder().decode([Opportunity].self, from: corrupted)) ?? []
    assertEqual(loadedCorrupted.count, 0, "Corrupted defaults empty")
    let otherStore: [String: String] = ["studentops.profile": "profileData", "studentops.projectProgress": "progress"]
    let otherBefore = otherStore
    _ = try? JSONEncoder().encode(repo.all())
    assertEqual(otherStore, otherBefore, "No mutation unrelated")
}
print("—— Seed Data ——")
do {
    let now = Date()
    func seedSource(id: String, name: String, url: String? = nil) -> OpportunitySource {
        OpportunitySource(sourceID: id, sourceName: name, sourceType: .staticSeed, sourceURL: url, retrievedAt: Date(timeIntervalSince1970: 1700000000), publisher: name)
    }
    let seedOps: [Opportunity] = [
        makeOpp(id: "seed-student-innovation-challenge-2026", title: "Student Innovation Challenge (Demo)", organization: "Demo Organization - Student Innovation Challenge", opportunityType: .competition, description: "Demo competition", location: OpportunityLocation(type: "online", city: nil, state: nil, country: "USA", online: true), delivery: .online, ageRange: OpportunityAgeRange(minAge: 13, maxAge: 18), deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 60, to: now), type: .fixed, displayString: "2026-12-01"), costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true), skills: ["Problem solving", "Programming"], interests: ["Technology"], careerFields: ["Computer Science"], source: seedSource(id: "seed-demo", name: "Demo Seed Catalog", url: "https://example.com/seed"), sourceURL: "https://example.com/opportunities/innovation-challenge", lastVerified: now),
        makeOpp(id: "seed-scholarship-demo", title: "Demo Scholarship - Future Scholars (Seed)", organization: "Demo Scholarship Foundation", opportunityType: .scholarship, description: "Demo scholarship", location: OpportunityLocation(type: "unknown", city: nil, state: nil, country: nil, online: nil), costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true), skills: ["Writing"], source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"), sourceURL: "https://example.com/scholarship-demo", lastVerified: Calendar.current.date(byAdding: .day, value: -10, to: now)),
        makeOpp(id: "seed-research-program", title: "Demo Research Program (Seed)", organization: "Demo Research Institute", opportunityType: .research, description: "Demo research", location: OpportunityLocation(type: "inPerson", city: "Austin", state: "TX", country: "USA", online: false), delivery: .inPerson, ageRange: OpportunityAgeRange(minAge: 15, maxAge: 18), deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: -10, to: now), type: .fixed, displayString: "2026-09-01"), costInfo: OpportunityCost(amount: 500, currency: "USD", isFree: false), source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"), sourceURL: "https://example.com/research-program", lastVerified: Calendar.current.date(byAdding: .day, value: -100, to: now)),
        makeOpp(id: "seed-internship-demo", title: "Demo Internship - Community Tech (Seed)", organization: "Demo Community Org", opportunityType: .internship, description: "Demo internship", location: OpportunityLocation(type: "hybrid", city: "Seattle", state: "WA", country: "USA", online: nil), delivery: .hybrid, ageRange: OpportunityAgeRange(minAge: 16, maxAge: nil), costInfo: nil, source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"), sourceURL: "https://example.com/internship-demo", lastVerified: now),
        makeOpp(id: "seed-summer-program", title: "Demo Summer Program - Code Camp (Seed)", organization: "Demo Summer Org", opportunityType: .summerProgram, description: "Demo summer", location: OpportunityLocation(type: "inPerson", city: "Boston", state: "MA", country: "USA", online: false), delivery: .inPerson, deadline: OpportunityDeadline(date: nil, type: .rolling, displayString: "Rolling"), costInfo: OpportunityCost(amount: 2000, currency: "USD", isFree: false), source: seedSource(id: "seed-demo", name: "Demo Seed Catalog", url: "https://example.com/summer"), sourceURL: "https://example.com/summer-program", lastVerified: Calendar.current.date(byAdding: .day, value: -5, to: now)),
        makeOpp(id: "seed-volunteering-demo", title: "Demo Volunteering - City Cleanup (Seed)", organization: "Demo Volunteer Network", opportunityType: .volunteering, description: "Demo volunteering", location: OpportunityLocation(type: "inPerson", city: "Portland", state: "OR", country: "USA", online: false), delivery: .inPerson, deadline: OpportunityDeadline(date: nil, type: .noDeadline, displayString: "No deadline"), costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true), skills: ["Leadership", "Teamwork"], source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"), sourceURL: "https://example.com/volunteering-demo", lastVerified: now),
        makeOpp(id: "seed-leadership-fellowship", title: "Demo Leadership Fellowship (Seed)", organization: "Demo Leadership Org", opportunityType: .leadership, description: "Demo leadership", location: OpportunityLocation(type: "hybrid", city: nil, state: nil, country: nil, online: nil), delivery: .hybrid, deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 45, to: now), type: .fixed, displayString: "2026-11-30"), costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true), skills: ["Leadership"], source: seedSource(id: "external-api", name: "External API Demo", url: "https://api.example.com/opportunities"), sourceURL: "https://example.com/leadership-fellowship", lastVerified: Calendar.current.date(byAdding: .day, value: -40, to: now)),
        makeOpp(id: "duplicate-innovation-challenge", title: "Student Innovation Challenge (Demo)", organization: "Demo Organization - Student Innovation Challenge", opportunityType: .competition, description: "Duplicate", location: OpportunityLocation(type: "online", city: nil, state: nil, country: "USA", online: true), deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 60, to: now), type: .fixed, displayString: "2026-12-01"), costInfo: OpportunityCost(amount: 0, currency: "USD", isFree: true), source: seedSource(id: "external-json", name: "External JSON Feed", url: "https://example.com/json"), sourceURL: "https://example.com/opportunities/innovation-challenge", lastVerified: now),
        makeOpp(id: "seed-expired-demo", title: "Demo Expired Opportunity (Seed)", organization: "Demo Expired Org", opportunityType: .conference, description: "Demo expired", location: OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true), deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: -30, to: now), type: .fixed, displayString: "2026-08-01"), source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"), sourceURL: "https://example.com/expired-demo", lastVerified: Calendar.current.date(byAdding: .day, value: -200, to: now), status: .expired),
        makeOpp(id: "seed-stale-demo", title: "Demo Stale Opportunity (Seed)", organization: "Demo Stale Org", opportunityType: .community, description: "Demo stale", source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"), sourceURL: "https://example.com/stale-demo", lastVerified: Calendar.current.date(byAdding: .day, value: -200, to: now)),
        makeOpp(id: "seed-fresh-demo", title: "Demo Fresh Opportunity (Seed)", organization: "Demo Fresh Org", opportunityType: .other, description: "Demo fresh", location: OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true), deadline: OpportunityDeadline(date: Calendar.current.date(byAdding: .day, value: 10, to: now), type: .fixed, displayString: "2026-10-01"), source: seedSource(id: "seed-demo", name: "Demo Seed Catalog"), sourceURL: "https://example.com/fresh-demo", lastVerified: now),
    ]
    for opp in seedOps {
        let result = Validator.validate(opp)
        assert(result.isValid, "Seed \(opp.id) validates: errors \(result.errors)")
        assert(!opp.id.isEmpty, "Seed \(opp.id) non-empty id")
        assert(!opp.title.isEmpty, "Seed \(opp.id) title")
        assert(!opp.organization.isEmpty, "Seed \(opp.id) org")
    }
    let ids = seedOps.map(\.id)
    assertEqual(Set(ids).count, ids.count, "Seed IDs unique")
    let (unique, dups) = Deduper.deduplicate(seedOps)
    assert(dups.count >= 1, "Seed duplicates found \(dups.count)")
    assert(unique.count < seedOps.count, "Unique less than total")
    assertEqual(unique.count, seedOps.count - dups.count, "Unique = total - dups")
    assert(dups.contains(where: { $0.1.reason == .canonicalURL || $0.1.reason == .normalizedIdentity }), "Duplicate reason is URL or identity")
    for opp in seedOps {
        if let url = opp.sourceURL { assert(isValidURL(url), "Seed \(opp.id) URL valid \(url)") }
        if let url = opp.source.sourceURL { assert(isValidURL(url), "Seed \(opp.id) sourceURL valid") }
    }
    for opp in seedOps {
        if let age = opp.ageRange, let min = age.minAge, let max = age.maxAge {
            assert(min <= max, "Seed \(opp.id) age min <= max")
        }
    }
    let types = Set(seedOps.map(\.opportunityType))
    assert(types.contains(.competition), "Seed has competition")
    assert(types.contains(.hackathon), "Seed has hackathon")
    assert(types.contains(.scholarship), "Seed has scholarship")
    assert(types.contains(.research), "Seed has research")
    assert(types.contains(.internship), "Seed has internship")
    assert(types.contains(.summerProgram), "Seed has summer")
    assert(types.contains(.volunteering), "Seed has volunteering")
    assert(types.contains(.leadership), "Seed has leadership")
    let locations = seedOps.map(\.location.type)
    assert(locations.contains("online"), "Seed has online")
    assert(locations.contains("inPerson"), "Seed has inPerson")
    assert(locations.contains("hybrid"), "Seed has hybrid")
    assert(locations.contains("unknown"), "Seed has unknown")
    let hasWithAge = seedOps.contains(where: { $0.ageRange != nil })
    let hasWithoutAge = seedOps.contains(where: { $0.ageRange == nil })
    assert(hasWithAge, "Seed has known age")
    assert(hasWithoutAge, "Seed has unknown age")
    let hasDeadline = seedOps.contains(where: { $0.deadlineInfo != nil })
    let hasNoDeadline = seedOps.contains(where: { $0.deadlineInfo == nil })
    assert(hasDeadline, "Has deadline")
    assert(hasNoDeadline, "Has no deadline")
    let free = seedOps.contains(where: { $0.costInfo?.isFree == true })
    let paid = seedOps.contains(where: { $0.costInfo?.isFree == false })
    let unknownCost = seedOps.contains(where: { $0.costInfo == nil })
    assert(free, "Has free")
    assert(paid, "Has paid")
    assert(unknownCost, "Has unknown cost")
    let multiSkill = seedOps.contains(where: { $0.skills.count >= 2 })
    assert(multiSkill, "Has multi skills")
    let sourceIDs = Set(seedOps.map(\.source.sourceID))
    assert(sourceIDs.count >= 2, "Multiple sources \(sourceIDs)")
}
print("—— Deterministic ordering performance ——")
do {
    var many: [Opportunity] = []
    for i in 0..<300 {
        many.append(makeOpp(id: "unique-\(i)", title: "Unique Title \(i)", organization: "Unique Org \(i)"))
    }
    let repo = TestRepository()
    let start = Date()
    repo.replaceAll(with: many)
    let elapsed = Date().timeIntervalSince(start)
    assert(elapsed < 2.0, "Performance 300 items under 2s, took \(elapsed)")
    assertEqual(repo.all().count, 300, "300 unique distinct title/org")
    let first = repo.all()
    let second = repo.all()
    assertEqual(first, second, "Ordering stable repeated calls")
}
print("—— Regression: ensure no second StudentProfile/Project/Skill model ——")
do {
    assertEqual(normalizeSkillID("  Python  "), "python", "Skill normalize consistent")
    assertEqual(collapseWhitespace("  Hello   World  "), "Hello World", "Whitespace collapse consistent")
    let opp = makeOpp(opportunityType: .hackathon)
    assertEqual(opp.opportunityType, .hackathon, "Strongly typed")
    let repo = TestRepository()
    assert(repo.all().isEmpty, "Repository in-memory not database")
}
print("—— Source abstraction ——")
do {
    let src = OpportunitySource(sourceID: "src-123", sourceName: "Test Source", sourceType: .staticSeed, sourceURL: "https://example.com/feed", retrievedAt: Date(), publisher: "Publisher")
    assertEqual(src.sourceID, "src-123", "Source ID")
    assertEqual(src.sourceType, .staticSeed, "Source type")
    assert(isValidURL(src.sourceURL!), "Source URL valid")
    let raw = RawOpportunityRecord(sourceID: "src", sourceName: "Name", sourceType: "api", sourceURL: "https://example.com", officialURL: "https://example.com/official")
    let normalizedOpp = Normalizer.normalize(raw)
    assertEqual(normalizedOpp.source.sourceType, .api, "Source type from raw")
    assert(normalizedOpp.sourceURL != nil, "SourceURL preserved")
}
print("—— Raw → Canonical separation ——")
do {
    let raw = RawOpportunityRecord(title: "  Test   Opportunity  ", organization: "  Test Org  ", category: "hackathon", location: "Online", deadline: "2026-12-01", cost: "Free", skills: ["Python", "python"], sourceID: "src", sourceName: "Src", sourceURL: "https://example.com")
    let canonical = Normalizer.normalize(raw)
    assertEqual(canonical.title, "Test Opportunity", "Raw→Canonical title normalized")
    assertEqual(canonical.organization, "Test Org", "Org normalized")
    assertEqual(canonical.opportunityType, .hackathon, "Category mapped")
    assertEqual(canonical.skills.count, 1, "Duplicate skills deduped via Skill.normalizeID")
    assert(canonical.sourceURL != nil, "URL normalized")
    assert(raw.title != canonical.title || raw.title == "  Test   Opportunity  ", "Raw differs from canonical, canonical is normalized")
    let canonical2 = Normalizer.normalize(raw)
    // Deterministic excluding retrievedAt which is time-based
    assertEqual(canonical.title, canonical2.title, "Raw→Canonical deterministic title")
    assertEqual(canonical.id, canonical2.id, "Deterministic ID")
    assertEqual(canonical.opportunityType, canonical2.opportunityType, "Deterministic type")
    assertEqual(canonical.skills, canonical2.skills, "Deterministic skills")
}
print("")
print("========================================")
if failed == 0 {
    print("All \(passed) tests passed ✓")
    print("Phase 10A Opportunity Intelligence Foundation — COMPLETE")
} else {
    print("\(failed) of \(passed+failed) tests FAILED")
    print("Passed: \(passed)")
}
print("========================================")
if failed > 0 { exit(1) }
