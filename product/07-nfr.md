---
id: PROD-07
title: Non-functional requirements
status: draft
---

# Non-functional requirements

The numbers in this document are **placeholders until the baseline is measured**.
Setting target figures without knowing the present ones is pointless: one either
sets an unreachable bar or, conversely, legitimizes a degradation.

The baseline is measured in Phase 0
([EPIC-009](../backlog/EPIC-009-baseline-measurement.md)). After that every
figure gets three values: the **baseline**, **no worse than** (the mandatory
minimum) and the **target**.

> **NFR-00. No scenario is slower than the baseline.**
> A system in which the user works more slowly than before is not accepted,
> regardless of the quality of the code. This requirement outranks every other
> figure in the document, and it is the one users will judge the project by.

Each requirement below carries an identifier so that a test, a runbook or a
release decision can cite it. How they are achieved is
[10-performance.md](10-performance.md); how they are watched is
[11-observability.md](11-observability.md).

---

## Performance

| # | Figure | Baseline | No worse than | Target |
|---|---|---|---|---|
| NFR-01 | API response time, 95th percentile (operational screens) | to be measured | = the current one | ≤ 300 ms |
| NFR-02 | API response time, 99th percentile | to be measured | = the current one | ≤ 1 s |
| NFR-03 | Opening a typical list (the first page) | to be measured | = the current one | ≤ 500 ms |
| NFR-04 | Producing a typical synchronous report | to be measured | = the current one | ≤ 5 s |
| NFR-05 | Threshold for switching a report to asynchronous mode | — | — | 5 s |
| NFR-06 | First paint of the web application | to be measured | = the current one | ≤ 2 s |
| NFR-07 | Time to interactive | to be measured | = the current one | to be set after G1 |
| NFR-08 | Size of the frontend's main bundle | to be measured | ≤ the current one | to be set after G1 |

NFR-01 and NFR-03 are the two the operators feel. They are measured per endpoint
and per list page, not as a system-wide average — an average over eight hundred
endpoints hides exactly the twenty that hurt.

## Load

| # | Figure | Value |
|---|---|---|
| NFR-10 | Concurrent users, an ordinary day | to be measured |
| NFR-11 | Concurrent users, peak | to be measured |
| NFR-12 | Requests per second, peak | to be measured |
| NFR-13 | Peak periods | to be determined: period close, month end, seasonality |
| NFR-14 | Headroom above the measured peak | ×3 |

**Peak periods in an ERP are not an abstraction.** The month close, payroll
accrual and stocktaking produce load several times higher than usual, and they
land on the three heaviest domains at once. The profile is measured over a period
of at least one full month so that a close is inside it.

## Data volume

| # | Figure | Value |
|---|---|---|
| NFR-20 | Current database size | to be measured |
| NFR-21 | The largest tables (top 20) by row count and size | to be measured |
| NFR-22 | Annual growth | to be measured |
| NFR-23 | Number of files and attachments, total size | to be measured |
| NFR-24 | Capacity planning horizon | 5 years |

The target schema already names which tables will be large and which are
partitioned by time; the measured figures decide the partition sizes and the
retention windows ([03-database rule 10](03-database/rules/10-large-tables.md)).

## Availability

| # | Figure | Value |
|---|---|---|
| NFR-30 | Target availability during business hours | 99.9% |
| NFR-31 | Planned maintenance window | to be agreed with operations |
| NFR-32 | RPO — acceptable data loss | ≤ 5 min `?` |
| NFR-33 | RTO — recovery time | ≤ 1 h `?` |
| NFR-34 | Deploying a new version with no downtime | mandatory |

RPO and RTO are confirmed by the system owner —
[OQ-006](../transition/12-open-questions.md). They are marked `?` because a
figure nobody has agreed to is not a requirement, and because both drive real
cost: RPO decides the replication topology, RTO decides how much restore
rehearsal is enough.

## Scalability

| # | Requirement |
|---|---|
| NFR-40 | The application is stateless: horizontal scaling by adding instances |
| NFR-41 | Background jobs are idempotent and safe with several workers running |
| NFR-42 | No operation requires a single, particular application instance |
| NFR-43 | Heavy reads are served from a replica and never affect operational work |

NFR-41 is the one that is easy to claim and hard to hold: a job that is safe with
one worker and corrupts data with two fails only under load, on the day the load
arrives.

## Cutover window constraints

A separate group following from the
[big bang](../docs/02-decisions/ADR-0001-strategy-big-bang.md):

| # | Figure | Value |
|---|---|---|
| NFR-50 | Acceptable downtime window for the cutover | to be agreed; provisionally ≤ 8 h `?` |
| NFR-51 | Time for the full data migration | must fit inside the window with ×2 headroom |
| NFR-52 | Rollback time | ≤ 1 h, verified by a rehearsal |
| NFR-53 | Stabilization period with the standby environment | to be agreed; provisionally 30 days `?` |

**NFR-51 is a hard constraint on the project, not a performance goal.** If the
full transfer does not fit inside the agreed window, the cutover strategy changes
— a staged migration with historical data preloaded — and that requires a new
ADR. It is verified at the very first rehearsal, which is to say it must be
measured long before the live cutover rather than discovered on the night.

## Security and observability

Not repeated here. The requirements are in [08-security.md](08-security.md) and
[11-observability.md](11-observability.md), each numbered the same way so that a
release decision can cite them together with the figures above.

## How these requirements are verified

| Requirement group | Verified by | When |
|---|---|---|
| NFR-01 … NFR-08 | load tests in CI on the pre-production environment | weekly, and before every release |
| NFR-10 … NFR-14 | a load profile captured over a full month, then trials at ×3 peak | Phase 0, then before G2 |
| NFR-20 … NFR-24 | measurement against a copy of production data | Phase 0, then quarterly |
| NFR-30 … NFR-34 | **drills** — a planned shutdown and a restore from backup | before G2, then twice a year |
| NFR-40 … NFR-43 | a multi-instance run with concurrent job execution | on every release to stage |
| NFR-50 … NFR-53 | **migration rehearsals**, timed | every rehearsal, from the first one |

**A degradation of a figure between releases is grounds for not shipping the
release.** Performance is lost gradually and imperceptibly; it is caught only by
comparison with the previous measurement, which is why the comparison is
automated rather than requested.

The availability and recovery figures are verified by drills rather than by
calculation on paper. A backup that has never been restored from is not a backup,
and an RTO that has never been measured is a number in a document.

## Open questions

| # | Question | Blocks |
|---|---|---|
| NFR-Q1 | What are the RPO and RTO the business actually needs? | NFR-32, NFR-33, and the replication topology |
| NFR-Q2 | What downtime window is acceptable for the cutover? | NFR-50, and therefore the whole migration design |
| NFR-Q3 | How long must the old system stay available in standby after the cutover? | NFR-53, and the infrastructure budget |
| NFR-Q4 | Are there contractual availability obligations to customers or partners? | NFR-30, and whether 99.9% is enough |
