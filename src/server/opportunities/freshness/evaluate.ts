import type { Opportunity } from "../models/opportunity";
import {
  DEFAULT_STALE_AFTER_DAYS,
  type DataFreshness,
  type DeadlineUrgency,
  type FreshnessResult,
  type FreshnessStatus,
} from "./types";

function parseIsoDate(value: string | null | undefined): Date | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  // Try full ISO first
  let d = new Date(trimmed);
  if (!isNaN(d.getTime())) {
    // For date-only YYYY-MM-DD, interpret as UTC midnight to avoid device timezone drift
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
      const [y, m, day] = trimmed.split("-").map(Number);
      return new Date(Date.UTC(y, m - 1, day));
    }
    return d;
  }
  return null;
}

function dateOnlyUTC(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function diffDays(a: Date, b: Date): number {
  // a - b in days, using UTC date-only for date-only deadlines
  const msPerDay = 24 * 60 * 60 * 1000;
  const utcA = Date.UTC(a.getUTCFullYear(), a.getUTCMonth(), a.getUTCDate());
  const utcB = Date.UTC(b.getUTCFullYear(), b.getUTCMonth(), b.getUTCDate());
  return Math.round((utcA - utcB) / msPerDay);
}

function isDateOnly(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function getDataFreshness(
  fetchedAt: string | null | undefined,
  asOf: Date
): DataFreshness {
  if (!fetchedAt) return "unknown";
  const parsed = parseIsoDate(fetchedAt);
  if (!parsed) return "unknown";
  const days = diffDays(asOf, parsed);
  // fetchedAt in future? treat as fresh
  if (days < 0) return "fresh";
  if (days <= DEFAULT_STALE_AFTER_DAYS) return "fresh";
  return "stale";
}

function getDeadlineUrgency(daysUntil: number | null): DeadlineUrgency {
  if (daysUntil === null) return "none";
  if (daysUntil >= 0 && daysUntil <= 3) return "urgent";
  if (daysUntil >= 4 && daysUntil <= 7) return "soon";
  if (daysUntil >= 8 && daysUntil <= 30) return "upcoming";
  if (daysUntil > 30) return "later";
  // Negative (expired) should not have urgency, but if called, treat as none
  return "none";
}

export function evaluateFreshness(
  opportunity: Opportunity,
  asOf: Date
): FreshnessResult {
  const deadlineStr = opportunity.deadline;
  const startStr = opportunity.startDate;
  const endStr = opportunity.endDate;

  const deadlineDate = parseIsoDate(deadlineStr);
  const startDate = parseIsoDate(startStr);
  const endDate = parseIsoDate(endStr);

  // Validate: if provided but invalid, treat as not provided for status, but ensure unknown handling
  const hasValidDeadline = deadlineStr !== null && deadlineDate !== null;
  const hasValidStart = startStr !== null && startDate !== null;
  const hasValidEnd = endStr !== null && endDate !== null;

  // If provided string but invalid → unknown (do not crash)
  const hasInvalidDate =
    (deadlineStr !== null && !hasValidDeadline) ||
    (startStr !== null && !hasValidStart) ||
    (endStr !== null && !hasValidEnd);

  // Data freshness separate from opportunity status
  const dataFreshness = getDataFreshness(
    opportunity.provenance?.fetchedAt ?? null,
    asOf
  );

  let status: FreshnessStatus = "unknown";
  let daysUntilDeadline: number | null = null;
  let daysSinceDeadline: number | null = null;
  let daysUntilStart: number | null = null;
  let reason = "";

  // Priority: deadline controls if exists and valid
  if (hasValidDeadline && deadlineDate) {
    // Use date-only comparison for deadline (YYYY-MM-DD) vs asOf
    // Deadline on same day => active with 0 days
    const asOfDateOnly = dateOnlyUTC(asOf);
    const deadlineDateOnly = dateOnlyUTC(deadlineDate);
    const diff = diffDays(deadlineDateOnly, asOfDateOnly);
    if (diff > 0) {
      status = "active";
      daysUntilDeadline = diff;
      reason = `Deadline is in ${diff} day${diff === 1 ? "" : "s"}.`;
    } else if (diff === 0) {
      status = "active";
      daysUntilDeadline = 0;
      reason = "Deadline is today.";
    } else {
      status = "expired";
      daysSinceDeadline = Math.abs(diff);
      reason = `Deadline passed ${Math.abs(diff)} day${Math.abs(diff) === 1 ? "" : "s"} ago.`;
    }
  } else if (hasValidStart && startDate) {
    // No valid deadline, use event dates
    const asOfTime = asOf.getTime();
    const startTime = startDate.getTime();
    const endTime = hasValidEnd && endDate ? endDate.getTime() : null;

    if (endTime !== null) {
      if (asOfTime < startTime) {
        status = "upcoming";
        daysUntilStart = diffDays(startDate, asOf);
        reason = `Event starts in ${daysUntilStart} day${daysUntilStart === 1 ? "" : "s"}.`;
      } else if (asOfTime >= startTime && asOfTime <= endTime) {
        status = "active";
        reason = "Event is currently in progress.";
      } else {
        status = "expired";
        reason = "Event has ended.";
      }
    } else {
      // No endDate — conservative one-time event handling
      const startDateOnly = dateOnlyUTC(startDate);
      const asOfDateOnly = dateOnlyUTC(asOf);
      const diff = diffDays(startDateOnly, asOfDateOnly);
      if (diff > 0) {
        status = "upcoming";
        daysUntilStart = diff;
        reason = `Event starts in ${diff} day${diff === 1 ? "" : "s"}.`;
      } else if (diff === 0) {
        status = "active";
        daysUntilStart = 0;
        reason = "Event starts today.";
      } else {
        // Passed start with no end — treat as expired (one-time event)
        status = "expired";
        reason = "Event has passed.";
      }
    }
  } else {
    // No useful date
    if (hasInvalidDate) {
      status = "unknown";
      reason = "Invalid date provided.";
    } else {
      status = "unknown";
      reason = "No deadline or event date is available.";
    }
  }

  // Urgency based on daysUntilDeadline (null if expired or no deadline)
  const deadlineUrgency: DeadlineUrgency =
    status === "expired" ? "none" : getDeadlineUrgency(daysUntilDeadline);

  return {
    status,
    dataFreshness,
    deadlineUrgency,
    deadline: hasValidDeadline ? deadlineStr : null,
    startDate: hasValidStart ? startStr : null,
    endDate: hasValidEnd ? endStr : null,
    daysUntilDeadline,
    daysUntilStart,
    daysSinceDeadline,
    reason,
  };
}

export function evaluateFreshnessBatch(
  opportunities: Opportunity[],
  asOf: Date
): Array<{ opportunity: Opportunity; freshness: FreshnessResult }> {
  // Preserve input order, deterministic, no sort
  return opportunities.map((opp) => ({
    opportunity: opp,
    freshness: evaluateFreshness(opp, asOf),
  }));
}
