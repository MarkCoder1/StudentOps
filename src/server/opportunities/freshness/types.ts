// Freshness types — Phase 5.6
// No database, no API, no mutation.

export type FreshnessStatus = "active" | "upcoming" | "expired" | "unknown";

export type DataFreshness = "fresh" | "stale" | "unknown";

export type DeadlineUrgency = "urgent" | "soon" | "upcoming" | "later" | "none";

export interface FreshnessResult {
  status: FreshnessStatus;
  dataFreshness: DataFreshness;
  deadlineUrgency: DeadlineUrgency;
  deadline: string | null;
  startDate: string | null;
  endDate: string | null;
  daysUntilDeadline: number | null;
  daysUntilStart: number | null;
  daysSinceDeadline: number | null;
  reason: string;
}

// Threshold as named constant
export const DEFAULT_STALE_AFTER_DAYS = 7;
