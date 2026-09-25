// AI Provider Abstraction — Phase 6.1
// Abstract interface that all AI providers must implement.
// Groq implementation lives in groq.ts.

import type {
  AIProviderConfig,
  AIProviderName,
  AIRequest,
  AIStructuredRequest,
  AIResult,
  AIError,
} from "./types";

export interface AIProvider {
  /** Provider identifier. */
  readonly name: AIProviderName;

  /** Provider configuration (read-only). */
  readonly config: AIProviderConfig;

  /**
   * Generate a raw text completion.
   * Use generateStructured() when you need typed output.
   */
  generate(request: AIRequest): Promise<AIResult<string>>;

  /**
   * Generate a structured, validated result.
   * The response is parsed against the provided JSON Schema.
   */
  generateStructured<T = unknown>(
    request: AIStructuredRequest
  ): Promise<AIResult<T>>;

  /**
   * Verify the provider can be initialized (API key present, etc.).
   * Returns Ok or an AIError.
   */
  healthCheck(): Promise<{ ok: true } | { ok: false; error: AIError }>;
}
