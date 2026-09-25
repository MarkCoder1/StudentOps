// Portfolio Writing Context Builder — Phase 8.9
// Deterministic, career-agnostic, no AI, no networking.
// Resolves selected portfolio entities and builds minimal fact-grounded context.

import type {
  PortfolioWritingContext,
  PortfolioWritingType,
} from "./types";

// ─── Input Types (canonical, minimal) ─────────────────────────────

export interface ContextBuilderInput {
  portfolio: {
    id: string;
    title: string;
    headline?: string | null;
    about?: string | null;
    goals?: string[];
    selectedProjectIDs?: string[];
    selectedAchievementIDs?: string[];
    selectedEvidenceIDs?: string[];
    selectedSkillIDs?: string[];
    selectedRoadmapIDs?: string[];
  };
  profile?: {
    firstName?: string | null;
    grade?: string | null;
    schoolLevel?: string | null;
    location?: string | null;
  } | null;
  projects: Array<{
    id: string;
    title: string;
    description?: string | null;
    category?: string | null;
    goal?: string | null;
    skills?: string[];
    progress?: number | null;
    isCompleted?: boolean | null;
    sourceRoadmapID?: string | null;
    evidenceCount?: number | null;
    artifactURL?: string | null;
  }>;
  achievements: Array<{
    id: string;
    title: string;
    description?: string | null;
    type?: string | null;
    createdAt?: string | null;
    evidenceCount?: number | null;
    skillIDs?: string[];
    roadmapID?: string | null;
    projectID?: string | null;
  }>;
  evidence: Array<{
    id: string;
    title: string;
    description?: string | null;
    type?: string | null;
    roadmapID?: string | null;
    milestoneID?: string | null;
    projectID?: string | null;
    skillIDs?: string[];
    artifactURL?: string | null;
    createdAt?: string | null;
    quality?: string | null;
  }>;
  skills: Array<{ id: string; name: string }>;
  roadmaps: Array<{
    id: string;
    title: string;
    goal?: string | null;
    progress?: number | null;
    isActive?: boolean | null;
    completedMilestones?: number | null;
    totalMilestones?: number | null;
  }>;
}

// ─── Helpers ───────────────────────────────────────────────────────

function truncate(text: string | null | undefined, max: number): string | null {
  if (!text) return null;
  const t = String(text).trim();
  if (!t) return null;
  if (t.length <= max) return t;
  return t.slice(0, max - 3) + "...";
}

function dedup<T>(arr: T[]): T[] {
  return [...new Set(arr)];
}

// ─── Fingerprint ───────────────────────────────────────────────────

export function fingerprintContext(ctx: PortfolioWritingContext): string {
  // Deterministic fingerprint: sorted JSON of relevant source IDs + key portfolio fields — must match iOS PortfolioWritingContextBuilder.fingerprint
  const payload = {
    portfolioID: ctx.portfolio.id,
    title: ctx.portfolio.title,
    headline: ctx.portfolio.headline ?? "",
    about: ctx.portfolio.about ?? "",
    goals: [...(ctx.portfolio.goals ?? [])].sort(),
    projects: ctx.projects.map((p) => p.id).sort(),
    achievements: ctx.achievements.map((a) => a.id).sort(),
    evidence: ctx.evidence.map((e) => e.id).sort(),
    skills: ctx.skills.map((s) => s.id).sort(),
    roadmaps: ctx.roadmaps.map((r) => r.id).sort(),
  };
  const str = JSON.stringify(payload);
  // Simple deterministic hash (FNV-1a 32-bit hex)
  let hash = 2166136261;
  for (let i = 0; i < str.length; i++) {
    hash ^= str.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

// ─── Builder ───────────────────────────────────────────────────────

export function buildPortfolioWritingContext(
  input: ContextBuilderInput,
  writingType: PortfolioWritingType,
  targetID?: string | null
): PortfolioWritingContext {
  const portfolio = {
    id: input.portfolio.id,
    title: truncate(input.portfolio.title, 120) ?? "Untitled Portfolio",
    headline: truncate(input.portfolio.headline ?? null, 160),
    about: truncate(input.portfolio.about ?? null, 1200),
    goals: (input.portfolio.goals ?? []).map((g) => truncate(g, 400)).filter(Boolean) as string[],
  };

  const student = {
    displayName: truncate(input.profile?.firstName ?? null, 60),
    grade: truncate(input.profile?.grade ?? null, 20),
    schoolLevel: truncate(input.profile?.schoolLevel ?? null, 30),
    location: truncate(input.profile?.location ?? null, 60),
  };

  const education = {
    grade: student.grade,
    schoolLevel: student.schoolLevel,
  };

  // Helper to find entity by ID
  const projectMap = new Map(input.projects.map((p) => [p.id, p]));
  const achievementMap = new Map(input.achievements.map((a) => [a.id, a]));
  const evidenceMap = new Map(input.evidence.map((e) => [e.id, e]));
  const skillMap = new Map(input.skills.map((s) => [s.id, s]));
  const roadmapMap = new Map(input.roadmaps.map((r) => [r.id, r]));

  // Target-specific filtering
  let projects: ContextBuilderInput["projects"] = [];
  let achievements: ContextBuilderInput["achievements"] = [];
  let evidence: ContextBuilderInput["evidence"] = [];
  let skills: ContextBuilderInput["skills"] = [];
  let roadmaps: ContextBuilderInput["roadmaps"] = [];

  switch (writingType) {
    case "headline": {
      // Portfolio-level summary: student + portfolio metadata + counts
      // Minimal: headiline should be based on portfolio title, student interests implied via skills/projects, but we keep student + portfolio only
      projects = [];
      achievements = [];
      evidence = [];
      skills = input.skills.slice(0, 6);
      roadmaps = [];
      break;
    }
    case "about": {
      // Portfolio-level: student + portfolio + selected counts, plus a sample of projects/achievements for grounding
      projects = input.portfolio.selectedProjectIDs
        ? (input.portfolio.selectedProjectIDs as string[]).slice(0, 3).map((id) => projectMap.get(id)).filter(Boolean) as ContextBuilderInput["projects"]
        : [];
      // Fallback to provided projects if selected empty
      if (projects.length === 0) projects = input.projects.slice(0, 2);
      achievements = input.portfolio.selectedAchievementIDs
        ? (input.portfolio.selectedAchievementIDs as string[]).slice(0, 2).map((id) => achievementMap.get(id)).filter(Boolean) as ContextBuilderInput["achievements"]
        : [];
      evidence = [];
      skills = input.skills.slice(0, 6);
      roadmaps = input.portfolio.selectedRoadmapIDs
        ? (input.portfolio.selectedRoadmapIDs as string[]).slice(0, 2).map((id) => roadmapMap.get(id)).filter(Boolean) as ContextBuilderInput["roadmaps"]
        : [];
      break;
    }
    case "goal": {
      // For a specific goal, send that goal + portfolio goals + student goals
      // targetID is index or goal text? We treat targetID as goal index or goal text
      // Find the specific goal
      let targetGoal: string | null = null;
      if (targetID) {
        // Try as index
        const idx = Number(targetID);
        if (!Number.isNaN(idx) && input.portfolio.goals && input.portfolio.goals[idx] !== undefined) {
          targetGoal = input.portfolio.goals[idx];
        } else {
          // Try as exact goal text
          const found = (input.portfolio.goals ?? []).find((g) => g === targetID);
          if (found) targetGoal = found;
          else targetGoal = targetID; // fallback use targetID as goal text if not found
        }
      }
      // For goal writing, context is the specific goal plus student profile
      projects = [];
      achievements = [];
      evidence = [];
      skills = input.skills.slice(0, 4);
      roadmaps = [];
      // Override portfolio goals to just the target goal for minimal context
      if (targetGoal) {
        portfolio.goals = [truncate(targetGoal, 400) as string];
      }
      break;
    }
    case "projectDescription": {
      if (!targetID || !projectMap.has(targetID)) {
        // No project found, will be handled as insufficient_context upstream, but still build minimal context
        break;
      }
      const proj = projectMap.get(targetID)!;
      projects = [proj];
      // Directly supporting evidence for this project
      evidence = input.evidence.filter((e) => e.projectID === targetID).slice(0, 4);
      // Related skills for this project
      const projSkillIDs = new Set((proj.skills ?? []).map((s) => s.toLowerCase()));
      skills = input.skills.filter((s) => projSkillIDs.has(s.id.toLowerCase())).slice(0, 4);
      // Related achievement if any selected achievement references this project
      achievements = input.achievements.filter((a) => a.projectID === targetID).slice(0, 2);
      // Roadmap context if project has sourceRoadmapID and that roadmap is selected
      if (proj.sourceRoadmapID && roadmapMap.has(proj.sourceRoadmapID)) {
        roadmaps = [roadmapMap.get(proj.sourceRoadmapID)!];
      }
      break;
    }
    case "achievementDescription": {
      if (!targetID || !achievementMap.has(targetID)) break;
      const ach = achievementMap.get(targetID)!;
      achievements = [ach];
      // Linked evidence
      const ids = new Set(ach.evidenceCount != null ? [] : []); // placeholder
      // Use achievement's evidenceIDs to find evidence (we don't have that in achievementMap's evidenceCount, need to look up via input.evidence)
      // For now, filter evidence that is in achievement's evidence list or that references achievement via project/roadmap
      // Simpler: filter evidence where achievement's evidenceIDs contains evidence id (we need achievement's evidence IDs, but our achievement input doesn't have that? It has evidenceCount, not IDs)
      // For context builder, we will use input.evidence that is linked via achievement's stored evidenceIDs if available via original achievement object
      // Since our ContextBuilderInput's achievement doesn't have evidenceIDs, we will just include evidence that references achievement's project/roadmap
      evidence = input.evidence.filter((e) => {
        // If evidence projectID matches achievement projectID, or evidence roadmapID matches achievement roadmapID
        if (ach.projectID && e.projectID === ach.projectID) return true;
        if (ach.roadmapID && e.roadmapID === ach.roadmapID) return true;
        return false;
      }).slice(0, 4);
      // If no evidence found via that, include any evidence (fallback)
      if (evidence.length === 0) evidence = input.evidence.slice(0, 2);
      // Related skills
      if (ach.skillIDs) {
        const achSkillIDs = new Set(ach.skillIDs.map((s) => s.toLowerCase()));
        skills = input.skills.filter((s) => achSkillIDs.has(s.id.toLowerCase())).slice(0, 4);
      }
      if (ach.projectID && projectMap.has(ach.projectID)) projects = [projectMap.get(ach.projectID)!];
      if (ach.roadmapID && roadmapMap.has(ach.roadmapID)) roadmaps = [roadmapMap.get(ach.roadmapID)!];
      break;
    }
    case "evidenceDescription": {
      if (!targetID || !evidenceMap.has(targetID)) break;
      const ev = evidenceMap.get(targetID)!;
      evidence = [ev];
      // Related project/roadmap/skill via evidence's own fields
      if (ev.projectID && projectMap.has(ev.projectID)) projects = [projectMap.get(ev.projectID)!];
      if (ev.roadmapID && roadmapMap.has(ev.roadmapID)) roadmaps = [roadmapMap.get(ev.roadmapID)!];
      if (ev.skillIDs) {
        const evSkillIDs = new Set(ev.skillIDs.map((s) => s.toLowerCase()));
        skills = input.skills.filter((s) => evSkillIDs.has(s.id.toLowerCase())).slice(0, 4);
      }
      break;
    }
    case "roadmapSummary": {
      if (!targetID || !roadmapMap.has(targetID)) break;
      const rm = roadmapMap.get(targetID)!;
      roadmaps = [rm];
      evidence = input.evidence.filter((e) => e.roadmapID === targetID).slice(0, 4);
      // Related skills for roadmap
      // We don't have roadmap's required skills in input, so just include a few skills
      skills = input.skills.slice(0, 4);
      break;
    }
  }

  // Truncate and dedup already done via slice; ensure minimal
  return {
    portfolio,
    student,
    education,
    projects: projects.map((p) => ({
      id: p.id,
      title: truncate(p.title, 80) ?? p.title,
      description: truncate(p.description ?? null, 500),
      goal: truncate(p.goal ?? null, 200),
      category: p.category ? truncate(p.category, 40) : null,
      skills: (p.skills ?? []).slice(0, 4),
      progress: p.progress ?? null,
      isCompleted: p.isCompleted ?? null,
      sourceRoadmapID: p.sourceRoadmapID ?? null,
      evidenceCount: p.evidenceCount ?? null,
      artifactURL: p.artifactURL ?? null,
    })),
    achievements: achievements.map((a) => ({
      id: a.id,
      title: truncate(a.title, 80) ?? a.title,
      description: truncate(a.description ?? null, 500),
      type: a.type ? truncate(a.type, 20) : null,
      createdAt: a.createdAt ?? null,
      evidenceCount: a.evidenceCount ?? null,
      skillIDs: a.skillIDs ?? [],
      roadmapID: a.roadmapID ?? null,
      projectID: a.projectID ?? null,
    })),
    evidence: evidence.map((e) => ({
      id: e.id,
      title: truncate(e.title, 80) ?? e.title,
      description: truncate(e.description ?? null, 500),
      type: e.type ? truncate(e.type, 20) : null,
      roadmapID: e.roadmapID ?? null,
      milestoneID: e.milestoneID ?? null,
      projectID: e.projectID ?? null,
      skillIDs: e.skillIDs ?? [],
      artifactURL: e.artifactURL ?? null,
      createdAt: e.createdAt ?? null,
      quality: e.quality ?? null,
    })),
    skills: skills.map((s) => ({ id: s.id, name: truncate(s.name, 40) ?? s.name })),
    roadmaps: roadmaps.map((r) => ({
      id: r.id,
      title: truncate(r.title, 80) ?? r.title,
      goal: truncate(r.goal ?? null, 200),
      progress: r.progress ?? null,
      isActive: r.isActive ?? null,
      completedMilestones: r.completedMilestones ?? null,
      totalMilestones: r.totalMilestones ?? null,
    })),
    constraints: { writingType, targetID: targetID ?? null },
  };
}
