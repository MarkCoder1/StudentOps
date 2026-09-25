// Groq AI Provider — Phase 6.1
// Server-only. Never import from client code or Swift.

import { Groq } from "groq-sdk";
import type {
  AIProviderConfig,
  AIProviderName,
  AIRequest,
  AIStructuredRequest,
  AIResult,
  AIError,
  AIErrorCode,
  AIUsage,
  AISchema,
} from "./types";
import type { AIProvider } from "./provider";

// ─── Default Configuration ───────────────────────────────────────

const DEFAULT_CONFIG: AIProviderConfig = {
  provider: "groq",
  model: "openai/gpt-oss-120b",
  temperature: 0.3,
  maxCompletionTokens: 2048,
  timeoutMs: 30_000,
};

// ─── Groq Provider ───────────────────────────────────────────────

export class GroqProvider implements AIProvider {
  readonly name: AIProviderName = "groq";
  readonly config: AIProviderConfig;

  private client: Groq | null = null;

  constructor(config?: Partial<AIProviderConfig>) {
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  // Lazy-init the Groq client so we can detect missing API key at call time.
  private getClient(): Groq {
    if (!this.client) {
      const apiKey = process.env.GROQ_API_KEY;
      if (!apiKey) {
        throw buildError("missing_api_key", "groq", "GROQ_API_KEY environment variable is not set");
      }
      this.client = new Groq({ apiKey });
    }
    return this.client;
  }

  async generate(request: AIRequest): Promise<AIResult<string>> {
    const client = this.getClient();
    const temperature = request.temperature ?? this.config.temperature;
    const maxTokens = request.maxCompletionTokens ?? this.config.maxCompletionTokens;

    try {
      const response = await client.chat.completions.create(
        {
          model: this.config.model,
          messages: [
            { role: "system", content: request.system },
            { role: "user", content: request.user },
          ],
          temperature,
          max_completion_tokens: maxTokens,
          stream: false,
          ...(request.reasoningEffort ? { reasoning_effort: request.reasoningEffort } : {}),
        },
        { timeout: this.config.timeoutMs }
      );

      const choice = response.choices?.[0];
      const text = choice?.message?.content ?? "";

      if (!text) {
        throw buildError("empty_response", "groq", "Model returned empty content");
      }

      return {
        data: text,
        rawText: text,
        model: response.model ?? this.config.model,
        provider: "groq",
        usage: parseUsage(response.usage),
      };
    } catch (err) {
      if (isAIError(err)) throw err;
      throw wrapProviderError(err, "groq");
    }
  }

  async generateStructured<T = unknown>(
    request: AIStructuredRequest
  ): Promise<AIResult<T>> {
    const client = this.getClient();
    const temperature = request.temperature ?? this.config.temperature;
    const maxTokens = request.maxCompletionTokens ?? this.config.maxCompletionTokens;

    // DEVELOPMENT LOGGING — log request params (no secrets)
    console.error(`[AI] generateStructured — model: ${this.config.model}, temperature: ${temperature}, maxTokens: ${maxTokens}`);
    console.error(`[AI] response_format:`, JSON.stringify({ type: "json_schema", json_schema: { name: request.outputSchema.name, strict: request.outputSchema.strict } }));

    try {
      const response = await client.chat.completions.create(
        {
          model: this.config.model,
          messages: [
            { role: "system", content: request.system },
            { role: "user", content: request.user },
          ],
          temperature,
          max_completion_tokens: maxTokens,
          stream: false,
          response_format: {
            type: "json_schema",
            json_schema: buildGroqSchema(request.outputSchema),
          },
          ...(request.reasoningEffort ? { reasoning_effort: request.reasoningEffort } : {}),
        },
        { timeout: this.config.timeoutMs }
      );

      const choice = response.choices?.[0];
      const text = choice?.message?.content ?? "";

      if (!text) {
        throw buildError("empty_response", "groq", "Model returned empty content");
      }

      // Parse JSON
      let parsed: unknown;
      try {
        parsed = JSON.parse(text);
      } catch {
        throw buildError("invalid_json", "groq", "Model returned invalid JSON");
      }

      // Validate against schema
      const validation = validateSchema(parsed, request.outputSchema.schema);
      if (!validation.ok) {
        throw buildError(
          "schema_validation_failed",
          "groq",
          validation.error
        );
      }

      return {
        data: parsed as T,
        rawText: text,
        model: response.model ?? this.config.model,
        provider: "groq",
        usage: parseUsage(response.usage),
      };
    } catch (err) {
      if (isAIError(err)) throw err;
      throw wrapProviderError(err, "groq");
    }
  }

  async healthCheck(): Promise<{ ok: true } | { ok: false; error: AIError }> {
    try {
      this.getClient();
      return { ok: true };
    } catch (err) {
      return { ok: false, error: err as AIError };
    }
  }
}

// ─── Schema Helpers ──────────────────────────────────────────────

function buildGroqSchema(schema: AISchema): {
  name: string;
  description?: string;
  schema: Record<string, unknown>;
  strict?: boolean;
} {
  return {
    name: schema.name,
    description: schema.description,
    schema: schema.schema,
    strict: schema.strict,
  };
}

// ─── Lightweight Schema Validation ───────────────────────────────
// Validates that the parsed output matches the expected shape.
// This is intentionally minimal — just enough to catch malformed AI output.

export type ValidationResult =
  | { ok: true }
  | { ok: false; error: string };

export function validateSchema(data: unknown, schema: Record<string, unknown>): ValidationResult {
  if (typeof data !== "object" || data === null) {
    return { ok: false, error: "Expected an object, got " + typeof data };
  }

  const required = schema.required;
  if (Array.isArray(required)) {
    for (const field of required) {
      if (typeof field === "string" && !(field in (data as Record<string, unknown>))) {
        return { ok: false, error: `Missing required field: ${field}` };
      }
    }
  }

  const properties = schema.properties;
  if (typeof properties === "object" && properties !== null) {
    for (const [key, propSchema] of Object.entries(properties)) {
      if (typeof propSchema !== "object" || propSchema === null) continue;
      const value = (data as Record<string, unknown>)[key];
      if (value === undefined) continue; // Optional field — skip
      const expectedType = (propSchema as Record<string, unknown>).type;
      if (typeof expectedType === "string") {
        if (!matchesType(value, expectedType)) {
          return {
            ok: false,
            error: `Field "${key}" expected type ${expectedType}, got ${typeof value}`,
          };
        }
      }
    }
  }

  return { ok: true };
}

function matchesType(value: unknown, expectedType: string): boolean {
  switch (expectedType) {
    case "string":
      return typeof value === "string";
    case "number":
      return typeof value === "number" && !isNaN(value);
    case "boolean":
      return typeof value === "boolean";
    case "array":
      return Array.isArray(value);
    case "object":
      return typeof value === "object" && value !== null && !Array.isArray(value);
    case "null":
      return value === null;
    default:
      return true; // Unknown type — pass through
  }
}

// ─── Error Helpers ───────────────────────────────────────────────

export function buildError(code: AIErrorCode, provider: AIProviderName, message: string): AIError {
  return { code, message, provider };
}

function isAIError(err: unknown): err is AIError {
  return typeof err === "object" && err !== null && "code" in err && "provider" in err;
}

function wrapProviderError(err: unknown, provider: AIProviderName): AIError {
  if (err instanceof Error) {
    const msg = err.message;

    // Extract Groq SDK APIError details for diagnostic logging
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const groqErr = err as any;
    const status: number | undefined = groqErr.status;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const errorBody: any = groqErr.error;

    // DEVELOPMENT LOGGING ONLY — never expose to client
    if (status !== undefined || errorBody !== undefined) {
      console.error(`[AI] Groq API error — status: ${status ?? "unknown"}`);
      if (errorBody) {
        console.error(`[AI] Groq error body:`, JSON.stringify(errorBody).slice(0, 500));
      }
      if (msg) {
        console.error(`[AI] Groq error message:`, msg.slice(0, 300));
      }
    } else {
      console.error(`[AI] Provider error (non-API):`, msg.slice(0, 300));
    }

    // Rate limit detection
    if (status === 429 || msg.includes("429") || msg.toLowerCase().includes("rate limit")) {
      return buildError("rate_limit", provider, "Rate limit exceeded. Please try again later.");
    }

    // Timeout detection
    if (msg.includes("timeout") || msg.includes("ETIMEDOUT") || msg.includes("aborted")) {
      return buildError("timeout", provider, "Request timed out.");
    }

    // Authentication error
    if (status === 401) {
      return buildError("provider_error", provider, "AI provider authentication failed.");
    }

    // Do not expose internal details to client
    return buildError("provider_error", provider, "AI provider request failed.");
  }

  return buildError("unknown", provider, "An unexpected error occurred.");
}

// ─── Usage Parsing ───────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function parseUsage(raw: any): AIUsage | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  return {
    promptTokens: (raw.prompt_tokens as number) ?? 0,
    completionTokens: (raw.completion_tokens as number) ?? 0,
    totalTokens: (raw.total_tokens as number) ?? 0,
  };
}
