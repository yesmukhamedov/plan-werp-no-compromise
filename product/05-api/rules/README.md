---
id: PROD-05-RULES
title: API rules
status: draft
---

# API rules

The rules by which **any** endpoint in the system is shaped. Each is stated so
that the specification linter can check it; the check is in
[../checks.md](../checks.md).

| # | Rule | What it settles |
|---|---|---|
| 1 | [Versioning](01-versioning.md) | one version for the whole system; what may change inside it |
| 2 | [Path structure](02-paths.md) | the four segments; no verbs; how a non-CRUD action is expressed |
| 3 | [Methods](03-methods.md) | which method means what, and which are idempotent |
| 4 | [Lists](04-lists.md) | pagination, sorting, search, filters — one way each |
| 5 | [Errors](05-errors.md) | one body, stable codes, status codes, nothing internal |
| 6 | [Types](06-types.md) | how a date, an amount, an enumeration and a null travel |
| 7 | [Permissions](07-permissions.md) | every endpoint declares what it requires |
| 8 | [Mobile compatibility](08-mobile-compatibility.md) | the single exempted section, and the terms of its exemption |
| 9 | [Long-running operations](09-long-running.md) | the 5-second threshold and the `202` shape |

## Where to start

[Rule 2](02-paths.md) and [rule 4](04-lists.md) are the two that decide whether
the API stays coherent at scale.

Paths, because a path is the first thing a consumer sees and the hardest thing to
change afterwards: a verb that slips into one path licenses a verb in the next
fifty, and the API stops being navigable.

Lists, because in an ERP most endpoints are lists, and a list is where the
temptation to be clever is strongest — a generic filter language looks like it
saves work and instead makes field-level permissions, load prediction and client
generation impossible, all three at once.

[Rule 5](05-errors.md) is third: it costs nothing to adopt on day one and cannot
be adopted on day four hundred, because by then every client has been written
against whatever came out.

## The relationship to the specification

These rules describe the shape; the OpenAPI specification is the content, and it
is what generates the server stubs and the clients
([ADR-0005](../../../docs/02-decisions/ADR-0005-contract-first-api.md)).

The order matters and is not negotiable: **the specification is written first,
the code is generated from it, and the implementation is tested against it.** A
specification derived from code that already exists is a description, not a
contract, and it stops being accurate the first time someone is in a hurry.

## What is not here

**The endpoints of a specific domain, named one by one** — that is the domain's
specification ([../../spec/](../../spec/README.md)); the count and the resource
list per section is [../registry.md](../registry.md).

**What a permission means and who holds it** — that is
[ADR-0006](../../../docs/02-decisions/ADR-0006-auth-model.md) and the domain
specification. Rule 7 only says that an endpoint must name one.
