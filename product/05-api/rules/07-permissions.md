---
id: PROD-05-R07
title: "API rule 7. Permissions"
status: draft
---

## Permissions

Every endpoint declares the permission it requires right in the specification
([NC-12](../../../docs/01-principles/01-no-compromise.md#nc-12)). An endpoint without a
declared permission does not pass the specification check in CI.
