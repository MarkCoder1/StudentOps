# Opportunity Intelligence — Phase 10A + 10B (Canonical → Eligibility → Matching → Ranking → Explore)

**Status:** Phase 10A and 10B complete. Deterministic eligibility, matching, and ranking are authoritative. Phase 11 will handle freshness/notification.

## 1. Pipeline Overview

```
External Source
    ↓
RawOpportunityRecord          // messy, optional strings, inconsistent casing/dates
    ↓
OpportunityNormalizer         // deterministic transforms, preserves meaning, removes noise
    ↓
OpportunityValidator          // structured errors/warnings, blocks invalid inserts
    ↓
OpportunityDeduper            // deterministic duplicate detection with reason
    ↓
Opportunity (canonical)       // single source of truth, Codable, strongly typed
    ↓
OpportunityRepository / AppDataStore  // local repository, deterministic ordering, persistence
    ↓
Future: Eligibility / Matching / Ranking (Phase 10B)
```

Views never touch raw arrays. All factual decisions are deterministic; AI is explanatory only.

## 2. What Is Authoritative

| Concept | Authoritative Source |
|---|---|
| Student state | `AppDataStore` (UserDefaults + Codable, one key `studentops.opportunities`) |
| Canonical opportunity | `Opportunity` struct (StudentOps/Opportunity.swift) |
| Skills normalization | `Skill.normalizeID(_:)` — reused, not duplicated (StudentOps/Skill.swift:26) |
| Deterministic ordering | `title asc → organization asc → id asc` in repository and AppDataStore |
| Freshness policy | `OpportunityFreshnessService` (centralized, no scatter) |
| Duplicate decision | `OpportunityDeduper.isDuplicate` with `DuplicateMatchReason` |
| Validation truth | `OpportunityValidator.validate` → `OpportunityValidationResult` |

`AppDataStore` is the local source of truth for persisted opportunities, consistent with how it stores `portfolios`, `evidenceRecords`, `achievementRecords`, `projectExecutionStates`, `customProjects`. Missing `studentops.opportunities` key on older installs safely defaults to `[]` then seeds via `OpportunitySeedData`.

## 3. Canonical Model (Facts vs Unknown)

The model distinguishes **explicitly known**, **explicitly false**, and **unknown / not provided**. Missing data is never inferred as false.

- **Age:** `OpportunityAgeRange?` — `nil` = unknown, `minAge`/`maxAge` optional. `minAge = 14, maxAge = 18` vs `nil`.
- **Grade:** `OpportunityGradeRange?` — `nil` = unknown.
- **Cost:** `OpportunityCost?` — `nil` or `isUnknown` = unknown, `isFree = true` with `amount = 0` = free, `isFree = false` with amount = paid.
- **Location:** `OpportunityLocation.type = "unknown"` + `online = nil` = unknown; `online = true` = remote; `online = false` = in-person; `hybrid` = hybrid.
- **Deadline:** `OpportunityDeadline?` — `nil` = unknown, `type = .rolling` = rolling, `type = .noDeadline` = no deadline, `type = .fixed` with `date` = known.
- **Eligibility:** `OpportunityEligibility?` — `nil` or `isUnknown` = unknown, not ineligible.
- **Skills/interests/careerFields:** empty arrays = unknown, not negative signal.

This is critical because Phase 10B eligibility must not infer ineligibility from missing data.

Strongly typed enums/structs: `OpportunityType`, `OpportunityLocation`, `OpportunityDeliveryMode`, `OpportunityAgeRange`, `OpportunityGradeRange`, `OpportunityRequirement`, `OpportunityDeadline`, `OpportunityCost`, `OpportunitySource`, `OpportunityFreshness`, `OpportunityStatus`.

## 4. Source Architecture

`OpportunitySource` captures provenance without claiming live data:

- `sourceID` — stable identifier for the source (e.g., `seed-demo`, `external-api`)
- `sourceName` — human name
- `sourceType` — `.staticSeed`, `.api`, `.jsonFeed`, `.manual`, `.other`
- `sourceURL` — validated `http/https` or nil
- `retrievedAt` — when the source was fetched
- `publisher` — organization that published the opportunity

Sources are pluggable: static seed (now), API feeds, JSON feeds, manually curated — all map through `RawOpportunityRecord → OpportunityNormalizer → Opportunity`. No web scraping in Phase 10A.

## 5. Normalization (Deterministic)

`OpportunityNormalizer` is deterministic: same raw record always yields same canonical representation.

- **Titles/organizations:** trim, collapse repeated whitespace (`collapseWhitespace`), preserve meaningful content.
- **IDs:** stable normalized IDs: trustworthy `id` → lowercased hyphenated; else `sourceID + org + title + deadline`; else `org-title-hash` via `deterministicHash` (FNV-1a).
- **URLs:** trim, validate `http/https` with host, lowercase host, strip fragment via `URLComponents`; preserve original `sourceURL` where useful.
- **Skills:** `Skill.normalizeID` (trim, collapse whitespace, lowercased); dedup via normalized ID; do not create second algorithm.
- **Interests/career fields:** trim, collapse whitespace, case-insensitive dedup.
- **Categories:** alias map (e.g., `"competitions"` → `.competition`, `"contest"` → `.competition`, `"summer"` → `.summerProgram`).
- **Dates:** parse `yyyy-MM-dd` and ISO8601; do not silently reinterpret ambiguous dates; fallback to `.unknown` with display string.
- **Costs:** `"Free"` → `isFree true`; `"$100"` → amount; `"Unknown"` → nil.
- **Ages:** extract first integer via `Scanner` + regex; `nil` if unparseable.

## 6. Validation (Structured Errors vs Warnings)

`OpportunityValidator.validate(_:) -> OpportunityValidationResult { isValid, errors, warnings }`

- **Errors (block insertion):** empty id/title/organization, invalid URL (`http/https` + host), `minAge > maxAge`, age out of 0–120, negative cost, `isFree true` with non-zero amount, empty `sourceID`/`sourceName`, duplicate nested `applicationRequirements.id`.
- **Warnings (allow insertion, signal missing data):** missing description, no deadline, unknown cost, no eligibility data, no skills/interests/careerFields, unparseable grade range, deadline far in past vs `lastVerified`.

Unknown information is a warning, not an error.

## 7. Deduplication (Hierarchy of Evidence, No AI)

`OpportunityDeduper` uses a hierarchy, not fuzzy scores. If confidence is insufficient, records are kept separate (no unsafe merges). Provides `DuplicateMatchReason` for explainability.

1. **exactID** — `id` lowercased equality (confidence 1.0)
2. **sourceID** — same `source.sourceID` + same `sourceURL` (confidence 0.95)
3. **canonicalURL** — same `sourceURL` or `officialURL` lowercased (confidence 0.95)
4. **normalizedIdentity** — same `organization.lowercased() | title.lowercased() | deadline.displayString.lowercased()` (confidence 0.8)

Deterministic; no ML/fuzzy. `deduplicate(_:)` returns `(unique: [Opportunity], duplicates: [(Opportunity, DuplicateMatch)])` with stable ordering.

## 8. Freshness (Deterministic, Centralized)

`OpportunityFreshnessService.freshness(for:now:) -> OpportunityFreshnessInfo`

- If `deadlineInfo.date` exists and `daysUntilDeadline < 0` → `.expired`
- Else if `deadlineInfo.type == .rolling` → `.fresh`
- Else → `freshnessFromLastVerified(lastVerified:)`:
  - `nil` → `.unknown`
  - `≤30 days` → `.fresh`
  - `≤90 days` → `.aging`
  - `≤180 days` → `.stale`
  - `>180 days` → `.expired`

Stale/expired opportunities are retained (status remains `active` or `expired`), not auto-deleted. Freshness is not an AI judgment and is not scattered in SwiftUI.

## 9. Repository

`OpportunityRepository` (`@MainActor`) and `AppDataStore` opportunity methods:

- `all()` / `allOpportunities()` — deterministic ordering (title, organization, id)
- `get(id:)` / `opportunity(forID:)` — exact match
- `insert(_:)` — validates, checks deduper, appends + sorts
- `upsert(_:)` — removes existing duplicates, validates, inserts
- `remove(id:)` — exact id match
- `replaceAll(with:)` — validates, dedupes, sorts
- `ingest(rawRecords:)` — normalizes → validates → dedupes, returns `(inserted, duplicates, invalid)`

Views never manipulate raw arrays. Value types (`Opportunity` is struct) where appropriate. Performance: `Dictionary`/`Set` lookup for O(1) dedup, not O(n²).

## 10. Persistence

One namespaced key: `studentops.opportunities` (UserDefaults + Codable, same style as `projects`, `executionStates`, `evidence`, `achievements`, `roadmaps`, `portfolios`).

- Saves via `JSONEncoder` on `opportunities.didSet`
- Loads via `JSONDecoder`; missing key → `[]` → seeds via `OpportunitySeedData.seedCatalog` (deduped)
- Corrupted data → `[]` via `try?` (safe default)
- Existing data → filter `isValid`, deduplicate, sort deterministically
- Does not mutate unrelated Student Graph state (profile, roadmapProgress, evidence, etc.)

## 11. Seed Data

`OpportunitySeedData.seedCatalog` — 12 deterministic demo records, explicitly marked `Demo`/`Seed` (e.g., `"Student Innovation Challenge (Demo)"` with organization `"Demo Organization - ..."`). Not live, not claimed real.

Covers:
- Types: competition, hackathon, scholarship, research, internship, summerProgram, volunteering, leadership, conference, community, other
- Delivery: online, inPerson, hybrid, unknown
- Ages: 13–18, 14–19, 15–18, 16+, unknown
- Grades: 9–12, 11–12, 10–12, 9–11, unknown
- Eligibility: known and unknown
- Deadlines: fixed future, fixed past (expired), rolling, noDeadline, unknown/nil
- Costs: free ($0), paid ($500, $2000), unknown
- Skills/interests/careerFields: single and multiple, overlapping
- Sources: `seed-demo`, `external-api`, `external-json` (multiple)
- Duplicates: `seed-student-innovation-challenge-2026` and `duplicate-innovation-challenge` share URL/title/org/deadline → deduper finds ≥1 duplicate
- Freshness: fresh (now), aging (40 days), stale (100 days), expired (–30 days, –200 days), unknown

All seed records validate (`isValid` true), IDs unique, no invalid URLs, no impossible `minAge > maxAge`.

## 12. What This Phase Intentionally Does NOT Do

- No eligibility matching/ranking (Phase 10B)
- No AI for normalization, categorization, deduplication, freshness, validation, IDs, ranking
- No scraping or live data claims
- No new database (uses UserDefaults, same as existing; server `opportunities.db` is separate server SQLite, not a new local DB)
- No new tab, no Explore redesign (Explore still consumes `RemoteOpportunity`/`PersonalizedFeed`; canonical `Opportunity` is foundation for future Explore integration)
- No application tracking, notifications, portfolio mutations from opportunities
- No second `StudentProfile`/`Project`/`Skill`/`Roadmap`/`Portfolio` model
- No modification of `ProjectRecommendationEngine`, `ProjectExecutionService`, `Portfolio*` engines

## 13. Architecture Decision: AppDataStore + OpportunityRepository

`AppDataStore` owns persistence (single source of truth for UI), while `OpportunityRepository` is a standalone deterministic repository for testing and future server sync. `AppDataStore` duplicates the repository logic (validation + dedup + sorting) rather than wrapping `OpportunityRepository` directly, to keep `@MainActor`/`@Published` semantics and UserDefaults `didSet` cohesion consistent with existing `AppDataStore` patterns for projects and portfolios. This is intentional to preserve the existing architectural convention (repository-owned persistence would have required a larger refactor). Both use the same deterministic ordering and dedup hierarchy.

## 14. Testing

`test-opportunity-intelligence.swift` (374 tests) covers:
- Model codable roundtrip, backward-compatible defaults, enum stability, facts vs unknown
- Normalization: whitespace, ID, URL, skill (via `Skill.normalizeID`), duplicate skills, category aliases, deterministic output, location/delivery, age/cost/deadline parsing
- Validation: valid, missing fields, invalid URLs, age ranges, grade ranges, negative cost, warnings vs errors, duplicate nested IDs
- Deduplication: exactID, sourceID, canonicalURL, normalizedIdentity, non-duplicates, deterministic, no unsafe merges, reason provided
- Freshness: fresh, aging, stale, expired, missing timestamps, deadline-based expiration, deterministic
- Repository: insert/get, upsert, delete, duplicate protection, deterministic ordering (title→org→id), validation, normalization via ingest, empty, replaceAll
- Persistence: save/load roundtrip, missing key defaults empty, corrupted defaults empty, no mutation of unrelated state
- Seed: all validate, IDs unique, duplicates dedupe, no invalid URLs, no impossible dates, multiple types/locations/ages/costs/sources
- Performance: 300 unique items under 2s, stable ordering
- Regression: no second domain models, no DB, no AI

Existing tests: `swift test-opportunity-roadmap-engine.swift` (373 passed), `vitest run` (311 passed) remain green.

## 15. Phase 10B — Deterministic Eligibility / Matching / Ranking (Complete)

### 15.1 Pipeline (Authoritative)

```
Student Graph (StudentProfile, Skills, Roadmaps, Projects, Evidence, Portfolios)
    +
Canonical Opportunity Repository (AppDataStore.opportunities, deduped, sorted)
    ↓
OpportunityEligibilityEngine  →  OpportunityEligibilityResult  (eligible / ineligible / unknown)
    ↓
OpportunityMatchingEngine     →  OpportunityMatchResult  (0–100, 10 deterministic signals, available-weight normalized)
    ↓
OpportunityRankingEngine      →  RankedOpportunity  (eligible > unknown > ineligible, then score, gaps, roadmap, urgency, title, org, id)
    ↓
Explore / OpportunityDetailView  (facts separate from match interpretation, source URL via openURL)
```

Eligibility happens first. Matching never determines eligibility. Ranking consumes match results only.

### 15.2 Eligibility vs Matching (Mandatory Separation)

- **Eligibility:** categorical factual gate — `eligible` | `ineligible` | `unknown`. Unknown is first-class, never turned into `ineligible`. Example: Age 14–18, Texas residency required, student age 14, residency unknown → `unknown` with reason `Residency requirement could not be verified`, not `ineligible`. Aggregates via `INELIGIBLE > UNKNOWN > ELIGIBLE` (any blocking → ineligible, else any unknown → unknown, else eligible).
- **Matching:** 0–100 relevance score measuring alignment when eligibility is `eligible` or `unknown`. `ELIGIBILITY = UNKNOWN, MATCH = 92` means "highly relevant but eligibility cannot be verified" — not "you are eligible". `ELIGIBILITY = INELIGIBLE, MATCH = 99` never appears in eligible lists (filtered).
- **Source of truth:** Canonical `Opportunity` + current `StudentProfile`/graph; derived scores are not persisted as canonical facts (recomputed on profile/skill/roadmap/project/opportunity change).

### 15.3 Eligibility Engine — `OpportunityEligibilityEngine`

**Status: `OpportunityEligibilityStatus`:** `eligible` | `ineligible` | `unknown` (plus `notEvaluated` only if genuinely useful, not invented).

**Result: `OpportunityEligibilityResult`:** `opportunityID`, `status`, `evaluatedRules`, `blockingReasons`, `unknownReasons`, `warnings`, `allReasons`. Each reason is `OpportunityEligibilityReason(code, dimension, message, blocking)`.

**Rules (only when explicitly represented, else unknown):**
- **Age:** `minAge`/`maxAge` vs parsed `profile.age` (Int via `Scanner` + regex). Below min → `ageTooYoung` (ineligible), above max → `ageTooOld`, within → `ageSatisfied`, student age empty/unparseable or opportunity age unknown → `ageUnknown`.
- **Grade:** `eligibleGrades` set vs `profile.grade` (ordering `7th..12th`). In set → `gradeSatisfied`, not in set → `gradeTooLow`/`gradeTooHigh` (ineligible), `gradeRange` nil/unknown or unparseable → `gradeUnknown`.
- **Location:** `OpportunityLocation` + `profile.location` (trimmed, lowercased contains). `online`/`hybrid` → `locationSatisfied` (compatible), `unknown` → `locationUnknown`, `inPerson` with city/state/country: student location empty → `locationUnknown`, contains city/state → `locationSatisfied`, otherwise `locationMismatch` (ineligible). Unknown not treated as mismatch.
- **Delivery:** `online`/`hybrid`/`inPerson` → `deliverySatisfied` (eligible), `unknown` → `deliverySatisfied` (not incompatible per spec — unknown not blocking, recorded as warning).
- **Cost:** No `StudentProfile` constraint exists → known cost (`free` or `paid`) → `costSatisfied` (eligible), unknown → `costUnknown`. Paid never auto-ineligible.
- **Deadline:** Uses centralized `OpportunityFreshnessService` logic, not duplicated parsing. `nil` → `deadlineUnknown`, `rolling`/`noDeadline` → `deadlineSatisfied`/`deadlineRolling`, `fixed` with `date`: `now > date` → `deadlinePassed` (ineligible), else `deadlineSatisfied`, `fixed` without date or `unknown` type → `deadlineUnknown`.
- **Explicit Requirements:** `OpportunityEligibility.details` + `requirements` + heuristics. Residency/citizenship/visa/state keywords → check `profile.location` (empty → `requirementUnknown`, state present in student location → `requirementSatisfied`, otherwise `requirementMismatch` if explicit state and mismatch; generic residency without state → `requirementUnknown`). GPA/essay/transcript/recommendation → `requirementUnknown` (application materials, not hard eligibility). Other freeform `must`/`required` → `requirementUnknown`. Never infer citizenship/residency/work authorization from unrelated fields; unknown stays unknown.

**Aggregation:** Any `blockingReasons` → `ineligible`; else any `unknownReasons` → `unknown`; else `eligible`. Scoring is not used.

**Explanations:** Deterministic `message` per reason (e.g., `"Age requirement: 14–18. You are 14."`, `"Grade requirement: 9th–12th. Your grade is 8th."`, `"Deadline has passed."`, `"Residency requirement could not be verified."`), `code` separate from display. No AI.

### 15.4 Matching Engine — `OpportunityMatchingEngine`

**Signals (10, deterministic, available vs unavailable):**
1. **Goal alignment (20%)** — `profile.careers+fields+milestones` (normalized via `Skill.normalizeID`) vs `opportunity.careerFields`. Intersection / `oppCareerFields.count`. Unavailable if either side empty.
2. **Career alignment (15%)** — `profile.careers` vs `oppCareerFields`. Same denominator. Unavailable if either empty.
3. **Interest alignment (10%)** — `profile.interests+customInterests` vs `oppInterests`. Intersection / `oppInterests.count`.
4. **Skill alignment (15%)** — `profile.strengths+customSkills` vs `oppSkills`. Intersection / `oppSkills.count`. Uses `Skill.normalizeID`.
5. **Skill-gap coverage (15%)** — `SkillGapEngine` active gaps (`store.activeSkillGapReports`) vs `oppSkills`. `inter / gapIDs.count`. Reuses `SkillGapEngine` (no duplication). Unavailable if `gapIDs` nil/empty or `oppSkills` empty.
6. **Roadmap alignment (10%)** — `OpportunityRoadmapEngine.connections(for: opp, store:)`. Best connection: `direct=1.0`, `relevant=0.6`, `future=0.3`, no connection=0. Unavailable if no active roadmaps.
7. **Project continuity (5%)** — `store.customProjects` skills/fields vs `oppSkills`/`oppCareerFields`. Best project overlap / total relevant. Unavailable if no projects or no opp relevant data.
8. **Evidence/portfolio value (5%)** — `oppSkills` vs gaps/portfolios. If gaps overlap → `inter/oppSkills.count`, else `min(1, oppSkills.count/4)*0.5+0.3`. Unavailable if `oppSkills` empty.
9. **Feasibility (3%)** — explicit `deliveryMode`/`location`/`cost`. `online=1.0`, `hybrid=0.85`, `inPerson` with location match=0.9 else 0.3, `unknown` + no location/cost → unavailable. Paid not penalized.
10. **Deadline urgency (2%)** — canonical `deadlineInfo` via `OpportunityFreshnessService`. `≤7d=1.0`, `≤30d=0.7`, `>30d=0.4`, `rolling=0.6`, `noDeadline=0.5`, `nil`/`unknown`=unavailable, `expired=0` (but ineligible).

**Weighted score:** `Σ(score_i * weight_i) / Σ(available weights) * 100` → `0–100` rounded. Unavailable signals excluded from denominator (no artificial zeros). If all unavailable → `0`. Documented weights: Goal 20, Career 15, Interest 10, Skill 15, Skill-gap 15, Roadmap 10, Continuity 5, Evidence 5, Feasibility 3, Urgency 2 = 100.

**No mutation:** `profile`, `Project`, `Skill`, `Roadmap`, `Evidence`, `Achievement`, `Portfolio`, `ProjectExecutionState`, `Opportunity` never mutated during `match()`.

**No fabricated reasons:** `reasons` only from available signals with `score > 0` and `score ≥ 0.1`; unknown/missing data yields unavailable, not `0` with fake reason.

### 15.5 Ranking Engine — `OpportunityRankingEngine`

**Consumes:** `[OpportunityMatchResult]` + `opportunitiesByID` → `[RankedOpportunity]`.

**Deterministic tie-break hierarchy:**
1. `eligible` (0) before `unknown` (1) before `ineligible` (2)
2. `overallMatchScore` descending
3. `skillGapCoverage` descending
4. `roadmapAlignment` descending
5. `deadlineUrgency` descending
6. `title` ascending (case-insensitive)
7. `organization` ascending (case-insensitive)
8. `id` ascending

Never dictionary/UUID/network/random. `RankedOpportunity` wraps `opportunity` + `matchResult` + `eligibilityStatus` + `rankScore`.

**Filters (deterministic, derived from canonical types, not hardcoded duplicates):**
- `RankingFilterMode`: `all`, `eligible`, `needsVerification` (`unknown`), `ineligible` (includes expired)
- `OpportunityType` category filter (only values from `OpportunityType.allCases` present in repo)
- `searchText` (case-insensitive haystack of `title+organization+description+skills+interests+careerFields`)

**Deduplication:** Defensive `OpportunityDeduper.deduplicate` before ranking if needed; repository already deduped.

### 15.6 AppDataStore Integration (No New DB, No Mutation)

New read-only accessors (no new persistence, scores recomputed on change):
- `eligibility(for:now:)` → `OpportunityEligibilityResult`
- `eligibilityMap(now:)` → `[String: OpportunityEligibilityResult]`
- `matchResult(for:now:)` → `OpportunityMatchResult` (precomputes gapIDs once, uses `store.activatedRoadmaps` + `opportunityRoadmapConnections`)
- `allMatchResults(now:)` → `[OpportunityMatchResult]` via `OpportunityMatchingEngine.matchAll`
- `rankedOpportunities(filter:category:searchText:now:)` → `[RankedOpportunity]` via `OpportunityRankingEngine.rank`
- `eligibleRankedOpportunities`, `needsVerificationRanked` convenience

`OpportunityService.scoredOpportunities` (legacy 5-item `localCatalog` with simple `matchScore`) kept for `HomeDashboard` compatibility but not authoritative for Explore; canonical Explore uses `rankedOpportunities`.

### 15.7 Explore Integration (Preserve Architecture, No Redesign)

`ExploreView` now has dual mode:
- **Has local opportunities** (`!store.opportunities.isEmpty`): shows deterministic local header `"Recommended for you"` + subtitle, local stats (`eligible`/`avg`/`needsVerification`/`ineligible`), local filter chips (`RankingFilterMode` + `OpportunityType` menu), single ranked list via `OpportunityCard(ranked:isSaved:onSave:onView)` with eligibility pill (`Eligible`/`Needs Verification`/`Not Eligible`, colors `success`/`warning`/`red`), match score, deadline, location/delivery, 1–2 deterministic reasons, and saves via `store.isSaved(Opportunity)` / `toggleSaved`.
- **No local opportunities**: falls back to legacy remote `PersonalizedFeed` sections (unchanged style, same `header`/`statsBar`/`filterChips`).

Tapping a ranked card navigates to `OpportunityDetailView(ranked:)` (also supports `init(opportunity:)` that recomputes match on the fly).

**No new tab, no redesign** — same `NavigationStack`, `background`, `sheet` for filters, `refreshable`, and `OpportunityCard` styling (`16` padding, `surface` background, `shadow`).

### 15.8 Opportunity Detail — Facts vs Match

`OpportunityDetailView` now supports `rankedOpportunity` + `canonicalOpportunity` in addition to `scored`/`remote`/`personalized`:

- **Facts (authoritative):** `Age: 14–18`, `Grades: 9th–12th`, `Location: Austin, TX`, `Delivery: Online`, `Cost: Free`, `Deadline: Oct 14`, `Organization`, `Source` + `sourceURL` (via `openURL`, validated `http/https`, no fabricated URLs), `Freshness` via `OpportunityFreshnessService`.
- **Match (personalized interpretation):** `Eligibility` section (color/icon `checkmark.shield.fill`/`questionmark.shield`/`xmark.shield`, label `ELIGIBLE`/`NEEDS VERIFICATION`/`NOT ELIGIBLE`, blocking/unknown reasons), `Match` section (`92%` + `Strong Match` + reasons), `Timeline` (`Freshness`), `Matched Goals/Interests/Skills`, `Skill Gaps Covered`, `Roadmap Connections`, `Why This Matches` (signals), separate from `Source`.

AI Insight remains `DisclosureGroup` secondary, not used for factual decisions.

**Source link:** `opp.sourceURL ?? opp.officialURL` or `opp.source.sourceURL`, validated, opened via `openURL`, not generated.

**No application tracking / notifications / cloud / auth / subscriptions / chatbot / admissions scoring** — intentionally not implemented.

### 15.9 No-AI & No-Mutation Guarantees

- No AI for eligibility, matching, scoring, ranking, deadline, freshness, category. `AIPersonalizationService` untouched (Phase 9.8).
- `OpportunityEligibilityEngine`, `OpportunityMatchingEngine`, `OpportunityRankingEngine` are pure (`static func`, no `@Published` writes, no file/network).
- `AppDataStore` accessors are read-only; viewing/ranking never calls `markRoadmapMilestoneComplete`, `addEvidence`, etc.

### 15.10 Testing (Phase 10B)

- Existing Phase 10A `test-opportunity-intelligence.swift` (374) + ~5,500 Swift + 311 Vitest still pass.
- New `test-opportunity-eligibility-matching-ranking.swift` (comprehensive, deterministic, no mutation checks, monotonicity, performance 1,000 opportunities).
- Monotonicity: gaining a matching skill/goal/roadmap connection never decreases alignment; deadline passing never stays `eligible`; `ineligible` → not in eligible list.
- Performance: 1,000 opportunities eligibility+matching+ranking <2s via `Dictionary`/`Set`.

### 15.11 Compatibility

- Legacy `legacyDeadline`, `legacyLocation`, `legacyEligibility`, `deadline`/`deadlineLabel`, `officialURL`, `relevant*`, `eligibleGrades`, `relevantLocations` kept. New code reads canonical fields (`deadlineInfo`, `ageRange`, `location`, etc.) and falls back to legacy where needed. Migration is safe; existing screens not broken.

### 15.12 Authoritative Implementations (Exactly One Each)

- **Eligibility:** `OpportunityEligibilityEngine` (no Explore/Detail/NextAction duplicate).
- **Matching:** `OpportunityMatchingEngine` (no card-specific scoring).
- **Ranking:** `OpportunityRankingEngine` (no view-specific ordering).
- Views consume engine results; duplicate logic (e.g., legacy `OpportunityService.matchScore` for 5-item catalog) remains for backward compat but is not used for canonical ranking (documented as non-authoritative for Explore).
