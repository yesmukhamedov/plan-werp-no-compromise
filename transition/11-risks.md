---
id: TRANS-11
title: Risk register
status: draft
reviewed: 2026-09-03
---

# Risk register

Reviewed monthly
([transition/plan/00-roadmap.md](plan/00-roadmap.md#cadence)). Every risk has an
owner, a trigger sign and a predefined action.

**A risk without a trigger sign is not a risk but an anxiety.** The sign must be
observable, so that the risk gets detected rather than sensed.

The scale: probability and impact — low / medium / high.

## Summary

| # | Risk | Prob. | Impact | Status |
|---|---|---|---|---|
| [R-01](#r-01) | The project stretches out and loses support | high | critical | open |
| [R-02](#r-02) | A moving target: the legacy develops faster | high | critical | open |
| [R-03](#r-03) | A failed cutover with rollback impossible | medium | critical | open |
| [R-04](#r-04) | Data quality worse than expected | high | high | open |
| [R-05](#r-05) | Hidden business logic in the database | — | — | **closed** |
| [R-06](#r-06) | The volume of `werp_jsf` is underestimated | medium | high | open |
| [R-07](#r-07) | The stack decision is not taken by G1 | medium | high | open |
| [R-08](#r-08) | Loss of the people who hold the knowledge | medium | high | open |
| [R-09](#r-09) | Users reject the new system | medium | high | open |
| [R-10](#r-10) | Divergence between duplicated domains | high | medium | open |
| [R-11](#r-11) | The "no compromise" rules are weakened under pressure | high | high | open |
| [R-12](#r-12) | The financial calculations do not reconcile | medium | critical | open |
| [R-13](#r-13) | The migration does not fit inside the window | medium | high | open |
| [R-14](#r-14) | Reports are underestimated | high | medium | open |

---

## R-01

**The project stretches out and loses the business's support.**

The estimate is 135–239 PM; under a big bang the business sees no result until
the very end. After a year with no visible result, support for the project
becomes fragile.

- **Sign:** the actuals deviate from the estimate by more than 30% at the end of
  a phase; a reduction in the allocated resources; demonstrations being
  cancelled.
- **Action:** demonstrations every two weeks from the very first screen — the
  only visible result; recalculating the estimates at every gate; a weekly public
  parity report as an objective indicator of progress.
- **If it triggers:** revise the scope — which domains can be left behind.
  Switching the strategy to a strangler fig
  ([ADR-0001](../docs/02-decisions/ADR-0001-strategy-big-bang.md)) at that stage
  is already more expensive than finishing what was started.

## R-02

**A moving target: the legacy develops faster than the new system catches up.**

The main cause of failure in large rewrites.

- **Sign:** the delta backlog grows month over month and does not shrink.
- **Action:** the [freeze policy](09-freeze-policy.md); the rule "a change in the
  legacy = a work item in the delta backlog"; a monthly delta retrospective.
- **If it triggers:** tighten the freeze level; revise the project's timeline. A
  multitude of exceptions is a signal that the freeze came too early or that the
  project is running too long, not that new prohibitions are needed.

## R-03

**A failed cutover, with rollback impossible or unacceptably expensive.**

Scenario O3
([transition/08-rollback.md](08-rollback.md#o3-rollback-during-stabilization))
has no complete technical solution.

- **Sign:** failed rehearsals; divergences in the shadow run before G2; pressure
  on the admission bar.
- **Action:** a formal admission checklist signed off by name; four rehearsals; a
  decision point with a cheap rollback; the legacy held in reserve for the whole
  stabilization period.
- **Accepted as a residual risk** — that is the price of
  [ADR-0001](../docs/02-decisions/ADR-0001-strategy-big-bang.md).

## R-04

**The quality of the production data is worse than expected.**

12 years of accumulation: broken integrity, duplicates, invalid values.

- **Sign:** a large rejection log at rehearsal R1.
- **Action:** expect this as a normal result; budget time for it; decisions on
  each class of problem are taken by the business in writing; cleansing is
  performed **in the legacy before the cutover**.
- **If it triggers:** cleansing becomes a separate track with an owner of its
  own; the cutover may be postponed.

## R-05

**Business logic in the database, invisible from the application code.**

**Closed on 2026-09-03 by measurement.** The schema was read object by object
([map/00-source-inventory.md](map/00-source-inventory.md#4-objects-other-than-tables)):
0 packages, 2 functions, 6 procedures, 3 views, 43 triggers — and 41 of the
triggers do little but assign a primary key from a sequence. One procedure holds a rule
worth moving into a domain scenario; two are unidentified.

The Phase 2 estimate does not need recalculating for this reason. What replaced
the risk is a smaller and much more specific one: **two procedures whose caller
is unknown** ([INV-R3](map/00-source-inventory.md#6-risks-that-follow-from-the-inventory)).

A different database risk did materialize and is tracked separately: the source
schema has 73 secondary indexes for 148 million rows, so the target index set
has to be designed from scratch rather than carried over
([INV-R5](map/00-source-inventory.md#6-risks-that-follow-from-the-inventory)).

## R-06

**The volume of functionality living only in `werp_jsf` is underestimated.**

233,913 lines of legacy in production; 33 links from React. How much of it is
unique is unknown ([OQ-012](12-open-questions.md)).

- **Sign:** the result of the Phase 0 inventory.
- **Action:** close OQ-012 before G0 — that is a condition of the gate.
- **If it triggers:** recalculate the estimate; possibly a separate wave in
  Phase 2.

## R-07

**The stack decision is not taken by gate G1.**

- **Sign:** G1 approaching with the matrix unfilled and no prototypes.
- **Action:** prototypes on two candidates — Phase 0 work with an assigned owner
  and a deadline.
- **If it triggers:** **the project stops.** That is a deliberate mechanism
  ([ADR-0003](../docs/02-decisions/ADR-0003-backend-stack.md#consequences-of-deferring)):
  it prevents development from starting while a fundamental question is
  unresolved.

## R-08

**Loss of the people who hold the knowledge about the current system.**

Some behaviour cannot be derived from the code.

- **Sign:** a key employee leaves; questions about the system stay unanswered for
  more than a week.
- **Action:** the Phase 0 priority is to extract the knowledge into
  characterization tests and the scenario registry while its holders are
  available; book their time in advance.
- **If it triggers:** reconstructing behaviour from the code and the data is
  expensive and not always possible.

## R-09

**Users reject the new system after the cutover.**

A new interface, changed scenarios, the loss of familiar workarounds.

- **Sign:** a negative reaction at the demonstrations; low attendance at the
  demonstrations; complaints during training.
- **Action:** demonstrations every two weeks from the very first screen; early
  acceptance; training before development ends; preserving the familiar scenarios
  wherever there is no reason to change them.
- **If it triggers:** fixing this after the cutover is expensive — which is
  exactly why feedback is collected throughout the project.

## R-10

**Divergence between duplicated implementations of a domain.**

CRM is implemented twice on different DBMSs; reference data twice; service twice.
The divergences are discovered only when they are consolidated.

- **Sign:** when consolidating a domain, the data or the logic of the two
  implementations do not match.
- **Action:** choosing the source of truth is the domain owner's decision, taken
  in Phase 0 ([OQ-002](12-open-questions.md)); budget time for resolving it in
  Phase 2.

## R-11

**The "no compromise" rules are weakened under schedule pressure.**

The most likely and most underestimated risk: that is exactly how the current
system arrived at its present state.

- **Sign:** requests to "temporarily" lower the coverage threshold, switch a
  check off, merge without review; a growing number of ADR exceptions; checks
  being disabled in CI.
- **Action:** the rules are enforced by machine, not by people
  ([product/09-quality.md](../product/09-quality.md#what-is-checked-automatically));
  a departure is possible only through an ADR — that is, in writing and visibly.
- **If it triggers:** the project loses its point. A system without rules will,
  in 12 years, arrive at exactly the place we are leaving.

## R-12

**The new system's financial calculations do not reconcile with the old one's.**

Domain D5 is 62,776 lines; compensation calculation is 7,598 lines in a single
class, almost certainly with accumulated special cases.

- **Sign:** non-zero divergences in the scenario parity.
- **Action:** characterization tests in Phase 0 are a mandatory condition for
  starting D5 and D6; zero tolerance; reconciliation to the cent.
- **If it triggers:** the cutover does not happen — it is a blocking admission
  condition.

## R-13

**The data migration does not fit inside the cutover window.**

- **Sign:** the timing measured at rehearsals R1–R2.
- **Action:** measure from the first rehearsal, not the last; ×2 headroom.
- **If it triggers:** a change of cutover strategy through an ADR — preloading
  historical data, a staged transfer. That takes time, so it has to be detected
  early.

## R-14

**The effort for reports is underestimated.**

The reports are scattered across god classes (5,366 lines in a single reporting
controller), and their number and liveness are unknown.

- **Sign:** the actual effort for the first five reports exceeds the estimate.
- **Action:** an inventory with the dead ones weeded out
  ([EPIC-007](../backlog/EPIC-007-reports-inventory.md)); an estimate from the
  first five, extrapolated, with the plan recalculated.

---

## Closed risks

None yet.
