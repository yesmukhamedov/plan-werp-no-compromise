---
id: PRN-01
title: What "no compromise" means
status: draft
---

# What "no compromise" means

"No compromise" does not mean "we will make it pretty" or "we will pick a
fashionable stack". It means **fifteen rules, each of which forbids one specific
compromise already made in the current system** and measured in
[00-context/02-pain-points.md](../00-context/02-pain-points.md).

A rule is fit for use only if it can produce an unambiguous verdict. That is why
each one has a "how it is checked" clause — a command or a query that gives
yes/no without discussion. The checks are collected in
[product/09-quality.md](../../product/09-quality.md) and wired into the new
project's CI.

**Violating any rule blocks the merge of a PR.** A departure is possible only
through an ADR with the status "Accepted" — that is, a compromise is allowed, but
it becomes written down, justified and visible instead of silent.

---

## NC-01

> **Functionality without a test does not exist.**

Code without an automated test is not merged. CI has no right to build a release
with tests disabled.

- Minimum branch coverage of the domain layer: **80%**, the threshold is checked
  in CI.
- Every fixed defect comes with a test that reproduces it.
- Every endpoint has at least one contract test.
- Financial calculations are covered by table-driven tests with reference values.

**How it is checked:** the coverage threshold in CI; a grep over the build
configuration for test-disabling flags (`-x test`, `skipTests`,
`--passWithNoTests`) returns nothing.

**Cancels:** [P-01](../00-context/02-pain-points.md#p-01-practically-no-tests).

---

## NC-02

> **A domain does not reach into another domain's internals.**

Cross-domain interaction happens only through a domain's public interface or an
event. Directly injecting another domain's repository/DAO is forbidden.

**How it is checked:** an architecture-rule test (ArchUnit or an equivalent for
the chosen stack) that fails on a forbidden dependency. The rule is described
once in [product/02-domains.md](../../product/02-domains.md) and enforced by
machine.

**Cancels:** [P-02](../00-context/02-pain-points.md#p-02-god-classes-and-field-injection)
in the part concerning `ContractController`, which injects seven foreign domains.

---

## NC-03

> **Dependencies are declared in the constructor.**

Field injection is forbidden. Dependencies are immutable. An object must be
constructible in a test without a dependency-injection container.

**How it is checked:** static analysis — zero field injections.

**Cancels:** [P-02](../00-context/02-pain-points.md#p-02-god-classes-and-field-injection).

---

## NC-04

> **A class — up to 400 lines, a method — up to 50, a class's dependencies — up
> to 7.**

The thresholds are chosen to cut off the current god classes (7,598 lines, 51
dependencies) without getting in the way of normal work. The thresholds are
subject to calibration in Phase 1, not dogma; but they exist and are checked by
machine.

**How it is checked:** the linter, a threshold in CI.

**Cancels:** [P-02](../00-context/02-pain-points.md#p-02-god-classes-and-field-injection).

---

## NC-05

> **One way of accessing data across the whole system.**

One mechanism is chosen (`[STACK]` — see
[ADR-0003](../02-decisions/ADR-0003-backend-stack.md)), and there is no other.
Raw SQL is allowed only in an explicitly separated query layer, only
parameterized, never through string concatenation.

**How it is checked:** a grep for the forbidden constructs in CI; review of new
data-access dependencies.

**Cancels:** [P-03](../00-context/02-pain-points.md#p-03-four-ways-to-reach-the-database-at-once).

---

## NC-06

> **One domain — one implementation.**

A second implementation of a domain cannot be created in principle: a domain
exists in one module, in one place, with one owner. New functionality is added
inside the existing domain.

**How it is checked:** the domain map in
[product/02-domains.md](../../product/02-domains.md) is the single source of
truth; a new module appears only through an ADR.

**Cancels:** [P-04](../00-context/02-pain-points.md#p-04-domains-implemented-twice).

---

## NC-07

> **One generation of the system in production.**

After the cutover the legacy environment is switched off on a schedule, not
"some day". The decommissioning date is fixed before the cutover starts
([transition/07-cutover.md](../../transition/07-cutover.md)).

**How it is checked:** [Phase 5](../../transition/plan/06-phase-5-decommission.md)
has the completion criterion "the legacy environment is stopped and deleted", and
the project does not count as finished before that.

**Cancels:** [P-05](../00-context/02-pain-points.md#p-05-three-backend-generations-in-production-at-once).

---

## NC-08

> **The build is reproducible on a clean machine.**

`git clone` + one command = a built artefact. No files from local folders, no
manual steps, no "first install the driver into your local repository". The
versions of all dependencies are pinned (a lock file).

**How it is checked:** CI builds the project in a clean container with no cache;
that is the check.

**Cancels:** [P-06](../00-context/02-pain-points.md#p-06-dependencies-out-of-support-the-build-is-not-reproducible).

---

## NC-09

> **All dependencies are in support.**

Not a single dependency out of support, not a single pre-release version in
production. Updating dependencies is regular planned work, not a one-off.

- Automated vulnerability scanning on every PR, blocking on critical findings.
- Automated dependency updates with a test run.
- One library per job — see NC-14.

**How it is checked:** a dependency scanner in CI; a staleness report is
collected weekly.

**Cancels:** [P-06](../00-context/02-pain-points.md#p-06-dependencies-out-of-support-the-build-is-not-reproducible).

---

## NC-10

> **Diagnostics means structured logs, metrics and tracing.**

`System.out`, `printStackTrace` and printing SQL in production are forbidden.
Every log record is an event with a request identifier, a user identifier and
context. Personal data and secrets never reach the logs.

**How it is checked:** a grep in CI for `System.out` / `printStackTrace` /
`console.log`; a configuration check for `show-sql` in the production profile.

**Cancels:** [P-07](../00-context/02-pain-points.md#p-07-diagnostics-through-systemout).

---

## NC-11

> **One artefact for all environments, configuration from outside.**

The same image that passed stage goes to prod. Not a single address, port, host
name or key in the sources or in the built bundle. The frontend receives its
configuration at runtime, not at build time.

**How it is checked:** a grep in CI for IP addresses and known host names in the
sources and in the built bundle; comparison of the image digest between
environments.

**Cancels:** [P-08](../00-context/02-pain-points.md#p-08-environment-configuration-is-baked-into-the-code).

---

## NC-12

> **One authentication and authorization model across the whole system.**

One token library, one access-decision point, declarative permissions. A
permission check is not written by hand in a controller.

**How it is checked:** a test that walks all endpoints and verifies that each
declares the permission it requires; zero endpoints without a declared
permission.

**Cancels:** [P-09](../00-context/02-pain-points.md#p-09-authorization-is-glued-together-from-three-schemes).

---

## NC-13

> **Only what has passed the pipeline reaches production.**

Manual deployment is technically impossible, not merely forbidden in words. The
pipeline builds and ships **all** components, not one.

**How it is checked:** only the CI service account holds permissions to change an
environment; a deployment audit.

**Cancels:** [P-10](../00-context/02-pain-points.md#p-10-cicd-builds-and-deploys-one-seventh-of-the-system).

---

## NC-14

> **One job — one library.**

Tables, forms, dates, charts, Excel export, money handling — one implementation
each per system, chosen deliberately and recorded. A second library in the same
category is added only through an ADR.

**How it is checked:** a registry of allowed libraries; CI fails when a
dependency outside the registry appears.

**Cancels:** [P-11](../00-context/02-pain-points.md#p-11-the-frontend--three-libraries-for-every-job).

---

## NC-15

> **Only sources in the repository.**

Logs, dumps, build artefacts, local jar files, start-up scripts for one specific
machine — all outside the repository.

**How it is checked:** `.gitignore` + a CI check for forbidden extensions and
file sizes.

**Cancels:** [P-12](../00-context/02-pain-points.md#p-12-junk-in-the-repositories).

---

## The rule about the rules

The fifteen rules above are the price the project pays for the word "rewrite". If
it turns out during the work that a rule gets in the way, there are exactly two
permissible actions:

1. change the rule through a PR to this document, with a rationale;
2. record a specific departure in an ADR with the status "Accepted", stating the
   deadline and the conditions for returning to the rule.

What is not permissible: silently violating it and not noticing. That is exactly
how the current system arrived at its present state.
