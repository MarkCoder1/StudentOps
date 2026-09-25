// Roadmap Personalization Prompt — Phase 6.3
// Builds the system and user prompts for AI roadmap ranking.
// The AI must use ONLY supplied facts — no inventing.

import type { RoadmapStudentContext, RoadmapCatalogItem } from "./types";

const SYSTEM_PROMPT = `You are the personalization layer for Student OPS.

You may recommend ONLY from the existing roadmaps supplied in the context.

Use ONLY the supplied student facts and roadmap facts.
Do not invent roadmaps, milestones, skills, achievements, projects, goals, or career information.
Do not modify roadmap progress.
Do not decide whether a milestone is completed.
Do not override deterministic calculations.

Rank the existing roadmaps according to how strongly they fit the student's stated interests, career goals, skills, projects, achievements, and goals.

Every recommendation must reference evidence contained in the supplied context.
If evidence is weak, give a lower fit score rather than inventing evidence.

Return ONLY the requested structured JSON with a "recommendations" array containing objects with:
- roadmapId: the exact ID from the supplied roadmaps
- fitScore: 0-100 integer
- reason: 1-2 concise sentences explaining the fit, referencing specific student facts

Include ALL supplied roadmaps in the recommendations, ranked by fitScore descending.
Write at an 8th-grade reading level. Be specific to this student. Do not give generic advice.`;

interface RoadmapPromptArgs {
  student: RoadmapStudentContext;
  roadmaps: RoadmapCatalogItem[];
}

export function buildRoadmapPrompt(args: RoadmapPromptArgs): { system: string; user: string } {
  const { student, roadmaps } = args;

  const studentSection = formatStudentSection(student);
  const roadmapsSection = formatRoadmapsSection(roadmaps);

  const user = `STUDENT PROFILE:
${studentSection}

AVAILABLE ROADMAPS:
${roadmapsSection}

Rank these roadmaps by fit for this student. Return ALL roadmaps in the recommendations array.`;

  return { system: SYSTEM_PROMPT, user };
}

function formatStudentSection(s: RoadmapStudentContext): string {
  const lines: string[] = [];
  if (s.firstName) lines.push(`- Name: ${s.firstName}`);
  if (s.schoolLevel) lines.push(`- School level: ${s.schoolLevel}`);
  if (s.grade) lines.push(`- Grade: ${s.grade}`);
  if (s.age) lines.push(`- Age: ${s.age}`);
  if (s.interests.length) lines.push(`- Interests: ${s.interests.join(", ")}`);
  if (s.skills.length) lines.push(`- Skills: ${s.skills.join(", ")}`);
  if (s.careers.length) lines.push(`- Career goals: ${s.careers.join(", ")}`);
  if (s.fields.length) lines.push(`- Fields of study: ${s.fields.join(", ")}`);
  if (s.goals.length) lines.push(`- Goals/milestones: ${s.goals.join(", ")}`);
  if (s.projects.length) {
    lines.push(`- Projects:`);
    for (const p of s.projects) {
      lines.push(`  - ${p.title} (${p.category}) — skills: ${p.skills.join(", ") || "none"}`);
    }
  }
  if (s.achievements.length) {
    lines.push(`- Achievements:`);
    for (const a of s.achievements) {
      lines.push(`  - ${a.title} (${a.category})`);
    }
  }
  if (s.completedRoadmapCount > 0) lines.push(`- Completed roadmaps: ${s.completedRoadmapCount}`);
  if (s.activeRoadmapCount > 0) lines.push(`- Active roadmaps: ${s.activeRoadmapCount}`);
  if (lines.length === 0) lines.push("- No profile data available");
  return lines.join("\n");
}

function formatRoadmapsSection(roadmaps: RoadmapCatalogItem[]): string {
  return roadmaps.map((r) => {
    const lines: string[] = [];
    lines.push(`- ID: ${r.id}`);
    lines.push(`  Title: ${r.title}`);
    lines.push(`  Goal: ${r.goal}`);
    lines.push(`  Category: ${r.category}`);
    lines.push(`  Description: ${r.description}`);
    lines.push(`  Progress: ${r.completedMilestones}/${r.milestoneCount} milestones`);
    if (r.relevantInterests.length) lines.push(`  Relevant interests: ${r.relevantInterests.join(", ")}`);
    if (r.relevantSkills.length) lines.push(`  Relevant skills: ${r.relevantSkills.join(", ")}`);
    if (r.relevantCareers.length) lines.push(`  Relevant careers: ${r.relevantCareers.join(", ")}`);
    if (r.relevantFields.length) lines.push(`  Relevant fields: ${r.relevantFields.join(", ")}`);
    lines.push(`  Deterministic match score: ${r.matchScore}%`);
    return lines.join("\n");
  }).join("\n\n");
}
