import type { MatchSignal } from "./types";

const WEIGHTS: Record<string, number> = {
  interest: 25,
  career: 20,
  field: 15,
  skill: 15,
  subject: 10,
  goal: 10,
  category: 5,
};

export function calculateScore(signals: MatchSignal[]): number {
  let weightedSum = 0;
  let totalWeight = 0;

  for (const sig of signals) {
    if (!sig.available) continue; // do not punish missing dimensions
    const w = WEIGHTS[sig.dimension] ?? 0;
    totalWeight += w;
    weightedSum += sig.score * w;
  }

  if (totalWeight === 0) return 0;
  const raw = (weightedSum / totalWeight) * 100;
  const clamped = Math.max(0, Math.min(100, raw));
  return Math.round(clamped);
}
