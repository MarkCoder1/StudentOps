import Foundation

// DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
// Generates deterministic realistic eligibility scores 80-99% per opportunity ID for demo.
// Keeps real opportunity names/data; only overrides displayed eligibility status/scores.
// TO REVERT: remove DemoScores helper and the override block at end of evaluate() method.
private enum DemoScores {
    static let enabled = true
    static func score(for id: String) -> Int {
        var hash: Int32 = 0
        for scalar in id.unicodeScalars {
            hash = (hash &<< 5) &- hash &+ Int32(scalar.value)
        }
        let h64 = Int64(hash)
        let absHash: Int64 = h64 == Int64(Int32.min) ? Int64(Int32.max) : (h64 < 0 ? -h64 : h64)
        return 80 + Int(absHash % 20) // 80-99
    }
}

// MARK: - Opportunity Eligibility Intelligence (Phase 10B)
// Authoritative factual eligibility. Deterministic, no AI, no mutation, no database.
// Pipeline: Student Graph + Canonical Opportunity → OpportunityEligibilityResult (eligible/ineligible/unknown)

enum OpportunityEligibilityStatus: String, Codable, Hashable {
    case eligible = "eligible"
    case ineligible = "ineligible"
    case unknown = "unknown"
    case notEvaluated = "notEvaluated"
}

enum OpportunityEligibilityReasonCode: String, Codable, Hashable {
    // Age
    case ageTooYoung = "ageTooYoung"
    case ageTooOld = "ageTooOld"
    case ageSatisfied = "ageSatisfied"
    case ageUnknown = "ageUnknown"
    // Grade
    case gradeTooLow = "gradeTooLow"
    case gradeTooHigh = "gradeTooHigh"
    case gradeSatisfied = "gradeSatisfied"
    case gradeUnknown = "gradeUnknown"
    case gradeNotInAllowed = "gradeNotInAllowed"
    // Location
    case locationMismatch = "locationMismatch"
    case locationSatisfied = "locationSatisfied"
    case locationUnknown = "locationUnknown"
    // Delivery
    case deliverySatisfied = "deliverySatisfied"
    // Cost
    case costSatisfied = "costSatisfied"
    case costUnknown = "costUnknown"
    // Deadline
    case deadlinePassed = "deadlinePassed"
    case deadlineSatisfied = "deadlineSatisfied"
    case deadlineRolling = "deadlineRolling"
    case deadlineUnknown = "deadlineUnknown"
    // Explicit requirements
    case requirementSatisfied = "requirementSatisfied"
    case requirementUnknown = "requirementUnknown"
    case requirementMismatch = "requirementMismatch"
    // Generic
    case eligible = "eligible"
    case unknown = "unknown"
}

struct OpportunityEligibilityReason: Hashable, Codable {
    let code: OpportunityEligibilityReasonCode
    let dimension: String // e.g., "age", "grade", "location", "deadline", "cost", "requirement"
    let message: String
    let blocking: Bool // true if this reason alone would make ineligible
}

struct OpportunityEligibilityResult: Hashable, Codable {
    let opportunityID: String
    let status: OpportunityEligibilityStatus
    let evaluatedRules: [String] // e.g., ["age","grade","location","deadline"]
    let blockingReasons: [OpportunityEligibilityReason]
    let unknownReasons: [OpportunityEligibilityReason]
    let warnings: [OpportunityEligibilityReason]
    let allReasons: [OpportunityEligibilityReason]

    var isEligible: Bool { status == .eligible }
    var isIneligible: Bool { status == .ineligible }
    var isUnknown: Bool { status == .unknown }
}

// MARK: - Pure Eligibility Engine

enum OpportunityEligibilityEngine {

    // MARK: Public API

    static func evaluate(opportunity: Opportunity, profile: StudentProfile, now: Date = Date()) -> OpportunityEligibilityResult {
        var blocking: [OpportunityEligibilityReason] = []
        var unknowns: [OpportunityEligibilityReason] = []
        var warnings: [OpportunityEligibilityReason] = []
        var evaluated: [String] = []

        // Age
        let ageEval = evaluateAge(opportunity: opportunity, profile: profile)
        evaluated.append("age")
        switch ageEval.status {
        case .ineligible: blocking.append(ageEval.reason)
        case .unknown: unknowns.append(ageEval.reason)
        case .eligible: break // satisfied, no reason needed? Add to allReasons but not blocking/unknown
        case .notEvaluated: break
        }

        // Grade
        let gradeEval = evaluateGrade(opportunity: opportunity, profile: profile)
        evaluated.append("grade")
        switch gradeEval.status {
        case .ineligible: blocking.append(gradeEval.reason)
        case .unknown: unknowns.append(gradeEval.reason)
        case .eligible: break
        case .notEvaluated: break
        }

        // Location
        let locEval = evaluateLocation(opportunity: opportunity, profile: profile)
        evaluated.append("location")
        switch locEval.status {
        case .ineligible: blocking.append(locEval.reason)
        case .unknown: unknowns.append(locEval.reason)
        case .eligible: break
        case .notEvaluated: break
        }

        // Delivery (unknown is not blocking; treat unknown as eligible for this rule)
        let deliveryEval = evaluateDelivery(opportunity: opportunity, profile: profile)
        evaluated.append("delivery")
        switch deliveryEval.status {
        case .ineligible: blocking.append(deliveryEval.reason)
        case .unknown:
            // Unknown delivery is not incompatible per spec → treat as not blocking, but record as warning not unknown?
            // We will not add to unknowns to avoid making entire result unknown due to delivery.
            warnings.append(deliveryEval.reason)
        case .eligible: break
        case .notEvaluated: break
        }

        // Cost
        let costEval = evaluateCost(opportunity: opportunity, profile: profile)
        evaluated.append("cost")
        switch costEval.status {
        case .ineligible: blocking.append(costEval.reason) // though spec says not auto ineligible, we still respect if somehow ineligible
        case .unknown: unknowns.append(costEval.reason)
        case .eligible: break
        case .notEvaluated: break
        }

        // Deadline
        let deadlineEval = evaluateDeadline(opportunity: opportunity, now: now)
        evaluated.append("deadline")
        switch deadlineEval.status {
        case .ineligible: blocking.append(deadlineEval.reason)
        case .unknown: unknowns.append(deadlineEval.reason)
        case .eligible: break
        case .notEvaluated: break
        }

        // Explicit requirements (structured)
        let explicitEvals = evaluateExplicitRequirements(opportunity: opportunity, profile: profile, now: now)
        for eval in explicitEvals {
            evaluated.append("requirement:\(eval.reason.dimension)")
            switch eval.status {
            case .ineligible: blocking.append(eval.reason)
            case .unknown: unknowns.append(eval.reason)
            case .eligible: break
            case .notEvaluated: break
            }
        }

        // Aggregation: INELIGIBLE > UNKNOWN > ELIGIBLE
        let status: OpportunityEligibilityStatus
        if !blocking.isEmpty {
            status = .ineligible
        } else if !unknowns.isEmpty {
            status = .unknown
        } else {
            status = .eligible
        }

        // All reasons (including satisfied for completeness, but we only store blocking/unknown/warnings as distinct)
        var allReasons: [OpportunityEligibilityReason] = []
        allReasons.append(contentsOf: blocking)
        allReasons.append(contentsOf: unknowns)
        allReasons.append(contentsOf: warnings)
        // Add satisfied reasons for completeness where rule was eligible and we have a reason
        for eval in [ageEval, gradeEval, locEval, deliveryEval, costEval, deadlineEval] where eval.status == .eligible {
            allReasons.append(eval.reason)
        }
        for eval in explicitEvals where eval.status == .eligible {
            allReasons.append(eval.reason)
        }

        // DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
        // Keep real opportunity data but force eligible with high randomized score (80-99%) for demo.
        // Ensures consistent display across all UI where eligibility is shown.
        if DemoScores.enabled {
            let demoScore = DemoScores.score(for: opportunity.id)
            let demoReason = OpportunityEligibilityReason(
                code: .eligible,
                dimension: "eligibility",
                message: "Eligibility score: \(demoScore)% — You appear highly eligible",
                blocking: false
            )
            return OpportunityEligibilityResult(
                opportunityID: opportunity.id,
                status: .eligible,
                evaluatedRules: evaluated,
                blockingReasons: [],
                unknownReasons: [],
                warnings: [],
                allReasons: [demoReason]
            )
        }

        return OpportunityEligibilityResult(
            opportunityID: opportunity.id,
            status: status,
            evaluatedRules: evaluated,
            blockingReasons: blocking,
            unknownReasons: unknowns,
            warnings: warnings,
            allReasons: allReasons
        )
    }

    // MARK: - Batch evaluation (for performance)

    static func evaluateAll(opportunities: [Opportunity], profile: StudentProfile, now: Date = Date()) -> [String: OpportunityEligibilityResult] {
        var dict: [String: OpportunityEligibilityResult] = [:]
        dict.reserveCapacity(opportunities.count)
        for opp in opportunities {
            dict[opp.id] = evaluate(opportunity: opp, profile: profile, now: now)
        }
        return dict
    }

    // MARK: - Helpers — return (status, reason)

    private struct RuleEval {
        let status: OpportunityEligibilityStatus
        let reason: OpportunityEligibilityReason
    }

    // Age — student age vs min/max
    private static func evaluateAge(opportunity: Opportunity, profile: StudentProfile) -> RuleEval {
        guard let range = opportunity.ageRange, !range.isUnknown else {
            return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .ageUnknown, dimension: "age", message: "Age requirement is not specified.", blocking: false))
        }
        // Parse student age
        let trimmed = profile.age.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let studentAge = Int(trimmed) else {
            // Also try to extract int from string like "15 years"
            if let parsed = parseAgeString(profile.age) {
                return evaluateAgeRange(studentAge: parsed, range: range, opportunity: opportunity)
            }
            return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .ageUnknown, dimension: "age", message: "Your age is not provided, so age eligibility could not be verified.", blocking: false))
        }
        return evaluateAgeRange(studentAge: studentAge, range: range, opportunity: opportunity)
    }

    private static func parseAgeString(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let scanner = Scanner(string: trimmed)
        var val: Int = 0
        if scanner.scanInt(&val) { return val }
        if let m = trimmed.range(of: "\\d+", options: .regularExpression), let v = Int(trimmed[m]) { return v }
        return nil
    }

    private static func evaluateAgeRange(studentAge: Int, range: OpportunityAgeRange, opportunity: Opportunity) -> RuleEval {
        if let min = range.minAge, studentAge < min {
            return RuleEval(status: .ineligible, reason: OpportunityEligibilityReason(code: .ageTooYoung, dimension: "age", message: "Age requirement: \(min)–\(range.maxAge.map{String($0)} ?? "∞"). You are \(studentAge).", blocking: true))
        }
        if let max = range.maxAge, studentAge > max {
            return RuleEval(status: .ineligible, reason: OpportunityEligibilityReason(code: .ageTooOld, dimension: "age", message: "Age requirement: \(range.minAge.map{String($0)} ?? "–")–\(max). You are \(studentAge).", blocking: true))
        }
        // Within range
        var msg: String
        if let min = range.minAge, let max = range.maxAge {
            msg = "Age requirement: \(min)–\(max). You are \(studentAge)."
        } else if let min = range.minAge {
            msg = "Age requirement: \(min)+. You are \(studentAge)."
        } else if let max = range.maxAge {
            msg = "Age requirement: up to \(max). You are \(studentAge)."
        } else {
            msg = "Age requirement satisfied. You are \(studentAge)."
        }
        return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .ageSatisfied, dimension: "age", message: msg, blocking: false))
    }

    // Grade
    private static func evaluateGrade(opportunity: Opportunity, profile: StudentProfile) -> RuleEval {
        guard let range = opportunity.gradeRange, !range.isUnknown else {
            return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .gradeUnknown, dimension: "grade", message: "Grade requirement is not specified.", blocking: false))
        }
        // If eligibleGrades is non-empty, use it
        if !range.eligibleGrades.isEmpty {
            if range.eligibleGrades.contains(profile.grade) {
                return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .gradeSatisfied, dimension: "grade", message: "Grade requirement: \(gradeSetDescription(range.eligibleGrades)). Your grade is \(profile.grade.rawValue).", blocking: false))
            } else {
                // Determine if too low or too high based on ordering
                let studentOrder = gradeOrder(profile.grade)
                let minOrder = range.eligibleGrades.map { gradeOrder($0) }.min() ?? 0
                let maxOrder = range.eligibleGrades.map { gradeOrder($0) }.max() ?? 0
                let code: OpportunityEligibilityReasonCode = studentOrder < minOrder ? .gradeTooLow : .gradeTooHigh
                return RuleEval(status: .ineligible, reason: OpportunityEligibilityReason(code: code, dimension: "grade", message: "Grade requirement: \(gradeSetDescription(range.eligibleGrades)). Your grade is \(profile.grade.rawValue).", blocking: true))
            }
        }
        // If eligibleGrades empty but gradeMin/Max present, it was unparseable → unknown
        if (range.gradeMin != nil && !(range.gradeMin!.isEmpty)) || (range.gradeMax != nil && !(range.gradeMax!.isEmpty)) {
            return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .gradeUnknown, dimension: "grade", message: "Grade requirement could not be verified.", blocking: false))
        }
        return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .gradeUnknown, dimension: "grade", message: "Grade requirement is not specified.", blocking: false))
    }

    private static func gradeOrder(_ grade: Grade) -> Int {
        switch grade {
        case .seventh: return 7
        case .eighth: return 8
        case .ninth: return 9
        case .tenth: return 10
        case .eleventh: return 11
        case .twelfth: return 12
        }
    }
    private static func gradeSetDescription(_ set: Set<Grade>) -> String {
        let sorted = set.sorted { gradeOrder($0) < gradeOrder($1) }
        if sorted.count == 1 { return sorted[0].rawValue }
        if sorted.count == 2 { return "\(sorted[0].rawValue)–\(sorted[1].rawValue)" }
        // Check if contiguous
        let orders = sorted.map { gradeOrder($0) }
        let minO = orders.first!
        let maxO = orders.last!
        if maxO - minO + 1 == orders.count {
            return "\(sorted.first!.rawValue)–\(sorted.last!.rawValue)"
        }
        return sorted.map(\.rawValue).joined(separator: ", ")
    }

    // Location
    private static func evaluateLocation(opportunity: Opportunity, profile: StudentProfile) -> RuleEval {
        let loc = opportunity.location
        let studentLoc = profile.location.trimmingCharacters(in: .whitespacesAndNewlines)
        // Unknown location requirement → unknown, not ineligible
        if loc.type.lowercased() == "unknown" && loc.city == nil && loc.state == nil && loc.country == nil && loc.online == nil {
            return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .locationUnknown, dimension: "location", message: "Location requirement is not specified.", blocking: false))
        }
        // Remote / online / hybrid is always compatible
        if loc.online == true || loc.type.lowercased() == "online" {
            return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .locationSatisfied, dimension: "location", message: "Location: Remote/Online — compatible with your location.", blocking: false))
        }
        if loc.type.lowercased() == "hybrid" {
            return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .locationSatisfied, dimension: "location", message: "Location: Hybrid — compatible.", blocking: false))
        }
        // In-person with specific city/state/country
        if loc.type.lowercased() == "inperson" || loc.type.lowercased() == "inPerson" {
            // If no specific city/state/country, generic inPerson without detail → cannot verify → unknown
            if loc.city == nil && loc.state == nil && loc.country == nil {
                // Generic in-person, no location detail → check if student location empty → unknown else assume mismatch? But spec says do not infer from incomplete
                if studentLoc.isEmpty {
                    return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .locationUnknown, dimension: "location", message: "Location requirement could not be verified.", blocking: false))
                }
                // Generic inPerson without specific place: treat as eligible (student could travel) but flag? We'll mark as unknown to be safe
                return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .locationUnknown, dimension: "location", message: "In-person location requirement could not be fully verified.", blocking: false))
            }
            // Has specific location: check student location
            if studentLoc.isEmpty {
                return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .locationUnknown, dimension: "location", message: "Location requirement: \(loc.displayString). Your location is not provided.", blocking: false))
            }
            let lowerStudent = studentLoc.lowercased()
            var matches = false
            if let city = loc.city?.lowercased(), !city.isEmpty, lowerStudent.contains(city) { matches = true }
            if let state = loc.state?.lowercased(), !state.isEmpty, lowerStudent.contains(state) { matches = true }
            if let country = loc.country?.lowercased(), !country.isEmpty, lowerStudent.contains(country) { matches = true }
            // Also check for state abbreviations? For now, simple contains
            if matches {
                return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .locationSatisfied, dimension: "location", message: "Location requirement: \(loc.displayString). Your location is \(studentLoc).", blocking: false))
            } else {
                return RuleEval(status: .ineligible, reason: OpportunityEligibilityReason(code: .locationMismatch, dimension: "location", message: "Location requirement: \(loc.displayString). Your location is \(studentLoc).", blocking: true))
            }
        }
        // Unknown delivery but location unknown already handled
        return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .locationUnknown, dimension: "location", message: "Location requirement could not be verified.", blocking: false))
    }

    // Delivery
    private static func evaluateDelivery(opportunity: Opportunity, profile: StudentProfile) -> RuleEval {
        switch opportunity.deliveryMode {
        case .online, .hybrid:
            return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .deliverySatisfied, dimension: "delivery", message: "Delivery mode: \(opportunity.deliveryMode.rawValue) — compatible.", blocking: false))
        case .inPerson:
            // Defer to location evaluation for in-person
            return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .deliverySatisfied, dimension: "delivery", message: "Delivery mode: In-person.", blocking: false))
        case .unknown:
            return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .deliverySatisfied, dimension: "delivery", message: "Delivery mode is not specified.", blocking: false))
        }
    }

    // Cost
    private static func evaluateCost(opportunity: Opportunity, profile: StudentProfile) -> RuleEval {
        guard let cost = opportunity.costInfo else {
            return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .costUnknown, dimension: "cost", message: "Cost information is not provided.", blocking: false))
        }
        if cost.isUnknown {
            return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .costUnknown, dimension: "cost", message: "Cost information is not provided.", blocking: false))
        }
        // Known cost (free or paid) — no explicit constraint in StudentProfile → eligible
        // We do not auto-mark paid as ineligible
        if cost.isFree == true {
            return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .costSatisfied, dimension: "cost", message: "Cost: Free.", blocking: false))
        }
        if let amt = cost.amount, let cur = cost.currency {
            return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .costSatisfied, dimension: "cost", message: "Cost: \(cur) \(amt).", blocking: false))
        }
        return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .costSatisfied, dimension: "cost", message: "Cost information is available.", blocking: false))
    }

    // Deadline — use centralized freshness logic without duplicating parsing
    private static func evaluateDeadline(opportunity: Opportunity, now: Date) -> RuleEval {
        guard let dl = opportunity.deadlineInfo else {
            return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .deadlineUnknown, dimension: "deadline", message: "Deadline is not specified.", blocking: false))
        }
        switch dl.type {
        case .rolling:
            return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .deadlineRolling, dimension: "deadline", message: "Deadline: Rolling — you can apply anytime.", blocking: false))
        case .noDeadline:
            return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .deadlineSatisfied, dimension: "deadline", message: "No deadline — open.", blocking: false))
        case .fixed:
            if let date = dl.date {
                if now > date {
                    let fmt = DateFormatter()
                    fmt.dateStyle = .medium
                    return RuleEval(status: .ineligible, reason: OpportunityEligibilityReason(code: .deadlinePassed, dimension: "deadline", message: "Deadline has passed (\(fmt.string(from: date))).", blocking: true))
                } else {
                    let days = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
                    return RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .deadlineSatisfied, dimension: "deadline", message: "Deadline: \(dl.displayString) (\(days) days left).", blocking: false))
                }
            } else {
                // Fixed type but no date → treat as unknown? But displayString exists
                return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .deadlineUnknown, dimension: "deadline", message: "Deadline: \(dl.displayString) — could not be verified.", blocking: false))
            }
        case .unknown:
            return RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .deadlineUnknown, dimension: "deadline", message: "Deadline: \(dl.displayString) — unknown.", blocking: false))
        }
    }

    // Explicit requirements — deterministic only when student data available
    private static func evaluateExplicitRequirements(opportunity: Opportunity, profile: StudentProfile, now: Date) -> [RuleEval] {
        var results: [RuleEval] = []
        // Combine eligibilityInfo details/requirements + applicationRequirements titles
        var allReqs: [String] = []
        if let details = opportunity.eligibilityInfo?.details, !details.isEmpty {
            allReqs.append(details)
        }
        if let reqs = opportunity.eligibilityInfo?.requirements { allReqs.append(contentsOf: reqs) }
        // applicationRequirements are not necessarily eligibility blocking, but we include as warnings/unknown
        // For factual eligibility, we only block on hard requirements that we can verify.
        // We will evaluate each requirement string for known dimensions.

        let studentLoc = profile.location.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasLocation = !studentLoc.isEmpty

        for req in allReqs {
            let lower = req.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lower.isEmpty { continue }

            // Check for residency / citizenship / location keywords
            let residencyKeywords = ["residen", "citizen", "work authorization", "visa"]
            let isResidency = residencyKeywords.contains { lower.contains($0) } || lower.contains("texas") || lower.contains("california") || lower.contains("new york")

            if isResidency {
                if !hasLocation {
                    results.append(RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .requirementUnknown, dimension: "residency", message: "Residency requirement could not be verified: \"\(req)\"", blocking: false)))
                } else {
                    // If requirement mentions a specific state, check student location contains it
                    // Extract state name if present
                    let states = ["texas","california","new york","florida","illinois","pennsylvania","ohio","georgia","massachusetts","washington","colorado","arizona","michigan"]
                    var foundState: String? = nil
                    for state in states where lower.contains(state) { foundState = state; break }
                    if let state = foundState {
                        if studentLoc.contains(state) {
                            results.append(RuleEval(status: .eligible, reason: OpportunityEligibilityReason(code: .requirementSatisfied, dimension: "residency", message: "Residency requirement: \(req) — satisfied.", blocking: false)))
                        } else {
                            results.append(RuleEval(status: .ineligible, reason: OpportunityEligibilityReason(code: .requirementMismatch, dimension: "residency", message: "Residency requirement: \(req). Your location is \(profile.location).", blocking: true)))
                        }
                    } else {
                        // Generic residency without specific state → unknown (cannot verify)
                        results.append(RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .requirementUnknown, dimension: "residency", message: "Residency requirement could not be verified: \"\(req)\"", blocking: false)))
                    }
                }
                continue
            }

            // Check for GPA / academic requirements where we have no GPA data → unknown
            if lower.contains("gpa") || lower.contains("grade point") || lower.contains("transcript") || lower.contains("essay") || lower.contains("recommendation") || lower.contains("reference") {
                // These are application materials, not hard eligibility blocks, so unknown
                results.append(RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .requirementUnknown, dimension: "application", message: "Requirement could not be verified: \"\(req)\"", blocking: false)))
                continue
            }

            // Check for age/grade in requirement text that we might have missed in structured fields
            // If requirement mentions age/grade, we already evaluated structured fields, so mark as unknown to avoid double counting unless we can verify
            if lower.contains("grade") || lower.contains("age") {
                // Already covered by structured age/grade rules, so don't add extra blocking
                continue
            }

            // Default: freeform requirement with no deterministic student data → unknown
            // But we treat it as unknown, not ineligible
            // Only add if requirement looks like a hard constraint (heuristic: contains "must", "required", "only")
            if lower.contains("must") || lower.contains("required") || lower.contains("only") {
                results.append(RuleEval(status: .unknown, reason: OpportunityEligibilityReason(code: .requirementUnknown, dimension: "requirement", message: "Requirement could not be verified: \"\(req)\"", blocking: false)))
            }
        }
        return results
    }
}
