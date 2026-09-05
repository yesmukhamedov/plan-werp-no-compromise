---
id: CTX-02
title: Workarounds and pain points
status: actual
measured_at: 2026-09-03
---

# Workarounds and pain points

Every entry is a measured fact, not an impression. Each is matched with a rule
from ["no compromise"](../01-principles/01-no-compromise.md) that forbids
repeating that compromise in the new system.

This is the project's key document: **if the new system does not eliminate an
entry from this list, it does not count as rewritten.**

---

## P-01. Practically no tests

**Fact.** For 3,597 source files and 354,761 lines in `werp_java_back_v2` there
are **4 test files**. The CI build runs with `-x test`, meaning those four tests
are not executed either.

**Consequence.** Any change is verified only by hand and only in production.
Hence the fear of touching the code, hence duplicating domains instead of
editing existing ones (see P-04), hence the impossibility of refactoring.

**Why this blocks the rewrite.** We have no executable description of how the
system behaves. That means no automated check of parity between the old and the
new behaviour is possible out of the box — characterization tests will have to be
written from scratch as separate work (see
[EPIC-004](../../backlog/EPIC-004-characterization-tests.md)).

**Rule:** [NC-01 — a test, or it does not exist](../01-principles/01-no-compromise.md#nc-01).

---

## P-02. God classes and field injection

**Fact.**

| Class | `@Autowired` fields | Lines |
|---|---:|---:|
| `ReferenceRestController` | 51 | — |
| `ServiceTableService` | 48 | 3,984 |
| `ContractController` | 38 | 3,775 |
| `InvoiceServiceImpl` | 37 | 2,375 |
| `FinanceMainoperationRestController` | 35 | 4,296 |
| `PayrollService` | 27 | **7,598** |
| `FinanceServiceDms` | 21 | 5,629 |
| `FinanceReportRestController` | 20 | 5,366 |

`ContractController` (the `marketing` domain) directly injects DAOs and services
from `accounting`, `hr`, `dit`, `logistics`, `mreference`, `reference` and
`general` — seven foreign subject areas in a single controller.

**Consequence.** There are no boundaries between domains. A class of 7,598 lines
can neither be covered by tests, nor held in one's head, nor split between
developers. Field injection hides dependencies from the compiler and makes the
object impossible to construct in a test.

**Rules:** [NC-02](../01-principles/01-no-compromise.md#nc-02) (domain
boundaries), [NC-03](../01-principles/01-no-compromise.md#nc-03) (explicit
dependencies), [NC-04](../01-principles/01-no-compromise.md#nc-04) (size limits).

---

## P-03. Four ways to reach the database at once

**Fact.** A single codebase contains, side by side:

- 165 Spring Data repositories with 451 `@Query` (43 of them
  `nativeQuery = true`);
- 837 calls to `EntityManager.createQuery` (JPQL as strings);
- 289 calls to `EntityManager.createNativeQuery` (raw SQL as strings);
- 20 uses of `JdbcTemplate`;
- a home-grown `dao/` layer with `DAOException` on top of all of the above.

Query strings are in places assembled by concatenation (`StringBuilder`,
`sql += ...`).

**Consequence.** There is no single place where the load on the database can be
assessed; no single way to profile a query; raw SQL nails the code to the Oracle
dialect — which directly obstructs
[ADR-0002](../02-decisions/ADR-0002-database-postgresql.md); concatenating query
strings is a potential class of vulnerabilities.

**Rule:** [NC-05](../01-principles/01-no-compromise.md#nc-05) — one way of
accessing data.

---

## P-04. Domains implemented twice

**Fact.**

| Domain | Implementation A | Implementation B |
|---|---|---|
| CRM | the `crm` module in `werp_java_back_v2` (327 files, Oracle) | the `werp_crm` repository (320 files, PostgreSQL) |
| Reference data | `core/reference` (176 files) | `core/mreference` (78 files) |
| Field service | `core/service` (71 files) | the `service` module (715 files) |
| Accounting/payroll | `core/accounting` | partially duplicated in the `service` module (`maccounting`) |
| CRM on the frontend | `src/crm` (156 files) | `src/crm2021` (188 files) |
| Call centre on the frontend | `src/callcenter` (118 files) | `src/crm/callCenter` |

It reaches the level of individual tables. Measured over the four Java
repositories on 2026-09-04
([transition/map/01-schema-in-code.md](../../transition/map/01-schema-in-code.md#2-one-table-several-models)):
**55 tables are mapped by more than one entity class** — 44 by two, 10 by three,
`COMPANY` by four (`Bukrs`, `Company`, `Company2`, `CompanyQE`).

**Consequence.** It is unknown which implementation is the source of truth.
Fixing a defect requires editing two places, and the second is usually
forgotten. The data diverges — and with two models writing one table, it can
diverge inside a single row.

**Cause.** A direct consequence of P-01: since the old code cannot be changed
safely, new functionality is written next to it.

**Rule:** [NC-06](../01-principles/01-no-compromise.md#nc-06) — one domain, one
implementation.

---

## P-05. Three backend generations in production at once

**Fact.** Serving users simultaneously:

- `werp_jsf` — JSF 2.2.8 / PrimeFaces 5.1 / Hibernate 3.6.7 (2011) / MySQL,
  233,913 lines, 472 xhtml pages;
- `werp_java_back_v2` — Spring Boot 2.0.0 (2018) / Oracle;
- `werp_crm` and `werp_call_center` — Spring Boot 2.4 / PostgreSQL.

The React frontend contains **33 links into the legacy JSF**: some screens (the
contract card, the customer reference list, some reports) open in the old
interface from the new one. The user moves between two UIs.

**Consequence.** Three authorization models, three data models, three ways of
logging, three release schedules. No part can be decommissioned without dealing
with all three.

**Rule:** [NC-07](../01-principles/01-no-compromise.md#nc-07) — one generation in
production.

---

## P-06. Dependencies out of support, the build is not reproducible

**Fact.**

- Spring Boot **2.0.0.RELEASE** — out of support since 2019; Spring Cloud
  `Finchley.M9` — a pre-release milestone.
- Oracle JDBC is wired in from the local folder `libs/ojdbc6-11.2.0.3.jar` via
  `flatDir` — the file cannot be reproduced from an artefact repository, and a
  clean build on a new machine is impossible without it.
- The `util` module compiles for Java 8, the rest for Java 11.
- The versions of Hibernate, Spring Cloud OAuth2 and Spring Cloud Bootstrap were
  raised by hand to versions designed for other Boot generations.
- The base image `openjdk:11` is archived; no security updates are published.
- In four of the five Dockerfiles, `ENTRYPOINT ["java","-jar"]` does not contain
  the jar file name — the container only works if the argument is passed from
  outside.
- On the frontend, `faker` and `@faker-js/faker` are in the production
  dependencies; `axios` 0.21, `react-table` 6.10.3, `semantic-ui-react` 0.72 are
  out of support.

**Rules:** [NC-08](../01-principles/01-no-compromise.md#nc-08) (a reproducible
build), [NC-09](../01-principles/01-no-compromise.md#nc-09) (supported
dependencies).

---

## P-07. Diagnostics through `System.out`

**Fact.** **1,443** calls to `System.out.print*` and **31** `printStackTrace()`
in the main backend. On top of that, the base `application.yml` has
`show-sql: true` and `hibernate.generate_statistics: true` enabled — that is,
every SQL query is logged and statistics are collected **in all profiles,
production included**.

**Consequence.** Diagnostic information is unstructured, not correlated per
request and not indexed. Continuous SQL output is a measurable performance hit
and a risk of customer data ending up in the logs.

**Rule:** [NC-10](../01-principles/01-no-compromise.md#nc-10) — structured logs,
tracing, no stdout.

---

## P-08. Environment configuration is baked into the code

**Fact.** The addresses and ports of the three environments (dev / stage / prod)
are hardcoded right in the `scripts` section of the frontend's `package.json` and
end up in the built bundle. Communication with the backend on some environments
goes over HTTP without TLS. The names of the cookies carrying the token differ
between environments and are set in `.env` files committed to the repository.

**Consequence.** The same artefact cannot be promoted from stage to prod — a
separate bundle is built for each environment. The internal network topology is
exposed to the client.

**Rule:** [NC-11](../01-principles/01-no-compromise.md#nc-11) — one artefact,
configuration from outside.

---

## P-09. Authorization is glued together from three schemes

**Fact.** In simultaneous use: a home-grown `auth-server` on
`spring-cloud-starter-oauth2` 2.2.4 (on top of Boot 2.0), JWT in cookies shared
with the legacy JSF by domain, `jjwt` 0.7.0 in some modules and
`com.auth0:java-jwt` 3.10.3 in others, plus a home-grown ABAC inside the `dit`
domain and a `PermissionService` in `main-module`.

**Consequence.** There is no single point that can answer the question "is this
user allowed to do this". Permission checks are smeared across controllers.
Tokens in cookies shared between subdomains are an enlarged attack surface.

**Rules:** [NC-12](../01-principles/01-no-compromise.md#nc-12) (a single access
model), see also [product/08-security.md](../../product/08-security.md).

---

## P-10. CI/CD builds and deploys one seventh of the system

**Fact.** The only working pipeline (`deploy-develop.yml`) triggers on a push to
`develop`, builds the **whole** Gradle project with `-x test`, but packages and
ships **only the `service` module**. The other six modules (`core` — 230k lines)
are deployed by hand. Alongside it sits a non-working `bitbucket-pipelines.yml`
from the Maven era. There are no pipelines for stage and prod, no quality gate,
no static analysis, no dependency scanning.

**Rule:** [NC-13](../01-principles/01-no-compromise.md#nc-13) — deployment only
through a pipeline.

---

## P-11. The frontend — three libraries for every job

**Fact.** Three tree libraries, three ways of exporting to Excel, two charting
stacks, two date libraries, two arbitrary-precision number libraries. 273 class
components against 2,185 uses of `useState` — two paradigms in one codebase. 189
uses of lifecycle methods declared deprecated (`componentWillMount`,
`componentWillReceiveProps`, `componentWillUpdate`). Zero TypeScript across 369k
lines. `routes.js` — 2,695 lines.

**Consequence.** Bundle size, inconsistent UX (different tables behave
differently), the impossibility of upgrading React — the deprecated lifecycle
methods are removed under StrictMode and are incompatible with concurrent mode.

**Rule:** [NC-14](../01-principles/01-no-compromise.md#nc-14) — one job, one
library.

---

## P-12. Junk in the repositories

**Fact.** Committed into `werp_call_center` are the application log (348 KB), its
daily archives and JVM crash dumps `hs_err_pid*.log`. In the root of the working
folder sit `.cmd` start-up scripts with numbers in their names
(`-1. run auth-server.cmd` … `-6. run crm.cmd`) — a manual orchestrator for
starting seven services.

**Rule:** [NC-15](../01-principles/01-no-compromise.md#nc-15) — only sources in
the repository.

---

## Summary table

| # | Problem | Metric | Rule |
|---|---|---|---|
| P-01 | No tests | 4 files across 355k lines, CI with `-x test` | NC-01 |
| P-02 | God classes | up to 7,598 lines, up to 51 injections | NC-02, NC-03, NC-04 |
| P-03 | 4 ways of accessing the DB | 451 + 837 + 289 + 20 | NC-05 |
| P-04 | Domains duplicated | 6 domains ×2 | NC-06 |
| P-05 | 3 generations in production | JSF + Boot 2.0 + Boot 2.4 | NC-07 |
| P-06 | Dead dependencies | Boot 2.0.0, ojdbc6 from `libs/` | NC-08, NC-09 |
| P-07 | `System.out` instead of logs | 1,443 + 31 | NC-10 |
| P-08 | Config in the code | addresses of 3 environments in `package.json` | NC-11 |
| P-09 | 3 authorization schemes | 2 JWT libraries + ABAC + cookies | NC-12 |
| P-10 | CI covers 1/7 of the system | 1 module out of 7 | NC-13 |
| P-11 | Duplicated libraries | 3 trees, 3 Excel, 2 charts | NC-14 |
| P-12 | Junk in git | logs, JVM dumps | NC-15 |
