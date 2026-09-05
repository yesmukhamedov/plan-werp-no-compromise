---
id: PROD-03-R01
title: "Rule 1. Organization"
status: draft
---

## 1. Organization

- One database, **a schema per domain**; the schema name is the domain code from
  the [map](../../02-domains.md) in lower case (`reference`, `contract`, `accounting`,
  …), plus `audit` and `migration`.
- A domain writes and reads **only its own schema**. The database role of a
  module has no privileges on any other schema — the boundary is a grant, not a
  convention.
- Foreign keys only within a schema. Between domains — a reference by identifier
  **without** an integrity constraint at the database level; integrity is
  enforced by the application layer and verified by a nightly reconciliation job
  that reports orphans as a metric.
- Shared reference data lives in the `reference` schema and is available to other
  domains through its public interface, not through a direct query.
- Cross-schema views do not exist. A read that spans domains is composed in the
  application or served by a read model that is built from events.
