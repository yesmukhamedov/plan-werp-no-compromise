---
id: PROD-04-R05
title: "Backend rule 5. Class rules"
status: draft
---

## Class rules

1. **Dependencies in the constructor, immutable.** Field injection is forbidden
   and is checked statically
   ([NC-03](../../../docs/01-principles/01-no-compromise.md#nc-03)).
2. **One class — one reason to change.** A controller changes when the transport
   changes, a handler when the scenario changes, an entity when the rules change.
3. **A controller contains no logic.** Parse the request, call the handler,
   return the response. If a controller has an `if` on a business condition, it is
   in the wrong place.
4. **An entity protects its invariants.** An entity in an incorrect state cannot
   be created; there are no setters that would allow it to be violated.
5. **A transaction begins and ends in the scenario handler.** Not in the
   controller, not in the repository, not in a domain service.
6. **A repository returns domain objects**, not table rows.
