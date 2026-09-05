---
id: PROD-SPEC-D5
title: D5 Accounting and finance — full specification
status: designed
domain: D5
owner: not assigned
---

# D5. Accounting and finance

DB schema: `accounting` · Module: `accounting` · API: `/api/v1/accounting` ·
Interface section: `pages/accounting`

Written to the depth set by [D1](D1-reference.md)
([spec/README.md](README.md#d1--the-reference-sample)). The structural forms it
uses are the ones named in
[rule 14](../03-database/rules/14-patterns.md); each table below
says which.

---

## Purpose and boundaries

The general ledger and everything that feeds it: the chart of accounts, the
fiscal calendar, double-entry posting, account determination, the receivable and
payable subledgers, billing, tax, payments, banking and cash, budgeting,
financial statements.

**The domain's key property:** this is the only place in the system where money
becomes final. Every other domain *proposes* a financial fact — a contract
proposes a claim, a warehouse proposes a valuation, payroll proposes a cost —
and the ledger *posts* it. Nothing is posted twice, and nothing that is posted
is ever edited.

**In scope:** accounts, periods, journal entries and their lines, balances, open
items, invoices, taxes, payments, bank accounts and statements, deposits,
budgets, statement layouts, debt-collection planning.

**Out of scope:**

| What | Where | Why not here |
|---|---|---|
| Payroll calculation | D6 Compensation | the ledger receives the result as a posting; it does not compute it |
| Contract terms, price lists, payment schedules | D4 Contracts | a schedule is a commitment; an invoice is a claim; they are different facts with different lifetimes |
| Stock quantities and movements | D7 Warehouse | the warehouse owns the quantity, the ledger owns the value |
| Counterparty identity, addresses, phone numbers | D2 Counterparties | an invoice references a party, it never copies one |
| Court proceedings and enforcement | D11 Legal | recovering a debt in court is not an accounting entry |
| Rendering, scheduling and export of reports | D0 Platform | one reporting mechanism for the whole system ([ADR-0009](../../docs/02-decisions/ADR-0009-reporting-and-exports.md)) |
| Chart-of-accounts *names* shown to a user, in their language | here, but in `account_name` | [localization](../03-database/rules/06-localization.md) |

## Model

Eight aggregates. An aggregate is the transaction boundary; a reference between
aggregates is by identifier.

| Aggregate | Root | Composition | Invariants |
|---|---|---|---|
| Chart of accounts | `account` | `account_name`, `account_dimension_rule` | the account number is unique within a company; only a leaf may be posted to; an account has exactly one nature and one normal side; a control account is posted to only from its subledger |
| Fiscal calendar | `fiscal_year` | `fiscal_period` | the periods of a year do not overlap and leave no gap; a period has exactly one state; a closed period never reopens without a recorded decision |
| Journal entry | `journal_entry` | `journal_entry_line` | debits equal credits, in the transaction currency and in the functional currency; every line names an account, a side and an amount; the entry belongs to exactly one open period; **the entry is immutable** |
| Account determination | `posting_rule` | `posting_rule_line` | a rule's lines balance by construction; at most one rule of a given event applies to a given document at a given date |
| Open item | `open_item` | `open_item_application` | the applied amount never exceeds the item amount; an item is cleared exactly when they are equal; an application is immutable |
| Invoice | `invoice` | `invoice_line`, `invoice_tax` | the line net equals quantity × price − discount; the invoice gross equals Σ line net + Σ tax; an issued invoice is immutable and is cancelled, never edited |
| Payment | `payment` | — | a payment's applications never exceed its amount; a returned payment reverses its posting rather than deleting it |
| Budget | `budget` | `budget_line` | at most one figure per budget, period, account and dimension set; an approved budget is immutable and superseded by a new revision |

### Double entry is the domain's one law

`journal_entry_line.side` is `DEBIT` or `CREDIT`; `amount` is always positive and
the side carries the sign. For every entry:

```
Σ amount WHERE side = DEBIT  =  Σ amount WHERE side = CREDIT     per currency
Σ functional_amount DEBIT    =  Σ functional_amount CREDIT
```

An entry that does not balance does not exist. This is the invariant the database
cannot express — it spans rows of a child table — so it is carried three ways at
once, exactly as [§7](../03-database/rules/07-constraints.md) requires of such an
invariant:

1. the header carries `debit_amount` and `credit_amount` with
   `ck_journal_entry__balanced` (`debit_amount = credit_amount`);
2. the application rule `BalancedEntryRule` refuses to write lines that do not
   sum to the header, and is covered by a test that writes through the repository
   directly;
3. the nightly job `EntryBalanceReconciliation` re-sums every line of the period
   against its header, and **any divergence is an alert**, not a report line.

### Every amount exists twice

A line carries the amount in the currency the business event happened in, and the
amount in the company's functional currency, plus the rate that converted them:

| Column | Meaning |
|---|---|
| `amount`, `currency_id` | the transaction currency — what was actually agreed |
| `functional_amount`, `functional_currency_id` | the company's accounting currency — what the statements are built from |
| `exchange_rate`, `rate_date` (on the entry) | the conversion that produced the second from the first |

Storing the rate on the entry is what makes a five-year-old figure reproducible.
Recomputing it later from today's rate table produces a different number and
silently rewrites history.

A third, group currency is **not** stored. If consolidation across companies with
different functional currencies is ever required, it is a third amount column on
the line — a migration, and the tolerable kind: a new concept
([14.7](../03-database/rules/14-patterns.md#147-a-dimension-is-a-column-not-a-table)).

### An entry is immutable, and there is no draft

`journal_entry` and `journal_entry_line` carry `created_at` and `created_by` and
**no** `updated_at`, `updated_by` or `version`
([§4](../03-database/rules/04-mandatory-columns.md)). The absence of those columns is
what states the immutability.

There is no `state` column on an entry, and no draft, parked or held entry
anywhere in the schema. A document that is not ready to post is not an entry — it
is the originating document (an invoice, a payment, a payroll run) in its own
state. An entry comes into existence posted.

A correction is a **reversal**: a new entry with `reverses_entry_id` pointing at
the original and the sides exchanged. An entry is reversed exactly when another
entry references it; that is a fact about a different row, not a column on this
one ([14.8](../03-database/rules/14-patterns.md#148-a-status-not-a-second-table)).

### A period is a state machine

| State | Posting | Set by |
|---|---|---|
| `FUTURE` | refused | the calendar is generated |
| `OPEN` | allowed | the accountant opens the period |
| `CLOSING` | allowed only from the closing journal | the close begins |
| `CLOSED` | refused | the close completes |
| `LOCKED` | refused, and cannot be reopened | the year is filed |

`PostingPeriodRule` refuses any entry whose `posting_date` falls outside the
period it names, and any entry into a period that is not `OPEN` — except entries
on the `CLOSING` journal while the period is `CLOSING`.

Reopening a `CLOSED` period is an operation with its own permission, its own
audit record and a mandatory reason. `LOCKED` has no reopen operation at all.

### A subledger and its control account

A receivable or a payable exists in two places at once and the two must agree:

- in the **ledger**, as a line on a control account (`account.control_of` is
  `RECEIVABLE` or `PAYABLE`);
- in the **subledger**, as an `open_item` for a specific counterparty, with a due
  date and a settlement history.

`open_item.entry_line_id` names the line that created it, so the two are tied row
by row. `ControlAccountRule` refuses a manual entry to any account with a
`control_of` value: a control account is written only by the process that also
writes the subledger. The nightly `SubledgerReconciliation` compares the sum of
open items per counterparty against the control-account balance and alerts on a
divergence.

This is the [ledger-and-derived-balance](../03-database/rules/14-patterns.md#144-a-ledger-and-a-derived-balance)
pattern applied twice over: the lines are the truth, `account_balance` is derived
from them, and `open_item` is a second derived view of the same lines kept for a
different question.

### Account determination

Which accounts a business event posts to is **data**, not code
([14.3](../03-database/rules/14-patterns.md#143-a-declaration-and-its-slots)). `posting_rule`
declares an event — an invoice issued, a payment received, stock issued, payroll
run — narrowed by product category, contract type, branch and a validity period.
`posting_rule_line` declares the lines that event produces: a side, an account,
and which figure of the source document supplies the amount.

The consequence is the point of the whole design: **a new document kind, a new
product line or a change of accounting policy is rows entered by an accountant,
not a release.** The posting engine has one code path and does not know what a
water purifier is.

### The balance is derived

`account_balance` holds, per account, period, currency and dimension set: the
opening amount, the debit and credit turnover, and the closing amount. It is
rebuildable from `journal_entry_line` from zero, the rebuild is a tested job, and
the reconciliation between the two is scheduled and alerting.

It is **not** twelve columns of twelve months. A period is a row
([14.2](../03-database/rules/14-patterns.md#142-a-repeating-group-is-a-child-table)), so an
adjustment period, a thirteenth period or a change of fiscal calendar costs
nothing.

---

## Tables

Schema `accounting` — **34 tables in 8 groups**, with every column, its type, its
constraints and its indexes:
**[03-database/schemas/accounting.md](../03-database/schemas/accounting.md)**.

The physical model lives at one level and is not repeated here
([how to read a schema file](../03-database/README.md#how-to-read-a-schema-file)).
What belongs to this document is the model above — the aggregates and their
invariants — and everything below it: the classes that implement them, the
endpoints that expose them, the permissions that guard them and the pages that
use them.


## Reference data

Loaded by the schema migration, versioned with it:

- `reference_list` entries `BUDGET_KIND`, `BUDGET_MEASURE`, `EXPENSE_KIND`,
  `COLLECTION_RESULT` — created as system lists in D1, populated here;
- a **template chart of accounts** per statutory framework, with
  `account_name` in the supported locales;
- the standard `journal` set: sales, purchase, cash, bank, general, payroll,
  inventory, closing;
- the standard `statement_definition` layouts for the balance sheet and the
  income statement, with `statement_line` and `statement_line_account` prefilled
  against the template chart.

The chart of accounts a company actually uses is **not** seed data: it is entered
or imported per company, because it is the accountant's decision and it changes.

---

## Classes

The `accounting` module. The structure —
[backend rule 2](../04-backend/rules/02-module-structure.md).

### `api/` — the public interface

What the other twelve modules see. Narrow on purpose: **posting is the only way
in.**

| Class | Operations |
|---|---|
| `AccountingFacade` | `post(PostingRequest)`, `reverse(entryId, reason)`, `getEntry(id)`, `getOpenItems(partyId)`, `getBalance(accountId, periodId, dimensions)`, `isPeriodOpen(companyId, date)` |
| `AccountingQuery` | batch reads: `getEntries(ids)`, `getOpenItemsByContract(ids)`, `getInvoices(ids)` |
| dto | `PostingRequest`, `PostingLine`, `JournalEntryDto`, `OpenItemDto`, `AccountDto`, `BalanceDto`, `InvoiceDto`, `PaymentDto`, `FiscalPeriodDto`, `TaxCodeDto` |
| events | `EntryPosted`, `EntryReversed`, `InvoiceIssued`, `InvoiceCancelled`, `PaymentRegistered`, `PaymentApplied`, `PaymentReturned`, `OpenItemCleared`, `PeriodClosed`, `PeriodReopened`, `BudgetApproved` |

`PostingRequest` names an **event** and a **source document**, not a set of
accounts. Which accounts the entry hits is `posting_rule`'s answer, not the
caller's. That is the single most important boundary in the system: no other
domain knows an account number.

### `domain/` — business logic

| Class | Type | Responsibility |
|---|---|---|
| `Account` | entity | an account, its nature, its validity |
| `ChartOfAccounts` | value object | the tree; ancestors, descendants, postable leaves |
| `FiscalYear`, `FiscalPeriod` | entities | the calendar and the period state machine |
| `Journal` | entity | a book of prime entry |
| `JournalEntry` | entity | an entry; immutable after construction |
| `JournalEntryLine` | entity | a line |
| `PostingRule`, `PostingRuleLine` | entities | account determination |
| `OpenItem` | aggregate root | a receivable or a payable and its applications |
| `Invoice`, `InvoiceLine`, `InvoiceTax` | entities | billing |
| `Payment` | entity | money moved |
| `BankAccount`, `BankStatement`, `BankStatementLine` | entities | banking |
| `TaxCode`, `TaxRate` | entities | tax |
| `Budget`, `BudgetLine` | entities | planning |
| `StatementDefinition`, `StatementLine` | entities | reporting layouts |
| `Money` | value object | amount + currency; addition across currencies is an error |
| `BalancedEntryRule` | rule | debits equal credits, per currency |
| `PostingPeriodRule` | rule | the period is open and contains the posting date |
| `ControlAccountRule` | rule | a control account is written only by its subledger |
| `PostableAccountIsLeafRule` | rule | only leaves are posted to |
| `LineDimensionRule` | rule | `account_dimension_rule` is satisfied |
| `IssuedInvoiceIsImmutableRule` | rule | an issued invoice is corrected, not edited |
| `ApplicationWithinAmountRule` | rule | applications never exceed the item |
| `PostingRuleBalancesRule` | rule | a rule can produce a balanced entry |
| `PostingEngine` | domain service | resolves the rule, builds the entry, applies the rate |
| `SettlementService` | domain service | applies a payment to open items, oldest-first or as directed |
| `PeriodCloseService` | domain service | the close sequence: revaluation, accruals, closing entries, state change |
| `BalanceRebuildService` | domain service | rebuilds `account_balance` from lines |
| `StatementBuilder` | domain service | evaluates a `statement_definition` against balances |

### `application/` — scenarios

One handler per scenario; each is a transaction boundary.

`PostEntryHandler`, `ReverseEntryHandler`, `CreateAccountHandler`,
`UpdateAccountHandler`, `ImportChartHandler`, `GenerateFiscalYearHandler`,
`OpenPeriodHandler`, `ClosePeriodHandler`, `ReopenPeriodHandler`,
`CreatePostingRuleHandler`, `UpdatePostingRuleHandler`, `CreateInvoiceHandler`,
`UpdateInvoiceHandler`, `IssueInvoiceHandler`, `CancelInvoiceHandler`,
`RegisterPaymentHandler`, `ApplyPaymentHandler`, `ReturnPaymentHandler`,
`LoadBankStatementHandler`, `MatchStatementLineHandler`,
`CreateTaxCodeHandler`, `AddTaxRateHandler`, `CreateBudgetHandler`,
`ImportBudgetLinesHandler`, `ApproveBudgetHandler`,
`CreateStatementDefinitionHandler`, `CreateCollectionPlanHandler`,
`RecordCollectionVisitHandler`.

Read queries, without a write transaction: `TrialBalanceQuery`,
`GeneralLedgerQuery`, `OpenItemAgeingQuery`, `AccountStatementQuery`,
`BudgetVarianceQuery`, `StatementQuery`, `CashPositionQuery`.

Scheduled jobs (`platform.background_job`): `EntryBalanceReconciliation`,
`SubledgerReconciliation`, `BalanceRebuildJob`, `ExchangeRevaluationJob`,
`OverdueOpenItemJob`, `OrphanReferenceJob`.

### `adapter/web/` — controllers

`AccountController`, `FiscalPeriodController`, `JournalController`,
`JournalEntryController`, `PostingRuleController`, `OpenItemController`,
`InvoiceController`, `PaymentController`, `BankAccountController`,
`BankStatementController`, `TaxCodeController`, `BudgetController`,
`StatementController`, `CollectionController`, `AccountingReportController`.

**Fifteen controllers, one per resource.** None exceeds 200 lines; none reaches
into another domain.

### `adapter/persistence/` — storage

One repository per aggregate root: `AccountRepository`, `FiscalCalendarRepository`,
`JournalRepository`, `JournalEntryRepository`, `PostingRuleRepository`,
`OpenItemRepository`, `InvoiceRepository`, `PaymentRepository`,
`BankAccountRepository`, `BankStatementRepository`, `TaxRepository`,
`BudgetRepository`, `StatementDefinitionRepository`, `AccountBalanceRepository`,
`CollectionRepository`.

Plus `ChartCache` — the chart of accounts and the posting rules, cached with
invalidation on the domain events.

### Volume estimate

~200 classes: 15 controllers, 15 repositories, 28 handlers, 7 read queries, 6
jobs, ~30 entities and value objects, 8 rules, 5 domain services, 2 facades,
~20 DTOs, 11 events, mappers.

---

## Endpoints

`/api/v1/accounting`. The full description is in the OpenAPI specification
([ADR-0005](../../docs/02-decisions/ADR-0005-contract-first-api.md)); here — the
composition and the permissions.

### Chart of accounts

| Method | Path | Permission | Note |
|---|---|---|---|
| GET | `/accounts` | `accounting.account.read` | list; filters `companyId`, `nature`, `isPostable`, `controlOf` |
| GET | `/accounts/tree` | `accounting.account.read` | the chart as a tree |
| GET | `/accounts/{id}` | `accounting.account.read` | |
| POST | `/accounts` | `accounting.account.write` | |
| PUT | `/accounts/{id}` | `accounting.account.write` | |
| POST | `/accounts/import` | `accounting.account.import` | a chart from a file |
| GET | `/accounts/{id}/dimension-rules` | `accounting.account.read` | |
| PUT | `/accounts/{id}/dimension-rules` | `accounting.account.write` | |

### Calendar

| Method | Path | Permission | Note |
|---|---|---|---|
| GET | `/fiscal-years` | `accounting.period.read` | |
| POST | `/fiscal-years` | `accounting.period.write` | generates the periods |
| GET | `/fiscal-periods` | `accounting.period.read` | filters `fiscalYearId`, `state` |
| POST | `/fiscal-periods/{id}/open` | `accounting.period.open` | |
| POST | `/fiscal-periods/{id}/close` | `accounting.period.close` | runs the close sequence |
| POST | `/fiscal-periods/{id}/reopen` | `accounting.period.reopen` | requires a reason |

### The ledger

| Method | Path | Permission | Note |
|---|---|---|---|
| GET | `/journals` | `accounting.entry.read` | |
| GET | `/entries` | `accounting.entry.read` | filters `periodId`, `journalId`, `accountId`, `partyId`, `sourceKind`, date range |
| GET | `/entries/{id}` | `accounting.entry.read` | with its lines |
| POST | `/entries` | `accounting.entry.post` | a manual entry; refused on a control account |
| POST | `/entries/{id}/reversal` | `accounting.entry.reverse` | requires a reason |

There is no `PUT /entries/{id}` and no `DELETE`. **The absence of those two
routes is the API's statement of the domain's central rule.**

### Account determination

| Method | Path | Permission |
|---|---|---|
| GET | `/posting-rules` | `accounting.rule.read` |
| GET | `/posting-rules/{id}` | `accounting.rule.read` |
| POST | `/posting-rules` | `accounting.rule.write` |
| PUT | `/posting-rules/{id}` | `accounting.rule.write` |
| POST | `/posting-rules/{id}/simulation` | `accounting.rule.read` | shows the entry a given document would produce, without posting it |

The simulation endpoint exists so that a change of accounting policy is checked
before it is applied, by the accountant, on a real document.

### Subledger

| Method | Path | Permission |
|---|---|---|
| GET | `/open-items` | `accounting.open_item.read` |
| GET | `/open-items/{id}` | `accounting.open_item.read` |
| GET | `/open-items/ageing` | `accounting.open_item.read` |
| POST | `/open-items/{id}/applications` | `accounting.open_item.apply` |
| POST | `/open-items/{id}/write-off` | `accounting.open_item.write_off` |

### Billing

| Method | Path | Permission |
|---|---|---|
| GET | `/invoices` | `accounting.invoice.read` |
| GET | `/invoices/{id}` | `accounting.invoice.read` |
| POST | `/invoices` | `accounting.invoice.write` |
| PUT | `/invoices/{id}` | `accounting.invoice.write` |
| POST | `/invoices/{id}/issue` | `accounting.invoice.issue` |
| POST | `/invoices/{id}/cancellation` | `accounting.invoice.cancel` |
| POST | `/invoices/{id}/credit-note` | `accounting.invoice.issue` |

### Payments and banking

| Method | Path | Permission |
|---|---|---|
| GET | `/payments` | `accounting.payment.read` |
| GET | `/payments/{id}` | `accounting.payment.read` |
| POST | `/payments` | `accounting.payment.write` |
| POST | `/payments/{id}/application` | `accounting.payment.apply` |
| POST | `/payments/{id}/return` | `accounting.payment.return` |
| GET | `/bank-accounts` | `accounting.bank.read` |
| POST / PUT | `/bank-accounts` | `accounting.bank.write` |
| GET | `/bank-statements` | `accounting.bank.read` |
| POST | `/bank-statements/import` | `accounting.bank.import` |
| POST | `/bank-statements/{id}/lines/{lineId}/match` | `accounting.bank.reconcile` |
| GET | `/deposits` | `accounting.deposit.read` |
| POST / PUT | `/deposits` | `accounting.deposit.write` |

### Tax, budgets, statements, collection

| Method | Path | Permission |
|---|---|---|
| GET | `/tax-codes` | `accounting.tax.read` |
| POST / PUT | `/tax-codes` | `accounting.tax.write` |
| POST | `/tax-codes/{id}/rates` | `accounting.tax.write` |
| GET | `/budgets` | `accounting.budget.read` |
| POST / PUT | `/budgets` | `accounting.budget.write` |
| POST | `/budgets/{id}/lines/import` | `accounting.budget.write` |
| POST | `/budgets/{id}/approval` | `accounting.budget.approve` |
| GET | `/budgets/{id}/variance` | `accounting.budget.read` |
| GET | `/statement-definitions` | `accounting.statement.read` |
| POST / PUT | `/statement-definitions` | `accounting.statement.write` |
| GET | `/collection-plans` | `accounting.collection.read` |
| POST / PUT | `/collection-plans` | `accounting.collection.write` |
| POST | `/collection-plans/{id}/visits` | `accounting.collection.visit` |

### Reports

| Method | Path | Permission | Note |
|---|---|---|---|
| GET | `/reports/trial-balance` | `accounting.report.read` | by period, dimensions optional |
| GET | `/reports/general-ledger` | `accounting.report.read` | by account and period |
| GET | `/reports/account-statement` | `accounting.report.read` | by counterparty |
| GET | `/reports/statement/{definitionCode}` | `accounting.report.statement` | the balance sheet or the income statement |
| GET | `/reports/cash-position` | `accounting.report.read` | |
| GET | `/documents/{kind}/{id}/chain` | `accounting.entry.read` | every document that produced or was produced by this one |

The reports are served from the replica and are produced through the platform's
reporting mechanism
([ADR-0009](../../docs/02-decisions/ADR-0009-reporting-and-exports.md)); the
domain supplies the queries, not the rendering.

**73 endpoints over 15 resources in total.**

### The domain's error codes

`accounting.entry.unbalanced`, `accounting.entry.period_closed`,
`accounting.entry.period_not_found`, `accounting.entry.account_not_postable`,
`accounting.entry.control_account_direct_post`,
`accounting.entry.dimension_required`, `accounting.entry.already_reversed`,
`accounting.rule.not_found_for_event`, `accounting.rule.ambiguous`,
`accounting.rule.cannot_balance`, `accounting.open_item.over_applied`,
`accounting.open_item.already_cleared`, `accounting.invoice.already_issued`,
`accounting.invoice.not_issued`, `accounting.invoice.totals_mismatch`,
`accounting.payment.over_applied`, `accounting.payment.currency_mismatch`,
`accounting.bank.statement_already_loaded`, `accounting.tax.rate_not_found`,
`accounting.budget.already_approved`, `accounting.period.reopen_forbidden`.

---

## Permissions

| Permission | What it allows |
|---|---|
| `accounting.account.read` / `.write` / `.import` | the chart of accounts |
| `accounting.period.read` / `.write` / `.open` / `.close` / `.reopen` | the calendar |
| `accounting.entry.read` / `.post` / `.reverse` | the ledger |
| `accounting.rule.read` / `.write` | account determination |
| `accounting.open_item.read` / `.apply` / `.write_off` | the subledgers |
| `accounting.invoice.read` / `.write` / `.issue` / `.cancel` | billing |
| `accounting.payment.read` / `.write` / `.apply` / `.return` | payments |
| `accounting.bank.read` / `.write` / `.import` / `.reconcile` | banking |
| `accounting.deposit.read` / `.write` | deposits |
| `accounting.tax.read` / `.write` | tax |
| `accounting.budget.read` / `.write` / `.approve` | budgets |
| `accounting.statement.read` / `.write` | statement layouts |
| `accounting.collection.read` / `.write` / `.visit` | debt collection |
| `accounting.report.read` / `.statement` | reports |

Four permissions are deliberately separate from the `.write` they sit next to,
because they are the operations that change what the company has told the outside
world: `.post`, `.reverse`, `.issue`, `.close`. A user who may prepare a document
is not thereby a user who may commit it.

`.reopen` is separate again, and is expected to be held by one or two people in
the company.

**The data-scope restriction:** a user sees the companies, branches and
counterparties within their scope
([ADR-0006](../../docs/02-decisions/ADR-0006-auth-model.md)). It is applied in
`adapter/persistence`, not in the controller. Reports obey the same scope, and a
report that spans companies requires a permission that grants that scope
explicitly.

---

## Pages

`pages/accounting`. The types —
[frontend rule 2](../06-frontend/rules/02-page-types.md).

| Code | Route | Type | Permission | Purpose |
|---|---|---|---|---|
| `ACC-CHT-L` | `/accounting/accounts` | L | `accounting.account.read` | the chart as a tree with a side panel |
| `ACC-CHT-F` | `/accounting/accounts/:id` | F | `accounting.account.write` | the account form, including its dimension rules |
| `ACC-PER-L` | `/accounting/periods` | L | `accounting.period.read` | the calendar with the state of each period |
| `ACC-PER-C` | `/accounting/periods/:id/close` | F | `accounting.period.close` | the close checklist, step by step |
| `ACC-ENT-L` | `/accounting/entries` | L | `accounting.entry.read` | the entry journal with filters |
| `ACC-ENT-V` | `/accounting/entries/:id` | V | `accounting.entry.read` | one entry, read-only, with its reversal chain |
| `ACC-ENT-F` | `/accounting/entries/new` | F | `accounting.entry.post` | a manual entry |
| `ACC-RUL-L` | `/accounting/posting-rules` | L | `accounting.rule.read` | account determination |
| `ACC-RUL-F` | `/accounting/posting-rules/:id` | F | `accounting.rule.write` | the rule form with a live simulation |
| `ACC-OPI-L` | `/accounting/open-items` | L | `accounting.open_item.read` | open items with ageing buckets |
| `ACC-INV-L` | `/accounting/invoices` | L | `accounting.invoice.read` | invoices |
| `ACC-INV-F` | `/accounting/invoices/:id` | F | `accounting.invoice.write` | the invoice form |
| `ACC-PAY-L` | `/accounting/payments` | L | `accounting.payment.read` | payments |
| `ACC-PAY-F` | `/accounting/payments/:id` | F | `accounting.payment.write` | the payment form with an application panel |
| `ACC-BNK-L` | `/accounting/bank-accounts` | L | `accounting.bank.read` | bank accounts, cash desks and wallets |
| `ACC-STM-R` | `/accounting/bank-statements/:id` | F | `accounting.bank.reconcile` | reconciliation: statement lines against payments |
| `ACC-TAX-L` | `/accounting/tax-codes` | L | `accounting.tax.read` | taxes and their rate history |
| `ACC-BUD-L` | `/accounting/budgets` | L | `accounting.budget.read` | budgets |
| `ACC-BUD-F` | `/accounting/budgets/:id` | F | `accounting.budget.write` | the budget grid: periods across, dimensions down |
| `ACC-SDF-L` | `/accounting/statement-definitions` | L | `accounting.statement.read` | statement layouts |
| `ACC-SDF-F` | `/accounting/statement-definitions/:id` | F | `accounting.statement.write` | the layout tree with account assignment |
| `ACC-COL-L` | `/accounting/collection` | L | `accounting.collection.read` | collection plans and their progress |
| `ACC-REP-L` | `/accounting/reports` | L | `accounting.report.read` | the domain's reports, parameterized |

**23 pages.** The budget grid `ACC-BUD-F` is one screen for every budget kind:
the kinds are rows of `BUDGET_KIND` and the dimensions are columns of
`budget_line`, so a thirteenth budget kind adds no screen
([14.7](../03-database/rules/14-patterns.md#147-a-dimension-is-a-column-not-a-table)).

### The domain's components

| Component | Where it is used | Behaviour |
|---|---|---|
| `AccountLookup` | every accounting form, and D6, D7 | the chart as a searchable tree, postable leaves only |
| `EntryPreview` | the rule form, the invoice form, the payment form | shows the entry a document will produce before it is posted |
| `AgeingBuckets` | open items, collection, CRM | the standard ageing bands, one definition |
| `PeriodPicker` | every report and every list | a period or a range, aware of which periods are open |

`EntryPreview` earns its place: the accountant sees the posting before it
happens, on every document, which is what makes a data-driven posting engine
trustworthy to the people who have to sign the result.

### Page states

Every page defines: loading (`Skeleton`), empty (`EmptyState` with a hint), error
(`ErrorState` with the code and the `traceId`), no permission
(`PermissionGate`). A closed period renders forms read-only rather than failing
on save.

---

## Audit

The domain owner's decision on what is audited
([§11](../03-database/rules/11-audit.md)):

| Table | Audited | Why |
|---|---|---|
| `journal_entry`, `journal_entry_line` | **inserts only** | the rows are immutable; the insert is the whole history |
| `account` | all changes, `nature`, `normal_side`, `control_of`, `is_postable` especially | changing them changes every statement built afterwards |
| `account_dimension_rule` | all changes | it decides what a posting may omit |
| `fiscal_period` | every state change, with who and when | the reopening of a closed period is the single most sensitive operation in the domain |
| `posting_rule`, `posting_rule_line` | all changes | this is accounting policy; a change of policy must be attributable |
| `invoice` | issue, cancellation, and every change while `DRAFT` | an issued invoice is an external commitment |
| `payment` | all changes | |
| `open_item_application` | inserts only | immutable |
| `document_link` | inserts only | immutable; it is the trail an auditor follows |
| `budget` | approval and revision | |
| `statement_definition`, `statement_line`, `statement_line_account` | all changes | they define what the reported figure means |
| `tax_rate` | inserts only | |
| `account_balance` | **not audited** | derived and rebuildable; auditing it audits arithmetic |
| `bank_statement_line` | **not audited** except the match | the content came from the bank |
| `account_name`, `tax_code_name`, `statement_line_name` | **not audited** | a translation does not change meaning |

Retention for the audit of this domain is set by the statutory record-keeping
period rather than by the platform default, and the law is cited in the migration
that sets it ([§10](../03-database/rules/10-large-tables.md)).

---

## Open questions

| # | Question | Affects |
|---|---|---|
| D5-Q1 | Which statutory framework does the chart of accounts follow, and is one chart shared by all companies or one per company? | the seed chart, `ux_account__company_id__code` |
| D5-Q2 | Is a group currency needed — that is, is consolidation across companies with different functional currencies in scope? | a third amount column on `journal_entry_line` |
| D5-Q3 | How many periods does a fiscal year have, and how many adjustment periods? | `fiscal_period.ordinal` range, the close sequence |
| D5-Q4 | Is exchange revaluation of open items required at each period close, or only at year end? | `ExchangeRevaluationJob`, `open_item_application.kind = EXCHANGE_DIFFERENCE` |
| D5-Q5 | Which of the five dimensions is mandatory on which account? | `account_dimension_rule` seed, and every report that groups by them |
| D5-Q6 | Does debt collection belong to this domain or to D9 CRM as field work? | `collection_plan`, `collection_visit` — 2 tables, and a boundary in [02-domains.md](../02-domains.md) |
| D5-Q7 | Which document numbering must be gapless by law, and per company or per branch? | `platform.document_number` series definitions |
| D5-Q8 | Are purchase invoices in scope, or only sales? | `invoice.kind`, the payable subledger, `posting_rule` events |
| D5-Q9 | What is the rounding rule the whole system uses, and does it differ per currency? | [§5.2](../03-database/rules/05-types.md#52-money) — this is the question that document leaves open |
| D5-Q10 | Who may reopen a closed period, and does the answer differ for the last period of a year? | `accounting.period.reopen`, the audit decision above |

The questions are closed by the domain owner **before** the first migration of
this schema, not after: every one of them changes a column, a constraint or a
seed, and the ledger is the one schema in the system where a late change is paid
for in reprinted statements.
