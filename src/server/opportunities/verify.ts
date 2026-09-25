import { StudentSuiteAdapter } from "./sources/studentSuite";
import { DevpostAdapter } from "./sources/devpost";
import { EventScraperAdapter } from "./sources/eventScraper";
import { ScholarshipExtractorAdapter } from "./sources/scholarshipExtractor";
import { ScholarshipFinderAdapter } from "./sources/scholarshipFinder";

function describeFields(record: any): { name: string; type: string; valuePreview: string }[] {
  if (!record || typeof record !== "object") return [];
  return Object.entries(record).map(([k, v]) => {
    let t = Array.isArray(v) ? `array[${(v as any[]).length}]` : v === null ? "null" : typeof v;
    if (t === "object" && v !== null) {
      const keys = Object.keys(v as any).slice(0, 3).join(",");
      t = `object{${keys}${Object.keys(v as any).length > 3 ? ",…" : ""}}`;
    }
    let preview = "";
    try {
      if (Array.isArray(v)) preview = JSON.stringify(v.slice(0, 2));
      else if (typeof v === "object" && v !== null) preview = JSON.stringify(v).slice(0, 120);
      else preview = String(v).slice(0, 80);
    } catch {}
    return { name: k, type: t, valuePreview: preview };
  });
}

function rawShape(data: any, rawResponse: any): string {
  if (Array.isArray(rawResponse)) return `array[${rawResponse.length}] (dataset items)`;
  if (rawResponse && typeof rawResponse === "object") {
    const keys = Object.keys(rawResponse).join(",");
    if ("data" in rawResponse) return `object{data:array,total,limit,offset} — keys: ${keys}`;
    return `object{${keys}}`;
  }
  return typeof rawResponse;
}

async function verifyStudentSuite() {
  console.log("\n=== 1. StudentSuite (https://studyymap.com/api/competitions) ===");
  const adapter = new StudentSuiteAdapter();
  try {
    const result = await adapter.fetch({ limit: 2 });
    console.log(`HTTP: success (200)`);
    console.log(`Records: ${result.data.length} (total: ${result.total ?? "n/a"}, limit: ${(result.meta as any)?.limit}, offset: ${(result.meta as any)?.offset})`);
    console.log(`Raw shape: ${rawShape(result.data, result.rawResponse)}`);
    if (result.data.length > 0) {
      const fields = describeFields(result.data[0]);
      console.log(`Fields in representative record (${fields.length}):`);
      for (const f of fields) console.log(`  - ${f.name}: ${f.type} — ${f.valuePreview}`);
      // Check inconsistency
      const second = result.data[1] ? describeFields(result.data[1]) : [];
      const firstNames = new Set(fields.map((f) => f.name));
      const missing = second.filter((f) => !firstNames.has(f.name)).map((f) => f.name);
      const extra = fields.filter((f) => !second.some((s) => s.name === f.name)).map((f) => f.name);
      if (missing.length || extra.length) console.log(`Inconsistent fields vs record 2: missing in first: ${missing.join(",") || "none"}, extra in first: ${extra.join(",") || "none"}`);
      else console.log(`Consistency: first 2 records share same field set (${fields.length} fields)`);
      // Check key expected fields
      const expected = ["id", "name", "category", "format", "region", "fee", "dates"];
      const absent = expected.filter((k) => !(result.data[0] as any)[k]);
      if (absent.length) console.log(`Missing expected fields: ${absent.join(",")}`);
    }
  } catch (e: any) {
    console.log(`HTTP: failure — ${e.message} (status: ${e.statusCode ?? "n/a"})`);
    console.log(`Error: ${e.name}`);
  }
}

async function verifyDevpost() {
  console.log("\n=== 2. Devpost (automation-lab/devpost-scraper via Apify) ===");
  const token = process.env.APIFY_API_TOKEN;
  const hasToken = !!token && token !== "your_apify_token_here" && token.trim() !== "";
  console.log(`Token configured: ${hasToken ? "yes (masked)" : "no — placeholder/missing"}`);
  if (!hasToken) console.log(`Expected: adapter will attempt Apify with placeholder and receive 401, or throw 401 pre-check if empty`);
  const adapter = new DevpostAdapter();
  try {
    const result = await adapter.fetch({ searchQuery: "", maxResults: 2 });
    console.log(`HTTP: success`);
    console.log(`Records: ${result.data.length}`);
    console.log(`Raw shape: ${rawShape(result.data, result.rawResponse)}`);
    if (result.data.length > 0) {
      const fields = describeFields(result.data[0]);
      console.log(`Fields:`);
      for (const f of fields) console.log(`  - ${f.name}: ${f.type}`);
    }
  } catch (e: any) {
    console.log(`HTTP: failure — ${e.message} (status: ${e.statusCode ?? "n/a"}, source: ${e.source})`);
    if (e.cause) console.log(`Cause preview: ${JSON.stringify(e.cause).slice(0, 300)}`);
  }
}

async function verifyEventScraper() {
  console.log("\n=== 3. Event Scraper Pro (webdatalabs/event-scraper-pro) ===");
  const token = process.env.APIFY_API_TOKEN;
  const hasToken = !!token && token !== "your_apify_token_here" && token.trim() !== "";
  console.log(`Token configured: ${hasToken ? "yes" : "no"}`);
  const adapter = new EventScraperAdapter();
  try {
    const result = await adapter.fetch({ keywords: ["ai"], cities: ["Berlin"], country: "DE", maxResults: 2 });
    console.log(`HTTP: success`);
    console.log(`Records: ${result.data.length}`);
    console.log(`Raw shape: ${rawShape(result.data, result.rawResponse)}`);
    if (result.data.length > 0) {
      const fields = describeFields(result.data[0]);
      console.log(`Fields:`);
      for (const f of fields) console.log(`  - ${f.name}: ${f.type} — ${f.valuePreview.slice(0,80)}`);
    }
  } catch (e: any) {
    console.log(`HTTP: failure — ${e.message} (status: ${e.statusCode ?? "n/a"})`);
    if (e.cause) console.log(`Cause preview: ${JSON.stringify(e.cause).slice(0,300)}`);
  }
}

async function verifyScholarshipExtractor() {
  console.log("\n=== 4. Scholarship/Competitions/Internships Extractor (saadithya/...) ===");
  const token = process.env.APIFY_API_TOKEN;
  const hasToken = !!token && token !== "your_apify_token_here" && token.trim() !== "";
  console.log(`Token configured: ${hasToken ? "yes" : "no"}`);
  const adapter = new ScholarshipExtractorAdapter();
  try {
    const result = await adapter.fetch({ category: "Scholarships", maxItems: 2 });
    console.log(`HTTP: success`);
    console.log(`Records: ${result.data.length}`);
    console.log(`Raw shape: ${rawShape(result.data, result.rawResponse)}`);
    if (result.data.length > 0) {
      const fields = describeFields(result.data[0]);
      console.log(`Fields:`);
      for (const f of fields) console.log(`  - ${f.name}: ${f.type} — ${f.valuePreview.slice(0,80)}`);
    }
  } catch (e: any) {
    console.log(`HTTP: failure — ${e.message} (status: ${e.statusCode ?? "n/a"})`);
    if (e.cause) console.log(`Cause: ${JSON.stringify(e.cause).slice(0,300)}`);
  }
}

async function verifyScholarshipFinder() {
  console.log("\n=== 5. Scholarship Finder (CollegeScholarships.org) ===");
  const actor = process.env.SCHOLARSHIP_FINDER_ACTOR_ID;
  const token = process.env.APIFY_API_TOKEN;
  console.log(`Actor ID configured: ${actor ? "yes" : "no — placeholder expected"}`);
  console.log(`Token configured: ${!!token && token !== "your_apify_token_here" ? "yes" : "no"}`);
  const adapter = new ScholarshipFinderAdapter();
  console.log(`Adapter isConfigured: ${adapter.isConfigured} (actorId: ${adapter.actorId ?? "null"})`);
  if (!adapter.isConfigured) {
    console.log(`Expected: adapter disabled, fetch should throw 501 without network`);
    try {
      await adapter.fetch({ keyword: "engineering", maxResults: "50" });
    } catch (e: any) {
      console.log(`HTTP: not attempted — ${e.message} (status: ${e.statusCode})`);
    }
    return;
  }
  try {
    const result = await adapter.fetch({ keyword: "engineering", maxResults: "50" });
    console.log(`HTTP: success`);
    console.log(`Records: ${result.data.length}`);
    console.log(`Raw shape: ${rawShape(result.data, result.rawResponse)}`);
  } catch (e: any) {
    console.log(`HTTP: failure — ${e.message} (status: ${e.statusCode})`);
  }
}

async function main() {
  console.log("=== Phase 5.1 Adapter Verification ===");
  console.log(`Time: ${new Date().toISOString()}`);
  console.log(`Node: ${process.version} — adapters are server-side only, token never logged`);
  await verifyStudentSuite();
  await verifyDevpost();
  await verifyEventScraper();
  await verifyScholarshipExtractor();
  await verifyScholarshipFinder();
  console.log("\n=== Summary (compact for Phase 5.2 design) ===");
}

main().catch((e) => {
  console.error("Verify crashed:", e);
  process.exit(1);
});
