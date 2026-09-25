import type { Opportunity } from "../models/opportunity";
import type { StudentProfileForEligibility, EligibilityCheck } from "./types";
import { parseStudentLocation } from "./types";

function normalizeCountryList(countries: string[] | null): Set<string> | null {
  if (!countries || countries.length === 0) return null;
  const normalized = countries
    .map((c) => c.trim().toUpperCase())
    .filter(Boolean);
  return normalized.length ? new Set(normalized) : null;
}

// Conservative geographic handling for free-form restrictions
function parseGeographicRestriction(
  text: string | null | undefined
): { type: "country" | "state" | "international" | null; value: string | null } | null {
  if (!text) return null;
  const lower = text.trim().toLowerCase();
  if (!lower) return null;

  // Obvious international
  if (["international", "worldwide", "global", "anywhere"].includes(lower)) {
    return { type: "international", value: lower };
  }

  // Direct country names/codes
  const countryMap: Record<string, string> = {
    "united states": "US",
    usa: "US",
    "u.s.": "US",
    us: "US",
    canada: "CA",
    ca: "CA",
    "united kingdom": "GB",
    uk: "GB",
    gb: "GB",
    australia: "AU",
    india: "IN",
    in: "IN",
  };
  if (countryMap[lower]) return { type: "country", value: countryMap[lower] };

  // US states
  const stateMap: Record<string, string> = {
    texas: "TX",
    california: "CA",
    "new york": "NY",
    florida: "FL",
    washington: "WA",
    illinois: "IL",
    // add common
    tx: "TX",
    ca: "CA",
    ny: "NY",
  };
  if (stateMap[lower]) return { type: "state", value: stateMap[lower] };

  // Phrases like "Texas residents", "Texas only", "Texas students"
  // Try to extract known state/country from phrase
  for (const [name, code] of Object.entries(stateMap)) {
    if (lower.includes(name)) {
      // Require clear signal words
      if (lower.includes("residents") || lower.includes("students") || lower.includes("only") || lower.includes(name)) {
        return { type: "state", value: code };
      }
    }
  }
  for (const [name, code] of Object.entries(countryMap)) {
    if (lower.includes(name)) {
      if (lower.includes("residents") || lower.includes("only") || lower.includes(name)) {
        return { type: "country", value: code };
      }
    }
  }

  // Ambiguous
  return null;
}

export function evaluateCountry(
  opportunity: Opportunity,
  student: StudentProfileForEligibility
): EligibilityCheck {
  const countries = normalizeCountryList(opportunity.eligibility.countries);
  if (!countries) {
    return {
      dimension: "country",
      status: "unknown",
      reason: "No country restriction is specified by the source.",
    };
  }

  const studentLoc = parseStudentLocation(student);
  const studentCountry = studentLoc.country;

  if (!studentCountry) {
    return {
      dimension: "country",
      status: "unknown",
      reason: "Student country is not available; cannot evaluate country requirement.",
    };
  }

  if (countries.has(studentCountry)) {
    return {
      dimension: "country",
      status: "eligible",
      reason: `Opportunity is available in ${studentCountry} and student is in ${studentCountry}.`,
    };
  }

  return {
    dimension: "country",
    status: "ineligible",
    reason: `Opportunity is restricted to ${Array.from(countries).join(", ")} and student is in ${studentCountry}.`,
  };
}

export function evaluateGeography(
  opportunity: Opportunity,
  student: StudentProfileForEligibility
): EligibilityCheck {
  const restriction = opportunity.eligibility.geographicRestrictions;
  if (!restriction || restriction.trim() === "") {
    return {
      dimension: "geography",
      status: "unknown",
      reason: "No geographic restriction is specified by the source.",
    };
  }

  const parsed = parseGeographicRestriction(restriction);
  if (!parsed) {
    return {
      dimension: "geography",
      status: "unknown",
      reason: `Geographic requirement "${restriction}" is ambiguous and cannot be evaluated.`,
    };
  }

  if (parsed.type === "international") {
    return {
      dimension: "geography",
      status: "eligible",
      reason: `Opportunity is international/worldwide.`,
    };
  }

  const studentLoc = parseStudentLocation(student);

  if (parsed.type === "country") {
    if (!studentLoc.country) {
      return {
        dimension: "geography",
        status: "unknown",
        reason: "Student country is not available; cannot evaluate geographic requirement.",
      };
    }
    if (studentLoc.country === parsed.value) {
      return {
        dimension: "geography",
        status: "eligible",
        reason: `Opportunity accepts students from ${parsed.value} and student is in ${studentLoc.country}.`,
      };
    }
    return {
      dimension: "geography",
      status: "ineligible",
      reason: `Opportunity is restricted to ${parsed.value} and student is in ${studentLoc.country}.`,
    };
  }

  if (parsed.type === "state") {
    if (!studentLoc.state) {
      return {
        dimension: "geography",
        status: "unknown",
        reason: "Student state is not available; cannot evaluate state requirement.",
      };
    }
    if (studentLoc.state === parsed.value) {
      return {
        dimension: "geography",
        status: "eligible",
        reason: `Opportunity accepts students from ${parsed.value} and student is in ${studentLoc.state}.`,
      };
    }
    return {
      dimension: "geography",
      status: "ineligible",
      reason: `Opportunity is restricted to ${parsed.value} and student is in ${studentLoc.state}.`,
    };
  }

  return {
    dimension: "geography",
    status: "unknown",
    reason: `Geographic requirement "${restriction}" is ambiguous and cannot be evaluated.`,
  };
}

export function evaluateState(
  opportunity: Opportunity,
  student: StudentProfileForEligibility
): EligibilityCheck {
  // State is a subset of geography, but we expose separate dimension for clarity
  // If geographicRestrictions explicitly mentions a state, reuse geography logic
  const restriction = opportunity.eligibility.geographicRestrictions;
  if (!restriction) {
    return {
      dimension: "state",
      status: "unknown",
      reason: "No state restriction is specified by the source.",
    };
  }

  const parsed = parseGeographicRestriction(restriction);
  if (!parsed || parsed.type !== "state") {
    // No clear state requirement
    return {
      dimension: "state",
      status: "unknown",
      reason: restriction.trim().length
        ? `State requirement is not clearly specified ("${restriction}").`
        : "No state restriction is specified by the source.",
    };
  }

  // Delegate to geography state handling
  const result = evaluateGeography(opportunity, student);
  // Map dimension to state
  return { ...result, dimension: "state" };
}
