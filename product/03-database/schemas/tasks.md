---
id: PROD-03-S-TASKS
title: "tasks schema — D12 Internal tasks and communications"
status: draft
---

# `tasks` — D12 Internal tasks and communications

| | |
|---|---|
| Domain | D12 Internal tasks and communications ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **6** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 2 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `tasks`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md), which are not repeated
below.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

**One task mechanism for the whole system.** A task raised from a case, a task
raised from a service order, a task raised by a manager and a task raised by a
scheduled job are the same table
([14.1](../rules/14-patterns.md#141-a-variant-is-a-row)). A domain that needs a
task links to `task`; it does not grow a task table.

**Messages to people outside the system are not here.** An SMS to a customer, an
e-mail to a supplier and a push notification are `platform.notification`, one
mechanism for every channel ([platform](platform.md)). This schema holds
messages between colleagues.

## Group 1. Tasks

### `task` — an internal task

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `number` | `text` | no | | from `platform.document_number` |
| `title` | `text` | no | `ck` length 1–255 | |
| `body` | `text` | yes | `ck` length 1–8000 | |
| `author_employee_id` | `uuid` | no | ⇢ `hr.employee` | who raised it |
| `assignee_employee_id` | `uuid` | yes | ⇢ `hr.employee` | who is to do it |
| `assignee_org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | or which unit, before it is picked up |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | |
| `priority` | `text` | no | `ck IN (LOW, NORMAL, HIGH, URGENT)` | |
| `state` | `text` | no | `ck IN (NEW, ASSIGNED, IN_PROGRESS, ON_HOLD, DONE, CANCELLED, REJECTED)` | |
| `due_at` | `timestamptz` | yes | | |
| `started_at` | `timestamptz` | yes | | |
| `completed_at` | `timestamptz` | yes | | |
| `parent_task_id` | `uuid` | yes | → `task.id` | a subtask's parent |
| `source_kind` | `text` | no | `ck IN (MANUAL, CASE, SERVICE_ORDER, DOCUMENT, CONTRACT, JOB, STOCK_DOCUMENT)` | what raised it |
| `source_id` | `uuid` | yes | typed link ([14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind)) | which record |
| `estimated_minutes` | `integer` | yes | `ck` > 0 | |
| `spent_minutes` | `integer` | yes | `ck` ≥ 0 | |
| `result` | `text` | yes | `ck` length 1–4000 | what was done |

Indexes: `ux_task__company_id__number`,
`ix_task__assignee_employee_id__state`,
`ix_task__assignee_org_unit_id__state` partial `WHERE assignee_employee_id IS NULL`,
`ix_task__author_employee_id__created_at`,
`ix_task__due_at` partial `WHERE state NOT IN ('DONE','CANCELLED','REJECTED')`,
`ix_task__source_kind__source_id`,
`ix_task__parent_task_id`.
Constraint: `ck_task__no_self_parent`; `ck_task__done_has_completed_at`.

An unassigned task belongs to a **unit**, not to nobody: that is what makes a
queue possible without a second table for queued work.

### `task_event` — its history

**Immutable.** Pattern:
[14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `task_id` | `uuid` | no | → `task.id` | |
| `kind` | `text` | no | `ck IN (CREATED, ASSIGNED, REASSIGNED, STARTED, HELD, RESUMED, COMPLETED, REJECTED, CANCELLED, COMMENTED, DUE_CHANGED)` | |
| `occurred_at` | `timestamptz` | no | | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | who |
| `previous_state` | `text` | yes | | |
| `new_state` | `text` | yes | | |
| `note` | `text` | yes | `ck` length 1–4000 | a comment is an event of kind `COMMENTED` |

Indexes: `ix_task_event__task_id__occurred_at`,
`ix_task_event__employee_id__occurred_at`.

> There is no separate comment table. A comment is something that happened to the
> task, it belongs in the same chronological list as every reassignment and every
> change of deadline, and splitting it out means every screen showing the history
> has to merge two tables in date order
> ([14.1](../rules/14-patterns.md#141-a-variant-is-a-row)).

### `task_category` — task categories

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `parent_id` | `uuid` | yes | → `task_category.id` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `name` | `text` | no | `ck` length 1–255 | |
| `path` | `ltree` | no | | the materialized path |
| `default_due_hours` | `integer` | yes | `ck` > 0 | the deadline a task of this category gets |
| `default_org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | who it goes to by default |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_task_category__company_id__code`,
`ix_task_category__parent_id`, `ix_task_category__path` (GiST).

### `task_category_link` — a task in a category

A task may sit in more than one category, which is why this is a link table and
not a column.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `task_id` | `uuid` | no | → `task.id` | |
| `task_category_id` | `uuid` | no | → `task_category.id` | |
| `is_primary` | `boolean` | no | default `false` | the one used for the default deadline |

Indexes: `ux_task_category_link__task_id__task_category_id`,
`ix_task_category_link__task_category_id`.

## Group 2. Messages between colleagues

### `message` — an internal message

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `kind` | `text` | no | `ck IN (DIRECT, BROADCAST, UNIT_ANNOUNCEMENT)` | |
| `author_employee_id` | `uuid` | no | ⇢ `hr.employee` | |
| `subject` | `text` | yes | `ck` length 1–255 | |
| `body` | `text` | no | `ck` length 1–8000 | |
| `sent_at` | `timestamptz` | yes | | null while it is a draft |
| `expires_at` | `timestamptz` | yes | | for an announcement |
| `parent_message_id` | `uuid` | yes | → `message.id` | a reply's parent |
| `task_id` | `uuid` | yes | → `task.id` | the task it concerns |
| `is_acknowledgement_required` | `boolean` | no | default `false` | recipients must confirm they read it |

Indexes: `ix_message__author_employee_id__sent_at`,
`ix_message__kind__sent_at`,
`ix_message__parent_message_id`,
`ix_message__task_id` partial `WHERE task_id IS NOT NULL`.

### `message_recipient` — one recipient of it

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) —
one row per recipient, never a list of identifiers in a text column.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `message_id` | `uuid` | no | → `message.id` | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | an individual recipient |
| `org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | a whole unit |
| `role_id` | `uuid` | yes | ⇢ `platform.role` | everyone holding a role |
| `delivered_at` | `timestamptz` | yes | | |
| `read_at` | `timestamptz` | yes | | |
| `acknowledged_at` | `timestamptz` | yes | | |

Indexes: `ix_message_recipient__message_id`,
`ix_message_recipient__employee_id__read_at`,
`ux_message_recipient__message_id__employee_id` partial `WHERE employee_id IS NOT NULL`.
Constraint: `ck_message_recipient__exactly_one_subject`.

A broadcast to a unit is **one** row naming the unit, not one row per person: the
membership of a unit as at the send date is `hr.assignment`, and expanding it
into copies would freeze a stale list.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a task table per domain | `task` with a `source_kind` | 1 |
| a task-comment table | `task_event` with `kind = COMMENTED` | 1 |
| an SMS table, an e-mail table, a push table | `platform.notification` and `notification_delivery` | 1 |
| a recipients column holding a list of identifiers | `message_recipient`, one row each | 2 |
| a broadcast table beside a message table | `message.kind = BROADCAST` | 1 |
| a phone directory | `hr.employee` joined to `party.phone_link` | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `task` | tens of millions, growing | state changes |
| `task_event` | hundreds of millions, growing | **immutable** |
| `task_category` | hundreds | rarely |
| `task_category_link` | tens of millions | rarely |
| `message` | tens of millions, growing | until sent |
| `message_recipient` | hundreds of millions, growing | read and acknowledgement only |

**6 tables.** `task_event` and `message_recipient` are partitioned by time with a
retention decision recorded before the first release
([rule 10](../rules/10-large-tables.md)).

## Open questions

| # | Question | Affects |
|---|---|---|
| D12-Q1 | Are internal messages needed at all, or is the company's chat tool the place for them? | `message`, `message_recipient` — two of the six tables |
| D12-Q2 | Is an in-app notification a `message` or a `platform.notification`? | the boundary with D0, and where the unread badge is counted |
| D12-Q3 | Do tasks need subtasks and dependencies, or only a parent? | `parent_task_id`, and a possible seventh table |
| D12-Q4 | Is time spent on a task recorded for payroll, or only for reporting? | `task.spent_minutes`, and a boundary with D3 |
