---
id: PROD-03-S-AUDIT
title: "audit schema — D0 Platform"
status: draft
---

# `audit` — D0 Platform

| | |
|---|---|
| Domain | D0 Platform ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **2** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 1 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

**Two tables serve all thirteen domains.** A domain does not get an audit table
of its own, and an audited table does not get a shadow twin
([rule 11](../rules/11-audit.md)).

Both tables are **immutable**: they carry `id`, `created_at` and `created_by` and
no `updated_*`, no `version` and no delete path. The absence of those columns is
what states the immutability, and an audit record that can be edited is not an
audit record.

What gets audited is **the domain owner's decision**, recorded in the domain's
specification, not a switch someone turns on for everything. Auditing everything
and auditing nothing are equally useless.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

## Group 1. The record and its detail

### `audit_event` — who did what to which entity, when, in which request

Pattern: [14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind) —
the subject is any entity of any domain, so the reference is typed, not thirteen
nullable foreign keys.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `occurred_at` | `timestamptz` | no | | when it happened |
| `app_user_id` | `uuid` | yes | ⇢ `platform.app_user` | who did it; null for a background job |
| `api_client_id` | `uuid` | yes | ⇢ `platform.api_client` | which machine consumer, if it was one |
| `job_run_id` | `uuid` | yes | ⇢ `platform.job_run` | which job run, if it was one |
| `acted_as_user_id` | `uuid` | yes | ⇢ `platform.app_user` | set when an administrator acted on someone's behalf |
| `domain_code` | `text` | no | `ck` in the domain list | which domain owns the entity |
| `entity_kind` | `text` | no | `ck` in the registered entity list | what was touched |
| `entity_id` | `uuid` | no | typed link | which record |
| `action` | `text` | no | `ck IN (CREATE, UPDATE, DELETE, READ, EXPORT, APPROVE, REJECT, POST, REVERSE, SIGN_IN, SIGN_IN_FAILED, PERMISSION_GRANTED, PERMISSION_REVOKED)` | what was done |
| `outcome` | `text` | no | `ck IN (SUCCEEDED, REFUSED, FAILED)` | a refused attempt is audited too |
| `refusal_reason` | `text` | yes | `ck` length 1–255 | why it was refused |
| `trace_id` | `text` | no | `ck` length 1–64 | ties the record to a trace ([11-observability.md](../../11-observability.md)) |
| `request_ip` | `inet` | yes | | where the request came from |
| `user_agent` | `text` | yes | `ck` length 1–500 | |
| `context` | `jsonb` | yes | | the filter of an export, the parameters of a read — the one justified `jsonb` here |

Indexes: `ix_audit_event__entity_kind__entity_id__occurred_at`,
`ix_audit_event__app_user_id__occurred_at`,
`ix_audit_event__occurred_at`,
`ix_audit_event__trace_id`,
`ix_audit_event__action` partial `WHERE outcome = 'REFUSED'`.

Constraint: `ck_audit_event__refused_has_reason`
(`outcome <> 'REFUSED' OR refusal_reason IS NOT NULL`).

> **A refused action is audited.** The record that matters after an incident is
> usually not what someone changed but what they tried to reach and were stopped
> from reaching, and a system that logs only successes cannot answer that.

> `action = READ` exists but is used almost nowhere: reads are audited only where
> a domain specification names the table, and today that is one table in the whole
> system — `hr.compensation`
> ([D3](../../spec/D3-hr.md#audit)). Auditing every read produces a table nobody
> can search.

### `audit_field_change` — the columns that changed, with their values

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) —
one row per changed column. Not a `before` and an `after` copy of the whole row,
and not a table shaped like the audited one.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `audit_event_id` | `uuid` | no | → `audit_event.id` | the event |
| `column_name` | `text` | no | `ck` `^[a-z_]+$` | which column changed |
| `old_value` | `text` | yes | | the previous value, rendered |
| `new_value` | `text` | yes | | the new value, rendered |
| `is_sensitive` | `boolean` | no | default `false` | the values are masked when the record is read |

Indexes: `ix_audit_field_change__audit_event_id`,
`ix_audit_field_change__column_name`.

Constraint: `ck_audit_field_change__something_changed`
(`old_value IS DISTINCT FROM new_value`).

> Values are stored as text rather than in typed columns on purpose: this table
> holds columns of every type in the system, and a typed variant would need one
> nullable column per type — the shape
> [14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind)
> exists to prevent. The typed original is always one join away, in the audited
> table.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| an audit table per domain | these two | 1 |
| a shadow table shaped like the audited one | `audit_event` + `audit_field_change` | 1 |
| a sign-in log | `audit_event` with `action = SIGN_IN` | 1 |
| an export log | `audit_event` with `action = EXPORT` and the filter in `context` | 1 |
| a permission-change log | `audit_event` with `action = PERMISSION_GRANTED` | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `audit_event` | hundreds of millions, growing | **immutable** |
| `audit_field_change` | billions, growing | **immutable** |

**2 tables**, and the two largest in the database.

Both are range-partitioned by `occurred_at`
([rule 10](../rules/10-large-tables.md)). Retention is set by the statutory
record-keeping period rather than by convenience, per domain, and the law is
cited in the migration that sets it — [OQ-003](../../../transition/12-open-questions.md).
Archiving is **detaching a partition**, never copying rows into a table with a
different name.

The audit schema is written by the platform and read by nobody except the audit
viewer. No domain role holds any privilege on it: a domain can cause an audit
record to be written, and cannot read, change or delete one.

## Open questions

| # | Question | Affects |
|---|---|---|
| A-Q1 | What is the retention period per domain, and where does the law set it? | partitioning, storage volume, [OQ-003](../../../transition/12-open-questions.md) |
| A-Q2 | Is `audit_field_change` needed for every audited action, or only for updates? | volume — this is the difference between billions of rows and hundreds of millions |
| A-Q3 | Which columns are `is_sensitive`, and who may see their values? | the audit viewer's permissions |
| A-Q4 | Does the audit of a deleted entity survive the entity? | retention, and whether logical deletion is enough |
