---
id: PROD-09
title: Testing strategy
status: draft
---

# Testing strategy

How [NC-01](../docs/01-principles/01-no-compromise.md#nc-01) is enforced:
functionality without a test does not exist, and that is checked **by machine
rather than by discipline**.

Why the rule is worded so strictly —
[P-01](../docs/00-context/02-pain-points.md#p-01-practically-no-tests).

Each requirement carries an identifier so that a definition of done, a release
decision or a domain review can cite it.

---

## Levels

| # | Level | What it verifies | Where it runs | Share |
|---|---|---|---|---|
| QA-01 | Unit | domain rules, calculations, invariants | without a database or HTTP | the bulk |
| QA-02 | Integration | a domain plus a real PostgreSQL in a container | a container | many |
| QA-03 | Contract | the implementation's conformance to the API specification | a container | per endpoint |
| QA-04 | Architecture | domain boundaries, dependency rules, naming | statically | few, but mandatory |
| QA-05 | End-to-end | scenarios from the registry, across the whole system | pre-production | per scenario |
| QA-06 | Characterization | behavioural reference values for the transition reconciliation | separately | Phase 0 |
| QA-07 | Load | the figures in [07-nfr.md](07-nfr.md) | pre-production | weekly |
| QA-08 | Migration | correctness of the data transfer | against a copy of the data | every rehearsal |
| QA-09 | Accessibility | contrast, focus, labels, keyboard operation | on every screen | per page |

QA-04 is the level that most projects skip and this one cannot: the entire
modular-monolith decision
([ADR-0008](../docs/02-decisions/ADR-0008-modular-monolith.md)) rests on
boundaries being enforced by a test rather than by review. The complete list of
those assertions is [04-backend/checks.md](04-backend/checks.md).

## The checks that enforce the fifteen rules

The rules [NC-01 … NC-15](../docs/01-principles/01-no-compromise.md) are enforced
by machine, not by a reviewer. Every line is a check in CI:

| Rule | Check | Result of a violation |
|---|---|---|
| NC-01 | the branch coverage threshold; a grep for test-disabling flags in the build configuration | the PR is not merged |
| NC-02 | the architecture-rule test `[STACK]` — [BE-01 … BE-04](04-backend/checks.md) | the PR is not merged |
| NC-03 | static analysis: zero field injections — [BE-08](04-backend/checks.md) | the PR is not merged |
| NC-04 | the linter: class length, method length, dependency count — [BE-07](04-backend/checks.md) | the PR is not merged |
| NC-05 | a grep for forbidden data-access mechanisms and SQL concatenation — [BE-13](04-backend/checks.md), [BE-14](04-backend/checks.md) | the PR is not merged |
| NC-08 | a build in a clean container with no cache | the build fails |
| NC-09 | the dependency vulnerability scanner | critical findings block |
| NC-10 | a grep for `System.out`, `printStackTrace`, `console.log`; a check for `show-sql` in the profiles | the PR is not merged |
| NC-11 | a grep for IP addresses and host names in the sources and in the built bundle — [FE-23](06-frontend/checks.md) | the PR is not merged |
| NC-12 | every endpoint declares its permission — [API-18](05-api/checks.md) | the PR is not merged |
| NC-14 | the registry of allowed libraries — [FE-19](06-frontend/checks.md) | the PR is not merged |
| NC-15 | a check for forbidden extensions and file sizes | the PR is not merged |

**This is precisely the mechanism that separates "no compromise" from an
intention.** A rule that is not checked by machine is observed exactly until the
first emergency.

The document-specific checks live with their documents —
[03-database/checks.md](03-database/checks.md) (20),
[04-backend/checks.md](04-backend/checks.md) (28),
[05-api/checks.md](05-api/checks.md) (26),
[06-frontend/checks.md](06-frontend/checks.md) (25) — **99 checks in total**, and
the pipeline that runs them is [13-cicd.md](13-cicd.md).

## Characterization tests

A special type that exists only in this project. They are written in Phase 0
([EPIC-004](../backlog/EPIC-004-characterization-tests.md)) **against the old
system**.

They do not verify correctness — they record a fact: "given this input, the old
system produces this result", including the cases where the result is wrong.

| # | Requirement |
|---|---|
| QA-10 | Characterization tests are written before the corresponding domain is implemented, not after |
| QA-11 | A recorded result is not "fixed" when it looks wrong; the divergence is raised with the domain owner and decided explicitly |
| QA-12 | Priority order: compensation calculation, accounting operations, contract calculations, warehouse balances |

Their purpose:

- a reference for the parity reconciliation
  ([transition/06-parity-verification.md](../transition/06-parity-verification.md));
- protection against "but we thought that is how it works";
- the only way to verify calculations that a shadow run cannot verify — write
  operations and multi-step processes.

QA-11 is the one that gets argued about. A characterization test that has been
quietly corrected to match the new system's output verifies nothing.

## Scenario registry

Assembled in Phase 0 ([EPIC-011](../backlog/EPIC-011-scenario-registry.md)) and
serving four purposes at once:

- the definition of the new system's completeness;
- the plan for the end-to-end tests;
- the plan for manual acceptance;
- the basis of scenario parity
  ([transition/06-parity-verification.md](../transition/06-parity-verification.md#level-3-scenario-parity)).

| # | Requirement |
|---|---|
| QA-20 | A scenario states: who, doing what, from which state, with which result, and how to verify it |
| QA-21 | One scenario is one verifiable piece of business value |
| QA-22 | Every page in the [page registry](06-frontend/registry.md) names the scenarios it serves |
| QA-23 | A scenario with no end-to-end test is a gap tracked in the backlog, not an accepted state |

## Test data

| # | Requirement |
|---|---|
| QA-30 | One way of preparing data across the whole system |
| QA-31 | The data for a test is created by the test, never taken from a shared pre-populated database |
| QA-32 | Copies of production data for pre-production are **anonymized** ([SEC-34](08-security.md#data)) |
| QA-33 | Reference sets for financial calculations are versioned together with the code |
| QA-34 | No test depends on a specific production identifier ([14.10](03-database/rules/14-patterns.md#1410-behaviour-reads-a-property-never-an-identifier)) |

QA-31 is the one that decides whether the suite stays trustworthy. A shared
pre-populated database makes tests depend on each other, and a suite whose
failures depend on execution order is a suite people learn to re-run rather than
read.

QA-34 is only achievable because the schema was designed for it: behaviour keys
on a property (`branch.kind = 'HEAD'`), never on an identifier, so a test fixture
does not have to reproduce specific rows.

## The N+1 problem

| # | Requirement |
|---|---|
| QA-40 | An integration test counts database queries per endpoint and fails when the expected number is exceeded — [BE-17](04-backend/checks.md) |
| QA-41 | No lazy association crosses an aggregate boundary — [BE-16](04-backend/checks.md) |

In a system with hundreds of entities and lazy loading this is the only way not
to discover the problem in production
([01-principles/03-engineering-standards.md](../docs/01-principles/03-engineering-standards.md#performance)).

The friction is real: the asserted number has to be updated whenever a query
legitimately changes. That friction is the point — it makes an accidental extra
query visible at review time.

## Run time

A tracked metric. Slow tests stop being run, and tests that are not run are
equivalent to tests that do not exist.

| # | Suite | Budget |
|---|---|---|
| QA-50 | Unit | seconds |
| QA-51 | Integration | minutes |
| QA-52 | The full run on a PR | ≤ 15 min |
| QA-53 | End-to-end | outside PRs — on a schedule and before a release |

Exceeding a budget is a work item, not a fact of life.

## Coverage

| # | Requirement |
|---|---|
| QA-60 | Branch coverage of the domain layer: 80%, checked in CI |
| QA-61 | A drop in coverage between PRs is grounds for refusing the merge |
| QA-62 | Coverage is not measured over generated code |
| QA-63 | Coverage is a necessary but not a sufficient condition |

QA-63 is not a loophole. It is the reason coverage is paired with QA-04, QA-40
and the contract tests: 100% coverage with meaningless assertions is worse than
70% with meaningful ones, because it produces confidence that is not earned.

## Open questions

| # | Question | Affects |
|---|---|---|
| QA-Q1 | Is 80% the right domain-layer threshold, or should it differ for D5 and D6? | QA-60, and the effort in the two money domains |
| QA-Q2 | Who signs off manual acceptance per domain, and against which scenarios? | QA-20 … QA-23, and gate G2 |
| QA-Q3 | How long are characterization tests kept after the cutover? | [Phase 5](../transition/plan/06-phase-5-decommission.md) |
