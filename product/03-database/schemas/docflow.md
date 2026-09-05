---
id: PROD-03-S-DOCFLOW
title: "docflow schema — D10 Document workflow"
status: draft
---

# `docflow` — D10 Document workflow

| | |
|---|---|
| Domain | D10 Document workflow ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **8** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 3 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `docflow`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md), which are not repeated
below.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

**One workflow engine for the whole system.** A personnel order, a stock
transfer approval, a purchase authorization, a discount above a threshold and a
leave request are document **kinds** — rows of `document_type` — not separate
implementations in five domains
([14.1](../rules/14-patterns.md#141-a-variant-is-a-row)).

Every other schema reaches this one the same way: it holds a
`⇢ docflow.document` column on the record that needed approving, and it reads the
document's state. No domain implements approval of its own.

## Group 1. What can be approved, and by whom

The declarations. Nothing here is a running document; this is the statement of
what documents exist and what route each takes
([14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots)).

### `document_type` — a kind of document and its rules

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | the type code |
| `name` | `text` | no | `ck` length 1–255 | |
| `owner_domain` | `text` | no | `ck` in the domain list | which domain raises it |
| `number_series` | `text` | no | | the series in `platform.document_number` |
| `default_route_id` | `uuid` | yes | → `route.id` | the route it usually takes |
| `requires_attachment` | `boolean` | no | default `false` | |
| `document_template_id` | `uuid` | yes | → `document_template.id` | what it is printed from |
| `retention_years` | `smallint` | yes | `ck` > 0 | how long it is kept |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_document_type__company_id__code`.

### `document_template` — what a document is generated from

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag) — a template
has a validity period, so a document printed last year reprints as it was.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `locale` | `text` | no | `ck` in the supported list | |
| `body` | `text` | no | | the template source |
| `output_kind` | `text` | no | `ck IN (PDF, DOCX, HTML)` | |
| `valid_from` | `date` | no | | |
| `valid_to` | `date` | yes | | exclusive |

Indexes: `ux_document_template__company_id__code__locale__valid_from`.

### `route` — an approval route

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `name` | `text` | no | `ck` length 1–255 | |
| `document_type_id` | `uuid` | yes | → `document_type.id` | the kind it serves |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | narrows it |
| `org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | narrows it |
| `amount_from` | `numeric(19,4)` | yes | `ck` ≥ 0 | the threshold it starts applying at |
| `amount_to` | `numeric(19,4)` | yes | `ck` ≥ 0 | and stops at |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | governs both thresholds |
| `priority` | `integer` | no | default 0 | the more specific route wins |
| `valid_from` | `date` | no | | |
| `valid_to` | `date` | yes | | exclusive |

Indexes: `ux_route__company_id__code__valid_from`,
`ix_route__document_type_id__valid_from`.
Constraint: `ex_route__no_ambiguity` — an exclusion constraint on
(`company_id`, `document_type_id`, `branch_id`, `org_unit_id`, `priority`, the
date range); `ck_route__amount_has_currency`.

Amount thresholds on the route are what let "over ten million needs the director"
be **data**. The alternative is a threshold constant in code, which is the same
defect as an identifier in code
([14.10](../rules/14-patterns.md#1410-behaviour-reads-a-property-never-an-identifier)).

### `route_step` — one step of a route

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table).
**A fifth approver is a row.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `route_id` | `uuid` | no | → `route.id` | |
| `ordinal` | `smallint` | no | `ck` > 0 | which step |
| `name` | `text` | no | `ck` length 1–255 | what the step is called |
| `approver_kind` | `text` | no | `ck IN (POSITION, ORG_UNIT_HEAD, ROLE, SPECIFIC_EMPLOYEE, DOCUMENT_AUTHOR_MANAGER)` | how the approver is found |
| `position_id` | `uuid` | yes | ⇢ `hr.position` | for `POSITION` |
| `role_id` | `uuid` | yes | ⇢ `platform.role` | for `ROLE` |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | for `SPECIFIC_EMPLOYEE` |
| `required_approvals` | `smallint` | no | default 1, `ck` > 0 | how many of the eligible must approve |
| `is_parallel` | `boolean` | no | default `false` | this step runs alongside the next |
| `is_optional` | `boolean` | no | default `false` | may be skipped |
| `deadline_hours` | `integer` | yes | `ck` > 0 | after which it escalates |
| `escalates_to_step_ordinal` | `smallint` | yes | `ck` > 0 | where it escalates to |

Indexes: `ux_route_step__route_id__ordinal`,
`ix_route_step__position_id`, `ix_route_step__employee_id`.
Constraint: `ck_route_step__approver_kind_has_its_reference`.

> `approver_kind = POSITION` rather than a specific employee is what keeps a
> route working when a person leaves. The route names the seat; who occupies it
> on the day is `hr.assignment`
> ([14.10](../rules/14-patterns.md#1410-behaviour-reads-a-property-never-an-identifier)).

## Group 2. The documents

### `document` — an internal document of any kind

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `document_type_id` | `uuid` | no | → `document_type.id` | which kind |
| `number` | `text` | no | | from `platform.document_number` |
| `route_id` | `uuid` | yes | → `route.id` | the route resolved for it |
| `current_step_ordinal` | `smallint` | yes | `ck` > 0 | where it has got to |
| `subject` | `text` | no | `ck` length 1–255 | |
| `body` | `text` | yes | `ck` length 1–8000 | |
| `document_date` | `date` | no | | |
| `effective_date` | `date` | yes | | when what it decides takes effect |
| `author_employee_id` | `uuid` | no | ⇢ `hr.employee` | who raised it |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | |
| `org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | |
| `amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what it authorizes, when it authorizes money |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |
| `state` | `text` | no | `ck IN (DRAFT, IN_APPROVAL, APPROVED, REJECTED, WITHDRAWN, EXECUTED, CANCELLED)` | |
| `subject_kind` | `text` | yes | `ck` in the registered entity list | what the document is about |
| `subject_id` | `uuid` | yes | typed link ([14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind)) | which record |
| `stored_file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the generated or signed artefact |
| `deadline_at` | `timestamptz` | yes | | when the whole approval is due |

Indexes: `ux_document__company_id__document_type_id__number`,
`ix_document__author_employee_id__document_date`,
`ix_document__state` partial `WHERE state = 'IN_APPROVAL'`,
`ix_document__subject_kind__subject_id`,
`ix_document__org_unit_id__document_date`,
`ix_document__deadline_at` partial `WHERE state = 'IN_APPROVAL'`.
Constraint: `ck_document__amount_has_currency`.

### `document_item` — the lines of a document

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `document_id` | `uuid` | no | → `document.id` | |
| `line_number` | `integer` | no | `ck` > 0 | |
| `subject_kind` | `text` | yes | `ck` in the registered entity list | what the line is about |
| `subject_id` | `uuid` | yes | typed link | which record |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | the person the line concerns |
| `description` | `text` | no | `ck` length 1–1000 | |
| `quantity` | `numeric(19,6)` | yes | | |
| `amount` | `numeric(19,4)` | yes | | |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |
| `effective_date` | `date` | yes | | when this line takes effect |

Indexes: `ux_document_item__document_id__line_number`,
`ix_document_item__employee_id`,
`ix_document_item__subject_kind__subject_id`.

A personnel order covering twelve employees is one document and twelve lines,
which is why the line carries `employee_id` and its own `effective_date`.

## Group 3. What has happened to it

### `document_approval` — an approval given or refused

**Immutable.** Pattern:
[14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots) — one row per
route step actually taken.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `document_id` | `uuid` | no | → `document.id` | |
| `route_step_id` | `uuid` | no | → `route_step.id` | which declared step |
| `step_ordinal` | `smallint` | no | `ck` > 0 | copied for ordering |
| `approver_employee_id` | `uuid` | no | ⇢ `hr.employee` | who decided |
| `acted_for_employee_id` | `uuid` | yes | ⇢ `hr.employee` | who they stood in for |
| `decision` | `text` | no | `ck IN (APPROVED, REJECTED, RETURNED, DELEGATED, SKIPPED, ESCALATED)` | |
| `decided_at` | `timestamptz` | no | | |
| `comment` | `text` | yes | `ck` length 1–2000 | |

Indexes: `ix_document_approval__document_id__step_ordinal`,
`ix_document_approval__approver_employee_id__decided_at`,
`ix_document_approval__route_step_id`.

`acted_for_employee_id` is how a delegation during leave is recorded without
anybody sharing an account — the question "who actually signed this" always has
an answer.

### `document_action` — the document's history

**Immutable.** Pattern:
[14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance) — the ledger;
`document.state` is its derived state.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `document_id` | `uuid` | no | → `document.id` | |
| `kind` | `text` | no | `ck IN (CREATED, SUBMITTED, APPROVED, REJECTED, RETURNED, WITHDRAWN, EXECUTED, CANCELLED, COMMENTED, REMINDED, ESCALATED)` | |
| `occurred_at` | `timestamptz` | no | | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | |
| `previous_state` | `text` | yes | | |
| `new_state` | `text` | yes | | |
| `note` | `text` | yes | `ck` length 1–2000 | |

Indexes: `ix_document_action__document_id__occurred_at`,
`ix_document_action__kind__occurred_at`.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a document family per domain — its own header, items, approvers and log | `document`, `document_item`, `document_approval`, `document_action` | 1 |
| a table per document kind | `document` + `document_type` | 1 |
| an approval-threshold constant in code | `route.amount_from` / `amount_to` | 3 |
| a route with a fixed number of approver columns | `route_step`, one row per step | 2 |
| a named approver per route | `route_step.approver_kind = POSITION`, resolved through `hr.assignment` | 3 |
| a printed-documents table | `document.stored_file_id` and `platform.stored_file` | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `document_type` | hundreds | rarely |
| `document_template` | hundreds | rarely |
| `route` | hundreds | inserts, plus closing a period |
| `route_step` | thousands | rarely |
| `document` | millions, growing | state changes |
| `document_item` | tens of millions | with the document |
| `document_approval` | tens of millions | **immutable** |
| `document_action` | tens of millions | **immutable** |

**8 tables** serving thirteen domains. That ratio is the point of the schema: the
alternative measured in an approval implemented per domain is eight tables per
domain that needs one, none of which agree about what "approved" means.

## Open questions

| # | Question | Affects |
|---|---|---|
| D10-Q1 | Is D10 needed in the new system, or is an off-the-shelf workflow product cheaper? | the existence of this schema — [02-domains.md](../../02-domains.md) |
| D10-Q2 | Which documents exist today, and which of them are legally required to be paper? | `document_type` seed, `retention_years` |
| D10-Q3 | Are parallel approval steps needed, or is approval always sequential? | `route_step.is_parallel`, and the engine's complexity |
| D10-Q4 | How is delegation during leave decided — automatically from `hr.absence`, or by hand? | `document_approval.acted_for_employee_id` |
| D10-Q5 | What happens to a document in approval when its route changes? | whether `document.route_id` is frozen at submission |
