---
id: ADR-NNNN
title: <short decision name>
status: Proposed
date: YYYY-MM-DD
deadline: <the gate by which the decision must be taken; or ->
supersedes: null
superseded_by: null
---

# ADR-NNNN. <Short decision name>

## Context

What is going on and why a decision became necessary. Facts and measurements, not
impressions. Links to the [inventory](../docs/00-context/01-inventory.md) and the
[pain points](../docs/00-context/02-pain-points.md) if the decision cancels a
specific compromise.

The material inputs that constrain the choice.

## Options

### A. <Name>

- **For:** …
- **Against:** …

### B. <Name>

- **For:** …
- **Against:** …

> The rejected options are described with the same honesty as the accepted one.
> An ADR whose alternatives are described pro forma "just to have them" is
> useless: in a year nobody will understand why this one was chosen.

## Decision

**Option X is accepted.**

The deciding considerations — why this one and not the one next to it.

## Accepted cost

What we lose by choosing this. If it seems that we lose nothing, then either the
options are formulated wrongly or the cost has not been found.

If the decision has mandatory compensating mechanisms, list them here and mark
them as not being subject to cancellation.

## Consequences

- What changes in the plan: which phases, epics, documents.
- What gets easier.
- What needs separate attention.
- Which risks grow stronger
  ([transition/11-risks.md](../transition/11-risks.md)).

## Open questions

What remains unresolved, with a link to
[transition/12-open-questions.md](../transition/12-open-questions.md).
