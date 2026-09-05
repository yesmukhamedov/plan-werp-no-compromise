---
id: PROD-03-S-SERVICE
title: "service schema — D8 Field service"
status: draft
---

# `service` — D8 Field service

| | |
|---|---|
| Domain | D8 Field service ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **18** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 5 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `service`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md), which are not repeated
below.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

**This is the schema that most rewards getting the structure right**, because it
is the one that grows: every new product line the company sells arrives here as
equipment that has to be maintained on its own schedule.

The rule the whole schema is built around:

> **How a product line is serviced — how many positions it has, at what
> intervals, with which parts — is data, not a column list.** A product line
> serviced in six positions and a product line serviced in one use the same four
> tables. A seventh position on an existing line is a row. An eleventh product
> line is a handful of rows entered by a service manager, with no migration and
> no release.

That is [pattern 14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots),
and [group 3](#group-3-maintenance) is where it lives.

## Group 1. Equipment in the field

### `installed_unit` — equipment installed at a customer

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — **whatever the
product line.** One table for every kind of equipment the company services.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | which product it is |
| `serial_number` | `text` | yes | `ck` length 1–60 | |
| `stock_item_id` | `uuid` | yes | ⇢ `inventory.stock_item` | the unit it was issued as |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | the contract it was sold under |
| `owner_party_id` | `uuid` | no | ⇢ `party.party` | whose it is |
| `address_id` | `uuid` | no | ⇢ `party.address` | where it stands |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | the branch that services it |
| `installed_on` | `date` | yes | | |
| `installed_by_employee_id` | `uuid` | yes | ⇢ `hr.employee` | |
| `state` | `text` | no | `ck IN (PLANNED, INSTALLED, SUSPENDED, REMOVED, REPLACED, WRITTEN_OFF)` | |
| `removed_on` | `date` | yes | | |
| `replaced_by_installed_unit_id` | `uuid` | yes | → `installed_unit.id` | the unit that took its place |
| `latitude` | `numeric(9,6)` | yes | `ck` −90…90 | denormalized from the address for route planning |
| `longitude` | `numeric(9,6)` | yes | `ck` −180…180 | likewise |

Indexes: `ux_installed_unit__company_id__serial_number` partial
`WHERE serial_number IS NOT NULL`,
`ix_installed_unit__owner_party_id`,
`ix_installed_unit__contract_id`,
`ix_installed_unit__branch_id__state`,
`ix_installed_unit__address_id`,
`ix_installed_unit__latitude__longitude` partial `WHERE state = 'INSTALLED'`.

The coordinates are the one denormalization in this schema, and the reason is
measured: route planning reads tens of thousands of units at once, and joining
`party.address` for each is the difference between a screen and a report.

### `warranty` — warranty terms

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `installed_unit_id` | `uuid` | yes | → `installed_unit.id` | the unit it covers |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | the contract it covers |
| `kind` | `text` | no | `ck IN (MANUFACTURER, COMPANY, EXTENDED, SERVICE_PACKAGE)` | who stands behind it |
| `covers` | `text` | no | `ck IN (PARTS, LABOUR, PARTS_AND_LABOUR, FULL)` | what it pays for |
| `valid_from` | `date` | no | | |
| `valid_to` | `date` | no | `ck` > `valid_from` | exclusive |
| `voided_on` | `date` | yes | | when it was voided |
| `void_reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `WARRANTY_VOID_REASON` | why |

Indexes: `ix_warranty__installed_unit_id__valid_from`,
`ix_warranty__contract_id`,
`ix_warranty__valid_to` partial `WHERE voided_on IS NULL`.

Whether a visit is chargeable is a lookup here by date, not a flag someone sets
on the order.

## Group 2. Requests and work

A **request** is what the customer asked for. An **order** is the work the
company did. They are separate because one request can produce several visits,
and because a request that is refused still has to be counted.

### `service_request` — a customer's request for service

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `number` | `text` | no | | from `platform.document_number` |
| `kind` | `text` | no | `ck IN (INSTALLATION, MAINTENANCE, REPAIR, INSPECTION, REMOVAL, COMPLAINT, UPGRADE)` | what is wanted |
| `installed_unit_id` | `uuid` | yes | → `installed_unit.id` | which equipment |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | |
| `customer_party_id` | `uuid` | no | ⇢ `party.party` | who asked |
| `address_id` | `uuid` | no | ⇢ `party.address` | where |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | who serves it |
| `channel` | `text` | no | `ck IN (CALL, MOBILE_APP, WEB, TECHNICIAN, SCHEDULED, PARTNER)` | how it arrived |
| `maintenance_slot_id` | `uuid` | yes | → `maintenance_slot.id` | the due position it satisfies |
| `priority` | `text` | no | `ck IN (LOW, NORMAL, HIGH, URGENT)` | |
| `requested_at` | `timestamptz` | no | | |
| `due_at` | `timestamptz` | yes | | the service-level deadline |
| `state` | `text` | no | `ck IN (NEW, PLANNED, IN_PROGRESS, COMPLETED, REFUSED, CANCELLED)` | |
| `refusal_reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `SERVICE_REFUSAL_REASON` | |
| `description` | `text` | yes | `ck` length 1–2000 | what the customer said |

Indexes: `ux_service_request__company_id__number`,
`ix_service_request__installed_unit_id__requested_at`,
`ix_service_request__customer_party_id`,
`ix_service_request__branch_id__state`,
`ix_service_request__due_at` partial `WHERE state IN ('NEW','PLANNED')`,
`ix_service_request__maintenance_slot_id` partial `WHERE maintenance_slot_id IS NOT NULL`.

### `service_appointment` — a scheduled visit

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `service_request_id` | `uuid` | no | → `service_request.id` | |
| `technician_employee_id` | `uuid` | no | ⇢ `hr.employee` | who goes |
| `scheduled_from` | `timestamptz` | no | | the window start |
| `scheduled_to` | `timestamptz` | no | `ck` > `scheduled_from` | the window end |
| `route_position` | `smallint` | yes | `ck` > 0 | where it sits in the day's route |
| `state` | `text` | no | `ck IN (PLANNED, CONFIRMED, EN_ROUTE, ARRIVED, DONE, MISSED, CANCELLED)` | |
| `arrived_at` | `timestamptz` | yes | | |
| `departed_at` | `timestamptz` | yes | | |
| `arrival_latitude` | `numeric(9,6)` | yes | `ck` −90…90 | where the technician actually was |
| `arrival_longitude` | `numeric(9,6)` | yes | `ck` −180…180 | |
| `reschedule_reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `RESCHEDULE_REASON` | |

Indexes: `ix_service_appointment__technician_employee_id__scheduled_from`,
`ix_service_appointment__service_request_id`,
`ix_service_appointment__state__scheduled_from` partial `WHERE state IN ('PLANNED','CONFIRMED')`.
Constraint: `ex_service_appointment__no_overlap` — an exclusion constraint on
(`technician_employee_id`, the time range) among appointments not cancelled. One
technician cannot be in two places at once, and the database says so.

### `service_order` — the work carried out

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `service_request_id` | `uuid` | no | → `service_request.id` | |
| `service_appointment_id` | `uuid` | yes | → `service_appointment.id` | |
| `number` | `text` | no | | from `platform.document_number` |
| `installed_unit_id` | `uuid` | yes | → `installed_unit.id` | |
| `technician_employee_id` | `uuid` | no | ⇢ `hr.employee` | who did it |
| `branch_id` | `uuid` | no | ⇢ `reference.branch` | |
| `warehouse_id` | `uuid` | yes | ⇢ `reference.warehouse` | the van stock parts came from |
| `performed_on` | `date` | no | | |
| `started_at` | `timestamptz` | yes | | |
| `finished_at` | `timestamptz` | yes | | |
| `outcome` | `text` | no | `ck IN (DONE, PARTIALLY_DONE, NOT_DONE, POSTPONED, REFUSED_BY_CUSTOMER)` | |
| `is_chargeable` | `boolean` | no | default `false` | resolved from `warranty` and the package |
| `warranty_id` | `uuid` | yes | → `warranty.id` | the cover that applied |
| `service_package_id` | `uuid` | yes | → `service_package.id` | the package it was served under |
| `net_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | what it is charged at |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |
| `invoice_id` | `uuid` | yes | ⇢ `accounting.invoice` | |
| `customer_signature_file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the signed act |
| `customer_rating` | `smallint` | yes | `ck` 1–5 | |
| `state` | `text` | no | `ck IN (DRAFT, SUBMITTED, APPROVED, INVOICED, CANCELLED)` | |

Indexes: `ux_service_order__number`,
`ix_service_order__service_request_id`,
`ix_service_order__technician_employee_id__performed_on`,
`ix_service_order__installed_unit_id__performed_on`,
`ix_service_order__branch_id__performed_on`,
`ix_service_order__state` partial `WHERE state IN ('DRAFT','SUBMITTED')`.

### `service_order_line` — the operations and parts of it

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — an operation
performed and a part fitted are one table with a `kind`; both are lines of the
same act and both are priced the same way.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `service_order_id` | `uuid` | no | → `service_order.id` | |
| `line_number` | `integer` | no | `ck` > 0 | |
| `kind` | `text` | no | `ck IN (OPERATION, PART, TRAVEL, DIAGNOSTIC)` | what the line is |
| `operation_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `SERVICE_OPERATION` | which operation |
| `product_id` | `uuid` | yes | ⇢ `reference.product` | which part |
| `stock_item_id` | `uuid` | yes | ⇢ `inventory.stock_item` | which unit of it |
| `maintenance_slot_id` | `uuid` | yes | → `maintenance_slot.id` | **the maintenance position this line closes** |
| `quantity` | `numeric(19,6)` | no | default 1, `ck` > 0 | |
| `unit_id` | `uuid` | yes | ⇢ `reference.unit_of_measure` | |
| `duration_minutes` | `integer` | yes | `ck` > 0 | for an operation |
| `unit_price_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | |
| `net_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | |
| `is_covered_by_warranty` | `boolean` | no | default `false` | |
| `stock_movement_id` | `uuid` | yes | ⇢ `inventory.stock_movement` | the issue of the part |

Indexes: `ux_service_order_line__service_order_id__line_number`,
`ix_service_order_line__product_id`,
`ix_service_order_line__maintenance_slot_id` partial `WHERE maintenance_slot_id IS NOT NULL`,
`ix_service_order_line__operation_id`.
Constraint: `ck_service_order_line__kind_has_its_reference` — an `OPERATION` has
an operation, a `PART` has a product.

`maintenance_slot_id` on the line is the join that closes the loop: a due
position becomes a request, the request becomes an order, and a **line** of that
order records which position was actually served. A visit that replaces four of
six cartridges closes four slots and leaves two open, which no set of columns on
a single row can express.

### `service_event` — the history of a request and its orders

**Immutable.** Pattern:
[14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `service_request_id` | `uuid` | no | → `service_request.id` | |
| `service_order_id` | `uuid` | yes | → `service_order.id` | |
| `kind` | `text` | no | `ck IN (CREATED, PLANNED, RESCHEDULED, ASSIGNED, EN_ROUTE, ARRIVED, COMPLETED, REFUSED, CANCELLED, ESCALATED, COMMENTED)` | |
| `occurred_at` | `timestamptz` | no | | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | who |
| `previous_state` | `text` | yes | | |
| `new_state` | `text` | yes | | |
| `note` | `text` | yes | `ck` length 1–2000 | |

Indexes: `ix_service_event__service_request_id__occurred_at`,
`ix_service_event__service_order_id`,
`ix_service_event__kind__occurred_at`.

## Group 3. Maintenance

**The four tables that make the domain extensible.** A declaration says how a
product line is serviced; a plan is one unit's schedule; a slot is one position
in it.

```
maintenance_program            how this product line is serviced
  └ maintenance_program_position   position 1, 2, 3 … n — each with its own interval and part
maintenance_plan               this unit's schedule, generated from the program
  └ maintenance_slot               position 1, 2, 3 … n — each with its own due date and state
```

Nothing in this group names a number of positions. Six positions, one position or
eleven are the same four tables and the same code.

### `maintenance_program` — how a product line is serviced

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots) and
[14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `name` | `text` | no | `ck` length 1–255 | |
| `product_id` | `uuid` | yes | ⇢ `reference.product` | the product it applies to |
| `product_category_id` | `uuid` | yes | ⇢ `reference.product_category` | or the whole category |
| `contract_type_id` | `uuid` | yes | ⇢ `contract.contract_type` | narrows it further |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | and further |
| `cycle_months` | `smallint` | yes | `ck` > 0 | after the last position, the cycle repeats |
| `starts_from` | `text` | no | `ck IN (INSTALLATION, PURCHASE, CONTRACT_START, PREVIOUS_SERVICE)` | what the first due date is counted from |
| `priority` | `integer` | no | default 0 | the more specific program wins |
| `valid_from` | `date` | no | | |
| `valid_to` | `date` | yes | | exclusive |

Indexes: `ux_maintenance_program__company_id__code__valid_from`,
`ix_maintenance_program__product_id__valid_from`,
`ix_maintenance_program__product_category_id`.
Constraint: `ex_maintenance_program__no_ambiguity` — an exclusion constraint on
(`company_id`, `product_id`, `product_category_id`, `contract_type_id`,
`branch_id`, `priority`, the date range), so which program applies to a unit is a
fact rather than a race.

### `maintenance_program_position` — one position of the program

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table).
**This table is the answer to "what if there is a seventh position".**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `maintenance_program_id` | `uuid` | no | → `maintenance_program.id` | the program |
| `ordinal` | `smallint` | no | `ck` > 0 | which position, 1 … n |
| `name` | `text` | no | `ck` length 1–255 | what it is called on the technician's screen |
| `interval_months` | `smallint` | yes | `ck` > 0 | months from the start point |
| `interval_from_previous_months` | `smallint` | yes | `ck` > 0 | or months from the previous position |
| `product_id` | `uuid` | yes | ⇢ `reference.product` | the part this position consumes |
| `operation_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `SERVICE_OPERATION` | the operation performed |
| `is_chargeable` | `boolean` | no | default `true` | whether the customer pays for it |
| `tolerance_days` | `smallint` | no | default 0, `ck` ≥ 0 | how late it may be before it counts as overdue |
| `is_mandatory` | `boolean` | no | default `true` | skipping it voids the warranty |

Indexes: `ux_maintenance_program_position__maintenance_program_id__ordinal`,
`ix_maintenance_program_position__product_id`.
Constraint: `ck_maintenance_program_position__one_interval` — exactly one of the
two interval columns is set.

> Add a row with `ordinal = 7`, an interval and a part. Every plan generated from
> that day carries a seventh slot; every existing plan is extended by the
> regeneration job; the technician's screen shows seven positions because it
> renders rows. **No column, no migration, no release, no code that knows the
> number six.**

### `maintenance_plan` — one unit's schedule

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `installed_unit_id` | `uuid` | no | → `installed_unit.id` | whose schedule |
| `maintenance_program_id` | `uuid` | no | → `maintenance_program.id` | which program generated it |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | |
| `starts_on` | `date` | no | | the start point the dates are counted from |
| `cycle_number` | `smallint` | no | default 1, `ck` > 0 | which repetition of the program |
| `state` | `text` | no | `ck IN (ACTIVE, SUSPENDED, COMPLETED, CANCELLED)` | |
| `regenerated_at` | `timestamptz` | yes | | when the slots were last recomputed |

Indexes: `ux_maintenance_plan__installed_unit_id__cycle_number`,
`ix_maintenance_plan__maintenance_program_id`,
`ix_maintenance_plan__state` partial `WHERE state = 'ACTIVE'`.

### `maintenance_slot` — one position of one plan

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table).
**The table that replaces a family of numbered columns.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `maintenance_plan_id` | `uuid` | no | → `maintenance_plan.id` | the plan |
| `maintenance_program_position_id` | `uuid` | no | → `maintenance_program_position.id` | which declared position |
| `ordinal` | `smallint` | no | `ck` > 0 | its number, copied for ordering |
| `due_date` | `date` | no | | when it falls due |
| `overdue_after` | `date` | no | | due date + tolerance; generated `STORED` |
| `done_date` | `date` | yes | | when it was actually served |
| `state` | `text` | no | `ck IN (PLANNED, DUE, OVERDUE, DONE, SKIPPED, CANCELLED)` | |
| `service_order_line_id` | `uuid` | yes | → `service_order_line.id` | the line that closed it |
| `product_id` | `uuid` | yes | ⇢ `reference.product` | the part actually used, if it differed |
| `skip_reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `MAINTENANCE_SKIP_REASON` | |

Indexes: `ux_maintenance_slot__maintenance_plan_id__ordinal`,
`ix_maintenance_slot__due_date__state` partial `WHERE state IN ('PLANNED','DUE','OVERDUE')`,
`ix_maintenance_slot__state`,
`ix_maintenance_slot__service_order_line_id` partial `WHERE service_order_line_id IS NOT NULL`.

> **"Which position is overdue" is one predicate on one column.** It does not
> name a position, and it does not change when the number of positions does.
> That single query — over every unit, every product line and every branch at
> once — is what the whole group exists to make possible.

## Group 4. What is sold as service

### `service_package` — a package of services

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `name` | `text` | no | `ck` length 1–255 | |
| `product_category_id` | `uuid` | yes | ⇢ `reference.product_category` | what it applies to |
| `price_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | |
| `duration_months` | `smallint` | no | `ck` > 0 | how long it runs |
| `visit_allowance` | `smallint` | yes | `ck` > 0 | how many visits it includes |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_service_package__company_id__code`.

### `package_item` — its contents

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `service_package_id` | `uuid` | no | → `service_package.id` | |
| `line_number` | `integer` | no | `ck` > 0 | |
| `operation_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `SERVICE_OPERATION` | an included operation |
| `product_id` | `uuid` | yes | ⇢ `reference.product` | an included part |
| `included_quantity` | `numeric(19,6)` | no | default 1, `ck` > 0 | how many are included |
| `discount_percentage` | `numeric(9,6)` | no | default 0, `ck` 0–1 | or how much off, if not free |

Indexes: `ux_package_item__service_package_id__line_number`.

### `spare_part` — which parts fit which product

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `product_id` | `uuid` | no | ⇢ `reference.product` | the equipment |
| `part_product_id` | `uuid` | no | ⇢ `reference.product` | the part |
| `quantity_per_service` | `numeric(19,6)` | no | default 1, `ck` > 0 | how many are used at a time |
| `is_interchangeable` | `boolean` | no | default `false` | an alternative to another part |
| `replaces_part_product_id` | `uuid` | yes | ⇢ `reference.product` | the part it supersedes |
| `valid_from` | `date` | no | | fits from |
| `valid_to` | `date` | yes | | fits until, exclusive |

Indexes: `ux_spare_part__product_id__part_product_id__valid_from`,
`ix_spare_part__part_product_id`.

### `upgrade_offer` — an offer to replace or upgrade equipment

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `installed_unit_id` | `uuid` | no | → `installed_unit.id` | what is being replaced |
| `customer_party_id` | `uuid` | no | ⇢ `party.party` | |
| `offered_on` | `date` | no | | |
| `expires_on` | `date` | yes | | |
| `discount_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | the trade-in allowance |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | |
| `state` | `text` | no | `ck IN (OFFERED, ACCEPTED, DECLINED, EXPIRED)` | |
| `resulting_contract_id` | `uuid` | yes | ⇢ `contract.contract` | the contract it produced |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | who offered it |

Indexes: `ix_upgrade_offer__installed_unit_id`,
`ix_upgrade_offer__customer_party_id`,
`ix_upgrade_offer__state__expires_on` partial `WHERE state = 'OFFERED'`.

### `upgrade_offer_item` — what is being offered

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `upgrade_offer_id` | `uuid` | no | → `upgrade_offer.id` | |
| `line_number` | `integer` | no | `ck` > 0 | |
| `product_id` | `uuid` | no | ⇢ `reference.product` | |
| `quantity` | `numeric(19,6)` | no | default 1, `ck` > 0 | |
| `unit_price_amount` | `numeric(19,4)` | no | `ck` ≥ 0 | |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | |

Indexes: `ux_upgrade_offer_item__upgrade_offer_id__line_number`.

## Group 5. Paying the technician

### `premium_rule` — how a premium is computed

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots) and
[14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | narrows the rule |
| `operation_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `SERVICE_OPERATION` | narrows it |
| `product_category_id` | `uuid` | yes | ⇢ `reference.product_category` | narrows it |
| `job_id` | `uuid` | yes | ⇢ `hr.job` | narrows it |
| `basis` | `text` | no | `ck IN (PER_ORDER, PER_OPERATION, PERCENTAGE_OF_AMOUNT, PER_SLOT_CLOSED)` | how it is computed |
| `amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | |
| `percentage` | `numeric(9,6)` | yes | `ck` 0–1 | |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |
| `priority` | `integer` | no | default 0 | |
| `valid_from` | `date` | no | | |
| `valid_to` | `date` | yes | | exclusive |

Indexes: `ux_premium_rule__company_id__code__valid_from`,
`ix_premium_rule__valid_from__valid_to`.
Constraint: `ex_premium_rule__no_ambiguity` on (`company_id`, `branch_id`,
`operation_id`, `product_category_id`, `job_id`, `priority`, the date range);
`ck_premium_rule__basis_has_its_value`.

### `technician_premium` — the premium earned

**Immutable.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `service_order_id` | `uuid` | no | → `service_order.id` | the work |
| `employee_id` | `uuid` | no | ⇢ `hr.employee` | who earned it |
| `premium_rule_id` | `uuid` | no | → `premium_rule.id` | the rule that produced it |
| `basis_quantity` | `numeric(19,6)` | yes | | how many orders, operations or slots |
| `basis_amount` | `numeric(19,4)` | yes | | the amount it was a percentage of |
| `amount` | `numeric(19,4)` | no | `ck` ≥ 0 | what was earned |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | governs every amount in the row |
| `fiscal_period_id` | `uuid` | no | ⇢ `accounting.fiscal_period` | the period it belongs to |
| `payroll_input_id` | `uuid` | yes | ⇢ `payroll.payroll_input` | how it reached the payslip |

Indexes: `ux_technician_premium__service_order_id__employee_id__premium_rule_id`,
`ix_technician_premium__employee_id__fiscal_period_id`,
`ix_technician_premium__payroll_input_id` partial `WHERE payroll_input_id IS NOT NULL`.

The rule that produced it is stored on the row, for the same reason a payslip
line stores its rate: a technician disputing a premium six months later gets an
answer, not a recalculation against rules that have since changed.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a table per product line's maintenance | `maintenance_program` + `maintenance_program_position`, one row per line | 1 |
| a column family per maintenance position — its date, its next date, its previous date, its part | `maintenance_slot`, one row per position | 2 |
| a plan table per product line | `maintenance_plan` + `maintenance_slot` | 1 |
| a separate parts table beside an operations table on an order | `service_order_line` with a `kind` | 1 |
| an installed-equipment table per product line | `installed_unit` | 1 |
| a warranty flag on the order | `warranty`, looked up by date | 3 |
| a table of premium kinds | `premium_rule` with a `basis` | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `installed_unit` | millions | state changes |
| `warranty` | millions | inserts |
| `service_request` | tens of millions, growing | state changes |
| `service_appointment` | tens of millions, growing | state changes |
| `service_order` | tens of millions, growing | until approved |
| `service_order_line` | hundreds of millions, growing | with the order |
| `service_event` | hundreds of millions, growing | **immutable** |
| `maintenance_program` | hundreds | rarely |
| `maintenance_program_position` | thousands | rarely |
| `maintenance_plan` | millions | state changes |
| `maintenance_slot` | hundreds of millions, growing | state changes |
| `service_package` | hundreds | rarely |
| `package_item` | thousands | rarely |
| `spare_part` | tens of thousands | rarely |
| `upgrade_offer` | millions | state changes |
| `upgrade_offer_item` | millions | with the offer |
| `premium_rule` | hundreds | inserts, plus closing a period |
| `technician_premium` | tens of millions, growing | **immutable** |

**18 tables** — one more than the registry first named, because
`maintenance_program_position` is what lets a program declare its positions
without a column per position. Without it the program table would have to name
them, and the schema would carry the very shape it exists to remove.

`maintenance_slot`, `service_event`, `service_order_line` and `service_request`
are the four above the partitioning threshold
([rule 10](../rules/10-large-tables.md)); the first is partitioned by `due_date`
and the rest by their own time key.

## Open questions

| # | Question | Affects |
|---|---|---|
| D8-Q1 | How many maintenance programs exist today, and do their intervals differ by branch or by contract type? | `maintenance_program` narrowing columns and the seed |
| D8-Q2 | When a program changes, are existing plans regenerated or left as they were? | `maintenance_plan.regenerated_at`, and what a customer was promised |
| D8-Q3 | Does a cycle repeat indefinitely, and does the cycle restart reset the intervals? | `maintenance_plan.cycle_number`, `maintenance_program.cycle_months` |
| D8-Q4 | Can one visit close positions on two different units at one address? | `service_order` to `installed_unit` cardinality |
| D8-Q5 | Is D8 a separate domain from D9, or one? | [02-domains.md](../../02-domains.md) |
| D8-Q6 | Is the technician premium computed here and passed to D6, or computed by D6? | `technician_premium`, `payroll.payroll_input.source` |
| D8-Q7 | What voids a warranty, and is a skipped mandatory position one of the causes? | `warranty.void_reason_id`, `maintenance_program_position.is_mandatory` |
