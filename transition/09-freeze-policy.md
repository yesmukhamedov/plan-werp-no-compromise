---
id: TRANS-09
title: Legacy freeze policy
status: draft
---

# Legacy freeze policy

Required by
[ADR-0001](../docs/02-decisions/ADR-0001-strategy-big-bang.md#accepted-cost).

## The problem

Under a big bang the new system is catching up with the old one. If the old one
keeps developing at its former pace, catching up is impossible — the target
moves. That is the main reason large rewrites do not finish: not technical
complexity but the continuously growing volume of what has to be reproduced.

At the same time, a system serving day-to-day operations cannot be frozen
completely
([C-01](../docs/00-context/03-constraints.md#c-01-production-does-not-stop)):
defects have to be fixed and regulators' requirements have to be met.

The freeze policy is a compromise between those two realities, put in writing
before the pressure begins.

## Levels

| Level | When | Allowed | Forbidden |
|---|---|---|---|
| **F0. Free** | Phase 0 | everything | — |
| **F1. Soft** | Phases 1–2 | defects, regulators' requirements, small improvements | new modules, new integrations, database schema changes |
| **F2. Hard** | from gate G2 | blocking defects, regulators' requirements | everything else |
| **F3. Full** | T−14d before the cutover | emergency fixes only, by the cutover lead's decision | everything else |

## The delta rule

**Any change to the legacy allowed after F1 immediately creates a work item in
the new WERP's delta backlog.** The rule applies without exception.

The work item is created by the author of the legacy change at the moment of the
merge, not "later". A legacy change does not count as finished until the
corresponding work item has been created.

```
a change in the legacy → a work item in the delta backlog → implementation in the new WERP → closure
```

**A condition for admission to the cutover: the delta backlog is empty**
([01-cutover-strategy.md](07-cutover.md#conditions-for-admission-to-the-cutover)).
That makes the cost of every legacy change visible: it is not free, it postpones
the cutover.

## The exception procedure

A change that does not pass the current freeze level can be allowed only like
this:

1. The initiator describes: what, why, and what happens if it is not done before
   the cutover.
2. The cost of implementing the same thing in the new WERP is estimated.
3. The decision is taken by the project lead together with the domain owner.
4. The decision and its rationale are recorded in the exception register.
5. The delta backlog work item is created automatically together with the
   exception.

The exception register is public within the team. **If the exceptions become
numerous, that is a signal not of poor discipline but that either the freeze was
introduced too early or the project is running too long.** Both conclusions call
for revising the plan, not for tightening the prohibitions.

## What the freeze never forbids

- Fixing defects that affect money, data or security.
- Changes required by a regulator or by law.
- Changes needed for the external integrations to work, at a counterparty's
  request.
- Operational actions by the operations team.

These categories jump the queue at any freeze level — and just as
unconditionally create a work item in the delta backlog.

## Communication

The freeze is introduced **by an announcement with a date**, not as a fait
accompli. Users and the business must understand: there will be no new
capabilities in the old system, because they will appear in the new one, and here
is when.

Without an explicit announcement the freeze is perceived as sabotage on
development's part — with an announcement it becomes a shared plan.

## The delta retrospective

Recorded monthly: how many changes were allowed, how many delta backlog items
were created, how many were closed. A growing unclosed delta backlog is the
earliest and most reliable sign that the project is not converging
([R-02](11-risks.md#r-02)).
