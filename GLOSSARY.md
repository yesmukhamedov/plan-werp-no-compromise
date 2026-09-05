# Glossary

One domain entity — one name across the whole system: in the code, in the API,
in the data schema, in the interface and in conversation
([01-principles/03-engineering-standards.md](docs/01-principles/03-engineering-standards.md#naming)).

The glossary grows as the project goes. The "Inherited names" section is filled
in [EPIC-003](backlog/EPIC-003-schema-inventory.md); the "Domains" section is
refined together with the business before gate G1.

---

## Plan terms

| Term | Meaning |
|---|---|
| **WERP** | the in-house ERP system, the subject of the rewrite |
| **Legacy** | all three generations of the current system, to be replaced |
| **New WERP** | the target system |
| **Big bang** | the transition strategy: parallel development, a single cutover ([ADR-0001](docs/02-decisions/ADR-0001-strategy-big-bang.md)) |
| **Cutover** | the moment users are switched over to the new system |
| **Shadow run** | duplicating read requests into the new system and comparing the responses ([transition/06-parity-verification.md](transition/06-parity-verification.md)) |
| **Parity** | proven behavioural equivalence of the new and the old system |
| **Accepted divergence** | a difference in behaviour signed off in writing by the business |
| **Freeze** | restricting changes to the legacy for the duration of the project ([transition/09-freeze-policy.md](transition/09-freeze-policy.md)) |
| **Delta backlog** | new-WERP work items produced by changes made to the legacy during the freeze |
| **Gate** | a checkpoint with formal conditions for passing it ([transition/plan/00-roadmap.md](transition/plan/00-roadmap.md#gates)) |
| **Characterization test** | a test that pins down the legacy's current behaviour, bugs included ([EPIC-004](backlog/EPIC-004-characterization-tests.md)) |
| **Rehearsal** | a full run of the data migration against a copy of production data |
| **Decision point** | the moment during the cutover after which rollback becomes expensive |
| **NC-NN** | a "no compromise" rule ([01-principles/01-no-compromise.md](docs/01-principles/01-no-compromise.md)) |
| **P-NN** | a pain point of the current system ([00-context/02-pain-points.md](docs/00-context/02-pain-points.md)) |
| **`[STACK]`** | marker: depends on the not-yet-chosen backend stack ([ADR-0003](docs/02-decisions/ADR-0003-backend-stack.md)) |

## Domains

From the [domain map](product/02-domains.md). Refined with the business before G1.

| Code | Domain | Responsible for |
|---|---|---|
| D0 | Platform | access, audit, reports, files, notifications, background jobs, observability |
| D1 | Reference data | companies, branches, countries, currencies, categories, goods |
| D2 | Counterparties | customers, addresses, phone numbers, communication channels |
| D3 | Personnel | headcount, positions, salaries, training |
| D4 | Contracts and sales | contracts, price lists, terms, payment schedules |
| D5 | Accounting and finance | journal entries, invoices, payments, reconciliations, reporting |
| D6 | Compensation calculation | payroll, bonuses, accruals, deductions |
| D7 | Warehouse and logistics | materials, delivery notes, stock balances, items on account |
| D8 | Field service | service requests, plans, spare parts, warranty |
| D9 | CRM and call centre | cases, calls, requests, demonstrations |
| D10 | Document workflow | internal documents, approval routes |
| D11 | Legal | court cases, debt recovery, claims |
| D12 | Internal tasks and communications | tasks, messages, broadcasts |

## Inherited names

Names in the existing schema that a reader cannot decode. Occurrence counts are
measured over the schema
([transition/map/00-source-inventory.md](transition/map/00-source-inventory.md));
469 columns and 51 tables carry one of them.

Transliteration and undecodable abbreviations are forbidden in the new system
([rule 2](product/03-database/rules/02-naming.md#22-six-prohibitions)): every one
gets a meaningful replacement.

### From the third-party ERP's nomenclature

These are standard names of a well-documented accounting package, so their
meaning is a fact rather than a guess. What is **not** a fact is whether WERP
uses each of them for the same thing — that column is marked where it needs
confirmation.

| Old | Columns | Meaning | New name |
|---|---:|---|---|
| `bukrs` | 133 | company code | `company_id` |
| `matnr` | 100 | material number — a product item | `product_id`, `article` |
| `waers` | 45 | currency key | `currency_id` |
| `werks` | 36 | plant; in WERP used for a warehouse — **confirm** | `warehouse_id` |
| `dmbtr` | 21 | amount in the accounting currency | `amount` + `currency_id` |
| `gjahr` | 20 | fiscal year | `fiscal_year` |
| `spras` | 19 | language key | `locale` |
| `hkont` | 14 | general ledger account | `account_id` |
| `wrbtr` | 12 | amount in the document currency | `document_amount` + `document_currency_id` |
| `belnr` | 9 | accounting document number | `entry_number` |
| `monat` | 8 | fiscal period | `fiscal_period` |
| `shkzg` | 7 | debit/credit indicator | `side` (`DEBIT` / `CREDIT`) |
| `bldat` | 7 | document date | `document_date` |
| `meins` | 6 | base unit of measure | `unit_id` |
| `blart` | 5 | document type | `kind` |
| `bschl` | 5 | posting key | `posting_key` |
| `buzei` | 5 | line item number within a document | `line_number` |
| `lifnr` | 4 | vendor | `supplier_id` |
| `budat` | 4 | posting date | `posting_date` |
| `sgtxt` | 4 | line item text | `description` |
| `kunnr` | 3 | customer | `customer_id` |
| `koart` | 2 | account type | `account_kind` |
| `kursf` | 6 | exchange rate | `exchange_rate` |
| `awkey` | 37 | reference key of the originating object | `source_document_id` + `source_document_kind` |
| `bkpf` | table | accounting document header | `accounting.journal_entry` |
| `bseg` | table | accounting document line items | `accounting.journal_entry_line` |
| `skat` | table | general ledger account names | `accounting.account` + `account_name` |
| `bsik` | table | open vendor items | a query over `journal_entry_line` |
| `fmglflext` | table | ledger totals | `accounting.gl_balance` |

### Type-encoding and truncated names

| Old | Columns | Meaning | New name |
|---|---:|---|---|
| `text45`, `text20`, `text10` | 23 | a name or a description; the number is the column's old length | `name`, `description` |
| `brnch` | 19 | branch | `branch_id` |
| `dep` | 15 | department or unit — **confirm which** | `org_unit_id` |
| `cus`, `sn` | 25 | customer, serial number | `customer_id`, `serial_number` |
| `f1 … f6` | 36 in one table | the maintenance positions of an installed unit — the replaceable cartridges of a water purifier | rows of `service.maintenance_slot` |
| `fno` | 2 | how many positions the unit has: 5 or 6 for a purifier, 1 for a vacuum cleaner | `maintenance_program.slot_count` |
| `vc` | in two table names | vacuum cleaner — the second serviced product line | `product_type`, not a table name |
| `mt`, `sid` | 44 | attributes of a maintenance position — **needs decoding** | — |

### Transliterated from Russian

| Old | Columns | Meaning | New name |
|---|---:|---|---|
| `tovar` | 29 | goods, a product item | `product_id`, `product_serial` |
| `addr_dom`, `tel_dom` | 21 | home address, home telephone | `address_link.role = HOME` |
| `addr_rab`, `tel_rab` | 16 | work address, work telephone | `address_link.role = WORK` |
| `skidka_vol` | 1 | discount | `discount_amount` |
| `fiz_yur` | table | natural person / legal entity | `party.kind` |
| `prikaz` | table | a personnel order | `docflow.document` |
| `migvozn` | table | **needs decoding** | — |
| `vnitru` | 1 | internal | `is_internal` |
| `kassa24` | table | the name of a payment gateway | `payment_gateway_receipt` |

### Module and table names whose purpose is unknown

Not decodable from the data and not guessed. Each requires a person who knows
([OQ-004](transition/12-open-questions.md#oq-004)).

| Old | What is known | Decision |
|---|---|---|
| `aes` | 9 tables, 21 rows in total, an accounting module | decide or delete |
| `newdev` | a code module, no tables of its own | decide or delete |
| `rfcol` | 1 table, 86,265 rows, 20 columns | find the consumer |
| `fact_table` | 1 table, 7 rows, 14 columns | find the consumer |
| `zf` in `serv_zf_branch_month_terms` | service premium terms per branch and month | decode the prefix |
| `ph_` | prefix of 25 shadow tables carrying the schema's foreign keys | not migrated |
| `dit` | internal IT: tasks, messages, SMS, access restrictions | splits across D0 and D12 |
| `mreference` | a second implementation of reference data | splits across D1 and D2 |

> The unknown rows are filled by interviewing the people who hold the knowledge,
> not by guessing. A guess that makes it into the schema lives for twelve years —
> which is exactly what happened with the original abbreviations.

## Domain terms

Filled in as the interviews in [EPIC-011](backlog/EPIC-011-scenario-registry.md)
proceed.

| Term | Meaning | Domain |
|---|---|---|
| | | |
