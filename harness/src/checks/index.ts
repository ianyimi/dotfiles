import type { DoctorCheck } from "../commands/doctor.ts";
import agentsMdDirectivesOverBudget from "./agentsMdDirectivesOverBudget.ts";
import antiPatternsOverBudget from "./antiPatternsOverBudget.ts";
import contextCoverage from "./contextCoverage.ts";
import contextRulesStale from "./contextRulesStale.ts";
import decisionsInconsistent from "./decisionsInconsistent.ts";
import envVarsUndocumented from "./envVarsUndocumented.ts";
import indexStale from "./indexStale.ts";
import shimsStale from "./shimsStale.ts";
import staleDependencies from "./staleDependencies.ts";
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
  envVarsUndocumented,
  shimsStale,
  contextRulesStale,
  staleDependencies,
  contextCoverage,
];
