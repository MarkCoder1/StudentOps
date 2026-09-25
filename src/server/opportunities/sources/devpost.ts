import {
  OpportunitySourceAdapter,
  RawSourceResult,
  SourceFetchError,
  SourceFetchOptions,
  nowIso,
  assertApifyToken,
} from "./types";
import { runApifyActorAndFetchDataset } from "./apify";

const ACTOR_ID = "automation-lab/devpost-scraper";
const DEFAULT_TIMEOUT_MS = 120_000;

export interface DevpostFetchOptions extends SourceFetchOptions {
  searchQuery?: string;
  challengeType?: "all" | "online" | "in-person";
  status?: "all" | "open" | "upcoming" | "ended";
  themes?: string[];
  orderBy?: "newest" | "prize-amount" | "deadline" | "recently-added" | "submissions-count";
  maxResults?: number;
}

export class DevpostAdapter implements OpportunitySourceAdapter<DevpostFetchOptions, unknown> {
  readonly source = "devpost" as const;

  async fetch(options: DevpostFetchOptions = {}): Promise<RawSourceResult<unknown>> {
    const token = assertApifyToken(this.source);
    const { timeoutMs = DEFAULT_TIMEOUT_MS, signal, ...input } = options;

    const actorInput: Record<string, unknown> = {};
    if (input.searchQuery !== undefined) actorInput.searchQuery = input.searchQuery;
    if (input.challengeType !== undefined) actorInput.challengeType = input.challengeType;
    if (input.status !== undefined) actorInput.status = input.status;
    if (input.themes !== undefined) actorInput.themes = input.themes;
    if (input.orderBy !== undefined) actorInput.orderBy = input.orderBy;
    if (input.maxResults !== undefined) actorInput.maxResults = input.maxResults;

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
        // Re-tag source if apify helper used generic
        if ((e.source as string) !== this.source) {
          throw new SourceFetchError(e.message, this.source, e.statusCode, e.cause);
        }
        throw e;
      }
      throw new SourceFetchError(
        `Devpost fetch failed: ${(e as Error).message}`,
        this.source,
        undefined,
        e
      );
    }
  }
}
