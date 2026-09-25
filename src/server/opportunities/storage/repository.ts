import type { Opportunity } from "../models/opportunity";
import type { StorageDb } from "./db";
import { getSharedDb } from "./db";

export interface OpportunityRow {
  id: string;
  source: string;
  external_id: string;
  title: string;
  description: string | null;
  organization: string | null;
  official_url: string | null;
  application_url: string | null;
  source_url: string | null;
  category: string | null;
  source_category: string | null;
  subjects: string;
  topics: string;
  skills: string;
  deadline: string | null;
  start_date: string | null;
  end_date: string | null;
  location: string;
  cost: string;
  benefits: string;
  eligibility: string;
  provenance: string;
  source_metadata: string;
  source_records: string | null;
  created_at: string;
  updated_at: string;
}

function nowIso(): string {
  return new Date().toISOString();
}

function validateOpportunity(opp: Opportunity): void {
  if (!opp.id || opp.id.trim() === "") throw new Error("Opportunity validation failed: id is required");
  if (!opp.source || String(opp.source).trim() === "") throw new Error("Opportunity validation failed: source is required");
  if (!opp.externalId || String(opp.externalId).trim() === "") throw new Error("Opportunity validation failed: externalId is required");
  if (!opp.title || opp.title.trim() === "") throw new Error("Opportunity validation failed: title is required");
}

function serializeOpportunity(opp: Opportunity, now: string, existingCreatedAt?: string | null): OpportunityRow {
  return {
    id: opp.id,
    source: opp.source,
    external_id: opp.externalId,
    title: opp.title,
    description: opp.description ?? null,
    organization: opp.organization ?? null,
    official_url: opp.officialUrl ?? null,
    application_url: opp.applicationUrl ?? null,
    source_url: opp.sourceUrl ?? null,
    category: opp.category ?? null,
    source_category: opp.sourceCategory ?? null,
    subjects: JSON.stringify(opp.subjects ?? []),
    topics: JSON.stringify(opp.topics ?? []),
    skills: JSON.stringify(opp.skills ?? []),
    deadline: opp.deadline ?? null,
    start_date: opp.startDate ?? null,
    end_date: opp.endDate ?? null,
    location: JSON.stringify(opp.location ?? { type: "unknown", city: null, state: null, country: null, online: null, latitude: null, longitude: null }),
    cost: JSON.stringify(opp.cost ?? { amount: null, currency: null, isFree: null }),
    benefits: JSON.stringify(opp.benefits ?? { awardText: null, awardAmount: null, awardCurrency: null, prizeText: null }),
    eligibility: JSON.stringify(opp.eligibility ?? { minAge: null, maxAge: null, gradeMin: null, gradeMax: null, countries: null, geographicRestrictions: null, enrollmentLevels: null, majors: null, requirements: null }),
    provenance: JSON.stringify(opp.provenance ?? { source: opp.source, externalId: opp.externalId, fetchedAt: now, sourceUpdatedAt: null }),
    source_metadata: JSON.stringify(opp.sourceMetadata ?? {}),
    source_records: opp.sourceRecords ? JSON.stringify(opp.sourceRecords) : null,
    created_at: existingCreatedAt ?? now,
    updated_at: now,
  };
}

function deserializeRow(row: OpportunityRow): Opportunity {
  return {
    id: row.id,
    source: row.source as Opportunity["source"],
    externalId: row.external_id,
    title: row.title,
    description: row.description,
    organization: row.organization,
    officialUrl: row.official_url,
    applicationUrl: row.application_url,
    sourceUrl: row.source_url,
    category: (row.category as Opportunity["category"]) ?? "other",
    sourceCategory: row.source_category,
    subjects: JSON.parse(row.subjects || "[]"),
    topics: JSON.parse(row.topics || "[]"),
    skills: JSON.parse(row.skills || "[]"),
    deadline: row.deadline,
    startDate: row.start_date,
    endDate: row.end_date,
    location: JSON.parse(row.location || "{}"),
    cost: JSON.parse(row.cost || "{}"),
    benefits: JSON.parse(row.benefits || "{}"),
    eligibility: JSON.parse(row.eligibility || "{}"),
    provenance: JSON.parse(row.provenance || "{}"),
    sourceMetadata: JSON.parse(row.source_metadata || "{}"),
    sourceRecords: row.source_records ? JSON.parse(row.source_records) : undefined,
  } as Opportunity;
}

export class OpportunityRepository {
  private db: StorageDb;

  constructor(db?: StorageDb) {
    this.db = db ?? getSharedDb();
  }

  upsertOpportunity(opp: Opportunity): Opportunity {
    validateOpportunity(opp);
    const now = nowIso();

    // Check existing created_at to preserve it
    const existing = this.db.prepare("SELECT created_at FROM opportunities WHERE id = ?").get(opp.id) as { created_at: string } | undefined;
    const row = serializeOpportunity(opp, now, existing?.created_at);

    const stmt = this.db.prepare(`
      INSERT INTO opportunities (
        id, source, external_id, title, description, organization,
        official_url, application_url, source_url, category, source_category,
        subjects, topics, skills, deadline, start_date, end_date,
        location, cost, benefits, eligibility, provenance, source_metadata, source_records,
        created_at, updated_at
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
      ON CONFLICT(id) DO UPDATE SET
        source=excluded.source,
        external_id=excluded.external_id,
        title=excluded.title,
        description=excluded.description,
        organization=excluded.organization,
        official_url=excluded.official_url,
        application_url=excluded.application_url,
        source_url=excluded.source_url,
        category=excluded.category,
        source_category=excluded.source_category,
        subjects=excluded.subjects,
        topics=excluded.topics,
        skills=excluded.skills,
        deadline=excluded.deadline,
        start_date=excluded.start_date,
        end_date=excluded.end_date,
        location=excluded.location,
        cost=excluded.cost,
        benefits=excluded.benefits,
        eligibility=excluded.eligibility,
        provenance=excluded.provenance,
        source_metadata=excluded.source_metadata,
        source_records=excluded.source_records,
        updated_at=excluded.updated_at
    `);

    // Use transaction for atomicity; better-sqlite style would be db.transaction
    // For node:sqlite, we use exec BEGIN/COMMIT
    try {
      this.db.exec("BEGIN");
      stmt.run(
        row.id,
        row.source,
        row.external_id,
        row.title,
        row.description,
        row.organization,
        row.official_url,
        row.application_url,
        row.source_url,
        row.category,
        row.source_category,
        row.subjects,
        row.topics,
        row.skills,
        row.deadline,
        row.start_date,
        row.end_date,
        row.location,
        row.cost,
        row.benefits,
        row.eligibility,
        row.provenance,
        row.source_metadata,
        row.source_records,
        row.created_at,
        row.updated_at
      );
      this.db.exec("COMMIT");
    } catch (e) {
      try {
        this.db.exec("ROLLBACK");
      } catch {}
      throw e;
    }

    return this.getOpportunityById(opp.id)!;
  }

  upsertOpportunities(opportunities: Opportunity[]): Opportunity[] {
    if (opportunities.length === 0) return [];
    // Validate all first to avoid partial corruption
    for (const opp of opportunities) validateOpportunity(opp);

    // Deduplicate input by id, keep last occurrence (deterministic)
    const byId = new Map<string, Opportunity>();
    for (const opp of opportunities) {
      byId.set(opp.id, opp);
    }
    const deduped = Array.from(byId.values());

    const results: Opportunity[] = [];
    try {
      this.db.exec("BEGIN");
      for (const opp of deduped) {
        const now = nowIso();
        const existing = this.db.prepare("SELECT created_at FROM opportunities WHERE id = ?").get(opp.id) as { created_at: string } | undefined;
        const row = serializeOpportunity(opp, now, existing?.created_at);
        const stmt = this.db.prepare(`
          INSERT INTO opportunities (
            id, source, external_id, title, description, organization,
            official_url, application_url, source_url, category, source_category,
            subjects, topics, skills, deadline, start_date, end_date,
            location, cost, benefits, eligibility, provenance, source_metadata, source_records,
            created_at, updated_at
          ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
          )
          ON CONFLICT(id) DO UPDATE SET
            source=excluded.source,
            external_id=excluded.external_id,
            title=excluded.title,
            description=excluded.description,
            organization=excluded.organization,
            official_url=excluded.official_url,
            application_url=excluded.application_url,
            source_url=excluded.source_url,
            category=excluded.category,
            source_category=excluded.source_category,
            subjects=excluded.subjects,
            topics=excluded.topics,
            skills=excluded.skills,
            deadline=excluded.deadline,
            start_date=excluded.start_date,
            end_date=excluded.end_date,
            location=excluded.location,
            cost=excluded.cost,
            benefits=excluded.benefits,
            eligibility=excluded.eligibility,
            provenance=excluded.provenance,
            source_metadata=excluded.source_metadata,
            source_records=excluded.source_records,
            updated_at=excluded.updated_at
        `);
        stmt.run(
          row.id,
          row.source,
          row.external_id,
          row.title,
          row.description,
          row.organization,
          row.official_url,
          row.application_url,
          row.source_url,
          row.category,
          row.source_category,
          row.subjects,
          row.topics,
          row.skills,
          row.deadline,
          row.start_date,
          row.end_date,
          row.location,
          row.cost,
          row.benefits,
          row.eligibility,
          row.provenance,
          row.source_metadata,
          row.source_records,
          row.created_at,
          row.updated_at
        );
      }
      this.db.exec("COMMIT");
    } catch (e) {
      try {
        this.db.exec("ROLLBACK");
      } catch {}
      throw e;
    }

    for (const opp of deduped) {
      const stored = this.getOpportunityById(opp.id);
      if (stored) results.push(stored);
    }
    return results;
  }

  getOpportunityById(id: string): Opportunity | null {
    const row = this.db.prepare("SELECT * FROM opportunities WHERE id = ?").get(id) as OpportunityRow | undefined;
    return row ? deserializeRow(row) : null;
  }

  getOpportunities(): Opportunity[] {
    const rows = this.db.prepare("SELECT * FROM opportunities ORDER BY id").all() as OpportunityRow[];
    return rows.map(deserializeRow);
  }

  getOpportunitiesBySource(source: string): Opportunity[] {
    const rows = this.db.prepare("SELECT * FROM opportunities WHERE source = ? ORDER BY id").all(source) as OpportunityRow[];
    return rows.map(deserializeRow);
  }

  // Basic filtering for future API (active/non-expired, source, category)
  getOpportunitiesFiltered(filters: {
    source?: string;
    category?: string;
    onlyActive?: boolean;
    asOf?: Date;
  } = {}): Opportunity[] {
    let query = "SELECT * FROM opportunities WHERE 1=1";
    const params: any[] = [];
    if (filters.source) {
      query += " AND source = ?";
      params.push(filters.source);
    }
    if (filters.category) {
      query += " AND category = ?";
      params.push(filters.category);
    }
    // Note: active/non-expired filtering requires freshness evaluation; for storage layer, we only support simple deadline > asOf
    // But spec says do not build full Explore filtering yet, keep basic. So we handle only source/category here.
    // If onlyActive is true, caller can filter via freshness engine separately; we provide hook but not full logic
    query += " ORDER BY id";
    const rows = this.db.prepare(query).all(...params) as OpportunityRow[];
    let opps = rows.map(deserializeRow);
    if (filters.onlyActive && filters.asOf) {
      // Simple deadline filter: deadline is null or deadline >= asOf (date-only UTC)
      const asOfDate = new Date(Date.UTC(filters.asOf.getUTCFullYear(), filters.asOf.getUTCMonth(), filters.asOf.getUTCDate()));
      opps = opps.filter((o) => {
        if (!o.deadline) return true; // unknown treated as active for storage retrieval; API will handle
        const d = new Date(o.deadline);
        if (isNaN(d.getTime())) return true;
        const dd = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
        return dd >= asOfDate;
      });
    }
    return opps;
  }

  clearAll(): void {
    this.db.exec("DELETE FROM opportunities");
  }

  count(): number {
    const row = this.db.prepare("SELECT COUNT(*) as cnt FROM opportunities").get() as { cnt: number };
    return row.cnt;
  }
}
