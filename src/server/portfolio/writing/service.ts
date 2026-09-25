// Portfolio Writing Service — Phase 8.9
// Deterministic, fact-grounded, read-only, no persistence.

import { getAIProvider } from "../../ai";
import { buildPortfolioWritingPrompt } from "./prompt";
import { buildPortfolioWritingContext, fingerprintContext } from "./context";
import type {
  PortfolioWritingRequest,
  PortfolioWritingResponse,
  PortfolioWritingError,
  PortfolioWritingType,
  PortfolioWritingContext,
} from "./types";
import { PORTFOLIO_WRITING_SCHEMA, type PortfolioWritingStructuredOutput } from "./types";

// ─── Length Limits (server-enforced) ───────────────────────────────

const LENGTH_LIMITS: Record<PortfolioWritingType, number> = {
  headline: 160,
  about: 1200,
  goal: 400,
  projectDescription: 1000,
  achievementDescription: 800,
  evidenceDescription: 800,
  roadmapSummary: 1000,
};

// ─── Error Helpers ─────────────────────────────────────────────────

function err(code: PortfolioWritingError["code"], message: string): PortfolioWritingError {
  return { code, message };
}

// ─── Validation ────────────────────────────────────────────────────

function validateRequest(req: PortfolioWritingRequest): PortfolioWritingError | null {
  if (!req.portfolioID || !req.portfolioID.trim()) return err("invalid_request", "portfolioID is required");
  if (!req.writingType) return err("invalid_request", "writingType is required");
  const validTypes: PortfolioWritingType[] = ["headline","about","goal","projectDescription","achievementDescription","evidenceDescription","roadmapSummary"];
  if (!validTypes.includes(req.writingType)) return err("invalid_request", `Invalid writingType: ${req.writingType}`);
  if (!req.tone) return err("invalid_request", "tone is required");
  if (!req.length) return err("invalid_request", "length is required");
  if (!req.context) return err("invalid_request", "context is required");
  if (!req.context.portfolio || !req.context.portfolio.id) return err("invalid_request", "context.portfolio.id is required");
  if (req.writingType !== "headline" && req.writingType !== "about" && req.writingType !== "goal" && !req.targetID) {
    // For entity-specific types, targetID is required
    return err("invalid_request", `targetID is required for ${req.writingType}`);
  }
  return null;
}

function validateResponse(
  data: PortfolioWritingStructuredOutput,
  writingType: PortfolioWritingType,
  context: PortfolioWritingContext,
  expectedSourceIDs: string[]
): PortfolioWritingError | null {
  if (!data.drafts || !Array.isArray(data.drafts) || data.drafts.length === 0) {
    return err("invalid_ai_response", "Model returned no drafts");
  }
  for (const draft of data.drafts) {
    if (typeof draft !== "string" || !draft.trim()) {
      return err("invalid_ai_response", "Draft must be a non-empty string");
    }
    const limit = LENGTH_LIMITS[writingType];
    if (draft.length > limit) {
      return err("invalid_ai_response", `Draft exceeds length limit ${limit} for ${writingType}`);
    }
  }
  if (!Array.isArray(data.factualClaims)) return err("invalid_ai_response", "factualClaims must be an array");
  if (!Array.isArray(data.warnings)) return err("invalid_ai_response", "warnings must be an array");
  if (typeof data.needsMoreContext !== "boolean") return err("invalid_ai_response", "needsMoreContext must be boolean");
  if (!Array.isArray(data.sourceIDs)) return err("invalid_ai_response", "sourceIDs must be an array");
  for (const sid of data.sourceIDs) {
    if (typeof sid !== "string" || !sid.trim()) return err("invalid_ai_response", "sourceIDs must be non-empty strings");
    if (!expectedSourceIDs.includes(sid)) {
      return err("invalid_ai_response", `Source ID ${sid} not in supplied context`);
    }
  }
  // Check unexpected fields (additionalProperties: false) is already enforced by schema validation in GroqProvider,
  // but we also ensure no extra top-level keys beyond expected
  const allowed = new Set(["drafts","factualClaims","warnings","needsMoreContext","sourceIDs"]);
  for (const key of Object.keys(data as unknown as Record<string, unknown>)) {
    if (!allowed.has(key)) return err("invalid_ai_response", `Unexpected field: ${key}`);
  }
  return null;
}

// ─── Integrity Gate ────────────────────────────────────────────────

function checkIntegrity(
  writingType: PortfolioWritingType,
  targetID: string | null | undefined,
  context: PortfolioWritingContext
): PortfolioWritingError | null {
  // For entity-specific types, ensure target is in context and not stale
  // Headline/about/goal do not require target existence
  if (["headline","about"].includes(writingType)) {
    return null;
  }
  if (writingType === "goal") {
    // Goal: targetID may be index or goal text; check if portfolio.goals contains it or index valid
    if (!targetID) {
      // No specific goal, writing for portfolio goals generally — allow
      return null;
    }
    const goals = context.portfolio.goals ?? [];
    const idx = Number(targetID);
    if (!Number.isNaN(idx) && goals[idx] !== undefined) return null;
    if (goals.includes(targetID)) return null;
    // If targetID is provided but not found, treat as insufficient context, not necessarily integrity error
    // But if it's a specific goal, we should allow generation even if not found — prompt will handle
    return null;
  }
  // For other types, target must be in context
  if (!targetID) return err("target_not_found", "targetID is required");
  switch (writingType) {
    case "projectDescription": {
      if (!context.projects.some((p) => p.id === targetID)) return err("target_not_found", `Project ${targetID} not found in context`);
      break;
    }
    case "achievementDescription": {
      if (!context.achievements.some((a) => a.id === targetID)) return err("target_not_found", `Achievement ${targetID} not found`);
      break;
    }
    case "evidenceDescription": {
      if (!context.evidence.some((e) => e.id === targetID)) return err("target_not_found", `Evidence ${targetID} not found`);
      break;
    }
    case "roadmapSummary": {
      if (!context.roadmaps.some((r) => r.id === targetID)) return err("target_not_found", `Roadmap ${targetID} not found`);
      break;
    }
    default:
      break;
  }
  // Check for structural errors affecting this target: we could run PortfolioGraphIntegrityEngine, but for now we treat missing target as integrity_error
  // Warnings/info do not block
  return null;
}

// ─── Main Service ──────────────────────────────────────────────────

export async function generatePortfolioWriting(
  request: PortfolioWritingRequest
): Promise<PortfolioWritingResponse> {
  // 1. Validate request
  const reqErr = validateRequest(request);
  if (reqErr) throw reqErr;

  const { portfolioID, writingType, targetID, currentText, tone, length, context } = request;

  // 2. Integrity gate
  const integrityErr = checkIntegrity(writingType, targetID ?? null, context);
  if (integrityErr) throw integrityErr;

  // 3. Check if target is selected in portfolio (for entity-specific types, ensure it's part of portfolio selection)
  // This is a soft check: if writing for a project not selected, we still allow but we could warn
  // For now, we allow but we could return insufficient_context if needed
  // We will not block if target not selected, but we will include warning later

  // 4. Build deterministic context (already provided, but we re-fingerprint for stale check)
  const fingerprint = fingerprintContext(context);

  // If request has contextFingerprint and it doesn't match current fingerprint, it's stale
  if (request.contextFingerprint && request.contextFingerprint !== fingerprint) {
    throw err("stale_context", "Context has changed since draft was generated. Regenerate.");
  }

  // 5. Build prompt
  const { system, user } = buildPortfolioWritingPrompt({
    context,
    writingType,
    currentText: currentText ?? null,
    tone,
    length,
  });

  // 6. Call AI provider with structured output
  const provider = getAIProvider();
  let result;
  try {
    result = await provider.generateStructured<PortfolioWritingStructuredOutput>({
      system,
      user,
      temperature: 0.4,
      maxCompletionTokens: 1024,
      outputSchema: {
        name: "portfolio_writing",
        description: "Portfolio writing drafts grounded in supplied facts",
        schema: PORTFOLIO_WRITING_SCHEMA,
        strict: true,
      },
    });
  } catch (e) {
    // Normalize AI errors to PortfolioWritingError
    const code = (e as { code?: string })?.code ?? "unknown";
    if (["missing_api_key","timeout","rate_limit","provider_error","empty_response","invalid_json","schema_validation_failed"].includes(code)) {
      throw err("ai_generation_failed", `AI generation failed: ${code}`);
    }
    throw err("ai_generation_failed", `AI generation failed`);
  }

  const data = result.data;

  // 7. Validate response
  const expectedSourceIDs = [
    ...context.projects.map((p) => p.id),
    ...context.achievements.map((a) => a.id),
    ...context.evidence.map((e) => e.id),
    ...context.skills.map((s) => s.id),
    ...context.roadmaps.map((r) => r.id),
    context.portfolio.id,
  ];
  const validationErr = validateResponse(data, writingType, context, expectedSourceIDs);
  if (validationErr) throw validationErr;

  // 8. Enforce length limits on first draft (use first draft as primary)
  const draft = data.drafts[0].trim();
  const limit = LENGTH_LIMITS[writingType];
  if (draft.length > limit) {
    throw err("invalid_ai_response", `Draft exceeds length limit`);
  }
  if (!draft) throw err("invalid_ai_response", "Draft is empty");

  // 9. Build response
  return {
    draft,
    writingType,
    sourceIDs: data.sourceIDs,
    factualClaims: data.factualClaims,
    warnings: data.warnings,
    needsMoreContext: data.needsMoreContext,
    contextFingerprint: fingerprint,
    model: result.model,
    provider: result.provider,
  };
}

// ─── Export for testing ────────────────────────────────────────────

export const __test__ = {
  validateRequest,
  validateResponse,
  checkIntegrity,
  LENGTH_LIMITS,
};
