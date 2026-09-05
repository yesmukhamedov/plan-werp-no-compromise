---
id: PROD-05-R01
title: "API rule 1. Versioning"
status: draft
---

## Versioning

- The version goes in the path: `/api/v1/...`. One version for the whole system,
  not per domain.
- Within a version only compatible changes are allowed: adding an optional field,
  adding an endpoint, adding a value to an enumeration (if the client is obliged
  to ignore unknown ones).
- A breaking change = a new version. The old one lives until all clients have
  confirmed they no longer use it.
- Compatibility is checked automatically on every PR; a breaking change without a
  version bump is not merged.
