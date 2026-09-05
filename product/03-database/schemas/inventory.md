---
id: PROD-03-S-INVENTORY
title: "inventory schema — D7 Warehouse and logistics"
status: draft
---

# `inventory` — D7 Warehouse and logistics

| | |
|---|---|
| Domain | D7 Warehouse and logistics ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **15** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 4 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `inventory`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md), which are not repeated
below.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

**One movement table.** Everything that happens to stock — a receipt, an issue, a
transfer, a reservation, a loss, a return, a write-off, a count adjustment — is a
row of `stock_movement` with a `kind`. A balance is derived from those rows, can
be rebuilt from zero, and is reconciled by a scheduled job whose divergence is an
alert ([14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance)).

**The warehouse owns the quantity; the ledger owns the value.** A movement
produces a posting in [`accounting`](accounting.md) through a posting rule; it
does not compute one.

## Group 1. What is in stock

### `stock_item` — a tracked unit

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — a serial-tracked
machine and a bulk-tracked consumable are one table; the difference is whether
`serial_number` is set.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | what it is |
| `serial_number` | `text` | yes | `ck` length 1–60 | set for a serial-tracked product |
| `batch_number` | `text` | yes | `ck` length 1–60 | set for a batch-tracked product |
| `warehouse_id` | `uuid` | yes | ⇢ `reference.warehouse` | where it is now; null once it has left |
| `state` | `text` | no | `ck IN (IN_STOCK, RESERVED, ISSUED, INSTALLED, IN_REPAIR, WRITTEN_OFF, RETURNED, LOST)` | derived from its movements |
| `condition` | `text` | no | `ck IN (NEW, USED, REFURBISHED, DAMAGED)` | |
| `received_on` | `date` | yes | | |
| `expires_on` | `date` | yes | | for a product with a shelf life |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | the contract it was issued against |
| `installed_unit_id` | `uuid` | yes | ⇢ `service.installed_unit` | the equipment it became |
| `accountable_party_id` | `uuid` | yes | ⇢ `party.party` | who currently holds it |

Indexes: `ux_stock_item__company_id__product_id__serial_number` partial
`WHERE serial_number IS NOT NULL`,
`ix_stock_item__warehouse_id__product_id__state`,
`ix_stock_item__product_id__state`,
`ix_stock_item__contract_id` partial `WHERE contract_id IS NOT NULL`,
`ix_stock_item__batch_number` partial `WHERE batch_number IS NOT NULL`.

`state` and `warehouse_id` are **derived from the movements** and maintained by
the aggregate in the same transaction that writes one. They exist because "what
is in this warehouse right now" is asked on every warehouse screen and must not
cost a scan of the movement table.

### `stock_movement` — every movement, one table

**Immutable, append-only.** Pattern:
[14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance). **The truth
of the domain.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `kind` | `text` | no | `ck IN (RECEIPT, ISSUE, TRANSFER_OUT, TRANSFER_IN, RESERVATION, RESERVATION_RELEASE, RETURN, WRITE_OFF, LOSS, FOUND, COUNT_ADJUSTMENT, REPAIR_OUT, REPAIR_IN, SALE, RESALE)` | what happened |
| `product_id` | `uuid` | no | ⇢ `reference.product` | what moved |
| `stock_item_id` | `uuid` | yes | → `stock_item.id` | which unit, when it is tracked |
| `warehouse_id` | `uuid` | no | ⇢ `reference.warehouse` | which warehouse it affected |
| `quantity` | `numeric(19,6)` | no | `ck` > 0 | how much; the `kind` carries the sign |
| `direction` | `smallint` | no | `ck IN (-1, 1)` | derived from `kind`, stored so a sum needs no case |
| `unit_id` | `uuid` | no | ⇢ `reference.unit_of_measure` | |
| `occurred_at` | `timestamptz` | no | | when it happened |
| `posting_date` | `date` | no | | the date it counts on |
| `unit_cost_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | the valuation of one unit |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | its currency |
| `source_kind` | `text` | no | `ck IN (STOCK_DOCUMENT, PURCHASE_ORDER, STOCKTAKE, SERVICE_ORDER, CONTRACT, MANUAL)` | what caused it |
| `source_id` | `uuid` | yes | typed link ([14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind)) | which record |
| `counterpart_warehouse_id` | `uuid` | yes | ⇢ `reference.warehouse` | the other side of a transfer |
| `party_id` | `uuid` | yes | ⇢ `party.party` | the counterparty, when there is one |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | who moved it |
| `reverses_movement_id` | `uuid` | yes | → `stock_movement.id` | the movement this one compensates |
| `journal_entry_id` | `uuid` | yes | ⇢ `accounting.journal_entry` | the posting it produced |

Indexes: `ix_stock_movement__warehouse_id__product_id__posting_date`,
`ix_stock_movement__stock_item_id__occurred_at`,
`ix_stock_movement__product_id__posting_date`,
`ix_stock_movement__source_kind__source_id`,
`ix_stock_movement__kind__posting_date`,
`ux_stock_movement__reverses_movement_id` partial `WHERE reverses_movement_id IS NOT NULL`.

Range-partitioned by `posting_date` ([rule 10](../rules/10-large-tables.md)).

> A correction is a **compensating movement**, never an edit and never a delete.
> The stock a warehouse held on a past date is therefore a fact, not a
> reconstruction — and a stocktake variance can be explained instead of merely
> booked.

### `stock_balance` — a derived balance

**Rebuildable.** Deleted and rebuilt from `stock_movement` by a job whose
divergence from the movements is an alert.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `warehouse_id` | `uuid` | no | ⇢ `reference.warehouse` | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | |
| `condition` | `text` | no | `ck IN (NEW, USED, REFURBISHED, DAMAGED)` | balances are kept per condition |
| `on_hand_quantity` | `numeric(19,6)` | no | default 0 | physically present |
| `reserved_quantity` | `numeric(19,6)` | no | default 0, `ck` ≥ 0 | promised to something |
| `available_quantity` | `numeric(19,6)` | no | generated `STORED` | on hand − reserved |
| `unit_id` | `uuid` | no | ⇢ `reference.unit_of_measure` | |
| `value_amount` | `numeric(19,4)` | no | default 0 | the carrying value |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs the amounts in the row |
| `rebuilt_at` | `timestamptz` | no | | when this row was computed |

Indexes: `ux_stock_balance__warehouse_id__product_id__condition`,
`ix_stock_balance__product_id`,
`ix_stock_balance__available_quantity` partial `WHERE available_quantity <= 0`.

### `stock_reservation` — stock promised to something

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag) — a reservation
expires by itself.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `warehouse_id` | `uuid` | no | ⇢ `reference.warehouse` | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | |
| `stock_item_id` | `uuid` | yes | → `stock_item.id` | a specific unit, when one was chosen |
| `quantity` | `numeric(19,6)` | no | `ck` > 0 | |
| `unit_id` | `uuid` | no | ⇢ `reference.unit_of_measure` | |
| `holder_kind` | `text` | no | `ck IN (CONTRACT, SERVICE_ORDER, STOCK_DOCUMENT, PURCHASE_ORDER)` | what it is held for |
| `holder_id` | `uuid` | no | typed link | which one |
| `valid_from` | `timestamptz` | no | | held from |
| `valid_to` | `timestamptz` | yes | | held until, exclusive; null means until released |
| `state` | `text` | no | `ck IN (ACTIVE, CONSUMED, RELEASED, EXPIRED)` | |

Indexes: `ix_stock_reservation__warehouse_id__product_id__state`,
`ix_stock_reservation__holder_kind__holder_id`,
`ix_stock_reservation__valid_to` partial `WHERE state = 'ACTIVE'`.

> A reservation with no expiry is stock that is lost until somebody notices. The
> expiry job releases them, and the release is a movement like any other.

### `stock_valuation_layer` — what a unit cost

**Immutable.** One layer per receipt, consumed by issues in the order the
valuation method dictates. This is what makes cost of goods sold reproducible
rather than recomputed from today's prices.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `warehouse_id` | `uuid` | no | ⇢ `reference.warehouse` | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | |
| `stock_movement_id` | `uuid` | no | → `stock_movement.id` | the receipt that created the layer |
| `received_quantity` | `numeric(19,6)` | no | `ck` > 0 | |
| `consumed_quantity` | `numeric(19,6)` | no | default 0, `ck` ≥ 0 | |
| `unit_cost_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs the amounts in the row |
| `received_on` | `date` | no | | the order layers are consumed in |

Indexes: `ux_stock_valuation_layer__stock_movement_id`,
`ix_stock_valuation_layer__warehouse_id__product_id__received_on` partial
`WHERE consumed_quantity < received_quantity`.
Constraint: `ck_stock_valuation_layer__consumed_within_received`.

## Group 2. The documents that move it

### `stock_document` — a warehouse document of any kind

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row). **A transfer, a
write-off, an internal request, a return and a goods receipt are one table with a
`kind`** — they carry the same columns, are approved the same way, are listed on
the same screen and produce the same movements.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `kind` | `text` | no | `ck IN (TRANSFER, WRITE_OFF, REQUEST, RECEIPT, RETURN, ISSUE)` | which document |
| `number` | `text` | no | | from `platform.document_number` |
| `from_warehouse_id` | `uuid` | yes | ⇢ `reference.warehouse` | the source |
| `to_warehouse_id` | `uuid` | yes | ⇢ `reference.warehouse` | the destination |
| `party_id` | `uuid` | yes | ⇢ `party.party` | the counterparty, for a receipt or a return |
| `document_date` | `date` | no | | |
| `posting_date` | `date` | yes | | set when it is posted |
| `state` | `text` | no | `ck IN (DRAFT, SUBMITTED, APPROVED, IN_TRANSIT, RECEIVED, POSTED, CANCELLED)` | the lifecycle |
| `reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `STOCK_DOCUMENT_REASON` | |
| `approval_document_id` | `uuid` | yes | ⇢ `docflow.document` | the approval |
| `responsible_employee_id` | `uuid` | yes | ⇢ `hr.employee` | |
| `journal_entry_id` | `uuid` | yes | ⇢ `accounting.journal_entry` | the posting it produced |
| `note` | `text` | yes | `ck` length 1–500 | |

Indexes: `ux_stock_document__company_id__kind__number`,
`ix_stock_document__from_warehouse_id__document_date`,
`ix_stock_document__to_warehouse_id__document_date`,
`ix_stock_document__state` partial `WHERE state NOT IN ('POSTED','CANCELLED')`.
Constraint: `ck_stock_document__warehouses_by_kind` — a transfer has both
warehouses, a receipt has a destination, a write-off has a source.

> A transfer is `IN_TRANSIT` between despatch and receipt, and the stock is in
> neither warehouse while it is. That is a state, not a pair of tables, and it is
> the state most warehouse systems fail to represent.

### `stock_document_item` — a line of one

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `stock_document_id` | `uuid` | no | → `stock_document.id` | the document |
| `line_number` | `integer` | no | `ck` > 0 | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | |
| `stock_item_id` | `uuid` | yes | → `stock_item.id` | a specific unit |
| `requested_quantity` | `numeric(19,6)` | no | `ck` > 0 | asked for |
| `dispatched_quantity` | `numeric(19,6)` | no | default 0, `ck` ≥ 0 | sent |
| `received_quantity` | `numeric(19,6)` | no | default 0, `ck` ≥ 0 | arrived |
| `unit_id` | `uuid` | no | ⇢ `reference.unit_of_measure` | |
| `unit_cost_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |
| `note` | `text` | yes | `ck` length 1–255 | |

Indexes: `ux_stock_document_item__stock_document_id__line_number`,
`ix_stock_document_item__product_id`,
`ix_stock_document_item__stock_item_id` partial `WHERE stock_item_id IS NOT NULL`.

Three quantity columns rather than one, because a shortfall between what was sent
and what arrived is the fact the whole document exists to record.

### `stock_document_event` — its history

**Immutable.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `stock_document_id` | `uuid` | no | → `stock_document.id` | the document |
| `kind` | `text` | no | `ck IN (CREATED, SUBMITTED, APPROVED, REJECTED, DESPATCHED, RECEIVED, POSTED, CANCELLED)` | |
| `occurred_at` | `timestamptz` | no | | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | who |
| `previous_state` | `text` | yes | | |
| `new_state` | `text` | yes | | |
| `note` | `text` | yes | `ck` length 1–500 | |

Indexes: `ix_stock_document_event__stock_document_id__occurred_at`.

## Group 3. Buying

### `purchase_order` — an order to a supplier

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `supplier_party_id` | `uuid` | no | ⇢ `party.party` | |
| `warehouse_id` | `uuid` | no | ⇢ `reference.warehouse` | where it is delivered |
| `number` | `text` | no | | from `platform.document_number` |
| `ordered_on` | `date` | no | | |
| `expected_on` | `date` | yes | | |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the group |
| `net_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | |
| `tax_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | |
| `gross_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | |
| `state` | `text` | no | `ck IN (DRAFT, APPROVED, SENT, PARTIALLY_RECEIVED, RECEIVED, CANCELLED)` | |
| `approval_document_id` | `uuid` | yes | ⇢ `docflow.document` | |
| `invoice_id` | `uuid` | yes | ⇢ `accounting.invoice` | the purchase invoice |

Indexes: `ux_purchase_order__company_id__number`,
`ix_purchase_order__supplier_party_id__ordered_on`,
`ix_purchase_order__state` partial `WHERE state IN ('SENT','PARTIALLY_RECEIVED')`,
`ix_purchase_order__expected_on` partial `WHERE state <> 'RECEIVED'`.

### `purchase_order_item` — a line of it

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `purchase_order_id` | `uuid` | no | → `purchase_order.id` | |
| `line_number` | `integer` | no | `ck` > 0 | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | |
| `ordered_quantity` | `numeric(19,6)` | no | `ck` > 0 | |
| `received_quantity` | `numeric(19,6)` | no | default 0, `ck` ≥ 0 | |
| `unit_id` | `uuid` | no | ⇢ `reference.unit_of_measure` | |
| `unit_price_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | |
| `net_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | |
| `tax_code_id` | `uuid` | yes | ⇢ `accounting.tax_code` | |

Indexes: `ux_purchase_order_item__purchase_order_id__line_number`,
`ix_purchase_order_item__product_id`.
Constraint: `ck_purchase_order_item__received_within_ordered_tolerance`.

### `supplier_price` — what a supplier charges, for a period

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `supplier_party_id` | `uuid` | no | ⇢ `party.party` | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | |
| `unit_price_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | |
| `minimum_quantity` | `numeric(19,6)` | no | default 1, `ck` > 0 | |
| `lead_time_days` | `smallint` | yes | `ck` ≥ 0 | how long delivery takes |
| `valid_from` | `date` | no | | |
| `valid_to` | `date` | yes | | exclusive |

Indexes: `ix_supplier_price__product_id__valid_from`,
`ix_supplier_price__supplier_party_id`.
Constraint: `ex_supplier_price__no_overlap` on (`supplier_party_id`,
`product_id`, `minimum_quantity`, the date range).

## Group 4. Counting and control

### `stocktake` — a physical count

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `warehouse_id` | `uuid` | no | ⇢ `reference.warehouse` | |
| `number` | `text` | no | | from `platform.document_number` |
| `kind` | `text` | no | `ck IN (FULL, PARTIAL, CYCLE, SPOT)` | |
| `counted_on` | `date` | no | | |
| `state` | `text` | no | `ck IN (PLANNED, COUNTING, COUNTED, APPROVED, POSTED, CANCELLED)` | |
| `responsible_employee_id` | `uuid` | yes | ⇢ `hr.employee` | |
| `approval_document_id` | `uuid` | yes | ⇢ `docflow.document` | |
| `variance_value_amount` | `numeric(19,4)` | yes | | the total value of the discrepancy |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |

Indexes: `ux_stocktake__warehouse_id__number`,
`ix_stocktake__counted_on`,
`ix_stocktake__state` partial `WHERE state NOT IN ('POSTED','CANCELLED')`.

### `stocktake_item` — one counted position

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `stocktake_id` | `uuid` | no | → `stocktake.id` | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | |
| `stock_item_id` | `uuid` | yes | → `stock_item.id` | |
| `expected_quantity` | `numeric(19,6)` | no | | what the system said |
| `counted_quantity` | `numeric(19,6)` | yes | `ck` ≥ 0 | what was found |
| `variance_quantity` | `numeric(19,6)` | yes | generated `STORED` | counted − expected |
| `unit_id` | `uuid` | no | ⇢ `reference.unit_of_measure` | |
| `reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `VARIANCE_REASON` | the explanation |
| `counted_by_employee_id` | `uuid` | yes | ⇢ `hr.employee` | |
| `stock_movement_id` | `uuid` | yes | → `stock_movement.id` | the adjustment it produced |

Indexes: `ux_stocktake_item__stocktake_id__product_id__stock_item_id`,
`ix_stocktake_item__variance_quantity` partial `WHERE variance_quantity <> 0`.

`expected_quantity` is **stored on the row** at the moment of counting: the
balance moves afterwards, and a variance recomputed later is not the variance
that was found.

### `accountable_item` — an item held by a named person

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag) — a period of
custody, not a flag on the item.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `stock_item_id` | `uuid` | no | → `stock_item.id` | which unit |
| `party_id` | `uuid` | no | ⇢ `party.party` | who holds it |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | when the holder is an employee |
| `quantity` | `numeric(19,6)` | no | default 1, `ck` > 0 | |
| `handed_over_document_id` | `uuid` | yes | ⇢ `docflow.document` | the handover act |
| `valid_from` | `date` | no | | held from |
| `valid_to` | `date` | yes | | returned on, exclusive |

Indexes: `ix_accountable_item__party_id__valid_from`,
`ix_accountable_item__stock_item_id`,
`ix_accountable_item__valid_to` partial `WHERE valid_to IS NULL`.
Constraint: `ex_accountable_item__no_overlap` on (`stock_item_id`, the date
range) — one unit is in one person's custody at a time.

What an employee must return on their last day is a query over this table joined
to `hr.employment`, not a checklist someone maintains.

### `stock_limit` — the level a warehouse must hold

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `warehouse_id` | `uuid` | no | ⇢ `reference.warehouse` | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | |
| `minimum_quantity` | `numeric(19,6)` | no | `ck` ≥ 0 | reorder below this |
| `maximum_quantity` | `numeric(19,6)` | yes | `ck` ≥ 0 | do not exceed this |
| `reorder_quantity` | `numeric(19,6)` | yes | `ck` > 0 | how much to order |
| `unit_id` | `uuid` | no | ⇢ `reference.unit_of_measure` | |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_stock_limit__warehouse_id__product_id`.
Constraint: `ck_stock_limit__maximum_above_minimum`.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a table per movement reason — sold, received, lost, reserved, returned, resold, written off | `stock_movement` with a `kind` | 1 |
| a transfer table, a write-off table, a request table, each with its own items table | `stock_document` + `stock_document_item` with a `kind` | 1 |
| a table holding one number per product | a column on `stock_balance` | 1 |
| a current-quantity column edited in place | `stock_movement`, with `stock_balance` derived from it | 3 |
| an in-transit warehouse invented to hold moving stock | `stock_document.state = IN_TRANSIT` | 3 |
| a cost table recomputed from today's prices | `stock_valuation_layer`, written once per receipt | 3 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `stock_item` | tens of millions | state changes |
| `stock_movement` | hundreds of millions, growing | **immutable** |
| `stock_balance` | millions | rebuilt |
| `stock_reservation` | tens of millions | state changes |
| `stock_valuation_layer` | tens of millions | consumption only |
| `stock_document` | millions | state changes |
| `stock_document_item` | tens of millions | with the document |
| `stock_document_event` | tens of millions | **immutable** |
| `purchase_order` | hundreds of thousands | state changes |
| `purchase_order_item` | millions | with the order |
| `supplier_price` | hundreds of thousands | inserts, plus closing a period |
| `stocktake` | tens of thousands | state changes |
| `stocktake_item` | tens of millions | until posted |
| `accountable_item` | millions | inserts, plus closing a period |
| `stock_limit` | hundreds of thousands | rarely |

**15 tables.** `stock_movement` is the largest and is range-partitioned by
`posting_date`; `stock_document_item` and `stocktake_item` are reviewed against
measured volume before the first release
([rule 10](../rules/10-large-tables.md)).

## Open questions

| # | Question | Affects |
|---|---|---|
| D7-Q1 | Which valuation method — FIFO, weighted average, or standard cost? | `stock_valuation_layer`, and every cost figure in D5 |
| D7-Q2 | Are balances kept per condition, or is condition only a property of an item? | `ux_stock_balance__warehouse_id__product_id__condition` |
| D7-Q3 | Is stock tracked by location within a warehouse — a bin, a shelf? | a sixteenth table, and a column on every movement |
| D7-Q4 | Does a transfer post to the ledger on despatch, on receipt, or both? | `stock_movement.kind`, and the in-transit account in D5 |
| D7-Q5 | What tolerance is allowed between ordered and received? | `ck_purchase_order_item__received_within_ordered_tolerance` |
| D7-Q6 | Who may post a stocktake variance, and above what value does it need a second approval? | `stocktake.approval_document_id`, and a permission |
