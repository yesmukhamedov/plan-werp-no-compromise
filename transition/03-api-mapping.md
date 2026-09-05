---
id: TRANS-03
title: API mapping
status: draft
---

# API mapping

Which existing endpoint is replaced by which
([05-api/](../product/05-api/README.md)).

This is the most formalizable of the four maps: both the source and the target
are machine-readable lists. It is also the completeness criterion for the new
system.

---

# Part I. What will have to be transformed

## Scale

| Source | Endpoints |
|---|---:|
| `werp_java_back_v2` | 1,286 (+ 410 `@RequestMapping` on classes) |
| `werp_crm` | not counted |
| `werp_call_center` | not counted |
| `werp_jsf` | 472 pages, no endpoints — xhtml navigation |

## Two sources of truth about paths

Some paths are declared by annotations in the code, others by substitution from
the configuration:

```
@GetMapping("${routes.api.reference.companies}")     from application.yml
@GetMapping("/states")                                right in the code
```

Both variants occur **in one class**. The full list of paths cannot be obtained
from the code or from the configuration — only from their union.

**Rule:** there is one source of truth — the OpenAPI specification
([ADR-0005](../docs/02-decisions/ADR-0005-contract-first-api.md)). The path is
not set in the code at all: the controllers are generated.

## Verbs and capital letters in paths

The forms in operation: `/FETCH_COUNTRIES`, `/FETCH_COUNTRIES2`, `/FETCH_USERS`,
`/checkAccess`, `/checkAccessWithTcode`, `/dmulstAll`, `/dmumovenode`,
`/userInfo`, `/crm/allCrmGroupDealersForCurrentUser`,
`/crm/dealersContractSalesDailyByBranchIdAndYearAndMonth`.

The last example shows the essence of the problem: the parameters are moved
**into the path name** rather than the query string. Every new combination of
filters spawns a new endpoint — that is how 1,286 endpoints accumulated.

**Rule:** the resource in the path, the filters in the parameters. The endpoint
above becomes:

```
GET /api/v1/contract/dealer-sales?branchId=…&period=…&granularity=DAILY
```

One line instead of two endpoints (`…ByBranchIdAndYearAndMonth` and
`…DailyByBranchIdAndYearAndMonth`).

## Versions in the name

`/FETCH_COUNTRIES` and `/FETCH_COUNTRIES2` coexist; the DTOs are called
`Branch2DTO`, `Company2DTO`. The second version was added alongside; the first
stayed.

**Rule:** the version goes in the path (`/api/v1/`), one per system. A `2` suffix
in a resource or model name is impossible under the specification linter's rules.

## Endpoints in the wrong domain

`ReferenceRestController` (the reference-data domain) contains 72 endpoints,
among them:

```
/crm/staffListForCrm              personnel data          → D3
/crm/salaryListForCrm/{staffId}   salary                  → D6
/crm/pyramidByYearAndMonth        the sales structure     → D9
/crm/dealersContractSales…        sales by contract       → D4
/checkAccess                      a permission check      → D0
```

An endpoint's domain is determined by **the subject of the data**, not by which
class it historically ended up in. During the transfer such endpoints move to
their own domains — and that changes the domain map, not only the API map.

## Returning entities instead of DTOs

Some endpoints return a JPA entity directly (`fetchCountries` returns
`Map<Long, Country>`). The client receives the table's structure, including
fields it should not know about, and any schema change breaks the contract.

**Rule:** entities do not leave the module; the response is described in the
specification.

## Arbitrary filtering

RSQL is in use — a query language in the URL string that lets the client compose
an arbitrary condition. The consequences: field-level permission control is
impossible, estimating a query's cost is impossible, generating a typed client is
impossible.

**Rule:** explicit named filters declared in the specification
([API rule 4](../product/05-api/rules/04-lists.md)).

---

# Part II. Mapping rules

| Category | Rule | Example |
|---|---|---|
| CRUD | a direct mapping | `GET /reference/branch/list` → `GET /api/v1/reference/branches` |
| A parameter in the path | moved into the query string | `/regions/{countryId}` → `/regions?countryId=` |
| A verb in the path | the method + a state sub-resource | `POST /cancelContract` → `POST /contracts/{id}/cancellation` |
| `FETCH_*` | an ordinary list | `/FETCH_COUNTRIES` → `GET /countries` |
| The `*2` versions | consolidated into one | `/FETCH_COUNTRIES2` → the same `GET /countries` |
| Specialized extracts | one list + filters | several → one |
| An endpoint of another domain | moves to its own domain | `/reference/crm/staffList…` → `/api/v1/hr/…` |
| The `*F4` mechanism | an ordinary list with search | `BranchF4` → `GET /branches?q=` |
| A dead endpoint | not carried over | the owner's decision, in writing |
| New | appears with no predecessor | marked "new" |

## Expected reduction

The number of endpoints should decrease noticeably thanks to: consolidating
versions, merging specialized extracts into lists with filters, replacing the
`*F4` mechanism, and weeding out the dead ones.

**By how much is unknown until the inventory.** The estimate appears in
[EPIC-002](../backlog/EPIC-002-contract-inventory.md) and refines the
[Phase 2 estimate](10-estimates.md).

---

# Part III. The compatibility layer

The only place where the rules above **do not apply**.

The mobile app is not being rewritten and requires a 1:1 contract
([C-06](../docs/00-context/03-constraints.md#c-06-the-mobile-app--a-separate-client-outside-this-plan)).
For it, the existing paths and response shapes are preserved unchanged.

## Where the list comes from

From `bridge` — the file `internal/routes/mobile.go`. It declares an **explicit
allowlist** of the paths opened to the mobile app: not prefixes but a list by
name.

That is a ready specification of the mandatory minimum, proven in operation — the
most valuable input artefact of
[EPIC-002](../backlog/EPIC-002-contract-inventory.md). Nothing has to be
reconstructed; the list already exists.

## Requirements on the layer

| Requirement | Why |
|---|---|
| The paths and response shapes match 1:1, error codes included | the app is not being rewritten |
| Implemented on top of the domain facades, with no logic of its own | otherwise a second implementation of the domain appears |
| Limited to the list from `bridge`; nothing beyond it | the same allowlist principle |
| Covered by tests that pin the responses | the only way to guarantee 1:1 |
| Marked deprecated in the specification | so that it gets retired rather than forgotten |
| The retirement condition is recorded | an update to the mobile app |

## Verification

The layer's tests are written **against the system in operation** in Phase 0
([TASK-0202](../backlog/EPIC-002-contract-inventory.md)) — as characterization
tests: they pin the current responses, quirks included. The same tests are then
run against the new system.

---

# Part IV. Endpoint map

Filled in in [EPIC-002](../backlog/EPIC-002-contract-inventory.md).

| Source | Method | Path | Live | Decision | Target | Owner |
|---|---|---|---|---|---|---|
| `werp_java_back_v2` | — | *(1,286 endpoints)* | — | not taken | — | — |
| `werp_crm` | — | *(not counted)* | — | not taken | — | — |
| `werp_call_center` | — | *(not counted)* | — | not taken | — | — |
| `bridge` → mobile | — | *(an explicit allowlist)* | yes | **1:1** | `/api/mobile/**` | — |

The "live" column is filled in from access statistics
([TASK-0106](../backlog/EPIC-001-project-setup.md)), not from memory.

A sample of a filled-in map —
[map/D1-reference.md](map/D1-reference.md#endpoints).

## The completeness criterion

The new system is complete with respect to the API when every source endpoint has
a decision, and every "migrate" or "consolidate" decision has an implemented
target endpoint.

This is a machine-checkable condition and one of the domain readiness indicators
([plan/03-phase-2-domains.md](plan/03-phase-2-domains.md#progress-indicators)).
