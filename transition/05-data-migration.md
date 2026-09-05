---
id: TRANS-05
title: Data migration
status: draft
---

# Data migration: Oracle/MySQL → PostgreSQL

The riskiest technical part of the project: code can be rewritten from scratch,
data cannot. Required by
[ADR-0002](../docs/02-decisions/ADR-0002-database-postgresql.md).

## What is migrated

| Source | Content | Volume |
|---|---|---|
| Oracle (`werp_java_back_v2`) | 523 entities + the audit tables + database objects | to be measured |
| MySQL (`werp_jsf`) | the legacy monolith's data; the overlap with Oracle needs establishing | to be measured |
| PostgreSQL (`werp_crm`, `werp_call_center`) | CRM and the call centre | to be measured |
| The file store | attachments and documents | to be measured |

**An open question of the first order:** how far the legacy JSF's data (MySQL)
overlaps with Oracle. If the legacy monolith holds data of its own that is not
represented in Oracle, the migration volume is substantially larger than
estimated.
→ [OQ-012](12-open-questions.md), to be closed before gate G0.

## Principles

1. **The migration is code, not a one-off script.** It lives in the repository,
   is reviewed, is covered by tests, is run with a single command and is
   reproducible.
2. **Idempotency.** A repeat run on the same input produces the same result.
3. **The source is read-only.** The migration tool physically has no permission
   to write to the legacy databases.
4. **Reconciliation is part of the migration**, not a subsequent stage. A tool
   that moved the data and did not verify it has not done its job.
5. **Every transformation is explainable.** For any row in the new database one
   can say where it came from and by which rule it was transformed.
6. **Nothing is discarded silently.** A row that failed to transfer lands in the
   rejection log with a reason; an empty rejection log is also a result that has
   to be explained.

## Stages

### S1. Schema inventory (Phase 0)

[EPIC-003](../backlog/EPIC-003-schema-inventory.md). For every source table the
following is recorded:

- the row count, the size, the annual growth;
- whether it is actually used (by application queries, by reports, by external
  systems);
- the owning domain per the [map](../product/02-domains.md);
- the decision: **migrate** / **consolidate with another table** / **do not
  migrate**;
- the rules for transforming types and names;
- data quality: the share of `NULL`, referential integrity violations,
  duplicates.

Separately, an inventory is taken of the **database objects invisible from the
application code**: views, triggers, sequences, stored procedures, DB scheduler
jobs, access permissions. If Oracle holds business logic in PL/SQL, that is a
separate and as yet unestimated amount of work
([OQ-007](12-open-questions.md)).

### S2. Designing the mappings

A "source → target" mapping table at the column level:

| Source | Target | Transformation | Verification |
|---|---|---|---|
| table.column | schema.table.column | the rule | how to make sure |

Special attention to:

- **Names.** Inherited abbreviations (`bukrs`, `matnr`, `lifnr`, `werks`) are
  replaced with meaningful ones; the name mapping table is part of the glossary
  ([GLOSSARY.md](../GLOSSARY.md)) and part of the migration tool.
- **Empty string versus `NULL`.** Oracle does not distinguish them, PostgreSQL
  does. Every text column gets an explicit decision.
- **Dates and times.** Conversion to UTC with the source zone stated explicitly.
- **Money.** Precision and rounding per
  [the database model](../product/03-database/README.md); the result is reconciled to the
  cent.
- **Boolean values.** `char(1)`/`number(1)` → `boolean` with an explicit list of
  acceptable input values.
- **Identifiers.** Preserving or reissuing them is a decision taken once for the
  whole system; preserving simplifies the reconciliation and the rollback,
  reissuing is cleaner. The default is to preserve, with the mapping recorded.

### S3. The migration tool

- A separate part of the monorepo (`migration/` per
  [ADR-0007](../docs/02-decisions/ADR-0007-repo-layout.md)).
- The transfer order follows the domain dependency graph.
- Batch processing with checkpoints: a failure does not require starting over.
- Detailed logging: how much was read, transferred, rejected, and for which
  reasons.
- Timing of every step — the migration time is a hard constraint
  ([07-nfr.md](../product/07-nfr.md#cutover-window-constraints)).

### S4. Data quality

Production data accumulated over 12 years contains things the new schema does not
permit. **This is discovered at the very first rehearsal and is a normal result,
not an emergency.**

Expected findings: referential integrity violations, duplicates in reference
lists, invalid dates, negative quantities, "magic" values instead of `NULL`,
inconsistency between duplicated domains
([P-04](../docs/00-context/02-pain-points.md#p-04-domains-implemented-twice)).

For every class of problem there is an explicit decision taken **together with
the business**: fix it, carry it over as it is with a marker, or do not carry it
over. The decision is documented. Silently "repairing" data during the migration
is unacceptable — that is exactly how money gets lost.

Data cleansing, where possible, is **performed in the legacy before the
cutover**, not at the moment of migration: that way it has time, verification and
an owner.

### S5. Rehearsals

At least four full rehearsals against a fresh copy of production data.

Every rehearsal produces a report: the execution time, the number of transferred
and rejected rows, the reconciliation results, the data-quality problems found,
the rollback time. A rehearsal without a report does not count.

| Rehearsal | Goal |
|---|---|
| R1 | the tool runs end to end; identifying data-quality problems |
| R2 | all the R1 findings are closed; timing measured |
| R3 | we fit inside the window; a full reconciliation; a rollback rehearsal |
| R4 | confirmation of stability; the result matches R3 |

R3 and R4 must pass consecutively and successfully — that is the condition for
admission to the live cutover.

### S6. The live migration

Per the procedure in [01-cutover-strategy.md](07-cutover.md).

## Reconciliation

The mandatory minimum after every run:

| Level | What is verified | Tolerance |
|---|---|---|
| Counts | the row count per table, source ↔ target | 0 (apart from explained rejections) |
| Checksums | aggregates over the key numeric columns | 0 |
| Financial | balances, turnovers, receivables per contract | **0, to the cent** |
| Referential | the absence of dangling references | 0 |
| Sampled | a one-by-one comparison of N random records | 0 |
| Scenario | the key reports of the old and the new system match | 0 |

In more detail — [03-parity-verification.md](06-parity-verification.md).

## Files and attachments

A separate track: the file store's volume may exceed the database's, and copying
files is the longest part of the cutover.

**The files are copied in advance**, before the cutover window, with a subsequent
re-synchronization of whatever changed. Only the delta falls inside the cutover
window. Integrity is verified by checksums.

## What must not be done

- Migrating straight from one production database to another without a rehearsal.
- Editing data in the source with the migration tool.
- Considering the migration successful without a reconciliation.
- Leaving data-quality decisions to a developer's discretion at the moment of the
  cutover.
- Carrying tables over "just in case", without establishing whether they are
  needed.
