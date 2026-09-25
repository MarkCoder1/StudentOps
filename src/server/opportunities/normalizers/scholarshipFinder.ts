import type { Opportunity } from "../models/opportunity";
import { makeOpportunityId } from "../models/opportunity";

interface ScholarshipFinderRaw {
  title?: string;
  detail_url?: string;
  award?: string;
  award_amount?: number | null;
  deadline?: string | null;
  description?: string | null;
  geographic_restrictions?: string | null;
  enrollment_level?: string | null;
  majors?: string[] | string | null;
  min_award?: number | null;
  max_award?: number | null;
  award_type?: string | null;
  renewable?: boolean | string | null;
  repay_required?: boolean | string | null;
  unlimited_awards?: boolean | null;
  [key: string]: unknown;
}

function normalizeDeadline(value?: string | null): string | null {
  if (!value || typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.toLowerCase() === "not specified") return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    const d = new Date(trimmed);
    if (!isNaN(d.getTime())) return trimmed;
  }
  // Try ISO parse but be conservative
  const d = new Date(trimmed);
  if (!isNaN(d.getTime()) && /\d{4}/.test(trimmed)) {
    // Return original if not YYYY-MM-DD but looks like date — normalize to YYYY-MM-DD if possible
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;
    // For other formats, attempt to output YYYY-MM-DD
    const y = d.getUTCFullYear();
    const m = String(d.getUTCMonth() + 1).padStart(2, "0");
    const day = String(d.getUTCDate()).padStart(2, "0");
    if (y >= 2000 && y <= 2100) return `${y}-${m}-${day}`;
  }
  return null;
}

function parseMajors(value?: string[] | string | null): string[] {
  if (Array.isArray(value)) return value.filter((v) => typeof v === "string");
  if (typeof value === "string" && value.trim()) return [value.trim()];
  return [];
}

export function normalizeScholarshipFinder(raw: ScholarshipFinderRaw, fetchedAt: string): Opportunity {
  const externalId = String(raw.detail_url ?? raw.title ?? Math.random().toString(36).slice(2));
  const idSource = raw.detail_url ? String(raw.detail_url) : String(raw.title ?? externalId);
  const id = makeOpportunityId("scholarshipFinder", idSource);
  const title = (raw.title ?? "").toString().trim();

  const deadline = normalizeDeadline(raw.deadline as string | null);

  const awardText = typeof raw.award === "string" && raw.award.trim() ? raw.award.trim() : null;
  let awardAmount: number | null = null;
  let awardCurrency: string | null = null;
  if (typeof raw.award_amount === "number") awardAmount = raw.award_amount;
  else if (typeof raw.min_award === "number") awardAmount = raw.min_award;
  else if (typeof raw.max_award === "number") awardAmount = raw.max_award;
  if (awardAmount !== null) awardCurrency = "USD"; // CollegeScholarships.org is US

  const majors = parseMajors(raw.majors);
  const enrollmentLevels =
    typeof raw.enrollment_level === "string" && raw.enrollment_level.trim()
      ? [raw.enrollment_level.trim()]
      : null;

  const url = typeof raw.detail_url === "string" && raw.detail_url ? raw.detail_url : null;

  return {
    id,
    source: "scholarshipFinder",
    externalId: idSource,
    title,
    description: typeof raw.description === "string" ? raw.description : null,
    organization: null,
    officialUrl: url,
    applicationUrl: url,
    sourceUrl: url,
    category: "scholarship",
    sourceCategory: typeof raw.award_type === "string" ? raw.award_type : "scholarship",
    subjects: majors,
    topics: majors,
    skills: [],
    deadline,
    startDate: null,
    endDate: null,
    location: {
      type: "unknown",
      city: null,
      state: null,
      country: raw.geographic_restrictions ? null : null, // only eligibility, not location
      online: null,
      latitude: null,
      longitude: null,
    },
    cost: { amount: null, currency: null, isFree: null },
    benefits: {
      awardText,
      awardAmount,
      awardCurrency,
      prizeText: awardText,
    },
    eligibility: {
      minAge: null,
      maxAge: null,
      gradeMin: null,
      gradeMax: null,
      countries: null,
      geographicRestrictions:
        typeof raw.geographic_restrictions === "string" && raw.geographic_restrictions.trim()
          ? raw.geographic_restrictions.trim()
          : null,
      enrollmentLevels,
      majors: majors.length ? majors : null,
      requirements: null,
    },
    provenance: {
      source: "scholarshipFinder",
      externalId: idSource,
      fetchedAt,
      sourceUpdatedAt: null,
    },
    sourceMetadata: {
      originalCategory: raw.award_type ?? null,
      min_award: raw.min_award ?? null,
      max_award: raw.max_award ?? null,
      award_amount: raw.award_amount ?? null,
      geographic_restrictions: raw.geographic_restrictions ?? null,
      enrollment_level: raw.enrollment_level ?? null,
      renewable: raw.renewable ?? null,
      repay_required: raw.repay_required ?? null,
      unlimited_awards: raw.unlimited_awards ?? null,
    },
  };
}
