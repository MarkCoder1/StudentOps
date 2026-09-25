import { describe, it, expect } from "vitest";
import { calculateRankScore, compareRankScores, generateBadges } from "../personalization/rank";
import { personalizeOpportunities } from "../personalization/index";
import type { Opportunity } from "../models/opportunity";
import type { StudentProfileForPersonalization } from "../personalization/types";
import type { PersonalizedOpportunity } from "../personalization/types";

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

function makeOpportunity(overrides: Partial<Opportunity> = {}): Opportunity {
  return {
    id: "test:1",
    source: "studentSuite",
    externalId: "1",
    title: "Test Opportunity",
    description: "A test opportunity",
    organization: "Test Org",
    officialUrl: "https://example.com",
    applicationUrl: "https://example.com/apply",
    sourceUrl: "https://example.com/source",
    category: "competition",
    sourceCategory: "STEM",
    subjects: ["Computer Science"],
    topics: ["AI", "Machine Learning"],
    skills: ["Python", "Coding"],
    deadline: "2026-12-01",
    startDate: null,
    endDate: null,
    location: { type: "online", city: null, state: null, country: null, online: true, latitude: null, longitude: null },
    cost: { amount: null, currency: null, isFree: true },
    benefits: { awardText: "$1000", awardAmount: 1000, awardCurrency: "USD", prizeText: "$1000" },
    eligibility: { minAge: null, maxAge: null, gradeMin: null, gradeMax: null, countries: null, geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null },
    provenance: { source: "studentSuite", externalId: "1", fetchedAt: "2026-09-13T00:00:00Z", sourceUpdatedAt: null },
    sourceMetadata: {},
    ...overrides,
  } as Opportunity;
}

function makeProfile(overrides: Partial<StudentProfileForPersonalization> = {}): StudentProfileForPersonalization {
  return {
    interests: ["Computer Science", "AI"],
    customInterests: [],
    strengths: ["Python", "Coding"],
    customSkills: [],
    careers: ["Software Engineer"],
    fields: ["Computer Science"],
    milestones: ["Get research experience"],
    grade: "11th",
    schoolLevel: "High School",
    location: "Austin, TX",
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Ranking tests
// ---------------------------------------------------------------------------

describe("calculateRankScore", () => {
  it("returns 0 for ineligible with no match and no urgency", () => {
    const score = calculateRankScore(0, "none", "ineligible", null);
    expect(score).toBe(0);
  });

  it("returns 100 for eligible with perfect match and urgent deadline", () => {
    const score = calculateRankScore(100, "urgent", "eligible", 1);
    expect(score).toBe(100);
  });

  it("weights match at 50%, urgency at 30%, eligibility at 20%", () => {
    // match=80, urgency=soon(75), eligible(100)
    // raw = 80*0.5 + 75*0.3 + 100*0.2 = 40 + 22.5 + 20 = 82.5 → 83
    const score = calculateRankScore(80, "soon", "eligible", 5);
    expect(score).toBe(83);
  });

  it("unknown eligibility gets 50% bonus", () => {
    // match=50, urgency=none(0), unknown(50)
    // raw = 50*0.5 + 0*0.3 + 50*0.2 = 25 + 0 + 10 = 35
    const score = calculateRankScore(50, "none", "unknown", null);
    expect(score).toBe(35);
  });

  it("clamps to 0-100 range", () => {
    expect(calculateRankScore(100, "urgent", "eligible", 0)).toBe(100);
    expect(calculateRankScore(0, "none", "ineligible", null)).toBe(0);
  });
});

describe("compareRankScores", () => {
  function makePersonalized(overrides: { rankScore: number; matchScore: number; daysUntilDeadline: number | null; title: string }): PersonalizedOpportunity {
    return {
      opportunity: makeOpportunity({ title: overrides.title }),
      eligibility: { status: "eligible", reasons: [] },
      match: { score: overrides.matchScore, label: "", reasons: [], signals: [] },
      freshness: { status: "active", urgency: "none", daysUntilDeadline: overrides.daysUntilDeadline, deadline: null, reason: "" },
      rankScore: overrides.rankScore,
      badges: [],
    };
  }

  it("sorts by higher rankScore first", () => {
    const a = makePersonalized({ rankScore: 80, matchScore: 70, daysUntilDeadline: 10, title: "A" });
    const b = makePersonalized({ rankScore: 60, matchScore: 80, daysUntilDeadline: 5, title: "B" });
    // Negative means a comes before b in sort order (Array.sort convention)
    expect(compareRankScores(a, b)).toBeLessThan(0);
  });

  it("tie-breaks by earlier deadline", () => {
    const a = makePersonalized({ rankScore: 50, matchScore: 50, daysUntilDeadline: 10, title: "A" });
    const b = makePersonalized({ rankScore: 50, matchScore: 50, daysUntilDeadline: 5, title: "B" });
    // b has earlier deadline, so a should come after b (positive = a after b)
    expect(compareRankScores(a, b)).toBeGreaterThan(0);
  });

  it("null deadlines sort after those with deadlines", () => {
    const a = makePersonalized({ rankScore: 50, matchScore: 50, daysUntilDeadline: null, title: "A" });
    const b = makePersonalized({ rankScore: 50, matchScore: 50, daysUntilDeadline: 10, title: "B" });
    // a has null deadline, should come after b (positive = a after b)
    expect(compareRankScores(a, b)).toBeGreaterThan(0);
  });

  it("tie-breaks by higher match score", () => {
    const a = makePersonalized({ rankScore: 50, matchScore: 60, daysUntilDeadline: null, title: "A" });
    const b = makePersonalized({ rankScore: 50, matchScore: 40, daysUntilDeadline: null, title: "B" });
    // Negative means a comes before b
    expect(compareRankScores(a, b)).toBeLessThan(0);
  });

  it("tie-breaks alphabetically", () => {
    const a = makePersonalized({ rankScore: 50, matchScore: 50, daysUntilDeadline: null, title: "Banana" });
    const b = makePersonalized({ rankScore: 50, matchScore: 50, daysUntilDeadline: null, title: "Apple" });
    // Banana > Apple alphabetically, so a comes after b (positive = a after b)
    expect(compareRankScores(a, b)).toBeGreaterThan(0);
  });
});

describe("generateBadges", () => {
  it("adds Best Match for score >= 80 and eligible", () => {
    const badges = generateBadges(85, "eligible", "none", null, "competition");
    expect(badges).toContain("Best Match");
  });

  it("does not add Best Match for ineligible", () => {
    const badges = generateBadges(90, "ineligible", "none", null, "competition");
    expect(badges).not.toContain("Best Match");
  });

  it("adds Deadline Soon for urgent", () => {
    const badges = generateBadges(50, "eligible", "urgent", null, "competition");
    expect(badges).toContain("Deadline Soon");
  });

  it("adds Deadline Soon for soon", () => {
    const badges = generateBadges(50, "eligible", "soon", null, "competition");
    expect(badges).toContain("Deadline Soon");
  });

  it("adds Scholarship for scholarship category", () => {
    const badges = generateBadges(50, "eligible", "none", null, "scholarship");
    expect(badges).toContain("Scholarship");
  });

  it("adds Hackathon for hackathon category", () => {
    const badges = generateBadges(50, "eligible", "none", null, "hackathon");
    expect(badges).toContain("Hackathon");
  });

  it("adds Competition for competition category", () => {
    const badges = generateBadges(50, "eligible", "none", null, "competition");
    expect(badges).toContain("Competition");
  });

  it("adds Free when isFree is true", () => {
    const badges = generateBadges(50, "eligible", "none", true, "competition");
    expect(badges).toContain("Free");
  });

  it("does not add Free when isFree is false", () => {
    const badges = generateBadges(50, "eligible", "none", false, "competition");
    expect(badges).not.toContain("Free");
  });
});

// ---------------------------------------------------------------------------
// Personalization integration tests
// ---------------------------------------------------------------------------

describe("personalizeOpportunities", () => {
  it("returns personalized feed with all opportunities", () => {
    const opps = [makeOpportunity(), makeOpportunity({ id: "test:2", title: "Second" })];
    const profile = makeProfile();
    const feed = personalizeOpportunities(opps, profile);
    expect(feed.opportunities).toHaveLength(2);
    expect(feed.stats.total).toBe(2);
  });

  it("scores eligible opportunities higher than ineligible", () => {
    const eligible = makeOpportunity({ id: "test:eligible", title: "Eligible" });
    const ineligible = makeOpportunity({
      id: "test:ineligible",
      title: "Ineligible",
      eligibility: { minAge: 25, maxAge: 30, gradeMin: null, gradeMax: null, countries: ["US"], geographicRestrictions: null, enrollmentLevels: ["Graduate"], majors: null, requirements: null },
    });
    const profile = makeProfile({ age: 16 });
    const feed = personalizeOpportunities([ineligible, eligible], profile);
    // Eligible should rank higher
    const eligibleIdx = feed.opportunities.findIndex((p) => p.opportunity.id === "test:eligible");
    const ineligibleIdx = feed.opportunities.findIndex((p) => p.opportunity.id === "test:ineligible");
    expect(eligibleIdx).toBeLessThan(ineligibleIdx);
  });

  it("counts eligibility stats correctly", () => {
    const opps = [
      makeOpportunity({ id: "test:1" }),
      makeOpportunity({ id: "test:2", eligibility: { minAge: 25, maxAge: 30, gradeMin: null, gradeMax: null, countries: null, geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null } }),
    ];
    const profile = makeProfile({ age: 16 });
    const feed = personalizeOpportunities(opps, profile);
    expect(feed.stats.total).toBe(2);
    // With no structured requirements, eligibility is "unknown"
    expect(feed.stats.unknown + feed.stats.eligible + feed.stats.ineligible).toBe(2);
  });

  it("creates sections based on categories", () => {
    const opps = [
      makeOpportunity({ id: "test:1", category: "scholarship", title: "Scholarship 1" }),
      makeOpportunity({ id: "test:2", category: "hackathon", title: "Hackathon 1" }),
      makeOpportunity({ id: "test:3", category: "competition", title: "Competition 1" }),
    ];
    const profile = makeProfile();
    const feed = personalizeOpportunities(opps, profile);
    const sectionIds = feed.sections.map((s) => s.id);
    expect(sectionIds).toContain("scholarships");
    expect(sectionIds).toContain("hackathons");
    expect(sectionIds).toContain("competitions");
  });

  it("excludes ineligible from primary sections", () => {
    const opps = [
      makeOpportunity({ id: "test:1", category: "scholarship", title: "Scholarship 1" }),
      makeOpportunity({
        id: "test:2",
        category: "scholarship",
        title: "Ineligible Scholarship",
        eligibility: { minAge: 25, maxAge: 30, gradeMin: null, gradeMax: null, countries: null, geographicRestrictions: null, enrollmentLevels: ["Graduate"], majors: null, requirements: null },
      }),
    ];
    const profile = makeProfile({ age: 16 });
    const feed = personalizeOpportunities(opps, profile);
    const scholarshipSection = feed.sections.find((s) => s.id === "scholarships");
    expect(scholarshipSection).toBeDefined();
    // Only eligible/unknown should be in section
    for (const p of scholarshipSection!.opportunities) {
      expect(p.eligibility.status).not.toBe("ineligible");
    }
  });

  it("returns empty sections when no opportunities match", () => {
    const feed = personalizeOpportunities([], makeProfile());
    expect(feed.opportunities).toHaveLength(0);
    expect(feed.sections).toHaveLength(0);
    expect(feed.stats.total).toBe(0);
  });

  it("handles missing deadlines gracefully", () => {
    const opp = makeOpportunity({ deadline: null });
    const feed = personalizeOpportunities([opp], makeProfile());
    expect(feed.opportunities[0].freshness.status).toBe("unknown");
    expect(feed.opportunities[0].freshness.daysUntilDeadline).toBeNull();
  });

  it("handles expired opportunities", () => {
    const opp = makeOpportunity({ deadline: "2020-01-01" });
    const feed = personalizeOpportunities([opp], makeProfile());
    expect(feed.opportunities[0].freshness.status).toBe("expired");
  });

  it("handles opportunities with no match signals", () => {
    const opp = makeOpportunity({
      subjects: [],
      topics: [],
      skills: [],
      category: "other",
    });
    const profile = makeProfile({ interests: [], strengths: [], careers: [], fields: [] });
    const feed = personalizeOpportunities([opp], profile);
    expect(feed.opportunities[0].match.score).toBe(0);
    expect(feed.opportunities[0].match.reasons).toHaveLength(0);
  });

  it("calculates average match score", () => {
    const opps = [
      makeOpportunity({ id: "test:1", subjects: ["Computer Science"], topics: ["AI"], skills: ["Python"] }),
      makeOpportunity({ id: "test:2", subjects: ["Art"], topics: ["Painting"], skills: ["Drawing"] }),
    ];
    const profile = makeProfile();
    const feed = personalizeOpportunities(opps, profile);
    expect(feed.stats.avgMatchScore).toBeGreaterThanOrEqual(0);
    expect(feed.stats.avgMatchScore).toBeLessThanOrEqual(100);
  });

  it("deterministic: same input produces same output", () => {
    const opps = [makeOpportunity(), makeOpportunity({ id: "test:2", title: "Second" })];
    const profile = makeProfile();
    const feed1 = personalizeOpportunities(opps, profile);
    const feed2 = personalizeOpportunities(opps, profile);
    expect(feed1.opportunities.map((p) => p.rankScore)).toEqual(feed2.opportunities.map((p) => p.rankScore));
    expect(feed1.opportunities.map((p) => p.match.score)).toEqual(feed2.opportunities.map((p) => p.match.score));
  });

  it("generates badges for matching opportunities", () => {
    const opp = makeOpportunity({
      subjects: ["Computer Science"],
      topics: ["AI"],
      skills: ["Python"],
      cost: { amount: null, currency: null, isFree: true },
    });
    const profile = makeProfile();
    const feed = personalizeOpportunities([opp], profile);
    const p = feed.opportunities[0];
    // Should have some badges (Free, possibly Best Match)
    expect(p.badges.length).toBeGreaterThanOrEqual(1);
  });
});
