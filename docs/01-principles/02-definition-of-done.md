---
id: PRN-02
title: Definition of Done
status: draft
---

# Definition of Done

Three levels of doneness. Each level includes the previous one in full.

---

## Task DoD

A task is closed when **all** of the following hold:

- [ ] Exactly what the task describes is implemented; anything beyond its scope
      is filed as a separate task rather than done "along the way".
- [ ] Automated tests are written and pass; branch coverage of the new domain
      code is at or above the threshold (NC-01).
- [ ] None of the rules [NC-01…NC-15](01-no-compromise.md) is violated; CI is
      green.
- [ ] The acceptance criteria from the task card are verified explicitly and
      ticked off.
- [ ] Public behaviour is reflected in the API specification (contract-first —
      [ADR-0005](../02-decisions/ADR-0005-contract-first-api.md)).
- [ ] Data-schema changes are delivered as a versioned migration with a verified
      rollback.
- [ ] The code has been reviewed by a person who is not its author.
- [ ] New log events, metrics and traces are added wherever the operation
      matters for operations.
- [ ] The module's documentation is updated if its contract or behaviour changed.

## Domain DoD

A domain counts as migrated when:

- [ ] The Task DoD is satisfied for all of its tasks.
- [ ] All of the domain's scenarios from the
      [scenario registry](../../product/09-quality.md#scenario-registry) are
      covered by end-to-end tests.
- [ ] All of the domain's endpoints from the
      [contract inventory](../../backlog/EPIC-002-contract-inventory.md) are
      implemented or explicitly marked as excluded with a rationale.
- [ ] A **shadow run** has been passed: against a copy of production data the
      responses of the new and the old domain have been compared; divergences are
      either absent or explained and accepted in writing
      ([transition/06-parity-verification.md](../../transition/06-parity-verification.md)).
- [ ] For financial domains the divergence in calculations is **zero**, with no
      tolerance.
- [ ] The domain's data migration has been exercised at full volume and fits
      within the cutover time budget.
- [ ] The domain's load profile has been measured and meets the NFRs
      ([product/07-nfr.md](../../product/07-nfr.md)).
- [ ] The domain's access permissions are described declaratively and covered by
      tests (NC-12).
- [ ] The domain's runbook is written: typical failures and the on-call actions.
- [ ] The domain's users have carried out acceptance on the pre-production
      environment and confirmed readiness in writing.

## Project DoD

The project is finished when:

- [ ] The Domain DoD is satisfied for all domains.
- [ ] The cutover is done and the new system serves all users.
- [ ] **The legacy environment is stopped and deleted** (NC-07) — not "switched
      off just in case" but decommissioned on the schedule from
      [Phase 5](../../transition/plan/06-phase-5-decommission.md).
- [ ] Oracle is decommissioned and the licences are not renewed
      ([ADR-0002](../02-decisions/ADR-0002-database-postgresql.md)).
- [ ] Not one of the items [P-01…P-12](../00-context/02-pain-points.md) is
      reproduced in the new system; verified against the summary table.
- [ ] Operations are run by the on-call team from the runbooks, without the
      involvement of the migration developers.
- [ ] The plan (this repository) is moved to the `completed` status with a
      retrospective.

---

## What Definition of Done is not

Phrasings that do **not** close a task:

- "works on my machine";
- "we will write the tests later";
- "for now I did it the way the old system does, we will refactor later";
- "coverage dropped, but that is temporary";
- "we will reconcile the data in production".

Each of these phrases is the exact mechanism by which the current system arrived
at the state described in
[02-pain-points.md](../00-context/02-pain-points.md).
