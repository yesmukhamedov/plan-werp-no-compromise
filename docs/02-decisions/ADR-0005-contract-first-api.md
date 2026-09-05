---
id: ADR-0005
title: Contract-first API
status: Proposed
date: 2026-09-03
deadline: gate G0
---

# ADR-0005. Contract-first API

## Context

Today the API specification is generated from the code (springfox-swagger
2.9.2) — meaning the description always trails the implementation and cannot be
the source of truth. The consequences are visible in the current system: 410
`@RequestMapping` mixed in with 1,286 typed annotations, non-uniform response and
error formats, a set of paths some of which are moved into the configuration
(`routes:` in `application.yml`) while others are hardcoded in annotations.

Under a big bang strategy the contract matters especially: the frontend and the
backend are written in parallel but meet only at the end. Without a shared
contract they will meet badly.

Separately: the mobile app must receive a contract that is **1:1** with the
current one
([C-06](../00-context/03-constraints.md#c-06-the-mobile-app--a-separate-client-outside-this-plan)).
That is impossible to verify without a formal description of what exists today.

## Decision (proposed)

**The specification is the source of truth. The code is generated from it, not
the other way round.**

1. The contract is described in a machine-readable format (OpenAPI for HTTP) and
   lives in a separate repository or directory, versioned independently of the
   implementation.
2. Generated from the specification: server interfaces/models `[STACK]`, the
   client for the frontend, the client for contract tests.
3. Writing HTTP wrappers and DTOs by hand is forbidden — they are generated.
4. A contract change is a separate PR reviewed by both sides. A breaking change
   requires a new version rather than an edit to the existing one.
5. A single error format for the whole system; the error codes are part of the
   contract.
6. A single pagination, sorting and filtering format for all lists.

## What this gives under a big bang

- The frontend starts working against a generated stub without waiting for the
  backend. That is the only way to run Phases 2 and 3 in parallel.
- The mobile app's contract is fixed formally and verified by a test, rather than
  by "we do not think we changed anything".
- The inventory of the current 1,286 endpoints
  ([EPIC-002](../../backlog/EPIC-002-contract-inventory.md)) yields not a list
  but an executable specification — which then becomes the completeness criterion
  for the new system.

## Naming and shape rules

Fixed once and checked by a specification linter:

- Resources are plural nouns; actions are HTTP methods, not verbs in the path.
  Current paths of the form `.../FETCH_USERS`, `.../dmulstAll`,
  `.../checkAccess` are not reproduced.
- Identifiers in the path; filters in the query string; a body only for changing
  state.
- Lists are always paginated; an endpoint that returns everything does not exist
  ([01-principles/03-engineering-standards.md](../01-principles/03-engineering-standards.md#performance)).
- Dates and times — ISO 8601 in UTC.
- Money — a string with a decimal representation plus the currency code next to
  it; never a floating-point number.
- Every endpoint declares the permission it requires (NC-12) right in the
  specification.

## Consequences

- Phase 0 work appears: describe the existing contract formally
  ([EPIC-002](../../backlog/EPIC-002-contract-inventory.md)). This is not
  bureaucracy — it is the only way to learn what exactly we are obliged to
  preserve.
- A contract-compatibility check appears in CI: a breaking change is detected
  automatically.
- Contract tests become a separate layer in the
  [testing strategy](../../product/09-quality.md).
- A specification linter with the rules from this ADR is required, otherwise in a
  year's time the contract will be as heterogeneous as the current one.
