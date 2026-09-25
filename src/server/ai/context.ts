// AI Context Builder — Phase 6.1
// Builds structured, typed context from Student OPS data for AI tasks.
// Context is constructed from authoritative deterministic engines — AI never replaces them.

import type { Opportunity } from "../opportunities/models/opportunity";
import type { PersonalizedOpportunity } from "../opportunities/personalization/types";
import type { EligibilityResult } from "../opportunities/eligibility/types";
import type { MatchResult } from "../opportunities/matching/types";
import type { FreshnessResult } from "../opportunities/freshness/types";

// ─── Context Types ───────────────────────────────────────────────

/** Minimal student data needed for AI context. */
export interface AIStudentContext {
  grade?: string | null;
  schoolLevel?: string | null;
  interests: string[];
  skills: string[];
  careers: string[];
  fields: string[];
  goals: string[];
  location?: string | null;
}

/** Compact opportunity data for AI context (avoids sending full DB). */
export interface AIOpportunityContext {
  id: string;
  title: string;
  description: string | null;
  organization: string | null;
  category: string;
  deadline: string | null;
  officialUrl: string | null;
  applicationUrl: string | null;
  cost: { isFree: boolean | null; amount: number | null };
  location: { type: string; online: boolean | null };
  skills: string[];
  topics: string[];
}

/** Deterministic engine results for a single opportunity. */
export interface AIEngineResult {
  eligibility: {
    status: string;
    reasons: Array<{ dimension: string; message: string }>;
  };
  match: {
    score: number;
    label: string;
    reasons: string[];
  };
  freshness: {
    status: string;
    urgency: string;
    daysUntilDeadline: number | null;
  };
  rankScore: number;
}

/** Full AI context for a single opportunity + student. */
export interface AIStudentOpportunityContext {
  student: AIStudentContext;
  opportunity: AIOpportunityContext;
  engines: AIEngineResult;
}

/** AI context for batch tasks (e.g., roadmap suggestions). */
export interface AIBatchContext {
  student: AIStudentContext;
  topOpportunities: AIOpportunityContext[];
  engineResults: Record<string, AIEngineResult>;
}

// ─── Builder Functions ───────────────────────────────────────────

/** Build student context from a personalization profile. */
export function buildStudentContext(profile: {
  grade?: string | null;
  schoolLevel?: string | null;
  interests?: string[];
  customInterests?: string[];
  strengths?: string[];
  customSkills?: string[];
  careers?: string[];
  fields?: string[];
  milestones?: string[];
  skills?: string[];
  location?: string | null;
}): AIStudentContext {
  const allInterests = [
    ...(profile.interests ?? []),
    ...(profile.customInterests ?? []),
  ];
  const allSkills = [
    ...(profile.strengths ?? []),
    ...(profile.customSkills ?? []),
    ...(profile.skills ?? []),
  ];

  // Deduplicate
  const interests = [...new Set(allInterests)].filter(Boolean);
  const skills = [...new Set(allSkills)].filter(Boolean);

  return {
    grade: profile.grade ?? null,
    schoolLevel: profile.schoolLevel ?? null,
    interests,
    skills,
    careers: [...new Set(profile.careers ?? [])].filter(Boolean),
    fields: [...new Set(profile.fields ?? [])].filter(Boolean),
    goals: [...new Set(profile.milestones ?? [])].filter(Boolean),
    location: profile.location ?? null,
  };
}

/** Build compact opportunity context from a full Opportunity. */
export function buildOpportunityContext(opportunity: Opportunity): AIOpportunityContext {
  return {
    id: opportunity.id,
    title: opportunity.title,
    description: truncate(opportunity.description, 500),
    organization: opportunity.organization,
    category: opportunity.category,
    deadline: opportunity.deadline,
    officialUrl: opportunity.officialUrl,
    applicationUrl: opportunity.applicationUrl,
    cost: {
      isFree: opportunity.cost.isFree,
      amount: opportunity.cost.amount,
    },
    location: {
      type: opportunity.location.type,
      online: opportunity.location.online,
    },
    skills: opportunity.skills,
    topics: opportunity.topics,
  };
}

/** Build engine result from a personalized opportunity. */
export function buildEngineResult(
  p: PersonalizedOpportunity,
  eligibility?: EligibilityResult | null,
  match?: MatchResult | null,
  freshness?: FreshnessResult | null
): AIEngineResult {
  return {
    eligibility: {
      status: p.eligibility.status,
      reasons: p.eligibility.reasons,
    },
    match: {
      score: p.match.score,
      label: p.match.label,
      reasons: p.match.reasons,
    },
    freshness: {
      status: p.freshness.status,
      urgency: p.freshness.urgency,
      daysUntilDeadline: p.freshness.daysUntilDeadline,
    },
    rankScore: p.rankScore,
  };
}

/** Build full AI context for a single opportunity + student. */
export function buildStudentOpportunityContext(
  studentProfile: Parameters<typeof buildStudentContext>[0],
  opportunity: Opportunity,
  personalized: PersonalizedOpportunity
): AIStudentOpportunityContext {
  return {
    student: buildStudentContext(studentProfile),
    opportunity: buildOpportunityContext(opportunity),
    engines: buildEngineResult(personalized),
  };
}

/** Build batch context from top opportunities. */
export function buildBatchContext(
  studentProfile: Parameters<typeof buildStudentContext>[0],
  personalized: PersonalizedOpportunity[]
): AIBatchContext {
  const student = buildStudentContext(studentProfile);
  const topOpportunities = personalized.slice(0, 10).map((p) => buildOpportunityContext(p.opportunity));
  const engineResults: Record<string, AIEngineResult> = {};
  for (const p of personalized.slice(0, 10)) {
    engineResults[p.opportunity.id] = buildEngineResult(p);
  }

  return {
    student,
    topOpportunities,
    engineResults,
  };
}

// ─── Helpers ─────────────────────────────────────────────────────

function truncate(text: string | null, maxLen: number): string | null {
  if (!text) return null;
  if (text.length <= maxLen) return text;
  return text.slice(0, maxLen - 3) + "...";
}
