import type { Opportunity } from "../models/opportunity";
import type { StudentProfileForMatching, MatchResult } from "./types";
import type { EligibilityResult } from "../eligibility/types";
import { getMatchLabel } from "./types";
import {
  signalInterest,
  signalCareer,
  signalField,
  signalSkill,
  signalSubject,
  signalGoal,
  signalCategory,
} from "./signals";
import { calculateScore } from "./score";
// DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
import { demoMatchScoreForId, DEMO_SCORES_ENABLED } from "../demoScores";

export function matchOpportunity(
  opportunity: Opportunity,
  student: StudentProfileForMatching,
  eligibility?: EligibilityResult | null
): MatchResult {
  const signals = [
    signalInterest(student, opportunity),
    signalCareer(student, opportunity),
    signalField(student, opportunity),
    signalSkill(student, opportunity),
    signalSubject(student, opportunity),
    signalGoal(student, opportunity),
    signalCategory(student, opportunity),
  ];

  let score = calculateScore(signals);
  // DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
  // Keep real opportunity data but randomize displayed match scores to 80-99% for demo.
  if (DEMO_SCORES_ENABLED) {
    score = demoMatchScoreForId(opportunity.id);
  }
  const reasons = signals
    .filter((s) => s.available && s.score > 0)
    .map((s) => s.reason);

  return {
    opportunityId: opportunity.id,
    score,
    eligibility: eligibility ? eligibility.status : null,
    reasons,
    signals,
    label: getMatchLabel(score),
  };
}

export function matchOpportunities(
  opportunities: Opportunity[],
  student: StudentProfileForMatching,
  eligibilityMap?: Map<string, EligibilityResult>
): MatchResult[] {
  return opportunities.map((opp) => {
    const elig = eligibilityMap?.get(opp.id) ?? null;
    return matchOpportunity(opp, student, elig);
  });
}
