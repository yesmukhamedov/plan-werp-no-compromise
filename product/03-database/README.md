---
id: PROD-03
title: Database
status: draft
---

# Database

PostgreSQL ([ADR-0002](../../docs/02-decisions/ADR-0002-database-postgresql.md)).

This is the entry point to the data model. The model is described at **four
levels**, and each level answers a different question. A reader who needs one of
them should not have to read the other three.

| Level | Where | Answers | Size |
|---|---|---|---|
| **0. The map** | this file | what the database consists of, which schema belongs to which part of the business | 1 page |
| **1. The rules** | [rules/](rules/README.md) | by what rules **any** object in the database is built — naming, types, keys, constraints, indexes, structural forms | 14 files |
| **2. The physical model** | [schemas/](schemas/README.md) | **every table, every column, every type**, grouped by schema and by table group | 14 files |
| **3. The domain specification** | [../spec/](../spec/README.md) | what the domain *means*: aggregates, invariants, classes, endpoints, permissions, pages, audit | one file per domain |

Plus [checks.md](checks.md) — the twenty checks that turn the rules from advice
into a failing build.

**Column-level detail lives at level 2 and nowhere else.** A domain specification
does not repeat a column list; it links to it. Two copies of a column list agree
on the day they are written and never again.

---

## The database in one page

One database. **A schema per domain**, plus `audit` and `migration`. A domain
writes and reads only its own schema, and the boundary is a database grant, not a
convention ([rule 1](rules/01-organization.md)).

Fourteen schemas, **204 tables**, grouped here by the part of the business they
serve:

### Foundation — what every domain stands on

| Schema | Domain | Tables | Holds |
|---|---|---:|---|
| [`platform`](schemas/platform.md) | D0 | 20 | users, roles, permissions, files, numbering, jobs, notifications, reports, settings |
| [`audit`](schemas/audit.md) | D0 | 2 | who did what to which record, once, for all thirteen domains |

`migration` is a fifteenth schema and a temporary one: it holds the mapping of
old identifiers to new ones for the duration of the transition and is dropped
with the system it maps.

### Shared records — the things every other domain refers to

| Schema | Domain | Tables | Holds |
|---|---|---:|---|
| [`reference`](schemas/reference.md) | D1 | 20 | companies, branches, warehouses, geography, currencies, the product catalogue, the standard enumerations |
| [`party`](schemas/party.md) | D2 | 16 | counterparties — people and organizations — with their addresses, phones and documents |

These two are the ones every other schema points at. A counterparty's name, a
branch code or a product article exists **once**, here, and is referenced by
identifier everywhere else.

### People

| Schema | Domain | Tables | Holds |
|---|---|---:|---|
| [`hr`](schemas/hr.md) | D3 | 23 | the organizational structure, the establishment, employments, assignments, absence, time, training |
| [`payroll`](schemas/payroll.md) | D6 | 7 | what was calculated from what HR agreed |

### Money

| Schema | Domain | Tables | Holds |
|---|---|---:|---|
| [`accounting`](schemas/accounting.md) | D5 | 34 | the chart of accounts, the calendar, double-entry postings, subledgers, invoices, payments, banking, budgets, statements |

The one schema where money becomes final. Every other domain proposes a financial
fact; this one posts it.

### Commerce

| Schema | Domain | Tables | Holds |
|---|---|---:|---|
| [`contract`](schemas/contract.md) | D4 | 17 | contracts, price lists, terms, payment schedules, promotions, sales plans |
| [`crm`](schemas/crm.md) | D9 | 14 | cases, calls, demonstrations, referrals, visits, targets, key indicators |

### Operations

| Schema | Domain | Tables | Holds |
|---|---|---:|---|
| [`inventory`](schemas/inventory.md) | D7 | 15 | stock items, movements, balances, transfers, orders, counts, write-offs |
| [`service`](schemas/service.md) | D8 | 18 | service requests and orders, installed equipment, maintenance programs and plans, spare parts, warranty, premiums |

### The workplace

| Schema | Domain | Tables | Holds |
|---|---|---:|---|
| [`docflow`](schemas/docflow.md) | D10 | 8 | internal documents of every kind, approval routes, approvals |
| [`tasks`](schemas/tasks.md) | D12 | 6 | internal tasks and messages |
| [`legal`](schemas/legal.md) | D11 | 4 | court cases, claims, recovery actions |

The department a schema serves is **not** a technical boundary — the technical
boundary is the domain map ([02-domains.md](../02-domains.md)) and it is what the
grants follow. The grouping above exists so that a person who works in one part
of the business can find their tables without reading the other thirteen schemas.

---

## How to read a schema file

Every file in [schemas/](schemas/README.md) has the same shape:

```
# <schema> — D<n> <Domain>

  a header block: domain, specification, table count, state, group count

## Group N. <name>       3–8 groups of tables that are read together
### `table_name`         purpose · structural pattern · every column with its type
                         indexes · constraints · rules the database cannot express

## Tables that deliberately do not exist
## Summary               row estimates, mutability, partitioning decisions
## Open questions        what the owner must answer, and what each answer changes
```

Each table lists **every column, its type, whether it is nullable, its
constraints and its meaning**. The six mandatory columns
([rule 4](rules/04-mandatory-columns.md)) are not repeated in every table — they
are on every mutable table by definition, and a table that omits them says so.

Two markers appear in every column list:

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** the same schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint; the application enforces it and a nightly job reports orphans as a metric ([rule 1](rules/01-organization.md)) |

Every table also names the **structural pattern** it follows
([rule 14](rules/14-patterns.md)). That is check
[DB-20](checks.md), and it is the line of defence against the schema growing a
table where it should have grown a row.

## Statuses

| Status | Means |
|---|---|
| `designed` | the columns, types, constraints and indexes are settled; code can be written against them |
| `drafted` | the tables, their groups and their columns are proposed **by the designer**; the domain owner has not yet confirmed them |
| `declared` | the schema is known to be needed and nothing more |

A `drafted` schema is a real proposal, not a placeholder: it is complete enough
to be argued with. It becomes `designed` when the domain owner has been through
it and its open questions are closed — which happens in the design step of the
domain's route
([transition/plan/03-phase-2-domains.md](../../transition/plan/03-phase-2-domains.md)).

The current state, schema by schema, is the registry:
[schemas/README.md](schemas/README.md).
