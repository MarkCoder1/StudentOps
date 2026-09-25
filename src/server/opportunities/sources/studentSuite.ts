import {
  OpportunitySourceAdapter,
  RawSourceResult,
  SourceFetchError,
  SourceFetchOptions,
  nowIso,
} from "./types";

const BASE_URL = "https://studyymap.com";
const ENDPOINT = "/api/competitions";
const DEFAULT_TIMEOUT_MS = 10_000;

export type StudentSuiteCategory =
  | "stem"
  | "mathematics"
  | "coding"
  | "essay_writing"
  | string; // allow future categories

export interface StudentSuiteFetchOptions extends SourceFetchOptions {
  category?: string;
  format?: "online" | "in_person" | "hybrid";
  participation?: "individual" | "team" | "individual_or_team";
  region?: string; // "international" or ISO alpha-2
  country?: string; // IN, US, GB, etc.
  fee?: "free";
  age?: number;
  deadline_before?: string; // YYYY-MM-DD
  limit?: number; // 1-200, default 50
  offset?: number;
}

interface StudentSuiteRawResponse {
  data: unknown[];
  total: number;
  limit: number;
  offset: number;
  error?: string;
}

export class StudentSuiteAdapter
  implements OpportunitySourceAdapter<StudentSuiteFetchOptions, unknown>
{
  readonly source = "studentSuite" as const;

  async fetch(
    options: StudentSuiteFetchOptions = {}
  ): Promise<RawSourceResult<unknown>> {
    const { timeoutMs = DEFAULT_TIMEOUT_MS, signal, ...params } = options;

    const url = new URL(ENDPOINT, BASE_URL);
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null && value !== "") {
        url.searchParams.set(key, String(value));
      }
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    const combinedSignal = signal
      ? this.mergeSignals(signal, controller.signal)
      : controller.signal;

    try {
      const res = await fetch(url.toString(), {
        method: "GET",
        headers: { Accept: "application/json" },
        signal: combinedSignal,
      });

      if (!res.ok) {
        let body: unknown = null;
        try {
          body = await res.json();
        } catch {
          try {
            body = await res.text();
          } catch {}
        }
        throw new SourceFetchError(
          `StudentSuite non-2xx: ${res.status} ${res.statusText}`,
          this.source,
          res.status,
          body
        );
      }

      let json: StudentSuiteRawResponse;
      try {
        json = (await res.json()) as StudentSuiteRawResponse;
      } catch (e) {
        throw new SourceFetchError(
          "StudentSuite malformed JSON",
          this.source,
          undefined,
          e
        );
      }

      if (!json || typeof json !== "object" || !Array.isArray((json as any).data)) {
        // Empty result is valid (empty data array), malformed is when data missing
        if ((json as any).error) {
          throw new SourceFetchError(
            `StudentSuite error: ${(json as any).error}`,
            this.source,
            400,
            json
          );
        }
        throw new SourceFetchError(
          "StudentSuite malformed response: missing data array",
          this.source,
          undefined,
          json
        );
      }

      return {
        source: this.source,
        data: json.data,
        rawResponse: json,
        total: typeof json.total === "number" ? json.total : undefined,
        fetchedAt: nowIso(),
        meta: { limit: json.limit, offset: json.offset, url: url.toString() },
      };
    } catch (e) {
      if (e instanceof SourceFetchError) throw e;
      if (e instanceof DOMException && e.name === "AbortError") {
        throw new SourceFetchError(
          `StudentSuite timeout after ${timeoutMs}ms`,
          this.source,
          408,
          e
        );
      }
      throw new SourceFetchError(
        `StudentSuite network failure: ${(e as Error).message}`,
        this.source,
        undefined,
        e
      );
    } finally {
      clearTimeout(timeout);
    }
  }

  private mergeSignals(a: AbortSignal, b: AbortSignal): AbortSignal {
    const controller = new AbortController();
    const onAbort = () => controller.abort();
    if (a.aborted || b.aborted) controller.abort();
    else {
      a.addEventListener("abort", onAbort, { once: true });
      b.addEventListener("abort", onAbort, { once: true });
    }
    return controller.signal;
  }
}
