---
id: EPIC-003
title: Database schema inventory
phase: 0
owner: not assigned
status: todo
gate: G0
closes: [OQ-007]
---

# EPIC-003. Database schema inventory

## Why

523 entities in Oracle, an unknown number of tables in the legacy MySQL, two
PostgreSQL databases. 289 native queries and 43 `nativeQuery` tie the code to the
Oracle dialect. Moving to PostgreSQL
([ADR-0002](../docs/02-decisions/ADR-0002-database-postgresql.md)) requires
knowing exactly what is moving.

Separately: **Oracle may hold business logic invisible from the application
code** — PL/SQL packages, triggers, scheduler jobs. That is a potentially large
unestimated volume ([R-05](../transition/11-risks.md#r-05)).

## Result

A catalogue of all the data objects with a decision on each and with the
transformation rules.

## State, 2026-09-03

The main database has been read object by object; the result is
[transition/map/00-source-inventory.md](../transition/map/00-source-inventory.md).

| Task | State |
|---|---|
| TASK-0301 catalogue the tables | **done** for Oracle: 449 tables, 3 views, 4,855 columns, 437 indexes, 57 foreign keys, ~148M rows. Annual growth is not yet measured |
| TASK-0302 determine liveness | **half done**: the code side is measured — 119 of 449 tables are named in no Java repository ([map/01-schema-in-code.md](../transition/map/01-schema-in-code.md#1-table-coverage)). The access-statistics side is not started, and it is the half that turns a candidate into a verdict |
| TASK-0303 objects other than tables | **done**; [OQ-007](../transition/12-open-questions.md#oq-007) is closed: 8 logic objects in total |
| TASK-0304 assess data quality | started: the branch tree, the branch type values, the country/currency pair and the city names have been checked; the rest is not started |
| TASK-0305 work through the native queries | not started |
| TASK-0306 overlap with the first-generation monolith | **not started, and it is the blocker**: that database has no inventory at all |
| TASK-0307 a decision on every table | done for 433 of 452 as a **proposal by the designer**; 19 have no decision because nobody knows what the tables are; every decision needs the owner's confirmation |
| TASK-0308 design the target schema | table level done for all fourteen schemas ([the schema registry](../product/03-database/schemas/README.md)); column level done for D1 only |
| TASK-0302a column liveness | **done for the mapped tables**: 120 of 3,626 columns are touched by nothing, plus 1,229 columns in tables no entity maps |
| TASK-0309 decode the names | **done** for the decodable ones ([GLOSSARY.md](../GLOSSARY.md#inherited-names)); 8 names remain that need a person who knows |

Three facts change the plan:

- the risk of hidden logic in the database ([R-05](../transition/11-risks.md#r-05))
  did not materialize — there is nearly nothing to move;
- only **49 of 452 objects** map one-to-one onto a target table. The migration
  is a transformation, not a transfer, and the effort belongs in the estimate as
  such ([10-estimates.md](../transition/10-estimates.md));
- the mapping tables that TASK-0308 needs — number to readable value, per column
  — **already exist as 572 constants inside the entity classes** and have been
  extracted. They need confirming against the data, not inventing. The same scan
  found 119 hardcoded production row identifiers and 22 budget tables that no
  repository mentions
  ([map/01-schema-in-code.md](../transition/map/01-schema-in-code.md)).

## Tasks

### TASK-0301. Catalogue the tables

For each: the row count, the size, the annual growth, the columns with their
types, the keys, the indexes, the constraints, and the owning domain per the
[map](../product/02-domains.md).

**Acceptance:** the catalogue is complete; the totals match the database's size.

### TASK-0302. Determine which tables are live

From access statistics (the data from TASK-0106) and from code analysis.

**Acceptance:** every table is marked read / written / dead, stating the
observation period.

> After 12 years there are certainly dead tables. Weeding them out is the
> cheapest way to reduce the migration's volume.

### TASK-0303. Inventory the database objects other than tables

Views, triggers, sequences, stored procedures and packages, DB scheduler jobs,
access permissions, synonyms.

**Acceptance:** [OQ-007](../transition/12-open-questions.md#oq-007) is closed. If
business logic is found in the database, its volume is estimated and the Phase 2
estimate is recalculated.

### TASK-0304. Assess data quality

For every significant table: the share of `NULL`, referential integrity
violations, duplicates, values outside the acceptable range, "magic" values
instead of `NULL`, invalid dates.

**Acceptance:** a data-quality report; the classes of problem are listed with an
estimate of their scale.

> This report determines the volume of cleansing work. The earlier it is
> obtained, the earlier the cleansing starts **in the legacy** — where it has
> time and an owner.

### TASK-0305. Work through the native queries

All 289 `createNativeQuery` and 43 `nativeQuery = true`: what they do, which
Oracle features they use, and how they carry over to PostgreSQL.

**Acceptance:** for every query a decision: rewrite it using the new data-access
layer, rewrite it in PostgreSQL SQL, or drop it.

### TASK-0306. Establish the overlap with the legacy MySQL

Which data is stored only in MySQL, which is duplicated in Oracle, and how they
are kept consistent.

**Acceptance:** [OQ-012](../transition/12-open-questions.md#oq-012) is closed as
far as the data is concerned; the volume of the additional migration is
estimated.

### TASK-0307. Take a decision on every table

Migrate / consolidate with another / do not migrate.

**Acceptance:** zero tables without a decision. "Let us carry it over just in
case" does not count as a decision.

### TASK-0308. Design the target schema

Per the rules of [product/03-database/](../product/03-database/README.md): a schema
per domain, naming without transliteration, the mandatory columns, the types.

**Acceptance:** a "source → target" mapping table at the column level, with the
transformation rule and the verification method. It is also the input for
[EPIC-005](EPIC-005-data-migration.md).

### TASK-0309. Decode the inherited names

`bukrs`, `matnr`, `lifnr`, `werks` and the other abbreviations — into
[GLOSSARY.md](../GLOSSARY.md) with meaningful replacements.

**Acceptance:** not a single unintelligible name in the target schema; the
glossary is extended.

## Epic closure criteria

- [ ] The table catalogue is complete
- [ ] Liveness is determined from data
- [ ] OQ-007 is closed and the volume of logic in the database is estimated
- [ ] The data-quality report has been obtained
- [ ] All the native queries have been worked through
- [ ] OQ-012 is closed as far as the data is concerned
- [ ] A decision has been taken on every table
- [ ] The target schema is designed and the mappings are described
- [ ] The inherited names are decoded
