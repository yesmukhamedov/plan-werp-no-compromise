---
id: PROD-03-R14
title: "Rule 14. Structural patterns"
status: draft
---

## 14. Structural patterns

The rules above say what a table must not look like. This section says what it
looks like instead: **ten named forms** that cover the structural decisions a
domain specification has to make. Every table in the registry is one of them, and
a table that is none of them is a shape the domain specification argues for by
name.

The patterns exist for one purpose. A system lives twelve years because the
twelfth year's change is cheap, and every pattern here is judged by the same
question:

> **The eleventh question.** An eleventh product line appears. A seventh
> maintenance position appears. A thirteenth budget kind, a fifth approval step,
> a fourth language, a ninth reason for a movement. What does it cost?

There are three possible answers and only one of them is acceptable:

| The answer | Verdict |
|---|---|
| **a row** | correct |
| **a migration** | tolerable for a genuinely new *concept*; never for a new *instance* of a concept the schema already has |
| **a table** | a defect — it duplicates every query, every screen and every report that touches it, and the copy diverges within the year |

### 14.1 A variant is a row

Two things that are counted together, reported together and read by the same
screen are **one table with a `kind` column**, however different the business
process behind them.

```
service.installed_unit(id, product_id, kind, …)
```

not `installed_unit_a` beside `installed_unit_b`.

The difference in behaviour does not disappear — it moves out of the *shape* of
the table into *data*: a rule row keyed by the kind
([14.3](14-patterns.md#143-a-declaration-and-its-slots)), or a named domain rule covered by a
test. Merging the storage is never permission to merge the behaviour, and the
specification states which rules stay separate.

**The eleventh costs:** a row.

### 14.2 A repeating group is a child table

A family of columns distinguished by a number — a position, a month, a step, an
attempt — is a child table with an ordinal column and one row per member.

```
service.maintenance_slot(id, plan_id, ordinal, due_date, done_date, state)
accounting.account_balance(id, account_id, period_id, …, amount)
```

not `f1_date … f6_date`, not `month1 … month12`.

Two things become possible that a column family makes impossible: asking "which
position is overdue" without naming every position, and holding a product that
has three positions without three empty columns.

**The eleventh costs:** a row.

### 14.3 A declaration and its slots

The pattern that makes 14.1 and 14.2 work together, and the one that carries most
of the system's capacity to absorb change.

A **declaration** table says how a kind of thing is structured — how many
positions it has, at what intervals, in what order, under what rule. A **slot**
table holds one row per position, generated from the declaration.

| Declaration | Slots | What an eleventh costs |
|---|---|---|
| `service.maintenance_program` | `service.maintenance_plan` → `maintenance_slot` | a row: a product line serviced in seven positions |
| `docflow.route` → `route_step` | `docflow.document_approval` | a row: a fifth approver |
| `contract.payment_template` | `contract.payment_schedule_entry` | a row: a new instalment scheme |
| `accounting.posting_rule` → `posting_rule_line` | `accounting.journal_entry_line` | a row: a document kind that posts to new accounts |
| `crm.checklist` → `checklist_item` | `crm.checklist_result` | a row: a new question |
| `accounting.statement_definition` → `statement_line` | — | a row: a new line of the balance sheet |

The declaration is reference data with a validity period; the slots are
operational data. Neither the count of positions nor their meaning is ever a
column name, a class name, or a constant in code.

**The eleventh costs:** a row of reference data, entered by a business user
without a release.

### 14.4 A ledger and a derived balance

Where something accumulates — stock, money, hours, points — the **movements are
the truth** and the balance is derived.

```
inventory.stock_movement       append-only, one row per movement, a kind column
inventory.stock_balance        derived, rebuildable, reconciled by a job

accounting.journal_entry_line  append-only, immutable once posted
accounting.account_balance     derived, rebuildable, reconciled by a job
```

Three properties follow, and all three are required:

1. the movement table is **append-only** — a correction is a compensating row,
   never an edit;
2. the balance is **rebuildable from zero**, and the rebuild is a tested job;
3. a scheduled reconciliation compares the two, and **the divergence is an
   alert** — not a number someone notices in a report a quarter later.

**The eleventh costs:** a row; a new reason for a movement is a `kind` value.

### 14.5 A period, not a flag

Anything that is true for a stretch of time is stored as `valid_from` /
`valid_to` (exclusive) — never as a flag plus the hope that history is not asked
for.

```
hr.employment(employee_id, position_id, org_unit_id, valid_from, valid_to, …)
accounting.tax_rate(tax_code_id, rate, valid_from, valid_to)
contract.price_list(…, valid_from, valid_to)
```

Overlap is prevented by an exclusion constraint, not by application code
([5.3](05-types.md#53-time)). "Who held this position on that date", "what rate applied to
that invoice" and "what did the structure look like at the close of the year"
become ordinary queries instead of reconstructions.

An `is_active` boolean survives only where the entity has no history worth
keeping — a reference row, a switch. Where it stands in for a period, it is a
defect.

**The eleventh costs:** a row, and yesterday's answer stays answerable.

### 14.6 One identity, many roles

A person, an organization, an address, a phone number exists **once**. Its
participation in something is a link row carrying the role.

```
party.party                              one identity
party.address_link(party_id, address_id, role)
contract.contract_party(contract_id, party_id, role)
```

A document never copies a name, an address or a phone number into columns of its
own. A corrected number is corrected in one place, and every document that
references it is correct from that moment.

**The eleventh costs:** a row; a new role is a value.

### 14.7 A dimension is a column, not a table

A figure reported by unit, by branch, by period, by expense kind and by measure
is **one fact table** whose dimensions are columns. Each new cut of the same
figures is a value in a column — never a table of its own.

```
accounting.budget_line(budget_id, period_id, account_id,
                       branch_id, org_unit_id, expense_kind, measure, amount)
```

Which dimensions an account requires is itself data
(`accounting.account_dimension_rule`), so a dimension becoming mandatory is a
row, and a line missing it is rejected at write time rather than discovered when
the report does not add up.

**The eleventh costs:** a row. A twelfth *dimension* costs a migration — and that
is the tolerable case: a new dimension is a new concept.

### 14.8 A status, not a second table

A record's stage in its life is a column. Its past is a history table shared by
the entity, or an audit record. Its old age is a **detached partition**
([10](10-large-tables.md)).

There is no draft copy, no parked copy, no backup copy, no temporary copy and no
archive copy of any table in the registry. The names are forbidden
([2.2](02-naming.md#22-six-prohibitions)); the shape is forbidden here.

**The eleventh costs:** a value in a `ck` list.

### 14.9 A typed link, not a foreign key per kind

Where a thing may attach to entities of many kinds, the attachment is one table
carrying the target's kind and identifier — not one nullable foreign key column
per possible target.

```
platform.stored_file_link(file_id, entity_kind, entity_id, role)
accounting.document_link(from_kind, from_id, to_kind, to_id, kind)
```

This is the one place the schema knowingly gives up a database-level foreign key,
and it pays for that the same way a cross-domain reference does: the application
enforces the reference, and a nightly job reports orphans as a metric
([1](01-organization.md)).

The pattern is permitted **only** for genuinely open-ended attachment. It is not
a licence to replace modelling with a pair of `kind` and `id` columns.

**The eleventh costs:** a row.

### 14.10 Behaviour reads a property, never an identifier

No rule, no report and no branch of code is keyed to a particular primary key
value. What makes a row special is a **property of the row**:

```
reference.branch.kind = 'HEAD'
reference.warehouse.is_main = true
accounting.account.control_of = 'RECEIVABLE'
```

A schema that obeys this pattern can be populated with any data set — a test
fixture, a demonstration environment, a second company — and behave identically.
A schema that does not obey it can only ever run against one database.

**The eleventh costs:** setting a property on a row.

### How a pattern is chosen

Three questions, in order, before a table is added to the registry:

1. **Is there already a table for this?** If a table exists whose rows are
   counted, listed and reported together with these, this is a `kind` value on
   that table ([14.1](14-patterns.md#141-a-variant-is-a-row)).
2. **Is this an instance of something declared elsewhere?** If how many, in what
   order or by what rule is knowable from configuration, this is slots against a
   declaration ([14.3](14-patterns.md#143-a-declaration-and-its-slots)).
3. **Does it accumulate, or is it true for a period?** Then it is a ledger
   ([14.4](14-patterns.md#144-a-ledger-and-a-derived-balance)) or a period
   ([14.5](14-patterns.md#145-a-period-not-a-flag)), and the balance or the flag is derived
   from it.

Only when all three answers are no does a new table exist — and the domain
specification then states which pattern it is and what its eleventh instance
costs.

---
