---
id: ADR-0007
title: Repository layout
status: Proposed
date: 2026-09-03
deadline: gate G0
---

# ADR-0007. Repository layout

## Context

Today the code is spread across seven repositories with no common principle: the
main backend (seven Gradle modules), the frontend, two separate services (one of
which duplicates a module of the main backend), the legacy monolith, the gateway
and its predecessor. The system has no common version — all modules of the main
backend carry version `0.0.1` at the same time. A change touching the backend and
the frontend requires two PRs with no link between them.

## Options

### A. A monorepo for the whole new WERP

The backend, the frontend, the API specification, infrastructure as code and the
tooling in one repository.

- **For:** an atomic change to the contract together with both sides; one system
  version; shared CI and shared rules; it is impossible for the specification and
  the implementation to drift apart; under a big bang, where the whole system
  ships as one release, a single version matches reality.
- **Against:** a build tool that understands the dependencies between the parts
  is needed; access rights are configured at a coarser granularity; the
  repository is large.

### B. A repository per component

- **For:** familiar, independent release cycles.
- **Against:** independent release cycles are not needed under a big bang — there
  is one release; the contract inevitably drifts from the implementation; it
  reproduces exactly the situation we are climbing out of.

## Decision (proposed)

**Option A — a monorepo**, with the following structure:

```
werp/
  api/                 the API specification — the source of truth (ADR-0005)
  backend/             [STACK] modules by domain (ADR-0008)
  frontend/            the web application (ADR-0004)
  db/                  schema migrations, reference data sets
  migration/           tools for moving data out of the legacy (Phase 4)
  ops/                 infrastructure as code, manifests, environment configuration
  tools/               developer scripts, generators, checks
  docs/                ADRs and documentation of the new system
```

`bridge` stays a separate repository: it is not rewritten, lives on its own cycle
and is deliberately isolated from the internals
([CTX-04](../00-context/04-current-integrations.md)).

The legacy repositories are left untouched and, after Phase 5, archived (not
deleted) — they remain the source of answers to the question "how did this work
before?".

## Rules

- One version for the whole system; a tag is applied once to the whole monorepo.
- CI builds only what the change touched, but the rule checks are common to
  everything.
- Ownership of the parts is recorded in a code-owners file; a review from the
  owner of the affected area is mandatory.
- The `main` branch is protected; a direct push is technically impossible.

## Consequences

- A monorepo build tool and cache configuration are required, otherwise CI
  becomes slow and people start bypassing it — and a bypassed CI does not satisfy
  [NC-13](../01-principles/01-no-compromise.md#nc-13).
- The barrier to entry for a new developer is lower: a single instruction for
  "how to run everything".
- The plan (this repository) stays separate: it is about how to build the system,
  not a part of the system. Once the project is finished it is archived together
  with the retrospective.
