---
id: PROD-05-R05
title: "API rule 5. Errors"
status: draft
---

## Errors

One format for the whole system:

```json
{
  "code": "contract.not_found",
  "message": "Договор не найден",
  "details": [ { "field": "contractId", "code": "not_found" } ],
  "traceId": "..."
}
```

- `code` — machine-readable, stable, part of the contract; the client makes
  decisions on it.
- `message` — localized text for a human
  ([ADR-0010](../../../docs/02-decisions/ADR-0010-i18n.md)).
- `traceId` — for searching the logs
  ([product/11-observability.md](../../11-observability.md)).
- A stack trace, a class name, SQL text and table names never reach the client.

Status codes: `400` — a malformed request, `401` — not authenticated, `403` — no
permission, `404` — not found, `409` — a state conflict, `422` — semantically
invalid, `429` — a limit exceeded, `5xx` — our error.
