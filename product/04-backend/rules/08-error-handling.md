---
id: PROD-04-R08
title: "Backend rule 8. Error handling"
status: draft
---

## Error handling

- One exception hierarchy; a domain exception carries a machine-readable code.
- An exception is not swallowed: it is either handled or propagated with context.
- Conversion into an HTTP response happens **in one place**, not in every
  controller.
- The client never receives a stack trace, a class name, SQL text or a table name.

---
