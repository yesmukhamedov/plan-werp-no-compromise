---
id: PROD-06-R04
title: "Frontend rule 4. Permissions in the interface"
status: draft
---

## Permissions in the interface

- A menu item, a button and an action are displayed according to the user's
  permission (`PermissionGate`).
- Hiding something in the interface is a convenience, **not protection**: the
  server checks the permission independently
  ([08-security.md](../../08-security.md)).
- The menu is built from the permissions received from the server, not from a
  static file.
