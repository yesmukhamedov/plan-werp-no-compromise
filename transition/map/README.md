---
id: TRANS-MAP
title: Domain mappings
status: draft
---

# Domain mappings

One file per domain, paired with
[product/spec/](../../product/spec/README.md).

| File | Answers the question |
|---|---|
| `product/spec/D<N>-*.md` | **what will be** — tables, classes, endpoints, pages |
| `transition/map/D<N>-*.md` | **where it comes from** — what turns into what, and how |

The pair is maintained in sync: while designing a target table, the
transformation rule for the source one is described right away. Done at different
times, the specification and the map drift apart, and the drift is discovered at
the migration rehearsal — that is, too late.

## State

Two files are common to every domain rather than specific to one:

- [00-source-inventory.md](00-source-inventory.md) — every object of the source
  schema with its decision and its target table;
- [01-schema-in-code.md](01-schema-in-code.md) — what the code does with those
  tables and columns: what it maps, what it never touches, and where the meaning
  of a column actually lives.

They answer *which table becomes what*; the per-domain files answer *which column
becomes what, and how it is verified*.

| Domain | Map | Specification | Status |
|---|---|---|---|
| all | [00-source-inventory.md](00-source-inventory.md) | [product/03-database/](../../product/03-database/schemas/README.md) | **452 objects, 433 decisions** |
| all | [01-schema-in-code.md](01-schema-in-code.md) | — | **5,355 files parsed** |
| D0 Platform | — | — | tables named, columns not started |
| D1 Reference data | [D1-reference.md](D1-reference.md) | [spec](../../product/spec/D1-reference.md) | **the sample** |
| D2…D12 | — | — | tables named, columns not started |

## Mandatory sections

```markdown
# D<N>. <Domain> — mapping

## Sources                  which modules and repositories belong to the domain
## Consolidation decisions  which of the duplicated implementations is the right one
## Tables                   table → table, column → column, rule, verification
## Data                     volume, quality, known problems
## Classes                  class → module/class, decision
## Endpoints                endpoint → endpoint, decision
## Pages                    screen → scenario → page
## Behaviour changes        what the user will notice
## Domain risks             what can go wrong specifically here
```

The **"Behaviour changes"** section is mandatory and is the one most often
skipped. Any divergence a user will notice must be a decision taken in advance
and in writing, not a surprise after the cutover
([06-parity-verification.md](../06-parity-verification.md#what-to-do-with-a-divergence)).

## Row format

```
source  →  target  |  transformation method  |  decision  |  verification
```

A row without a transformation method or without a verification is not filled in.
It is precisely those two fields that distinguish a map from a list: a list says
what is being carried over, a map says how and how to make sure it was carried
over correctly.

## Who fills it in

The domain's designer together with the domain owner. The "do not migrate" and
"consolidate" decisions are taken by the **owner**, not by a developer: these are
decisions about which functionality the users will keep.
