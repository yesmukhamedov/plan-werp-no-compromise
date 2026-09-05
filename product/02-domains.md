---
id: PROD-02
title: Domain map
status: draft
---

# Domain map

**The single source of truth about what the system consists of.** A code module,
a schema in the database, a section of the API specification, an owner and a
section of the interface are determined by this map and by nothing else. A new
module appears only through an ADR
([NC-06](../docs/01-principles/01-no-compromise.md#nc-06)).

The map is a proposal. It **must be verified and refined together with the
business owners** before gate G1: domain boundaries are product knowledge, not
the result of reading packages.

---

## How it was derived

The 14 subject areas of `core` plus the separate modules and repositories,
consolidated with the duplication taken into account
([P-04](../docs/00-context/02-pain-points.md#p-04-domains-implemented-twice)):

| Current placement | Target domain |
|---|---|
| `core/general`, `auth-server`, `core/dit` (ABAC), `main-module` (permissions) | Platform + Access |
| `core/reference` + `core/mreference` | Reference data |
| `core/hr` | Personnel |
| `core/marketing` | Contracts and sales |
| `core/accounting` (+ `service/maccounting`) | Accounting and finance |
| `core/accounting` (payroll calculation) | Compensation calculation |
| `core/logistics` | Warehouse and logistics |
| `core/service` + the `service` module | Field service |
| CRM, call centre (four sources) | CRM and call centre |
| `core/documents` | Document workflow |
| `core/law_department` | Legal |
| `core/dit` (tasks, messages, SMS) | Internal tasks and communications |
| `core/aes` | needs clarification — [OQ-004](../transition/12-open-questions.md) |
| `core/newdev` | needs clarification — [OQ-004](../transition/12-open-questions.md) |
| `scheduler` | not a domain — the platform's background-job subsystem |
| `util` | not a domain — dissolves into the platform |

Four domains collapse out of eight existing implementations. **That is the main
structural gain of the rewrite**, and it is the reason the new system is smaller
than the old one rather than merely tidier.

## Domains

| # | Domain | Responsible for | Depends on | Owner |
|---|---|---|---|---|
| D0 | **Platform** | access, audit, reports, files, notifications, numbering, background jobs, observability | — | not assigned |
| D1 | **Reference data** | companies, branches, countries, currencies, categories, goods, units of measure | D0 | not assigned |
| D2 | **Counterparties** | customers, addresses, phone numbers, communication channels, creditworthiness | D0, D1 | not assigned |
| D3 | **Personnel** | structure, establishment, employments, absence, time, training | D0, D1, D2 | not assigned |
| D4 | **Contracts and sales** | contracts, price lists, terms, payment schedules, promotions | D1, D2, D3 | not assigned |
| D5 | **Accounting and finance** | the ledger, invoices, payments, banking, budgets, statements | D1, D2, D4 | not assigned |
| D6 | **Compensation calculation** | payroll components, rates, runs, payslips | D3, D5 | not assigned |
| D7 | **Warehouse and logistics** | stock, movements, balances, documents, purchasing, counts | D1, D2, D5 | not assigned |
| D8 | **Field service** | requests, orders, installed equipment, maintenance programs and plans | D1, D2, D4, D7 | not assigned |
| D9 | **CRM and call centre** | cases, interactions, referrals, checklists, indicators | D1, D2, D4 | not assigned |
| D10 | **Document workflow** | internal documents of every kind, routes, approvals | D0, D3 | not assigned |
| D11 | **Legal** | court cases, claims, recovery | D2, D4, D5 | not assigned |
| D12 | **Internal tasks and communications** | tasks, messages | D0, D3 | not assigned |

**Every domain needs a named owner before gate G1.** A domain with no owner has
nobody who can close its open questions, and every specification in this plan
ends with a list of them.

## What each domain has been designed into

The four registries, one row per domain, so that the size and state of the whole
system is visible in one place.

| Domain | Schema · tables | Module · classes | API · endpoints | Interface · pages | State |
|---|---|---|---|---|---|
| D0 | [platform](03-database/schemas/platform.md) + [audit](03-database/schemas/audit.md) · 22 | `platform-*` · ~120 | `/platform` · ~45 | `admin` · ~16 | drafted |
| D1 | [reference](03-database/schemas/reference.md) · 20 | `reference` · ~90 | `/reference` · 48 | `reference` · 14 | **designed** |
| D2 | [party](03-database/schemas/party.md) · 16 | `party` · ~60 | `/party` · ~28 | `party` · ~9 | drafted |
| D3 | [hr](03-database/schemas/hr.md) · 23 | `hr` · ~160 | `/hr` · 63 | `hr` · 19 | **designed** |
| D4 | [contract](03-database/schemas/contract.md) · 17 | `contract` · ~150 | `/contract` · ~55 | `contract` · ~15 | drafted |
| D5 | [accounting](03-database/schemas/accounting.md) · 34 | `accounting` · ~200 | `/accounting` · 73 | `accounting` · 23 | **designed** |
| D6 | [payroll](03-database/schemas/payroll.md) · 7 | `payroll` · ~90 | `/payroll` · ~28 | `payroll` · ~8 | drafted |
| D7 | [inventory](03-database/schemas/inventory.md) · 15 | `inventory` · ~170 | `/inventory` · ~52 | `inventory` · ~15 | drafted |
| D8 | [service](03-database/schemas/service.md) · 18 | `service` · ~200 | `/service` · ~60 | `service` · ~18 | drafted |
| D9 | [crm](03-database/schemas/crm.md) · 14 | `crm` · ~130 | `/crm` · ~42 | `crm` · ~12 | drafted |
| D10 | [docflow](03-database/schemas/docflow.md) · 8 | `docflow` · ~50 | `/docflow` · ~22 | `docflow` · ~8 | drafted |
| D11 | [legal](03-database/schemas/legal.md) · 4 | `legal` · ~25 | `/legal` · ~14 | `legal` · ~6 | declared |
| D12 | [tasks](03-database/schemas/tasks.md) · 6 | `tasks` · ~55 | `/tasks` · ~20 | `tasks` · ~6 | drafted |

**One name across all four columns.** A domain's schema, module, API section and
interface section share it, and a divergence is a build failure
([BE-28](04-backend/checks.md)).

## Dependency graph

```
                          D0 Platform
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
        D1 Reference       D12 Tasks      D10 Documents
              │
              ▼
       D2 Counterparties
              │
       ┌──────┴───────┐
       ▼              ▼
  D3 Personnel   D4 Contracts
       │              │
       │      ┌───────┼────────┬──────────┐
       │      ▼       ▼        ▼          ▼
       │  D5 Finance  D9 CRM  D11 Legal  D8 Service
       │      │                          ▲
       ▼      ▼                          │
   D6 Compensation         D7 Warehouse ─┘
```

**The graph determines the development order in
[Phase 2](../transition/plan/03-phase-2-domains.md).** Under a big bang the order
is determined by dependencies rather than by business priority: there are no
intermediate releases, so "the most valuable thing first" makes no sense.

**D2 is the critical path.** Five domains point at it, three of them already have
designed schemas, and it is the only one of the shared-record domains still
drafted — which makes moving it to `designed` the highest-value next piece of
design work in the plan.

## Boundary rules

Stated here, enforced by the architecture-rule test `[STACK]`:

| # | Rule | Check |
|---|---|---|
| DOM-01 | A domain reaches another domain **only** through its public interface or through an event | [BE-18](04-backend/checks.md) |
| DOM-02 | A domain reads **only** its own schema in the database | [BE-12](04-backend/checks.md), [DB-09](03-database/checks.md) |
| DOM-03 | References to another domain's entities are by identifier, without foreign keys across the boundary | [DB-09](03-database/checks.md) |
| DOM-04 | There are no cyclic dependencies between domains | [BE-20](04-backend/checks.md) |
| DOM-05 | A domain does not depend on a domain "below" it in the graph | [BE-21](04-backend/checks.md) |
| DOM-06 | The platform depends on **no** domain; the reverse is allowed | [BE-22](04-backend/checks.md) |
| DOM-07 | A domain's schema, module, API section and interface section share one name | [BE-28](04-backend/checks.md) |

**DOM-04 is a design signal, not a rule to work around.** A cycle appearing means
the boundary is drawn incorrectly; it is fixed by moving a responsibility or by
replacing a synchronous call with an event — never by weakening the rule.

## The boundaries that are already load-bearing

Three boundaries are relied on so heavily by the designed domains that changing
them would invalidate written specifications. They are worth confirming first.

| Boundary | The rule it carries | Where it is stated |
|---|---|---|
| D3 ↔ D6 | **D3 says what was agreed, D6 says what was calculated.** D6 reads `hr.compensation` and never writes it | [D3](spec/D3-hr.md#purpose-and-boundaries) |
| D5 ↔ everyone | **Every other domain proposes a financial fact; D5 posts it.** No other domain knows an account number | [D5](spec/D5-accounting.md#purpose-and-boundaries) |
| D2 ↔ everyone | **A person or organization exists once.** No document carries a copied name, address or telephone number | [party schema](03-database/schemas/party.md) |

## What must be confirmed with the business before G1

| # | Question | Why it matters | What changes if the answer differs |
|---|---|---|---|
| DOM-Q1 | Is the boundary between D4 (contracts) and D5 (accounting) correct? | today `ContractController` lives in `marketing` but works with invoices and journal entries — the boundary is drawn along the code, not along the meaning | `payment_schedule_entry` ↔ `open_item`, and every ageing report |
| DOM-Q2 | Is D6 a separate domain or part of D5? | payroll calculation is 7,598 lines in a single class inside `accounting`, while logically it sits closer to personnel | one schema and one module disappear or move |
| DOM-Q3 | What are `aes` and `newdev`? | 5,778 lines with no clear purpose — [OQ-004](../transition/12-open-questions.md) | possibly a fourteenth domain |
| DOM-Q4 | Are D10 and D11 needed in the new system? | 3,573 lines in total; an off-the-shelf solution or dropping them may be cheaper | 12 tables, 2 modules, ~36 endpoints |
| DOM-Q5 | Is it true that D8 and D9 are different domains? | today they are intertwined on the frontend (`callcenter` and `crm/callCenter`) | 32 tables merge or stay apart |
| DOM-Q6 | Who owns each domain? | every specification ends with questions only an owner can close | the whole Phase 2 schedule |

The answers change the estimates. Until they are obtained, the Phase 2 estimates
are given as a range ([transition/10-estimates.md](../transition/10-estimates.md)).

DOM-Q6 is the one that blocks the others: the remaining five are questions *for*
owners, and there are none yet.
