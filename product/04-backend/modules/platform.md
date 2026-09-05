---
id: PROD-04-M-PLATFORM
title: "Platform modules — D0"
status: draft
---

# Platform modules — D0

The modules **all domains depend on and that depend on none**. Written in
[Phase 1](../../../transition/plan/02-phase-1-platform.md), before any domain
development starts.

The reason for the order is not tidiness. A platform written after the domains is
written thirteen times, once per domain, in thirteen incompatible ways — which is
exactly how a catch-all `util` layer comes into existence.

Schemas these modules own: [`platform`](../../03-database/schemas/platform.md)
(20 tables) and [`audit`](../../03-database/schemas/audit.md) (2 tables).

| | |
|---|---|
| Modules | **12** |
| Estimated classes | ~120 |
| State | outlined — the responsibilities are settled, the class lists are not |
| Written in | [Phase 1](../../../transition/plan/02-phase-1-platform.md) |

## The twelve

| Module | Responsibility | Key classes | Tables it owns |
|---|---|---|---|
| `platform-access` | authentication, permissions, data scope | `PermissionEvaluator`, `DataScopeResolver`, `CurrentUser` | `app_user`, `api_client`, `role`, `permission`, `role_permission`, `user_role`, `access_scope`, `access_scope_item` |
| `platform-audit` | the immutable change log | `AuditWriter`, `AuditableRegistry` | `audit_event`, `audit_field_change` |
| `platform-report` | templates, generation, asynchronous execution | `ReportRunner`, `ReportTemplate`, `ExcelWriter`, `PdfWriter` | `report_definition`, `report_run` |
| `platform-file` | upload, storage, delivery, lifetime | `FileStore`, `FileAccessPolicy` | `stored_file`, `stored_file_link` |
| `platform-notification` | email, SMS, messengers, in-app notifications | `NotificationSender`, `NotificationTemplate` | `notification_template`, `notification`, `notification_delivery` |
| `platform-task` | scheduling, queue, retries, idempotency | `TaskScheduler`, `TaskRunner`, `IdempotencyKey` | `background_job`, `job_run` |
| `platform-numbering` | allocation of human-facing document numbers | `DocumentNumberAllocator`, `NumberSeries` | `document_number` |
| `platform-outbox` | transactional event publication | `OutboxWriter`, `OutboxPublisher` | `outbox_event` |
| `platform-observability` | logs, metrics, tracing | `RequestContext`, `TraceId` | — |
| `platform-error` | a single error model, localization | `DomainException`, `ErrorCode`, `ErrorResponseFactory` | — |
| `platform-i18n` | messages in three languages | `MessageResolver`, `LocaleResolver` | — |
| `platform-money` | decimal arithmetic, currencies, rounding | `Money`, `Currency`, `ExchangeRate`, `RoundingPolicy` | — |
| `platform-changelog` | the operation log for rolling the cutover back | `OperationLogWriter` | — |

Thirteen rows for twelve modules is not an error to be fixed by deleting a row:
`platform-numbering` was separated out when
[`document_number`](../../03-database/schemas/platform.md) got its own rules
about gapless series, and the count moves to **13** the moment the schema
registry does. Counts here are outcomes of design, exactly as they are in the
[schema registry](../../03-database/schemas/README.md).

## The four that carry no tables

`platform-observability`, `platform-error`, `platform-i18n` and `platform-money`
own nothing in the database, and that is the point of them: they are the shape of
behaviour that must be identical in every domain.

| Module | What it prevents by existing |
|---|---|
| `platform-money` | thirteen implementations of rounding, and a currency mismatch that adds up silently |
| `platform-error` | an error format per domain, and a client that has to handle thirteen of them |
| `platform-i18n` | a string literal in a component, and a fourth language costing a release |
| `platform-observability` | a request that cannot be traced across a domain boundary |

## `platform-changelog` — the one that is used once

Needed by no domain, and needed exactly once: on the night of the cutover, to
make a late rollback possible
([transition/08-rollback.md](../../../transition/08-rollback.md#o2-late-rollback)).

It lives in the platform rather than in the cutover tooling for one reason —
otherwise it is written in the last week before the cutover by someone who has
not slept, or it is forgotten entirely and the rollback option quietly stops
existing.

## What the platform must not become

| Not allowed | Why |
|---|---|
| A `platform-common` or `platform-util` module | that is where things get dumped; the name is forbidden by [rule 4](../rules/04-class-types.md) |
| A platform module that depends on a domain | the dependency is one-directional, and the architecture-rule test enforces it |
| A domain reaching a platform table directly | the platform exposes facades like any other module ([rule 3](../rules/03-visibility.md)) |
| A second implementation of anything here | [NC-06](../../../docs/01-principles/01-no-compromise.md#nc-06) |

## Open questions

| # | Question | Affects |
|---|---|---|
| D0-M1 | Is `platform-numbering` a module of its own or part of `platform-task`? | the module count, and who owns gapless allocation |
| D0-M2 | Does `platform-notification` send, or hand off to an external delivery service? | the module's size, and whether `notification_delivery` mirrors a provider |
| D0-M3 | Which of the twelve are needed before the first domain, and which can follow? | the [Phase 1](../../../transition/plan/02-phase-1-platform.md) critical path |
