---
id: PROD-06-CHECKS
title: How the frontend rules are enforced
status: draft
---

# How the frontend rules are enforced

A rule is enforced by a check that runs in CI on every pull request
([13-cicd.md](../13-cicd.md)). The check fails the build; it does not warn.

| # | Check | Rule |
|---|---|---|
| FE-01 | every directory under `pages/` matches a domain code from the map | [1](rules/01-application-structure.md) |
| FE-02 | no module under `pages/<a>/` imports from `pages/<b>/` | [1](rules/01-application-structure.md) |
| FE-03 | nothing under `shared/ui/` imports from `pages/` or `features/` | [1](rules/01-application-structure.md) |
| FE-04 | `shared/api/` is generated; a hand edit fails the build | [1](rules/01-application-structure.md), [ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md) |
| FE-05 | every page declares its type, and a page of no type carries a rationale | [2](rules/02-page-types.md) |
| FE-06 | every page defines the four states: loading, empty, error, no permission | [2](rules/02-page-types.md) |
| FE-07 | every list page keeps filters, sorting and page in the URL | [3](rules/03-state.md) |
| FE-08 | no API response is written into the global store | [3](rules/03-state.md) |
| FE-09 | every page declares the permission it requires, and it exists in `platform.permission` | [4](rules/04-permissions.md), [API-19](../05-api/checks.md) |
| FE-10 | the menu is built from the permissions the server returned, never from a static file | [4](rules/04-permissions.md) |
| FE-11 | no string literal is rendered to the user; every text comes from the message system | [5](rules/05-localization.md), [ADR-0010](../../docs/02-decisions/ADR-0010-i18n.md) |
| FE-12 | every message key exists in all supported locales | [5](rules/05-localization.md) |
| FE-13 | no number, date or currency is formatted by hand | [5](rules/05-localization.md) |
| FE-14 | the bundle is split by route; no page pulls another page's code | [6](rules/06-performance.md) |
| FE-15 | the main bundle is within its size budget | [6](rules/06-performance.md), [07-nfr.md](../07-nfr.md) |
| FE-16 | every table over the row threshold is virtualized | [6](rules/06-performance.md) |
| FE-17 | only components from `shared/ui` are used; a second component in an existing category fails | [design system](design-system.md), [NC-14](../../docs/01-principles/01-no-compromise.md#nc-14) |
| FE-18 | no component name matches `*V2`, `New*`, `Custom*` or a trailing digit | [design system](design-system.md) |
| FE-19 | every dependency is on the allowed-library registry | [NC-14](../../docs/01-principles/01-no-compromise.md#nc-14) |
| FE-20 | accessibility: contrast, visible focus, labelled fields, roles, no focus traps | [design system](design-system.md#accessibility) |
| FE-21 | every interactive element is reachable and operable from the keyboard | [design system](design-system.md#keyboard-operation) |
| FE-22 | no `console.log` anywhere in the built bundle | [NC-10](../../docs/01-principles/01-no-compromise.md#nc-10) |
| FE-23 | no host name, IP address or environment URL in the sources or the bundle | [NC-11](../../docs/01-principles/01-no-compromise.md#nc-11) |
| FE-24 | configuration is read at runtime, never baked in at build time | [12-environments.md](../12-environments.md) |
| FE-25 | the section list in the source tree equals the one in [registry.md](registry.md) | [registry](registry.md) |

## The three that are usually treated as optional

**FE-06.** The empty state and the error state are the two screens nobody builds
until a user hits them, and the error state is the one that has to carry the
`traceId` — without it a support request is "it broke" and the on-call engineer
has nothing to search on
([11-observability.md](../11-observability.md#tracing)).

**FE-21.** Keyboard operation is invisible in a demonstration and decisive for
the person doing the job eight hours a day. It is the first requirement to be
dropped under schedule pressure, which is exactly why it is a build failure
rather than an acceptance note.

**FE-17 and FE-18.** A second table component always arrives with a good reason
attached — a deadline, a special case, a library that does one thing better. The
cost lands later, on whoever has to make column persistence, virtualization and
server-side sorting work in two places. The check makes the decision explicit: a
second component in an existing category needs an ADR, and an ADR needs someone
to argue for it in writing.

## What is checked elsewhere

| Concern | Where |
|---|---|
| That the endpoint a page calls exists and returns what it expects | [05-api/checks.md](../05-api/checks.md) |
| Response-time and paint budgets | [10-performance.md](../10-performance.md) |
| That hiding an element is not the access control | [08-security.md](../08-security.md) |
| Scenario coverage by end-to-end tests | [09-quality.md](../09-quality.md) |
