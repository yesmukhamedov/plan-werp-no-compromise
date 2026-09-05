---
id: PROD-03-R02
title: "Rule 2. Naming"
status: draft
---

## 2. Naming

### 2.1 Objects

| Object | Rule | Example |
|---|---|---|
| Schema | `snake_case`, the domain code | `accounting` |
| Table | `snake_case`, **singular** | `contract`, `journal_entry` |
| Join table | `<a>_<b>`, alphabetical | `contract_product` |
| Child table | `<parent>_<part>` | `journal_entry_line` |
| Localized-name table | `<parent>_name` | `country_name` |
| Column | `snake_case` | `created_at`, `total_amount` |
| Primary key | **always** `id` | |
| Foreign key column | `<entity>_id` | `customer_id` |
| Self-reference | `parent_id` | |
| Boolean | `is_<property>` / `has_<property>` | `is_active` |
| Point in time | `<action>_at` | `approved_at` |
| Date without a time | `<action>_date` | `posting_date` |
| Amount | `<meaning>_amount` + `<meaning>_currency_id` | `total_amount` |
| Quantity | `<meaning>_quantity` | `ordered_quantity` |
| Enumeration column | a noun, no suffix | `kind`, `status`, `source` |
| Index | `ix_<table>__<columns>` | `ix_branch__company_id` |
| Unique index | `ux_<table>__<columns>` | `ux_country__code` |
| Check constraint | `ck_<table>__<meaning>` | `ck_contract__amount_positive` |
| Foreign key constraint | `fk_<table>__<column>` | `fk_branch__company_id` |
| Exclusion constraint | `ex_<table>__<meaning>` | `ex_price__no_overlap` |
| Trigger | `tg_<table>__<what it maintains>` | `tg_branch__path` |
| Partition | `<table>_<key>` | `journal_entry_2027` |

### 2.2 Six prohibitions

1. **No abbreviation that has to be looked up.** A column name is understandable
   to a person opening the schema for the first time. `posting_key`, not `bschl`.
   Only abbreviations a domain expert uses out loud survive — and they are listed
   in [GLOSSARY.md](../../../GLOSSARY.md) with their expansion.
2. **No transliteration.** Neither in table names, nor in column names, nor in
   enumeration values.
3. **One meaning — one name, everywhere.** A country identifier is `country_id`
   in every table of the system. The name of a concept is fixed once in
   [GLOSSARY.md](../../../GLOSSARY.md) and is the same in the schema, the API, the code
   and the interface.
4. **A name does not encode a type or a length.** The column holding a name is
   `name`. Names like `text45`, `num2`, `varchar_field` do not exist.
5. **A name is not numbered.** `note` and `note2`, `address_1` and `address_2`,
   `f1 … f6` are forbidden. A second value of the same kind is a **row in a
   child table**, not a second column. The only exception is a pair whose members
   have genuinely different meanings, and then they are named by those meanings
   (`home_address_id`, `work_address_id`), never by an ordinal.
6. **A name does not encode lifecycle.** No `_old`, `_new`, `_tmp`, `_temp`,
   `_backup`, `_archive`, `_copy`, `_his`, `_2` on any object. A historical row
   is the same table with a status or a validity period; a superseded table is
   deleted by a migration.
