---
id: PROD-03-RULES
title: Database rules
status: draft
---

# Database rules

The rules by which **any** object in the database is built. Every one of them is
stated so that a machine can check it: a rule nobody can check is a preference,
and preferences do not survive twelve years
([NC-01](../../../docs/01-principles/01-no-compromise.md)).

The check for each rule is in [../checks.md](../checks.md).

| # | Rule | What it settles |
|---|---|---|
| 1 | [Organization](01-organization.md) | one schema per domain; what may cross a schema boundary |
| 2 | [Naming](02-naming.md) | how every object is named, and the six prohibitions |
| 3 | [Identifiers](03-identifiers.md) | `uuid` from the application; natural keys are never primary keys |
| 4 | [Mandatory columns](04-mandatory-columns.md) | the six columns every mutable table carries; what immutability looks like |
| 5 | [Types](05-types.md) | the type per kind of value; enumerations; money; time |
| 6 | [Localization](06-localization.md) | translatable values are rows, never columns |
| 7 | [Constraints](07-constraints.md) | what the database refuses, and what it cannot |
| 8 | [Indexes](08-indexes.md) | an index exists for a named query |
| 9 | [Logic in the database](09-logic-in-the-database.md) | what may live in the database, and what may not |
| 10 | [Large tables](10-large-tables.md) | thresholds, partitioning, archiving, retention |
| 11 | [Audit](11-audit.md) | one audit mechanism for thirteen domains |
| 12 | [Migrations](12-migrations.md) | forward only; four steps for a breaking change |
| 13 | [Performance](13-performance.md) | measured budgets, measured plans |
| 14 | [Structural patterns](14-patterns.md) | **the ten forms a table may take, and what an eleventh instance costs** |

## Where to start

Rules 1–13 are constraints: they say what an object must look like once you have
decided it exists.

[Rule 14](14-patterns.md) is different, and is the one to read first when
designing something new. It says what shape a thing should take at all, and it
judges every answer by the same question:

> **The eleventh question.** An eleventh product line appears. A seventh
> maintenance position appears. A thirteenth budget kind, a fifth approval step,
> a fourth language, a ninth reason for a movement. What does it cost — a row, a
> migration, or a table?

The physical model that results is in [../schemas/](../schemas/README.md).
