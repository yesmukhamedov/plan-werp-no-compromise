---
id: ADR-0002
title: DBMS — PostgreSQL
status: Accepted
date: 2026-09-03
---

# ADR-0002. DBMS — PostgreSQL

## Context

The system currently has three data stores at once:

- **Oracle** — the main backend `werp_java_back_v2` (523 entities); the driver
  `ojdbc6-11.2.0.3` is wired in from the local `libs/` folder via `flatDir`, and
  the dialect in the configuration is `Oracle10gDialect`;
- **MySQL** — the legacy `werp_jsf` (Hibernate 3.6.7, connector 5.1.18);
- **PostgreSQL** — `werp_crm` and `werp_call_center` (Spring Boot 2.4, Flyway).

Tied to Oracle are 289 `createNativeQuery` calls and 43 `nativeQuery = true`.

## Options

### A. PostgreSQL for the whole system

- **For:** the move has already begun — two services and both live migration
  practices (Flyway) are on PostgreSQL; there are no licence payments and none of
  the environment-count limits that come with them; it starts up freely locally
  and in CI, which rule NC-08 (a reproducible build) and the testing strategy
  directly require; it removes the `flatDir` dependency on a driver file in the
  repository.
- **Against:** migrating 523 entities and the entire schema; 332 native queries
  to rewrite; expertise in operating PostgreSQL under ERP load is needed;
  Oracle-specific features (hierarchical queries, specific functions, sequences,
  PL/SQL packages if any exist) must be dealt with one by one.

### B. Stay on Oracle, upgrade the driver and the dialect

- **For:** minimal risk to the data; the native queries carry over as they are;
  operations are familiar.
- **Against:** licences; `ojdbc` from a local folder (or a closed artefact
  repository) stays; standing up a full instance in CI and on every developer's
  machine is expensive — and without that, rule NC-01 (tests against the real
  DBMS) is only partially satisfiable; the split with the already-running
  PostgreSQL services persists.

### C. Hybrid — the new on PostgreSQL, the legacy domains on Oracle

- **For:** gradualness.
- **Against:** directly contradicts [ADR-0001](ADR-0001-strategy-big-bang.md):
  under a big bang there is no transition period, and hence no reason to keep two
  DBMSs. A hybrid would mean distributed transactions and duplicated reference
  data forever.

## Decision

**Option A — PostgreSQL for the whole system — is accepted.** Oracle and MySQL
are decommissioned together with the legacy environment.

## Consequences

### What appears in the plan

- A separate data-migration track →
  [transition/05-data-migration.md](../../transition/05-data-migration.md),
  [EPIC-005](../../backlog/EPIC-005-data-migration.md).
- An inventory of all 332 native queries and of the database objects (views,
  triggers, sequences, procedures) with a decision on each: rewrite, move into
  the code, drop → [EPIC-003](../../backlog/EPIC-003-schema-inventory.md).
- Post-migration data reconciliation with zero tolerance on the financial tables
  → [transition/06-parity-verification.md](../../transition/06-parity-verification.md).

### What gets easier

- Starting the full system locally with a single command — the database comes up
  as a container.
- Tests run against a real DBMS rather than an embedded substitute; a behavioural
  divergence between the test and the production store is ruled out.
- The build stops depending on a file in `libs/` — part of
  [P-06](../00-context/02-pain-points.md#p-06-dependencies-out-of-support-the-build-is-not-reproducible)
  is closed.

### What needs separate attention

- **Money types.** The rounding rules and precision are fixed once
  ([product/03-database/](../../product/03-database/README.md)); Oracle's and
  PostgreSQL's rounding behaviour may differ — this is verified by tests against
  reference values, not assumed.
- **Audit.** The current system uses Envers
  ([C-10](../00-context/03-constraints.md#c-10-change-audit-already-exists-and-must-be-preserved));
  the audit tables migrate together with the data, and the audit mechanism in the
  new system is designed before the transfer begins.
- **Case and sorting.** Oracle and PostgreSQL behave differently with identifier
  case and with sorting Cyrillic. The collation rules are chosen explicitly and
  fixed in a migration rather than left to a default.
- **Empty string versus NULL.** Oracle does not distinguish an empty string from
  `NULL`; PostgreSQL does. This changes the behaviour of comparisons and unique
  indexes — every column where the difference matters is dealt with during the
  migration.
- **Peak load.** The load profile is measured on the current system before the
  schema is designed, not after →
  [product/10-performance.md](../../product/10-performance.md).

### Open questions

- The PostgreSQL version, the topology (replicas, failover), the backup method
  and the target RPO/RTO —
  [OQ-006](../../transition/12-open-questions.md).
- Whether Oracle holds stored business logic (packages, triggers, DB scheduler
  jobs) invisible from the application code —
  [OQ-007](../../transition/12-open-questions.md). This is potentially a large and
  as yet unestimated part of the work.
