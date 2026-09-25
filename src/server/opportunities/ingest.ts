#!/usr/bin/env node
// Phase 5.8 Opportunity Ingestion Script
// Fetches from all 5 sources → normalizers → deduplication → SQLite upsert

import { readFileSync } from "node:fs";
import { resolve } from "node:path";

// ---------------------------------------------------------------------------
// Load .env.local so APIFY_API_TOKEN / SCHOLARSHIP_FINDER_ACTOR_ID are set
// ---------------------------------------------------------------------------
function loadEnvLocal(): void {
  try {
    const raw = readFileSync(resolve(process.cwd(), ".env.local"), "utf-8");
    for (const line of raw.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eq = trimmed.indexOf("=");
      if (eq === -1) continue;
      const key = trimmed.slice(0, eq).trim();
      const value = trimmed.slice(eq + 1).trim();
      if (!process.env[key]) process.env[key] = value;
    }
  } catch {
    // .env.local missing — proceed with existing env
  }
}
loadEnvLocal();

// ---------------------------------------------------------------------------
// Imports (all extensionless — resolved by tsx / bundler moduleResolution)
// ---------------------------------------------------------------------------
import { StudentSuiteAdapter } from "./sources/studentSuite";
import { DevpostAdapter } from "./sources/devpost";
import { EventScraperAdapter } from "./sources/eventScraper";
import { ScholarshipExtractorAdapter } from "./sources/scholarshipExtractor";
import { ScholarshipFinderAdapter } from "./sources/scholarshipFinder";
import { normalizeOpportunity } from "./normalizers";
import { deduplicateOpportunities } from "./deduplication/deduplicate";
import { OpportunityRepository, getSharedDb } from "./storage";
import type { Opportunity } from "./models/opportunity";
import type { OpportunitySource } from "./sources/types";

// ---------------------------------------------------------------------------
// Per-source configuration (controlled limits for first ingestion)
// ---------------------------------------------------------------------------
interface SourceJob {
  name: OpportunitySource;
  fetch: () => Promise<{ data: unknown[]; fetchedAt: string }>;
}

function buildJobs(): SourceJob[] {
  const jobs: SourceJob[] = [];

  // 1. StudentSuite — direct HTTP, no auth
  const ss = new StudentSuiteAdapter();
  jobs.push({
    name: "studentSuite",
    fetch: () => ss.fetch({ limit: 50 }),
  });

  // 2. Devpost — Apify
  const devpost = new DevpostAdapter();
  jobs.push({
    name: "devpost",
    fetch: () => devpost.fetch({ maxResults: 20, status: "open" }),
  });

  // 3. Event Scraper — Apify
  const ev = new EventScraperAdapter();
  jobs.push({
    name: "eventScraper",
    fetch: () =>
      ev.fetch({
        maxResults: 10,
        keywords: ["student", "hackathon", "competition", "scholarship"],
        includeOnlineEvents: true,
      }),
  });

  // 4. Scholarship Extractor — Apify (requires category)
  const se = new ScholarshipExtractorAdapter();
  jobs.push({
    name: "scholarshipExtractor",
    fetch: () =>
      se.fetch({
        category: "Scholarships",
        maxItems: 20,
      }),
  });

  // 5. Scholarship Finder — Apify (disabled if SCHOLARSHIP_FINDER_ACTOR_ID missing)
  const sf = new ScholarshipFinderAdapter();
  jobs.push({
    name: "scholarshipFinder",
    fetch: () =>
      sf.fetch({
        keyword: "student",
        maxResults: "50",
        fetchDetails: false,
      }),
  });

  return jobs;
}

// ---------------------------------------------------------------------------
// Per-source stats
// ---------------------------------------------------------------------------
interface SourceResult {
  source: OpportunitySource;
  fetched: number;
  normalized: number;
  stored: number;
  error?: string;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main(): Promise<void> {
  const startTime = Date.now();
  console.log("╔══════════════════════════════════════════════╗");
  console.log("║   Phase 5.8 — Opportunity Ingestion         ║");
  console.log("╚══════════════════════════════════════════════╝\n");

  const repo = new OpportunityRepository(getSharedDb());
  const beforeCount = repo.count();
  console.log(`Database before ingestion: ${beforeCount} opportunities\n`);

  const jobs = buildJobs();
  const results: SourceResult[] = [];
  const allNormalized: Opportunity[] = [];

  // ---- Fetch + Normalize each source independently ----
  for (const job of jobs) {
    const result: SourceResult = {
      source: job.name,
      fetched: 0,
      normalized: 0,
      stored: 0,
    };

    console.log(`━━━ ${job.name} ━━━`);
    try {
      const raw = await job.fetch();
      result.fetched = raw.data.length;
      console.log(`  Fetched: ${result.fetched} records`);

      let normalizedCount = 0;
      let normalizeErrors = 0;

      for (const record of raw.data) {
        try {
          const opp = normalizeOpportunity(job.name, record, raw.fetchedAt);
          allNormalized.push(opp);
          normalizedCount++;
        } catch (e: any) {
          normalizeErrors++;
          if (normalizeErrors <= 3) {
            console.log(`  ⚠ Normalize error: ${e.message?.slice(0, 120)}`);
          }
        }
      }

      result.normalized = normalizedCount;
      console.log(`  Normalized: ${normalizedCount}${normalizeErrors > 0 ? ` (${normalizeErrors} errors)` : ""}`);
    } catch (e: any) {
      result.error = e.message;
      console.log(`  ✗ Failed: ${e.message?.slice(0, 200)}`);
    }

    results.push(result);
    console.log("");
  }

  // ---- Deduplicate across all sources ----
  console.log(`━━━ Deduplication ━━━`);
  console.log(`  Input opportunities: ${allNormalized.length}`);

  const dedupResult = deduplicateOpportunities(allNormalized);
  const deduped = dedupResult.opportunities;
  const dupGroups = dedupResult.duplicateGroups;
  const dupCount = dedupResult.statistics.duplicateCount;

  console.log(`  Duplicate groups: ${dupGroups.length}`);
  console.log(`  Duplicates removed: ${dupCount}`);
  console.log(`  After dedup: ${deduped.length}`);
  console.log("");

  // ---- Upsert into SQLite ----
  console.log(`━━━ SQLite Upsert ━━━`);
  const stored = repo.upsertOpportunities(deduped);
  console.log(`  Upserted: ${stored.length} records`);

  const afterCount = repo.count();
  console.log(`  Database after ingestion: ${afterCount} opportunities`);
  console.log("");

  // ---- Per-source breakdown in DB ----
  const bySource = new Map<string, number>();
  const allOpps = repo.getOpportunities();
  for (const opp of allOpps) {
    bySource.set(opp.source, (bySource.get(opp.source) || 0) + 1);
  }

  // ---- Final Report ----
  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log("╔══════════════════════════════════════════════╗");
  console.log("║   INGESTION REPORT                          ║");
  console.log("╚══════════════════════════════════════════════╝\n");

  for (const r of results) {
    const status = r.error ? `FAILED — ${r.error.slice(0, 100)}` : "OK";
    console.log(`  ${r.source}:`);
    console.log(`    Fetched:     ${r.fetched}`);
    console.log(`    Normalized:  ${r.normalized}`);
    console.log(`    Status:      ${status}`);
  }

  console.log("");
  console.log(`  Total before dedup:   ${allNormalized.length}`);
  console.log(`  Duplicates removed:   ${dupCount}`);
  console.log(`  Total stored:         ${stored.length}`);
  console.log(`  Active in DB:         ${afterCount}`);
  console.log("");

  console.log("  By source (in DB):");
  for (const [source, count] of bySource) {
    console.log(`    ${source}: ${count}`);
  }

  if (dupGroups.length > 0) {
    console.log("");
    console.log("  Duplicate groups:");
    for (const g of dupGroups.slice(0, 10)) {
      console.log(`    ${g.canonicalId} (${g.confidence}) — merged ${g.mergedIds.length} sources`);
    }
    if (dupGroups.length > 10) {
      console.log(`    ... and ${dupGroups.length - 10} more groups`);
    }
  }

  console.log(`\n  Completed in ${elapsed}s`);
}

main().catch((e) => {
  console.error("Fatal error:", e);
  process.exit(1);
});
