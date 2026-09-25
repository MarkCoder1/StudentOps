import type { Opportunity } from "../models/opportunity";
import { isValidUrl, isValidIsoDate } from "../models/opportunity";
import type { OpportunitySource } from "../sources/types";
import { SourceFetchError } from "../sources/types";
import { normalizeStudentSuite } from "./studentSuite";
import { normalizeDevpost } from "./devpost";
import { normalizeEventScraper } from "./eventScraper";
import { normalizeScholarshipExtractor } from "./scholarshipExtractor";
import { normalizeScholarshipFinder } from "./scholarshipFinder";

export * from "./studentSuite";
export * from "./devpost";
export * from "./eventScraper";
export * from "./scholarshipExtractor";
export * from "./scholarshipFinder";

export function normalizeOpportunity(
  source: OpportunitySource,
  rawRecord: unknown,
  fetchedAt: string = new Date().toISOString()
): Opportunity {
  if (!rawRecord || typeof rawRecord !== "object") {
    throw new SourceFetchError(`Cannot normalize empty record for ${source}`, source, 400, rawRecord);
  }
  switch (source) {
    case "studentSuite":
      return normalizeStudentSuite(rawRecord as any, fetchedAt);
    case "devpost":
      return normalizeDevpost(rawRecord as any, fetchedAt);
    case "eventScraper":
      return normalizeEventScraper(rawRecord as any, fetchedAt);
    case "scholarshipExtractor":
      return normalizeScholarshipExtractor(rawRecord as any, fetchedAt);
    case "scholarshipFinder":
      return normalizeScholarshipFinder(rawRecord as any, fetchedAt);
    default:
      throw new SourceFetchError(`Unknown source ${source}`, source as OpportunitySource, 400);
  }
}

// Lightweight validation — missing optional fields must NOT fail
export function validateOpportunity(opp: Opportunity): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  if (!opp.title || opp.title.trim() === "") errors.push("title must be present");
  if (!opp.source) errors.push("source must be present");
  if (!opp.externalId || opp.externalId.trim() === "") errors.push("externalId must be present");
  if (!opp.id || !opp.id.startsWith(`${opp.source}:`)) errors.push("id must be deterministic source:externalId");
  if (!isValidUrl(opp.officialUrl)) errors.push(`officialUrl invalid: ${opp.officialUrl}`);
  if (!isValidUrl(opp.applicationUrl)) errors.push(`applicationUrl invalid: ${opp.applicationUrl}`);
  if (!isValidUrl(opp.sourceUrl)) errors.push(`sourceUrl invalid: ${opp.sourceUrl}`);
  if (!isValidIsoDate(opp.deadline)) errors.push(`deadline invalid: ${opp.deadline}`);
  if (!isValidIsoDate(opp.startDate)) errors.push(`startDate invalid: ${opp.startDate}`);
  if (!isValidIsoDate(opp.endDate)) errors.push(`endDate invalid: ${opp.endDate}`);
  if (opp.cost.amount !== null && typeof opp.cost.amount !== "number") errors.push("cost.amount must be number|null");
  if (opp.benefits.awardAmount !== null && typeof opp.benefits.awardAmount !== "number") errors.push("awardAmount must be number|null");
  if (opp.eligibility.minAge !== null && typeof opp.eligibility.minAge !== "number") errors.push("minAge must be number|null");
  if (opp.eligibility.maxAge !== null && typeof opp.eligibility.maxAge !== "number") errors.push("maxAge must be number|null");
  return { valid: errors.length === 0, errors };
}
