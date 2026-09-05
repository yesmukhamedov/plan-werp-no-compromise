---
id: ADR-INDEX
title: Index of architectural decisions
status: actual
---

# Architectural decisions (ADRs)

One decision — one file. A file is never deleted or rewritten after the fact: if
a decision is cancelled, it gets the status "Superseded" and a link to its
successor. That way not only the outcome but also the reason is preserved.

The template — [templates/ADR.md](../../templates/ADR.md).

## Statuses

| Status | Meaning |
|---|---|
| `Proposed` | formulated, under discussion |
| `Accepted` | in force, mandatory |
| `Deferred` | the decision is deliberately not taken; a deadline and a condition are stated |
| `Superseded` | cancelled by another ADR (with a link) |
| `Rejected` | considered and turned down; kept for the sake of the reason |

## Registry

| # | Decision | Status | Close before |
|---|---|---|---|
| [0001](ADR-0001-strategy-big-bang.md) | Transition strategy — big bang | Accepted | — |
| [0002](ADR-0002-database-postgresql.md) | DBMS — PostgreSQL | Accepted | — |
| [0003](ADR-0003-backend-stack.md) | Backend stack | **Deferred** | gate **G1** |
| [0004](ADR-0004-frontend-stack.md) | Frontend stack | Proposed | gate **G1** |
| [0005](ADR-0005-contract-first-api.md) | Contract-first API | Proposed | gate **G0** |
| [0006](ADR-0006-auth-model.md) | Authentication and authorization model | Proposed | gate **G1** |
| [0007](ADR-0007-repo-layout.md) | Repository layout | Proposed | gate **G0** |
| [0008](ADR-0008-modular-monolith.md) | A modular monolith, not microservices | Proposed | gate **G1** |
| [0009](ADR-0009-reporting-and-exports.md) | Reports and exports | Proposed | gate **G2** |
| [0010](ADR-0010-i18n.md) | Multilingual support | Proposed | gate **G1** |

## Gates

A gate is a checkpoint by which the listed decisions must be in the "Accepted"
status. The gates are defined in
[transition/plan/00-roadmap.md](../../transition/plan/00-roadmap.md#gates).

## How to add a decision

1. Copy [templates/ADR.md](../../templates/ADR.md) to
   `ADR-NNNN-short-name.md` with the next free number.
2. Fill in the context, the options, the decision, the consequences. **The
   rejected options are described with the same honesty as the accepted one** —
   otherwise the ADR is useless.
3. Add a row to the registry above.
4. Open a PR. The status changes to "Accepted" only after the merge.
