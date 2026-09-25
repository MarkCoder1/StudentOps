// Shared normalization for matching — case-insensitive, trim, punctuation, hyphen

export function normalizeToken(value: string): string {
  if (!value) return "";
  let s = value.toLowerCase().trim();
  s = s.replace(/[_-]/g, " ");
  s = s.replace(/[.,/#!$%^&*;:{}=\-"'`~()]/g, " ");
  s = s.replace(/\s+/g, " ").trim();
  return s;
}

export function normalizeTokens(values: string[]): Set<string> {
  const set = new Set<string>();
  for (const v of values) {
    const n = normalizeToken(v);
    if (n) set.add(n);
  }
  return set;
}

export function normalizeArray(values: string[] | null | undefined): string[] {
  if (!values) return [];
  return values.map((v) => normalizeToken(v)).filter(Boolean);
}

// Small transparent synonym maps — keep explicit, inspectable
// Career -> related opportunity terms
const CAREER_MAP: Record<string, string[]> = {
  "software engineer": ["software", "software engineering", "programming", "coding", "computer science", "developer", "software development"],
  "ai researcher": ["ai", "artificial intelligence", "machine learning", "data science"],
  "biomedical engineer": ["biomedical", "bioengineering", "medicine", "biology"],
  "product designer": ["design", "product design", "ux", "ui"],
};

const FIELD_MAP: Record<string, string[]> = {
  "computer science": ["computer science", "programming", "software", "coding", "artificial intelligence", "machine learning", "software engineering"],
  engineering: ["engineering", "mechanical", "electrical", "biomedical"],
  biology: ["biology", "life sciences", "biomedical"],
  medicine: ["medicine", "health", "biomedical"],
  business: ["business", "entrepreneurship", "finance", "economics"],
  psychology: ["psychology", "neuroscience"],
  arts: ["arts", "design", "creative"],
  law: ["law", "legal"],
};

// Reverse: opportunity topic -> field equivalence
export function expandCareerTerms(careers: string[]): Set<string> {
  const out = new Set<string>();
  for (const c of careers) {
    const norm = normalizeToken(c);
    if (!norm) continue;
    out.add(norm);
    const expanded = CAREER_MAP[norm];
    if (expanded) {
      for (const e of expanded) out.add(normalizeToken(e));
    }
  }
  return out;
}

export function expandFieldTerms(fields: string[]): Set<string> {
  const out = new Set<string>();
  for (const f of fields) {
    const norm = normalizeToken(f);
    if (!norm) continue;
    out.add(norm);
    const expanded = FIELD_MAP[norm];
    if (expanded) {
      for (const e of expanded) out.add(normalizeToken(e));
    }
  }
  return out;
}

// For category matching — normalize category strings
export function normalizeCategory(value: string | null | undefined): string {
  if (!value) return "";
  return normalizeToken(value);
}

// Opportunity side helpers
export function collectOpportunityTerms(opp: { subjects: string[]; topics: string[]; skills: string[]; category: string; sourceCategory: string | null; title: string }): {
  subjects: Set<string>;
  topics: Set<string>;
  skills: Set<string>;
  categories: Set<string>;
  titleTokens: Set<string>;
} {
  return {
    subjects: normalizeTokens(opp.subjects),
    topics: normalizeTokens(opp.topics),
    skills: normalizeTokens(opp.skills),
    categories: normalizeTokens([opp.category, opp.sourceCategory ?? ""].filter(Boolean)),
    titleTokens: normalizeTokens(opp.title.split(/\s+/)),
  };
}
