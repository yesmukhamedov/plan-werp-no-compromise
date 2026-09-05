---
id: PROD-06-R03
title: "Frontend rule 3. State"
status: draft
---

## State

| Kind of state | Where it lives |
|---|---|
| Server data | the request cache (one library), keyed by the request parameters |
| List state: filters, sorting, page | **the URL** |
| Form state | the form library, locally |
| Open dialogs, tabs | the component's local state |
| The user, permissions, locale | a single application context |
| Table column settings | the browser's local storage |

**There is no global store for API responses.** A request cache is not an
application state store, and mixing the two is not allowed.
