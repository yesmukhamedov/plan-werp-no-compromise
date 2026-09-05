---
id: PROD-03-SCHEMAS
title: Target schema registry
status: draft
---

# Target schema registry

**Fourteen schemas, 204 tables.** This is the complete list of what exists in the
database; each file behind it carries every table of that schema with every
column, its type, its constraints and its indexes.

The rules those columns obey: [../rules/](../rules/README.md).
How the rules are enforced: [../checks.md](../checks.md).
Why the schemas are grouped as they are: [../README.md](../README.md).

| Schema | Domain | Tables | State | Specification |
|---|---|---:|---|---|
| [`platform`](platform.md) | D0 Platform | 20 | drafted | — |
| [`audit`](audit.md) | D0 Platform | 2 | drafted | — |
| [`reference`](reference.md) | D1 Reference data | 20 | **designed** | [spec/D1-reference.md](../../spec/D1-reference.md) |
| [`party`](party.md) | D2 Counterparties | 16 | drafted | — |
| [`hr`](hr.md) | D3 Personnel | 23 | **designed** | [spec/D3-hr.md](../../spec/D3-hr.md) |
| [`contract`](contract.md) | D4 Contracts and sales | 17 | drafted | — |
| [`accounting`](accounting.md) | D5 Accounting and finance | 34 | **designed** | [spec/D5-accounting.md](../../spec/D5-accounting.md) |
| [`payroll`](payroll.md) | D6 Compensation calculation | 7 | drafted | — |
| [`inventory`](inventory.md) | D7 Warehouse and logistics | 15 | drafted | — |
| [`service`](service.md) | D8 Field service | 18 | drafted | — |
| [`crm`](crm.md) | D9 CRM and call centre | 14 | drafted | — |
| [`docflow`](docflow.md) | D10 Document workflow | 8 | drafted | — |
| [`legal`](legal.md) | D11 Legal | 4 | declared | — |
| [`tasks`](tasks.md) | D12 Tasks and communications | 6 | drafted | — |

Plus `migration`, a fifteenth schema that exists only for the duration of the
transition and is dropped with the system it maps
([transition/01-database-mapping.md](../../../transition/01-database-mapping.md)).

## What the states mean

| State | Means | What is still missing |
|---|---|---|
| `designed` | columns, types, constraints and indexes are settled; code can be written | nothing — the open questions are closed |
| `drafted` | the tables, their groups and their columns are the **designer's proposal** | the domain owner's confirmation, and the answers to the file's open questions |
| `declared` | the schema is known to be needed | whether the domain is in scope at all |

A `drafted` schema is a complete proposal, not a placeholder: it is detailed
enough to be argued with, which is the point. It becomes `designed` in the design
step of its domain's route
([transition/plan/03-phase-2-domains.md](../../../transition/plan/03-phase-2-domains.md)),
and **a domain's code is not written until its schema is `designed`**.

## The counts are outcomes, not estimates

Every number in the table above is the result of designing the tables in the file
behind it. Four of them have already moved, and each move was a decision with a
reason recorded in the file:

| Schema | Was | Is | Why |
|---|---:|---:|---|
| `accounting` | 20 | 34 | double entry, a fiscal calendar, account determination, subledgers, tax and statement layouts are separate concerns, and a `MONTH1 … MONTH12` totals table becomes one row per period |
| `hr` | 15 | 23 | job, position and assignment are three levels, not one; compensation, absence entitlement and certification are periods, not columns |
| `party` | 14 | 16 | `party_role` — one party plays several roles — and `email_link`, for symmetry with the address and phone links |
| `service` | 17 | 18 | `maintenance_program_position`, so a program can declare its positions without a column per position |
| `crm` | 15 | 14 | the call, demonstration and visit tables collapse into `activity`; `activity_participant` and `checklist_result` are added |

## Design order

Following the domain dependency graph
([02-domains.md](../../02-domains.md#dependency-graph)):

```
platform, audit  →  reference  →  party  →  hr, contract  →  accounting
                                                             ↓
                                    payroll, inventory, legal, crm, service
docflow, tasks — after platform
```

**A schema is not designed before the one it references.** That is why
`reference` was designed first, and why `party` is the next one to move from
drafted to designed: `hr`, `contract`, `accounting`, `service` and `crm` all
point at it.

## Reading a schema file

Every file has the same shape:

```
# <schema> — D<n> <Domain>

  a header block: domain, specification, table count, state, group count
  the markers used in every column list

## Group N. <name>        3–8 groups of tables that are read together
### `table_name`          purpose · structural pattern · every column with its type
                          indexes · constraints · the rules the database cannot express

## Tables that deliberately do not exist
                          what was considered and rejected, and which of the
                          three questions it failed

## Summary                row estimates, mutability, partitioning decisions
## Open questions         what the domain owner has to answer, and what each answer changes
```

The **"tables that deliberately do not exist"** section is the one to read before
proposing a new table. It exists because a rejected design that is not written
down is proposed again within the year.
