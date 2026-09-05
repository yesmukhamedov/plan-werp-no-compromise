---
id: PROD-06-RULES
title: Frontend rules
status: draft
---

# Frontend rules

The rules by which **any** page and **any** component of the web application is
built. The check for each is in [../checks.md](../checks.md).

| # | Rule | What it settles |
|---|---|---|
| 1 | [Application structure](01-application-structure.md) | the directory layout, what a page may import, what is generated |
| 2 | [Five page types](02-page-types.md) | L, F, C, R, D — what each must contain and how it behaves |
| 3 | [State](03-state.md) | where each kind of state lives, and why the URL holds list state |
| 4 | [Permissions in the interface](04-permissions.md) | display by permission; why hiding is not protection |
| 5 | [Localization](05-localization.md) | three languages, no literals, one formatting mechanism |
| 6 | [Performance](06-performance.md) | route splitting, virtualization, the bundle budget |

Plus [../design-system.md](../design-system.md) — the component library, the
keyboard map and the accessibility requirements. It is not numbered as a rule
because it is a catalogue rather than a constraint, but it is as binding: a
second component in an existing category comes only through an ADR.

## Where to start

[Rule 2](02-page-types.md). Everything else in the frontend follows from taking
the five page types seriously: the design system exists to serve them, the state
rules exist because a list page has filters, the performance rules exist because
a list page has ten thousand rows.

An ERP built as an arbitrary collection of screens needs a designer per screen. An
ERP built as five types repeated needs a designer once — and the four hundredth
screen behaves the way the first one did, which is what a user actually
experiences as quality.

## What is not here

**The pages of a specific domain, named one by one** — that is the domain's
specification ([../../spec/](../../spec/README.md)); the count and the section
list is [../registry.md](../registry.md).

**Which endpoint a page calls** — the domain specification again, and
[05-api/registry.md](../../05-api/registry.md).
