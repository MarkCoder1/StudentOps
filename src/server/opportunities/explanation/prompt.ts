// Explanation Prompt Builder — Phase 6.2
// Builds the system and user prompts for AI opportunity explanations.
// The AI must use ONLY supplied facts — no inventing.

import type { AIStudentContext, AIOpportunityContext, AIEngineResult } from "../../ai/context";

const SYSTEM_PROMPT = `You are the explanation layer for Student OPS.

Use ONLY the supplied student facts, opportunity facts, and deterministic eligibility/matching/freshness results.

Do not invent or infer unsupported facts.
Never override deterministic eligibility, deadline, matching, freshness, or progress calculations.
Never fabricate requirements, deadlines, prizes, organizations, skills, roadmap relationships, or student accomplishments.

Explain why this opportunity is relevant to this specific student using ONLY the data provided.

If there is insufficient evidence for a claim, phrase the explanation conservatively rather than inventing information.

Return ONLY the requested structured JSON with three fields:
- whyThisFits: 1-3 sentences explaining why this opportunity matches the student's interests, skills, and profile.
- roadmapConnection: 1-2 sentences on how this opportunity supports the student's goals and roadmap.
- nextStep: 1 sentence with a concrete, actionable next step the student should take.

Write at an 8th-grade reading level. Be specific to this student and this opportunity. Do not give generic advice.`;

interface ExplanationUserPromptArgs {
  student: AIStudentContext;
  opportunity: AIOpportunityContext;
  engines: AIEngineResult;
}

export function buildExplanationPrompt(args: ExplanationUserPromptArgs): { system: string; user: string } {
  const { student, opportunity, engines } = args;

  const studentSection = formatStudentSection(student);
  const opportunitySection = formatOpportunitySection(opportunity);
  const enginesSection = formatEnginesSection(engines);

  const user = `STUDENT PROFILE:
${studentSection}

OPPORTUNITY:
${opportunitySection}

DETERMINISTIC RESULTS:
${enginesSection}

Generate a structured explanation with whyThisFits, roadmapConnection, and nextStep.`;

  return { system: SYSTEM_PROMPT, user };
}

function formatStudentSection(s: AIStudentContext): string {
  const lines: string[] = [];
  if (s.schoolLevel) lines.push(`- School level: ${s.schoolLevel}`);
  if (s.grade) lines.push(`- Grade: ${s.grade}`);
  if (s.interests.length) lines.push(`- Interests: ${s.interests.join(", ")}`);
  if (s.skills.length) lines.push(`- Skills: ${s.skills.join(", ")}`);
  if (s.careers.length) lines.push(`- Career goals: ${s.careers.join(", ")}`);
  if (s.fields.length) lines.push(`- Fields of study: ${s.fields.join(", ")}`);
  if (s.goals.length) lines.push(`- Goals/milestones: ${s.goals.join(", ")}`);
  if (s.location) lines.push(`- Location: ${s.location}`);
  if (lines.length === 0) lines.push("- No profile data available");
  return lines.join("\n");
}

function formatOpportunitySection(o: AIOpportunityContext): string {
  const lines: string[] = [];
  lines.push(`- Title: ${o.title}`);
  if (o.organization) lines.push(`- Organization: ${o.organization}`);
  lines.push(`- Category: ${o.category}`);
  if (o.description) lines.push(`- Description: ${o.description}`);
  if (o.skills.length) lines.push(`- Skills involved: ${o.skills.join(", ")}`);
  if (o.topics.length) lines.push(`- Topics: ${o.topics.join(", ")}`);
  if (o.deadline) lines.push(`- Deadline: ${o.deadline}`);
  if (o.cost.isFree === true) lines.push(`- Cost: Free`);
  else if (o.cost.amount != null) lines.push(`- Cost: ${o.cost.amount}`);
  if (o.location.type === "online") lines.push(`- Location: Online`);
  else if (o.location.type === "inPerson") lines.push(`- Location: In-person`);
  return lines.join("\n");
}

function formatEnginesSection(e: AIEngineResult): string {
  const lines: string[] = [];
  lines.push(`- Eligibility: ${e.eligibility.status}`);
  if (e.eligibility.reasons.length) {
    for (const r of e.eligibility.reasons) {
      lines.push(`  - ${r.dimension}: ${r.message}`);
    }
  }
  lines.push(`- Match score: ${e.match.score}% (${e.match.label})`);
  if (e.match.reasons.length) {
    lines.push(`- Match reasons: ${e.match.reasons.join("; ")}`);
  }
  lines.push(`- Freshness: ${e.freshness.status} (${e.freshness.urgency})`);
  if (e.freshness.daysUntilDeadline != null) {
    lines.push(`- Days until deadline: ${e.freshness.daysUntilDeadline}`);
  }
  return lines.join("\n");
}
