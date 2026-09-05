---
id: PROD-05-REGISTRY
title: Endpoint registry
status: draft
---

# Endpoint registry

**Fourteen sections, 132 resources, ~550 endpoints.** One section per domain,
plus the platform's own and the mobile compatibility layer.

The rules every endpoint obeys: [rules/](rules/README.md).
How they are enforced: [checks.md](checks.md).

| Section | Domain | Resources | Endpoints | State | Specification |
|---|---|---:|---:|---|---|
| `/api/v1/platform` | D0 Platform | 10 | ~45 | outlined | — |
| `/api/v1/reference` | D1 Reference data | 12 | **48** | **designed** | [spec/D1-reference.md](../spec/D1-reference.md#endpoints) |
| `/api/v1/party` | D2 Counterparties | 5 | ~28 | drafted | — |
| `/api/v1/hr` | D3 Personnel | 11 | **63** | **designed** | [spec/D3-hr.md](../spec/D3-hr.md#endpoints) |
| `/api/v1/contract` | D4 Contracts and sales | 8 | ~55 | drafted | — |
| `/api/v1/accounting` | D5 Accounting and finance | 15 | **73** | **designed** | [spec/D5-accounting.md](../spec/D5-accounting.md#endpoints) |
| `/api/v1/payroll` | D6 Compensation calculation | 4 | ~28 | drafted | — |
| `/api/v1/inventory` | D7 Warehouse and logistics | 8 | ~52 | drafted | — |
| `/api/v1/service` | D8 Field service | 9 | ~60 | drafted | — |
| `/api/v1/crm` | D9 CRM and call centre | 6 | ~42 | drafted | — |
| `/api/v1/docflow` | D10 Document workflow | 4 | ~22 | drafted | — |
| `/api/v1/legal` | D11 Legal | 3 | ~14 | declared | — |
| `/api/v1/tasks` | D12 Tasks and communications | 3 | ~20 | drafted | — |
| `/api/mobile` | the compatibility layer | — | fixed | declared | [transition/03-api-mapping.md](../../transition/03-api-mapping.md#part-iii-the-compatibility-layer) |

**The three exact figures come from written specifications.** The rest are
derived from the resources below — one to two reads, one to two writes and the
state transitions the schema's `state` column names — and they will move when the
domain is designed. They are a planning figure, not a commitment; their origin
and the expected reduction against what exists today are in
[transition/03-api-mapping.md](../../transition/03-api-mapping.md#expected-reduction).

`/api/v1/inventory` was `/api/v1/logistics` when this registry was first drawn.
The section, the module and the schema now share one name.

---

## The resources, section by section

A resource is a noun with its own path. The count matters because **a resource is
also a controller** ([04-backend/modules/](../04-backend/modules/README.md)) and
usually **a list page plus a form page**
([06-frontend/registry.md](../06-frontend/registry.md)) — the three registries
move together.

### `/api/v1/platform` — D0

`users`, `api-clients`, `roles`, `permissions`, `access-scopes`, `files`,
`background-jobs`, `notifications`, `reports`, `settings`

Reachable only by an administrator. `permissions` is read-only: the list is seed
data generated from the domain specifications, not something an administrator
composes.

### `/api/v1/reference` — D1 · designed

`companies`, `branches`, `warehouses`, `countries`, `regions`, `cities`,
`currencies`, `exchange-rates`, `products`, `product-categories`, `units`,
`lists`

**Twelve resources, one per thing another domain needs to name.** `lists` serves
every standard enumeration in the system through one path
(`/lists/{code}/items`) — thirty small reference lists do not get thirty
resources.

There is no `POST /exchange-rates/{id}` and no `PUT`: a rate is immutable.

### `/api/v1/party` — D2 · drafted

`parties`, `addresses`, `phones`, `emails`, `credit-ratings`

The narrowest section relative to its importance. `parties` carries the merge
operation (`POST /parties/{id}/merge`), which is the only place in the system
where two records become one — and it forwards rather than deletes.

### `/api/v1/hr` — D3 · designed

`org-units`, `jobs`, `positions`, `employees`, `employments`, `absences`,
`time-sheets`, `courses`, `certifications`, `expenses`, `reports`

**`asOf` is a parameter on every list that reads a period-dated table.** Its
default is today; its presence is what makes the history reachable from the API
rather than only from the database.

There is no `DELETE` on an employment and no `PUT` on a compensation row.
Personnel history is not editable through the API, and the absence of those two
routes is where that is stated.

### `/api/v1/contract` — D4 · drafted

`contracts`, `contract-types`, `payment-schedules`, `payment-templates`,
`price-lists`, `promotions`, `sales-plans`, `signature-requests`

A re-schedule is `POST /payment-schedules` producing a new revision, not a `PUT`
on the existing one.

### `/api/v1/accounting` — D5 · designed

`accounts`, `fiscal-years`, `fiscal-periods`, `journals`, `entries`,
`posting-rules`, `open-items`, `invoices`, `payments`, `bank-accounts`,
`bank-statements`, `tax-codes`, `budgets`, `statement-definitions`, `reports`

**There is no `PUT /entries/{id}` and no `DELETE`.** The absence of those two
routes is the API's statement of the domain's central rule: a posted entry is
never edited, and a correction is a reversal.

`POST /posting-rules/{id}/simulation` shows the entry a given document *would*
produce without posting it — so a change of accounting policy is checked by the
accountant, on a real document, before it is applied.

### `/api/v1/payroll` — D6 · drafted

`components`, `rates`, `inputs`, `runs`

Four resources for a calculation that is today one class of 7,598 lines. The
smallness is the design: a new earning or deduction is a row in `components`, not
an endpoint.

### `/api/v1/inventory` — D7 · drafted

`stock-items`, `movements`, `balances`, `stock-documents`, `purchase-orders`,
`stocktakes`, `accountable-items`, `stock-limits`

`movements` is read-only from outside: a movement is produced by posting a
`stock-document`, a `purchase-order` receipt or a `stocktake`, never by a direct
write. `balances` is read-only entirely — it is derived.

### `/api/v1/service` — D8 · drafted

`installed-units`, `service-requests`, `appointments`, `service-orders`,
`maintenance-programs`, `maintenance-plans`, `packages`, `spare-parts`,
`upgrade-offers`

`maintenance-programs` carries the positions as a nested resource
(`/maintenance-programs/{id}/positions`), which is what makes a seventh
maintenance position a `POST` by a service manager rather than a release.

`GET /maintenance-plans/slots?state=OVERDUE` is one query over every product
line, every unit and every branch at once — the query the whole domain design
exists to make possible.

### `/api/v1/crm` — D9 · drafted

`cases`, `activities`, `referrals`, `checklists`, `kpis`, `reports`

One `activities` resource for calls, demonstrations, visits and meetings.
A counterparty's history is `GET /activities?partyId=…`, one request.

### `/api/v1/docflow` — D10 · drafted

`document-types`, `routes`, `documents`, `templates`

Four resources serving thirteen domains. Another domain does not expose approval
endpoints of its own; it links to a `document`.

### `/api/v1/legal` — D11 · declared

`court-cases`, `claims`, `recovery-actions`

### `/api/v1/tasks` — D12 · drafted

`tasks`, `task-categories`, `messages`

Notifications to people **outside** the system are not here — they are
`/api/v1/platform/notifications`.

---

## What every endpoint must have

Checked by the specification linter; without all of these an endpoint does not
pass CI ([checks.md](checks.md)):

- an `operationId` — unique across the whole specification, in `camelCase`;
- the required permission
  ([NC-12](../../docs/01-principles/01-no-compromise.md#nc-12));
- a description;
- request and response schemas — as references to shared components, never
  inline;
- the list of error codes the endpoint can return, each of which must exist in
  the owning domain's error-code list;
- an example request and an example response;
- for a list — the standard pagination, sorting and search parameters, and no
  others of its own invention.

## How a section becomes `designed`

In the design step of its domain's route
([transition/plan/03-phase-2-domains.md](../../transition/plan/03-phase-2-domains.md)),
and not before its schema is designed: an endpoint returning fields nobody has
confirmed is a contract that will break.

The order is therefore fixed: **schema → endpoints → pages**, per domain, with
the specification written before any code
([ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md)).
