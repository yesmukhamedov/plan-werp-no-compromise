---
id: PROD-03-CHECKS
title: How the database rules are enforced
status: draft
---

# How the rules are enforced

A rule is enforced by a check that runs in CI over the migrated schema of a
freshly built database ([13-cicd.md](../13-cicd.md)). The check fails the build; it
does not warn.

| # | Check | Rule |
|---|---|---|
| DB-01 | every table has a primary key named `id` of type `uuid` | [3](rules/03-identifiers.md) |
| DB-02 | every mutable table has the six mandatory columns, spelled exactly so | [4](rules/04-mandatory-columns.md) |
| DB-03 | no object name matches a forbidden pattern: numbered, type-encoding, lifecycle-suffixed | [2.2](rules/02-naming.md#22-six-prohibitions) |
| DB-04 | every name token appears in the glossary or in the allowed word list | [2.2](rules/02-naming.md#22-six-prohibitions) |
| DB-05 | no `real`, `double precision`, `char(n)`, `timestamp` without a time zone, `numeric` without precision | [5](rules/05-types.md) |
| DB-06 | every `*_amount` column has a `*_currency_id` beside it, or its table has a single `currency_id` declared to govern the row | [5.2](rules/05-types.md#52-money) |
| DB-07 | every enumeration column has a `ck` listing its values | [5.1](rules/05-types.md#51-enumerations) |
| DB-08 | every foreign key column has an index leading with it | [8](rules/08-indexes.md) |
| DB-09 | no foreign key crosses a schema boundary | [1](rules/01-organization.md) |
| DB-10 | every unique index on a logically deleted table is partial | [4](rules/04-mandatory-columns.md) |
| DB-11 | every trigger, view and materialized view is listed in a domain specification | [9](rules/09-logic-in-the-database.md) |
| DB-12 | no stored procedure, function or database job exists outside that list | [9](rules/09-logic-in-the-database.md) |
| DB-13 | no sequence and no identity column exists | [3](rules/03-identifiers.md) |
| DB-14 | no translatable column of the form `name_<locale>` exists | [6](rules/06-localization.md) |
| DB-15 | every index is referenced by a migration description that names its query | [8](rules/08-indexes.md) |
| DB-16 | the schema built from migrations from zero equals the schema in the environment | [12](rules/12-migrations.md) |
| DB-17 | every table above the volume threshold has a retention decision recorded | [10](rules/10-large-tables.md) |
| DB-18 | no two tables in the database have the same set of column names | [14.1](rules/14-patterns.md#141-a-variant-is-a-row) |
| DB-19 | the set of tables in the database equals the registry in [Part II](schemas/README.md), table for table | [14](rules/14-patterns.md) |
| DB-20 | every table in the registry names the structural pattern it follows | [14](rules/14-patterns.md) |

Checks DB-04, DB-15 and DB-20 need a source the schema does not contain — the
glossary, the migration descriptions and the domain specifications. They are the
three that make the rules hold over years, and they are the three most likely to
be dropped under pressure. They are not dropped
([NC-01](../../docs/01-principles/01-no-compromise.md)).

DB-18 is the cheapest check in the list and the one that catches the most
expensive defect: a table copied to serve a second variant is identical to its
original on the day it is created, and it is only ever created on that day. After
that it diverges, and no check can tell it apart from a table that was designed.
