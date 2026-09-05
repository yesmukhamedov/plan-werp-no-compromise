---
id: TRANS-PLAN-04
title: Phase 3 — Frontend
status: draft
---

# Phase 3 — Frontend

**Goal:** implement all the screens of the new system.

Runs **in parallel with [Phase 2](03-phase-2-domains.md)**. The parallelism is
possible only thanks to contract-first: the frontend works against a stub
generated from the specification and meets the real backend when it is already
working
([ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md)).

## Volume

The 369,214 lines of the current frontend are **not an estimate of the new
work's volume**. They include: duplicated sections (`crm` and `crm2021`, two call
centres), class-component boilerplate, hand-written HTTP wrappers (which are now
generated), and logic that moves to the server (report generation —
[ADR-0009](../../docs/02-decisions/ADR-0009-reporting-and-exports.md)).

The real unit of estimation is a **screen**, not a line. The number of screens is
determined in Phase 0, together with the scenario registry and the report
inventory.

## Order

```
the design system (completion)
        │
        ├─► the application skeleton: navigation, login, permissions, errors, localization
        │
        ├─► the standard forms: list, card, form, selection from a reference list,
        │   file upload, running a report
        │
        └─► screens by domain — in the same order as Phase 2
```

### The design system — first and blocking

Started in Phase 1, finished here. Mass screen development does not begin before
it.

Contents: the palette, the typography, the grid, the input components, **one**
data table, **one** form, dialogs, notifications, loading and error states,
navigation, keyboard operation, accessibility.

The requirement on the table: server-side pagination, sorting, filtering, pinned
columns, virtualization, export through the server. It is the only table in the
system ([NC-14](../../docs/01-principles/01-no-compromise.md#nc-14)).

### The standard forms — second and decisive

In an ERP the screens are of the same few kinds. If the five basic forms are done
well, the rest are assembled from them quickly; if badly, every screen is written
from scratch, as it is today.

| Form | What it settles |
|---|---|
| List | pagination, filters, sorting, bulk actions, export |
| Card | viewing, tabs, related entities, change history |
| Input form | validation against the schema from the contract, saving, server errors |
| Selection from a reference list | search, lazy loading, creation on the fly |
| Running a report | parameters, synchronous and asynchronous modes, delivery of the result |

These five forms are in effect the quality budget of the whole frontend. One does
not cut corners on them.

### Keyboard operation — a requirement, not an improvement

ERP operators work from the keyboard: entering data, moving between fields,
saving, searching. Their speed depends directly on whether they have to reach for
the mouse. The requirement is built into the design system rather than added at
the end.

## Rules of the phase

- **TypeScript in strict mode**, functional components. No automated conversion
  of the old JS is performed
  ([ADR-0004](../../docs/02-decisions/ADR-0004-frontend-stack.md)).
- **The API client is generated** from the specification; there are no
  hand-written HTTP wrappers.
- **Server state is separated from client state**; there is no global store for
  API responses.
- **No configuration in the bundle** — the addresses arrive at runtime
  ([NC-11](../../docs/01-principles/01-no-compromise.md#nc-11)).
- **Zero report generation in the browser**
  ([ADR-0009](../../docs/02-decisions/ADR-0009-reporting-and-exports.md)).
- **Zero links into the legacy** — there will be no legacy.
- The registry of allowed libraries, with a check in CI.
- Localization in all three languages from the very first screen; a missing
  translation breaks CI
  ([ADR-0010](../../docs/02-decisions/ADR-0010-i18n.md)).

## Testing

| Level | What it verifies |
|---|---|
| Component tests | the behaviour of the design-system components |
| Screen tests | a scenario on a screen against the API stub |
| End-to-end tests | scenarios from the registry, end to end through the real backend |
| Visual regression | the design system does not break unnoticed |
| Accessibility | an automated check on every screen |

## User acceptance

Every two weeks — a demonstration on the pre-production environment
([00-roadmap.md](00-roadmap.md#cadence)). Under a big bang this is the only
channel of user feedback for the whole project.

Users' comments on the interface are the cheapest feedback one can get, and the
most expensive if obtained after the cutover.

## Risks of the phase

| Risk | What to do |
|---|---|
| The design system falls behind and blocks everything | start it in Phase 1; a dedicated owner |
| The number of screens is underestimated | count the screens in Phase 0 rather than estimating from lines |
| The stub diverges from the real backend | the stub is generated from the same specification; a divergence is impossible by construction — but contract tests are mandatory |
| Users reject the new interface after the cutover | demonstrations every two weeks from the very first screen |
| The screens copy the old interface with all its problems | the old interface is a source of requirements, not a model to copy; the same rule as in Phase 2 |

## Completion criteria

- All the screens from the registry are implemented or explicitly excluded.
- The end-to-end tests cover the scenario registry.
- User acceptance has passed for all the domains.
- The frontend's figures meet the NFRs
  ([product/07-nfr.md](../../product/07-nfr.md)).
