---
id: PROD
title: Product — what will be built
status: draft
---

# Product

**Only the result is described here.** What the new WERP will be: which tables
with which columns and indexes, which modules and classes, which endpoints,
which pages and components.

This section contains **not a word about how we get there** — nothing about
legacy, nothing about migration, nothing about phases. The link between what
exists and what is targeted lives in
[transition/](../transition/README.md).

The split is deliberate: a document that simultaneously describes the target
system and explains where each of its parts came from is impossible to read
either for a developer (who needs only the result) or for whoever plans the
transition (who needs the mappings). A year after the cutover all of
`transition/` is archived, while `product/` remains the system's documentation.

---

## Reading route

| Who | What to read |
|---|---|
| Backend developer | [01](01-architecture.md) → [02](02-domains.md) → [04](04-backend/README.md) → [03](03-database/README.md) → [05](05-api/README.md) |
| Frontend developer | [01](01-architecture.md) → [06](06-frontend/README.md) → [05](05-api/README.md) |
| Data designer | [03](03-database/README.md) → [spec/](spec/README.md) |
| Operations | [12](12-environments.md) → [13](13-cicd.md) → [14](14-runbooks.md) → [11](11-observability.md) |
| Security | [08](08-security.md) → [05](05-api/rules/07-permissions.md) |

## Contents

### Architecture

| Document | About |
|---|---|
| [01-architecture.md](01-architecture.md) | layers, modules, platform, deployment |
| [02-domains.md](02-domains.md) | the domain map, the dependency graph, boundary rules |

### System artefacts

Four documents answering the question "what exactly will be built". Each consists
of **rules** (how an artefact of this type is put together) and a **registry**
(the list of all artefacts with their state).

| Document | Answers the question | Rules | Registry | Checks |
|---|---|---|---|---|
| [03-database/](03-database/README.md) | which tables, columns, types, indexes | [14](03-database/rules/README.md) | [14 schemas, 204 tables](03-database/schemas/README.md) | [20](03-database/checks.md) |
| [04-backend/](04-backend/README.md) | which modules and classes | [8](04-backend/rules/README.md) | [24 modules, ~1,300 classes](04-backend/modules/README.md) | [28](04-backend/checks.md) |
| [05-api/](05-api/README.md) | which endpoints | [9](05-api/rules/README.md) | [14 sections, ~550 endpoints](05-api/registry.md) | [26](05-api/checks.md) |
| [06-frontend/](06-frontend/README.md) | which pages and components | [6](06-frontend/rules/README.md) + [the design system](06-frontend/design-system.md) | [14 sections, ~170 pages](06-frontend/registry.md) | [25](06-frontend/checks.md) |

**The four registries describe the same thirteen domains from four sides**, and a
name that differs between them is a build failure
([BE-28](04-backend/checks.md)). The 99 checks are what the pipeline runs
([13-cicd.md](13-cicd.md)).

### Full specifications

[spec/](spec/README.md) — one file per domain, where all four slices (tables,
classes, endpoints, pages) are brought together and taken to the level of "code
can be written".

Filled in during Phase 0 and Phase 1. The depth reference is
[spec/D1-reference.md](spec/D1-reference.md).

### Requirements and operations

| Document | About |
|---|---|
| [07-nfr.md](07-nfr.md) | performance, load, availability |
| [08-security.md](08-security.md) | security |
| [09-quality.md](09-quality.md) | the testing strategy |
| [10-performance.md](10-performance.md) | how performance is achieved and verified |
| [11-observability.md](11-observability.md) | logs, metrics, tracing |
| [12-environments.md](12-environments.md) | environments and configuration |
| [13-cicd.md](13-cicd.md) | the build and deployment pipeline |
| [14-runbooks.md](14-runbooks.md) | operations runbooks |

## Rules of this section

1. **The result only.** Phrasings like "today this works one way but will work
   another" are forbidden here — they belong to
   [transition/](../transition/README.md). A reader of `product/` is not obliged
   to know that a previous system ever existed.

2. **Concreteness.** "A contracts table with the necessary fields" is not a
   specification. A specification is a list of columns with types, constraints
   and indexes.

3. **Maturity levels.** Every artefact in a registry has a status:

   | Status | Meaning |
   |---|---|
   | `designed` | the specification is complete, code can be written |
   | `outlined` | the composition is known, the details are not worked out |
   | `declared` | it is known that the artefact is needed, nothing more |

   Implementation of an artefact does not begin until it is `designed`.

4. **Stack neutrality.** The backend stack decision is deferred
   ([ADR-0003](../docs/02-decisions/ADR-0003-backend-stack.md)). Places that
   depend on it are marked `[STACK]` and are refined after gate G1. The data
   schema, the API contract and the set of pages do not depend on the stack and
   are being designed already.

5. **Source of truth.** In case of a discrepancy between this section and any
   other document, `product/` wins: it describes what is being built.

## What is not filled in here yet

The registries contain rows with the status `declared` — that is an honest
statement of today's state, not an omission: populating the registries is
precisely the work of Phase 0
([EPIC-002](../backlog/EPIC-002-contract-inventory.md),
[EPIC-003](../backlog/EPIC-003-schema-inventory.md),
[EPIC-007](../backlog/EPIC-007-reports-inventory.md),
[EPIC-011](../backlog/EPIC-011-scenario-registry.md)).

The format and the depth are fixed in full — on the example of domain D1
([spec/D1-reference.md](spec/D1-reference.md)). The other domains are filled in
following that model.
