import Foundation

// MARK: - Canonical Opportunity Model (Phase 10A)
// Single source of truth for opportunity intelligence. Deterministic, Codable, strongly-typed.
// Distinguishes explicitly known vs unknown vs false for eligibility, cost, location, deadline, etc.

struct Opportunity: Identifiable, Hashable, Codable {
    // MARK: Core Identity
    let id: String
    let title: String
    let organization: String
    let organizationDescription: String?
    let opportunityType: OpportunityType
    let description: String

    // MARK: Location & Delivery
    let location: OpportunityLocation
    let deliveryMode: OpportunityDeliveryMode

    // MARK: Eligibility (unknown vs false)
    let ageRange: OpportunityAgeRange? // nil = unknown
    let gradeRange: OpportunityGradeRange? // nil = unknown
    let eligibilityInfo: OpportunityEligibility?
    let applicationRequirements: [OpportunityRequirement]
    let deadlineInfo: OpportunityDeadline?
    let costInfo: OpportunityCost?

    // MARK: Skills / Interests / Career Fields (normalized)
    let skills: [String] // Skill.normalizeID applied
    let interests: [String]
    let careerFields: [String]

    // MARK: Source & Freshness
    let source: OpportunitySource
    let sourceURL: String? // original source URL, validated http/https
    let lastVerified: Date?
    let status: OpportunityStatus

    // MARK: Legacy compatibility (kept for existing Explore UI, computed from canonical where possible)
    // These are derived for backward compatibility; decoding supports both old and new JSON.
    let category: OpportunityCategory
    let legacyDeadline: String // old deadline: String
    let legacyLocation: String
    let legacyEligibility: String
    let whyItMatches: String
    let requirements: [String]
    let importantDates: [String]
    let officialURL: URL?
    let relevantInterests: Set<String>
    let relevantSkills: Set<String>
    let relevantCareers: Set<String>
    let relevantFields: Set<String>
    let eligibleGrades: Set<Grade>
    let relevantLocations: Set<String>

    var sourceLabel: String { source.sourceName.isEmpty ? "Student OPS" : source.sourceName }
    var deadline: String { legacyDeadline }
    var deadlineLabel: String { legacyDeadline }

    // MARK: - Initializers

    init(
        id: String,
        title: String,
        organization: String,
        organizationDescription: String? = nil,
        opportunityType: OpportunityType,
        description: String,
        location: OpportunityLocation,
        deliveryMode: OpportunityDeliveryMode = .unknown,
        ageRange: OpportunityAgeRange? = nil,
        gradeRange: OpportunityGradeRange? = nil,
        eligibilityInfo: OpportunityEligibility? = nil,
        applicationRequirements: [OpportunityRequirement] = [],
        deadlineInfo: OpportunityDeadline? = nil,
        costInfo: OpportunityCost? = nil,
        skills: [String] = [],
        interests: [String] = [],
        careerFields: [String] = [],
        source: OpportunitySource,
        sourceURL: String? = nil,
        lastVerified: Date? = nil,
        status: OpportunityStatus = .active,
        // Legacy
        category: OpportunityCategory? = nil,
        legacyDeadline: String? = nil,
        legacyLocation: String? = nil,
        legacyEligibility: String? = nil,
        whyItMatches: String? = nil,
        requirements: [String]? = nil,
        importantDates: [String]? = nil,
        officialURL: URL? = nil,
        relevantInterests: Set<String>? = nil,
        relevantSkills: Set<String>? = nil,
        relevantCareers: Set<String>? = nil,
        relevantFields: Set<String>? = nil,
        eligibleGrades: Set<Grade>? = nil,
        relevantLocations: Set<String>? = nil
    ) {
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
        // Normalize skills via existing system
        var seenSkills = Set<String>()
        var normSkills: [String] = []
        for raw in skills {
            let nid = Skill.normalizeID(raw)
            guard !nid.isEmpty, !seenSkills.contains(nid) else { continue }
            seenSkills.insert(nid)
            normSkills.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        self.skills = normSkills
        self.interests = interests.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.careerFields = careerFields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.source = source
        let srcURL = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceURL = (srcURL?.isEmpty == true) ? nil : srcURL
        self.lastVerified = lastVerified
        self.status = status

        // Legacy derived or provided
        self.category = category ?? OpportunityTypeMapper.category(for: opportunityType)
        self.legacyDeadline = legacyDeadline ?? deadlineInfo?.displayString ?? "Rolling"
        self.legacyLocation = legacyLocation ?? location.displayString
        self.legacyEligibility = legacyEligibility ?? eligibilityInfo?.displayString ?? "Unknown"
        self.whyItMatches = whyItMatches ?? ""
        self.requirements = requirements ?? applicationRequirements.map(\.title)
        self.importantDates = importantDates ?? (deadlineInfo.map { [$0.displayString] } ?? [])
        self.officialURL = officialURL ?? (sourceURL.flatMap { URL(string: $0) })
        self.relevantInterests = relevantInterests ?? Set(interests)
        self.relevantSkills = relevantSkills ?? Set(normSkills)
        self.relevantCareers = relevantCareers ?? Set(careerFields)
        self.relevantFields = relevantFields ?? Set(careerFields)
        self.eligibleGrades = eligibleGrades ?? gradeRange?.eligibleGrades ?? []
        self.relevantLocations = relevantLocations ?? Set([location.displayString])
    }

    // MARK: - Legacy initializer (backward compatibility for local catalog)

    init(
        id: String,
        title: String,
        organization: String,
        category: OpportunityCategory,
        deadline: String,
        location legacyLocationString: String,
        eligibility: String,
        description: String,
        whyItMatches: String,
        requirements: [String],
        importantDates: [String],
        officialURL: URL?,
        relevantInterests: Set<String>,
        relevantSkills: Set<String>,
        relevantCareers: Set<String>,
        relevantFields: Set<String>,
        eligibleGrades: Set<Grade>,
        relevantLocations: Set<String>
    ) {
        // Map legacy category to canonical type
        let type = OpportunityTypeMapper.type(for: category)
        // Parse location string to canonical location
        let locLower = legacyLocationString.lowercased()
        let locType: String
        let delivery: OpportunityDeliveryMode
        if locLower.contains("online") && locLower.contains("hybrid") {
            locType = "hybrid"; delivery = .hybrid
        } else if locLower.contains("online") {
            locType = "online"; delivery = .online
        } else if locLower.contains("in person") {
            locType = "inPerson"; delivery = .inPerson
        } else {
            locType = "unknown"; delivery = .unknown
        }
        let loc = OpportunityLocation(type: locType, city: nil, state: nil, country: nil, online: delivery == .online || delivery == .hybrid, latitude: nil, longitude: nil)
        // Deadline
        let deadlineTrim = deadline.trimmingCharacters(in: .whitespacesAndNewlines)
        let deadlineInfo: OpportunityDeadline?
        if deadlineTrim.lowercased() == "rolling" {
            deadlineInfo = OpportunityDeadline(date: nil, type: .rolling, displayString: "Rolling")
        } else if deadlineTrim.isEmpty {
            deadlineInfo = nil
        } else {
            deadlineInfo = OpportunityDeadline(date: nil, type: .unknown, displayString: deadlineTrim)
        }
        // Source
        let src = OpportunitySource(sourceID: "local-\(id)", sourceName: organization, sourceType: .staticSeed, sourceURL: officialURL?.absoluteString, retrievedAt: Date(), publisher: organization)

        self.init(
            id: id,
            title: title,
            organization: organization,
            organizationDescription: nil,
            opportunityType: type,
            description: description,
            location: loc,
            deliveryMode: delivery,
            ageRange: nil,
            gradeRange: OpportunityGradeRange(gradeMin: nil, gradeMax: nil, eligibleGrades: eligibleGrades),
            eligibilityInfo: OpportunityEligibility(details: eligibility, requirements: []),
            applicationRequirements: requirements.map { OpportunityRequirement(title: $0) },
            deadlineInfo: deadlineInfo,
            costInfo: nil,
            skills: Array(relevantSkills),
            interests: Array(relevantInterests),
            careerFields: Array(relevantFields.union(relevantCareers)),
            source: src,
            sourceURL: officialURL?.absoluteString,
            lastVerified: Date(),
            status: .active,
            category: category,
            legacyDeadline: deadline,
            legacyLocation: legacyLocationString,
            legacyEligibility: eligibility,
            whyItMatches: whyItMatches,
            requirements: requirements,
            importantDates: importantDates,
            officialURL: officialURL,
            relevantInterests: relevantInterests,
            relevantSkills: relevantSkills,
            relevantCareers: relevantCareers,
            relevantFields: relevantFields,
            eligibleGrades: eligibleGrades,
            relevantLocations: relevantLocations
        )
    }

    // MARK: - Codable (backward compatible)

    enum CodingKeys: String, CodingKey {
        case id, title, organization, organizationDescription, opportunityType, description
        case location, deliveryMode, ageRange, gradeRange, eligibilityInfo, applicationRequirements, deadlineInfo, costInfo
        case skills, interests, careerFields, source, sourceURL, lastVerified, status
        // Legacy
        case category, legacyDeadline, deadline, legacyLocation, legacyEligibility, eligibility, whyItMatches, requirements, importantDates, officialURL, relevantInterests, relevantSkills, relevantCareers, relevantFields, eligibleGrades, relevantLocations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        organization = (try? c.decode(String.self, forKey: .organization)) ?? ""
        organizationDescription = try? c.decode(String.self, forKey: .organizationDescription)
        // opportunityType may be stored as OpportunityType or string
        if let ot = try? c.decode(OpportunityType.self, forKey: .opportunityType) {
            opportunityType = ot
        } else if let raw = try? c.decode(String.self, forKey: .opportunityType) {
            opportunityType = OpportunityType(rawValue: raw) ?? .other
        } else if let cat = try? c.decode(OpportunityCategory.self, forKey: .category) {
            opportunityType = OpportunityTypeMapper.type(for: cat)
        } else {
            opportunityType = .other
        }
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        location = (try? c.decode(OpportunityLocation.self, forKey: .location)) ?? OpportunityLocation(type: "unknown", city: nil, state: nil, country: nil, online: nil, latitude: nil, longitude: nil)
        deliveryMode = (try? c.decode(OpportunityDeliveryMode.self, forKey: .deliveryMode)) ?? .unknown
        ageRange = try? c.decode(OpportunityAgeRange.self, forKey: .ageRange)
        gradeRange = try? c.decode(OpportunityGradeRange.self, forKey: .gradeRange)
        eligibilityInfo = try? c.decode(OpportunityEligibility.self, forKey: .eligibilityInfo)
        applicationRequirements = (try? c.decode([OpportunityRequirement].self, forKey: .applicationRequirements)) ?? []
        deadlineInfo = try? c.decode(OpportunityDeadline.self, forKey: .deadlineInfo)
        costInfo = try? c.decode(OpportunityCost.self, forKey: .costInfo)
        // Skills normalized
        let rawSkills = (try? c.decode([String].self, forKey: .skills)) ?? []
        var seen = Set<String>()
        var normed: [String] = []
        for raw in rawSkills {
            let nid = Skill.normalizeID(raw)
            if !nid.isEmpty, !seen.contains(nid) {
                seen.insert(nid); normed.append(raw.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        skills = normed
        interests = (try? c.decode([String].self, forKey: .interests)) ?? []
        careerFields = (try? c.decode([String].self, forKey: .careerFields)) ?? []
        source = (try? c.decode(OpportunitySource.self, forKey: .source)) ?? OpportunitySource(sourceID: "unknown", sourceName: "Unknown", sourceType: .manual, sourceURL: nil, retrievedAt: Date(), publisher: nil)
        sourceURL = try? c.decode(String.self, forKey: .sourceURL)
        if let d = try? c.decode(Date.self, forKey: .lastVerified) {
            lastVerified = d
        } else if let s = try? c.decode(String.self, forKey: .lastVerified), let d = ISO8601DateFormatter().date(from: s) {
            lastVerified = d
        } else {
            lastVerified = nil
        }
        status = (try? c.decode(OpportunityStatus.self, forKey: .status)) ?? .active

        // Legacy
        if let cat = try? c.decode(OpportunityCategory.self, forKey: .category) {
            category = cat
        } else {
            category = OpportunityTypeMapper.category(for: opportunityType)
        }
        if let ld = try? c.decode(String.self, forKey: .legacyDeadline) {
            legacyDeadline = ld
        } else if let d = try? c.decode(String.self, forKey: .deadline) {
            legacyDeadline = d
        } else {
            legacyDeadline = deadlineInfo?.displayString ?? "Rolling"
        }
        if let ll = try? c.decode(String.self, forKey: .legacyLocation) {
            legacyLocation = ll
        } else if let l = try? c.decode(String.self, forKey: .location), (try? c.decode(OpportunityLocation.self, forKey: .location)) == nil {
            // Old location was String, not struct
            legacyLocation = l
        } else {
            legacyLocation = location.displayString
        }
        if let le = try? c.decode(String.self, forKey: .legacyEligibility) {
            legacyEligibility = le
        } else if let e = try? c.decode(String.self, forKey: .eligibility), (try? c.decode(OpportunityEligibility.self, forKey: .eligibilityInfo)) == nil {
            legacyEligibility = e
        } else {
            legacyEligibility = eligibilityInfo?.displayString ?? "Unknown"
        }
        whyItMatches = (try? c.decode(String.self, forKey: .whyItMatches)) ?? ""
        requirements = (try? c.decode([String].self, forKey: .requirements)) ?? applicationRequirements.map(\.title)
        importantDates = (try? c.decode([String].self, forKey: .importantDates)) ?? []
        if let urlStr = try? c.decode(String.self, forKey: .officialURL), let url = URL(string: urlStr) {
            officialURL = url
        } else if let url = try? c.decode(URL.self, forKey: .officialURL) {
            officialURL = url
        } else {
            officialURL = sourceURL.flatMap { URL(string: $0) }
        }
        relevantInterests = (try? c.decode(Set<String>.self, forKey: .relevantInterests)) ?? Set(interests)
        relevantSkills = (try? c.decode(Set<String>.self, forKey: .relevantSkills)) ?? Set(skills)
        relevantCareers = (try? c.decode(Set<String>.self, forKey: .relevantCareers)) ?? Set(careerFields)
        relevantFields = (try? c.decode(Set<String>.self, forKey: .relevantFields)) ?? Set(careerFields)
        eligibleGrades = (try? c.decode(Set<Grade>.self, forKey: .eligibleGrades)) ?? gradeRange?.eligibleGrades ?? []
        relevantLocations = (try? c.decode(Set<String>.self, forKey: .relevantLocations)) ?? Set([location.displayString])
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(organization, forKey: .organization)
        try c.encodeIfPresent(organizationDescription, forKey: .organizationDescription)
        try c.encode(opportunityType, forKey: .opportunityType)
        try c.encode(description, forKey: .description)
        try c.encode(location, forKey: .location)
        try c.encode(deliveryMode, forKey: .deliveryMode)
        try c.encodeIfPresent(ageRange, forKey: .ageRange)
        try c.encodeIfPresent(gradeRange, forKey: .gradeRange)
        try c.encodeIfPresent(eligibilityInfo, forKey: .eligibilityInfo)
        try c.encode(applicationRequirements, forKey: .applicationRequirements)
        try c.encodeIfPresent(deadlineInfo, forKey: .deadlineInfo)
        try c.encodeIfPresent(costInfo, forKey: .costInfo)
        try c.encode(skills, forKey: .skills)
        try c.encode(interests, forKey: .interests)
        try c.encode(careerFields, forKey: .careerFields)
        try c.encode(source, forKey: .source)
        try c.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try c.encodeIfPresent(lastVerified, forKey: .lastVerified)
        try c.encode(status, forKey: .status)
        try c.encode(category, forKey: .category)
        try c.encode(legacyDeadline, forKey: .legacyDeadline)
        try c.encode(legacyLocation, forKey: .legacyLocation)
        try c.encode(legacyEligibility, forKey: .legacyEligibility)
        try c.encode(whyItMatches, forKey: .whyItMatches)
        try c.encode(requirements, forKey: .requirements)
        try c.encode(importantDates, forKey: .importantDates)
        try c.encodeIfPresent(officialURL?.absoluteString, forKey: .officialURL)
        try c.encode(relevantInterests, forKey: .relevantInterests)
        try c.encode(relevantSkills, forKey: .relevantSkills)
        try c.encode(relevantCareers, forKey: .relevantCareers)
        try c.encode(relevantFields, forKey: .relevantFields)
        try c.encode(eligibleGrades, forKey: .eligibleGrades)
        try c.encode(relevantLocations, forKey: .relevantLocations)
    }
}

struct ScoredOpportunity: Identifiable, Hashable {
    let opportunity: Opportunity
    let matchScore: Int
    var id: String { opportunity.id }
}

// MARK: - Supporting Types

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

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "other"
        self = OpportunityType(rawValue: raw) ?? .other
    }
}

enum OpportunityDeliveryMode: String, Codable, Hashable, CaseIterable {
    case inPerson = "inPerson"
    case online = "online"
    case hybrid = "hybrid"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "unknown"
        // Normalize aliases
        let norm = raw.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "")
        switch norm {
        case "inperson", "in-person", "onsite": self = .inPerson
        case "online", "remote", "virtual": self = .online
        case "hybrid": self = .hybrid
        default: self = .unknown
        }
    }
}

struct OpportunityLocation: Hashable, Codable {
    let type: String // online, inPerson, hybrid, unknown (legacy string, but we also have deliveryMode)
    let city: String?
    let state: String?
    let country: String?
    let online: Bool?
    let latitude: Double?
    let longitude: Double?

    init(type: String, city: String?, state: String?, country: String?, online: Bool?, latitude: Double?, longitude: Double?) {
        self.type = type
        self.city = city?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.state = state?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.country = country?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.online = online
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? "unknown"
        city = try? c.decode(String.self, forKey: .city)
        state = try? c.decode(String.self, forKey: .state)
        country = try? c.decode(String.self, forKey: .country)
        online = try? c.decode(Bool.self, forKey: .online)
        latitude = try? c.decode(Double.self, forKey: .latitude)
        longitude = try? c.decode(Double.self, forKey: .longitude)
    }

    enum CodingKeys: String, CodingKey { case type, city, state, country, online, latitude, longitude }

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

    init(minAge: Int?, maxAge: Int?) {
        self.minAge = minAge
        self.maxAge = maxAge
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        minAge = try? c.decode(Int.self, forKey: .minAge)
        maxAge = try? c.decode(Int.self, forKey: .maxAge)
    }

    enum CodingKeys: String, CodingKey { case minAge, maxAge }

    var isUnknown: Bool { minAge == nil && maxAge == nil }
}

struct OpportunityGradeRange: Hashable, Codable {
    let gradeMin: String?
    let gradeMax: String?
    let eligibleGrades: Set<Grade>

    init(gradeMin: String?, gradeMax: String?, eligibleGrades: Set<Grade>) {
        self.gradeMin = gradeMin?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.gradeMax = gradeMax?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.eligibleGrades = eligibleGrades
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gradeMin = try? c.decode(String.self, forKey: .gradeMin)
        gradeMax = try? c.decode(String.self, forKey: .gradeMax)
        eligibleGrades = (try? c.decode(Set<Grade>.self, forKey: .eligibleGrades)) ?? []
    }

    enum CodingKeys: String, CodingKey { case gradeMin, gradeMax, eligibleGrades }

    var isUnknown: Bool { gradeMin == nil && gradeMax == nil && eligibleGrades.isEmpty }
}

struct OpportunityRequirement: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String?
    let required: Bool

    init(id: String = UUID().uuidString, title: String, description: String? = nil, required: Bool = true) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = desc?.isEmpty == true ? nil : desc
        self.required = required
    }

    enum CodingKeys: String, CodingKey { case id, title, description, required }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        required = (try? c.decode(Bool.self, forKey: .required)) ?? true
    }
}

struct OpportunityDeadline: Hashable, Codable {
    let date: Date?
    let type: DeadlineType
    let displayString: String

    enum DeadlineType: String, Codable, Hashable {
        case fixed = "fixed"
        case rolling = "rolling"
        case noDeadline = "noDeadline"
        case unknown = "unknown"
    }

    init(date: Date?, type: DeadlineType, displayString: String? = nil) {
        self.date = date
        self.type = type
        if let ds = displayString?.trimmingCharacters(in: .whitespacesAndNewlines), !ds.isEmpty {
            self.displayString = ds
        } else if let d = date {
            let f = DateFormatter()
            f.dateStyle = .medium
            self.displayString = f.string(from: d)
        } else {
            self.displayString = type == .rolling ? "Rolling" : type == .noDeadline ? "No deadline" : "Unknown"
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let d = try? c.decode(Date.self, forKey: .date) {
            date = d
        } else if let s = try? c.decode(String.self, forKey: .date), let d = ISO8601DateFormatter().date(from: s) ?? DateFormatter().date(from: s) {
            date = d
        } else {
            date = nil
        }
        type = (try? c.decode(DeadlineType.self, forKey: .type)) ?? .unknown
        displayString = (try? c.decode(String.self, forKey: .displayString)) ?? (type == .rolling ? "Rolling" : "Unknown")
    }

    enum CodingKeys: String, CodingKey { case date, type, displayString }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(date, forKey: .date)
        try c.encode(type, forKey: .type)
        try c.encode(displayString, forKey: .displayString)
    }
}

struct OpportunityCost: Hashable, Codable {
    let amount: Double?
    let currency: String?
    let isFree: Bool? // nil = unknown

    init(amount: Double?, currency: String?, isFree: Bool?) {
        self.amount = amount
        let cur = currency?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.currency = cur?.isEmpty == true ? nil : cur
        self.isFree = isFree
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        amount = try? c.decode(Double.self, forKey: .amount)
        currency = try? c.decode(String.self, forKey: .currency)
        isFree = try? c.decode(Bool.self, forKey: .isFree)
    }

    enum CodingKeys: String, CodingKey { case amount, currency, isFree }

    var isUnknown: Bool { isFree == nil && amount == nil }
    var isFreeValue: Bool? { isFree }
}

struct OpportunityEligibility: Hashable, Codable {
    let details: String?
    let requirements: [String]

    init(details: String?, requirements: [String] = []) {
        let d = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = d?.isEmpty == true ? nil : d
        self.requirements = requirements.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        details = try? c.decode(String.self, forKey: .details)
        requirements = (try? c.decode([String].self, forKey: .requirements)) ?? []
    }

    enum CodingKeys: String, CodingKey { case details, requirements }

    var displayString: String { details ?? (requirements.isEmpty ? "Unknown" : requirements.joined(separator: ", ")) }
    var isUnknown: Bool { details == nil && requirements.isEmpty }
}

struct OpportunitySource: Hashable, Codable {
    let sourceID: String
    let sourceName: String
    let sourceType: SourceType
    let sourceURL: String?
    let retrievedAt: Date
    let publisher: String?

    enum SourceType: String, Codable, Hashable {
        case staticSeed = "staticSeed"
        case api = "api"
        case jsonFeed = "jsonFeed"
        case manual = "manual"
        case other = "other"

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            let raw = (try? c.decode(String.self)) ?? "other"
            self = SourceType(rawValue: raw) ?? .other
        }
    }

    init(sourceID: String, sourceName: String, sourceType: SourceType, sourceURL: String?, retrievedAt: Date, publisher: String?) {
        self.sourceID = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceType = sourceType
        let url = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceURL = url?.isEmpty == true ? nil : url
        self.retrievedAt = retrievedAt
        let pub = publisher?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.publisher = pub?.isEmpty == true ? nil : pub
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sourceID = (try? c.decode(String.self, forKey: .sourceID)) ?? UUID().uuidString
        sourceName = (try? c.decode(String.self, forKey: .sourceName)) ?? "Unknown"
        sourceType = (try? c.decode(SourceType.self, forKey: .sourceType)) ?? .other
        sourceURL = try? c.decode(String.self, forKey: .sourceURL)
        if let d = try? c.decode(Date.self, forKey: .retrievedAt) {
            retrievedAt = d
        } else if let s = try? c.decode(String.self, forKey: .retrievedAt), let d = ISO8601DateFormatter().date(from: s) {
            retrievedAt = d
        } else {
            retrievedAt = Date()
        }
        publisher = try? c.decode(String.self, forKey: .publisher)
    }

    enum CodingKeys: String, CodingKey { case sourceID, sourceName, sourceType, sourceURL, retrievedAt, publisher }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sourceID, forKey: .sourceID)
        try c.encode(sourceName, forKey: .sourceName)
        try c.encode(sourceType, forKey: .sourceType)
        try c.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try c.encode(retrievedAt, forKey: .retrievedAt)
        try c.encodeIfPresent(publisher, forKey: .publisher)
    }
}

enum OpportunityFreshness: String, Codable, Hashable {
    case fresh = "fresh"
    case aging = "aging"
    case stale = "stale"
    case expired = "expired"
    case unknown = "unknown"
}

enum OpportunityStatus: String, Codable, Hashable {
    case active = "active"
    case expired = "expired"
    case archived = "archived"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? "unknown"
        self = OpportunityStatus(rawValue: raw) ?? .unknown
    }
}

struct OpportunityFreshnessInfo: Hashable, Codable {
    let freshness: OpportunityFreshness
    let daysUntilDeadline: Int?
    let isExpired: Bool
    let lastVerified: Date?

    init(freshness: OpportunityFreshness, daysUntilDeadline: Int?, isExpired: Bool, lastVerified: Date?) {
        self.freshness = freshness
        self.daysUntilDeadline = daysUntilDeadline
        self.isExpired = isExpired
        self.lastVerified = lastVerified
    }

    enum CodingKeys: String, CodingKey { case freshness, daysUntilDeadline, isExpired, lastVerified }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        freshness = (try? c.decode(OpportunityFreshness.self, forKey: .freshness)) ?? .unknown
        daysUntilDeadline = try? c.decode(Int.self, forKey: .daysUntilDeadline)
        isExpired = (try? c.decode(Bool.self, forKey: .isExpired)) ?? false
        lastVerified = try? c.decode(Date.self, forKey: .lastVerified)
    }
}

// MARK: - Helpers

enum OpportunityTypeMapper {
    static func category(for type: OpportunityType) -> OpportunityCategory {
        switch type {
        case .competition, .hackathon: return .competitions
        case .scholarship: return .scholarships
        case .research: return .research
        case .volunteering, .community: return .volunteering
        case .leadership, .fellowship: return .leadership
        case .summerProgram: return .summerPrograms
        case .academicProgram, .conference: return .academicPrograms
        case .internship: return .all
        case .other: return .all
        }
    }

    static func type(for category: OpportunityCategory) -> OpportunityType {
        switch category {
        case .competitions: return .competition
        case .scholarships: return .scholarship
        case .research: return .research
        case .volunteering: return .volunteering
        case .leadership: return .leadership
        case .summerPrograms: return .summerProgram
        case .academicPrograms: return .academicProgram
        case .all: return .other
        }
    }
}
