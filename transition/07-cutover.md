---
id: TRANS-07
title: Cutover strategy
status: draft
---

# Cutover strategy

An implementation of
[ADR-0001](../docs/02-decisions/ADR-0001-strategy-big-bang.md). The cutover is
the single moment when users move from the old system to the new one. There will
be no second attempt on the same day, so this whole document is about making that
moment boring.

**The main principle: by the time of the live cutover this must be a rehearsed
procedure, not an event.**

## Conditions for admission to the cutover

The cutover does not begin until **everything** listed is done. The list is
checked formally, and each box is ticked by a named person responsible.

- [ ] The Domain DoD is satisfied for all domains
      ([01-principles/02-definition-of-done.md](../docs/01-principles/02-definition-of-done.md#domain-dod)).
- [ ] The shadow run has been going for at least 30 consecutive days;
      divergences are either absent or accepted in writing
      ([03-parity-verification.md](06-parity-verification.md)).
- [ ] The divergence in financial calculations is zero.
- [ ] At least **four** full data migration rehearsals have been carried out, the
      last **two consecutively** successful.
- [ ] The migration time fits inside the agreed window with at least ×2 headroom.
- [ ] The rollback plan has been rehearsed, the rollback time measured and within
      the norm ([04-rollback.md](08-rollback.md)).
- [ ] The load trials on the pre-production environment have passed at ×3 the
      peak.
- [ ] The users have been trained; acceptance is signed off by the domain owners.
- [ ] The runbooks are written, the on-call shift is formed and knows them.
- [ ] Monitoring and alerts are configured and verified on the pre-production
      environment.
- [ ] The external counterparties have been notified of the downtime window.
- [ ] The legacy freeze is in force and the delta backlog is empty
      ([05-freeze-policy.md](09-freeze-policy.md)).
- [ ] The date and time for decommissioning the legacy are set
      ([NC-07](../docs/01-principles/01-no-compromise.md#nc-07)).

Failure to satisfy any item means postponing the cutover. This rule exists
precisely so that it gets applied under schedule pressure.

## Choosing the window

- A period of minimal business activity: not the month close, not payroll
  accrual, not the seasonal peak. The specific window is chosen from the load
  profile out of [EPIC-009](../backlog/EPIC-009-baseline-measurement.md).
- The window must accommodate: the migration + the verification + headroom + a
  **full rollback**. If the rollback does not fit inside the window, the window
  was chosen wrongly.
- The working day after the cutover has a reinforced on-call shift and the domain
  developers present.

## The course of the cutover

| Step | Action | Reversible |
|---|---|---|
| T−14d | Code freeze on the new WERP; defect fixes only | yes |
| T−7d | The final rehearsal against a fresh copy of the data | yes |
| T−2d | Notifying users and counterparties | yes |
| T−1d | Verifying the backups; confirming readiness against the checklist | yes |
| T−0 | **The window opens.** The legacy is switched to read-only mode | yes |
| T+ | The final backup of the legacy | yes |
| T+ | The data transfer | yes |
| T+ | The automated reconciliation of the transferred data | yes |
| T+ | Smoke tests on the new system with production data | yes |
| T+ | Manual acceptance of the key scenarios by the domain owners | yes |
| T+ | **The decision point:** we go on, or we roll back | ← the last point of cheap rollback |
| T+ | Switching the routing to the new system | expensive |
| T+ | The legacy is stopped (not deleted) | |
| T+ | Verifying the external integrations through `bridge` | |
| T+ | Opening access to the users | |
| T+1h | Monitoring the figures; the decision to close the window | |

**The decision point is the key element of the procedure.** Before it a rollback
is cheap (the legacy has not changed, the data has not diverged). After it, data
appears in the new system that does not exist in the legacy, and the rollback
becomes expensive ([04-rollback.md](08-rollback.md)). The criteria for passing the
point are defined in advance and are not softened on the night of the cutover.

## Stabilization

- The legacy environment is kept **operational but stopped** for the whole
  stabilization period (provisionally 30 days,
  [OQ-011](12-open-questions.md)).
- Reinforced on-call duty for the first two weeks.
- A daily comparison of the key figures against the pre-cutover values.
- Defects found by users are classified by impact; blocking ones are fixed the
  same day.
- The threshold at which a rollback decision is taken during stabilization is
  defined **before** the cutover, not on the spot.

## After stabilization

[Phase 5](plan/06-phase-5-decommission.md) begins: the legacy is decommissioned,
Oracle and MySQL are stopped, the licences are not renewed, the repositories are
archived. The project does not count as finished until that is done
([NC-07](../docs/01-principles/01-no-compromise.md#nc-07)).

## Roles for the cutover

| Role | Responsibility |
|---|---|
| Cutover lead | the only person who takes the "go" / "roll back" decision |
| Data owner | the migration and the reconciliation |
| Infrastructure owner | routing, environments, backups |
| Domain owners | manual acceptance of their scenarios |
| On-call shift | observation, response |
| Business liaison | notifications to users and counterparties |

The roles are assigned by name no later than T−14d. The rollback decision is
taken by one person — a collective decision at three in the morning is not taken.
