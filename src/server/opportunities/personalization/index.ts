import type { Opportunity } from "../models/opportunity";
import type { StudentProfileForEligibility } from "../eligibility/types";
import type { StudentProfileForMatching } from "../matching/types";
import { evaluateEligibility } from "../eligibility/evaluate";
import { matchOpportunity } from "../matching/evaluate";
import { evaluateFreshness } from "../freshness/evaluate";
import type { PersonalizedOpportunity, PersonalizedFeed, FeedSection, StudentProfileForPersonalization } from "./types";
import { calculateRankScore, compareRankScores, generateBadges } from "./rank";
// DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
import { demoEligibilityScoreForId, DEMO_SCORES_ENABLED } from "../demoScores";
import { getMatchLabel } from "../matching/types";

// Convert personalization profile to eligibility profile
function toEligibilityProfile(profile: StudentProfileForPersonalization): StudentProfileForEligibility {
  return {
    age: profile.age,
    dateOfBirth: profile.dateOfBirth,
    grade: profile.grade,
    schoolLevel: profile.schoolLevel,
    location: profile.location,
    interests: profile.interests,
    customInterests: profile.customInterests,
    strengths: profile.strengths,
    customSkills: profile.customSkills,
    careers: profile.careers,
    fields: profile.fields,
    city: profile.city,
    state: profile.state,
    country: profile.country,
  };
}

// Convert personalization profile to matching profile
function toMatchingProfile(profile: StudentProfileForPersonalization): StudentProfileForMatching {
  return {
    interests: profile.interests,
    customInterests: profile.customInterests,
    strengths: profile.strengths,
    customSkills: profile.customSkills,
    careers: profile.careers,
    fields: profile.fields,
    milestones: profile.milestones,
    skills: profile.skills,
    schoolLevel: profile.schoolLevel,
    grade: profile.grade,
  };
}

// Process a single opportunity through all engines
function processOpportunity(
  opportunity: Opportunity,
  profile: StudentProfileForPersonalization,
  asOf: Date
): PersonalizedOpportunity {
  const eligProfile = toEligibilityProfile(profile);
  const matchProfile = toMatchingProfile(profile);

  // 1. Evaluate eligibility
  let eligibility = evaluateEligibility(opportunity, eligProfile, asOf);

  // 2. Calculate match score (pass eligibility for context)
  let match = matchOpportunity(opportunity, matchProfile, eligibility);

  // 3. Evaluate freshness
  const freshness = evaluateFreshness(opportunity, asOf);

  // 4. Calculate rank score (will be overridden for demo if enabled)
  let rankScore = calculateRankScore(
    match.score,
    freshness.deadlineUrgency,
    eligibility.status,
    freshness.daysUntilDeadline
  );

  // DEMO OVERRIDE — TEMPORARY — REVERT AFTER DEMO
  // Ensures consistent high eligibility/match scores (80-99%) across all displays.
  // Keeps real opportunity names/data; only overrides displayed scores.
  // Generates deterministic randomized scores per opportunity ID.
  let badges: string[];
  if (DEMO_SCORES_ENABLED) {
    const demoScore = demoEligibilityScoreForId(opportunity.id);
    // Force eligible status with demo score in reasons
    eligibility = {
      status: "eligible",
      reasons: [{ dimension: "geography", message: `Eligibility score: ${demoScore}% — You appear highly eligible` }],
      checks: eligibility.checks.map((c) => ({ ...c, status: "eligible" as const })),
    };
    // Force match score/label to demo
    match = {
      ...match,
      score: demoScore,
      label: getMatchLabel(demoScore),
    };
    // Force rankScore to demo (ensures consistent 80%+ ranking)
    rankScore = demoScore;
    badges = generateBadges(
      demoScore,
      "eligible",
      freshness.deadlineUrgency,
      opportunity.cost.isFree,
      opportunity.category
    );
  } else {
    // 5. Generate badges (non-demo path)
    badges = generateBadges(
      match.score,
      eligibility.status,
      freshness.deadlineUrgency,
      opportunity.cost.isFree,
      opportunity.category
    );
  }

  return {
    opportunity,
    eligibility: {
      status: eligibility.status,
      reasons: eligibility.reasons.map((r) => ({ dimension: r.dimension, message: r.message })),
    },
    match: {
      score: match.score,
      label: match.label,
      reasons: match.reasons,
      signals: match.signals,
    },
    freshness: {
      status: freshness.status,
      urgency: freshness.deadlineUrgency,
      daysUntilDeadline: freshness.daysUntilDeadline,
      deadline: freshness.deadline,
      reason: freshness.reason,
    },
    rankScore,
    badges,
  };
}

// Build feed sections from personalized opportunities
function buildSections(items: PersonalizedOpportunity[]): FeedSection[] {
  const sections: FeedSection[] = [];

  // For You: eligible + high match (score >= 20), sorted by rankScore
  const forYou = items
    .filter((p) => p.eligibility.status !== "ineligible" && p.match.score >= 20)
    .sort((a, b) => compareRankScores(a, b));
  if (forYou.length > 0) {
    sections.push({
      id: "forYou",
      title: "FOR YOU",
      subtitle: "Matched to your goals",
      opportunities: forYou,
    });
  }

  // Deadline Soon: eligible + urgent/soon deadline
  const deadlineSoon = items
    .filter((p) =>
      p.eligibility.status !== "ineligible" &&
      (p.freshness.urgency === "urgent" || p.freshness.urgency === "soon")
    )
    .sort((a, b) => compareRankScores(a, b));
  if (deadlineSoon.length > 0) {
    sections.push({
      id: "deadlineSoon",
      title: "DEADLINE SOON",
      subtitle: "Apply before it's too late",
      opportunities: deadlineSoon,
    });
  }

  // Scholarships
  const scholarships = items
    .filter((p) => p.opportunity.category.toLowerCase() === "scholarship" && p.eligibility.status !== "ineligible")
    .sort((a, b) => compareRankScores(a, b));
  if (scholarships.length > 0) {
    sections.push({
      id: "scholarships",
      title: "SCHOLARSHIPS",
      subtitle: "Funding for your education",
      opportunities: scholarships,
    });
  }

  // Competitions
  const competitions = items
    .filter((p) => p.opportunity.category.toLowerCase() === "competition" && p.eligibility.status !== "ineligible")
    .sort((a, b) => compareRankScores(a, b));
  if (competitions.length > 0) {
    sections.push({
      id: "competitions",
      title: "COMPETITIONS",
      subtitle: "Showcase your skills",
      opportunities: competitions,
    });
  }

  // Hackathons
  const hackathons = items
    .filter((p) => p.opportunity.category.toLowerCase() === "hackathon" && p.eligibility.status !== "ineligible")
    .sort((a, b) => compareRankScores(a, b));
  if (hackathons.length > 0) {
    sections.push({
      id: "hackathons",
      title: "HACKATHONS",
      subtitle: "Build and ship something new",
      opportunities: hackathons,
    });
  }

  // Events (workshops, conferences, other)
  const events = items
    .filter((p) =>
      ["workshop", "conference", "other"].includes(p.opportunity.category.toLowerCase()) &&
      p.eligibility.status !== "ineligible"
    )
    .sort((a, b) => compareRankScores(a, b));
  if (events.length > 0) {
    sections.push({
      id: "events",
      title: "PROGRAMS & EVENTS",
      subtitle: "Learn and connect",
      opportunities: events,
    });
  }

  return sections;
}

// Main personalization function
export function personalizeOpportunities(
  opportunities: Opportunity[],
  profile: StudentProfileForPersonalization,
  asOf: Date = new Date()
): PersonalizedFeed {
  // Process all opportunities through engines
  const items = opportunities.map((opp) => processOpportunity(opp, profile, asOf));

  // Sort by rankScore (descending)
  items.sort((a, b) => compareRankScores(a, b));

  // Build sections
  const sections = buildSections(items);

  // Calculate stats
  const eligible = items.filter((p) => p.eligibility.status === "eligible").length;
  const ineligible = items.filter((p) => p.eligibility.status === "ineligible").length;
  const unknown = items.filter((p) => p.eligibility.status === "unknown").length;
  const avgMatchScore = items.length > 0
    ? Math.round(items.reduce((sum, p) => sum + p.match.score, 0) / items.length)
    : 0;

  return {
    opportunities: items,
    sections,
    stats: {
      total: items.length,
      eligible,
      ineligible,
      unknown,
      avgMatchScore,
    },
  };
}
