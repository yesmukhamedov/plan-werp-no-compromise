---
id: PROD-05-R06
title: "API rule 6. Types"
status: draft
---

## Types

| What | How it is transferred |
|---|---|
| Date and time | ISO 8601, UTC, with the zone stated |
| Date without time | `YYYY-MM-DD` |
| Money | `{ "amount": "1234.56", "currency": "KZT" }` — a string, not a number |
| Percentages and coefficients | a string with a decimal representation |
| Identifier | a string; the format is a platform decision, uniform across the system |
| Enumeration | a string constant in `SCREAMING_SNAKE_CASE`; the values are part of the contract |
| Absence of a value | `null`; a missing field and `null` do not differ in meaning |

Money is transferred as a string deliberately: a floating-point number in JSON
loses precision, and the whole D5 domain is monetary
([C-09](../../../docs/00-context/03-constraints.md#c-09-financial-calculations-require-exact-arithmetic)).
