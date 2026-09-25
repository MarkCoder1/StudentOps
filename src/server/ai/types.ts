// AI Provider Abstraction — Phase 6.1
// Provider-isolated types for Student OPS AI layer.
// No Groq-specific types here — those live in groq.ts.

// ─── Configuration ───────────────────────────────────────────────

export interface AIProviderConfig {
  provider: AIProviderName;
  model: string;
  temperature: number;
  maxCompletionTokens: number;
  timeoutMs: number;
}

export type AIProviderName = "groq";

// ─── Request ─────────────────────────────────────────────────────

export interface AIRequest {
  /** System prompt — sets role, context, constraints. */
  system: string;
  /** User prompt — the specific task/question. */
  user: string;
  /** Temperature override (0–2). Lower = more deterministic. */
  temperature?: number;
  /** Max completion tokens override. */
  maxCompletionTokens?: number;
  /** Reasoning effort for models that support it. Lower = fewer reasoning tokens. */
  reasoningEffort?: "none" | "low" | "medium" | "high";
}

// ─── Structured Output ───────────────────────────────────────────

/** JSON Schema definition for structured output (draft 2020-12). */
export interface AISchema {
  /** Schema name (a-z, A-Z, 0-9, underscores, dashes; max 64 chars). */
  name: string;
  /** Human-readable description. */
  description?: string;
  /** JSON Schema object. */
  schema: Record<string, unknown>;
  /** Strict schema adherence. Default false. */
  strict?: boolean;
}

/** Request with typed structured output. */
export interface AIStructuredRequest extends AIRequest {
  /** JSON Schema for the expected response shape. */
  outputSchema: AISchema;
}

// ─── Result ──────────────────────────────────────────────────────

export interface AIResult<T = unknown> {
  /** Parsed and validated structured data. */
  data: T;
  /** Raw text from the model (for debugging). */
  rawText?: string;
  /** Model that generated the response. */
  model: string;
  /** Provider that handled the request. */
  provider: AIProviderName;
  /** Token usage if available. */
  usage?: AIUsage;
}

export interface AIUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

// ─── Errors ──────────────────────────────────────────────────────

export type AIErrorCode =
  | "missing_api_key"
  | "provider_error"
  | "timeout"
  | "invalid_json"
  | "schema_validation_failed"
  | "empty_response"
  | "rate_limit"
  | "unknown";

export interface AIError {
  code: AIErrorCode;
  message: string;
  provider: AIProviderName;
  /** Never includes API keys or raw secrets. */
  detail?: string;
}
