import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { createTestDb } from "../storage/db";
import { OpportunityRepository } from "../storage/repository";
import type { Opportunity } from "../models/opportunity";
import type { StorageDb } from "../storage/db";

function makeOpp(overrides: Partial<Opportunity> = {}): Opportunity {
  return {
    id: "studentSuite:test-1",
    source: "studentSuite",
    externalId: "test-1",
    title: "Test Opportunity",
    description: "Description",
    organization: "Org",
    officialUrl: "https://example.com",
    applicationUrl: "https://example.com/apply",
    sourceUrl: "https://example.com/source",
    category: "competition",
    sourceCategory: "STEM",
    subjects: ["physics"],
    topics: ["AI"],
    skills: ["Python"],
    deadline: "2026-10-01",
    startDate: null,
    endDate: null,
    location: { type: "online", city: null, state: null, country: null, online: true, latitude: null, longitude: null },
    cost: { amount: 0, currency: "USD", isFree: true },
    benefits: { awardText: "$1000", awardAmount: 1000, awardCurrency: "USD", prizeText: "$1000" },
    eligibility: { minAge: 13, maxAge: 18, gradeMin: null, gradeMax: null, countries: ["US"], geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null },
    provenance: { source: "studentSuite", externalId: "test-1", fetchedAt: "2026-09-12T00:00:00.000Z", sourceUpdatedAt: null },
    sourceMetadata: { originalCategory: "STEM" },
    ...overrides,
  } as Opportunity;
}

describe("Opportunity Storage", () => {
  let db: StorageDb;
  let repo: OpportunityRepository;

  beforeEach(() => {
    db = createTestDb();
    repo = new OpportunityRepository(db);
  });

  afterEach(() => {
    try {
      db.close();
    } catch {}
  });

  it("insert new opportunity → stored successfully", () => {
    const opp = makeOpp();
    const stored = repo.upsertOpportunity(opp);
    expect(stored.id).toBe(opp.id);
    expect(repo.count()).toBe(1);
  });

  it("read getById → same canonical data", () => {
    const opp = makeOpp({ title: "Original", description: "Desc", subjects: ["a", "b"] });
    repo.upsertOpportunity(opp);
    const fetched = repo.getOpportunityById(opp.id);
    expect(fetched).not.toBeNull();
    expect(fetched!.title).toBe("Original");
    expect(fetched!.subjects).toEqual(["a", "b"]);
    expect(fetched!.provenance.fetchedAt).toBe("2026-09-12T00:00:00.000Z");
  });

  it("update same ID deadline Oct1 → Oct5 → exactly one record, deadline Oct5", () => {
    const opp1 = makeOpp({ id: "studentSuite:update-test", externalId: "update-test", deadline: "2026-10-01" });
    repo.upsertOpportunity(opp1);
    expect(repo.getOpportunityById(opp1.id)!.deadline).toBe("2026-10-01");
    const opp2 = makeOpp({ id: "studentSuite:update-test", externalId: "update-test", deadline: "2026-10-05", title: "Updated Title" });
    repo.upsertOpportunity(opp2);
    expect(repo.count()).toBe(1);
    const fetched = repo.getOpportunityById(opp1.id)!;
    expect(fetched.deadline).toBe("2026-10-05");
    expect(fetched.title).toBe("Updated Title");
  });

  it("same source + externalId → no duplicate (upsert)", () => {
    const a = makeOpp({ id: "devpost:29377", source: "devpost", externalId: "29377", title: "A" });
    const b = makeOpp({ id: "devpost:29377", source: "devpost", externalId: "29377", title: "B" });
    repo.upsertOpportunity(a);
    repo.upsertOpportunity(b);
    expect(repo.count()).toBe(1);
    expect(repo.getOpportunityById(a.id)!.title).toBe("B");
  });

  it("different source + same externalId → allowed (different id)", () => {
    const a = makeOpp({ id: "studentSuite:123", source: "studentSuite", externalId: "123", title: "A" });
    const b = makeOpp({ id: "devpost:123", source: "devpost", externalId: "123", title: "B" });
    repo.upsertOpportunity(a);
    repo.upsertOpportunity(b);
    expect(repo.count()).toBe(2);
  });

  it("bulk upsert 100 opportunities → all stored", () => {
    const opps: Opportunity[] = Array.from({ length: 100 }, (_, i) =>
      makeOpp({ id: `studentSuite:bulk-${i}`, externalId: `bulk-${i}`, title: `Bulk ${i}` })
    );
    const results = repo.upsertOpportunities(opps);
    expect(results).toHaveLength(100);
    expect(repo.count()).toBe(100);
  });

  it("duplicate bulk input same opportunity twice → one final record", () => {
    const opp = makeOpp({ id: "studentSuite:dup", externalId: "dup", title: "First" });
    const dup = makeOpp({ id: "studentSuite:dup", externalId: "dup", title: "Second" });
    repo.upsertOpportunities([opp, dup]);
    expect(repo.count()).toBe(1);
    expect(repo.getOpportunityById(opp.id)!.title).toBe("Second"); // last wins deterministically
  });

  it("retrieval getOpportunityById, getOpportunities, getOpportunitiesBySource", () => {
    const a = makeOpp({ id: "studentSuite:a", source: "studentSuite", externalId: "a", title: "A" });
    const b = makeOpp({ id: "devpost:b", source: "devpost", externalId: "b", title: "B" });
    const c = makeOpp({ id: "studentSuite:c", source: "studentSuite", externalId: "c", title: "C" });
    repo.upsertOpportunities([a, b, c]);
    expect(repo.getOpportunityById("studentSuite:a")!.title).toBe("A");
    expect(repo.getOpportunities()).toHaveLength(3);
    const bySource = repo.getOpportunitiesBySource("studentSuite");
    expect(bySource).toHaveLength(2);
    expect(bySource.every((o) => o.source === "studentSuite")).toBe(true);
  });

  it("expired records remain stored", () => {
    const expired = makeOpp({ id: "studentSuite:expired", externalId: "expired", deadline: "2020-01-01", title: "Old" });
    repo.upsertOpportunity(expired);
    const fetched = repo.getOpportunityById(expired.id);
    expect(fetched).not.toBeNull();
    expect(fetched!.deadline).toBe("2020-01-01");
    // getOpportunities should still return it
    expect(repo.getOpportunities()).toHaveLength(1);
  });

  it("provenance survives serialization", () => {
    const opp = makeOpp({
      id: "studentSuite:prov",
      externalId: "prov",
      provenance: { source: "studentSuite", externalId: "prov", fetchedAt: "2026-09-01T00:00:00.000Z", sourceUpdatedAt: "2026-08-15T00:00:00.000Z" },
      sourceRecords: [
        { source: "studentSuite", externalId: "prov" },
        { source: "devpost", externalId: "999" },
      ],
    });
    repo.upsertOpportunity(opp);
    const fetched = repo.getOpportunityById(opp.id)!;
    expect(fetched.provenance.fetchedAt).toBe("2026-09-01T00:00:00.000Z");
    expect(fetched.provenance.sourceUpdatedAt).toBe("2026-08-15T00:00:00.000Z");
    expect(fetched.sourceRecords).toEqual([
      { source: "studentSuite", externalId: "prov" },
      { source: "devpost", externalId: "999" },
    ]);
  });

  it("nested normalized data preserved (subjects, location, cost, benefits, eligibility)", () => {
    const opp = makeOpp({
      subjects: ["physics", "AI"],
      topics: ["machine learning"],
      skills: ["Python"],
      location: { type: "online", city: null, state: null, country: "US", online: true, latitude: 37, longitude: -122 },
      cost: { amount: 0, currency: "USD", isFree: true },
      benefits: { awardText: "$500", awardAmount: 500, awardCurrency: "USD", prizeText: "$500" },
      eligibility: { minAge: 13, maxAge: 18, gradeMin: null, gradeMax: null, countries: ["US"], geographicRestrictions: "Texas", enrollmentLevels: ["high_school"], majors: ["CS"], requirements: null },
    });
    repo.upsertOpportunity(opp);
    const f = repo.getOpportunityById(opp.id)!;
    expect(f.subjects).toEqual(["physics", "AI"]);
    expect(f.location).toEqual({ type: "online", city: null, state: null, country: "US", online: true, latitude: 37, longitude: -122 });
    expect(f.cost).toEqual({ amount: 0, currency: "USD", isFree: true });
    expect(f.eligibility.countries).toEqual(["US"]);
  });

  it("student-specific data NOT permanently stored", () => {
    const opp = makeOpp();
    // Even if we add matchScore-like field to sourceMetadata, it should not be treated as student-specific? But canonical should not have matchScore
    // Ensure repo does not add matchScore
    repo.upsertOpportunity(opp);
    const fetched = repo.getOpportunityById(opp.id)!;
    expect((fetched as any).matchScore).toBeUndefined();
    expect((fetched as any).eligibilityStatus).toBeUndefined();
    expect((fetched as any).deadlineUrgency).toBeUndefined();
  });

  it("validation rejects malformed records", () => {
    const bad1 = makeOpp({ id: "" } as any);
    expect(() => repo.upsertOpportunity(bad1)).toThrow(/id is required/);
    const bad2 = makeOpp({ title: "" } as any);
    expect(() => repo.upsertOpportunity(bad2)).toThrow(/title is required/);
    const bad3 = makeOpp({ source: "" as any });
    expect(() => repo.upsertOpportunity(bad3)).toThrow(/source is required/);
  });

  it("bulk upsert validates and does not partially corrupt", () => {
    const good = makeOpp({ id: "studentSuite:good", externalId: "good", title: "Good" });
    const bad = makeOpp({ id: "", externalId: "", title: "" } as any);
    expect(() => repo.upsertOpportunities([good, bad as any])).toThrow();
    // Should have rolled back, no partial insert
    expect(repo.count()).toBe(0);
  });

  it("concurrent duplicate writes protected (unique constraint)", () => {
    const a = makeOpp({ id: "studentSuite:conc", externalId: "conc", title: "A" });
    const b = makeOpp({ id: "studentSuite:conc", externalId: "conc", title: "B" });
    // Simulate two concurrent upserts via bulk with duplicate
    repo.upsertOpportunities([a, b]);
    expect(repo.getOpportunityById(a.id)!.title).toBe("B");
    // Direct duplicate insert via upsert should not throw
    expect(() => repo.upsertOpportunity(a)).not.toThrow();
  });

  it("createdAt preserved on update, updatedAt changes", async () => {
    const opp = makeOpp({ id: "studentSuite:time", externalId: "time" });
    repo.upsertOpportunity(opp);
    const first = repo.getOpportunityById(opp.id)!;
    // Need to check created_at and updated_at via raw query
    const row1 = (db.prepare("SELECT created_at, updated_at FROM opportunities WHERE id = ?").get(opp.id) as any);
    expect(row1.created_at).toBeDefined();
    expect(row1.updated_at).toBeDefined();
    // Wait a bit to ensure updated_at changes
    await new Promise((r) => setTimeout(r, 10));
    const opp2 = makeOpp({ id: "studentSuite:time", externalId: "time", title: "Updated" });
    repo.upsertOpportunity(opp2);
    const row2 = (db.prepare("SELECT created_at, updated_at FROM opportunities WHERE id = ?").get(opp.id) as any);
    expect(row2.created_at).toBe(row1.created_at);
    expect(row2.updated_at).not.toBe(row1.updated_at);
  });

  it("freshness timestamps preserved", () => {
    const opp = makeOpp({
      provenance: { source: "studentSuite", externalId: "fresh", fetchedAt: "2026-09-12T00:00:00.000Z", sourceUpdatedAt: "2026-09-11T00:00:00.000Z" },
    });
    repo.upsertOpportunity({ ...opp, id: "studentSuite:fresh", externalId: "fresh" });
    const fetched = repo.getOpportunityById("studentSuite:fresh")!;
    expect(fetched.provenance.fetchedAt).toBe("2026-09-12T00:00:00.000Z");
    expect(fetched.provenance.sourceUpdatedAt).toBe("2026-09-11T00:00:00.000Z");
  });

  it("isolation: test db does not affect other tests (in-memory)", () => {
    expect(repo.count()).toBe(0); // fresh db per test
  });
});
