---
id: PROD-10
title: Performance
status: draft
---

# Performance

The target figures are in [07-nfr.md](07-nfr.md). **This document is how they are
achieved and how they are verified** — the figures are the requirement, and this
is the method.

> **[NFR-00](07-nfr.md). No scenario is slower than the baseline.**
> A system in which the user works more slowly than before is not accepted,
> regardless of the quality of the code.

---

## The baseline

Target figures are set relative to a measured baseline
([EPIC-009](../backlog/EPIC-009-baseline-measurement.md)). Without one, a project
either legitimizes a degradation or sets a bar it cannot reach — and neither is
discovered until acceptance.

| What the baseline includes | Why |
|---|---|
| Response times per endpoint, with percentiles | the "no worse than" target, per endpoint rather than as an average |
| The load profile over a full month | identifying the peaks, including a period close |
| The peak periods and their nature | month close, payroll accrual, stocktaking |
| The heaviest database queries | what to rewrite first |
| Table volumes and annual growth | capacity planning, and which tables are partitioned |
| The time to produce typical reports | where the asynchrony threshold falls |
| Frontend figures: load, paint, bundle size | the "no worse than" target for the interface |

Collecting it is [Phase 0](../transition/plan/01-phase-0-foundation.md) work, and
it is on the critical path: nothing after it can be judged without it.

## Principles

| # | Principle | Enforced by |
|---|---|---|
| PERF-01 | **Everything is paginated.** An endpoint with an unbounded result set does not exist | [API-08](05-api/checks.md), [BE-15](04-backend/checks.md) |
| PERF-02 | **Filters are explicit.** No arbitrary query language in the URL — the cost of a request must be predictable | [API-10](05-api/checks.md) |
| PERF-03 | **An index exists for a named query**, and the migration description names it | [DB-15](03-database/checks.md) |
| PERF-04 | **Profiling happens at a realistic volume.** A query that is fast on an empty database tells you nothing | — |
| PERF-05 | **N+1 is caught by a test**, not in production | [BE-17](04-backend/checks.md), [QA-40](09-quality.md) |
| PERF-06 | **Heavy reads go to a replica.** A report does not affect the operators' work | [NFR-43](07-nfr.md#scalability) |
| PERF-07 | **Long-running operations are asynchronous**, above a 5-second threshold | [API rule 9](05-api/rules/09-long-running.md), [ADR-0009](../docs/02-decisions/ADR-0009-reporting-and-exports.md) |
| PERF-08 | **The cache is explicit**, with a stated invalidation policy; losing it never produces incorrect data | [01-architecture.md](01-architecture.md#data) |
| PERF-09 | **The server computes reports.** Never the browser | [ADR-0009](../docs/02-decisions/ADR-0009-reporting-and-exports.md) |
| PERF-10 | **A derived table is rebuildable and reconciled**, and the divergence is an alert | [03-database 14.4](03-database/rules/14-patterns.md#144-a-ledger-and-a-derived-balance) |

PERF-02 is the one that looks like a restriction and is a protection. A generic
filter language in the URL appears to save work; it makes field-level
permissions, load prediction and client generation impossible, all three at once,
and it does so gradually enough that nobody attributes the outcome to the
decision.

PERF-10 belongs here rather than only in the database rules because a derived
table is a **performance** device: `account_balance` and `stock_balance` exist so
that a balance is not a sum over hundreds of millions of rows. A derived table
that cannot be rebuilt is a cache pretending to be data.

## Where the design already spends its performance budget

The schema design made three decisions that are performance decisions, and they
are worth naming so they are not undone by someone who reads them as
denormalization for its own sake:

| Decision | Cost | What it buys |
|---|---|---|
| `branch.path` and `org_unit.path` as `ltree`, maintained by a trigger | one trigger, one test that writes bypassing the application | the branch filter on nearly every screen in the system stops being a recursive query |
| `installed_unit.latitude` / `longitude` copied from the address | a copy that must be kept correct | route planning reads tens of thousands of units without a join per unit |
| `document_link.chain_id` | a denormalized root identifier | a chain of six documents is one index lookup rather than six recursive round trips |

Each is recorded where it lives, with its justification, because an unexplained
denormalization is removed by the next person who finds it.

## Verification

| # | When | What |
|---|---|---|
| PERF-20 | On every PR | the database query-count test; the test-suite time budget |
| PERF-21 | Weekly | a load run on pre-production, compared with the previous one |
| PERF-22 | On completing a domain | that domain's load profile against the NFR figures |
| PERF-23 | Before G2 | full trials at ×3 the measured peak, the ERP peak scenario included |
| PERF-24 | After the cutover | a daily comparison of the figures against the pre-cutover values |

**A degradation of a figure between releases is grounds for not shipping the
release.** Performance is lost gradually and imperceptibly; it is caught only by
comparison with the previous measurement, which is why PERF-21 is automated and
reported rather than run on request.

PERF-23 exists because a peak in an ERP is not a scaled-up ordinary day: the
month close hits D5, D6 and D7 simultaneously with queries that never run at any
other time. A trial at ×3 of an ordinary profile does not exercise it.

## Frontend figures

| Metric | Why it is the one measured |
|---|---|
| Time to first paint | the first impression, and the one users describe as "slow" |
| Time to interactive | when work can actually begin |
| Main bundle size | today: 369k lines with three libraries per job |
| Time to open a typical list | the most frequent operation in an ERP, by a wide margin |
| Input responsiveness in a form | the operators work from the keyboard, and lag there costs real time |

The last one is rarely measured and is the one an operator feels most: a form
that lags 80 ms behind typing is unusable for eight hours in a way that is
invisible in a five-minute demonstration.

## Capacity

| # | Requirement |
|---|---|
| PERF-30 | Planning five years ahead, based on measured annual growth |
| PERF-31 | Partitioning of large historical tables on **measured** volume, never in advance |
| PERF-32 | A quarterly review: data growth changes what used to work |
| PERF-33 | Every table above the volume threshold has a recorded retention decision — [DB-17](03-database/checks.md) |

The tables that will reach the threshold are already known from the design:
`audit_event` and `audit_field_change` first, then `journal_entry_line`,
`stock_movement`, `maintenance_slot`, `time_sheet_entry`, `outbox_event` and
`notification_delivery`. Each names its partition key in its schema file, so
PERF-31 is a decision about *when*, not about *how*.

## Open questions

| # | Question | Affects |
|---|---|---|
| PERF-Q1 | What is the real peak profile, and which domains does it hit together? | PERF-23, and the headroom figure [NFR-14](07-nfr.md#load) |
| PERF-Q2 | Is a read replica available in the target infrastructure from day one? | PERF-06 — without it, reports and operational work compete |
| PERF-Q3 | Which reports must stay synchronous for the business, whatever their cost? | PERF-07, and the 5-second threshold |
