// Eligibility types — Phase 5.4
// Unknown ≠ Ineligible. Only hard contradictions are ineligible.

export type EligibilityStatus = "eligible" | "ineligible" | "unknown";

export type EligibilityDimension =
  | "age"
  | "country"
  | "geography"
  | "state"
  | "enrollment"
  | "major";

export interface EligibilityCheck {
  dimension: EligibilityDimension;
  status: EligibilityStatus;
  reason: string;
}

export interface EligibilityReason {
  dimension: EligibilityDimension;
  message: string;
}

export interface EligibilityResult {
  status: EligibilityStatus;
  reasons: EligibilityReason[];
  checks: EligibilityCheck[];
}

// Minimal StudentProfile for eligibility — mirrors Swift StudentProfile
// Only structured fields used for eligibility; other fields are optional and ignored.

export type SchoolLevel = "Middle School" | "High School" | string;
export type Grade = "9th" | "10th" | "11th" | "12th" | string;

export interface StudentProfileForEligibility {
  // Age/DOB — if not present, age check is unknown
  // Age may arrive as string from Swift UserDefaults (e.g., "15") — handled as number
  age?: number | string | null;
  dateOfBirth?: string | null; // ISO YYYY-MM-DD
  grade?: Grade | null;
  schoolLevel?: SchoolLevel | null;
  location?: string | null; // e.g., "Austin, TX" or "Texas, US"
  // Structured profile fields
  interests?: string[];
  customInterests?: string[];
  strengths?: string[];
  customSkills?: string[];
  careers?: string[];
  fields?: string[]; // intended study areas
  // Raw location helpers
  city?: string | null;
  state?: string | null;
  country?: string | null; // ISO alpha-2 or name, e.g., "US", "United States"
}

// Helper to normalize student location string into parts
export function parseStudentLocation(profile: StudentProfileForEligibility): {
  country: string | null;
  state: string | null;
  city: string | null;
} {
  // If explicit fields provided, use them
  if (profile.country || profile.state || profile.city) {
    return {
      country: normalizeCountry(profile.country),
      state: normalizeState(profile.state),
      city: profile.city ? profile.city.trim() : null,
    };
  }
  // Parse location string like "Austin, TX" or "Texas, US"
  const loc = profile.location?.trim() ?? "";
  if (!loc) return { country: null, state: null, city: null };

  // Simple heuristic: split by comma
  const parts = loc.split(",").map((p) => p.trim()).filter(Boolean);
  let city: string | null = null;
  let state: string | null = null;
  let country: string | null = null;

  if (parts.length === 1) {
    const p = parts[0];
    // Could be state, country, or city
    const asState = normalizeState(p);
    const asCountry = normalizeCountry(p);
    if (asState) state = asState;
    else if (asCountry) country = asCountry;
    else city = p;
  } else if (parts.length >= 2) {
    // Assume "City, State" or "State, Country" or "City, State, Country"
    // Try to detect last part as country if 2 letters or known country name
    const last = parts[parts.length - 1];
    const lastCountry = normalizeCountry(last);
    const lastState = normalizeState(last);
    if (lastCountry) {
      country = lastCountry;
      // Second last might be state
      const secondLast = parts[parts.length - 2];
      const s = normalizeState(secondLast);
      if (s) {
        state = s;
        if (parts.length >= 3) city = parts[0];
      } else {
        // Could be city
        if (parts.length === 2) city = parts[0];
      }
    } else if (lastState) {
      state = lastState;
      if (parts.length >= 2) city = parts[0] || null;
    } else {
      // No country/state detected, treat as city, state
      city = parts[0] || null;
      state = normalizeState(parts[1]) || null;
      if (!state) city = parts.join(", ");
    }
  }

  return { country, state, city };
}

function normalizeCountry(value: string | null | undefined): string | null {
  if (!value) return null;
  const v = value.trim();
  const lower = v.toLowerCase();
  const map: Record<string, string> = {
    "united states": "US",
    usa: "US",
    "u.s.": "US",
    "u.s.a.": "US",
    "united states of america": "US",
    america: "US",
    us: "US",
    canada: "CA",
    ca: "CA",
    mexico: "MX",
    mx: "MX",
    "united kingdom": "GB",
    uk: "GB",
    gb: "GB",
    england: "GB",
    australia: "AU",
    au: "AU",
    india: "IN",
    in: "IN",
    singapore: "SG",
    sg: "SG",
    germany: "DE",
    de: "DE",
    france: "FR",
    fr: "FR",
    china: "CN",
    cn: "CN",
    japan: "JP",
    jp: "JP",
    korea: "KR",
    "south korea": "KR",
    kr: "KR",
    brazil: "BR",
    br: "BR",
    "south africa": "ZA",
    za: "ZA",
  };
  if (map[lower]) return map[lower];
  // ISO alpha-2 already
  if (/^[a-z]{2}$/i.test(v)) return v.toUpperCase();
  return null;
}

function normalizeState(value: string | null | undefined): string | null {
  if (!value) return null;
  const v = value.trim();
  const lower = v.toLowerCase();
  const map: Record<string, string> = {
    alabama: "AL",
    alaska: "AK",
    arizona: "AZ",
    arkansas: "AR",
    california: "CA",
    colorado: "CO",
    connecticut: "CT",
    delaware: "DE",
    florida: "FL",
    georgia: "GA",
    hawaii: "HI",
    idaho: "ID",
    illinois: "IL",
    indiana: "IN",
    iowa: "IA",
    kansas: "KS",
    kentucky: "KY",
    louisiana: "LA",
    maine: "ME",
    maryland: "MD",
    massachusetts: "MA",
    michigan: "MI",
    minnesota: "MN",
    mississippi: "MS",
    missouri: "MO",
    montana: "MT",
    nebraska: "NE",
    nevada: "NV",
    "new hampshire": "NH",
    "new jersey": "NJ",
    "new mexico": "NM",
    "new york": "NY",
    "north carolina": "NC",
    "north dakota": "ND",
    ohio: "OH",
    oklahoma: "OK",
    oregon: "OR",
    pennsylvania: "PA",
    "rhode island": "RI",
    "south carolina": "SC",
    "south dakota": "SD",
    tennessee: "TN",
    texas: "TX",
    utah: "UT",
    vermont: "VT",
    virginia: "VA",
    washington: "WA",
    "west virginia": "WV",
    wisconsin: "WI",
    wyoming: "WY",
    "district of columbia": "DC",
    dc: "DC",
    tx: "TX",
    ca: "CA",
    ny: "NY",
  };
  if (map[lower]) return map[lower];
  if (/^[a-z]{2}$/i.test(v)) return v.toUpperCase();
  return null;
}

export function calculateAge(birthDate: string, asOf: Date = new Date()): number | null {
  const dob = new Date(birthDate);
  if (isNaN(dob.getTime())) return null;
  let age = asOf.getUTCFullYear() - dob.getUTCFullYear();
  const m = asOf.getUTCMonth() - dob.getUTCMonth();
  if (m < 0 || (m === 0 && asOf.getUTCDate() < dob.getUTCDate())) {
    age--;
  }
  return age;
}
