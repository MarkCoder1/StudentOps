# Adaptive Roadmap Adaptation (Phase 12B)

## 1. Purpose

Phase 12B adds **controlled, deterministic roadmap adaptation** on top of Phase 12A's read-only adaptive recommendation layer.

- Phase 12A answers: *“What should the student work on next?”* via `AdaptiveRoadmapEngine` → `AdaptiveRoadmapResult` (derived, never persisted).
- Phase 12B answers: *“Can the existing roadmap safely adapt to the student's current progress?”* via **proposals** that translate derived intelligence into **explicit, user-confirmed structural adjustments** without rewriting the roadmap automatically.

> Adaptive Roadmaps propose structural changes; they do not silently rewrite the student's roadmap.

All adaptation is:
- deterministic (same canonical state → same proposals)
- sourced from existing canonical Student Graph data (Roadmap, SkillGraph, gaps, projects, opportunities, evidence, progress)
- gated by explicit user confirmation
- reversible when technically possible
- never automatically deleting student work

---

## 2. Canonical vs Derived Data

| Data | Category | Persisted? | Mutated by viewing? |
|------|----------|------------|---------------------|
| `Roadmap` (catalog milestones, actions, skillsDeveloped, dependencies) | Canonical template | No (static catalog) | No |
| `StudentProfile` (strengths, customSkills, careers, fields, milestones) | Canonical | Yes (AppDataStore) | No |
| `roadmapProgress` [roadmapID → completedCount] | Canonical | Yes | Only on explicit completion |
| `completedActionIDs` | Canonical | Yes | Only on explicit toggle |
| `customProjects`, `projectProgress` | Canonical | Yes | Only on explicit creation/completion |
| `opportunities` (canonical, deduped) | Canonical | Yes | Only on ingest/upsert |
| `evidenceRecords` | Canonical | Yes | Only on milestone completion or student entry |
| `activeRoadmaps` | Canonical | Yes | Only on start/deactivate |
| `AdaptiveRoadmapResult`, `AdaptiveRoadmapContext`, `AdaptiveRoadmapRecommendation` | Derived (Phase 12A) | No | No |
| `AdaptiveRoadmapProposal` | Derived proposal (Phase 12B) | No (recomputed) | No |
| `AdaptiveRoadmapOverrides` (deferred IDs, linked projects/opportunities, reordered milestones/actions, applied IDs, dismissed IDs, skill sequences, history) | Controlled mutation layer | Yes (single UserDefaults blob `studentops.adaptiveOverrides`) | Only via explicit `applyAdaptiveProposal` / `revert` / `dismiss` |

Architecture:

```text
Student Graph (AppDataStore)
        ↓
AdaptiveRoadmapEngine (Phase 12A, read-only)
        ↓
AdaptiveRoadmapResult (derived)
        ↓
AdaptiveRoadmapProposalEngine (Phase 12B, read-only, consumes result)
        ↓
[AdaptiveRoadmapProposal] (derived, sorted by priority)
        ↓
User reviews → Explicit Apply (AppDataStore.applyAdaptiveProposal) → Updated Canonical Overrides
        ↓
Effective roadmap order / deferred / links (via AppDataStore.effectiveMilestones etc.)
```

No duplicate roadmap model, no duplicate skill graph, no new database.

---

## 3. Proposal Architecture

### 3.1 Flow Boundary

```text
Canonical Roadmap
       ↓
AdaptiveRoadmapEngine → Adaptive Proposal
       ↓
User reviews (Review / Keep Current Roadmap / Dismiss)
       ↓
Explicit Apply
       ↓
Updated Canonical Roadmap (via overrides)
```

Never skip proposal/review for destructive or structural changes. Proposals appear automatically when state changes, but **never auto-mutate**.

### 3.2 Files

- `AdaptiveRoadmapProposal.swift` — model (`AdaptiveRoadmapProposal`, `AdaptiveProposalChangeType`, `AdaptiveProposalReasonCode`, `AdaptiveProposalStateSnapshot`, `AdaptiveRoadmapOverrides`, `AppliedProposalRecord`)
- `AdaptiveRoadmapProposalEngine.swift` — deterministic generation `proposals(roadmap:profile:store:) -> [AdaptiveRoadmapProposal]` consuming `AdaptiveRoadmapResult`
- `AdaptiveRoadmapUpdatesView.swift` — UI (`AdaptiveRoadmapUpdatesSection`, `AdaptiveProposalReviewSheet`)
- `AppDataStore.swift` extensions — persistence, validation, apply, revert, effective ordering, dismissal
- `RoadmapsView.swift` — adds top-level ROADMAP UPDATES section (uses `store.allAdaptiveProposals`)
- `RoadmapDetailView.swift` — adds per-roadmap ROADMAP UPDATES section via `store.adaptiveProposals(for:)`

---

## 4. Proposal Types

`AdaptiveProposalChangeType` (finite, no AI-generated types):

| Type | Meaning | Safe? |
|------|---------|-------|
| `unlockAction` | Previously blocked action/milestone now ready due to newly satisfied prerequisite or completed dependency | Yes — reorders milestone to active position |
| `reorderAction` | Advance to next existing action after completing previous (e.g., after completing an action, move next into focus) | Yes — reorders actions within milestone |
| `deferAction` | Suggest deferring an action exclusively dedicated to a skill now demonstrated | Yes — marks deferred (non-destructive, reversible) |
| `insertExistingProject` | Reuse an **existing** project that directly satisfies a roadmap action/skill | Yes — links existing projectID to action (no creation) |
| `connectOpportunity` | Connect an **existing eligible** opportunity aligned to a roadmap skill | Yes — links opportunityID only if `OpportunityEligibilityEngine` says eligible |
| `markProgressDerived` | Mark an action as derived progress when its skill is now demonstrated with evidence | Yes — inserts into `completedActionIDs` (reversible) |
| `adjustSkillSequence` | Correct skill ordering when prerequisite appears after dependent in roadmap order | Yes — reorders skill sequence / milestone order respecting dependencies |

Only changes representable by existing roadmap structures are supported. No arbitrary content creation.

### 4.1 Reason Codes

`AdaptiveProposalReasonCode` (deterministic):

- `newlySatisfiedPrerequisite` — prerequisite now in demonstrated set
- `blockedActionReady` — blocked action now unlocked
- `dependencyUnlocked` — milestone dependencies satisfied
- `relevanceChanged` — skill gap reduced, action relevance changed
- `projectSatisfiesNeed` — existing project builds missing/demonstrated skill
- `projectCompleted` — completed project can serve as evidence/context
- `opportunityAligned` — eligible opportunity builds gap
- `skillGapReduced` — skill now demonstrated, exclusive action can be deferred
- `prerequisiteSatisfied` — prerequisites now satisfied, ready to reorder
- `actionCompleted` — previous action completed, suggest next
- `skillDemonstrated` — skill demonstrated, mark derived progress
- `evidenceConnection` — evidence exists, propose connection

Every proposal includes `explanation` (human-readable WHY) plus `reasonCode` for deterministic traceability.

---

## 5. Safe Adaptation Rules

Adaptation triggers only on **concrete state changes**:

1. **Completed prerequisite** (`Programming Fundamentals` → `Data Structures`): if prerequisite becomes demonstrated/completed, proposal may **unlock** the dependent milestone/action. Does not fabricate milestone.
2. **Completed action**: if an action is completed, proposal may recommend advancing to the **next existing action**. Does not fabricate new milestone.
3. **Skill gap changed**: if a previously missing skill is demonstrated, proposal may **defer** (not delete) actions exclusively dedicated to that gap. Does not auto-delete.
4. **Project completed**: if an existing project demonstrates a required skill, proposal may **connect** the completed project as evidence/context. Does not auto-create evidence.
5. **Existing project relevance**: if an existing project directly satisfies a roadmap action's skill, proposal suggests **reusing** that project rather than creating another.
6. **Opportunity**: if an existing **eligible** opportunity is strongly aligned with a roadmap skill, proposal suggests **connecting** it. Eligibility still comes from `OpportunityEligibilityEngine`; ineligible opportunities strictly excluded.

If something is no longer relevant, prefer `Defer` or `Suggest adjustment` over destructive deletion.

---

## 6. User Confirmation

Structural changes **require explicit user action**. No background mutation on launch, view open, profile change, progress change, or project completion — those events only cause **new proposals to appear**.

Example banner (ROADMAP UPDATE AVAILABLE):

```text
Data Structures is now available.
You completed its prerequisite: Programming Fundamentals.
Suggested change: Move Data Structures into your active sequence.
[Review] [Keep Current Roadmap]
```

Review screen shows:

```text
CURRENT
Phase 2 Algorithms
Phase 3 Projects

PROPOSED
Phase 2 Data Structures
Phase 3 Algorithms
Phase 4 Projects

WHY: Data Structures was previously blocked by Programming Fundamentals.
```

Actions in `AdaptiveProposalReviewSheet`:
- **Apply** → `store.applyAdaptiveProposal(proposal)` (validates first)
- **Keep Current Roadmap** / **Dismiss** → `store.dismissProposal(proposal)` (hides until assumptions change, does not mutate)
- **Reversible** badge indicates undo possible via `revertAdaptiveProposal`

---

## 7. Validation

Before applying, `isProposalValid(_:)` checks:

- RoadmapID still exists in catalog
- Affected action/milestone/phase IDs still exist (no invalid references)
- Source projectID still exists (if `insertExistingProject`)
- Source opportunityID still exists **and** still eligible (if `connectOpportunity`)
- Prerequisites remain satisfied (skill still demonstrated or dependency still met)
- **Staleness**: proposal still appears in **recomputed** `AdaptiveRoadmapProposalEngine.proposals(...)` for current canonical state; if not, it is stale → `“Proposal is outdated. Recalculate recommendations.”` and apply returns `false`.

Idempotency: if `appliedProposalIDs` already contains `proposal.id`, `apply` returns `true` without duplicating (history not duplicated, overrides not duplicated).

---

## 8. Stale Proposals

A proposal becomes stale if underlying assumptions change:

- prerequisite completed/removed
- roadmap action/milestone changed (catalog edit or manual reorder)
- project deleted
- opportunity becomes ineligible (age/grade/location/deadline change)
- profile goal/career changed
- roadmap manually edited via overrides (conflicting reorder)

Stale proposals are **rejected or recalculated**, never applied. Validation recomputes proposals and checks `contains(id)`; if missing, stale. Dismissed IDs are also cleared when they become stale, so a previously dismissed proposal can reappear if regenerated under new assumptions via `clearDismissedIfStale`.

---

## 9. Conflict Handling

If the student manually changes the roadmap while a proposal exists (e.g., manual reorder via overrides conflicting with `beforeState`), the proposal must be **revalidated**. Applying checks `beforeState` vs current overrides; mismatch → validation fails, proposal considered outdated, manual change has precedence.

User-created/manual roadmap changes (via explicit overrides or completed actions) have **precedence** over old adaptive proposals. Proposals do not overwrite manual changes.

Example: applied `reorderAction` moving milestone X early; user later manually reorders differently → next `unlockAction` proposal recomputes from new order, not old.

---

## 10. Applying Proposals

Controlled mutation API through `AppDataStore`:

```swift
@discardableResult func applyAdaptiveProposal(_ proposal: AdaptiveRoadmapProposal) -> Bool
@discardableResult func revertAdaptiveProposal(_ proposal: AdaptiveRoadmapProposal) -> Bool
func isProposalValid(_ proposal: AdaptiveRoadmapProposal) -> Bool
func adaptiveProposals(for roadmap: Roadmap) -> [AdaptiveRoadmapProposal]
var allAdaptiveProposals: [AdaptiveRoadmapProposal] { get }
```

Per-type mutations (all reversible):

- `reorderAction` / `unlockAction` / `adjustSkillSequence`: updates `reorderedMilestones[roadmapID]` or `reorderedActions[milestoneID]` after validating dependency order (`isValidMilestoneOrder` ensures dependencies still respected). Stores `beforeState` / `afterState` in history.
- `deferAction`: inserts `affectedActionIDs` into `deferredActionIDs` set.
- `insertExistingProject`: sets `linkedProjects[actionID] = projectID` (validated project exists).
- `connectOpportunity`: sets `linkedOpportunities[actionID] = opportunityID` only if `eligibility.isEligible`.
- `markProgressDerived`: inserts `actionID` into `completedActionIDs` and `completedActionOverrides` (reusing existing toggle path, reversible).

If validation fails, apply returns `false`, no mutation. If already applied, apply returns `true` idempotently.

All overrides persisted via `AdaptiveRoadmapOverrides` blob in UserDefaults (`studentops.adaptiveOverrides`), separate from catalog, no new database.

---

## 11. Reversibility

Every applied structural adaptation is reversible when technically possible. Minimal reversible change record:

```swift
struct AppliedProposalRecord {
  proposalID, roadmapID, changeType,
  beforeState, afterState, appliedAt,
  affectedActionIDs, affectedMilestoneIDs, isReversible
}
```

`revertAdaptiveProposal` restores `beforeState`:
- milestone/action order → restored or removed if was new
- deferred sets → remove IDs
- linked project/opportunity → restore previous or remove
- completed actions → remove from `completedActionIDs`
- skill sequences → restore

Revert returns `false` if not `isReversible` or not found in history. Not a full version-control system, just per-proposal snapshot.

---

## 12. No Automatic Mutation

Adaptive proposals **must not** modify the roadmap simply because:
- app launches
- Roadmap screen opens
- profile changes
- progress changes
- project completed

Those events may cause **new proposals to appear** (recomputed on demand), but only explicit user confirmation may apply a structural change via `applyAdaptiveProposal`.

Verified by tests: repeated `proposals(...)` calls produce zero mutations to `completedActionIDs`, `deferredActionIDs`, `linkedProjects`, etc.

---

## 13. Determinism

Same canonical state → same proposals, same priority, same ordering.

Guarantees:
- Pure functions: no randomness, no AI, no Date-based variance except fixed epoch `createdAt` for deterministic testing (engine uses `Date(timeIntervalSince1970: 1_700_000_000)` for ID generation; display uses derived timestamp)
- Consumption of `AdaptiveRoadmapResult` (which itself is deterministic) rather than duplicating prerequisite/skill-gap logic
- Stable sorting: priority descending → `changeType.rawValue` ascending → `title` ascending → `id` ascending
- Deduplication by stable ID (`roadmapID-type-key`)
- Set → sorted array conversions before comparisons

---

## 14. Testing

File: `test-adaptive-roadmap-proposals.swift` — run via `swift test-adaptive-roadmap-proposals.swift`

Coverage (60 assertions across 25 suites):

| Suite | Tests |
|-------|-------|
| Proposal generation: deterministic output, correct type/reason, correct affected IDs | 3 |
| Prerequisites: newly satisfied prerequisite creates proposal, blocked dependency becomes available, unresolved dependency cannot be unlocked | 3 |
| Existing work: completed project can be connected, completed action not duplicated, existing project reuse, existing opportunity reuse | 4 |
| Safety: no automatic mutation, no deletion/fabrication, no fabricated actions/prerequisites/opportunities, no stale application | 2 (multi-check) |
| Validation: changed roadmap invalidates, changed profile invalidates, changed prerequisite invalidates, deleted object invalidates | 4 |
| Apply: valid applies correctly, invalid rejected, applying twice does not duplicate, unrelated content unchanged | 4 |
| Reversibility: reversible changes can be restored (defer, project link, milestone reorder) | 1 (multi-step) |
| Determinism: same state → same proposals | 1 |
| Performance: 100 careers, 500 skills, 1,000 opportunities, multiple roadmaps/projects/evidence < 2s | 1 |
| No fabricated IDs after apply, conflict handling (manual change stale) | 2 |

Also verifies Phase 12A regression: `test-adaptive-roadmap-intelligence.swift` (50 tests) still passes, plus roadmap/career/opportunity/project/evidence suites.

---

## 15. Performance

Benchmark inside `test-adaptive-roadmap-proposals.swift` (suite 23): 5 runs on 1,000 opportunities + 20 projects, 4-milestone roadmap → **~0.09s** on simulator.

Architecture budget: **< 2.0 seconds** for `AdaptiveRoadmapProposalEngine.proposals(...)`. Empirical measurement with:

- 100 careers (via `CareerCatalog.all` union)
- 500 distinct skills (simulated via `"Skill \(i % 500)"`)
- 1,000 opportunities (500 eligible, 500 ineligible)
- multiple roadmaps (SE roadmap 4 milestones, simple roadmap 2)
- multiple projects (20 custom)
- multiple evidence records (linked to skills)
- multiple proposals (up to 8 per roadmap cap)

Achieved via:
- `Set`/`Dictionary` lookups for prerequisite/eligibility checks
- Reuse of `AdaptiveRoadmapResult` rather than recomputing gaps
- Early continues via `contains` checks
- Proposal cap at 8 per roadmap
- Stable sorting O(n log n) with n ≤ 8

No new caching/database architecture introduced.

---

## 16. Deferred Features

Explicitly **not** built (deferred to future phases per spec §18):

- AI-generated roadmaps or AI roadmap decision-making
- Automatic roadmap rewriting without confirmation
- Automatic phase/milestone/project/evidence creation
- Automatic phase creation
- Notifications / reminders
- Cloud sync / authentication
- Social/community features
- Salary/job-market data, admissions/employment predictions, personality analysis

Also deferred within 12B scope:
- Multi-roadmap batch apply (single proposal per sheet only)
- Proposal diff visualization beyond before/after ordered IDs
- Full version-control history (only per-proposal before/after snapshot)
- Background refresh of proposals (they are recomputed on demand when views appear)

---

## Appendix: Verification Checklist

- [x] All Phase 12A tests pass (`test-adaptive-roadmap-intelligence.swift` 50/50)
- [x] Phase 12B tests pass (`test-adaptive-roadmap-proposals.swift` 60/60)
- [x] Xcode build succeeds (iPhone 17 simulator)
- [x] Vitest passes (`npm test` — 1 pass, 3 tests)
- [x] TypeScript passes (`npm run typecheck` — no errors)
- [x] Deterministic: same inputs → identical proposals, titles, priorities, IDs
- [x] No new database / no duplicate roadmap model / no duplicate skill graph
- [x] No new tab (only sections in existing Roadmaps tab + detail sheets)
- [x] No AI decision-making (only deterministic `CareerSkillGraph`, `SkillGapEngine`, `AdaptiveRoadmapEngine`, `OpportunityEligibilityEngine`)
- [x] No automatic mutation (viewing or profile change only generates new proposals)
- [x] No deletion of phases/milestones/actions/projects/evidence (defer preferred)
- [x] Reversible changes via `revertAdaptiveProposal`
- [x] Stale proposals rejected
- [x] Manual edits have precedence and cause revalidation

