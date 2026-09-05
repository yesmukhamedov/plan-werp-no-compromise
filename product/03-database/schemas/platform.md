---
id: PROD-03-S-PLATFORM
title: "platform schema — D0 Platform"
status: draft
---

# `platform` — D0 Platform

| | |
|---|---|
| Domain | D0 Platform ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **20** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 5 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `platform`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md) — `id`, `created_at`,
`created_by`, `updated_at`, `updated_by`, `version` — which are not repeated
below. Immutable tables are marked as such.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

**The platform depends on no domain, and every domain depends on it.** That is
why it is designed and built first, and why every table here has to be right
before anything else is written against it.

## Group 1. Who may do what

Access is **one** mechanism, not two: `permission` says what may be done,
`access_scope` says which rows it may be done to
([ADR-0006](../../../docs/02-decisions/ADR-0006-auth-model.md)). There is no
second access mechanism anywhere in the system.

### `app_user` — someone who signs in

Pattern: [14.6](../rules/14-patterns.md#146-one-identity-many-roles) — a user is
an account, not a person.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `login` | `text` | no | `ck` length 3–100 | the sign-in name |
| `party_id` | `uuid` | yes | ⇢ `party.person` | the person behind the account, when there is one |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | the employment the account belongs to |
| `email` | `text` | yes | `ck` e-mail format | where password resets go |
| `password_hash` | `text` | yes | | null for an account that authenticates externally |
| `password_changed_at` | `timestamptz` | yes | | |
| `authentication_kind` | `text` | no | `ck IN (PASSWORD, EXTERNAL, SERVICE)` | how the account proves itself |
| `external_system` | `text` | yes | `ck` length 1–40 | the identity provider |
| `external_id` | `text` | yes | | the account's identifier there |
| `is_active` | `boolean` | no | default `true` | may sign in |
| `locked_until` | `timestamptz` | yes | | set by the lockout rule |
| `failed_attempt_count` | `smallint` | no | default 0, `ck` ≥ 0 | reset on a successful sign-in |
| `last_login_at` | `timestamptz` | yes | | |
| `locale` | `text` | no | `ck` in the supported list | the interface language |
| `timezone` | `text` | no | default `Asia/Almaty` | how times are rendered for this user |

Indexes: `ux_app_user__login`,
`ux_app_user__external_system__external_id` partial `WHERE external_id IS NOT NULL`,
`ix_app_user__employee_id`, `ix_app_user__party_id`.

> A user is **not** an employee. Some employees never sign in; some accounts —
> an integration, a contractor — belong to no employee at all. Merging the two
> makes the second case unrepresentable and the first case a lie.

### `api_client` — a machine consumer of the API

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` `^[a-z0-9_-]+$` | the client code |
| `name` | `text` | no | | what it is |
| `secret_hash` | `text` | no | | the hashed credential |
| `secret_rotated_at` | `timestamptz` | no | | when it was last rotated |
| `allowed_ip_range` | `cidr` | yes | | where it may call from |
| `rate_limit_per_minute` | `integer` | yes | `ck` > 0 | its share of the API |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_api_client__code`.

### `role` — a named set of permissions

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` `^[A-Z_]+$` | the role code |
| `name` | `text` | no | | the role name |
| `description` | `text` | yes | `ck` length 1–500 | what the role is for |
| `is_system` | `boolean` | no | default `false` | not editable from the interface |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_role__code`.

### `permission` — one named right

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` `^[a-z_]+\.[a-z_]+\.[a-z_]+$` | `<domain>.<resource>.<action>` |
| `domain_code` | `text` | no | `ck` in the domain list | which domain declares it |
| `resource` | `text` | no | | which resource |
| `action` | `text` | no | | which action |
| `description` | `text` | no | `ck` length 1–255 | what it allows, in words |

Indexes: `ux_permission__code`, `ix_permission__domain_code`.

Permissions are **seed data**, generated from the domain specifications and
versioned with the schema. A permission that no specification declares is a
build failure ([checks.md](../checks.md)).

### `role_permission` — which rights a role grants

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `role_id` | `uuid` | no | → `role.id` | the role |
| `permission_id` | `uuid` | no | → `permission.id` | the right |

Indexes: `ux_role_permission__role_id__permission_id`,
`ix_role_permission__permission_id`.

### `user_role` — which roles a user holds

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag) — a role held
for a period, so a temporary elevation expires by itself.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `app_user_id` | `uuid` | no | → `app_user.id` | the user |
| `role_id` | `uuid` | no | → `role.id` | the role |
| `valid_from` | `date` | no | | held from |
| `valid_to` | `date` | yes | | held until, exclusive |
| `granted_by` | `uuid` | no | → `app_user.id` | who granted it |
| `reason` | `text` | yes | `ck` length 1–255 | why, for a temporary grant |

Indexes: `ix_user_role__app_user_id`, `ix_user_role__role_id`.
Constraint: `ex_user_role__no_overlap` — an exclusion constraint on
(`app_user_id`, `role_id`, the date range).

> A temporary elevation that has to be revoked by hand is never revoked. Making
> the grant a period means the database revokes it.

### `access_scope` — a named restriction of visible data

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `app_user_id` | `uuid` | no | → `app_user.id` | whose scope it is |
| `code` | `text` | no | | the scope name |
| `is_unrestricted` | `boolean` | no | default `false` | the user sees everything |

Indexes: `ux_access_scope__app_user_id__code`.

### `access_scope_item` — the entries of a scope

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) —
one row per granted object, never a column per object kind.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `access_scope_id` | `uuid` | no | → `access_scope.id` | the scope |
| `dimension` | `text` | no | `ck IN (COMPANY, BRANCH, WAREHOUSE, ORG_UNIT)` | what is being restricted |
| `object_id` | `uuid` | no | typed link ([14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind)) | which object |
| `includes_descendants` | `boolean` | no | default `true` | the subtree as well as the node |

Indexes: `ux_access_scope_item__access_scope_id__dimension__object_id`,
`ix_access_scope_item__object_id`.

## Group 2. Files and numbers

Two small mechanisms that every domain uses and no domain reimplements.

### `stored_file` — file metadata

The bytes live in the object store; the database holds a reference
([rule 5](../rules/05-types.md)).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `storage_key` | `text` | no | | the key in the object store |
| `file_name` | `text` | no | `ck` length 1–255 | the name as uploaded |
| `content_type` | `text` | no | `ck` length 1–100 | the MIME type |
| `size_bytes` | `bigint` | no | `ck` > 0 | the size |
| `checksum` | `text` | no | `ck` length 64 | SHA-256, for deduplication and integrity |
| `is_scanned` | `boolean` | no | default `false` | passed the malware scan |
| `scanned_at` | `timestamptz` | yes | | |
| `retention_until` | `date` | yes | | when it may be deleted |

Indexes: `ux_stored_file__storage_key`, `ix_stored_file__checksum`,
`ix_stored_file__retention_until` partial `WHERE retention_until IS NOT NULL`.

### `stored_file_link` — a file attached to an entity of any domain

Pattern: [14.9](../rules/14-patterns.md#149-a-typed-link-not-a-foreign-key-per-kind).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `stored_file_id` | `uuid` | no | → `stored_file.id` | the file |
| `entity_kind` | `text` | no | `ck` in the registered entity list | what it is attached to |
| `entity_id` | `uuid` | no | typed link | which one |
| `role` | `text` | no | `ck IN (ATTACHMENT, PHOTO, SIGNATURE, SCAN, GENERATED)` | what the file is to that entity |

Indexes: `ux_stored_file_link__stored_file_id__entity_kind__entity_id__role`,
`ix_stored_file_link__entity_kind__entity_id`.

### `document_number` — allocation of human-facing numbers

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots) — a
series is declared, numbers are drawn from it.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | whose series it is |
| `series` | `text` | no | `ck` `^[A-Z0-9_]+$` | the series code, e.g. `SALES_INVOICE` |
| `year` | `smallint` | yes | `ck` 2000–2100 | set when the series restarts yearly |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | set when the series is per branch |
| `prefix` | `text` | yes | `ck` length 1–10 | printed before the number |
| `next_value` | `bigint` | no | `ck` > 0 | the next number to hand out |
| `is_gapless` | `boolean` | no | default `false` | the law forbids gaps in this series |
| `padding` | `smallint` | no | default 0, `ck` 0–12 | zero-padding of the printed number |

Indexes: `ux_document_number__company_id__series__year__branch_id`.

> This is the **only** counter in the database
> ([rule 3](../rules/03-identifiers.md)): there are no sequences and no identity
> columns. A gapless series is allocated under a row lock and is a deliberate,
> measured throughput cost, taken only where the law requires it.

## Group 3. Work that happens without a user

### `outbox_event` — a domain event awaiting delivery

**Immutable except its delivery state.** The transactional outbox: an event is
written in the same transaction as the change that produced it, so an event is
never lost and never emitted for a rolled-back change.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `event_kind` | `text` | no | `ck` in the declared event list | which event |
| `aggregate_kind` | `text` | no | | what it happened to |
| `aggregate_id` | `uuid` | no | typed link | which one |
| `payload` | `jsonb` | no | | the event body — the one justified `jsonb` in the schema |
| `occurred_at` | `timestamptz` | no | | when the change happened |
| `state` | `text` | no | `ck IN (PENDING, DELIVERED, FAILED, DEAD)` | delivery state |
| `attempt_count` | `smallint` | no | default 0, `ck` ≥ 0 | |
| `next_attempt_at` | `timestamptz` | yes | | back-off |
| `delivered_at` | `timestamptz` | yes | | |
| `last_error` | `text` | yes | `ck` length 1–2000 | |
| `trace_id` | `text` | yes | | ties it to the request that caused it |

Indexes: `ix_outbox_event__state__next_attempt_at` partial `WHERE state IN ('PENDING','FAILED')`,
`ix_outbox_event__aggregate_kind__aggregate_id`, `ix_outbox_event__occurred_at`.

Volume: partitioned by `occurred_at`; delivered partitions are detached after the
retention period ([rule 10](../rules/10-large-tables.md)).

### `background_job` — a declared job and its schedule

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` `^[a-z_]+\.[a-z_]+$` | `<domain>.<job>` |
| `schedule` | `text` | no | | the cron expression |
| `timezone` | `text` | no | default `Asia/Almaty` | the zone the schedule is read in |
| `is_enabled` | `boolean` | no | default `true` | |
| `timeout_seconds` | `integer` | no | `ck` > 0 | when a run is considered hung |
| `max_attempts` | `smallint` | no | default 1, `ck` > 0 | |
| `is_singleton` | `boolean` | no | default `true` | never two runs at once |
| `owner_domain` | `text` | no | `ck` in the domain list | who is paged when it fails |

Indexes: `ux_background_job__code`.

### `job_run` — one execution

**Immutable once finished.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `background_job_id` | `uuid` | no | → `background_job.id` | the job |
| `started_at` | `timestamptz` | no | | |
| `finished_at` | `timestamptz` | yes | | |
| `state` | `text` | no | `ck IN (RUNNING, SUCCEEDED, FAILED, TIMED_OUT, CANCELLED)` | the outcome |
| `attempt` | `smallint` | no | `ck` > 0 | which attempt this was |
| `processed_count` | `integer` | yes | `ck` ≥ 0 | how much work it did |
| `error_message` | `text` | yes | `ck` length 1–2000 | |
| `trace_id` | `text` | yes | | ties it to a trace ([11-observability.md](../../11-observability.md)) |

Indexes: `ix_job_run__background_job_id__started_at`,
`ix_job_run__state` partial `WHERE state = 'RUNNING'`.

## Group 4. Talking to people

One notification mechanism for every channel. A domain does not send an e-mail.

### `notification_template` — the template of a message

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots) and
[14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` `^[A-Z0-9_]+$` | the template code |
| `channel` | `text` | no | `ck IN (EMAIL, SMS, PUSH, IN_APP)` | which channel |
| `locale` | `text` | no | `ck` in the supported list | which language |
| `subject` | `text` | yes | `ck` length 1–255 | for the channels that have one |
| `body` | `text` | no | | the template body |
| `valid_from` | `date` | no | | in use from |
| `valid_to` | `date` | yes | | in use until, exclusive |

Indexes: `ux_notification_template__code__channel__locale__valid_from`.

### `notification` — a message to be delivered

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `notification_template_id` | `uuid` | yes | → `notification_template.id` | the template used |
| `recipient_user_id` | `uuid` | yes | → `app_user.id` | the recipient inside the system |
| `recipient_party_id` | `uuid` | yes | ⇢ `party.party` | the recipient outside it |
| `subject` | `text` | yes | `ck` length 1–255 | the rendered subject |
| `body` | `text` | no | | the rendered body |
| `locale` | `text` | no | `ck` in the supported list | |
| `priority` | `text` | no | `ck IN (LOW, NORMAL, HIGH)` | |
| `source_kind` | `text` | yes | | what raised it |
| `source_id` | `uuid` | yes | typed link | which record |
| `created_for` | `timestamptz` | no | | when it should go out |
| `state` | `text` | no | `ck IN (PENDING, SENT, PARTIALLY_SENT, FAILED, CANCELLED)` | across all its channels |

Indexes: `ix_notification__recipient_user_id__created_at`,
`ix_notification__state__created_for` partial `WHERE state = 'PENDING'`.

### `notification_delivery` — one attempt over one channel

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) —
one row per channel per attempt, never `sms_sent` and `email_sent` columns.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `notification_id` | `uuid` | no | → `notification.id` | the message |
| `channel` | `text` | no | `ck IN (EMAIL, SMS, PUSH, IN_APP)` | which channel |
| `address` | `text` | no | `ck` length 1–255 | the number, the address, the device token |
| `attempt` | `smallint` | no | `ck` > 0 | which attempt |
| `state` | `text` | no | `ck IN (QUEUED, SENT, DELIVERED, READ, FAILED)` | how far it got |
| `sent_at` | `timestamptz` | yes | | |
| `delivered_at` | `timestamptz` | yes | | when the provider confirmed |
| `read_at` | `timestamptz` | yes | | |
| `provider` | `text` | yes | `ck` length 1–40 | which gateway carried it |
| `provider_message_id` | `text` | yes | | its identifier there |
| `error_code` | `text` | yes | `ck` length 1–60 | |
| `cost_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what the message cost |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | its currency |

Indexes: `ux_notification_delivery__notification_id__channel__attempt`,
`ix_notification_delivery__state`,
`ux_notification_delivery__provider__provider_message_id` partial `WHERE provider_message_id IS NOT NULL`.

## Group 5. Reports and settings

### `report_definition` — a declared report

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots) — a
report is declared as data; its parameters are rows, not a form someone codes
([ADR-0009](../../../docs/02-decisions/ADR-0009-reporting-and-exports.md)).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` `^[a-z_]+\.[a-z_]+$` | `<domain>.<report>` |
| `owner_domain` | `text` | no | `ck` in the domain list | who owns it |
| `permission_id` | `uuid` | no | → `permission.id` | what a reader must hold |
| `parameters` | `jsonb` | no | | the parameter declarations — the second justified `jsonb` |
| `output_kinds` | `text` | no | `ck` a comma-free list of `PDF`, `XLSX`, `CSV` | what it can produce |
| `runs_on_replica` | `boolean` | no | default `true` | heavy reads do not touch the primary |
| `max_rows` | `integer` | yes | `ck` > 0 | the export cap |
| `is_active` | `boolean` | no | default `true` | |

Indexes: `ux_report_definition__code`.

### `report_run` — one run, with its artefact

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `report_definition_id` | `uuid` | no | → `report_definition.id` | which report |
| `requested_by` | `uuid` | no | → `app_user.id` | who asked |
| `parameter_values` | `jsonb` | no | | what they asked for — audited, because it is what was seen |
| `state` | `text` | no | `ck IN (QUEUED, RUNNING, READY, FAILED, EXPIRED)` | |
| `started_at` | `timestamptz` | yes | | |
| `finished_at` | `timestamptz` | yes | | |
| `row_count` | `integer` | yes | `ck` ≥ 0 | how much came back |
| `stored_file_id` | `uuid` | yes | → `stored_file.id` | the artefact |
| `expires_at` | `timestamptz` | yes | | when the artefact is deleted |
| `error_message` | `text` | yes | `ck` length 1–2000 | |
| `trace_id` | `text` | yes | | |

Indexes: `ix_report_run__report_definition_id__created_at`,
`ix_report_run__requested_by__created_at`,
`ix_report_run__expires_at` partial `WHERE state = 'READY'`.

### `system_setting` — a named setting with a typed value

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `code` | `text` | no | `ck` `^[a-z_]+\.[a-z_]+$` | the setting name |
| `company_id` | `uuid` | yes | ⇢ `reference.company` | null means the whole system |
| `value_kind` | `text` | no | `ck IN (STRING, INTEGER, DECIMAL, BOOLEAN, DATE, JSON)` | what kind of value it holds |
| `string_value` | `text` | yes | | |
| `integer_value` | `bigint` | yes | | |
| `decimal_value` | `numeric(19,6)` | yes | | |
| `boolean_value` | `boolean` | yes | | |
| `date_value` | `date` | yes | | |
| `json_value` | `jsonb` | yes | | |
| `description` | `text` | no | `ck` length 1–255 | what it does |
| `is_secret` | `boolean` | no | default `false` | never returned by the API, never logged |

Indexes: `ux_system_setting__code__company_id`.
Constraint: `ck_system_setting__one_value` — exactly one value column is set, and
it is the one `value_kind` names.

> Six typed columns rather than one text column, because a setting read as the
> wrong type is a defect discovered in production. A secret is **not** stored
> here at all: `is_secret` marks a setting whose value comes from the secret
> store ([12-environments.md](../../12-environments.md)).

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a per-domain audit table | [`audit`](audit.md), two tables for thirteen domains | 1 |
| a per-domain file table | `stored_file` + `stored_file_link` | 1 |
| a per-channel notification table | `notification` + `notification_delivery` with a `channel` | 1 |
| a sequence, or a table of counters per document kind | `document_number`, one row per series | 1 |
| a session table | sessions are not stored in the database ([ADR-0006](../../../docs/02-decisions/ADR-0006-auth-model.md)) | — |
| a user-preferences table | `app_user.locale`, `app_user.timezone`, and `system_setting` per company | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `app_user` | thousands | regularly |
| `api_client` | tens | rarely |
| `role` | tens | rarely |
| `permission` | hundreds | seed only |
| `role_permission` | thousands | rarely |
| `user_role` | tens of thousands | inserts, plus closing a period |
| `access_scope` | thousands | rarely |
| `access_scope_item` | tens of thousands | rarely |
| `stored_file` | millions, growing | inserts |
| `stored_file_link` | millions, growing | inserts |
| `document_number` | hundreds | one update per document issued |
| `outbox_event` | hundreds of millions, growing | state only |
| `background_job` | tens | rarely |
| `job_run` | millions, growing | **immutable once finished** |
| `notification_template` | hundreds | rarely |
| `notification` | tens of millions, growing | state only |
| `notification_delivery` | hundreds of millions, growing | state only |
| `report_definition` | hundreds | rarely |
| `report_run` | millions, growing | state only |
| `system_setting` | hundreds | rarely |

**20 tables.** Three of them — `outbox_event`, `notification_delivery` and
`job_run` — carry more rows than most domains do, and all three are partitioned
by time with a retention decision recorded before the first release
([rule 10](../rules/10-large-tables.md)).

## Open questions

| # | Question | Affects |
|---|---|---|
| D0-Q1 | Is authentication local, external, or both? | `app_user.authentication_kind`, `password_hash` nullability |
| D0-Q2 | Which document series must be gapless by law? | `document_number.is_gapless`, and the throughput of issuing those documents |
| D0-Q3 | How long is a delivered `outbox_event` kept? | partitioning and retention |
| D0-Q4 | Are in-app notifications a channel, or a separate inbox? | `notification_delivery.channel`, and whether D12 `message` overlaps this |
| D0-Q5 | Which settings are per company and which are global? | `system_setting.company_id` nullability per code |
