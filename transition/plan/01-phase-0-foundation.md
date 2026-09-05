---
id: TRANS-PLAN-01
title: Phase 0 — Foundation
status: draft
gate: G0
---

# Phase 0 — Foundation

**Goal:** find out what exactly we are obliged to reproduce. Not a line of the
new system's code is written in this phase.

**Why this is a separate phase.** Over 12 years the current system has
accumulated behaviour that is documented nowhere: 1,286 endpoints, 523 entities,
an unknown number of reports and permissions. The only holders of that knowledge
are the code and the people. Under a big bang the unknown surfaces not gradually
but all at once and at the end. Phase 0 turns the unknown into the known
**before** it becomes expensive.

**A key property:** the phase is entirely **stack-independent**. It runs while
[ADR-0003](../../docs/02-decisions/ADR-0003-backend-stack.md) is being decided
and is not blocked by it.

## Phase deliverables

| # | Deliverable | Epic |
|---|---|---|
| 1 | A formal specification of the current API | [EPIC-002](../../backlog/EPIC-002-contract-inventory.md) |
| 2 | A database schema inventory with a decision on every table | [EPIC-003](../../backlog/EPIC-003-schema-inventory.md) |
| 3 | Characterization tests for the critical calculations | [EPIC-004](../../backlog/EPIC-004-characterization-tests.md) |
| 4 | A registry of roles and permissions | [EPIC-006](../../backlog/EPIC-006-permissions-inventory.md) |
| 5 | A report registry with the dead ones weeded out | [EPIC-007](../../backlog/EPIC-007-reports-inventory.md) |
| 6 | Measured baseline figures | [EPIC-009](../../backlog/EPIC-009-baseline-measurement.md) |
| 7 | A registry of business scenarios | [EPIC-011](../../backlog/EPIC-011-scenario-registry.md) |
| 8 | A domain map confirmed by the business | [product/02-domains.md](../../product/02-domains.md) |
| 9 | ADR-0005 and ADR-0007 accepted | [02-decisions](../02-decisions/) |
| 10 | Prototypes on the stack candidates, the matrix filled in | [ADR-0003](../../docs/02-decisions/ADR-0003-backend-stack.md#next-steps) |
| 11 | Organization: the team, the roles, the domain owners | [EPIC-001](../../backlog/EPIC-001-project-setup.md) |
| 12 | A security audit of the current system | [EPIC-010](../../backlog/EPIC-010-security-audit.md) |

## The order of work

```
EPIC-001 organization ─┬─► EPIC-002 API contracts ──┐
                       ├─► EPIC-003 DB schema ──────┤
                       ├─► EPIC-006 permissions ────┼─► the domain map ─► G0
                       ├─► EPIC-007 reports ────────┤
                       ├─► EPIC-009 figures ────────┤
                       ├─► EPIC-010 security ───────┤
                       └─► EPIC-011 scenarios ──────┘
                                   │
                                   ▼
                       EPIC-004 characterization tests
                                   │
                                   ▼
                       stack prototypes ─► ADR-0003 (by G1)
```

EPIC-002, 003, 006, 007, 009, 010 and 011 run in parallel and independently.
EPIC-004 relies on 002 and 011. The stack prototypes begin after 002 and 003 —
otherwise the prototype will be solving the wrong problem.

## What matters to get right

### Inventory is not documentation

The task is not to describe everything. The task is to take a **decision** on
every element: migrate, consolidate, drop. An inventory without decisions turns
into 300 pages nobody will read.

A live system of 12 years always contains dead matter: reports nobody uses;
endpoints nobody calls; tables nobody reads; permissions assigned to nobody.
Finding and cutting off the dead matter is the cheapest way to reduce the
project's volume. It is done once, here, and nowhere else.

**The source of truth about what is alive is data, not opinion:** endpoint access
logs, table query statistics, report usage history. If such data does not exist,
collecting it has to be switched on in the legacy in the first week of Phase 0,
otherwise the decisions will be taken from memory.

### The people who hold the knowledge

Some of the system's behaviour cannot be derived from the code: why a calculation
is arranged the way it is, which of two duplicated places is the right one, what
`aes` means. The holders of that knowledge are people, and their time has to be
planned in advance.

That is the phase's limiting factor. If a key person is available two hours a
week, the phase will take as long as it takes.

### Characterization tests

[EPIC-004](../../backlog/EPIC-004-characterization-tests.md) is not ordinary
tests. They do not verify that the system works **correctly**; they record how it
works **now**, bugs included. They are the reference for the parity
reconciliation.

They are written for what a shadow run cannot verify: calculations, multi-step
processes, edge cases. First of all for payroll calculation (7,598 lines in a
single class) and accounting operations.

## What not to do in this phase

- Do not write the new system's code. The temptation to "start with something
  simple" will lead to rewriting that code once the stack is chosen.
- Do not design the interface. The design system belongs to Phase 1, after the
  scenarios are confirmed.
- Do not try to improve the legacy. The freeze is not in force yet, but improving
  something that will be switched off makes no sense either.
- Do not defer the uncomfortable questions. A question deferred in Phase 0 will
  surface in Phase 4 and cost ten times as much.

## Completion criteria

Gate [G0](00-roadmap.md#g0--end-of-phase-0).
