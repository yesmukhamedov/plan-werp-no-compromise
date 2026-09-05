---
id: PROD-04-R03
title: "Backend rule 3. What is visible from outside a module"
status: draft
---

## What is visible from outside a module

Only the contents of `api/`. Everything else is inaccessible technically
`[STACK]`, not by agreement.

Another domain **cannot**: inject a repository, import an entity, read a table,
call a service directly. An attempt is detected by the architecture-rule test
and blocks the merge
([NC-02](../../../docs/01-principles/01-no-compromise.md#nc-02)).
