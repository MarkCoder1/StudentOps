// Context Builder — Phase 9.8
// Builds minimal, structured facts from deterministic engines. AI never replaces them.

import type {
  ProjectExplanationContext,
  ProjectCoachingContext,
  ProjectReflectionContext,
  SkillExplanationContext,
  RoadmapExplanationContext,
} from "./types";

// Generic helper to truncate for prompt
function trunc(s: string | null | undefined, max = 300): string | null {
  if (!s) return null;
  const t = s.trim();
  if (!t) return null;
  return t.length > max ? t.slice(0, max - 3) + "..." : t;
}

export function buildProjectExplanationContext(args: {
  student: { goals: string[]; interests: string[]; skills: string[] };
  project: { id: string; title: string; description: string | null; category: string | null; skills: string[] };
  recommendation: { score: number; reasons: string[]; breakdown: { goalAlignment: number; skillGapCoverage: number; roadmapAlignment: number; interestAlignment: number } };
  skillGaps: string[];
  roadmap?: { id: string; title: string; active: boolean } | null;
}): ProjectExplanationContext {
  return {
    student: {
      goals: args.student.goals.slice(0, 5),
      interests: args.student.interests.slice(0, 5),
      skills: args.student.skills.slice(0, 8),
    },
    project: {
      id: args.project.id,
      title: trunc(args.project.title, 80) ?? args.project.id,
      description: trunc(args.project.description, 300),
      category: trunc(args.project.category, 40),
      skills: args.project.skills.slice(0, 6),
    },
    recommendation: {
      score: args.recommendation.score,
      reasons: args.recommendation.reasons.slice(0, 4),
      breakdown: args.recommendation.breakdown,
    },
    skillGaps: args.skillGaps.slice(0, 6),
    roadmap: args.roadmap ?? null,
    contextVersion: "9.8",
  };
}

export function buildProjectCoachingContext(args: {
  project: { id: string; title: string; goal: string | null; description: string | null };
  playbook?: { overview: string | null; steps: Array<{ id: string; title: string; order: number }>; skillsDeveloped: string[] } | null;
  execution: { completedStepIDs: string[]; totalSteps: number; percent: number };
  currentStep: { id: string; title: string; description: string; objective: string | null; requiredSkills: string[]; estimatedEffort: string | null } | null;
  nextStep: { id: string; title: string; description: string } | null;
  student: { goals: string[]; skills: string[] };
  skillGaps: string[];
}): ProjectCoachingContext {
  return {
    project: {
      id: args.project.id,
      title: trunc(args.project.title, 80) ?? args.project.id,
      goal: trunc(args.project.goal, 200),
      description: trunc(args.project.description, 300),
    },
    playbook: args.playbook
      ? {
          overview: trunc(args.playbook.overview, 300),
          steps: args.playbook.steps.slice(0, 10),
          skillsDeveloped: args.playbook.skillsDeveloped.slice(0, 6),
        }
      : null,
    execution: args.execution,
    currentStep: args.currentStep
      ? {
          id: args.currentStep.id,
          title: trunc(args.currentStep.title, 60) ?? args.currentStep.id,
          description: trunc(args.currentStep.description, 300) ?? "",
          objective: trunc(args.currentStep.objective, 200),
          requiredSkills: args.currentStep.requiredSkills.slice(0, 4),
          estimatedEffort: trunc(args.currentStep.estimatedEffort, 40),
        }
      : null,
    nextStep: args.nextStep
      ? {
          id: args.nextStep.id,
          title: trunc(args.nextStep.title, 60) ?? args.nextStep.id,
          description: trunc(args.nextStep.description, 200) ?? "",
        }
      : null,
    student: {
      goals: args.student.goals.slice(0, 4),
      skills: args.student.skills.slice(0, 6),
    },
    skillGaps: args.skillGaps.slice(0, 6),
    contextVersion: "9.8",
  };
}

export function buildProjectReflectionContext(args: {
  project: { id: string; title: string; description: string | null; outcome: string | null; skills: string[] };
  playbook?: { steps: Array<{ id: string; title: string }>; deliverables: Array<{ id: string; title: string }>; criteria: Array<{ id: string; title: string }> } | null;
  execution: { completedStepIDs: string[]; completedDeliverableIDs: string[]; confirmedCriterionIDs: string[]; isCompleted: boolean };
  evidence: Array<{ id: string; title: string }>;
  achievements: Array<{ id: string; title: string }>;
}): ProjectReflectionContext {
  return {
    project: {
      id: args.project.id,
      title: trunc(args.project.title, 80) ?? args.project.id,
      description: trunc(args.project.description, 300),
      outcome: trunc(args.project.outcome, 300),
      skills: args.project.skills.slice(0, 6),
    },
    playbook: args.playbook
      ? {
          steps: args.playbook.steps.slice(0, 10),
          deliverables: args.playbook.deliverables.slice(0, 6),
          criteria: args.playbook.criteria.slice(0, 6),
        }
      : null,
    execution: args.execution,
    evidence: args.evidence.slice(0, 4),
    achievements: args.achievements.slice(0, 4),
    contextVersion: "9.8",
  };
}

export function buildSkillExplanationContext(args: {
  skill: { id: string; name: string };
  gapReason: string;
  roadmap?: { id: string; title: string } | null;
  project?: { id: string; title: string; skills: string[] } | null;
  studentGoal?: string | null;
}): SkillExplanationContext {
  return {
    skill: { id: args.skill.id, name: trunc(args.skill.name, 40) ?? args.skill.id },
    gapReason: trunc(args.gapReason, 300) ?? "Skill gap",
    roadmap: args.roadmap ? { id: args.roadmap.id, title: trunc(args.roadmap.title, 60) ?? args.roadmap.id } : null,
    project: args.project ? { id: args.project.id, title: trunc(args.project.title, 60) ?? args.project.id, skills: args.project.skills.slice(0, 6) } : null,
    studentGoal: trunc(args.studentGoal, 80),
    contextVersion: "9.8",
  };
}

export function buildRoadmapExplanationContext(args: {
  roadmap: { id: string; title: string; goal: string | null };
  progress: { completedMilestones: number; totalMilestones: number; percent: number; isActive: boolean };
  nextMilestone?: { id: string; title: string } | null;
  skillGaps: string[];
  relevantProjects: Array<{ id: string; title: string }>;
}): RoadmapExplanationContext {
  return {
    roadmap: {
      id: args.roadmap.id,
      title: trunc(args.roadmap.title, 60) ?? args.roadmap.id,
      goal: trunc(args.roadmap.goal, 300),
    },
    progress: args.progress,
    nextMilestone: args.nextMilestone ? { id: args.nextMilestone.id, title: trunc(args.nextMilestone.title, 60) ?? args.nextMilestone.id } : null,
    skillGaps: args.skillGaps.slice(0, 8),
    relevantProjects: args.relevantProjects.slice(0, 4),
    contextVersion: "9.8",
  };
}

export function fingerprintContext(context: Record<string, unknown>): string {
  const data = JSON.stringify(context, Object.keys(context).sort());
  let hash = 2166136261;
  for (let i = 0; i < data.length; i++) {
    hash ^= data.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}
