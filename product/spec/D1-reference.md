---
id: PROD-SPEC-D1
title: D1 Reference data — full specification
status: designed
domain: D1
owner: not assigned
---

# D1. Reference data

The reference specification: it sets the mandatory depth for the other domains
([spec/README.md](README.md#d1--the-reference-sample)).

DB schema: `reference` · Module: `reference` · API: `/api/v1/reference` ·
Interface section: `pages/reference`

---

## Purpose and boundaries

Reference data shared across the whole system: the organizational structure,
geography, currencies, the product catalogue, standard enumerations.

**In scope:** companies, branches, warehouses, countries, regions, cities,
currencies, exchange rates, units of measure, product categories and product
items, standard reasons, positions, lines of business.

**Out of scope:**

| What | Where | Why not here |
|---|---|---|
| Customers, addresses, phone numbers | D2 Counterparties | a counterparty is not reference data; it has a life cycle |
| Employees, headcount | D3 Personnel | likewise |
| Price lists, contract terms | D4 Contracts | they depend on the contract and change often |
| Users, roles, permissions | D0 Platform | that is access, not reference data |
| Warehouse stock balances | D7 Warehouse | a warehouse is reference data, a balance is operational data |

**The domain's key property:** all the others depend on it, while it depends on
none (apart from the platform). That is why it is designed and implemented first,
and why its public interface must be especially narrow — twelve modules will be
using it.

## Model

Five aggregates:

| Aggregate | Root | Composition | Invariants |
|---|---|---|---|
| Organization | `Company` | `Branch` (a tree), `Warehouse` | a branch belongs to one company; the branch tree has no cycles; a company has exactly one head branch |
| Geography | `Country` | `Region`, `City` | a city belongs to a region, a region to a country; the country code is unique |
| Currencies | `Currency` | `ExchangeRate` | the currency code is unique; a rate on a date is unique per currency pair |
| Product catalogue | `ProductCategory` | `Product`, `UnitOfMeasure` | an item belongs to one category; the article number is unique within a company |
| Enumerations | `ReferenceList` | `ReferenceItem` | an item's code is unique within its list |

An aggregate is the transaction boundary and the loading boundary. A reference
between aggregates is by identifier.

### The shared enumeration mechanism

Small reference lists (termination reasons, address types, issue statuses,
operation kinds) **do not get tables of their own**. They are stored as items of
named lists in two tables, `reference_list` / `reference_item`.

The reason: each such list is 3–5 columns and one screen. Fifteen separate tables
with fifteen controllers and fifteen screens mean fifteenfold duplication of the
same code.

A reference list gets **its own** table if at least one of the following holds: it
has more than three meaningful attributes; it is referenced with an integrity
constraint; it has business rules of its own; it is edited by a separate role.

---

## Tables

Schema `reference` — **20 tables in 6 groups**, with every column, its type, its
constraints and its indexes:
**[03-database/schemas/reference.md](../03-database/schemas/reference.md)**.

The physical model lives at one level and is not repeated here
([how to read a schema file](../03-database/README.md#how-to-read-a-schema-file)).
What belongs to this document is the model above — the aggregates and their
invariants — and everything below it: the classes that implement them, the
endpoints that expose them, the permissions that guard them and the pages that
use them.


## Reference data

Loaded by the schema migration, versioned together with it, not editable in the
interface:

- `country`, `region` — per ISO 3166 with names in three languages;
- `currency` — per ISO 4217;
- `unit_of_measure` — the base set;
- `reference_list` — the system lists with `is_system = true`.

---

## Classes

The `reference` module. The structure —
[backend rule 2](../04-backend/rules/02-module-structure.md).

### `api/` — the public interface

Everything the other twelve modules see. Deliberately narrow.

| Class | Operations |
|---|---|
| `ReferenceFacade` | `getCompany(id)`, `getBranch(id)`, `getBranchSubtree(id)`, `getWarehouse(id)`, `getProduct(id)`, `getCurrency(id)`, `getRate(from, to, date)`, `getItem(list, code)`, `resolveNames(ids, locale)` |
| `ReferenceQuery` | batch reads: `getCompanies(ids)`, `getBranches(ids)`, `getProducts(ids)` — so that the caller does not make N calls |
| dto | `CompanyDto`, `BranchDto`, `BranchTreeDto`, `WarehouseDto`, `CountryDto`, `CityDto`, `CurrencyDto`, `ExchangeRateDto`, `ProductDto`, `ProductCategoryDto`, `UnitOfMeasureDto`, `ReferenceItemDto` |
| events | `CompanyChanged`, `BranchChanged`, `BranchDeactivated`, `WarehouseChanged`, `ProductChanged`, `ProductDeactivated`, `ExchangeRateAdded`, `ReferenceItemChanged` |

`resolveNames` exists so that other domains do not pull a whole reference list
just to display a name next to an identifier.

The deactivation events are separate from the change events: deactivating a
branch or an item affects open documents in other domains, and they must react to
it.

### `domain/` — business logic

| Class | Type | Responsibility |
|---|---|---|
| `Company` | entity | a company and its invariants |
| `Branch` | entity | a branch, its position in the tree |
| `BranchTree` | value object | operations over the tree: subtree, ancestors, path |
| `Warehouse` | entity | a warehouse |
| `Country`, `Region`, `City` | entities | geography |
| `Currency` | entity | a currency |
| `ExchangeRate` | entity | a rate on a date, immutable |
| `Product`, `ProductCategory` | entities | the product catalogue |
| `UnitOfMeasure` | entity | a unit of measure |
| `ReferenceList`, `ReferenceItem` | entities | enumerations |
| `LocalizedName` | value object | a name in a language |
| `BranchTreeRule` | rule | the absence of cycles, the correctness of levels |
| `SingleMainWarehouseRule` | rule | one main warehouse per branch |
| `RateChronologyRule` | rule | the correctness of a rate's date |
| `DeactivationRule` | rule | what cannot be deactivated while dependents exist |
| `BranchService` | domain service | moving a tree node, recomputing `path` |
| `ExchangeRateService` | domain service | picking the rate for a date; if absent, the nearest preceding one |

### `application/` — scenarios

One handler per scenario; each is a transaction boundary.

`CreateCompanyHandler`, `UpdateCompanyHandler`, `CreateBranchHandler`,
`UpdateBranchHandler`, `MoveBranchHandler`, `DeactivateBranchHandler`,
`CreateWarehouseHandler`, `UpdateWarehouseHandler`, `CreateProductHandler`,
`UpdateProductHandler`, `DeactivateProductHandler`, `ImportProductsHandler`,
`CreateProductCategoryHandler`, `MoveProductCategoryHandler`,
`AddExchangeRateHandler`, `ImportExchangeRatesHandler`,
`CreateReferenceItemHandler`, `UpdateReferenceItemHandler`,
`ReorderReferenceItemsHandler`.

Read queries: `BranchTreeQuery`, `ProductSearchQuery`, `CityLookupQuery`,
`ExchangeRateQuery` — separate from the command handlers, without a write
transaction.

### `adapter/web/` — controllers

Generated from the specification; they contain no logic.

`CompanyController`, `BranchController`, `WarehouseController`,
`CountryController`, `RegionController`, `CityController`,
`CurrencyController`, `ExchangeRateController`, `ProductController`,
`ProductCategoryController`, `UnitOfMeasureController`,
`ReferenceItemController`.

**Twelve controllers, one per resource.** None exceeds 200 lines, and none
reaches into another domain.

### `adapter/persistence/` — storage

`CompanyRepository`, `BranchRepository`, `WarehouseRepository`,
`CountryRepository`, `RegionRepository`, `CityRepository`,
`CurrencyRepository`, `ExchangeRateRepository`, `ProductRepository`,
`ProductCategoryRepository`, `UnitOfMeasureRepository`,
`ReferenceListRepository`, `LocalizedNameRepository`.

Plus `ReferenceCache` — a cache of the rarely changing reference lists with
invalidation on domain events.

### Volume estimate

~90 classes: 12 controllers, 13 repositories, 19 handlers, 4 read queries, ~14
entities and value objects, 4 rules, 2 domain services, 2 facades, ~12 DTOs, 8
events, mappers.

---

## Endpoints

`/api/v1/reference`. The full description is in the OpenAPI specification; here —
the composition and the permissions.

### Companies

| Method | Path | Permission | Note |
|---|---|---|---|
| GET | `/companies` | `reference.company.read` | list, paginated |
| GET | `/companies/{id}` | `reference.company.read` | |
| POST | `/companies` | `reference.company.write` | |
| PUT | `/companies/{id}` | `reference.company.write` | |
| POST | `/companies/{id}/deactivation` | `reference.company.write` | instead of DELETE |

### Branches

| Method | Path | Permission | Note |
|---|---|---|---|
| GET | `/branches` | `reference.branch.read` | list; filters `companyId`, `kind`, `cityId`, `isActive` |
| GET | `/branches/tree` | `reference.branch.read` | the tree; parameter `rootId` |
| GET | `/branches/{id}` | `reference.branch.read` | |
| POST | `/branches` | `reference.branch.write` | |
| PUT | `/branches/{id}` | `reference.branch.write` | |
| POST | `/branches/{id}/move` | `reference.branch.write` | changing the parent |
| POST | `/branches/{id}/deactivation` | `reference.branch.write` | |

### Warehouses

| Method | Path | Permission |
|---|---|---|
| GET | `/warehouses` | `reference.warehouse.read` |
| GET | `/warehouses/{id}` | `reference.warehouse.read` |
| POST | `/warehouses` | `reference.warehouse.write` |
| PUT | `/warehouses/{id}` | `reference.warehouse.write` |
| POST | `/warehouses/{id}/deactivation` | `reference.warehouse.write` |

### Geography

| Method | Path | Permission |
|---|---|---|
| GET | `/countries` | `reference.geo.read` |
| GET | `/countries/{id}` | `reference.geo.read` |
| GET | `/regions` | `reference.geo.read` |
| GET | `/cities` | `reference.geo.read` |
| GET | `/cities/{id}` | `reference.geo.read` |
| POST / PUT | `/countries`, `/regions`, `/cities` | `reference.geo.write` |

The lists of regions and cities are filtered through `countryId` / `regionId` —
**separate paths of the form `/regions/{countryId}` do not exist**: a filter does
not change the resource.

### Currencies and rates

| Method | Path | Permission |
|---|---|---|
| GET | `/currencies` | `reference.currency.read` |
| GET | `/exchange-rates` | `reference.currency.read` |
| GET | `/exchange-rates/current` | `reference.currency.read` |
| POST | `/exchange-rates` | `reference.currency.write` |
| POST | `/exchange-rates/import` | `reference.currency.write` |

`POST /exchange-rates` has no matching PUT: a rate is immutable.

### Product catalogue

| Method | Path | Permission |
|---|---|---|
| GET | `/products` | `reference.product.read` |
| GET | `/products/{id}` | `reference.product.read` |
| POST | `/products` | `reference.product.write` |
| PUT | `/products/{id}` | `reference.product.write` |
| POST | `/products/{id}/deactivation` | `reference.product.write` |
| POST | `/products/import` | `reference.product.import` |
| GET | `/product-categories` | `reference.product.read` |
| GET | `/product-categories/tree` | `reference.product.read` |
| POST / PUT | `/product-categories` | `reference.product.write` |
| GET | `/units` | `reference.unit.read` |
| POST / PUT | `/units` | `reference.unit.write` |

### Enumerations

| Method | Path | Permission |
|---|---|---|
| GET | `/lists` | `reference.list.read` |
| GET | `/lists/{code}/items` | `reference.list.read` |
| POST | `/lists/{code}/items` | `reference.list.write` |
| PUT | `/lists/{code}/items/{id}` | `reference.list.write` |
| POST | `/lists/{code}/items/reorder` | `reference.list.write` |

**48 endpoints over 12 resources in total.**

### The domain's error codes

`reference.company.not_found`, `reference.company.code_taken`,
`reference.branch.not_found`, `reference.branch.cycle_detected`,
`reference.branch.has_active_children`, `reference.warehouse.main_already_exists`,
`reference.product.article_taken`, `reference.product.in_use`,
`reference.rate.not_found_for_date`, `reference.rate.same_currency`,
`reference.item.code_taken`, `reference.list.is_system`.

---

## Permissions

| Permission | What it allows |
|---|---|
| `reference.company.read` / `.write` | companies |
| `reference.branch.read` / `.write` | branches |
| `reference.warehouse.read` / `.write` | warehouses |
| `reference.geo.read` / `.write` | geography |
| `reference.currency.read` / `.write` | currencies and rates |
| `reference.product.read` / `.write` / `.import` | the product catalogue |
| `reference.unit.read` / `.write` | units of measure |
| `reference.list.read` / `.write` | enumerations |

**The data-scope restriction:** a user sees the companies and branches within
their scope of visibility. It is applied in `adapter/persistence`, not in the
controller ([ADR-0006](../../docs/02-decisions/ADR-0006-auth-model.md)).

Geography, currencies and units of measure are not scope-restricted — they are
shared.

---

## Pages

`pages/reference`. The types —
[frontend rule 2](../06-frontend/rules/02-page-types.md).

| Code | Route | Type | Permission | Purpose |
|---|---|---|---|---|
| `REF-COM-L` | `/reference/companies` | L | `reference.company.read` | the list of companies |
| `REF-COM-F` | `/reference/companies/:id` | F | `reference.company.write` | the company card-form |
| `REF-BRN-T` | `/reference/branches` | L | `reference.branch.read` | the branch tree with a side panel |
| `REF-BRN-F` | `/reference/branches/:id` | F | `reference.branch.write` | the branch form |
| `REF-WHS-L` | `/reference/warehouses` | L | `reference.warehouse.read` | the list of warehouses |
| `REF-WHS-F` | `/reference/warehouses/:id` | F | `reference.warehouse.write` | the warehouse form |
| `REF-GEO-L` | `/reference/geo` | L | `reference.geo.read` | geography: countries → regions → cities |
| `REF-CUR-L` | `/reference/currencies` | L | `reference.currency.read` | currencies |
| `REF-RAT-L` | `/reference/exchange-rates` | L | `reference.currency.read` | rates with a date filter |
| `REF-PRD-L` | `/reference/products` | L | `reference.product.read` | the catalogue: the category tree + a table |
| `REF-PRD-F` | `/reference/products/:id` | F | `reference.product.write` | the item form |
| `REF-PRD-I` | `/reference/products/import` | F | `reference.product.import` | uploading the catalogue from a file |
| `REF-UOM-L` | `/reference/units` | L | `reference.unit.read` | units of measure |
| `REF-LST-L` | `/reference/lists/:code?` | L | `reference.list.read` | **all** standard enumerations, one screen |

**14 pages.** The last one serves all the enumerations at once: the list of
reference lists on the left, the items of the selected one on the right. Fifteen
separate screens for fifteen small reference lists are not created — that is the
practical result of
[the shared enumeration mechanism](#the-shared-enumeration-mechanism).

### The domain's components

Besides the design system, the domain adds three reusable components — used by
**all the other** sections of the application:

| Component | Where it is used | Behaviour |
|---|---|---|
| `BranchLookup` | almost every filter in the system | a tree with search, multiple selection, "including subordinates" |
| `ProductLookup` | contracts, warehouse, service | search by article number, name, barcode; lazy loading |
| `CurrencyAmountInput` | everywhere an amount is entered | amount + currency, precision per currency |

They live in `features/`, not in `pages/reference`: the page does not own them.

### Page states

Every page must define: loading (`Skeleton`), empty (`EmptyState` with a hint),
error (`ErrorState` with the code and the `traceId`), no permission
(`PermissionGate`).

---

## Audit

The domain owner's decision on what exactly is audited
([rule 11](../03-database/rules/11-audit.md)):

| Table | Audited | Why |
|---|---|---|
| `company` | all changes | affects all financial reporting |
| `branch` | all changes, `parent_id` and `is_active` especially | moving a node changes the reporting by unit |
| `warehouse` | all changes | affects warehouse accounting |
| `product` | changes to `article`, `unit_id`, `is_serial_tracked`, `is_active` | affects documents |
| `exchange_rate` | inserts only | the rows are immutable |
| `reference_item` | changes to `code`, `is_active` | the code is used in documents |
| `country`, `region`, `city`, `currency`, `unit_of_measure` | **not audited** | they change once in years, and the changes are harmless |

The names (`*_name`) are not audited: editing a translation does not change the
meaning of the data.

---

## Open questions

| # | Question | Affects |
|---|---|---|
| D1-Q1 | Is a "region" level needed in the branch tree as a separate `kind`, or is the structure of arbitrary depth? | `branch.kind`, `BranchTreeRule` |
| D1-Q2 | Where do the exchange rates come from — automated loading from an external source or manual entry? | `exchange_rate.source`, `ImportExchangeRatesHandler` |
| D1-Q3 | Is the article number unique within a company or across the whole system? | `ux_product__company_id__article` |
| D1-Q4 | Which of the small reference lists genuinely require tables of their own? | the composition of `reference_list` |
| D1-Q5 | Are translations of product item names needed? | `product_name` |

The questions are closed by the domain owner before implementation begins
(Phase 1). Each of them changes the schema, so they are closed **before** the
first migration, not after.
