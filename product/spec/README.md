---
id: PROD-SPEC
title: Full domain specifications
status: draft
---

# Full domain specifications

One file per domain. Each contains all four slices at once, taken to the level of
"code can be written":

1. **Tables** — columns, types, constraints, indexes;
2. **Classes** — the module's composition by layer, the public interface, events;
3. **Endpoints** — path, method, parameters, permission, error codes;
4. **Pages** — route, type, components, scenarios.

The slices are gathered in one file deliberately: while designing a table you
need to see the endpoint that serves it and the page that calls that endpoint.
Spread across four documents, they drift apart.

## State

| Domain | Specification | Status |
|---|---|---|
| D0 Platform | — | schema **drafted**: every column in [03-database/schemas/platform.md](../03-database/schemas/platform.md) |
| D1 Reference data | [D1-reference.md](D1-reference.md) | **designed** |
| D2 Counterparties | — | schema **drafted**: every column in [03-database/schemas/party.md](../03-database/schemas/party.md) |
| D3 Personnel | [D3-hr.md](D3-hr.md) | **designed** |
| D4 Contracts and sales | — | schema **drafted**: every column in [03-database/schemas/contract.md](../03-database/schemas/contract.md) |
| D5 Accounting and finance | [D5-accounting.md](D5-accounting.md) | **designed** |
| D6 Compensation calculation | — | schema **drafted**: every column in [03-database/schemas/payroll.md](../03-database/schemas/payroll.md) |
| D7 Warehouse and logistics | — | schema **drafted**: every column in [03-database/schemas/inventory.md](../03-database/schemas/inventory.md) |
| D8 Field service | — | schema **drafted**: every column in [03-database/schemas/service.md](../03-database/schemas/service.md) |
| D9 CRM and call centre | — | schema **drafted**: every column in [03-database/schemas/crm.md](../03-database/schemas/crm.md) |
| D10 Document workflow | — | schema **drafted**: every column in [03-database/schemas/docflow.md](../03-database/schemas/docflow.md) |
| D11 Legal | — | schema `declared`: [03-database/schemas/legal.md](../03-database/schemas/legal.md) |
| D12 Tasks and communications | — | schema **drafted**: every column in [03-database/schemas/tasks.md](../03-database/schemas/tasks.md) |

D3 and D5 were written next, out of dependency order, because they are the two
domains whose data model the business judges the system by: an accounting
department and a personnel department both have a well-established body of
practice, and a schema that departs from it is wrong in a way no test detects.
Both are written to the canonical model rather than to the shape of any existing
implementation, and both are annotated with the structural pattern each table
follows ([rule 14](../03-database/rules/14-patterns.md)).

## D1 — the reference sample

[D1-reference.md](D1-reference.md) is written in full and sets the **mandatory
depth** for the other twelve. A domain specification less detailed than D1 does
not count as finished.

D1 was chosen first not because it is simple but because all the other domains
depend on it ([02-domains.md](../02-domains.md#dependency-graph)) and because it
is implemented as the reference domain of Phase 1
([transition/plan/02-phase-1-platform.md](../../transition/plan/02-phase-1-platform.md#7-the-reference-domain)).

## When a specification is written

| Moment | What | Who |
|---|---|---|
| Phase 0 | tables and endpoints — based on the inventory | the designer + the domain owner |
| Phase 1 | all of D1 — as the reference sample | the platform team |
| Phase 2, the "Design" step | the other domains, before any code is written | the domain team |

A domain's code is not written until its specification is moved to the `designed`
status. That is the condition of step 2 of the domain route
([transition/plan/03-phase-2-domains.md](../../transition/plan/03-phase-2-domains.md#what-happens-to-each-domain)).

## Mandatory sections

A domain specification contains **all** of the sections listed. A missing section
means unfinished design, not "there is nothing to write here":

```markdown
# D<N>. <Domain>

## Purpose and boundaries      what is in scope, what is NOT, the owner
## Model                       entities, aggregates, invariants
## Tables                      a link to 03-database/schemas/<schema>.md — not a copy
## Reference data              what is loaded by the schema migration
## Classes                     by layer; the public interface; events
## Endpoints                   path, method, parameters, permission, errors
## Permissions                 the list of the domain's permissions
## Pages                       route, type, components, scenarios
## Audit                       what is audited and why
## Open questions              what is unresolved
```

### Where the columns live

The **Tables** section of a specification is a link, never a column list. The
physical model — every table, every column, every type, every index — is
[03-database/schemas/](../03-database/schemas/README.md), one file per schema,
and it is the only place that detail exists.

That was not the original arrangement. The four slices were gathered in one file
so that a table could be designed with the endpoint that serves it in view, and
that argument still holds for the *model*: the aggregates and their invariants
stay here. What moved out is the column list, for a reason that outweighs it —
two copies of a column list agree on the day they are written and never again,
and the one in the specification is the copy nobody updates.

The specification and the schema file are one link apart, and only one of them
can be wrong about a type.

## The link to the transition

The specification answers the question **what will be**. The question **where it
came from and what maps to what** is answered by the same domain's mapping:
[transition/map/](../../transition/map/README.md).

The pair of documents per domain — the specification in `product/spec/` and the
map in `transition/map/` — is maintained in sync. After the cutover the maps are
archived and the specifications remain.
