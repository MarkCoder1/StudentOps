import { SourceFetchError, nowIso } from "./types";

export const APIFY_API_BASE = "https://api.apify.com/v2";
const DEFAULT_POLL_INTERVAL_MS = 2000;
const DEFAULT_TIMEOUT_MS = 120_000;

interface ApifyRunResponse {
  data: {
    id: string;
    actId: string;
    defaultDatasetId: string;
    status: string;
  };
}

interface ApifyRunStatusResponse {
  data: {
    id: string;
    status: "RUNNING" | "READY" | "SUCCEEDED" | "FAILED" | "TIMED-OUT" | "ABORTED";
    defaultDatasetId: string;
    startedAt: string;
    finishedAt?: string;
  };
}

export interface ApifyRunOptions {
  timeoutMs?: number;
  pollIntervalMs?: number;
  signal?: AbortSignal;
  fetchFn?: typeof fetch;
}

export async function startApifyRun(
  actorId: string,
  input: Record<string, unknown>,
  token: string,
  options: ApifyRunOptions = {}
): Promise<{ runId: string; datasetId: string }> {
  const { fetchFn = fetch } = options;
  const url = `${APIFY_API_BASE}/acts/${encodeURIComponent(actorId)}/runs?token=${encodeURIComponent(token)}`;

  const res = await fetchFn(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
    signal: options.signal,
  });

  if (!res.ok) {
    let body: unknown;
    try {
      body = await res.json();
    } catch {
      body = await res.text();
    }
    throw new SourceFetchError(
      `Apify start run failed ${res.status} for ${actorId}`,
      "devpost" as any,
      res.status,
      body
    );
  }

  let json: ApifyRunResponse;
  try {
    json = (await res.json()) as ApifyRunResponse;
  } catch (e) {
    throw new SourceFetchError(`Apify start run malformed JSON for ${actorId}`, "devpost" as any, undefined, e);
  }

  if (!json?.data?.id || !json?.data?.defaultDatasetId) {
    throw new SourceFetchError(`Apify start run missing id/datasetId for ${actorId}`, "devpost" as any, undefined, json);
  }

  return { runId: json.data.id, datasetId: json.data.defaultDatasetId };
}

export async function pollApifyRun(
  runId: string,
  token: string,
  options: ApifyRunOptions = {}
): Promise<string> {
  const {
    timeoutMs = DEFAULT_TIMEOUT_MS,
    pollIntervalMs = DEFAULT_POLL_INTERVAL_MS,
    signal,
    fetchFn = fetch,
  } = options;

  const start = Date.now();
  while (true) {
    if (signal?.aborted) {
      throw new SourceFetchError(`Apify poll aborted for run ${runId}`, "devpost" as any, 408);
    }
    if (Date.now() - start > timeoutMs) {
      throw new SourceFetchError(`Apify run ${runId} timeout after ${timeoutMs}ms`, "devpost" as any, 408);
    }

    const url = `${APIFY_API_BASE}/actor-runs/${encodeURIComponent(runId)}?token=${encodeURIComponent(token)}`;
    const res = await fetchFn(url, { signal });

    if (!res.ok) {
      let body: unknown;
      try {
        body = await res.json();
      } catch {
        body = await res.text();
      }
      throw new SourceFetchError(`Apify poll failed ${res.status} for ${runId}`, "devpost" as any, res.status, body);
    }

    let json: ApifyRunStatusResponse;
    try {
      json = (await res.json()) as ApifyRunStatusResponse;
    } catch (e) {
      throw new SourceFetchError(`Apify poll malformed JSON for ${runId}`, "devpost" as any, undefined, e);
    }

    const status = json?.data?.status;
    if (status === "SUCCEEDED") {
      if (!json.data.defaultDatasetId) {
        throw new SourceFetchError(`Apify run ${runId} succeeded but missing datasetId`, "devpost" as any, undefined, json);
      }
      return json.data.defaultDatasetId;
    }
    if (status === "FAILED" || status === "TIMED-OUT" || status === "ABORTED") {
      throw new SourceFetchError(`Apify run ${runId} ${status}`, "devpost" as any, undefined, json);
    }

    // RUNNING | READY — wait
    await new Promise((r) => setTimeout(r, pollIntervalMs));
  }
}

export async function fetchApifyDataset(
  datasetId: string,
  token: string,
  options: { signal?: AbortSignal; fetchFn?: typeof fetch; clean?: boolean } = {}
): Promise<unknown[]> {
  const { signal, fetchFn = fetch, clean = true } = options;
  const url = `${APIFY_API_BASE}/datasets/${encodeURIComponent(datasetId)}/items?token=${encodeURIComponent(token)}&format=json&clean=${clean ? "true" : "false"}`;

  const res = await fetchFn(url, { signal, headers: { Accept: "application/json" } });

  if (!res.ok) {
    let body: unknown;
    try {
      body = await res.json();
    } catch {
      body = await res.text();
    }
    throw new SourceFetchError(`Apify dataset fetch failed ${res.status} for ${datasetId}`, "devpost" as any, res.status, body);
  }

  let json: unknown;
  try {
    json = await res.json();
  } catch (e) {
    throw new SourceFetchError(`Apify dataset malformed JSON for ${datasetId}`, "devpost" as any, undefined, e);
  }

  if (!Array.isArray(json)) {
    throw new SourceFetchError(`Apify dataset expected array for ${datasetId}`, "devpost" as any, undefined, json);
  }

  return json;
}

// Convenience: start → poll → fetch
export async function runApifyActorAndFetchDataset(
  actorId: string,
  input: Record<string, unknown>,
  token: string,
  options: ApifyRunOptions & { clean?: boolean } = {}
): Promise<{ datasetId: string; items: unknown[]; runId: string }> {
  const { runId, datasetId: initialDatasetId } = await startApifyRun(actorId, input, token, options);
  const finalDatasetId = await pollApifyRun(runId, token, options);
  // Use final datasetId from poll (may differ but usually same as initial)
  const datasetId = finalDatasetId || initialDatasetId;
  const items = await fetchApifyDataset(datasetId, token, options);
  return { datasetId, items, runId };
}
