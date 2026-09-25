import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { GroqProvider, validateSchema, buildError } from "../groq";
import { getAIProvider, createAIProvider, resetAIProvider } from "../index";
import {
  buildStudentContext,
  buildOpportunityContext,
  buildEngineResult,
  buildStudentOpportunityContext,
  buildBatchContext,
} from "../context";
import type { Opportunity } from "../../opportunities/models/opportunity";
import type { PersonalizedOpportunity } from "../../opportunities/personalization/types";

// ─── Fixtures ────────────────────────────────────────────────────

function makeOpportunity(overrides: Partial<Opportunity> = {}): Opportunity {
  return {
    id: "test:1",
    source: "studentSuite",
    externalId: "1",
    title: "Test Opportunity",
    description: "A test opportunity for AI foundation.",
    organization: "Test Org",
    officialUrl: "https://example.com",
    applicationUrl: null,
    sourceUrl: null,
    category: "competition",
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

function makePersonalized(overrides: Partial<PersonalizedOpportunity> = {}): PersonalizedOpportunity {
  const opp = makeOpportunity();
  return {
    opportunity: opp,
    eligibility: { status: "unknown", reasons: [] },
    match: { score: 60, label: "Strong match", reasons: ["Matches your interest in Computer Science"], signals: [] },
    freshness: { status: "active", urgency: "none", daysUntilDeadline: 90, deadline: "2026-12-31", reason: "Active opportunity" },
    rankScore: 45,
    badges: ["Competition", "Free"],
    ...overrides,
  };
}

// ─── Provider Configuration ──────────────────────────────────────

describe("GroqProvider configuration", () => {
  it("has correct default config", () => {
    const provider = new GroqProvider();
    expect(provider.name).toBe("groq");
    expect(provider.config.model).toBe("openai/gpt-oss-120b");
    expect(provider.config.temperature).toBe(0.3);
    expect(provider.config.maxCompletionTokens).toBe(2048);
    expect(provider.config.timeoutMs).toBe(30_000);
  });

  it("allows config overrides", () => {
    const provider = new GroqProvider({ temperature: 0.7, model: "custom-model" });
    expect(provider.config.temperature).toBe(0.7);
    expect(provider.config.model).toBe("custom-model");
    // Non-overridden values remain default
    expect(provider.config.provider).toBe("groq");
    expect(provider.config.timeoutMs).toBe(30_000);
  });
});

// ─── Missing API Key Handling ────────────────────────────────────

describe("GroqProvider missing API key", () => {
  const originalEnv = process.env.GROQ_API_KEY;

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.GROQ_API_KEY;
    } else {
      process.env.GROQ_API_KEY = originalEnv;
    }
  });

  it("healthCheck returns error when API key is missing", async () => {
    delete process.env.GROQ_API_KEY;
    const provider = new GroqProvider();
    const result = await provider.healthCheck();
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe("missing_api_key");
      expect(result.error.provider).toBe("groq");
    }
  });

  it("generate throws when API key is missing", async () => {
    delete process.env.GROQ_API_KEY;
    const provider = new GroqProvider();
    await expect(
      provider.generate({ system: "test", user: "test" })
    ).rejects.toMatchObject({ code: "missing_api_key" });
  });

  it("generateStructured throws when API key is missing", async () => {
    delete process.env.GROQ_API_KEY;
    const provider = new GroqProvider();
    await expect(
      provider.generateStructured({
        system: "test",
        user: "test",
        outputSchema: { name: "test", schema: { type: "object", properties: {} } },
      })
    ).rejects.toMatchObject({ code: "missing_api_key" });
  });
});

// ─── Provider Resolution ─────────────────────────────────────────

describe("Provider resolution", () => {
  beforeEach(() => {
    resetAIProvider();
  });

  it("getAIProvider returns a GroqProvider", () => {
    const provider = getAIProvider();
    expect(provider).toBeInstanceOf(GroqProvider);
    expect(provider.name).toBe("groq");
  });

  it("getAIProvider returns the same instance (singleton)", () => {
    const a = getAIProvider();
    const b = getAIProvider();
    expect(a).toBe(b);
  });

  it("createAIProvider returns a new instance", () => {
    const a = createAIProvider();
    const b = createAIProvider();
    expect(a).toBeInstanceOf(GroqProvider);
    expect(a).not.toBe(b);
  });

  it("resetAIProvider clears the singleton", () => {
    const a = getAIProvider();
    resetAIProvider();
    const b = getAIProvider();
    expect(a).not.toBe(b);
  });
});

// ─── Schema Validation ───────────────────────────────────────────

describe("Schema validation", () => {
  it("accepts valid object matching schema", () => {
    const schema = {
      type: "object",
      properties: {
        name: { type: "string" },
        score: { type: "number" },
        active: { type: "boolean" },
      },
      required: ["name", "score"],
    };
    const result = validateSchema({ name: "test", score: 42, active: true }, schema);
    expect(result.ok).toBe(true);
  });

  it("rejects non-object data", () => {
    const result = validateSchema("not an object", { type: "object", properties: {} });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error).toContain("Expected an object");
    }
  });

  it("rejects missing required fields", () => {
    const schema = {
      type: "object",
      properties: { name: { type: "string" }, score: { type: "number" } },
      required: ["name", "score"],
    };
    const result = validateSchema({ name: "test" }, schema);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error).toContain("Missing required field: score");
    }
  });

  it("rejects wrong field types", () => {
    const schema = {
      type: "object",
      properties: { count: { type: "number" } },
    };
    const result = validateSchema({ count: "not a number" }, schema);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error).toContain('"count"');
      expect(result.error).toContain("expected type number");
    }
  });

  it("accepts optional fields as undefined", () => {
    const schema = {
      type: "object",
      properties: { name: { type: "string" }, extra: { type: "string" } },
      required: ["name"],
    };
    const result = validateSchema({ name: "test" }, schema);
    expect(result.ok).toBe(true);
  });

  it("accepts null values when type is null", () => {
    const schema = {
      type: "object",
      properties: { value: { type: "null" } },
    };
    const result = validateSchema({ value: null }, schema);
    expect(result.ok).toBe(true);
  });

  it("accepts arrays when type is array", () => {
    const schema = {
      type: "object",
      properties: { items: { type: "array" } },
    };
    const result = validateSchema({ items: [1, 2, 3] }, schema);
    expect(result.ok).toBe(true);
  });

  it("rejects non-array when type is array", () => {
    const schema = {
      type: "object",
      properties: { items: { type: "array" } },
    };
    const result = validateSchema({ items: "not an array" }, schema);
    expect(result.ok).toBe(false);
  });
});

// ─── Error Construction ──────────────────────────────────────────

describe("AIError construction", () => {
  it("buildError creates proper error object", () => {
    const err = buildError("timeout", "groq", "Request timed out");
    expect(err.code).toBe("timeout");
    expect(err.provider).toBe("groq");
    expect(err.message).toBe("Request timed out");
  });

  it("error does not contain API keys", () => {
    const err = buildError("provider_error", "groq", "Something went wrong");
    const errorStr = JSON.stringify(err);
    expect(errorStr).not.toContain("gsk_");
    expect(errorStr).not.toContain("sk-");
    expect(errorStr).not.toContain("key");
  });
});

// ─── Context Builder ─────────────────────────────────────────────

describe("buildStudentContext", () => {
  it("builds student context from profile", () => {
    const ctx = buildStudentContext({
      grade: "11th",
      schoolLevel: "High School",
      interests: ["Computer Science", "AI"],
      strengths: ["Python"],
      careers: ["Software Engineer"],
      fields: ["Computer Science"],
      milestones: ["Get research experience"],
      location: "Austin, TX",
    });
    expect(ctx.grade).toBe("11th");
    expect(ctx.schoolLevel).toBe("High School");
    expect(ctx.interests).toEqual(["Computer Science", "AI"]);
    expect(ctx.skills).toEqual(["Python"]);
    expect(ctx.careers).toEqual(["Software Engineer"]);
    expect(ctx.fields).toEqual(["Computer Science"]);
    expect(ctx.goals).toEqual(["Get research experience"]);
    expect(ctx.location).toBe("Austin, TX");
  });

  it("merges custom interests and skills", () => {
    const ctx = buildStudentContext({
      interests: ["CS"],
      customInterests: ["Art"],
      strengths: ["Python"],
      customSkills: ["Design"],
      skills: ["Java"],
    });
    expect(ctx.interests).toContain("CS");
    expect(ctx.interests).toContain("Art");
    expect(ctx.skills).toContain("Python");
    expect(ctx.skills).toContain("Design");
    expect(ctx.skills).toContain("Java");
  });

  it("deduplicates interests and skills", () => {
    const ctx = buildStudentContext({
      interests: ["AI", "CS", "AI"],
      strengths: ["Python", "Python"],
    });
    expect(ctx.interests).toEqual(["AI", "CS"]);
    expect(ctx.skills).toEqual(["Python"]);
  });

  it("handles empty/missing profile", () => {
    const ctx = buildStudentContext({});
    expect(ctx.interests).toEqual([]);
    expect(ctx.skills).toEqual([]);
    expect(ctx.careers).toEqual([]);
    expect(ctx.fields).toEqual([]);
    expect(ctx.goals).toEqual([]);
  });
});

describe("buildOpportunityContext", () => {
  it("builds compact opportunity context", () => {
    const opp = makeOpportunity({ title: "AI Hackathon", category: "hackathon" });
    const ctx = buildOpportunityContext(opp);
    expect(ctx.id).toBe("test:1");
    expect(ctx.title).toBe("AI Hackathon");
    expect(ctx.category).toBe("hackathon");
    expect(ctx.cost.isFree).toBe(true);
    expect(ctx.skills).toContain("Python");
  });

  it("truncates long descriptions", () => {
    const longDesc = "A".repeat(1000);
    const opp = makeOpportunity({ description: longDesc });
    const ctx = buildOpportunityContext(opp);
    expect(ctx.description).toHaveLength(500);
    expect(ctx.description).toMatch(/\.\.\.$/);
  });
});

describe("buildEngineResult", () => {
  it("builds engine result from personalized opportunity", () => {
    const p = makePersonalized();
    const result = buildEngineResult(p);
    expect(result.eligibility.status).toBe("unknown");
    expect(result.match.score).toBe(60);
    expect(result.match.label).toBe("Strong match");
    expect(result.freshness.status).toBe("active");
    expect(result.freshness.urgency).toBe("none");
    expect(result.rankScore).toBe(45);
  });
});

describe("buildStudentOpportunityContext", () => {
  it("builds full context for student + opportunity", () => {
    const profile = {
      grade: "11th",
      interests: ["CS"],
      careers: ["Engineer"],
    };
    const opp = makeOpportunity();
    const p = makePersonalized();
    const ctx = buildStudentOpportunityContext(profile, opp, p);
    expect(ctx.student.grade).toBe("11th");
    expect(ctx.opportunity.title).toBe("Test Opportunity");
    expect(ctx.engines.match.score).toBe(60);
  });
});

describe("buildBatchContext", () => {
  it("builds batch context from personalized list", () => {
    const profile = { interests: ["AI"], careers: ["Engineer"] };
    const items = [
      makePersonalized(),
      makePersonalized({ rankScore: 30 }),
      makePersonalized({ rankScore: 20 }),
    ];
    const ctx = buildBatchContext(profile, items);
    expect(ctx.student.interests).toEqual(["AI"]);
    expect(ctx.topOpportunities).toHaveLength(3);
    expect(ctx.engineResults["test:1"]).toBeDefined();
  });

  it("limits to top 10 opportunities", () => {
    const profile = {};
    const items = Array.from({ length: 20 }, (_, i) =>
      makePersonalized({
        rankScore: 100 - i,
        opportunity: makeOpportunity({
          id: `opp:${i}`,
          externalId: String(i),
          title: `Opportunity ${i}`,
        }),
      })
    );
    const ctx = buildBatchContext(profile, items);
    expect(ctx.topOpportunities).toHaveLength(10);
    expect(Object.keys(ctx.engineResults)).toHaveLength(10);
  });
});
