---
id: PROD-04-R01
title: "Backend rule 1. Deployable units"
status: draft
---

## Deployable units

One ([ADR-0008](../../../docs/02-decisions/ADR-0008-modular-monolith.md)):

| Unit | What | Why separate |
|---|---|---|
| `werp-app` | the whole application: the platform + 13 domains | — |
| `werp-worker` | background jobs | a different load profile; **the same codebase**, a different run mode |

`werp-worker` is not a separate project. It is the same artefact started with a
different profile.
