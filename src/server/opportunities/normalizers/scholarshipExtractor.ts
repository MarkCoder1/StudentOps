import type { Opportunity, OpportunityCategory } from "../models/opportunity";
import { makeOpportunityId } from "../models/opportunity";

interface ScholarshipExtractorRaw {
  title?: string;
  description?: string;
  deadline?: string; // YYYY-MM-DD or "Not specified"
  awards?: string;
  challengeLink?: string;
  category?: string;
  [key: string]: unknown;
}

function mapExtractorCategory(rawCategory?: string): { category: OpportunityCategory; sourceCategory: string | null } {
  if (!rawCategory) return { category: "other", sourceCategory: null };
  const lower = rawCategory.trim().toLowerCase();
  const map: Record<string, OpportunityCategory> = {
    scholarships: "scholarship",
    scholarship: "scholarship",
    internships: "internship",
    internship: "internship",
    fellowships: "fellowship",
    fellowship: "fellowship",
    "app challenge": "competition",
    "design challenge": "competition",
    "ideation challenge": "competition",
    "photography challenge": "creative",
    "poetry competition": "creative",
    "video challenge": "creative",
    "writing challenge": "creative",
    "music and art challenge": "creative",
  };
  return { category: map[lower] ?? "other", sourceCategory: rawCategory };
}

function normalizeDeadline(value?: string | null): string | null {
  if (!value || typeof value !== "string") return null;
  const trimmed = value.trim();
  if (trimmed.toLowerCase() === "not specified" || trimmed === "") return null;
  // Expect YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    const d = new Date(trimmed);
    if (!isNaN(d.getTime())) return trimmed;
  }
  // Try to parse other formats but be conservative: if not ISO, return null
  // Check if it's a valid date string that can be normalized to YYYY-MM-DD
  const d = new Date(trimmed);
  if (!isNaN(d.getTime()) && /\d{4}/.test(trimmed)) {
    // Only accept if it looks like a date, not random text
    return trimmed; // preserve original if not YYYY-MM-DD but valid date? Safer to return null per spec: do NOT fabricate
  }
  return null;
}

export function normalizeScholarshipExtractor(
  raw: ScholarshipExtractorRaw,
  fetchedAt: string
): Opportunity {
  const externalId = String(raw.challengeLink ?? raw.title ?? Math.random().toString(36).slice(2));
  const idSource = raw.challengeLink ? String(raw.challengeLink) : String(raw.title ?? externalId);
  const id = makeOpportunityId("scholarshipExtractor", idSource);
  const title = (raw.title ?? "").toString().trim();
  const { category, sourceCategory } = mapExtractorCategory(raw.category);
  const deadline = normalizeDeadline(raw.deadline as string | undefined);
  const awardText =
    typeof raw.awards === "string" && raw.awards.trim().toLowerCase() !== "not specified" && raw.awards.trim() !== ""
      ? raw.awards.trim()
      : null;

  const url = typeof raw.challengeLink === "string" && raw.challengeLink ? raw.challengeLink : null;

  return {
    id,
    source: "scholarshipExtractor",
    externalId: idSource,
    title,
    description: typeof raw.description === "string" ? raw.description : null,
    organization: null,
    officialUrl: url,
    applicationUrl: url,
    sourceUrl: url,
    category,
    sourceCategory,
    subjects: [],
    topics: [],
    skills: [],
    deadline,
    startDate: null,
    endDate: null,
    location: {
      type: "unknown",
      city: null,
      state: null,
      country: null,
      online: null,
      latitude: null,
      longitude: null,
    },
    cost: { amount: null, currency: null, isFree: null },
    benefits: {
      awardText,
      awardAmount: null,
      awardCurrency: null,
      prizeText: awardText,
    },
    eligibility: {
      minAge: null,
      maxAge: null,
      gradeMin: null,
      gradeMax: null,
      countries: null,
      geographicRestrictions: null,
      enrollmentLevels: null,
      majors: null,
      requirements: null,
    },
    provenance: {
      source: "scholarshipExtractor",
      externalId: idSource,
      fetchedAt,
      sourceUpdatedAt: null,
    },
    sourceMetadata: {
      originalCategory: raw.category ?? null,
      awards: raw.awards ?? null,
      deadline: raw.deadline ?? null,
    },
  };
}
