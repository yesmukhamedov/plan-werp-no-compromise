---
id: PROD-06
title: Frontend
status: draft
---

# Frontend

The web application: which pages it consists of and which components those pages
are assembled from. The stack —
[ADR-0004](../../docs/02-decisions/ADR-0004-frontend-stack.md).

| Level | Where | Answers |
|---|---|---|
| **0. The map** | this file | what the interface is made of, and what is uniform across it |
| **1. The rules** | [rules/](rules/README.md) | how **any** page is structured, typed, secured and localized |
| **2. The design system** | [design-system.md](design-system.md) | the components every page is built from |
| **3. The registry** | [registry.md](registry.md) | which sections and pages exist |
| | [../spec/](../spec/README.md) | the pages of a designed domain, named one by one |
| | [checks.md](checks.md) | the checks that enforce the rules |

---

## The interface in one page

An ERP interface is not an arbitrary set of screens. It is **five page types
repeated a few hundred times**, and treating it that way is what makes ~400
screens buildable by a small team and learnable by a user in a day.

| Type | What it is | Share | Rule |
|---|---|---:|---|
| **L** — list | filter, table, row actions, export | ~55% | [2](rules/02-page-types.md) |
| **F** — form | create and edit, validated against the API schema | ~25% | [2](rules/02-page-types.md) |
| **C** — card | one entity: header, tabs, history, available actions | ~10% | [2](rules/02-page-types.md) |
| **R** — report | parameters → run → result, computed on the server | ~8% | [2](rules/02-page-types.md) |
| **D** — dashboard | summary figures and charts, read-only | ~2% | [2](rules/02-page-types.md) |

**A page that is none of the five is an exception requiring a rationale**, and
the rationale goes in the domain specification. That is not bureaucracy: every
bespoke screen is a screen that has to be designed, tested, made accessible and
made keyboard-operable on its own.

## What is uniform, and why each one matters

| Uniform | Consequence if it were not |
|---|---|
| One `DataTable` in the whole system | column settings, virtualization, server-side sorting and pinned columns get reimplemented per team, and three of the five implementations are slow |
| One `Form` | validation drifts from the API schema, and the server rejects what the form accepted |
| List state lives **in the URL** | a filtered list cannot be sent to a colleague, and the browser's back button loses the user's place |
| The menu is built from the server's permissions | a static menu shows items that 403 on click |
| Every text comes from the message system | a fourth language costs a release instead of a translation file |
| Every page defines four states — loading, empty, error, no permission | the error state is the one nobody builds, and the user gets a blank screen with no `traceId` to quote |
| The API client is **generated** | a hand-written wrapper drifts from the contract silently |

## Keyboard operation is a requirement

ERP operators work from the keyboard, and it directly determines how fast they
work. **No scenario may require a mouse**, and that is verified at acceptance
rather than hoped for — see
[design-system.md](design-system.md#keyboard-operation).

This is the requirement most likely to be quietly dropped under schedule
pressure, because it is invisible in a demonstration and obvious to the person
who does the job eight hours a day.

## What the frontend deliberately does not have

| Will not exist | Why |
|---|---|
| A second table, form or date-picker component | one library per job ([NC-14](../../docs/01-principles/01-no-compromise.md#nc-14)); a second one comes only through an ADR |
| A component named `TableV2`, `NewForm`, `CustomTable2` | the name says a migration was abandoned halfway |
| A hand-written HTTP wrapper | `shared/api` is generated from the specification |
| A global store holding API responses | a request cache is not application state; mixing them is how a stale screen happens |
| Report generation in the browser | [ADR-0009](../../docs/02-decisions/ADR-0009-reporting-and-exports.md) |
| A string literal in a component | [ADR-0010](../../docs/02-decisions/ADR-0010-i18n.md) |
| An import from one page into another | what is shared is lifted into `features/` or `shared/` ([rule 1](rules/01-application-structure.md)) |
| Permission logic that is only in the interface | hiding is convenience, not protection ([rule 4](rules/04-permissions.md)) |
