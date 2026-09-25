import { NextRequest, NextResponse } from "next/server";
import { getOpportunityService } from "@/server/opportunities/service";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);

    const limitRaw = searchParams.get("limit");
    const offsetRaw = searchParams.get("offset");
    const source = searchParams.get("source") ?? undefined;
    const category = searchParams.get("category") ?? undefined;
    const onlyActiveRaw = searchParams.get("onlyActive");

    // Parse limit/offset if present, keep as number or undefined
    let limit: number | undefined;
    let offset: number | undefined;
    let onlyActive: boolean | string | undefined;

    if (limitRaw !== null) {
      // Validate numeric string
      if (!/^-?\d+$/.test(limitRaw)) {
        return NextResponse.json(
          { error: { code: "INVALID_LIMIT", message: "Invalid limit: must be integer >= 1" } },
          { status: 400 }
        );
      }
      limit = parseInt(limitRaw, 10);
    }
    if (offsetRaw !== null) {
      if (!/^-?\d+$/.test(offsetRaw)) {
        return NextResponse.json(
          { error: { code: "INVALID_OFFSET", message: "Invalid offset: must be integer >= 0" } },
          { status: 400 }
        );
      }
      offset = parseInt(offsetRaw, 10);
    }
    if (onlyActiveRaw !== null) {
      // Accept true/false string, or boolean
      if (onlyActiveRaw === "true" || onlyActiveRaw === "false") {
        onlyActive = onlyActiveRaw;
      } else {
        return NextResponse.json(
          { error: { code: "INVALID_ONLYACTIVE", message: "Invalid onlyActive: must be true or false" } },
          { status: 400 }
        );
      }
    }

    const service = getOpportunityService();
    const result = service.getOpportunities({
      limit,
      offset,
      source: source ?? undefined,
      category: category ?? undefined,
      onlyActive: onlyActive as any,
      asOf: new Date(),
    });

    return NextResponse.json(result, { status: 200 });
  } catch (e: any) {
    // Handle validation errors thrown by service
    const statusCode = e.statusCode ?? 500;
    const code = e.code ?? (statusCode === 400 ? "BAD_REQUEST" : "INTERNAL_ERROR");
    const message = statusCode === 500 ? "Internal server error" : e.message || "Bad request";
    // Never expose stack traces or internal details for 500
    if (statusCode === 500) {
      console.error("[GET /api/opportunities] internal error:", e);
    }
    return NextResponse.json({ error: { code, message } }, { status: statusCode });
  }
}
