import type { Opportunity } from "../models/opportunity";
import type { StudentProfileForEligibility, EligibilityCheck } from "./types";
import { calculateAge } from "./types";

export function evaluateAge(
  opportunity: Opportunity,
  student: StudentProfileForEligibility,
  asOf: Date = new Date()
): EligibilityCheck {
  const minAge = opportunity.eligibility.minAge;
  const maxAge = opportunity.eligibility.maxAge;

  // No age limits → unknown
  if (minAge === null && maxAge === null) {
    return {
      dimension: "age",
      status: "unknown",
      reason: "Age requirement is not specified by the source.",
    };
  }

  // Resolve student age — support number or numeric string from Swift profile
  let studentAge: number | null = null;
  if (typeof student.age === "number" && !isNaN(student.age)) {
    studentAge = student.age;
  } else if (typeof student.age === "string" && (student.age as string).trim() !== "") {
    const parsed = parseInt(student.age as string, 10);
    if (!isNaN(parsed)) studentAge = parsed;
  } else if (student.dateOfBirth) {
    studentAge = calculateAge(student.dateOfBirth, asOf);
  }

  // If no DOB/age, cannot evaluate
  if (studentAge === null) {
    return {
      dimension: "age",
      status: "unknown",
      reason: "Student age is not available; cannot evaluate age requirement.",
    };
  }

  // Check minAge
  if (minAge !== null && studentAge < minAge) {
    return {
      dimension: "age",
      status: "ineligible",
      reason: `Student is ${studentAge} and the opportunity requires ages ${minAge}–${maxAge ?? "∞"}.`,
    };
  }

  // Check maxAge
  if (maxAge !== null && studentAge > maxAge) {
    return {
      dimension: "age",
      status: "ineligible",
      reason: `Student is ${studentAge} and the opportunity requires ages ${minAge ?? "0"}–${maxAge}.`,
    };
  }

  // If we are here, passed all present constraints
  if (minAge !== null && maxAge !== null) {
    return {
      dimension: "age",
      status: "eligible",
      reason: `Student is ${studentAge} and meets the age requirement ${minAge}–${maxAge}.`,
    };
  }
  if (minAge !== null) {
    return {
      dimension: "age",
      status: "eligible",
      reason: `Student is ${studentAge} and meets the minimum age ${minAge}.`,
    };
  }
  // maxAge only
  return {
    dimension: "age",
    status: "eligible",
    reason: `Student is ${studentAge} and is within the maximum age ${maxAge}.`,
  };
}
