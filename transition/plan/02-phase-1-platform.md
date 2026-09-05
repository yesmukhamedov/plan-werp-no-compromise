---
id: TRANS-PLAN-02
title: Phase 1 — Platform
status: draft
gate: G1
depends_on: ADR-0003
---

# Phase 1 — Platform

**Goal:** build the skeleton on which 13 domains are written uniformly and
quickly.

**The block:** the phase does not begin until
[ADR-0003](../../docs/02-decisions/ADR-0003-backend-stack.md) is accepted. That
is a hard gate: the platform cannot be written on an unchosen stack.

**Why the platform comes before the domains.** If there is no platform, every
domain will build its own — that is how today's `util` and `main-module`
appeared, and behind them three ways of accessing data, three authorization
schemes and three libraries per job. The "platform first" order is not
architectural aesthetics but a direct prevention of
[P-03](../../docs/00-context/02-pain-points.md#p-03-four-ways-to-reach-the-database-at-once),
[P-09](../../docs/00-context/02-pain-points.md#p-09-authorization-is-glued-together-from-three-schemes)
and
[P-11](../../docs/00-context/02-pain-points.md#p-11-the-frontend--three-libraries-for-every-job).

## Contents

### 1. The development skeleton

- A monorepo per
  [ADR-0007](../../docs/02-decisions/ADR-0007-repo-layout.md).
- A build on a clean machine with one command
  ([NC-08](../../docs/01-principles/01-no-compromise.md#nc-08)).
- Starting the whole system locally with one command, PostgreSQL in a container
  included.
- Linters, formatters, a uniform style — configured and mandatory `[STACK]`.
- **The architecture-rule test** — it fails on a violation of domain boundaries
  ([NC-02](../../docs/01-principles/01-no-compromise.md#nc-02)). Written here,
  before any domain code, otherwise it will never be written at all.
- The registry of allowed libraries with a check in CI
  ([NC-14](../../docs/01-principles/01-no-compromise.md#nc-14)).

### 2. The platform subsystems

Per
[product/01-architecture.md](../../product/01-architecture.md#platform):

| Subsystem | Done when |
|---|---|
| Access | login, permissions and data scope work; an endpoint without a permission does not pass CI |
| Audit | a change to an entity produces an immutable record with the full context |
| Errors and validation | a single error format, localized messages, a `traceId` |
| Reports and exports | template → Excel and PDF; synchronous and asynchronous modes |
| Files | upload, storage, delivery with a permission check, lifetime |
| Notifications | email, SMS, in-app; a single sending point |
| Background jobs | scheduling, queue, retries, idempotency |
| Observability | structured logs, metrics, tracing through all the layers |
| Reference infrastructure | the shared mechanism for reference lists, search, cache |
| Multilingual support | [ADR-0010](../../docs/02-decisions/ADR-0010-i18n.md); a missing translation breaks CI |
| **The operation log for rollback** | all mutating operations are recorded in a form suitable for replay ([transition/08-rollback.md](../08-rollback.md#o2-late-rollback)) |

The last item is easy to forget — no domain needs it and it is needed only once,
on the night of the cutover. That is precisely why it is on the platform's list.

### 3. Data

- A schema per domain, the migration tool, the naming conventions
  ([product/03-database/](../../product/03-database/README.md)).
- The money type and the rounding rules — implemented and covered by tests
  against reference values.
- Handling time in UTC.
- The test infrastructure: a real PostgreSQL in a container, data sets, a fast
  run `[STACK]`.

### 4. The API contract

- The specification as the source of truth, code generation
  ([ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md)).
- A specification linter with the rules from
  [05-api/](../../product/05-api/README.md).
- A backward-compatibility check in CI.
- Generation of the stub for the frontend — **without it Phase 3 cannot run in
  parallel with Phase 2**.

### 5. CI/CD

Per [product/13-cicd.md](../../product/13-cicd.md): build, tests, coverage,
static analysis, vulnerability scanning, image build, deployment to all
environments, with manual deployment technically impossible
([NC-13](../../docs/01-principles/01-no-compromise.md#nc-13)).

### 6. Environments

- Dev, stage (pre-production, with a copy of production data), prod.
- Anonymization of the data when it is copied into the pre-production
  environment.
- Observability in all environments.

### 7. The reference domain

One domain implemented **in full** — from the schema migration to the screen and
the test: D1 "Reference data" (not the simplest, but the one most used by the
others).

The reference domain is:

- the check that the platform is fit for work;
- the model the other 12 are written after;
- the basis for the effort estimate
  ([07-estimates.md](../10-estimates.md));
- the first entry into the shadow run.

**Without the reference domain Phase 1 is not finished**, even if all the
subsystems are written. A platform is verified by use, not by inspection.

### 8. The design system

It begins here and is finished at the start of Phase 3
([ADR-0004](../../docs/02-decisions/ADR-0004-frontend-stack.md)): the palette,
the typography, the components, the table, the form, keyboard operation,
accessibility. Without it, 1,300 screens will look like 1,300 applications.

### 9. The shadow run

Technically started here, on the reference domain
([transition/06-parity-verification.md](../06-parity-verification.md)). The
mechanism must be working long before it becomes critical.

## Order

```
skeleton + CI/CD ─► the API contract ─┬─► the platform subsystems ─┐
                                      │                            ├─► the reference domain ─► G1
        data and migrations ──────────┘                            │
        the design system (start) ─────────────────────────────────┘
                                                                   │
                                             the shadow run ───────┘
```

## The phase's risk

**The platform can grow forever.** The temptation to "add one more convenient
thing" is strong, and there is no feedback from the domains yet.

The antidote: the platform counts as ready when the **reference domain runs on
it**, not when it is "complete". Everything else is added on request from Phase 2,
as an ordinary work item with a rationale.

## Completion criteria

Gate [G1](00-roadmap.md#g1--end-of-phase-1).
