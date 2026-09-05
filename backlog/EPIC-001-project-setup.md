---
id: EPIC-001
title: Project setup
phase: 0
owner: not assigned
status: todo
blocks: [EPIC-002, EPIC-003, EPIC-004, EPIC-006, EPIC-007, EPIC-009, EPIC-010, EPIC-011]
---

# EPIC-001. Project setup

## Why

No inventory epic can be carried out while there are no people to carry it out
and no people to answer the questions. This epic is the project's first week.

## Result

- The team is assembled and the roles are assigned by name.
- Every domain has an owner on the business side.
- The time of the people who hold the knowledge is booked.
- The working cadence is established and running.

## Tasks

### TASK-0101. Confirm the team composition

Headcount, roles, share of time, the period of availability.

**Acceptance:** [OQ-001](../transition/12-open-questions.md#oq-001) is closed;
the estimates in [07-estimates.md](../transition/10-estimates.md) are converted
into a calendar.

### TASK-0102. Appoint the domain owners

One person per domain from the [map](../product/02-domains.md). The owner answers
questions, takes decisions about divergences and signs off acceptance.

**Acceptance:** the "domain → owner" table is filled in completely; the owners
have been notified and have confirmed their readiness.

### TASK-0103. Assign the project roles

The project lead, the architect, the data owner, the infrastructure owner, the
cutover lead (may be appointed later, but the role is declared right away).

**Acceptance:** the roles are assigned by name; each one's area of
responsibility is described.

### TASK-0104. Book the time of the people who hold the knowledge

Developers and users who know the current system. This is the limiting factor of
Phase 0 ([R-08](../transition/11-risks.md#r-08)).

**Acceptance:** the interview schedule for the first month is agreed.

### TASK-0105. Start the cadence

The weekly report, demonstrations every two weeks, the monthly retrospective and
risk review
([00-roadmap.md](../transition/plan/00-roadmap.md#cadence)).

**Acceptance:** the meetings are in the calendar; the first report is out.

### TASK-0106. Switch on usage data collection in the legacy

Endpoint calls, report runs, table queries. Without this data, "migrate / do not
migrate" decisions are taken from memory
([OQ-014](../transition/12-open-questions.md#oq-014)).

**Acceptance:** the collection is running; the data is accumulating; the first
weekly report has been received.

> To be done in the first week: the earlier the collection starts, the more
> representative the sample will be by the time the decisions are taken. A month
> of data is better than a week.

### TASK-0107. Announce the project

Tell the users and the business: what we are doing, why, what will change, and
when the freeze comes into force.

**Acceptance:** the announcement has been made; the questions have been collected
and answered.

> A freeze introduced without an announcement is perceived as sabotage on
> development's part
> ([05-freeze-policy.md](../transition/09-freeze-policy.md#communication)).

## Epic closure criteria

- [ ] OQ-001 is closed
- [ ] All the domains have owners
- [ ] The project roles are assigned
- [ ] Usage data collection is running
- [ ] The cadence is started
- [ ] The project is announced
