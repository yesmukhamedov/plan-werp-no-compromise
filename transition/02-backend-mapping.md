---
id: TRANS-02
title: Backend mapping
status: draft
---

# Backend mapping

Which existing class is replaced by what in the target structure
([04-backend/](../product/04-backend/README.md)).

---

# Part I. Why this is not a class-for-class transfer

The mapping here is **not one-to-one**, and that is the main thing to understand
when planning.

## One class → many classes

`ContractController` — 3,775 lines, 38 field injections. It contains: transport,
business logic, calls into seven foreign domains, report generation, sending SMS.

In the target structure it turns into roughly: 1 controller (≤ 200 lines), 6–10
scenario handlers, 2–4 domain services, several rules, and calls to other
domains' facades instead of direct calls into their DAOs.

The same applies to `PayrollService` (7,598 lines), `FinanceServiceDms` (5,629),
`FinanceReportRestController` (5,366), `ServiceTableService` (3,984),
`InvoiceServiceImpl` (2,375).

**Consequence for the estimate:** a domain's effort is not proportional to the
number of inherited classes. One god class is more expensive than twenty small
ones.

## Many classes → one

Duplicated domains collapse: two CRM implementations (the `crm` module and the
`werp_crm` repository), two reference-data implementations (`reference` and
`mreference`), two field-service implementations.

**Consequence:** before the transfer it has to be decided which implementation is
the right one. That is not a technical decision — the domain owner takes it
([OQ-002](12-open-questions.md#oq-002)).

## Class → nothing

Whole categories disappear:

| What disappears | How much | What replaces it |
|---|---|---|
| The `*F4` classes — "value help" | 34 in one domain | ordinary list endpoints with search |
| The `dao/` layer with `DAOException` | per domain | repositories |
| Hand-written HTTP wrappers, DTOs | hundreds | generation from the specification |
| `util`, `main-module` as a dumping ground for shared code | 293 files | platform modules with explicit boundaries |
| Classes serving dead endpoints | unknown | nothing |

## Nothing → class

Things appear that do not exist in the inherited system at all: domain facades,
domain events and listeners, rules as separate classes, scenario handlers, tests,
the platform modules (12 of them), the compatibility layer for the mobile app.

**This is a substantial part of the work that has no predecessor** — and it is
regularly forgotten when estimating a "rewrite".

---

# Part II. Mapping rules

## By class type

| Was | Becomes | Rule |
|---|---|---|
| A `*Controller` with logic | `*Controller` + `*Handler` | the controller keeps transport only |
| A `*Service` (a god class) | several `*Handler` + `*Service` + `*Rule` | split by scenario |
| `*ServiceImpl` + an interface | one class | an interface with a single implementation is not created |
| `*Dao`, `*DaoImpl` | `*Repository` | one data-access mechanism |
| `@Entity` (a table) | a domain entity + a `*Record` | the domain model is separated from the table row |
| `*F4` | a list endpoint with search | there is no separate suggestion mechanism |
| Hand-written DTOs | generated from the specification | |
| `*Util`, `*Helper` | a domain rule or a platform module | classes with such names do not exist |
| Direct injection of another domain's DAO | a call to another domain's facade | [NC-02](../docs/01-principles/01-no-compromise.md#nc-02) |

## The "behaviour, not code" rule

The existing implementation is a **source of requirements**, not a model to copy.
We read it to understand what the system does; we write it anew knowing why.

The sign of a violation: a structure appears in the target class that can only be
explained by the history of the inherited code.

## What is carried over verbatim

One category is carried over as closely to the original as possible — the
**calculation formulas** (monetary, payroll, tax). Their behaviour is pinned down
by characterization tests
([EPIC-004](../backlog/EPIC-004-characterization-tests.md)) and must match to the
cent.

What is carried over is the **formula**, not its packaging: a calculation from a
400-line method becomes a set of rules producing the same results from the same
inputs.

---

# Part III. Module map

| Source | Files | Target module | Decision | Owner |
|---|---:|---|---|---|
| `core/general`, `auth-server`, `main-module` (permissions), `dit` (ABAC) | ~420 | `platform-*` | consolidate | not assigned |
| `core/reference` + `core/mreference` | 254 | `reference` | **consolidate** | not assigned |
| `core/mreference` (customers, addresses, phone numbers) | part | `party` | consolidate | not assigned |
| `core/hr` | 321 | `hr` | migrate | not assigned |
| `core/marketing` | 272 | `contract` | migrate | not assigned |
| `core/accounting` + `service/maccounting` | ~350 | `accounting` | consolidate | not assigned |
| `core/accounting` (payroll calculation) | part | `payroll` | extract | not assigned |
| `core/logistics` | 418 | `logistics` | migrate | not assigned |
| `core/service` + the `service` module | 786 | `service` | **consolidate** | not assigned |
| `core/crm` + the `crm` module + `werp_crm` + `werp_call_center` | ~966 | `crm` | **consolidate (4 sources)** | not assigned |
| `core/documents` | 37 | `docflow` | migrate | not assigned |
| `core/law_department` | 15 | `legal` | migrate | not assigned |
| `core/dit` (tasks, messages, SMS) | part of 162 | `tasks` | migrate | not assigned |
| `core/aes` | 40 | **undetermined** | [OQ-004](12-open-questions.md#oq-004) | not assigned |
| `core/newdev` | 53 | **undetermined** | [OQ-004](12-open-questions.md#oq-004) | not assigned |
| `scheduler` | 23 | `platform-task` | consolidate | not assigned |
| `util` (70) + `main-module` (223) | 293 | distributed across the platform | **break down** | not assigned |
| `werp_jsf` | 1,223 | **unknown** | [OQ-012](12-open-questions.md#oq-012) | not assigned |

The four rows marked "consolidate" are where the risk is concentrated:
divergences between duplicated implementations are discovered only when one tries
to merge them ([R-10](11-risks.md#r-10)).

## Breakdown priorities

The classes requiring a design decision before the others — by descending impact:

| Class | Lines / injections | Why first |
|---|---|---|
| `PayrollService` | 7,598 | people's money; special cases accumulated over 12 years |
| `ReferenceRestController` | 1,934 / 51 | it holds CRM, HR and sales endpoints inside the reference-data domain — breaking it down sets the boundaries of several domains at once |
| `FinanceServiceDms` | 5,629 / 21 | accounting |
| `FinanceReportRestController` | 5,366 / 20 | reports, the underestimated part |
| `ContractController` | 3,775 / 38 | seven foreign domains in one class |
| `ServiceTableService` | 3,984 / 48 | the largest number of dependencies |
| `util` + `main-module` | 293 files | until they are broken down, the platform is not designed |

`ReferenceRestController` is broken down **first among the controllers**: it
serves the reference domain D1 and at the same time shows where the real
boundaries between domains run.

The full class map of a domain — [map/](map/README.md); the sample is
[map/D1-reference.md](map/D1-reference.md#classes).
