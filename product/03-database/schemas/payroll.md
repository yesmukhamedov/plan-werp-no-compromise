---
id: PROD-03-S-PAYROLL
title: "payroll schema — D6 Compensation calculation"
status: draft
---

# `payroll` — D6 Compensation calculation

| | |
|---|---|
| Domain | D6 Compensation calculation ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **7** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 3 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `payroll`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md), which are not repeated
below.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

**The domain computes; it does not agree and it does not pay.** What was agreed
with the employee is [`hr.compensation`](hr.md), which this domain reads and
never writes. What the company owes the ledger is
[`accounting.journal_entry`](accounting.md), which this domain causes and does
not write either. In between sits one calculation, and this schema holds its
declaration, its inputs and its result.

**Seven tables, and the shape of them is the whole design.** A payroll that grows
a column for every new allowance, deduction and contribution becomes
unmaintainable within a few years; a payroll whose components are **rows** grows
by data entry.

## Group 1. What a payslip can contain

The declaration. Nothing in this group is a calculation — it is the statement of
which calculations exist.

### `payroll_component` — one thing that can appear on a payslip

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots).
**A new earning, deduction or contribution is a row here.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | the component code |
| `name` | `text` | no | `ck` length 1–255 | how it is printed on a payslip |
| `kind` | `text` | no | `ck IN (EARNING, DEDUCTION, EMPLOYER_CONTRIBUTION, INFORMATIONAL)` | which side of the payslip it falls on |
| `basis` | `text` | no | `ck IN (FIXED_AMOUNT, RATE_TIMES_HOURS, PERCENTAGE_OF_BASE, PERCENTAGE_OF_GROSS, PER_UNIT, MANUAL_INPUT, FORMULA)` | how its amount is arrived at |
| `sequence` | `integer` | no | `ck` > 0 | the order components are evaluated in |
| `is_taxable` | `boolean` | no | default `true` | enters the income-tax base |
| `is_contribution_base` | `boolean` | no | default `true` | enters the social-contribution base |
| `is_prorated_by_time` | `boolean` | no | default `false` | scaled by days actually worked |
| `time_code_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `TIME_CODE` | the time code it is driven by |
| `allowance_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `ALLOWANCE_KIND` | the agreed allowance it pays out |
| `gl_account_id` | `uuid` | yes | ⇢ `accounting.account` | where it posts |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_payroll_component__company_id__code`,
`ix_payroll_component__kind__sequence`,
`ix_payroll_component__time_code_id` partial `WHERE time_code_id IS NOT NULL`.

> `sequence` is why the design works. Income tax must be computed after the
> earnings it taxes; a net-pay component after both. Ordering by an integer
> column makes the order **data**; ordering by the position of a method in a
> class makes it a release.

> `gl_account_id` names the account directly rather than going through
> `accounting.posting_rule` because a payroll component maps one-to-one to an
> account and the indirection would buy nothing. If that ever stops being true,
> the column is replaced by a posting rule event — a migration, and the
> tolerable kind.

### `payroll_component_rule` — how a component is computed, for a period

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `payroll_component_id` | `uuid` | no | → `payroll_component.id` | the component |
| `org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | narrows the rule to a unit |
| `job_id` | `uuid` | yes | ⇢ `hr.job` | narrows it to a job |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | narrows it to a branch |
| `fixed_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | for `FIXED_AMOUNT` |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | its currency |
| `percentage` | `numeric(9,6)` | yes | `ck` 0–10 | for the percentage bases |
| `rate_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | for `RATE_TIMES_HOURS` and `PER_UNIT` |
| `minimum_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | the floor |
| `maximum_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | the ceiling |
| `priority` | `integer` | no | default 0 | the more specific rule wins |
| `valid_from` | `date` | no | | applies from |
| `valid_to` | `date` | yes | | applies until, exclusive |

Indexes: `ix_payroll_component_rule__payroll_component_id__valid_from`,
`ix_payroll_component_rule__valid_to` partial `WHERE valid_to IS NULL`.
Constraint: `ex_payroll_component_rule__no_ambiguity` — an exclusion constraint
on (`payroll_component_id`, `org_unit_id`, `job_id`, `branch_id`, `priority`,
the date range); `ck_payroll_component_rule__amount_has_currency`;
`ck_payroll_component_rule__basis_value_present` — the column the component's
basis needs is set.

### `payroll_rate` — a statutory rate

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag). Income tax,
social tax, pension, medical insurance — the rates the state sets, kept apart
from the components that use them because the state changes them on its own
schedule and every past payslip must keep the rate it was computed with.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `country_id` | `uuid` | no | ⇢ `reference.country` | which state sets it |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | the rate code |
| `rate` | `numeric(9,6)` | no | `ck` 0–1 | the rate as a fraction |
| `base_floor_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | the base is at least this |
| `base_ceiling_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | the base is capped here |
| `deduction_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | the standard relief |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |
| `applies_to_category` | `text` | yes | `ck IN (RESIDENT, NON_RESIDENT, PENSIONER, STUDENT, DISABLED, VETERAN)` | the category it is specific to |
| `valid_from` | `date` | no | | applies from |
| `valid_to` | `date` | yes | | applies until, exclusive |

Indexes: `ux_payroll_rate__company_id__code__applies_to_category__valid_from`,
`ix_payroll_rate__valid_from__valid_to`.
Constraint: `ex_payroll_rate__no_overlap` on (`company_id`, `code`,
`applies_to_category`, the date range).

> A rate is a **row with a period**, and it is never edited. When the state
> changes a rate mid-year, last month's payslips keep last month's rate without
> anyone doing anything, and a recalculation of an old period reproduces the old
> figure exactly. Editing a rate in place silently rewrites every payslip that
> is ever recomputed.

## Group 2. What goes in

### `payroll_input` — a value that cannot be derived

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — a bonus
awarded, a piece count, a one-off deduction, a court-ordered garnishment are all
*a number a person supplied for a component in a period*, so they are one table.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `employment_id` | `uuid` | no | ⇢ `hr.employment` | whose |
| `payroll_component_id` | `uuid` | no | → `payroll_component.id` | for which component |
| `fiscal_period_id` | `uuid` | no | ⇢ `accounting.fiscal_period` | for which period |
| `amount` | `numeric(19,4)` | yes | | the value, when it is money |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | its currency |
| `quantity` | `numeric(19,6)` | yes | `ck` ≥ 0 | the value, when it is a count |
| `reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `PAYROLL_INPUT_REASON` | why |
| `document_id` | `uuid` | yes | ⇢ `docflow.document` | the approval behind it |
| `source` | `text` | no | `ck IN (MANUAL, SERVICE_PREMIUM, SALES_COMMISSION, COURT_ORDER, IMPORT)` | where the number came from |
| `source_id` | `uuid` | yes | typed link ([14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind)) | the record that produced it |
| `state` | `text` | no | `ck IN (DRAFT, APPROVED, CONSUMED, CANCELLED)` | |

Indexes: `ux_payroll_input__employment_id__payroll_component_id__fiscal_period_id__source_id`,
`ix_payroll_input__fiscal_period_id__state`,
`ix_payroll_input__source__source_id`.
Constraint: `ck_payroll_input__has_a_value`; `ck_payroll_input__amount_has_currency`.

A technician's premium from [`service`](service.md) and a seller's commission
from [`contract`](contract.md) both arrive here as rows with a `source` and a
`source_id`, so a payslip line can always be traced back to the work that earned
it.

## Group 3. What comes out

### `payroll_run` — one calculation

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `fiscal_period_id` | `uuid` | no | ⇢ `accounting.fiscal_period` | the period |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | null means the whole company |
| `kind` | `text` | no | `ck IN (REGULAR, ADVANCE, CORRECTION, FINAL_SETTLEMENT, BONUS)` | which run this is |
| `sequence` | `smallint` | no | default 1, `ck` > 0 | the run number within the period |
| `state` | `text` | no | `ck IN (DRAFT, CALCULATED, APPROVED, POSTED, PAID, CANCELLED)` | the lifecycle |
| `calculated_at` | `timestamptz` | yes | | |
| `approved_at` | `timestamptz` | yes | | |
| `approved_by` | `uuid` | yes | ⇢ `platform.app_user` | |
| `journal_entry_id` | `uuid` | yes | ⇢ `accounting.journal_entry` | the posting it produced |
| `employee_count` | `integer` | yes | `ck` ≥ 0 | how many payslips |
| `gross_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | the run total |
| `net_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |

Indexes: `ux_payroll_run__company_id__fiscal_period_id__branch_id__kind__sequence`,
`ix_payroll_run__state` partial `WHERE state IN ('DRAFT','CALCULATED')`,
`ix_payroll_run__journal_entry_id`.

> **A recalculation is a new run**, with `kind = CORRECTION`, and the previous
> run keeps its state and its payslips. Nothing is copied into a temporary table
> and nothing is deleted: a `TEMP_` table is not a stage of a calculation, it is
> a lost audit trail ([14.8](../rules/14-patterns.md#148-a-status-not-a-second-table)).

### `payroll_entry` — one employee in one run

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `payroll_run_id` | `uuid` | no | → `payroll_run.id` | the run |
| `employment_id` | `uuid` | no | ⇢ `hr.employment` | whose payslip |
| `employee_id` | `uuid` | no | ⇢ `hr.employee` | denormalized for the payslip index |
| `org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | the unit as at the period, for reporting |
| `worked_days` | `numeric(9,4)` | no | default 0, `ck` ≥ 0 | from the time sheet |
| `worked_hours` | `numeric(9,4)` | no | default 0, `ck` ≥ 0 | from the time sheet |
| `gross_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | the sum of the earning lines |
| `deduction_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | the sum of the deduction lines |
| `net_amount` | `numeric(19,4)` | no | default 0 | gross − deductions |
| `employer_cost_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | gross + employer contributions |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |
| `payment_id` | `uuid` | yes | ⇢ `accounting.payment` | how it was paid |
| `state` | `text` | no | `ck IN (CALCULATED, APPROVED, PAID, HELD)` | |

Indexes: `ux_payroll_entry__payroll_run_id__employment_id`,
`ix_payroll_entry__employee_id__created_at`,
`ix_payroll_entry__org_unit_id`,
`ix_payroll_entry__payment_id` partial `WHERE payment_id IS NOT NULL`.
Constraint: `ck_payroll_entry__net_is_gross_less_deductions`
(`net_amount = gross_amount - deduction_amount`).

The four totals are maintained by the aggregate in the same transaction that
writes the lines — this is one aggregate, so there is no second writer and no
trigger ([rule 9](../rules/09-logic-in-the-database.md)).

### `payroll_entry_line` — one component of one payslip

**Immutable.** Pattern:
[14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table). **This
is the table that replaces a column per allowance, per deduction and per
contribution.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `payroll_entry_id` | `uuid` | no | → `payroll_entry.id` | the payslip |
| `payroll_component_id` | `uuid` | no | → `payroll_component.id` | which component |
| `sequence` | `integer` | no | `ck` > 0 | the order it was evaluated in |
| `base_amount` | `numeric(19,4)` | yes | | what the calculation was applied to |
| `rate` | `numeric(9,6)` | yes | | the rate or percentage used |
| `quantity` | `numeric(19,6)` | yes | | hours or units |
| `amount` | `numeric(19,4)` | no | | the resulting amount; signed by the component's kind |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |
| `payroll_rate_id` | `uuid` | yes | → `payroll_rate.id` | the statutory rate row used |
| `payroll_component_rule_id` | `uuid` | yes | → `payroll_component_rule.id` | the rule row used |
| `payroll_input_id` | `uuid` | yes | → `payroll_input.id` | the input row used |

Indexes: `ux_payroll_entry_line__payroll_entry_id__payroll_component_id`,
`ix_payroll_entry_line__payroll_component_id`,
`ix_payroll_entry_line__payroll_rate_id`.

> Every line stores **which rule row and which rate row produced it**. That is
> what makes a payslip explainable three years later, to an employee, an
> auditor or a court — without re-running a calculation whose inputs have since
> changed. It is the same discipline the ledger uses when it stores the exchange
> rate on the entry.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a bonus table, a deduction table, a contribution table | `payroll_component` with a `kind`, and `payroll_entry_line` | 1 |
| a column per allowance on a payslip | `payroll_entry_line`, one row per component | 2 |
| a temporary calculation table, and an archive of it | `payroll_run` with a state; a recalculation is a new run | 3 |
| a table of tax rates per tax, per year | `payroll_rate` with a period | 2 |
| a payslip-print table | the payslip is a report ([ADR-0009](../../../docs/02-decisions/ADR-0009-reporting-and-exports.md)) | 1 |
| a salary table | `hr.compensation` — this domain does not agree pay | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `payroll_component` | hundreds | rarely |
| `payroll_component_rule` | thousands | inserts, plus closing a period |
| `payroll_rate` | hundreds | inserts, plus closing a period |
| `payroll_input` | millions, growing | state changes |
| `payroll_run` | thousands | state changes |
| `payroll_entry` | tens of millions, growing | state changes |
| `payroll_entry_line` | hundreds of millions, growing | **immutable** |

**7 tables.** `payroll_entry_line` is range-partitioned through its run's period
([rule 10](../rules/10-large-tables.md)).

Everything here is personal data of the most sensitive kind. Access follows
[08-security.md](../../08-security.md); a payslip is visible to its own
employee, to the payroll role, and to nobody else by default — a manager who may
approve a time sheet does not thereby see what the calculation produced
([D3 permissions](../../spec/D3-hr.md#permissions)).

## Open questions

| # | Question | Affects |
|---|---|---|
| D6-Q1 | Is D6 a separate domain or part of D5? | the existence of this schema — [02-domains.md](../../02-domains.md) |
| D6-Q2 | Which components exist today, and is the list complete? | `payroll_component` seed; this is the question the whole design depends on |
| D6-Q3 | How is a retroactive change handled — a correction run for the old period, or an adjustment in the current one? | `payroll_run.kind`, and every year-to-date figure |
| D6-Q4 | Are advances a run kind or a payment against a later run? | `payroll_run.kind = ADVANCE`, and the settlement in D5 |
| D6-Q5 | Does the technician premium belong to D8 and arrive as input, or is it computed here? | `payroll_input.source`, and a boundary with D8 |
| D6-Q6 | Which statutory categories change a rate, and where is the category recorded? | `payroll_rate.applies_to_category`, and a column in `hr` that currently does not exist |
