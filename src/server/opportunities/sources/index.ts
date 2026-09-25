export * from "./types";
export * from "./studentSuite";
export * from "./devpost";
export * from "./eventScraper";
export * from "./scholarshipExtractor";
export * from "./scholarshipFinder";
export * from "./apify";

import { StudentSuiteAdapter } from "./studentSuite";
import { DevpostAdapter } from "./devpost";
import { EventScraperAdapter } from "./eventScraper";
import { ScholarshipExtractorAdapter } from "./scholarshipExtractor";
import { ScholarshipFinderAdapter } from "./scholarshipFinder";
import type { OpportunitySource, OpportunitySourceAdapter } from "./types";

// Factory for later phases to call without per-adapter imports
export function createAllAdapters(): Record<OpportunitySource, OpportunitySourceAdapter> {
  return {
    studentSuite: new StudentSuiteAdapter(),
    devpost: new DevpostAdapter(),
    eventScraper: new EventScraperAdapter(),
    scholarshipExtractor: new ScholarshipExtractorAdapter(),
    scholarshipFinder: new ScholarshipFinderAdapter(),
  };
}
