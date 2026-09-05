---
id: ADR-0006
title: Authentication and authorization model
status: Proposed
date: 2026-09-03
deadline: gate G1
---

# ADR-0006. Authentication and authorization model

## Context

The following currently operate in the system at the same time:

- a home-grown `auth-server` (1,032 lines) on `spring-cloud-starter-oauth2` in a
  version designed for a different Spring Boot generation;
- JWT in cookies shared by domain with the legacy JSF — that is how the frontend
  "hands over" the session to the old interface;
- two different JWT libraries in different modules;
- a home-grown ABAC inside the `dit` domain plus a `PermissionService` in
  `main-module`;
- permission checks written by hand in controllers.

There is no single point that answers the question "is this user allowed to do
this"
([P-09](../00-context/02-pain-points.md#p-09-authorization-is-glued-together-from-three-schemes)).

## Decision (proposed)

### Authentication

1. **One identity provider** for the whole system. An external (off-the-shelf)
   one is preferable: a home-grown authentication server is not a competitive
   advantage in 2026 and is a permanent source of vulnerabilities.
2. **One token library**, one signature scheme, one key rotation process.
3. Tokens are not stored in cookies shared between applications. Sharing the
   session with the legacy is not needed — there will be no legacy
   ([NC-07](../01-principles/01-no-compromise.md#nc-07)).
4. Access tokens are short-lived; refresh happens through a separate token that
   can be revoked.
5. Multi-factor authentication is supported by the provider and enabled by policy
   for roles with access to financial operations.
6. Service calls (`bridge` → internal services, background jobs) use a separate
   credential type, not a user's.

### Authorization

A combined model in which each level answers for its own concern:

| Level | Answers the question | How it is defined |
|---|---|---|
| Role | "what kind of account is this" | the role reference list |
| Permission | "is the action allowed" | declaratively on the endpoint in the API specification |
| Data scope | "over which records" — branch, company, unit | a subject attribute, applied in the data-access layer |
| Ownership | "own record or someone else's" | a domain rule |

The key requirements:

- **Every endpoint declares the permission it requires.** An endpoint without a
  declared permission does not pass CI (NC-12).
- **The data-scope restriction is applied in the data-access layer**, not in the
  controller. Forgetting it must be impossible — that is a matter of
  construction, not discipline.
- The authorization decision is taken in one place and logged together with the
  reason for a denial.
- Permissions are verified by a test that walks all endpoints: for each one, at
  least one test for allow and one for deny.

### What is carried over from the current system

The current ABAC model and `PermissionService` contain permission business logic
accumulated over years — it cannot be thrown away, but neither can it be carried
over as it is. Permissions are inventoried as separate Phase 0 work
([EPIC-006](../../backlog/EPIC-006-permissions-inventory.md)): the full list of
roles and permissions, their bindings to menu items and endpoints, and their
actual usage.

## Consequences

- A dependency on an external identity provider appears — choosing a specific one
  and deciding between self-hosting and a managed offering require a separate
  analysis before gate G1.
- Migrating accounts and passwords is part of the
  [data migration](../../transition/05-data-migration.md); passwords are never
  carried over in plaintext under any circumstances — either the hashing scheme
  is preserved or the passwords are reset with a forced change.
- The frontend's menu and navigation are built from the user's permissions — this
  is existing behaviour (`/current-user/routes`) that is preserved but gets a
  single source.

## Open questions

- Is single sign-on with the corporate directory (LDAP / Active Directory)
  required? — [OQ-009](../../transition/12-open-questions.md)
- The regulator's requirements for logging access to personal data —
  [OQ-003](../../transition/12-open-questions.md)
