---
id: EPIC-005
title: The data migration tool
phase: 0 (preparation) → 4 (execution)
owner: not assigned
status: todo
depends_on: [EPIC-003]
---

# EPIC-005. The data migration tool

## Why

Code can be rewritten from scratch, data cannot. Transferring from Oracle and
MySQL into PostgreSQL is the project's riskiest technical part
([transition/05-data-migration.md](../transition/05-data-migration.md)).

The tool is **code in the repository**, not a one-off script: it is reviewed,
covered by tests, run with one command and executed five times (four rehearsals
and the live run).

## When

The transformation rules are designed in Phase 0 (on the results of
[EPIC-003](EPIC-003-schema-inventory.md)); the tool itself is written after G1,
once the stack is known and the target schema exists; it is executed in Phase 4.

## Tasks

### TASK-0501. Design the transformation rules

Based on the mapping table from TASK-0308. To be worked out separately:

- empty string versus `NULL` (Oracle does not distinguish them, PostgreSQL does)
  — for every text column;
- dates and times → UTC with the source zone stated explicitly;
- money: precision and rounding, verified to the cent;
- boolean values: `char(1)` / `number(1)` → `boolean`;
- identifiers: preserve or reissue (the default is to preserve).

**Acceptance:** every column of the target schema has a rule and a verification
method.

### TASK-0502. Write the tool

The transfer order follows the domain dependency graph, with batch processing,
checkpoints, detailed logging and per-step timing.

**Acceptance:** it runs with one command; it is idempotent; it **has no write
permission on the source**; a repeat run produces the same result.

### TASK-0503. Implement the reconciliation

All the levels from
[02-data-migration.md](../transition/05-data-migration.md#reconciliation):
counts, checksums, financial (zero tolerance), referential, sampled, scenario.

**Acceptance:** the reconciliation is part of the run rather than a separate
step; the report is produced automatically.

> A tool that moved the data and did not verify it has not done its job.

### TASK-0504. Implement the rejection log

Every row that cannot be transferred, with a reason.

**Acceptance:** the log is produced; an empty log also requires an explanation.

### TASK-0505. Transfer of files and attachments

A separate track: copying in advance + re-synchronizing the delta inside the
cutover window; integrity verified by checksums.

**Acceptance:** the volume is measured; the copying time is measured; only the
delta falls inside the cutover window.

### TASK-0506. Migration of accounts

Passwords are never carried over in plaintext under any circumstances
([ADR-0006](../docs/02-decisions/ADR-0006-auth-model.md)).

**Acceptance:** the decision on the hashing scheme or on a forced password change
is taken and implemented.

### TASK-0507. The rehearsal pipeline

Stand up a clean environment → restore a copy of production data → run the
migration → reconcile → publish the report. By a button and on a schedule.

**Acceptance:** the pipeline works; the report is published automatically.

### TASK-0508. Rehearsals R1–R4

Per
[02-data-migration.md](../transition/05-data-migration.md#s5-rehearsals).

**Acceptance:** four rehearsals carried out, each with a report; R3 and R4
successful consecutively; R3 included a rollback rehearsal; the time fits inside
the window with ×2 headroom.

## Epic closure criteria

- [ ] The transformation rules cover every column of the target schema
- [ ] The tool is idempotent and does not write to the source
- [ ] The reconciliation is built into the run
- [ ] Files and accounts migrate
- [ ] The rehearsal pipeline works
- [ ] R3 and R4 have passed consecutively and successfully
- [ ] The migration time fits inside the window with ×2 headroom
