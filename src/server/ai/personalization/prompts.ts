// Prompts — Phase 9.8
// Centralized, fact-grounded, no hallucination.

import type {
  ProjectExplanationContext,
  ProjectCoachingContext,
  ProjectReflectionContext,
  SkillExplanationContext,
  RoadmapExplanationContext,
} from "./types";

const BASE_SYSTEM = `You are an assistant inside Student OPS.

STRICT RULES — YOU MUST FOLLOW:
- Use ONLY the supplied student/project facts. Do NOT invent awards, grades, skills, projects, outcomes, hours, impact numbers, leadership roles, competitions, publications, credentials, evidence, achievements, or metrics.
- If a fact is missing, omit it or say "Not enough information" — never hallucinate.
- Do NOT determine eligibility, recommendation scores, project completion, step completion, skill gaps, or roadmap progress. Those are deterministic and already supplied — you only explain them.
- Do NOT mark anything complete, create achievements, or claim outcomes not present.
- Your job is to explain, personalize, coach, or draft language using only supplied facts.
- Be concise, specific, grounded, actionable, and student-appropriate.
- Return ONLY the requested structured JSON.`;

export function buildProjectExplanationPrompt(context: ProjectExplanationContext): { system: string; user: string } {
  const system = `${BASE_SYSTEM}\n\nYou explain why a project was recommended. Do not generate a new score.`;
  const user = [
    `PROJECT EXPLANATION REQUEST`,
    ``,
    `Student goals: ${context.student.goals.join(" | ") || "none"}`,
    `Student interests: ${context.student.interests.join(" | ") || "none"}`,
    `Student skills: ${context.student.skills.join(" | ") || "none"}`,
    `Skill gaps: ${context.skillGaps.join(" | ") || "none"}`,
    context.roadmap ? `Roadmap: ${context.roadmap.title} (active: ${context.roadmap.active})` : `Roadmap: none`,
    ``,
    `Project: ${context.project.title} (${context.project.id})`,
    `Category: ${context.project.category ?? "none"}`,
    `Description: ${context.project.description ?? "none"}`,
    `Skills: ${context.project.skills.join(" | ") || "none"}`,
    ``,
    `Deterministic recommendation (do not change):`,
    `Score: ${context.recommendation.score} / 100`,
    `Reasons: ${context.recommendation.reasons.join(" | ") || "none"}`,
    `Breakdown: goal=${context.recommendation.breakdown.goalAlignment}, skillGap=${context.recommendation.breakdown.skillGapCoverage}, roadmap=${context.recommendation.breakdown.roadmapAlignment}, interest=${context.recommendation.breakdown.interestAlignment}`,
    ``,
    `Explain why this project matters to this student using only the facts above. Keep to 1-3 short paragraphs, then list 2-3 reasons.`,
  ].join("\n");
  return { system, user };
}

export function buildProjectCoachingPrompt(context: ProjectCoachingContext): { system: string; user: string } {
  const system = `${BASE_SYSTEM}\n\nYou coach the student on the exact next playbook step. Do not complete steps, do not mark deliverables.`;
  const user = [
    `PROJECT COACHING REQUEST`,
    ``,
    `Project: ${context.project.title} (${context.project.id})`,
    `Goal: ${context.project.goal ?? "none"}`,
    context.playbook?.overview ? `Overview: ${context.playbook.overview}` : null,
    context.playbook ? `Playbook skills: ${context.playbook.skillsDeveloped.join(" | ")}` : null,
    ``,
    `Execution: ${context.execution.completedStepIDs.length} / ${context.execution.totalSteps} steps, ${context.execution.percent}%`,
    context.currentStep ? `Current step: ${context.currentStep.title} — ${context.currentStep.description} (objective: ${context.currentStep.objective ?? "none"}, skills: ${context.currentStep.requiredSkills.join(" | ") || "none"}, effort: ${context.currentStep.estimatedEffort ?? "none"})` : `Current step: none`,
    context.nextStep ? `Next step: ${context.nextStep.title} — ${context.nextStep.description}` : `Next step: none`,
    ``,
    `Student goals: ${context.student.goals.join(" | ") || "none"}`,
    `Student skills: ${context.student.skills.join(" | ") || "none"}`,
    `Skill gaps: ${context.skillGaps.join(" | ") || "none"}`,
    ``,
    `Provide focused coaching for the next step: a short focus paragraph, 2-5 concrete actions, and an optional caution. Use only supplied facts.`,
  ]
    .filter(Boolean)
    .join("\n");
  return { system, user };
}

export function buildProjectReflectionPrompt(context: ProjectReflectionContext): { system: string; user: string } {
  const system = `${BASE_SYSTEM}\n\nYou generate reflection prompts or a draft reflection strictly from supplied facts. Do not invent outcomes or impact.`;
  const user = [
    `PROJECT REFLECTION REQUEST`,
    ``,
    `Project: ${context.project.title}`,
    `Description: ${context.project.description ?? "none"}`,
    `Outcome: ${context.project.outcome ?? "none"}`,
    `Skills: ${context.project.skills.join(" | ") || "none"}`,
    context.playbook ? `Steps: ${context.playbook.steps.map((s) => s.title).join(" | ")}` : null,
    context.playbook ? `Deliverables: ${context.playbook.deliverables.map((d) => d.title).join(" | ")}` : null,
    context.playbook ? `Criteria: ${context.playbook.criteria.map((c) => c.title).join(" | ")}` : null,
    `Execution: ${context.execution.completedStepIDs.length} steps, ${context.execution.completedDeliverableIDs.length} deliverables, ${context.execution.confirmedCriterionIDs.length} criteria, completed: ${context.execution.isCompleted}`,
    `Evidence: ${context.evidence.map((e) => e.title).join(" | ") || "none"}`,
    `Achievements: ${context.achievements.map((a) => a.title).join(" | ") || "none"}`,
    ``,
    `Generate 3-5 reflection prompts (and optionally a draft if requested) grounded only in facts above.`,
  ]
    .filter(Boolean)
    .join("\n");
  return { system, user };
}

export function buildSkillExplanationPrompt(context: SkillExplanationContext): { system: string; user: string } {
  const system = `${BASE_SYSTEM}\n\nYou explain why a skill is a gap and how a project helps. Do not decide gap.`;
  const user = [
    `SKILL EXPLANATION REQUEST`,
    ``,
    `Skill: ${context.skill.name} (${context.skill.id})`,
    `Gap reason: ${context.gapReason}`,
    context.roadmap ? `Roadmap: ${context.roadmap.title}` : `Roadmap: none`,
    context.project ? `Project: ${context.project.title} (skills: ${context.project.skills.join(" | ")})` : `Project: none`,
    context.studentGoal ? `Student goal: ${context.studentGoal}` : `Student goal: none`,
    ``,
    `Explain why this skill is a gap and how the project helps, using only supplied facts.`,
  ].join("\n");
  return { system, user };
}

export function buildRoadmapExplanationPrompt(context: RoadmapExplanationContext): { system: string; user: string } {
  const system = `${BASE_SYSTEM}\n\nYou explain a roadmap's current state and what to focus next. Do not reorder phases.`;
  const user = [
    `ROADMAP EXPLANATION REQUEST`,
    ``,
    `Roadmap: ${context.roadmap.title} (${context.roadmap.id})`,
    `Goal: ${context.roadmap.goal ?? "none"}`,
    `Progress: ${context.progress.completedMilestones} / ${context.progress.totalMilestones} milestones, ${context.progress.percent}%${context.progress.isActive ? " (active)" : ""}`,
    context.nextMilestone ? `Next milestone: ${context.nextMilestone.title}` : `Next milestone: none`,
    `Skill gaps: ${context.skillGaps.join(" | ") || "none"}`,
    `Relevant projects: ${context.relevantProjects.map((p) => p.title).join(" | ") || "none"}`,
    ``,
    `Summarize the roadmap and suggest 2-4 focus areas using only facts above.`,
  ].join("\n");
  return { system, user };
}
