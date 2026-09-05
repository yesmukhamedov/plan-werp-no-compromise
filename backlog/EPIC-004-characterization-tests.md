---
id: EPIC-004
title: Characterization tests
phase: 0
owner: not assigned
status: todo
gate: G0
depends_on: [EPIC-002, EPIC-011]
---

# EPIC-004. Characterization tests

## Why

The current system has **4 test files across 354,761 lines**. That means no
executable description of how the system behaves exists.

Under a big bang that is critical: the only way to prove the new system's
equivalence is to compare it with the old one. The shadow run covers reads but
**does not cover calculations and write operations** — and that is exactly where
the risk is concentrated.

## What they are

Characterization tests do not verify that the system works **correctly**. They
record how it works **now** — bugs included, if there are any.

They are the reference for the parity reconciliation
([transition/06-parity-verification.md](../transition/06-parity-verification.md)),
not a set of requirements. A test that pinned down incorrect behaviour is a
success: now people know about it.

## Priorities

By descending risk:

| Priority | What | Why |
|---|---|---|
| 1 | Compensation calculation | 7,598 lines in a single class; special cases have surely accumulated; an error = people's money |
| 2 | Accounting operations and journal entries | a 62,776-line domain; an error = the company's money |
| 3 | Contract calculations | payment schedules, receivables, penalties |
| 4 | Warehouse stock balances | the result of an operation on a balance |
| 5 | Reports with calculations | summary figures |

## Tasks

### TASK-0401. Prepare the test bench

An isolated instance of the legacy with a fixed data set, reproducible. The tests
must be re-runnable and produce the same result.

**Acceptance:** the bench comes up with one command; a repeat run produces an
identical result.

### TASK-0402. Collect the input data sets

Real cases from production data, **anonymized**, edge cases included: maximum
amounts, zero values, rare combinations of conditions, the end of a period.

**Acceptance:** for every priority area at least N cases are collected, edge
cases included; the data is anonymized.

> A test's value is determined by whether it covers the special cases. The
> ordinary case the new system will reproduce anyway.

### TASK-0403. Pin down compensation calculation

Table-driven tests: input → the reference result, including all the intermediate
accruals and deductions.

**Acceptance:** the tests pass against the legacy; the reference values are
versioned; all the known kinds of accrual are covered.

### TASK-0404. Pin down the accounting operations

Journal entries, balances, turnovers, reconciliations.

**Acceptance:** the tests pass against the legacy; the reference values are
versioned.

### TASK-0405. Pin down the contract calculations

**Acceptance:** the tests pass against the legacy; the reference values are
versioned.

### TASK-0406. Pin down the warehouse operations

**Acceptance:** the tests pass against the legacy; the reference values are
versioned.

### TASK-0407. Collect the anomalies discovered

Everything that looks like a bug in the old system while the tests are being
written goes into a separate list with a decision from the business: do we
reproduce it or fix it.

**Acceptance:** a list of anomalies with a decision on each, in writing.

> This is a valuable by-product of the epic: it makes visible the bugs nobody
> knew about — before the cutover rather than after.

## Epic closure criteria

- [ ] The test bench is reproducible
- [ ] The data sets are collected and anonymized
- [ ] All the areas of priorities 1–4 are covered
- [ ] The reference values are versioned in the repository
- [ ] The list of anomalies is compiled and the decisions are taken in writing

## How it is used later

- A mandatory condition for starting domains D5 and D6 in
  [Phase 2](../transition/plan/03-phase-2-domains.md).
- The reference for scenario parity in
  [Phase 4](../transition/plan/05-phase-4-parity-and-cutover.md).
- Part of the scenario registry
  ([EPIC-011](EPIC-011-scenario-registry.md)).
