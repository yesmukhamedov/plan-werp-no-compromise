---
id: TRANS-MAP-00
title: Source schema inventory — all 452 objects
status: measured
measured_at: 2026-09-03
source: Oracle schema ERP, test contour
---

# Source schema inventory

Every table of the main database, with the decision taken for it and the target
table it becomes. This is the row-per-source-table map promised by
[01-database-mapping.md](../01-database-mapping.md#part-iii-table-map); the
transformation rules that apply to the columns are there, the target schema is
in [product/03-database/](../../product/03-database/README.md).

**How it was obtained.** Read directly from the Oracle data dictionary
(`user_tables`, `user_tab_columns`, `user_indexes`, `user_ind_columns`,
`user_constraints`, `user_sequences`, `user_triggers`, `user_views`) on the test
contour on the `measured_at` date. Every number below is a measurement, not an
estimate. The reproduction queries are in the
[appendix](#appendix-how-this-was-measured).

---

## 1. What was measured

| | Value |
|---|---:|
| Tables | 449 |
| Views | 3 |
| Columns | 4,855 |
| Rows (optimizer statistics) | ~148,000,000 |
| Table segments | ~12.3 GB |
| Indexes (excluding LOB) | 437 |
| — of them non-unique | **73** |
| Sequences | 342 |
| Triggers | 43 |
| Procedures / functions / packages | 6 / 2 / 0 |
| Foreign keys | 57 |
| Value check constraints | **6** of 1,441 (the rest are `NOT NULL` declarations) |

Three databases are **not** covered by this inventory and are a gap that has to
be closed before gate G0:

| Source | State | Why it is not here |
|---|---|---|
| MySQL, `werp_jsf` | in production | never inventoried; composition unknown |
| PostgreSQL, `aura_crm` | in production | already mirrored into Oracle as `CRM_*`; which of the two is the source of truth is [OQ-002](../12-open-questions.md) |
| PostgreSQL, `aura_call_center` | in production | already mirrored into Oracle as `CC_*` (25 tables); the same question |

The CRM and call-centre mirrors are counted here once, in their Oracle form.

### The schema moves while it is being described

The reference dump taken on 2026-07-11 and the live schema read on 2026-09-03
differ by **28 objects**: 26 tables gained columns and 2 tables are new. That is
roughly one schema change every other day.

Consequence for the transition: this inventory is a snapshot, not a contract. It
is re-read before the migration rehearsal and again before the cutover, and the
difference is a work item, not a surprise ([09-freeze-policy.md](../09-freeze-policy.md)).

---

## 2. The decisions, in totals

| Decision | Objects | What it means |
|---|---:|---|
| `merge` | 253 | several source tables become one target table |
| `collapse` | 62 | the table becomes rows of `reference_item` or a column of another table |
| `drop` | 51 | the data is not carried over |
| `migrate` | 49 | one source table becomes one target table |
| `decide` | 19 | the owner's decision is required before design can continue |
| `split` | 18 | one source table becomes several target tables |
| **Total** | **452** | |

**Only 49 tables of 452 map one-to-one.** Eleven per cent. Everything else is
merged, collapsed, split or dropped — which is the measured answer to the
question of why the migration cannot be written as a column-renaming script.

The 452 source objects become **127 target tables**. The target schema has 180;
the remaining **53 tables have no source at all** — audit, notifications,
background jobs, document numbering, the seven localization tables, the outbox,
the approval routes. That third of the target schema is work with no counterpart
in the source, and it is the part most easily left out of an estimate made by
looking at the old system. The registry is in
[the schema registry](../../product/03-database/schemas/README.md).

### By domain

| Domain | Source objects | Source rows | Target tables | Of them with a source |
|---|---:|---:|---:|---:|
| D0 Platform | 34 | 6,395,828 | 22 | 14 |
| D1 Reference data | 30 | 19,311 | 20 | 11 |
| D2 Counterparties | 16 | 1,964,814 | 14 | 9 |
| D3 Personnel | 21 | 173,231 | 15 | 12 |
| D4 Contracts and sales | 38 | 5,075,054 | 17 | 13 |
| D5 Accounting and finance | 87 | 59,788,018 | 20 | 18 |
| D6 Compensation calculation | 13 | 3,512,727 | 7 | 5 |
| D7 Warehouse and logistics | 44 | 18,107,904 | 15 | 10 |
| D8 Field service | 53 | 25,782,781 | 17 | 13 |
| D9 CRM and call centre | 52 | 25,225,014 | 15 | 12 |
| D10 Document workflow | 15 | 290,853 | 8 | 6 |
| D11 Legal | 1 | 0 | 4 | 1 |
| D12 Tasks and communications | 23 | 1,653,738 | 6 | 3 |
| — copies and dead weight | 25 | 768 | 0 | — |
| **Total** | **452** | **~148,000,000** | **180** | **127** |

The target table counts are the ones in the
[registry](../../product/03-database/schemas/README.md); the last
column says how many of them any existing table feeds.

D5, D7, D8 and D9 hold 236 of the 452 tables and 129 of the 148 million rows.
They are where both the design work and the migration risk are.

D11 Legal consists of **one empty table**. Either the domain does not exist in
the data or it lives somewhere not yet found; designing it before that is
answered is designing for nobody ([D11-R1](#risks-that-follow-from-the-inventory)).

---

## 3. The seven structural findings

Each is a measured property of the schema, and each one determines a design rule
in [product/03-database/](../../product/03-database/README.md).

### 3.1 A shadow schema of 25 tables carries the foreign keys

Twenty-five tables share the prefix `PH_`, and twenty-three of them are a
structural copy of a table that also exists without the prefix: `PH_CONTRACT`
(84 columns, **0 rows**) beside `CONTRACT` (85 columns, 384,804 rows);
`PH_SERVICE` (0 rows) beside `SERVICE` (1,218,587 rows); `PH_STAFF` (0 rows)
beside `STAFF` (17,240 rows).

Of the schema's 57 foreign keys, **47 are declared on the `PH_` copies**. The
tables that actually hold the data have almost no declared referential
integrity: `CONTRACT`, `SERVICE`, `BSEG`, `BKPF`, `CUSTOMER`, `MATNR_LIST` — not
one foreign key between them.

The consequence for the migration is direct: referential integrity cannot be
assumed anywhere and must be **measured** table by table before the transfer
([05-data-migration.md](../05-data-migration.md)).

### 3.2 Seventy-three secondary indexes for 148 million rows

437 index objects exist, but 364 of them are the unique indexes that back a
primary or unique key. Real secondary indexes: **73, spread over 37 tables**.
412 of 449 tables have none at all, and 111 tables have no index whatsoever.

| Table | Rows | Secondary indexes |
|---|---:|---:|
| `BSEG` | 27,717,360 | 1 |
| `SERV_CRMHISTORY` | 7,888,777 | **0** (and no primary key) |
| `SERV_FILTER_VC_PLAN` | 5,535,874 | **0** |
| `INVOICE_TABLE_ITEM1` | 9,500,695 | 0 |
| `RELATED_DOCS` | 4,521,553 | 0 |
| `SERVICE_POS` | 3,608,116 | 0 |
| `CONTRACT` | 384,804 | 1 |

Of 1,184 columns whose name says they reference another table, **13 per cent**
lead an index.

Value constraints are as scarce: of the schema's 1,441 check constraints, all but
**six** are `NOT NULL` declarations. Two of the six check that a part-time flag
holds 0 or 1. Nothing in the database prevents a negative amount, an unknown
status code or a coordinate outside the globe.

Seventeen tables of more than 100,000 rows have no index of any kind. Every read
of them is a full scan.

### 3.3 The same model implemented twice, repeatedly

Measured by comparing column sets:

| Pair | Columns in common | Rows |
|---|---|---|
| `SERV_FILTER` / `SERV_FILTER_VC` | 45 of 45 — **identical** | 188,800 / 186,727 |
| `SERV_FILTER_PLAN` / `SERV_FILTER_VC_PLAN` | 26 of 28 | 2,181,401 / 5,535,874 |
| `HR_DOC` / `HR_DOCUMENT` | 11 of 14 | 22,563 / 404 |
| `KPI_DATA` / `CRM_KPI_DATA` | 14 of 15 | 171,653 / 447,270 |
| `FMGLFLEXT` / `FMGLFLEXT2` | 18 of 18 | 9,190 / 19,776 |
| `SALE_PLAN` / `SALE_PLAN_ARCHIVE` | 17 of 17 — identical | 128 / 10,710 |
| `CRM_DOC_RECO` / `CRM_DOC_RECO_BASE` | 37 of 37 | not confirmed |
| `INVOICE` / `INVOICE_TABLE` | 7 of 18 | 33 / 4,243,069 |

The `SERV_FILTER` pair is a copy made for a second product line, not a shared
model. `SERV_FILTER` serves water purifiers, `SERV_FILTER_VC` serves vacuum
cleaners; the two differ by the equipment, by the contract type behind it and by
the servicing rules. The copy kept the columns of the first product line
regardless:

| | `SERV_FILTER` (purifiers) | `SERV_FILTER_VC` (vacuum cleaners) |
|---|---:|---:|
| Rows | 188,800 | 186,727 |
| Maintenance positions per unit (`FNO`) | 5 (156,247 rows) or 6 (32,553) | **1** (186,727) |
| Rows with position 1 filled | 188,800 | 186,727 |
| Rows with position 2 filled | 188,800 | **38** |
| Rows with position 6 filled | 24,986 | **0** |

**Thirty-five of the 45 columns of `SERV_FILTER_VC` are null in every row but 38
of them.** A product that needs one maintenance position was given a table shaped
for a product that needs six, because the number of positions is baked into the
column list instead of being a property of the product.

The plan tables repeat it: `SERV_FILTER_PLAN` (2,863,777 rows) carries
`SERVICE_APPLICATION_ID`, which is **null in every row**, while
`SERV_FILTER_VC_PLAN` (5,676,803 rows) does not have the column at all.

The target keeps one `service.installed_unit` and one
`service.maintenance_plan`, and moves the number of positions and their intervals
into `service.maintenance_program` — a row per product type. A third product line
is then data, not a fifth pair of tables ([D8](#d8--field-service)).

The servicing rules themselves genuinely differ between the two lines, and that
difference is a parity requirement, not an implementation detail: both sets of
rules have to be reproduced and both have to be verified
([D8-R1](#6-risks-that-follow-from-the-inventory)).

The `*_ARCHIVE`, `*_HIS`, `*_OLD`, `*_BACKUP` and `TEMP_*` families are the same
mistake in its cheapest form — **versioning by copying the table**. Fifteen
tables and 1.9 million rows exist only because there is no status column.

### 3.4 A table per state transition

The warehouse keeps one table per event that can happen to an item, each with
the same column set:

| Table | Columns | Rows |
|---|---:|---:|
| `MATNR_SOLD` | 12 | 3,455,098 |
| `MATNR_RECEIVED` | 13 | 865,699 |
| `MATNR_LOST` | 11 | 792,691 |
| `MATNR_RESERVED` | 12 | 14,719 |
| `MATNR_RETURNED` | 12 | 2 |
| `MATNR_RESOLD` | 11 | 1,283 |
| `MATNR_RESOLD_SERVICE` | 11 | 2,419 |
| `MATNR_REPAIR_WRITEOFF` | 11 | 116,837 |
| `MATNR_LIST_SOLD` | 17 | 2,723,568 |

`MATNR_SOLD`, `MATNR_LOST`, `MATNR_RECEIVED` and `MATNR_RESERVED` differ from one
another by **at most one column**. Nine tables and 7.9 million rows become one
`inventory.stock_movement` with a `kind` column.

`MATNR_PURCHASE_AMOUNT` is the extreme case: two columns (`ID`, `AMOUNT`),
5,500,674 rows — a single number exiled into a table of its own.

### 3.5 Repeating groups spread across columns

`SERV_FILTER` holds the replaceable cartridges of a water purifier as `F1_MT …
F6_MT`, `F1_SID … F6_SID`, `F1_DATE`, `F1_DATE_NEXT`, `F1_DATE_PREV`,
`F1_SID_PREV` — six positions times six attributes, **36 of the table's 45
columns**. `SERV_FILTER_PLAN`
repeats the shape with `CURRENT_F1 … CURRENT_F4M1` and `OVERDUE_F1 …
OVERDUE_F4M1`.

A seventh position cannot be added without a migration, and a query for "which
position is overdue" cannot be written without naming all six.

`SOCIALTAX_COEF` does the same with 26 columns of rates. `CONTRACT` does it with
two address blocks: `ADDR_DOM_*` (10 columns) and `ADDR_RAB_*` (8 columns) —
while the same row *also* carries `ADDR_HOME_ID`, `ADDR_WORK_ID` and
`ADDR_SERVICE_ID` pointing at the `ADDRESS` table. The address is stored twice,
by two mechanisms, in one row, with nothing keeping them equal.

### 3.6 Housekeeping columns exist in a third of the schema

| Property | Tables | Share |
|---|---:|---:|
| a creation timestamp, in any spelling | 143 | 32% |
| a modification timestamp | 109 | 24% |
| who created the row | 124 | 28% |
| who changed the row | 91 | 20% |
| optimistic locking | 21 | 5% |
| logical deletion | 23 | 5% |

Three generations of convention coexist. `BKPF` and `BSEG` have none. `CONTRACT`
and `STAFF` have `CREATED_DATE` / `UPDATED_DATE` of type `DATE`. `INVOICE_TABLE`,
`CC_*` and `AITU_*` have `CREATED_AT` / `UPDATED_AT` of type `TIMESTAMP(6)`, not
null. The same fact is spelled three ways and typed two ways in one schema.

### 3.7 Types encode nothing

| Fact | Count |
|---|---:|
| Columns of type `NUMBER` | 2,874 (59% of all columns) |
| — of them with no precision or scale at all | 590 |
| — of them `NUMBER(1)`, used as a flag | 101 |
| Money columns (`NUMBER(*,2)`) | 262 under 111 different names |
| `FLOAT` columns, including a unit price and tax rates | 8 |
| Localization columns (`*_EN`, `*_RU`, `*_TR`, `*_KK`, `*_KZ`) | 199 across 69 tables |
| Columns named `TEXT45`, `TEXT20`, `TEXT10` | 23 |
| Date columns of type `DATE` (no time zone) | 369 |
| Boolean values stored as a number or a one-character string | 118 |

`ADDRESS.LATITUDE` and `ADDRESS.LONGITUDE` are `VARCHAR2(30)`.
`STAFF.ACCOUNT` — a bank account — is `NUMBER(21,2)`.
`BKPF.KURSF` — an exchange rate — is `NUMBER(21,2)`, so a rate cannot carry more
than two decimal places.
Kazakh is spelled `_KK` in 27 columns and `_KZ` in 2.
`CURRENCY.CURRENCY` contains `YTL` and `CHY`, neither of which is an ISO 4217
code.

---

## 4. Objects other than tables

### Sequences: 342 of them, and an application-level allocator beside them

The schema has 342 sequences for 326 primary keys, a family of them named
`SEQ_BKPF_BLART_*` per document type, and a stored procedure
(`SP_AUTO_RESET_SEQUENCES`) that walks that family and re-aligns each sequence by
altering its increment at runtime.

In parallel, `TABLE_ID_LIMIT` allocates identifier **ranges** per table
(`TABLE_NAME`, `TABLE_FIELD`, `FROM_ID`, `TO_ID`, `CURRENT_ID`) — a second,
application-level identifier generator.

In the target neither survives: identifiers are UUIDs generated by the
application ([rule 3](../../product/03-database/rules/03-identifiers.md)),
and `TABLE_ID_LIMIT` becomes `platform.document_number`, whose only job is
human-facing document numbers.

### Triggers: 43, of which 40 assign a primary key

| Group | Count | Decision |
|---|---:|---|
| assign `:NEW.id` from a sequence before insert | **41** | **gone**: the application generates the identifier |
| `CUS_FULL_PHONE_COMPOUND_ALL` — maintains `CUSTOMER.FULL_PHONE` | 1 | **gone**: a denormalized string replaced by a query over `party.phone` |
| `AFTER_LOGON` — sets a session parameter | 1 | **gone**: a session setting, not data |

Two of the 41 do one thing more than assign a key: one defaults a counter to
zero, one writes an audit row. Both are covered by the target's column defaults
and platform audit.

### Procedures and functions: 8, and what happens to each

| Object | What it does | Decision |
|---|---|---|
| `CONVERTCYRTOLAT` | transliterates Cyrillic into Latin | **gone** — presentation, not storage |
| `CREATESMSFORONEMONTH` | generates a month of SMS rows | **gone** — a background job |
| `CREATE_PHONE_REF` | fills the phone reference table | **gone** — a migration, once |
| `INSERT2`, `PR_REBELLIONRIDER` | not identified | **decide** — find the caller or delete |
| `SP_AUTO_RESET_SEQUENCES` | re-aligns the `SEQ_BKPF_BLART_*` family | **gone** with the sequences |
| `UPDATE_CUSTOMER_FULL_PHONE` | rebuilds a denormalized phone string | **gone** with the column |
| `UPDATE_INSTALLMENT_DATE` | shifts a payment-schedule date | **moves** into D4 as a scenario with a test |

Total business logic living in the database: **8 objects**. The rule for the
target — [what may live in the database](../../product/03-database/rules/09-logic-in-the-database.md)
— therefore costs almost nothing to adopt: there is nearly nothing to move.

### Views: 3

`BRANCHTREE`, `PROBLEM_CUSTOMERS`, `STAFFWORKSUMMARY`. All three are read models
of a query. `BRANCHTREE` is replaced by the materialized `branch.path`
([D1 specification](../../product/spec/D1-reference.md)); the other two become
reports.

---

## 5. Data-quality probes already run

Run against the test contour on the `measured_at` date. They close three
questions that were open in [D1-reference.md](D1-reference.md#domain-risks) and
open one new one.

| Check | Result |
|---|---|
| Branch tree connectivity | 217 branches, 7 companies, **exactly one root per company**, no dangling `parent_branch_id` |
| `BRANCH.TYPE` value set | four values: 1 (4 rows), 2 (11), 3 (157), 4 (45) — matches the `HEAD/REGION/BRANCH/POINT` mapping |
| `COUNTRY.CURRENCY_ID` versus `COUNTRY.CURRENCY` | consistent in all 11 rows — but two of the codes are not ISO 4217 |
| `CITY.NAME` fill rate | 469 of 469 rows filled |
| `EXCHANGE_RATE` | exists with 2,199 rows; the rate is stored as `NUMBER(21,2)`, and every timestamp carries a `18:00:00` time-of-day artefact |

**D1-R2 is closed green** on this contour: the branch tree is connected. The same
check has to pass on production data before it is closed for good.

**A new finding:** the target `reference.currency` cannot simply take the source
codes. `YTL` (retired in 2009 in favour of `TRY`) and `CHY` (not a code at all;
the Chinese yuan is `CNY`) require a mapping decision by the D1 owner before the
transfer.

---

## 6. Risks that follow from the inventory

| # | Risk | Evidence | Action |
|---|---|---|---|
| INV-R1 | Referential integrity is unknown across the whole schema | 47 of 57 foreign keys sit on empty shadow tables | measure orphan rates per reference before designing the target constraint |
| INV-R2 | The migration cannot be verified by row counts alone | 253 tables merge into fewer targets | verification is per-value and per-amount, not per-row ([06-parity-verification.md](../06-parity-verification.md)) |
| INV-R3 | Nineteen tables have no decision because nobody knows what they are | `AES` (9 tables), `RFCOL`, `FACT_TABLE`, `MIGVOZN`, `AGREEMENT`, `DAILY_FIN_DOC`, `STAFF_PP`, `CITYREG`, `HCITY`, `PBI_REGIONS` | [OQ-004](../12-open-questions.md); each needs an owner or a deletion |
| INV-R4 | The MySQL legacy is not inventoried at all | it is in production and has no schema map | inventory it before G0 or accept that its data will not be migrated |
| INV-R5 | Three tables of accounting hold 41 million rows with two indexes between them | `BSEG`, `BKPF`, `INVOICE_TABLE_ITEM1` | design the target index set from measured queries, not by analogy |
| INV-R6 | The schema changes about once every other day | 28 objects changed in 54 days | re-read the inventory before the rehearsal and before the cutover |
| D8-R1 | Two product lines are serviced by different rules, and the rules live in two copied table families | purifiers use 5-6 maintenance positions, vacuum cleaners use 1; the plan tables differ in their columns | both rule sets are written down before the merge, and parity is verified per product line |
| D11-R1 | The Legal domain has one empty table | `LEGAL_DEPARTMENT`, 0 rows | confirm with the business whether the domain exists at all |

---

## Appendix: how this was measured

Read-only queries against the data dictionary of the schema on the test contour.

```sql
-- tables, rows, size
SELECT table_name, num_rows, blocks FROM user_tables;

-- columns and types
SELECT table_name, column_id, column_name, data_type,
       data_precision, data_scale, char_length, nullable
FROM   user_tab_columns;

-- indexes and the columns they lead with
SELECT i.index_name, i.table_name, i.uniqueness, i.index_type,
       c.column_name, c.column_position
FROM   user_indexes i JOIN user_ind_columns c ON c.index_name = i.index_name
WHERE  i.index_type <> 'LOB';

-- constraints: P primary, U unique, R foreign, C check (mostly NOT NULL)
SELECT constraint_type, COUNT(*) FROM user_constraints GROUP BY constraint_type;

-- objects other than tables
SELECT COUNT(*) FROM user_sequences;
SELECT COUNT(*) FROM user_triggers;
SELECT view_name FROM user_views;

-- tables with no index at all
SELECT COUNT(*) FROM user_tables t
WHERE  NOT EXISTS (SELECT 1 FROM user_indexes i WHERE i.table_name = t.table_name);
```

`num_rows` and `blocks` are optimizer statistics and can be stale; they are used
here for orders of magnitude and for ranking, never as a migration count. The
counts that the migration is verified against are taken with `COUNT(*)` at the
moment of the transfer ([05-data-migration.md](../05-data-migration.md)).

---

## 7. The map

One row per source object, grouped by target domain, ordered by row count.

Decisions: `migrate` one to one · `merge` several into one · `split` one into
several · `collapse` into `reference_item` or into a column · `drop` not carried
over · `decide` the owner's decision is required.

**In code** says what the four Java repositories do with the table: how many
entity classes map it, how many of its columns no class and no query touches, or
that it is absent from the code altogether. The method and the findings are in
[01-schema-in-code.md](01-schema-in-code.md).

Rows are the optimizer statistics as of the `measured_at` date; `?` means the
table has never been analysed, which for 71 tables is itself a signal that
nothing reads them.

### D0 — Platform

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `CRM_REVINFO` | 7 | 2 908 603 | 1 entity, 2 col. unused | merge | `audit.audit_event` | three revision tables in two schemas |
| `REVINFO` | 4 | 2 152 280 | **2 entities** | merge | `audit.audit_event` | three revision tables in two schemas |
| `EVENT_LOG` | 7 | 1 237 375 | 1 entity | merge | `audit.audit_event` | a free-text event log becomes typed audit |
| `STAFF_FILE` | 3 | 35 072 | 1 entity | merge | `platform.stored_file_link` | five attachment tables, one mechanism |
| `UPD_FILE` | 6 | 35 072 | **2 entities** | migrate | `platform.stored_file` |  |
| `USER_BRANCH` | 4 | 11 160 | 1 entity | merge | `platform.access_scope_item` | three scope tables, one mechanism |
| `ROLE_ACTION` | 4 | 6 144 | **2 entities** | migrate | `platform.role_permission` | an action becomes a named permission |
| `REQ_EVENT_LOG` | 5 | 4 537 | 1 entity | merge | `audit.audit_event` | a free-text event log becomes typed audit |
| `USER_ROLE` | 3 | 1 918 | **2 entities** | migrate | `platform.user_role` |  |
| `USER_TABLE` | 17 | 1 685 | 1 entity | split | `platform.app_user + hr.employee` | a login and a person in one row |
| `USER_WERKS` | 4 | 928 | 1 entity | merge | `platform.access_scope_item` | three scope tables, one mechanism |
| `MENU` | 11 | 270 | 1 entity | drop | — | navigation is derived from permissions in the interface |
| `TABLE_ID_LIMIT` | 8 | 236 | 1 entity | migrate | `platform.document_number` | an id allocator becomes a document-number allocator |
| `ABAC` | 8 | 197 | 1 entity | merge | `platform.permission` | row-level restrictions become scope rules |
| `ERROR_TABLE` | 5 | 130 | 1 entity | drop | — | error codes are part of the API contract |
| `ROLE` | 3 | 95 | 1 entity | migrate | `platform.role` |  |
| `TASK_ATTACHMENT` | 3 | 78 | 1 entity | merge | `platform.stored_file_link` | five attachment tables, one mechanism |
| `ZREPORT` | 4 | 28 | **2 entities** | merge | `platform.report_definition` |  |
| `MESSAGE_ATTACH` | 4 | 10 | **2 entities** | merge | `platform.stored_file_link` | five attachment tables, one mechanism |
| `CC_OUTBOX_EVENT` | 9 | 4 | **absent** | migrate | `platform.outbox_event` | the only outbox that exists becomes the platform mechanism |
| `REVINFO_TYPE` | 6 | 3 | 1 entity | merge | `audit.audit_event` | three revision tables in two schemas |
| `OAUTH_CLIENT_DETAILS` | 11 | 2 | **absent** | migrate | `platform.api_client` |  |
| `TABLES` | 2 | 1 | name only | drop | — | no consumer |
| `AITU_CONTRACT_PDF` | 4 | ? | 1 entity | merge | `platform.stored_file_link` | five attachment tables, one mechanism |
| `CC_SCHEMA_VERSION` | 10 | ? | **absent** | drop | — | owned by the migration tool |
| `CDR` | 9 | 0 | name only | drop | — | no consumer |
| `CRM_SCHEMA_VERSION` | 10 | ? | **absent** | drop | — | owned by the migration tool |
| `MAIN_PAGE_FOLDERS` | 5 | 0 | 1 entity | drop | — | navigation is derived from permissions in the interface |
| `MAIN_PAGE_FOLDERS_OLD` | 4 | 0 | **absent** | drop | — | navigation is derived from permissions in the interface; a copy of another table |
| `MAIN_PAGE_FOLDERS_TRANS` | 3 | 0 | **absent** | drop | — | navigation is derived from permissions in the interface |
| `POWERBI_LINKS` | 4 | ? | 1 entity | merge | `platform.report_definition` |  |
| `PRIKAZ_ATTACH` | 5 | 0 | 1 entity | merge | `platform.stored_file_link` | five attachment tables, one mechanism |
| `SYS_TEMP_FBT` | 5 | ? | **absent** | drop | — | no consumer; a copy of another table |
| `USER_BRANCH_CUSTOMER` | 4 | 0 | 1 entity | merge | `platform.access_scope_item` | three scope tables, one mechanism |

### D1 — Reference data

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `TEMP_LANG` | 2 | 13 110 | **absent** | drop | — | the locale list is a constant of the message system; a copy of another table |
| `EXCHANGE_RATE` | 8 | 2 199 | **3 entities** | migrate | `reference.exchange_rate` | the rate precision is raised, one pair per row |
| `MATNR` | 28 | 1 846 | **2 entities** | split | `reference.product + product_name` | the catalogue leaves the accounting tables |
| `MATNR_BUKRS` | 3 | 993 | 1 entity | merge | `reference.product` | a product is owned by a company |
| `CITY` | 8 | 447 | **2 entities** | split | `reference.city + city_name` | name and name_kz into rows |
| `BRANCH` | 13 | 217 | 1 entity | migrate | `reference.branch` | plus path, depth, code, is_active |
| `WERKS_BRANCH` | 5 | 184 | **2 entities** | merge | `reference.warehouse` | becomes warehouse.branch_id |
| `STATE` | 6 | 77 | **2 entities** | split | `reference.region + region_name` | renamed |
| `SUB_COMPANY` | 15 | 77 | **2 entities** | merge | `reference.company` | a subcompany is a company with a parent |
| `WERKS_TYPE` | 5 | 72 | **2 entities** | migrate | `reference.warehouse` | the table and the model are renamed |
| `CITYREG` | 3 | 19 | **2 entities** | decide | `reference.region` | purpose not confirmed |
| `CURRENCY` | 5 | 12 | **2 entities** | split | `reference.currency + currency_name` | codes normalised to ISO 4217 |
| `MONTH` | 2 | 12 | name only | drop | — | months and periods are computed, not stored |
| `BUSINESS_AREA` | 5 | 11 | 1 entity, 1 col. unused | collapse | `reference.reference_item BUSINESS_AREA` |  |
| `COUNTRY` | 9 | 11 | **2 entities** | split | `reference.country + country_name` | names into rows, the currency by reference only |
| `MATNR_TYPE` | 3 | 8 | 1 entity | collapse | `reference.reference_item PRODUCT_KIND` |  |
| `COMPANY` | 5 | 7 | **4 entities** | migrate | `reference.company` |  |
| `ACTION_TYPE` | 3 | 3 | 1 entity, 1 col. unused | collapse | `reference.reference_item` |  |
| `LANGUAGE` | 2 | 3 | name only | drop | — | the locale list is a constant of the message system |
| `MEINS_TYPE` | 5 | 3 | 1 entity, 2 col. unused | split | `reference.unit_of_measure + unit_of_measure_name` |  |
| `BRANCHTREE` | 0 | view | hand-written SQL only | drop | — | a view over branch, replaced by branch.path |
| `COMPANY_AUD` | 5 | 0 | **absent** | merge | `audit.audit_event` |  |
| `COUNTRY_AUD` | 9 | 0 | **absent** | merge | `audit.audit_event` |  |
| `CURRENCY_AUD` | 6 | 0 | **absent** | merge | `audit.audit_event` |  |
| `HCITY` | 5 | ? | **absent** | decide | `reference.region` | purpose not confirmed |
| `PBI_REGIONS` | 4 | ? | **absent** | decide | `reference.region` | purpose not confirmed |
| `PERIOD` | 3 | 0 | name only | drop | — | months and periods are computed, not stored |
| `STATUS` | 6 | ? | 1 entity | collapse | `reference.reference_item` |  |
| `SUB_COMPANY_DETAIL` | 15 | ? | 1 entity | merge | `reference.company` | a subcompany is a company with a parent |
| `WERKSFLEXT` | 19 | 0 | **absent** | drop | — | empty, no consumer |

### D2 — Counterparties

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `REF_PHONES` | 6 | 699 827 | 1 entity | split | `party.phone + phone_link` |  |
| `ADDRESS` | 21 | 564 871 | 1 entity | split | `party.address + address_link` | the link to the owner leaves the address |
| `CUSTOMER` | 29 | 352 919 | 1 entity | split | `party.party + person + organization` | one row currently holds all three |
| `REF_PHONES_AUD` | 8 | 347 155 | 1 entity, 1 col. unused | merge | `audit.audit_event` |  |
| `LEGAL_ENTITY` | 3 | 33 | 1 entity | collapse | `reference.reference_item LEGAL_FORM` |  |
| `ADDR_TYPE` | 5 | 4 | 1 entity | collapse | `party.address_link.role` |  |
| `REF_PHONE_TYPES` | 5 | 3 | 1 entity | collapse | `party.phone.kind` |  |
| `FIZ_YUR` | 5 | 2 | name only | collapse | `party.party.kind` | two rows encoding a discriminator |
| `CREDIT_RATING` | 10 | ? | 1 entity | migrate | `party.credit_rating` |  |
| `CREDIT_RATING_VERIFICATION` | 13 | ? | 1 entity | migrate | `party.credit_rating_check` |  |
| `PHONE_CHANNEL` | 7 | ? | 1 entity | merge | `party.phone_channel` |  |
| `PHONE_CHANNEL_LINK` | 9 | ? | 1 entity | merge | `party.phone_channel` |  |
| `PHONE_CHANNEL_LINK_AUDIT` | 11 | ? | 1 entity | merge | `audit.audit_event` |  |
| `PHONE_CHECK_AUD` | 8 | ? | 1 entity | merge | `audit.audit_event` |  |
| `PROBLEM_CUSTOMERS` | 0 | view | view | drop | — | a view, becomes a query over party_status |
| `SERV_CUSTOMER_STATUS` | 6 | ? | **absent** | migrate | `party.party_status` |  |

### D3 — Personnel

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `STAFF_TIMESHEET` | 14 | 123 770 | 1 entity | split | `hr.time_sheet + time_sheet_entry` | a month per row becomes a day per row |
| `SALARY` | 24 | 28 603 | **3 entities** | migrate | `hr.compensation` | the backup copy is dropped |
| `STAFF` | 52 | 17 240 | **3 entities**, 1 col. unused | split | `hr.employee + hr.employment + party.person` | 52 columns, three entities |
| `STAFF_OFFICIAL_DATA` | 30 | 1 841 | **2 entities** | merge | `hr.employment` |  |
| `STAFF_EXPENCE` | 15 | 1 490 | 1 entity | migrate | `hr.employee_expense` | the spelling is corrected |
| `STAFF_EDUCATION` | 12 | 230 | **2 entities** | migrate | `hr.education` |  |
| `LEAVE_REASON` | 4 | 21 | 1 entity | collapse | `reference.reference_item LEAVE_REASON` |  |
| `DEPARTMENT` | 7 | 17 | **2 entities** | migrate | `hr.org_unit` |  |
| `STAFF_COURSE` | 10 | 8 | 1 entity | merge | `hr.course_enrolment` |  |
| `HR_STAFF_PROBLEM` | 4 | 6 | 1 entity | collapse | `reference.reference_item STAFF_PROBLEM` |  |
| `NATIONALITY` | 4 | 2 | 1 entity | collapse | `reference.reference_item NATIONALITY` |  |
| `STAFF_EXPERIENCE` | 6 | 2 | 1 entity | migrate | `hr.work_experience` |  |
| `STAFF_EXIT_INTERVIEW` | 14 | 1 | 1 entity | migrate | `hr.exit_interview` |  |
| `COURSE_TYPE` | 4 | 0 | **absent** | migrate | `hr.course` |  |
| `HR_COURSE` | 5 | ? | 1 entity | migrate | `hr.course` |  |
| `HR_STAFF_INFO` | 14 | ? | 1 entity | merge | `hr.employee` |  |
| `POSITION` | 6 | ? | 1 entity, 1 col. unused | migrate | `hr.position` |  |
| `SALARY_BACKUP` | 23 | ? | **absent** | migrate | `hr.compensation` | the backup copy is dropped; a copy of another table |
| `STAFFWORKSUMMARY` | 0 | view | view | drop | — | a view, becomes a report |
| `STAFF_COURSE_HISTORY` | 6 | ? | 1 entity | merge | `hr.course_enrolment` |  |
| `STAFF_PP` | 8 | 0 | **absent** | decide | — | purpose not confirmed, empty |

### D4 — Contracts and sales

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `PAYMENT_SCHEDULE` | 7 | 2 713 183 | 1 entity | merge | `contract.payment_schedule_entry` | three copies of one schedule |
| `CONTRACT_HISTORY` | 12 | 1 164 674 | 1 entity | merge | `contract.contract_event` |  |
| `CONTRACT_PYRAMID` | 7 | 518 897 | 1 entity | merge | `contract.referral_link` | the archive is a column, not a table |
| `CONTRACT` | 85 | 384 804 | **3 entities**, 1 col. unused | split | `contract.contract + contract_party + party.address_link` | 85 columns, the address and phone blocks leave |
| `CONTRACT_PROMOS` | 3 | 156 636 | 1 entity | migrate | `contract.contract_promotion` |  |
| `CONTRACT_DESCRIPTION` | 6 | 60 075 | 1 entity | merge | `contract.contract` |  |
| `CONTRACT_ADD_MATNR` | 7 | 20 896 | 1 entity | migrate | `contract.contract_item` |  |
| `PRICE_LIST` | 20 | 19 671 | **2 entities** | split | `contract.price_list + price_list_item` |  |
| `PAYMENT_TEMPLATE` | 6 | 17 064 | 1 entity | migrate | `contract.payment_template` |  |
| `SALE_PLAN_ARCHIVE` | 17 | 10 710 | 1 entity, 3 col. unused | merge | `contract.sales_plan + sales_plan_item` | a copy of another table |
| `PLANS` | 7 | 4 939 | name only | merge | `contract.sales_plan + sales_plan_item` |  |
| `PYRAMID` | 14 | 1 748 | 1 entity | merge | `contract.referral_link` | the archive is a column, not a table |
| `FAB_PRICE` | 5 | 566 | name only | merge | `contract.price_list_item` | three price tables, one model |
| `TB_CONTRACT_STATUS_CASA_MO` | 5 | 553 | **absent** | drop | — | a report snapshot |
| `PROMOTION` | 20 | 240 | 1 entity, 1 col. unused | migrate | `contract.promotion` |  |
| `MATNR_PRICE` | 11 | 170 | 1 entity | merge | `contract.price_list_item` | three price tables, one model |
| `SALE_PLAN` | 17 | 128 | 1 entity | merge | `contract.sales_plan + sales_plan_item` |  |
| `CONTRACT_OPER` | 4 | 25 | **2 entities** | merge | `contract.contract_event` |  |
| `CONTRACT_TYPE` | 15 | 23 | 1 entity | migrate | `contract.contract_type` |  |
| `CONTRACT_STATUS` | 10 | 19 | 1 entity, 1 col. unused | collapse | `contract.contract.status` | a status becomes a value, not a table |
| `AGREEMENT` | 8 | 8 | 1 entity | decide | `contract.contract` | purpose not confirmed |
| `PAYMENT_SCHEDULE_TEMPORARY` | 7 | 7 | 1 entity | merge | `contract.payment_schedule_entry` | three copies of one schedule |
| `CONTRACT_HISTORY_OPER_TYPE` | 4 | 5 | 1 entity | merge | `contract.contract_event` |  |
| `CONTRACT_LAST_STATE` | 4 | 5 | 1 entity | collapse | `contract.contract.status` | a status becomes a value, not a table |
| `PLANS_CATEGORY` | 2 | 5 | **absent** | merge | `contract.sales_plan + sales_plan_item` |  |
| `DEMO_PRICE` | 9 | 3 | 1 entity | merge | `contract.price_list_item` | three price tables, one model |
| `AITU_CONTRACT` | 27 | ? | 1 entity, 1 col. unused | merge | `contract.e_signature_request` |  |
| `AITU_CONTRACT_AUD` | 6 | ? | 1 entity | merge | `contract.e_signature_request` |  |
| `AITU_CONTRACT_SYNC_LOG` | 5 | ? | 1 entity | merge | `contract.e_signature_request` |  |
| `AITU_CUSTOMERS_PD` | 16 | ? | 1 entity | merge | `contract.e_signature_request` |  |
| `AITU_DOC_INSTANCE` | 16 | ? | 1 entity | merge | `docflow.document_template` |  |
| `AITU_DOC_TEMPLATE` | 12 | ? | 1 entity | merge | `docflow.document_template` |  |
| `AITU_PAYMENT_SCHEDULE` | 9 | ? | 1 entity | merge | `contract.payment_schedule_entry` |  |
| `AITU_REQUESTS_PD` | 24 | ? | 1 entity | merge | `contract.e_signature_request` |  |
| `AITU_REQUEST_ES` | 18 | ? | 1 entity | merge | `contract.e_signature_request` |  |
| `AITU_SC_BRANCH` | 8 | ? | 1 entity | merge | `reference.branch` | an integration attribute of a branch |
| `PAYMENT_SCHEDULE_ARC` | 6 | 0 | 1 entity | merge | `contract.payment_schedule_entry` | three copies of one schedule; a copy of another table |
| `PYRAMID_ARCHIVE` | 13 | ? | 1 entity | merge | `contract.referral_link` | the archive is a column, not a table; a copy of another table |

### D5 — Accounting and finance

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `BSEG` | 20 | 27 717 360 | 1 entity, 1 col. unused | merge | `accounting.journal_entry_line` |  |
| `BKPF` | 34 | 10 242 354 | 1 entity | merge | `accounting.journal_entry` | a parked document is not an entry: an entry exists only posted, so it maps to the document it originates from |
| `INVOICE_TABLE_ITEM1` | 10 | 9 500 695 | **2 entities** | merge | `accounting.invoice_line` |  |
| `RELATED_DOCS` | 5 | 4 521 553 | 1 entity | migrate | `accounting.document_link` | the polymorphic reference becomes typed |
| `INVOICE_TABLE` | 24 | 4 243 069 | **2 entities** | migrate | `accounting.invoice` |  |
| `PREBSEG` | 20 | 1 930 874 | 1 entity, 1 col. unused | merge | `accounting.journal_entry_line` |  |
| `PREBKPF` | 41 | 993 410 | 1 entity | merge | `accounting.journal_entry` | a parked document is not an entry: an entry exists only posted, so it maps to the document it originates from |
| `BSEG_OLD` | 20 | 289 082 | **absent** | merge | `accounting.journal_entry_line` | a copy of another table |
| `BKPF_OLD` | 34 | 144 541 | 1 entity, 1 col. unused | merge | `accounting.journal_entry` | a copy of another table |
| `RFCOL` | 20 | 86 265 | 1 entity | decide | — | purpose not confirmed |
| `BUDGET_FX_RATE_HISTORICAL` | 4 | 36 853 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `FMGLFLEXT2` | 19 | 19 776 | 1 entity | merge | `accounting.account_balance` | three copies of one totals table |
| `BUDGET_OVERHEAD` | 11 | 13 829 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_SALARY` | 8 | 10 596 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `FMGLFLEXT` | 18 | 9 190 | 1 entity | merge | `accounting.account_balance` | three copies of one totals table |
| `BUDGET_STMM` | 8 | 8 550 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_OVERHEAD_CF` | 5 | 4 407 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_SERVICE_BONUS` | 8 | 3 211 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_BONUS_AMOUNTS` | 10 | 2 193 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `SKAT` | 9 | 1 813 | **3 entities** | split | `accounting.account + account_name` |  |
| `TB_CASA_MONTHLY_COLLECTOR` | 5 | 1 552 | **absent** | drop | — | a report snapshot |
| `BUDGET_SALES_ALLOCATION` | 9 | 948 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_CASAMORE_BONUS` | 7 | 864 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `FIN_PLAN_FIN_MGR_COLLECT_MONEY` | 15 | 628 | 1 entity, 1 col. unused | merge | `accounting.collection_plan` |  |
| `MATNR_ACCOUNTING_CODE` | 9 | 606 | 1 entity | migrate | `accounting.posting_rule` |  |
| `CASH_BANK_BRANCH` | 3 | 598 | 1 entity | merge | `accounting.bank_account` |  |
| `BUDGET_SERVICE_SALES` | 6 | 555 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_SERVICE_STMM` | 6 | 555 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `TRANSACTION` | 10 | 385 | 1 entity, 1 col. unused | migrate | `accounting.payment` |  |
| `BUDGET_CASAMORE_SALES` | 6 | 288 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_CASAMORE_STMM` | 6 | 288 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_VNITRU_FX` | 6 | 238 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `INVOICE_ITEM` | 6 | 172 | **absent** | merge | `accounting.invoice + invoice_line` | the smaller of two invoice implementations |
| `BUDGET_HQ_OVERHEAD` | 5 | 120 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_FX` | 4 | 102 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_BRANCH_MATNR` | 3 | 71 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BSCHL_TYPE` | 5 | 64 | 1 entity | collapse | `accounting.journal_entry_line` | the posting key, account type and sign become columns |
| `BLART_TYPE` | 5 | 59 | 1 entity | collapse | `accounting.journal_entry.kind` |  |
| `DAILY_FIN_DOC` | 12 | 56 | **3 entities** | decide | `accounting.journal_entry` | purpose not confirmed |
| `INVOICE` | 18 | 33 | hand-written SQL only | merge | `accounting.invoice + invoice_line` | the smaller of two invoice implementations |
| `INVOICE_TABLE_ITEM` | 7 | 31 | **absent** | merge | `accounting.invoice_line` |  |
| `FMCP_DATE` | 2 | 16 | 1 entity | merge | `accounting.fiscal_period` |  |
| `MOBILE_MA_TRACK_EMP_PROCESS` | 9 | 16 | **absent** | merge | `accounting.collection_visit` | six tables for one field-collection process |
| `DEPOSIT` | 5 | 15 | 1 entity | merge | `accounting.deposit` |  |
| `MOBILE_MA_TRACK_STEP` | 5 | 11 | 1 entity | merge | `accounting.collection_visit` | six tables for one field-collection process |
| `BANK_PARTNER` | 4 | 9 | 1 entity | collapse | `reference.reference_item BANK_PARTNER` |  |
| `EXPENCE_TYPE` | 3 | 9 | 1 entity | collapse | `reference.reference_item EXPENSE_TYPE` | the spelling is corrected |
| `BUDGET_MAIN_EXPENSE_TYPE` | 2 | 8 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `AES_TYPE1` | 5 | 7 | 1 entity | decide | — | module purpose unknown, nine tables and 21 rows in total |
| `BUDGET_MEASURE_TYPE` | 2 | 7 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `FACT_TABLE` | 14 | 7 | 1 entity | decide | — | purpose not confirmed |
| `KASSA24` | 9 | 7 | 1 entity | migrate | `accounting.payment` |  |
| `MOBILE_MA_COLLECT_MONEY` | 14 | 7 | **absent** | merge | `accounting.collection_visit` | six tables for one field-collection process |
| `SKAT_GRP` | 3 | 7 | **absent** | migrate | `accounting.statement_line` |  |
| `BANK` | 12 | 5 | 1 entity, 2 col. unused | migrate | `accounting.bank` |  |
| `KOART_TYPE` | 2 | 5 | **absent** | collapse | `accounting.journal_entry_line` | the posting key, account type and sign become columns |
| `AES_TYPE2` | 4 | 4 | 1 entity | decide | — | module purpose unknown, nine tables and 21 rows in total |
| `BUDGET_SERVICE_BONUS_TYPE` | 2 | 4 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `FIN_PLAN_COLLECT_MONEY_STATUS` | 5 | 4 | 1 entity | merge | `accounting.collection_plan` |  |
| `FIN_REF_PAYMENT_METHOD` | 5 | 4 | 1 entity | merge | `accounting.collection_plan` |  |
| `MOBILE_MA_COLLECT_RESULT` | 5 | 4 | **absent** | merge | `accounting.collection_visit` | six tables for one field-collection process |
| `AES_COMPBR` | 4 | 3 | 1 entity | decide | — | module purpose unknown, nine tables and 21 rows in total |
| `BANK_ACCOUNT` | 7 | 3 | 1 entity | migrate | `accounting.bank_account` |  |
| `BUDGET_CASAMORE_BONUS_TYPE` | 2 | 3 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `BUDGET_STMM_TYPE` | 2 | 3 | **absent** | merge | `accounting.budget + budget_line` | 22 budget tables, one model with dimensions |
| `MOBILE_MA_PAYMENT_METHOD` | 5 | 3 | **absent** | merge | `accounting.collection_visit` | six tables for one field-collection process |
| `AES_TYPE3` | 4 | 2 | 1 entity | decide | — | module purpose unknown, nine tables and 21 rows in total |
| `POSTING` | 11 | 2 | 1 entity | merge | `accounting.journal_entry` |  |
| `SHKZG_TYPE` | 2 | 2 | 1 entity | collapse | `accounting.journal_entry_line` | the posting key, account type and sign become columns |
| `AES` | 23 | 1 | 1 entity | decide | — | module purpose unknown, nine tables and 21 rows in total |
| `AES_DETAIL` | 4 | 1 | 1 entity | decide | — | module purpose unknown, nine tables and 21 rows in total |
| `AES_OS` | 4 | 1 | 1 entity | decide | — | module purpose unknown, nine tables and 21 rows in total |
| `AES_RNUM` | 3 | 1 | 1 entity | decide | — | module purpose unknown, nine tables and 21 rows in total |
| `AES_STATUS` | 3 | 1 | 1 entity | decide | — | module purpose unknown, nine tables and 21 rows in total |
| `INVOICE_DELIVERY_TERM` | 5 | 1 | 1 entity | collapse | `reference.reference_item` |  |
| `INVOICE_PAYMENT_TERM` | 5 | 1 | 1 entity | collapse | `reference.reference_item` |  |
| `BKPF_BACKUP_1` | 34 | ? | **absent** | merge | `accounting.journal_entry` | a copy of another table |
| `BKPF_HISTORY` | 9 | ? | 1 entity | merge | `audit.audit_event` |  |
| `BKPF_HISTORY_OPER_TYPE` | 4 | ? | 1 entity | merge | `audit.audit_event` |  |
| `BSIK` | 19 | 0 | 1 entity, 1 col. unused | drop | — | empty, open items are a query over journal_entry_line |
| `DEPOSIT_THRESHOLD` | 7 | ? | 1 entity | merge | `accounting.deposit` |  |
| `DEPOSIT_THRESHOLD_AUD` | 6 | ? | 1 entity | merge | `accounting.deposit` |  |
| `FMGLFLEXT_BACKUP` | 18 | ? | **absent** | merge | `accounting.account_balance` | three copies of one totals table; a copy of another table |
| `INSTALLMENT_REPORT` | 12 | ? | **absent** | drop | — | a report is not a table |
| `INSTALLMENT_REPORT_ITEM` | 34 | ? | name only | drop | — | a report is not a table |
| `MOBILE_MA_TRACKED_BP` | 5 | 0 | 1 entity | merge | `accounting.collection_visit` | six tables for one field-collection process |
| `SYSTEM_YEAR_CONTROL` | 1 | ? | **absent** | merge | `accounting.fiscal_period` |  |

### D6 — Compensation calculation

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `PAYROLL` | 30 | 1 923 521 | 1 entity | merge | `payroll.payroll_entry` | the temporary copies become a run status |
| `TEMP_PAYROLL_ARCHIVE` | 33 | 1 394 218 | 1 entity, 6 col. unused | merge | `payroll.payroll_entry` | the temporary copies become a run status; a copy of another table |
| `BONUS_ARCHIVE` | 23 | 120 923 | 1 entity | merge | `payroll.payroll_input` | the archive is a column, not a table; a copy of another table |
| `MIGVOZN` | 9 | 71 868 | name only | decide | `payroll.payroll_entry` | the name is not decoded |
| `BONUS` | 24 | 2 076 | 1 entity | merge | `payroll.payroll_input` | the archive is a column, not a table |
| `BONUS_MAIN` | 10 | 98 | 1 entity | migrate | `payroll.payroll_component_rule` |  |
| `BONUS_TYPE` | 5 | 19 | 1 entity | collapse | `reference.reference_item BONUS_TYPE` |  |
| `BONUS_CATEGORY` | 4 | 4 | 1 entity, 1 col. unused | collapse | `reference.reference_item BONUS_TYPE` |  |
| `FOUND_CONTRIBUTION` | 4 | ? | 1 entity | merge | `payroll.payroll_component` |  |
| `FOUND_CONTRIB_BRANCH_LINK` | 2 | ? | join table only | merge | `payroll.payroll_component` |  |
| `PAYROLL_GUAR_MIGR_AGGR` | 5 | ? | **absent** | merge | `payroll.payroll_entry` | the temporary copies become a run status |
| `SOCIALTAX_COEF` | 26 | 0 | 1 entity | split | `payroll.payroll_rate` | 26 columns become rows of a rate table, one per period |
| `TEMP_PAYROLL` | 33 | 0 | 1 entity, 1 col. unused | merge | `payroll.payroll_entry` | the temporary copies become a run status; a copy of another table |

### D7 — Warehouse and logistics

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `MATNR_PURCHASE_AMOUNT` | 2 | 5 500 674 | 1 entity | merge | `inventory.stock_balance` | a derived aggregate, rebuilt from movements |
| `MATNR_LIST` | 18 | 4 403 387 | 1 entity | migrate | `inventory.stock_item` | the serial-number register |
| `MATNR_SOLD` | 12 | 3 455 098 | 1 entity | merge | `inventory.stock_movement` | a table per movement kind becomes a kind column |
| `MATNR_LIST_SOLD` | 17 | 2 723 568 | 1 entity | merge | `inventory.stock_movement` | a table per movement kind becomes a kind column |
| `MATNR_RECEIVED` | 13 | 865 699 | **2 entities** | merge | `inventory.stock_movement` | a table per movement kind becomes a kind column |
| `MATNR_LOST` | 11 | 792 691 | 1 entity | merge | `inventory.stock_movement` | a table per movement kind becomes a kind column |
| `MATNR_REPAIR_WRITEOFF` | 11 | 116 837 | 1 entity | merge | `inventory.stock_movement` | a table per movement kind becomes a kind column |
| `WRITEOFF_REPAIR_ITEM` | 7 | 72 488 | 1 entity | merge | `inventory.stock_document + stock_document_item` |  |
| `REQUEST_MATNR` | 8 | 67 019 | **2 entities** | merge | `inventory.stock_document + stock_document_item` |  |
| `MATNR_ACCOUNTABLE` | 12 | 34 681 | 1 entity | merge | `inventory.accountable_item` |  |
| `ORDER_MATNR` | 7 | 16 207 | 1 entity | merge | `inventory.purchase_order + purchase_order_item` |  |
| `MATNR_RESERVED` | 12 | 14 719 | 1 entity | merge | `inventory.stock_movement` | a table per movement kind becomes a kind column |
| `WRITEOFF_REPAIR` | 17 | 12 341 | 1 entity | merge | `inventory.stock_document + stock_document_item` |  |
| `REQUEST` | 15 | 10 691 | 1 entity | merge | `inventory.stock_document + stock_document_item` |  |
| `MATNR_MOVING` | 12 | 6 843 | 1 entity | merge | `inventory.stock_document + stock_document_item` |  |
| `MATNR_IN_WERKS` | 6 | 3 538 | **absent** | merge | `inventory.stock_balance` | a derived aggregate, rebuilt from movements |
| `MATNR_MOVEMENT_ITEM` | 8 | 2 637 | 1 entity | merge | `inventory.stock_document + stock_document_item` |  |
| `MATNR_RESOLD_SERVICE` | 11 | 2 419 | 1 entity | merge | `inventory.stock_movement` | a table per movement kind becomes a kind column |
| `ORDER_TABLE` | 14 | 2 367 | 1 entity | merge | `inventory.purchase_order + purchase_order_item` |  |
| `MATNR_RESOLD` | 11 | 1 283 | 1 entity | merge | `inventory.stock_movement` | a table per movement kind becomes a kind column |
| `MATNR_LIMIT_ITEM` | 4 | 1 206 | **2 entities** | merge | `inventory.stock_limit` |  |
| `REV_ITEM` | 11 | 774 | 1 entity | merge | `inventory.stocktake + stocktake_item` | seven tables for one count |
| `MATNR_MOVEMENT` | 21 | 188 | 1 entity, 1 col. unused | merge | `inventory.stock_document + stock_document_item` |  |
| `REQUEST_OUT_MATNR` | 4 | 130 | 1 entity | merge | `inventory.stock_document` |  |
| `MATNR_LIMIT` | 8 | 106 | **2 entities** | merge | `inventory.stock_limit` |  |
| `ORDER_OUT_LIST` | 6 | 99 | 1 entity | merge | `inventory.purchase_order` |  |
| `ORDER_LIST` | 9 | 90 | 1 entity, 2 col. unused | merge | `inventory.purchase_order + purchase_order_item` |  |
| `REV_RESPONSIBLE` | 5 | 32 | 1 entity | merge | `inventory.stocktake + stocktake_item` | seven tables for one count |
| `ACCOUNT_MATNR_STATE` | 11 | 20 | **2 entities** | merge | `inventory.accountable_item` |  |
| `ORDER_OUT` | 10 | 16 | 1 entity | merge | `inventory.purchase_order` |  |
| `ORDER_STATUS_OLD` | 4 | 16 | **absent** | collapse | `inventory.purchase_order.status` | a copy of another table |
| `REQUEST_OUT` | 10 | 10 | 1 entity, 1 col. unused | merge | `inventory.stock_document` |  |
| `REV_ITEM_TITLE` | 8 | 9 | 1 entity | merge | `inventory.stocktake + stocktake_item` | seven tables for one count |
| `REVISION` | 13 | 8 | hand-written SQL only | merge | `inventory.stocktake + stocktake_item` | seven tables for one count |
| `ORDER_TITLE` | 18 | 7 | **absent** | merge | `inventory.purchase_order + purchase_order_item` |  |
| `ORDER_STATUS` | 4 | 4 | 1 entity | collapse | `inventory.purchase_order.status` |  |
| `MATNR_RETURNED` | 12 | 2 | 1 entity | merge | `inventory.stock_movement` | a table per movement kind becomes a kind column |
| `MATNR_LIMIT_ID` | 4 | 0 | **absent** | merge | `inventory.stock_limit` |  |
| `REQUEST_STAFF` | 4 | 0 | 1 entity | merge | `inventory.stock_document` |  |
| `REV_ACT` | 8 | 0 | **absent** | merge | `inventory.stocktake + stocktake_item` | seven tables for one count |
| `REV_ITEMS` | 10 | 0 | **absent** | merge | `inventory.stocktake + stocktake_item` | seven tables for one count |
| `REV_MATNR_STATE` | 8 | 0 | **absent** | merge | `inventory.stocktake + stocktake_item` | seven tables for one count |
| `WRITEOFF_DOC` | 9 | 0 | name only | merge | `inventory.stock_document + stock_document_item` |  |
| `WRITEOFF_ITEM` | 6 | 0 | **absent** | merge | `inventory.stock_document + stock_document_item` |  |

### D8 — Field service

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `SERV_CRMHISTORY` | 18 | 7 888 777 | **2 entities** | merge | `service.service_event` | 7.9M rows, no index, no key |
| `SERV_FILTER_VC_PLAN` | 27 | 5 535 874 | 1 entity | merge | `service.maintenance_plan + maintenance_slot` | vacuum cleaners; the same shape minus one column |
| `SERVICE_POS` | 21 | 3 608 116 | **2 entities**, 5 col. unused | migrate | `service.service_order_line` |  |
| `SERV_FILTER_PLAN` | 28 | 2 181 401 | 1 entity, 1 col. unused | merge | `service.maintenance_plan + maintenance_slot` | purifiers; the F1..F6 column groups become rows; `service_application_id` is null in all 2,863,777 rows |
| `SERVICE_APPLICATION_AUD` | 29 | 1 804 811 | 1 entity | migrate | `service.service_request` | the audit copy goes to audit.audit_event |
| `SERVICE` | 44 | 1 218 587 | 1 entity | split | `service.service_order + party contact data` | 44 columns, the customer name and address leave |
| `SERV_PREMIUM` | 10 | 868 816 | 1 entity | merge | `service.technician_premium` |  |
| `SERV_CON_MATNR_WAR` | 9 | 842 451 | **2 entities**, 1 col. unused | merge | `service.warranty` |  |
| `SERV_CRMSCHEDULE` | 12 | 805 977 | **2 entities** | migrate | `service.service_appointment` |  |
| `SERVICE_APPLICATION` | 28 | 628 426 | 1 entity, 1 col. unused | migrate | `service.service_request` | the audit copy goes to audit.audit_event |
| `SERV_FILTER` | 45 | 188 798 | 1 entity | merge | `service.installed_unit` | water purifiers; 5-6 maintenance positions per unit |
| `SERV_FILTER_VC` | 45 | 186 722 | **2 entities**, 6 col. unused | merge | `service.installed_unit` | vacuum cleaners; 1 position, 35 of 45 columns null in every row |
| `SERV_MATNR_UPD_ITEM` | 7 | 12 474 | 1 entity | merge | `service.upgrade_offer + upgrade_offer_item` | six tables for one scenario |
| `MATNR_SPARE_PARTS` | 3 | 3 615 | **3 entities** | migrate | `service.spare_part` |  |
| `SERV_MATNR_UPD_PRICE` | 10 | 2 716 | 1 entity | merge | `service.upgrade_offer + upgrade_offer_item` | six tables for one scenario |
| `SERV_MATNR_UPD` | 25 | 1 139 | 1 entity | merge | `service.upgrade_offer + upgrade_offer_item` | six tables for one scenario |
| `MATNR_WAR` | 4 | 1 115 | **3 entities** | merge | `service.warranty` |  |
| `SERV_PLAN_PERCENT` | 19 | 1 068 | 1 entity | merge | `service.premium_rule` |  |
| `SERV_PACKET_WAR` | 5 | 637 | **2 entities** | merge | `service.warranty` |  |
| `SERV_PACKET_POS` | 10 | 404 | **2 entities** | migrate | `service.service_package + package_item` |  |
| `SERV_FILTER_PREMIS_AUD` | 19 | 276 | 1 entity | merge | `service.technician_premium` |  |
| `SERV_PACKET` | 16 | 209 | **2 entities** | migrate | `service.service_package + package_item` |  |
| `SERV_FILTER_PREMIS` | 17 | 152 | 1 entity | merge | `service.technician_premium` |  |
| `SERV_ZF_BRANCH_MONTH_TERMS` | 14 | 57 | **2 entities** | merge | `service.premium_rule` |  |
| `SERV_ZF_BRANCH_MONTH_TERMS_AUD` | 16 | 38 | 1 entity, 1 col. unused | merge | `service.premium_rule` |  |
| `SERV_MATNR_UPD_CUSTOMER` | 11 | 20 | 1 entity | merge | `service.upgrade_offer + upgrade_offer_item` | six tables for one scenario |
| `SERV_COEFFICIENT` | 10 | 19 | 1 entity | merge | `service.premium_rule` |  |
| `SERV_CRMACTION` | 5 | 13 | **3 entities** | collapse | `reference.reference_item` |  |
| `SERV_SERVICE_TYPE` | 7 | 10 | 1 entity | collapse | `reference.reference_item + service.service_order` | seven small tables |
| `SERV_MATNR_UPD_LIMIT` | 10 | 9 | 1 entity | merge | `service.upgrade_offer + upgrade_offer_item` | six tables for one scenario |
| `SERV_APP_STATUS` | 4 | 7 | 1 entity | collapse | `service.service_request` | the status and kind become columns |
| `SERV_APP_TYPE` | 4 | 7 | 1 entity | collapse | `service.service_request` | the status and kind become columns |
| `SERV_FILTER_PLAN_STATUS` | 7 | 6 | 1 entity | collapse | `service.maintenance_plan.status` |  |
| `SERV_SERVICE_STATUS` | 7 | 6 | 1 entity | collapse | `reference.reference_item + service.service_order` | seven small tables |
| `SERVICE_OPERATION` | 3 | 4 | **absent** | collapse | `reference.reference_item + service.service_order` | seven small tables |
| `SERVICE_TYPE` | 3 | 4 | name only | collapse | `reference.reference_item + service.service_order` | seven small tables |
| `SERV_CRM_CALL_STATUS` | 4 | 4 | 1 entity | collapse | `reference.reference_item` |  |
| `SERV_CRM_CAT_SPRAV` | 5 | 4 | 1 entity | collapse | `reference.reference_item` |  |
| `SERV_MATNR_UPD_TYPE` | 2 | 3 | 1 entity | merge | `service.upgrade_offer + upgrade_offer_item` | six tables for one scenario |
| `SERV_OPERATION_TYPE` | 7 | 3 | 1 entity | collapse | `reference.reference_item + service.service_order` | seven small tables |
| `SERV_SERVICE_CATEGORY` | 7 | 3 | **3 entities** | collapse | `reference.reference_item + service.service_order` | seven small tables |
| `SERV_SERVICE_OPERATION` | 7 | 2 | 1 entity | collapse | `reference.reference_item + service.service_order` | seven small tables |
| `SERV_PREMIUM_PRICE_TYPE` | 7 | 1 | 1 entity | merge | `service.technician_premium` |  |
| `AUDIT_SERV_CRM_CAT_CHANGE` | 10 | ? | **absent** | merge | `audit.audit_event` |  |
| `AUDIT_SERV_CRM_CAT_SECOND` | 10 | ? | **absent** | merge | `audit.audit_event` |  |
| `SERVICE_MASTER_DRAFT` | 34 | ? | 1 entity | merge | `service.service_order` | a draft is a status, not a table |
| `SERVICE_MASTER_DRAFT_POS` | 17 | ? | 1 entity | merge | `service.service_order` | a draft is a status, not a table |
| `SERVICE_MASTER_DRAFT_PREM` | 11 | ? | 1 entity | merge | `service.service_order` | a draft is a status, not a table |
| `SERV_FILTER_ARCHIVE` | 7 | ? | **2 entities** | drop | — | an archive copy; a copy of another table |
| `SERV_FILTER_PLAN_HIS` | 28 | 0 | 1 entity, 1 col. unused | merge | `service.maintenance_plan + maintenance_slot` | the F1..F6 column groups become rows; a copy of another table |
| `SERV_FILTER_VC_PLAN_HIS` | 27 | 0 | 1 entity | merge | `service.maintenance_plan + maintenance_slot` | the F1..F6 column groups become rows; a copy of another table |
| `SERV_PREMIS_POSITIONS` | 3 | 0 | 1 entity | merge | `service.technician_premium` |  |
| `SERV_PREMIUM_PRICE_TYPE_AUD` | 9 | 0 | **absent** | merge | `service.technician_premium` |  |

### D9 — CRM and call centre

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `CRM_RECO_PHONE` | 6 | 16 466 120 | 1 entity, 2 col. unused | merge | `crm.referral_contact` | 16.5M rows of untyped phone numbers |
| `CRM_DOC_DEMO_HISTORY` | 43 | 2 943 588 | 1 entity, 7 col. unused | merge | `crm.activity` | the history copy goes to audit |
| `CRM_DOC_DEMO` | 41 | 2 802 275 | **2 entities**, 2 col. unused | merge | `crm.activity` | the history copy goes to audit |
| `CRM_CALL` | 22 | 1 734 389 | **2 entities**, 2 col. unused | merge | `crm.activity` | one activity table for every interaction |
| `CRM_KPI_DATA` | 21 | 447 270 | 1 entity, 2 col. unused | merge | `crm.kpi_definition + kpi_target + kpi_fact` | the KPI model exists twice |
| `CRM_VISIT_PHONE` | 6 | 341 460 | 1 entity, 2 col. unused | merge | `crm.referral_contact` | 16.5M rows of untyped phone numbers |
| `KPI_DATA` | 15 | 171 653 | 1 entity | merge | `crm.kpi_definition + kpi_target + kpi_fact` | the KPI model exists twice |
| `DELETE_CRM_DOC_DEMO` | 6 | 168 214 | **absent** | merge | `crm.activity` | the history copy goes to audit; a copy of another table |
| `CRM_KPI_DATA_ITEM` | 18 | 144 092 | 1 entity, 2 col. unused | merge | `crm.kpi_definition + kpi_target + kpi_fact` | the KPI model exists twice |
| `CRM_KPI_ITEM` | 7 | 3 324 | 1 entity, 2 col. unused | merge | `crm.kpi_definition + kpi_target + kpi_fact` | the KPI model exists twice |
| `KPI_ITEM` | 5 | 1 783 | 1 entity | merge | `crm.kpi_definition + kpi_target + kpi_fact` | the KPI model exists twice |
| `KPI_SETTING` | 14 | 387 | **2 entities**, 1 col. unused | merge | `crm.kpi_definition + kpi_target + kpi_fact` | the KPI model exists twice |
| `CC_CALL` | 6 | 157 | **absent** | merge | `crm.activity` | one activity table for every interaction |
| `CC_COMMENT` | 7 | 72 | **absent** | migrate | `crm.case_comment` |  |
| `CRM_TARGET_OWNER` | 17 | 65 | 1 entity, 3 col. unused | migrate | `crm.kpi_target` |  |
| `CC_REF_TASK_DETAIL` | 11 | 48 | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CRM_REF_REASON` | 7 | 31 | 1 entity, 2 col. unused | collapse | `reference.reference_item` | seven reference tables, six of them empty |
| `CC_REF_TASK_CATEGORY` | 10 | 20 | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_CHECK_LIST` | 4 | 16 | **absent** | merge | `crm.checklist + checklist_item` |  |
| `CC_REF_CHECK` | 9 | 12 | **absent** | merge | `crm.checklist + checklist_item` |  |
| `CC_REF_POSITION` | 10 | 12 | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_REF_REASON_CLOSE` | 9 | 12 | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_REF_APPLICATION_CATEGORY` | 9 | 6 | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CRM_SOURCE_APPEAL` | 8 | 5 | 1 entity, 2 col. unused | collapse | `reference.reference_item` | seven reference tables, six of them empty |
| `CC_REF_DEPARTMENT` | 9 | 3 | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_APPLICATION` | 25 | ? | **absent** | merge | `crm.case` |  |
| `CC_APPLICATION_LOG` | 6 | ? | **absent** | merge | `crm.case` |  |
| `CC_REF_CATEGORY` | 8 | ? | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_REF_PRESENT` | 8 | ? | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_REF_PROBLEM` | 9 | ? | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_REF_REASON` | 9 | ? | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_REF_SOURCE` | 9 | ? | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_REF_THEME` | 8 | ? | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_REF_VACANCY` | 8 | ? | **absent** | collapse | `reference.reference_item` | thirteen reference tables of 8 to 11 columns each |
| `CC_RELEASE_LOG` | 8 | ? | **absent** | drop | — | a deployment log inside the data schema |
| `CC_TASK` | 13 | ? | **absent** | merge | `crm.case_task` |  |
| `CC_TASK_DETAIL` | 24 | ? | **absent** | merge | `crm.case_task` |  |
| `CC_TASK_LOG` | 6 | ? | **absent** | merge | `crm.case_task` |  |
| `CRM_CLIENT_PHONE` | 6 | 0 | 1 entity, 3 col. unused | merge | `crm.referral_contact` | 16.5M rows of untyped phone numbers |
| `CRM_DOC_RECO` | 37 | ? | 1 entity, 12 col. unused | merge | `crm.referral` |  |
| `CRM_DOC_RECO_BASE` | 39 | ? | 1 entity, 3 col. unused | merge | `crm.referral` |  |
| `CRM_DOC_VISIT` | 24 | ? | **2 entities**, 3 col. unused | migrate | `crm.activity` |  |
| `CRM_KPI_SETTING` | 25 | ? | 1 entity, 3 col. unused | merge | `crm.kpi_definition + kpi_target + kpi_fact` | the KPI model exists twice |
| `CRM_REF_CLIENT` | 12 | 0 | 1 entity, 2 col. unused | collapse | `reference.reference_item` | seven reference tables, six of them empty |
| `CRM_REF_DEMO_RESULT` | 4 | 0 | **absent** | collapse | `reference.reference_item` | seven reference tables, six of them empty |
| `CRM_REF_GUIDE` | 6 | 0 | 1 entity, 3 col. unused | collapse | `reference.reference_item` | seven reference tables, six of them empty |
| `CRM_REF_RELATIVE` | 6 | 0 | 1 entity, 2 col. unused | collapse | `reference.reference_item` | seven reference tables, six of them empty |
| `CRM_REF_SUPPORT` | 12 | 0 | 1 entity, 2 col. unused | collapse | `reference.reference_item` | seven reference tables, six of them empty |
| `CRM_RELEASE_LOG` | 10 | 0 | 1 entity, 2 col. unused | drop | — | a deployment log inside the data schema |
| `DEALER_KPI_PERIOD` | 13 | ? | 1 entity | merge | `crm.kpi_definition + kpi_target + kpi_fact` | the KPI model exists twice |
| `DEALER_WORD_BONUS` | 5 | ? | 1 entity | merge | `crm.kpi_definition + kpi_target + kpi_fact` | the KPI model exists twice |
| `DEMONSTRATION` | 21 | 0 | 1 entity, 1 col. unused | merge | `crm.activity` | the history copy goes to audit |

### D10 — Document workflow

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `HR_DOC_ACTION_LOG` | 7 | 133 694 | 1 entity | merge | `docflow.document_action` |  |
| `MY_DOCS` | 10 | 73 422 | 1 entity, 1 col. unused | merge | `docflow.document` |  |
| `HR_DOC_APPROVER` | 9 | 33 187 | **2 entities** | merge | `docflow.document_approval` |  |
| `HR_DOC_ITEM` | 19 | 25 795 | 1 entity | merge | `docflow.document_item` |  |
| `HR_DOC` | 14 | 22 563 | 1 entity | merge | `docflow.document` | two parallel implementations of one workflow |
| `HR_DOCUMENT_ACTION_LOG` | 5 | 696 | 1 entity | merge | `docflow.document_action` |  |
| `HR_DOCUMENT_ROUTE` | 9 | 442 | 1 entity | split | `docflow.route + route_step` |  |
| `HR_DOCUMENT_ITEM` | 13 | 429 | 1 entity | merge | `docflow.document_item` |  |
| `HR_DOCUMENT` | 12 | 404 | 1 entity | merge | `docflow.document` | two parallel implementations of one workflow |
| `HR_DOC_TRANSFER_APPROVER` | 9 | 122 | 1 entity | merge | `docflow.document_approval` |  |
| `HR_DOC_TRANSFER_ITEM` | 14 | 54 | 1 entity | merge | `docflow.document_item` |  |
| `HR_DOC_TRANSFER` | 10 | 45 | 1 entity | merge | `docflow.document` | a transfer is a document kind |
| `HR_DOC_TRANSFER_ACTION_LOG` | 5 | 0 | 1 entity | merge | `docflow.document_action` |  |
| `PRIKAZ` | 13 | 0 | 1 entity | merge | `docflow.document` | an order is a document |
| `PRIKAZ_LOG` | 5 | 0 | 1 entity | merge | `docflow.document` | an order is a document |

### D11 — Legal

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `LEGAL_DEPARTMENT` | 10 | 0 | 1 entity | decide | `legal.court_case` | the only table of the domain, empty |

### D12 — Tasks and communications

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `SMS` | 14 | 848 541 | 1 entity | merge | `platform.notification + notification_delivery` | five tables for one channel |
| `OUT_CALL_COMMENT` | 6 | 342 712 | 1 entity | merge | `crm.activity + crm.activity_comment` | an outbound call is an activity with a direction |
| `OUT_CALL` | 10 | 192 940 | 1 entity, 2 col. unused | merge | `crm.activity + crm.activity_comment` | an outbound call is an activity with a direction |
| `MESSAGE_HEADER` | 6 | 74 675 | **2 entities** | merge | `tasks.message + message_recipient` |  |
| `MESSAGE_TO` | 4 | 63 515 | **2 entities** | merge | `tasks.message + message_recipient` |  |
| `TASK_HISTORY` | 7 | 34 865 | 1 entity | merge | `tasks.task + task_event` |  |
| `TASK` | 18 | 29 002 | 1 entity | merge | `tasks.task + task_event` |  |
| `OUT_CALL_TASK` | 3 | 28 680 | 1 entity | merge | `crm.activity + crm.activity_comment` | an outbound call is an activity with a direction |
| `SMS_NOTIFICATION_HISTORY` | 7 | 17 166 | 1 entity | merge | `platform.notification + notification_delivery` | five tables for one channel |
| `SMS_KAZINFO` | 10 | 8 866 | 1 entity | merge | `platform.notification + notification_delivery` | five tables for one channel |
| `SMS_KAZ_INFO_REP` | 12 | 5 354 | 1 entity | merge | `platform.notification + notification_delivery` | five tables for one channel |
| `TASK_CATEGORY_TASK` | 2 | 5 103 | join table only | merge | `tasks.task_category + task_category_link` |  |
| `SMS_CONTROLLER` | 3 | 2 247 | 1 entity | merge | `platform.notification + notification_delivery` | five tables for one channel |
| `BROADCAST_MESSAGE` | 8 | 15 | 1 entity | merge | `platform.notification + notification_template` |  |
| `BROADCAST_TEMPLATE` | 8 | 13 | 1 entity | merge | `platform.notification + notification_template` |  |
| `TASK_ADMIN` | 3 | 13 | 1 entity | merge | `tasks.task + task_event` |  |
| `TASK_CATEGORY` | 5 | 8 | 1 entity | merge | `tasks.task_category + task_category_link` |  |
| `OUT_CALL_STATUS` | 5 | 5 | 1 entity | collapse | `crm.activity.state` |  |
| `TASK_TYPE` | 5 | 5 | 1 entity | collapse | `tasks.task` | the status, priority and kind become columns |
| `MESSAGE_GROUP_USER` | 6 | 4 | 1 entity | merge | `tasks.message + message_recipient` |  |
| `TASK_STATUS` | 5 | 4 | 1 entity | collapse | `tasks.task` | the status, priority and kind become columns |
| `TASK_PRIORITY` | 6 | 3 | 1 entity | collapse | `tasks.task` | the status, priority and kind become columns |
| `MESSAGE_GROUP` | 2 | 2 | 1 entity | merge | `tasks.message + message_recipient` |  |

### — — No domain — copies and dead weight

| Source table | Cols | Rows | In code | Decision | Target | Note |
|---|---:|---:|---|---|---|---|
| `PH_CITY` | 6 | 447 | **absent** | drop | — | a shadow copy of CITY; the schema declares its foreign keys on this copy |
| `PH_POSITION` | 4 | 122 | **absent** | drop | — | a shadow copy of POSITION; the schema declares its foreign keys on this copy |
| `PH_STATE` | 3 | 77 | **absent** | drop | — | a shadow copy of STATE; the schema declares its foreign keys on this copy |
| `PH_CONTRACT_STATUS` | 8 | 19 | **absent** | drop | — | a shadow copy of CONTRACT_STATUS; the schema declares its foreign keys on this copy |
| `PH_CUSTOMER` | 25 | 19 | **absent** | drop | — | a shadow copy of CUSTOMER; the schema declares its foreign keys on this copy |
| `PH_DEPARTMENT` | 4 | 17 | **absent** | drop | — | a shadow copy of DEPARTMENT; the schema declares its foreign keys on this copy |
| `PH_COUNTRY` | 6 | 11 | **absent** | drop | — | a shadow copy of COUNTRY; the schema declares its foreign keys on this copy |
| `PH_SERV_SERVICE_TYPE` | 6 | 10 | **absent** | drop | — | a shadow copy of SERV_SERVICE_TYPE; the schema declares its foreign keys on this copy |
| `PH_CONTRACT_TYPE` | 13 | 9 | **absent** | drop | — | a shadow copy of CONTRACT_TYPE; the schema declares its foreign keys on this copy |
| `PH_SERV_APP_STATUS` | 3 | 7 | **absent** | drop | — | a shadow copy of SERV_APP_STATUS; the schema declares its foreign keys on this copy |
| `PH_SERV_APP_TYPE` | 3 | 7 | **absent** | drop | — | a shadow copy of SERV_APP_TYPE; the schema declares its foreign keys on this copy |
| `PH_SERV_SERVICE_STATUS` | 6 | 6 | **absent** | drop | — | a shadow copy of SERV_SERVICE_STATUS; the schema declares its foreign keys on this copy |
| `PH_CONTRACT_LAST_STATE` | 3 | 5 | **absent** | drop | — | a shadow copy of CONTRACT_LAST_STATE; the schema declares its foreign keys on this copy |
| `PH_BRANCH_TYPE` | 3 | 4 | **absent** | drop | — | no table of that name exists without the prefix; the branch-type list lives only in the shadow schema |
| `PH_BUSINESS_AREA` | 4 | 4 | **absent** | drop | — | a shadow copy of BUSINESS_AREA; the schema declares its foreign keys on this copy |
| `PH_PRODUCT_CATEGORY` | 6 | 3 | **absent** | drop | — | no table of that name exists without the prefix; the product category is a numeric column on `MATNR` instead |
| `PH_COMPANY` | 3 | 1 | **absent** | drop | — | a shadow copy of COMPANY; the schema declares its foreign keys on this copy |
| `PH_BRANCH` | 9 | 0 | **absent** | drop | — | a shadow copy of BRANCH; the schema declares its foreign keys on this copy |
| `PH_CONTRACT` | 84 | 0 | **absent** | drop | — | a shadow copy of CONTRACT; the schema declares its foreign keys on this copy |
| `PH_MATNR` | 24 | 0 | **absent** | drop | — | a shadow copy of MATNR; the schema declares its foreign keys on this copy |
| `PH_MATNR_TYPE` | 3 | 0 | **absent** | drop | — | a shadow copy of MATNR_TYPE; the schema declares its foreign keys on this copy |
| `PH_SERVICE` | 42 | 0 | **absent** | drop | — | a shadow copy of SERVICE; the schema declares its foreign keys on this copy |
| `PH_SERVICE_APPLICATION` | 27 | 0 | **absent** | drop | — | a shadow copy of SERVICE_APPLICATION; the schema declares its foreign keys on this copy |
| `PH_SERVICE_POS` | 21 | 0 | **absent** | drop | — | a shadow copy of SERVICE_POS; the schema declares its foreign keys on this copy |
| `PH_STAFF` | 39 | 0 | **absent** | drop | — | a shadow copy of STAFF; the schema declares its foreign keys on this copy |
