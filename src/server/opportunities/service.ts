import type { Opportunity } from "./models/opportunity";
import { OpportunityRepository } from "./storage/repository";
import { getSharedDb } from "./storage/db";
import { evaluateFreshness } from "./freshness/evaluate";
import type { OpportunitySource } from "./sources/types";
import type { OpportunityCategory } from "./models/opportunity";

const VALID_SOURCES: Set<string> = new Set(["studentSuite", "devpost", "eventScraper", "scholarshipExtractor", "scholarshipFinder"]);
const VALID_CATEGORIES: Set<string> = new Set([
  "competition",
  "hackathon",
  "scholarship",
  "internship",
  "fellowship",
  "research",
  "leadership",
  "volunteering",
  "summerProgram",
  "academicProgram",
  "workshop",
  "conference",
  "creative",
  "other",
]);

export interface GetOpportunitiesParams {
  limit?: number;
  offset?: number;
  source?: string;
  category?: string;
  onlyActive?: boolean;
  asOf?: Date;
}

export interface PaginatedResult<T> {
  data: T[];
  pagination: {
    limit: number;
    offset: number;
    total: number;
  };
}

export class OpportunityService {
  private repo: OpportunityRepository;

  constructor(repo?: OpportunityRepository) {
    this.repo = repo ?? new OpportunityRepository(getSharedDb());
  }

  validateParams(params: GetOpportunitiesParams): { limit: number; offset: number; source?: string; category?: string; onlyActive: boolean; asOf: Date } {
    let limit = params.limit ?? 50;
    let offset = params.offset ?? 0;

    if (!Number.isInteger(limit) || limit < 1) {
      throw Object.assign(new Error("Invalid limit: must be integer >= 1"), { statusCode: 400, code: "INVALID_LIMIT" });
    }
    if (!Number.isInteger(offset) || offset < 0) {
      throw Object.assign(new Error("Invalid offset: must be integer >= 0"), { statusCode: 400, code: "INVALID_OFFSET" });
    }
    if (limit > 100) limit = 100;

    let onlyActive = false;
    if (params.onlyActive !== undefined) {
      // Strict boolean validation: only true/false string or boolean
      if (typeof params.onlyActive === "string") {
        if (params.onlyActive === "true") onlyActive = true;
        else if (params.onlyActive === "false") onlyActive = false;
        else throw Object.assign(new Error("Invalid onlyActive: must be true or false"), { statusCode: 400, code: "INVALID_ONLYACTIVE" });
      } else if (typeof params.onlyActive === "boolean") {
        onlyActive = params.onlyActive;
      } else {
        throw Object.assign(new Error("Invalid onlyActive: must be true or false"), { statusCode: 400, code: "INVALID_ONLYACTIVE" });
      }
    }

    let source: string | undefined;
    if (params.source !== undefined) {
      if (!VALID_SOURCES.has(params.source)) {
        throw Object.assign(new Error(`Invalid source: ${params.source}`), { statusCode: 400, code: "INVALID_SOURCE" });
      }
      source = params.source;
    }

    let category: string | undefined;
    if (params.category !== undefined) {
      if (!VALID_CATEGORIES.has(params.category)) {
        throw Object.assign(new Error(`Invalid category: ${params.category}`), { statusCode: 400, code: "INVALID_CATEGORY" });
      }
      category = params.category;
    }

    const asOf = params.asOf ?? new Date();

    return { limit, offset, source, category, onlyActive, asOf };
  }

  getOpportunities(params: GetOpportunitiesParams = {}): PaginatedResult<Opportunity> {
    const { limit, offset, source, category, onlyActive, asOf } = this.validateParams(params);

    // Fetch filtered by source/category via storage (no onlyActive yet, we handle via freshness)
    let opportunities: Opportunity[];
    if (source || category) {
      // Use storage filtered (without onlyActive, we handle freshness separately)
      // For onlyActive, we fetch all matching source/category first, then filter
      const all = this.repo.getOpportunitiesFiltered({ source, category });
      opportunities = all;
    } else {
      opportunities = this.repo.getOpportunities();
    }

    // Apply onlyActive via freshness engine (explicit asOf, no hidden Date.now)
    if (onlyActive) {
      opportunities = opportunities.filter((opp) => {
        const freshness = evaluateFreshness(opp, asOf);
        return freshness.status !== "expired";
      });
    }

    const total = opportunities.length;
    const paginated = opportunities.slice(offset, offset + limit);

    return {
      data: paginated,
      pagination: { limit, offset, total },
    };
  }

  getOpportunityById(id: string): Opportunity | null {
    if (!id || id.trim() === "") {
      throw Object.assign(new Error("Invalid id"), { statusCode: 400, code: "INVALID_ID" });
    }
    return this.repo.getOpportunityById(id);
  }
}

// Singleton for API routes
let defaultService: OpportunityService | null = null;
export function getOpportunityService(): OpportunityService {
  if (!defaultService) defaultService = new OpportunityService();
  return defaultService;
}
