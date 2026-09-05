---
id: EPIC-007
title: Report inventory
phase: 0
owner: not assigned
status: todo
gate: G0
---

# EPIC-007. Report inventory

## Why

Reports are the most underestimated part of the volume. They are scattered across
god classes (`FinanceReportRestController` — 5,366 lines) and across reporting
methods inside domain services; some are produced **in the browser** by three
different libraries. How many there are in total and which of them are used is
unknown.

Reports are simultaneously:

- the part of the system most visible to the user;
- the part most sensitive to divergences during the reconciliation;
- the most likely area of dead code (over 12 years reports get created and
  forgotten).

## Result

A registry of reports with a decision on each and an effort estimate.

## Tasks

### TASK-0701. Compile the list of reports

All the sources: reporting controllers, reporting methods of domain services,
generation in the browser, printable forms, regular exports.

**Acceptance:** a list stating the source, the parameters, the output format and
the presumed consumers.

### TASK-0702. Determine liveness

From the data collected in TASK-0106: which reports were run during the
observation period, by whom, how often.

**Acceptance:** every report is marked live / dead / seasonal, stating the
observation period.

> Seasonal reports (annual, quarterly) will not fall inside a short observation
> window. They have to be identified separately, by interview rather than from
> statistics — otherwise a live annual report will be marked dead.

### TASK-0703. Take a decision on every report

Migrate / consolidate with another / do not migrate.

**Acceptance:** zero reports without a decision signed off by the domain owner.

> Weeding out the dead reports is one of the cheapest ways to reduce the
> project's volume. It is done once, here.

### TASK-0704. Classify by complexity

A simple list / a report with calculations / a summary report / a printable form;
synchronous or asynchronous by execution time.

**Acceptance:** the classification is complete; for every class the
implementation approach is defined.

### TASK-0705. Estimate the effort on a sample

Estimate five reports of different classes in detail; extrapolate to the
registry.

**Acceptance:** the Phase 2 estimate for reports is refined in
[07-estimates.md](../transition/10-estimates.md);
[R-14](../transition/11-risks.md#r-14) is reassessed.

### TASK-0706. Pin down the reference values for the reconciliation

For every report being carried over — the reference result on fixed data, for the
parity reconciliation with zero tolerance.

**Acceptance:** the reference values are stored and versioned.

### TASK-0707. Collect the requirements on the reporting subsystem

What the platform must be able to do
([ADR-0009](../docs/02-decisions/ADR-0009-reporting-and-exports.md)): formats,
templates, localization, asynchrony, delivery, permissions.

**Acceptance:** the requirements are handed over to
[Phase 1](../transition/plan/02-phase-1-platform.md).

## Epic closure criteria

- [ ] The list of reports is complete, those produced in the browser included
- [ ] Liveness is determined and the seasonal ones identified by interview
- [ ] A decision has been taken on every report
- [ ] The classification is done
- [ ] The effort estimate is refined on a sample
- [ ] The reference values for the reconciliation are pinned down
- [ ] The requirements on the reporting subsystem are handed over to Phase 1
