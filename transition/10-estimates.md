---
id: TRANS-10
title: Effort estimate
status: draft
confidence: low
---

# Effort estimate

## How to read this document

The estimates are given in **person-months (PM)** and as a **range**. Calendar
dates are not derived: they depend on the team composition
([OQ-001](12-open-questions.md)), which is not confirmed.

The confidence of the estimates is **low**, and that is an honest characteristic
rather than caution. The reasons are named below; each of them is removed by
specific Phase 0 work, after which the estimates are recalculated.

**An estimate is a commitment to recalculate it, not a promise to fit inside
it.**

## Why the estimates are imprecise right now

| Reason | Removed by |
|---|---|
| The stack is not chosen — the effort coefficient for the transfer is unknown | [ADR-0003](../docs/02-decisions/ADR-0003-backend-stack.md), G1 |
| It is unknown how much of the code is dead | [EPIC-003](../backlog/EPIC-003-schema-inventory.md), [EPIC-007](../backlog/EPIC-007-reports-inventory.md) |
| The number of reports and screens is unknown | [EPIC-007](../backlog/EPIC-007-reports-inventory.md), [EPIC-011](../backlog/EPIC-011-scenario-registry.md) |
| The volume of business logic in the database is unknown | [OQ-007](12-open-questions.md) |
| The overlap between the legacy JSF's data and Oracle is unknown | [OQ-012](12-open-questions.md) |
| The divergence between the duplicated domains is unknown | [EPIC-002](../backlog/EPIC-002-contract-inventory.md), Phase 2 |
| The domain boundaries are not confirmed by the business | [product/02-domains.md](../product/02-domains.md#what-must-be-confirmed-with-the-business-before-g1) |
| The team composition is not confirmed | [OQ-001](12-open-questions.md) |

## The basis: what gets carried over

| Component | Source lines | Estimated useful volume | Why less |
|---|---:|---:|---|
| `werp_java_back_v2` | 354,761 | ~60–70% | duplicated domains, boilerplate, dead branches |
| `werp_react_front` | 369,214 | ~40–50% | duplicated sections, class-component boilerplate, hand-written HTTP wrappers (now generated), reports (moving to the server) |
| `werp_crm` + `werp_call_center` | 28,553 | collapses into D9 | a duplicate of the CRM domain |
| `werp_jsf` | 233,913 | **unknown** | if the functionality has already been carried over into v2 — not carried over; if not — a substantial additional volume |

The share of `werp_jsf` is **the estimate's largest uncertainty**. The legacy
monolith is still in production and 33 links from React lead into it, meaning
some functionality exists **only** there. Exactly how much is determined in
Phase 0 ([OQ-012](12-open-questions.md)). The answer decides whether we are at
the lower or the upper bound of the range.

## Estimate by phase

| Phase | Estimate, PM | Confidence | What determines it |
|---|---|---|---|
| 0. Foundation | 6–10 | medium | availability of the people who hold the knowledge |
| 1. Platform | 12–20 | medium | the stack, the skills, the platform's scope |
| 2. Domains | **60–110** | **low** | the share of dead code, the volume of `werp_jsf`, the divergence between duplicates |
| 3. Frontend | **40–70** | **low** | the number of screens, the quality of the design system |
| 4. Parity and cutover | 15–25 + **3–4 calendar months** | medium | data quality, the number of divergences |
| 5. Legacy decommissioning | 2–4 | high | approvals |
| **Total** | **135–239 PM** | | |

Phases 2 and 3 run in parallel, so they do not add up in the calendar.

Phase 4 contains **3–4 incompressible calendar months**: 30 days of the shadow
run plus four migration rehearsals plus the stabilization period. Those months do
not depend on the size of the team.

## Estimate by domain (Phase 2)

The coefficient converting lines into effort will appear after the reference
domain (Phase 1) — until then the numbers below are based on relative volume.

| Domain | Source lines | Share of Phase 2 | Comment |
|---|---:|---:|---|
| D5 Accounting and finance | 62,776 | ~20% | the largest; probably underestimated |
| D8 Field service | 96,612 | ~18% | two sources (`core/service` + the `service` module), consolidated |
| D9 CRM and call centre | 57,000+ | ~15% | **four** sources, the maximum divergence between duplicates |
| D3 Personnel | 34,988 | ~10% | |
| D4 Contracts and sales | 34,228 | ~10% | a 3,775-line god class with seven foreign domains |
| D7 Warehouse and logistics | 29,018 | ~9% | |
| D1 Reference data | 14,810 | ~5% | the reference domain, done in Phase 1 |
| D12 Tasks and communications | 13,255 | ~5% | |
| D6 Compensation calculation | inside D5 | ~5% | 7,598 lines in one class; the risk of special cases |
| D2 Counterparties | inside `mreference` | ~2% | |
| D10 Document workflow | 2,584 | ~1% | may be dropped in favour of an off-the-shelf solution |
| D11 Legal | 989 | ~1% | likewise |

## What the estimate does not include

Listed explicitly, because these are exactly what usually blows the budget:

- **Business logic in the database.** If Oracle holds PL/SQL packages, triggers
  and scheduler jobs with logic in them, that is a separate, unestimated volume
  ([OQ-007](12-open-questions.md)).
- **Functionality that lives only in `werp_jsf`**
  ([OQ-012](12-open-questions.md)).
- **Resolving the divergences between duplicated implementations.** Discovered
  only when they are consolidated.
- **Data cleansing.** Its volume is known after the first migration rehearsal.
- **Regulator requirements** ([OQ-003](12-open-questions.md)).
- **The delta backlog** — the work generated by changes to the legacy during the
  project. Directly proportional to the project's duration.
- The business owners' time for interviews, decisions and acceptance. That is not
  "free" — it is the limiting factor of several phases.

## The recalculation rule

The estimates are revised at fixed moments:

| Moment | What gets refined |
|---|---|
| Gate G0 | the volume of dead code, the number of reports and screens, the volume of `werp_jsf` |
| Gate G1 | the effort coefficient from the reference domain, the stack |
| After each Phase 2 wave | the coefficient from actual data |
| After R1 | the volume of data-quality work |

A deviation of the actuals from the estimate by more than 30% is a reason to
revise the **plan**, not to add people. Adding people to a project already
running does not always speed it up, and never immediately.

## An honest warning

Full-rewrite projects for ERPs of this size historically finish later and cost
more than the estimate, and a noticeable share of them do not finish at all. The
main reason is not technical: the target moves faster than one walks towards it.

In this plan three mechanisms work against that: the
[freeze policy](09-freeze-policy.md), the delta backlog rule and the
recalculation of the estimates at every gate. They are useful exactly to the
extent that they are followed.
