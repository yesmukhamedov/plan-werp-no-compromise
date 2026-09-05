---
id: PROD-03-R05
title: "Rule 5. Types"
status: draft
---

## 5. Types

| What | Type | Why |
|---|---|---|
| Identifier | `uuid` | |
| Money | `numeric(19,4)` + a currency column | precision is mandatory |
| Exchange rate | `numeric(19,8)` | two decimal places lose money on conversion |
| Percentage, coefficient | `numeric(9,6)` | |
| Quantity | `numeric(19,6)` | fractional quantities exist |
| Small counter | `integer` | |
| Point in time | `timestamptz`, stored in UTC | the time zone is not baked into the image |
| Date | `date` | a date with no time is not midnight in some zone |
| Duration | `interval` | not a number of minutes in an untyped column |
| Short text | `text` + a `ck` length constraint | `varchar(n)` changes through a migration, a constraint does not |
| Enumeration | `text` + a `ck` constraint with the list | the values are readable in the database and in exports |
| Flag | `boolean` | |
| Geographic coordinate | `numeric(9,6)` with a range check | |
| Phone number | `text` in E.164 + a `ck` | one format, one column |
| Email | `text` + a `ck` | |
| Tree path | `ltree` | |
| Semi-structured data | `jsonb` | **only with a rationale in the migration description** |
| Binary data | not in the database | files go to the file store, the database holds a reference |

Forbidden, and checked automatically against the schema:

- `real` / `double precision` anywhere — not for money, not for quantities, not
  for rates, not for coordinates;
- `numeric` with no precision, and integer types chosen "to be safe" — every
  numeric column states its precision and scale;
- `timestamp` without a time zone;
- `char(n)`;
- a number or a one-character string used as a boolean;
- a number used as an enumeration;
- `jsonb` as a way of not designing the schema;
- columns of the form `field1`, `note2`, `reserved`, `attr3`.

### 5.1 Enumerations

An enumeration value is a readable upper-case string (`ACTIVE`, `CANCELLED`), not
a number and not a database `enum` type. A number is unreadable in an export and
breeds magic constants in the code; a database `enum` cannot gain a value without
a lock.

The permitted values are listed in a `ck` constraint on the column. That makes
the list visible to anyone reading the schema and makes an invalid value a write
error rather than a report defect discovered a year later.

The line between the two mechanisms is not the size of the list:

> **A `ck` enumeration is a list the code branches on. A `reference_item` is a
> list only the data uses.**

`journal.kind` is a `ck` list because the posting engine behaves differently for
a closing journal than for a cash one; `budget.kind_id` is a `reference_item`
because no code anywhere asks which kind of budget it is. Applying the test the
other way round produces the two failures that follow from getting it wrong: a
business user waiting on a release to add a category, or a `switch` statement
over rows a business user can edit.

A list that has attributes of its own — an order, a description, a validity
period, an owner — is not an enumeration; it is `reference_item`
([spec/D1](../../spec/D1-reference.md#the-shared-enumeration-mechanism)) or a table.

### 5.2 Money

Defined **once** at the platform level and not overridden by domains:

- storage — 4 decimal places; presentation — per currency;
- an amount column never travels alone: `<x>_amount` always has
  `<x>_currency_id` beside it, and both are null or both are set (a `ck`). The
  one alternative is a table that declares a **single `currency_id` governing
  every amount in the row** — a balance, a statement line, a deposit — and the
  domain specification says so in the table's description;
- adding amounts in different currencies is a runtime error, not a silent
  conversion;
- the rounding rule is uniform across the system and is fixed here once
  accounting confirms it `?`;
- a converted amount stores the rate and the rate date it used, so that the
  calculation can be reproduced years later;
- a monetary column is never nullable "for convenience": absent means 0 or means
  unknown, and the difference is a design decision recorded in the domain
  specification.

### 5.3 Time

- Everything that happened at a moment is `timestamptz` in UTC.
- Everything that is a calendar fact — a posting date, a birthday, an accounting
  period — is `date`, and no time zone is applied to it anywhere in the stack.
- A period is stored as `valid_from` / `valid_to` with `valid_to` exclusive, and
  overlapping periods are prevented by an exclusion constraint, not by
  application code.
- No column stores a date as text or as a number.
