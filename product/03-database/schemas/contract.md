---
id: PROD-03-S-CONTRACT
title: "contract schema — D4 Contracts and sales"
status: draft
---

# `contract` — D4 Contracts and sales

| | |
|---|---|
| Domain | D4 Contracts and sales ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **17** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 5 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `contract`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md), which are not repeated
below.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

**What the schema owns:** the agreement between the company and a counterparty —
what is sold, on what terms, at what price, on what schedule, and who played
which part in making it.

**What it does not own:** the claim that follows from the agreement. An
instalment falling due is a `payment_schedule_entry` here; the invoice that
demands it and the receivable that tracks it are
[`accounting`](accounting.md). That boundary is the one to check with the
business before anything is built
([02-domains.md](../../02-domains.md)).

## Group 1. The agreement

### `contract_type` — a kind of contract and its rules

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots) — the
kinds of contract the company sells are **data**. A new one is a row.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | the type code |
| `name` | `text` | no | `ck` length 1–255 | |
| `requires_installation` | `boolean` | no | default `false` | a fitting visit is created on signing |
| `requires_maintenance` | `boolean` | no | default `false` | a maintenance plan is created on installation |
| `default_term_months` | `smallint` | yes | `ck` > 0 | |
| `default_payment_template_id` | `uuid` | yes | → `payment_template.id` | the schedule it is usually sold on |
| `is_instalment` | `boolean` | no | default `false` | the customer pays over time |
| `document_series` | `text` | no | | the numbering series in `platform.document_number` |
| `is_active` | `boolean` | no | default `true` | still sold |

Indexes: `ux_contract_type__company_id__code`.

### `contract` — the agreement itself

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | the branch that sold it |
| `contract_type_id` | `uuid` | no | → `contract_type.id` | which kind |
| `customer_party_id` | `uuid` | no | ⇢ `party.party` | **the only place the customer appears** |
| `number` | `text` | no | | from `platform.document_number` |
| `signed_on` | `date` | yes | | |
| `valid_from` | `date` | no | | in force from |
| `valid_to` | `date` | yes | | in force until, exclusive |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount on the contract |
| `total_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the agreed total |
| `down_payment_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | |
| `state` | `text` | no | `ck IN (DRAFT, SIGNED, ACTIVE, SUSPENDED, COMPLETED, TERMINATED, CANCELLED)` | the lifecycle |
| `terminated_on` | `date` | yes | | |
| `termination_reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `CONTRACT_TERMINATION_REASON` | |
| `service_address_id` | `uuid` | yes | ⇢ `party.address` | where the equipment lives |
| `price_list_id` | `uuid` | yes | → `price_list.id` | the price list it was sold from |
| `parent_contract_id` | `uuid` | yes | → `contract.id` | set when this contract replaces or extends another |

Indexes: `ux_contract__company_id__number`,
`ix_contract__customer_party_id`,
`ix_contract__branch_id__signed_on`,
`ix_contract__state` partial `WHERE state IN ('ACTIVE','SUSPENDED')`,
`ix_contract__valid_to` partial `WHERE valid_to IS NOT NULL`,
`ix_contract__parent_contract_id`.

> There is **no** customer name, address block or telephone column on a contract.
> `customer_party_id` and `service_address_id` point into
> [`party`](party.md), and the roles the contract needs are `party.address_link`
> and `party.phone_link`
> ([14.6](../rules/14-patterns.md#146-one-identity-many-roles)). A corrected
> number is corrected once.

### `contract_item` — what is sold under it

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `contract_id` | `uuid` | no | → `contract.id` | the contract |
| `line_number` | `integer` | no | `ck` > 0 | the position |
| `product_id` | `uuid` | no | ⇢ `reference.product` | what is sold |
| `quantity` | `numeric(19,6)` | no | `ck` > 0 | how much |
| `unit_id` | `uuid` | no | ⇢ `reference.unit_of_measure` | |
| `unit_price_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | |
| `discount_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | |
| `net_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | quantity × price − discount |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |
| `serial_number` | `text` | yes | `ck` length 1–60 | for a serial-tracked product |
| `warranty_months` | `smallint` | yes | `ck` ≥ 0 | overrides the product default |

Indexes: `ux_contract_item__contract_id__line_number`,
`ix_contract_item__product_id`,
`ix_contract_item__serial_number` partial `WHERE serial_number IS NOT NULL`.

### `contract_party` — who plays which part

Pattern: [14.6](../rules/14-patterns.md#146-one-identity-many-roles) — the dealer
who sold it, the fitter who installed it, the collector who services the debt and
the guarantor are all `party.party` rows in a role, not four columns.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `contract_id` | `uuid` | no | → `contract.id` | the contract |
| `party_id` | `uuid` | no | ⇢ `party.party` | who |
| `role` | `text` | no | `ck IN (DEALER, FITTER, COLLECTOR, GUARANTOR, REFERRER, MANAGER)` | in what part |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | set when the party is an employee acting in the role |
| `share_percentage` | `numeric(9,6)` | yes | `ck` 0–1 | their share of a commission |
| `valid_from` | `date` | no | | from |
| `valid_to` | `date` | yes | | until, exclusive |

Indexes: `ix_contract_party__contract_id__role`,
`ix_contract_party__party_id`,
`ix_contract_party__employee_id` partial `WHERE employee_id IS NOT NULL`.
Constraint: `ex_contract_party__no_overlap` on (`contract_id`, `role`,
`party_id`, the date range).

The collector changing is a new row and a closed period — not an overwritten
column, so the question "who was servicing this contract in March" stays
answerable.

### `contract_event` — the history of the agreement

**Immutable.** Pattern:
[14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance) — the ledger;
`contract.state` is its derived state.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `contract_id` | `uuid` | no | → `contract.id` | the contract |
| `kind` | `text` | no | `ck IN (CREATED, SIGNED, ACTIVATED, SUSPENDED, RESUMED, RESCHEDULED, ITEM_CHANGED, PARTY_CHANGED, TERMINATED, COMPLETED, CANCELLED, RESTRUCTURED)` | what happened |
| `occurred_on` | `date` | no | | when it takes effect |
| `reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `CONTRACT_EVENT_REASON` | why |
| `document_id` | `uuid` | yes | ⇢ `docflow.document` | the approval behind it |
| `previous_state` | `text` | yes | | the state before |
| `new_state` | `text` | yes | | the state after |
| `note` | `text` | yes | `ck` length 1–500 | |

Indexes: `ix_contract_event__contract_id__occurred_on`,
`ix_contract_event__kind__occurred_on`.

### `contract_document` — the signed artefacts

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `contract_id` | `uuid` | no | → `contract.id` | the contract |
| `kind` | `text` | no | `ck IN (AGREEMENT, ANNEX, ACT, TERMINATION, SCHEDULE, CONSENT)` | which artefact |
| `stored_file_id` | `uuid` | no | ⇢ `platform.stored_file` | the bytes |
| `signed_on` | `date` | yes | | |
| `is_original` | `boolean` | no | default `false` | the paper original is held |

Indexes: `ix_contract_document__contract_id__kind`.

## Group 2. Money over time

The commitment side of the contract. What is **owed and when** — not what is
claimed, and not what is paid.

### `payment_template` — a schedule pattern

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots) — the
declaration a schedule is generated from. **A new instalment scheme is a row.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | the template code |
| `name` | `text` | no | `ck` length 1–255 | |
| `instalment_count` | `smallint` | no | `ck` > 0 | how many instalments it generates |
| `period_months` | `smallint` | no | default 1, `ck` > 0 | the gap between them |
| `first_due_offset_days` | `smallint` | no | default 30, `ck` ≥ 0 | when the first one falls |
| `down_payment_percentage` | `numeric(9,6)` | no | default 0, `ck` 0–1 | |
| `interest_rate` | `numeric(9,6)` | no | default 0, `ck` ≥ 0 | the annual rate, if any |
| `rounding_rule` | `text` | no | `ck IN (LAST_INSTALMENT, FIRST_INSTALMENT, SPREAD)` | where the rounding difference goes |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_payment_template__company_id__code`.

### `payment_schedule` — a schedule as a whole

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `contract_id` | `uuid` | no | → `contract.id` | the contract |
| `payment_template_id` | `uuid` | yes | → `payment_template.id` | what generated it |
| `revision` | `integer` | no | default 1, `ck` > 0 | the revision number |
| `state` | `text` | no | `ck IN (ACTIVE, SUPERSEDED, CANCELLED)` | |
| `total_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the sum of its entries |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the group |
| `valid_from` | `date` | no | | the revision applies from |
| `reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `RESCHEDULE_REASON` | why it was re-scheduled |

Indexes: `ux_payment_schedule__contract_id__revision`,
`ix_payment_schedule__contract_id__state` partial `WHERE state = 'ACTIVE'`.

> **A re-schedule is a new revision, not an edit.** The previous revision stays
> with its entries, so what the customer was told last year is still on file, and
> a dispute about "what was I supposed to pay in March" has an answer
> ([14.8](../rules/14-patterns.md#148-a-status-not-a-second-table)).

### `payment_schedule_entry` — one instalment

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) —
one row per instalment, never twelve columns.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `payment_schedule_id` | `uuid` | no | → `payment_schedule.id` | the schedule |
| `ordinal` | `smallint` | no | `ck` > 0 | which instalment |
| `due_date` | `date` | no | | when it falls due |
| `principal_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | |
| `interest_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | |
| `total_amount` | `numeric(19,4)` | no | `ck` > 0 | principal + interest |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |
| `open_item_id` | `uuid` | yes | ⇢ `accounting.open_item` | the receivable this instalment became |

Indexes: `ux_payment_schedule_entry__payment_schedule_id__ordinal`,
`ix_payment_schedule_entry__due_date`,
`ix_payment_schedule_entry__open_item_id` partial `WHERE open_item_id IS NOT NULL`.

There is **no** `paid_amount` and no `is_paid` column here. What has been paid is
`accounting.open_item` and its applications; duplicating it would create two
answers to one question ([14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance)).

## Group 3. Prices and promotions

### `price_list` — a price list with a validity period

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `name` | `text` | no | `ck` length 1–255 | |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | null means every branch |
| `contract_type_id` | `uuid` | yes | → `contract_type.id` | null means every kind |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | |
| `valid_from` | `date` | no | | in force from |
| `valid_to` | `date` | yes | | in force until, exclusive |

Indexes: `ux_price_list__company_id__code__valid_from`,
`ix_price_list__valid_from__valid_to`.
Constraint: `ex_price_list__no_overlap` on (`company_id`, `branch_id`,
`contract_type_id`, the date range) — two price lists cannot both apply.

### `price_list_item` — a price in it

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `price_list_id` | `uuid` | no | → `price_list.id` | the list |
| `product_id` | `uuid` | no | ⇢ `reference.product` | the item |
| `unit_price_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | |
| `minimum_quantity` | `numeric(19,6)` | no | default 1, `ck` > 0 | the quantity the price starts at |
| `maximum_discount_percentage` | `numeric(9,6)` | no | default 0, `ck` 0–1 | how far a seller may go |

Indexes: `ux_price_list_item__price_list_id__product_id__minimum_quantity`,
`ix_price_list_item__product_id`.

### `promotion` — a promotion and its conditions

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `name` | `text` | no | `ck` length 1–255 | |
| `kind` | `text` | no | `ck IN (DISCOUNT_PERCENTAGE, DISCOUNT_AMOUNT, FREE_ITEM, FREE_SERVICE, EXTENDED_WARRANTY, CASHBACK)` | what it gives |
| `discount_percentage` | `numeric(9,6)` | yes | `ck` 0–1 | |
| `discount_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |
| `free_product_id` | `uuid` | yes | ⇢ `reference.product` | |
| `extra_warranty_months` | `smallint` | yes | `ck` > 0 | |
| `minimum_contract_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | the condition |
| `product_category_id` | `uuid` | yes | ⇢ `reference.product_category` | narrows it |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | narrows it |
| `usage_limit` | `integer` | yes | `ck` > 0 | how many times it may be applied in total |
| `valid_from` | `date` | no | | |
| `valid_to` | `date` | yes | | exclusive |

Indexes: `ux_promotion__company_id__code`,
`ix_promotion__valid_from__valid_to`.
Constraint: `ck_promotion__kind_has_its_value` — the column the `kind` names is
set and the others are null.

### `contract_promotion` — a promotion applied to a contract

**Immutable.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `contract_id` | `uuid` | no | → `contract.id` | the contract |
| `promotion_id` | `uuid` | no | → `promotion.id` | the promotion |
| `applied_on` | `date` | no | | |
| `benefit_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what it was worth on this contract |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |

Indexes: `ux_contract_promotion__contract_id__promotion_id`,
`ix_contract_promotion__promotion_id`.

The benefit is **stored** rather than recomputed: a promotion's terms change and
the contract keeps what it was actually given.

## Group 4. Plans and referrals

### `sales_plan` — a plan for a unit and a period

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | |
| `org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | a plan may be personal |
| `fiscal_period_id` | `uuid` | no | ⇢ `accounting.fiscal_period` | the period planned for |
| `revision` | `integer` | no | default 1, `ck` > 0 | |
| `state` | `text` | no | `ck IN (DRAFT, APPROVED, SUPERSEDED)` | |
| `approved_at` | `timestamptz` | yes | | |
| `approved_by` | `uuid` | yes | ⇢ `platform.app_user` | |

Indexes: `ux_sales_plan__branch_id__org_unit_id__employee_id__fiscal_period_id__revision`,
`ix_sales_plan__fiscal_period_id`.

### `sales_plan_item` — one figure of a plan

Pattern: [14.7](../rules/14-patterns.md#147-a-dimension-is-a-column-not-a-table) —
one fact table, dimensions as columns.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `sales_plan_id` | `uuid` | no | → `sales_plan.id` | the plan |
| `product_category_id` | `uuid` | yes | ⇢ `reference.product_category` | dimension |
| `contract_type_id` | `uuid` | yes | → `contract_type.id` | dimension |
| `measure` | `text` | no | `ck IN (CONTRACT_COUNT, AMOUNT, UNIT_COUNT)` | what is planned |
| `target_quantity` | `numeric(19,6)` | yes | `ck` ≥ 0 | |
| `target_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |

Indexes: `ux_sales_plan_item__sales_plan_id__product_category_id__contract_type_id__measure`.
Constraint: `ck_sales_plan_item__has_a_target`; `ck_sales_plan_item__amount_has_currency`.

### `referral_link` — who referred whom

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `referrer_party_id` | `uuid` | no | ⇢ `party.party` | who referred |
| `referred_party_id` | `uuid` | no | ⇢ `party.party` | who was referred |
| `contract_id` | `uuid` | yes | → `contract.id` | the contract that resulted |
| `referred_on` | `date` | no | | |
| `reward_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what the referrer earned |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |
| `state` | `text` | no | `ck IN (REGISTERED, CONVERTED, REWARDED, EXPIRED)` | |

Indexes: `ix_referral_link__referrer_party_id`,
`ux_referral_link__referred_party_id__referrer_party_id`,
`ix_referral_link__contract_id` partial `WHERE contract_id IS NOT NULL`.
Constraint: `ck_referral_link__not_self`
(`referrer_party_id <> referred_party_id`).

The referral structure is a graph over `party.party`, not a tree of copied
customer records. Depth is a query over this one table.

## Group 5. Signing

### `e_signature_request` — an electronic signing request

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `contract_id` | `uuid` | no | → `contract.id` | the contract |
| `party_id` | `uuid` | no | ⇢ `party.party` | who is asked to sign |
| `channel` | `text` | no | `ck IN (SMS_CODE, MOBILE_APP, QUALIFIED_CERTIFICATE, BIOMETRIC)` | how |
| `provider` | `text` | no | `ck` length 1–40 | which service |
| `external_id` | `text` | yes | | its identifier there |
| `requested_at` | `timestamptz` | no | | |
| `expires_at` | `timestamptz` | no | `ck` > `requested_at` | |
| `state` | `text` | no | `ck IN (REQUESTED, SENT, SIGNED, DECLINED, EXPIRED, FAILED)` | |
| `signed_at` | `timestamptz` | yes | | |
| `attempt_count` | `smallint` | no | default 0, `ck` ≥ 0 | |
| `stored_file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the signed artefact |
| `evidence` | `jsonb` | yes | | what the provider returned as proof — a justified `jsonb` |

Indexes: `ix_e_signature_request__contract_id`,
`ux_e_signature_request__provider__external_id` partial `WHERE external_id IS NOT NULL`,
`ix_e_signature_request__state__expires_at` partial `WHERE state IN ('REQUESTED','SENT')`.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| customer name, address and phone columns on a contract | `customer_party_id`, `service_address_id`, and the D2 link tables | 1 |
| a table per contract kind | `contract` + `contract_type` | 1 |
| an archive of superseded schedules | `payment_schedule.revision` and `state` | 3 |
| a paid-amount column on a schedule entry | `accounting.open_item` and its applications | 1 |
| a dealer, fitter and collector column on a contract | `contract_party` with a role | 2 |
| a table per promotion kind | `promotion` with a `kind` and the value column it names | 1 |
| a referral tree with copied customer data | `referral_link` over `party.party` | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `contract_type` | tens | rarely |
| `contract` | millions | state changes |
| `contract_item` | millions | with the contract |
| `contract_party` | millions | inserts, plus closing a period |
| `contract_event` | tens of millions | **immutable** |
| `contract_document` | millions | inserts |
| `payment_template` | hundreds | rarely |
| `payment_schedule` | millions | revision only |
| `payment_schedule_entry` | tens of millions | with the revision |
| `price_list` | hundreds | rarely |
| `price_list_item` | hundreds of thousands | with the list |
| `promotion` | hundreds | rarely |
| `contract_promotion` | millions | **immutable** |
| `sales_plan` | tens of thousands | until approved |
| `sales_plan_item` | hundreds of thousands | with the plan |
| `referral_link` | millions | state changes |
| `e_signature_request` | millions | state changes |

**17 tables.** `contract_event` and `payment_schedule_entry` are the two above
the partitioning threshold and are reviewed against measured volume before the
first release ([rule 10](../rules/10-large-tables.md)).

## Open questions

| # | Question | Affects |
|---|---|---|
| D4-Q1 | Where is the boundary with D5 — does a schedule entry become a receivable when it is generated, or when it falls due? | `payment_schedule_entry.open_item_id`, and every ageing report |
| D4-Q2 | Is a re-schedule always a new revision, or may an entry be moved in place? | `payment_schedule.revision`, and what a customer dispute can be answered with |
| D4-Q3 | May two price lists apply to one sale, and if so which wins? | `ex_price_list__no_overlap`, or its removal plus a priority column |
| D4-Q4 | Are promotions combinable? | `contract_promotion`, and the discount calculation |
| D4-Q5 | Is the referral reward a contract term, a payroll item, or an accounting entry? | `referral_link.reward_amount`, and a boundary with D6 |
| D4-Q6 | Which contract kinds legally require a qualified signature? | `e_signature_request.channel`, and the evidence retained |
