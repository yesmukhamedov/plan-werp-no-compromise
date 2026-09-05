---
id: TRANS-12
title: Open questions
status: draft
---

# Open questions

Questions whose answers change the plan. Each has an owner and the gate by which
it must be closed.

**A question deferred in Phase 0 surfaces in Phase 4 and costs ten times as
much.**

## Summary

| # | Question | Blocks | Who answers |
|---|---|---|---|
| [OQ-001](#oq-001) | The team's composition and size | G0 | management |
| [OQ-002](#oq-002) | Which implementation of the duplicated domains is the source of truth | G0 | the domain owners |
| [OQ-003](#oq-003) | Regulators' requirements on data | G1 | legal, information security |
| [OQ-004](#oq-004) | The purpose of the `aes` and `newdev` modules | G0 | the people who hold the knowledge |
| [OQ-005](#oq-005) | The full list of external integrations | G0 | operations, the business |
| [OQ-006](#oq-006) | The PostgreSQL topology, RPO/RTO | G1 | operations |
| [OQ-007](#oq-007) | Business logic in Oracle | G0 | **answered** |
| [OQ-008](#oq-008) | Client requirements: offline, tablets, browsers | G1 | the business |
| [OQ-009](#oq-009) | Single sign-on with the corporate directory | G1 | IT |
| [OQ-010](#oq-010) | Who maintains the translations after launch | G1 | the business |
| [OQ-011](#oq-011) | The cutover window and the stabilization period | G2 | the business, operations |
| [OQ-012](#oq-012) | What lives only in `werp_jsf` | **G0** | the people who hold the knowledge |
| [OQ-013](#oq-013) | Whether domains D10 and D11 are needed in the new system | G0 | the business |
| [OQ-014](#oq-014) | Whether usage data for endpoints and reports exists | G0 | operations |
| [OQ-015](#oq-015) | What maintains the 22 budget tables | **G0** | the business, finance |

---

## OQ-001

**The team's composition and size for the duration of the project.**

Without an answer, the estimates in person-months cannot be converted into a
calendar, and planning the phases is impossible. Additionally: are there
dedicated roles — an architect, a data owner, an infrastructure owner, domain
owners on the business side.

→ [transition/10-estimates.md](10-estimates.md),
[C-11](../docs/00-context/03-constraints.md#c-11-team-and-budget-)

## OQ-002

**Which of the duplicated implementations is the source of truth?**

CRM is implemented twice (the `crm` module on Oracle and the `werp_crm`
repository on PostgreSQL), reference data twice (`reference` and `mreference`),
field service twice, and on the frontend there are `crm` and `crm2021` plus two
call centres.

For each pair we need: which one is in use, for which scenarios, and how the
behaviour differs.

→ [R-10](11-risks.md#r-10),
[product/02-domains.md](../product/02-domains.md)

## OQ-003

**Regulators' requirements on personal data and retention.**

Retention periods for primary documents; requirements for localizing personal
data; requirements for the immutability of financial operation logs; requirements
for logging access to personal data.

The answer may add a substantial amount of work.

→ [product/08-security.md](../product/08-security.md),
[C-12](../docs/00-context/03-constraints.md#c-12-regulators-data-retention-requirements-)

## OQ-004

**What are `aes` and `newdev`?**

5,778 lines in two modules with a non-obvious purpose. `aes` contains entities
that look like fixed-asset accounting; `newdev` deals with "requests". We need:
the purpose, the users, whether the module is alive, and the target domain.

→ [product/02-domains.md](../product/02-domains.md)

## OQ-005

**The full list of external integrations.**

The known ones are listed in
[CTX-04](../docs/00-context/04-current-integrations.md). We need confirmation
that the list is complete, including: cron exports, file exchange, direct
database access by external systems, integrations known only to operations.

A missed integration will be discovered on the night of the cutover.

## OQ-006

**The PostgreSQL topology and the target recovery figures.**

The version, replicas, failover, backups, RPO, RTO.

→ [product/07-nfr.md](../product/07-nfr.md#availability),
[ADR-0002](../docs/02-decisions/ADR-0002-database-postgresql.md)

## OQ-007

**Does Oracle hold business logic invisible from the application code?**

**Answered, 2026-09-03: almost none.** The schema was read object by object
([map/00-source-inventory.md](map/00-source-inventory.md#4-objects-other-than-tables)):
0 packages, 2 functions, 6 procedures, 3 views, 43 triggers of which 41 do
little but assign a primary key from a sequence. One procedure carries a
business rule worth moving (`UPDATE_INSTALLMENT_DATE`); two are unidentified and
need their caller found.

The feared unestimated volume is not there. [R-05](11-risks.md#r-05) drops from
a scope risk to two decisions.

→ [R-05](11-risks.md#r-05),
[EPIC-003](../backlog/EPIC-003-schema-inventory.md)

## OQ-008

**Requirements on the client application.**

Is offline operation needed (warehouse, field service)? Tablets? The minimum
supported browsers? The answer affects the frontend architecture.

→ [ADR-0004](../docs/02-decisions/ADR-0004-frontend-stack.md)

## OQ-009

**Is single sign-on with the corporate directory (LDAP / AD) required?**

It affects the choice of identity provider and the migration of accounts.

→ [ADR-0006](../docs/02-decisions/ADR-0006-auth-model.md)

## OQ-010

**Who maintains the translations after launch?**

A developer in the code, or a content owner through a translation tool. It
affects the choice of message store.

→ [ADR-0010](../docs/02-decisions/ADR-0010-i18n.md)

## OQ-011

**The acceptable downtime window for the cutover and the stabilization period.**

Provisionally: a window of ≤ 8 h, stabilization of 30 days. Requires confirmation
by the business and by operations — the entire data migration strategy depends on
the window.

→ [transition/07-cutover.md](07-cutover.md), [R-13](11-risks.md#r-13)

## OQ-012

**Which functionality lives only in `werp_jsf`?**

**The plan's most important open question.** 233,913 lines of legacy in
production, 33 links from React. If a substantial part of the functionality
exists only there, the project's volume is noticeably larger than estimated.
Additionally: does the legacy MySQL data overlap with Oracle.

To be closed **before G0** — the estimates, the domain map and the data migration
volume all depend on the answer.

→ [R-06](11-risks.md#r-06),
[transition/10-estimates.md](10-estimates.md)

## OQ-013

**Are domains D10 (document workflow) and D11 (legal) needed in the new
system?**

3,573 lines in total. An off-the-shelf solution or dropping them may be cheaper.
The decision is a product one.

→ [product/02-domains.md](../product/02-domains.md)

## OQ-014

**Is there usage data for endpoints, reports and tables?**

Without it, "migrate / do not migrate" decisions are taken from memory. If the
data does not exist, collecting it has to be switched on in the legacy in the
first week of Phase 0.

→ [transition/plan/01-phase-0-foundation.md](plan/01-phase-0-foundation.md#inventory-is-not-documentation)

## OQ-015

**What writes and reads the 22 budget tables, and is budgeting in scope?**

`BUDGET_*` holds about 83,000 rows — overheads, salaries, sales allocations,
historical exchange rates — and the word `budget` appears in **none** of the five
repositories, backend or frontend
([map/01-schema-in-code.md](map/01-schema-in-code.md#the-22-budget-tables-have-no-application-at-all)).
Something outside the application maintains them; the Power BI integration is the
likely candidate but is not confirmed.

Two answers are possible and they differ by a lot of work: budgeting is a live
business process the new system must absorb, or it is a spreadsheet-and-Power-BI
practice that stays outside. Until it is answered, the scope of D5 is unknown.

→ [map/01-schema-in-code.md](map/01-schema-in-code.md),
[product/02-domains.md](../product/02-domains.md)

---

## Closed questions

| # | Question | Answer | Date |
|---|---|---|---|
| — | The transition strategy | big bang, [ADR-0001](../docs/02-decisions/ADR-0001-strategy-big-bang.md) | 2026-09-03 |
| — | The DBMS | PostgreSQL, [ADR-0002](../docs/02-decisions/ADR-0002-database-postgresql.md) | 2026-09-03 |
