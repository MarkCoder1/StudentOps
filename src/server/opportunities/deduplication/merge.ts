import type { Opportunity } from "../models/opportunity";

// Source priority as final tie-breaker (most authoritative structured data)
const SOURCE_PRIORITY: Record<string, number> = {
  studentSuite: 5,
  devpost: 4,
  scholarshipFinder: 3,
  scholarshipExtractor: 2,
  eventScraper: 1,
};

function scoreCompleteness(opp: Opportunity): number {
  let score = 0;
  if (opp.title) score += 2;
  if (opp.description) score += 2;
  if (opp.organization) score += 2;
  if (opp.officialUrl) score += 3;
  if (opp.applicationUrl) score += 3;
  if (opp.deadline) score += 3;
  if (opp.startDate) score += 2;
  if (opp.location.city || opp.location.country) score += 2;
  if (opp.location.latitude !== null) score += 1;
  if (opp.cost.amount !== null) score += 1;
  if (opp.benefits.awardText || opp.benefits.prizeText) score += 2;
  if (opp.eligibility.minAge !== null) score += 1;
  if (opp.eligibility.countries && opp.eligibility.countries.length) score += 1;
  if (opp.subjects.length) score += 1;
  if (opp.topics.length) score += 1;
  if (opp.skills.length) score += 1;
  return score;
}

export function chooseCanonical(members: Opportunity[]): Opportunity {
  // Deterministic: sort by completeness desc, then source priority desc, then id asc
  const sorted = [...members].sort((a, b) => {
    const sa = scoreCompleteness(a);
    const sb = scoreCompleteness(b);
    if (sb !== sa) return sb - sa;
    const pa = SOURCE_PRIORITY[a.source] ?? 0;
    const pb = SOURCE_PRIORITY[b.source] ?? 0;
    if (pb !== pa) return pb - pa;
    return a.id.localeCompare(b.id);
  });
  return sorted[0];
}

function mergeArrays(a: string[], b: string[]): string[] {
  const normalizedSeen = new Set<string>();
  const result: string[] = [];
  const add = (arr: string[]) => {
    for (const v of arr) {
      const norm = v.trim().toLowerCase();
      if (!norm) continue;
      if (!normalizedSeen.has(norm)) {
        normalizedSeen.add(norm);
        result.push(v.trim());
      }
    }
  };
  add(a);
  add(b);
  return result;
}

export function mergeOpportunities(canonical: Opportunity, others: Opportunity[]): Opportunity {
  // Start from canonical clone
  const merged: Opportunity = JSON.parse(JSON.stringify(canonical));

  // Preserve provenance: add sourceRecords
  const sourceRecords = [
    { source: canonical.source, externalId: canonical.externalId },
    ...others.map((o) => ({ source: o.source, externalId: o.externalId })),
  ];
  // Deduplicate sourceRecords by source:externalId
  const seen = new Set<string>();
  const deduped: typeof sourceRecords = [];
  for (const r of sourceRecords) {
    const k = `${r.source}:${r.externalId}`;
    if (!seen.has(k)) {
      seen.add(k);
      deduped.push(r);
    }
  }
  (merged as any).sourceRecords = deduped;

  for (const other of others) {
    // Never replace known value with null
    if (!merged.description && other.description) merged.description = other.description;
    if (!merged.organization && other.organization) merged.organization = other.organization;
    if (!merged.officialUrl && other.officialUrl) merged.officialUrl = other.officialUrl;
    if (!merged.applicationUrl && other.applicationUrl) merged.applicationUrl = other.applicationUrl;
    if (!merged.sourceUrl && other.sourceUrl) merged.sourceUrl = other.sourceUrl;
    if (!merged.deadline && other.deadline) merged.deadline = other.deadline;
    if (!merged.startDate && other.startDate) merged.startDate = other.startDate;
    if (!merged.endDate && other.endDate) merged.endDate = other.endDate;

    // Location: prefer more complete (more non-null fields)
    const canonicalLocFields = [merged.location.city, merged.location.country, merged.location.latitude].filter(Boolean).length;
    const otherLocFields = [other.location.city, other.location.country, other.location.latitude].filter(Boolean).length;
    if (otherLocFields > canonicalLocFields) {
      // Merge missing fields only, don't overwrite existing city/country if canonical already has
      if (!merged.location.city && other.location.city) merged.location.city = other.location.city;
      if (!merged.location.country && other.location.country) merged.location.country = other.location.country;
      if (merged.location.latitude === null && other.location.latitude !== null) merged.location.latitude = other.location.latitude;
      if (merged.location.longitude === null && other.location.longitude !== null) merged.location.longitude = other.location.longitude;
      // type/online: keep canonical's type unless canonical is unknown
      if (merged.location.type === "unknown" && other.location.type !== "unknown") {
        merged.location.type = other.location.type;
        merged.location.online = other.location.online;
      }
    } else {
      if (!merged.location.city && other.location.city) merged.location.city = other.location.city;
      if (!merged.location.country && other.location.country) merged.location.country = other.location.country;
      if (merged.location.latitude === null && other.location.latitude !== null) merged.location.latitude = other.location.latitude;
      if (merged.location.longitude === null && other.location.longitude !== null) merged.location.longitude = other.location.longitude;
    }

    if (merged.cost.amount === null && other.cost.amount !== null) merged.cost.amount = other.cost.amount;
    if (merged.cost.currency === null && other.cost.currency) merged.cost.currency = other.cost.currency;
    if (merged.cost.isFree === null && other.cost.isFree !== null) merged.cost.isFree = other.cost.isFree;

    if (!merged.benefits.awardText && other.benefits.awardText) merged.benefits.awardText = other.benefits.awardText;
    if (merged.benefits.awardAmount === null && other.benefits.awardAmount !== null) merged.benefits.awardAmount = other.benefits.awardAmount;
    if (!merged.benefits.awardCurrency && other.benefits.awardCurrency) merged.benefits.awardCurrency = other.benefits.awardCurrency;
    if (!merged.benefits.prizeText && other.benefits.prizeText) merged.benefits.prizeText = other.benefits.prizeText;

    // Eligibility: merge missing, keep canonical on conflict
    if (merged.eligibility.minAge === null && other.eligibility.minAge !== null) merged.eligibility.minAge = other.eligibility.minAge;
    if (merged.eligibility.maxAge === null && other.eligibility.maxAge !== null) merged.eligibility.maxAge = other.eligibility.maxAge;
    if (!merged.eligibility.countries && other.eligibility.countries) merged.eligibility.countries = other.eligibility.countries;
    if (!merged.eligibility.geographicRestrictions && other.eligibility.geographicRestrictions) merged.eligibility.geographicRestrictions = other.eligibility.geographicRestrictions;
    if (!merged.eligibility.enrollmentLevels && other.eligibility.enrollmentLevels) merged.eligibility.enrollmentLevels = other.eligibility.enrollmentLevels;
    if (!merged.eligibility.majors && other.eligibility.majors) merged.eligibility.majors = other.eligibility.majors;

    // Arrays: merge deduped
    merged.subjects = mergeArrays(merged.subjects, other.subjects);
    merged.topics = mergeArrays(merged.topics, other.topics);
    merged.skills = mergeArrays(merged.skills, other.skills);

    // Source metadata: preserve non-conflicting, keep canonical on conflict, but add missing keys
    for (const [k, v] of Object.entries(other.sourceMetadata)) {
      if ((merged.sourceMetadata as any)[k] == null && v != null) {
        (merged.sourceMetadata as any)[k] = v;
      }
    }
    // Deadline conflict: keep canonical, but could record conflict in metadata (lightweight)
    if (merged.deadline && other.deadline && merged.deadline !== other.deadline) {
      // Preserve conflict for later review without overwriting
      (merged.sourceMetadata as any).__deadlineConflict = [
        (merged.sourceMetadata as any).__deadlineConflict,
        other.deadline,
      ]
        .flat()
        .filter(Boolean);
    }
  }

  return merged;
}
