---
id: CTX-01
title: Inventory of the current system
status: actual
measured_at: 2026-09-03
---

# Inventory of the current system

Every number was obtained by measuring working copies of the repositories on the
`measured_at` date. This is the baseline: the plan is assessed relative to it,
and if it diverges, the estimates in
[transition/10-estimates.md](../../transition/10-estimates.md) are recalculated.

The measurement method is recorded in the
[appendix](#appendix-how-this-was-measured) so that the figures can be
reproduced and refreshed.

## 1. Repository summary

| Repository | Role | Stack | Files | Lines | Tests | In production |
|---|---|---|---:|---:|---:|---|
| `werp_jsf` | Legacy monolith | JSF 2.2.8 + PrimeFaces 5.1, Hibernate 3.6.7, Spring 3.x, MySQL | 1,223 java + 472 xhtml | 233,913 | JUnit 3.8.1 (declared) | **yes** |
| `werp_java_back_v2` | Main backend | Spring Boot 2.0.0, Java 11, Oracle, Gradle | 3,597 | 354,761 | **4 files** | yes |
| `werp_react_front` | Frontend | React 16.11, Redux 3, CRA 3.4, JavaScript | 2,092 | 369,214 | 1 stub | yes |
| `werp_crm` | CRM (second implementation) | Spring Boot 2.4.4, PostgreSQL, Flyway | 320 | 19,584 | present | yes |
| `werp_call_center` | Call centre | Spring Boot 2.4.5, PostgreSQL, Flyway | 217 | 8,969 | present | yes |
| `bridge` | External gateway | Go 1.22, stdlib, 0 dependencies | 27 | 3,769 | 8 files | being rolled out |
| `target-bridge` | Legacy gateway (Laravel 8) | PHP | — | — | — | being retired |

**Total application code to be replaced: ~990k lines** (excluding `bridge`,
which has already been rewritten and stays).

## 2. `werp_java_back_v2` — the main backend

A Gradle multi-project, `rootProject.name = 'werp'`, group `kz.aura.werp`,
version `0.0.1` on all modules simultaneously.

### 2.1. Modules

| Module | Artefact | Files | Lines | Purpose |
|---|---|---:|---:|---|
| `core` | `werp-core` | 2,225 | 230,446 | the main monolith: 14 subject areas |
| `service` | `werp-service` | 715 | 85,642 | field service + partial duplication of accounting |
| `crm` | `werp-crm` | 327 | 20,257 | CRM on Oracle (duplicates the `werp_crm` repository on PostgreSQL) |
| `main-module` | `werp-main-module` | 223 | 11,739 | shared library: permissions, audit, base entities |
| `util` | `werp-utils` | 70 | 4,020 | utilities; built for Java 8, everything else for 11 |
| `scheduler` | `werp-scheduler` | 23 | 1,625 | background jobs |
| `auth-server` | `werp-auth-server` | 14 | 1,032 | OAuth2 token-issuing server |

Of the seven modules, CI builds and deploys **one** (`service`) — the rest are
deployed by hand.

### 2.2. Subject areas inside `core`

| Area | Files | Lines | What it is |
|---|---:|---:|---|
| `accounting` | 292 | 62,776 | accounting, finance, payroll calculation |
| `hr` | 321 | 34,988 | personnel, headcount, salaries, training |
| `marketing` | 272 | 34,228 | contracts, price lists, sales |
| `logistics` | 418 | 29,018 | warehouse, delivery notes, materials, items on account |
| `dit` | 162 | 13,255 | internal tasks, messages, SMS, ABAC |
| `general` | 187 | 12,141 | platform: authorization, menu, export, attachments |
| `service` | 71 | 10,970 | field service (duplicated by the separate `service` module) |
| `reference` | 176 | 10,670 | reference data |
| `crm` | 102 | 8,905 | CRM and call centre (duplicated by the `crm` module and two repositories) |
| `mreference` | 78 | 4,140 | a second implementation of reference data: addresses, customers, phone numbers |
| `aes` | 40 | 3,909 | an accounting module (purpose needs clarification — see OQ-004) |
| `documents` | 37 | 2,584 | internal document workflow, approval routes |
| `newdev` | 53 | 1,869 | requests (purpose needs clarification — see OQ-004) |
| `law_department` | 15 | 989 | legal department: court cases, debt recovery |

### 2.3. API surface and model

| Metric | Value |
|---|---:|
| HTTP endpoints (`@Get/Post/Put/Delete/PatchMapping`) | **1,286** |
| — GET | 708 |
| — POST | 336 |
| — PUT | 138 |
| — DELETE | 91 |
| — PATCH | 13 |
| `@RequestMapping` (including on classes) | 410 |
| Controllers | 243 |
| `@Service` | 418 |
| JPA entities (`@Entity`) | **523** |
| Spring Data repositories | 165 |
| `@Query` | 451 |
| of those with `nativeQuery = true` | 43 |
| `EntityManager.createQuery` | 837 |
| `EntityManager.createNativeQuery` | 289 |
| Uses of `JdbcTemplate` | 20 |
| `@Transactional` | 1,084 |

Three competing ways of accessing data (Spring Data, JPQL through
`EntityManager`, native SQL and `JdbcTemplate`) coexist within a single module.

### 2.4. Dependencies

- Spring Boot **2.0.0.RELEASE** — the first release of the 2.0 branch, shipped in
  February 2018, out of support since 2019.
- Spring Cloud **Finchley.M9** — a *milestone*, not a release.
- Hibernate 5.4.31 was raised by hand on top of the version managed by Boot 2.0;
  the dependencies `spring-cloud-starter-oauth2:2.2.4` and
  `spring-cloud-starter-bootstrap:3.0.1` belong to other Boot generations.
- Oracle JDBC — `ojdbc6-11.2.0.3` from the local `libs/` folder via `flatDir`.
  The project cannot be built without that file.
- springfox-swagger 2.9.2, Guava 20.0, jjwt 0.7.0, ModelMapper, Redisson 3.12.4.
- Joda-Time is used in parallel with `java.time`.
- The `util` module compiles with `sourceCompatibility = 1.8`, the rest with 11.

## 3. `werp_react_front` — the frontend

| Metric | Value |
|---|---:|
| `.js`/`.jsx` files | 2,092 |
| Lines | 369,214 |
| TypeScript files | **0** |
| Class components | 273 |
| Uses of `useState` | 2,185 |
| Deprecated lifecycle methods (`componentWill*`) | 189 |
| Links to the legacy JSF from React | 33 |
| Localization languages | 3 (ru / en / tr) |
| Lines in `routes/routes.js` | 2,695 |

Sections by line count: `service` 55,884, `hr` 41,945, `logistics` 39,406,
`finance` 39,309, `crm2021` 35,830, `dit` 30,626, `callcenter` 28,160,
`marketing` 26,673, `crm` 20,068, `reference` 8,391, `accounting` 7,569,
`edu` 7,024, `aes` 6,791, `utils` 4,789, `components` 3,581, `lawyer` 3,437,
`admin` 2,606, the rest smaller.

`crm` and `crm2021` are two parallel implementations of the same section;
`finance` and `accounting` are split differently than on the backend.

### The frontend stack

- React 16.11 (the current branch is 19), `react-scripts` 3.4.0 (Create React
  App is out of support), Babel configuration from `babel-preset-react-app`
  3.1.1.
- Redux 3.7 + `react-redux` 5.1 + `redux-form` 7.2 — all three generations
  behind.
- `react-router` 4.
- Three tree libraries: `react-sortable-tree`, `react-treebeard`,
  `react-treeview`.
- Three ways of exporting to Excel: `xlsx`, `react-export-excel`,
  `react-data-export`.
- Two charting stacks: `chart.js` + `react-chartjs-2`, and `recharts`.
- Two date libraries: `moment` and `date-fns`.
- Two arbitrary-precision libraries: `bigdecimal` and `bignumber.js`.
- `faker` and `@faker-js/faker` — test-data generators — in the **production**
  dependencies.
- `axios` 0.21, `react-table` 6.10.3, `semantic-ui-react` 0.72 — out of support.

## 4. The separate services

`werp_crm` (Spring Boot 2.4.4) and `werp_call_center` (Spring Boot 2.4.5) are an
attempt at extracting domains that was started and never finished. Both are on
PostgreSQL with Flyway, the package structure is noticeably cleaner
(`domain/model`, `domain/repository`, `domain/spec`, `converter`,
`dto/{form,grid,detail,report,search}`), and tests exist.

At the same time `werp_crm` (320 files) coexists with the `crm` module inside
`werp_java_back_v2` (327 files) — **CRM is implemented twice, on two different
DBMSs**. Which implementation is the source of truth for which scenarios —
[OQ-002](../../transition/12-open-questions.md).

Application logs and JVM crash dumps (`hs_err_pid*.log`) are committed into the
`werp_call_center` repository.

## 5. `bridge` — the reference sample

The external gateway, rewritten from the Laravel version in Go (stdlib, zero
external dependencies, 3,769 lines, 8 test files). The only part of the system
already brought up to target quality: an explicit route allowlist, one
deployment = one environment, headers trusted only from trusted proxies,
duplicating tests that pin the legacy contracts 1:1.

**`bridge` is excluded from the rewrite scope** and stays as it is. Its README is
the model for what a module's documentation in the new WERP should look like (see
[01-principles/03-engineering-standards.md](../01-principles/03-engineering-standards.md)).

## 6. Infrastructure

- Kubernetes, a self-hosted GitHub Actions runner, an image registry on Docker
  Hub.
- Three environments: dev, stage, prod. The environment addresses are
  **hardcoded into the frontend's `package.json`** (`build:dev` / `build:stage` /
  `build:prod`) and end up in the built bundle.
- Base images: `openjdk:11` (archived, no updates are published) in four of the
  five Dockerfiles; `eclipse-temurin:11-jre` in one.
- The CI build runs with `-x test`.
- Alongside it sits a non-working `bitbucket-pipelines.yml` with the image
  `maven:3.3.9-jdk-8` — an artefact of the era when the project was built with
  Maven.

## 7. The main database

Read from the Oracle data dictionary on 2026-09-03. The object-by-object list,
with the decision taken for each, is in
[transition/map/00-source-inventory.md](../../transition/map/00-source-inventory.md).

| | Value |
|---|---:|
| Tables | 449 (+ 3 views) |
| Columns | 4,855 |
| Rows | ~148,000,000 |
| Table segments | ~12.3 GB |
| Indexes, excluding LOB | 437 |
| — of them non-unique | **73**, over 37 tables |
| Tables with no index at all | 111 |
| Foreign keys | 57, of which **47 are declared on empty shadow copies** |
| Value check constraints | **6** of 1,441 (the rest are `NOT NULL`) |
| Sequences / triggers / procedures / functions / packages | 342 / 43 / 6 / 2 / 0 |
| Tables with a modification timestamp | 109 (24%) |
| Tables with optimistic locking | 21 (5%) |

Two figures set the tone of the whole transition. **Seventy-three secondary
indexes** serve 148 million rows — `BSEG` with 27.7 million rows has one, and
`SERV_CRMHISTORY` with 7.9 million has none and no primary key either. And
**forty-nine of 452 objects** map one to one onto a target table: the rest merge,
split, collapse into enumerations or are not carried over at all.

The database also drifts while it is being described: between the reading on
2026-07-11 and the one on 2026-09-03, 26 tables gained columns and 2 tables
appeared.

## Appendix: how this was measured

```sh
# files and lines per module
find <module> -name '*.java' | wc -l
find <module> -name '*.java' -exec cat {} + | wc -l

# endpoints
grep -rE '@(Get|Post|Put|Delete|Patch)Mapping' --include=*.java . | wc -l

# entities, services, repositories
grep -rl '@Entity' --include=*.java . | wc -l
grep -rl '@Service' --include=*.java . | wc -l
grep -rl 'extends JpaRepository\|extends CrudRepository' --include=*.java . | wc -l
```

The full recomputation script — [tools/measure.sh](../../tools/measure.sh).
