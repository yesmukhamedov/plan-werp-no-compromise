---
id: PROD-06-R02
title: "Frontend rule 2. Five page types"
status: draft
---

## Five page types

In an ERP the pages are of the same few kinds. The type determines the structure,
the behaviour and the set of components; an arbitrary page is an exception
requiring a rationale.

### Type L — list

The main type, ~60% of the pages.

| Element | Mandatory | Behaviour |
|---|---|---|
| Filter bar | yes | explicit named filters, the state in the URL |
| Search box | if applicable | server-side search with input debouncing |
| Table | yes | server-side pagination, sorting, pinned columns, virtualization |
| Row actions | yes | according to the user's permissions |
| Bulk actions | if applicable | with confirmation |
| Export | if applicable | **server-side**, through `platform-report` |
| Create button | if applicable | according to permission |

The state of the filters, the sorting and the page lives **in the URL**: a link
to a filtered list can be sent to a colleague, and the browser's "back" returns
to where you were.

### Type C — card

Viewing a single entity: a header with the key fields, tabs with related
entities, the change history (from `platform-audit`), actions available in the
current state.

### Type F — form

Creation and editing. Validation against the schema from the API specification —
the same schema as on the server; server errors are shown on the corresponding
fields; unsaved changes are not lost when the page is left by accident.

### Type R — report

Parameters → run → result. A report taking longer than the threshold runs
asynchronously: the page shows the job's state and the result arrives as a link
([ADR-0009](../../../docs/02-decisions/ADR-0009-reporting-and-exports.md)). **Nothing
is computed in the browser.**

### Type D — dashboard

Summary indicators and charts. Read-only, with no input.
