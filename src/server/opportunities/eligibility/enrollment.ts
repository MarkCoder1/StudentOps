import type { Opportunity } from "../models/opportunity";
import type { StudentProfileForEligibility, EligibilityCheck } from "./types";

type NormalizedLevel = "middle_school" | "high_school" | "undergraduate" | "graduate";

const LEVEL_SYNONYMS: Record<string, NormalizedLevel> = {
  "middle school": "middle_school",
  "middle_school": "middle_school",
  middleschool: "middle_school",
  "high school": "high_school",
  high_school: "high_school",
  highschool: "high_school",
  undergraduate: "undergraduate",
  undergrad: "undergraduate",
  college: "undergraduate",
  university: "undergraduate",
  graduate: "graduate",
  grad: "graduate",
};

function normalizeLevels(levels: string[] | null | undefined): Set<NormalizedLevel> | null {
  if (!levels || levels.length === 0) return null;
  const set = new Set<NormalizedLevel>();
  for (const raw of levels) {
    const lower = raw.trim().toLowerCase();
    const norm = LEVEL_SYNONYMS[lower];
    if (norm) set.add(norm);
    // Unknown levels are ignored (conservative — treat as unknown, not as mismatch)
  }
  return set.size ? set : null;
}

function studentLevels(profile: StudentProfileForEligibility): Set<NormalizedLevel> {
  const set = new Set<NormalizedLevel>();
  const school = profile.schoolLevel?.trim().toLowerCase() ?? "";
  const grade = profile.grade?.trim().toLowerCase() ?? "";

  if (LEVEL_SYNONYMS[school]) set.add(LEVEL_SYNONYMS[school]);

  // Grade mapping: 6th-8th => middle, 9th-12th => high
  if (grade.includes("6th") || grade.includes("7th") || grade.includes("8th")) set.add("middle_school");
  if (grade.includes("9th") || grade.includes("10th") || grade.includes("11th") || grade.includes("12th")) set.add("high_school");

  // Also handle numeric grades
  const num = parseInt(grade, 10);
  if (!isNaN(num)) {
    if (num >= 6 && num <= 8) set.add("middle_school");
    if (num >= 9 && num <= 12) set.add("high_school");
  }

  // College plan hints undergrad, but not used to infer enrollment directly
  return set;
}

export function evaluateEnrollment(
  opportunity: Opportunity,
  student: StudentProfileForEligibility
): EligibilityCheck {
  const required = normalizeLevels(opportunity.eligibility.enrollmentLevels);
  if (!required) {
    return {
      dimension: "enrollment",
      status: "unknown",
      reason: "Enrollment requirement is not specified by the source.",
    };
  }

  const studentSet = studentLevels(student);
  if (studentSet.size === 0) {
    return {
      dimension: "enrollment",
      status: "unknown",
      reason: "Student enrollment level is not available; cannot evaluate enrollment requirement.",
    };
  }

  // Check for intersection
  for (const lvl of studentSet) {
    if (required.has(lvl)) {
      return {
        dimension: "enrollment",
        status: "eligible",
        reason: `Opportunity requires ${Array.from(required).join("/")} and student is ${Array.from(studentSet).join("/")} .`,
      };
    }
  }

  // No overlap → check if clearly mismatch: e.g., student middle_school, required undergraduate only
  // If student is middle/high and required is undergraduate/graduate → ineligible
  // Conservative: if required contains only undergraduate/graduate and student is middle/high → ineligible
  const hasOverlap = [...studentSet].some((s) => required.has(s));
  if (!hasOverlap) {
    // If required is undergraduate/graduate and student is middle/high, it's a clear mismatch
    const studentIsK12 = studentSet.has("middle_school") || studentSet.has("high_school");
    const requiredIsCollege = required.has("undergraduate") || required.has("graduate");
    if (studentIsK12 && requiredIsCollege) {
      return {
        dimension: "enrollment",
        status: "ineligible",
        reason: `Opportunity requires ${Array.from(required).join("/")} and student is ${Array.from(studentSet).join("/")} .`,
      };
    }
    // If student is college and required is K12, also ineligible
    const studentIsCollege = studentSet.has("undergraduate") || studentSet.has("graduate");
    const requiredIsK12 = required.has("middle_school") || required.has("high_school");
    if (studentIsCollege && requiredIsK12) {
      return {
        dimension: "enrollment",
        status: "ineligible",
        reason: `Opportunity requires ${Array.from(required).join("/")} and student is ${Array.from(studentSet).join("/")} .`,
      };
    }
    // Otherwise ambiguous
    return {
      dimension: "enrollment",
      status: "unknown",
      reason: `Enrollment requirement "${Array.from(required).join(", ")}" cannot be confidently evaluated for student levels ${Array.from(studentSet).join(", ")}.`,
    };
  }

  return {
    dimension: "enrollment",
    status: "unknown",
    reason: "Enrollment requirement cannot be evaluated.",
  };
}
