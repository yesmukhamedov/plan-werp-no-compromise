---
id: TRANS-MAP-01
title: The schema as the code sees it
status: measured
measured_at: 2026-09-04
source: four Java repositories, 5,355 files
---

# The schema as the code sees it

The [schema inventory](00-source-inventory.md) says what exists in the database.
This document says what the code does with it: which tables it maps, which
columns it never touches, and — the part that matters most for the rewrite —
**where the meaning of a column actually lives**.

The target schema is [product/03-database/](../../product/03-database/README.md); the
transformation rules are [01-database-mapping.md](../01-database-mapping.md).

**How it was obtained.** All 5,355 `.java` files of the four repositories were
parsed for `@Table`, `@SecondaryTable`, `@JoinTable`, `@Column`, `@JoinColumn`,
field declarations, superclasses, `static final` constants, enumerations,
Hibernate mapping annotations and SQL string literals. Inheritance is resolved,
so a column mapped in an abstract parent counts as mapped in the child. The
method and its limits are in the [appendix](#appendix-method-and-its-limits).

---

## 1. Table coverage

| The code's relationship to a table | Tables |
|---|---:|
| has an entity class of its own | 314 |
| reached only as a join or secondary table | 2 |
| reached only from hand-written SQL | 2 |
| the name appears in a string, nothing maps it | 12 |
| **absent from all four repositories** | **119** |

**One table in four is not named anywhere in the code.** Those 119 tables hold
1,104 columns and 561,151 rows. They fall into six groups:

| Group | Tables | Explanation |
|---|---:|---|
| `PH_*` shadow copies | 25 | confirmed dead: no code, and they hold the schema's foreign keys ([00-source-inventory.md](00-source-inventory.md#31-a-shadow-schema-of-25-tables-carries-the-foreign-keys)) |
| `CC_*` call-centre mirror | 25 | the Oracle mirror is not yet used; the running code is the separate PostgreSQL service |
| `BUDGET_*` | 22 | **nothing anywhere reads or writes them** — see below |
| copies and temporaries | 9 | `BSEG_OLD`, `BKPF_BACKUP_1`, `TEMP_LANG`, `DELETE_CRM_DOC_DEMO`, … |
| `MOBILE_MA_*` | 4 | the field-collection process |
| the rest | 34 | `OAUTH_CLIENT_DETAILS`, `SKAT_GRP`, `INVOICE_ITEM`, `MATNR_IN_WERKS`, `REV_ACT`, `STAFF_PP`, `WERKSFLEXT`, the `*_AUD` tables, … |

Not every one of the 119 is dead. `OAUTH_CLIENT_DETAILS` is read by the Spring
authorization server through its own SQL; the `*_AUD` tables are written by
Hibernate Envers, which needs no mapping of its own; the `CC_*` mirror is waiting
for a migration that has not happened. **Absence from the code is a strong
candidate for "dead", not a verdict** — the verdict needs access statistics
(TASK-0302).

### The 22 budget tables have no application at all

The word `budget` occurs in **none** of the five repositories — not in the Java
of the backend, the first-generation monolith, the CRM or the call centre, and
not in the JavaScript of the frontend. Yet `BUDGET_OVERHEAD` holds 13,829 rows,
`BUDGET_SALARY` 10,596, `BUDGET_STMM` 8,550, `BUDGET_FX_RATE_HISTORICAL` 36,853 —
about 83,000 rows in total, and the data is not old.

Something writes them, and it is not in any repository. The likely consumer is
the Power BI integration (the table `POWERBI_LINKS` and a Power BI screen exist
on the frontend), but that is a hypothesis, not a finding.

**This is a scope question, not a migration detail**
([OQ-015](../12-open-questions.md#oq-015)): if budgeting is a live business
process running outside the application, the rewrite either absorbs it or
knowingly leaves it outside. Both are decisions; neither is made by silence.

## 2. One table, several models

| Entity classes mapping the same table | Tables |
|---|---:|
| 1 | 259 |
| 2 | 44 |
| 3 | 10 |
| 4 | 1 |

**Fifty-five tables are mapped by more than one entity class.**

| Table | Classes |
|---|---|
| `COMPANY` | `Bukrs`, `Company`, `Company2`, `CompanyQE` |
| `EXCHANGE_RATE` | `ExchangeRate`, `ExchangeRateModel`, `Facur01ExchangeRateQE` |
| `SKAT` | `Hkont`, `Skat`, `SkatQE` |
| `CONTRACT` | `Contract`, `ContractForCrmQE`, `LgsContract` |
| `STAFF` | `Staff`, `StaffForCrmQE`, `StaffGridEntity` |
| `SALARY` | `Salary`, `SalaryForCrmQE`, `StaffPosition` |
| `DAILY_FIN_DOC` | `DailyFinDoc`, `DailyFinDoc2`, `DailyFinDocStatus` |
| `SERV_CRMACTION` | `ServCRMAction`, `ServCrmAction`, `ServiceCRMAction` |
| `MATNR_WAR` | `LgsMatnrWarranty`, `MatnrWar`, `MatnrWarranty` |
| `SERV_SERVICE_CATEGORY` | `ProductCategory`, `ServServiceCategory`, `ServiceCategory` |
| `PRICE_LIST` | `PriceList`, `PriceListNew` |
| `CURRENCY` | `Currency`, `Currency2` |

Three patterns, and they need different decisions:

- **`X` and `X2`, `X` and `XNew`** — a second model written when the first could
  not be changed. Both are alive; which one is authoritative is unknown from the
  code.
- **`XQE`** — a read model for one screen, mapped onto the same table.
- **`ServCRMAction` / `ServCrmAction` / `ServiceCRMAction`** — the same concept
  spelled three ways in three modules, which is what happens when a name is not
  fixed anywhere ([GLOSSARY.md](../../GLOSSARY.md)).

Each of the 55 is a consolidation decision for the domain owner, and each is a
place where two models can write mutually inconsistent rows today.

## 3. Column coverage

Over the 314 tables that have an entity — 3,626 columns:

| | Columns |
|---|---:|
| mapped by a class or named in a query | 3,506 (97%) |
| **touched by nothing** | **120 (3%)** |
| tables where every column is mapped | 257 of 314 |

And separately: **1,229 columns live in the 135 tables that have no entity at
all** — a quarter of the schema's columns.

The 120 untouched columns are not a random tail:

| Columns | Tables | What they are |
|---|---:|---|
| `MIGRATED_AT`, `SRC_SYSTEM` | 21 each | scaffolding of the PostgreSQL→Oracle CRM migration, never read since |
| `F6_MT`, `F6_SID`, `F6_DATE`, `F6_DATE_NEXT`, `F6_DATE_PREV`, `F6_SID_PREV` | `SERV_FILTER_VC` | the sixth maintenance position of a product that has one — dead in the code and null in the data, from both sides ([00-source-inventory.md](00-source-inventory.md#33-the-same-model-implemented-twice-repeatedly)) |
| `MANAGER_ID`, `TRAINER_ID`, `DIRECTOR_ID`, `COORDINATOR_ID`, `MAIN_TRAINER_ID`, `APPROVE` | `TEMP_PAYROLL_ARCHIVE` (1.4M rows) | six columns of a payroll copy nothing reads |
| `PRICE`, `GIVEN_QUANTITY`, `LAST_STATE`, `DOP_SERV_ID`, `MATNR_PRICE_LIST_ID` | `SERVICE_POS` (3.6M rows) | five columns on a table of three and a half million rows |
| `LATITUDE`, `LONGITUDE` | `ADDRESS`, `CRM_DOC_DEMO_HISTORY`, `BRANCH` | coordinates collected and never used; in `ADDRESS` they are `VARCHAR2(30)` |
| `IS_ACTIVE`, `NAME_KK`, `NAME_EN`, `NAME_TR`, `CONTENT`, `PHONE_NUMBER`, … | scattered | columns added and abandoned |

**Every one of them is a migration decision**, and the default is not to carry it
over. A column no code has read in years does not become valuable by being copied
into a new schema.

Six columns across three tables are reached **only** by hand-written SQL —
`INVOICE.AWKEY`, `INVOICE.INVOICE_DATE`, `TASK_CATEGORY_TASK.TASK_ID` and three
more. They are invisible to any refactoring that goes through the entities.

## 4. Where the meaning of a column actually lives

This is the finding that matters most for the target schema.

The schema stores numbers. **The meaning of those numbers is in `static final`
constants inside the Java classes:** 968 numeric constants in total, of which
**572 are declared inside entity classes**.

| Table | Constants | What they define |
|---|---:|---|
| `INVOICE_TABLE` | 27 | `TYPE_POSTING=1`, `TYPE_WRITEOFF=2`, `TYPE_SEND=3`, `TYPE_ACCOUNTABILITY=4`, `TYPE_WRITEOFF_DOC=5`, `TYPE_POSTING_IN=6`, … |
| `HR_DOCUMENT` | 20 | `STATUS_ON_CREATE=1`, `STATUS_ON_VIEW=2`, `STATUS_ON_AGREEMENT=3`, `STATUS_ON_EXECUTION=4`, `STATUS_CLOSED=5`, `STATUS_REFUSED=6` |
| `CONTRACT_STATUS` | 18 | `STATUS_STANDARD=1`, `STATUS_GIFT=2`, `STATUS_CANCELLED=3`, `STATUS_PROBLEM_REAL=4`, `STATUS_CLOSED=5`, `STATUS_REISSUED=6` |
| `POSITION` | 16 | `DEALER_POSITION_ID=4`, `MANAGER_POSITION_ID=3`, `DEMOSEC_POSITION_ID=8`, `DIRECTOR_POSITION_ID=10`, … |
| `HR_DOC_ACTION_LOG` | 16 | `ACTION_CREATE=1`, `ACTION_UPDATE=2`, `ACTION_VIEW=3`, `ACTION_SEND=4`, `ACTION_APPROVE=5`, `ACTION_REFUSE=6` |
| `SERVICE` | 13 | `TYPE_FILTERS=1`, `TYPE_FITTING=2`, `TYPE_SERVICE=3`, `TYPE_PACKET=4`, `TYPE_SELLING=5` |
| `HR_DOC` | 13 | `TYPE_RECRUITMENT=1`, `TYPE_TRANSFER=2`, `TYPE_DISMISS=3`, `TYPE_CHANGE_SALARY=4`, `TYPE_BYPASS_SHEET=5` |
| `REQUEST` | 10 | `STATUS_NEW=1`, `STATUS_IN_PROCESS=2`, `STATUS_SENT=3`, `STATUS_CLOSED=4`, `STATUS_COLLECTED=5`, `STATUS_ADJUSTMENT=6` |
| `SERV_APP_STATUS` | 10 | `NEW=1`, `DISTRIBUTED=2`, `MASTER_FILL=3`, `MANAGER_FILL=4`, `DONE=5`, `CANCEL=6` |
| `MATNR` | 8 | `MATNR_TYPE_TOVAR=1`, `MATNR_TYPE_PART=2`, `MATNR_TYPE_FILTER=3`, `MATNR_TYPE_ACCESSORY=4`, `MATNR_TYPE_DEMOMODEL=5`, `MATNR_TYPE_MATVALUE=6` |
| `SERV_SERVICE_TYPE` | 8 | `REPLACING_FILTERS=1`, `INSTALLATION=2`, `SELL_PARTS=3`, `PREVENTION=4`, `SERVICE_INSTALL=5`, `MOUNTING=6` |

Plus **94 enumeration types** declared elsewhere in the code.

Three consequences:

1. **An export from the database is unreadable.** A report says `TYPE_ID = 4`;
   only a developer with the sources open knows it means "accountability".
2. **The list can be extended in one place and not the other.** A value inserted
   into the table with no constant behind it is invisible to the code; a constant
   with no row behind it is a runtime error.
3. **This is the migration input nobody has written down yet.** Every one of
   these lists is the mapping table for the "number → readable string"
   transformation ([01-database-mapping.md](../01-database-mapping.md#part-ii-transformation-rules)).
   They are here, extracted, and they need the owner's confirmation that the list
   is complete and each value still means what its name says.

In the target these become `ck` constraints on a text column, readable in the
database and in any export
([rule 5](../../product/03-database/rules/05-types.md#51-enumerations)).

## 5. Row identifiers hardcoded in the sources

**119 constants name a specific row of production data:**

| Constant | Value | Where |
|---|---:|---|
| `Branch.AURA_MAIN_BRANCH_ID` | 2 | backend v2, and again in the first-generation monolith |
| `Branch.GREEN_LIGHT_MAIN_BRANCH_ID` | 207 | the same |
| `Position.DEALER_POSITION_ID` | 4 | backend v2 ×2, the monolith |
| `Position.DIRECTOR_POSITION_ID` | 10 | the same |
| `Position.STAZHER_DEALER_POSITION_ID` | 67 | the same |
| `Staff.POS_MASTER_FILTER` | 13 | backend v2 |
| `LgsUtil.CENTRAL_WERKS_ID` | 2 | backend v2 |
| `RefTransactions.DEMO_PRICE_TRANSACTION_ID` | 1236 | backend v2 |
| `LocalUserAccessRepository.ADMIN_ROLE_ID` | 1 | backend v2 |
| `PayrollService.DEBUG_STAFF_ID` | 12353 | backend v2 |
| `DmsdList.BAHTYBAY_STAFF_ID` | 4620 | the first-generation monolith |

The last two deserve their own line: a payroll service carries a debugging
employee identifier, and a screen carries **a named individual's** staff
identifier as a constant.

**239 constants are declared in more than one file** — up to five copies each
(146 in two files, 61 in three, 26 in four, 6 in five). They currently agree.
Nothing makes them agree.

Every one of these is a business rule expressed as a row number. In the target it
becomes a property of the data — `branch.kind = HEAD`, `position.is_sales`,
`warehouse.is_main` — and the rule for that is already written
([01-database-mapping.md](../01-database-mapping.md#9-production-data-identifiers-in-the-code)).
What was missing was the list. It is now measurable: **119 places, each a
separate design decision.**

## 6. Logic hidden in the mapping

Business rules that are neither in the database nor in a service, but in the
annotations:

| Annotation | Uses | What it does |
|---|---:|---|
| `@Formula` | 40 | a correlated SQL subquery evaluated per row on every load |
| `@Where` | 9 | a filter silently added to every query for that entity |
| `@Filter` | 1 | a conditional filter |
| `@PrePersist` / `@PreUpdate` | 5 | logic on save |

`@Where` is the dangerous one, because it changes results at a distance:

```java
@Where(clause = "is_active=1")        // Phone
@Where(clause = "active = 1")         // the ServFilter link of a contract
@Where(clause = "active <> 0")        // the plan history entities
```

Three spellings of "active" on comparable columns, in one codebase. Anyone
querying `Phone` gets only active numbers and cannot see from the call site that
a filter was applied — and a report that must count all numbers is quietly wrong.

`@Formula` puts business meaning into the mapping and a query into every row:

```java
// Customer: what the customer is called depends on whether it is a person
@Formula("case when fiz_yur is not null and fiz_yur = 2 " +
         "then concat(...lastname, firstname, middlename) else name end")

// PriceListNew: a product's name fetched per row
@Formula("(SELECT m.text45 FROM Matnr m WHERE m.MATNR = MATNR)")

// Staff: a full name assembled in SQL with INITCAP
```

The first one is the definition of `FIZ_YUR = 2` — a fact about the data model
that exists only inside a string in an annotation. The second is an N+1 built
into the mapping: loading a price list loads a subquery per row.

In the target, a derived value is a generated column, a read model or a domain
method — never a SQL string inside a mapping annotation
([rule 9](../../product/03-database/rules/09-logic-in-the-database.md)).

## 7. Two writers on one column

`CUSTOMER.FULL_PHONE` and `CUSTOMER.FULL_ADDRESS` are maintained by a database
trigger and a stored procedure (`CUS_FULL_PHONE_COMPOUND_ALL`,
`UPDATE_CUSTOMER_FULL_PHONE`). They are **also** mapped in `Customer` as ordinary
writable fields:

```java
@Column(name = "full_phone", nullable = true)
private String fullPhone;
```

No `insertable = false`, no `updatable = false`. Two independent writers, no rule
about which wins. Whichever ran last is the value.

In the target the concatenated string does not exist: phone numbers are rows in
`party.phone`, and "all the customer's numbers" is a query
([the `party` schema](../../product/03-database/schemas/party.md)).

## 8. A rule bound to a column: personal-data access audit

Reading a customer's phone number is audited. The audit is written by hand at
**22 call sites**, each passing the column it is about:

```java
phoneCheckAudService.logPhoneAccess(phone, "FULL_PHONE", userId,
                                    "CUSTOMER", customerId, transactionId);
```

The destination is `PHONE_CHECK_AUD`, and the marker is a string literal —
`"PHONE"` in some calls, `"FULL_PHONE"` in others.

This is a compliance rule attached to a specific column, and it is the kind of
thing a rewrite loses silently: nothing in the schema says the column is
sensitive, and nothing but a developer's memory adds the audit call to the
twenty-third place.

**It must be carried over as a platform property of the column, not as a call
convention** — the target's audit is a platform subsystem
([rule 11](../../product/03-database/rules/11-audit.md)), and which
columns are personal data is stated in the domain specification, not in the call
site. That is a requirement for D2 and for
[EPIC-010](../../backlog/EPIC-010-security-audit.md).

## 9. What this changes in the plan

| Finding | Consequence |
|---|---|
| 119 tables absent from the code | the strongest candidates for "do not migrate"; combined with access statistics they can remove a quarter of the tables from scope |
| 22 budget tables with no application | a scope question for the business, before G0 |
| 55 tables with several models | 55 consolidation decisions, each an owner's decision, each a possible source of inconsistent data today |
| 120 unused columns plus 1,229 columns in unmapped tables | the migration carries less than the schema suggests — but each omission is a recorded decision |
| 572 constants defining column meanings | the number→string mapping tables for the migration exist; they need confirming, not inventing |
| 119 hardcoded row identifiers | 119 design decisions, each turning a row number into a property |
| 9 `@Where` filters | nine invisible query filters that change what a report returns; each must be found in the specification, not rediscovered after the cutover |
| The phone-access audit | a column-level compliance rule that must survive the rewrite by design, not by memory |

## Risks

| # | Risk | How it shows | Action |
|---|---|---|---|
| CODE-R1 | A table absent from the code is dropped, and something outside the code was writing it | data stops appearing after the cutover, noticed weeks later | do not drop on code absence alone — require access statistics (TASK-0302) |
| CODE-R2 | The budget process lives outside every repository | budgeting silently disappears in the rewrite | establish its owner and its tooling before G0 |
| CODE-R3 | A constant list is incomplete or out of date | a value in the data has no name, and the migration maps it to nothing | reconcile every constant list against `SELECT DISTINCT` on the column |
| CODE-R4 | A `@Where` filter is not reproduced | reports quietly return more or fewer rows than before | list all nine in the domain specifications and cover each with a parity test |
| CODE-R5 | 239 duplicated constants drift apart during the freeze | two modules disagree about which row is the head branch | fix them into data before the transfer, not after |
| CODE-R6 | The phone-access audit is lost | a compliance failure that nobody notices until an inspection | carry it as a schema-level property of the column |

---

## Appendix: method and its limits

Every `.java` file of `werp_java_back_v2`, the first-generation monolith,
the standalone CRM and the standalone call centre — 5,355 files — was parsed for:

- `@Table`, `@SecondaryTable`, `@JoinTable`, `@CollectionTable` → which table a
  class maps, and how;
- `@Column`, `@JoinColumn` → the explicitly named columns;
- field declarations → the implicitly named columns (`camelCase` → `SNAKE_CASE`,
  the naming strategy this stack uses);
- `extends` chains → columns inherited from an abstract parent count as mapped;
- SQL string literals containing `FROM`, `JOIN`, `INSERT INTO`, `UPDATE` or
  `DELETE FROM` → tables and columns reached without an entity;
- `static final` fields with a literal value → the constants;
- `enum` declarations;
- `@Formula`, `@Where`, `@Filter`, `@ColumnTransformer`, `@PrePersist`,
  `@PreUpdate`, `@PostLoad`.

**What the method can miss.** A column name assembled by string concatenation at
runtime; a table reached only through a dynamically built query; a mapping in XML
rather than annotations; usage from a source outside these four repositories —
which is precisely the case the budget tables raise. The direction of the error
is known: the method **over-reports** what is mapped (field names are matched
generously) and therefore **under-reports** unused columns. The 120 unused
columns are a floor, not a ceiling.

Two claims in this document were verified by hand against the sources rather than
trusted to the parser: the address columns of `CONTRACT` (mapped, in
`marketing/entities/Contract.java`) and the `full_phone` mapping (writable, no
`insertable=false`). The first was found because an earlier version of the parser
mis-attributed classes with the same name in different packages; the counts here
are from the corrected version.
