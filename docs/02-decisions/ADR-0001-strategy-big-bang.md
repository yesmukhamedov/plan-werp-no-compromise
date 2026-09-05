---
id: ADR-0001
title: Transition strategy — big bang
status: Accepted
date: 2026-09-03
supersedes: null
superseded_by: null
---

# ADR-0001. Transition strategy — big bang

## Context

A system of three generations (the JSF monolith, Spring Boot 2.0, two services on
Spring Boot 2.4) totalling ~990k lines and serving production every day has to be
replaced. The transition method is the project's most expensive decision: it
determines the duration, the risk and whether the business sees a result before
the very end.

The material inputs:

- **There are no tests**
  ([P-01](../00-context/02-pain-points.md#p-01-practically-no-tests)) — no
  automated safety net exists under any strategy; it has to be created.
- **There are no boundaries between domains**
  ([P-02](../00-context/02-pain-points.md#p-02-god-classes-and-field-injection))
  — a single controller pulls in seven foreign domains, the database is shared,
  transactions cut across everything.
- **The DBMS changes** ([ADR-0002](ADR-0002-database-postgresql.md)) — the data
  moves in its entirety.
- Attempts at gradually extracting domains have already been made twice
  (`werp_crm`, `werp_call_center`) and **were never finished**: both produced a
  duplicate of the domain rather than its replacement
  ([P-04](../00-context/02-pain-points.md#p-04-domains-implemented-twice)).

## Options

### A. Strangler Fig — domain by domain

The new system grows next to the old one; a gateway switches routes as pieces
become ready; the generations coexist for months.

- **For:** early feedback, the ability to roll back per route, production does
  not stand still, the risk is spread out.
- **Against:** with a change of DBMS this requires either two-way data
  synchronization or distributed transactions between Oracle and PostgreSQL for
  the entire transition period; the cross-cutting transactions of the current
  code (`ContractController`, which touches `accounting` + `hr` + `logistics` in
  one call) cannot be cut along a domain boundary without cutting the
  transaction; **this path has already been tried twice in this project and both
  times produced a duplicate, not a replacement**.

### B. Big bang — parallel development, a single cutover

The new system is written in full, the old one is frozen feature-wise, and the
cutover happens in a single window.

- **For:** no transitional two-world state, no data synchronization between two
  DBMSs, the target architecture is not distorted for the sake of legacy
  compatibility, transactions are designed anew and correctly, the old code need
  not be touched at all.
- **Against:** a long period with no production release; the risk is concentrated
  in one point; rollback is more expensive; requirements have time to go stale
  during development.

### C. Hybrid — the frontend anew, the backend gradually

- **For:** an intermediate result is visible.
- **Against:** requires a stable API contract on top of the legacy backend —
  that is, the backend has to be tidied up first, which is the main work anyway.
  Gives the worst of both options.

## Decision

**Option B — big bang — is accepted.**

The deciding considerations: the change of DBMS turns option A from "gradual"
into "gradual plus permanent synchronization of two databases"; the absence of
domain boundaries makes it impossible to cut the transactions; and above all,
option A has already been tested in practice twice in this project and produced
duplicated domains instead of replacement.

## Accepted cost

Big bang is the strategy with the highest risk of failure. We accept it
deliberately and compensate for it with **four mandatory mechanisms**. None of
them is optional; dropping any one of them invalidates the decision and requires
a new ADR.

### 1. A shadow run instead of production releases

The absence of early releases is compensated by continuous reconciliation
against a copy of production data: from its first finished domain the new system
receives the real request stream in read-only mode, and its responses are
compared automatically with the legacy's. A divergence is a defect.
→ [transition/06-parity-verification.md](../../transition/06-parity-verification.md)

### 2. Cutover rehearsals

The cutover is rehearsed at full data volume **at least four times** before the
live one. Each rehearsal is timed and ends with a divergence report. The live
cutover is permitted only after two consecutive successful rehearsals.
→ [transition/07-cutover.md](../../transition/07-cutover.md)

### 3. A legacy freeze policy

Without restricting changes to the legacy, the target moves faster than one can
walk towards it. The freeze comes into force at gate G2; it does not forbid
changes outright but puts them into the mode "defects and regulator requirements
— yes, new functionality — no", and every change let through lands in the new
WERP's delta backlog.
→ [transition/09-freeze-policy.md](../../transition/09-freeze-policy.md)

### 4. A verified rollback

The rollback plan is written before the cutover, rehearsed together with it and
has a measured execution time. The legacy environment stays operational for an
**agreed stabilization period** after the cutover and only then is
decommissioned.
→ [transition/08-rollback.md](../../transition/08-rollback.md)

## Consequences

- [Phase 4](../../transition/plan/05-phase-4-parity-and-cutover.md) — parity and
  cutover — appears as a separate phase whose cost is comparable to development.
- The order in which domains are developed is determined not by business priority
  but by dependencies: with no production releases there is no point in "doing
  the most valuable thing first".
  → [transition/plan/03-phase-2-domains.md](../../transition/plan/03-phase-2-domains.md)
- A pre-production environment with a copy of production data is required for the
  whole duration of the project.
- User feedback arrives through regular demonstrations on the pre-production
  environment rather than through production. The demonstration cadence is an
  obligation, not a wish.
- The risks [R-01](../../transition/11-risks.md#r-01) (schedule stretching),
  [R-02](../../transition/11-risks.md#r-02) (a moving target) and
  [R-03](../../transition/11-risks.md#r-03) (a failed cutover) carry the maximum
  weight in the risk register.
