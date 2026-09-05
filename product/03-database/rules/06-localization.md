---
id: PROD-03-R06
title: "Rule 6. Localization in data"
status: draft
---

## 6. Localization in data

Translatable values are **not stored as columns** (`name`, `name_kk`, `name_en`):
adding a language must not require a schema migration, and a partially filled
language must not be invisible.

```
reference.country          id, code, ...
reference.country_name     country_id, locale, name    ux(country_id, locale)
```

The locale column is checked against the list of supported locales
([ADR-0010](../../../docs/02-decisions/ADR-0010-i18n.md)); the locale code is the same
string everywhere in the system, in one spelling.

Proper names — a company, a branch, a person, a product item — are **not**
translated: they are the same in every language.

Interface texts and error messages are not stored in the database at all.
