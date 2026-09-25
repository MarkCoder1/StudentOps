import { describe, it, expect } from "vitest";
import { evaluateFreshness, evaluateFreshnessBatch } from "../freshness/evaluate";
import type { Opportunity } from "../models/opportunity";

function makeOpp(overrides: Partial<Opportunity> = {}): Opportunity {
  return {
    id: "test:1",
    source: "studentSuite",
    externalId: "1",
    title: "Test",
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
    provenance: { source: "studentSuite", externalId: "1", fetchedAt: "2026-09-10T00:00:00.000Z", sourceUpdatedAt: null },
    sourceMetadata: {},
    ...overrides,
  } as Opportunity;
}

const asOf = (iso: string) => new Date(iso);

describe("Freshness — deadline", () => {
  it("asOf 2026-09-12 deadline 2026-09-20 → active 8 days urgency upcoming", () => {
    const opp = makeOpp({ deadline: "2026-09-20" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("active");
    expect(r.daysUntilDeadline).toBe(8);
    expect(r.daysSinceDeadline).toBeNull();
    expect(r.deadlineUrgency).toBe("upcoming");
    expect(r.reason).toMatch(/8 days/);
  });

  it("deadline passed → expired 2 days since", () => {
    const opp = makeOpp({ deadline: "2026-09-10" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("expired");
    expect(r.daysSinceDeadline).toBe(2);
    expect(r.daysUntilDeadline).toBeNull();
    expect(r.deadlineUrgency).toBe("none");
    expect(r.reason).toMatch(/passed/);
  });

  it("deadline same day → active 0 days", () => {
    const opp = makeOpp({ deadline: "2026-09-12" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T12:00:00.000Z"));
    expect(r.status).toBe("active");
    expect(r.daysUntilDeadline).toBe(0);
    expect(r.deadlineUrgency).toBe("urgent");
  });

  it("deadline controls over event dates", () => {
    const opp = makeOpp({ deadline: "2026-10-01", startDate: "2026-11-15" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("active");
    expect(r.daysUntilDeadline).toBe(19);
  });
});

describe("Freshness — event", () => {
  it("startDate future → upcoming", () => {
    const opp = makeOpp({ startDate: "2026-10-01T00:00:00.000Z" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("upcoming");
    expect(r.daysUntilStart).toBe(19);
  });

  it("between start and end → active", () => {
    const opp = makeOpp({ startDate: "2026-09-10T00:00:00.000Z", endDate: "2026-09-15T00:00:00.000Z" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("active");
    expect(r.reason).toMatch(/in progress/);
  });

  it("after end → expired", () => {
    const opp = makeOpp({ startDate: "2026-09-01T00:00:00.000Z", endDate: "2026-09-05T00:00:00.000Z" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("expired");
  });

  it("one-time event passed start no end → expired", () => {
    const opp = makeOpp({ startDate: "2026-09-01T00:00:00.000Z" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("expired");
  });

  it("one-time event starts today no end → active", () => {
    const opp = makeOpp({ startDate: "2026-09-12T00:00:00.000Z" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("active");
  });
});

describe("Freshness — missing data", () => {
  it("no dates → unknown", () => {
    const opp = makeOpp({});
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("unknown");
    expect(r.reason).toMatch(/No deadline/);
  });
});

describe("Freshness — staleness", () => {
  it("fetched 2 days ago → fresh", () => {
    const opp = makeOpp({ provenance: { source: "studentSuite", externalId: "1", fetchedAt: "2026-09-10T00:00:00.000Z", sourceUpdatedAt: null } });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.dataFreshness).toBe("fresh");
  });

  it("fetched 10 days ago → stale", () => {
    const opp = makeOpp({ provenance: { source: "studentSuite", externalId: "1", fetchedAt: "2026-09-02T00:00:00.000Z", sourceUpdatedAt: null } });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.dataFreshness).toBe("stale");
  });

  it("fetchedAt null → unknown", () => {
    const opp = makeOpp({ provenance: { source: "studentSuite", externalId: "1", fetchedAt: null as any, sourceUpdatedAt: null } });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.dataFreshness).toBe("unknown");
  });

  it("active + stale separate", () => {
    const opp = makeOpp({
      deadline: "2026-09-20",
      provenance: { source: "studentSuite", externalId: "1", fetchedAt: "2026-08-01T00:00:00.000Z", sourceUpdatedAt: null },
    });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("active");
    expect(r.dataFreshness).toBe("stale");
  });
});

describe("Urgency", () => {
  it("0-3 → urgent", () => {
    expect(evaluateFreshness(makeOpp({ deadline: "2026-09-12" }), asOf("2026-09-12T00:00:00.000Z")).deadlineUrgency).toBe("urgent");
    expect(evaluateFreshness(makeOpp({ deadline: "2026-09-15" }), asOf("2026-09-12T00:00:00.000Z")).deadlineUrgency).toBe("urgent");
  });
  it("4-7 → soon", () => {
    expect(evaluateFreshness(makeOpp({ deadline: "2026-09-16" }), asOf("2026-09-12T00:00:00.000Z")).deadlineUrgency).toBe("soon");
    expect(evaluateFreshness(makeOpp({ deadline: "2026-09-19" }), asOf("2026-09-12T00:00:00.000Z")).deadlineUrgency).toBe("soon");
  });
  it("8-30 → upcoming", () => {
    expect(evaluateFreshness(makeOpp({ deadline: "2026-09-20" }), asOf("2026-09-12T00:00:00.000Z")).deadlineUrgency).toBe("upcoming");
  });
  it("31+ → later", () => {
    expect(evaluateFreshness(makeOpp({ deadline: "2026-10-20" }), asOf("2026-09-12T00:00:00.000Z")).deadlineUrgency).toBe("later");
  });
  it("no deadline → none", () => {
    expect(evaluateFreshness(makeOpp({}), asOf("2026-09-12T00:00:00.000Z")).deadlineUrgency).toBe("none");
  });
  it("expired → none", () => {
    expect(evaluateFreshness(makeOpp({ deadline: "2026-09-10" }), asOf("2026-09-12T00:00:00.000Z")).deadlineUrgency).toBe("none");
  });
});

describe("Invalid date", () => {
  it("invalid deadline → unknown no crash", () => {
    const opp = makeOpp({ deadline: "not-a-date" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.status).toBe("unknown");
    expect(r.deadline).toBeNull();
  });
});

describe("Determinism", () => {
  it("same opp + asOf → same result", () => {
    const opp = makeOpp({ deadline: "2026-09-20" });
    const a = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    const b = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(a).toEqual(b);
  });
});

describe("Explicit asOf", () => {
  it("does not use Date.now", () => {
    const opp = makeOpp({ deadline: "2026-09-20" });
    const r1 = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    const r2 = evaluateFreshness(opp, asOf("2026-09-19T00:00:00.000Z"));
    expect(r1.daysUntilDeadline).toBe(8);
    expect(r2.daysUntilDeadline).toBe(1);
    expect(r1.status).not.toBe(r2.status === "expired" ? "active" : "expired"); // just ensure different asOf gives different
  });
});

describe("No mutation", () => {
  it("does not modify opportunity", () => {
    const opp = makeOpp({ deadline: "2026-09-20" });
    const copy = JSON.parse(JSON.stringify(opp));
    evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(opp).toEqual(copy);
  });
});

describe("Batch", () => {
  it("preserves order, no sort", () => {
    const opps = [makeOpp({ id: "b:2", deadline: "2026-09-20" }), makeOpp({ id: "a:1", deadline: "2026-09-10" })];
    const res = evaluateFreshnessBatch(opps, asOf("2026-09-12T00:00:00.000Z"));
    expect(res[0].opportunity.id).toBe("b:2");
    expect(res[1].opportunity.id).toBe("a:1");
  });
});

describe("Reason explainability", () => {
  it("has concise reason", () => {
    const opp = makeOpp({ deadline: "2026-09-20" });
    const r = evaluateFreshness(opp, asOf("2026-09-12T00:00:00.000Z"));
    expect(r.reason.length).toBeGreaterThan(5);
  });
});
