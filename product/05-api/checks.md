---
id: PROD-05-CHECKS
title: How the API rules are enforced
status: draft
---

# How the API rules are enforced

A rule is enforced by a check that runs in CI on every pull request
([13-cicd.md](../13-cicd.md)). The check fails the build; it does not warn.

Most of these run against the OpenAPI specification rather than against the code,
which is what makes them cheap: the specification is written before the
implementation exists
([ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md)), so a rule
is enforced before there is anything to rewrite.

| # | Check | Rule |
|---|---|---|
| API-01 | every path starts `/api/v1/` or `/api/mobile/` | [1](rules/01-versioning.md) |
| API-02 | the specification is backward-compatible with the previous release, or the version is bumped | [1](rules/01-versioning.md) |
| API-03 | the domain segment of every path is a domain code from the map, in the singular | [2](rules/02-paths.md) |
| API-04 | every resource segment is a plural noun in `kebab-case` | [2](rules/02-paths.md) |
| API-05 | no path segment is a verb | [2](rules/02-paths.md) |
| API-06 | no path nests deeper than two resource levels | [2](rules/02-paths.md) |
| API-07 | every operation uses a method whose meaning matches it; `GET` has no request body | [3](rules/03-methods.md) |
| API-08 | every collection `GET` declares the standard pagination parameters and no others | [4](rules/04-lists.md) |
| API-09 | every collection `GET` returns the standard list envelope | [4](rules/04-lists.md) |
| API-10 | no parameter accepts a free-form query expression | [4](rules/04-lists.md) |
| API-11 | every operation declares its error responses, and each uses the shared error schema | [5](rules/05-errors.md) |
| API-12 | every declared error `code` exists in its domain's error-code list | [5](rules/05-errors.md), [BE-26](../04-backend/checks.md) |
| API-13 | no response schema contains a field named for an internal concept — a class, a table, a stack trace | [5](rules/05-errors.md), [NC-11](../../docs/01-principles/01-no-compromise.md#nc-11) |
| API-14 | every monetary field uses the shared money schema — a string plus a currency | [6](rules/06-types.md) |
| API-15 | no field is typed `number` where the domain says it is money, a rate or a coefficient | [6](rules/06-types.md) |
| API-16 | every date and date-time field uses the declared format | [6](rules/06-types.md) |
| API-17 | every enumeration is a string in `SCREAMING_SNAKE_CASE`, and its values are listed | [6](rules/06-types.md) |
| API-18 | **every operation declares the permission it requires** | [7](rules/07-permissions.md), [NC-12](../../docs/01-principles/01-no-compromise.md#nc-12) |
| API-19 | every declared permission exists in `platform.permission` | [7](rules/07-permissions.md) |
| API-20 | every operation has a unique `operationId` in `camelCase` | [registry](registry.md) |
| API-21 | every schema is a reference to a shared component, never inline | [registry](registry.md) |
| API-22 | every operation has a description and an example request and response | [registry](registry.md) |
| API-23 | nothing outside the declared path list is served under `/api/mobile/` | [8](rules/08-mobile-compatibility.md) |
| API-24 | every `/api/mobile/` operation is marked deprecated and has a pinned-response test | [8](rules/08-mobile-compatibility.md) |
| API-25 | the implementation conforms to the specification — the contract test suite | [ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md) |
| API-26 | the section list in the specification equals the section list in [registry.md](registry.md) | [registry](registry.md) |

## The two that carry the contract

**API-02** is the check that makes a version mean something. Without it, "we only
made a compatible change" is an opinion held by the person making the change,
and it is wrong about twice a year — which is exactly often enough to teach every
client team to pin, copy and stop trusting the contract.

**API-18** is
[NC-12](../../docs/01-principles/01-no-compromise.md#nc-12) in executable form. An
endpoint with no declared permission is not an endpoint that is open to everyone;
it is an endpoint whose access rule exists only in whichever `if` a developer
remembered to write. The check makes that state unrepresentable.

## The one that has to be re-earned every release

**API-24.** The mobile compatibility layer is exempt from the rules, and an
exemption without an expiry becomes permanent. The pinned-response tests and the
deprecation marker are what keep it from quietly becoming a second API — and the
condition for its retirement is written into
[rule 8](rules/08-mobile-compatibility.md) rather than left as an intention.

## What is checked elsewhere

| Concern | Where |
|---|---|
| That the handler behind an endpoint is shaped correctly | [04-backend/checks.md](../04-backend/checks.md) |
| That the columns the endpoint returns exist | [03-database/checks.md](../03-database/checks.md) |
| That a page consuming the endpoint declares the same permission | [06-frontend/checks.md](../06-frontend/checks.md) |
| Response-time budgets per endpoint | [10-performance.md](../10-performance.md) |
| Rate limiting, input validation, output filtering | [08-security.md](../08-security.md) |
