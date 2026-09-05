---
id: EPIC-010
title: Legacy security audit
phase: 0
owner: not assigned
status: todo
gate: G0
---

# EPIC-010. Legacy security audit

## Why

Several problems are visible from the configuration and the structure of the code
([product/08-security.md](../product/08-security.md#what-is-known-about-the-current-state)):
traffic over HTTP without TLS on some environments, JWT in cookies shared with
the legacy, SQL concatenation, diagnostics through `System.out` with SQL printing
enabled, dependencies out of support.

**No full audit has been carried out.** The list above is what is visible, not
the result of a check.

Two reasons to do the audit in Phase 0 rather than later:

1. What is found may require an **immediate** fix in the legacy — independently
   of the rewrite. The system is running now.
2. What is found changes the plan's priorities: if there is a systemic hole in
   the current access model, the requirements on the corresponding part of the
   new system will be higher.

## Result

An audit report with the findings classified and an action plan for each.

## Tasks

### TASK-1001. Check the transport and the configuration

TLS in all environments, security headers, exposure of the internal topology,
secrets in repositories and images, configuration in the built bundle.

**Acceptance:** the findings are listed with a criticality assessment.

### TASK-1002. Check the access model

Endpoints with no permission check; gaps in the data-scope restriction (the
results of TASK-0603); the possibility of accessing someone else's object by
identifier; the correctness of token handling.

**Acceptance:** a list of endpoints with no permission check; a list of places
where the data-scope restriction is not applied.

> This is the most likely area of serious findings: the checks are written by
> hand in controllers, which means that somewhere they are not written at all.

### TASK-1003. Check the handling of data

Places where SQL is concatenated; validation of input at the boundary; handling
of uploaded files; delivery of files with a permission check.

**Acceptance:** the findings are listed; for the SQL concatenation — an
assessment of exploitability.

### TASK-1004. Check for leaks into diagnostics

What ends up in the 1,443 `System.out.print*` calls and in the logs with SQL
printing enabled: personal data, tokens, request contents.

**Acceptance:** an assessment of the leak; if confirmed — an immediate fix in the
legacy, not after the cutover.

### TASK-1005. Scan the dependencies

Known vulnerabilities across all the repositories: the backend, the frontend, the
separate services, the legacy.

**Acceptance:** a report with criticality and exploitability in the system's
context.

### TASK-1006. Classify the findings and assign actions

| Class | Action |
|---|---|
| Critical, exploitable | fix in the legacy immediately, outside the freeze |
| Critical, not exploitable from outside | fix in the legacy as planned work |
| Requires architectural rework | account for it in the requirements on the new system |
| Removed by the rewrite | record it, do not fix it in the legacy |

**Acceptance:** every finding has a class and an assigned action with an owner
and a deadline.

> The freeze never forbids security fixes
> ([05-freeze-policy.md](../transition/09-freeze-policy.md#what-the-freeze-never-forbids)).

### TASK-1007. Refine the requirements on the new system

**Acceptance:** [product/08-security.md](../product/08-security.md) is extended
with the requirements that follow from the findings.

## Epic closure criteria

- [ ] All the areas are checked
- [ ] The findings are classified and actions assigned
- [ ] The critical exploitable findings are fixed in the legacy
- [ ] The requirements on the new system are refined

## Handling the results

The audit report contains information about vulnerabilities in the system in
operation. It is **not published in this repository** (the repository is public)
and is kept in a closed environment. What stays here is only the requirements
that follow from it, without any description of the vulnerabilities.
