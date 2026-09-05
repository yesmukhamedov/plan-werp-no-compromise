---
id: TRANS
title: Transition — from what exists to the product
status: draft
---

# Transition

**Only the movement is described here.** What turns into what: how a given
existing table changes, which class is replaced by which, which endpoint by which,
which page by which. And how that movement is organized: phases, data migration,
cutover, rollback, risks.

The target state is **not described** here — it is in
[product/](../product/README.md). This section links to it.

The split is easy to check: if you remove every mention of legacy from a document
and it still makes sense — it is in the wrong section.

Once the project is finished, `transition/` is archived and `product/` remains
the system's documentation.

---

## Reading route

| Who | What to read |
|---|---|
| New to the project | [plan/00-roadmap.md](plan/00-roadmap.md) → [10-estimates.md](10-estimates.md) → [11-risks.md](11-risks.md) |
| Data designer | [01-database-mapping.md](01-database-mapping.md) → [05-data-migration.md](05-data-migration.md) |
| Domain developer | [02-backend-mapping.md](02-backend-mapping.md) → [03-api-mapping.md](03-api-mapping.md) → [map/](map/README.md) |
| Frontend developer | [04-frontend-mapping.md](04-frontend-mapping.md) |
| Cutover lead | [07-cutover.md](07-cutover.md) → [08-rollback.md](08-rollback.md) → [06-parity-verification.md](06-parity-verification.md) |

## Contents

### Mappings

Four documents linking what exists to what is targeted. Each consists of
**rules** (how a mapping of this type is performed) and the **map** (what turns
into what).

| Document | Links | To what in the product |
|---|---|---|
| [01-database-mapping.md](01-database-mapping.md) | table → table, column → column | [product/03-database/](../product/03-database/README.md) |
| [02-backend-mapping.md](02-backend-mapping.md) | class → module and class | [04-backend/](../product/04-backend/README.md) |
| [03-api-mapping.md](03-api-mapping.md) | endpoint → endpoint | [05-api/](../product/05-api/README.md) |
| [04-frontend-mapping.md](04-frontend-mapping.md) | page → page | [06-frontend/](../product/06-frontend/README.md) |

The full maps per domain — [map/](map/README.md), one file per domain, paired with
[product/spec/](../product/spec/README.md).

### Migration and cutover

| Document | About |
|---|---|
| [05-data-migration.md](05-data-migration.md) | the data transfer tool, rehearsals, reconciliation |
| [06-parity-verification.md](06-parity-verification.md) | the shadow run, proving equivalence |
| [07-cutover.md](07-cutover.md) | the cutover procedure |
| [08-rollback.md](08-rollback.md) | rollback |
| [09-freeze-policy.md](09-freeze-policy.md) | the legacy freeze, the delta backlog |

### Organization

| Document | About |
|---|---|
| [plan/00-roadmap.md](plan/00-roadmap.md) | phases and gates |
| [plan/](plan/00-roadmap.md) | the six phases in detail |
| [10-estimates.md](10-estimates.md) | the effort estimate |
| [11-risks.md](11-risks.md) | the risk register |
| [12-open-questions.md](12-open-questions.md) | open questions |

## Four decisions per element

Every element of the existing system — a table, a class, an endpoint, a page —
gets **exactly one** decision. It is taken once, in Phase 0, and written into the
map.

| Decision | What it means | Who takes it |
|---|---|---|
| **Migrate** | the element has a counterpart in the product | the domain owner |
| **Consolidate** | several elements collapse into one | the domain owner |
| **Do not migrate** | the element is dead or not needed | the domain owner, in writing |
| **New** | the element exists in the product but has no predecessor | the designer |

**An element without a decision is unfinished Phase 0 work.** "We will figure it
out along the way" is not a decision: that is how dead code moves into the new
system together with the live code.

The "new" category matters just as much as the others: it shows how much of the
product is new rather than carried over — and that is the part of the estimate
usually forgotten.

## How to read the map

Every row of the map is a mapping stating the transformation method:

```
source  →  target  |  method  |  decision  |  owner  |  verification
```

A row without a transformation method or without a verification does not count as
filled in: it is precisely the method and the verification that distinguish a map
from a list.

## State

The maps are populated in Phase 0. Right now:

| Map | Filled in | What populates it |
|---|---|---|
| Database | the rules + the D1 sample | [EPIC-003](../backlog/EPIC-003-schema-inventory.md) |
| Backend | the rules + the D1 sample | [EPIC-002](../backlog/EPIC-002-contract-inventory.md) |
| API | the rules + the D1 sample | [EPIC-002](../backlog/EPIC-002-contract-inventory.md) |
| Frontend | the rules + the D1 sample | [EPIC-011](../backlog/EPIC-011-scenario-registry.md) |

The sample of full depth — [map/D1-reference.md](map/D1-reference.md).
