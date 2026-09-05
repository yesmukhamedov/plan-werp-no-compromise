---
id: EPIC-009
title: Baseline measurement
phase: 0
owner: not assigned
status: todo
gate: G0
---

# EPIC-009. Baseline measurement

## Why

[product/07-nfr.md](../product/07-nfr.md) contains placeholders instead of
numbers, and that is deliberate: setting target figures without knowing the
current ones is pointless — one either legitimizes a degradation or sets an
unreachable bar.

The project's rule: **the new system has no right to be slower than the old one
in any scenario.** The only way to verify that is to measure the old one.

## Result

The NFR tables filled in: for every figure — "today", "no worse than", "target".

## Tasks

### TASK-0901. Switch on observability in the legacy

Collection of response times per endpoint, request rates, errors. The minimal
intervention in the legacy that is acceptable under the freeze.

**Acceptance:** the data is being collected; the observation period has started.

> To be done in the first week of Phase 0 together with TASK-0106: the longer the
> observation period, the more reliable the profile. A month is better than a
> week.

### TASK-0902. Capture the load profile

At least one full month: the daily and weekly profile, the peaks.

**Acceptance:** the profile is built; the peak periods are identified and
explained (the month close, payroll accrual, stocktaking, seasonality).

> Peak periods in an ERP exceed the ordinary load several times over. Designing
> for the average load produces a system that falls over at the end of the month.

### TASK-0903. Measure response times

Per endpoint, the 50th/95th/99th percentiles. Separately — the most frequent and
the slowest ones.

**Acceptance:** the table is filled in; the endpoints that clearly need reworking
are identified.

### TASK-0904. Measure the database figures

The heaviest queries, their execution time, index usage, table sizes, annual
growth, the database's size.

**Acceptance:** the data is obtained and handed over to
[EPIC-003](EPIC-003-schema-inventory.md).

### TASK-0905. Measure the frontend figures

Load time, time to interactive, bundle size, the time to open typical screens.

**Acceptance:** the table is filled in.

### TASK-0906. Measure the volumes

The number of users, concurrent sessions (ordinary and peak), the size of the
file store, the number of files.

**Acceptance:** the data is obtained and handed over to capacity planning and to
[EPIC-005](EPIC-005-data-migration.md) (the volume of the file transfer).

### TASK-0907. Test the hypotheses about the problems

Confirm or refute by measurement: the impact of `show-sql` in production, the
presence of N+1, endpoints without pagination, the cost of arbitrary filtering
([product/10-performance.md](../product/10-performance.md#what-is-known-about-the-current-problems)).

**Acceptance:** every hypothesis is confirmed or refuted by data.

### TASK-0908. Fill in the NFRs

**Acceptance:** no placeholders are left in
[07-nfr.md](../product/07-nfr.md); every figure has three values.

## Epic closure criteria

- [ ] Observability in the legacy is running
- [ ] The load profile has been captured over a full month
- [ ] Response times are measured per endpoint
- [ ] The database and frontend figures are measured
- [ ] The volumes are measured
- [ ] The hypotheses about the problems are tested
- [ ] The NFR tables are filled in
