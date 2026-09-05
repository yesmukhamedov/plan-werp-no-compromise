---
id: TRANS-08
title: Rollback
status: draft
---

# Rollback

The plan for returning to the legacy if the cutover goes wrong. Written
**before** the cutover, rehearsed together with the migration, with a measured
execution time.

Required by
[ADR-0001](../docs/02-decisions/ADR-0001-strategy-big-bang.md#accepted-cost). A
rollback plan written after the cutover is not a plan.

## Three scenarios, three costs

| Scenario | When | Cost | Data loss |
|---|---|---|---|
| **O1. Early rollback** | before the decision point, inside the cutover window | low | none |
| **O2. Late rollback** | after the switchover, inside the cutover window | medium | the data entered after the switchover |
| **O3. Rollback during stabilization** | days or weeks after the cutover | **very high** | requires a reverse migration |

## O1. Early rollback

The users are not working in the new system yet; the legacy has not changed and
is merely switched to read-only mode.

**The procedure:** stop the migration → lift read-only mode on the legacy →
notify the users → hold a post-mortem.

**The norm: ≤ 15 minutes.** Verified at rehearsal R3.

An early rollback is **not a failure but a normal outcome**. Its cheapness is
precisely why the decision point is placed exactly there. The "we roll back"
decision at that point is taken easily and without discussion — the discussion
happens afterwards.

## O2. Late rollback

The users are already working in the new system; data has appeared in it that
does not exist in the legacy.

**The procedure:** close access to the users → record the volume of data entered
→ return the routing to the legacy → lift read-only mode → transfer the data
entered into the new system back into the legacy **by hand, from the operation
log** → open access.

**The norm: ≤ 1 hour** to restoring service (excluding the manual data transfer).

The key feasibility condition: **from its first minute the new system keeps a log
of all mutating operations in a form suitable for manual replay in the legacy.**
That is a requirement on the platform, not on the rollback procedure, and it must
be satisfied in Phase 1 rather than remembered on the night of the cutover.

That is precisely why the cutover window is chosen in a period of minimal
activity: the fewer operations entered before the moment of rollback, the cheaper
O2 is.

## O3. Rollback during stabilization

The most expensive scenario: over days of work in the new system a volume of data
accumulates that cannot be transferred by hand.

**It requires a reverse migration** — a tool for transferring from PostgreSQL
back into Oracle/MySQL. Such a tool:

- cannot in the general case be made complete (the new schema is richer than the
  old one);
- costs about as much as the forward migration;
- is **not developed** in this plan.

Instead there are three measures that reduce the probability of needing O3:

1. **The bar for admission to the cutover**
   ([01-cutover-strategy.md](07-cutover.md#conditions-for-admission-to-the-cutover))
   — mistakes on that scale must be found before, not after.
2. **A predefined rollback threshold.** What exactly counts as grounds for O3 is
   written down before the cutover. Without that, the decision will be taken on
   emotion.
3. **The legacy stays operational** for the whole stabilization period: if O3 is
   needed after all, there is somewhere to return to, even if with a manual
   transfer.

**This is accepted risk [R-03](11-risks.md#r-03).** It is written down
explicitly, not hidden.

## Criteria for the rollback decision

Defined **before** the cutover and not softened during it.

| Sign | Action |
|---|---|
| The migration did not finish in the time allotted | O1 |
| The data reconciliation revealed a divergence in the financial tables | O1 |
| The smoke tests failed | O1 |
| A domain owner did not sign off acceptance | O1 |
| Mass errors for users after access is opened | O2 |
| Performance figures worse than acceptable | O2 if a quick fix is impossible |
| Data loss or corruption discovered | O2 immediately, regardless of the stage |
| Isolated defects with a workaround available | we do not roll back, we fix |

The decision is taken by the **cutover lead alone**. This is not about hierarchy
— it is about the fact that a collective decision at three in the morning is not
taken.

## What is rehearsed

At rehearsal R3, O1 is exercised and its time measured. O2 is exercised on the
pre-production environment: switching over and back, with a check that the legacy
is operational.

An unverified rollback plan is equivalent to no plan at all.
