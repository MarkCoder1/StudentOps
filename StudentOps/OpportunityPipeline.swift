import Foundation

// MARK: - Opportunity Intelligence Foundation (Phase 10A)
// Pipeline: External Source → Raw → Normalization → Validation → Deduplication → Canonical Repository
// Deterministic, no AI, no database, no second StudentProfile/Project model.

// MARK: - Raw Opportunity Record (external, messy)

struct RawOpportunityRecord: Codable, Hashable {
    let id: String?
    let title: String?
    let organization: String?
    let organizationDescription: String?
    let category: String? // raw category string, may be alias
    let description: String?
    let location: String? // raw location string
    let deliveryMode: String?
    let minAge: String? // raw string, may be "14", "14 years"
    let maxAge: String? // raw string
    let gradeMin: String?
    let gradeMax: String?
    let eligibility: String?
    let requirements: [String]?
    let deadline: String? // raw date string, may be "2026-12-01", "Rolling", "TBD"
    let cost: String? // raw cost string, e.g., "$100", "Free", "Unknown"
    let skills: [String]?
    let interests: [String]?
    let careerFields: [String]?
    let sourceID: String?
    let sourceName: String?
    let sourceType: String?
    let sourceURL: String?
    let retrievedAt: String? // raw date string
    let officialURL: String?
    let lastVerified: String?

    init(
        id: String? = nil,
        title: String? = nil,
        organization: String? = nil,
        organizationDescription: String? = nil,
        category: String? = nil,
        description: String? = nil,
        location: String? = nil,
        deliveryMode: String? = nil,
        minAge: String? = nil,
        maxAge: String? = nil,
        gradeMin: String? = nil,
        gradeMax: String? = nil,
        eligibility: String? = nil,
        requirements: [String]? = nil,
        deadline: String? = nil,
        cost: String? = nil,
        skills: [String]? = nil,
        interests: [String]? = nil,
        careerFields: [String]? = nil,
        sourceID: String? = nil,
        sourceName: String? = nil,
        sourceType: String? = nil,
        sourceURL: String? = nil,
        retrievedAt: String? = nil,
        officialURL: String? = nil,
        lastVerified: String? = nil
    ) {
        self.id = id
        self.title = title
        self.organization = organization
        self.organizationDescription = organizationDescription
        self.category = category
        self.description = description
        self.location = location
        self.deliveryMode = deliveryMode
        self.minAge = minAge
        self.maxAge = maxAge
        self.gradeMin = gradeMin
        self.gradeMax = gradeMax
        self.eligibility = eligibility
        self.requirements = requirements
        self.deadline = deadline
        self.cost = cost
        self.skills = skills
        self.interests = interests
        self.careerFields = careerFields
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.retrievedAt = retrievedAt
        self.officialURL = officialURL
        self.lastVerified = lastVerified
    }
}

// MARK: - Opportunity Source (canonical)

extension OpportunitySource {
    static func fromRaw(_ raw: RawOpportunityRecord, retrievedAt: Date = Date()) -> OpportunitySource {
        let sid = raw.sourceID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        let sname = raw.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Source"
        let stype: SourceType
        if let t = raw.sourceType?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
            switch t {
            case "staticseed", "static_seed", "seed": stype = .staticSeed
            case "api": stype = .api
            case "jsonfeed", "json_feed": stype = .jsonFeed
            case "manual": stype = .manual
            default: stype = .other
            }
        } else {
            stype = .other
        }
        let url = raw.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let retrieved: Date
        if let r = raw.retrievedAt, let d = ISO8601DateFormatter().date(from: r) ?? DateFormatter.iso8601.date(from: r) {
            retrieved = d
        } else {
            retrieved = retrievedAt
        }
        return OpportunitySource(sourceID: sid, sourceName: sname, sourceType: stype, sourceURL: url, retrievedAt: retrieved, publisher: raw.organization?.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

// MARK: - Normalizer

enum OpportunityNormalizer {
    static func normalize(_ raw: RawOpportunityRecord) -> Opportunity {
        // Title
        let title = normalizeTitle(raw.title)
        // Organization
        let org = normalizeOrganization(raw.organization)
        // ID: stable normalized ID
        let id = normalizeID(raw: raw, title: title, organization: org)
        // Category -> OpportunityType
        let type = normalizeCategory(raw.category)
        // Description
        let desc = normalizeText(raw.description) ?? ""
        // Location
        let loc = normalizeLocation(raw.location, deliveryMode: raw.deliveryMode)
        let delivery = normalizeDeliveryMode(raw.deliveryMode, location: raw.location)
        // Age
        let ageRange = normalizeAgeRange(minAge: raw.minAge, maxAge: raw.maxAge)
        // Grade
        let gradeRange = normalizeGradeRange(gradeMin: raw.gradeMin, gradeMax: raw.gradeMax)
        // Skills (use existing Skill.normalizeID)
        let skills: [String] = {
            guard let s = raw.skills else { return [] }
            var seen = Set<String>()
            var out: [String] = []
            for rawSkill in s {
                let nid = Skill.normalizeID(rawSkill)
                guard !nid.isEmpty, !seen.contains(nid) else { continue }
                seen.insert(nid)
                out.append(rawSkill.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return out
        }()
        let interests = normalizeStringArray(raw.interests)
        let careerFields = normalizeStringArray(raw.careerFields)
        // URLs
        let sourceURL = normalizeURL(raw.sourceURL)
        let officialURLStr = normalizeURL(raw.officialURL) ?? normalizeURL(raw.sourceURL)
        let officialURL = officialURLStr.flatMap { URL(string: $0) }
        // Source
        let source = OpportunitySource.fromRaw(raw)
        // Deadline
        let deadlineInfo = normalizeDeadline(raw.deadline)
        // Cost
        let costInfo = normalizeCost(raw.cost)
        // Eligibility
        let eligibilityInfo: OpportunityEligibility? = {
            let details = normalizeText(raw.eligibility)
            if details == nil && (raw.requirements?.isEmpty ?? true) { return nil }
            return OpportunityEligibility(details: details, requirements: raw.requirements ?? [])
        }()
        let appReqs: [OpportunityRequirement] = (raw.requirements ?? []).map { OpportunityRequirement(title: $0) }
        // Last verified
        let lastVerified: Date? = {
            if let s = raw.lastVerified, let d = ISO8601DateFormatter().date(from: s) ?? DateFormatter.iso8601.date(from: s) { return d }
            if let s = raw.retrievedAt, let d = ISO8601DateFormatter().date(from: s) ?? DateFormatter.iso8601.date(from: s) { return d }
            return nil
        }()
        // Status: active if not expired, else status will be computed via freshness later, but set initial .active
        let status: OpportunityStatus = .active

        return Opportunity(
            id: id,
            title: title.isEmpty ? "Untitled Opportunity" : title,
            organization: org.isEmpty ? "Unknown Organization" : org,
            organizationDescription: normalizeText(raw.organizationDescription),
            opportunityType: type,
            description: desc,
            location: loc,
            deliveryMode: delivery,
            ageRange: ageRange,
            gradeRange: gradeRange,
            eligibilityInfo: eligibilityInfo,
            applicationRequirements: appReqs,
            deadlineInfo: deadlineInfo,
            costInfo: costInfo,
            skills: skills,
            interests: interests,
            careerFields: careerFields,
            source: source,
            sourceURL: sourceURL,
            lastVerified: lastVerified,
            status: status,
            category: OpportunityTypeMapper.category(for: type),
            legacyDeadline: deadlineInfo?.displayString,
            legacyLocation: loc.displayString,
            legacyEligibility: eligibilityInfo?.displayString,
            whyItMatches: "",
            requirements: raw.requirements ?? [],
            importantDates: deadlineInfo.map { [$0.displayString] } ?? [],
            officialURL: officialURL,
            relevantInterests: Set(interests),
            relevantSkills: Set(skills),
            relevantCareers: Set(careerFields),
            relevantFields: Set(careerFields),
            eligibleGrades: gradeRange?.eligibleGrades ?? [],
            relevantLocations: Set([loc.displayString])
        )
    }

    // MARK: - Helpers

    static func normalizeTitle(_ raw: String?) -> String {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return "" }
        return collapseWhitespace(r)
    }

    static func normalizeOrganization(_ raw: String?) -> String {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return "" }
        return collapseWhitespace(r)
    }

    static func normalizeID(raw: RawOpportunityRecord, title: String, organization: String) -> String {
        // Hierarchy: exact id if trustworthy (non-empty, not placeholder), else source+externalId, else org+title+deadline hash
        if let id = raw.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty, !id.lowercased().contains("unknown") {
            return collapseWhitespace(id).lowercased().replacingOccurrences(of: " ", with: "-")
        }
        if let sid = raw.sourceID?.trimmingCharacters(in: .whitespacesAndNewlines), !sid.isEmpty,
           let oid = raw.id?.trimmingCharacters(in: .whitespacesAndNewlines), !oid.isEmpty {
            return "\(sid.lowercased())-\(oid.lowercased())"
        }
        if let sid = raw.sourceID?.trimmingCharacters(in: .whitespacesAndNewlines), !sid.isEmpty {
            let t = normalizeTitle(raw.title).lowercased().replacingOccurrences(of: " ", with: "-")
            let o = normalizeOrganization(raw.organization).lowercased().replacingOccurrences(of: " ", with: "-")
            let d = normalizeText(raw.deadline)?.lowercased().replacingOccurrences(of: " ", with: "-") ?? ""
            let base = "\(sid)-\(o)-\(t)-\(d)".lowercased()
            return base.replacingOccurrences(of: "--", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Fallback: org + title + deadline deterministic hash
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
        case "competition", "competitions", "contest": return .competition
        case "hackathon", "hackathons": return .hackathon
        case "scholarship", "scholarships": return .scholarship
        case "research", "researchprogram": return .research
        case "internship", "internships": return .internship
        case "summerprogram", "summerprograms", "summer": return .summerProgram
        case "academicprogram", "academicprograms", "academic": return .academicProgram
        case "volunteering", "volunteer", "communityservice": return .volunteering
        case "leadership", "leadershipprogram": return .leadership
        case "fellowship", "fellowships": return .fellowship
        case "conference", "conferences", "program": return .conference
        case "community", "communityopportunity": return .community
        default: return .other
        }
    }

    static func normalizeLocation(_ raw: String?, deliveryMode: String?) -> OpportunityLocation {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else {
            // Try to infer from deliveryMode
            if let dm = deliveryMode?.lowercased(), dm.contains("online") { return OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true, latitude: nil, longitude: nil) }
            return OpportunityLocation(type: "unknown", city: nil, state: nil, country: nil, online: nil, latitude: nil, longitude: nil)
        }
        let lower = r.lowercased()
        if lower.contains("online") || lower.contains("remote") || lower.contains("virtual") {
            return OpportunityLocation(type: "online", city: nil, state: nil, country: nil, online: true, latitude: nil, longitude: nil)
        }
        if lower.contains("hybrid") {
            return OpportunityLocation(type: "hybrid", city: nil, state: nil, country: nil, online: nil, latitude: nil, longitude: nil)
        }
        // Try to parse city, state
        return OpportunityLocation(type: "inPerson", city: nil, state: nil, country: nil, online: false, latitude: nil, longitude: nil)
    }

    static func normalizeDeliveryMode(_ raw: String?, location: String?) -> OpportunityDeliveryMode {
        if let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty {
            return OpportunityDeliveryMode(rawValue: r) ?? .unknown
        }
        if let loc = location?.lowercased() {
            if loc.contains("online") || loc.contains("remote") { return .online }
            if loc.contains("hybrid") { return .hybrid }
            if loc.contains("in person") { return .inPerson }
        }
        return .unknown
    }

    static func normalizeAgeRange(minAge: String?, maxAge: String?) -> OpportunityAgeRange? {
        let minVal = parseAge(minAge)
        let maxVal = parseAge(maxAge)
        if minVal == nil && maxVal == nil { return nil }
        return OpportunityAgeRange(minAge: minVal, maxAge: maxVal)
    }

    static func parseAge(_ raw: String?) -> Int? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        // Extract first integer
        // Extract first integer
        let scanner = Scanner(string: r)
        var val: Int = 0
        if scanner.scanInt(&val) { return val }
        // Try to find digits
        if let num = r.range(of: "\\d+", options: .regularExpression).flatMap({ Int(r[$0]) }) { return num }
        return nil
    }

    static func normalizeGradeRange(gradeMin: String?, gradeMax: String?) -> OpportunityGradeRange? {
        let gmin = gradeMin?.trimmingCharacters(in: .whitespacesAndNewlines)
        let gmax = gradeMax?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (gmin == nil || gmin!.isEmpty) && (gmax == nil || gmax!.isEmpty) { return nil }
        // Try to map to Grade enum
        let eligible = parseEligibleGrades(gradeMin: gmin, gradeMax: gmax)
        return OpportunityGradeRange(gradeMin: gmin, gradeMax: gmax, eligibleGrades: eligible)
    }

    static func parseEligibleGrades(gradeMin: String?, gradeMax: String?) -> Set<Grade> {
        // Simple: if both provided, include range, else empty
        // For now, return empty and let caller handle; but we try to parse
        guard let minStr = gradeMin?.lowercased(), let maxStr = gradeMax?.lowercased() else { return [] }
        let all: [Grade] = [.seventh, .eighth, .ninth, .tenth, .eleventh, .twelfth]
        // Map string like "9", "9th", "ninth" to Grade
        func gradeFrom(_ s: String) -> Grade? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if t.contains("7") || t.contains("seventh") { return .seventh }
            if t.contains("8") || t.contains("eighth") { return .eighth }
            if t.contains("9") || t.contains("ninth") { return .ninth }
            if t.contains("10") || t.contains("tenth") { return .tenth }
            if t.contains("11") || t.contains("eleventh") { return .eleventh }
            if t.contains("12") || t.contains("twelfth") { return .twelfth }
            return nil
        }
        guard let minG = gradeFrom(minStr), let maxG = gradeFrom(maxStr) else { return [] }
        let order: [Grade] = [.seventh, .eighth, .ninth, .tenth, .eleventh, .twelfth]
        guard let minIdx = order.firstIndex(of: minG), let maxIdx = order.firstIndex(of: maxG), minIdx <= maxIdx else { return [] }
        return Set(order[minIdx...maxIdx])
    }

    static func normalizeDeadline(_ raw: String?) -> OpportunityDeadline? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        let lower = r.lowercased()
        if lower == "rolling" || lower.contains("rolling") { return OpportunityDeadline(date: nil, type: .rolling, displayString: "Rolling") }
        if lower == "tbd" || lower == "no deadline" || lower == "unknown" { return OpportunityDeadline(date: nil, type: .unknown, displayString: r) }
        // Try to parse date
        let fmts: [DateFormatter] = [DateFormatter.iso8601, DateFormatter.medium, DateFormatter.short]
        for fmt in fmts {
            if let d = fmt.date(from: r) { return OpportunityDeadline(date: d, type: .fixed, displayString: r) }
        }
        // Try ISO8601
        if let d = ISO8601DateFormatter().date(from: r) { return OpportunityDeadline(date: d, type: .fixed, displayString: r) }
        // Fallback unknown with display
        return OpportunityDeadline(date: nil, type: .unknown, displayString: r)
    }

    static func normalizeCost(_ raw: String?) -> OpportunityCost? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        let lower = r.lowercased()
        if lower == "free" || lower.contains("free") { return OpportunityCost(amount: 0, currency: "USD", isFree: true) }
        if lower == "unknown" { return nil }
        // Try to parse amount like "$100", "100 USD"
        let digits = r.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined(separator: "|").split(separator: "|").compactMap { Double($0) }.first
        if let amt = digits {
            return OpportunityCost(amount: amt, currency: "USD", isFree: amt == 0)
        }
        return OpportunityCost(amount: nil, currency: nil, isFree: nil)
    }

    static func normalizeURL(_ raw: String?) -> String? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        guard let url = URL(string: r), let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme), url.host != nil else { return nil }
        guard var comps = URLComponents(string: r) else { return r }
        comps.host = comps.host?.lowercased()
        comps.fragment = nil
        return comps.string ?? r
    }

    static func normalizeText(_ raw: String?) -> String? {
        guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty else { return nil }
        return collapseWhitespace(r)
    }

    static func normalizeStringArray(_ arr: [String]?) -> [String] {
        guard let a = arr else { return [] }
        var seen = Set<String>()
        var out: [String] = []
        for raw in a {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            let collapsed = collapseWhitespace(t)
            let lower = collapsed.lowercased()
            if seen.contains(lower) { continue }
            seen.insert(lower)
            out.append(collapsed)
        }
        return out
    }

    static func collapseWhitespace(_ s: String) -> String {
        let parts = s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    static func deterministicHash(_ s: String) -> String {
        var hash: UInt32 = 2166136261
        for byte in s.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return String(format: "%08x", hash)
    }
}

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    static let medium: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()
}

// MARK: - Validation

enum OpportunityValidationLevel: String, Codable, Hashable {
    case error = "error"
    case warning = "warning"
}

struct OpportunityValidationIssue: Hashable, Codable {
    let level: OpportunityValidationLevel
    let field: String
    let message: String
    let code: String
}

struct OpportunityValidationResult: Hashable, Codable {
    let isValid: Bool
    let errors: [OpportunityValidationIssue]
    let warnings: [OpportunityValidationIssue]

    var hasErrors: Bool { !errors.isEmpty }
}

enum OpportunityValidator {
    static func validate(_ opp: Opportunity) -> OpportunityValidationResult {
        var errors: [OpportunityValidationIssue] = []
        var warnings: [OpportunityValidationIssue] = []

        // ID
        if opp.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.init(level: .error, field: "id", message: "ID is empty", code: "empty_id"))
        }
        // Title
        if opp.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.init(level: .error, field: "title", message: "Title is empty", code: "empty_title"))
        }
        // Organization
        if opp.organization.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.init(level: .error, field: "organization", message: "Organization is empty", code: "empty_organization"))
        }
        // URLs
        if let urlStr = opp.sourceURL, !urlStr.isEmpty {
            if !isValidURL(urlStr) {
                errors.append(.init(level: .error, field: "sourceURL", message: "Invalid URL: \(urlStr)", code: "invalid_url"))
            }
        }
        if let srcURL = opp.source.sourceURL, !srcURL.isEmpty {
            if !isValidURL(srcURL) {
                errors.append(.init(level: .error, field: "source.sourceURL", message: "Invalid source URL", code: "invalid_url"))
            }
        }
        if let official = opp.officialURL?.absoluteString, !isValidURL(official) {
            errors.append(.init(level: .error, field: "officialURL", message: "Invalid official URL", code: "invalid_url"))
        }
        // Age range
        if let age = opp.ageRange {
            if let min = age.minAge, let max = age.maxAge, min > max {
                errors.append(.init(level: .error, field: "ageRange", message: "minAge > maxAge", code: "invalid_age_range"))
            }
            if let min = age.minAge, min < 0 || min > 120 {
                errors.append(.init(level: .error, field: "ageRange.minAge", message: "Invalid minAge", code: "invalid_age"))
            }
            if let max = age.maxAge, max < 0 || max > 120 {
                errors.append(.init(level: .error, field: "ageRange.maxAge", message: "Invalid maxAge", code: "invalid_age"))
            }
        }
        // Grade range
        if let grade = opp.gradeRange {
            if let min = grade.gradeMin, let max = grade.gradeMax, !min.isEmpty && !max.isEmpty {
                // Check if gradeMin and gradeMax are parseable, but we don't have strict validation; just warn if both present but eligibleGrades empty and they are not empty
                if grade.eligibleGrades.isEmpty {
                    warnings.append(.init(level: .warning, field: "gradeRange", message: "Could not parse grade range", code: "unparseable_grade"))
                }
            }
            if grade.eligibleGrades.contains(where: { $0.rawValue.isEmpty }) {
                errors.append(.init(level: .error, field: "gradeRange", message: "Invalid grade", code: "invalid_grade"))
            }
        }
        // Deadline relationships
        if let dl = opp.deadlineInfo, let date = dl.date {
            if let verified = opp.lastVerified, date < verified.addingTimeInterval(-365*24*3600) {
                warnings.append(.init(level: .warning, field: "deadline", message: "Deadline far in past relative to verification", code: "stale_deadline"))
            }
        }
        // Cost
        if let cost = opp.costInfo {
            if let amt = cost.amount, amt < 0 {
                errors.append(.init(level: .error, field: "cost.amount", message: "Negative cost", code: "negative_cost"))
            }
            if cost.isFree == true, let amt = cost.amount, amt != 0 {
                errors.append(.init(level: .error, field: "cost", message: "Free but amount not 0", code: "invalid_cost"))
            }
        }
        // Source
        if opp.source.sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.init(level: .error, field: "source.sourceID", message: "Source ID empty", code: "empty_source_id"))
        }
        if opp.source.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.init(level: .error, field: "source.sourceName", message: "Source name empty", code: "empty_source_name"))
        }
        // Duplicate nested IDs
        let reqIDs = opp.applicationRequirements.map(\.id)
        if Set(reqIDs).count != reqIDs.count {
            errors.append(.init(level: .error, field: "applicationRequirements", message: "Duplicate requirement IDs", code: "duplicate_ids"))
        }
        // Warnings
        if opp.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append(.init(level: .warning, field: "description", message: "Missing description", code: "missing_description"))
        }
        if opp.deadlineInfo == nil {
            warnings.append(.init(level: .warning, field: "deadline", message: "No deadline", code: "missing_deadline"))
        }
        if opp.costInfo == nil || opp.costInfo?.isUnknown == true {
            warnings.append(.init(level: .warning, field: "cost", message: "Unknown cost", code: "unknown_cost"))
        }
        if opp.eligibilityInfo == nil || opp.eligibilityInfo?.isUnknown == true {
            warnings.append(.init(level: .warning, field: "eligibility", message: "No eligibility data", code: "missing_eligibility"))
        }
        if opp.skills.isEmpty && opp.interests.isEmpty && opp.careerFields.isEmpty {
            warnings.append(.init(level: .warning, field: "skills", message: "No skills/interests/career fields", code: "missing_taxonomy"))
        }

        let isValid = errors.isEmpty
        return OpportunityValidationResult(isValid: isValid, errors: errors, warnings: warnings)
    }

    private static func isValidURL(_ s: String) -> Bool {
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(), ["http","https"].contains(scheme), url.host != nil else { return false }
        return true
    }
}

// MARK: - Deduplication

enum DuplicateMatchReason: String, Codable, Hashable {
    case exactID = "exactID"
    case sourceID = "sourceID"
    case canonicalURL = "canonicalURL"
    case normalizedIdentity = "normalizedIdentity"
}

struct DuplicateMatch: Hashable, Codable {
    let existingID: String
    let incomingID: String
    let reason: DuplicateMatchReason
    let confidence: Double // 0-1
}

enum OpportunityDeduper {
    static func isDuplicate(_ a: Opportunity, _ b: Opportunity) -> (Bool, DuplicateMatchReason?) {
        // 1. exact canonical ID
        if a.id.lowercased() == b.id.lowercased() && !a.id.isEmpty {
            return (true, .exactID)
        }
        // 2. normalized source + source opportunity ID
        // Hierarchy: same publisher/sourceID AND same canonical sourceURL (when both present)
        if !a.source.sourceID.isEmpty && !b.source.sourceID.isEmpty
            && a.source.sourceID.lowercased() == b.source.sourceID.lowercased() {
            if let aURL = a.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !aURL.isEmpty,
               let bURL = b.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !bURL.isEmpty,
               aURL.lowercased() == bURL.lowercased() {
                return (true, .sourceID)
            }
            // Also treat same sourceID + same canonical opportunity ID suffix as duplicate when trustworthy
            // (covers case where id already contains externalId)
            if !a.id.isEmpty && !b.id.isEmpty && a.id.lowercased() == b.id.lowercased() {
                return (true, .sourceID)
            }
        }
        // 3. canonical source URL (normalized)
        if let aURL = a.sourceURL?.lowercased(), let bURL = b.sourceURL?.lowercased(), !aURL.isEmpty, aURL == bURL {
            return (true, .canonicalURL)
        }
        if let aOff = a.officialURL?.absoluteString.lowercased(), let bOff = b.officialURL?.absoluteString.lowercased(), !aOff.isEmpty, aOff == bOff {
            return (true, .canonicalURL)
        }
        // 4. normalized organization + title + deadline display
        let aNorm = "\(a.organization.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(a.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(a.deadlineInfo?.displayString.lowercased() ?? "")"
        let bNorm = "\(b.organization.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(b.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(b.deadlineInfo?.displayString.lowercased() ?? "")"
        if aNorm == bNorm && !aNorm.replacingOccurrences(of: "|", with: "").isEmpty {
            return (true, .normalizedIdentity)
        }
        return (false, nil)
    }

    static func deduplicate(_ opportunities: [Opportunity]) -> (unique: [Opportunity], duplicates: [(Opportunity, DuplicateMatch)]) {
        var seen: [Opportunity] = []
        var duplicates: [(Opportunity, DuplicateMatch)] = []
        var idMap: [String: Opportunity] = [:] // normalized id -> opp
        var urlMap: [String: Opportunity] = [:] // normalized url -> opp
        var normMap: [String: Opportunity] = [:] // normalized identity -> opp

        for opp in opportunities {
            // Check exact ID
            let normID = opp.id.lowercased()
            if let existing = idMap[normID] {
                duplicates.append((opp, DuplicateMatch(existingID: existing.id, incomingID: opp.id, reason: .exactID, confidence: 1.0)))
                continue
            }
            // Check URL
            if let url = opp.sourceURL?.lowercased(), let existing = urlMap[url] {
                duplicates.append((opp, DuplicateMatch(existingID: existing.id, incomingID: opp.id, reason: .canonicalURL, confidence: 0.95)))
                continue
            }
            if let url = opp.officialURL?.absoluteString.lowercased(), let existing = urlMap[url] {
                duplicates.append((opp, DuplicateMatch(existingID: existing.id, incomingID: opp.id, reason: .canonicalURL, confidence: 0.95)))
                continue
            }
            // Check normalized identity
            let normKey = "\(opp.organization.lowercased())|\(opp.title.lowercased())|\(opp.deadlineInfo?.displayString.lowercased() ?? "")"
            if let existing = normMap[normKey] {
                // Only consider duplicate if organization and title both non-empty
                if !opp.organization.isEmpty && !opp.title.isEmpty {
                    duplicates.append((opp, DuplicateMatch(existingID: existing.id, incomingID: opp.id, reason: .normalizedIdentity, confidence: 0.8)))
                    continue
                }
            }
            // Also check full deduper hierarchy for near matches (sourceID etc.)
            var foundDuplicate: DuplicateMatch? = nil
            for existing in seen {
                let (isDup, reason) = isDuplicate(existing, opp)
                if isDup, let r = reason {
                    foundDuplicate = DuplicateMatch(existingID: existing.id, incomingID: opp.id, reason: r, confidence: 0.9)
                    break
                }
            }
            if let dup = foundDuplicate {
                duplicates.append((opp, dup))
                continue
            }

            // Unique
            seen.append(opp)
            idMap[normID] = opp
            if let url = opp.sourceURL?.lowercased() { urlMap[url] = opp }
            if let url = opp.officialURL?.absoluteString.lowercased() { urlMap[url] = opp }
            normMap[normKey] = opp
        }

        // Deterministic ordering of unique
        let sortedUnique = seen.sorted { a, b in
            if a.title.lowercased() != b.title.lowercased() { return a.title.lowercased() < b.title.lowercased() }
            if a.organization.lowercased() != b.organization.lowercased() { return a.organization.lowercased() < b.organization.lowercased() }
            return a.id < b.id
        }

        return (sortedUnique, duplicates)
    }
}

// MARK: - Freshness

enum OpportunityFreshnessService {
    static func freshness(for opp: Opportunity, now: Date = Date()) -> OpportunityFreshnessInfo {
        // Check deadline first
        if let dl = opp.deadlineInfo, let date = dl.date {
            let days = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
            if days < 0 {
                return OpportunityFreshnessInfo(freshness: .expired, daysUntilDeadline: days, isExpired: true, lastVerified: opp.lastVerified)
            }
            // Not expired, check freshness based on lastVerified
            let freshness = freshnessFromLastVerified(lastVerified: opp.lastVerified, now: now)
            return OpportunityFreshnessInfo(freshness: freshness, daysUntilDeadline: days, isExpired: false, lastVerified: opp.lastVerified)
        }
        // No deadline date, check lastVerified
        if dlTypeIsRolling(opp) {
            return OpportunityFreshnessInfo(freshness: .fresh, daysUntilDeadline: nil, isExpired: false, lastVerified: opp.lastVerified)
        }
        let freshness = freshnessFromLastVerified(lastVerified: opp.lastVerified, now: now)
        let isExpired = freshness == .expired
        return OpportunityFreshnessInfo(freshness: freshness, daysUntilDeadline: nil, isExpired: isExpired, lastVerified: opp.lastVerified)
    }

    private static func dlTypeIsRolling(_ opp: Opportunity) -> Bool {
        opp.deadlineInfo?.type == .rolling
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

    static func isExpired(_ opp: Opportunity, now: Date = Date()) -> Bool {
        freshness(for: opp, now: now).isExpired
    }

    static func isFresh(_ opp: Opportunity, now: Date = Date()) -> Bool {
        freshness(for: opp, now: now).freshness == .fresh
    }
}

// MARK: - Repository

@MainActor
final class OpportunityRepository {
    private(set) var opportunities: [Opportunity] = []

    // Deterministic ordering: title ascending, organization ascending, id ascending
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

    @discardableResult
    func insert(_ opp: Opportunity) -> Bool {
        let validation = OpportunityValidator.validate(opp)
        guard validation.isValid else { return false }
        // Deduplication check
        for existing in opportunities {
            let (isDup, _) = OpportunityDeduper.isDuplicate(existing, opp)
            if isDup { return false }
        }
        opportunities.append(opp)
        opportunities = sorted(opportunities)
        return true
    }

    @discardableResult
    func upsert(_ opp: Opportunity) -> Bool {
        let validation = OpportunityValidator.validate(opp)
        guard validation.isValid else { return false }
        // Remove existing duplicates
        opportunities.removeAll { existing in
            let (isDup, _) = OpportunityDeduper.isDuplicate(existing, opp)
            return isDup
        }
        opportunities.append(opp)
        opportunities = sorted(opportunities)
        return true
    }

    @discardableResult
    func remove(id: String) -> Bool {
        let tid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tid.isEmpty else { return false }
        let before = opportunities.count
        opportunities.removeAll(where: { $0.id == tid })
        return opportunities.count < before
    }

    func replaceAll(with newOpportunities: [Opportunity]) {
        var unique: [Opportunity] = []
        var seenIDs = Set<String>()
        for opp in newOpportunities {
            let validation = OpportunityValidator.validate(opp)
            guard validation.isValid else { continue }
            let normID = opp.id.lowercased()
            if seenIDs.contains(normID) { continue }
            // Deduplicate against already added
            var isDup = false
            for existing in unique {
                let (dup, _) = OpportunityDeduper.isDuplicate(existing, opp)
                if dup { isDup = true; break }
            }
            if isDup { continue }
            seenIDs.insert(normID)
            unique.append(opp)
        }
        opportunities = sorted(unique)
    }

    // For Raw ingestion
    func ingest(rawRecords: [RawOpportunityRecord]) -> (inserted: Int, duplicates: Int, invalid: Int) {
        var inserted = 0, duplicates = 0, invalid = 0
        for raw in rawRecords {
            let opp = OpportunityNormalizer.normalize(raw)
            let validation = OpportunityValidator.validate(opp)
            if !validation.isValid {
                invalid += 1
                continue
            }
            // Check duplicate
            var isDup = false
            for existing in opportunities {
                let (dup, _) = OpportunityDeduper.isDuplicate(existing, opp)
                if dup { isDup = true; break }
            }
            if isDup {
                duplicates += 1
                continue
            }
            opportunities.append(opp)
            inserted += 1
        }
        opportunities = sorted(opportunities)
        return (inserted, duplicates, invalid)
    }

    func clear() { opportunities.removeAll() }

    // Persistence helpers (Codable)
    func save(to url: URL) throws {
        let data = try JSONEncoder().encode(opportunities)
        try data.write(to: url)
    }

    func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([Opportunity].self, from: data)
        opportunities = sorted(decoded)
    }
}
