---
id: PROD-04-M-DOMAINS
title: "Domain modules — D1 … D12"
status: draft
---

# Domain modules — D1 … D12

Twelve modules, one per business domain of the [map](../../02-domains.md). Each owns
exactly one schema, and the module name **is** the schema name — one meaning, one
name ([rule 2 of the database](../../03-database/rules/02-naming.md#22-six-prohibitions)).

For each module below: the aggregate roots it stores (which is what determines
its repositories), the API resources it exposes (which is what determines its
controllers), the named domain rules it must enforce, and the events it
publishes.

**Those four lists are derived, not invented.** An aggregate root comes from the
schema's model section; a resource comes from its table groups; a named rule is
one the database cannot express and the schema file states explicitly. That is
why a module can be inventoried before its specification is written — and why the
inventory is worth checking against the specification when it is.

## The registry

| Module | Domain | Schema | Aggregate roots | Resources | Named rules | State | Classes |
|---|---|---|---:|---:|---:|---|---:|
| `reference` | D1 Reference data | [reference](../../03-database/schemas/reference.md) | 5 | 12 | 4 | **designed** | ~90 |
| `party` | D2 Counterparties | [party](../../03-database/schemas/party.md) | 5 | 5 | 3 | drafted | ~60 |
| `hr` | D3 Personnel | [hr](../../03-database/schemas/hr.md) | 8 | 11 | 11 | **designed** | ~160 |
| `contract` | D4 Contracts and sales | [contract](../../03-database/schemas/contract.md) | 9 | 8 | 5 | drafted | ~150 |
| `accounting` | D5 Accounting and finance | [accounting](../../03-database/schemas/accounting.md) | 8 | 15 | 8 | **designed** | ~200 |
| `payroll` | D6 Compensation calculation | [payroll](../../03-database/schemas/payroll.md) | 4 | 4 | 4 | drafted | ~90 |
| `inventory` | D7 Warehouse and logistics | [inventory](../../03-database/schemas/inventory.md) | 9 | 8 | 6 | drafted | ~170 |
| `service` | D8 Field service | [service](../../03-database/schemas/service.md) | 9 | 9 | 7 | drafted | ~200 |
| `crm` | D9 CRM and call centre | [crm](../../03-database/schemas/crm.md) | 6 | 6 | 4 | drafted | ~130 |
| `docflow` | D10 Document workflow | [docflow](../../03-database/schemas/docflow.md) | 4 | 4 | 4 | drafted | ~50 |
| `legal` | D11 Legal | [legal](../../03-database/schemas/legal.md) | 2 | 3 | 2 | declared | ~25 |
| `tasks` | D12 Tasks and communications | [tasks](../../03-database/schemas/tasks.md) | 3 | 3 | 2 | drafted | ~55 |

**The class counts are for planning volume only.** How many classes a module ends
up with becomes clear when it is designed; their origin is
[transition/02-backend-mapping.md](../../../transition/02-backend-mapping.md).
The counts for the three designed modules are exact and come from their
specifications.

`inventory` was called `logistics` when the module registry was first drawn. It
is now named after its schema, because a module and its schema differing in name
is exactly the kind of small inconsistency that costs a search every time someone
new joins.

---

## `reference` — D1

Specification: **[spec/D1-reference.md](../../spec/D1-reference.md)** — written in
full, and the sample the other twelve are held to.

| | |
|---|---|
| Aggregate roots → repositories | `Company`, `Country`, `Currency`, `ProductCategory`, `ReferenceList` |
| Resources → controllers | companies, branches, warehouses, countries, regions, cities, currencies, exchange rates, products, product categories, units, reference items |
| Named rules | `BranchTreeRule`, `SingleMainWarehouseRule`, `RateChronologyRule`, `DeactivationRule` |
| Domain services | `BranchService`, `ExchangeRateService` |
| Events | `CompanyChanged`, `BranchChanged`, `BranchDeactivated`, `WarehouseChanged`, `ProductChanged`, `ProductDeactivated`, `ExchangeRateAdded`, `ReferenceItemChanged` |

**Twelve modules use this one**, which is why its facade is deliberately the
narrowest in the system and why `resolveNames` exists: so that a caller
displaying a name next to an identifier does not pull a whole reference list.

## `party` — D2

Schema drafted; specification not written. **The next module to design** — five
others point at it.

| | |
|---|---|
| Aggregate roots → repositories | `Party`, `Address`, `Phone`, `Email`, `CreditRating` |
| Resources → controllers | parties, addresses, phones, emails, credit ratings |
| Named rules | `SinglePrimaryPerRoleRule`, `MergeIsNonDestructiveRule`, `ConsentRequiredForChannelRule` |
| Domain services | `PartyMergeService`, `DuplicateDetectionService` |
| Events | `PartyCreated`, `PartyMerged`, `PartyStatusChanged`, `PhoneInvalidated`, `AddressChanged` |

The facade this module exposes is the second most used in the system. Its shape
decides whether other domains copy contact data or reference it — which is the
single defect the schema exists to prevent.

## `hr` — D3

Specification: **[spec/D3-hr.md](../../spec/D3-hr.md)** — written in full.

| | |
|---|---|
| Aggregate roots → repositories | `OrgUnit`, `Job`, `Position`, `Employee`, `Employment`, `Absence`, `TimeSheet`, `Course` |
| Resources → controllers | org units, jobs, positions, employees, employments, absences, time sheets, training, certifications, expenses, reports |
| Named rules | 11, from `OrgUnitTreeRule` to `CertificationFromCourseRule` |
| Domain services | `EmploymentService`, `WorkingCalendarService`, `EntitlementService`, `OrgStructureService` |
| Events | `EmploymentStarted`, `EmploymentEnded`, `AssignmentChanged`, `CompensationChanged`, `AbsenceApproved`, `TimeSheetLocked`, `CertificationExpired`, `OrgUnitChanged` |

`EmploymentService` is deliberately one service rather than seven handlers each
doing its own period arithmetic: closing an assignment, opening the next and
writing the event is one operation, and doing two of the three is the defect the
design exists to prevent.

**Every read on this module's facade takes a date.** `getEmploymentAt`, not
`getEmployment` — an interface that cannot say "as at" forces every caller to
assume "as at now".

## `contract` — D4

| | |
|---|---|
| Aggregate roots → repositories | `Contract`, `ContractType`, `PaymentTemplate`, `PaymentSchedule`, `PriceList`, `Promotion`, `SalesPlan`, `ReferralLink`, `ESignatureRequest` |
| Resources → controllers | contracts, contract types, payment schedules, payment templates, price lists, promotions, sales plans, signatures |
| Named rules | `ScheduleRevisionIsNotAnEditRule`, `SinglePriceListAppliesRule`, `PromotionConditionRule`, `NoSelfReferralRule`, `IssuedScheduleIsImmutableRule` |
| Domain services | `ScheduleGenerationService`, `PricingService`, `PromotionService` |
| Events | `ContractSigned`, `ContractActivated`, `ContractSuspended`, `ContractTerminated`, `ScheduleRevised`, `ReferralConverted` |

`ScheduleGenerationService` is the module's centre of gravity: a schedule is
generated from a `payment_template`, and a re-schedule produces a **new
revision** rather than editing entries — so what the customer was told last year
is still on file.

## `accounting` — D5

Specification: **[spec/D5-accounting.md](../../spec/D5-accounting.md)** — written
in full.

| | |
|---|---|
| Aggregate roots → repositories | `Account`, `FiscalYear`, `Journal`, `JournalEntry`, `PostingRule`, `OpenItem`, `Invoice`, `Payment`, `Budget`, `StatementDefinition` |
| Resources → controllers | 15, from accounts to reports |
| Named rules | `BalancedEntryRule`, `PostingPeriodRule`, `ControlAccountRule`, `PostableAccountIsLeafRule`, `LineDimensionRule`, `IssuedInvoiceIsImmutableRule`, `ApplicationWithinAmountRule`, `PostingRuleBalancesRule` |
| Domain services | `PostingEngine`, `SettlementService`, `PeriodCloseService`, `BalanceRebuildService`, `StatementBuilder` |
| Events | `EntryPosted`, `EntryReversed`, `InvoiceIssued`, `PaymentApplied`, `OpenItemCleared`, `PeriodClosed`, `PeriodReopened`, `BudgetApproved` |

**`PostingRequest` names an event and a source document, not a set of accounts.**
Which accounts the entry hits is `posting_rule`'s answer, not the caller's — and
that is the single most important module boundary in the system: no other domain
knows an account number.

## `payroll` — D6

| | |
|---|---|
| Aggregate roots → repositories | `PayrollComponent`, `PayrollRate`, `PayrollInput`, `PayrollRun` |
| Resources → controllers | components, rates, inputs, runs |
| Named rules | `ComponentSequenceRule`, `RateAppliesAtDateRule`, `RecalculationIsANewRunRule`, `PayslipLineRecordsItsSourceRule` |
| Domain services | `PayrollEngine`, `TaxBaseService` |
| Events | `PayrollCalculated`, `PayrollApproved`, `PayrollPosted`, `PayrollPaid` |

`PayrollEngine` evaluates components **in the order the data says**
(`payroll_component.sequence`), not in the order methods appear in a class. That
is what makes a new deduction a row rather than a release, and it is why this
module is a fifth the size of the calculation it replaces.

This module **reads `hr.compensation` and never writes it.** What was agreed is
D3's; what was calculated is D6's.

## `inventory` — D7

| | |
|---|---|
| Aggregate roots → repositories | `StockItem`, `StockMovement`, `StockBalance`, `StockReservation`, `StockDocument`, `PurchaseOrder`, `SupplierPrice`, `Stocktake`, `AccountableItem` |
| Resources → controllers | stock items, movements, balances, stock documents, purchase orders, stocktakes, accountable items, limits |
| Named rules | `MovementIsAppendOnlyRule`, `ReservationWithinAvailableRule`, `TransferHasBothWarehousesRule`, `ValuationLayerConsumptionRule`, `ReceiptWithinToleranceRule`, `CustodyIsExclusiveRule` |
| Domain services | `MovementService`, `BalanceRebuildService`, `ValuationService`, `ReservationExpiryService` |
| Events | `StockReceived`, `StockIssued`, `StockTransferred`, `StockWrittenOff`, `ReservationExpired`, `StocktakePosted` |

`MovementService` is the only writer of `stock_movement`, and the movement table
is append-only: a correction is a compensating row. Everything else in the module
— balances, valuation, custody — is derived from it and rebuildable.

## `service` — D8

| | |
|---|---|
| Aggregate roots → repositories | `InstalledUnit`, `Warranty`, `ServiceRequest`, `MaintenanceProgram`, `MaintenancePlan`, `ServicePackage`, `SparePart`, `UpgradeOffer`, `PremiumRule` |
| Resources → controllers | installed units, service requests, appointments, service orders, maintenance programs, maintenance plans, packages, spare parts, upgrade offers |
| Named rules | `ProgramAppliesUnambiguouslyRule`, `SlotClosedByOrderLineRule`, `TechnicianIsNotInTwoPlacesRule`, `WarrantyDecidesChargeabilityRule`, `MandatorySlotSkipVoidsWarrantyRule`, `PlanRegenerationPreservesDoneSlotsRule`, `PremiumRuleAppliesUnambiguouslyRule` |
| Domain services | `MaintenancePlanService`, `RoutePlanningService`, `PremiumService`, `ChargeabilityService` |
| Events | `UnitInstalled`, `UnitRemoved`, `RequestRaised`, `OrderCompleted`, `SlotClosed`, `SlotOverdue`, `PremiumEarned` |

`MaintenancePlanService` generates a plan's slots from a program's positions and
regenerates them when the program changes. **It contains no number of
positions.** A product line serviced in six positions and one serviced in one go
through the same code; a seventh position is a row of reference data.

That single property is the reason the domain was designed the way it was, and it
is the one to check first when reviewing this module's code.

## `crm` — D9

| | |
|---|---|
| Aggregate roots → repositories | `Case`, `Activity`, `Referral`, `Checklist`, `KpiDefinition`, `KpiFact` |
| Resources → controllers | cases, activities, referrals, checklists, key indicators, reports |
| Named rules | `ActivityKindColumnsRule`, `ReferralPhoneIsAPartyPhoneRule`, `ChecklistAnswerMatchesKindRule`, `SingleKpiFactPerPeriodRule` |
| Domain services | `CaseRoutingService`, `ActivityService`, `KpiComputationService` |
| Events | `CaseOpened`, `CaseResolved`, `ActivityCompleted`, `ReferralConverted`, `KpiRecomputed` |

One `Activity` aggregate for a call, a demonstration, a visit and a meeting. A
counterparty's history is then one query ordered by one column, rather than four
queries merged in date order by every screen that shows it — and one of the four
always being forgotten.

## `docflow` — D10

| | |
|---|---|
| Aggregate roots → repositories | `DocumentType`, `DocumentTemplate`, `Route`, `Document` |
| Resources → controllers | document types, routes, documents, templates |
| Named rules | `RouteAppliesUnambiguouslyRule`, `ApproverResolvesToAPersonRule`, `RouteIsFrozenAtSubmissionRule`, `DelegationIsRecordedRule` |
| Domain services | `ApprovalEngine`, `RouteResolutionService`, `DocumentRenderService` |
| Events | `DocumentSubmitted`, `DocumentApproved`, `DocumentRejected`, `DocumentExecuted` |

**Eight tables and one engine serve thirteen domains.** `ApprovalEngine` resolves
an approver through `hr.assignment` from the seat the route names, so a route
keeps working when a person leaves.

## `legal` — D11

Status `declared`: whether the domain exists as a system responsibility at all is
a question for the business
([02-domains.md](../../02-domains.md#what-must-be-confirmed-with-the-business-before-g1)).

| | |
|---|---|
| Aggregate roots → repositories | `CourtCase`, `Claim` |
| Resources → controllers | court cases, claims, recovery actions |
| Named rules | `RecoveryBelongsToCaseOrClaimRule`, `RecoveredWithinAwardedRule` |
| Events | `ClaimSent`, `CaseFiled`, `CaseClosed`, `DebtRecovered` |

The module holds no amount owed of its own: the debt is
`accounting.open_item`, and this module points at it.

## `tasks` — D12

| | |
|---|---|
| Aggregate roots → repositories | `Task`, `TaskCategory`, `Message` |
| Resources → controllers | tasks, task categories, messages |
| Named rules | `UnassignedTaskBelongsToAUnitRule`, `BroadcastIsNotExpandedRule` |
| Domain services | `TaskRoutingService` |
| Events | `TaskCreated`, `TaskAssigned`, `TaskCompleted`, `MessageSent` |

**One task mechanism for the whole system.** A domain that needs a task links to
`Task`; it does not grow a task table. Messages to people *outside* the system
are not here at all — they are `platform-notification`.

---

## Development order

Following the dependency graph
([02-domains.md](../../02-domains.md#dependency-graph)). **A module does not start
before the one it depends on**, and a module does not start before its schema is
`designed`:

```
platform (12 modules)
   └ reference ──┬── party ──┬── hr ──┬── payroll
                 │           │        │
                 │           └── contract ──┬── accounting ──┬── payroll
                 │                          │                │
                 │                          ├── crm          ├── inventory ── service
                 │                          └── legal        └── legal
                 └ docflow, tasks (need only the platform)
```

In more detail —
[transition/plan/03-phase-2-domains.md](../../../transition/plan/03-phase-2-domains.md#order).

Three modules can start today: `reference`, `hr` and `accounting` have designed
schemas and written specifications. `party` blocks five others and is therefore
the highest-value schema to move from drafted to designed next.
