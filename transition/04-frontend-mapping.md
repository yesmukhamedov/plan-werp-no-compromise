---
id: TRANS-04
title: Frontend mapping
status: draft
---

# Frontend mapping

Which existing page is replaced by which
([06-frontend/](../product/06-frontend/README.md)).

The most uncertain of the four maps: unlike a table or an endpoint, a page has no
machine-readable list. That is why it is built not from the code but from the
**scenarios** ([EPIC-011](../backlog/EPIC-011-scenario-registry.md)).

---

# Part I. What will have to be transformed

## The scale and its uncertainty

| Metric | Value |
|---|---:|
| `.js` / `.jsx` files | 2,092 |
| Lines | 369,214 |
| `<Route path=` declarations in the main routes file | 107 |
| Lazy page loads (`Loadable`) in the same file | 345 |
| Lines in the routes file | 2,695 |

**The numbers 107 and 345 do not add up, and they should not:** some routes are
declared inside sections rather than in the main file. How many screens the
system has in total is unknown, and learning that from the code is harder than
learning it from the scenarios.

That is why the target page registry is built from the scenario registry rather
than from a file inventory. This is the only one of the four maps whose source is
not the code.

## Transaction codes in routes

The paths in operation: `/accounting/mainoperation/hrpl`,
`/accounting/mainoperation/acser`, `/hr/report/hrrsb`,
`/hr/mainoperation/customer/hrc01`, `…/hrc02`, `…/hrc03/:id`,
`/marketing/mainoperation/mmcef`, `/marketing/mainoperation/mmcefa`,
`/hr/reference/hrrefistd`, `/dit/werpreference`.

`hrc01`, `hrc02`, `hrc03` are three screens of the same entity differing by
number. The route says neither what the screen is nor how it differs from its
neighbour.

**Rule:** a route is readable by a human:
`/reference/branches`, `/reference/branches/:id`.

The codes are kept as **aliases** for the transition period: users know them by
heart and search by them. An alias redirects to the new route and is retired once
training is done.

> This is the only concession in routing, and it is temporary. The decision on
> when to remove the aliases is taken when Phase 5 is closed.

## Duplicated sections

| Section | Files | Duplicate | Files |
|---|---:|---|---:|
| `src/crm` | 156 | `src/crm2021` | 188 |
| `src/callcenter` | 118 | `src/crm/callCenter` | inside `crm` |
| `src/finance` | 179 | `src/accounting` | 43 |

The first two pairs are parallel implementations of the same section. The third
is a split that does not coincide with the split on the backend.

**Rule:** one section per domain, the boundaries taken from the
[domain map](../product/02-domains.md) rather than from the frontend's history.

## Two paradigms at once

273 class components against 2,185 uses of `useState`; 189 uses of lifecycle
methods declared deprecated (`componentWillMount`, `componentWillReceiveProps`,
`componentWillUpdate`).

The deprecated methods are incompatible with modern React — they are the very
reason the frontend cannot be upgraded gradually.

**Rule:** functional components only, TypeScript in strict mode. No automated
JS → TS conversion is performed: it would carry the architecture over along with
the code ([ADR-0004](../docs/02-decisions/ADR-0004-frontend-stack.md)).

## Links into the legacy interface

33 places where React opens a screen of the old JSF interface (the contract card,
the customer reference list, some reports).

**Every such link is a screen that does not exist in React at all.** That is not
"move a page over" but "write a page for the first time", and the effort differs
by a wide margin.

Working through all 33 links is a Phase 0 task; the result determines
[OQ-012](12-open-questions.md#oq-012) and the Phase 3 estimate.

## Logic moving to the server

Some frontend code has no target counterpart because it moves to the backend:

| What | Where | Why |
|---|---|---|
| Excel generation (three libraries) | `platform-report` | the client used to receive the whole data set |
| Calculations in the browser (`bigdecimal`, `bignumber.js`) | the domain modules | one arithmetic per system |
| Hand-written HTTP wrappers | generation from the specification | |
| The store of API responses | the request cache | |

**Consequence:** the frontend's volume shrinks not only because of the
duplicates. Estimating Phase 3 from 369k lines means overstating it several times
over.

---

# Part II. Mapping rules

| Category | Rule |
|---|---|
| A list screen | → a type L page with server-side pagination and filters in the URL |
| A card screen | → type C; related entities in tabs |
| A form screen | → type F; validation against the schema from the specification |
| A report screen | → type R; computed on the server, long ones asynchronously |
| An indicator dashboard | → type D |
| A `*F4` modal window | → the `Lookup` component from the design system |
| Duplicated sections | consolidated into one; which is the right one is decided by the domain owner |
| A link into the legacy | **a new page**, written from scratch |
| An export in the browser | disappears; replaced by a server-side one |
| A screen with no scenario | not carried over |
| A scenario with no screen | a new page |

## The last two rows are the most important

The map is built not "screen → screen" but through the scenarios:

```
a legacy screen  →  a scenario from the registry  →  a product page
```

That yields two categories a code comparison cannot yield:

- **a screen with no scenario** — nobody uses it, and it is not carried over;
- **a scenario with no screen** — users perform it by a workaround (an export to
  Excel, a manual recalculation, arrangements outside the system). Such a scenario
  requires a **new** page.

The second category is the most valuable find of Phase 0
([TASK-1103](../backlog/EPIC-011-scenario-registry.md)) and the one most often
skipped when estimating. If it is not identified, the new system will reproduce
the same inconveniences.

---

# Part III. Page map

Filled in in [EPIC-011](../backlog/EPIC-011-scenario-registry.md).

| Legacy section | Files | Scenarios | Product pages | Decision | Owner |
|---|---:|---:|---:|---|---|
| `src/reference` | 38 | — | 14 | **designed** | not assigned |
| `src/service` | 234 | — | — | not taken | — |
| `src/hr` | 260 | — | — | not taken | — |
| `src/logistics` | 213 | — | — | not taken | — |
| `src/finance` + `src/accounting` | 222 | — | — | consolidate | — |
| `src/crm` + `src/crm2021` | 344 | — | — | **consolidate** | — |
| `src/callcenter` | 118 | — | — | consolidate with `crm` | — |
| `src/dit` | 241 | — | — | not taken | — |
| `src/marketing` | 125 | — | — | not taken | — |
| `src/edu` | 101 | — | — | not taken | — |
| `src/aes` | 33 | — | — | [OQ-004](12-open-questions.md#oq-004) | — |
| `src/lawyer` | 24 | — | — | not taken | — |
| `src/admin` | 12 | — | — | not taken | — |
| `src/documents` | 8 | — | — | not taken | — |
| screens that exist only in JSF | 472 xhtml | — | — | **[OQ-012](12-open-questions.md#oq-012)** | — |

A sample of a filled-in map — [map/D1-reference.md](map/D1-reference.md#pages).

## The order of filling it in

1. Collect the scenarios per domain (TASK-1101).
2. Match the scenarios against the existing screens (TASK-1104).
3. Identify screens with no scenarios — candidates for removal.
4. Identify scenarios with no screens — new pages (TASK-1103).
5. Work through the 33 links into the legacy — screens that do not exist in
   React.
6. Design the pages in [product/spec/](../product/spec/README.md).
7. Recalculate the Phase 3 estimate.

Step 7 is mandatory: until it is done, the frontend estimate remains a range
([10-estimates.md](10-estimates.md)).
