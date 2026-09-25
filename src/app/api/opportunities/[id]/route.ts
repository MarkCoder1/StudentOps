import { NextRequest, NextResponse } from "next/server";
import { getOpportunityService } from "@/server/opportunities/service";

export const dynamic = "force-dynamic";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    // Next.js decodes URL param, but we need to handle encoded colon etc.
    // params.id is already decoded, e.g., "studentsuite:abc123"
    const decodedId = decodeURIComponent(id);

    if (!decodedId || decodedId.trim() === "") {
      return NextResponse.json(
        { error: { code: "INVALID_ID", message: "Invalid id" } },
        { status: 400 }
      );
    }

    const service = getOpportunityService();
    const opp = service.getOpportunityById(decodedId);

    if (!opp) {
      return NextResponse.json(
        { error: { code: "OPPORTUNITY_NOT_FOUND", message: "Opportunity not found" } },
        { status: 404 }
      );
    }

    return NextResponse.json({ data: opp }, { status: 200 });
  } catch (e: any) {
    const statusCode = e.statusCode ?? 500;
    const code = e.code ?? (statusCode === 400 ? "BAD_REQUEST" : "INTERNAL_ERROR");
    const message = statusCode === 500 ? "Internal server error" : e.message || "Bad request";
    if (statusCode === 500) {
      console.error("[GET /api/opportunities/[id]] internal error:", e);
    }
    return NextResponse.json({ error: { code, message } }, { status: statusCode });
  }
}
