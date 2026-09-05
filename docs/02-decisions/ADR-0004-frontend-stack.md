---
id: ADR-0004
title: Frontend stack
status: Proposed
date: 2026-09-03
deadline: gate G1
---

# ADR-0004. Frontend stack

## Context

The current frontend is 369,214 lines of JavaScript without a single TypeScript
file, React 16.11 on `react-scripts` 3.4.0 (Create React App is out of support),
Redux 3.7 + `redux-form` 7.2 + `react-router` 4. 273 class components coexist
with 2,185 uses of `useState`; there are 189 uses of lifecycle methods declared
deprecated. Three libraries each for trees and Excel export, two each for
charts, dates and decimal arithmetic
([P-11](../00-context/02-pain-points.md#p-11-the-frontend--three-libraries-for-every-job)).

An ERP frontend is mostly tables, forms, searchable reference lists, reports and
exports. There is little exotica and a lot of volume: ~1,300 endpoints on the
backend produce a comparable number of screens.

## Decision (proposed)

1. **TypeScript in strict mode.** Not optional. 369k lines of untyped code are
   the direct reason the frontend cannot be refactored.
2. **React, current version**, functional components only. React is chosen not
   out of inertia but because the whole team and the whole codebase are already
   on it — retraining onto another framework buys nothing that would repay the
   cost.
3. **One build tool** with fast rebuilds; the built artefact receives its
   configuration at runtime, not at build time (NC-11).
4. **Separation of server and client state.** Server state — a request-caching
   library; client state — a minimal local store. Redux in its current form (a
   global store for everything, API responses included) is not reproduced.
5. **One form library with schema-based validation**, shared with the backend
   (see [ADR-0005](ADR-0005-contract-first-api.md)).
6. **One table library** — for data, not decoration: server-side pagination,
   sorting, filtering, pinned columns, virtualization. Every list in the system
   looks and behaves the same way.
7. **One design system**, one component library, one date library, one charting
   library, one way of exporting to Excel — the registry of allowed libraries is
   maintained explicitly (NC-14).
8. **The API client is generated from the specification** — hand-written HTTP
   wrappers do not exist ([ADR-0005](ADR-0005-contract-first-api.md)).

## What is deliberately not carried over

- A global store for API responses.
- Duplicated sections (`crm` and `crm2021`, `callcenter` and `crm/callCenter`).
- Links into the legacy interface — there will be none, because there will be no
  legacy ([NC-07](../01-principles/01-no-compromise.md#nc-07)).
- A 2,695-line routes file: routes are declared next to their sections.
- Test-data generators in the production dependencies.

## Consequences

- Rewriting the frontend in full is Phase 3, comparable in size to the backend.
  Automated JS → TS conversion is not considered: it would carry the architecture
  over along with the code.
- A design system is required before mass screen development starts, otherwise
  1,300 screens will look like 1,300 different applications — exactly as they do
  now.
- Multilingual support (ru / en / tr, ~1,700 messages) is carried over together
  with a rework of the keys → [ADR-0010](ADR-0010-i18n.md).
- Accessibility and keyboard operation are a requirement on the design system,
  not a task for individual screens: in an ERP the operators work from the
  keyboard, and it affects their speed directly.

## Open questions

- Is support for offline operation and for tablets needed (warehouse, field
  service)? The answer determines the choice between an ordinary web application
  and an application with an offline store —
  [OQ-008](../../transition/12-open-questions.md).
- The minimum supported browsers —
  [OQ-008](../../transition/12-open-questions.md).
