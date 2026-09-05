---
id: ADR-0003
title: Backend stack
status: Deferred
date: 2026-09-03
deadline: gate G1 (end of Phase 0)
---

# ADR-0003. Backend stack

## Status: Deferred

The decision is **deliberately not being taken now** and must be taken before
gate **G1** — that is, before Phase 1 begins. Deferring it does not block the
start: all of Phase 0 is stack-independent.

Deferring is not "we did not think about it". It records that the decision will
be taken on the basis of data that does not exist today: the results of the
contract inventory ([EPIC-002](../../backlog/EPIC-002-contract-inventory.md)),
the database schema inventory
([EPIC-003](../../backlog/EPIC-003-schema-inventory.md)) and a confirmed team
composition ([OQ-001](../../transition/12-open-questions.md)).

## What the decision must deliver

Whichever stack is chosen, it must make the following possible:

| # | Requirement | Source |
|---|---|---|
| 1 | Modularity with machine-checkable domain boundaries | NC-02 |
| 2 | Constructor dependency injection | NC-03 |
| 3 | **One** data-access mechanism covering both simple CRUD and complex reporting queries | NC-05 |
| 4 | Type-safe queries against PostgreSQL without SQL concatenation | NC-05, [ADR-0002](ADR-0002-database-postgresql.md) |
| 5 | Transactions with explicit boundaries and a controllable isolation level | [C-09](../00-context/03-constraints.md#c-09-financial-calculations-require-exact-arithmetic) |
| 6 | Fixed-precision decimal arithmetic as a first-class type | C-09 |
| 7 | Code generation from the API specification (contract-first) | [ADR-0005](ADR-0005-contract-first-api.md) |
| 8 | Declarative authorization at the endpoint level | NC-12 |
| 9 | Structured logs, metrics, distributed tracing | NC-10 |
| 10 | Testing against a real PostgreSQL in a container, with a fast run | NC-01 |
| 11 | Auditing of entity changes | [C-10](../00-context/03-constraints.md#c-10-change-audit-already-exists-and-must-be-preserved) |
| 12 | Producing Excel and PDF | [ADR-0009](ADR-0009-reporting-and-exports.md) |
| 13 | Multilingual messages, validation errors included | [ADR-0010](ADR-0010-i18n.md) |
| 14 | A build on a clean machine with one command, a dependency lock file | NC-08 |
| 15 | Specialists available on the market and hireable | practice |

Requirement 3 combined with 4 is the most constraining. In a system with 62k
lines of accounting domain and hundreds of reports, "one data-access mechanism"
has to work equally well for an edit form and for a summary report over tens of
millions of rows.

## Candidates

The matrix is filled in during Phase 0. The "score" column is the result of
[TASK-0301](../../backlog/EPIC-003-schema-inventory.md), not an opinion.

| Candidate | Strengths | Weaknesses | Score |
|---|---|---|---|
| Java (LTS) + Spring Boot 3.x | The team knows Spring; maximum portability of logic from the current 355k lines; off-the-shelf answers to all 15 requirements; a deep hiring market | The same framework as the current system — a risk of reproducing the habits along with the code; runtime weight | — |
| Kotlin + Spring Boot 3.x | The same, plus null safety and less boilerplate | A mixed Java/Kotlin period; retraining the team | — |
| Go | Experience already proven in this project: `bridge` is written and running; predictable resource consumption; fast start-up; explicitness | The ORM layer for 523 entities is rewritten by hand; reporting queries and the ERP's transactional logic are written from scratch; substantially more work | — |
| Hybrid: Go at the edge + JVM in the domain | The right tool for each layer | Two ecosystems in operation; double the platform and hiring cost | — |

## Selection criteria

The decision is taken on the sum of weighted criteria. The weights are approved
together with the decision; provisionally:

| Criterion | Weight | Why |
|---|---:|---|
| Portability of the existing domain logic | 30% | 355k lines are the project's main cost |
| Compliance with requirements 1–15 | 25% | without it the stack is unusable |
| Competence and hiring | 20% | the project outlasts the team roster |
| Cost of operation | 15% | resources, licences, observability |
| Development speed | 10% | important but not decisive under a big bang |

**A separate rule:** "fashionable" and "interesting" are not criteria. The
project is rewriting an ERP that has been running for 12 years; the chosen stack
must live a comparable span.

## What in the plan depends on this decision

Every place marked with the `[STACK]` marker. The full list:

| Where | What exactly depends on it |
|---|---|
| [01-principles/03-engineering-standards.md](../01-principles/03-engineering-standards.md) | the specific linters, formatters, architecture-rule checking tool |
| [product/01-architecture.md](../../product/01-architecture.md) | the module isolation mechanism, the way modules interact internally |
| [product/03-database/](../../product/03-database/README.md) | the data-access mechanism, the migration tool, the audit mechanism |
| [product/09-quality.md](../../product/09-quality.md) | the testing framework, the container tooling for integration tests |
| [product/11-observability.md](../../product/11-observability.md) | the logging library and the metrics exporter |
| [product/13-cicd.md](../../product/13-cicd.md) | the build steps, the dependency cache, the base image |
| [transition/plan/02-phase-1-platform.md](../../transition/plan/02-phase-1-platform.md) | the whole phase: the platform is built on the chosen stack |
| [transition/10-estimates.md](../../transition/10-estimates.md) | the effort coefficient for migrating a domain |

**Nothing beyond the above.** If it turns out during the work that something else
depends on the stack, it is added to the table rather than decided silently.

## Consequences of deferring

- Phase 0 is executed in full and without restrictions — it is about contracts,
  data, requirements and organization, not about technology.
- Phase 1 **cannot start** until the decision is taken. This is a hard gate.
- The estimates in
  [transition/10-estimates.md](../../transition/10-estimates.md) are given as a
  range that will collapse to a point once the stack is chosen.
- If the decision is not taken by gate G1, the project stops. That is a
  deliberate mechanism: it prevents starting development "while we think", in
  parallel with a fundamental unresolved question.

## Next steps

1. Wait for the results of
   [EPIC-002](../../backlog/EPIC-002-contract-inventory.md) and
   [EPIC-003](../../backlog/EPIC-003-schema-inventory.md).
2. Build a prototype on the two leading candidates: one non-trivial domain — the
   proposal is contract-based calculation as the most telling one (monetary
   arithmetic, several tables, a report, access permissions).
3. Fill in the matrix, weigh it, take the decision, move the ADR to "Accepted".
4. Update every place carrying the `[STACK]` marker.
