---
id: PROD-08
title: Security
status: draft
---

# Security

The security requirements on the system. The access model itself is
[ADR-0006](../docs/02-decisions/ADR-0006-auth-model.md); everything else is here.

Some of these requirements arose from the findings of an audit of the system in
operation ([EPIC-010](../backlog/EPIC-010-security-audit.md)). **The findings
themselves are not described here — the repository is public.**

Every requirement carries an identifier so that a review, a penetration test or a
release decision can cite it, and the last section maps each to the check that
enforces it. A security requirement with no check is an intention, and intentions
survive until the first deadline.

---

## Transport

| # | Requirement |
|---|---|
| SEC-01 | TLS on all external connections without exception, the internal environments included |
| SEC-02 | Security HTTP headers are configured at the platform level, not per endpoint |
| SEC-03 | Internal addresses and the network topology are not exposed to the client ([NC-11](../docs/01-principles/01-no-compromise.md#nc-11)) |

## Authentication and sessions

| # | Requirement |
|---|---|
| SEC-10 | Authentication follows [ADR-0006](../docs/02-decisions/ADR-0006-auth-model.md); there is no second mechanism |
| SEC-11 | Tokens are short-lived, refreshable and revocable |
| SEC-12 | Logging out genuinely terminates the session on the server |
| SEC-13 | Concurrent sessions are controllable; an administrator can terminate a user's session |
| SEC-14 | Repeated failed sign-ins lock the account for a period, and both the failure and the lock are audited |

SEC-12 is worth stating explicitly because the common implementation — deleting
the token in the browser — leaves a valid credential in the hands of anyone who
captured it.

## Authorization

| # | Requirement |
|---|---|
| SEC-20 | Every endpoint declares the permission it requires ([NC-12](../docs/01-principles/01-no-compromise.md#nc-12)); an endpoint without one does not pass CI |
| SEC-21 | The data-scope restriction — company, branch, unit — is applied **in the data-access layer**, not in the controller |
| SEC-22 | Access to an object by identifier is always checked; "the user does not know the identifier" is not protection |
| SEC-23 | A denial of access is logged with its reason ([audit](03-database/schemas/audit.md)) |
| SEC-24 | Hiding an element in the interface is convenience, not protection; the server checks independently |

**SEC-21 is the one that decides whether the model holds.** A scope check written
in a controller is a check somebody will forget in the four hundredth endpoint.
Applied in the repository layer, forgetting it becomes impossible rather than
unlikely.

## Data

| # | Requirement |
|---|---|
| SEC-30 | Secrets come only from the secret store — never the repository, the image, build variables or logs. Checked automatically |
| SEC-31 | Personal data does not reach logs, error messages or metrics |
| SEC-32 | Data is encrypted at rest and in transit |
| SEC-33 | Access to production data is by request, with logging |
| SEC-34 | Copies for development and testing are **anonymized** — a requirement on the tooling, not a wish |
| SEC-35 | A user exporting large volumes is a logged event, subject to a rate limit |
| SEC-36 | Reading `hr.compensation` is audited — the only audited read in the system, and deliberately so ([D3](spec/D3-hr.md#audit)) |

SEC-36 exists because the question asked after a leak is who *looked*, not who
changed. It is scoped to one table on purpose: auditing every read produces a
table nobody can search
([audit schema](03-database/schemas/audit.md)).

## Input and output

| # | Requirement |
|---|---|
| SEC-40 | All input is validated at the boundary against the schema from the API specification |
| SEC-41 | Parameterized queries always; SQL concatenation is forbidden and checked ([NC-05](../docs/01-principles/01-no-compromise.md#nc-05)) |
| SEC-42 | Uploaded files: type and size limits, content inspection, storage outside the web root, delivery through a controlled endpoint with a permission check |
| SEC-43 | Rate limiting at the user level and at the entry-point level |
| SEC-44 | No response ever carries a stack trace, class name, SQL text or table name ([05-api rule 5](05-api/rules/05-errors.md)) |

## Dependencies and the build

| # | Requirement |
|---|---|
| SEC-50 | Dependency vulnerability scanning on every PR; critical findings block the merge ([NC-09](../docs/01-principles/01-no-compromise.md#nc-09)) |
| SEC-51 | Pinned versions via a lock file; a reproducible build ([NC-08](../docs/01-principles/01-no-compromise.md#nc-08)) |
| SEC-52 | Base images are updated regularly and rebuilt automatically |
| SEC-53 | A software bill of materials is produced during the build |
| SEC-54 | Static security analysis runs in the pipeline |
| SEC-55 | Images are signed, and only a signed image is deployable |

## Operations

| # | Requirement |
|---|---|
| SEC-60 | Access to production goes only through the pipeline ([NC-13](../docs/01-principles/01-no-compromise.md#nc-13)); interactive access to containers is closed by default |
| SEC-61 | The log of administrative actions is immutable |
| SEC-62 | Restoration from backup is tested by drills |
| SEC-63 | A security incident response plan exists, with assigned roles |
| SEC-64 | An administrator acting on another user's behalf is recorded as such, never by borrowing their account ([audit](03-database/schemas/audit.md)) |

## How these requirements are enforced

| Requirement | Enforced by |
|---|---|
| SEC-03, SEC-44 | [API-13](05-api/checks.md), [BE-25](04-backend/checks.md), [FE-23](06-frontend/checks.md) |
| SEC-20 | [API-18](05-api/checks.md), [FE-09](06-frontend/checks.md) |
| SEC-21 | [BE-12](04-backend/checks.md) plus a test per domain that queries outside the scope and expects nothing |
| SEC-23, SEC-64 | the [audit schema](03-database/schemas/audit.md), which records refused actions and acting-as |
| SEC-30 | a secret scan in the pipeline, over sources, images and build variables |
| SEC-31 | a log-masking mechanism in `platform-observability`, plus a test that asserts a masked field never appears |
| SEC-34 | the anonymization tool is in the monorepo and is covered by tests — an error in it is a leak ([12-environments.md](12-environments.md)) |
| SEC-40 | request validation generated from the specification, not written by hand |
| SEC-41 | [BE-13](04-backend/checks.md) |
| SEC-50 … SEC-55 | the pipeline stages listed in [13-cicd.md](13-cicd.md) |
| SEC-62 | a restore drill, on a schedule, with the elapsed time recorded against [NFR-33](07-nfr.md#availability) |

The requirements without an automated check — SEC-11, SEC-13, SEC-33, SEC-63 —
are verified by review and by drill, and they are named here rather than left
implicit precisely because they are the ones that decay quietly.

## Regulator requirements

The requirements concerning personal data, retention periods, data localization
and the immutability of operation logs **are not confirmed** and constitute
[OQ-003](../transition/12-open-questions.md).

The answer may add a substantial amount of work — for example a requirement to
store data in a particular jurisdiction, or to guarantee the immutability of
financial logs by a specific mechanism. Until it is obtained, the Phase 1
estimates remain a range.

| # | Question | What it could change |
|---|---|---|
| SEC-Q1 | Which personal data categories are regulated, and what retention applies to each? | retention on `party`, `hr`, `audit`; possibly encryption at field level |
| SEC-Q2 | Is data localization required? | the hosting decision, and therefore [12-environments.md](12-environments.md) |
| SEC-Q3 | Must financial logs be immutable by a specific mechanism? | the audit schema, and possibly write-once storage |
| SEC-Q4 | Is there a right-to-erasure obligation, and how does it interact with accounting retention? | `party` deletion, and a conflict with statutory record-keeping that has to be resolved by counsel |
