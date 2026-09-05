---
id: PROD-05-R04
title: "API rule 4. Lists"
status: draft
---

## Lists

**All** list endpoints are paginated. An endpoint returning an unbounded result
set does not exist in the system
([01-principles/03-engineering-standards.md](../../../docs/01-principles/03-engineering-standards.md#performance)).

The uniform parameters:

| Parameter | Purpose |
|---|---|
| `page` / `size` or `cursor` / `limit` | pagination; one method for the whole system |
| `sort` | `field:asc\|desc`, several allowed |
| `q` | full-text search over the resource |
| filters | explicit named parameters declared in the specification |

An arbitrary query language in the URL string is **not used**: it makes
field-level permission control, load predictability and automatic client
generation impossible.

A list response always has one shape: the array of items, the total count, a flag
indicating whether a next page exists.
