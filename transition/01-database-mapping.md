---
id: TRANS-01
title: Database mapping
status: draft
---

# Database mapping

How the existing schema turns into the target one
([product/03-database/](../product/03-database/README.md)). The transformation rules
are here; the object-by-object map is in
[map/00-source-inventory.md](map/00-source-inventory.md) and the per-domain maps
are in [map/](map/README.md).

This document is the source of requirements for the migration tool
([EPIC-005](../backlog/EPIC-005-data-migration.md)) and for designing the target
schema ([EPIC-003](../backlog/EPIC-003-schema-inventory.md)).

---

# Part I. What will have to be transformed

An analysis of the existing schema through the cases that determine the volume of
work. Every figure comes from reading the Oracle data dictionary on 2026-09-03;
the method and the full object list are in
[map/00-source-inventory.md](map/00-source-inventory.md).

The scale being transformed:

| | Value |
|---|---:|
| Tables | 449 (+ 3 views) |
| Columns | 4,855 |
| Rows | ~148,000,000 |
| Data | ~12.3 GB in table segments |
| Objects mapping one-to-one onto a target table | **49 of 452** |

## 1. Names taken from a third-party ERP

A significant part of the schema is named in the terms of the system WERP grew
out of. Measured occurrences:

| Name | Columns | Tables |
|---|---:|---:|
| `bukrs` | 133 | 1 |
| `matnr` | 100 | 42 |
| `waers` | 45 | — |
| `werks` | 36 | 5 |
| `dmbtr` | 21 | — |
| `gjahr` | 20 | — |
| `spras` | 19 | — |
| `hkont` | 14 | — |
| `wrbtr` | 12 | — |
| `belnr`, `monat`, `shkzg`, `bldat`, `meins`, `blart`, `bschl`, `buzei`, `lifnr`, `budat`, `sgtxt`, `kunnr`, `koart` | 3–9 each | — |

**469 columns and 51 tables** carry one of these. Understanding the schema
without knowing that nomenclature is impossible.

A separate case is **a name that encodes the type rather than the meaning**:
`TEXT45` (17 columns, holding a branch's name, a product's name, a payroll
comment), `TEXT20`, `TEXT10`.

**Rule:** every such abbreviation is decoded once and replaced with a meaningful
name. The dictionary is in [GLOSSARY.md](../GLOSSARY.md#inherited-names) and is
part of the migration tool.

## 2. Three different ways of naming the same thing

Identifiers are named in at least three forms at once:

| Form | Occurrences | Example |
|---|---:|---|
| `<entity>_id` | 1,109 | `branch_id`, `country_id` |
| `id` | 284 | |
| `<entity>id`, no separator | 33 | `countryid`, `stateid`, `branchid` |
| `id<entity>`, the prefix form | 8 | `idcity`, `idstate` |

The forms occur **in neighbouring tables that reference each other**: `CITY` has
`IDCITY`, `STATEID` and `COUNTRYID`; `STATE` has `IDSTATE` and `COUNTRYID`;
`BRANCH` has `BRANCH_ID`, `COUNTRY_ID` and `STATE_ID`. `BKPF` and `BSEG` refer to
a branch as `BRNCH`.

Primary keys are equally inconsistent: 180 tables name theirs `ID`, 98 name it
`<entity>_ID`, five use a prefix form, and eleven use a business value
(`BUKRS`, `MATNR`, `BSCHL`, `SPRAS`, `MEINS`, `SHKZG`, `KOART`, `ECN`).
**125 tables have no primary key at all**, among them `SERV_CRMHISTORY` with
7,888,777 rows.

**Rule:** a primary key is always `id` of type `uuid`, a foreign key is
`<entity>_id` ([rule 2](../product/03-database/rules/02-naming.md)).

## 3. A shadow schema that holds the integrity

Twenty-five tables carry the prefix `PH_`; twenty-three of them duplicate the
structure of a table that exists without it. `PH_CONTRACT` has 84 columns and
**0 rows** next to `CONTRACT` with 85 columns and 384,804 rows. The same for
`PH_SERVICE`, `PH_STAFF`, `PH_MATNR`, `PH_SERVICE_POS`.

**47 of the schema's 57 foreign keys are declared on those copies.** The tables
that hold the data have almost none.

**Rule:** the copies are not migrated. Referential integrity is measured on the
real tables before the transfer, per reference, and the orphan rate is a number
in the migration plan, not an assumption
([05-data-migration.md](05-data-migration.md)).

## 4. Two entities on one table, and one entity on two tables

Both directions occur:

| Case | Evidence |
|---|---|
| The classes `Company` and `Bukrs` both map to `company` | two models, one table |
| `SERV_FILTER` and `SERV_FILTER_VC` | **45 identical columns**, 188,800 and 186,727 rows — one table copied for a second product line |
| `SERV_FILTER_PLAN` and `SERV_FILTER_VC_PLAN` | 26 of 28 columns shared, 2.2M and 5.5M rows |
| `HR_DOC` and `HR_DOCUMENT` | 11 of 14 columns shared — two implementations of one approval workflow |
| `KPI_DATA` and `CRM_KPI_DATA` | 14 of 15 columns shared — the KPI model exists twice |
| `FMGLFLEXT` and `FMGLFLEXT2` | 18 of 18 columns shared |
| `INVOICE` (33 rows) and `INVOICE_TABLE` (4,243,069 rows) | two invoice implementations |

**Rule:** one meaning — one table. When consolidating, the implementation used by
more scenarios wins; the other is deleted together with the code that depends on
it ([02-backend-mapping.md](02-backend-mapping.md)).

The `SERV_FILTER` pair is the case that shows how to consolidate correctly.
`SERV_FILTER` serves water purifiers, `SERV_FILTER_VC` serves vacuum cleaners:
different equipment, a different contract type behind it and different servicing
rules. The second table was made by copying the first, so it inherited six
maintenance positions for a product that has one — **35 of its 45 columns are
null in every row but 38**, and a purifier's `FNO` is 5 or 6 while a vacuum
cleaner's is always 1.

Consolidating them is therefore not "add a discriminator to the wider table". The
number of maintenance positions and their intervals move out of the column list
into `service.maintenance_program`, a row per product type; the positions
themselves become rows of `service.maintenance_slot`. A third product line then
costs a row of reference data.

**What must not be lost in the merge:** the servicing rules of the two lines
genuinely differ. Both are written down before the merge and both are verified
separately at parity ([06-parity-verification.md](06-parity-verification.md)) —
merging the storage is not permission to merge the behaviour.

## 5. Versioning by copying the table

Fifteen tables exist only because there is no status column: `*_OLD`, `*_BACKUP`,
`*_ARCHIVE`, `*_HIS`, `TEMP_*`. `SALE_PLAN` and `SALE_PLAN_ARCHIVE` have
identical column sets, 128 and 10,710 rows. `TEMP_PAYROLL_ARCHIVE` holds
1,394,218 rows. `BKPF_OLD`, `BSEG_OLD`, `BKPF_BACKUP_1`, `SALARY_BACKUP`,
`FMGLFLEXT_BACKUP` are copies of production tables left in the schema.

**Rule:** history is a status, a validity period, or a detached partition —
never a table with a different name
([rule 10](../product/03-database/rules/10-large-tables.md)).

## 6. A table per state transition

The warehouse keeps `MATNR_SOLD`, `MATNR_RECEIVED`, `MATNR_LOST`,
`MATNR_RESERVED`, `MATNR_RETURNED`, `MATNR_RESOLD`, `MATNR_RESOLD_SERVICE`,
`MATNR_REPAIR_WRITEOFF`, `MATNR_LIST_SOLD` — nine tables, 7.9 million rows, whose
column sets differ by at most one column.

`MATNR_PURCHASE_AMOUNT` has two columns and 5,500,674 rows: one number given a
table of its own.

**Rule:** one movement table with a `kind` column; a balance is derived from it
and reconciled by a job
([the `inventory` schema](../product/03-database/schemas/inventory.md)).

## 7. Repeating groups spread across columns

`SERV_FILTER` stores six maintenance positions as `F1_MT … F6_MT`, `F1_SID …
F6_SID`, `F1_DATE`, `F1_DATE_NEXT`, `F1_DATE_PREV`, `F1_SID_PREV` — **36 of its
45 columns** — because a water purifier has five or six replaceable cartridges. `SERV_FILTER_PLAN` repeats the shape with `CURRENT_F1 …
OVERDUE_F4M1`. `SOCIALTAX_COEF` holds 26 columns of rates.

A seventh position cannot be added without a migration, and "which position is
overdue" cannot be asked without naming all six. A product with fewer positions
gets the columns anyway and leaves them empty.

**Rule:** a repeating group becomes rows in a child table.

## 8. The same data stored twice in one row

`CONTRACT` carries an address block `ADDR_DOM_*` (10 columns) and a second one
`ADDR_RAB_*` (8 columns), **and** the columns `ADDR_HOME_ID`, `ADDR_WORK_ID`,
`ADDR_SERVICE_ID` referring to the `ADDRESS` table. Four phone columns
(`TEL_DOM`, `TEL_MOB1`, `TEL_MOB2`, `TEL_RAB`) sit beside a `REF_PHONES` table of
699,827 rows. Nothing keeps the two copies equal.

`CUSTOMER` carries `FULL_ADDRESS` (1,500 characters) and `FULL_PHONE` (500
characters), maintained by a database trigger and a stored procedure.

`SERVICE` carries `CUSTOMER_FIRSTNAME`, `CUSTOMER_MIDNAME`, `CUSTOMER_LASTNAME`,
`ADDR` and `TEL` beside `CUSTOMER_ID`.

`COUNTRY` carries both `CURRENCY_ID` and `CURRENCY`, and both `STATUS_ID` and
`STATUS`.

**Rule:** one value is stored in one place. During the migration a source of
truth is chosen per pair, the divergences are recorded in the rejection log and
resolved by the domain owner. A denormalized copy that is genuinely needed for
reading is a read model, rebuilt from the source, not a column edited by a
trigger.

## 9. Production data identifiers in the code

The `Branch` entity declares `GREEN_LIGHT_MAIN_BRANCH_ID = 207L` and
`AURA_MAIN_BRANCH_ID = 2L` — primary key values from the production database,
hardcoded into the sources.

That makes the code dependent on the database's content: the same sources behave
differently against another data set, and the test data is obliged to reproduce
specific identifiers.

Those two are not exceptional. Measured over the four Java repositories:
**119 constants name a specific row of production data**, among them
`Position.DEALER_POSITION_ID = 4`, `Position.DIRECTOR_POSITION_ID = 10`,
`LgsUtil.CENTRAL_WERKS_ID = 2`, `PayrollService.DEBUG_STAFF_ID = 12353` and a
constant naming an individual employee. **239 constants are declared in two to
five files at once**; they agree today, and nothing keeps them agreeing
([map/01-schema-in-code.md](map/01-schema-in-code.md#5-row-identifiers-hardcoded-in-the-sources)).

**Rule:** behaviour that depends on a specific record is expressed by **a
property in the data**, not by an identifier in the code — `branch.kind = HEAD`,
`warehouse.is_main`. The list of 119 places exists; each is a separate design
decision ([EPIC-003](../backlog/EPIC-003-schema-inventory.md)).

## 10. Housekeeping columns are applied selectively

Measured over the schema, not over the code:

| Property | Tables | Share |
|---|---:|---:|
| a creation timestamp, in any spelling | 143 | 32% |
| a modification timestamp | 109 | 24% |
| who created the row | 124 | 28% |
| who changed the row | 91 | 20% |
| optimistic locking | 21 | 5% |
| logical deletion | 23 | 5% |

Three generations of convention coexist: `BKPF` and `BSEG` have none;
`CONTRACT` and `STAFF` have `CREATED_DATE` / `UPDATED_DATE` of type `DATE`;
`INVOICE_TABLE`, the `CC_*` and the `AITU_*` families have `CREATED_AT` /
`UPDATED_AT` of type `TIMESTAMP(6)`, not null.

**Consequences for the transition:**

- most tables **have no history**: who created a record and when cannot be
  reconstructed. During the migration such columns are filled with a "migrated"
  marker rather than with invented values;
- change auditing exists for a handful of entities — their history is carried
  over ([C-10](../docs/00-context/03-constraints.md#c-10-change-audit-already-exists-and-must-be-preserved)),
  while for the rest the history starts at the moment of the cutover, and that
  has to be communicated to users in advance;
- optimistic locking is practically absent — meaning concurrent edits are
  currently lost silently. In the product `version` is mandatory, and that is a
  **change in behaviour** users will notice: they will start receiving a conflict
  message instead of losing data.

## 11. Localization by columns

199 columns across 69 tables hold a translation: `*_EN` (68), `*_TR` (62),
`*_RU` (40), `*_KK` (27), `*_KZ` (2). Kazakh is spelled two different ways in one
schema. Adding a language requires a schema migration; a language added but not
filled is invisible.

**Rule:** paired name tables
([rule 6](../product/03-database/rules/06-localization.md)).
During the migration the columns are unfolded into rows, and an empty translation
becomes an absent row rather than an empty string.

## 12. The meaning of a column lives in the code, not in the database

The schema stores numbers; what those numbers mean is `static final` constants
inside the Java classes — **968 numeric constants, 572 of them declared inside
entity classes**:

| Table | Constants | Examples |
|---|---:|---|
| `INVOICE_TABLE` | 27 | `TYPE_POSTING=1`, `TYPE_WRITEOFF=2`, `TYPE_SEND=3` |
| `HR_DOCUMENT` | 20 | `STATUS_ON_CREATE=1` … `STATUS_REFUSED=6` |
| `CONTRACT_STATUS` | 18 | `STATUS_STANDARD=1`, `STATUS_GIFT=2`, `STATUS_CANCELLED=3` |
| `SERVICE` | 13 | `TYPE_FILTERS=1`, `TYPE_FITTING=2`, `TYPE_SERVICE=3` |
| `MATNR` | 8 | `MATNR_TYPE_TOVAR=1`, `MATNR_TYPE_PART=2`, `MATNR_TYPE_FILTER=3` |

plus 94 enumeration types elsewhere in the code.

**These lists are the migration's input, and they now exist**
([map/01-schema-in-code.md](map/01-schema-in-code.md#4-where-the-meaning-of-a-column-actually-lives)).
What each list still needs is the owner's confirmation that it is complete and
that every value still means what its name says — checked against
`SELECT DISTINCT` on the column, because a value present in the data with no
constant behind it is exactly the case that breaks a migration.

Business rules also hide in the mapping annotations: 40 `@Formula` (a correlated
subquery per row), **9 `@Where`** (a filter silently added to every query for an
entity, spelled `is_active=1`, `active = 1` and `active <> 0` on comparable
columns), 1 `@Filter`, 5 lifecycle callbacks. A `@Where` that is not reproduced
changes what a report returns and nothing announces it.

**Rule:** an enumeration becomes a readable string with a `ck` constraint listing
its values; a derived value becomes a generated column, a read model or a domain
method — never a SQL string in an annotation
([rule 9](../product/03-database/rules/09-logic-in-the-database.md)).

## 13. Types encode nothing

| Fact | Count |
|---|---:|
| `NUMBER` columns | 2,874 (59% of the schema) |
| — with no precision or scale | 590 |
| — `NUMBER(1)` used as a flag | 101 |
| Money columns, `NUMBER(*,2)` | 262, under 111 different names |
| `FLOAT` columns | 8, including a unit price and two tax rates |
| Booleans stored as a number or a one-character string | 118 |
| `DATE` columns (no time zone) | 369 |

Specific cases the migration has to decide about:

- `ADDRESS.LATITUDE` and `ADDRESS.LONGITUDE` are `VARCHAR2(30)`;
- `STAFF.ACCOUNT` — a bank account — is `NUMBER(21,2)`;
- `BKPF.KURSF` — an exchange rate — is `NUMBER(21,2)`, so a rate cannot hold more
  than two decimals; every historical conversion inherits that error;
- `EXCHANGE_RATE.EXRATE_DATE` carries a `18:00:00` time-of-day on every row — the
  artefact of a time zone applied to a date;
- `CURRENCY.CURRENCY` contains `YTL` and `CHY`, neither of which is an ISO 4217
  code;
- a branch's type is the number `TYPE` with values 1–4 whose meaning exists only
  in the code; `is_main` is an `int`.

**Rule:** the target types are fixed in
[rule 5](../product/03-database/rules/05-types.md); an enumeration is a
readable string and a flag is `boolean`. The number-to-string mapping is defined
per column in the domain's map, and **every mapping is verified by a per-value
count reconciliation**.

## 14. Indexes and integrity practically do not exist

| | Value |
|---|---:|
| Index objects | 437 |
| — unique, backing a key | 364 |
| — **secondary** | **73**, over 37 tables |
| Tables with no secondary index | 412 of 449 |
| Tables with no index at all | 111 |
| Tables above 100,000 rows with no index at all | 17 |
| Foreign-key-shaped columns leading an index | 13% of 1,184 |
| Value check constraints | 6 of 1,441 |

`BSEG` (27.7M rows) has one secondary index. `SERV_CRMHISTORY` (7.9M rows) has
none and no primary key.

**Consequence:** the target index set cannot be derived from the existing one —
there is almost nothing to derive it from. It is designed from the queries the
specifications declare and verified against measured plans
([rule 8](../product/03-database/rules/08-indexes.md)). This is work
that has no counterpart in the source and is easy to leave out of an estimate.

## 15. What lives inside the database

| Object | Count | Decision |
|---|---:|---|
| Sequences | 342 | gone: identifiers come from the application |
| Triggers | 43 | 41 of them assign a primary key — gone with the sequences |
| Procedures | 6 | five gone, one becomes a domain scenario |
| Functions | 2 | gone |
| Views | 3 | one replaced by a materialized tree path, two become reports |
| Packages | 0 | |

Plus `TABLE_ID_LIMIT` — an application-level allocator of identifier ranges
running in parallel with the 342 sequences, and `SP_AUTO_RESET_SEQUENCES`, a
procedure that re-aligns a family of sequences by altering their increment at
runtime.

**Rule:** [what may live in the database](../product/03-database/rules/09-logic-in-the-database.md).
Because there is so little logic there, adopting the rule costs almost nothing —
the object-by-object decisions are in
[map/00-source-inventory.md](map/00-source-inventory.md#4-objects-other-than-tables).

---

# Part II. Transformation rules

Applied to every column. The migration tool implements them
([TASK-0501](../backlog/EPIC-005-data-migration.md)).

| What | Rule | Verification |
|---|---|---|
| Table name | singular, `snake_case`, no abbreviations | review + the schema linter |
| Column name | `snake_case`, no transliteration, no type encoding, no ordinal | the same |
| Primary key | a new `uuid`; the old value is kept in the mapping table | a count reconciliation |
| Composite natural key | kept as a unique index, never as the primary key | a uniqueness check before the transfer |
| Foreign key | redirected through the mapping table | a referential reconciliation |
| A reference with no target row | an orphan: counted, reported, decided per reference | the orphan rate is recorded before and after |
| Empty string | Oracle does not distinguish it from `NULL` — an explicit decision per column | a sampled reconciliation |
| Date and time | → `timestamptz` in UTC with the source zone stated explicitly; a calendar date → `date`, dropping the time-of-day artefact | a reconciliation on boundary values |
| Money | `numeric(19,4)`, rounding per the platform rule | **a reconciliation to the cent** |
| Exchange rate | `numeric(19,8)`; the existing two decimals are carried over as they are and **not** back-computed | a value reconciliation |
| Boolean | `int` / `char(1)` → `boolean` with an explicit list of acceptable input values | a per-value count reconciliation |
| Enumeration | a number → a string code per the domain's mapping table | a per-value count reconciliation |
| Localized name | the columns `*_ru`, `*_en`, `*_tr`, `*_kk`, `*_kz` → rows in `*_name`; an empty value → no row | a count reconciliation per locale |
| Repeating group | `f1 … f6` → rows in a child table with an ordinal column | a count reconciliation: 6 × the parents |
| A table per state | → rows of one table with a `kind` column | a per-kind count reconciliation |
| A copy table (`*_OLD`, `*_ARCHIVE`) | → rows of the same target table with a status, or not migrated | a decision recorded per table |
| Denormalized duplicate | one source of truth is chosen; the divergences go to the rejection log | a divergence count |
| Housekeeping columns | missing ones are filled with the migration marker | — |
| Dead columns | not carried over | the decision is recorded |

## Preserving the old identifiers

The target schema uses `uuid`; the source uses numbers and strings. For the
duration of the project a mapping table is maintained:

```
migration.id_map(source_schema, source_table, source_id, target_id)
```

It is needed for: redirecting foreign keys; a row-by-row reconciliation;
investigating divergences in the shadow run; transferring data by hand under
rollback O2 ([08-rollback.md](08-rollback.md#o2-late-rollback)).

At 148 million rows the table is not a detail: its size, its indexes and the
throughput of lookups against it are part of the migration's performance plan
([05-data-migration.md](05-data-migration.md)).

It is deleted in [Phase 5](plan/06-phase-5-decommission.md) together with the
system it maps.

---

# Part III. Table map

Filled in: [map/00-source-inventory.md](map/00-source-inventory.md) — one row per
source object, with its decision and its target table.

### What the code does with those objects

Measured over the four Java repositories, 5,355 files
([map/01-schema-in-code.md](map/01-schema-in-code.md)):

| | Tables |
|---|---:|
| mapped by an entity class | 314 |
| reached only as a join table or from hand-written SQL | 4 |
| the name appears, nothing maps it | 12 |
| **absent from every repository** | **119** |

Of the 119, twenty-five are the shadow copies, twenty-five the call-centre
mirror, nine are backups — and **twenty-two are the budget tables, which no
repository mentions at all** while holding some 83,000 rows. That is a scope
question for the business, not a migration detail.

| Source | Objects | Rows | State |
|---|---:|---:|---|
| Oracle, schema ERP | 449 tables + 3 views | ~148,000,000 | **mapped, decisions taken for 433 of 452** |
| MySQL, the first-generation monolith | not confirmed | not confirmed | **not inventoried** |
| PostgreSQL, CRM | 23 tables | mirrored into Oracle as `CRM_*` | covered through the mirror; which side is the source of truth — [OQ-002](12-open-questions.md) |
| PostgreSQL, call centre | 20 tables | mirrored into Oracle as `CC_*` | the same |

Decisions taken: `merge` 253, `collapse` 62, `drop` 51, `migrate` 49, `split` 18.
Nineteen tables have the decision `decide` — nobody currently knows what they are
for ([OQ-004](12-open-questions.md)).

**The MySQL database is the open hole in this map.** It is in production, it has
no schema inventory, and until it has one the migration scope is not known. That
is a condition of gate [G0](plan/00-roadmap.md#g0--end-of-phase-0).

## What remains after the map is filled

The map states *what becomes what*. It does not yet state *how each column is
transformed* — that is the per-domain work, and its required depth is set by
[map/D1-reference.md](map/D1-reference.md#column-mapping-branch--referencebranch).

| Step | Where | State |
|---|---|---|
| 1. Catalogue the objects | [map/00-source-inventory.md](map/00-source-inventory.md) | **done** |
| 2. Determine liveness from access statistics | TASK-0302 | not started — 118 tables are empty and 71 have never been analysed |
| 3. Assign the table to a domain | [map/00-source-inventory.md](map/00-source-inventory.md) | **done** |
| 4. Take the decision: migrate / consolidate / do not migrate | [map/00-source-inventory.md](map/00-source-inventory.md) | done for 433 of 452; **taken by the designer, to be confirmed by the owners** |
| 5. Design the target table | [product/spec/](../product/spec/README.md) | D1, D3 and D5 done; D0, D2, D4 and D6–D12 outlined at table level |
| 6. Describe the column mapping | [map/](map/README.md) | D1 done as the sample; D3 and D5 next, now that their targets exist; the rest not started |

Steps 5 and 6 go together: a column is designed and immediately gets its
transformation rule. Done at different times, they drift apart.

The decisions in step 4 were taken from the structure of the data. **They are a
proposal to the domain owners, not a settled outcome**: "do not migrate" and
"consolidate" are decisions about which functionality users keep, and those
belong to the owner ([map/README.md](map/README.md#who-fills-it-in)).
