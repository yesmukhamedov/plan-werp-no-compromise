---
id: PROD-14
title: Runbooks
status: draft
---

# Runbooks

A runbook is an instruction for the on-call engineer: what to do when something
has broken, written so that a person who did not write this code can follow it at
night.

**This is not documentation "for the future".** It is a condition for being
admitted to the cutover
([transition/07-cutover.md](../transition/07-cutover.md#conditions-for-admission-to-the-cutover))
and part of the Domain DoD. **A domain without a runbook does not count as
ready.**

---

## The form

Every runbook answers five questions and not one more:

```markdown
# <The symptom as the on-call engineer sees it>

## How to tell that this is it
Which alert, which metrics, what the users see.

## How urgent it is
The business impact. Whether it can wait until morning.

## What to check
Numbered diagnostic steps, starting from the most likely.

## What to do
Specific commands and actions. What must not be done.

## Who to call
The domain owner, a developer, operations — with the escalation conditions.
```

A runbook is written **from the symptom**, not from the cause: the on-call
engineer sees "users cannot post an operation", not "the connection pool broke".

The "what must not be done" line is the one that earns its place at four in the
morning. In this system it is usually specific and consequential: do not delete
rows from a movement table to fix a balance, do not edit a posted entry, do not
re-run a payroll run in place.

## Rules

| # | Rule |
|---|---|
| RB-01 | **A runbook exists before it is needed.** One written after the first incident is a post-mortem, not a runbook |
| RB-02 | **A runbook is verified by execution** — a drill on pre-production. An unverified runbook is equivalent to a missing one |
| RB-03 | **Every alert links to a runbook.** An alert without one is useless at night ([OBS-32](11-observability.md#alerts)) |
| RB-04 | **A runbook is updated after every incident** in which it proved inaccurate |
| RB-05 | **A runbook is not the place to explain the architecture.** A link to the documentation, not a retelling of it |
| RB-06 | Every runbook names the domain owner and the escalation path, by role rather than by person |

RB-02 is the one that separates a real runbook from a plausible one. A procedure
that has never been executed contains at least one step that does not work, and
it is discovered at the worst possible moment.

## The mandatory set

### Platform

- The application is not responding
- A high error share
- Response time degradation
- The database is unavailable
- The connection pool is exhausted
- The background job queue is overflowing
- The outbox is not draining — events are accumulating undelivered
- The file store is unavailable
- Problems logging in
- The identity provider is unavailable
- The disk is full

The outbox runbook is new relative to the old system and is not optional: an
outbox that stops draining is silent, and every domain that depends on an event
degrades gradually without a single error
([04-backend rule 7](04-backend/rules/07-cross-domain.md)).

### Domains

One per domain: typical failures, specific operations, what must not be touched
without the owner. **Special attention to the domains dealing with money: D5 and
D6.**

The design creates four specific situations that need a runbook each, because in
every one the wrong instinct is the destructive one:

| Symptom | The wrong instinct | The runbook exists to say |
|---|---|---|
| A ledger reconciliation reports a divergence | correct the balance | `account_balance` is derived — rebuild it, then investigate the lines |
| A subledger does not agree with its control account | post an adjusting entry | find the missing `open_item` first; an adjustment hides the cause |
| A stock balance is wrong | edit the balance row | `stock_movement` is the truth; add a compensating movement, never edit |
| A payroll run produced a wrong figure | fix the run | a recalculation is a **new run**; the old one stays |

### Integrations

- An external system is unavailable — one per integration in
  [CTX-04](../docs/00-context/04-current-integrations.md)
- `bridge` is not responding
- A data divergence with an external system
- A payment gateway is returning duplicates

### Data

- Restoring from a backup
- A data divergence or corruption has been discovered
- Rolling back a failed schema migration
- A cross-domain orphan-reference report is non-empty

The last one follows from the architecture: references across domains carry no
database constraint, and a nightly job reports orphans as a metric
([01-architecture.md](01-architecture.md#modules-and-boundaries)). Somebody has
to know what to do when it is not zero.

### Cutover — Phase 4 only

- The migration does not fit inside the window
- The reconciliation revealed a divergence
- Rollback O1
  ([transition/08-rollback.md](../transition/08-rollback.md#o1-early-rollback))
- Rollback O2
- The smoke tests failed after the switchover

## Incident post-mortems

After every significant incident — a post-mortem **without looking for someone to
blame**:

| # | Section | |
|---|---|---|
| RB-10 | what happened, on a timeline | |
| RB-11 | how it was discovered, and how long that took | the number that says whether the alerting works |
| RB-12 | what was done | |
| RB-13 | why it became possible | **the cause is in the system, not in the person** |
| RB-14 | what we change | the code, the runbook, the alert, or the process — at least one |

RB-11 and RB-14 are the two that make the exercise worth the hour. Time to
discovery is the honest measure of the observability investment; and **an
incident that led to no change will happen again**, which is why RB-14 requires
naming something concrete rather than "be more careful".

Post-mortems are stored together with the runbooks.

## On-call duty

| # | Requirement |
|---|---|
| RB-20 | The on-call shift is formed **before** the cutover, not after |
| RB-21 | Reinforced on-call duty for the first two weeks after the cutover, with the domain developers involved |
| RB-22 | Permanent on-call duty after stabilization — **without the migration developers** |
| RB-23 | Every runbook has been executed as a drill by someone on the rota, not only by its author |

RB-22 is the real handover test. On-call duty that still depends on the people
who wrote the migration means the system has not been handed to operations; it
has been left on manual support by its authors
([transition/plan/06-phase-5-decommission.md](../transition/plan/06-phase-5-decommission.md#6-handover-to-operations)).

RB-23 is the same test applied to the documents: a runbook only its author can
follow is a runbook that works only while its author is reachable.

## Open questions

| # | Question | Affects |
|---|---|---|
| RB-Q1 | Who is on the rota, and what are the hours? | RB-20 — and there is no rota today |
| RB-Q2 | What is the escalation path per domain, given that no domain has an owner yet? | RB-06, and [DOM-Q6](02-domains.md#what-must-be-confirmed-with-the-business-before-g1) |
| RB-Q3 | Which incidents count as significant enough for a post-mortem? | RB-10 … RB-14 |
