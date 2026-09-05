---
id: TRANS-MAP-D1
title: D1 Reference data — mapping
status: sample
domain: D1
owner: not assigned
---

# D1. Reference data — mapping

Paired with
[product/spec/D1-reference.md](../../product/spec/D1-reference.md). The sample of
the mandatory depth for the other domains.

All the information about the source comes from the code in operation. Cells
saying "not confirmed" mean the data requires verification in
[EPIC-003](../../backlog/EPIC-003-schema-inventory.md), not that nobody looked
for it.

---

## Sources

| Source | Files | What it contains |
|---|---:|---|
| `core/reference` | 176 | reference data: branches, companies, countries, cities, products, reasons |
| `core/mreference` | 78 | the second implementation: addresses, customers, phone numbers, business areas |
| `core/reference/f4` | 34 classes | the "value help" mechanism — suggestions for forms |
| `src/reference` (frontend) | 38 | reference screens and selection modals |
| `werp_jsf` | not confirmed | there may be reference screens that exist only in the legacy |

## Consolidation decisions

The domain is assembled from two parallel implementations — the main source of
work.

| Question | Decision | Rationale | Who took it |
|---|---|---|---|
| Is `reference` or `mreference` the source of truth? | **split by meaning** rather than choosing one | `mreference` contains customers, addresses and phone numbers — those are not reference data but counterparties | not taken |
| Where do `Address`, `Customer`, `Phone`, `PhoneChannel` from `mreference` go | → domain **D2 Counterparties** | a counterparty has a life cycle, reference data does not | not taken |
| Where does `BusinessArea` go (it exists in both) | → D1, one implementation | a duplicate | not taken |
| `Company` and `Bukrs` — two models of the `company` table | one model, `Company` | the same set of fields | not taken |
| The `*F4` mechanism (34 classes) | **abolished** | replaced by list endpoints with search | not taken |
| 15+ small reference lists | → `reference_list` / `reference_item` | 3–5 columns each; separate tables = fifteenfold duplication of code | not taken |

> The "split by meaning" row is an example of how a consolidation decision
> changes the boundaries of **two** domains at once. Such decisions are taken by
> the owner, not by a developer.

---

## Tables

### Table mapping

| Source (class → table) | Decision | Target | Method |
|---|---|---|---|
| `Company` → `company` | consolidate with `Bukrs` | `reference.company` | one model instead of two |
| `Bukrs` → `company` | **deleted** | — | a duplicate of the same table |
| `SubCompany` → not confirmed | not taken | — | needs analysis |
| `Branch` → `branch` | migrate | `reference.branch` | + `path`, `depth`; `type` → `kind` |
| `BranchTree` → the view `BRANCHTREE` | **deleted** | — | it is a view, not a table; replaced by `path` in `branch` |
| `WerksBranch` → not confirmed | not taken | — | the warehouse↔branch link; possibly absorbed by `warehouse.branch_id` |
| `Werks` → `werks_type` (72 rows) | migrate | `reference.warehouse` | the class and the table are renamed; `werks_branch` (184 rows) becomes `warehouse.branch_id` |
| `Country` → `country` | migrate | `reference.country` + `country_name` | localization into a separate table |
| `State` → `state` (77 rows) | migrate | `reference.region` + `region_name` | renaming; the columns are `idstate`, `statename`, `countryid` |
| `City` → `city` (469 rows) | migrate | `reference.city` + `city_name` | `name`, `name_kz` → rows; the key column is `idcity` |
| `Cityreg` → `cityreg` (19 rows), `hcity`, `pbi_regions` | not taken | — | three tables, purpose unclear |
| `Matnr` → `matnr` (1,846 rows, 28 columns) | migrate | `reference.product` + `product_name` | `text45` → `name`; `name_en`, `name_tr` → rows; `unit` is free text and becomes `unit_id` |
| `DemoPrice` → `demo_price` (3 rows) | **moves** | D4, `contract.price_list_item` | a price is not reference data; joins `matnr_price` and `fab_price` |
| `Month` → not confirmed | **do not migrate** | — | months are computed, not stored |
| `Translation` → not confirmed | **do not migrate** | — | replaced by the message system |
| `LeaveReason` | → `reference_item` | `LEAVE_REASON` | collapsed into an enumeration |
| `Reason` | → `reference_item` | `REASON` | likewise |
| `StaffProblem` | → `reference_item` | `STAFF_PROBLEM` | likewise |
| `Nationality` | → `reference_item` | `NATIONALITY` | likewise |
| `AddressType` | → `reference_item` | `ADDRESS_TYPE` | likewise |
| `Department` | not taken | D3? | a unit sits closer to personnel |
| `ErrorTable` | **do not migrate** | — | error codes are part of the API contract |
| `BusinessArea` (×2) | consolidate | `reference_item` `BUSINESS_AREA` | a duplicate across two modules |
| `UpdFile` (×2) | not taken | `platform-file`? | a duplicate; probably a platform concern |
| `Currency` → `currency` (12 rows) | migrate | `reference.currency` + `currency_name` | the codes are not ISO 4217: `YTL` and `CHY` need a mapping decision |
| `ExchangeRate` → `exchange_rate` (2,199 rows) | migrate | `reference.exchange_rate` | the rate is `NUMBER(21,2)` and every date carries an `18:00:00` artefact |
| `Meins` → `meins_type` (3 rows) | migrate | `reference.unit_of_measure` + `unit_of_measure_name` | three units in the reference table, free-text units on the products |
| `ProductCategory` → `ph_product_category` (3 rows) | migrate | `reference.product_category` | the category exists only in the shadow schema; elsewhere it is the numeric column `tovar_category` |
| — | **new** | 7 `*_name` tables | localization |

**In total, measured against the schema** ([00-source-inventory.md](00-source-inventory.md#d1--reference-data)):
30 source objects become 20 target tables — 6 migrate, 6 split into a table plus
its names, 5 collapse into enumerations, 6 are not carried over, and the
remaining 7 `*_name` tables have no predecessor at all. Fewer tables are
genuinely new than a first reading suggests: currencies, rates and units already
exist, they are simply not usable in the shape they are in.

### Column mapping: `branch` → `reference.branch`

A full analysis of one table as a sample of the required level of detail.

| Source | Type | Target | Type | Transformation method | Verification |
|---|---|---|---|---|---|
| `branch_id` | `Long` | `id` | `uuid` | a new UUID; the pair is written to `migration.id_map` | the row count |
| — | — | `company_id` | `uuid` | from `bukrs` through the `id_map` of the `company` table | a referential reconciliation |
| `bukrs` | `String` | *(deleted)* | — | replaced by `company_id` | — |
| `parent_branch_id` | `Long` | `parent_id` | `uuid` | through `id_map`; `null` for the root | a referential reconciliation + the absence of cycles |
| `business_area_id` | `Long` | *(into `reference_item`)* | — | → an item of the `BUSINESS_AREA` list | a per-value count reconciliation |
| `country_id` | `Long` | *(deleted)* | — | derived through `city_id` → `region` → `country` | a sampled reconciliation |
| `text45` | `String` | `name` | `text` | renaming | a character-by-character match |
| — | — | `code` | `text` | **no source** — needs a decision ([the risk below](#domain-risks)) | — |
| `type` | `Long` | `kind` | `text` | `1→HEAD`, `2→REGION`, `3→BRANCH`, `4→POINT` | a per-value count reconciliation |
| `TOVAR_CATEGORY` | `Long` | *(into D4 or deleted)* | — | a product category is not a property of a branch | the owner's decision |
| `state_id` | `Long` | *(deleted)* | — | derived through `city_id` | a sampled reconciliation |
| — | — | `city_id` | `uuid` | **no direct source** — reconstructed from `state_id` and the address | a manual reconciliation of a sample |
| `latitude` | `Double` | `latitude` | `numeric(9,6)` | a type conversion; a range check | a value reconciliation |
| `longitude` | `Double` | `longitude` | `numeric(9,6)` | likewise | likewise |
| `center_lat` | `Double` | *(do not migrate)* | — | the purpose is not confirmed | the owner's decision |
| `center_long` | `Double` | *(do not migrate)* | — | likewise | likewise |
| — | — | `is_active` | `boolean` | **no source** — all existing ones are considered active | a manual review of the list |
| — | — | `path`, `depth` | `ltree`, `int` | computed from the tree after the transfer | a tree connectivity check |
| — | — | `address_text` | `text` | from the address, if one is found | — |
| — | — | housekeeping columns | | `created_at` = the moment of migration, `created_by` = the "migrated" marker | — |

**Six target columns have no source**, two source columns have no target, and
three are computed. There is no one-to-one mapping — and that will be the case in
most tables.

### Production data constants in the code

The `Branch` class declares `GREEN_LIGHT_MAIN_BRANCH_ID = 207L` and
`AURA_MAIN_BRANCH_ID = 2L` — identifiers of specific records in the production
database, hardcoded into the sources
([01-database-mapping.md](../01-database-mapping.md#5-production-data-identifiers-in-the-code)).

| Constant | What it means | What replaces it | Action |
|---|---|---|---|
| `AURA_MAIN_BRANCH_ID` | the head branch of the main company | `branch.kind = HEAD` + `company_id` | find every usage |
| `GREEN_LIGHT_MAIN_BRANCH_ID` | the head branch of the second company | likewise | likewise |

Finding **all** the places where these constants are used is a mandatory task of
the domain's analysis: each place contains a business rule expressed through a
record identifier.

---

## Data

Measured on the test contour on 2026-09-03. Production has to be re-checked
before the transfer.

| Table | Rows | Quality | Known problems |
|---|---:|---|---|
| `company` | 7 | checked | two models on one table |
| `branch` | 217 | **checked, clean** | no `code`; the tree is connected — see below |
| `werks_type` | 72 | not checked | `is_main` as an `int` |
| `country` | 11 | **checked, consistent** | `currency_id` and `currency` agree in all 11 rows, but two codes are not ISO 4217 |
| `city` | 469 | **checked** | `name` filled in all 469 rows; `name_kz` fill rate not yet measured |
| `state` | 77 | not checked | |
| `currency` | 12 | **checked** | `YTL` (retired in 2009) and `CHY` (not a code) |
| `exchange_rate` | 2,199 | **checked** | the rate has two decimal places; every date carries `18:00:00` |
| `matnr` | 1,846 | not checked | `unit` is free text; `name_ru` and `name_kk` do not exist while `name_en` and `name_tr` do |

**The branch tree check has been run and passes:** 217 branches over 7 companies,
**exactly one root per company**, no dangling `parent_branch_id`. `branch.type`
holds exactly four values — 1 (4 rows), 2 (11), 3 (157), 4 (45) — which matches
the `HEAD` / `REGION` / `BRANCH` / `POINT` mapping above.

**The checks still outstanding:**

- the absence of cycles in the branch tree (the connectivity check does not prove
  it);
- how fully `name_kz` is populated in `city` — the completeness of the
  localization depends on it;
- the referential integrity of `city.stateid` → `state`, `state` → `country`;
- duplicates in the reference lists being collapsed into `reference_item`;
- the same set of checks against production rather than the test contour.

---

## Classes

| Source | Decision | Target |
|---|---|---|
| `ReferenceRestController` (1,934 lines, 72 endpoints, 51 injections) | **break down** | 12 D1 controllers + endpoints leaving for D3, D4, D6, D9, D0 |
| `BranchController`, `CompanyController`, `CountryController`, `DemoPriceController`, `DepartmentController`, `LeaveReasonController`, `MatnrsRestController`, `NationalityController`, `RefAddressController`, `ServServiceCategoryController`, `StaffProblemController`, `UserRolesController` | consolidate | 12 controllers, one per resource |
| `UserRolesController` | **moves** | D0 Platform — that is access, not reference data |
| `RefAddressController` | **moves** | D2 Counterparties |
| `reference/dao/*` | replace | `adapter/persistence/*Repository` |
| `reference/service/*` | break down | `application/*Handler` + `domain/*Service` |
| `reference/f4/*` (34 classes) | **delete** | list endpoints with search |
| `reference/entities`, `reference/tables`, `reference/model` (three model packages) | consolidate | `domain/model` + `adapter/persistence/*Record` |
| `mreference/*` (customers, addresses, phone numbers) | **moves** | D2 Counterparties |
| — | **new** | `ReferenceFacade`, `ReferenceQuery` — the public interface |
| — | **new** | 8 domain events |
| — | **new** | `BranchTreeRule`, `SingleMainWarehouseRule`, `RateChronologyRule`, `DeactivationRule` |
| — | **new** | `ExchangeRateService`, `ReferenceCache` |
| — | **new** | the domain's tests |

### Breaking down `ReferenceRestController`

The domain's key task and one of the first in the project
([02-backend-mapping.md](../02-backend-mapping.md#breakdown-priorities)). Of the
class's 72 endpoints, the smaller part stays in D1.

| Endpoint group | Target domain |
|---|---|
| `/companies`, `/countries`, `/states`, `/cities`, `/regions`, `/branches/*`, `/products`, `/product-categories`, `/oper-types`, `/spare-part-*` | **D1** |
| `/crm/staffListForCrm`, `/crm/staffListAllForCrm`, `/positions` | D3 Personnel |
| `/crm/salaryListForCrm/{staffId}`, `/crm/salaryListByYearAndMonthForCrm` | D6 Compensation calculation |
| `/crm/dealersContractSales*` | D4 Contracts and sales |
| `/crm/pyramid*`, `/crm/*ForCrm` (dealer groups) | D9 CRM |
| `/checkAccess`, `/checkAccessWithTcode`, `/userInfo` | D0 Platform |
| `/reasons/{type}` | D1, → `reference_item` |

This breakdown is not only about the API: it shows where the **real** domain
boundaries run, and that is why it is done before the domain map is confirmed
([product/02-domains.md](../../product/02-domains.md#what-must-be-confirmed-with-the-business-before-g1)).

---

## Endpoints

| Source | Decision | Target |
|---|---|---|
| `GET /api/core/reference/branch/?branchId=` | migrate | `GET /api/v1/reference/branches/{id}` |
| `GET /api/core/reference/branch/list` | migrate | `GET /api/v1/reference/branches` (+ pagination, filters) |
| `POST/PUT /api/core/reference/branch` | migrate | `POST /branches`, `PUT /branches/{id}` |
| `DELETE /api/core/reference/branch?branchId=` | **semantics change** | `POST /branches/{id}/deactivation` |
| `GET /api/core/reference/country?id=` | migrate | `GET /countries/{id}` |
| `GET /api/core/reference/country/list` | migrate | `GET /countries` |
| `GET /api/core/reference/FETCH_COUNTRIES` | **consolidate** | `GET /countries` |
| `GET /api/core/reference/FETCH_COUNTRIES2` | **consolidate** | `GET /countries` |
| `GET /api/core/reference/company/?bukrs=` | migrate | `GET /companies/{id}` |
| `GET /api/core/reference/states/{countryId}` | **shape changes** | `GET /regions?countryId=` |
| `GET /api/core/reference/cities/{stateId}` | **shape changes** | `GET /cities?regionId=` |
| `GET /api/core/reference/regions/{cityId}` | break down | the purpose is unclear — "a city's region" contradicts the hierarchy |
| `GET /api/core/reference/branches/{bukrs}` | consolidate | `GET /branches?companyId=` |
| `GET /api/core/reference/branches/service/{bukrs}`, `/branches/marketing/{bukrs}` | **consolidate** | `GET /branches?companyId=&kind=` |
| `GET /api/core/reference/branches/all`, `/branches/type` | consolidate | `GET /branches` |
| `GET /api/core/reference/checkAccess`, `/checkAccessWithTcode` | **moves** | D0 |
| `GET /api/core/reference/crm/**` (13 endpoints) | **moves** | D3, D4, D6, D9 |
| — | **new** | `/exchange-rates`, `/units`, `/lists/*`, `/warehouses`, `/branches/tree`, `/products/import` |

**Three `/branches/*` endpoints collapse into one** with parameters — a typical
example of how 1,286 endpoints get reduced
([03-api-mapping.md](../03-api-mapping.md#expected-reduction)).

### `fetchCountries` returns an entity

`GET /FETCH_COUNTRIES` returns `Map<Long, Country>` — a JPA entity directly,
with no DTO. The client receives the table's structure.

During the transfer the response shape changes to the one described in the
specification. **That is a breaking change** for everyone using it — the list of
consumers has to be established before the transfer (TASK-0203).

---

## Pages

| Legacy screen | Files | Scenario | Product page | Decision |
|---|---:|---|---|---|
| `mainoperation/NationalityListPage` | 1 | maintaining the nationalities list | `REF-LST-L` | **consolidated** into the shared enumerations screen |
| `mainoperation/LeaveReasonListPage` + the form | 2 | termination reasons | `REF-LST-L` | consolidate |
| `mainoperation/StaffProblemListPage` + the form | 2 | employee issues | `REF-LST-L` | consolidate |
| `mainoperation/DemoPriceListPage` + the form | 2 | demo prices | undetermined | the owner's decision: D1 or D4 |
| `mainoperation/SubCompanyListPage` + a modal | 2 | subcompanies | `REF-COM-L` | consolidate |
| `f4/branch/*` (3 files) | 3 | selecting a branch | the `BranchLookup` component | **not a page** |
| `f4/bukrs/*` (2) | 2 | selecting a company | `Lookup` | not a page |
| `f4/matnr/*` | 1 | selecting a product | `ProductLookup` | not a page |
| `f4/position/*` (2) | 2 | selecting a position | `Lookup` (D3) | moves |
| `f4/date/*` (2) | 2 | selecting a month and a year | `Field.Date` | **deleted** |
| `f4/address/*` (7) | 7 | addresses | D2 Counterparties | moves |
| `f4/Customer/*` (3) | 3 | customers | D2 Counterparties | moves |
| `f4/phone/*` (5) | 5 | phone numbers | D2 Counterparties | moves |
| `f4/staff/*` | 1 | selecting an employee | `Lookup` (D3) | moves |
| `f4/cashBankBalance/*` | 1 | balances | D5 | moves |
| `/dit/werpreference` | ? | not confirmed | — | needs analysis |
| — | — | maintaining warehouses | `REF-WHS-L`, `REF-WHS-F` | **new** |
| — | — | maintaining exchange rates | `REF-RAT-L` | **new** |
| — | — | uploading the product catalogue from a file | `REF-PRD-I` | **new** |
| — | — | maintaining units of measure | `REF-UOM-L` | **new** |

**The frontend bottom line for D1:** of the section's 38 files a significant part
are selection modals, which become **three components** of the design system
rather than pages; more than half of the files move to D2 and D3; and 4 new pages
appear.

Five screens of small reference lists collapse into one
([`REF-LST-L`](../../product/spec/D1-reference.md#pages)) — a direct consequence
of the `reference_item` decision.

---

## Behaviour changes

What the user will notice after the cutover. Every item requires a decision from
the domain owner **before** implementation.

| Change | What the user will see | Decision |
|---|---|---|
| Deleting a branch → deactivation | the "Delete" button becomes "Deactivate"; records do not disappear | not taken |
| The appearance of `version` | the message "the record was changed by another user" instead of a silent loss of edits | not taken |
| Small reference lists on one screen | five menu items become one | not taken |
| Selection modals → a component | uniform behaviour instead of different behaviour in different windows | not taken |
| Pagination in lists | cities and products are no longer loaded in full | not taken |
| The new `code` field on a branch | a mandatory field that did not exist | **requires the data to be populated before the cutover** |
| A branch tree instead of a flat list | a new way of navigating | not taken |
| A separate currency reference list | the currency stops being a string in the country | not taken |

The penultimate row is an example of a find that **must go into the data
cleansing plan**: if the branches have no code, it has to be filled in in the
legacy before the cutover rather than invented during the migration
([05-data-migration.md](../05-data-migration.md#s4-data-quality)).

---

## Domain risks

| # | Risk | How it shows | Action |
|---|---|---|---|
| D1-R1 | A branch has no `code` column | there is nothing to fill the new mandatory field with | decide: generate it, fill it in by hand in the legacy, or drop the mandatory requirement |
| D1-R2 | The branch tree's connectivity | **checked on the test contour and clean**: one root per company, no dangling parents | repeat on production; the cycle check is still outstanding |
| D1-R3 | A branch's `city_id` is reconstructed indirectly | some branches will end up with no city | measure the share; if significant, fill it in by hand |
| D1-R4 | Production ID constants in the code | a missed usage breaks a business rule | find every usage; each is a separate decision |
| D1-R5 | The consumers of `FETCH_COUNTRIES` are unknown | a breaking change to the response shape | establish the list of consumers before the transfer |
| D1-R8 | The currency codes are not ISO 4217 | `YTL` instead of `TRY`, `CHY` instead of `CNY` | the owner decides the mapping before the transfer; every amount in those currencies is affected |
| D1-R6 | `mreference` contains more than reference data | the D1/D2 boundary is drawn incorrectly | confirm the split with the owners of both domains |
| D1-R7 | Breaking down `ReferenceRestController` changes the domain map | 13 endpoints leave for four other domains | do the breakdown **before** the domain map is confirmed at G1 |

D1-R7 is the reason this domain is analysed first: its breakdown affects the
boundaries of other domains, not only its own.
