---
id: PROD-03-S-REFERENCE
title: "reference schema — D1 Reference data"
status: draft
---

# `reference` — D1 Reference data

| | |
|---|---|
| Domain | D1 Reference data ([02-domains.md](../../02-domains.md)) |
| Domain specification | [D1-reference.md](../../spec/D1-reference.md) |
| Tables | **20** |
| State of the model | **designed** |
| Table groups | 6 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `reference`. All tables have the
[mandatory columns](../rules/04-mandatory-columns.md) — `id`, `created_at`,
`created_by`, `updated_at`, `updated_by`, `version` — which are not repeated in
the lists below.

## Group 1. The organization

Who the company is and how it is divided. Read together on every screen that
carries a "by branch" filter, which is almost every screen in the system.

### `company` — a company

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` length 1–10 | the company's short code |
| `name` | `text` | no | `ck` length 1–255 | the name |
| `full_name` | `text` | yes | | the full legal name |
| `tax_number` | `text` | yes | `ck` length 1–20 | the tax number |
| `country_id` | `uuid` | no | → `country.id` | the country of registration |
| `default_currency_id` | `uuid` | no | → `currency.id` | the accounting currency |
| `is_active` | `boolean` | no | default `true` | in operation |

Indexes: `ux_company__code`, `ix_company__country_id`.

### `branch` — a branch

The tree of a company's units.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | → `company.id` | the owner |
| `parent_id` | `uuid` | yes | → `branch.id` | the parent in the tree; `null` means the root |
| `code` | `text` | no | `ck` length 1–20 | the branch code |
| `name` | `text` | no | | the name |
| `kind` | `text` | no | `ck IN (HEAD, REGION, BRANCH, POINT)` | the level in the structure |
| `city_id` | `uuid` | yes | → `city.id` | the city it is located in |
| `address_text` | `text` | yes | | the address as a single line |
| `latitude` | `numeric(9,6)` | yes | `ck` −90…90 | the latitude |
| `longitude` | `numeric(9,6)` | yes | `ck` −180…180 | the longitude |
| `is_active` | `boolean` | no | default `true` | in operation |
| `path` | `ltree` | no | | the materialized path for tree queries |
| `depth` | `integer` | no | `ck` ≥ 0 | the depth, denormalized from `path` |

Indexes: `ux_branch__company_id__code`, `ix_branch__parent_id`,
`ix_branch__path` (GiST), `ix_branch__city_id`,
`ix_branch__company_id` partial `WHERE is_active`.

Constraints: `ck_branch__no_self_parent` (`parent_id <> id`); the absence of
cycles is checked by the application rule `BranchTreeRule` — in the database it
is inexpressible.

> `path` and `depth` are stored because the branch tree is read on almost every
> screen in the system (the "by branch" filter), and a recursive query on every
> read is measurably more expensive. They are maintained by a trigger and covered
> by a test.

### `warehouse` — a warehouse

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | → `company.id` | the owner |
| `branch_id` | `uuid` | no | → `branch.id` | the link to a branch |
| `code` | `text` | no | `ck` length 1–20 | the warehouse code |
| `name` | `text` | no | | the name |
| `kind` | `text` | no | `ck IN (MAIN, TRANSIT, SERVICE, RETURN)` | the type |
| `is_main` | `boolean` | no | default `false` | the main one for the branch |
| `is_active` | `boolean` | no | default `true` | in operation |

Indexes: `ux_warehouse__company_id__code`, `ix_warehouse__branch_id`,
`ux_warehouse__branch_id__is_main` partial `WHERE is_main` — guarantees no more
than one main warehouse per branch.

## Group 2. Geography

A three-level hierarchy: country -> region -> city. Referenced by addresses in
D2, by branches here, and by tax and reporting rules in D5.

### `country` — a country

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` length 2, upper case | ISO 3166-1 alpha-2 |
| `code3` | `text` | yes | `ck` length 3 | ISO 3166-1 alpha-3 |
| `currency_id` | `uuid` | yes | → `currency.id` | the country's currency |
| `phone_prefix` | `text` | yes | `ck` length 1–6 | the phone prefix |
| `phone_pattern` | `text` | yes | | the pattern for validating a number |

Indexes: `ux_country__code`, `ux_country__code3`.

The names live in `country_name` (see
[localization](#reference-data-localization)).

### `region` — a region

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `country_id` | `uuid` | no | → `country.id` | the country |
| `code` | `text` | yes | | the region code |

Indexes: `ix_region__country_id`, `ux_region__country_id__code` partial
`WHERE code IS NOT NULL`.

### `city` — a city

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `region_id` | `uuid` | no | → `region.id` | the region |
| `code` | `text` | yes | | the city code |
| `phone_prefix` | `text` | yes | | the phone code |
| `timezone` | `text` | no | default `Asia/Almaty` | the time zone |

Indexes: `ix_city__region_id`.

> `country_id` is **deliberately absent** from a city: it is derived through the
> region. Denormalization here creates the possibility of inconsistency with no
> gain — a selection of cities always goes by region.

## Group 3. Currency and rates

Every amount anywhere in the system names a currency from this group, and every
conversion names a rate from it.

### `currency` — a currency

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` length 3, upper case | ISO 4217 |
| `numeric_code` | `text` | yes | `ck` length 3 | the ISO numeric code |
| `symbol` | `text` | yes | | the symbol |
| `minor_units` | `smallint` | no | `ck` 0–4, default 2 | decimal places for display |

Indexes: `ux_currency__code`.

### `exchange_rate` — an exchange rate

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `from_currency_id` | `uuid` | no | → `currency.id` | from currency |
| `to_currency_id` | `uuid` | no | → `currency.id` | to currency |
| `rate_date` | `date` | no | | the effective date |
| `rate` | `numeric(19,8)` | no | `ck` > 0 | the rate |
| `source` | `text` | no | `ck IN (NATIONAL_BANK, MANUAL, PARTNER)` | the source |

Indexes: `ux_exchange_rate__from__to__date`, `ix_exchange_rate__rate_date`.

Constraint: `ck_exchange_rate__different_currencies`
(`from_currency_id <> to_currency_id`).

> A rate is **historical data, not reference data**: the rows are neither changed
> nor deleted. Recalculating retroactively changes the financial reporting, so a
> correction is recorded as a new row with a different `source` rather than as an
> edit to the existing one.

## Group 4. The product catalogue

What the company sells and services. Referenced by contracts, invoices, stock
movements and service orders.

### `unit_of_measure` — a unit of measure

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` length 1–10 | the code |
| `precision` | `smallint` | no | `ck` 0–6, default 0 | the permitted number of decimal places |

Indexes: `ux_unit_of_measure__code`.

### `product_category` — a product category

The tree of categories.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `parent_id` | `uuid` | yes | → `product_category.id` | the parent |
| `code` | `text` | no | | the category code |
| `path` | `ltree` | no | | the materialized path |
| `is_active` | `boolean` | no | default `true` | in operation |

Indexes: `ux_product_category__code`, `ix_product_category__parent_id`,
`ix_product_category__path` (GiST).

### `product` — a product item

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | → `company.id` | the owner |
| `category_id` | `uuid` | no | → `product_category.id` | the category |
| `article` | `text` | no | `ck` length 1–40 | the article number |
| `name` | `text` | no | | the name |
| `unit_id` | `uuid` | no | → `unit_of_measure.id` | the base unit |
| `barcode` | `text` | yes | `ck` length 8–14 | the barcode |
| `is_serial_tracked` | `boolean` | no | default `false` | tracked by serial numbers |
| `warranty_months` | `smallint` | yes | `ck` ≥ 0 | the warranty |
| `is_active` | `boolean` | no | default `true` | in operation |

Indexes: `ux_product__company_id__article`, `ix_product__category_id`,
`ix_product__barcode` partial `WHERE barcode IS NOT NULL`,
`ix_product__name_trgm` (GIN, trigrams) — for searching by part of the name.

## Group 5. The standard enumerations

The mechanism that keeps thirty small reference lists from becoming thirty
tables, thirty controllers and thirty screens.

### `reference_list` / `reference_item` — standard enumerations

`reference_list`:

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` `^[A-Z_]+$` | the list code, for example `LEAVE_REASON` |
| `is_system` | `boolean` | no | default `false` | a system list — not editable from the interface |

Indexes: `ux_reference_list__code`.

`reference_item`:

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `list_id` | `uuid` | no | → `reference_list.id` | the list |
| `code` | `text` | no | | the item code |
| `sort_order` | `integer` | no | default 0 | the display order |
| `is_active` | `boolean` | no | default `true` | in operation |
| `attributes` | `jsonb` | yes | | the list's additional attributes |

Indexes: `ux_reference_item__list_id__code`,
`ix_reference_item__list_id` partial `WHERE is_active`.

> `attributes` is the only use of `jsonb` in the domain, and it is justified: the
> set of attributes differs from list to list and does not participate in
> queries. As soon as filtering by an attribute is required, that list gets a
> table of its own.

## Group 6. Localized names

Translatable names are moved into paired tables. Adding a language does not
require a schema migration
([rule 6](../rules/06-localization.md)).

| Table | Columns |
|---|---|
| `country_name` | `country_id` → `country.id`, `locale`, `name` |
| `region_name` | `region_id`, `locale`, `name` |
| `city_name` | `city_id`, `locale`, `name` |
| `currency_name` | `currency_id`, `locale`, `name` |
| `unit_of_measure_name` | `unit_id`, `locale`, `name` |
| `product_category_name` | `category_id`, `locale`, `name` |
| `reference_item_name` | `item_id`, `locale`, `name` |

Each of them has: `ux_<table>__<parent>_id__locale`, plus a `ck` on
`locale IN (ru, en, tr)`.

The names of companies, branches, warehouses and product items are **not
translated** — they are proper names and are the same in every language.

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `company` | tens | rarely |
| `branch` | hundreds | rarely |
| `warehouse` | hundreds | rarely |
| `country` | ~250 | almost never |
| `region` | thousands | almost never |
| `city` | tens of thousands | rarely |
| `currency` | tens | almost never |
| `exchange_rate` | hundreds of thousands, growing | inserts only |
| `unit_of_measure` | tens | almost never |
| `product_category` | hundreds | rarely |
| `product` | tens of thousands | regularly |
| `reference_list` | tens | almost never |
| `reference_item` | thousands | regularly |
| the name tables (7) | ×3 of the parent | together with the parent |

**20 tables** in total. All of them are cached at the application level except
`exchange_rate` and `product`; invalidation happens on a change event.
