---
id: PROD-03-R11
title: "Rule 11. Audit"
status: draft
---

## 11. Audit

- Audit is a platform subsystem, uniform across all domains, not an ORM mechanism
  switched on according to a domain's taste.
- **What gets audited is the domain owner's decision, recorded explicitly** in
  the domain's specification. Auditing everything and auditing nothing are
  equally useless.
- An audit record is immutable and contains: the subject, the moment, the entity,
  the action, the previous and the new values, and the request identifier that
  ties it to a trace ([11-observability.md](../../11-observability.md)).
- It is stored in the `audit` schema, not next to the domain's data, and never in
  a table shaped like the audited one.
- The retention period — [OQ-003](../../../transition/12-open-questions.md#oq-003).
