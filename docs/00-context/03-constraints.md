---
id: CTX-03
title: Constraints
status: draft
---

# Constraints

Constraints are what the plan must accept as given. Unlike risks (which may not
materialize) and open questions (which will be closed), constraints are not up
for discussion — the solution is designed around them.

Some constraints are marked `?` — they require confirmation by the product owner
before gate G0 and are mirrored in the
[open questions](../../transition/12-open-questions.md).

## C-01. Production does not stop

The current system serves day-to-day operations every day. Throughout the
development of the new WERP the old one keeps running, keeps accepting changes
and keeps accumulating data.

**Consequence for the plan:** a [freeze policy](../../transition/09-freeze-policy.md)
is needed that restricts changes to the legacy without forbidding them
outright, along with a mechanism for carrying legacy changes over into the new
system (the delta backlog).

## C-02. The strategy is big bang

The decision is taken ([ADR-0001](../02-decisions/ADR-0001-strategy-big-bang.md)):
the new system is developed in parallel and introduced in a single cutover.
Gradually "squeezing out" domains through routing is not used.

**Consequence:** there are no intermediate production releases for validating
hypotheses. Feedback must therefore come from another source — a shadow run
against a copy of production data
([transition/06-parity-verification.md](../../transition/06-parity-verification.md))
and regular demonstrations to users on the pre-production environment.

## C-03. The DBMS is PostgreSQL

The decision is taken
([ADR-0002](../02-decisions/ADR-0002-database-postgresql.md)). The target system
runs on PostgreSQL; Oracle is decommissioned together with the legacy backend.

**Consequence:** the 289 native queries and 43 `nativeQuery` in the current code
are not directly portable and are subject to rewriting rather than porting; the
data schema is migrated on a separate track.

## C-04. The backend stack has not been chosen yet

The decision is deliberately deferred
([ADR-0003](../02-decisions/ADR-0003-backend-stack.md)).

**Consequence:** until gate G1 the plan must contain no decisions that cannot be
carried out on any of the candidates. Every stack-dependent place is marked
`[STACK]` and listed in ADR-0003. The Phase 0 work is entirely
stack-independent, so the start of the project is not blocked by the decision.

## C-05. External integrations cannot be changed

Contracts with external systems (the payment provider, the credit bureau, the
SMS provider, messengers, forms on public sites, the mobile app) are defined by
the counterparties. The new WERP must honour them unchanged.

**Consequence:** `bridge` stays the entry point and is not rewritten; the new
system must provide `bridge` with the same internal endpoints as the current one,
or else the change is made in both repositories at once. The full list —
[04-current-integrations.md](04-current-integrations.md).

## C-06. The mobile app — a separate client outside this plan

The mobile app calls the backend through `bridge` over a fixed list of paths.
Rewriting it is not part of the project scope.

**Consequence:** for the mobile client the new backend must preserve the contract
**1:1**, including the error format and the status codes. That is stricter than
for the web frontend, which is written anew together with the backend.

## C-07. Multilingual support is mandatory

The current system is localized in three languages (ru / en / tr); the
dictionaries contain ~1,700 messages. Dropping any of the languages is a product
decision, not an engineering one.

## C-08. Three environments

Dev, stage, prod. Kubernetes, a self-hosted CI runner, an external image
registry. Changing the orchestration platform is out of scope.

## C-09. Financial calculations require exact arithmetic

The `accounting` domain (62,776 lines) and payroll calculation are monetary
computations. The current code uses `decimal4j` on the backend and both
`bigdecimal` and `bignumber.js` on the frontend at the same time.

**Consequence:** the money type and the rounding rules are fixed once at the
platform level ([product/03-database/](../../product/03-database/README.md)), and
reconciling the calculations of the old and the new system is a mandatory part of
the parity verification, with zero tolerance for divergence.

## C-10. Change audit already exists and must be preserved

The current system uses Hibernate Envers to version some entities. The change
history must not be lost during the migration.

**Consequence:** the data migration carries over not only the current state but
also the audit tables; the target system must have a working audit mechanism from
day one, not "later".

## C-11. Team and budget `?`

The size and composition of the team for the development period are not
confirmed. The estimates in
[transition/10-estimates.md](../../transition/10-estimates.md) are given in
person-months and are converted into a calendar only after confirmation.

→ [OQ-001](../../transition/12-open-questions.md)

## C-12. Regulators' data-retention requirements `?`

To be confirmed: retention periods for primary documents, requirements for
localizing personal data, requirements for the immutability of operation logs.
The storage model and deletion policy in
[product/03-database/](../../product/03-database/README.md) depend on the answer.

→ [OQ-003](../../transition/12-open-questions.md)
