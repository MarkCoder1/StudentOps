import type { Opportunity } from "../models/opportunity";
import type { EligibilityResult, EligibilityStatus } from "../eligibility/types";
import type { MatchResult, MatchSignal } from "../matching/types";
import type { FreshnessResult, FreshnessStatus, DeadlineUrgency } from "../freshness/types";

// PersonalizedOpportunity — computed dynamically from StudentProfile + Opportunity
// Never persisted to the shared opportunity database.
export interface PersonalizedOpportunity {
  // The original opportunity data
  opportunity: Opportunity;

  // Eligibility
  eligibility: {
    status: EligibilityStatus;
    reasons: Array<{ dimension: string; message: string }>;
  };

  // Matching
  match: {
    score: number; // 0-100
    label: string; // "Excellent match" etc.
    reasons: string[]; // human-readable match reasons
    signals: MatchSignal[];
  };

  // Freshness
  freshness: {
    status: FreshnessStatus;
    urgency: DeadlineUrgency;
    daysUntilDeadline: number | null;
    deadline: string | null;
    reason: string;
  };

  // Computed ranking score (deterministic, explainable)
  rankScore: number;

  // Badges for the card UI
  badges: string[]; // e.g., ["Best Match", "Deadline Soon", "Free"]
}

export interface PersonalizedFeed {
  opportunities: PersonalizedOpportunity[];
  sections: FeedSection[];
  stats: {
    total: number;
    eligible: number;
    ineligible: number;
    unknown: number;
    avgMatchScore: number;
  };
}

export interface FeedSection {
  id: string; // "forYou", "deadlineSoon", "scholarships", "competitions", "hackathons", "events"
  title: string;
  subtitle: string;
  opportunities: PersonalizedOpportunity[];
}

// Student profile for personalization (matches iOS StudentProfile)
export interface StudentProfileForPersonalization {
  age?: number | string | null;
  dateOfBirth?: string | null;
  grade?: string | null;
  schoolLevel?: string | null;
  location?: string | null;
  city?: string | null;
  state?: string | null;
  country?: string | null;
  interests?: string[];
  customInterests?: string[];
  strengths?: string[];
  customSkills?: string[];
  careers?: string[];
  fields?: string[];
  milestones?: string[];
  skills?: string[];
}
