---
id: PROD-05-R09
title: "API rule 9. Long-running operations"
status: draft
---

## Long-running operations

An operation that does not fit inside the response time budget
([07-nfr.md](../../07-nfr.md)) returns `202` and a job identifier; the client either
polls the state through a separate endpoint or receives a notification. That is
how heavy reports
([ADR-0009](../../../docs/02-decisions/ADR-0009-reporting-and-exports.md)), bulk
uploads and recalculations work.

---
