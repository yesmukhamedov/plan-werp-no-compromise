---
id: PROD-03-S-CRM
title: "crm schema — D9 CRM and call centre"
status: draft
---

# `crm` — D9 CRM and call centre

| | |
|---|---|
| Domain | D9 CRM and call centre ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **14** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 5 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `crm`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md), which are not repeated
below.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

Two decisions shape this schema, and both are consolidations:

1. **One `case` table for every kind of case**, whatever channel it arrived on
   and whatever it is about.
2. **One `activity` table for every interaction** — an inbound call, an outbound
   call, a demonstration, a visit, a meeting, a message. They share their
   columns, their screens, their reports and their permissions; the only thing
   that differs between them is a `kind` and a handful of columns that the kind
   makes relevant ([14.1](../rules/14-patterns.md#141-a-variant-is-a-row)).

A separate table per interaction kind means the same counterparty's history has
to be assembled from four places, in the right order, by every screen that shows
it — and one of the four is always forgotten.

## Group 1. Cases

### `case` — a customer case, whatever channel it arrived on

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `number` | `text` | no | | from `platform.document_number` |
| `kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `CASE_KIND` | complaint, enquiry, request, claim, suggestion |
| `topic_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `CASE_TOPIC` | what it is about |
| `party_id` | `uuid` | yes | ⇢ `party.party` | who raised it |
| `phone_id` | `uuid` | yes | ⇢ `party.phone` | the number it came from, when the party is unknown |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | |
| `installed_unit_id` | `uuid` | yes | ⇢ `service.installed_unit` | |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | who owns it |
| `channel` | `text` | no | `ck IN (INBOUND_CALL, OUTBOUND_CALL, WEB, MOBILE_APP, EMAIL, MESSENGER, WALK_IN, TECHNICIAN, PARTNER)` | how it arrived |
| `priority` | `text` | no | `ck IN (LOW, NORMAL, HIGH, URGENT)` | |
| `opened_at` | `timestamptz` | no | | |
| `due_at` | `timestamptz` | yes | | the service-level deadline |
| `closed_at` | `timestamptz` | yes | | |
| `state` | `text` | no | `ck IN (NEW, ASSIGNED, IN_PROGRESS, WAITING_CUSTOMER, RESOLVED, CLOSED, REJECTED)` | |
| `resolution_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `CASE_RESOLUTION` | how it ended |
| `assigned_employee_id` | `uuid` | yes | ⇢ `hr.employee` | who is handling it |
| `service_request_id` | `uuid` | yes | ⇢ `service.service_request` | the field work it produced |
| `satisfaction_rating` | `smallint` | yes | `ck` 1–5 | |
| `subject` | `text` | no | `ck` length 1–255 | |
| `description` | `text` | yes | `ck` length 1–4000 | |

Indexes: `ux_case__company_id__number`,
`ix_case__party_id__opened_at`,
`ix_case__branch_id__state`,
`ix_case__assigned_employee_id__state`,
`ix_case__due_at` partial `WHERE state NOT IN ('CLOSED','REJECTED')`,
`ix_case__phone_id` partial `WHERE phone_id IS NOT NULL`,
`ix_case__kind_id__opened_at`.

`phone_id` without a `party_id` is the anonymous caller: the number is a
`party.phone` row from the first ring, so that when the caller is later
identified the case attaches to a party without anything being retyped.

### `case_comment` — a comment on a case

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `case_id` | `uuid` | no | → `case.id` | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | who wrote it |
| `is_internal` | `boolean` | no | default `true` | not shown to the customer |
| `body` | `text` | no | `ck` length 1–4000 | |

Indexes: `ix_case_comment__case_id__created_at`.

### `case_task` — a task raised from a case

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `case_id` | `uuid` | no | → `case.id` | |
| `task_id` | `uuid` | no | ⇢ `tasks.task` | the task itself, in D12 |
| `purpose` | `text` | no | `ck IN (INVESTIGATE, CALL_BACK, COMPENSATE, ESCALATE, FOLLOW_UP)` | why it was raised |

Indexes: `ux_case_task__case_id__task_id`, `ix_case_task__task_id`.

> The task is **not** re-implemented here. `tasks.task` is the one task
> mechanism in the system; this table is the link that says a task belongs to a
> case ([14.6](../rules/14-patterns.md#146-one-identity-many-roles)).

## Group 2. Interactions

### `activity` — one interaction with a counterparty

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row). **A call, a
demonstration, a visit and a meeting are one table.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `kind` | `text` | no | `ck IN (CALL, DEMONSTRATION, VISIT, MEETING, MESSAGE, EMAIL)` | which interaction |
| `direction` | `text` | no | `ck IN (INBOUND, OUTBOUND, INTERNAL)` | |
| `party_id` | `uuid` | yes | ⇢ `party.party` | with whom |
| `phone_id` | `uuid` | yes | ⇢ `party.phone` | the number, for a call |
| `case_id` | `uuid` | yes | → `case.id` | the case it belongs to |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | who conducted it |
| `started_at` | `timestamptz` | no | | |
| `ended_at` | `timestamptz` | yes | | |
| `duration_seconds` | `integer` | yes | `ck` ≥ 0 | for a call |
| `wait_seconds` | `integer` | yes | `ck` ≥ 0 | how long the caller waited |
| `outcome_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `ACTIVITY_OUTCOME` | how it went |
| `state` | `text` | no | `ck IN (PLANNED, IN_PROGRESS, COMPLETED, NO_ANSWER, CANCELLED)` | |
| `address_id` | `uuid` | yes | ⇢ `party.address` | where, for a visit or a demonstration |
| `latitude` | `numeric(9,6)` | yes | `ck` −90…90 | where the employee actually was |
| `longitude` | `numeric(9,6)` | yes | `ck` −180…180 | |
| `product_id` | `uuid` | yes | ⇢ `reference.product` | what was demonstrated |
| `resulting_contract_id` | `uuid` | yes | ⇢ `contract.contract` | the sale it produced |
| `recording_file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the call recording |
| `external_system` | `text` | yes | `ck` length 1–40 | the telephony platform |
| `external_id` | `text` | yes | | its identifier there |
| `campaign_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `CAMPAIGN` | the campaign it belongs to |

Indexes: `ix_activity__party_id__started_at`,
`ix_activity__employee_id__started_at`,
`ix_activity__kind__started_at`,
`ix_activity__case_id`,
`ix_activity__branch_id__started_at`,
`ux_activity__external_system__external_id` partial `WHERE external_id IS NOT NULL`,
`ix_activity__phone_id` partial `WHERE phone_id IS NOT NULL`,
`ix_activity__state__started_at` partial `WHERE state = 'PLANNED'`.

Constraint: `ck_activity__kind_columns` — a `CALL` has a direction and a phone; a
`DEMONSTRATION` has a product; a `VISIT` has an address.

> The kind-specific columns are nullable and checked, rather than being four
> tables. The trade is deliberate: some columns are empty on some rows, and in
> return the counterparty's history is one query ordered by one column, and a
> seventh interaction kind is a `ck` value plus, at most, a column.

### `activity_comment` — a comment on an interaction

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `activity_id` | `uuid` | no | → `activity.id` | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | |
| `body` | `text` | no | `ck` length 1–4000 | |

Indexes: `ix_activity_comment__activity_id__created_at`.

### `activity_participant` — who else took part

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) —
one row per participant, never `participant_1` and `participant_2`.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `activity_id` | `uuid` | no | → `activity.id` | |
| `party_id` | `uuid` | yes | ⇢ `party.party` | an external participant |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | an internal one |
| `role` | `text` | no | `ck IN (ORGANIZER, PARTICIPANT, OBSERVER, TRANSFERRED_TO)` | |

Indexes: `ix_activity_participant__activity_id`,
`ix_activity_participant__party_id`,
`ix_activity_participant__employee_id`.
Constraint: `ck_activity_participant__exactly_one_subject`.

A call transferred between two operators is two participant rows, not a second
call record and not a lost minute.

## Group 3. Referrals

### `referral` — a referral given by a customer

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `referrer_party_id` | `uuid` | no | ⇢ `party.party` | who gave it |
| `activity_id` | `uuid` | yes | → `activity.id` | the interaction it was given in |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | the contract they gave it under |
| `given_on` | `date` | no | | |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | |
| `state` | `text` | no | `ck IN (NEW, IN_PROGRESS, CONVERTED, EXHAUSTED, REJECTED)` | |

Indexes: `ix_referral__referrer_party_id__given_on`,
`ix_referral__state` partial `WHERE state IN ('NEW','IN_PROGRESS')`.

### `referral_contact` — the contacts in a referral

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `referral_id` | `uuid` | no | → `referral.id` | |
| `phone_id` | `uuid` | no | ⇢ `party.phone` | the number given |
| `party_id` | `uuid` | yes | ⇢ `party.party` | the party, once identified |
| `given_name` | `text` | yes | `ck` length 1–255 | the name as the referrer said it |
| `state` | `text` | no | `ck IN (NEW, CONTACTED, INTERESTED, DECLINED, CONVERTED, INVALID)` | |
| `assigned_employee_id` | `uuid` | yes | ⇢ `hr.employee` | who is working it |
| `referral_link_id` | `uuid` | yes | ⇢ `contract.referral_link` | the credited conversion |

Indexes: `ix_referral_contact__referral_id`,
`ix_referral_contact__phone_id`,
`ix_referral_contact__state__assigned_employee_id`.

The number is a `party.phone` row from the moment it is written down. That is
what makes "we already have this number" answerable before anyone calls it, and
it is why the phone table has one row per number in the whole system
([party](party.md)).

## Group 4. Checklists

The [declaration-and-slots](../rules/14-patterns.md#143-a-declaration-and-its-slots)
pattern applied to quality control: a checklist is declared once, its items are
rows, and a filled-in checklist is a row per item.

### `checklist` — a checklist

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `name` | `text` | no | `ck` length 1–255 | |
| `applies_to` | `text` | no | `ck IN (CALL, VISIT, DEMONSTRATION, SERVICE_ORDER, CASE)` | what it is filled in against |
| `valid_from` | `date` | no | | |
| `valid_to` | `date` | yes | | exclusive |

Indexes: `ux_checklist__company_id__code__valid_from`.

### `checklist_item` — one question of it

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `checklist_id` | `uuid` | no | → `checklist.id` | |
| `ordinal` | `smallint` | no | `ck` > 0 | |
| `question` | `text` | no | `ck` length 1–500 | |
| `answer_kind` | `text` | no | `ck IN (YES_NO, SCALE, TEXT, CHOICE)` | |
| `weight` | `numeric(9,6)` | no | default 1, `ck` ≥ 0 | its share of the score |
| `is_mandatory` | `boolean` | no | default `true` | |
| `is_critical` | `boolean` | no | default `false` | failing it fails the whole checklist |

Indexes: `ux_checklist_item__checklist_id__ordinal`.

**A new question is a row.** It appears on the form, in the score and in the
report on the day it is entered.

### `checklist_result` — one filled-in answer

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `checklist_item_id` | `uuid` | no | → `checklist_item.id` | which question |
| `subject_kind` | `text` | no | `ck IN (CALL, VISIT, DEMONSTRATION, SERVICE_ORDER, CASE)` | what was assessed |
| `subject_id` | `uuid` | no | typed link ([14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind)) | which one |
| `assessed_by_employee_id` | `uuid` | no | ⇢ `hr.employee` | who assessed |
| `assessed_at` | `timestamptz` | no | | |
| `boolean_answer` | `boolean` | yes | | for `YES_NO` |
| `scale_answer` | `smallint` | yes | `ck` 0–10 | for `SCALE` |
| `choice_id` | `uuid` | yes | ⇢ `reference.reference_item` | for `CHOICE` |
| `text_answer` | `text` | yes | `ck` length 1–2000 | for `TEXT` |

Indexes: `ux_checklist_result__checklist_item_id__subject_kind__subject_id`,
`ix_checklist_result__subject_kind__subject_id`,
`ix_checklist_result__assessed_by_employee_id__assessed_at`.
Constraint: `ck_checklist_result__answer_matches_kind`.

## Group 5. Targets and indicators

**One measurement model for the whole system.** Sales, service, the call centre
and personnel all define, target and record their indicators here; there is not a
second key-indicator mechanism anywhere
([14.1](../rules/14-patterns.md#141-a-variant-is-a-row)).

### `kpi_definition` — what is measured

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `name` | `text` | no | `ck` length 1–255 | |
| `owner_domain` | `text` | no | `ck` in the domain list | which domain produces the figure |
| `unit` | `text` | no | `ck IN (COUNT, AMOUNT, PERCENTAGE, MINUTES, RATING)` | |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | when the unit is an amount |
| `direction` | `text` | no | `ck IN (HIGHER_IS_BETTER, LOWER_IS_BETTER)` | |
| `subject_kind` | `text` | no | `ck IN (EMPLOYEE, ORG_UNIT, BRANCH, COMPANY, TEAM)` | what it is measured for |
| `period_kind` | `text` | no | `ck IN (DAY, WEEK, MONTH, QUARTER, YEAR)` | |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_kpi_definition__company_id__code`.

### `kpi_target` — the target value

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `kpi_definition_id` | `uuid` | no | → `kpi_definition.id` | |
| `subject_kind` | `text` | no | `ck IN (EMPLOYEE, ORG_UNIT, BRANCH, COMPANY, TEAM)` | |
| `subject_id` | `uuid` | no | typed link | for whom |
| `fiscal_period_id` | `uuid` | no | ⇢ `accounting.fiscal_period` | for when |
| `target_value` | `numeric(19,6)` | no | | the target |
| `threshold_value` | `numeric(19,6)` | yes | | the minimum acceptable |
| `stretch_value` | `numeric(19,6)` | yes | | the stretch goal |
| `set_by_employee_id` | `uuid` | yes | ⇢ `hr.employee` | |

Indexes: `ux_kpi_target__kpi_definition_id__subject_kind__subject_id__fiscal_period_id`,
`ix_kpi_target__fiscal_period_id`.

### `kpi_fact` — the achieved value

**Rebuildable.** Computed by the owning domain's job and reconciled against its
source.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `kpi_definition_id` | `uuid` | no | → `kpi_definition.id` | |
| `subject_kind` | `text` | no | `ck IN (EMPLOYEE, ORG_UNIT, BRANCH, COMPANY, TEAM)` | |
| `subject_id` | `uuid` | no | typed link | |
| `fiscal_period_id` | `uuid` | no | ⇢ `accounting.fiscal_period` | |
| `value` | `numeric(19,6)` | no | | the achieved figure |
| `computed_at` | `timestamptz` | no | | |
| `source_job_run_id` | `uuid` | yes | ⇢ `platform.job_run` | which run produced it |

Indexes: `ux_kpi_fact__kpi_definition_id__subject_kind__subject_id__fiscal_period_id`,
`ix_kpi_fact__fiscal_period_id`.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a calls table, a demonstrations table, a visits table, a meetings table | `activity` with a `kind` | 1 |
| a comment table per interaction kind | `activity_comment` | 1 |
| a second key-indicator model for a second department | `kpi_definition` and its two companions | 1 |
| a task table | `tasks.task`, linked through `case_task` | 1 |
| a mirror of the counterparty's name and phone on a case | `party_id`, `phone_id` | 1 |
| a checklist table per assessed subject | `checklist.applies_to` and `checklist_result.subject_kind` | 1 |
| a leads table | `party` with `party_role = LEAD` | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `case` | tens of millions, growing | state changes |
| `case_comment` | tens of millions | inserts |
| `case_task` | millions | inserts |
| `activity` | hundreds of millions, growing | state changes |
| `activity_comment` | tens of millions | inserts |
| `activity_participant` | hundreds of millions | inserts |
| `referral` | tens of millions | state changes |
| `referral_contact` | tens of millions | state changes |
| `checklist` | hundreds | rarely |
| `checklist_item` | thousands | rarely |
| `checklist_result` | tens of millions | inserts |
| `kpi_definition` | hundreds | rarely |
| `kpi_target` | millions | rarely |
| `kpi_fact` | tens of millions | rebuilt |

**14 tables** — one fewer than the registry first named, because the call,
demonstration and visit tables collapse into `activity`, while
`activity_participant` and `checklist_result` are added.

`activity` and `activity_participant` are the two largest and are
range-partitioned by `started_at` ([rule 10](../rules/10-large-tables.md)). Call
recordings are files in the object store with their own retention, not rows.

## Open questions

| # | Question | Affects |
|---|---|---|
| D9-Q1 | Is D9 a separate domain from D8, or one? | the existence of this schema — [02-domains.md](../../02-domains.md) |
| D9-Q2 | Which telephony platform is the source of truth for a call, and is `activity` a mirror of it or the original? | `activity.external_system`, and the integration |
| D9-Q3 | Is a referral credited in D9 or in D4, and can both credit the same conversion? | `referral_contact.referral_link_id` |
| D9-Q4 | How long are call recordings kept, and who may listen to one? | retention, and a permission |
| D9-Q5 | Which indicators exist today, and who owns each figure? | `kpi_definition` seed, `owner_domain` |
| D9-Q6 | Does a case have a service-level agreement per kind, and where is it declared? | `case.due_at`, and a declaration table that does not yet exist |
