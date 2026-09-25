// Shared adapter abstraction — Phase 5.1 source adapter layer only
// No normalization, deduplication, filtering, matching, or DB here.

export type OpportunitySource =
  | "studentSuite"
  | "devpost"
  | "eventScraper"
  | "scholarshipExtractor"
  | "scholarshipFinder";

export interface RawSourceResult<T = unknown> {
  source: OpportunitySource;
  /** Raw payload as returned by source (array of items) */
  data: T[];
  /** Full raw response for inspection (StudentSuite: {data,total,limit,offset}) */
  rawResponse?: unknown;
  /** Total before pagination when provided */
  total?: number;
  fetchedAt: string; // ISO timestamp
  meta?: Record<string, unknown>;
}

export interface SourceFetchOptions {
  /** Optional timeout in ms (default per-adapter) */
  timeoutMs?: number;
  /** AbortSignal passthrough */
  signal?: AbortSignal;
}

export class SourceFetchError extends Error {
  constructor(
    message: string,
    public readonly source: OpportunitySource,
    public readonly statusCode?: number,
    public readonly cause?: unknown
  ) {
    super(message);
    this.name = "SourceFetchError";
  }
}

export interface OpportunitySourceAdapter<TOptions extends SourceFetchOptions = SourceFetchOptions, TRaw = unknown> {
  readonly source: OpportunitySource;
  fetch(options?: TOptions): Promise<RawSourceResult<TRaw>>;
}

// Helpers
export function assertApifyToken(source: OpportunitySource): string {
  const token = process.env.APIFY_API_TOKEN;
  if (!token || token.trim() === "") {
    throw new SourceFetchError(
      `Missing APIFY_API_TOKEN for ${source} — set server-side env APIFY_API_TOKEN (never NEXT_PUBLIC_)`,
      source,
      401
    );
  }
  return token;
}

export function nowIso(): string {
  return new Date().toISOString();
}
