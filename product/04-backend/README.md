---
id: PROD-04
title: Backend
status: draft
---

# Backend

What the server side consists of: deployable units, modules, layers, classes.

Concrete technologies are not named — the stack decision is deferred
([ADR-0003](../../docs/02-decisions/ADR-0003-backend-stack.md)). Everything
described here is achievable on any of the candidates; the places where the stack
does have an influence are marked `[STACK]`.

The document is organized like [03-database/](../03-database/README.md), and for
the same reason: rules that apply to every class, a registry that enumerates
every module, and checks that make the rules a failing build rather than a
preference.

| Level | Where | Answers |
|---|---|---|
| **0. The map** | this file | what the server side is made of, and how a request travels through it |
| **1. The rules** | [rules/](rules/README.md) | how **any** module and **any** class is built |
| **2. The registry** | [modules/](modules/README.md) | which modules exist, and what is inside each |
| **3. The domain specification** | [../spec/](../spec/README.md) | the classes of a designed domain, named one by one |
| | [checks.md](checks.md) | the checks that enforce the rules |

---

## The shape of the server side in one page

One application, two run modes, twenty-four modules.

```
                    HTTP request
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  adapter/web       controllers      │  transport only, no logic
        ├────────────────────────────────────┤
        │  application       handlers         │  one scenario, one transaction
        ├────────────────────────────────────┤
        │  domain            entities, rules  │  knows nothing of HTTP or SQL
        ├────────────────────────────────────┤
        │  adapter/persistence  repositories  │  its own schema, nothing else
        └────────────────────────────────────┘
                         │
                         ▼
                  one schema per domain
```

**The dependency rule — inwards, never outwards:**

```
adapter  →  application  →  domain
   │                          ▲
   └──────── api ─────────────┘
```

`domain` knows nothing about HTTP or about the database. That is the only thing
that makes it testable without a container and without a database, and it is
[rule 2](rules/02-module-structure.md).

## How a request travels

A single scenario, from the wire to the row, naming the class type at each step:

| # | Where | Class | What it does | What it must not do |
|---|---|---|---|---|
| 1 | `adapter/web` | `<Resource>Controller` | parse, call one handler, return | contain an `if` on a business condition |
| 2 | `application` | `<UseCase>Handler` | open the transaction, check the permission, orchestrate | contain the rule itself |
| 3 | `domain` | entity, `<X>Rule`, `<X>Service` | decide | know it is being called over HTTP |
| 4 | `adapter/persistence` | `<Entity>Repository` | read and write **its own schema** | return a table row instead of a domain object |
| 5 | `application` | the same handler | publish an event through the outbox | call another domain's repository |

Every one of the "must not do" entries is a check in [checks.md](checks.md), not
a review comment.

## The two deployable units

| Unit | What | Why separate |
|---|---|---|
| `werp-app` | the whole application: the platform plus 12 business domains | — |
| `werp-worker` | background jobs | a different load profile; **the same codebase**, a different run mode |

`werp-worker` is not a separate project
([rule 1](rules/01-deployable-units.md)).

## The twenty-four modules

| Group | Count | Where |
|---|---:|---|
| Platform modules — depended on by all, depending on none | 12 | [modules/platform.md](modules/platform.md) |
| Domain modules — one per business domain | 12 | [modules/domains.md](modules/domains.md) |

Thirteen domains, twelve domain modules: D0 is a domain of the map but is a
**group** of twelve platform modules rather than one module, and it owns two
schemas rather than one. Everywhere else the correspondence is exact — one
business domain, one module, one schema, one API section, one interface
section.

## What the backend deliberately does not have

| Will not exist | Why |
|---|---|
| A class named `*Util`, `*Helper`, `*Manager`, `*Common` | that is the name of a place where things get dumped ([rule 4](rules/04-class-types.md)) |
| A second data-access mechanism | [NC-05](../../docs/01-principles/01-no-compromise.md#nc-05), [rule 6](rules/06-data-access.md) |
| Business logic in a controller | [rule 5](rules/05-class-rules.md) |
| A transaction opened in a repository or a controller | [rule 5](rules/05-class-rules.md) |
| A cross-domain call that is not a facade call or an event | [rule 7](rules/07-cross-domain.md) |
| Field injection | [NC-03](../../docs/01-principles/01-no-compromise.md#nc-03), [rule 5](rules/05-class-rules.md) |
| A stack trace, class name, SQL text or table name in a response | [rule 8](rules/08-error-handling.md) |
