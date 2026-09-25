import type { Opportunity } from "../models/opportunity";
import type { EligibilityStatus, EligibilityResult } from "../eligibility/types";

export type MatchDimension = "interest" | "career" | "field" | "skill" | "subject" | "goal" | "category";

export interface MatchSignal {
  dimension: MatchDimension;
  score: number; // 0, 0.5, 1.0
  reason: string;
  // Optional: available indicates if dimension had data to evaluate
  available: boolean;
}

export interface MatchResult {
  opportunityId: string;
  score: number; // 0-100 integer
  eligibility: EligibilityStatus | null; // null if not provided
  reasons: string[];
  signals: MatchSignal[];
  label: string; // Excellent match etc.
}

// Lightweight StudentProfile for matching — mirrors Swift StudentProfile
// Keep optional to avoid punishing missing data
export interface StudentProfileForMatching {
  interests?: string[];
  customInterests?: string[];
  strengths?: string[];
  customSkills?: string[];
  careers?: string[];
  fields?: string[]; // intended study areas
  milestones?: string[]; // goals
  skills?: string[]; // alias if present
  // Additional for category/goal mapping
  schoolLevel?: string | null;
  grade?: string | null;
}

export function getMatchLabel(score: number): string {
  if (score >= 80) return "Excellent match";
  if (score >= 60) return "Strong match";
  if (score >= 40) return "Good match";
  if (score >= 20) return "Possible match";
  return "Low match";
}
