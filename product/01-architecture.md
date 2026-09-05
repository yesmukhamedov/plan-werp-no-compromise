---
id: PROD-01
title: Target architecture
status: draft
---

# Target architecture

How the new WERP is put together, at the level above modules and below decisions.

Concrete technologies are not named: the stack decision is deferred
([ADR-0003](../docs/02-decisions/ADR-0003-backend-stack.md)), and everything here
is achievable on any of the candidates. The places where the stack does have an
influence are marked `[STACK]`.

| This document says | The detail is in |
|---|---|
| what the system is made of, and how the pieces connect | — |
| which domains exist and what depends on what | [02-domains.md](02-domains.md) |
| how data is stored | [03-database/](03-database/README.md) |
| how the server side is built | [04-backend/](04-backend/README.md) |
| how the contract is shaped | [05-api/](05-api/README.md) |
| how the interface is built | [06-frontend/](06-frontend/README.md) |

---

## Overall diagram

```
        browser                     mobile app             external systems
           │                            │                         │
           │                            └────────┬────────────────┘
           │                                     ▼
           │                              ┌─────────────┐
           │                              │   bridge    │  Go, not rewritten
           │                              └──────┬──────┘
           ▼                                     │
   ┌───────────────┐                             │
   │  web frontend │                             │
   │  (static)     │                             │
   └───────┬───────┘                             │
           │                                     │
           └──────────────┬──────────────────────┘
                          ▼
                 ┌──────────────────┐
                 │ identity         │  authentication (ADR-0006)
                 │ provider         │
                 └────────┬─────────┘
                          ▼
        ┌─────────────────────────────────────────┐
        │            WERP application             │  a modular monolith (ADR-0008)
        │  ┌───────────────────────────────────┐  │
        │  │  platform: access, audit,         │  │  12 modules
        │  │  reports, files, notifications,   │  │
        │  │  background jobs, observability   │  │
        │  └───────────────────────────────────┘  │
        │  ┌────────┬────────┬────────┬────────┐  │
        │  │ domain │ domain │ domain │  ...   │  │
        │  └────────┴────────┴────────┴────────┘  │  12 modules, boundaries checked
        └────────────────────┬────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
   PostgreSQL          file storage           job queue
   (14 schemas,                               + worker
    204 tables)
```

## The system in numbers

Every figure below is an outcome of design recorded in a registry, not an
estimate. They move when a design decision moves, and each move has a reason
written down where it happened.

| | Count | Registry |
|---|---:|---|
| Domains | 13 — D0 … D12, of which 12 are business domains | [02-domains.md](02-domains.md) |
| Database schemas | 14 | [03-database/schemas/](03-database/schemas/README.md) |
| Tables | 204 | the same |
| Backend modules | 24 — 12 platform, 12 domain | [04-backend/modules/](04-backend/modules/README.md) |
| Classes (estimate) | ~1,300 | the same |
| API sections | 14 | [05-api/registry.md](05-api/registry.md) |
| Endpoints | ~550 | the same |
| Interface sections | 14 | [06-frontend/registry.md](06-frontend/registry.md) |
| Pages | ~170 | the same |
| Deployable units | 2 (one artefact) | [04-backend/rules/01-deployable-units.md](04-backend/rules/01-deployable-units.md) |

**The four registries describe the same thirteen things from four sides**, and
they are kept aligned by check: a module, its schema, its API section and its
interface section share one name, and a name that differs in one of the four is a
build failure ([BE-28](04-backend/checks.md)).

## The architectural constraints

Nine constraints that the rest of the documents implement. Each is stated so it
can be cited, and each has a place where it is enforced.

| # | Constraint | Enforced by |
|---|---|---|
| ARCH-01 | One deployable application; the worker is a run mode, not a service | [ADR-0008](../docs/02-decisions/ADR-0008-modular-monolith.md), [04-backend rule 1](04-backend/rules/01-deployable-units.md) |
| ARCH-02 | The domain layer depends on nothing external — not HTTP, not the database, not a framework | [BE-02](04-backend/checks.md) |
| ARCH-03 | A module is reachable only through its `api/` package | [BE-01](04-backend/checks.md), [NC-02](../docs/01-principles/01-no-compromise.md#nc-02) |
| ARCH-04 | A module reads and writes only its own database schema | [BE-12](04-backend/checks.md), [DB-09](03-database/checks.md) |
| ARCH-05 | Cross-domain interaction is a facade call or an event; there is no third way | [BE-18](04-backend/checks.md) |
| ARCH-06 | No cyclic dependency between modules, and no dependency on a module below in the graph | [BE-20](04-backend/checks.md), [BE-21](04-backend/checks.md) |
| ARCH-07 | The platform depends on no domain; every domain may depend on the platform | [BE-22](04-backend/checks.md) |
| ARCH-08 | One artefact passes through every environment; only configuration differs | [NC-11](../docs/01-principles/01-no-compromise.md#nc-11), [12-environments.md](12-environments.md) |
| ARCH-09 | The application is stateless; no operation requires a particular instance | [07-nfr.md](07-nfr.md#scalability) |

**ARCH-02 is the load-bearing one.** A domain layer that knows about HTTP or SQL
cannot be tested without a container and a database, and a layer that cannot be
tested cheaply is a layer that stops being tested. That is exactly the state the
existing `ContractController` is in, with business logic mixed into transport.

## Layers

Inside every domain, three layers and one dependency rule: **inwards, never
outwards**.

| Layer | What it contains | What it depends on |
|---|---|---|
| Domain | entities, rules, invariants, domain operations | nothing external |
| Application | scenarios, transaction boundaries, authorization, orchestration | the domain layer |
| Adapters | HTTP, storage, queues, external systems, files | the application layer |

How a request travels through them, step by step, naming the class type at each
step: [04-backend/README.md](04-backend/README.md#how-a-request-travels).

## Modules and boundaries

The system is divided into modules according to the [domain map](02-domains.md).
Every module:

- has a **narrow, explicit public interface** — everything else is inaccessible
  from outside technically `[STACK]`;
- has **its own schema** in PostgreSQL; it does not read other modules' tables;
- refers to other modules' entities **by identifier**, without foreign keys
  across the boundary;
- has an owner — a person;
- has a README
  ([01-principles/03-engineering-standards.md](../docs/01-principles/03-engineering-standards.md#module-structure)).

A boundary violation is detected by the architecture-rule test and blocks the
merge ([NC-02](../docs/01-principles/01-no-compromise.md#nc-02)).

## Cross-domain interaction

Two ways, and only these:

| Way | When | Transaction | Failure mode it avoids |
|---|---|---|---|
| A synchronous call to another module's `Facade` | the result is needed now and the operation is logically single | shared | eventual consistency where the business expects immediate consistency |
| A domain event through the transactional outbox | another domain must react, and the initiator does not need the result | published in the source's transaction, processed separately | a lost event, or an event published for a rolled-back change |

Forbidden: reading another domain's tables, injecting another domain's
repository, sharing a mutable structure between domains.

**The outbox is not optional.** An event published outside the producing
transaction is either lost when the transaction rolls back or emitted for a
change that never happened, and both failures are silent.

## Platform

The layer common to all domains, written in
[Phase 1](../transition/plan/02-phase-1-platform.md) **before** domain
development — otherwise every domain builds its own variant, which is precisely
how today's `util` and `main-module` came to exist.

Twelve modules, listed with their responsibilities, key classes and the tables
they own: [04-backend/modules/platform.md](04-backend/modules/platform.md).

| Subsystem | Responsibility |
|---|---|
| Access | authentication, permissions, data scope ([ADR-0006](../docs/02-decisions/ADR-0006-auth-model.md)) |
| Audit | who changed what, and when ([C-10](../docs/00-context/03-constraints.md#c-10-change-audit-already-exists-and-must-be-preserved)) |
| Reports and exports | templates, generation, asynchronous execution ([ADR-0009](../docs/02-decisions/ADR-0009-reporting-and-exports.md)) |
| Files | upload, storage, access, lifetime |
| Notifications | email, SMS, messenger messages, in-app notifications |
| Numbering | human-facing document numbers, gapless where the law requires |
| Background jobs | scheduling, queue, retries, idempotency |
| Outbox | transactional event publication |
| Observability | logs, metrics, tracing ([11-observability.md](11-observability.md)) |
| Errors and validation | a single error model, localized messages |
| Money | decimal arithmetic, currencies, rounding |
| Internationalization | messages in three languages |

## Data

- One PostgreSQL database, a schema per domain
  ([ADR-0002](../docs/02-decisions/ADR-0002-database-postgresql.md)).
- The schema changes only through versioned migrations; runtime autogeneration is
  forbidden in all environments, the development one included.
- Heavy reads — reports, analytics, exports — go to a replica, and the code says
  so explicitly.
- The cache is explicit, with a clear invalidation policy; it is not a source of
  truth, and losing it does not lead to incorrect data.

In detail — [03-database/](03-database/README.md).

## Deployment

| Component | Instances | Profile |
|---|---|---|
| The WERP application | several, behind a load balancer | request handling |
| The background job worker | separate, the same codebase | long-running operations, scheduling |
| The web frontend | static files behind a CDN or web server | — |
| `bridge` | as it is today | the external boundary |

The very same artefact passes through all environments; the only differences are
in configuration ([ARCH-08](#the-architectural-constraints)).

## What the architecture deliberately does not have

| Will not exist | Why |
|---|---|
| Microservices | [ADR-0008](../docs/02-decisions/ADR-0008-modular-monolith.md) |
| A shared database between independently deployable parts | a distributed monolith is the worst of both worlds ([ADR-0008](../docs/02-decisions/ADR-0008-modular-monolith.md)) |
| A second implementation of a domain | [NC-06](../docs/01-principles/01-no-compromise.md#nc-06) |
| A home-grown authentication server | [ADR-0006](../docs/02-decisions/ADR-0006-auth-model.md) |
| Report generation in the browser | [ADR-0009](../docs/02-decisions/ADR-0009-reporting-and-exports.md) |
| A `util` layer where everything gets dumped | that is how today's `util` appeared, and `main-module` right behind it |
| Direct frontend access to several different backends | the reason addresses end up hardcoded in the bundle |
| Business logic inside the database | [03-database rule 9](03-database/rules/09-logic-in-the-database.md) |

## What would make this architecture the wrong one

Stated so that the decision can be revisited honestly rather than defended:

| If this turned out to be true | Then |
|---|---|
| Two domains genuinely need independent release cadences | ARCH-01 is wrong, and the answer is a new ADR superseding [ADR-0008](../docs/02-decisions/ADR-0008-modular-monolith.md) — not an exception |
| One domain's load profile is orders of magnitude apart from the rest | the same, and the split follows a boundary that already exists |
| The team grows past the point where one repository and one release train work | [ADR-0007](../docs/02-decisions/ADR-0007-repo-layout.md) is revisited before ADR-0008 |

The modular monolith is chosen partly *because* each of these has a clean exit:
the module boundaries are enforced by machine, so a module that has to become a
service already has the interface it would need.
