---
id: PROD-03-R04
title: "Rule 4. Mandatory columns"
status: draft
---

## 4. Mandatory columns

Every mutable entity, without exception:

| Column | Type | Purpose |
|---|---|---|
| `id` | `uuid` | the primary key |
| `created_at` | `timestamptz` | the moment of creation |
| `created_by` | `uuid` | who created it |
| `updated_at` | `timestamptz` | the moment of the last change |
| `updated_by` | `uuid` | who made the last change |
| `version` | `integer` | optimistic locking |

**`version` is mandatory, not optional.** Without it, two users editing the same
record concurrently silently lose one of the changes.

The six columns are declared by one shared migration fragment, so that they
cannot be spelled differently in different schemas.

Deletion is logical (`deleted_at`, `deleted_by`) everywhere the record takes part
in history or reporting; physical deletion happens only with a rationale in the
migration description. Where deletion is logical, **every unique index is
partial** (`WHERE deleted_at IS NULL`) — otherwise a deleted row blocks the reuse
of its code forever.

Immutable rows — an exchange rate, a journal entry line, an audit record — carry
`created_at` and `created_by` and **no** `updated_*` or `version`: the absence of
those columns is what states the immutability.

Reference tables that do not change in operation (currency codes, country codes)
are exempt from `version`, but not from `created_at` / `updated_at`.
