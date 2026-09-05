---
id: PROD-04-R06
title: "Backend rule 6. Data access"
status: draft
---

## Data access

**One mechanism for the whole system** `[STACK]`,
[NC-05](../../../docs/01-principles/01-no-compromise.md#nc-05). A second one does not
exist.

- Queries are type-safe; SQL concatenation is forbidden and checked.
- Raw SQL is allowed only in a dedicated read-query layer (reports, summary
  extracts), only parameterized, with a rationale.
- Lazy loading across an aggregate boundary is forbidden — that is the very
  source of the N+1 problem.
- Every list query is paginated at the SQL level, not in memory.
