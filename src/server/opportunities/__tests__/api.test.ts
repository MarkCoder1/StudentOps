import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { createTestDb } from "../storage/db";
import { OpportunityRepository } from "../storage/repository";
import { OpportunityService } from "../service";
import type { Opportunity } from "../models/opportunity";
import type { StorageDb } from "../storage/db";

function makeOpp(overrides: Partial<Opportunity> = {}): Opportunity {
  const id = overrides.id ?? `test:${Math.random().toString(36).slice(2, 8)}`;
  const source = (overrides.source as any) ?? "studentSuite";
  const externalId = overrides.externalId ?? id.split(":")[1] ?? "1";
  return {
    id,
    source,
    externalId,
    title: "Test Opportunity",
    description: "Description",
    organization: "Org",
    officialUrl: "https://example.com",
    applicationUrl: "https://example.com/apply",
    sourceUrl: "https://example.com/source",
    category: "competition",
    sourceCategory: "STEM",
    subjects: ["AI"],
    topics: ["AI"],
    skills: ["Python"],
    deadline: "2099-12-31",
    startDate: null,
    endDate: null,
    location: { type: "online", city: null, state: null, country: null, online: true, latitude: null, longitude: null },
    cost: { amount: 0, currency: "USD", isFree: true },
    benefits: { awardText: "$1000", awardAmount: 1000, awardCurrency: "USD", prizeText: "$1000" },
    eligibility: { minAge: null, maxAge: null, gradeMin: null, gradeMax: null, countries: null, geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null },
    provenance: { source, externalId, fetchedAt: "2026-09-12T00:00:00.000Z", sourceUpdatedAt: null },
    sourceMetadata: {},
    ...overrides,
  } as Opportunity;
}

describe("API Service — OpportunityService", () => {
  let db: StorageDb;
  let repo: OpportunityRepository;
  let service: OpportunityService;

  beforeEach(() => {
    db = createTestDb();
    repo = new OpportunityRepository(db);
    service = new OpportunityService(repo);
  });

  afterEach(() => {
    try {
      db.close();
    } catch {}
    vi.restoreAllMocks();
  });

  it("GET /api/opportunities → 200 correct shape empty", () => {
    const result = service.getOpportunities();
    expect(result.data).toEqual([]);
    expect(result.pagination).toEqual({ limit: 50, offset: 0, total: 0 });
  });

  it("pagination limit=10 offset=0 → max 10", () => {
    const opps = Array.from({ length: 15 }, (_, i) => makeOpp({ id: `test:${i}`, externalId: `${i}`, title: `Opp ${i}` }));
    repo.upsertOpportunities(opps);
    const result = service.getOpportunities({ limit: 10, offset: 0 });
    expect(result.data).toHaveLength(10);
    expect(result.pagination.limit).toBe(10);
    expect(result.pagination.offset).toBe(0);
    expect(result.pagination.total).toBe(15);
  });

  it("limit 1000 → capped at 100", () => {
    const opps = Array.from({ length: 150 }, (_, i) => makeOpp({ id: `test:${i}`, externalId: `${i}` }));
    repo.upsertOpportunities(opps);
    const result = service.getOpportunities({ limit: 1000 } as any);
    expect(result.pagination.limit).toBe(100);
    expect(result.data).toHaveLength(100);
    expect(result.pagination.total).toBe(150);
  });

  it("invalid limit -1 → 400", () => {
    expect(() => service.getOpportunities({ limit: -1 })).toThrow();
    try {
      service.getOpportunities({ limit: -1 });
    } catch (e: any) {
      expect(e.statusCode).toBe(400);
      expect(e.code).toBe("INVALID_LIMIT");
    }
  });

  it("invalid offset -1 → 400", () => {
    expect(() => service.getOpportunities({ offset: -1 })).toThrow();
    try {
      service.getOpportunities({ offset: -1 });
    } catch (e: any) {
      expect(e.statusCode).toBe(400);
    }
  });

  it("invalid onlyActive=banana → 400", () => {
    expect(() => service.getOpportunities({ onlyActive: "banana" as any })).toThrow();
    try {
      service.getOpportunities({ onlyActive: "banana" as any });
    } catch (e: any) {
      expect(e.statusCode).toBe(400);
      expect(e.code).toBe("INVALID_ONLYACTIVE");
    }
  });

  it("source filter studentsuite → only StudentSuite", () => {
    repo.upsertOpportunities([
      makeOpp({ id: "studentSuite:1", source: "studentSuite", externalId: "1" }),
      makeOpp({ id: "devpost:2", source: "devpost", externalId: "2" }),
    ]);
    const result = service.getOpportunities({ source: "studentSuite" });
    expect(result.data).toHaveLength(1);
    expect(result.data[0].source).toBe("studentSuite");
  });

  it("invalid source → 400", () => {
    expect(() => service.getOpportunities({ source: "not-a-real-source" })).toThrow();
    try {
      service.getOpportunities({ source: "not-a-real-source" });
    } catch (e: any) {
      expect(e.statusCode).toBe(400);
      expect(e.code).toBe("INVALID_SOURCE");
    }
  });

  it("category filter", () => {
    repo.upsertOpportunities([
      makeOpp({ id: "a:1", source: "studentSuite", externalId: "1", category: "competition" }),
      makeOpp({ id: "b:2", source: "studentSuite", externalId: "2", category: "hackathon" }),
    ]);
    const result = service.getOpportunities({ category: "hackathon" });
    expect(result.data).toHaveLength(1);
    expect(result.data[0].category).toBe("hackathon");
  });

  it("invalid category → 400", () => {
    expect(() => service.getOpportunities({ category: "invalid-cat" as any })).toThrow();
  });

  it("onlyActive=true → expired excluded", () => {
    const asOf = new Date("2026-09-12T00:00:00.000Z");
    const active = makeOpp({ id: "a:1", source: "studentSuite", externalId: "1", deadline: "2099-12-31" });
    const expired = makeOpp({ id: "b:2", source: "studentSuite", externalId: "2", deadline: "2020-01-01" });
    repo.upsertOpportunities([active, expired]);
    const result = service.getOpportunities({ onlyActive: true, asOf });
    expect(result.data).toHaveLength(1);
    expect(result.data[0].id).toBe("a:1");
    expect(result.pagination.total).toBe(1);
  });

  it("onlyActive uses explicit asOf, not hidden Date.now", () => {
    const asOf = new Date("2026-09-12T00:00:00.000Z");
    const opp = makeOpp({ id: "a:1", source: "studentSuite", externalId: "1", deadline: "2026-09-12" });
    repo.upsertOpportunity(opp);
    // deadline same day as asOf → active (0 days)
    const r1 = service.getOpportunities({ onlyActive: true, asOf: new Date("2026-09-12T00:00:00.000Z") });
    expect(r1.data).toHaveLength(1);
    const r2 = service.getOpportunities({ onlyActive: true, asOf: new Date("2026-09-13T00:00:00.000Z") });
    expect(r2.data).toHaveLength(0);
  });

  it("getOpportunityById → 200 correct", () => {
    const opp = makeOpp({ id: "studentSuite:abc123", source: "studentSuite", externalId: "abc123", title: "Found" });
    repo.upsertOpportunity(opp);
    const fetched = service.getOpportunityById("studentSuite:abc123");
    expect(fetched).not.toBeNull();
    expect(fetched!.title).toBe("Found");
  });

  it("getOpportunityById missing → null", () => {
    const fetched = service.getOpportunityById("missing:id");
    expect(fetched).toBeNull();
  });

  it("getOpportunityById with colon/slash → handled", () => {
    const opp = makeOpp({ id: "studentSuite:abc/def-123_456", source: "studentSuite", externalId: "abc/def-123_456" });
    repo.upsertOpportunity(opp);
    const fetched = service.getOpportunityById("studentSuite:abc/def-123_456");
    expect(fetched).not.toBeNull();
  });

  it("nested serialization correct", () => {
    const opp = makeOpp({
      id: "a:1",
      source: "studentSuite",
      externalId: "1",
      subjects: ["AI"],
      topics: ["ML"],
      skills: ["Python"],
      location: { type: "online", city: "Berlin", state: null, country: "DE", online: true, latitude: 52, longitude: 13 },
      cost: { amount: 0, currency: "USD", isFree: true },
      benefits: { awardText: "$100", awardAmount: 100, awardCurrency: "USD", prizeText: "$100" },
      eligibility: { minAge: 13, maxAge: 18, gradeMin: null, gradeMax: null, countries: ["US"], geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null },
      provenance: { source: "studentSuite", externalId: "1", fetchedAt: "2026-09-12T00:00:00.000Z", sourceUpdatedAt: "2026-09-10T00:00:00.000Z" },
      sourceMetadata: { extra: "value" },
    });
    repo.upsertOpportunity(opp);
    const fetched = service.getOpportunityById("a:1")!;
    expect(Array.isArray(fetched.subjects)).toBe(true);
    expect(typeof fetched.location).toBe("object");
    expect(Array.isArray(fetched.topics)).toBe(true);
    expect(typeof fetched.cost).toBe("object");
    expect(typeof fetched.benefits).toBe("object");
    expect(typeof fetched.eligibility).toBe("object");
    expect(typeof fetched.provenance).toBe("object");
    // Ensure not JSON strings
    expect(typeof fetched.subjects).not.toBe("string");
  });

  it("does not store student-specific matching", () => {
    const opp = makeOpp({ id: "a:1", source: "studentSuite", externalId: "1" });
    repo.upsertOpportunity(opp);
    const fetched = service.getOpportunityById("a:1") as any;
    expect(fetched.matchScore).toBeUndefined();
    expect(fetched.eligibilityStatus).toBeUndefined();
    expect(fetched.deadlineUrgency).toBeUndefined();
  });

  it("no external source calls during getOpportunities", async () => {
    // Ensure service does not call fetch
    const spy = vi.spyOn(globalThis, "fetch");
    repo.upsertOpportunity(makeOpp({ id: "a:1", source: "studentSuite", externalId: "1" }));
    service.getOpportunities({ limit: 10 });
    service.getOpportunityById("a:1");
    expect(spy).not.toHaveBeenCalled();
    spy.mockRestore();
  });

  it("pagination total is filtered total, not DB total", () => {
    repo.upsertOpportunities([
      makeOpp({ id: "a:1", source: "studentSuite", externalId: "1", category: "competition" }),
      makeOpp({ id: "b:2", source: "studentSuite", externalId: "2", category: "hackathon" }),
      makeOpp({ id: "c:3", source: "devpost", externalId: "3", category: "competition" }),
    ]);
    const result = service.getOpportunities({ source: "studentSuite", limit: 10 });
    expect(result.pagination.total).toBe(2);
    expect(result.data).toHaveLength(2);
  });
});

// Route-level checks — verify route files exist and are read-only (no SQL)
// We avoid importing Next.js route handlers directly in this environment to keep vitest simple;
// Service tests above already cover 95% of route logic (validation, pagination, filtering, 404).
import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

describe("API Routes — files and read-only checks", () => {
  it("GET /api/opportunities route exists and is thin (no SQL)", () => {
    const p = resolve("./src/app/api/opportunities/route.ts");
    expect(existsSync(p)).toBe(true);
    const content = readFileSync(p, "utf8");
    expect(content).toContain("getOpportunityService");
    expect(content).not.toMatch(/SELECT|INSERT|UPDATE|DELETE/i);
    expect(content).toContain('export const dynamic = "force-dynamic"');
  });

  it("GET /api/opportunities/[id] route exists and handles colon IDs", () => {
    const p = resolve("./src/app/api/opportunities/[id]/route.ts");
    expect(existsSync(p)).toBe(true);
    const content = readFileSync(p, "utf8");
    expect(content).toContain("decodeURIComponent");
    expect(content).toContain("OPPORTUNITY_NOT_FOUND");
    expect(content).not.toMatch(/SELECT|INSERT/i);
  });

  it("Routes are read-only (only GET)", () => {
    const list = readFileSync(resolve("./src/app/api/opportunities/route.ts"), "utf8");
    const detail = readFileSync(resolve("./src/app/api/opportunities/[id]/route.ts"), "utf8");
    expect(list).toContain("export async function GET");
    expect(list).not.toContain("export async function POST");
    expect(list).not.toContain("export async function PUT");
    expect(detail).toContain("export async function GET");
    expect(detail).not.toContain("export async function POST");
  });
});
