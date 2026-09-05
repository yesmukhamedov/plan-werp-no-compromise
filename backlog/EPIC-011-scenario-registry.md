---
id: EPIC-011
title: Business scenario registry
phase: 0
owner: not assigned
status: todo
gate: G0
---

# EPIC-011. Business scenario registry

## Why

The endpoint inventory
([EPIC-002](EPIC-002-contract-inventory.md)) answers the question "what the
system can do technically". It does not answer the question **"what people do in
it"** — and that is what determines the completeness of the new system.

The scenario registry is Phase 0's most valuable artefact, because it serves four
purposes at once:

1. the definition of the new system's completeness;
2. the plan for the end-to-end tests
   ([product/09-quality.md](../product/09-quality.md));
3. the plan for manual user acceptance;
4. the basis of scenario parity
   ([transition/06-parity-verification.md](../transition/06-parity-verification.md#level-3-scenario-parity)).

## Scenario format

```markdown
## SC-NNN. <Title from the user's point of view>

**Domain:** D<N>
**Role:** who performs it
**Frequency:** daily / weekly / monthly / rarely
**Criticality:** blocking / important / auxiliary

**Precondition:** the state it starts from
**Steps:** what the user does
**Result:** what should come out of it
**How to verify:** the observable sign of success
**Special cases:** the known exceptions and edge situations
```

One scenario — one verifiable piece of business value. "Open the list of
contracts" is not a scenario; "arrange a contract with a customer, from the
request to the first payment" is.

## Tasks

### TASK-1101. Collect the scenarios per domain

Interviews with users and domain owners, observing them at work, analysing the
endpoint usage data (TASK-0106).

**Acceptance:** the scenarios are collected across all 13 domains; each domain's
owner has confirmed that the list for their domain is complete.

> The limiting factor is the users' availability. It is planned in advance
> (TASK-0104).

### TASK-1102. Mark up criticality and frequency

**Acceptance:** every scenario is marked up; the blocking scenarios are singled
out.

> The blocking scenarios determine what must work at the moment access is opened
> after the cutover, and what the smoke tests check.

### TASK-1103. Identify the workarounds

Over 12 years users have developed ways of doing what the system does not support
directly: exporting to Excel and typing the result back in, using a field for
something other than its purpose, arrangements made outside the system.

**Acceptance:** the workarounds are listed; each has a decision — support the
scenario directly in the new system, or keep the workaround.

> **The epic's most valuable task.** Workarounds are unmet requirements. If they
> are not identified, the new system will reproduce the same inconveniences and
> the users will keep working the same way. And if a workaround is removed without
> the scenario being supported, work stops.

### TASK-1104. Link the scenarios to the endpoints

Which endpoints are involved in each scenario.

**Acceptance:** the links are described; endpoints involved in no scenario are
identified — they are candidates for removal in
[EPIC-002](EPIC-002-contract-inventory.md).

### TASK-1105. Link the scenarios to the reports

**Acceptance:** the links are described; reports linked to no scenario are handed
over to [EPIC-007](EPIC-007-reports-inventory.md) as candidates for removal.

### TASK-1106. Define the scenarios for the smoke tests

The minimal set of blocking scenarios verified on the night of the cutover before
access is opened
([transition/07-cutover.md](../transition/07-cutover.md#the-course-of-the-cutover)).

**Acceptance:** the set is defined, agreed with the domain owners, and executable
within a limited time.

### TASK-1107. Define the scenarios for the parity reconciliation

Which scenarios are reconciled with zero tolerance (finance, calculations,
reports) and which are reconciled as agreed.

**Acceptance:** the markup is done and agreed with the domain owners.

## Epic closure criteria

- [ ] The scenarios are collected across all the domains and confirmed by the
      owners
- [ ] Criticality and frequency are marked up
- [ ] The workarounds are identified and the decisions taken
- [ ] The scenarios are linked to the endpoints and the reports
- [ ] The set of smoke tests is defined
- [ ] The markup for the parity reconciliation is done
