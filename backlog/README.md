---
id: BACKLOG
title: Backlog
status: actual
---

# Backlog

The plan's phases are broken down into epics, and the epics into tasks. One epic
— one file.

Templates: [templates/EPIC.md](../templates/EPIC.md),
[templates/TASK.md](../templates/TASK.md).

## Phase 0 epics

All the epics below are
[Phase 0](../transition/plan/01-phase-0-foundation.md) work closing gate
[G0](../transition/plan/00-roadmap.md#g0--end-of-phase-0). They are
**stack-independent** and are carried out while
[ADR-0003](../docs/02-decisions/ADR-0003-backend-stack.md) is being decided.

| # | Epic | Closes | Blocks |
|---|---|---|---|
| [EPIC-001](EPIC-001-project-setup.md) | Project setup | — | all the others |
| [EPIC-002](EPIC-002-contract-inventory.md) | API contract inventory | G0 | ADR-0003, Phases 1–3 |
| [EPIC-003](EPIC-003-schema-inventory.md) | Database schema inventory | G0, OQ-007 | ADR-0003, the data migration |
| [EPIC-004](EPIC-004-characterization-tests.md) | Characterization tests | G0 | D5, D6 in Phase 2 |
| [EPIC-005](EPIC-005-data-migration.md) | The data migration tool | — | Phase 4 (starts after G1) |
| [EPIC-006](EPIC-006-permissions-inventory.md) | Inventory of roles and permissions | G0 | ADR-0006 |
| [EPIC-007](EPIC-007-reports-inventory.md) | Report inventory | G0 | ADR-0009, the estimates |
| [EPIC-008](EPIC-008-i18n-migration.md) | Multilingual support migration | — | Phase 3 |
| [EPIC-009](EPIC-009-baseline-measurement.md) | Baseline measurement | G0 | the NFRs |
| [EPIC-010](EPIC-010-security-audit.md) | Legacy security audit | G0 | the plan's priorities |
| [EPIC-011](EPIC-011-scenario-registry.md) | Business scenario registry | G0 | the tests, parity, acceptance |

## Order

```
EPIC-001 ──┬─► EPIC-002 ──┬─► EPIC-004
           ├─► EPIC-003 ──┴─► EPIC-005 (starts after G1)
           ├─► EPIC-006
           ├─► EPIC-007 ─────► EPIC-008
           ├─► EPIC-009
           ├─► EPIC-010
           └─► EPIC-011 ──────► EPIC-004
```

## Epics for Phases 1–5

They will appear after gates G0 and G1: their composition depends on the results
of Phase 0 and on the chosen stack. Creating them now would be planning blind.

The exception is [EPIC-005](EPIC-005-data-migration.md): it is described in
advance because its preparation (the transformation rules) begins already in
Phase 0, on the results of EPIC-003.

## What the epics populate

The Phase 0 work populates **both** halves of the plan — the product
specifications and the transition maps:

| Epic | Populates in the product | Populates in the transition |
|---|---|---|
| [EPIC-002](EPIC-002-contract-inventory.md) | [05-api/](../product/05-api/README.md) — the endpoint registry | [transition/03-api-mapping.md](../transition/03-api-mapping.md) — the endpoint map |
| [EPIC-003](EPIC-003-schema-inventory.md) | [product/03-database/](../product/03-database/README.md) — the table registry | [transition/01-database-mapping.md](../transition/01-database-mapping.md) — the table map |
| [EPIC-007](EPIC-007-reports-inventory.md) | type R pages in [06-frontend/](../product/06-frontend/README.md) | the "do not migrate" decisions on reports |
| [EPIC-011](EPIC-011-scenario-registry.md) | [06-frontend/](../product/06-frontend/README.md) — the page registry | [transition/04-frontend-mapping.md](../transition/04-frontend-mapping.md) — the page map |
| [EPIC-006](EPIC-006-permissions-inventory.md) | permissions in the domain specifications | the mapping of old permissions to new ones |

Breaking down the classes
([transition/02-backend-mapping.md](../transition/02-backend-mapping.md)) happens
inside EPIC-002 and EPIC-003: module boundaries are determined by the set of
endpoints and tables.

A sample of the result — domain D1:
[the specification](../product/spec/D1-reference.md) and
[the map](../transition/map/D1-reference.md).

## Rules

1. **Identifiers are not reused.** A cancelled epic stays in place with a note.
2. **Every epic has an owner** — a person, not a role.
3. **A task comes with acceptance criteria** — otherwise it is unclear when it is
   closed.
4. **An epic is closed when all of its tasks are closed** and the result from its
   description is achieved, not when it is "mostly done".
5. Changes go through PRs ([CONTRIBUTING.md](../CONTRIBUTING.md)).
