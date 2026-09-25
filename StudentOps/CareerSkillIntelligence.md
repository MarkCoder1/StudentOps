# Career + Skill Intelligence — Phase 11A Foundation

**Status:** Phase 11A complete. Deterministic career/skill graph + intelligence engines are authoritative. Phase 11B/12 will add adaptive roadmaps (not started).

## 1. Pipeline

```
Student Graph (StudentProfile, Skills, Projects, Roadmaps, Evidence, Portfolios, Opportunities)
    ↓
Career Catalog (deterministic, demo) + Skill Graph (Career ↔ Skill relationships)
    ↓
CareerIntelligenceEngine  →  CareerAlignmentResult (0–100, 7 signals)
    ↓
SkillIntelligenceEngine   →  SkillCoverage / SkillGapInsight / NextSkillRecommendation (reuses SkillGapEngine)
    ↓
CareerRankingEngine       →  RankedCareer (deterministic)
    ↓
Roadmaps / Explore / Progress (consume, do not mutate)
```

Views never score directly. All factual results are deterministic; AI is explanatory-only (Phase 9.8 remains the only AI layer).

## 2. Canonical Career Model

`Career` (`Career.swift`) is the single source of truth for careers. `StudentProfile.careers` remains the student's stated interests; no second `StudentProfile`/`Skill`/`Project`/`Roadmap`/`Opportunity` was created.

**Fields (minimum supported):**
- `id` (deterministic via `Career.normalizeID(title:)`), `title`, `normalizedID`, `description`, `fields`, `industries`, `skills` (canonical Skill IDs), `relatedSkills`, `interests`, `educationRequirements` (optional, only when explicitly known), `commonActivities`, `source` (`CareerSourceMetadata`), `sourceURL`, `lastVerified`, `status` (`catalog` = DEMO/CATALOG DATA vs `verified` = LIVE/VERIFIED).

No salary, growth, or admissions statistics are added — no verified source exists. This phase is about the student's graph, not labor-market data.

**Supporting types:** `CareerSourceMetadata`, `CareerStatus`, `CareerSkillRelationship(careerID, skillID, relationshipType, importance)`, `SkillPrerequisite(skillID, prerequisiteSkillID)`.

**Strongly typed:** `CareerSkillRelationshipType` (`foundational` 4, `core` 3, `supporting` 2, `advanced` 1) with `importance` documented, not arbitrary percentages.

## 3. Career Normalization (Deterministic, No Fuzzy)

`Career.normalizeID(title:)`:
- trims, lowercases
- replaces `-_/\\` with spaces, collapses whitespace
- maps **explicit aliases only** via `aliasMap` (e.g., `"software engineer"` / `"software-engineer"` / `"swe"` → `"software-engineering"`). Only careers in the map are treated as same.
- otherwise hyphenates (`"Data Science"` → `"data-science"`).
- Deterministic; same input → same ID; unsafe fuzzy matching never used. Documented in `Career.normalizeID` and `aliasMap`.

Other arrays (`fields`, `industries`, `interests`, `commonActivities`) use `normalizeStringArray` (trim, collapse, case-insensitive dedup). Skills use `Skill.normalizeID()` (reused, no second algorithm).

## 4. Career Catalog (Demo, Deterministic)

`CareerCatalog.all` — 12 deterministic demo careers, each marked `status: .catalog` and description suffix `(Catalog demo data)` to distinguish from `verified`:

- Software Engineering, Data Science, AI/ML Engineering, Cybersecurity, Mechanical Engineering, Electrical Engineering, Biomedical Engineering, Product Design, Business/Entrepreneurship, Research Science, Cybersecurity Analyst, Design Engineering

All skills are canonical (via `Skill.normalizeID`). No live labor-market claims.

`CareerCatalog.byID`, `career(for:)`, `sortedTitles` are deterministic (`id`/`title` asc).

## 5. Career ↔ Skill Graph

`CareerSkillGraph.allRelationships` is built deterministically from the catalog:

- For each career, `skills` indices `0..<2` → `foundational`, `2..<5` → `core`, `5..<7` → `supporting`, rest → `advanced`; `relatedSkills` → `supporting`. `importance` derived from type (4/3/2/1). Dedup via `careerID|skillID` Set, sorted `careerID asc, importance desc, skillID asc`.
- Reuses `Skill.normalizeID` for `skillID`.
- `skills(for:)`, `requiredSkills(for:)` (foundational+core), `careerIDs(for:)` are deterministic.
- Duplicate protection via `Set`.

`prerequisites` is a small deterministic list where explicitly defined (e.g., `Data Structures` → `Programming Fundamentals`, `Machine Learning` → `Python`, `Algorithms` → `Data Structures`). Engine never recommends advanced while ignoring explicit prerequisite; no AI-invented prerequisites.

## 6. Career Intelligence Engine — `CareerIntelligenceEngine`

**Authoritative** for career insights. Reuses `SkillGapEngine`, `RoadmapService`, `Skill.normalizeID`.

**Signals (7, weighted, unavailable handling as in Opportunity Intelligence):**

| Signal | Weight | Student vs Career | Unavailable when |
|---|---|---|---|
| Goal alignment | 25% | `profile.careers+fields+milestones` (normalized) vs `career.fields+industries` | either side empty |
| Field alignment | 15% | `profile.fields` vs `career.fields` | either empty |
| Interest alignment | 15% | `profile.interests+customInterests` vs `career.interests` | either empty |
| Skill coverage | 20% | `profile.strengths+customSkills+demonstrated` vs `career.skills+relatedSkills` | either empty |
| Project continuity | 10% | `store.customProjects` skills vs `career` skills | no projects or no career skills |
| Roadmap alignment | 10% | `activeRoadmaps` required skills vs `career` skills + direct field match | no active roadmaps |
| Opportunity continuity | 5% | `store.opportunities` skills vs `career` skills | no opportunities or no career skills |

If unavailable, denominator excludes its weight (no artificial zero). Score `0–100` = `round( Σ(score_i * weight_i) / Σ(available weights) * 100)`. If all unavailable → `0` and `isInsufficientContext = true` with reason `Add career goals, interests, and skills to improve matching`. Not a probability/salary/admissions score — documented as **Student Graph alignment**.

**Result `CareerAlignmentResult`:** `careerID`, `careerTitle`, `score`, `signals`, `matchedGoals/Fields/Interests/Skills`, `relatedProjects`, `roadmapConnections`, `skillCoverage` (matched/total), `missingSkills`, `reasons` (only from available `score>0.05`), `warnings` (`No data for X`), `isInsufficientContext`.

**Deterministic reasons:** e.g., `Matches your Computer Science goal`, `Shares 4 skills with Software Engineering`, `Your active roadmap targets Software Engineering`, `Your project demonstrates 3 relevant skills`, `SQL is a current gap...` Only when underlying intersection exists.

## 7. Skill Intelligence Engine — `SkillIntelligenceEngine`

**Authoritative** for skill-level insights. **Reuses `SkillGapEngine`** (`demonstratedSkillIDs`, `evaluate`, `requiredSkills`) rather than recreating. Also reuses `CareerSkillGraph`, `RoadmapService`, `OpportunityEligibilityEngine`/`MatchingEngine` where appropriate (calls authoritative engines, no second opportunity matcher).

**Calculations:**
- **Current skill coverage:** `demonstrated + profile skills` vs `career` or `all careers` via `coverage()`.
- **Missing skills:** `targetSkills - allStudentSkills`.
- **Developing skills:** via `SkillGapEngine` per active roadmap (status `developing` vs `gap`).
- **Skill relevance to career:** `CareerSkillRelationship` importance.
- **Skill relevance to roadmap/project/opportunity:** via `RoadmapService` `skillsDeveloped`, `project.skills`, `opportunity.skills` intersections.

**`SkillGapInsight`:** `skillID`, `skillName`, `relatedCareerIDs`, `gapReason` (e.g., `SQL is a core skill for AI/ML Engineering and is not present...` only when data supports), `importance`, `relationshipType`, `roadmapConnection` (`roadmapID:milestoneID`), `relevantProjects`, `relevantOpportunities`, `nextAction`.

**Skill importance:** Deterministic from `CareerSkillRelationshipType` (`foundational` strongest, then `core`, `supporting`, `advanced`), not real-world percentages.

**Next skills:** `nextSkills(limit:)` scores gaps by `importance*10` + `foundational/core bonus` + `active gap` + `roadmap` + `opportunity` + `project` – `20` if prerequisite missing (ensures prereq ordered first). Deterministic sort `score desc, importance desc, name asc`. Prerequisite ordering enforced: never recommends advanced while missing explicit prerequisite.

**No AI** determines gaps/proficiency; `SkillGapEngine` is source of truth.

## 8. Career Ranking — `CareerRankingEngine`

Only if UI needs multiple careers ranked. Deterministic:

1. `alignment.score` desc
2. `skillCoverage` desc
3. `roadmapAlignment` score desc
4. `projectContinuity` score desc
5. `title` asc (case-insensitive)
6. `id` asc

Never randomness/UUID/dictionary order/AI. Neutral terminology `Career matches`/`Career alignment`, not `best careers`.

## 9. Empty Profile Behavior

Completely new student (no careers, fields, interests, skills, projects, roadmaps):
- All signals unavailable → `score 0`, `isInsufficientContext = true`, `reasons` contains `Add career goals...`, `warnings` list unavailable dimensions.
- No fabricated personalization (no `Matches your...` when no overlap).
- `nextSkills` falls back to foundational missing career skills with generic reasons, not invented.

## 10. Explore / Roadmap / Progress Integration

- **Explore:** Keeps `Opportunities` as authoritative `OpportunityIntelligence`. Adds career/skill intelligence only where natural (e.g., `CAREER DIRECTION` → selected/current career + alignment + `skills to develop`), without crowding. Does not redesign Explore.
- **Roadmaps:** Consume `CareerIntelligenceEngine` + `SkillIntelligenceEngine` (`career → required skills → gaps → roadmap → projects/opportunities`) read-only; no progress mutation, no auto-creating milestones (Phase 12).
- **Progress:** Consumes `skillCoverage`, `missingSkills`, `skillsDeveloped` via `ProjectExecutionService`/`SkillGapEngine`/`PortfolioEngine`; no second progress system.

## 11. Persistence & No-Mutation

Career/skill insights are **derived** (`Career Catalog + Student Graph` → deterministic result). Scores are **not persisted** as canonical facts (opportunities, skills, roadmaps, projects changes automatically update results). Catalog needs no persistence beyond code (demo); if needed, follow `AppDataStore` conventions (no database). `AppDataStore` exposes derived accessors: `careerAlignments`, `careerAlignment(for:)`, `rankedCareers`, `topRankedCareers(limit:)`, `skillCoverage(careerID:)`, `skillGaps(careerID:)`, `nextSkills(careerID:limit:)` — all read-only, never mutate `StudentProfile`/`Project`/`Roadmap`/`Evidence`/`Achievement`/`Portfolio`/`Opportunity`.

## 12. No-AI Rules

No new AI. `Phase 9.8` remains only AI layer. AI may later explain deterministic results (`why a career matches`, `why a skill matters`) but never determines eligibility/matching/gaps/ranking/prerequisites.

## 13. Testing & Performance

`test-career-skill-intelligence.swift` covers:
- Career model (codable, normalization, aliases, deterministic IDs, malformed, backward compat)
- Career graph (career→skills, required/core/supporting/advanced, normalized IDs, duplicate protection, deterministic catalog)
- Career intelligence (goal/field/interest/skill/project/roadmap/opportunity, unavailable, normalized, deterministic reasons, no fabricated, repeated execution)
- Skill intelligence (current/missing, career gaps, importance, roadmap/project/opportunity connections, next skill, prerequisite ordering, deterministic)
- Ranking (score, skill-gap, roadmap, project, title, ID tie-breaks, deterministic repeated)
- Empty state (no careers/skills/projects/roadmaps)
- Regression (ProjectRecommendationEngine, ProjectExecutionService, SkillGapEngine, Opportunity*Engines, Portfolio, AI)
- Monotonicity (adding required skill/goal/roadmap/project/opportunity never decreases relevant alignment)
- Performance (100 careers, 500 skills, 1,000 opportunities with realistic data — uses `Set`/`Dictionary`, no O(n²))

## 14. Architecture Rules

Exactly one authoritative implementation for: `Career.normalizeID`, career alignment, skill-gap logic, career ranking, skill prioritization. No scoring in `ExploreView`/`RoadmapDetailView`/`ProgressView`/cards/sheets — views consume engine results.

## 15. Not Implemented (Phase 11B/12)

Adaptive roadmap generation/rewriting, notifications, job-market scraping, live salary/growth, employment/college probability, personality diagnosis, AI career selection, cloud/auth, application tracking, social, new DB/tab — intentionally deferred.
