import { describe, it, expect, beforeEach, vi, afterEach } from "vitest";

// These tests use fetch mocks — no real Apify credits consumed.

describe("StudentSuiteAdapter", async () => {
  const { StudentSuiteAdapter } = await import("../sources/studentSuite.js");
  const { SourceFetchError } = await import("../sources/types.js");

  const originalFetch = globalThis.fetch;
  const originalEnv = process.env.APIFY_API_TOKEN;

  beforeEach(() => {
    vi.restoreAllMocks();
  });
  afterEach(() => {
    globalThis.fetch = originalFetch;
    process.env.APIFY_API_TOKEN = originalEnv;
  });

  it("request → successful raw response", async () => {
    const mockBody = {
      data: [{ id: "breakthrough-junior-challenge", name: "Test" }],
      total: 1,
      limit: 50,
      offset: 0,
    };
    globalThis.fetch = vi.fn(async () =>
      new Response(JSON.stringify(mockBody), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      })
    ) as any;

    const adapter = new StudentSuiteAdapter();
    const result = await adapter.fetch({ category: "stem", limit: 1 });

    expect(result.source).toBe("studentSuite");
    expect(result.data).toHaveLength(1);
    expect(result.total).toBe(1);
    expect(result.rawResponse).toEqual(mockBody);
    expect(result.fetchedAt).toBeDefined();
  });

  it("empty result is valid", async () => {
    const mockBody = { data: [], total: 0, limit: 50, offset: 0 };
    globalThis.fetch = vi.fn(async () =>
      new Response(JSON.stringify(mockBody), { status: 200, headers: { "Content-Type": "application/json" } })
    ) as any;

    const adapter = new StudentSuiteAdapter();
    const result = await adapter.fetch({ category: "stem" });
    expect(result.data).toHaveLength(0);
    expect(result.total).toBe(0);
  });

  it("non-2xx response → SourceFetchError", async () => {
    globalThis.fetch = vi.fn(async () =>
      new Response(JSON.stringify({ error: 'unknown category "foo"' }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      })
    ) as any;

    const adapter = new StudentSuiteAdapter();
    await expect(adapter.fetch({ category: "foo" as any })).rejects.toThrow(SourceFetchError);
    await expect(adapter.fetch({ category: "foo" as any })).rejects.toMatchObject({ statusCode: 400 });
  });

  it("malformed JSON → SourceFetchError", async () => {
    globalThis.fetch = vi.fn(async () =>
      new Response("not json", { status: 200, headers: { "Content-Type": "application/json" } })
    ) as any;

    const adapter = new StudentSuiteAdapter();
    await expect(adapter.fetch()).rejects.toThrow(SourceFetchError);
  });

  it("timeout → 408", async () => {
    // Mock fetch that never resolves, rely on abort
    globalThis.fetch = vi.fn((_, opts: any) => {
      return new Promise((_, reject) => {
        opts.signal?.addEventListener("abort", () => {
          const e = new DOMException("Aborted", "AbortError");
          reject(e);
        });
      });
    }) as any;

    const adapter = new StudentSuiteAdapter();
    await expect(adapter.fetch({ timeoutMs: 10 })).rejects.toMatchObject({ statusCode: 408 });
  });
});

describe("Apify adapters — token and run lifecycle", async () => {
  const { DevpostAdapter } = await import("../sources/devpost.js");
  const { EventScraperAdapter } = await import("../sources/eventScraper.js");
  const { ScholarshipExtractorAdapter } = await import("../sources/scholarshipExtractor.js");
  const { ScholarshipFinderAdapter } = await import("../sources/scholarshipFinder.js");
  const { SourceFetchError } = await import("../sources/types.js");

  const originalFetch = globalThis.fetch;
  const originalToken = process.env.APIFY_API_TOKEN;

  beforeEach(() => {
    vi.restoreAllMocks();
    process.env.APIFY_API_TOKEN = "test-token-123";
  });
  afterEach(() => {
    globalThis.fetch = originalFetch;
    process.env.APIFY_API_TOKEN = originalToken;
  });

  function mockApifySuccess() {
    let call = 0;
    globalThis.fetch = vi.fn(async (url: string) => {
      call++;
      const u = String(url);
      if (u.includes("/acts/") && u.includes("/runs")) {
        return new Response(
          JSON.stringify({ data: { id: "run-123", defaultDatasetId: "ds-123", status: "READY" } }),
          { status: 201, headers: { "Content-Type": "application/json" } }
        );
      }
      if (u.includes("/actor-runs/run-123")) {
        return new Response(
          JSON.stringify({ data: { id: "run-123", status: "SUCCEEDED", defaultDatasetId: "ds-123" } }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }
      if (u.includes("/datasets/ds-123/items")) {
        return new Response(JSON.stringify([{ id: 1, title: "Mock Item" }]), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      return new Response(JSON.stringify({}), { status: 200 });
    }) as any;
  }

  it("Devpost: token exists → run can be started → dataset retrieved", async () => {
    mockApifySuccess();
    const adapter = new DevpostAdapter();
    const result = await adapter.fetch({ searchQuery: "AI", maxResults: 1 });
    expect(result.source).toBe("devpost");
    expect(result.data).toHaveLength(1);
    expect(result.meta).toMatchObject({ actorId: "automation-lab/devpost-scraper" });
  });

  it("EventScraper: token exists → raw dataset returned", async () => {
    mockApifySuccess();
    const adapter = new EventScraperAdapter();
    const result = await adapter.fetch({ keywords: ["ai"], cities: ["Berlin"], maxResults: 1 });
    expect(result.source).toBe("eventScraper");
    expect(Array.isArray(result.data)).toBe(true);
  });

  it("ScholarshipExtractor: valid category → raw dataset", async () => {
    mockApifySuccess();
    const adapter = new ScholarshipExtractorAdapter();
    const result = await adapter.fetch({ category: "Scholarships", maxItems: 1 });
    expect(result.source).toBe("scholarshipExtractor");
    expect(result.data).toHaveLength(1);
  });

  it("missing APIFY_API_TOKEN → 401", async () => {
    process.env.APIFY_API_TOKEN = "";
    const adapter = new DevpostAdapter();
    await expect(adapter.fetch()).rejects.toThrow(SourceFetchError);
    await expect(adapter.fetch()).rejects.toMatchObject({ statusCode: 401 });
  });

  it("ScholarshipExtractor requires category → 400", async () => {
    const adapter = new ScholarshipExtractorAdapter();
    await expect((adapter as any).fetch({})).rejects.toMatchObject({ statusCode: 400 });
  });

  it("HTTP error on start run → SourceFetchError", async () => {
    globalThis.fetch = vi.fn(async () =>
      new Response(JSON.stringify({ error: "bad" }), { status: 500 })
    ) as any;
    const adapter = new DevpostAdapter();
    await expect(adapter.fetch()).rejects.toThrow(SourceFetchError);
  });

  it("actor failure → SourceFetchError", async () => {
    globalThis.fetch = vi.fn(async (url: string) => {
      const u = String(url);
      if (u.includes("/acts/")) {
        return new Response(JSON.stringify({ data: { id: "run-123", defaultDatasetId: "ds-123" } }), {
          status: 201,
          headers: { "Content-Type": "application/json" },
        });
      }
      if (u.includes("/actor-runs/")) {
        return new Response(
          JSON.stringify({ data: { id: "run-123", status: "FAILED", defaultDatasetId: "ds-123" } }),
          { status: 200 }
        );
      }
      return new Response(JSON.stringify([]), { status: 200 });
    }) as any;

    const adapter = new DevpostAdapter();
    await expect(adapter.fetch()).rejects.toThrow(/FAILED/);
  });

  it("empty dataset is valid (not error)", async () => {
    globalThis.fetch = vi.fn(async (url: string) => {
      const u = String(url);
      if (u.includes("/acts/")) {
        return new Response(JSON.stringify({ data: { id: "run-123", defaultDatasetId: "ds-123" } }), { status: 201 });
      }
      if (u.includes("/actor-runs/")) {
        return new Response(JSON.stringify({ data: { id: "run-123", status: "SUCCEEDED", defaultDatasetId: "ds-123" } }), { status: 200 });
      }
      if (u.includes("/datasets/")) {
        return new Response(JSON.stringify([]), { status: 200 });
      }
      return new Response(JSON.stringify([]), { status: 200 });
    }) as any;

    const adapter = new DevpostAdapter();
    const result = await adapter.fetch({ maxResults: 1 });
    expect(result.data).toHaveLength(0);
    expect(result.total).toBe(0);
  });

  it("ScholarshipFinder: not configured → 501 placeholder", async () => {
    // Ensure env not set
    delete process.env.SCHOLARSHIP_FINDER_ACTOR_ID;
    // Re-import to pick up null? Already imported with process.env read at module load — need to test via isConfigured
    const adapter = new ScholarshipFinderAdapter();
    if (!adapter.isConfigured) {
      await expect(adapter.fetch({ keyword: "test" })).rejects.toMatchObject({ statusCode: 501 });
      expect(adapter.actorId).toBeNull();
    } else {
      // If configured via env, verify it would attempt fetch (mock)
      mockApifySuccess();
      const result = await adapter.fetch({ keyword: "test", maxResults: "50" });
      expect(result.source).toBe("scholarshipFinder");
    }
  });

  it("timeout → 408", async () => {
    // Mock poll that never succeeds
    globalThis.fetch = vi.fn(async (url: string) => {
      const u = String(url);
      if (u.includes("/acts/")) {
        return new Response(JSON.stringify({ data: { id: "run-123", defaultDatasetId: "ds-123" } }), { status: 201 });
      }
      if (u.includes("/actor-runs/")) {
        return new Response(JSON.stringify({ data: { id: "run-123", status: "RUNNING", defaultDatasetId: "ds-123" } }), { status: 200 });
      }
      return new Response(JSON.stringify([]), { status: 200 });
    }) as any;

    const adapter = new DevpostAdapter();
    await expect(adapter.fetch({ maxResults: 1, timeoutMs: 10 } as any)).rejects.toMatchObject({ statusCode: 408 });
  });
});

describe("Security — token never exposed", () => {
  it("adapter does not log token", async () => {
    const { DevpostAdapter } = await import("../sources/devpost.js");
    process.env.APIFY_API_TOKEN = "super-secret";
    const adapter = new DevpostAdapter();
    // Ensure fetch URL contains token but error messages do not leak full token in logs (we check error does not contain token)
    // Mock failing fetch to trigger error path
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => new Response("fail", { status: 500 }) as any;
    try {
      await adapter.fetch();
    } catch (e: any) {
      expect(String(e.message)).not.toContain("super-secret");
      expect(JSON.stringify(e.cause || "")).not.toContain("super-secret");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
});
