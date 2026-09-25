import type { Opportunity } from "../models/opportunity";
import type { DeduplicationResult, DuplicateGroup, Confidence } from "./types";
import { normalizeText, normalizeOrganization, normalizeUrl } from "./normalizeComparison";
import { titleSimilarity } from "./similarity";
import { chooseCanonical, mergeOpportunities } from "./merge";

function isEvent(opportunity: Opportunity): boolean {
  return opportunity.source === "eventScraper";
}

function getCycleYear(opp: Opportunity): string | null {
  const meta: any = opp.sourceMetadata;
  if (meta && meta.cycle_year != null) return String(meta.cycle_year);
  // Also try to extract year from title like "2026" or "2027"
  const titleYear = opp.title.match(/\b(20\d{2})\b/);
  return titleYear ? titleYear[1] : null;
}

function deadlinesEqual(a: string | null, b: string | null): boolean {
  if (!a || !b) return false;
  return a === b;
}

function urlMatch(a: string | null, b: string | null): boolean {
  const na = normalizeUrl(a);
  const nb = normalizeUrl(b);
  if (!na || !nb) return false;
  return na === nb;
}

function evaluatePair(a: Opportunity, b: Opportunity): { confidence: Confidence; reason: string; shouldMerge: boolean } {
  // Very strong: same source + externalId
  if (a.source === b.source && a.externalId === b.externalId) {
    return { confidence: "very-strong", reason: "same source + externalId", shouldMerge: true };
  }

  // Strong: same officialUrl or applicationUrl (normalized)
  if (urlMatch(a.officialUrl, b.officialUrl)) {
    return { confidence: "strong", reason: "same officialUrl", shouldMerge: true };
  }
  if (urlMatch(a.applicationUrl, b.applicationUrl)) {
    return { confidence: "strong", reason: "same applicationUrl", shouldMerge: true };
  }

  const normTitleA = normalizeText(a.title);
  const normTitleB = normalizeText(b.title);
  const titleExact = normTitleA !== "" && normTitleA === normTitleB;
  const titleSim = titleSimilarity(normTitleA, normTitleB);
  const titleSimilar = titleSim >= 0.9; // candidate, but not sufficient alone

  const normOrgA = normalizeOrganization(a.organization);
  const normOrgB = normalizeOrganization(b.organization);
  const orgExact = normOrgA !== "" && normOrgA === normOrgB;

  const deadlineA = a.deadline;
  const deadlineB = b.deadline;
  const deadlineMatch = deadlinesEqual(deadlineA, deadlineB);
  const deadlineMismatch = deadlineA !== null && deadlineB !== null && deadlineA !== deadlineB;
  const deadlineUnknown = deadlineA === null || deadlineB === null;

  // Cycle year check — if both have cycle_year and differ, do NOT merge even if title/org match
  const cycleA = getCycleYear(a);
  const cycleB = getCycleYear(b);
  const cycleMismatch = cycleA !== null && cycleB !== null && cycleA !== cycleB;

  if (cycleMismatch) {
    // Different years → keep separate unless very-strong URL already matched (already returned)
    return { confidence: "none", reason: `different cycle year ${cycleA} vs ${cycleB}`, shouldMerge: false };
  }

  // Event special handling: require startDate + city/venue
  if (isEvent(a) || isEvent(b)) {
    if (titleExact && orgExact) {
      // For events, also require startDate match and location
      const startMatch = a.startDate !== null && b.startDate !== null && a.startDate === b.startDate;
      const cityA = normalizeText(a.location.city);
      const cityB = normalizeText(b.location.city);
      const cityMatch = cityA !== "" && cityA === cityB;
      if (startMatch && (cityMatch || (a.location.city === null && b.location.city === null))) {
        return { confidence: "strong", reason: "event: same title + organization + startDate" + (cityMatch ? " + city" : ""), shouldMerge: true };
      }
      // Same title+org but different date → keep separate
      if (a.startDate && b.startDate && a.startDate !== b.startDate) {
        return { confidence: "none", reason: "event same title/org but different startDate", shouldMerge: false };
      }
      // Fall through to non-merge for events without strong date
      return { confidence: "weak", reason: "event title+org but missing startDate/city for strong match", shouldMerge: false };
    }
    return { confidence: "weak", reason: "event weak title similarity", shouldMerge: false };
  }

  // Non-event strong: title exact + org exact + deadline match
  if (titleExact && orgExact && deadlineMatch) {
    return { confidence: "strong", reason: "same title + organization + deadline", shouldMerge: true };
  }

  // Strong: title exact + org exact + deadline unknown (conservative? treat as medium, not strong)
  // Per spec, medium should NOT auto-merge, so we keep medium as not merge
  if (titleExact && orgExact) {
    // If deadlines both present and mismatch, keep separate
    if (deadlineMismatch) {
      return { confidence: "none", reason: "same title+org but different deadlines", shouldMerge: false };
    }
    // Same title+org, at least one deadline unknown → medium confidence, do NOT merge (conservative)
    // But if we also have strong URL, already merged above
    return { confidence: "medium", reason: "same title + organization (deadline unknown/missing)", shouldMerge: false };
  }

  if (titleExact && deadlineMatch) {
    // Title + deadline match but org differs or missing
    // This is medium — require org for strong, so not auto-merge
    // Check if org one is null -> could still be same org with missing data, but conservative says no
    return { confidence: "medium", reason: "same title + deadline (org differs/missing)", shouldMerge: false };
  }

  // Weak: similar title only
  if (titleSimilar) {
    return { confidence: "weak", reason: `similar title only (similarity ${titleSim.toFixed(2)})`, shouldMerge: false };
  }

  return { confidence: "none", reason: "no strong signal", shouldMerge: false };
}

// Union-Find for deterministic grouping
class DSU {
  parent: Map<string, string> = new Map();
  find(x: string): string {
    if (!this.parent.has(x)) this.parent.set(x, x);
    let p = this.parent.get(x)!;
    if (p !== x) {
      p = this.find(p);
      this.parent.set(x, p);
    }
    return p;
  }
  union(a: string, b: string) {
    const ra = this.find(a);
    const rb = this.find(b);
    if (ra === rb) return;
    // Deterministic: smaller id wins as root
    if (ra < rb) this.parent.set(rb, ra);
    else this.parent.set(ra, rb);
  }
}

export function deduplicateOpportunities(opportunities: Opportunity[]): DeduplicationResult {
  const inputCount = opportunities.length;
  if (inputCount === 0) {
    return {
      opportunities: [],
      duplicateGroups: [],
      statistics: { inputCount: 0, outputCount: 0, duplicateCount: 0, duplicateGroupCount: 0, bySource: {} },
    };
  }

  // Deterministic ordering: sort by id
  const sorted = [...opportunities].sort((a, b) => a.id.localeCompare(b.id));

  const dsu = new DSU();
  for (const opp of sorted) dsu.find(opp.id);

  const pairReasons = new Map<string, { confidence: Confidence; reason: string }>();

  // Pairwise evaluation O(n^2) — acceptable for MVP (catalog < few hundred)
  for (let i = 0; i < sorted.length; i++) {
    for (let j = i + 1; j < sorted.length; j++) {
      const a = sorted[i];
      const b = sorted[j];
      const { confidence, reason, shouldMerge } = evaluatePair(a, b);
      if (shouldMerge) {
        dsu.union(a.id, b.id);
        const key = [a.id, b.id].sort().join("|");
        pairReasons.set(key, { confidence, reason });
      }
    }
  }

  // Group by root
  const groups = new Map<string, Opportunity[]>();
  for (const opp of sorted) {
    const root = dsu.find(opp.id);
    if (!groups.has(root)) groups.set(root, []);
    groups.get(root)!.push(opp);
  }

  const duplicateGroups: DuplicateGroup[] = [];
  const resultOpportunities: Opportunity[] = [];

  for (const [root, members] of groups) {
    if (members.length === 1) {
      resultOpportunities.push(members[0]);
    } else {
      // Multiple members → choose canonical and merge
      const canonical = chooseCanonical(members);
      const others = members.filter((m) => m.id !== canonical.id);
      const merged = mergeOpportunities(canonical, others);
      // Determine confidence/reason for group (take strongest pair)
      let bestConfidence: Confidence = "weak";
      let bestReason = "merged";
      let bestRank = 0;
      const rank = (c: Confidence) => ({ "very-strong": 4, strong: 3, medium: 2, weak: 1, none: 0 }[c] ?? 0);
      for (let i = 0; i < members.length; i++) {
        for (let j = i + 1; j < members.length; j++) {
          const key = [members[i].id, members[j].id].sort().join("|");
          const info = pairReasons.get(key);
          if (info && rank(info.confidence) > bestRank) {
            bestRank = rank(info.confidence);
            bestConfidence = info.confidence;
            bestReason = info.reason;
          }
        }
      }
      // Fallback if no pair reason stored (should not happen)
      if (bestRank === 0) {
        bestConfidence = "strong";
        bestReason = "grouped via transitive closure";
      }
      resultOpportunities.push(merged);
      duplicateGroups.push({
        canonicalId: canonical.id,
        mergedIds: members.map((m) => m.id).sort(),
        confidence: bestConfidence,
        reason: bestReason,
        members,
      });
    }
  }

  // Deterministic output ordering
  resultOpportunities.sort((a, b) => a.id.localeCompare(b.id));
  duplicateGroups.sort((a, b) => a.canonicalId.localeCompare(b.canonicalId));

  const bySource: Record<string, number> = {};
  for (const opp of resultOpportunities) {
    bySource[opp.source] = (bySource[opp.source] ?? 0) + 1;
  }

  return {
    opportunities: resultOpportunities,
    duplicateGroups,
    statistics: {
      inputCount,
      outputCount: resultOpportunities.length,
      duplicateCount: inputCount - resultOpportunities.length,
      duplicateGroupCount: duplicateGroups.length,
      bySource,
    },
  };
}
