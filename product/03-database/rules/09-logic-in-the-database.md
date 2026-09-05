---
id: PROD-03-R09
title: "Rule 9. Logic in the database"
status: draft
---

## 9. Logic in the database

The database stores data and enforces invariants. It does not hold business
logic: logic that lives there is invisible to the application's tests, its
deployment, its version control and its observability.

| Object | Permitted | Condition |
|---|---|---|
| Constraint | yes | always — see [7](07-constraints.md) |
| Generated column (`STORED`) | yes | a pure function of the same row |
| Trigger | **only** to maintain a derived column that must stay correct for every writer (`ltree` path, `depth`, a `tsvector`) | named in the domain specification, covered by a test that writes bypassing the application |
| View | yes | a named read model, no business rule inside |
| Materialized view | yes | with a measured refresh cost and a stated staleness budget |
| Stored procedure, function | **no** | except a helper called by a trigger permitted above |
| Package, job, scheduler inside the database | **no** | background work is a platform job |
| Trigger that assigns an identifier | **no** | identifiers come from the application |
| Trigger that maintains a denormalized copy of another table's data | **no** | that is a read model or a query |

Every trigger that exists is listed in the domain's specification with the
invariant it maintains. A trigger not listed there is a defect.
