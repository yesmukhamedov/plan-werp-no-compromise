---
id: PROD-05-R08
title: "API rule 8. The compatibility layer for the mobile app"
status: draft
---

## The compatibility layer for the mobile app

There is **one** section of the specification in the system that does not obey
the rules above: `/api/mobile/**`. It reproduces the contract expected by the
mobile app, which is not being rewritten
([C-06](../../../docs/00-context/03-constraints.md#c-06-the-mobile-app--a-separate-client-outside-this-plan)).

Properties of the layer:

- implemented on top of the domain facades, it contains no logic of its own;
- limited to an explicit list of paths — nothing beyond it is exposed;
- covered by tests that pin the responses 1:1;
- marked deprecated in the specification, with a condition for its retirement: an
  update to the mobile app.

This is the product's only deliberate compromise. It is written down here rather
than made silently. The set of paths and the mapping rules —
[transition/03-api-mapping.md](../../../transition/03-api-mapping.md#part-iii-the-compatibility-layer).
