import type { Opportunity } from "../models/opportunity";
import type { StudentProfileForEligibility, EligibilityCheck } from "./types";

function normalizeMajor(value: string): string {
  return value.trim().toLowerCase();
}

export function evaluateMajor(
  opportunity: Opportunity,
  student: StudentProfileForEligibility
): EligibilityCheck {
  const requiredMajors = opportunity.eligibility.majors;
  if (!requiredMajors || requiredMajors.length === 0) {
    return {
      dimension: "major",
      status: "unknown",
      reason: "Major/field requirement is not specified by the source.",
    };
  }

  // Build student fields set — only explicit academic fields, not loose interests
  // Conservative: interests, customInterests, strengths are NOT equivalent to major
  // Only student.fields (intended study areas) is considered
  const studentFields = new Set<string>();
  for (const f of student.fields ?? []) {
    const norm = normalizeMajor(f);
    if (norm) studentFields.add(norm);
  }

  // Also consider student.careers? No — careers are not majors, per spec example AI vs Computer Science should be unknown
  // So we intentionally do NOT add careers/interests/skills to studentFields

  if (studentFields.size === 0) {
    return {
      dimension: "major",
      status: "unknown",
      reason: "Student field of study is not available; cannot evaluate major requirement.",
    };
  }

  const normalizedRequired = requiredMajors.map(normalizeMajor);

  // Check for exact match (case-insensitive)
  for (const req of normalizedRequired) {
    if (studentFields.has(req)) {
      return {
        dimension: "major",
        status: "eligible",
        reason: `Opportunity requires ${requiredMajors.join("/")} and student field includes ${req}.`,
      };
    }
  }

  // Conservative: if no exact match, do NOT infer broader field equivalence
  // Example: student "AI" vs required "Computer Science" → unknown, not eligible
  // Only if required is broader and student has specific subfield, we still return unknown to avoid false eligibility
  return {
    dimension: "major",
    status: "unknown",
    reason: `Opportunity requires ${requiredMajors.join(", ")} and student fields are ${Array.from(studentFields).join(", ")} — cannot confidently determine match.`,
  };
}
