// Tests for Roadmap Personalization — Phase 6.3

import { describe, it, expect } from "vitest";
import { buildRoadmapPrompt } from "../prompt";
import { validateAndNormalize } from "../service";
import type {
  RoadmapStudentContext,
  RoadmapCatalogItem,
} from "../types";

const STUDENT: RoadmapStudentContext = {
  firstName: "Alex",
  age: "16",
  schoolLevel: "high",
  grade: "11th",
  interests: ["Technology", "AI"],
  skills: ["Programming", "Problem solving"],
  careers: ["Software Engineer"],
  fields: ["Computer Science"],
  goals: ["Build a portfolio"],
  projects: [{ title: "Weather App", category: "Technology", skills: ["Programming"] }],
  achievements: [{ title: "Hackathon Winner", category: "Technology" }],
  completedRoadmapCount: 0,
  activeRoadmapCount: 1,
};

const ROADMAPS: RoadmapCatalogItem[] = [
  {
    id: "software-engineer",
    title: "Become a Software Engineer",
    goal: "Turn your technical interests into a project-ready software engineering foundation.",
    category: "career",
    description: "A practical sequence from programming fundamentals.",
    milestoneCount: 6,
    completedMilestones: 0,
    relevantInterests: ["Technology", "AI"],
    relevantSkills: ["Programming", "Problem solving"],
    relevantCareers: ["Software Engineer"],
    relevantFields: ["Computer Science"],
    matchScore: 81,
  },
  {
    id: "research-builder",
    title: "Build a Research Profile",
    goal: "Move from curiosity to documented research.",
    category: "academic",
    description: "Learn how to ask a strong question.",
    milestoneCount: 4,
    completedMilestones: 0,
    relevantInterests: ["Science", "Medicine"],
    relevantSkills: ["Research", "Writing"],
    relevantCareers: ["AI Researcher"],
    relevantFields: ["Biology", "Medicine"],
    matchScore: 56,
  },
  {
    id: "portfolio-projects",
    title: "Build a Project Portfolio",
    goal: "Create a body of work that makes your strengths visible.",
    category: "projects",
    description: "A flexible project path.",
    milestoneCount: 4,
    completedMilestones: 0,
    relevantInterests: ["Technology", "Design"],
    relevantSkills: ["Building things", "Programming"],
    relevantCareers: ["Software Engineer"],
    relevantFields: ["Computer Science"],
    matchScore: 75,
  },
  {
    id: "college-ready",
    title: "Prepare for College",
    goal: "Build an intentional academic and opportunity plan.",
    category: "college-preparation",
    description: "Organize your direction.",
    milestoneCount: 4,
    completedMilestones: 0,
    relevantInterests: ["Technology"],
    relevantSkills: ["Research", "Writing"],
    relevantCareers: [],
    relevantFields: ["Computer Science"],
    matchScore: 63,
  },
];

const VALID_IDS = new Set(ROADMAPS.map((r) => r.id));

describe("buildRoadmapPrompt", () => {
  it("includes student profile details", () => {
    const { user } = buildRoadmapPrompt({ student: STUDENT, roadmaps: ROADMAPS });
    expect(user).toContain("Alex");
    expect(user).toContain("Technology");
    expect(user).toContain("Software Engineer");
    expect(user).toContain("Weather App");
    expect(user).toContain("Hackathon Winner");
  });

  it("includes all roadmap titles and IDs", () => {
    const { user } = buildRoadmapPrompt({ student: STUDENT, roadmaps: ROADMAPS });
    expect(user).toContain("software-engineer");
    expect(user).toContain("research-builder");
    expect(user).toContain("portfolio-projects");
    expect(user).toContain("college-ready");
    expect(user).toContain("Become a Software Engineer");
  });

  it("system prompt restricts to supplied facts only", () => {
    const { system } = buildRoadmapPrompt({ student: STUDENT, roadmaps: ROADMAPS });
    expect(system).toContain("ONLY");
    expect(system).toContain("Do not invent roadmaps");
  });

  it("handles student with no data", () => {
    const empty: RoadmapStudentContext = {
      interests: [],
      skills: [],
      careers: [],
      fields: [],
      goals: [],
      projects: [],
      achievements: [],
      completedRoadmapCount: 0,
      activeRoadmapCount: 0,
    };
    const { user } = buildRoadmapPrompt({ student: empty, roadmaps: ROADMAPS });
    expect(user).toContain("STUDENT PROFILE");
    expect(user).toContain("AVAILABLE ROADMAPS");
  });

  it("includes roadmap progress and match scores", () => {
    const { user } = buildRoadmapPrompt({ student: STUDENT, roadmaps: ROADMAPS });
    expect(user).toContain("0/6");
    expect(user).toContain("81%");
    expect(user).toContain("Deterministic match score");
  });
});

describe("validateAndNormalize", () => {
  it("returns empty for null input", () => {
    const result = validateAndNormalize(null, VALID_IDS);
    expect(result.recommendations).toEqual([]);
  });

  it("returns empty for non-object input", () => {
    const result = validateAndNormalize("bad", VALID_IDS);
    expect(result.recommendations).toEqual([]);
  });

  it("returns empty for missing recommendations array", () => {
    const result = validateAndNormalize({ bad: "data" }, VALID_IDS);
    expect(result.recommendations).toEqual([]);
  });

  it("validates roadmap IDs against catalog", () => {
    const result = validateAndNormalize(
      {
        recommendations: [
          { roadmapId: "software-engineer", fitScore: 90, reason: "Perfect match" },
          { roadmapId: "nonexistent-roadmap", fitScore: 80, reason: "Fake" },
        ],
      },
      VALID_IDS
    );

    const ids = result.recommendations.map((r) => r.roadmapId);
    expect(ids).toContain("software-engineer");
    expect(ids).not.toContain("nonexistent-roadmap");
  });

  it("removes duplicate roadmap IDs", () => {
    const result = validateAndNormalize(
      {
        recommendations: [
          { roadmapId: "software-engineer", fitScore: 90, reason: "First" },
          { roadmapId: "software-engineer", fitScore: 85, reason: "Duplicate" },
        ],
      },
      VALID_IDS
    );

    expect(result.recommendations).toHaveLength(1);
    expect(result.recommendations[0].roadmapId).toBe("software-engineer");
  });

  it("clamps fitScore to 0-100", () => {
    const result = validateAndNormalize(
      {
        recommendations: [
          { roadmapId: "software-engineer", fitScore: 150, reason: "Too high" },
          { roadmapId: "research-builder", fitScore: -10, reason: "Too low" },
        ],
      },
      VALID_IDS
    );

    const scores = result.recommendations.map((r) => r.fitScore);
    expect(scores).toContain(100);
    expect(scores).toContain(0);
  });

  it("rounds non-integer fitScores", () => {
    const result = validateAndNormalize(
      {
        recommendations: [
          { roadmapId: "software-engineer", fitScore: 87.6, reason: "Rounded up" },
          { roadmapId: "research-builder", fitScore: 55.3, reason: "Rounded down" },
        ],
      },
      VALID_IDS
    );

    expect(result.recommendations.find((r) => r.roadmapId === "software-engineer")!.fitScore).toBe(88);
    expect(result.recommendations.find((r) => r.roadmapId === "research-builder")!.fitScore).toBe(55);
  });

  it("provides default reason when empty", () => {
    const result = validateAndNormalize(
      {
        recommendations: [
          { roadmapId: "software-engineer", fitScore: 90, reason: "" },
        ],
      },
      VALID_IDS
    );

    expect(result.recommendations[0].reason).toContain("fit");
  });

  it("provides default reason for missing reason field", () => {
    const result = validateAndNormalize(
      {
        recommendations: [
          { roadmapId: "software-engineer", fitScore: 90 },
        ],
      },
      VALID_IDS
    );

    expect(result.recommendations[0].reason).toContain("fit");
  });

  it("uses default fitScore of 50 for missing score", () => {
    const result = validateAndNormalize(
      {
        recommendations: [
          { roadmapId: "software-engineer", reason: "No score" },
        ],
      },
      VALID_IDS
    );

    expect(result.recommendations[0].fitScore).toBe(50);
  });

  it("sorts by fitScore descending", () => {
    const result = validateAndNormalize(
      {
        recommendations: [
          { roadmapId: "research-builder", fitScore: 40, reason: "Low" },
          { roadmapId: "software-engineer", fitScore: 95, reason: "High" },
          { roadmapId: "portfolio-projects", fitScore: 70, reason: "Mid" },
        ],
      },
      VALID_IDS
    );

    expect(result.recommendations[0].fitScore).toBe(95);
    expect(result.recommendations[1].fitScore).toBe(70);
    expect(result.recommendations[2].fitScore).toBe(40);
  });

  it("handles malformed items in recommendations array", () => {
    const result = validateAndNormalize(
      {
        recommendations: [
          null,
          "string",
          42,
          { roadmapId: "software-engineer", fitScore: 90, reason: "Good" },
        ],
      },
      VALID_IDS
    );

    expect(result.recommendations).toHaveLength(1);
    expect(result.recommendations[0].roadmapId).toBe("software-engineer");
  });
});
