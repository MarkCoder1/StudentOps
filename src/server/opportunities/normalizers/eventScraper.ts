import type { Opportunity } from "../models/opportunity";
import { makeOpportunityId } from "../models/opportunity";

interface EventScraperRaw {
  platform?: string;
  title?: string;
  startsAt?: string; // ISO
  timezone?: string;
  isOnline?: boolean | null;
  venueName?: string | null;
  address?: string | null;
  city?: string | null;
  country?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  rsvpCount?: number | null;
  capacity?: number | null;
  organizerName?: string | null;
  organizerUrl?: string | null;
  ticketStatus?: string | null;
  currency?: string | null;
  priceMin?: number | null;
  topics?: string[];
  category?: string;
  coverImageUrl?: string | null;
  eventUrl?: string;
  description?: string | null;
  endTime?: string | null;
  [key: string]: unknown;
}

function mapEventCategory(rawCategory?: string): { category: Opportunity["category"]; sourceCategory: string | null } {
  if (!rawCategory) return { category: "other", sourceCategory: null };
  const lower = rawCategory.toLowerCase();
  if (lower.includes("workshop")) return { category: "workshop", sourceCategory: rawCategory };
  if (lower.includes("conference")) return { category: "conference", sourceCategory: rawCategory };
  return { category: "other", sourceCategory: rawCategory };
}

function mapEventLocation(raw: EventScraperRaw): Opportunity["location"] {
  let type: Opportunity["location"]["type"] = "unknown";
  if (raw.isOnline === true) type = "online";
  else if (raw.isOnline === false) type = "inPerson";
  // Preserve isOnline boolean
  return {
    type,
    city: typeof raw.city === "string" ? raw.city : null,
    state: null,
    country: typeof raw.country === "string" ? raw.country : null,
    online: typeof raw.isOnline === "boolean" ? raw.isOnline : null,
    latitude: typeof raw.latitude === "number" ? raw.latitude : null,
    longitude: typeof raw.longitude === "number" ? raw.longitude : null,
  };
}

function normalizeIsoDate(value?: string | null): string | null {
  if (!value || typeof value !== "string") return null;
  const d = new Date(value);
  if (isNaN(d.getTime())) return null;
  return d.toISOString();
}

export function normalizeEventScraper(raw: EventScraperRaw, fetchedAt: string): Opportunity {
  const externalId = String((raw as any).id ?? raw.eventUrl ?? raw.title ?? Math.random().toString(36).slice(2));
  // Prefer eventUrl as externalId if id not present, but keep deterministic
  const idSource = (raw as any).id ? String((raw as any).id) : raw.eventUrl ? String(raw.eventUrl) : String(raw.title ?? externalId);
  const id = makeOpportunityId("eventScraper", idSource);
  const title = (raw.title ?? "").toString().trim();
  const { category, sourceCategory } = mapEventCategory(raw.category);
  const topics = Array.isArray(raw.topics) ? raw.topics.filter((t) => typeof t === "string") : [];

  const startDate = normalizeIsoDate(raw.startsAt ?? null);
  const endDate = raw.endTime ? normalizeIsoDate(raw.endTime as string) : null;

  // Cost: priceMin/currency/ticketStatus
  let isFree: boolean | null = null;
  if (raw.ticketStatus === "free") isFree = true;
  else if (raw.ticketStatus === "on_sale" || raw.ticketStatus === "sold_out") isFree = false;

  const costAmount = typeof raw.priceMin === "number" ? raw.priceMin : null;
  const costCurrency = typeof raw.currency === "string" ? raw.currency : null;

  return {
    id,
    source: "eventScraper",
    externalId: idSource,
    title,
    description: typeof raw.description === "string" ? raw.description : null,
    organization: typeof raw.organizerName === "string" ? raw.organizerName : null,
    officialUrl: typeof raw.eventUrl === "string" ? raw.eventUrl : null,
    applicationUrl: typeof raw.eventUrl === "string" ? raw.eventUrl : null,
    sourceUrl: typeof raw.eventUrl === "string" ? raw.eventUrl : null,
    category,
    sourceCategory,
    subjects: [],
    topics,
    skills: [],
    deadline: null, // events have startDate, not application deadline
    startDate,
    endDate,
    location: mapEventLocation(raw),
    cost: {
      amount: costAmount,
      currency: costCurrency,
      isFree,
    },
    benefits: {
      awardText: null,
      awardAmount: null,
      awardCurrency: null,
      prizeText: null,
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
      source: "eventScraper",
      externalId: idSource,
      fetchedAt,
      sourceUpdatedAt: null,
    },
    sourceMetadata: {
      originalCategory: raw.category ?? null,
      platform: raw.platform ?? null,
      timezone: raw.timezone ?? null,
      venueName: raw.venueName ?? null,
      address: raw.address ?? null,
      rsvpCount: raw.rsvpCount ?? null,
      capacity: raw.capacity ?? null,
      organizerUrl: raw.organizerUrl ?? null,
      ticketStatus: raw.ticketStatus ?? null,
      coverImageUrl: raw.coverImageUrl ?? null,
    },
  };
}
