// Personalization Types — Phase 9.8
// Structured request/response for AI personalization (no AI decision-making)

export type PersonalizationOperation =
  | "projectExplanation"
  | "projectCoaching"
  | "projectReflection"
  | "skillExplanation"
  | "roadmapExplanation";

export interface PersonalizationRequest {
  operation: PersonalizationOperation;
  context: Record<string, unknown>;
  contextFingerprint?: string;
}

export interface PersonalizationResponse {
  operation: PersonalizationOperation;
  data: unknown;
  model: string;
  provider: string;
  contextFingerprint?: string;
}

export type PersonalizationErrorCode =
  | "invalid_request"
  | "insufficient_context"
  | "invalid_ai_response"
  | "ai_generation_failed"
  | "unknown";

export interface PersonalizationError {
  code: PersonalizationErrorCode;
  message: string;
}

// ─── Operation-specific contexts (minimal, data-minimized) ───

export interface ProjectExplanationContext {
  student: {
    goals: string[];
    interests: string[];
    skills: string[];
  };
  project: {
    id: string;
    title: string;
    description: string | null;
    category: string | null;
    skills: string[];
  };
  recommendation: {
    score: number;
    reasons: string[];
    breakdown: {
      goalAlignment: number;
      skillGapCoverage: number;
      roadmapAlignment: number;
      interestAlignment: number;
    };
  };
  skillGaps: string[];
  roadmap?: {
    id: string;
    title: string;
    active: boolean;
  } | null;
  contextVersion?: string;
}

export interface ProjectCoachingContext {
  project: {
    id: string;
    title: string;
    goal: string | null;
    description: string | null;
  };
  playbook?: {
    overview: string | null;
    steps: Array<{ id: string; title: string; order: number }>;
    skillsDeveloped: string[];
  } | null;
  execution: {
    completedStepIDs: string[];
    totalSteps: number;
    percent: number;
  };
  currentStep: {
    id: string;
    title: string;
    description: string;
    objective: string | null;
    requiredSkills: string[];
    estimatedEffort: string | null;
  } | null;
  nextStep: {
    id: string;
    title: string;
    description: string;
  } | null;
  student: {
    goals: string[];
    skills: string[];
  };
  skillGaps: string[];
  contextVersion?: string;
}

export interface ProjectReflectionContext {
  project: {
    id: string;
    title: string;
    description: string | null;
    outcome: string | null;
    skills: string[];
  };
  playbook?: {
    steps: Array<{ id: string; title: string }>;
    deliverables: Array<{ id: string; title: string }>;
    criteria: Array<{ id: string; title: string }>;
  } | null;
  execution: {
    completedStepIDs: string[];
    completedDeliverableIDs: string[];
    confirmedCriterionIDs: string[];
    isCompleted: boolean;
  };
  evidence: Array<{ id: string; title: string }>;
  achievements: Array<{ id: string; title: string }>;
  contextVersion?: string;
}

export interface SkillExplanationContext {
  skill: {
    id: string;
    name: string;
  };
  gapReason: string;
  roadmap?: {
    id: string;
    title: string;
  } | null;
  project?: {
    id: string;
    title: string;
    skills: string[];
  } | null;
  studentGoal?: string | null;
  contextVersion?: string;
}

export interface RoadmapExplanationContext {
  roadmap: {
    id: string;
    title: string;
    goal: string | null;
  };
  progress: {
    completedMilestones: number;
    totalMilestones: number;
    percent: number;
    isActive: boolean;
  };
  nextMilestone?: {
    id: string;
    title: string;
  } | null;
  skillGaps: string[];
  relevantProjects: Array<{ id: string; title: string }>;
  contextVersion?: string;
}

// ─── Structured outputs ───

export interface ProjectExplanationOutput {
  summary: string;
  reasons: string[];
}
export interface ProjectCoachingOutput {
  focus: string;
  actions: string[];
  caution?: string | null;
}
export interface ProjectReflectionOutput {
  prompts: string[];
  draftReflection?: string | null;
}
export interface SkillExplanationOutput {
  summary: string;
  howProjectHelps: string;
}
export interface RoadmapExplanationOutput {
  summary: string;
  focusAreas: string[];
}
