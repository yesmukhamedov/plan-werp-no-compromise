---
id: ADR-0009
title: Reports and exports
status: Proposed
date: 2026-09-03
deadline: gate G2
---

# ADR-0009. Reports and exports

## Context

Reporting is an underestimated part of the volume. In the current system:

- on the backend — Apache POI in three different versions in different modules,
  PDF generation through OpenHTMLToPDF + Thymeleaf, a separate set of fonts in
  the resources;
- on the frontend — **three** Excel export libraries (`xlsx`,
  `react-export-excel`, `react-data-export`), meaning some reports are produced
  in the browser from data already loaded;
- the reporting controllers are among the largest classes in the system:
  `FinanceReportRestController` — 5,366 lines, `ReportController` — 1,900+ lines,
  plus reporting methods inside domain services;
- 708 GET endpoints, a significant share of which are reports and extracts.

Producing a report in the browser means the entire data set is first transferred
to the client. For ERP reports that is both a performance problem and a security
problem (the client receives more than it displays).

## Decision (proposed)

1. **A report is produced on the server.** Never in the browser. Export to Excel
   and PDF is done by a single server-side subsystem; there are no export
   libraries on the frontend.
2. **One library per format:** one for spreadsheets, one for PDF — and one way of
   describing a template.
3. **A report is not a domain endpoint but a subsystem.** The domain supplies the
   data; the reporting subsystem is responsible for the shape, the template, the
   localization and the delivery. That breaks the chain "the report grows → the
   domain service swells" which produced the 5,000-line classes.
4. **Heavy reports are asynchronous.** A report taking longer than the set
   threshold is queued, executed by a background worker and delivered as a link.
   A synchronous report with unbounded execution time is the main cause of an
   unresponsive ERP under load.
5. **Reporting queries are isolated from operational ones.** Heavy reads go to a
   replica so that a report does not affect the operators' work. The replica
   topology — [OQ-006](../../transition/12-open-questions.md).
6. **A report template is data, not code.** Changing a report's shape must not
   require an application release wherever that is possible.
7. **The server computes the numbers in a report.** The same result as in the
   interface, with the same arithmetic and the same rounding
   ([C-09](../00-context/03-constraints.md#c-09-financial-calculations-require-exact-arithmetic)).

## Separately: reconciling reports at the cutover

Reports are the part of the system most visible to the user and the most
sensitive to divergences. During parity verification
([transition/06-parity-verification.md](../../transition/06-parity-verification.md))
the financial and accounting reports are reconciled **row by row and to the
cent, with zero tolerance**. That is a separate, pre-budgeted amount of work, not
"we will check when we get there".

## Consequences

- A reporting subsystem appears as part of the platform (Phase 1), before domain
  development — otherwise every domain will invent its own.
- An inventory of the reports is required: how many there are, who uses them,
  which are alive. Over 12 years some reports are almost certainly dead — those
  need not be carried over.
  → [EPIC-007](../../backlog/EPIC-007-reports-inventory.md)
- Asynchronous reports require a job queue and a mechanism for notifying the
  user — that is part of the platform, not of an individual domain.
- Storing the produced files, their lifetime and the access permissions to them
  are requirements on the file-storage subsystem.
