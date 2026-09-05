---
id: PROD-05-R02
title: "API rule 2. Path structure"
status: draft
---

## Path structure

```
/api/v1/{domain}/{resource}[/{id}[/{nested-resource}[/{id}]]]
```

- `{domain}` — from the [domain map](../../02-domains.md), in the singular.
- `{resource}` — a plural noun, `kebab-case`.
- Nesting goes no deeper than two levels. Deeper — a separate top-level resource.
- There are no verbs in the path: the action is expressed by the method, not by
  the resource name.

Actions that cannot be expressed through CRUD (post a document, cancel a
contract, recalculate) are shaped as a state sub-resource:

```
POST /api/v1/contract/contracts/{id}/cancellation
POST /api/v1/accounting/postings/{id}/approval
```

rather than as `POST /cancelContract`.
