// Universal Opportunity — Phase 5.2
// No deduplication, eligibility decision, matching, ranking, or DB here.

import type { OpportunitySource } from "../sources/types";

export type OpportunityCategory =
  | "competition"
  | "hackathon"
  | "scholarship"
  | "internship"
  | "fellowship"
  | "research"
  | "leadership"
  | "volunteering"
  | "summerProgram"
  | "academicProgram"
  | "workshop"
  | "conference"
  | "creative"
  | "other";

export type LocationType = "online" | "inPerson" | "hybrid" | "unknown";

export interface OpportunityLocation {
  type: LocationType;
  city: string | null;
  state: string | null;
  country: string | null;
  online: boolean | null;
  latitude: number | null;
  longitude: number | null;
}

export interface OpportunityCost {
  amount: number | null;
  currency: string | null;
  isFree: boolean | null;
}

export interface OpportunityBenefits {
  awardText: string | null;
  awardAmount: number | null;
  awardCurrency: string | null;
  prizeText: string | null;
}

export interface OpportunityEligibility {
  minAge: number | null;
  maxAge: number | null;
  gradeMin: string | null;
  gradeMax: string | null;
  countries: string[] | null;
  geographicRestrictions: string | null;
  enrollmentLevels: string[] | null;
  majors: string[] | null;
  requirements: string[] | null;
}

export interface OpportunityProvenance {
  source: OpportunitySource;
  externalId: string;
  fetchedAt: string; // ISO
  sourceUpdatedAt: string | null;
  raw?: unknown; // lightweight, not full payload dup
}

export interface OpportunitySourceMetadata {
  originalCategory?: string | null;
  originalFormat?: string | null;
  originalParticipation?: string | null;
  originalThemes?: string[] | null;
  originalRegion?: string | null;
  originalFee?: unknown;
  [key: string]: unknown;
}

export interface Opportunity {
  // Identity — deterministic for now (source:externalId)
  id: string;
  source: OpportunitySource;
  externalId: string;

  // Basic
  title: string;
  description: string | null;
  organization: string | null;
  officialUrl: string | null;
  applicationUrl: string | null;
  sourceUrl: string | null;

  // Category
  category: OpportunityCategory;
  sourceCategory: string | null;

  // Topics
  subjects: string[];
  topics: string[];
  skills: string[];

  // Timing — ISO 8601 (YYYY-MM-DD or full timestamp)
  deadline: string | null; // YYYY-MM-DD or ISO
  startDate: string | null;
  endDate: string | null;

  // Location
  location: OpportunityLocation;

  // Cost (application fee, NOT prize)
  cost: OpportunityCost;

  // Benefits/Awards
  benefits: OpportunityBenefits;

  // Eligibility — extraction only, no boolean decision
  eligibility: OpportunityEligibility;

  // Provenance
  provenance: OpportunityProvenance;

  // Small source-specific preservation
  sourceMetadata: OpportunitySourceMetadata;

  // Deduplication provenance (Phase 5.3) — lightweight refs to contributing records
  sourceRecords?: Array<{ source: OpportunitySource; externalId: string }>;
}

// Helpers
export function makeOpportunityId(source: OpportunitySource, externalId: string): string {
  return `${source}:${externalId}`;
}

export function isValidUrl(value: string | null): boolean {
  if (!value) return true; // null is allowed (optional field)
  try {
    const u = new URL(value);
    return u.protocol === "http:" || u.protocol === "https:";
  } catch {
    return false;
  }
}

export function isValidIsoDate(value: string | null): boolean {
  if (value === null) return true;
  // Accept YYYY-MM-DD or full ISO
  const isoDate = /^\d{4}-\d{2}-\d{2}$/;
  const isoDateTime = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/;
  if (isoDate.test(value)) {
    const d = new Date(value);
    return !isNaN(d.getTime());
  }
  if (isoDateTime.test(value)) {
    const d = new Date(value);
    return !isNaN(d.getTime());
  }
  return false;
}
