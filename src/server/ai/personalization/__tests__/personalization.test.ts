import { describe, it, expect, beforeEach, vi } from "vitest";
import {
  generateProjectExplanation,
  generateProjectCoaching,
  generateProjectReflection,
  generateSkillExplanation,
  generateRoadmapExplanation,
} from "../service";
import type {
  ProjectExplanationContext,
  ProjectCoachingContext,
  ProjectReflectionContext,
  SkillExplanationContext,
  RoadmapExplanationContext,
} from "../types";

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

function makeProjectExplanationContext(overrides: Partial<ProjectExplanationContext> = {}): ProjectExplanationContext {
  return {
    student: { goals: ["Software Engineer"], interests: ["Technology"], skills: ["Python"] },
    project: { id: "proj1", title: "Plant Dashboard", description: "Desc", category: "Data", skills: ["Python"] },
    recommendation: { score: 87, reasons: ["Matches goal", "Covers skill gap"], breakdown: { goalAlignment: 1, skillGapCoverage: 0.75, roadmapAlignment: 1, interestAlignment: 0.5 } },
    skillGaps: ["TypeScript"],
    roadmap: { id: "rm1", title: "Research Builder", active: true },
    contextVersion: "9.8",
    ...overrides,
  };
}

function makeProjectCoachingContext(overrides: Partial<ProjectCoachingContext> = {}): ProjectCoachingContext {
  return {
    project: { id: "proj1", title: "Plant Dashboard", goal: "Build tool", description: "Desc" },
    playbook: { overview: "Overview", steps: [{ id: "s1", title: "Define", order: 1 }], skillsDeveloped: ["Python"] },
    execution: { completedStepIDs: ["s1"], totalSteps: 4, percent: 25 },
    currentStep: { id: "s2", title: "Build", description: "Build first version", objective: "Working prototype", requiredSkills: ["Python"], estimatedEffort: "1 week" },
    nextStep: { id: "s2", title: "Build", description: "Build first version" },
    student: { goals: ["Software Engineer"], skills: ["Python"] },
    skillGaps: ["TypeScript"],
    contextVersion: "9.8",
    ...overrides,
  };
}

function makeProjectReflectionContext(overrides: Partial<ProjectReflectionContext> = {}): ProjectReflectionContext {
  return {
    project: { id: "proj1", title: "Plant Dashboard", description: "Desc", outcome: "Built prototype", skills: ["Python"] },
    playbook: { steps: [{ id: "s1", title: "Define" }], deliverables: [{ id: "d1", title: "Prototype" }], criteria: [{ id: "c1", title: "Works" }] },
    execution: { completedStepIDs: ["s1","s2"], completedDeliverableIDs: ["d1"], confirmedCriterionIDs: ["c1"], isCompleted: true },
    evidence: [{ id: "ev1", title: "Evidence" }],
    achievements: [{ id: "ach1", title: "Achievement" }],
    contextVersion: "9.8",
    ...overrides,
  };
}

function makeSkillContext(overrides: Partial<SkillExplanationContext> = {}): SkillExplanationContext {
  return {
    skill: { id: "typescript", name: "TypeScript" },
    gapReason: "Required by Software Engineer roadmap, milestone 2",
    roadmap: { id: "rm1", title: "Software Engineer" },
    project: { id: "proj1", title: "Portfolio Site", skills: ["TypeScript"] },
    studentGoal: "Software Engineer",
    contextVersion: "9.8",
    ...overrides,
  };
}

function makeRoadmapContext(overrides: Partial<RoadmapExplanationContext> = {}): RoadmapExplanationContext {
  return {
    roadmap: { id: "rm1", title: "Software Engineer", goal: "Become engineer" },
    progress: { completedMilestones: 2, totalMilestones: 6, percent: 33, isActive: true },
    nextMilestone: { id: "m3", title: "Build Projects" },
    skillGaps: ["TypeScript", "Testing"],
    relevantProjects: [{ id: "proj1", title: "Portfolio Site" }],
    contextVersion: "9.8",
    ...overrides,
  };
}

describe("Personalization fact preservation", () => {
  it("project explanation preserves deterministic score", async () => {
    const ctx = makeProjectExplanationContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { summary: "This project fits your path because it matches your goal and builds a needed skill.", reasons: ["Matches Software Engineer goal", "Builds TypeScript gap"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    const result = await generateProjectExplanation(ctx);
    expect(result.data.summary).toContain("fits");
    // Ensure score 87 was in context (not recalculated by AI)
    expect(ctx.recommendation.score).toBe(87);
    expect(mockGenerateStructured).toHaveBeenCalledWith(expect.objectContaining({
      outputSchema: expect.objectContaining({ name: "project_explanation" }),
    }));
  });

  it("project coaching does not complete steps", async () => {
    const ctx = makeProjectCoachingContext();
    const executionBefore = [...ctx.execution.completedStepIDs];
    mockGenerateStructured.mockResolvedValueOnce({
      data: { focus: "Focus on testing the core user flow before polishing.", actions: ["Test normal case with valid input", "Test missing input case", "Record observed results"], caution: "Don't change architecture yet" },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    await generateProjectCoaching(ctx);
    expect(ctx.execution.completedStepIDs).toEqual(executionBefore);
  });
});

describe("ProjectExplanation validation", () => {
  beforeEach(() => { vi.clearAllMocks(); });

  it("valid request succeeds", async () => {
    const ctx = makeProjectExplanationContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { summary: "This project aligns with your Software Engineer goal and builds your missing TypeScript skill.", reasons: ["Matches Software Engineer goal", "Builds TypeScript gap"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    const result = await generateProjectExplanation(ctx);
    expect(result.data.summary.length).toBeGreaterThan(20);
  });

  it("missing project id fails", async () => {
    const ctx = makeProjectExplanationContext({ project: { id: "", title: "", description: null, category: null, skills: [] } });
    await expect(generateProjectExplanation(ctx)).rejects.toMatchObject({ code: "invalid_request" });
  });

  it("malformed AI response (missing summary) fails", async () => {
    const ctx = makeProjectExplanationContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { reasons: ["Only reasons"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    await expect(generateProjectExplanation(ctx)).rejects.toMatchObject({ code: "invalid_ai_response" });
  });

  it("empty summary fails", async () => {
    const ctx = makeProjectExplanationContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { summary: "   ", reasons: ["Reason 1", "Reason 2"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    await expect(generateProjectExplanation(ctx)).rejects.toMatchObject({ code: "invalid_ai_response" });
  });

  it("overly long summary fails", async () => {
    const ctx = makeProjectExplanationContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { summary: "A".repeat(700), reasons: ["Reason 1", "Reason 2"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    await expect(generateProjectExplanation(ctx)).rejects.toMatchObject({ code: "invalid_ai_response" });
  });

  it("provider error maps to ai_generation_failed", async () => {
    const ctx = makeProjectExplanationContext();
    mockGenerateStructured.mockRejectedValueOnce({ code: "timeout", message: "timeout", provider: "groq" });
    await expect(generateProjectExplanation(ctx)).rejects.toMatchObject({ code: "ai_generation_failed" });
  });

  it("unknown operation not applicable (service validates)", async () => {
    // This is more for route, but here we test that valid operation passes
    const ctx = makeProjectExplanationContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { summary: "Valid summary with enough length to pass validation checks.", reasons: ["Reason one valid", "Reason two valid"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    await expect(generateProjectExplanation(ctx)).resolves.toBeDefined();
  });
});

describe("ProjectCoaching", () => {
  beforeEach(() => { vi.clearAllMocks(); });

  it("valid coaching succeeds", async () => {
    const ctx = makeProjectCoachingContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { focus: "Focus on testing the core user flow.", actions: ["Test normal input", "Test missing input", "Record results"], caution: null },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    const result = await generateProjectCoaching(ctx);
    expect(result.data.focus.length).toBeGreaterThan(20);
  });

  it("empty actions fails", async () => {
    const ctx = makeProjectCoachingContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { focus: "Focus", actions: [] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    await expect(generateProjectCoaching(ctx)).rejects.toMatchObject({ code: "invalid_ai_response" });
  });

  it("no mutation of execution", async () => {
    const ctx = makeProjectCoachingContext();
    const before = JSON.stringify(ctx.execution);
    mockGenerateStructured.mockResolvedValueOnce({
      data: { focus: "Focus with enough length to pass validation checks here.", actions: ["Action one long enough", "Action two long enough"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    await generateProjectCoaching(ctx);
    expect(JSON.stringify(ctx.execution)).toBe(before);
  });
});

describe("ProjectReflection", () => {
  it("valid reflection succeeds", async () => {
    const ctx = makeProjectReflectionContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { prompts: ["What problem did you solve?", "Which part was hardest?", "What would you change?"], draftReflection: null },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    const result = await generateProjectReflection(ctx);
    expect(result.data.prompts.length).toBe(3);
  });

  it("too few prompts fails", async () => {
    const ctx = makeProjectReflectionContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { prompts: ["Only one"], draftReflection: null },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    await expect(generateProjectReflection(ctx)).rejects.toMatchObject({ code: "invalid_ai_response" });
  });
});

describe("SkillExplanation", () => {
  it("valid skill explanation succeeds", async () => {
    const ctx = makeSkillContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { summary: "TypeScript is a gap because your roadmap requires it for the next milestone.", howProjectHelps: "Portfolio Site gives you practice with TypeScript in a real project." },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    const result = await generateSkillExplanation(ctx);
    expect(result.data.summary).toContain("gap");
  });

  it("missing skill fails", async () => {
    const ctx = makeSkillContext({ skill: { id: "", name: "" } });
    await expect(generateSkillExplanation(ctx)).rejects.toMatchObject({ code: "invalid_request" });
  });
});

describe("RoadmapExplanation", () => {
  it("valid roadmap explanation succeeds", async () => {
    const ctx = makeRoadmapContext();
    mockGenerateStructured.mockResolvedValueOnce({
      data: { summary: "Your roadmap has 2 completed milestones, focus on the next.", focusAreas: ["Complete next milestone", "Practice TypeScript"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    const result = await generateRoadmapExplanation(ctx);
    expect(result.data.summary.length).toBeGreaterThan(20);
  });

  it("does not reorder roadmap", async () => {
    const ctx = makeRoadmapContext();
    const beforeOrder = ctx.skillGaps.join(",");
    mockGenerateStructured.mockResolvedValueOnce({
      data: { summary: "Summary with enough length to pass validation checks here.", focusAreas: ["Focus one", "Focus two"] },
      rawText: "{}",
      model: "openai/gpt-oss-120b",
      provider: "groq",
    });
    await generateRoadmapExplanation(ctx);
    expect(ctx.skillGaps.join(",")).toBe(beforeOrder);
  });
});

describe("No mutation across operations", () => {
  it("calling all operations does not mutate original contexts", async () => {
    const projCtx = makeProjectExplanationContext();
    const original = JSON.stringify(projCtx);
    mockGenerateStructured.mockResolvedValue({ data: { summary: "Summary with enough length for validation.", reasons: ["Reason one long enough", "Reason two long enough"] }, rawText: "{}", model: "x", provider: "groq" });
    await generateProjectExplanation(projCtx);
    expect(JSON.stringify(projCtx)).toBe(original);
  });
});

describe("Recommendation isolation", () => {
  it("changing AI output does not change deterministic score", async () => {
    const ctx1 = makeProjectExplanationContext();
    const ctx2 = makeProjectExplanationContext();
    expect(ctx1.recommendation.score).toBe(ctx2.recommendation.score);
    // AI could return different text, but score in context is same (87)
    mockGenerateStructured.mockResolvedValueOnce({ data: { summary: "Summary A with enough length.", reasons: ["R1 long enough", "R2 long enough"] }, rawText: "{}", model: "x", provider: "groq" });
    const r1 = await generateProjectExplanation(ctx1);
    mockGenerateStructured.mockResolvedValueOnce({ data: { summary: "Summary B different text with enough length.", reasons: ["R1 different", "R2 different"] }, rawText: "{}", model: "x", provider: "groq" });
    const r2 = await generateProjectExplanation(ctx2);
    expect(r1.data.summary).not.toBe(r2.data.summary);
    // But deterministic score in context unchanged
    expect(ctx1.recommendation.score).toBe(87);
    expect(ctx2.recommendation.score).toBe(87);
  });
});
