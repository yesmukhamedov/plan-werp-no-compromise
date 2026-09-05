---
id: PROD-04-R07
title: "Backend rule 7. Cross-domain interaction"
status: draft
---

## Cross-domain interaction

Two ways; there is no third:

| Way | When | Transaction |
|---|---|---|
| Calling another domain's `Facade` | the result is needed now, the operation is logically single | shared |
| Publishing an event | another domain must react, the result is not needed | published in the source's transaction, processed separately |

An event is published through a transactional outbox: it cannot be lost when the
transaction rolls back and cannot be published if the transaction did not
complete.
