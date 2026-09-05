---
id: PROD-03-R07
title: "Rule 7. Constraints"
status: draft
---

## 7. Constraints

The database is the last line of defence for an invariant that must hold for
every writer, including a migration and a manual fix at three in the morning.

Mandatory on every table:

- a primary key;
- a unique index on every natural key;
- a foreign key on every reference **within** the schema, with an explicit
  `ON DELETE` clause — `RESTRICT` unless the domain specification argues
  otherwise; `CASCADE` is written down, never adopted by accident;
- `NOT NULL` on every column that the domain says is mandatory — nullability is a
  decision, not a default;
- a `ck` for every enumeration column, listing its values;
- a `ck` for every numeric range the domain knows (`amount >= 0`,
  `latitude BETWEEN -90 AND 90`, `minor_units BETWEEN 0 AND 4`);
- a `ck` for every text column with a known length or format;
- an exclusion constraint for every non-overlap rule (a price period, a rate
  period, an assignment period).

An invariant that the database cannot express is stated as a named application
rule in the domain specification and is covered by a test. It is never simply
absent.
