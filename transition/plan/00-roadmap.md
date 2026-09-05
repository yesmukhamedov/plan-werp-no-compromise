---
id: TRANS-PLAN-00
title: Roadmap
status: draft
---

# Roadmap

Six phases and five gates. Calendar dates are deliberately left out: they will
appear once the team composition is confirmed
([OQ-001](../12-open-questions.md)) and the stack is chosen
([ADR-0003](../../docs/02-decisions/ADR-0003-backend-stack.md)). Until then the
estimates are given in person-months —
[07-estimates.md](../10-estimates.md).

## Overview

```
Phase 0         Phase 1       Phase 2             Phase 3         Phase 4       Phase 5
Foundation  →   Platform   →  Domains         →   Frontend    →   Parity    →   Legacy
                                                                  and cutover   retirement
   │              │             │                   │               │             │
   G0             G1            │                   │              G2            G3            G4
contracts      stack and    ─────── in parallel ──────            readiness    cutover   legacy
and data       platform                                           for cutover   done      stopped
               ready
```

Phases 2 and 3 run **in parallel** — which is possible only thanks to
contract-first
([ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md)): the
frontend works against a generated stub without waiting for the backend.

## Phases

| Phase | Name | Result | Document |
|---|---|---|---|
| 0 | Foundation | we know exactly what we are obliged to reproduce | [01-phase-0-foundation.md](01-phase-0-foundation.md) |
| 1 | Platform | there is a skeleton on which domains can be written | [02-phase-1-platform.md](02-phase-1-platform.md) |
| 2 | Domains | all the business logic has been carried over | [03-phase-2-domains.md](03-phase-2-domains.md) |
| 3 | Frontend | all the screens are implemented | [04-phase-3-frontend.md](04-phase-3-frontend.md) |
| 4 | Parity and cutover | the system runs in production | [05-phase-4-parity-and-cutover.md](05-phase-4-parity-and-cutover.md) |
| 5 | Legacy retirement | the old systems do not exist | [06-phase-5-decommission.md](06-phase-5-decommission.md) |

## Gates

A gate is a point that cannot be passed without satisfying its conditions. The
conditions are checked formally; the person responsible signs off. A gate that is
"broadly passed" is not passed.

### G0 — end of Phase 0

You cannot start building without knowing exactly what you are building.

- [ ] The current API contract is described formally
      ([EPIC-002](../../backlog/EPIC-002-contract-inventory.md))
- [ ] The database schema is inventoried and a decision is taken on every table
      ([EPIC-003](../../backlog/EPIC-003-schema-inventory.md))
- [ ] The scenario registry is assembled
      ([EPIC-011](../../backlog/EPIC-011-scenario-registry.md))
- [ ] Permissions and roles are inventoried
      ([EPIC-006](../../backlog/EPIC-006-permissions-inventory.md))
- [ ] Reports are inventoried and the dead ones weeded out
      ([EPIC-007](../../backlog/EPIC-007-reports-inventory.md))
- [ ] The current system's baseline figures are measured
      ([EPIC-009](../../backlog/EPIC-009-baseline-measurement.md))
- [ ] The domain map is confirmed by the business
      ([product/02-domains.md](../../product/02-domains.md#what-must-be-confirmed-with-the-business-before-g1))
- [ ] ADR-0005 and ADR-0007 are accepted
- [ ] OQ-001, OQ-002, OQ-004, OQ-012 are closed
- [ ] The team composition is confirmed

### G1 — end of Phase 1

You cannot write 13 domains on an unchosen stack and a non-existent platform.

- [ ] **ADR-0003 is accepted** — the stack is chosen
- [ ] ADR-0004, 0006, 0008, 0010 are accepted
- [ ] The platform is ready: access, audit, reports, files, notifications,
      background jobs, observability
- [ ] CI/CD works: build, tests, quality, security, deployment
- [ ] The architecture-rule test is written and fails on a boundary violation
- [ ] One reference domain is implemented from the database to the screen — as
      the model for the rest
- [ ] The pre-production environment with a copy of production data is running
- [ ] The shadow run is technically up

### G2 — readiness for the cutover

- [ ] The Domain DoD is satisfied for all domains
- [ ] All screens are implemented and user acceptance has passed
- [ ] The shadow run: 30 days with no unresolved divergences
- [ ] The divergence in financial calculations is zero
- [ ] Rehearsals R3 and R4 have passed consecutively
- [ ] The load trials at ×3 the peak have passed
- [ ] The delta backlog is empty
- [ ] The full admission checklist
      ([transition/07-cutover.md](../07-cutover.md#conditions-for-admission-to-the-cutover))

### G3 — cutover done

- [ ] All users work in the new system
- [ ] The stabilization period finished without resorting to a rollback
- [ ] The figures are no worse than before the cutover

### G4 — project finished

- [ ] The legacy is stopped and deleted, the repositories archived
- [ ] Oracle and MySQL are decommissioned
- [ ] Not one item of
      [P-01…P-12](../../docs/00-context/02-pain-points.md) is reproduced
- [ ] Operations are run by the on-call team from the runbooks
- [ ] The retrospective is held and the plan is moved to the `completed` status

## The critical path

```
Contract inventory (P0)
        ↓
Choosing the stack (G1) ──────────► blocks everything
        ↓
The platform (P1) ────────────────► blocks all domains
        ↓
D0 → D1 → D2 → D3/D4 → D5 → D6/D7 → D8/D9   (P2, per the dependency graph)
        ↓
Shadow run: 30 days with no divergences (P4) ──► cannot be shortened
        ↓
Rehearsals R1–R4 (P4)
        ↓
Cutover (G3)
```

Two elements of the critical path **cannot be sped up with money or people**: the
30 days of the shadow run and the four migration rehearsals. That is calendar
time, and it must be in the plan from the very beginning rather than discovered
at the end.

## What sets the pace

| Phase | Limiting factor |
|---|---|
| 0 | availability of the people who hold the knowledge about the current system |
| 1 | taking the stack decision; skills in platform development |
| 2 | the number of domain developers; the domain dependency graph |
| 3 | the design system; the speed of user acceptance |
| 4 | the calendar: the shadow run and the rehearsals |
| 5 | approvals with operations |

## Cadence

Regardless of how long the phases take:

| Frequency | What |
|---|---|
| Weekly | the parity report ([transition/06-parity-verification.md](../06-parity-verification.md#reporting)) |
| Every two weeks | a demonstration to users on the pre-production environment |
| Monthly | the delta backlog retrospective ([transition/09-freeze-policy.md](../09-freeze-policy.md#the-delta-retrospective)) |
| Monthly | a review of the risk register |
| At the end of a phase | the phase retrospective, recalculation of the estimates |

The demonstrations every two weeks are not a formality. Under a big bang they are
**the only channel of user feedback** for the whole duration of the project.
