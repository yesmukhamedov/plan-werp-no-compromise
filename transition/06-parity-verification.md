---
id: TRANS-06
title: Parity verification
status: draft
---

# Parity verification

The mechanism that compensates for the big bang's main shortcoming — the absence
of feedback from production until the cutover itself
([ADR-0001](../docs/02-decisions/ADR-0001-strategy-big-bang.md#accepted-cost)).

**The idea:** the new system receives the same input as the old one, and its
responses are compared automatically with the old one's. A divergence is a
defect. That gives us a stream of real feedback without releasing the new system
into production.

Without this mechanism a big bang degenerates into "we write for a year and a
half and then hope". It is not optional.

## Three levels

### Level 1. Data reconciliation

One-off, after every migration run. Described in
[02-data-migration.md](05-data-migration.md#reconciliation).

### Level 2. The shadow run

Continuous, from the first finished domain right up to the cutover.

```
             a user request
                  │
                  ▼
          ┌───────────────┐
          │   legacy      │──────► response to the user
          └───────┬───────┘
                  │ a copy of the request (read only)
                  ▼
          ┌───────────────┐
          │  new WERP     │──────► the response is discarded
          └───────┬───────┘
                  ▼
          ┌───────────────┐
          │  comparison   │──────► divergences into the report
          └───────────────┘
```

The rules:

- **Only read requests** are copied. Mutating requests are never duplicated — the
  new system must not create data during this period.
- The new system runs against a copy of production data, synchronized regularly.
- The new system's response **never** reaches the user.
- The comparison is by meaning, not byte by byte: key order, number formatting
  and request identifiers are excluded from the comparison, while substantive
  differences are not.
- The divergence report is produced daily, broken down by domain and endpoint.

The project metric: **the share of requests with a divergence.** It is published
weekly and is the main indicator of readiness for the cutover. The admission
condition is 30 consecutive days with no unresolved divergences.

Technically the shadow run is implemented at the routing level, outside both
systems — it must not require changes to the legacy.

### Level 3. Scenario parity

Manual and automated end-to-end scenarios executed in both systems with identical
input and compared by result.

It covers what the shadow run does not see: write operations, multi-step
processes, printable forms, calculations.

| Category | What is compared | Tolerance |
|---|---|---|
| Financial calculations | amounts, journal entries, balances, taxes | **0** |
| Compensation calculation | accruals, deductions, the total per employee | **0** |
| Reports | row by row | **0** |
| Printable forms | the data content (not the styling) | 0 |
| Warehouse operations | the balances after the operation | 0 |
| Access permissions | what a user with role X sees and can do | 0 |
| Interface scenarios | reachability of the result, the number of steps | as agreed |

The scenario registry is assembled in Phase 0
([EPIC-011](../backlog/EPIC-011-scenario-registry.md)) and serves simultaneously
as: the manual acceptance plan, the basis of the end-to-end tests and the
definition of the new system's completeness.

## What to do with a divergence

Every divergence goes down the same path:

1. **Record it** — the request, both responses, the domain, the date.
2. **Classify it:**
   - *a defect of the new system* → a work item, gets fixed;
   - *a defect of the old system* → an **accepted divergence**, requiring a
     written decision from the business: do we reproduce the bug or fix it;
   - *a deliberate change* → it must have been described in a work item in
     advance; if it was not described, it is not a deliberate change but a
     defect;
   - *an artefact of the comparison* → the comparison tool gets fixed.
3. **Close it** — either by a fix or by written acceptance.

**The key rule: "the old system gets it wrong the same way" is not grounds for
closing a divergence silently.** The decision to reproduce the old system's bug
is taken by the business and written down. Otherwise in a year nobody will
remember why the figure is what it is.

Over 12 years the system has accumulated behaviours that users consider correct
and developers consider bugs, and vice versa. The shadow run makes them visible —
that is its second and no less valuable function.

## Reporting

Weekly, throughout Phases 2–4:

| Figure | Meaning |
|---|---|
| The share of requests with a divergence, by domain | the domain's readiness |
| The number of unresolved divergences | the debt |
| The number of accepted divergences | how many of the old system's bugs we reproduce |
| Coverage of the scenario registry | the completeness of the verification |
| Consecutive days with no new divergences | maturity |

These figures are the only objective indicator of progress under a big bang.
Readiness percentages quoted by developers are not such an indicator.
