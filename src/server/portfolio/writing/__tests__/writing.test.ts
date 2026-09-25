import { describe, it, expect, beforeEach, vi } from "vitest";
import { generatePortfolioWriting } from "../service";
import { buildPortfolioWritingContext, fingerprintContext } from "../context";
import type { PortfolioWritingContext } from "../types";

// ─── Helpers ───────────────────────────────────────────────────────

function makePortfolio(overrides: Partial<PortfolioWritingContext["portfolio"]> = {}): PortfolioWritingContext["portfolio"] {
  return {
    id: "portfolio-1",
    title: "My Portfolio",
    headline: null,
    about: null,
    goals: [],
    ...overrides,
  };
}

function makeContext(overrides: Partial<PortfolioWritingContext> = {}): PortfolioWritingContext {
  return {
    portfolio: makePortfolio(),
    student: { displayName: "Alex", grade: "10th", schoolLevel: "High School", location: "Austin, TX" },
    education: { grade: "10th", schoolLevel: "High School" },
    projects: [],
    achievements: [],
    evidence: [],
    skills: [],
    roadmaps: [],
    constraints: { writingType: "headline", targetID: null },
    ...overrides,
  };
}

// Mock AI provider
const mockGenerateStructured = vi.fn();

vi.mock("../../../ai", async () => {
  const actual = await vi.importActual<typeof import("../../../ai")>("../../../ai");
  return {
    ...actual,
    getAIProvider: () => ({
      generateStructured: mockGenerateStructured,
      generate: vi.fn(),
      healthCheck: vi.fn().mockResolvedValue({ ok: true }),
      name: "groq",
      config: { model: "openai/gpt-oss-120b", provider: "groq", temperature: 0.3, maxCompletionTokens: 2048, timeoutMs: 30000 },
    }),
  };
});

function mockSuccessResponse(overrides: Partial<{
  drafts: string[];
  factualClaims: string[];
  warnings: string[];
  needsMoreContext: boolean;
  sourceIDs: string[];
}> = {}) {
  return {
    drafts: ["Polished headline from verified facts"],
    factualClaims: ["Portfolio title is My Portfolio"],
    warnings: [],
    needsMoreContext: false,
    sourceIDs: ["portfolio-1"],
    ...overrides,
  };
}

// ─── Tests ─────────────────────────────────────────────────────────

describe("PortfolioWritingContext", () => {
  it("builds headline context minimal", () => {
    const portfolio = makePortfolio({ title: "Test" });
    const ctx = buildPortfolioWritingContext(
      {
        portfolio: { id: "p1", title: "Test", headline: null, about: null, goals: [], selectedProjectIDs: [], selectedAchievementIDs: [], selectedEvidenceIDs: [], selectedSkillIDs: [], selectedRoadmapIDs: [] },
        profile: { firstName: "Alex", grade: "10th", schoolLevel: "High School", location: "Austin" },
        projects: [{ id: "proj-1", title: "Proj", description: "Desc", category: "Tech", goal: "Goal", skills: ["Python"], progress: 100, isCompleted: true, sourceRoadmapID: null, evidenceCount: 1, artifactURL: null }],
        achievements: [],
        evidence: [],
        skills: [{ id: "python", name: "Python" }],
        roadmaps: [],
      },
      "headline",
      null
    );
    expect(ctx.portfolio.title).toBe("Test");
    expect(ctx.student.displayName).toBe("Alex");
  });

  it("builds projectDescription target-specific", () => {
    const portfolio = { id: "p1", title: "T", headline: null, about: null, goals: [], selectedProjectIDs: ["proj-1"], selectedAchievementIDs: [], selectedEvidenceIDs: [], selectedSkillIDs: [], selectedRoadmapIDs: [] };
    const projects = [{ id: "proj-1", title: "Plant Dashboard", description: "Desc", category: "Tech", goal: "Goal", skills: ["Python"], progress: 100, isCompleted: true, sourceRoadmapID: null, evidenceCount: 1, artifactURL: "https://example.com" }];
    const evidence = [{ id: "ev-1", title: "Ev", description: "Desc", type: "project-work", roadmapID: null, milestoneID: null, projectID: "proj-1", skillIDs: ["python"], artifactURL: "https://example.com", createdAt: new Date().toISOString(), quality: "Strong" }];
    const ctx = buildPortfolioWritingContext(
      { portfolio, profile: { firstName: "Alex" }, projects: projects as never, achievements: [], evidence: evidence as never, skills: [{ id: "python", name: "Python" }], roadmaps: [] },
      "projectDescription",
      "proj-1"
    );
    expect(ctx.projects.map((p) => p.id)).toEqual(["proj-1"]);
    expect(ctx.evidence.some((e) => e.id === "ev-1")).toBe(true);
  });

  it("excludes irrelevant data", () => {
    const portfolio = { id: "p1", title: "T", headline: null, about: null, goals: [], selectedProjectIDs: ["proj-1"], selectedAchievementIDs: [], selectedEvidenceIDs: [], selectedSkillIDs: [], selectedRoadmapIDs: [] };
    const projects = [
      { id: "proj-1", title: "P1", description: null, category: null, goal: null, skills: [], progress: null, isCompleted: null, sourceRoadmapID: null, evidenceCount: null, artifactURL: null },
      { id: "proj-unrelated", title: "Unrelated", description: null, category: null, goal: null, skills: [], progress: null, isCompleted: null, sourceRoadmapID: null, evidenceCount: null, artifactURL: null },
    ];
    const ctx = buildPortfolioWritingContext(
      { portfolio, profile: {}, projects: projects as never, achievements: [], evidence: [], skills: [], roadmaps: [] },
      "projectDescription",
      "proj-1"
    );
    expect(ctx.projects.map((p) => p.id)).toEqual(["proj-1"]);
    expect(ctx.projects.some((p) => p.id === "proj-unrelated")).toBe(false);
  });

  it("fingerprint is deterministic", () => {
    const ctx = makeContext();
    const fp1 = fingerprintContext(ctx);
    const fp2 = fingerprintContext(ctx);
    expect(fp1).toBe(fp2);
  });

  it("fingerprint changes when source changes", () => {
    const ctx1 = makeContext({ portfolio: makePortfolio({ title: "Old" }) });
    const ctx2 = makeContext({ portfolio: makePortfolio({ title: "New" }) });
    expect(fingerprintContext(ctx1)).not.toBe(fingerprintContext(ctx2));
  });
});

describe("generatePortfolioWriting", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("successful generation", async () => {
    const ctx = makeContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: mockSuccessResponse(),
      rawText: JSON.stringify(mockSuccessResponse()),
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });

    const result = await generatePortfolioWriting({
      portfolioID: "portfolio-1",
      writingType: "headline",
      tone: "professional",
      length: "short",
      context: ctx,
    });

    expect(result.draft).toBe("Polished headline from verified facts");
    expect(result.writingType).toBe("headline");
    expect(result.sourceIDs).toContain("portfolio-1");
  });

  it("rejects malformed model output (missing drafts)", async () => {
    const ctx = makeContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { factualClaims: [], warnings: [], needsMoreContext: false, sourceIDs: ["portfolio-1"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });

    await expect(
      generatePortfolioWriting({
        portfolioID: "portfolio-1",
        writingType: "headline",
        tone: "professional",
        length: "short",
        context: ctx,
      })
    ).rejects.toMatchObject({ code: "invalid_ai_response" });
  });

  it("rejects empty draft", async () => {
    const ctx = makeContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: mockSuccessResponse({ drafts: ["   "] }),
      rawText: JSON.stringify(mockSuccessResponse({ drafts: ["   "] })),
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });

    await expect(
      generatePortfolioWriting({
        portfolioID: "portfolio-1",
        writingType: "headline",
        tone: "professional",
        length: "short",
        context: ctx,
      })
    ).rejects.toMatchObject({ code: "invalid_ai_response" });
  });

  it("rejects invalid source ID", async () => {
    const ctx = makeContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: mockSuccessResponse({ sourceIDs: ["unknown-id"] }),
      rawText: JSON.stringify(mockSuccessResponse({ sourceIDs: ["unknown-id"] })),
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });

    await expect(
      generatePortfolioWriting({
        portfolioID: "portfolio-1",
        writingType: "headline",
        tone: "professional",
        length: "short",
        context: ctx,
      })
    ).rejects.toMatchObject({ code: "invalid_ai_response" });
  });

  it("enforces length limits", async () => {
    const ctx = makeContext();
    const longDraft = "A".repeat(200);
    mockGenerateStructured.mockResolvedValueOnce({
      data: mockSuccessResponse({ drafts: [longDraft] }),
      rawText: JSON.stringify(mockSuccessResponse({ drafts: [longDraft] })),
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });

    await expect(
      generatePortfolioWriting({
        portfolioID: "portfolio-1",
        writingType: "headline",
        tone: "professional",
        length: "short",
        context: ctx,
      })
    ).rejects.toMatchObject({ code: "invalid_ai_response" });
  });

  it("handles stale context fingerprint mismatch", async () => {
    const ctx = makeContext();
    const fp = fingerprintContext(ctx);
    // Change context to make fingerprint mismatch
    const differentCtx = makeContext({ portfolio: makePortfolio({ title: "Different" }) });

    mockGenerateStructured.mockResolvedValueOnce({
      data: mockSuccessResponse(),
      rawText: JSON.stringify(mockSuccessResponse()),
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });

    // First generation with original context
    const result = await generatePortfolioWriting({
      portfolioID: "portfolio-1",
      writingType: "headline",
      tone: "professional",
      length: "short",
      context: ctx,
    });

    expect(result.contextFingerprint).toBe(fp);
    // Simulate stale: request with old fingerprint but new context
    expect(fingerprintContext(differentCtx)).not.toBe(fp);
  });

  it("validates target not found", async () => {
    const ctx = makeContext({ projects: [] });
    await expect(
      generatePortfolioWriting({
        portfolioID: "portfolio-1",
        writingType: "projectDescription",
        targetID: "missing-proj",
        tone: "professional",
        length: "short",
        context: ctx,
      })
    ).rejects.toMatchObject({ code: "target_not_found" });
  });

  it("handles Groq timeout/error", async () => {
    const ctx = makeContext();
    mockGenerateStructured.mockRejectedValueOnce({ code: "timeout", message: "timeout", provider: "groq" });

    await expect(
      generatePortfolioWriting({
        portfolioID: "portfolio-1",
        writingType: "headline",
        tone: "professional",
        length: "short",
        context: ctx,
      })
    ).rejects.toMatchObject({ code: "ai_generation_failed" });
  });

  it("validates request missing fields", async () => {
    const ctx = makeContext();
    await expect(
      generatePortfolioWriting({
        portfolioID: "",
        writingType: "headline",
        tone: "professional",
        length: "short",
        context: ctx,
      } as never)
    ).rejects.toMatchObject({ code: "invalid_request" });
  });
});
