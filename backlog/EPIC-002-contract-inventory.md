---
id: EPIC-002
title: API contract inventory
phase: 0
owner: not assigned
status: todo
gate: G0
---

# EPIC-002. API contract inventory

## Why

1,286 endpoints in the main backend plus the endpoints of the two separate
services and of the legacy JSF. There is no formal description — the
specification is generated from the code (springfox 2.9.2), meaning it always
trails the implementation.

Without a formal contract:

- compatibility with the mobile app cannot be guaranteed
  ([C-06](../docs/00-context/03-constraints.md#c-06-the-mobile-app--a-separate-client-outside-this-plan));
- Phases 2 and 3 cannot be run in parallel
  ([ADR-0005](../docs/02-decisions/ADR-0005-contract-first-api.md));
- the completeness of the new system cannot be determined;
- an automated comparison in the shadow run cannot be built.

## Result

A machine-readable specification of the current API with a decision on every
endpoint: **migrate / consolidate with another / do not migrate**.

## Tasks

### TASK-0201. Collect the full list of endpoints

All the sources: `werp_java_back_v2` (1,286 + 410 `@RequestMapping`),
`werp_crm`, `werp_call_center`, the legacy JSF, and the paths declared in the
`routes:` configuration.

**Acceptance:** a list stating the source, the method, the path, the parameters
and the response shape. The count matches the one measured in the
[inventory](../docs/00-context/01-inventory.md#23-api-surface-and-model).

### TASK-0202. Pin down the mobile contract

Extract the list of paths opened to the mobile app from `bridge`
(`internal/routes/mobile.go`) — a ready, proven list.

**Acceptance:** the mobile contract is described formally; for every path the
request and response shape is recorded; tests pinning the current behaviour 1:1
are written.

> This is the project's hardest constraint. A mistake here breaks the mobile
> app, which we are not rewriting.

### TASK-0203. Determine which endpoints are live

From the data collected in TASK-0106: which endpoints are called and which are
not.

**Acceptance:** every endpoint is marked live / dead / undetermined, stating the
observation period.

### TASK-0204. Consolidate the duplicates

For the duplicated domains
([P-04](../docs/00-context/02-pain-points.md#p-04-domains-implemented-twice)),
determine which endpoints duplicate each other and which of them is the source of
truth.

**Acceptance:** [OQ-002](../transition/12-open-questions.md#oq-002) is closed;
each pair has a decision from the domain owner.

### TASK-0205. Take a decision on every endpoint

**Acceptance:** zero endpoints without a decision. A "do not migrate" decision
carries a rationale and the domain owner's signature.

### TASK-0206. Describe the target contract

The specification of the new API per the rules from
[05-api/](../product/05-api/README.md): naming, pagination, errors, types,
permissions.

**Acceptance:** the specification passes the linter; for every endpoint being
migrated there is an "old → new" mapping.

### TASK-0207. Set up generation from the specification

The stub for the frontend, the client, the contract tests.

**Acceptance:** the stub comes up with one command and responds per the
specification — that is the condition for running Phases 2 and 3 in parallel.

## Epic closure criteria

- [ ] All the endpoints are listed and the count matches the measured one
- [ ] The mobile contract is pinned down and covered by tests
- [ ] Liveness is determined from data, not from memory
- [ ] OQ-002 is closed
- [ ] A decision has been taken on every endpoint
- [ ] The target specification passes the linter
- [ ] The stub works
