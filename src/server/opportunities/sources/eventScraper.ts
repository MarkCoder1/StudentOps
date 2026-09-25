import {
  OpportunitySourceAdapter,
  RawSourceResult,
  SourceFetchError,
  SourceFetchOptions,
  nowIso,
  assertApifyToken,
} from "./types";
import { runApifyActorAndFetchDataset } from "./apify";

const ACTOR_ID = "webdatalabs/event-scraper-pro";
const DEFAULT_TIMEOUT_MS = 300_000; // Eventbrite needs longer (browser)

export interface EventScraperFetchOptions extends SourceFetchOptions {
  keywords?: string[];
  cities?: string[];
  country?: string;
  platforms?: ("meetup" | "luma" | "eventbrite")[];
  dateFrom?: string; // YYYY-MM-DD
  dateTo?: string;
  maxResults?: number; // maps to maxResults per platform
  includeOnlineEvents?: boolean;
  minimumAttendees?: number;
  includeFreeEvents?: boolean;
}

export class EventScraperAdapter
  implements OpportunitySourceAdapter<EventScraperFetchOptions, unknown>
{
  readonly source = "eventScraper" as const;

  async fetch(
    options: EventScraperFetchOptions = {}
  ): Promise<RawSourceResult<unknown>> {
    const token = assertApifyToken(this.source);
    const { timeoutMs = DEFAULT_TIMEOUT_MS, signal, ...input } = options;

    // Build actor input without inventing unsupported fields
    const actorInput: Record<string, unknown> = {};
    if (input.keywords !== undefined) actorInput.keywords = input.keywords;
    if (input.cities !== undefined) actorInput.cities = input.cities;
    if (input.country !== undefined) actorInput.country = input.country;
    if (input.platforms !== undefined) actorInput.platforms = input.platforms;
    if (input.dateFrom !== undefined) actorInput.dateFrom = input.dateFrom;
    if (input.dateTo !== undefined) actorInput.dateTo = input.dateTo;
    if (input.maxResults !== undefined) actorInput.maxResults = input.maxResults;
    if (input.includeOnlineEvents !== undefined)
      actorInput.includeOnlineEvents = input.includeOnlineEvents;
    if (input.minimumAttendees !== undefined)
      actorInput.minimumAttendees = input.minimumAttendees;
    if (input.includeFreeEvents !== undefined)
      actorInput.includeFreeEvents = input.includeFreeEvents;

    // Do not filter events here — return raw dataset items

    try {
      const { datasetId, items, runId } = await runApifyActorAndFetchDataset(
        ACTOR_ID,
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
        meta: { actorId: ACTOR_ID, datasetId, runId, input: actorInput },
      };
    } catch (e) {
      if (e instanceof SourceFetchError) {
        if ((e.source as string) !== this.source) {
          throw new SourceFetchError(e.message, this.source, e.statusCode, e.cause);
        }
        throw e;
      }
      throw new SourceFetchError(
        `EventScraper fetch failed: ${(e as Error).message}`,
        this.source,
        undefined,
        e
      );
    }
  }
}
