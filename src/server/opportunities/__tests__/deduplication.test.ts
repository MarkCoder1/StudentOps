import { describe, it, expect } from "vitest";
import { deduplicateOpportunities } from "../deduplication/deduplicate";
import { normalizeUrl, normalizeText } from "../deduplication/normalizeComparison";
import { titleSimilarity } from "../deduplication/similarity";
import type { Opportunity } from "../models/opportunity";

function makeOpp(overrides: Partial<Opportunity> & { id: string; source: any; externalId: string; title: string }): Opportunity {
  return {
    source: overrides.source,
    externalId: overrides.externalId,
    id: overrides.id,
    title: overrides.title,
    description: overrides.description ?? null,
    organization: overrides.organization ?? null,
    officialUrl: overrides.officialUrl ?? null,
    applicationUrl: overrides.applicationUrl ?? null,
    sourceUrl: overrides.sourceUrl ?? null,
    category: (overrides.category as any) ?? "other",
    sourceCategory: overrides.sourceCategory ?? null,
    subjects: overrides.subjects ?? [],
    topics: overrides.topics ?? [],
    skills: overrides.skills ?? [],
    deadline: overrides.deadline ?? null,
    startDate: overrides.startDate ?? null,
    endDate: overrides.endDate ?? null,
    location: overrides.location ?? { type: "unknown", city: null, state: null, country: null, online: null, latitude: null, longitude: null },
    cost: overrides.cost ?? { amount: null, currency: null, isFree: null },
    benefits: overrides.benefits ?? { awardText: null, awardAmount: null, awardCurrency: null, prizeText: null },
    eligibility: overrides.eligibility ?? { minAge: null, maxAge: null, gradeMin: null, gradeMax: null, countries: null, geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null },
    provenance: overrides.provenance ?? { source: overrides.source, externalId: overrides.externalId, fetchedAt: "2026-09-12T00:00:00.000Z", sourceUpdatedAt: null },
    sourceMetadata: overrides.sourceMetadata ?? {},
    sourceRecords: overrides.sourceRecords,
  } as Opportunity;
}

describe("deduplication — exact source identity", () => {
  it("same source + externalId → one record", () => {
    const a = makeOpp({ id: "devpost:29377", source: "devpost", externalId: "29377", title: "Hack A" });
    const b = makeOpp({ id: "devpost:29377", source: "devpost", externalId: "29377", title: "Hack A duplicate" });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(1);
    expect(res.statistics.duplicateCount).toBe(1);
    expect(res.duplicateGroups[0].confidence).toBe("very-strong");
  });
});

describe("URL normalization", () => {
  it("same officialUrl with tracking params and trailing slash → one record", () => {
    const a = makeOpp({
      id: "studentSuite:1",
      source: "studentSuite",
      externalId: "1",
      title: "Challenge X",
      officialUrl: "https://example.com/opportunity?utm_source=foo",
      organization: "Org",
    });
    const b = makeOpp({
      id: "devpost:2",
      source: "devpost",
      externalId: "2",
      title: "Challenge X Different Title But URL same",
      officialUrl: "https://EXAMPLE.com/opportunity/",
      organization: "Other",
    });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(1);
    expect(res.duplicateGroups[0].reason).toMatch(/officialUrl/);
  });

  it("normalizeUrl lowercases hostname, removes utm", () => {
    expect(normalizeUrl("https://Example.COM/path/?utm_source=abc&keep=1&utm_medium=x#frag")).toBe(
      "https://example.com/path?keep=1"
    );
  });
});

describe("title + organization + deadline", () => {
  it("matching title+org+deadline → one record", () => {
    const a = makeOpp({
      id: "studentSuite:1",
      source: "studentSuite",
      externalId: "1",
      title: "Breakthrough Junior Challenge",
      organization: "Breakthrough Prize Foundation",
      deadline: "2026-06-25",
    });
    const b = makeOpp({
      id: "scholarshipExtractor:2",
      source: "scholarshipExtractor",
      externalId: "2",
      title: "breakthrough junior challenge", // case diff
      organization: " Breakthrough Prize Foundation ",
      deadline: "2026-06-25",
    });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(1);
    expect(res.duplicateGroups[0].confidence).toBe("strong");
  });
});

describe("title only different org → two records", () => {
  it("same title different organizations → two records", () => {
    const a = makeOpp({ id: "a:1", source: "studentSuite", externalId: "1", title: "AI Challenge", organization: "Org A" });
    const b = makeOpp({ id: "b:2", source: "devpost", externalId: "2", title: "AI Challenge", organization: "Org B" });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(2);
  });
});

describe("same title different year → two records", () => {
  it("Scholarship 2026 vs 2027", () => {
    const a = makeOpp({
      id: "a:1",
      source: "studentSuite",
      externalId: "1",
      title: "Scholarship 2026",
      organization: "Org",
      sourceMetadata: { cycle_year: 2026 } as any,
    });
    const b = makeOpp({
      id: "b:2",
      source: "studentSuite",
      externalId: "2",
      title: "Scholarship 2027",
      organization: "Org",
      sourceMetadata: { cycle_year: 2027 } as any,
    });
    // Note: our cycle detection uses sourceMetadata.cycle_year
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(2);
  });
});

describe("event title different date → two records, same date → one", () => {
  it("same event title different startDate → two", () => {
    const a = makeOpp({
      id: "eventScraper:1",
      source: "eventScraper",
      externalId: "1",
      title: "AI Meetup",
      organization: "BLISS",
      startDate: "2026-07-15T17:00:00.000Z",
      location: { type: "inPerson", city: "Berlin", state: null, country: "DE", online: false, latitude: null, longitude: null },
    });
    const b = makeOpp({
      id: "eventScraper:2",
      source: "eventScraper",
      externalId: "2",
      title: "AI Meetup",
      organization: "BLISS",
      startDate: "2026-08-15T17:00:00.000Z",
      location: { type: "inPerson", city: "Berlin", state: null, country: "DE", online: false, latitude: null, longitude: null },
    });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(2);
  });

  it("same event title same org same date + city → one", () => {
    const a = makeOpp({
      id: "eventScraper:1",
      source: "eventScraper",
      externalId: "1",
      title: "AI Meetup",
      organization: "BLISS",
      startDate: "2026-07-15T17:00:00.000Z",
      location: { type: "inPerson", city: "Berlin", state: null, country: "DE", online: false, latitude: null, longitude: null },
    });
    const b = makeOpp({
      id: "eventScraper:2",
      source: "eventScraper",
      externalId: "2",
      title: "AI Meetup",
      organization: "BLISS",
      startDate: "2026-07-15T17:00:00.000Z",
      location: { type: "inPerson", city: "Berlin", state: null, country: "DE", online: false, latitude: null, longitude: null },
    });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(1);
  });
});

describe("similar but different titles → two records", () => {
  it("Google Science Fair vs Google AI Challenge", () => {
    const a = makeOpp({ id: "a:1", source: "studentSuite", externalId: "1", title: "Google Science Fair", organization: "Google" });
    const b = makeOpp({ id: "b:2", source: "devpost", externalId: "2", title: "Google AI Challenge", organization: "Google" });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(2);
    // Also test similarity helper
    expect(titleSimilarity(normalizeText("Google Science Fair"), normalizeText("Google AI Challenge"))).toBeLessThan(0.9);
  });
});

describe("missing deadline not mismatch", () => {
  it("one has deadline, one null → do not treat as mismatch, but also not strong duplicate", () => {
    const a = makeOpp({
      id: "a:1",
      source: "studentSuite",
      externalId: "1",
      title: "Challenge",
      organization: "Org",
      deadline: "2026-06-25",
    });
    const b = makeOpp({
      id: "b:2",
      source: "scholarshipExtractor",
      externalId: "2",
      title: "Challenge",
      organization: "Org",
      deadline: null,
    });
    const res = deduplicateOpportunities([a, b]);
    // Same title+org but deadline unknown → medium confidence, should NOT merge per conservative rule
    expect(res.opportunities).toHaveLength(2);
  });
});

describe("different deadlines → separate", () => {
  it("same title/org but clearly different deadlines → two", () => {
    const a = makeOpp({ id: "a:1", source: "studentSuite", externalId: "1", title: "Challenge", organization: "Org", deadline: "2026-06-25" });
    const b = makeOpp({ id: "b:2", source: "devpost", externalId: "2", title: "Challenge", organization: "Org", deadline: "2026-06-30" });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(2);
  });
});

describe("merge fields", () => {
  it("useful non-conflicting data survives", () => {
    const a = makeOpp({
      id: "studentSuite:1",
      source: "studentSuite",
      externalId: "1",
      title: "Challenge",
      organization: "Org",
      deadline: "2026-06-25",
      description: "A",
      officialUrl: "https://example.com/a",
      subjects: ["physics"],
      topics: [],
    });
    const b = makeOpp({
      id: "devpost:2",
      source: "devpost",
      externalId: "2",
      title: "Challenge",
      organization: "Org",
      deadline: "2026-06-25",
      description: null,
      officialUrl: null,
      subjects: [],
      topics: ["AI"],
      eligibility: { minAge: 13, maxAge: 18, gradeMin: null, gradeMax: null, countries: null, geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null },
    });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(1);
    const merged = res.opportunities[0];
    expect(merged.description).toBe("A"); // never replace known with null
    expect(merged.topics).toContain("AI");
    expect(merged.subjects).toContain("physics");
    expect(merged.eligibility.minAge).toBe(13);
    expect((merged as any).sourceRecords).toEqual(
      expect.arrayContaining([
        { source: "studentSuite", externalId: "1" },
        { source: "devpost", externalId: "2" },
      ])
    );
  });
});

describe("array merging", () => {
  it("subjects/topics merge deduped case-insensitive", () => {
    const a = makeOpp({
      id: "a:1",
      source: "studentSuite",
      externalId: "1",
      title: "T",
      organization: "Org",
      deadline: "2026-01-01",
      subjects: ["AI", "physics"],
    });
    const b = makeOpp({
      id: "b:2",
      source: "devpost",
      externalId: "2",
      title: "T",
      organization: "Org",
      deadline: "2026-01-01",
      subjects: ["ai", "Math"],
    });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(1);
    expect(res.opportunities[0].subjects).toHaveLength(3); // AI (deduped), physics, Math
    expect(res.opportunities[0].subjects.map((s) => s.toLowerCase()).sort()).toEqual(["ai", "math", "physics"]);
  });
});

describe("URL normalization", () => {
  it("trailing slash and utm do not prevent match", () => {
    const a = makeOpp({
      id: "a:1",
      source: "studentSuite",
      externalId: "1",
      title: "X",
      officialUrl: "https://example.com/page/?utm_source=foo&utm_medium=bar&keep=1",
    });
    const b = makeOpp({
      id: "b:2",
      source: "devpost",
      externalId: "2",
      title: "Y Different Title",
      officialUrl: "https://example.com/page?keep=1",
    });
    const res = deduplicateOpportunities([a, b]);
    expect(res.opportunities).toHaveLength(1);
  });
});

describe("determinism", () => {
  it("same input → same output every time, order independent", () => {
    const a = makeOpp({ id: "studentSuite:1", source: "studentSuite", externalId: "1", title: "Challenge", organization: "Org", deadline: "2026-06-25" });
    const b = makeOpp({ id: "devpost:2", source: "devpost", externalId: "2", title: "Challenge", organization: "Org", deadline: "2026-06-25" });
    const r1 = deduplicateOpportunities([a, b]);
    const r2 = deduplicateOpportunities([b, a]);
    expect(r1.opportunities.map((o) => o.id)).toEqual(r2.opportunities.map((o) => o.id));
    expect(r1.duplicateGroups).toEqual(r2.duplicateGroups);
  });
});

describe("statistics", () => {
  it("returns correct counts", () => {
    const a = makeOpp({ id: "a:1", source: "studentSuite", externalId: "1", title: "A" });
    const b = makeOpp({ id: "a:1", source: "studentSuite", externalId: "1", title: "A dup" }); // same source+id
    const c = makeOpp({ id: "b:2", source: "devpost", externalId: "2", title: "B" });
    const res = deduplicateOpportunities([a, b, c]);
    expect(res.statistics.inputCount).toBe(3);
    expect(res.statistics.outputCount).toBe(2);
    expect(res.statistics.duplicateCount).toBe(1);
    expect(res.statistics.duplicateGroupCount).toBe(1);
    expect(res.statistics.bySource).toBeDefined();
  });
});

describe("normalizeText", () => {
  it("case, whitespace, punctuation", () => {
    expect(normalizeText("Breakthrough Junior Challenge")).toBe("breakthrough junior challenge");
    expect(normalizeText("  breakthrough   junior\tchallenge ")).toBe("breakthrough junior challenge");
    expect(normalizeText("Breakthrough & Junior")).toBe("breakthrough and junior");
  });
});
