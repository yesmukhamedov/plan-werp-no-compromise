---
id: TRANS-PLAN-06
title: Phase 5 — Legacy decommissioning
status: draft
gate: G4
---

# Phase 5 — Legacy decommissioning

**Goal:** the old systems do not exist.

**Why this is a separate phase rather than "we will clean up later".** An old
system that has not been decommissioned is
[P-05](../../docs/00-context/02-pain-points.md#p-05-three-backend-generations-in-production-at-once):
that is exactly how three backend generations ended up in the current landscape
at the same time. Each of them was once meant to be switched off "later".

Rule [NC-07](../../docs/01-principles/01-no-compromise.md#nc-07) exists for
precisely this phase: **the project is not finished while the legacy is
running.**

## The condition for starting

The stabilization period is over, gate
[G3](00-roadmap.md#g3--cutover-done) is passed, and no rollback decision was
taken.

## The work

### 1. Stopping the legacy

| Step | Action |
|---|---|
| 1 | A full backup of all the legacy databases and files, verified by a restore |
| 2 | Exporting the historical data into a long-term archive in an open format |
| 3 | Disconnecting the legacy applications from the network |
| 4 | Waiting out the agreed period (nobody came asking — so it is not needed) |
| 5 | Stopping the application servers |
| 6 | Stopping Oracle and MySQL |
| 7 | Releasing the resources |

Step 4 is not over-caution: over 12 years exports and reports may have been
connected to the database that none of the current staff knows about.
Disconnecting from the network while keeping the system operational reveals them
safely.

### 2. Licences and contracts

- The Oracle licences are not renewed — one of the project's measurable economic
  results
  ([ADR-0002](../../docs/02-decisions/ADR-0002-database-postgresql.md)).
- Support and hosting contracts relating only to the legacy are revised.

### 3. Code and repositories

- `werp_jsf`, `werp_java_back_v2`, `werp_react_front`, `werp_crm`,
  `werp_call_center`, `target-bridge` — **archived, not deleted**: they remain
  the only answer to the question "how did this work before?".
- Access is read-only.
- The README of each carries a decommissioning note, the date and a link to the
  new repository.
- The legacy CI pipelines are switched off.

`bridge` is not archived — it stays in operation.

### 4. Infrastructure

- The manifests, configurations, secrets, DNS records and routing rules relating
  to the legacy are deleted.
- The legacy images are deleted from the registry.
- The legacy dashboards and alerts are switched off.

### 5. Verifying the result

A formal check against the summary table
[P-01…P-12](../../docs/00-context/02-pain-points.md#summary-table): not one item
is reproduced in the new system. It is verified with the same commands that
measured the current system — the method is described in the
[appendix to the inventory](../../docs/00-context/01-inventory.md#appendix-how-this-was-measured).

That is the only objective way of answering the question "did it work?".

### 6. Handover to operations

- The on-call team works from the runbooks without the involvement of the
  migration developers.
- The process for updates, on-call duty and incident response is established.
- The rules
  [NC-01…NC-15](../../docs/01-principles/01-no-compromise.md) remain in force and
  keep being checked in CI — otherwise the new system will begin its own journey
  towards the old one's state from day one.

### 7. Retrospective

- What was estimated correctly, what was not, and by how much.
- What was found in Phase 0 and what surfaced in Phase 4 — and why.
- Whether the big bang compensation mechanisms worked.
- How large the delta backlog was over the project.
- What we would do differently.

The result is a document in this repository. It is archived together with the
plan and remains the answer for the next large rewrite.

## Completion criteria

Gate [G4](00-roadmap.md#g4--project-finished).

## After the project

This repository is moved to the `completed` status and archived. The living
documentation of the new system becomes the monorepo's `docs/`
([ADR-0007](../../docs/02-decisions/ADR-0007-repo-layout.md)).

The "no compromise" rules move into the new repository and keep being enforced.
They were written not for the rewrite project but for a system that has to live
the next 12 years.
