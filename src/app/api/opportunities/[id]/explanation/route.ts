// POST /api/opportunities/[id]/explanation
// Generates an AI explanation for why an opportunity fits a student.
// Server-only — GROQ_API_KEY never leaves this process.

import { NextRequest, NextResponse } from "next/server";
import { getOpportunityService } from "@/server/opportunities/service";
import { generateExplanation } from "@/server/opportunities/explanation/service";
import type { StudentProfileForPersonalization } from "@/server/opportunities/personalization/types";

export const dynamic = "force-dynamic";

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const decodedId = decodeURIComponent(id);

    if (!decodedId || decodedId.trim() === "") {
      return NextResponse.json(
        { error: { code: "INVALID_ID", message: "Invalid opportunity id" } },
        { status: 400 }
      );
    }

    // Parse request body — profile is required
    let body: { profile?: StudentProfileForPersonalization };
    try {
      body = await request.json();
    } catch {
      return NextResponse.json(
        { error: { code: "INVALID_BODY", message: "Invalid request body" } },
        { status: 400 }
      );
    }

    const profile: StudentProfileForPersonalization = body.profile ?? {};

    // Load opportunity from database
    const service = getOpportunityService();
    const opportunity = service.getOpportunityById(decodedId);

    if (!opportunity) {
      return NextResponse.json(
        { error: { code: "OPPORTUNITY_NOT_FOUND", message: "Opportunity not found" } },
        { status: 404 }
      );
    }

    // Generate AI explanation
    const result = await generateExplanation(opportunity, profile);

    return NextResponse.json(result, { status: 200 });
  } catch (e: unknown) {
    // Normalize AI errors — never expose API keys or internal details
    const message = e instanceof Error ? e.message : "Unknown error";

    // Check for AI-specific errors
    if (typeof e === "object" && e !== null && "code" in e) {
      const aiErr = e as { code: string; message: string };
      const statusCode =
        aiErr.code === "missing_api_key" ? 503 :
        aiErr.code === "timeout" ? 504 :
        aiErr.code === "rate_limit" ? 429 : 500;

      console.error("[POST /api/opportunities/[id]/explanation] AI error:", aiErr.code);
      return NextResponse.json(
        { error: { code: "EXPLANATION_FAILED", message: "Could not generate explanation" } },
        { status: statusCode }
      );
    }

    const statusCode = 500;
    console.error("[POST /api/opportunities/[id]/explanation] internal error:", message);
    return NextResponse.json(
      { error: { code: "INTERNAL_ERROR", message: "Internal server error" } },
      { status: statusCode }
    );
  }
}
