---
id: PROD-06-R01
title: "Frontend rule 1. Application structure"
status: draft
---

## Application structure

```
src/
  app/                    entry point, routing, providers, configuration from the runtime
  shared/
    ui/                   the design system: components with no knowledge of the domain
    api/                  the client GENERATED from the specification — never edited by hand
    lib/                  formatting, locales, money, dates
  features/               reusable fragments of behaviour (filter, export, selection)
  pages/
    <domain>/
      <page>/
        index.tsx         the page
        model.ts          the page's state
        ui/               components that exist only on this page
```

The rules:

- `pages/<domain>` corresponds one-to-one to a domain from the
  [map](../../02-domains.md);
- a page imports nothing from another page: what is shared is lifted into
  `features/` or `shared/`;
- `shared/ui` knows nothing about domains at all;
- **`shared/api` is generated** from the specification
  ([ADR-0005](../../../docs/02-decisions/ADR-0005-contract-first-api.md)); hand-written
  HTTP wrappers do not exist;
- routes are declared next to the pages, not in a single file.
