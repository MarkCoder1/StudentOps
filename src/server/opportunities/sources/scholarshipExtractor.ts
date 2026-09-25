import {
  OpportunitySourceAdapter,
  RawSourceResult,
  SourceFetchError,
  SourceFetchOptions,
  nowIso,
  assertApifyToken,
} from "./types";
import { runApifyActorAndFetchDataset } from "./apify";

const ACTOR_ID = "saadithya/scholarships-competitions-internships-extractor";
const DEFAULT_TIMEOUT_MS = 120_000;

export type ScholarshipExtractorCategory =
  | "App Challenge"
  | "Design Challenge"
  | "Fellowships"
  | "Ideation Challenge"
  | "Internships"
  | "Music and Art Challenge"
  | "Photography Challenge"
  | "Poetry Competition"
  | "Scholarships"
  | "Video Challenge"
  | "Writing Challenge"
  | string;

export interface ScholarshipExtractorFetchOptions extends SourceFetchOptions {
  category: ScholarshipExtractorCategory; // required per actor
  deadlineAfter?: string; // YYYY-MM-DD
  maxItems?: number; // 1-100, default 20
  testMode?: boolean;
}

export class ScholarshipExtractorAdapter
  implements OpportunitySourceAdapter<ScholarshipExtractorFetchOptions, unknown>
{
  readonly source = "scholarshipExtractor" as const;

  async fetch(
    options: ScholarshipExtractorFetchOptions
  ): Promise<RawSourceResult<unknown>> {
    if (!options || !options.category) {
      throw new SourceFetchError(
        "ScholarshipExtractor requires category",
        this.source,
        400
      );
    }

    const token = assertApifyToken(this.source);
    const { timeoutMs = DEFAULT_TIMEOUT_MS, signal, ...input } = options as ScholarshipExtractorFetchOptions & SourceFetchOptions;

    const actorInput: Record<string, unknown> = {
      category: input.category,
    };
    if (input.deadlineAfter !== undefined) actorInput.deadlineAfter = input.deadlineAfter;
    if (input.maxItems !== undefined) actorInput.maxItems = input.maxItems;
    if (input.testMode !== undefined) actorInput.testMode = input.testMode;

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
        `ScholarshipExtractor fetch failed: ${(e as Error).message}`,
        this.source,
        undefined,
        e
      );
    }
  }
}
