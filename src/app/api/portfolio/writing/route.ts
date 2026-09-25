// POST /api/portfolio/writing
// Generates AI-powered portfolio wording from verified canonical context.
// Server-only — GROQ_API_KEY never leaves this process.

import { NextRequest, NextResponse } from "next/server";
import { generatePortfolioWriting } from "@/server/portfolio/writing/service";
import type { PortfolioWritingRequest } from "@/server/portfolio/writing/types";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    let body: PortfolioWritingRequest;
    try {
      body = await request.json();
    } catch {
      return NextResponse.json(
        { error: { code: "invalid_request", message: "Invalid request body" } },
        { status: 400 }
      );
    }

    // Basic validation: require portfolioID, writingType, tone, length, context
    if (!body.portfolioID || typeof body.portfolioID !== "string" || !body.portfolioID.trim()) {
      return NextResponse.json(
        { error: { code: "invalid_request", message: "portfolioID is required" } },
        { status: 400 }
      );
    }
    if (!body.writingType || typeof body.writingType !== "string") {
      return NextResponse.json(
        { error: { code: "invalid_request", message: "writingType is required" } },
        { status: 400 }
      );
    }
    if (!body.tone || typeof body.tone !== "string") {
      return NextResponse.json(
        { error: { code: "invalid_request", message: "tone is required" } },
        { status: 400 }
      );
    }
    if (!body.length || typeof body.length !== "string") {
      return NextResponse.json(
        { error: { code: "invalid_request", message: "length is required" } },
        { status: 400 }
      );
    }
    if (!body.context || typeof body.context !== "object") {
      return NextResponse.json(
        { error: { code: "invalid_request", message: "context is required" } },
        { status: 400 }
      );
    }

    // Generate writing
    const result = await generatePortfolioWriting(body);

    return NextResponse.json(result, { status: 200 });
  } catch (e: unknown) {
    const err = e as { code?: string; message?: string };
    const code = err?.code ?? "unknown";

    // Map to HTTP status
    const statusMap: Record<string, number> = {
      portfolio_not_found: 404,
      target_not_found: 404,
      target_not_selected: 400,
      integrity_error: 422,
      insufficient_context: 422,
      stale_context: 409,
      invalid_request: 400,
      ai_generation_failed: 502,
      invalid_ai_response: 502,
    };
    const status = statusMap[code] ?? 500;

    // Never expose internal details or API keys
    const safeMessage =
      code === "ai_generation_failed" || code === "invalid_ai_response"
        ? "Could not generate writing"
        : err?.message ?? "Internal server error";

    // Log server-side (no secrets)
    console.error(`[POST /api/portfolio/writing] error: ${code}`);

    return NextResponse.json(
      { error: { code, message: safeMessage } },
      { status }
    );
  }
}
