---
id: ADR-0008
title: A modular monolith, not microservices
status: Proposed
date: 2026-09-03
deadline: gate G1
---

# ADR-0008. A modular monolith, not microservices

## Context

The current system is a distributed monolith: seven deployable units that call
each other through Feign while **sharing one database and common modules**
(`main-module`, `util`). The service boundaries do not coincide with the domain
boundaries: `crm` exists both as a module of the main backend and as a separate
service; `accounting` is partially duplicated in the `service` module.

This is the worst of all possible options: the complexity of a distributed system
has already been paid for, while its benefits (independent deployment,
independent scaling, failure isolation) have not been obtained.

## Options

### A. A modular monolith

One deployable unit; inside it, modules with machine-checkable boundaries, each
with its own public interface, its own schema in the database and its own owner.

- **For:** transactions stay local — critical for the accounting domain, where an
  operation touches a contract, a journal entry and the warehouse at once;
  boundaries are checked by the compiler and by an architecture test rather than
  by agreement; debugging, local start-up and testing are cheaper by orders of
  magnitude; under a big bang the whole system ships as one release, so
  independent deployment is not required.
- **Against:** it scales as a whole; a failure affects everything; it demands
  discipline, otherwise in a few years it turns into the current `core`.

### B. Microservices

- **For:** independence of teams and deployments, independent scaling.
- **Against:** the ERP's cross-cutting transactions turn into distributed sagas —
  exactly the work that in the accounting domain can be neither cheap nor gotten
  wrong; it requires a mature platform (a service mesh, distributed tracing,
  contract testing between services, data orchestration) that does not exist
  today; the team size is unknown
  ([OQ-001](../../transition/12-open-questions.md)), and microservices pay off
  through the number of independent teams, not the number of domains.

### C. Keep the current split into seven services

Rejected: the split does not match the domains and is the cause of
[P-04](../00-context/02-pain-points.md#p-04-domains-implemented-twice).

## Decision (proposed)

**Option A — a modular monolith.** The only separately deployable components:

| Component | Why separate |
|---|---|
| The web application | a different runtime |
| `bridge` | the external boundary, not rewritten, a different life cycle |
| The background job worker | a different load and scaling profile; **the same codebase**, a different run mode |

Everything else consists of modules inside a single deployable application.

## The discipline without which this degenerates into the current `core`

The difference between a modular monolith and a monolith lies exclusively in
enforcing the boundaries. Therefore:

1. **The boundaries are checked by machine.** The architecture-rule test fails
   when a module reaches into another module's internals (NC-02). This is not a
   recommendation to the reviewer.
2. **Each module has its own explicit public interface** — narrow and separately
   declared. Everything else is inaccessible from outside technically, not by
   agreement.
3. **Each module has its own schema in the database.** Reaching into another
   module's tables directly is forbidden; the link between modules is by
   identifier, not by a foreign key across the boundary.
4. **Cross-domain operations** go either through the public interface or through
   an event. An event inside a monolith remains transactional, which removes the
   main complexity of sagas.
5. **Each module has an owner** — a person, not "the backend team".

## The path to microservices is left open

A modular monolith with enforced boundaries and separate schemas is a system from
which a module can be extracted into a separate service in a foreseeable amount
of time, should a real reason appear: a genuine difference in load profile or a
genuine need for independent releases. The reverse path (from microservices to a
modular monolith) is more expensive.

**A decision to extract a service is taken on the basis of a measured need and is
recorded in a separate ADR.** "The module has grown" is not a reason.

## Consequences

- The [domain map](../../product/02-domains.md) becomes a critical document: it
  defines the code modules, the database schemas and the ownership alike.
- The architecture-rule test appears in Phase 1, before any domain code is
  written — otherwise it will never be written at all.
- Scaling is horizontal, by whole application instances; the load profile is
  measured in advance
  ([product/10-performance.md](../../product/10-performance.md)).
- Application start-up time and test-suite run time become tracked metrics: in a
  monolith they degrade unnoticed and one day make development painful.
