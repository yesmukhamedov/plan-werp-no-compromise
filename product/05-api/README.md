---
id: PROD-05
title: API contract
status: draft
---

# API contract

An implementation of the principles from
[ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md). The document
fixes the shape of the API so that **more than eight hundred endpoints written by
different people over several years look like one API.**

That is the whole purpose. An API of this size is not made coherent by review; it
is made coherent by rules narrow enough that there is only one way to express a
given thing, and by checks that fail a build when someone finds a second way.

| Level | Where | Answers |
|---|---|---|
| **0. The map** | this file | what the API is shaped like, and what is guaranteed about it |
| **1. The rules** | [rules/](rules/README.md) | how **any** endpoint is versioned, named, paginated, typed and secured |
| **2. The registry** | [registry.md](registry.md) | which sections and resources exist, and how many endpoints each has |
| **3. The domain specification** | [../spec/](../spec/README.md) | the endpoints of a designed domain, named one by one |
| | [checks.md](checks.md) | the checks that enforce the rules |

The contract itself — the OpenAPI specification — is the source of truth for the
generated server stubs and clients. **This document is about its shape; the
specification is its content.**

---

## The API in one page

```
/api/v1/{domain}/{resource}[/{id}[/{nested-resource}[/{id}]]]
```

| Property | Value | Rule |
|---|---|---|
| Version | one for the whole system, in the path | [1](rules/01-versioning.md) |
| Domain segment | from the [domain map](../02-domains.md), singular | [2](rules/02-paths.md) |
| Resource segment | plural noun, `kebab-case`, no verbs | [2](rules/02-paths.md) |
| Nesting | two levels maximum | [2](rules/02-paths.md) |
| An action that is not CRUD | a state sub-resource: `POST .../{id}/cancellation` | [2](rules/02-paths.md) |
| Every list | paginated; unbounded result sets do not exist | [4](rules/04-lists.md) |
| Every error | one body: `code`, `message`, `details`, `traceId` | [5](rules/05-errors.md) |
| Every money value | a string plus a currency, never a number | [6](rules/06-types.md) |
| Every endpoint | declares the permission it requires | [7](rules/07-permissions.md) |
| Anything slower than 5 s | `202` and a job identifier | [9](rules/09-long-running.md) |

## What a consumer can rely on

These are the promises the rules exist to make keepable. They are worth stating
as promises, because each is what a client's code depends on:

1. **A path never changes meaning within a version.** A breaking change is a new
   version, and compatibility is checked on every pull request
   ([1](rules/01-versioning.md)).
2. **Every list looks the same** — the same pagination parameters, the same
   response envelope, the same sort syntax — so a client writes list handling
   once ([4](rules/04-lists.md)).
3. **Every error looks the same**, and `code` is stable and machine-readable, so
   a client branches on a code rather than on a message
   ([5](rules/05-errors.md)).
4. **A `traceId` comes back on every failure**, so a user's support request
   resolves to a specific request in the logs
   ([11-observability.md](../11-observability.md)).
5. **Nothing internal is ever on the wire**: no stack trace, class name, SQL text
   or table name, in any environment
   ([NC-11](../../docs/01-principles/01-no-compromise.md#nc-11)).
6. **Money never loses precision**, because it is never a JSON number
   ([6](rules/06-types.md)).

## The one deliberate exception

`/api/mobile/**` does not obey the rules above. It reproduces the contract the
existing mobile application expects, which is not being rewritten
([C-06](../../docs/00-context/03-constraints.md#c-06-the-mobile-app--a-separate-client-outside-this-plan)).

It is **the product's only deliberate compromise**, and it is written down rather
than made silently: an explicit list of paths, no logic of its own, responses
pinned 1:1 by tests, marked deprecated with a stated condition for retirement
([8](rules/08-mobile-compatibility.md)).

## What the API deliberately does not have

| Will not exist | Why |
|---|---|
| A version per domain | a client would have to track thirteen ([1](rules/01-versioning.md)) |
| A verb in a path (`/cancelContract`) | the method is the verb ([2](rules/02-paths.md)) |
| An unpaginated list endpoint | the cost of a request must be bounded ([4](rules/04-lists.md)) |
| An arbitrary query language in the URL | it defeats field-level permissions, load prediction and client generation ([4](rules/04-lists.md)) |
| An error format that differs per domain | [5](rules/05-errors.md) |
| A money amount as a JSON number | precision loss, in the one domain that is entirely monetary ([6](rules/06-types.md)) |
| An endpoint with no declared permission | it does not pass CI ([NC-12](../../docs/01-principles/01-no-compromise.md#nc-12)) |
| A hand-written HTTP client | clients are generated from the specification ([ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md)) |
