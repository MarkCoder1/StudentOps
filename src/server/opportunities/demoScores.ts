// DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
// Generates deterministic realistic-looking eligibility/match scores >=80% for demo.
// Keeps real opportunity names/data, but displays randomized high scores (82%, 87%, 91%, 96% etc).
// Consistency: same opportunity ID always yields same score across all engines and displays.
//
// TO REVERT: delete this file and remove all "DEMO OVERRIDE" blocks in:
//   - src/server/opportunities/eligibility/evaluate.ts
//   - src/server/opportunities/matching/evaluate.ts
//   - src/server/opportunities/personalization/index.ts
//   - src/server/opportunities/personalization/rank.ts (if modified)

// Set to true for demo; automatically disabled during `npm test` (NODE_ENV=test) so tests verify real logic.
// To force demo scores during tests, set DEMO_SCORES_FORCE=true env var.
export const DEMO_SCORES_ENABLED =
  process.env.DEMO_SCORES_FORCE === "true" ? true : process.env.NODE_ENV !== "test";

/**
 * Deterministic hash -> 80-99 inclusive.
 * Uses same algorithm as Swift DemoScores for cross-platform consistency.
 * Java-style hash: hash = hash*31 + charCode with 32-bit overflow.
 */
export function demoEligibilityScoreForId(id: string): number {
  let hash = 0;
  for (let i = 0; i < id.length; i++) {
    hash = ((hash << 5) - hash + id.charCodeAt(i)) | 0;
  }
  const abs = Math.abs(hash);
  // 0-19 => 80-99; ensures distribution like 82,87,91,96 etc.
  return 80 + (abs % 20);
}

export function demoMatchScoreForId(id: string): number {
  return demoEligibilityScoreForId(id);
}

export function demoRankScoreForId(id: string): number {
  return demoEligibilityScoreForId(id);
}
