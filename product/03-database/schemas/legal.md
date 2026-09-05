---
id: PROD-03-S-LEGAL
title: "legal schema — D11 Legal"
status: draft
---

# `legal` — D11 Legal

| | |
|---|---|
| Domain | D11 Legal ([02-domains.md](../../02-domains.md)) |
| Domain specification | not written |
| Tables | **4** |
| State of the model | **drafted** — and the schema itself is only `declared`: whether the domain exists as a system responsibility at all is a question for the business |
| Table groups | 2 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `legal`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md), which are not repeated
below.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint ([rule 1](../rules/01-organization.md)) |

**Read the status before the tables.** This is the smallest schema in the system
and the least certain. Whether the company wants court work tracked here, in an
off-the-shelf legal product, or not at all is
[a question for the business before gate G1](../../02-domains.md).

The boundary that matters if it is kept: **debt collection in the field is D5**
([`accounting.collection_plan`](accounting.md)), and **the debt itself is
`accounting.open_item`**. This schema begins where persuasion ends and
proceedings begin. It never holds an amount owed of its own; it points at the
open items it is recovering.

## Group 1. Proceedings

### `court_case` — a case the company is party to

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `number` | `text` | no | | the internal number, from `platform.document_number` |
| `court_reference` | `text` | yes | `ck` length 1–60 | the court's own case number |
| `kind` | `text` | no | `ck IN (DEBT_RECOVERY, CONTRACT_DISPUTE, LABOUR, CONSUMER_CLAIM, ADMINISTRATIVE, OTHER)` | |
| `our_side` | `text` | no | `ck IN (CLAIMANT, RESPONDENT, THIRD_PARTY)` | which side the company is on |
| `opponent_party_id` | `uuid` | no | ⇢ `party.party` | the other side |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | the contract in dispute |
| `court_name` | `text` | yes | `ck` length 1–255 | |
| `city_id` | `uuid` | yes | ⇢ `reference.city` | where it is heard |
| `lawyer_employee_id` | `uuid` | yes | ⇢ `hr.employee` | who is conducting it |
| `filed_on` | `date` | yes | | |
| `next_hearing_at` | `timestamptz` | yes | | |
| `claim_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what is being claimed |
| `awarded_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what was awarded |
| `recovered_amount` | `numeric(19,4)` | no | default 0, `ck` ≥ 0 | what has actually come in |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | governs every amount in the row |
| `state` | `text` | no | `ck IN (PREPARING, FILED, IN_HEARING, JUDGMENT, APPEAL, ENFORCEMENT, CLOSED_WON, CLOSED_LOST, SETTLED, WITHDRAWN)` | |
| `closed_on` | `date` | yes | | |
| `outcome_note` | `text` | yes | `ck` length 1–2000 | |

Indexes: `ux_court_case__company_id__number`,
`ix_court_case__opponent_party_id`,
`ix_court_case__lawyer_employee_id__state`,
`ix_court_case__next_hearing_at` partial `WHERE state NOT LIKE 'CLOSED%'`,
`ix_court_case__contract_id` partial `WHERE contract_id IS NOT NULL`.
Constraint: `ck_court_case__amount_has_currency`;
`ck_court_case__recovered_within_awarded`.

`recovered_amount` is maintained by the aggregate from the payments applied
against the case's open items — it is a convenience for the lawyer's screen, and
the authoritative figure is always
[`accounting.open_item`](accounting.md).

### `claim` — a claim made or received

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — a claim the
company sends and a claim it receives are one table with a direction. Most claims
never become court cases, and a claim that does keeps its history.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | |
| `number` | `text` | no | | from `platform.document_number` |
| `direction` | `text` | no | `ck IN (OUTGOING, INCOMING)` | who is claiming |
| `party_id` | `uuid` | no | ⇢ `party.party` | the other side |
| `contract_id` | `uuid` | yes | ⇢ `contract.contract` | |
| `court_case_id` | `uuid` | yes | → `court_case.id` | the case it grew into |
| `basis_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `CLAIM_BASIS` | what it is founded on |
| `sent_on` | `date` | yes | | |
| `respond_by` | `date` | yes | | the deadline for a reply |
| `responded_on` | `date` | yes | | |
| `amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |
| `state` | `text` | no | `ck IN (DRAFT, SENT, ACKNOWLEDGED, SATISFIED, REJECTED, ESCALATED, WITHDRAWN, EXPIRED)` | |
| `document_id` | `uuid` | yes | ⇢ `docflow.document` | the approved letter |

Indexes: `ux_claim__company_id__number`,
`ix_claim__party_id__sent_on`,
`ix_claim__court_case_id` partial `WHERE court_case_id IS NOT NULL`,
`ix_claim__respond_by` partial `WHERE state = 'SENT'`.
Constraint: `ck_claim__amount_has_currency`.

## Group 2. Recovery and history

### `recovery_action` — a step in recovering a debt

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — every kind of
enforcement step is one table with a `kind`, because they are listed together,
counted together and chased by the same person.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `court_case_id` | `uuid` | yes | → `court_case.id` | the case it belongs to |
| `claim_id` | `uuid` | yes | → `claim.id` | or the claim |
| `party_id` | `uuid` | no | ⇢ `party.party` | the debtor |
| `kind` | `text` | no | `ck IN (DEMAND_LETTER, WRIT_APPLICATION, WRIT_ISSUED, BAILIFF_REFERRAL, ASSET_SEIZURE, TRAVEL_BAN, PAYMENT_AGREEMENT, WRITE_OFF_PROPOSAL)` | which step |
| `taken_on` | `date` | no | | |
| `due_on` | `date` | yes | | when the next move is expected |
| `state` | `text` | no | `ck IN (PLANNED, TAKEN, SUCCEEDED, FAILED, CANCELLED)` | |
| `amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what the step concerns |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | |
| `external_reference` | `text` | yes | `ck` length 1–60 | the bailiff's or registry's reference |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | who took it |
| `stored_file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the document produced |
| `note` | `text` | yes | `ck` length 1–2000 | |

Indexes: `ix_recovery_action__court_case_id__taken_on`,
`ix_recovery_action__claim_id`,
`ix_recovery_action__party_id__taken_on`,
`ix_recovery_action__due_on` partial `WHERE state = 'PLANNED'`.
Constraint: `ck_recovery_action__belongs_to_something`
(at least one of `court_case_id`, `claim_id` is set);
`ck_recovery_action__amount_has_currency`.

### `court_case_event` — the case history

**Immutable.** Pattern:
[14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance) — the ledger;
`court_case.state` is its derived state.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `court_case_id` | `uuid` | no | → `court_case.id` | |
| `kind` | `text` | no | `ck IN (FILED, HEARING_SCHEDULED, HEARING_HELD, ADJOURNED, JUDGMENT, APPEAL_FILED, SETTLED, ENFORCEMENT_STARTED, CLOSED, COMMENTED)` | |
| `occurred_at` | `timestamptz` | no | | |
| `employee_id` | `uuid` | yes | ⇢ `hr.employee` | |
| `previous_state` | `text` | yes | | |
| `new_state` | `text` | yes | | |
| `stored_file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the ruling, the minute, the notice |
| `note` | `text` | yes | `ck` length 1–4000 | |

Indexes: `ix_court_case_event__court_case_id__occurred_at`,
`ix_court_case_event__kind__occurred_at`.

The table is named `court_case_event` rather than `case_event` because
[`crm.case`](crm.md) is a different thing entirely, and one meaning must have one
name across the whole system
([rule 2](../rules/02-naming.md#22-six-prohibitions)) — which also means two
different meanings must not share one.

## Tables that deliberately do not exist

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| a debt table | `accounting.open_item` — the debt is an accounting fact | 1 |
| a table per enforcement step | `recovery_action` with a `kind` | 1 |
| a separate table for incoming claims | `claim.direction` | 1 |
| a hearings table | `court_case_event` with `kind = HEARING_HELD` | 1 |
| a field-collection table | `accounting.collection_plan` and `collection_visit` | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `court_case` | tens of thousands | state changes |
| `claim` | hundreds of thousands | state changes |
| `recovery_action` | millions | state changes |
| `court_case_event` | millions | **immutable** |

**4 tables.** None is near a volume threshold, and none needs partitioning.

Case files are personal data and often carry data about health, family and
finances that the rest of the system does not hold. Access follows
[08-security.md](../../08-security.md) and is expected to be the narrowest in the
system: the legal team and nobody else.

## Open questions

| # | Question | Affects |
|---|---|---|
| D11-Q1 | Is the domain in scope at all, or is an off-the-shelf product or nothing cheaper? | the existence of this schema — [02-domains.md](../../02-domains.md) |
| D11-Q2 | Where does debt collection stop being D5 and start being D11? | `recovery_action.kind = DEMAND_LETTER`, and the boundary with `accounting.collection_plan` |
| D11-Q3 | Is an integration with the court or bailiff registry in scope? | `external_reference`, and whether states arrive automatically |
| D11-Q4 | Who may read a case file, and are labour cases restricted further? | permissions, and possibly a second scope dimension |
| D11-Q5 | How long is a closed case kept? | retention |
