---
id: PROD-03-S-PARTY
title: "party schema — D2 Counterparties"
status: draft
---

# `party` — D2 Counterparties

| | |
|---|---|
| Domain | D2 Counterparties ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **16** |
| State of the model | **drafted** — the columns are the designer's proposal, not confirmed by the owner |
| Table groups | 5 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `party`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md), which are not repeated
below.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

**The schema exists to make one statement true:** a person or an organization the
company deals with exists **once**, and every document in every domain points at
that one row. A contract does not carry a customer's telephone number; a service
order does not carry their name; a case does not carry their address. A corrected
number is corrected once and every document is correct from that moment
([14.6](../rules/14-patterns.md#146-one-identity-many-roles)).

This is the schema whose shape decides whether the rest of the system can be
kept honest, and it is designed immediately after
[`reference`](reference.md).

## Group 1. Identity

One root table, two tables of the attributes only one kind of party has. A party
is a person or an organization and is never both.

### `party` — anyone the company deals with

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `kind` | `text` | no | `ck IN (PERSON, ORGANIZATION)` | which of the two it is |
| `company_id` | `uuid` | no | ⇢ `reference.company` | whose counterparty it is |
| `code` | `text` | no | | the counterparty number, from `platform.document_number` |
| `display_name` | `text` | no | `ck` length 1–255 | how the party is shown in a list; **derived**, generated `STORED` from the person's or organization's name |
| `is_active` | `boolean` | no | default `true` | dealt with |
| `preferred_locale` | `text` | yes | `ck` in the supported list | which language to address them in |
| `source` | `text` | no | `ck IN (SALES, CALL_CENTRE, REFERRAL, IMPORT, WEB, MIGRATION)` | where the record came from |
| `merged_into_party_id` | `uuid` | yes | → `party.id` | set when this record was merged into another |

Indexes: `ux_party__company_id__code`,
`ix_party__display_name_trgm` (GIN, trigrams) — the search every screen uses,
`ix_party__kind`,
`ix_party__merged_into_party_id` partial `WHERE merged_into_party_id IS NOT NULL`.

> Duplicate counterparties are created by every call centre in the world.
> `merged_into_party_id` makes the merge **non-destructive**: the losing row stays
> and forwards, so a document written against it a year ago still resolves. A
> merge that deletes rows breaks history and can never be undone.

### `person` — the attributes only a natural person has

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the identity |
| `first_name` | `text` | no | `ck` length 1–100 | |
| `middle_name` | `text` | yes | `ck` length 1–100 | |
| `last_name` | `text` | yes | `ck` length 1–100 | |
| `birth_date` | `date` | yes | | |
| `gender` | `text` | yes | `ck IN (FEMALE, MALE, UNSPECIFIED)` | |
| `citizenship_country_id` | `uuid` | yes | ⇢ `reference.country` | |
| `marital_status_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `MARITAL_STATUS` | |
| `is_deceased` | `boolean` | no | default `false` | stops every automated contact |
| `deceased_on` | `date` | yes | | |

Indexes: `ux_person__party_id`,
`ix_person__last_name__first_name`,
`ix_person__birth_date`.

Names are **not** translated: a proper name is the same in every language
([rule 6](../rules/06-localization.md)).

### `organization` — the attributes only a legal entity has

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the identity |
| `name` | `text` | no | `ck` length 1–255 | the trading name |
| `full_name` | `text` | yes | `ck` length 1–500 | the full legal name |
| `legal_form_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `LEGAL_FORM` | |
| `registration_country_id` | `uuid` | yes | ⇢ `reference.country` | |
| `registered_on` | `date` | yes | | |
| `industry_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `INDUSTRY` | |
| `employee_count` | `integer` | yes | `ck` ≥ 0 | for segmentation |
| `is_vat_registered` | `boolean` | no | default `false` | changes how it is invoiced |

Indexes: `ux_organization__party_id`, `ix_organization__name_trgm` (GIN).

## Group 2. Legal identity

What the state calls the party, and the documents that prove it. Kept apart from
the identity itself because a party may hold several, and because they expire.

### `party_identifier` — a state identifier

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) —
one row per identifier, never a column per country's scheme.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the party |
| `kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `PARTY_IDENTIFIER_KIND` | taxpayer number, individual number, registration number |
| `country_id` | `uuid` | no | ⇢ `reference.country` | which state issued it |
| `value` | `text` | no | `ck` length 1–40 | the identifier |
| `is_primary` | `boolean` | no | default `false` | the one shown by default |
| `verified_at` | `timestamptz` | yes | | when it was checked against a register |

Indexes: `ux_party_identifier__country_id__kind_id__value`,
`ix_party_identifier__party_id`.

The unique index across country and kind is what makes duplicate detection
possible at all: the same identifier appearing twice is the strongest available
signal that two rows are one party.

### `identity_document` — a passport or its equivalent

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the party |
| `kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `IDENTITY_DOCUMENT_KIND` | passport, identity card, residence permit |
| `series` | `text` | yes | `ck` length 1–10 | |
| `number` | `text` | no | `ck` length 1–40 | |
| `issued_by` | `text` | yes | `ck` length 1–255 | the issuing authority |
| `issued_on` | `date` | no | | |
| `valid_from` | `date` | no | | valid from |
| `valid_to` | `date` | yes | `ck` > `valid_from` | valid until, exclusive |
| `stored_file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the scan |

Indexes: `ix_identity_document__party_id__valid_from`,
`ix_identity_document__valid_to`,
`ux_identity_document__kind_id__series__number`.

> A second document is a **row**, not `passport_id2`, `passport_given_by2` and
> `passport_validity2` ([rule 2](../rules/02-naming.md#22-six-prohibitions)). A
> person renewing a passport gets a new row and the old one keeps its period, so
> a contract signed under the old document still resolves.

## Group 3. Roles and standing

What the party is **to us**, and how we currently treat them. Both period-dated,
because both change and both are asked about retrospectively.

### `party_role` — what the party is to the company

Pattern: [14.6](../rules/14-patterns.md#146-one-identity-many-roles) and
[14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the party |
| `role` | `text` | no | `ck IN (CUSTOMER, SUPPLIER, DEALER, FITTER, COLLECTOR, PARTNER, LEAD, GUARANTOR)` | which role |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | the branch the role is played at |
| `valid_from` | `date` | no | | from |
| `valid_to` | `date` | yes | | until, exclusive |

Indexes: `ix_party_role__party_id__role`,
`ix_party_role__role__valid_to` partial `WHERE valid_to IS NULL`.
Constraint: `ex_party_role__no_overlap` on (`party_id`, `role`, `branch_id`, the
date range).

> One party, several roles. The same person may be a customer, then a dealer,
> then both. Three tables — a customers table, a dealers table, a suppliers
> table — would store the same telephone number three times and let the three
> disagree.

### `party_status` — how the party is currently treated

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the party |
| `status_id` | `uuid` | no | ⇢ `reference.reference_item` in list `PARTY_STATUS` | blacklisted, VIP, do-not-call, in dispute |
| `reason` | `text` | yes | `ck` length 1–500 | why |
| `document_id` | `uuid` | yes | ⇢ `docflow.document` | the decision that set it |
| `valid_from` | `date` | no | | from |
| `valid_to` | `date` | yes | | until, exclusive |

Indexes: `ix_party_status__party_id__valid_from`,
`ix_party_status__status_id__valid_to` partial `WHERE valid_to IS NULL`.
Constraint: `ex_party_status__no_overlap` on (`party_id`, `status_id`, the date
range).

## Group 4. How to reach them

Three typed value tables and three link tables. The value tables are separate
because an address, a telephone number and an e-mail address genuinely differ in
their columns and in the format each is checked against
([rule 5](../rules/05-types.md)) — collapsing them into one contact table would
mean giving up every one of those checks.

The **link** tables are what make a value shareable: one address serves a
household of four parties, and correcting it corrects it for all four.

### `address` — one address, structured

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `country_id` | `uuid` | no | ⇢ `reference.country` | |
| `region_id` | `uuid` | yes | ⇢ `reference.region` | |
| `city_id` | `uuid` | yes | ⇢ `reference.city` | |
| `postal_code` | `text` | yes | `ck` length 1–20 | |
| `street` | `text` | yes | `ck` length 1–255 | |
| `house` | `text` | yes | `ck` length 1–20 | |
| `building` | `text` | yes | `ck` length 1–20 | |
| `apartment` | `text` | yes | `ck` length 1–20 | |
| `line` | `text` | no | `ck` length 1–500 | the address on one line; generated `STORED` from the parts above |
| `latitude` | `numeric(9,6)` | yes | `ck` −90…90 | |
| `longitude` | `numeric(9,6)` | yes | `ck` −180…180 | |
| `geocoded_at` | `timestamptz` | yes | | when the coordinates were resolved |
| `is_verified` | `boolean` | no | default `false` | confirmed by a visit or by a register |

Indexes: `ix_address__city_id__street`,
`ix_address__line_trgm` (GIN),
`ix_address__latitude__longitude` partial `WHERE latitude IS NOT NULL` — the
route-planning query in D8.

Coordinates are `numeric(9,6)`, not text and not `double precision`
([rule 5](../rules/05-types.md)).

### `address_link` — an address attached to a party in a role

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the party |
| `address_id` | `uuid` | no | → `address.id` | the address |
| `role` | `text` | no | `ck IN (REGISTERED, RESIDENTIAL, WORK, DELIVERY, SERVICE, BILLING)` | what the address is to them |
| `is_primary` | `boolean` | no | default `false` | the default for that role |
| `valid_from` | `date` | no | | from |
| `valid_to` | `date` | yes | | until, exclusive |

Indexes: `ix_address_link__party_id__role`, `ix_address_link__address_id`,
`ux_address_link__party_id__role__is_primary` partial `WHERE is_primary AND valid_to IS NULL`.

### `phone` — one number in E.164

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `number` | `text` | no | `ck` E.164 format | the number, one format, one column |
| `country_id` | `uuid` | yes | ⇢ `reference.country` | resolved from the prefix |
| `is_mobile` | `boolean` | yes | | resolved from the numbering plan |
| `is_valid` | `boolean` | no | default `true` | cleared when a call proves it dead |
| `invalidated_at` | `timestamptz` | yes | | |

Indexes: `ux_phone__number`.

**One row per number in the whole system.** That is what makes "who else has this
number" answerable, which is the question the call centre asks on every inbound
call.

### `phone_link` — a number attached to a party in a role

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the party |
| `phone_id` | `uuid` | no | → `phone.id` | the number |
| `role` | `text` | no | `ck IN (MOBILE, HOME, WORK, CONTACT_PERSON, EMERGENCY)` | what the number is to them |
| `is_primary` | `boolean` | no | default `false` | |
| `contact_person_name` | `text` | yes | `ck` length 1–255 | whose phone it is, when it is not the party's own |
| `valid_from` | `date` | no | | from |
| `valid_to` | `date` | yes | | until, exclusive |

Indexes: `ix_phone_link__party_id__role`, `ix_phone_link__phone_id`.

### `phone_channel` — which channels the number is reachable on

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) —
one row per channel, never `has_whatsapp` and `has_telegram` columns.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `phone_id` | `uuid` | no | → `phone.id` | the number |
| `channel_id` | `uuid` | no | ⇢ `reference.reference_item` in list `PHONE_CHANNEL` | voice, SMS, and the messengers |
| `is_reachable` | `boolean` | no | default `true` | |
| `checked_at` | `timestamptz` | yes | | when it was last confirmed |
| `consent_given_at` | `timestamptz` | yes | | when the party agreed to be contacted this way |
| `consent_withdrawn_at` | `timestamptz` | yes | | and when they withdrew it |

Indexes: `ux_phone_channel__phone_id__channel_id`.

Consent is stored per channel, because that is the granularity the law and the
party both use. A fifth messenger is a row in `PHONE_CHANNEL`.

### `email` — one address

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `address` | `text` | no | `ck` e-mail format, lower case | the address |
| `is_valid` | `boolean` | no | default `true` | cleared on a hard bounce |
| `bounced_at` | `timestamptz` | yes | | |
| `consent_given_at` | `timestamptz` | yes | | |
| `consent_withdrawn_at` | `timestamptz` | yes | | |

Indexes: `ux_email__address`.

### `email_link` — an address attached to a party in a role

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the party |
| `email_id` | `uuid` | no | → `email.id` | the address |
| `role` | `text` | no | `ck IN (PERSONAL, WORK, BILLING, NOTIFICATION)` | what it is to them |
| `is_primary` | `boolean` | no | default `false` | |
| `valid_from` | `date` | no | | from |
| `valid_to` | `date` | yes | | until, exclusive |

Indexes: `ix_email_link__party_id__role`, `ix_email_link__email_id`.

## Group 5. Whether to trust them

### `credit_rating` — an assessment of a counterparty

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `party_id` | `uuid` | no | → `party.id` | the party |
| `score` | `integer` | no | `ck` 0–1000 | the assessed score |
| `grade` | `text` | no | `ck IN (A, B, C, D, E)` | the band the score falls in |
| `credit_limit_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what may be extended |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | its currency |
| `decided_by` | `uuid` | yes | ⇢ `platform.app_user` | who set it, when it was set by hand |
| `valid_from` | `date` | no | | from |
| `valid_to` | `date` | yes | | until, exclusive |

Indexes: `ix_credit_rating__party_id__valid_from`,
`ix_credit_rating__valid_to` partial `WHERE valid_to IS NULL`.
Constraint: `ex_credit_rating__no_overlap` on (`party_id`, the date range);
`ck_credit_rating__limit_has_currency`.

### `credit_rating_check` — one verification behind an assessment

**Immutable.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `credit_rating_id` | `uuid` | no | → `credit_rating.id` | the assessment |
| `source` | `text` | no | `ck IN (CREDIT_BUREAU, TAX_REGISTER, INTERNAL_HISTORY, COURT_REGISTER, MANUAL)` | where the evidence came from |
| `checked_at` | `timestamptz` | no | | when |
| `outcome` | `text` | no | `ck IN (CLEAR, FLAGGED, REFUSED, UNAVAILABLE)` | what came back |
| `detail` | `text` | yes | `ck` length 1–2000 | what it said |
| `external_reference` | `text` | yes | `ck` length 1–100 | the enquiry identifier at the source |

Indexes: `ix_credit_rating_check__credit_rating_id`,
`ix_credit_rating_check__source__checked_at`.

The checks are kept because an assessment has to be defensible months later, and
because a bureau enquiry costs money and should not be repeated.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a customers table, a suppliers table, a dealers table | `party` + `party_role` | 1 |
| address and telephone columns on a contract, a service order or a case | `address_link`, `phone_link` | 1 |
| a one-line `full_address` and a one-line `full_phone` maintained by a trigger | the link tables; a read model if a denormalized read is measured to be needed | 1, and [rule 9](../rules/09-logic-in-the-database.md) |
| `passport_2`, `phone_2`, `email_2` columns | rows in `identity_document`, `phone_link`, `email_link` | 2 |
| a `has_whatsapp` / `has_telegram` pair of columns | `phone_channel` | 2 |
| a blacklist table | `party_status` with a status and a period | 1 |
| a table of merged duplicates | `party.merged_into_party_id` | 3 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `party` | millions | regularly |
| `person` | millions | rarely |
| `organization` | tens of thousands | rarely |
| `party_identifier` | millions | rarely |
| `identity_document` | millions | inserts |
| `party_role` | millions | inserts, plus closing a period |
| `party_status` | hundreds of thousands | inserts, plus closing a period |
| `address` | millions | rarely |
| `address_link` | millions | inserts, plus closing a period |
| `phone` | millions | rarely |
| `phone_link` | millions | inserts, plus closing a period |
| `phone_channel` | millions | regularly |
| `email` | hundreds of thousands | rarely |
| `email_link` | hundreds of thousands | inserts, plus closing a period |
| `credit_rating` | millions | inserts, plus closing a period |
| `credit_rating_check` | millions | **immutable** |

**16 tables.** Everything in this schema is personal data: access, export and
retention follow [08-security.md](../../08-security.md), and every export of a
counterparty list is audited with the filter that produced it.

## Open questions

| # | Question | Affects |
|---|---|---|
| D2-Q1 | Is a counterparty scoped to a company, or shared across the group? | `ux_party__company_id__code`, and every cross-company report |
| D2-Q2 | What is the duplicate-detection rule, and is a merge reversible? | `merged_into_party_id`, `party_identifier` uniqueness |
| D2-Q3 | Are contact persons of an organization needed — a person linked to an organization in a role? | a seventeenth table, `party_relation` |
| D2-Q4 | Is consent required per channel by law, and from what date? | `phone_channel`, `email` consent columns, and every campaign |
| D2-Q5 | Who assigns a credit rating, and is it computed or entered? | `credit_rating.decided_by`, `credit_rating_check.source` |
| D2-Q6 | How long is a counterparty's personal data kept after the last contract ends? | retention, and the right to erasure |
