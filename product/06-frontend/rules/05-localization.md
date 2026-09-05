---
id: PROD-06-R05
title: "Frontend rule 5. Localization"
status: draft
---

## Localization

Three languages (ru / en / tr). All texts come from the message system; there are
no string literals in components, and this is checked by the linter. Numbers,
dates and currencies are formatted according to the user's locale by a single
mechanism ([ADR-0010](../../../docs/02-decisions/ADR-0010-i18n.md)).
