---
id: TRANS-PLAN-05
title: Phase 4 — Parity and cutover
status: draft
gate: G2, G3
---

# Phase 4 — Parity and cutover

**Goal:** prove that the new system is equivalent to the old one and move the
users onto it.

**This is a separate phase whose cost is comparable to development**, not "the
final two weeks". That was decided in
[ADR-0001](../../docs/02-decisions/ADR-0001-strategy-big-bang.md#consequences):
under a big bang, verification and the cutover are work in their own right, not
the tail end of development.

## The key property: the phase cannot be sped up

Two elements are calendar time, and neither money nor people shorten them:

- **30 days of the shadow run** with no unresolved divergences;
- **four migration rehearsals**, two of them successful consecutively.

That must be in the plan from the very beginning. Discovering it at the end means
either missing the deadline or cutting over without verification.

## The work

### 1. The shadow run at full scale

The mechanism was started in Phase 1, and domains were connected as they became
ready in Phase 2. Here it runs across the whole system.

Daily analysis of divergences; each goes through the classification from
[03-parity-verification.md](../06-parity-verification.md#what-to-do-with-a-divergence).
The weekly report is the main readiness indicator.

### 2. Scenario parity

Running the scenario registry in both systems with the results reconciled.

Financial calculations, compensation calculation and reports — **with zero
tolerance**. This is where the bulk of the unexpected work surfaces: over 12
years special cases have accumulated that nobody remembers, and they are found
only by comparison.

### 3. Load trials

On the pre-production environment, at production data volume, at ×3 the measured
peak ([product/07-nfr.md](../../product/07-nfr.md)).

The ERP peak scenario is verified separately: the period close, mass accrual,
stocktaking. Ordinary load does not show what the end of the month shows.

### 4. Migration rehearsals

Four full runs per
[02-data-migration.md](../05-data-migration.md#s5-rehearsals). Each with a
report. R3 includes a rollback rehearsal.

The first rehearsal will almost certainly expose data-quality problems
accumulated over 12 years. **That is an expected result, not an emergency** — but
the time to resolve them and for the business's decisions has to be in the plan.

### 5. Training and preparation

- Training users on the pre-production environment.
- Instructions and in-app help.
- Runbooks for the on-call shift
  ([product/14-runbooks.md](../../product/14-runbooks.md)).
- Forming the on-call shift for the cutover and stabilization period.

Training begins **before** development ends: people have to be trained on the
system they will actually see, but it also takes more time than one expects.

### 6. Closing the delta backlog

All the changes allowed in the legacy during the freeze
([05-freeze-policy.md](../09-freeze-policy.md)) must be implemented. An empty
delta backlog is an admission condition.

### 7. The cutover

Per [01-cutover-strategy.md](../07-cutover.md).

### 8. Stabilization

The stabilization period (provisionally 30 days), reinforced on-call duty, a
daily comparison of the figures, the legacy held in reserve.

## Order

```
the shadow run (continuous) ─────────────────────────────────────┐
                                                                 │
scenario parity ─────┐                                           │
load trials ─────────┤                                           │
rehearsals R1–R4 ────┼─► G2 ─► cutover ─► stabilization ─► G3 ───┘
training ────────────┤
delta backlog = 0 ───┘
```

## Risks of the phase

| Risk | How it shows | What to do |
|---|---|---|
| More divergences than expected | the shadow run does not reach 30 clean days | postpone the cutover; that is exactly what the shadow run is for |
| The migration does not fit inside the window | measured at R1–R2 | change the cutover strategy through an ADR — preloading history, a staged transfer |
| Data quality worse than expected | R1 produces a large rejection log | budget time; perform the cleansing in the legacy before the cutover |
| Schedule pressure on the admission bar | "let us cut over and finish the rest later" | the admission checklist is formal and signed off by name; that is its only purpose |
| The users are not ready | training deferred to the end | begin training before development ends |

## Completion criteria

Gates [G2](00-roadmap.md#g2--readiness-for-the-cutover) and
[G3](00-roadmap.md#g3--cutover-done).
