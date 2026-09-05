---
id: PROD-03-S-ACCOUNTING
title: "accounting schema — D5 Accounting and finance"
status: draft
---

# `accounting` — D5 Accounting and finance

| | |
|---|---|
| Domain | D5 Accounting and finance ([02-domains.md](../../02-domains.md)) |
| Domain specification | [D5-accounting.md](../../spec/D5-accounting.md) |
| Tables | **34** |
| State of the model | **designed** |
| Table groups | 8 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `accounting`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md) — `id`, `created_at`,
`created_by`, `updated_at`, `updated_by`, `version` — which are not repeated
below. Immutable tables are marked as such and carry only `id`, `created_at`,
`created_by`.

Two reference markers are used:

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint; the application enforces it and a nightly job reports orphans as a metric ([§1](../rules/01-organization.md)) |

## Group 1. The chart and the calendar

The two things every posting names: which account it hits and which period it
falls in. Both are period-dated, and both are set up before a single entry
exists.

### `account` — an account in the chart

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag) (a period, not a flag)
over a tree.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | whose chart this is |
| `parent_id` | `uuid` | yes | → `account.id` | the parent in the chart |
| `code` | `text` | no | `ck` `^[0-9]{4,10}$` | the account number |
| `nature` | `text` | no | `ck IN (ASSET, LIABILITY, EQUITY, INCOME, EXPENSE)` | what the account measures |
| `normal_side` | `text` | no | `ck IN (DEBIT, CREDIT)` | the side that increases it |
| `is_postable` | `boolean` | no | default `false` | entries may be posted to it |
| `control_of` | `text` | yes | `ck IN (RECEIVABLE, PAYABLE, BANK, CASH, INVENTORY, TAX, PAYROLL)` | the subledger it reconciles against |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | set when the account may hold only one currency |
| `is_reconciled_by_open_item` | `boolean` | no | default `false` | its lines produce open items |
| `path` | `ltree` | no | | the materialized path |
| `depth` | `integer` | no | `ck` ≥ 0 | the depth, derived from `path` |
| `valid_from` | `date` | no | | in the chart from |
| `valid_to` | `date` | yes | | in the chart until, exclusive |

Indexes: `ux_account__company_id__code`, `ix_account__parent_id`,
`ix_account__path` (GiST), `ix_account__company_id__control_of` partial
`WHERE control_of IS NOT NULL`.

Constraints: `ck_account__no_self_parent`; `ck_account__control_is_postable`
(`control_of IS NULL OR is_postable`); `ck_account__validity`
(`valid_to IS NULL OR valid_to > valid_from`).

Application rules — inexpressible in the database, each covered by a test:
`PostableAccountIsLeafRule` (a postable account has no children),
`AccountNatureMatchesParentRule`, `AccountInUseCannotChangeNatureRule`.

`path` and `depth` are maintained by a trigger and covered by a test that writes
bypassing the application — the one trigger this domain has
([§9](../rules/09-logic-in-the-database.md)).

> `normal_side` is **not** derived from `nature`. A contra account — accumulated
> depreciation against an asset, a sales discount against income — has the
> opposite normal side to its nature, and deriving it makes those accounts
> unrepresentable.

### `account_name` — account names by locale

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `account_id` | `uuid` | no | → `account.id` | the account |
| `locale` | `text` | no | `ck` in the supported list | the language |
| `name` | `text` | no | `ck` length 1–255 | the name |
| `short_name` | `text` | yes | `ck` length 1–60 | the name for a statement column |

Indexes: `ux_account_name__account_id__locale`.

### `account_dimension_rule` — which dimensions an account requires

Pattern: [14.7](../rules/14-patterns.md#147-a-dimension-is-a-column-not-a-table).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `account_id` | `uuid` | no | → `account.id` | the account |
| `dimension` | `text` | no | `ck IN (BRANCH, ORG_UNIT, PARTY, PRODUCT, CONTRACT)` | which dimension |
| `requirement` | `text` | no | `ck IN (REQUIRED, OPTIONAL, FORBIDDEN)` | whether a line must carry it |

Indexes: `ux_account_dimension_rule__account_id__dimension`.

A line that violates the rule is refused at write time by
`LineDimensionRule`. Without this table the requirement lives in the head of
whoever built the report, and is discovered when the report does not add up.

### `fiscal_year` — a financial year

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `code` | `text` | no | `ck` `^[0-9]{4}$` | the year |
| `start_date` | `date` | no | | the first day |
| `end_date` | `date` | no | `ck` > `start_date` | the last day |
| `state` | `text` | no | `ck IN (OPEN, CLOSED)` | the year's state |

Indexes: `ux_fiscal_year__company_id__code`.

### `fiscal_period` — an accounting period

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) —
a period is a row, never a column.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `fiscal_year_id` | `uuid` | no | → `fiscal_year.id` | the year |
| `ordinal` | `smallint` | no | `ck` 1–16 | the position in the year |
| `start_date` | `date` | no | | the first day |
| `end_date` | `date` | no | `ck` ≥ `start_date` | the last day |
| `kind` | `text` | no | `ck IN (REGULAR, ADJUSTMENT)` | an adjustment period carries the closing entries |
| `state` | `text` | no | `ck IN (FUTURE, OPEN, CLOSING, CLOSED, LOCKED)` | see [the state machine](#a-period-is-a-state-machine) |
| `closed_at` | `timestamptz` | yes | | when it was closed |
| `closed_by` | `uuid` | yes | ⇢ `platform.app_user` | who closed it |

Indexes: `ux_fiscal_period__fiscal_year_id__ordinal`,
`ix_fiscal_period__start_date__end_date`.

Constraints: `ex_fiscal_period__no_overlap` — an exclusion constraint on
(`fiscal_year_id`, the date range), so two periods of one year cannot overlap.
The absence of gaps is `CalendarCompletenessRule`, checked when the year is
generated.

## Group 2. The ledger

The truth of the domain. `journal_entry_line` is append-only and immutable;
`account_balance` is derived from it and rebuildable; the two are reconciled
nightly and a divergence is an alert.

### `journal` — a book of prime entry

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `code` | `text` | no | `ck` length 1–10 | the journal code |
| `name` | `text` | no | | the name; not translated — it is an internal designation |
| `kind` | `text` | no | `ck IN (SALES, PURCHASE, CASH, BANK, GENERAL, PAYROLL, INVENTORY, CLOSING)` | the code branches on this |
| `number_series` | `text` | no | | the series `platform.document_number` allocates from |
| `is_active` | `boolean` | no | default `true` | in use |

Indexes: `ux_journal__company_id__code`.

> `kind` is a `ck` list rather than a `reference_item` because the posting engine
> branches on it: a `CLOSING` journal may post into a closing period, a `CASH`
> journal requires a cash account. **A `ck` enumeration is a list the code
> branches on; a `reference_item` is a list only the data uses**
> ([§5.1](../rules/05-types.md#51-enumerations)). `budget.kind_id` is the other
> side of that distinction.

### `journal_entry` — a posted accounting document

**Immutable.** Carries `id`, `created_at`, `created_by` and nothing else of the
mandatory set.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `journal_id` | `uuid` | no | → `journal.id` | the journal |
| `fiscal_period_id` | `uuid` | no | → `fiscal_period.id` | the period it posts into |
| `number` | `text` | no | | the human-facing number, allocated by `platform.document_number` |
| `posting_date` | `date` | no | | the date it affects the ledger on |
| `document_date` | `date` | no | | the date on the source document |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | the transaction currency |
| `functional_currency_id` | `uuid` | no | ⇢ `reference.currency` | the company's accounting currency |
| `exchange_rate` | `numeric(19,8)` | no | `ck` > 0 | the rate used |
| `rate_date` | `date` | no | | the date the rate was taken for |
| `debit_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the total debit, functional currency |
| `credit_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the total credit, functional currency |
| `description` | `text` | yes | `ck` length 1–255 | what the entry is |
| `source_kind` | `text` | no | `ck IN (MANUAL, INVOICE, PAYMENT, PAYROLL, INVENTORY, CONTRACT, GATEWAY, CLOSING, REVERSAL)` | what produced it |
| `source_id` | `uuid` | yes | typed link ([14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind)) | the originating document |
| `reverses_entry_id` | `uuid` | yes | → `journal_entry.id` | the entry this one reverses |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | the branch it belongs to |
| `posting_rule_id` | `uuid` | yes | → `posting_rule.id` | the rule that generated it |

Indexes: `ux_journal_entry__company_id__journal_id__number`,
`ix_journal_entry__fiscal_period_id`, `ix_journal_entry__posting_date`,
`ix_journal_entry__source_kind__source_id`,
`ux_journal_entry__reverses_entry_id` partial `WHERE reverses_entry_id IS NOT NULL`
— an entry is reversed at most once.

Constraints: `ck_journal_entry__balanced` (`debit_amount = credit_amount`);
`ck_journal_entry__manual_has_no_source`
(`source_kind <> 'MANUAL' OR source_id IS NULL`);
`ck_journal_entry__reversal_has_target`
(`source_kind <> 'REVERSAL' OR reverses_entry_id IS NOT NULL`).

Volume: the largest table in the schema after its own lines. Range-partitioned by
`posting_date` per [§10](../rules/10-large-tables.md); a filed year is a
detached partition, never a copied table.

### `journal_entry_line` — a line of an entry

**Immutable.** Pattern:
[14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance) — this table is the
ledger, and everything else in the domain is derived from it.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `entry_id` | `uuid` | no | → `journal_entry.id` | the entry |
| `line_number` | `integer` | no | `ck` > 0 | the position in the entry |
| `account_id` | `uuid` | no | → `account.id` | the account |
| `side` | `text` | no | `ck IN (DEBIT, CREDIT)` | the side |
| `amount` | `numeric(19,4)` | no | `ck` > 0 | the amount, transaction currency |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | that currency |
| `functional_amount` | `numeric(19,4)` | no | `ck` > 0 | the amount, functional currency |
| `functional_currency_id` | `uuid` | no | ⇢ `reference.currency` | that currency |
| `description` | `text` | yes | `ck` length 1–255 | the line text |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | dimension |
| `org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | dimension |
| `party_id` | `uuid` | yes | ⇢ `party.party` | dimension |
| `product_id` | `uuid` | yes | ⇢ `reference.product` | dimension |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | dimension |
| `quantity` | `numeric(19,6)` | yes | | for lines that carry a quantity |
| `unit_id` | `uuid` | yes | ⇢ `reference.unit_of_measure` | its unit |
| `tax_code_id` | `uuid` | yes | → `tax_code.id` | the tax the line carries |

Indexes: `ux_journal_entry_line__entry_id__line_number`,
`ix_journal_entry_line__account_id`,
`ix_journal_entry_line__party_id` partial `WHERE party_id IS NOT NULL`,
`ix_journal_entry_line__branch_id`,
`ix_journal_entry_line__contract_id` partial `WHERE contract_id IS NOT NULL`.

Constraints: `ck_journal_entry_line__quantity_has_unit` — both null or both set.

Partitioned together with its parent.

> The five dimension columns are the whole reporting model of the system. A cut
> of the figures the business asks for later is a `GROUP BY` on this table, not a
> table of its own
> ([14.7](../rules/14-patterns.md#147-a-dimension-is-a-column-not-a-table)). Which of
> the five a given account requires is `account_dimension_rule`.

### `account_balance` — derived period balances

**Rebuildable.** Not a source of truth; deleted and rebuilt by a job whose
divergence from the lines is an alert.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `account_id` | `uuid` | no | → `account.id` | the account |
| `fiscal_period_id` | `uuid` | no | → `fiscal_period.id` | the period |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | the currency all four amounts are in |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | the dimension the balance is kept by |
| `org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | likewise |
| `opening_amount` | `numeric(19,4)` | no | | signed by the account's normal side |
| `debit_turnover_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | debits in the period |
| `credit_turnover_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | credits in the period |
| `closing_amount` | `numeric(19,4)` | no | | the closing balance |
| `rebuilt_at` | `timestamptz` | no | | when this row was last computed |

Indexes: `ux_account_balance__account_id__fiscal_period_id__currency_id__branch_id__org_unit_id`,
`ix_account_balance__fiscal_period_id`.

One `currency_id` governs every amount in the row — the case
[DB-06](../checks.md) allows explicitly.

## Group 3. Account determination

**The group that makes an eleventh product line free.** Which accounts a business
event posts to is reference data an accountant edits, not code a team releases.

### `posting_rule` — account determination, the declaration

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots). **This table
is why an eleventh product line costs nothing.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | the rule code |
| `event` | `text` | no | `ck IN (INVOICE_ISSUED, INVOICE_CANCELLED, PAYMENT_RECEIVED, PAYMENT_SENT, PAYMENT_RETURNED, STOCK_RECEIVED, STOCK_ISSUED, STOCK_WRITTEN_OFF, PAYROLL_ACCRUED, PAYROLL_PAID, TAX_ACCRUED, PERIOD_CLOSED)` | which business event it serves |
| `journal_id` | `uuid` | no | → `journal.id` | the journal the entry lands in |
| `product_category_id` | `uuid` | yes | ⇢ `reference.product_category` | narrows the rule |
| `contract_type_id` | `uuid` | yes | ⇢ `contract.contract_type` | narrows the rule |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | narrows the rule |
| `priority` | `integer` | no | default 0 | the more specific rule wins |
| `valid_from` | `date` | no | | applies from |
| `valid_to` | `date` | yes | | applies until, exclusive |

Indexes: `ux_posting_rule__company_id__code`,
`ix_posting_rule__company_id__event__valid_from`.

Constraint: `ex_posting_rule__no_ambiguity` — an exclusion constraint preventing
two rules with the same company, event, narrowing set and priority from
overlapping in time. Which rule applies to a document is then a fact, not a race.

### `posting_rule_line` — the lines the rule produces

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `posting_rule_id` | `uuid` | no | → `posting_rule.id` | the rule |
| `line_number` | `integer` | no | `ck` > 0 | the position |
| `side` | `text` | no | `ck IN (DEBIT, CREDIT)` | the side |
| `account_id` | `uuid` | no | → `account.id` | the account |
| `amount_source` | `text` | no | `ck IN (NET, TAX, GROSS, DISCOUNT, COST, ROUNDING)` | which figure of the document supplies the amount |
| `party_source` | `text` | no | `ck IN (CUSTOMER, SUPPLIER, EMPLOYEE, NONE)` | which party the line is dimensioned by |
| `tax_code_id` | `uuid` | yes | → `tax_code.id` | for tax lines |

Indexes: `ux_posting_rule_line__posting_rule_id__line_number`,
`ix_posting_rule_line__account_id`.

Application rule `PostingRuleBalancesRule`: the debit sources of a rule and its
credit sources must be capable of balancing for every document the rule accepts.
Verified when the rule is saved, not when the entry fails.

## Group 4. The subledgers

A receivable or a payable seen per counterparty and per due date, tied row by row
to the ledger line that created it and reconciled against its control account.

### `open_item` — a receivable or a payable

Pattern: [14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance) — a second
derived view of the same lines, kept for a different question.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `kind` | `text` | no | `ck IN (RECEIVABLE, PAYABLE)` | which side of the business |
| `party_id` | `uuid` | no | ⇢ `party.party` | the counterparty |
| `account_id` | `uuid` | no | → `account.id` | the control account |
| `entry_line_id` | `uuid` | no | → `journal_entry_line.id` | the line that created it |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | the contract behind it |
| `document_date` | `date` | no | | the date of the source document |
| `due_date` | `date` | no | | when it falls due |
| `amount` | `numeric(19,4)` | no | `ck` > 0 | the item's amount |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | its currency |
| `applied_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | the sum of its applications |
| `state` | `text` | no | generated `STORED` | `OPEN`, `PARTIALLY_APPLIED` or `CLEARED`, from the two amounts |
| `cleared_on` | `date` | yes | | when it was cleared |

Indexes: `ux_open_item__entry_line_id`,
`ix_open_item__party_id__state`,
`ix_open_item__due_date` partial `WHERE state <> 'CLEARED'`,
`ix_open_item__account_id`.

Constraints: `ck_open_item__applied_within_amount` (`applied_amount <= amount`);
`ck_open_item__cleared_has_date`.

`applied_amount` is maintained by the aggregate, in the same transaction that
writes an application — **not** by a trigger. `open_item` is the aggregate root
and `open_item_application` is part of it, so there is no second writer to
protect against ([§9](../rules/09-logic-in-the-database.md)).

`state` is a generated column: a pure function of `amount` and `applied_amount`
in the same row, which is what
[§9](../rules/09-logic-in-the-database.md) permits a generated column to be.

### `open_item_application` — one settlement against an item

**Immutable.** Pattern:
[14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — a payment, a credit note, an
offset and a write-off settle an item in exactly the same way, so they are one
table with a `kind`.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `open_item_id` | `uuid` | no | → `open_item.id` | the item |
| `kind` | `text` | no | `ck IN (PAYMENT, CREDIT_NOTE, OFFSET, WRITE_OFF, EXCHANGE_DIFFERENCE)` | what settled it |
| `source_id` | `uuid` | yes | typed link | the settling document |
| `payment_id` | `uuid` | yes | → `payment.id` | set when `kind = PAYMENT` |
| `entry_line_id` | `uuid` | no | → `journal_entry_line.id` | the line that recorded the settlement |
| `amount` | `numeric(19,4)` | no | `ck` > 0 | the amount applied |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | its currency |
| `applied_on` | `date` | no | | the settlement date |

Indexes: `ix_open_item_application__open_item_id`,
`ix_open_item_application__payment_id` partial `WHERE payment_id IS NOT NULL`.

Constraint: `ck_open_item_application__payment_kind`
(`kind <> 'PAYMENT' OR payment_id IS NOT NULL`).

## Group 5. Billing and tax

What the company claims and what it owes the state. An issued invoice is
immutable, and a tax rate is stored on the document that used it.

### `invoice` — an invoice

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — a sales invoice, a
purchase invoice, a credit note and a debit note are one table with a `kind`.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | the branch |
| `kind` | `text` | no | `ck IN (SALES, PURCHASE, CREDIT_NOTE, DEBIT_NOTE)` | which document this is |
| `party_id` | `uuid` | no | ⇢ `party.party` | the counterparty |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | the contract behind it |
| `number` | `text` | no | | allocated by `platform.document_number` |
| `issue_date` | `date` | no | | the date of issue |
| `due_date` | `date` | no | `ck` ≥ `issue_date` | when payment falls due |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | the currency |
| `exchange_rate` | `numeric(19,8)` | no | `ck` > 0 | the rate at issue |
| `rate_date` | `date` | no | | the rate's date |
| `net_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | before tax |
| `tax_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the tax |
| `gross_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the total |
| `state` | `text` | no | `ck IN (DRAFT, ISSUED, CANCELLED)` | the lifecycle |
| `issued_at` | `timestamptz` | yes | | when it was issued |
| `cancelled_at` | `timestamptz` | yes | | when it was cancelled |
| `cancellation_reason` | `text` | yes | `ck` length 1–255 | why |
| `journal_entry_id` | `uuid` | yes | → `journal_entry.id` | the entry it produced |
| `reverses_invoice_id` | `uuid` | yes | → `invoice.id` | the invoice a credit note corrects |

Indexes: `ux_invoice__company_id__kind__number`,
`ix_invoice__party_id__state`, `ix_invoice__due_date` partial
`WHERE state = 'ISSUED'`, `ix_invoice__contract_id`,
`ix_invoice__journal_entry_id`.

Constraints: `ck_invoice__gross_is_net_plus_tax`
(`gross_amount = net_amount + tax_amount`);
`ck_invoice__cancelled_has_reason`.

An invoice is mutable only in `DRAFT`. `IssuedInvoiceIsImmutableRule` refuses
every change after issue; a correction is a credit note with
`reverses_invoice_id`. The currency columns are single: one `currency_id` governs
all three amounts.

### `invoice_line` — a line of an invoice

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `invoice_id` | `uuid` | no | → `invoice.id` | the invoice |
| `line_number` | `integer` | no | `ck` > 0 | the position |
| `product_id` | `uuid` | yes | ⇢ `reference.product` | the item, when there is one |
| `description` | `text` | no | `ck` length 1–255 | what is being charged |
| `quantity` | `numeric(19,6)` | no | `ck` > 0 | how much |
| `unit_id` | `uuid` | no | ⇢ `reference.unit_of_measure` | the unit |
| `unit_price_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the price per unit |
| `discount_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | the discount |
| `net_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | quantity × price − discount |
| `tax_code_id` | `uuid` | no | → `tax_code.id` | the tax applied |
| `tax_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the tax on this line |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |

Indexes: `ux_invoice_line__invoice_id__line_number`,
`ix_invoice_line__product_id` partial `WHERE product_id IS NOT NULL`.

### `invoice_tax` — the tax summary of an invoice

One row per tax code on the invoice; what a tax return is built from.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `invoice_id` | `uuid` | no | → `invoice.id` | the invoice |
| `tax_code_id` | `uuid` | no | → `tax_code.id` | the tax code |
| `rate` | `numeric(9,6)` | no | `ck` ≥ 0 | the rate applied |
| `base_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | what the rate was applied to |
| `tax_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the resulting tax |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs both amounts |

Indexes: `ux_invoice_tax__invoice_id__tax_code_id`.

The rate is **stored on the row**, not looked up when the return is printed: the
rate that applied on the issue date is a fact of the document.

### `tax_code` — a tax

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | the code |
| `kind` | `text` | no | `ck IN (VAT, WITHHOLDING, EXCISE, SALES, OTHER)` | the kind of tax |
| `receivable_account_id` | `uuid` | yes | → `account.id` | input tax |
| `payable_account_id` | `uuid` | yes | → `account.id` | output tax |
| `is_active` | `boolean` | no | default `true` | in use |

Indexes: `ux_tax_code__company_id__code`.

### `tax_code_name` — tax names by locale

`tax_code_id` → `tax_code.id`, `locale`, `name`.
Index: `ux_tax_code_name__tax_code_id__locale`. The name is printed on invoices,
so it is translated.

### `tax_rate` — a rate for a period

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `tax_code_id` | `uuid` | no | → `tax_code.id` | the tax |
| `rate` | `numeric(9,6)` | no | `ck` 0–1 | the rate as a fraction |
| `valid_from` | `date` | no | | applies from |
| `valid_to` | `date` | yes | | applies until, exclusive |

Indexes: `ix_tax_rate__tax_code_id__valid_from`.

Constraint: `ex_tax_rate__no_overlap` — an exclusion constraint on
(`tax_code_id`, the date range). A change of rate is a new row, and last year's
invoices keep last year's rate without anyone remembering to.

## Group 6. Payments and banking

Money actually moving. Cash, a bank transfer, a card and a payment gateway are
one table with a method column; a bank statement is matched against it.

### `payment` — money moved

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — cash, a bank
transfer, a card, a payment gateway and an offset are one table with a `method`.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | the branch |
| `kind` | `text` | no | `ck IN (INCOMING, OUTGOING)` | which direction |
| `method` | `text` | no | `ck IN (CASH, BANK_TRANSFER, CARD, GATEWAY, OFFSET, OTHER)` | how |
| `party_id` | `uuid` | yes | ⇢ `party.party` | who paid or was paid |
| `bank_account_id` | `uuid` | yes | → `bank_account.id` | the account it moved through |
| `number` | `text` | no | | allocated by `platform.document_number` |
| `payment_date` | `date` | no | | the value date |
| `amount` | `numeric(19,4)` | no | `ck` > 0 | the amount |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | its currency |
| `exchange_rate` | `numeric(19,8)` | no | `ck` > 0 | the rate used |
| `rate_date` | `date` | no | | the rate's date |
| `applied_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | how much has been applied to open items |
| `state` | `text` | no | `ck IN (REGISTERED, APPLIED, RETURNED, CANCELLED)` | the lifecycle |
| `external_system` | `text` | yes | `ck` length 1–40 | the gateway, when `method = GATEWAY` |
| `external_id` | `text` | yes | | its identifier there |
| `journal_entry_id` | `uuid` | yes | → `journal_entry.id` | the entry it produced |
| `note` | `text` | yes | `ck` length 1–500 | |

Indexes: `ux_payment__company_id__number`,
`ux_payment__external_system__external_id` partial `WHERE external_id IS NOT NULL`,
`ix_payment__party_id__payment_date`, `ix_payment__bank_account_id__payment_date`,
`ix_payment__state` partial `WHERE state = 'REGISTERED'`.

Constraints: `ck_payment__applied_within_amount`;
`ck_payment__gateway_has_external` (`method <> 'GATEWAY' OR external_id IS NOT NULL`);
`ck_payment__cash_has_account`.

A gateway receipt is a payment with `method = GATEWAY` and a pair of external
columns — **not** a table of its own
([§3](../rules/03-identifiers.md)). A cash movement is a payment with
`method = CASH` against a `bank_account` whose `kind` is `CASH`.

### `bank` — a bank

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` length 8–11 | the BIC |
| `name` | `text` | no | | the name; a proper name, not translated |
| `country_id` | `uuid` | no | ⇢ `reference.country` | the country |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_bank__code`.

### `bank_account` — an account money moves through

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — a bank account, a
cash desk and a gateway wallet are the same thing to the ledger.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `bank_id` | `uuid` | yes | → `bank.id` | null for cash and gateways |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | the branch that operates it |
| `kind` | `text` | no | `ck IN (BANK, CASH, GATEWAY)` | what it is |
| `number` | `text` | no | `ck` length 1–34 | the account number or IBAN |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | its currency |
| `gl_account_id` | `uuid` | no | → `account.id` | the ledger account it maps to |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_bank_account__company_id__number__currency_id`,
`ix_bank_account__gl_account_id`.

Constraint: `ck_bank_account__bank_required` (`kind <> 'BANK' OR bank_id IS NOT NULL`).

### `bank_statement` — a statement received from a bank

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `bank_account_id` | `uuid` | no | → `bank_account.id` | the account |
| `statement_date` | `date` | no | | the date it covers |
| `opening_amount` | `numeric(19,4)` | no | | the opening balance |
| `closing_amount` | `numeric(19,4)` | no | | the closing balance |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs both |
| `state` | `text` | no | `ck IN (LOADED, RECONCILING, RECONCILED)` | the lifecycle |
| `external_id` | `text` | yes | | the bank's identifier for it |

Indexes: `ux_bank_statement__bank_account_id__statement_date`.

### `bank_statement_line` — a movement on a statement

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `bank_statement_id` | `uuid` | no | → `bank_statement.id` | the statement |
| `line_number` | `integer` | no | `ck` > 0 | the position |
| `value_date` | `date` | no | | the value date |
| `side` | `text` | no | `ck IN (DEBIT, CREDIT)` | in or out |
| `amount` | `numeric(19,4)` | no | `ck` > 0 | the amount |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | its currency |
| `counterparty_name` | `text` | yes | `ck` length 1–255 | as the bank spells it |
| `counterparty_account` | `text` | yes | `ck` length 1–34 | as the bank spells it |
| `purpose` | `text` | yes | `ck` length 1–500 | the payment purpose |
| `payment_id` | `uuid` | yes | → `payment.id` | the payment it was matched to |
| `state` | `text` | no | `ck IN (UNMATCHED, MATCHED, IGNORED)` | the reconciliation state |

Indexes: `ux_bank_statement_line__bank_statement_id__line_number`,
`ix_bank_statement_line__state` partial `WHERE state = 'UNMATCHED'`,
`ix_bank_statement_line__payment_id` partial `WHERE payment_id IS NOT NULL`.

`counterparty_name` is text from an external system and is deliberately **not** a
reference to `party.party`: it is what the bank sent, kept as sent. The link to a
counterparty is made through `payment_id`.

### `deposit` — a placed deposit

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `bank_account_id` | `uuid` | no | → `bank_account.id` | the account it was placed from |
| `gl_account_id` | `uuid` | no | → `account.id` | the ledger account it sits on |
| `number` | `text` | no | | the agreement number |
| `principal_amount` | `numeric(19,4)` | no | `ck` > 0 | the principal |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |
| `interest_rate` | `numeric(9,6)` | no | `ck` ≥ 0 | the annual rate |
| `minimum_balance_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | the threshold the terms require |
| `opened_on` | `date` | no | | placed on |
| `matures_on` | `date` | no | `ck` > `opened_on` | matures on |
| `closed_on` | `date` | yes | | actually closed on |
| `state` | `text` | no | `ck IN (ACTIVE, MATURED, CLOSED_EARLY)` | the lifecycle |

Indexes: `ux_deposit__company_id__number`, `ix_deposit__matures_on` partial
`WHERE state = 'ACTIVE'`.

## Group 7. Planning and reporting

What was planned, and how the result is laid out for a reader. Both are data: a
new budget kind is a row, and a new line of the balance sheet is a row.

### `budget` — a budget

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `fiscal_year_id` | `uuid` | no | → `fiscal_year.id` | the year |
| `kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `BUDGET_KIND` | which budget this is |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | the branch, when the budget is per branch |
| `revision` | `integer` | no | default 1, `ck` > 0 | the revision number |
| `state` | `text` | no | `ck IN (DRAFT, APPROVED, SUPERSEDED)` | the lifecycle |
| `approved_at` | `timestamptz` | yes | | when |
| `approved_by` | `uuid` | yes | ⇢ `platform.app_user` | by whom |

Indexes: `ux_budget__company_id__fiscal_year_id__kind_id__branch_id__revision`,
`ix_budget__state` partial `WHERE state = 'APPROVED'`.

> `kind_id` is a `reference_item`, not a `ck` list, because **no code branches on
> it**: a budget kind changes which figures are entered, not what the system
> does with them. A thirteenth budget kind is a row entered by a business user.
> `journal.kind` is the opposite case and is a `ck` list for that reason.

### `budget_line` — one figure of a budget

Pattern: [14.7](../rules/14-patterns.md#147-a-dimension-is-a-column-not-a-table) —
one fact table, dimensions as columns.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `budget_id` | `uuid` | no | → `budget.id` | the budget |
| `fiscal_period_id` | `uuid` | no | → `fiscal_period.id` | the period |
| `account_id` | `uuid` | yes | → `account.id` | the account, when the figure is by account |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | dimension |
| `org_unit_id` | `uuid` | yes | ⇢ `hr.org_unit` | dimension |
| `product_category_id` | `uuid` | yes | ⇢ `reference.product_category` | dimension |
| `expense_kind_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `EXPENSE_KIND` | dimension |
| `measure_id` | `uuid` | no | ⇢ `reference.reference_item` in list `BUDGET_MEASURE` | what is being budgeted: amount, headcount, units |
| `amount` | `numeric(19,4)` | yes | | the money figure |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | its currency |
| `quantity` | `numeric(19,6)` | yes | | the non-money figure |
| `unit_id` | `uuid` | yes | ⇢ `reference.unit_of_measure` | its unit |

Indexes: `ux_budget_line__budget_id__fiscal_period_id__account_id__branch_id__org_unit_id__product_category_id__expense_kind_id__measure_id`,
`ix_budget_line__fiscal_period_id`, `ix_budget_line__account_id`.

Constraints: `ck_budget_line__amount_has_currency` (both null or both set);
`ck_budget_line__quantity_has_unit`; `ck_budget_line__has_a_figure`
(at least one of `amount`, `quantity` is set).

### `statement_definition` — the layout of a financial statement

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | the layout code |
| `kind` | `text` | no | `ck IN (BALANCE_SHEET, INCOME_STATEMENT, CASH_FLOW, MANAGEMENT)` | which statement |
| `valid_from` | `date` | no | | applies from |
| `valid_to` | `date` | yes | | applies until, exclusive |

Indexes: `ux_statement_definition__company_id__code__valid_from`.

A change in the reporting standard is a new definition with a new validity
period. Last year's statements keep last year's layout, and reprinting them
produces the same numbers.

### `statement_line` — a line of a statement

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `statement_definition_id` | `uuid` | no | → `statement_definition.id` | the layout |
| `parent_id` | `uuid` | yes | → `statement_line.id` | the parent line |
| `line_number` | `integer` | no | `ck` > 0 | the position among its siblings |
| `code` | `text` | no | | the line code as the standard names it |
| `sign` | `text` | no | `ck IN (PLUS, MINUS)` | how it enters its parent |
| `aggregation` | `text` | no | `ck IN (ACCOUNTS, SUM_OF_CHILDREN, DIFFERENCE)` | where the figure comes from |
| `is_bold` | `boolean` | no | default `false` | a presentation hint |

Indexes: `ux_statement_line__statement_definition_id__code`,
`ix_statement_line__parent_id`.

### `statement_line_account` — which accounts a line sums

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `statement_line_id` | `uuid` | no | → `statement_line.id` | the line |
| `account_id` | `uuid` | no | → `account.id` | the account |
| `side` | `text` | yes | `ck IN (DEBIT, CREDIT)` | take only balances of this side |

Indexes: `ux_statement_line_account__statement_line_id__account_id`,
`ix_statement_line_account__account_id`.

A new account joining the balance sheet is a row here. Nobody edits a report.

### `statement_line_name` — statement line captions by locale

`statement_line_id` → `statement_line.id`, `locale`, `name`.
Index: `ux_statement_line_name__statement_line_id__locale`.

## Group 8. Chains and field collection

The trail from one document to the next, and the planning of debt collection in
the field.

### `document_link` — the document chain

**Immutable.** Pattern:
[14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind).

A financial fact rarely arrives as a single document. A contract produces an
invoice, the invoice produces an entry, a correction produces a credit note and a
second entry, a payment settles two invoices at once. This table is the chain
that ties them together, and it is what makes "show me everything this figure
came from" one query instead of five.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `from_kind` | `text` | no | `ck IN (INVOICE, PAYMENT, JOURNAL_ENTRY, OPEN_ITEM, CONTRACT, SERVICE_ORDER, STOCK_MOVEMENT, PAYROLL_RUN)` | the kind of the source document |
| `from_id` | `uuid` | no | typed link | its identifier |
| `to_kind` | `text` | no | the same `ck` list | the kind of the target document |
| `to_id` | `uuid` | no | typed link | its identifier |
| `kind` | `text` | no | `ck IN (SOURCE, REVERSAL, CORRECTION, SETTLEMENT, SPLIT, CONSOLIDATION)` | what the link means |
| `chain_id` | `uuid` | no | | the root of the chain, so a whole chain is one index lookup |

Indexes: `ux_document_link__from_kind__from_id__to_kind__to_id__kind`,
`ix_document_link__to_kind__to_id`, `ix_document_link__chain_id`.

Constraint: `ck_document_link__not_self`
(`from_kind <> to_kind OR from_id <> to_id`).

This is the one table in the domain that gives up database-level referential
integrity, and it pays for it the way
[14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind) requires:
`OrphanReferenceJob` walks every link nightly and reports a broken one as a
metric. The alternative — a nullable foreign key column per document kind — grows
a column every time the system learns a new document, which is the defect the
pattern exists to prevent.

`chain_id` is denormalized deliberately: without it, displaying a chain of six
documents is six recursive round trips, and the chain is displayed on every
financial document screen in the system.

### `collection_plan` — a debt-collection plan

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | the branch |
| `fiscal_period_id` | `uuid` | no | → `fiscal_period.id` | the period planned for |
| `employee_id` | `uuid` | no | ⇢ `hr.employee` | who owns the plan |
| `target_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | what is to be collected |
| `collected_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | what was collected |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs both |
| `state` | `text` | no | `ck IN (DRAFT, ACTIVE, CLOSED)` | the lifecycle |

Indexes: `ux_collection_plan__branch_id__fiscal_period_id__employee_id`.

### `collection_visit` — a visit made under a plan

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `collection_plan_id` | `uuid` | no | → `collection_plan.id` | the plan |
| `party_id` | `uuid` | no | ⇢ `party.party` | the debtor |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | the contract |
| `visited_at` | `timestamptz` | no | | when |
| `result_id` | `uuid` | no | ⇢ `reference.reference_item` in list `COLLECTION_RESULT` | the outcome |
| `collected_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what was collected on the visit |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | its currency |
| `payment_id` | `uuid` | yes | → `payment.id` | the payment it produced |
| `latitude` | `numeric(9,6)` | yes | `ck` −90…90 | where |
| `longitude` | `numeric(9,6)` | yes | `ck` −180…180 | where |
| `note` | `text` | yes | `ck` length 1–500 | |

Indexes: `ix_collection_visit__collection_plan_id`,
`ix_collection_visit__party_id__visited_at`.

## Tables that deliberately do not exist

Each of these was considered, failed the
[three questions](../rules/14-patterns.md#how-a-pattern-is-chosen), and is recorded
here so that it is not re-proposed:

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a cash-transaction table | `payment` with `method = CASH` | 1 — cash is counted and reported with every other payment |
| a payment-gateway receipt table | `payment` with `method = GATEWAY` and `external_system` / `external_id` | 1 |
| a credit-note table | `invoice` with `kind = CREDIT_NOTE` | 1 |
| a product-to-account rule table | `posting_rule` narrowed by `product_category_id` | 2 |
| an account-group table | the chart's own tree (`account.parent_id`, `path`) for structure, `statement_line` for reporting | 1 — it was a third name for two things that already exist |
| monthly total columns or a monthly totals table | `account_balance`, one row per period | 2 |
| a draft or parked entry table | the originating document in its own state | 3 — an entry exists only posted |
| a nullable foreign key per document kind on every document | `document_link`, one typed link table | 1 |
| a per-year or per-branch copy of any table above | a column, and a detached partition when the volume warrants it | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `account` | thousands | rarely |
| `account_name` | ×3 of the parent | with the parent |
| `account_dimension_rule` | thousands | rarely |
| `fiscal_year` | tens | almost never |
| `fiscal_period` | hundreds | state changes only |
| `journal` | tens | almost never |
| `journal_entry` | tens of millions, growing | **immutable** |
| `journal_entry_line` | hundreds of millions, growing | **immutable** |
| `account_balance` | millions | rebuilt |
| `posting_rule` | hundreds | rarely |
| `posting_rule_line` | thousands | rarely |
| `open_item` | tens of millions | applied against |
| `open_item_application` | tens of millions | **immutable** |
| `invoice` | millions, growing | until issued |
| `invoice_line` | tens of millions | with the invoice |
| `invoice_tax` | millions | with the invoice |
| `tax_code` | tens | almost never |
| `tax_code_name` | ×3 of the parent | with the parent |
| `tax_rate` | hundreds | inserts only |
| `payment` | tens of millions, growing | state changes |
| `bank` | tens | almost never |
| `bank_account` | hundreds | rarely |
| `bank_statement` | tens of thousands | state changes |
| `bank_statement_line` | millions | matching only |
| `deposit` | hundreds | state changes |
| `budget` | hundreds | until approved |
| `budget_line` | millions | with the budget |
| `statement_definition` | tens | almost never |
| `statement_line` | hundreds | rarely |
| `statement_line_account` | thousands | rarely |
| `statement_line_name` | ×3 of the parent | with the parent |
| `document_link` | tens of millions, growing | **immutable** |
| `collection_plan` | thousands | regularly |
| `collection_visit` | hundreds of thousands | inserts mostly |

**34 tables** in total. Five of them — `journal_entry`, `journal_entry_line`,
`open_item_application`, `document_link`, and the invoice family once issued —
are immutable, and that is what makes the domain auditable.

Tables above the partitioning threshold
([§10](../rules/10-large-tables.md)): `journal_entry` and
`journal_entry_line`, range-partitioned by `posting_date`; `payment` and
`open_item`, reviewed against measured volume before the first release.
