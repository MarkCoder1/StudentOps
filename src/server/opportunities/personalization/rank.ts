import type { EligibilityStatus } from "../eligibility/types";
import type { DeadlineUrgency } from "../freshness/types";
import type { FreshnessStatus } from "../freshness/types";
import type { PersonalizedOpportunity } from "./types";
// DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
import { DEMO_SCORES_ENABLED } from "../demoScores";

// Deterministic ranking formula for personalized opportunities.
//
// rankScore = (matchScore * 0.5) + (urgencyBonus * 0.3) + (eligibilityBonus * 0.2)
//
// Components:
//   matchScore: 0-100 from MatchingEngine (weighted average of 7 dimensions)
//   urgencyBonus: 0-100 based on deadline proximity
//     - "urgent" (0-3 days): 100
//     - "soon" (4-7 days): 75
//     - "upcoming" (8-30 days): 50
//     - "later" (>30 days): 25
//     - "none" (no deadline or expired): 0
//   eligibilityBonus:
//     - "eligible": 100
//     - "unknown": 50
//     - "ineligible": 0
//
// Final rankScore range: 0-100
// Tie-breaking: same rankScore → earlier deadline first → higher match score → alphabetical title

const URGENCY_WEIGHTS: Record<DeadlineUrgency, number> = {
  urgent: 100,
  soon: 75,
  upcoming: 50,
  later: 25,
  none: 0,
};

const ELIGIBILITY_WEIGHTS: Record<EligibilityStatus, number> = {
  eligible: 100,
  unknown: 50,
  ineligible: 0,
};

export function calculateRankScore(
  matchScore: number,
  urgency: DeadlineUrgency,
  eligibility: EligibilityStatus,
  daysUntilDeadline: number | null
): number {
  const urgencyBonus = URGENCY_WEIGHTS[urgency] ?? 0;
  const eligibilityBonus = ELIGIBILITY_WEIGHTS[eligibility] ?? 0;

  // Weighted combination
  const raw = (matchScore * 0.5) + (urgencyBonus * 0.3) + (eligibilityBonus * 0.2);
  const result = Math.round(Math.max(0, Math.min(100, raw)));
  // DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
  // Ensure rankScore never drops below 80% for demo. Primary per-ID override is in personalization/index.ts.
  if (DEMO_SCORES_ENABLED && result < 80) {
    return 80;
  }
  return result;
}

// Compare two rank scores for sorting. Deterministic tie-breaking.
export function compareRankScores(a: PersonalizedOpportunity, b: PersonalizedOpportunity): number {
  // Primary: higher rankScore first
  if (b.rankScore !== a.rankScore) return b.rankScore - a.rankScore;

  // Tie-break 1: earlier deadline first (smaller daysUntilDeadline = more urgent)
  // null deadlines sort after those with deadlines
  const aDays = a.freshness.daysUntilDeadline;
  const bDays = b.freshness.daysUntilDeadline;
  if (aDays !== bDays) {
    if (aDays === null) return 1;
    if (bDays === null) return -1;
    return aDays - bDays;
  }

  // Tie-break 2: higher match score first
  if (b.match.score !== a.match.score) return b.match.score - a.match.score;

  // Tie-break 3: alphabetical title
  return a.opportunity.title.localeCompare(b.opportunity.title);
}

// Generate badges based on match, eligibility, freshness, and cost
export function generateBadges(
  matchScore: number,
  eligibility: EligibilityStatus,
  urgency: DeadlineUrgency,
  isFree: boolean | null,
  category: string
): string[] {
  const badges: string[] = [];

  // Best Match badge (top 20% of scores)
  if (matchScore >= 80 && eligibility !== "ineligible") {
    badges.push("Best Match");
  }

  // Deadline Soon
  if (urgency === "urgent") {
    badges.push("Deadline Soon");
  } else if (urgency === "soon") {
    badges.push("Deadline Soon");
  }

  // Category badges
  const cat = category.toLowerCase();
  if (cat === "scholarship") badges.push("Scholarship");
  if (cat === "hackathon") badges.push("Hackathon");
  if (cat === "competition") badges.push("Competition");

  // Free badge
  if (isFree === true) {
    badges.push("Free");
  }

  return badges;
}
