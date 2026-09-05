---
id: PROD-13
title: CI/CD
status: draft
---

# CI/CD

The pipeline is where every rule in this plan stops being a document and becomes
a build failure. **Ninety-nine checks run on every pull request**, and each one
exists because a specific rule would otherwise be observed only until the first
emergency.

---

## Principles

| # | Principle |
|---|---|
| CI-01 | **Only what has passed the pipeline reaches production** ([NC-13](../docs/01-principles/01-no-compromise.md#nc-13)). Manual deployment is technically impossible: only the CI service account holds permission to change an environment |
| CI-02 | **The pipeline ships everything**, not one component |
| CI-03 | **Tests cannot be disabled.** Test-skipping flags do not exist in the build configuration, and their absence is checked |
| CI-04 | **One artefact for all environments** ([ENV-20](12-environments.md#configuration)) |
| CI-05 | **Fast.** People bypass a slow pipeline, and a bypassed pipeline does not satisfy CI-01 |

CI-05 is not a comfort requirement. It is what makes CI-01 hold: every minute
above the budget increases the pressure to find a way around, and the way around
is always found eventually.

## Where the checks come from

The pipeline does not invent its checks. Each comes from a rule document, and
each is numbered there:

| Source | Checks | What they cover |
|---|---:|---|
| [03-database/checks.md](03-database/checks.md) | 20 | keys, types, names, constraints, indexes, migrations |
| [04-backend/checks.md](04-backend/checks.md) | 28 | module boundaries, layer dependencies, class rules, data access |
| [05-api/checks.md](05-api/checks.md) | 26 | paths, methods, lists, errors, types, permissions, compatibility |
| [06-frontend/checks.md](06-frontend/checks.md) | 25 | structure, page types, state, localization, accessibility, bundle |
| [09-quality.md](09-quality.md) | the NC rules | coverage, test time, N+1, forbidden constructs |
| **Total** | **99** | |

A check that cannot be traced to a rule is removed; a rule with no check is
either given one or downgraded to a preference, out loud
([NC-01](../docs/01-principles/01-no-compromise.md)).

## The pipeline

```
PR opened
   │
   ├─ build in a clean container, without an artefact cache    NC-08
   ├─ linters and formatting
   ├─ unit tests                                              QA-01
   ├─ integration tests (PostgreSQL in a container)           QA-02
   ├─ contract tests against the specification                API-25
   ├─ architecture-rule tests                                 BE-01…BE-28
   ├─ schema checks against a freshly migrated database       DB-01…DB-20
   ├─ API specification lint                                  API-01…API-26
   ├─ frontend checks, accessibility included                 FE-01…FE-25
   ├─ query-count tests (N+1)                                 BE-17
   ├─ coverage check (threshold + no drop)                    NC-01
   ├─ static analysis, security analysis included             SEC-54
   ├─ dependency vulnerability scanning                       NC-09
   ├─ API backward-compatibility check                        API-02
   ├─ allowed-library registry check                          NC-14
   ├─ registry alignment: schemas, modules, sections, pages   BE-27, BE-28
   ├─ forbidden constructs
   │    System.out / printStackTrace / console.log            NC-10
   │    IP addresses and host names                           NC-11
   │    SQL concatenation                                     NC-05
   │    field injection                                       NC-03
   │    secrets                                               SEC-30
   └─ class and method sizes                                  NC-04
   │
   ▼
merged into main
   │
   ├─ image build, SBOM generation                            SEC-53
   ├─ image signing                                           SEC-55
   ├─ deployment to dev
   ├─ smoke tests
   ├─ deployment to stage
   ├─ end-to-end tests                                        QA-05
   ├─ load run (on a schedule)                                PERF-21
   │
   ▼
deployment to prod (with a confirmation)
   ├─ schema migrations
   ├─ zero-downtime deployment                                NFR-34
   ├─ smoke tests
   └─ automatic rollback if the smoke tests fail
```

**Every stage in the list enforces a specific numbered rule.** This is not "best
practices in general" — it is
[NC-01 … NC-15](../docs/01-principles/01-no-compromise.md) plus the four rule
documents, in executable form.

## Time budget

| # | Stage | Budget |
|---|---|---|
| CI-10 | The PR checks | ≤ 15 min |
| CI-11 | From merge to dev | ≤ 10 min |
| CI-12 | From merge to stage | ≤ 30 min |
| CI-13 | Deployment to prod | ≤ 15 min |

Exceeding a budget is a prioritized work item, not a fact of life. The monorepo
([ADR-0007](../docs/02-decisions/ADR-0007-repo-layout.md)) requires building only
what a change touched, plus a working cache — otherwise CI-10 cannot be met once
the system is at full size, and CI-05 fails with it.

## Schema migrations in the pipeline

| # | Requirement |
|---|---|
| CI-20 | Applied automatically before the deployment |
| CI-21 | Exercised against a copy of production data **before the merge**, with the duration recorded |
| CI-22 | Compatible with the previous application version — otherwise zero-downtime deployment is impossible |
| CI-23 | A breaking change comes in four steps, each in a separate release: add → backfill → switch → drop ([rule 12](03-database/rules/12-migrations.md)) |
| CI-24 | A migration that locks a table for longer than the stated budget is rejected in review, not discovered in production |

CI-21 is the check that makes the cutover-window figure real
([NFR-51](07-nfr.md#cutover-window-constraints)): the duration of every migration
against production-sized data is known before it is merged, not measured on the
night.

## Branching and releases

| # | Requirement |
|---|---|
| CI-30 | Short-lived branches, pull requests, a protected `main` |
| CI-31 | Conventional Commits; the changelog is assembled automatically |
| CI-32 | One version per monorepo; a tag on the whole repository |
| CI-33 | The image is tagged with the version and the commit hash; an artefact is traceable back to its source |

## Specifics of the cutover period

Three additional pipelines, all of them ordinary pipelines in the repository:

| # | Pipeline | What it does |
|---|---|---|
| CI-40 | **Migration rehearsal** | stand up a clean environment, restore a copy of production data, run the migration, reconcile, publish the report. Triggered by a button and on a schedule |
| CI-41 | **Shadow run** | refresh the data copy, restart the comparison, publish the divergence figures |
| CI-42 | **Rollback** | rehearsed and timed against [NFR-52](07-nfr.md#cutover-window-constraints) |

**A procedure carried out by hand at three in the morning is carried out with
mistakes.** That is the whole reason these are pipelines rather than instruction
sheets — and the reason CI-42 is rehearsed rather than documented: a rollback
path that has never been executed is a hope.

## Open questions

| # | Question | Affects |
|---|---|---|
| CI-Q1 | Who may approve a production deployment, and is a second approver required when a migration is included? | the confirmation step, [ENV-Q4](12-environments.md#open-questions) |
| CI-Q2 | Is a production-sized data copy available to the pipeline for CI-21? | whether migration durations are known before merge |
| CI-Q3 | What is the release cadence after the cutover? | CI-30 … CI-33, and the stabilization plan |
