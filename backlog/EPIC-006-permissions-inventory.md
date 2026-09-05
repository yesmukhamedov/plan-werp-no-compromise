---
id: EPIC-006
title: Inventory of roles and permissions
phase: 0
owner: not assigned
status: todo
gate: G0
---

# EPIC-006. Inventory of roles and permissions

## Why

The access model is currently glued together from three schemes: a home-grown
`auth-server`, ABAC inside the `dit` domain, `PermissionService` in
`main-module`, plus checks written by hand in controllers
([P-09](../docs/00-context/02-pain-points.md#p-09-authorization-is-glued-together-from-three-schemes)).

There is no single point that answers the question "is this user allowed to do
this". Which means nobody can answer the question "what will change about
permissions after the cutover" either — and that is the first question people
will ask.

Over 12 years, permission business logic has accumulated that cannot be thrown
away, but cannot be carried over as it is either.

## Result

A complete registry of roles and permissions with a decision on each and a
mapping onto the target model
([ADR-0006](../docs/02-decisions/ADR-0006-auth-model.md)).

## Tasks

### TASK-0601. Compile the registry of roles

All the roles, their purpose, the number of users in each, who grants them.

**Acceptance:** the registry is complete; roles with no users are flagged.

### TASK-0602. Compile the registry of permissions

All the permissions from all three mechanisms, including the checks written by
hand in controllers.

**Acceptance:** the registry is complete; for every permission the mechanism that
checks it and the place in the code are stated.

### TASK-0603. Describe the data-scope restriction

How the separation by branch, company and unit works today: where it is applied,
where it has been forgotten, what the exceptions are.

**Acceptance:** the rules are described; the gaps found are recorded as security
findings ([EPIC-010](EPIC-010-security-audit.md)).

> A data-scope restriction applied in the controller is easy to forget — and that
> can only be discovered by a deliberate check.

### TASK-0604. Link the permissions to the endpoints

For every endpoint from
[EPIC-002](EPIC-002-contract-inventory.md) — which permission is required.

**Acceptance:** the "endpoint → permission" table is complete; endpoints with no
explicit permission check are identified and listed separately.

### TASK-0605. Link the permissions to the menu and navigation

Today the menu is built from permissions (`/current-user/routes`). That behaviour
is preserved but gets a single source.

**Acceptance:** the "permission → menu item" mapping is described.

### TASK-0606. Determine liveness

Permissions assigned to nobody; roles with no users; checks that never fire.

**Acceptance:** every permission is marked live / dead; the decision on the dead
ones is taken by the owner.

### TASK-0607. Design the target model

Role / permission / data scope / ownership per
[ADR-0006](../docs/02-decisions/ADR-0006-auth-model.md); the "old permission →
new" mapping.

**Acceptance:** the model is described; every permission being carried over has a
counterpart; the permissions are declared in the API specification.

## Epic closure criteria

- [ ] The registries of roles and permissions are complete
- [ ] The data-scope restriction is described and the gaps identified
- [ ] Every endpoint is linked to a permission
- [ ] Dead permissions and roles are weeded out
- [ ] The target model is designed
- [ ] The permissions are declared in the API specification
      ([NC-12](../docs/01-principles/01-no-compromise.md#nc-12))
