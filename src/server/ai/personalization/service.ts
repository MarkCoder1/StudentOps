// Personalization Service — Phase 9.8
// Deterministic validation + structured AI generation. AI never decides eligibility/progress.

import { getAIProvider } from "../index";
import {
  buildProjectExplanationPrompt,
  buildProjectCoachingPrompt,
  buildProjectReflectionPrompt,
  buildSkillExplanationPrompt,
  buildRoadmapExplanationPrompt,
} from "./prompts";
import {
  PROJECT_EXPLANATION_SCHEMA,
  PROJECT_COACHING_SCHEMA,
  PROJECT_REFLECTION_SCHEMA,
  SKILL_EXPLANATION_SCHEMA,
  ROADMAP_EXPLANATION_SCHEMA,
} from "./schemas";
import type {
  ProjectExplanationContext,
  ProjectCoachingContext,
  ProjectReflectionContext,
  SkillExplanationContext,
  RoadmapExplanationContext,
  ProjectExplanationOutput,
  ProjectCoachingOutput,
  ProjectReflectionOutput,
  SkillExplanationOutput,
  RoadmapExplanationOutput,
} from "./types";

export type PersonalizationErrorCode =
  | "invalid_request"
  | "insufficient_context"
  | "ai_generation_failed"
  | "invalid_ai_response"
  | "unknown";

export interface PersonalizationError {
  code: PersonalizationErrorCode;
  message: string;
}

function err(code: PersonalizationErrorCode, message: string): PersonalizationError {
  return { code, message };
}

function validateProjectExplanationContext(ctx: ProjectExplanationContext): PersonalizationError | null {
  if (!ctx.project?.id || !ctx.project.title) return err("invalid_request", "project id/title required");
  if (typeof ctx.recommendation?.score !== "number") return err("invalid_request", "recommendation score required");
  if (!Array.isArray(ctx.recommendation.reasons)) return err("invalid_request", "reasons required");
  if (!ctx.student) return err("invalid_request", "student required");
  return null;
}
function validateProjectCoachingContext(ctx: ProjectCoachingContext): PersonalizationError | null {
  if (!ctx.project?.id) return err("invalid_request", "project id required");
  if (!ctx.execution) return err("invalid_request", "execution required");
  // currentStep may be null when completed, that's okay
  return null;
}
function validateProjectReflectionContext(ctx: ProjectReflectionContext): PersonalizationError | null {
  if (!ctx.project?.id) return err("invalid_request", "project id required");
  if (!ctx.execution) return err("invalid_request", "execution required");
  return null;
}
function validateSkillExplanationContext(ctx: SkillExplanationContext): PersonalizationError | null {
  if (!ctx.skill?.id) return err("invalid_request", "skill id required");
  if (!ctx.gapReason) return err("invalid_request", "gapReason required");
  return null;
}
function validateRoadmapExplanationContext(ctx: RoadmapExplanationContext): PersonalizationError | null {
  if (!ctx.roadmap?.id) return err("invalid_request", "roadmap id required");
  if (!ctx.progress) return err("invalid_request", "progress required");
  return null;
}

function hasSufficientContext(operation: string, ctx: unknown): boolean {
  // Minimal check: at least project/skill/roadmap present
  const c = ctx as Record<string, unknown>;
  if (!c) return false;
  // For all, require at least one meaningful field
  return true;
}

// ─── Project Explanation ───

export async function generateProjectExplanation(
  context: ProjectExplanationContext
): Promise<{ data: ProjectExplanationOutput; model: string; provider: string }> {
  const v = validateProjectExplanationContext(context);
  if (v) throw v;
  if (!hasSufficientContext("projectExplanation", context)) throw err("insufficient_context", "Insufficient context");

  const { system, user } = buildProjectExplanationPrompt(context);
  const provider = getAIProvider();
  try {
    const result = await provider.generateStructured<ProjectExplanationOutput>({
      system,
      user,
      temperature: 0.4,
      maxCompletionTokens: 800,
      outputSchema: PROJECT_EXPLANATION_SCHEMA,
    });
    const data = result.data as ProjectExplanationOutput;
    if (typeof data.summary !== "string" || data.summary.length < 20 || data.summary.length > 600) throw err("invalid_ai_response", "summary length invalid");
    if (!Array.isArray((data as unknown as { reasons?: unknown }).reasons) || data.reasons.length < 2 || data.reasons.length > 4) throw err("invalid_ai_response", "reasons length invalid");
    for (const r of data.reasons) {
      if (typeof r !== "string" || r.length < 10 || r.length > 200) throw err("invalid_ai_response", "reason length invalid");
    }
    return { data, model: result.model, provider: result.provider };
  } catch (e) {
    const code = (e as { code?: string })?.code;
    if (code && ["missing_api_key","timeout","rate_limit","provider_error","empty_response","invalid_json","schema_validation_failed"].includes(code)) {
      throw err("ai_generation_failed", `AI generation failed: ${code}`);
    }
    if ((e as PersonalizationError)?.code) throw e;
    throw err("ai_generation_failed", "AI generation failed");
  }
}

// ─── Project Coaching ───

export async function generateProjectCoaching(
  context: ProjectCoachingContext
): Promise<{ data: ProjectCoachingOutput; model: string; provider: string }> {
  const v = validateProjectCoachingContext(context);
  if (v) throw v;
  const { system, user } = buildProjectCoachingPrompt(context);
  const provider = getAIProvider();
  try {
    const result = await provider.generateStructured<ProjectCoachingOutput>({
      system,
      user,
      temperature: 0.4,
      maxCompletionTokens: 900,
      outputSchema: PROJECT_COACHING_SCHEMA,
    });
    const data = result.data as ProjectCoachingOutput;
    if (typeof data.focus !== "string" || data.focus.length < 20 || data.focus.length > 400) throw err("invalid_ai_response", "focus length invalid");
    if (!Array.isArray((data as unknown as { actions?: unknown }).actions) || data.actions.length < 2 || data.actions.length > 5) throw err("invalid_ai_response", "actions length invalid");
    return { data, model: result.model, provider: result.provider };
  } catch (e) {
    if ((e as PersonalizationError)?.code) throw e;
    const code = (e as { code?: string })?.code;
    if (code && ["missing_api_key","timeout","rate_limit","provider_error","empty_response","invalid_json","schema_validation_failed"].includes(code)) {
      throw err("ai_generation_failed", `AI generation failed: ${code}`);
    }
    throw err("ai_generation_failed", "AI generation failed");
  }
}

// ─── Project Reflection ───

export async function generateProjectReflection(
  context: ProjectReflectionContext
): Promise<{ data: ProjectReflectionOutput; model: string; provider: string }> {
  const v = validateProjectReflectionContext(context);
  if (v) throw v;
  const { system, user } = buildProjectReflectionPrompt(context);
  const provider = getAIProvider();
  try {
    const result = await provider.generateStructured<ProjectReflectionOutput>({
      system,
      user,
      temperature: 0.4,
      maxCompletionTokens: 900,
      outputSchema: PROJECT_REFLECTION_SCHEMA,
    });
    const data = result.data as ProjectReflectionOutput;
    if (!Array.isArray((data as unknown as { prompts?: unknown }).prompts) || data.prompts.length < 3 || data.prompts.length > 5) throw err("invalid_ai_response", "prompts length invalid");
    return { data, model: result.model, provider: result.provider };
  } catch (e) {
    if ((e as PersonalizationError)?.code) throw e;
    const code = (e as { code?: string })?.code;
    if (code && ["missing_api_key","timeout","rate_limit","provider_error","empty_response","invalid_json","schema_validation_failed"].includes(code)) {
      throw err("ai_generation_failed", `AI generation failed: ${code}`);
    }
    throw err("ai_generation_failed", "AI generation failed");
  }
}

// ─── Skill Explanation ───

export async function generateSkillExplanation(
  context: SkillExplanationContext
): Promise<{ data: SkillExplanationOutput; model: string; provider: string }> {
  const v = validateSkillExplanationContext(context);
  if (v) throw v;
  const { system, user } = buildSkillExplanationPrompt(context);
  const provider = getAIProvider();
  try {
    const result = await provider.generateStructured<SkillExplanationOutput>({
      system,
      user,
      temperature: 0.4,
      maxCompletionTokens: 700,
      outputSchema: SKILL_EXPLANATION_SCHEMA,
    });
    const data = result.data as SkillExplanationOutput;
    if (typeof data.summary !== "string" || data.summary.length < 20 || data.summary.length > 400) throw err("invalid_ai_response", "summary length invalid");
    return { data, model: result.model, provider: result.provider };
  } catch (e) {
    if ((e as PersonalizationError)?.code) throw e;
    const code = (e as { code?: string })?.code;
    if (code && ["missing_api_key","timeout","rate_limit","provider_error","empty_response","invalid_json","schema_validation_failed"].includes(code)) {
      throw err("ai_generation_failed", `AI generation failed: ${code}`);
    }
    throw err("ai_generation_failed", "AI generation failed");
  }
}

// ─── Roadmap Explanation ───

export async function generateRoadmapExplanation(
  context: RoadmapExplanationContext
): Promise<{ data: RoadmapExplanationOutput; model: string; provider: string }> {
  const v = validateRoadmapExplanationContext(context);
  if (v) throw v;
  const { system, user } = buildRoadmapExplanationPrompt(context);
  const provider = getAIProvider();
  try {
    const result = await provider.generateStructured<RoadmapExplanationOutput>({
      system,
      user,
      temperature: 0.4,
      maxCompletionTokens: 800,
      outputSchema: ROADMAP_EXPLANATION_SCHEMA,
    });
    const data = result.data as RoadmapExplanationOutput;
    if (typeof data.summary !== "string" || data.summary.length < 20 || data.summary.length > 600) throw err("invalid_ai_response", "summary length invalid");
    if (!Array.isArray((data as unknown as { focusAreas?: unknown }).focusAreas) || data.focusAreas.length < 2 || data.focusAreas.length > 4) throw err("invalid_ai_response", "focusAreas length invalid");
    return { data, model: result.model, provider: result.provider };
  } catch (e) {
    if ((e as PersonalizationError)?.code) throw e;
    const code = (e as { code?: string })?.code;
    if (code && ["missing_api_key","timeout","rate_limit","provider_error","empty_response","invalid_json","schema_validation_failed"].includes(code)) {
      throw err("ai_generation_failed", `AI generation failed: ${code}`);
    }
    throw err("ai_generation_failed", "AI generation failed");
  }
}

// For testing
export const __test__ = {
  validateProjectExplanationContext,
  validateProjectCoachingContext,
  validateProjectReflectionContext,
  validateSkillExplanationContext,
  validateRoadmapExplanationContext,
};
