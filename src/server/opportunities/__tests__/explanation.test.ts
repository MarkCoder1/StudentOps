import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { validateSchema } from "../../ai/groq";
import { EXPLANATION_SCHEMA } from "../explanation/types";
import { buildExplanationPrompt } from "../explanation/prompt";
import type { AIStudentContext, AIOpportunityContext, AIEngineResult } from "../../ai/context";
import type { Opportunity } from "../models/opportunity";

// ─── Fixtures ────────────────────────────────────────────────────

function makeOpp(overrides: Partial<Opportunity> = {}): Opportunity {
  return {
    id: "test:1",
    source: "studentSuite",
    externalId: "1",
    title: "AI Hackathon 2026",
    description: "A hackathon focused on building AI projects.",
    organization: "TechOrg",
    officialUrl: "https://example.com",
    applicationUrl: null,
    sourceUrl: null,
    category: "hackathon",
    sourceCategory: null,
    subjects: ["Computer Science"],
    topics: ["AI", "Machine Learning"],
    skills: ["Python", "JavaScript"],
    deadline: "2026-12-31",
    startDate: null,
    endDate: null,
    location: { type: "online", city: null, state: null, country: null, online: true, latitude: null, longitude: null },
    cost: { amount: null, currency: null, isFree: true },
    benefits: { awardText: "$1,000 prize", awardAmount: 1000, awardCurrency: "USD", prizeText: null },
    eligibility: { minAge: null, maxAge: null, gradeMin: null, gradeMax: null, countries: null, geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null },
    provenance: { source: "studentSuite", externalId: "1", fetchedAt: "2026-09-13T00:00:00.000Z", sourceUpdatedAt: null },
    sourceMetadata: {},
    ...overrides,
  };
}

const STUDENT_CTX: AIStudentContext = {
  grade: "11th",
  schoolLevel: "High School",
  interests: ["Computer Science", "AI"],
  skills: ["Python", "JavaScript"],
  careers: ["Software Engineer"],
  fields: ["Computer Science"],
  goals: ["Get research experience"],
  location: "Austin, TX",
};

const OPPORTUNITY_CTX: AIOpportunityContext = {
  id: "test:1",
  title: "AI Hackathon 2026",
  description: "A hackathon focused on building AI projects.",
  organization: "TechOrg",
  category: "hackathon",
  deadline: "2026-12-31",
  officialUrl: "https://example.com",
  applicationUrl: null,
  cost: { isFree: true, amount: null },
  location: { type: "online", online: true },
  skills: ["Python", "JavaScript"],
  topics: ["AI", "Machine Learning"],
};

const ENGINE_RESULT: AIEngineResult = {
  eligibility: { status: "unknown", reasons: [] },
  match: { score: 75, label: "Strong match", reasons: ["Matches your interest in Computer Science"] },
  freshness: { status: "active", urgency: "none", daysUntilDeadline: 109 },
  rankScore: 55,
};

// ─── Schema Validation ───────────────────────────────────────────

describe("Explanation schema validation", () => {
  it("accepts valid explanation", () => {
    const data = {
      whyThisFits: "You like CS and this is a CS hackathon.",
      roadmapConnection: "Supports your software engineer goal.",
      nextStep: "Apply before the deadline.",
    };
    const result = validateSchema(data, EXPLANATION_SCHEMA);
    expect(result.ok).toBe(true);
  });

  it("rejects missing required field", () => {
    const data = {
      whyThisFits: "You like CS.",
      roadmapConnection: "Supports your goal.",
      // missing nextStep
    };
    const result = validateSchema(data, EXPLANATION_SCHEMA);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error).toContain("Missing required field: nextStep");
    }
  });

  it("rejects wrong field type", () => {
    const data = {
      whyThisFits: 42, // should be string
      roadmapConnection: "Supports your goal.",
      nextStep: "Apply.",
    };
    const result = validateSchema(data, EXPLANATION_SCHEMA);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error).toContain("expected type string");
    }
  });

  it("rejects non-object input", () => {
    const result = validateSchema("not an object", EXPLANATION_SCHEMA);
    expect(result.ok).toBe(false);
  });

  it("accepts explanation with extra fields", () => {
    const data = {
      whyThisFits: "You like CS.",
      roadmapConnection: "Supports your goal.",
      nextStep: "Apply.",
      extraField: "ignored",
    };
    const result = validateSchema(data, EXPLANATION_SCHEMA);
    expect(result.ok).toBe(true);
  });
});

// ─── Prompt Builder ──────────────────────────────────────────────

describe("buildExplanationPrompt", () => {
  it("returns system and user prompts", () => {
    const { system, user } = buildExplanationPrompt({
      student: STUDENT_CTX,
      opportunity: OPPORTUNITY_CTX,
      engines: ENGINE_RESULT,
    });
    expect(system).toBeTruthy();
    expect(user).toBeTruthy();
    expect(typeof system).toBe("string");
    expect(typeof user).toBe("string");
  });

  it("system prompt constrains AI to supplied facts", () => {
    const { system } = buildExplanationPrompt({
      student: STUDENT_CTX,
      opportunity: OPPORTUNITY_CTX,
      engines: ENGINE_RESULT,
    });
    expect(system).toContain("Use ONLY the supplied");
    expect(system).toContain("Do not invent");
    expect(system).toContain("structured JSON");
  });

  it("user prompt includes student profile", () => {
    const { user } = buildExplanationPrompt({
      student: STUDENT_CTX,
      opportunity: OPPORTUNITY_CTX,
      engines: ENGINE_RESULT,
    });
    expect(user).toContain("Computer Science");
    expect(user).toContain("Software Engineer");
    expect(user).toContain("11th");
    expect(user).toContain("Python");
  });

  it("user prompt includes opportunity details", () => {
    const { user } = buildExplanationPrompt({
      student: STUDENT_CTX,
      opportunity: OPPORTUNITY_CTX,
      engines: ENGINE_RESULT,
    });
    expect(user).toContain("AI Hackathon 2026");
    expect(user).toContain("TechOrg");
    expect(user).toContain("hackathon");
    expect(user).toContain("Free");
    expect(user).toContain("Online");
  });

  it("user prompt includes deterministic engine results", () => {
    const { user } = buildExplanationPrompt({
      student: STUDENT_CTX,
      opportunity: OPPORTUNITY_CTX,
      engines: ENGINE_RESULT,
    });
    expect(user).toContain("unknown"); // eligibility status
    expect(user).toContain("75%"); // match score
    expect(user).toContain("Strong match"); // match label
    expect(user).toContain("active"); // freshness status
    expect(user).toContain("109"); // days until deadline
  });

  it("user prompt includes eligibility reasons", () => {
    const enginesWithReasons: AIEngineResult = {
      ...ENGINE_RESULT,
      eligibility: {
        status: "eligible",
        reasons: [{ dimension: "age", message: "You meet the age requirement" }],
      },
    };
    const { user } = buildExplanationPrompt({
      student: STUDENT_CTX,
      opportunity: OPPORTUNITY_CTX,
      engines: enginesWithReasons,
    });
    expect(user).toContain("age");
    expect(user).toContain("You meet the age requirement");
  });

  it("handles empty student profile gracefully", () => {
    const { user } = buildExplanationPrompt({
      student: { interests: [], skills: [], careers: [], fields: [], goals: [] },
      opportunity: OPPORTUNITY_CTX,
      engines: ENGINE_RESULT,
    });
    expect(user).toContain("No profile data available");
  });
});

// ─── Secret Safety ───────────────────────────────────────────────

describe("Explanation context security", () => {
  it("prompt does not expose GROQ_API_KEY", () => {
    const { system, user } = buildExplanationPrompt({
      student: STUDENT_CTX,
      opportunity: OPPORTUNITY_CTX,
      engines: ENGINE_RESULT,
    });
    const combined = system + user;
    expect(combined).not.toContain("gsk_");
    expect(combined).not.toContain("sk-");
    expect(combined).not.toContain("GROQ_API_KEY");
    expect(combined).not.toContain(process.env.GROQ_API_KEY ?? "NEVER_MATCHES");
  });

  it("prompt does not expose internal database IDs", () => {
    const { user } = buildExplanationPrompt({
      student: STUDENT_CTX,
      opportunity: OPPORTUNITY_CTX,
      engines: ENGINE_RESULT,
    });
    // Should not contain raw DB paths or internal tokens
    expect(user).not.toContain("node_modules");
    expect(user).not.toContain(".env");
  });
});

// ─── Existing Engines Unchanged ──────────────────────────────────

describe("Existing personalization engines unaffected", () => {
  it("personalizeOpportunities still works", async () => {
    const { personalizeOpportunities } = await import("../personalization/index");
    const opp = makeOpp();
    const feed = personalizeOpportunities([opp], {
      interests: ["Computer Science"],
      careers: ["Software Engineer"],
    });
    expect(feed.opportunities).toHaveLength(1);
    expect(feed.opportunities[0].match.score).toBeGreaterThanOrEqual(0);
    expect(feed.opportunities[0].eligibility.status).toBeTruthy();
    expect(feed.opportunities[0].freshness.status).toBeTruthy();
  });
});

// ─── Missing API Key Handling ────────────────────────────────────

describe("Explanation service — missing API key", () => {
  const originalEnv = process.env.GROQ_API_KEY;

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.GROQ_API_KEY;
    } else {
      process.env.GROQ_API_KEY = originalEnv;
    }
  });

  it("generateExplanation throws missing_api_key when GROQ_API_KEY is absent", async () => {
    delete process.env.GROQ_API_KEY;
    // Reset the provider singleton so it picks up the missing key
    const { resetAIProvider } = await import("../../ai/index");
    resetAIProvider();

    const { generateExplanation } = await import("../explanation/service");
    const opp = makeOpp();
    const profile = { interests: ["CS"] };

    await expect(generateExplanation(opp, profile)).rejects.toMatchObject({
      code: "missing_api_key",
    });
  });
});
