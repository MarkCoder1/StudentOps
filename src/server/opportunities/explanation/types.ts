// Opportunity Explanation Types — Phase 6.2
// Structured AI explanation of why an opportunity fits a specific student.

/** Structured AI explanation returned to the client. */
export interface OpportunityExplanation {
  /** Why this opportunity fits the student's profile and interests. */
  whyThisFits: string;
  /** How this opportunity connects to the student's roadmap and goals. */
  roadmapConnection: string;
  /** Concrete next step the student should take. */
  nextStep: string;
}

/** JSON Schema for Groq structured output validation. */
export const EXPLANATION_SCHEMA = {
  type: "object",
  properties: {
    whyThisFits: { type: "string" },
    roadmapConnection: { type: "string" },
    nextStep: { type: "string" },
  },
  required: ["whyThisFits", "roadmapConnection", "nextStep"],
  additionalProperties: false,
} as const;
