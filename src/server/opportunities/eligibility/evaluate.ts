import type { Opportunity } from "../models/opportunity";
import type { EligibilityResult, EligibilityCheck, StudentProfileForEligibility } from "./types";
import { evaluateAge } from "./age";
import { evaluateCountry, evaluateGeography, evaluateState } from "./geography";
import { evaluateEnrollment } from "./enrollment";
import { evaluateMajor } from "./major";
// DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
import { demoEligibilityScoreForId, DEMO_SCORES_ENABLED } from "../demoScores";

export function evaluateEligibility(
  opportunity: Opportunity,
  student: StudentProfileForEligibility,
  asOf: Date = new Date()
): EligibilityResult {
  const checks: EligibilityCheck[] = [];

  checks.push(evaluateAge(opportunity, student, asOf));
  checks.push(evaluateCountry(opportunity, student));
  checks.push(evaluateGeography(opportunity, student));
  checks.push(evaluateState(opportunity, student));
  checks.push(evaluateEnrollment(opportunity, student));
  checks.push(evaluateMajor(opportunity, student));

  // Deduplicate? Keep all 6 dimensions for explainability

  const hasIneligible = checks.some((c) => c.status === "ineligible");
  const hasUnknown = checks.some((c) => c.status === "unknown");
  const hasEligible = checks.some((c) => c.status === "eligible");

  let overall: EligibilityResult["status"];
  const reasons: EligibilityResult["reasons"] = [];

  // Check if opportunity has no structured requirements at all
  const hasNoRequirements =
    opportunity.eligibility.minAge === null &&
    opportunity.eligibility.maxAge === null &&
    (opportunity.eligibility.countries === null || opportunity.eligibility.countries.length === 0) &&
    !opportunity.eligibility.geographicRestrictions &&
    (opportunity.eligibility.enrollmentLevels === null || opportunity.eligibility.enrollmentLevels.length === 0) &&
    (opportunity.eligibility.majors === null || opportunity.eligibility.majors.length === 0);

  if (hasNoRequirements) {
    overall = "unknown";
    // Do not push ineligible, just note unknown
  } else if (hasIneligible) {
    overall = "ineligible";
  } else if (hasUnknown) {
    overall = "unknown";
  } else if (hasEligible) {
    overall = "eligible";
  } else {
    // Should not happen — no checks with eligible and no ineligible/unknown but has requirements
    overall = "unknown";
  }

  // If overall is eligible, it means all applicable checks were eligible and no unknowns
  // But our current checks always return unknown when no restriction, so eligible only when at least one check was eligible and none unknown/ineligible
  // Adjust: if hasNoRequirements, status is unknown regardless
  if (hasNoRequirements) {
    overall = "unknown";
  }

  // Build reasons: include all non-unknown checks, plus unknowns that explain
  for (const c of checks) {
    if (c.status !== "unknown" || c.reason.includes("not specified") || c.reason.includes("not available")) {
      // Include all checks for explainability, but keep concise
      reasons.push({ dimension: c.dimension, message: c.reason });
    }
  }

  // If truly no requirements, ensure at least one reason
  if (reasons.length === 0) {
    reasons.push({ dimension: "geography", message: "No structured eligibility requirements provided by source." });
  }

  // DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
  // Force all opportunities to appear eligible with high randomized scores (80-99%) for demo.
  // Keeps real opportunity names/data; only overrides displayed eligibility status/reasons.
  if (DEMO_SCORES_ENABLED) {
    const demoScore = demoEligibilityScoreForId(opportunity.id);
    return {
      status: "eligible",
      reasons: [{ dimension: "geography", message: `Eligibility score: ${demoScore}% — You appear highly eligible` }],
      checks: checks.map((c) => ({ ...c, status: "eligible" as const, reason: `Eligible (${demoScore}% match)` })),
    };
  }

  return {
    status: overall,
    reasons,
    checks,
  };
}

export function evaluateOpportunities(
  opportunities: Opportunity[],
  student: StudentProfileForEligibility,
  asOf: Date = new Date()
): Array<{ opportunity: Opportunity; eligibility: EligibilityResult }> {
  return opportunities.map((opp) => ({
    opportunity: opp,
    eligibility: evaluateEligibility(opp, student, asOf),
  }));
}
