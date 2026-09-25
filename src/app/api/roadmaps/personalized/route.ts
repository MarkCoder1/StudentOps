// POST /api/roadmaps/personalized
// Uses AI to rank and explain existing roadmaps for a student.
// Server-only — GROQ_API_KEY never leaves this process.

import { NextRequest, NextResponse } from "next/server";
import { personalizeRoadmaps } from "@/server/roadmaps/service";
import type {
  RoadmapStudentContext,
  RoadmapCatalogItem,
} from "@/server/roadmaps/types";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    let body: { student?: RoadmapStudentContext; roadmaps?: RoadmapCatalogItem[] };
    try {
      body = await request.json();
    } catch {
      return NextResponse.json(
        { error: { code: "INVALID_BODY", message: "Invalid request body" } },
        { status: 400 }
      );
    }

    const { student, roadmaps } = body;

    if (!student || !Array.isArray(student.interests)) {
      return NextResponse.json(
        { error: { code: "INVALID_STUDENT", message: "Invalid student data" } },
        { status: 400 }
      );
    }

    if (!roadmaps || !Array.isArray(roadmaps) || roadmaps.length === 0) {
      return NextResponse.json(
        { error: { code: "INVALID_ROADMAPS", message: "Invalid or empty roadmaps data" } },
        { status: 400 }
      );
    }

    const result = await personalizeRoadmaps({ student, roadmaps });
    return NextResponse.json(result, { status: 200 });
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : "Unknown error";

    if (typeof e === "object" && e !== null && "code" in e) {
      const aiErr = e as { code: string; message: string };
      const statusCode =
        aiErr.code === "missing_api_key" ? 503 :
        aiErr.code === "timeout" ? 504 :
        aiErr.code === "rate_limit" ? 429 : 500;

      console.error("[POST /api/roadmaps/personalized] AI error:", aiErr.code);
      return NextResponse.json(
        { error: { code: "PERSONALIZATION_FAILED", message: "Could not generate recommendations" } },
        { status: statusCode }
      );
    }

    console.error("[POST /api/roadmaps/personalized] internal error:", message);
    return NextResponse.json(
      { error: { code: "INTERNAL_ERROR", message: "Internal server error" } },
      { status: 500 }
    );
  }
}
