// Explanation Service — Phase 6.2
// Server-side service that generates an AI explanation for a specific opportunity + student.
// Uses existing deterministic engines + AI provider. No secrets exposed.

import type { Opportunity } from "../models/opportunity";
import type { StudentProfileForPersonalization, PersonalizedOpportunity } from "../personalization/types";
import type { OpportunityExplanation } from "./types";
import { EXPLANATION_SCHEMA } from "./types";
import { buildExplanationPrompt } from "./prompt";
import { getAIProvider } from "../../ai";
import { buildStudentContext, buildOpportunityContext, buildEngineResult } from "../../ai/context";
import { personalizeOpportunities } from "../personalization";

export interface ExplanationRequest {
  opportunityId: string;
  profile: StudentProfileForPersonalization;
}

export interface ExplanationResult {
  explanation: OpportunityExplanation;
}

export interface ExplanationError {
  error: {
    code: string;
    message: string;
  };
}

/**
 * Generate an AI explanation for why a specific opportunity fits a student.
 *
 * Flow:
 * 1. Load opportunity from DB via service
 * 2. Run deterministic engines (eligibility, matching, freshness)
 * 3. Build compact AI context
 * 4. Call AIProvider with structured output
 * 5. Return validated explanation
 */
export async function generateExplanation(
  opportunity: Opportunity,
  profile: StudentProfileForPersonalization
): Promise<ExplanationResult> {
  // 1. Run personalization engines for this single opportunity
  const feed = personalizeOpportunities([opportunity], profile, new Date());
  const personalized: PersonalizedOpportunity = feed.opportunities[0];

  // 2. Build AI context
  const studentCtx = buildStudentContext(profile);
  const opportunityCtx = buildOpportunityContext(opportunity);
  const enginesCtx = buildEngineResult(personalized);

  // 3. Build prompt
  const { system, user } = buildExplanationPrompt({
    student: studentCtx,
    opportunity: opportunityCtx,
    engines: enginesCtx,
  });

  // 4. Call AI provider with structured output
  const provider = getAIProvider();
  const result = await provider.generateStructured<OpportunityExplanation>({
    system,
    user,
    reasoningEffort: "low",
    outputSchema: {
      name: "opportunity_explanation",
      description: "Structured explanation of why an opportunity fits a student",
      schema: EXPLANATION_SCHEMA,
      strict: true,
    },
  });

  return { explanation: result.data };
}
