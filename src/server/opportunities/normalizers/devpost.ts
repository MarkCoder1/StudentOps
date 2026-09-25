import type { Opportunity } from "../models/opportunity";
import { makeOpportunityId } from "../models/opportunity";

interface DevpostRaw {
  id?: number | string;
  title?: string;
  url?: string;
  organizationName?: string;
  location?: string;
  openState?: string;
  submissionPeriodDates?: string;
  timeLeftToSubmission?: string;
  themes?: string[];
  prizeAmount?: string;
  cashPrizesCount?: number;
  otherPrizesCount?: number;
  registrationsCount?: number;
  featured?: boolean;
  winnersAnnounced?: boolean;
  inviteOnly?: boolean;
  thumbnailUrl?: string;
  submissionGalleryUrl?: string;
  [key: string]: unknown;
}

// Conservative parser for "Apr 09 - May 20, 2026" etc.
// Returns ISO YYYY-MM-DD or null if ambiguous.
function parseSubmissionPeriod(
  raw: string | undefined
): { startDate: string | null; deadline: string | null } {
  if (!raw || typeof raw !== "string") return { startDate: null, deadline: null };
  const trimmed = raw.trim();
  if (!trimmed) return { startDate: null, deadline: null };

  // Split on " - "
  const parts = trimmed.split(" - ").map((p) => p.trim()).filter(Boolean);
  if (parts.length === 1) {
    const d = parseSingleDate(parts[0]);
    return { startDate: d, deadline: d };
  }
  if (parts.length === 2) {
    // Second part should contain year
    const second = parseSingleDate(parts[1]);
    if (!second) return { startDate: null, deadline: null };
    const secondDate = new Date(second);
    const year = secondDate.getUTCFullYear();
    // First part may be "Apr 09" or "Nov 28"
    let firstStr = parts[0];
    // If first part already contains year (has comma), parse directly
    let first: string | null = null;
    if (firstStr.includes(",")) {
      first = parseSingleDate(firstStr);
    } else {
      // Append year from second
      first = parseSingleDate(`${firstStr}, ${year}`);
      // Handle case like "Nov 28" where second is "29, 2015" -> first "Nov 28" should be Nov 28, 2015 (same month as second? Actually second is just day+year, need month)
      // For "Nov 28 - 29, 2015", first is "Nov 28", second is "29, 2015" -> second parse will be "29, 2015" which Date may parse as Jan 29, 2015? Better handle.
      // Detect if second part is like "29, 2015" (only day + year) then first's month should be used for second's month?
      // Conservative: if second part does not contain month name, assume same month as first.
      if (!first && /^[0-9]{1,2},/.test(parts[1])) {
        // parts[1] is "29, 2015" — extract month from first
        const monthMatch = firstStr.match(/[A-Za-z]+/);
        if (monthMatch) {
          first = parseSingleDate(`${monthMatch[0]} ${parts[0].replace(monthMatch[0], "").trim()}, ${year}`);
          // Actually first already is e.g., "Nov 28" -> we already tried "Nov 28, 2015" and got first.
        }
      }
      // If second was "29, 2015" style, our second parse via parseSingleDate may have failed or mis-parsed.
      // Re-parse second with month from first if needed
      if (second && /^[0-9]{1,2},/.test(parts[1])) {
        const month = firstStr.match(/[A-Za-z]+/)?.[0];
        if (month) {
          const correctedSecondStr = `${month} ${parts[1]}`;
          const corrected = parseSingleDate(correctedSecondStr);
          if (corrected) {
            return { startDate: first, deadline: corrected };
          }
        }
      }
    }
    return { startDate: first, deadline: second };
  }
  return { startDate: null, deadline: null };
}

function parseSingleDate(str: string): string | null {
  const d = new Date(str);
  if (isNaN(d.getTime())) return null;
  // Verify the string looks like a date (contains month name or year)
  // Avoid parsing random strings like "Online"
  if (!/[A-Za-z]{3,}/.test(str) && !/\d{4}/.test(str)) return null;
  const year = d.getUTCFullYear();
  // Only accept reasonable years 2000-2100
  if (year < 2000 || year > 2100) return null;
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  // Use UTC to avoid timezone shift
  // Check that parsed month/day matches input to avoid false positives like "29, 2015" -> Jan 29
  // For "29, 2015" we already handle separately
  return `${year}-${month}-${day}`;
}

function mapDevpostLocation(location?: string): Opportunity["location"] {
  if (!location || typeof location !== "string") {
    return { type: "unknown", city: null, state: null, country: null, online: null, latitude: null, longitude: null };
  }
  const lower = location.trim().toLowerCase();
  if (lower === "online") {
    return { type: "online", city: null, state: null, country: null, online: true, latitude: null, longitude: null };
  }
  // Preserve as city for in-person, no geocoding
  return { type: "inPerson", city: location.trim(), state: null, country: null, online: false, latitude: null, longitude: null };
}

export function normalizeDevpost(raw: DevpostRaw, fetchedAt: string): Opportunity {
  const externalId = String(raw.id ?? "");
  const id = makeOpportunityId("devpost", externalId);
  const title = (raw.title ?? "").toString().trim();
  const url = typeof raw.url === "string" && raw.url ? raw.url : null;
  const themes = Array.isArray(raw.themes) ? raw.themes.filter((t) => typeof t === "string") : [];
  const { startDate, deadline } = parseSubmissionPeriod(raw.submissionPeriodDates);

  return {
    id,
    source: "devpost",
    externalId,
    title,
    description: null, // Devpost list API does not provide description in this payload
    organization: typeof raw.organizationName === "string" ? raw.organizationName : null,
    officialUrl: url,
    applicationUrl: url,
    sourceUrl: url,
    category: "hackathon",
    sourceCategory: "hackathon",
    subjects: [],
    topics: themes,
    skills: [],
    deadline,
    startDate,
    endDate: null,
    location: mapDevpostLocation(raw.location),
    cost: { amount: null, currency: null, isFree: null },
    benefits: {
      awardText: null,
      awardAmount: null,
      awardCurrency: null,
      prizeText: typeof raw.prizeAmount === "string" ? raw.prizeAmount : null,
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
      source: "devpost",
      externalId,
      fetchedAt,
      sourceUpdatedAt: null,
    },
    sourceMetadata: {
      originalCategory: "hackathon",
      originalThemes: themes,
      openState: raw.openState ?? null,
      submissionPeriodDates: raw.submissionPeriodDates ?? null,
      timeLeftToSubmission: raw.timeLeftToSubmission ?? null,
      cashPrizesCount: raw.cashPrizesCount ?? null,
      otherPrizesCount: raw.otherPrizesCount ?? null,
      registrationsCount: raw.registrationsCount ?? null,
      featured: raw.featured ?? null,
      inviteOnly: raw.inviteOnly ?? null,
      thumbnailUrl: raw.thumbnailUrl ?? null,
      submissionGalleryUrl: raw.submissionGalleryUrl ?? null,
    },
  };
}
