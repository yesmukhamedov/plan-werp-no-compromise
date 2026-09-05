---
id: PROD-11
title: Observability
status: draft
---

# Observability

The requirement is
[NC-10](../docs/01-principles/01-no-compromise.md#nc-10). Where things stand
today: 1,443 calls to `System.out.print*`, 31 `printStackTrace()`, SQL printing
enabled in all profiles
([P-07](../docs/00-context/02-pain-points.md#p-07-diagnostics-through-systemout)).

Observability is **part of the platform, written in Phase 1**, not something
added just before launch. Under a big bang it is needed from day one: the shadow
run, the migration rehearsals and the cutover are impossible without it.

---

## Three sources, one identifier

| Source | Answers the question | Main use |
|---|---|---|
| Logs | what exactly happened in a specific request | incident analysis |
| Metrics | how the system as a whole is feeling | alerts, trends |
| Tracing | where in the chain the time went | finding the bottleneck |

They are linked by the **request identifier**: with it one moves from an alert to
a trace, and from a trace to the logs. Without it the three are three separate
tools and an incident takes an hour instead of a minute.

## Logs

| # | Requirement |
|---|---|
| OBS-01 | Logs are **structured** and machine-readable |
| OBS-02 | `System.out`, `printStackTrace` and SQL printing are forbidden and checked in CI |
| OBS-03 | Mandatory fields: time, level, request identifier, user identifier, domain, operation, duration, result |
| OBS-04 | **Personal data and secrets never reach the logs** — a platform masking mechanism, not developer discipline |
| OBS-05 | The levels are meaningful: `ERROR` requires human intervention, `WARN` requires attention, `INFO` is a significant business event, `DEBUG` is development only |
| OBS-06 | Retention and volume follow the regulator's requirements ([OQ-003](../transition/12-open-questions.md)) |

OBS-04 is stated as a platform requirement deliberately. Masking that depends on
every developer remembering which field is personal fails on the first field
somebody forgets, and the failure is discovered by someone reading the logs who
should not have been able to.

## Metrics

### Technical

Request rate and duration per endpoint with percentiles, the error share, the
database connection pool, database query duration, the background job queue
depth, resource consumption, application start-up time.

### Business

| # | Requirement |
|---|---|
| OBS-10 | Every domain declares business metrics together with its owner |
| OBS-11 | A domain with no business metric is not complete |

**Their absence is the typical mistake.** It is precisely the business metrics
that show the system has broken *logically* while every technical figure is
formally green: contracts created per hour, operations posted, cases handled,
export volume, failed logins.

Examples the design already implies, one per money domain:

| Domain | Metric | What its silence would mean |
|---|---|---|
| D5 | entries posted per hour; open items cleared per day | posting is failing silently, or a subledger has stopped feeding the ledger |
| D6 | payslips calculated per run; runs reaching `POSTED` | a payroll run is stuck between calculated and approved |
| D7 | movements per hour; balance reconciliation divergence | the derived balance has drifted from the movements |
| D8 | maintenance slots closed per day; slots going overdue | field work has stopped and nobody has phoned yet |

### Reconciliation metrics

The design puts four scheduled reconciliations in the system, and each publishes
its divergence as a metric with an alert:
`EntryBalanceReconciliation`, `SubledgerReconciliation`, the stock balance
rebuild, and the cross-domain orphan-reference job.

| # | Requirement |
|---|---|
| OBS-12 | Every derived table has a reconciliation job, and its divergence is a metric |
| OBS-13 | A non-zero divergence is an alert, not a report line somebody reads next quarter |

### Project metrics

For the duration of the cutover — a separate group: the share of divergences in
the shadow run per domain, the migration duration per step, the number of
rejected rows. They are published weekly and are the main readiness indicator
([transition/06-parity-verification.md](../transition/06-parity-verification.md#reporting)).

## Tracing

| # | Requirement |
|---|---|
| OBS-20 | End-to-end: from the browser request, through `bridge` and the application, to the database query |
| OBS-21 | The trace identifier is returned to the client in every error response ([05-api rule 5](05-api/rules/05-errors.md)) |
| OBS-22 | Background jobs and event processing are traced on a par with requests |
| OBS-23 | An outbox event carries the trace identifier of the request that produced it |

OBS-21 is what turns a support request from "it broke" into a specific request in
the logs: the user quotes the identifier and the on-call engineer finds it in
seconds. OBS-23 extends that across an asynchronous boundary, which is where a
trace is normally lost.

## Alerts

The five rules that separate alerts that work from alerts that get ignored:

| # | Rule |
|---|---|
| OBS-30 | **An alert equals an action.** If nobody needs to react, it is a metric, not an alert |
| OBS-31 | **By symptom, not by cause.** "Users cannot create a contract" is more useful than "CPU load is 90%" |
| OBS-32 | **The recipient and the runbook are known.** An alert without a runbook is useless at night ([14-runbooks.md](14-runbooks.md)) |
| OBS-33 | **Verified by firing.** A fake alert is discovered only at the moment it was needed |
| OBS-34 | **Noise is removed.** An alert that gets ignored regularly is switched off or fixed — never tolerated, because it devalues all the others |

OBS-34 is the one that decides whether the other four survive year two. A single
alert that fires nightly for no reason teaches an entire on-call rotation to
dismiss alerts without reading them.

## Dashboards

| Dashboard | For whom | Must answer |
|---|---|---|
| System status | the on-call shift | is anything broken right now, and where |
| Domain | the domain owner and their developers | is this domain healthy, technically and in business terms |
| Business figures | the business | is the company's work flowing |
| Reconciliation | the finance and warehouse owners | do the derived figures still agree with their sources |
| Cutover | the cutover lead, only during Phase 4 | are we ready, by the numbers |

## Readiness and liveness

| # | Requirement |
|---|---|
| OBS-40 | The application reports readiness to accept traffic and liveness **separately** |
| OBS-41 | The readiness check takes into account the database and the critical dependencies |
| OBS-42 | Zero-downtime deployment relies on these checks ([NFR-34](07-nfr.md#availability)) |

Conflating the two is a common and expensive mistake: an instance that is alive
but not yet ready receives traffic and fails it, and an instance that is
temporarily not ready gets killed and restarted in a loop.

## What is checked in CI

| Check | Rule |
|---|---|
| zero `System.out`, `printStackTrace`, `console.log` | OBS-02, [FE-22](06-frontend/checks.md) |
| zero `show-sql` in non-production profiles | OBS-02 |
| every new endpoint is covered by a metric and a trace, provided by the platform rather than by hand | OBS-20 |
| every alert definition references a runbook | OBS-32, [RB-03](14-runbooks.md#rules) |
| every masked field stays masked — a test asserting it never appears in a log line | OBS-04 |

## Open questions

| # | Question | Affects |
|---|---|---|
| OBS-Q1 | What log retention does the regulator require? | OBS-06, and the storage budget |
| OBS-Q2 | Which business metrics does each domain owner actually want? | OBS-10, OBS-11 — and there are no owners yet |
| OBS-Q3 | Who receives an alert outside business hours, from the first day of the cutover? | OBS-32, and the on-call rota in [14-runbooks.md](14-runbooks.md) |
