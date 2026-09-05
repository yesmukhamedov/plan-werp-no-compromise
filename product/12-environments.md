---
id: PROD-12
title: Environments
status: draft
---

# Environments

Four environments, one artefact, and one rule that makes the set work: **the
image that passed pre-production is the image that goes to production, byte for
byte** ([NC-11](../docs/01-principles/01-no-compromise.md#nc-11)).

---

## The environments

| Environment | Purpose | Data | Who deploys |
|---|---|---|---|
| **Local** | development | synthetic | the developer, with one command |
| **Dev** | integration of changes | synthetic | CI automatically from `main` |
| **Stage (pre-production)** | acceptance, load, rehearsals, the shadow run, demonstrations | **an anonymized copy of production** | CI |
| **Prod** | operation | production | CI, with a confirmation |

### Local

| # | Requirement |
|---|---|
| ENV-01 | `git clone` plus **one command** gives a working system, PostgreSQL in a container included ([NC-08](../docs/01-principles/01-no-compromise.md#nc-08)) |
| ENV-02 | No files from local folders, no manual driver installation, no start-up script tied to one machine |
| ENV-03 | If starting up locally is harder than one command, that is a **platform defect**, tracked as one |

ENV-03 is written as a defect rather than an aspiration on purpose. A local setup
that takes a day is paid for once per developer per machine, silently, forever —
and it is the first thing that makes a new person unproductive for a week.

### Pre-production

**The project's key environment.** With the chosen transition strategy it
replaces production as the source of feedback for the entire development period
([ADR-0001](../docs/02-decisions/ADR-0001-strategy-big-bang.md)).

| # | Requirement |
|---|---|
| ENV-10 | It holds a copy of production data, refreshed regularly and **anonymized** |
| ENV-11 | The shadow run executes on it ([transition/06-parity-verification.md](../transition/06-parity-verification.md)) |
| ENV-12 | The migration rehearsals are carried out on it |
| ENV-13 | Demonstrations to users take place on it every two weeks |
| ENV-14 | The load trials execute on it |
| ENV-15 | Its resource profile is comparable to production, or the load trials mean nothing |

ENV-15 is a **cost item that has to be budgeted from the very beginning**. A
pre-production environment sized at a quarter of production produces load results
that are a quarter true, and the discovery happens after the cutover.

Under a big bang there is no intermediate release to learn from. Everything the
project would normally learn from production for two years, it learns here — so
an under-resourced pre-production environment is not a saving, it is the removal
of the project's only feedback loop.

## Configuration

| # | Requirement |
|---|---|
| ENV-20 | **One artefact for all environments.** The digest that passed stage matches the one that went to prod, and this is verified |
| ENV-21 | Configuration arrives from the environment; secrets from the secret store ([SEC-30](08-security.md#data)) |
| ENV-22 | **The frontend receives its configuration at runtime**, not at build time — [FE-24](06-frontend/checks.md) |
| ENV-23 | A missing mandatory variable means a **refusal to start**, not implicit default behaviour |
| ENV-24 | Not a single address, port or host name in the sources or in the bundle; checked in CI — [FE-23](06-frontend/checks.md) |

ENV-23 is already done in `bridge`, and it is the model. A service that starts
with a missing variable and silently uses a default is a service that runs
against the wrong database at three in the morning.

ENV-22 is what makes ENV-20 possible for the frontend at all: a bundle with an
API address baked in is a different artefact per environment, whatever the
pipeline says.

## Data in non-production environments

| # | Requirement |
|---|---|
| ENV-30 | Copying production data happens **only** with anonymization, automated and verifiable |
| ENV-31 | The anonymization tool is part of the monorepo and is covered by tests — an error in it is a leak |
| ENV-32 | Access to production data is by request, with logging ([SEC-33](08-security.md#data)) |
| ENV-33 | The anonymized copy preserves data *distribution*, not only shape — otherwise the load trials are wrong |

ENV-31 deserves its emphasis: the anonymization tool is the one piece of
non-product code whose failure is a personal-data incident. It is tested like
product code, and it is reviewed like security code.

ENV-33 is the requirement that is usually missed. Replacing every name with
`user_1` and every amount with `100` produces a database that is safe and
useless: the indexes behave differently, the query plans differ, and the load
trial measures a system nobody will ever run.

## Network and access

| # | Requirement |
|---|---|
| ENV-40 | TLS on all external connections without exception, the internal environments included ([SEC-01](08-security.md#transport)) |
| ENV-41 | The internal topology is not exposed to the client |
| ENV-42 | Interactive access to production containers is closed by default; diagnostics go through observability ([11-observability.md](11-observability.md)) |
| ENV-43 | Changes in production happen only through the pipeline ([NC-13](../docs/01-principles/01-no-compromise.md#nc-13)) |

ENV-42 and ENV-43 are a pair, and they only work together. Closing the shell
without giving the on-call engineer logs, metrics, traces and runbooks does not
improve security — it improves it on paper and produces a workaround within a
month.

## Infrastructure as code

| # | Requirement |
|---|---|
| ENV-50 | All environments are described as code in the monorepo (`ops/` per [ADR-0007](../docs/02-decisions/ADR-0007-repo-layout.md)) |
| ENV-51 | An infrastructure change goes through a PR, with review |
| ENV-52 | An environment is reproducible from scratch out of the repository, **verified by creating a temporary one** |

ENV-52 is the check that keeps ENV-50 honest. Infrastructure code that has never
been used to build an environment from nothing describes an environment that has
drifted from it.

## Backups

| # | Requirement |
|---|---|
| ENV-60 | Regular copies of the production database and of the file store |
| ENV-61 | **Restoration is verified by drills**, not assumed |
| ENV-62 | The measured restore time is recorded against [NFR-33](07-nfr.md#availability) |
| ENV-63 | A separate backup procedure applies for the duration of the cutover ([transition/07-cutover.md](../transition/07-cutover.md)) |

**A backup that has never been restored from is not a backup.** ENV-61 is the
whole content of this section; the rest is scheduling.

## Open questions

| # | Question | Affects |
|---|---|---|
| ENV-Q1 | Is pre-production budgeted at production-comparable resources? | ENV-15, and whether the load trials mean anything |
| ENV-Q2 | How often can the production copy be refreshed, given its size? | ENV-10, and how stale the shadow run's input is |
| ENV-Q3 | Where may data be hosted? | [SEC-Q2](08-security.md#regulator-requirements), and the whole infrastructure decision |
| ENV-Q4 | Who approves a production deployment, and is a second approver required for a migration? | ENV-43, and the pipeline's confirmation step |
