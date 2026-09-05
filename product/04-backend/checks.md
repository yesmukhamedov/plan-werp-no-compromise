---
id: PROD-04-CHECKS
title: How the backend rules are enforced
status: draft
---

# How the backend rules are enforced

A rule is enforced by a check that runs in CI on every pull request
([13-cicd.md](../13-cicd.md)). The check fails the build; it does not warn.

Most of these are one architecture-rule test with many assertions rather than
twenty separate jobs `[STACK]` — but each is listed separately here, because a
check that is not named is a check that gets quietly deleted when it becomes
inconvenient.

| # | Check | Rule |
|---|---|---|
| BE-01 | no class outside `<module>/api/` is reachable from another module | [3](rules/03-visibility.md) |
| BE-02 | `domain/` imports nothing from `adapter/`, `application/` or any framework | [2](rules/02-module-structure.md) |
| BE-03 | `application/` imports nothing from `adapter/` | [2](rules/02-module-structure.md) |
| BE-04 | every module has the five directories and a `README.md` | [2](rules/02-module-structure.md) |
| BE-05 | no class name ends in `Util`, `Helper`, `Manager` or `Common` | [4](rules/04-class-types.md) |
| BE-06 | every class carries the suffix of its type, and no class carries two | [4](rules/04-class-types.md) |
| BE-07 | class length, method length and dependency count are within the limits | [4](rules/04-class-types.md), [NC-04](../../docs/01-principles/01-no-compromise.md#nc-04) |
| BE-08 | zero field injections; every dependency is a constructor parameter and immutable | [5](rules/05-class-rules.md), [NC-03](../../docs/01-principles/01-no-compromise.md#nc-03) |
| BE-09 | a transaction is opened only in a `*Handler` | [5](rules/05-class-rules.md) |
| BE-10 | a controller references no repository and no entity | [5](rules/05-class-rules.md) |
| BE-11 | a repository returns a domain object, never a record type | [5](rules/05-class-rules.md) |
| BE-12 | a repository touches only its own module's schema | [6](rules/06-data-access.md), [DB-09](../03-database/checks.md) |
| BE-13 | no SQL string concatenation anywhere | [6](rules/06-data-access.md), [NC-05](../../docs/01-principles/01-no-compromise.md#nc-05) |
| BE-14 | no second data-access mechanism is on the dependency list | [6](rules/06-data-access.md), [NC-05](../../docs/01-principles/01-no-compromise.md#nc-05) |
| BE-15 | every list query is paginated at the SQL level | [6](rules/06-data-access.md) |
| BE-16 | no lazy association crosses an aggregate boundary | [6](rules/06-data-access.md) |
| BE-17 | a query-count test covers every list endpoint; exceeding the expected count fails | [6](rules/06-data-access.md), [09-quality.md](../09-quality.md) |
| BE-18 | a cross-module call goes to a `*Facade` or is an event; nothing else compiles | [7](rules/07-cross-domain.md) |
| BE-19 | every published event is written through the outbox, in the producer's transaction | [7](rules/07-cross-domain.md) |
| BE-20 | there are no cyclic dependencies between modules | [7](rules/07-cross-domain.md), [02-domains.md](../02-domains.md#boundary-rules) |
| BE-21 | no module depends on a module below it in the dependency graph | [7](rules/07-cross-domain.md) |
| BE-22 | no platform module depends on a domain module | [7](rules/07-cross-domain.md) |
| BE-23 | every thrown exception descends from the one hierarchy and carries a code | [8](rules/08-error-handling.md) |
| BE-24 | conversion to an HTTP response happens in exactly one class | [8](rules/08-error-handling.md) |
| BE-25 | no response body can contain a stack trace, class name, SQL text or table name | [8](rules/08-error-handling.md), [NC-11](../../docs/01-principles/01-no-compromise.md#nc-11) |
| BE-26 | every error code a module can return is declared in the API specification | [8](rules/08-error-handling.md), [05-api](../05-api/checks.md) |
| BE-27 | every module in the registry exists in the source tree, and every module in the tree is in the registry | [modules/](modules/README.md) |
| BE-28 | a module's name equals its schema's name | [modules/](modules/README.md) |

## The three that cost the most and are worth the most

**BE-01** is the check the whole modular monolith stands on
([ADR-0008](../../docs/02-decisions/ADR-0008-modular-monolith.md)). Without it the
boundaries are a convention, and a convention survives until the first deadline.
Its cost is that it constrains how modules are packaged `[STACK]`; its value is
that the system can still be split into services in year five if that ever
becomes the right answer.

**BE-17** is unusual: it asserts a **number of database queries** per endpoint,
which means the assertion has to be updated whenever a query legitimately
changes. That friction is the point — an N+1 introduced by a lazy association is
otherwise invisible until production
([P-01](../../docs/00-context/02-pain-points.md#p-01-practically-no-tests)).

**BE-27** and **BE-28** need a source the code does not contain — this registry.
They are the pair that keeps the four registries of this plan describing the same
system, and they are the ones most likely to be dropped as bureaucracy. They are
not dropped ([NC-01](../../docs/01-principles/01-no-compromise.md)).

## What is checked elsewhere

| Concern | Where |
|---|---|
| Columns, types, indexes, constraints | [03-database/checks.md](../03-database/checks.md) |
| The API specification's shape and compatibility | [05-api/checks.md](../05-api/checks.md) |
| The interface's structure and accessibility | [06-frontend/checks.md](../06-frontend/checks.md) |
| Coverage, test time budgets, the N+1 threshold | [09-quality.md](../09-quality.md) |
| Secrets, dependencies, static security analysis | [08-security.md](../08-security.md) |
