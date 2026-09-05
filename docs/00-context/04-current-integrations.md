---
id: CTX-04
title: External integrations and API consumers
status: draft
---

# External integrations and API consumers

Everything connected to WERP from the outside. Every entry is an obligation the
new system takes on without changing the contract
([C-05](03-constraints.md#c-05-external-integrations-cannot-be-changed)).

Taking inventory of the contracts is mandatory Phase 0 work
([EPIC-002](../../backlog/EPIC-002-contract-inventory.md)); this table is its
starting point, not its result.

## Connection diagram

```
                 external world
                      │
                 ┌────┴─────┐
                 │  bridge  │   Go, route allowlist, not rewritten
                 └────┬─────┘
        ┌─────────────┼─────────────┬──────────────┐
        ▼             ▼             ▼              ▼
     auth          core         service          crm
        │             │             │              │
        └─────────────┴──────┬──────┴──────────────┘
                             ▼
                         database
```

The web frontend calls the internal services **directly**, bypassing `bridge`
(hence the hardcoded environment addresses in the bundle —
[P-08](02-pain-points.md#p-08-environment-configuration-is-baked-into-the-code)).
The target diagram changes that — see
[product/01-architecture.md](../../product/01-architecture.md).

## Outbound and inbound integrations (through `bridge`)

| Integration | Direction | What it does | Who owns the contract |
|---|---|---|---|
| Payment provider | inbound | accepting payments, reconciliation | the counterparty |
| Credit bureau | outbound | credit score by customer identifier | the counterparty |
| SMS provider | outbound + webhook | broadcasts and delivery reports | the counterparty |
| Messenger (WhatsApp) | two-way | sending, receiving, message list | the counterparty |
| Public site forms | inbound | leads from landing pages → CRM | ours, but public |
| Messenger super-app | inbound | requests, electronic signature | the counterparty |
| Messenger for operators | two-way | integrated directly into the call centre, bypassing `bridge` | the counterparty |

## Consumers of the internal API

| Consumer | Through what | Contract rigidity | Rewritten? |
|---|---|---|---|
| Web frontend | directly | we define the contract | **yes**, together with the backend |
| Mobile app | `bridge`, a fixed path allowlist | **1:1, changes forbidden** | no ([C-06](03-constraints.md#c-06-the-mobile-app--a-separate-client-outside-this-plan)) |
| Legacy JSF | shared cookies, shared DB | will be decommissioned | no, removed |
| External integrations | `bridge` | 1:1 | no |
| Internal services calling each other | Feign / HTTP | we define the contract | yes |

## What this means for the plan

1. **`bridge` is the responsibility boundary.** Everything behind it we rewrite
   freely. Everything in front of it is an obligation to third parties. The only
   requirement on the new system: provide `bridge` with the same set of internal
   endpoints.

2. **The mobile contract is the project's hardest constraint.** The list of paths
   opened to the mobile app is fixed in `bridge`
   (`internal/routes/mobile.go`) — a ready, verified specification of the
   mandatory minimum. It becomes the input for
   [EPIC-002](../../backlog/EPIC-002-contract-inventory.md).

3. **Internal calls between services currently go through Feign** — under a big
   bang this layer disappears together with the old topology, and there is no
   need to replace it one for one.

4. **The messenger for operators is connected to the call centre directly**,
   bypassing `bridge` — this is an exception to the general scheme. When
   rewriting, it must either be routed through `bridge` (preferable, for
   uniformity) or the exception must be recorded explicitly in an ADR.

## What needs clarifying

- The full list of counterparties with active contracts and SLAs — `?`
- Whether there are integrations known only to operations (cron exports, file
  exchange, direct DB access from external systems) — `?`

→ [OQ-005](../../transition/12-open-questions.md)
