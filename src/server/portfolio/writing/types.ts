// Portfolio Writing Types — Phase 8.9
// Fact-grounded AI writing for Student OPS portfolios.
// Deterministic, career-agnostic, no invented facts.

export type PortfolioWritingType =
  | "headline"
  | "about"
  | "goal"
  | "projectDescription"
  | "achievementDescription"
  | "evidenceDescription"
  | "roadmapSummary";

export type PortfolioWritingTone =
  | "professional"
  | "concise"
  | "confident"
  | "natural"
  | "technical";

export type PortfolioWritingLength = "short" | "medium" | "detailed";

// ─── Request ───────────────────────────────────────────────────────

export interface PortfolioWritingRequest {
  /** Portfolio ID that owns the target. */
  portfolioID: string;
  /** What to write. */
  writingType: PortfolioWritingType;
  /** Target entity ID (projectID, achievementID, etc.) when applicable. */
  targetID?: string | null;
  /** Current text for rewrite/clarify, if any. */
  currentText?: string | null;
  /** Desired tone. */
  tone: PortfolioWritingTone;
  /** Desired length. */
  length: PortfolioWritingLength;
  /** Fact-grounded context built on server from canonical data. */
  context: PortfolioWritingContext;
  /** Deterministic fingerprint of the context used to generate this draft. */
  contextFingerprint?: string | null;
}

// ─── Context ───────────────────────────────────────────────────────

export interface PortfolioWritingContext {
  /** Portfolio metadata (title, headline, about, goals). */
  portfolio: {
    id: string;
    title: string;
    headline: string | null;
    about: string | null;
    goals: string[];
  };
  /** Student identity (factual, minimal). */
  student: {
    displayName: string | null;
    grade: string | null;
    schoolLevel: string | null;
    location: string | null;
  };
  /** Education (minimal). */
  education?: {
    grade: string | null;
    schoolLevel: string | null;
  } | null;
  /** Selected projects relevant to this writing task (target-specific). */
  projects: Array<{
    id: string;
    title: string;
    description: string | null;
    category: string | null;
    goal: string | null;
    skills: string[];
    progress: number | null;
    isCompleted: boolean | null;
    sourceRoadmapID: string | null;
    evidenceCount?: number | null;
    artifactURL?: string | null;
  }>;
  /** Selected achievements relevant to this task. */
  achievements: Array<{
    id: string;
    title: string;
    description: string | null;
    type: string | null;
    createdAt: string | null;
    evidenceCount: number | null;
    skillIDs: string[];
    roadmapID: string | null;
    projectID: string | null;
  }>;
  /** Selected evidence relevant to this task. */
  evidence: Array<{
    id: string;
    title: string;
    description: string | null;
    type: string | null;
    roadmapID: string | null;
    milestoneID: string | null;
    projectID: string | null;
    skillIDs: string[];
    artifactURL: string | null;
    createdAt: string | null;
    quality: string | null;
  }>;
  /** Selected skills relevant to this task. */
  skills: Array<{
    id: string;
    name: string;
  }>;
  /** Selected roadmaps relevant to this task. */
  roadmaps: Array<{
    id: string;
    title: string;
    goal: string | null;
    progress: number | null;
    isActive: boolean | null;
    completedMilestones: number | null;
    totalMilestones: number | null;
  }>;
  /** Factual constraints for this writing type. */
  constraints?: {
    writingType: PortfolioWritingType;
    targetID?: string | null;
  } | null;
}

// ─── Response ──────────────────────────────────────────────────────

export interface PortfolioWritingResponse {
  /** Polished draft text. */
  draft: string;
  /** Echo of requested writing type. */
  writingType: PortfolioWritingType;
  /** Canonical source IDs that supplied facts. */
  sourceIDs: string[];
  /** Factual claims used (must be traceable to context). */
  factualClaims: string[];
  /** Warnings (e.g., insufficient context). */
  warnings: string[];
  /** Whether more context would help. */
  needsMoreContext: boolean;
  /** Deterministic fingerprint of the context used. */
  contextFingerprint: string;
  /** Model and provider for audit (no secrets). */
  model: string;
  provider: string;
}

// ─── Error Codes ───────────────────────────────────────────────────

export type PortfolioWritingErrorCode =
  | "portfolio_not_found"
  | "target_not_found"
  | "target_not_selected"
  | "integrity_error"
  | "insufficient_context"
  | "ai_generation_failed"
  | "invalid_ai_response"
  | "stale_context"
  | "invalid_request";

export interface PortfolioWritingError {
  code: PortfolioWritingErrorCode;
  message: string;
}

// ─── JSON Schema for Groq Structured Output ────────────────────────

export const PORTFOLIO_WRITING_SCHEMA = {
  type: "object",
  properties: {
    drafts: {
      type: "array",
      description: "1-3 polished draft variants, all grounded in supplied facts.",
      items: { type: "string" },
      minItems: 1,
      maxItems: 3,
    },
    factualClaims: {
      type: "array",
      description: "Factual claims used, each traceable to supplied context.",
      items: { type: "string" },
    },
    warnings: {
      type: "array",
      description: "Warnings if context insufficient or ambiguous.",
      items: { type: "string" },
    },
    needsMoreContext: {
      type: "boolean",
      description: "Whether more canonical context would improve the draft.",
    },
    sourceIDs: {
      type: "array",
      description: "Canonical source IDs that supplied facts.",
      items: { type: "string" },
    },
  },
  required: ["drafts", "factualClaims", "warnings", "needsMoreContext", "sourceIDs"],
  additionalProperties: false,
} as const;

// For single-draft response (we use first draft)
export interface PortfolioWritingStructuredOutput {
  drafts: string[];
  factualClaims: string[];
  warnings: string[];
  needsMoreContext: boolean;
  sourceIDs: string[];
}
