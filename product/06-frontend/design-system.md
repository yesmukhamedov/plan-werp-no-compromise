---
id: PROD-06-DS
title: Design system
status: draft
---

# Design system

`shared/ui`. One library per job
([NC-14](../../docs/01-principles/01-no-compromise.md#nc-14)); the registry of
allowed dependencies is checked in CI.

## Components

| Component | Purpose | Key properties |
|---|---|---|
| `DataTable` | **the only** table in the system | server-side pagination/sorting/filtering, pinned columns, virtualization, row selection, persisted column settings |
| `Form` | **the only** form | schema-based validation, field errors, submission state, protection against data loss |
| `Field.*` | input fields | `Text`, `Number`, `Money`, `Date`, `DateRange`, `Select`, `Lookup`, `Checkbox`, `TextArea`, `File` |
| `Lookup` | selection from a reference list | server-side search, lazy loading, creation on the fly, display of the selected value |
| `MoneyInput` / `MoneyText` | money input and output | decimal arithmetic, currency, locale |
| `FilterBar` | the filter bar | synchronization with the URL, saved filter sets |
| `PageHeader` | the page header | title, breadcrumbs, actions |
| `Tabs` | the tabs of a card | the state in the URL |
| `Modal` / `Drawer` | dialogs | focus trap, closing on Esc |
| `Toast` | notifications | do not block work |
| `ConfirmDialog` | confirmation | mandatory for irreversible actions |
| `EmptyState` | empty | explains what to do |
| `ErrorState` | an error | the error code and the `traceId` for contacting support |
| `Skeleton` | loading | instead of a full-page spinner |
| `Chart.*` | charts | `Line`, `Bar`, `Pie` — one library |
| `AuditTrail` | change history | a single appearance across all cards |
| `PermissionGate` | display by permission | hides the element when the permission is absent |

No component named `CustomTable2`, `NewForm` or `TableV2` exists in the system. A
second component in the same category is added only through an ADR.

## Keyboard operation

A requirement, not an improvement: ERP operators work from the keyboard, and it
directly affects their speed.

| Action | Keys |
|---|---|
| Moving between fields | `Tab` / `Shift+Tab` in visual order |
| Save the form | `Ctrl+Enter` |
| Cancel, close a dialog | `Esc` |
| Search on the page | `/` |
| Navigating table rows | `↑` `↓` |
| Open a row | `Enter` |
| Select a row | `Space` |

No scenario may require a mouse. Verified at acceptance.

## Accessibility

Checked automatically on every screen: contrast, a visible focus ring, field
labels, roles and labels for assistive technologies, the absence of focus traps.
