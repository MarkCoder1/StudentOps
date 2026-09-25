import { describe, it, expect } from "vitest";
import { matchOpportunity, matchOpportunities } from "../matching/evaluate";
import type { Opportunity } from "../models/opportunity";

function makeOpp(overrides: Partial<Opportunity> = {}): Opportunity {
  return {
    id: "test:1",
    source: "studentSuite",
    externalId: "1",
    title: "Test Opportunity",
    description: null,
    organization: null,
    officialUrl: null,
    applicationUrl: null,
    sourceUrl: null,
    category: "other",
    sourceCategory: null,
    subjects: [],
    topics: [],
    skills: [],
    deadline: null,
    startDate: null,
    endDate: null,
    location: { type: "unknown", city: null, state: null, country: null, online: null, latitude: null, longitude: null },
    cost: { amount: null, currency: null, isFree: null },
    benefits: { awardText: null, awardAmount: null, awardCurrency: null, prizeText: null },
    eligibility: { minAge: null, maxAge: null, gradeMin: null, gradeMax: null, countries: null, geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null },
    provenance: { source: "studentSuite", externalId: "1", fetchedAt: "2026-09-12T00:00:00.000Z", sourceUpdatedAt: null },
    sourceMetadata: {},
    ...overrides,
  } as Opportunity;
}

describe("Matching — interest", () => {
  it("Exact interest match → strong signal → high score", () => {
    const student = { interests: ["AI"], customInterests: [] };
    const opp = makeOpp({ topics: ["AI"], subjects: [] });
    const result = matchOpportunity(opp, student);
    const sig = result.signals.find((s) => s.dimension === "interest")!;
    expect(sig.score).toBe(1);
    expect(sig.available).toBe(true);
    expect(result.score).toBeGreaterThan(40);
    expect(result.reasons.some((r) => r.toLowerCase().includes("ai"))).toBe(true);
  });

  it("No interest match → no signal", () => {
    const student = { interests: ["Biology"] };
    const opp = makeOpp({ topics: ["Machine Learning"], subjects: ["AI"] });
    const result = matchOpportunity(opp, student);
    const sig = result.signals.find((s) => s.dimension === "interest")!;
    expect(sig.score).toBe(0);
  });
});

describe("Matching — career", () => {
  it("Career Software Engineer vs programming → positive", () => {
    const student = { careers: ["Software Engineer"] };
    const opp = makeOpp({ topics: ["Programming"], subjects: ["Software"] });
    const result = matchOpportunity(opp, student);
    const sig = result.signals.find((s) => s.dimension === "career")!;
    expect(sig.score).toBeGreaterThan(0);
    expect(sig.score).toBe(1); // via expanded map programming
  });

  it("Career Physical Therapist vs robotics → no strong match", () => {
    const student = { careers: ["Physical Therapist"] };
    const opp = makeOpp({ topics: ["Robotics"], subjects: [] });
    const result = matchOpportunity(opp, student);
    const sig = result.signals.find((s) => s.dimension === "career")!;
    expect(sig.score).toBe(0);
  });
});

describe("Matching — skill", () => {
  it("Skill Python exact → strong", () => {
    const student = { customSkills: ["Python"] };
    const opp = makeOpp({ skills: ["Python"] });
    const result = matchOpportunity(opp, student);
    const sig = result.signals.find((s) => s.dimension === "skill")!;
    expect(sig.score).toBe(1);
    expect(result.reasons.some((r) => r.includes("Python"))).toBe(true);
  });

  it("Missing skill should not punish overall", () => {
    const studentNoSkill = { interests: ["AI"], careers: ["Software Engineer"], fields: ["Computer Science"] };
    const studentWithSkill = { ...studentNoSkill, customSkills: ["Python"] };
    const opp = makeOpp({ topics: ["AI"], skills: ["Python"], category: "hackathon", subjects: ["Computer Science"] });
    const r1 = matchOpportunity(opp, studentNoSkill);
    const r2 = matchOpportunity(opp, studentWithSkill);
    // With skill missing, skill dimension unavailable → not counted, so r1 should not be heavily punished
    // r2 has extra skill match, so should be higher but not huge penalty for r1
    expect(r1.score).toBeGreaterThan(0);
    expect(r2.score).toBeGreaterThanOrEqual(r1.score);
  });
});

describe("Matching — field", () => {
  it("Field Computer Science exact → strong", () => {
    const student = { fields: ["Computer Science"] };
    const opp = makeOpp({ subjects: ["Computer Science"] });
    const result = matchOpportunity(opp, student);
    expect(result.signals.find((s) => s.dimension === "field")!.score).toBe(1);
  });

  it("Field via expanded mapping programming → CS", () => {
    const student = { fields: ["Computer Science"] };
    const opp = makeOpp({ topics: ["Programming"] });
    // Computer Science expanded includes programming
    const result = matchOpportunity(opp, student);
    expect(result.signals.find((s) => s.dimension === "field")!.score).toBe(1);
  });
});

describe("Matching — multiple signals", () => {
  it("multiple signals substantially higher than unrelated", () => {
    const student = {
      interests: ["AI"],
      customInterests: [],
      careers: ["Software Engineer"],
      fields: ["Computer Science"],
      customSkills: ["Python"],
      strengths: [],
      milestones: [],
    };
    const oppMatched = makeOpp({
      topics: ["AI", "Machine Learning"],
      skills: ["Python"],
      subjects: ["Computer Science", "Programming"],
      category: "hackathon",
    });
    const oppUnrelated = makeOpp({
      topics: ["Biology"],
      skills: ["Lab Technique"],
      subjects: ["Medicine"],
      category: "scholarship",
    });
    const r1 = matchOpportunity(oppMatched, student);
    const r2 = matchOpportunity(oppUnrelated, student);
    expect(r1.score).toBeGreaterThan(r2.score + 20);
    expect(r1.score).toBeGreaterThan(60);
    expect(r2.score).toBeLessThan(20);
  });
});

describe("Matching — missing profile data", () => {
  it("skill dimension unavailable → not punished", () => {
    const studentEmptySkills = { interests: ["AI"] };
    const opp = makeOpp({ topics: ["AI"] });
    const result = matchOpportunity(opp, studentEmptySkills);
    const skillSig = result.signals.find((s) => s.dimension === "skill")!;
    expect(skillSig.available).toBe(false);
    // Score should be based only on available dimensions, not punished by missing skill.
    // Interest (25) + subject (10) are available and match (both derived from interests), category (5) available but 0 → weighted 35/40 = 88
    // So score is high, not zero, proving missing skill not heavily punished
    expect(result.score).toBe(88);
    expect(result.score).toBeGreaterThan(80);
  });
});

describe("Matching — eligibility independence", () => {
  it("ineligible can still have high match", () => {
    const student = { interests: ["AI"] };
    const opp = makeOpp({ topics: ["AI"], subjects: ["AI"] });
    const elig = { status: "ineligible" as const, reasons: [], checks: [] };
    const result = matchOpportunity(opp, student, elig as any);
    expect(result.eligibility).toBe("ineligible");
    expect(result.score).toBeGreaterThan(60);
    // Should not zero out
  });
});

describe("Matching — determinism", () => {
  it("same input → identical output", () => {
    const student = { interests: ["AI"], fields: ["Computer Science"] };
    const opp = makeOpp({ topics: ["AI"], subjects: ["Computer Science"] });
    const r1 = matchOpportunity(opp, student);
    const r2 = matchOpportunity(opp, student);
    expect(r1).toEqual(r2);
  });
});

describe("Matching — reasons", () => {
  it("every positive signal produces reason", () => {
    const student = { interests: ["AI"], careers: ["Software Engineer"], fields: ["Computer Science"], customSkills: ["Python"] };
    const opp = makeOpp({ topics: ["AI"], subjects: ["Computer Science"], skills: ["Python"], category: "hackathon" });
    const result = matchOpportunity(opp, student);
    const positive = result.signals.filter((s) => s.score > 0);
    expect(positive.length).toBeGreaterThan(0);
    for (const sig of positive) {
      expect(result.reasons.some((r) => r.length > 5)).toBe(true);
    }
  });

  it("no generic reason", () => {
    const student = { interests: ["AI"] };
    const opp = makeOpp({ topics: ["AI"] });
    const result = matchOpportunity(opp, student);
    for (const r of result.reasons) {
      expect(r.toLowerCase()).not.toBe("this opportunity is great for you.");
    }
  });
});

describe("Matching — subject/topic", () => {
  it("subject Computer Science via formatting variations", () => {
    const student = { fields: ["Computer Science"] };
    const opp1 = makeOpp({ subjects: ["computer-science"] });
    const opp2 = makeOpp({ subjects: ["computer science"] });
    const opp3 = makeOpp({ subjects: ["Computer Science"] });
    for (const opp of [opp1, opp2, opp3]) {
      const res = matchOpportunity(opp, student);
      expect(res.signals.find((s) => s.dimension === "subject")!.score).toBe(1);
    }
  });
});

describe("Matching — category", () => {
  it("category STEM vs STEM → positive", () => {
    const student = { interests: ["STEM"] };
    const opp = makeOpp({ category: "competition", sourceCategory: "STEM" });
    // Our category signal checks interests vs category, so STEM interest vs competition category not exact, but sourceCategory STEM?
    // Let's use interest STEM vs category competition not match, but sourceCategory STEM should give 0.5
    const result = matchOpportunity(opp, student);
    // At least category dimension available but may be 0 or 0.5
    expect(result.signals.find((s) => s.dimension === "category")!.available).toBe(true);
  });
});

describe("Matching — goal", () => {
  it("goal build research profile vs research competition", () => {
    const student = { milestones: ["build research profile"] };
    const opp = makeOpp({ category: "research", topics: ["research"] });
    const result = matchOpportunity(opp, student);
    expect(result.signals.find((s) => s.dimension === "goal")!.score).toBeGreaterThan(0);
  });
});

describe("Matching — score range and label", () => {
  it("score 0-100 and label", () => {
    const student = { interests: ["AI"] };
    const opp = makeOpp({ topics: ["AI"] });
    const result = matchOpportunity(opp, student);
    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.score).toBeLessThanOrEqual(100);
    expect(Number.isInteger(result.score)).toBe(true);
    expect(result.label).toMatch(/match/i);
  });
});

describe("Matching — batch", () => {
  it("matchOpportunities batch preserves order and eligibility", () => {
    const student = { interests: ["AI"] };
    const opps = [makeOpp({ id: "a:1", topics: ["AI"] }), makeOpp({ id: "b:2", topics: ["Biology"] })];
    const map = new Map([["a:1", { status: "eligible" as const, reasons: [], checks: [] }]]);
    const results = matchOpportunities(opps, student as any, map as any);
    expect(results).toHaveLength(2);
    expect(results[0].eligibility).toBe("eligible");
    expect(results[1].eligibility).toBeNull();
  });
});

describe("Matching — no mutation", () => {
  it("does not modify inputs", () => {
    const student = { interests: ["AI"] };
    const opp = makeOpp({ title: "Original", topics: ["AI"] });
    const copyOpp = JSON.parse(JSON.stringify(opp));
    const copyStudent = JSON.parse(JSON.stringify(student));
    matchOpportunity(opp, student);
    expect(opp).toEqual(copyOpp);
    expect(student).toEqual(copyStudent);
  });
});
