import type { Opportunity, OpportunityCategory } from "../models/opportunity";
import { makeOpportunityId } from "../models/opportunity";

interface StudentSuiteRaw {
  id: string;
  name?: string;
  title?: string;
  organizer?: string;
  organizer_url?: string;
  category?: string;
  subjects?: string[];
  description?: string;
  format?: string;
  age_min?: number | null;
  age_max?: number | null;
  participation?: string;
  region?: string;
  fee?: { amount?: number | null; currency?: string | null } | null;
  prize?: string | null;
  official_url?: string | null;
  cycle_year?: number;
  dates?: Array<{
    label?: string;
    date?: string;
    type?: string;
    timezone?: string | null;
    estimated?: boolean;
    source_url?: string | null;
  }>;
  country_tracks?: Array<{ country: string; track?: string }>;
  added_by?: string;
  verified?: { by?: string; on?: string | null };
  valid_till?: string | null;
  image?: string | null;
  [key: string]: unknown;
}

function mapStudentSuiteCategory(_rawCategory: string | undefined): OpportunityCategory {
  // All StudentSuite records are competitions per spec
  return "competition";
}

function mapStudentSuiteLocation(
  format?: string,
  region?: string
): Opportunity["location"] {
  let type: Opportunity["location"]["type"] = "unknown";
  let online: boolean | null = null;
  if (format === "online") {
    type = "online";
    online = true;
  } else if (format === "in_person") {
    type = "inPerson";
    online = false;
  } else if (format === "hybrid") {
    type = "hybrid";
    online = null;
  }
  // region is "international" or ISO code; only populate when explicit and not international
  let country: string | null = null;
  let city: string | null = null;
  if (region && region !== "international") {
    // region may be ISO alpha-2 like US
    if (/^[A-Z]{2}$/.test(region)) country = region;
    else city = region;
  }
  return {
    type,
    city,
    state: null,
    country,
    online,
    latitude: null,
    longitude: null,
  };
}

function findDeadline(dates?: StudentSuiteRaw["dates"]): string | null {
  if (!Array.isArray(dates)) return null;
  const deadline = dates.find((d) => d.type === "deadline" && typeof d.date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d.date));
  return deadline?.date ?? null;
  // Do not confuse results type — explicitly filter deadline only
}

export function normalizeStudentSuite(
  raw: StudentSuiteRaw,
  fetchedAt: string
): Opportunity {
  const externalId = String(raw.id ?? "");
  const title = (raw.name ?? raw.title ?? "").toString().trim();
  const sourceCategory = raw.category ?? null;
  const category = mapStudentSuiteCategory(raw.category);

  const feeAmount =
    raw.fee && typeof raw.fee.amount === "number" ? raw.fee.amount : null;
  const feeCurrency =
    raw.fee && typeof raw.fee.currency === "string" ? raw.fee.currency : null;

  const costIsFree =
    typeof feeAmount === "number" ? feeAmount === 0 : null;

  const deadline = findDeadline(raw.dates);

  // Preserve full dates array in sourceMetadata for later if needed, but keep provenance light
  const countriesFromTracks = Array.isArray(raw.country_tracks)
    ? (raw.country_tracks
        .map((ct) => (typeof ct.country === "string" ? ct.country : null))
        .filter(Boolean) as string[])
    : null;

  const id = makeOpportunityId("studentSuite", externalId);

  return {
    id,
    source: "studentSuite",
    externalId,
    title,
    description: typeof raw.description === "string" ? raw.description : null,
    organization: typeof raw.organizer === "string" ? raw.organizer : null,
    officialUrl:
      typeof raw.official_url === "string" && raw.official_url
        ? raw.official_url
        : null,
    applicationUrl:
      typeof raw.official_url === "string" && raw.official_url
        ? raw.official_url
        : null,
    sourceUrl:
      typeof raw.official_url === "string" && raw.official_url
        ? raw.official_url
        : typeof raw.organizer_url === "string"
          ? raw.organizer_url
          : null,
    category,
    sourceCategory,
    subjects: Array.isArray(raw.subjects) ? raw.subjects.filter((s) => typeof s === "string") : [],
    topics: Array.isArray(raw.subjects) ? raw.subjects.filter((s) => typeof s === "string") : [],
    skills: [],
    deadline,
    startDate: null,
    endDate: null,
    location: mapStudentSuiteLocation(raw.format, raw.region),
    cost: {
      amount: feeAmount,
      currency: feeCurrency,
      isFree: costIsFree,
    },
    benefits: {
      awardText: null,
      awardAmount: null,
      awardCurrency: null,
      prizeText: typeof raw.prize === "string" ? raw.prize : null,
    },
    eligibility: {
      minAge: typeof raw.age_min === "number" ? raw.age_min : null,
      maxAge: typeof raw.age_max === "number" ? raw.age_max : null,
      gradeMin: null,
      gradeMax: null,
      countries: countriesFromTracks && countriesFromTracks.length ? countriesFromTracks : null,
      geographicRestrictions: typeof raw.region === "string" ? raw.region : null,
      enrollmentLevels: null,
      majors: null,
      requirements: null,
    },
    provenance: {
      source: "studentSuite",
      externalId,
      fetchedAt,
      sourceUpdatedAt:
        raw.verified && typeof (raw.verified as any).on === "string"
          ? (raw.verified as any).on
          : null,
    },
    sourceMetadata: {
      originalCategory: raw.category ?? null,
      originalFormat: raw.format ?? null,
      originalParticipation: raw.participation ?? null,
      originalRegion: raw.region ?? null,
      originalFee: raw.fee ?? null,
      cycle_year: raw.cycle_year ?? null,
      verified: raw.verified ?? null,
    },
  };
}
