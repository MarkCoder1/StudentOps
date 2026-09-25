import type { Opportunity } from "../models/opportunity";

export type Confidence = "very-strong" | "strong" | "medium" | "weak" | "none";

export interface DuplicateGroup {
  canonicalId: string;
  mergedIds: string[]; // includes canonicalId + all duplicates in group
  confidence: Confidence;
  reason: string;
  // Optional for inspection
  members?: Opportunity[];
}

export interface DeduplicationResult {
  opportunities: Opportunity[]; // canonical unique opportunities
  duplicateGroups: DuplicateGroup[];
  statistics: {
    inputCount: number;
    outputCount: number;
    duplicateCount: number;
    duplicateGroupCount: number;
    bySource?: Record<string, number>;
  };
}

export interface ComparisonSignals {
  sameSourceAndExternalId: boolean;
  sameOfficialUrl: boolean;
  sameApplicationUrl: boolean;
  titleExactMatch: boolean;
  titleSimilar: boolean;
  titleSimilarity: number; // 0-1
  orgExactMatch: boolean;
  orgSimilar: boolean;
  deadlineMatch: boolean; // both non-null and equal
  deadlineMismatch: boolean; // both non-null and different
  deadlineUnknown: boolean; // at least one null
  locationMatch: boolean;
  startDateMatch: boolean;
  cycleYearMatch: boolean | null; // null if not applicable
  cycleYearMismatch: boolean;
}
