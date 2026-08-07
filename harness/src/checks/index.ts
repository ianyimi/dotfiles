import type { DoctorCheck } from "../commands/doctor.ts";
import agentsMdDirectivesOverBudget from "./agentsMdDirectivesOverBudget.ts";
import antiPatternsOverBudget from "./antiPatternsOverBudget.ts";
import decisionsInconsistent from "./decisionsInconsistent.ts";
import indexStale from "./indexStale.ts";
import namingViolations from "./namingViolations.ts";
import openSpecsStale from "./openSpecsStale.ts";
import preferencesOverBudget from "./preferencesOverBudget.ts";
import skillOverBudget from "./skillOverBudget.ts";
import staleCommands from "./staleCommands.ts";
import stalePackages from "./stalePackages.ts";
import structureStale from "./structureStale.ts";

/**
 * The static doctor check registry (master §8: no dynamic discovery — determinism).
 * Later phase specs append their checks here.
 */
export const CHECKS: DoctorCheck[] = [
  preferencesOverBudget,
  antiPatternsOverBudget,
  skillOverBudget,
  agentsMdDirectivesOverBudget,
  staleCommands,
  stalePackages,
  openSpecsStale,
  decisionsInconsistent,
  namingViolations,
  structureStale,
  indexStale,
];
