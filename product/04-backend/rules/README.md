---
id: PROD-04-RULES
title: Backend rules
status: draft
---

# Backend rules

The rules by which **any** module and **any** class on the server side is built.
Each is stated so that a machine can check it; the check is in
[../checks.md](../checks.md).

| # | Rule | What it settles |
|---|---|---|
| 1 | [Deployable units](01-deployable-units.md) | one artefact, two run modes |
| 2 | [Module structure](02-module-structure.md) | the same five directories in every module; the dependency rule |
| 3 | [Visibility](03-visibility.md) | only `api/` is reachable from outside a module |
| 4 | [Class types](04-class-types.md) | eleven types, their suffixes, their line limits, the four forbidden names |
| 5 | [Class rules](05-class-rules.md) | constructor injection, one reason to change, where a transaction begins |
| 6 | [Data access](06-data-access.md) | one mechanism, no SQL concatenation, no lazy loading across an aggregate |
| 7 | [Cross-domain interaction](07-cross-domain.md) | a facade call or an event; there is no third way |
| 8 | [Error handling](08-error-handling.md) | one hierarchy, one conversion point, nothing internal on the wire |

## Where to start

[Rule 2](02-module-structure.md) and [rule 3](03-visibility.md) are the pair that
makes the rest possible. A module whose internals are reachable from outside will
be reached into, and once that has happened for a year the boundary cannot be
restored without a rewrite — which is the situation this whole plan exists to
end.

Everything else is a consequence:

- [rule 4](04-class-types.md) and [rule 5](05-class-rules.md) keep a class small
  enough that its reason to change is obvious;
- [rule 6](06-data-access.md) keeps the number of ways to reach the database at
  one, so a change to how data is read is one change;
- [rule 7](07-cross-domain.md) keeps the count of inter-module paths at two, so
  the dependency graph can be drawn;
- [rule 8](08-error-handling.md) keeps the failure shape uniform, so a client
  handles errors once.

## What is not here

**How a specific domain's classes are named and what each does** — that is the
domain's specification ([../../spec/](../../spec/README.md)), and the inventory
of modules is [../modules/](../modules/README.md).

**How the schema those classes read is built** — that is
[03-database/rules/](../../03-database/rules/README.md). The two rule sets are
deliberately separate documents: a person designing a repository needs the
database rules, and a person designing a table does not need the class rules.
