---
id: PROD-04-R04
title: "Backend rule 4. Class types"
status: draft
---

## Class types

| Type | Suffix | Responsibility | State | Line limit |
|---|---|---|---|---|
| Facade | `Facade` | the module's public operations | none | 200 |
| Scenario handler | `Handler` | one scenario, the transaction boundary | none | 150 |
| Domain service | `Service` | an operation over several entities | none | 300 |
| Entity | — | state + invariants | yes | 300 |
| Value object | — | an immutable value | yes | 100 |
| Rule | `Rule` / `Policy` | one business rule | none | 100 |
| Repository | `Repository` | access to its own tables | none | 300 |
| Controller | `Controller` | transport only | none | 200 |
| Mapper | `Mapper` | between layers | none | 200 |
| Event | `Event` | a fact that happened in the domain | yes (immutable) | 50 |
| Listener | `Listener` | a reaction to someone else's event | none | 150 |

The limits are an upper bound, not a target
([NC-04](../../../docs/01-principles/01-no-compromise.md#nc-04)). The general limit is
400 lines for a class, 50 for a method, 7 dependencies for a class; all of it is
checked by the linter.

**No class named `*Util`, `*Helper`, `*Manager` or `*Common` exists in the
system.** Such names mean "this is where we dump what we found no place for", and
that is exactly how modules grow from which nothing can later be extracted.
