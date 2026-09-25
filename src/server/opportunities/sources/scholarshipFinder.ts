import {
  OpportunitySourceAdapter,
  RawSourceResult,
  SourceFetchError,
  SourceFetchOptions,
  nowIso,
  assertApifyToken,
} from "./types";
import { runApifyActorAndFetchDataset } from "./apify";

// Configuration placeholder — do NOT invent actor ID.
// If the exact CollegeScholarships.org Apify actor is not available, keep disabled.
const SCHOLARSHIP_FINDER_ACTOR_ID: string | null =
  process.env.SCHOLARSHIP_FINDER_ACTOR_ID?.trim() || null;

// Fallback known public actor for reference (not used unless configured):
// Some deployments may use a custom actor; document without hardcoding.
const DEFAULT_TIMEOUT_MS = 120_000;

export interface ScholarshipFinderFetchOptions extends SourceFetchOptions {
  keyword?: string;
  maxResults?: string; // "50" | "100" | "200" | "500" | "1000" | "2000" | "5000"
  maxPages?: string; // "5" | "10" | "20" | "50" | "100" | "769"
  fetchDetails?: boolean;
  minAward?: string; // "" | "500" | "1000" | "2500" | "5000" | "10000" | "25000"
  sortBy?: string; // "none" | "award_high" | "award_low" | "deadline"
}

export class ScholarshipFinderAdapter
  implements OpportunitySourceAdapter<ScholarshipFinderFetchOptions, unknown>
{
  readonly source = "scholarshipFinder" as const;

  get isConfigured(): boolean {
    return SCHOLARSHIP_FINDER_ACTOR_ID !== null && SCHOLARSHIP_FINDER_ACTOR_ID.length > 0;
  }

  get actorId(): string | null {
    return SCHOLARSHIP_FINDER_ACTOR_ID;
  }

  async fetch(
    options: ScholarshipFinderFetchOptions = {}
  ): Promise<RawSourceResult<unknown>> {
    if (!this.isConfigured || !SCHOLARSHIP_FINDER_ACTOR_ID) {
      throw new SourceFetchError(
        "ScholarshipFinder not configured: set server-side env SCHOLARSHIP_FINDER_ACTOR_ID to the CollegeScholarships.org Apify actor (e.g., 'actor-id/college-scholarships-scraper') — adapter is intentionally disabled until identifier is supplied",
        this.source,
        501
      );
    }

    const token = assertApifyToken(this.source);
    const { timeoutMs = DEFAULT_TIMEOUT_MS, signal, ...input } = options;

    const actorInput: Record<string, unknown> = {};
    if (input.keyword !== undefined) actorInput.keyword = input.keyword;
    if (input.maxResults !== undefined) actorInput.maxResults = String(input.maxResults);
    if (input.maxPages !== undefined) actorInput.maxPages = String(input.maxPages);
    if (input.fetchDetails !== undefined) actorInput.fetchDetails = input.fetchDetails;
    if (input.minAward !== undefined) actorInput.minAward = String(input.minAward);
    if (input.sortBy !== undefined) actorInput.sortBy = input.sortBy;

    try {
      const { datasetId, items, runId } = await runApifyActorAndFetchDataset(
        SCHOLARSHIP_FINDER_ACTOR_ID,
        actorInput,
        token,
        { timeoutMs, signal }
      );

      return {
        source: this.source,
        data: items,
        rawResponse: items,
        total: items.length,
        fetchedAt: nowIso(),
        meta: {
          actorId: SCHOLARSHIP_FINDER_ACTOR_ID,
          datasetId,
          runId,
          input: actorInput,
        },
      };
    } catch (e) {
      if (e instanceof SourceFetchError) {
        if ((e.source as string) !== this.source) {
          throw new SourceFetchError(e.message, this.source, e.statusCode, e.cause);
        }
        throw e;
      }
      throw new SourceFetchError(
        `ScholarshipFinder fetch failed: ${(e as Error).message}`,
        this.source,
        undefined,
        e
      );
    }
  }
}
