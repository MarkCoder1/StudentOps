// Roadmap Personalization Service — Phase 6.3
// Validates AI output, enforces deterministic guardrails.

import { getAIProvider } from "@/server/ai";
import { buildRoadmapPrompt } from "./prompt";
import {
  ROADMAP_RECOMMENDATION_SCHEMA,
  type PersonalizedRoadmapRecommendation,
  type PersonalizedRoadmapResponse,
  type RoadmapStudentContext,
  type RoadmapCatalogItem,
} from "./types";

interface PersonalizeArgs {
  student: RoadmapStudentContext;
  roadmaps: RoadmapCatalogItem[];
}

/** Main entry point. Calls AI, validates, returns safe results. */
export async function personalizeRoadmaps(
  args: PersonalizeArgs
): Promise<PersonalizedRoadmapResponse> {
  const { student, roadmaps } = args;
  const validIds = new Set(roadmaps.map((r) => r.id));

  if (roadmaps.length === 0) {
    return { recommendations: [] };
  }

  const provider = getAIProvider();
  const { system, user } = buildRoadmapPrompt({ student, roadmaps });

  const result = await provider.generateStructured<PersonalizedRoadmapResponse>({
    system,
    user,
    reasoningEffort: "low",
    outputSchema: {
      name: "roadmap_recommendations",
      description: "Ranked recommendations of existing roadmaps for this student",
      schema: ROADMAP_RECOMMENDATION_SCHEMA,
    },
  });

  return validateAndNormalize(result.data, validIds);
}

/** Validate and normalize raw AI output into safe, deterministic results. */
export function validateAndNormalize(
  raw: unknown,
  validIds: Set<string>
): PersonalizedRoadmapResponse {
  if (!raw || typeof raw !== "object" || !Array.isArray((raw as PersonalizedRoadmapResponse).recommendations)) {
    return { recommendations: [] };
  }

  const input = raw as PersonalizedRoadmapResponse;
  const seen = new Set<string>();
  const recommendations: PersonalizedRoadmapRecommendation[] = [];

  for (const rec of input.recommendations) {
    if (!rec || typeof rec !== "object") continue;

    const roadmapId = typeof rec.roadmapId === "string" ? rec.roadmapId.trim() : "";
    if (!roadmapId || !validIds.has(roadmapId)) continue;
    if (seen.has(roadmapId)) continue;
    seen.add(roadmapId);

    const fitScore = typeof rec.fitScore === "number"
      ? Math.min(Math.max(Math.round(rec.fitScore), 0), 100)
      : 50;

    const reason = typeof rec.reason === "string" && rec.reason.trim().length > 0
      ? rec.reason.trim()
      : `Good fit based on your profile.`;

    recommendations.push({ roadmapId, fitScore, reason });
  }

  recommendations.sort((a, b) => b.fitScore - a.fitScore);

  return { recommendations };
}
