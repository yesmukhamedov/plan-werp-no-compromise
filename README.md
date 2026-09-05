# plan-werp-no-compromise

A project plan for the complete rewrite of WERP — an in-house ERP system
(backend, frontend, integrations, database).

**This is not code. This is the plan itself, run as a project:** with decisions
(ADRs), specifications, mappings, phases, epics, a risk register and CI that
validates the plan's integrity. Implementation does not start until the plan is
closed — see [gates](transition/plan/00-roadmap.md#gates).

---

## Two parts

The repository is split into **product** and **transition** — and that is the
main property of its structure.

```
                                      ┌──────────────────────────┐
   docs/         shared foundation    │  product/  WHAT WILL BE  │
   ├ context     facts about legacy   │  tables, columns,        │
   ├ principles  rules                │  indexes, classes,       │
   └ decisions   ADRs                 │  endpoints, pages,       │
        │                             │  components              │
        │                             └────────────▲─────────────┘
        │                                          │ references
        │                             ┌────────────┴─────────────┐
        └────────────────────────────►│ transition/ HOW WE MOVE  │
                                      │  which table changes     │
                                      │  how, which class is     │
                                      │  replaced by what, which │
                                      │  page by which           │
                                      └──────────────────────────┘
```

| | [product/](product/README.md) | [transition/](transition/README.md) |
|---|---|---|
| **Answers the question** | what will be built | what turns into what |
| **Contains** | tables with columns and indexes, modules and classes, endpoints, pages and components | mappings, data migration, cutover, rollback, phases, risks |
| **Mentions legacy** | no, never | constantly — that is its subject |
| **Fate after the project** | becomes the system's documentation | archived |

Test for placing a document correctly: **if you remove every mention of legacy
from it and it still makes sense — it belongs to the product.**

The split exists because a document that simultaneously describes the target
system and explains the origin of each of its parts is unreadable both for the
developer (who needs only the result) and for the transition planner (who needs
the mappings).

### Paired documents

Four slices of the system are described in pairs — a specification in the
product, a map in the transition:

| Slice | What will be | Where it comes from |
|---|---|---|
| Database | [the database model](product/03-database/README.md) | [transition/01-database-mapping.md](transition/01-database-mapping.md) |
| Backend | [04-backend/](product/04-backend/README.md) | [transition/02-backend-mapping.md](transition/02-backend-mapping.md) |
| API | [05-api/](product/05-api/README.md) | [transition/03-api-mapping.md](transition/03-api-mapping.md) |
| Frontend | [06-frontend/](product/06-frontend/README.md) | [transition/04-frontend-mapping.md](transition/04-frontend-mapping.md) |

Deeper — per domain: [product/spec/](product/spec/README.md) and
[transition/map/](transition/map/README.md), in pairs. The reference sample of
the required depth is domain D1 "Reference data":
[specification](product/spec/D1-reference.md) and
[map](transition/map/D1-reference.md).

---

## Why

WERP has been growing for ~12 years in layers. Today it is:

- **three backend generations in production at once** — a JSF monolith from
  2013, Spring Boot 2.0 (released 2018) and two separate services on Spring
  Boot 2.4;
- **~1M lines** of application code in total (Java + JS), of which **4 test
  files** across the entire main backend;
- **two databases at once** — Oracle in the monolith, PostgreSQL in the new
  services;
- functionality implemented through workarounds: god classes of 3,000–7,000
  lines, controllers with 38–51 field injections, duplicated domains (CRM
  written twice), a frontend that for some screens still links back to the
  legacy JSF.

The full picture with numbers — [docs/00-context/01-inventory.md](docs/00-context/01-inventory.md)
and [docs/00-context/02-pain-points.md](docs/00-context/02-pain-points.md).

"No compromise" is not a slogan but a
[set of verifiable rules](docs/01-principles/01-no-compromise.md), each of which
forbids one specific compromise already made in the current system.

---

## Top-level decisions taken

| # | Decision | Status | ADR |
|---|---|---|---|
| 1 | Transition strategy — **big bang** (parallel development, a single cutover) | Accepted | [ADR-0001](docs/02-decisions/ADR-0001-strategy-big-bang.md) |
| 2 | DBMS — **PostgreSQL**, moving off Oracle | Accepted | [ADR-0002](docs/02-decisions/ADR-0002-database-postgresql.md) |
| 3 | Backend stack | **Deferred** — to be closed before Phase 1 starts | [ADR-0003](docs/02-decisions/ADR-0003-backend-stack.md) |
| 4 | Frontend stack | Proposed | [ADR-0004](docs/02-decisions/ADR-0004-frontend-stack.md) |
| 5 | Contract-first API | Proposed | [ADR-0005](docs/02-decisions/ADR-0005-contract-first-api.md) |

The full index — [docs/02-decisions/README.md](docs/02-decisions/README.md).

> **The backend stack is deliberately left unfixed.** The whole plan is written
> stack-neutrally; the places where the decision genuinely changes something are
> tagged with the `[STACK]` marker and listed in
> [ADR-0003](docs/02-decisions/ADR-0003-backend-stack.md#what-in-the-plan-depends-on-this-decision).
> The data schema, the API contract and the set of pages do not depend on the
> stack and are being designed already.

---

## Structure

```
docs/                    SHARED FOUNDATION — the basis of both parts
  00-context/            legacy inventory, pain points, constraints, integrations
  01-principles/         15 "no compromise" rules, DoD, standards
  02-decisions/          ADRs — one file per decision, deferred ones included

product/                 WHAT WILL BE
  01-architecture.md     layers, modules, platform
  02-domains.md          domain map and dependency graph
  03-database/           rules/ · schemas/ · checks — 14 schemas, 204 tables
  04-backend/            rules/ · modules/ · checks — 24 modules, ~1,300 classes
  05-api/                rules/ · registry · checks — 14 sections, ~550 endpoints
  06-frontend/           rules/ · design system · registry · checks — ~170 pages
  07…14                  NFRs, security, tests, performance, observability,
                         environments, CI/CD, runbooks — numbered requirements
  spec/                  full specifications per domain

transition/              HOW WE MOVE
  01…04                  mappings: data, backend, API, frontend
  05…09                  data migration, parity, cutover, rollback, freeze
  10…12                  estimates, risks, open questions
  plan/                  roadmap and six phases
  map/                   full mappings per domain

backlog/                 11 Phase 0 epics with tasks and acceptance criteria
templates/               ADR / epic / task templates
tools/                   validate.sh, measure.sh
.github/workflows/       CI: plan validation on every PR
```

## How to read this

| Who you are | Route |
|---|---|
| New to the project | [context](docs/00-context/01-inventory.md) → [pain points](docs/00-context/02-pain-points.md) → [roadmap](transition/plan/00-roadmap.md) |
| Deciding on the project | [estimates](transition/10-estimates.md) → [risks](transition/11-risks.md) → [ADR-0001](docs/02-decisions/ADR-0001-strategy-big-bang.md) |
| Going to build it | all of [product/](product/README.md) |
| Going to migrate it | all of [transition/](transition/README.md) |
| Looking for a depth sample | [product/spec/D1-reference.md](product/spec/D1-reference.md) + [transition/map/D1-reference.md](transition/map/D1-reference.md) |

## How to maintain it

The plan is a living document and changes only through PRs:
[CONTRIBUTING.md](CONTRIBUTING.md). CI (`tools/validate.sh`) checks on every PR
that identifiers are unique, that the required frontmatter fields are present,
that there are no broken internal links, that the product/transition split holds
and that no sensitive data is present.

```sh
./tools/validate.sh
```

## Sensitive data

The repository is **public**. It must not contain internal addresses and hosts,
database or account names, secrets, legacy source code, production data dumps or
personal data. Placeholders and aggregated metrics are used instead. The check is
automated; the rules are in
[CONTRIBUTING.md](CONTRIBUTING.md#sensitive-data).

## Status

| | |
|---|---|
| Phase | Phase 0 — Foundation |
| Gate | G0 not passed |
| Domains designed | 1 of 13 (D1 — the sample) |
| Open blocking questions | see [transition/12-open-questions.md](transition/12-open-questions.md) |
