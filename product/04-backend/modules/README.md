---
id: PROD-04-MODULES
title: Module registry
status: draft
---

# Module registry

**Twenty-four modules: 12 platform and 12 domain.** This is the complete list of what the server side is made of.

| Group | Count | Classes (estimate) | Where |
|---|---:|---:|---|
| [Platform](platform.md) — depended on by all, depending on none | 12 | ~120 | D0 |
| [Domain](domains.md) — one per business domain | 12 | ~1,180 | D1 … D12 |
| **Total** | **24** | **~1,300** | |

`werp-worker` is not in the count: it is the same artefact started in a different
run mode ([rule 1](../rules/01-deployable-units.md)).

## State, module by module

| Module | Domain | Schema | State | Specification |
|---|---|---|---|---|
| `platform-*` (12) | D0 | [platform](../../03-database/schemas/platform.md), [audit](../../03-database/schemas/audit.md) | outlined | — |
| `reference` | D1 | [reference](../../03-database/schemas/reference.md) | **designed** | [spec/D1-reference.md](../../spec/D1-reference.md) |
| `party` | D2 | [party](../../03-database/schemas/party.md) | drafted | — |
| `hr` | D3 | [hr](../../03-database/schemas/hr.md) | **designed** | [spec/D3-hr.md](../../spec/D3-hr.md) |
| `contract` | D4 | [contract](../../03-database/schemas/contract.md) | drafted | — |
| `accounting` | D5 | [accounting](../../03-database/schemas/accounting.md) | **designed** | [spec/D5-accounting.md](../../spec/D5-accounting.md) |
| `payroll` | D6 | [payroll](../../03-database/schemas/payroll.md) | drafted | — |
| `inventory` | D7 | [inventory](../../03-database/schemas/inventory.md) | drafted | — |
| `service` | D8 | [service](../../03-database/schemas/service.md) | drafted | — |
| `crm` | D9 | [crm](../../03-database/schemas/crm.md) | drafted | — |
| `docflow` | D10 | [docflow](../../03-database/schemas/docflow.md) | drafted | — |
| `legal` | D11 | [legal](../../03-database/schemas/legal.md) | declared | — |
| `tasks` | D12 | [tasks](../../03-database/schemas/tasks.md) | drafted | — |

The states mean the same thing they mean in the
[schema registry](../../03-database/schemas/README.md), and they move together: a
module is not `designed` while its schema is `drafted`, because a repository
cannot be written against columns nobody has confirmed.

## One module, one schema, one API section, one interface section

The four registries in this plan describe the same thirteen things from four
sides, and they are kept aligned deliberately:

| The module | its schema | its API section | its interface section |
|---|---|---|---|
| [modules/domains.md](domains.md) | [03-database/schemas/](../../03-database/schemas/README.md) | [05-api/registry.md](../../05-api/registry.md) | [06-frontend/registry.md](../../06-frontend/registry.md) |

A name that differs between the four is a defect, not a style choice. `inventory`
was `logistics` in the module registry and `/api/v1/logistics` in the API
registry while its schema was already `inventory`; all three now say
`inventory`.

## What determines a module's contents

Not taste. Four lists follow mechanically from the schema, and they are what
[domains.md](domains.md) records per module:

| From the schema | Determines |
|---|---|
| an aggregate root | a repository |
| a table group | an API resource, and therefore a controller |
| a rule the database cannot express | a `*Rule` class, and a test that writes bypassing the application |
| a derived table with a rebuild job | a domain service and a scheduled job |

That is why a module can be inventoried before it is specified — and why the
inventory is worth re-checking against the specification once that exists.

## What is not here

**The classes of a designed domain, named one by one** — that is the domain's
specification, [../../spec/](../../spec/README.md). This registry says how many
and of which type; the specification says which.
