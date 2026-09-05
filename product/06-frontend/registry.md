---
id: PROD-06-REGISTRY
title: Page registry
status: draft
---

# Page registry

**Fourteen sections, ~170 pages.** One section per domain plus the
administrator's, mirroring `pages/<domain>` in the source tree one-to-one
([rule 1](rules/01-application-structure.md)).

The rules every page obeys: [rules/](rules/README.md).
The components it is built from: [design-system.md](design-system.md).
How the rules are enforced: [checks.md](checks.md).

| Section | Domain | Pages | Of which L / F / C / R / D | State | Specification |
|---|---|---:|---|---|---|
| `admin` | D0 Platform | ~16 | 8 / 6 / 0 / 1 / 1 | outlined | — |
| `reference` | D1 Reference data | **14** | 9 / 5 / 0 / 0 / 0 | **designed** | [spec/D1-reference.md](../spec/D1-reference.md#pages) |
| `party` | D2 Counterparties | ~9 | 4 / 3 / 2 / 0 / 0 | drafted | — |
| `hr` | D3 Personnel | **19** | 10 / 6 / 1 / 1 / 1 | **designed** | [spec/D3-hr.md](../spec/D3-hr.md#pages) |
| `contract` | D4 Contracts and sales | ~15 | 7 / 5 / 2 / 1 / 0 | drafted | — |
| `accounting` | D5 Accounting and finance | **23** | 11 / 9 / 1 / 1 / 1 | **designed** | [spec/D5-accounting.md](../spec/D5-accounting.md#pages) |
| `payroll` | D6 Compensation calculation | ~8 | 4 / 2 / 1 / 1 / 0 | drafted | — |
| `inventory` | D7 Warehouse and logistics | ~15 | 8 / 5 / 1 / 1 / 0 | drafted | — |
| `service` | D8 Field service | ~18 | 9 / 6 / 1 / 1 / 1 | drafted | — |
| `crm` | D9 CRM and call centre | ~12 | 6 / 3 / 1 / 1 / 1 | drafted | — |
| `docflow` | D10 Document workflow | ~8 | 4 / 3 / 1 / 0 / 0 | drafted | — |
| `legal` | D11 Legal | ~6 | 3 / 2 / 1 / 0 / 0 | declared | — |
| `tasks` | D12 Tasks and communications | ~6 | 3 / 2 / 0 / 0 / 1 | drafted | — |

## The designed domains came out three times smaller than the estimate

This is the registry's most useful number, and it should be read carefully.

| Domain | Estimated before design | Designed | Ratio |
|---|---:|---:|---:|
| D1 Reference data | 14 | 14 | 1.0 |
| D3 Personnel | ~55 | 19 | 0.35 |
| D5 Accounting and finance | ~70 | 23 | 0.33 |

Two things account for the difference, and both are design decisions rather than
optimism:

1. **One screen serves a family.** D1's `REF-LST-L` serves *every* standard
   enumeration in the system; D3's `HR-EMT-A` is one action form for hiring,
   transfer, promotion, suspension and termination; D5's budget grid serves every
   budget kind. Each replaces the five to fifteen near-identical screens an
   estimate assumes.
2. **A grid whose rows are reference data does not grow.** D3's time sheet renders
   `TIME_CODE` rows; a thirteenth time code adds a row, not a screen
   ([03-database rule 14.3](../03-database/rules/14-patterns.md#143-a-declaration-and-its-slots)).

**The caveat matters as much as the finding.** These counts are derived from the
schemas and the resources — they cover the pages the *data model* implies. The
[scenario registry](../../backlog/EPIC-011-scenario-registry.md) may add pages
that no schema implies: an operational monitor, a multi-step wizard, a
reconciliation workbench. Until it exists, treat ~170 as a floor rather than a
forecast, and see
[transition/04-frontend-mapping.md](../../transition/04-frontend-mapping.md#the-scale-and-its-uncertainty)
for why it cannot be estimated any other way.

---

## The sections

### `admin` — D0

Users, roles, permissions, access scopes, files, background jobs, notification
templates, report definitions, settings.

The permissions screen is **read-only**: the list is seed data generated from the
domain specifications. What an administrator composes is a `role`, not a
permission.

### `reference` — D1 · designed

Fourteen pages, and one of them carries the domain's whole enumeration mechanism:
`REF-LST-L` at `/reference/lists/:code?` shows the list of reference lists on the
left and the items of the selected one on the right. **Thirty small reference
lists do not get thirty screens.**

This section also contributes three components used by every other section —
`BranchLookup`, `ProductLookup`, `CurrencyAmountInput` — which live in
`features/`, not in `pages/reference`: the page does not own them.

### `party` — D2 · drafted

Counterparty list and card, address, phone and e-mail management, the merge
screen, credit ratings.

The counterparty card is the system's most-opened screen after the contract card,
and it is the one that proves the D2 design: it shows contracts, cases, service
history and open items **by reference**, never by copied columns.

### `hr` — D3 · designed

Nineteen pages, two of which carry the design:

- `HR-EMT-A` — **one** action form for hire, transfer, promotion, suspension and
  termination. Which fields appear comes from the action chosen. Five separate
  order screens would be five places to get the period arithmetic wrong.
- `HR-TSH-F` — a grid whose rows are `TIME_CODE` reference rows. A thirteenth
  time code adds a row and nothing else.

Plus `PeriodTimeline`, a component that exists because periods are only as useful
as the user's ability to see them: a gap between two assignments is invisible in
a table and obvious on a timeline.

### `contract` — D4 · drafted

Contract list, card and form; the payment-schedule screen with its revision
history; price lists; promotions; sales plans; the signing flow.

The schedule screen shows **revisions side by side**, because the question it
exists to answer is "what was the customer told, and when did it change".

### `accounting` — D5 · designed

Twenty-three pages, and the two that matter most are not the ones an estimate
would predict:

- `ACC-RUL-F` — the posting-rule form **with a live simulation**. The accountant
  sees the entry a real document would produce before the rule is applied. That
  is what makes a data-driven posting engine trustworthy to the people who sign
  the result.
- `ACC-PER-C` — the period-close checklist, step by step, because closing a
  period is a procedure and a procedure done from memory is done differently each
  month.

### `payroll` — D6 · drafted

Components, rates, inputs, runs, and the payslip. The payslip is a **type R
page**: it is a report, generated on the server, not a screen assembled in the
browser.

### `inventory` — D7 · drafted

Stock items, movements, balances, stock documents, purchase orders, stocktakes,
accountable items, limits.

`movements` and `balances` are read-only screens. A movement is produced by
posting a document, never by editing a row — and the interface says so by
offering no edit action.

### `service` — D8 · drafted

Installed units, service requests, the dispatch board, service orders,
maintenance programs and their positions, maintenance plans, packages, spare
parts, upgrade offers.

The dispatch board is the section's one genuinely bespoke screen — a day, a set of
technicians, a set of appointments, dragged between them — and it carries a
rationale in the domain specification because it is none of the five types.

`GET /maintenance-plans/slots?state=OVERDUE` backs a single overdue-maintenance
list across every product line at once. **There is no screen per product line**,
and that is the visible payoff of the schema design.

### `crm` — D9 · drafted

Cases, the activity feed, referrals, checklists, key indicators, the call-centre
operator screen.

The operator screen is the second bespoke one: an inbound call resolves a number
to a party in one query — because `party.phone` holds one row per number in the
whole system — and opens the case, the contract and the service history together.

### `docflow` — D10 · drafted

Document types, routes and their steps, the document list, the approval inbox.

**One approval inbox for the whole system.** A personnel order, a purchase
authorization and a discount above a threshold arrive in the same place, in one
list, with one set of actions.

### `legal` — D11 · declared

Court cases, claims, recovery actions.

### `tasks` — D12 · drafted

Tasks, task categories, messages, the personal dashboard.

---

## What every page must have in its specification

Checked at design review and, where machine-checkable, in CI
([checks.md](checks.md)):

- a code and a route;
- a type — L, F, C, R or D — or a rationale for being none of them;
- the required permission;
- the scenarios from the [registry](../../backlog/EPIC-011-scenario-registry.md)
  that it serves;
- the endpoints it uses, by `operationId`;
- the design-system components it is assembled from;
- the four states: loading, empty, error, no permission;
- its keyboard path — how the whole page is operated without a mouse.

The last two are the ones that get skipped, and they are the ones a user
encounters on a bad day and every day respectively.
