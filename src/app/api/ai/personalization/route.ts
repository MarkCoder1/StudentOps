// POST /api/ai/personalization
// Unified personalization endpoint (project/skill/roadmap). Server-side Groq, structured.
// Body: { operation: "projectExplanation" | "projectCoaching" | ..., context: {...} }

import { NextRequest, NextResponse } from "next/server";
import {
  generateProjectExplanation,
  generateProjectCoaching,
  generateProjectReflection,
  generateSkillExplanation,
  generateRoadmapExplanation,
} from "@/server/ai/personalization/service";

export const dynamic = "force-dynamic";

const VALID_OPERATIONS = new Set([
  "projectExplanation",
  "projectCoaching",
  "projectReflection",
  "skillExplanation",
  "roadmapExplanation",
]);

export async function POST(request: NextRequest) {
  try {
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return NextResponse.json({ error: { code: "invalid_request", message: "Invalid JSON" } }, { status: 400 });
    }

    const rec = body as Record<string, unknown>;
    const operation = rec.operation as string | undefined;
    const context = rec.context as Record<string, unknown> | undefined;

    if (!operation || typeof operation !== "string" || !VALID_OPERATIONS.has(operation)) {
      return NextResponse.json({ error: { code: "invalid_request", message: "Invalid operation" } }, { status: 400 });
    }
    if (!context || typeof context !== "object") {
      return NextResponse.json({ error: { code: "invalid_request", message: "context required" } }, { status: 400 });
    }

    let result: unknown;
    switch (operation) {
      case "projectExplanation":
        result = await generateProjectExplanation(context as never);
        break;
      case "projectCoaching":
        result = await generateProjectCoaching(context as never);
        break;
      case "projectReflection":
        result = await generateProjectReflection(context as never);
        break;
      case "skillExplanation":
        result = await generateSkillExplanation(context as never);
        break;
      case "roadmapExplanation":
        result = await generateRoadmapExplanation(context as never);
        break;
      default:
        return NextResponse.json({ error: { code: "invalid_request", message: "Unknown operation" } }, { status: 400 });
    }

    return NextResponse.json({ operation, data: (result as { data: unknown }).data, model: (result as { model: string }).model, provider: (result as { provider: string }).provider }, { status: 200 });
  } catch (e: unknown) {
    const err = e as { code?: string; message?: string };
    const code = err?.code ?? "unknown";
    const statusMap: Record<string, number> = {
      invalid_request: 400,
      insufficient_context: 422,
      invalid_ai_response: 502,
      ai_generation_failed: 502,
    };
    const status = statusMap[code] ?? 500;
    const safeMessage = code === "ai_generation_failed" || code === "invalid_ai_response" ? "Could not generate personalization" : err?.message ?? "Internal error";
    console.error(`[POST /api/ai/personalization] error: ${code}`);
    return NextResponse.json({ error: { code, message: safeMessage } }, { status });
  }
}
