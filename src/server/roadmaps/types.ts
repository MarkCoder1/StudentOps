// Roadmap Personalization Types — Phase 6.3
// Structured AI recommendation of which existing roadmaps fit a student.

/** A single roadmap recommendation from AI. */
export interface PersonalizedRoadmapRecommendation {
  /** Must match an existing roadmap ID from the supplied catalog. */
  roadmapId: string;
  /** Fit score 0–100 indicating how strongly this roadmap matches the student. */
  fitScore: number;
  /** Concise, specific reason referencing student facts. */
  reason: string;
}

/** Full AI response for personalized roadmap recommendations. */
export interface PersonalizedRoadmapResponse {
  recommendations: PersonalizedRoadmapRecommendation[];
}

/** Compact student data sent from iOS for roadmap personalization. */
export interface RoadmapStudentContext {
  firstName?: string;
  age?: string;
  schoolLevel?: string;
  grade?: string;
  interests: string[];
  skills: string[];
  careers: string[];
  fields: string[];
  goals: string[];
  projects: Array<{ title: string; category: string; skills: string[] }>;
  achievements: Array<{ title: string; category: string }>;
  completedRoadmapCount: number;
  activeRoadmapCount: number;
}

/** Compact roadmap data sent from iOS for AI ranking. */
export interface RoadmapCatalogItem {
  id: string;
  title: string;
  goal: string;
  category: string;
  description: string;
  milestoneCount: number;
  completedMilestones: number;
  relevantInterests: string[];
  relevantSkills: string[];
  relevantCareers: string[];
  relevantFields: string[];
  matchScore: number;
}

/** JSON Schema for Groq structured output. */
export const ROADMAP_RECOMMENDATION_SCHEMA = {
  type: "object",
  properties: {
    recommendations: {
      type: "array",
      items: {
        type: "object",
        properties: {
          roadmapId: { type: "string" },
          fitScore: { type: "number" },
          reason: { type: "string" },
        },
        required: ["roadmapId", "fitScore", "reason"],
        additionalProperties: false,
      },
    },
  },
  required: ["recommendations"],
  additionalProperties: false,
} as const;
