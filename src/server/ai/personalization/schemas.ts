// Schemas — Phase 9.8
// Strict JSON Schemas for structured AI outputs. Keep lengths concise.

export const PROJECT_EXPLANATION_SCHEMA = {
  name: "project_explanation",
  description: "Why a project was recommended",
  strict: true,
  schema: {
    type: "object",
    properties: {
      summary: { type: "string", minLength: 20, maxLength: 600 },
      reasons: {
        type: "array",
        items: { type: "string", minLength: 10, maxLength: 200 },
        minItems: 2,
        maxItems: 4,
      },
    },
    required: ["summary", "reasons"],
    additionalProperties: false,
  },
} as const;

export const PROJECT_COACHING_SCHEMA = {
  name: "project_coaching",
  description: "Coaching for next playbook step",
  strict: true,
  schema: {
    type: "object",
    properties: {
      focus: { type: "string", minLength: 20, maxLength: 400 },
      actions: {
        type: "array",
        items: { type: "string", minLength: 10, maxLength: 200 },
        minItems: 2,
        maxItems: 5,
      },
      caution: { type: ["string", "null"], maxLength: 200 },
    },
    required: ["focus", "actions"],
    additionalProperties: false,
  },
} as const;

export const PROJECT_REFLECTION_SCHEMA = {
  name: "project_reflection",
  description: "Reflection prompts for completed project",
  strict: true,
  schema: {
    type: "object",
    properties: {
      prompts: {
        type: "array",
        items: { type: "string", minLength: 10, maxLength: 250 },
        minItems: 3,
        maxItems: 5,
      },
      draftReflection: { type: ["string", "null"], maxLength: 1200 },
    },
    required: ["prompts"],
    additionalProperties: false,
  },
} as const;

export const SKILL_EXPLANATION_SCHEMA = {
  name: "skill_explanation",
  description: "Why a skill is a gap and how project helps",
  strict: true,
  schema: {
    type: "object",
    properties: {
      summary: { type: "string", minLength: 20, maxLength: 400 },
      howProjectHelps: { type: "string", minLength: 20, maxLength: 400 },
    },
    required: ["summary", "howProjectHelps"],
    additionalProperties: false,
  },
} as const;

export const ROADMAP_EXPLANATION_SCHEMA = {
  name: "roadmap_explanation",
  description: "Roadmap summary and focus areas",
  strict: true,
  schema: {
    type: "object",
    properties: {
      summary: { type: "string", minLength: 20, maxLength: 600 },
      focusAreas: {
        type: "array",
        items: { type: "string", minLength: 10, maxLength: 200 },
        minItems: 2,
        maxItems: 4,
      },
    },
    required: ["summary", "focusAreas"],
    additionalProperties: false,
  },
} as const;
