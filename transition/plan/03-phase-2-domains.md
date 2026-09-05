---
id: TRANS-PLAN-03
title: Phase 2 — Domains
status: draft
---

# Phase 2 — Domains

**Goal:** carry over all the business logic. The project's longest and most
expensive phase.

Runs **in parallel with [Phase 3](04-phase-3-frontend.md)**.

## Order

Determined by the dependency graph from the
[domain map](../../product/02-domains.md#dependency-graph) rather than by
business priority: under a big bang there are no intermediate releases, so "the
most valuable thing first" buys nothing, while breaking the dependency order
buys stubs that later get rewritten.

| Wave | Domains | Can run in parallel | Why now |
|---|---|---|---|
| W1 | D1 Reference data | — (the reference domain, done in Phase 1) | everything depends on it |
| W2 | D2 Counterparties, D12 Tasks and communications, D10 Document workflow | yes | they depend only on D0/D1 |
| W3 | D3 Personnel, D4 Contracts and sales | yes | the core of day-to-day operations |
| W4 | D5 Accounting and finance | — | the largest (62,776 lines); it needs D4 and D2 |
| W5 | D6 Compensation calculation, D7 Warehouse and logistics, D11 Legal | yes | they depend on D5 |
| W6 | D8 Field service, D9 CRM and call centre | yes | the topmost in the graph |

## What happens to each domain

A single route for all 13. A deviation from it is an exception requiring a
rationale.

```
1. Analysis       studying the current implementation, interviewing the owner,
                  cross-checking against the scenario registry and the characterization tests
2. Design         the domain model, the DB schema, the public interface, events
3. Contract       the API specification section; the frontend gets a stub and
                  starts work (Phase 3)
4. Schema         the schema migration, the seed data
5. Domain         the domain layer: entities, rules, invariants — with tests
6. Scenarios      the application layer: transactions, permissions, orchestration — with tests
7. Adapters       HTTP, storage, integrations
8. Reports        the domain's reports from the registry (dead ones are not carried over)
9. Migration      the domain's data transfer rules → the migration tool
10. Parity        the domain is connected to the shadow run; divergences are resolved
11. Acceptance    the domain owner checks the scenarios and signs off
```

Steps 1–3 are the most important and the most frequently cut short. A domain
started at step 5 is a transfer of old code into new syntax.

## Rules of the phase

### We carry over behaviour, not code

The current implementation is a **source of requirements**, not a model to copy.
We read it to understand what the system does; we write it anew knowing why.

Opening a 7,598-line god class and pasting it into the new project contradicts
the very point of the project.

### The duplication collapses here

Eight current implementations are consolidated into four domains
([the domain map](../../product/02-domains.md#how-it-was-derived)). Choosing
"which of the two implementations is the right one" is not a technical decision;
the domain owner takes it and writes it down.

This is the phase's biggest source of unexpected work: divergences between
duplicated implementations are discovered only when one tries to consolidate
them.

### A domain is closed only by the Domain DoD

[01-principles/02-definition-of-done.md](../../docs/01-principles/02-definition-of-done.md#domain-dod).
A domain that is "mostly ready" does not count as ready. Under a big bang the
"almost ready" domains pile up and all surface together right before the
cutover.

### The domain owner is a person

One person on the business side per domain: they answer questions, take decisions
about divergences and sign off acceptance. A domain without an owner does not
start.

### Dead matter is not carried over

The removal decisions were taken in Phase 0
([EPIC-003](../../backlog/EPIC-003-schema-inventory.md),
[EPIC-007](../../backlog/EPIC-007-reports-inventory.md)). In Phase 2 they are
executed, not revisited. Returning something removed to the transfer scope goes
through a work item with a rationale.

## Progress indicators

A readiness percentage quoted by a developer is not an indicator. The real ones
are:

| Indicator | Where to look |
|---|---|
| The share of the domain's requests with a divergence in the shadow run | [parity](../06-parity-verification.md#reporting) |
| The share of the domain's scenarios from the registry that pass an end-to-end test | the scenario registry |
| The share of the domain's endpoints from the specification that are implemented | the API specification |
| The domain owner's signature | acceptance |

The first three are computed automatically. That is essential: under a big bang a
progress report must not depend on who compiles it.

## Risks of the phase

| Risk | How it shows | What to do |
|---|---|---|
| D5 is bigger than it looks | 62,776 lines of accounting are a third of all of `core`; the estimate may be understated twofold | break it into sub-areas at the analysis step; revise the estimate after the first sub-area |
| Consolidating duplicates exposes divergences in the data | the two CRM implementations behave differently on the same data | budget time for resolving it; the business takes the decisions |
| Compensation calculation | 7,598 lines in a single class, most likely with accumulated special cases | the characterization tests from Phase 0 are a mandatory condition for starting D6 |
| Reports are underestimated | there are hundreds of reports; they are in the registry, but the effort for each is unknown | estimate from the first five reports, extrapolate, recalculate the plan |
| The domain owners are unavailable | questions pile up and domains stall | book their time in advance; an owner's unavailability is grounds for stopping the domain, not for guessing |

## Completion criteria

- The Domain DoD is satisfied for all 13 domains.
- All the endpoints from the specification are implemented or explicitly
  excluded.
- All the domains are connected to the shadow run.
- The data migration rules are written for all the domains.
