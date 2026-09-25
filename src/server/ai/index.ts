// AI Layer — Phase 6.1
// Provider-isolated AI abstraction for Student OPS.
// Server-only — never import from client code or Swift.

export type {
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

export type { AIProvider } from "./provider";

export type {
  AIStudentContext,
  AIOpportunityContext,
  AIEngineResult,
  AIStudentOpportunityContext,
  AIBatchContext,
} from "./context";

export {
  buildStudentContext,
  buildOpportunityContext,
  buildEngineResult,
  buildStudentOpportunityContext,
  buildBatchContext,
} from "./context";

export { GroqProvider } from "./groq";

// ─── Singleton Provider Access ───────────────────────────────────

import type { AIProvider } from "./provider";
import type { AIProviderConfig } from "./types";
import { GroqProvider } from "./groq";

let defaultProvider: AIProvider | null = null;

/**
 * Get the default AI provider (Groq).
 * Lazily initialized — safe to call before env is ready.
 */
export function getAIProvider(): AIProvider {
  if (!defaultProvider) {
    defaultProvider = new GroqProvider();
  }
  return defaultProvider;
}

/**
 * Create a provider with custom configuration.
 * Useful for testing or overriding defaults.
 */
export function createAIProvider(config?: Partial<AIProviderConfig>): AIProvider {
  return new GroqProvider(config);
}

/**
 * Reset the default provider (for testing).
 */
export function resetAIProvider(): void {
  defaultProvider = null;
}
