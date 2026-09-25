import { NextRequest, NextResponse } from "next/server";
import { getOpportunityService } from "@/server/opportunities/service";
import { personalizeOpportunities } from "@/server/opportunities/personalization";
import type { StudentProfileForPersonalization } from "@/server/opportunities/personalization/types";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const profile: StudentProfileForPersonalization = body.profile ?? {};

    // Fetch all active opportunities (no pagination — personalization needs full set)
    const service = getOpportunityService();
    const result = service.getOpportunities({
      limit: 500,
      offset: 0,
      onlyActive: true,
      asOf: new Date(),
    });

    // Run personalization
    const feed = personalizeOpportunities(result.data, profile, new Date());

    return NextResponse.json(feed, { status: 200 });
  } catch (e: any) {
    const statusCode = e.statusCode ?? 500;
    const code = e.code ?? (statusCode === 400 ? "BAD_REQUEST" : "INTERNAL_ERROR");
    const message = statusCode === 500 ? "Internal server error" : e.message || "Bad request";
    if (statusCode === 500) {
      console.error("[POST /api/opportunities/personalized] internal error:", e);
    }
    return NextResponse.json({ error: { code, message } }, { status: statusCode });
  }
}
