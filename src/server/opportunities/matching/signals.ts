import type { Opportunity } from "../models/opportunity";
import type { StudentProfileForMatching, MatchSignal } from "./types";
import {
  normalizeToken,
  normalizeTokens,
  expandCareerTerms,
  expandFieldTerms,
  collectOpportunityTerms,
} from "./normalize";

function hasExactMatch(a: Set<string>, b: Set<string>): boolean {
  for (const v of a) if (b.has(v)) return true;
  return false;
}

function hasRelatedMatch(a: Set<string>, b: Set<string>): boolean {
  // For now related = same as exact after expansion; caller expands
  return hasExactMatch(a, b);
}

// Interest: student interests/customInterests vs opp subjects/topics/skills/category/titleTokens
export function signalInterest(
  student: StudentProfileForMatching,
  opp: Opportunity
): MatchSignal {
  const interests = [...(student.interests ?? []), ...(student.customInterests ?? [])];
  if (interests.length === 0) {
    return { dimension: "interest", score: 0, reason: "No interests provided", available: false };
  }
  const studentSet = normalizeTokens(interests);
  const oppTerms = collectOpportunityTerms(opp);
  const oppCombined = new Set([...oppTerms.subjects, ...oppTerms.topics, ...oppTerms.skills]);

  // Exact structured match: any interest equals any subject/topic/skill
  if (hasExactMatch(studentSet, oppCombined)) {
    // Find example
    const example = [...studentSet].find((s) => oppCombined.has(s)) ?? [...studentSet][0];
    const rawExample = interests.find((i) => normalizeToken(i) === example) ?? example;
    return {
      dimension: "interest",
      score: 1,
      reason: `Matches your interest in ${rawExample}.`,
      available: true,
    };
  }

  // Related via category: interest "AI" vs opp category "hackathon" not strong — skip
  // Weak textual: if any interest token appears in title
  const titleTokens = oppTerms.titleTokens;
  if (hasExactMatch(studentSet, titleTokens)) {
    const example = [...studentSet].find((s) => titleTokens.has(s)) ?? "";
    const raw = interests.find((i) => normalizeToken(i) === example) ?? example;
    return {
      dimension: "interest",
      score: 0.5,
      reason: `Related to your interest in ${raw}.`,
      available: true,
    };
  }

  return { dimension: "interest", score: 0, reason: "No interest match", available: true };
}

export function signalCareer(
  student: StudentProfileForMatching,
  opp: Opportunity
): MatchSignal {
  const careers = student.careers ?? [];
  if (careers.length === 0) {
    return { dimension: "career", score: 0, reason: "No career interests provided", available: false };
  }
  const expandedStudent = expandCareerTerms(careers);
  const oppTerms = collectOpportunityTerms(opp);
  const oppCombined = new Set([...oppTerms.subjects, ...oppTerms.topics, ...oppTerms.skills, ...oppTerms.categories]);

  if (hasExactMatch(expandedStudent, oppCombined)) {
    const raw = careers[0];
    return {
      dimension: "career",
      score: 1,
      reason: `Matches your ${raw} career goal.`,
      available: true,
    };
  }
  // Related: expanded career terms vs title tokens
  if (hasExactMatch(expandedStudent, oppTerms.titleTokens)) {
    return {
      dimension: "career",
      score: 0.5,
      reason: `Related to your career interest in ${careers[0]}.`,
      available: true,
    };
  }
  return { dimension: "career", score: 0, reason: "No career match", available: true };
}

export function signalField(
  student: StudentProfileForMatching,
  opp: Opportunity
): MatchSignal {
  const fields = student.fields ?? [];
  if (fields.length === 0) {
    return { dimension: "field", score: 0, reason: "No fields provided", available: false };
  }
  const expanded = expandFieldTerms(fields);
  const oppTerms = collectOpportunityTerms(opp);
  const oppCombined = new Set([...oppTerms.subjects, ...oppTerms.topics, ...oppTerms.skills]);

  if (hasExactMatch(expanded, oppCombined)) {
    const raw = fields[0];
    return { dimension: "field", score: 1, reason: `Matches your ${raw} field.`, available: true };
  }
  if (hasExactMatch(expanded, oppTerms.titleTokens) || hasExactMatch(expanded, oppTerms.categories)) {
    return { dimension: "field", score: 0.5, reason: `Related to your field ${fields[0]}.`, available: true };
  }
  return { dimension: "field", score: 0, reason: "No field match", available: true };
}

export function signalSkill(
  student: StudentProfileForMatching,
  opp: Opportunity
): MatchSignal {
  const skills = [...(student.customSkills ?? []), ...(student.strengths ?? []), ...(student.skills ?? [])];
  if (skills.length === 0) {
    return { dimension: "skill", score: 0, reason: "No skills provided", available: false };
  }
  const studentSet = normalizeTokens(skills);
  const oppSkills = normalizeTokens(opp.skills);
  const oppCombined = new Set([...oppSkills, ...normalizeTokens(opp.topics), ...normalizeTokens(opp.subjects)]);

  if (hasExactMatch(studentSet, oppSkills) || hasExactMatch(studentSet, oppCombined)) {
    // Find matching skill example
    const match = [...studentSet].find((s) => oppSkills.has(s) || oppCombined.has(s)) ?? [...studentSet][0];
    const raw = skills.find((k) => normalizeToken(k) === match) ?? match;
    return { dimension: "skill", score: 1, reason: `Uses ${raw}, which is one of your listed skills.`, available: true };
  }
  return { dimension: "skill", score: 0, reason: "No skill match", available: true };
}

export function signalSubject(
  student: StudentProfileForMatching,
  opp: Opportunity
): MatchSignal {
  // Subjects/topics from student fields/interests vs opp subjects/topics
  const studentSubjects = [...(student.fields ?? []), ...(student.interests ?? []), ...(student.customInterests ?? [])];
  if (studentSubjects.length === 0) {
    return { dimension: "subject", score: 0, reason: "No subject data", available: false };
  }
  const studentSet = normalizeTokens(studentSubjects);
  const oppSet = new Set([...normalizeTokens(opp.subjects), ...normalizeTokens(opp.topics)]);

  if (hasExactMatch(studentSet, oppSet)) {
    const raw = studentSubjects.find((s) => oppSet.has(normalizeToken(s))) ?? studentSubjects[0];
    return { dimension: "subject", score: 1, reason: `Matches your interest in ${raw}.`, available: true };
  }
  if (hasExactMatch(studentSet, normalizeTokens(opp.category.split(/[\s_]+/)))) {
    return { dimension: "subject", score: 0.5, reason: `Related to ${studentSubjects[0]}.`, available: true };
  }
  return { dimension: "subject", score: 0, reason: "No subject match", available: true };
}

export function signalGoal(
  student: StudentProfileForMatching,
  opp: Opportunity
): MatchSignal {
  const goals = student.milestones ?? [];
  if (goals.length === 0) {
    return { dimension: "goal", score: 0, reason: "No goals provided", available: false };
  }
  const goalTokens = normalizeTokens(goals);
  const oppTerms = collectOpportunityTerms(opp);
  const oppCombined = new Set([...oppTerms.subjects, ...oppTerms.topics, ...oppTerms.categories]);

  // Goal like "build research profile" vs opportunity category "research"
  for (const g of goals) {
    const norm = normalizeToken(g);
    // Simple keyword check: if goal contains research and opp has research
    if (norm.includes("research") && (opp.category === "research" || oppCombined.has("research"))) {
      return { dimension: "goal", score: 1, reason: `Matches your goal: ${g}.`, available: true };
    }
    if (norm.includes("software") && (oppCombined.has("software") || oppCombined.has("coding"))) {
      return { dimension: "goal", score: 1, reason: `Matches your goal: ${g}.`, available: true };
    }
  }
  // Fallback exact token match
  if (hasExactMatch(goalTokens, oppCombined)) {
    return { dimension: "goal", score: 0.5, reason: `Related to your goal ${goals[0]}.`, available: true };
  }
  return { dimension: "goal", score: 0, reason: "No goal match", available: true };
}

export function signalCategory(
  student: StudentProfileForMatching,
  opp: Opportunity
): MatchSignal {
  const studentCats = new Set([
    ...normalizeTokens(student.interests ?? []),
    ...normalizeTokens(student.fields ?? []),
    ...normalizeTokens(student.careers ?? []),
  ]);
  if (studentCats.size === 0) {
    return { dimension: "category", score: 0, reason: "No category data", available: false };
  }
  const oppCat = normalizeToken(opp.category);
  const oppSourceCat = normalizeToken(opp.sourceCategory ?? "");
  if (oppCat && studentCats.has(oppCat)) {
    return { dimension: "category", score: 1, reason: `Matches category ${opp.category}.`, available: true };
  }
  if (oppSourceCat && studentCats.has(oppSourceCat)) {
    return { dimension: "category", score: 0.5, reason: `Related category ${opp.sourceCategory}.`, available: true };
  }
  // Also check explicit mapping: business vs entrepreneurship
  if (studentCats.has("business") && oppCat === "entrepreneurship") {
    return { dimension: "category", score: 0.5, reason: `Business interest relates to Entrepreneurship.`, available: true };
  }
  if (studentCats.has("entrepreneurship") && oppCat === "business") {
    return { dimension: "category", score: 0.5, reason: `Entrepreneurship relates to Business.`, available: true };
  }
  return { dimension: "category", score: 0, reason: "No category match", available: true };
}
