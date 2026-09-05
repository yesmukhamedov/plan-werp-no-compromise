---
id: PROD-SPEC-D3
title: D3 Personnel — full specification
status: designed
domain: D3
owner: not assigned
---

# D3. Personnel

DB schema: `hr` · Module: `hr` · API: `/api/v1/hr` ·
Interface section: `pages/hr`

Written to the depth set by [D1](D1-reference.md)
([spec/README.md](README.md#d1--the-reference-sample)). The structural forms it
uses are the ones named in
[rule 14](../03-database/rules/14-patterns.md); each table below
says which.

---

## Purpose and boundaries

The employment relationship and everything that hangs on it: the organizational
structure, the establishment, jobs, employees, employments and assignments,
compensation, absence, time recording, training, qualifications and departure.

**The domain's key property, and the one that shapes every table below:**

> A person is not an employee. An employee is a **relationship** between a person
> and a company, and that relationship has a beginning, an end and a history.

The person — the name, the date of birth, the identity document, the address, the
telephone number — is `party.person` and lives in D2. This schema stores no name,
no passport, no address and no phone number in any column. That is not an
optimization; it is what makes it possible to correct a surname once, to employ
the same person twice, and to answer "who worked in this unit on that date"
without reconstruction.

**In scope:** organizational units, jobs, positions, employees, employments,
assignments, personnel actions, compensation, absence and entitlement, time
sheets, education, experience, certification, training, dependants, employee
expenses, exit interviews.

**Out of scope:**

| What | Where | Why not here |
|---|---|---|
| Names, dates of birth, identity documents, addresses, phone numbers | D2 Counterparties | a person exists once, whatever roles they hold ([14.6](../03-database/rules/14-patterns.md#146-one-identity-many-roles)) |
| Payroll calculation, taxes, deductions, contributions | D6 Compensation | this domain says what was **agreed**; D6 computes what is **paid** |
| Posting a payroll cost to the ledger | D5 Accounting | one place where money becomes final |
| Sign-in, roles, permissions | D0 Platform | an employee is not a user; some employees never sign in and some users are not employees |
| Approval routes for personnel orders | D10 Document workflow | one workflow engine for the whole system |
| Recruitment, vacancies, candidates | not in the system | [D3-Q8](#open-questions) |

The boundary with D6 is the sharpest one in the system and is worth stating
twice: **`hr.compensation` is what was agreed with the employee; `payroll.*` is
what was calculated from it.** D6 reads this domain and never writes to it.

## Model

Eight aggregates.

| Aggregate | Root | Composition | Invariants |
|---|---|---|---|
| Organizational structure | `org_unit` | `org_unit_name` | a unit has one parent at a time; the tree has no cycles; a unit's period lies inside its parent's |
| Job catalogue | `job` | `job_name` | the job code is unique within a company |
| Establishment | `position` | — | a position names one org unit and one job for a period; the assigned full-time equivalent never exceeds the budgeted one |
| Employee | `employee` | `education`, `work_experience`, `certification`, `dependant` | one employee is exactly one `party.person`; the personnel number is unique within a company |
| Employment | `employment` | `assignment`, `compensation`, `employment_event` | assignments of one employment never overlap; every change of assignment or compensation has an event; an employment's end date is never earlier than its start |
| Absence | `absence` | — | absences of one employee never overlap; an absence lies inside an employment |
| Time sheet | `time_sheet` | `time_sheet_entry` | one sheet per employee per period; an entry's date lies inside the period; the hours of one day never exceed 24 |
| Training | `course` | `course_session`, `course_enrolment` | an enrolment belongs to exactly one session; a session belongs to exactly one course |

### Three levels, not one

The single most common way to get personnel data wrong is to put the job title,
the unit and the branch on the employee as columns. This domain separates them
into three things that change at different rates and for different reasons:

| Level | What it is | Changes when |
|---|---|---|
| `job` | a **job** as the company defines it — "service technician", with its grade and its family | the company redefines the role |
| `position` | a **seat** in the establishment — one budgeted service technician in the Almaty service unit | the establishment is planned or revised |
| `assignment` | a **placement** — this employment occupies that seat from this date to that one | a person is hired, transferred, promoted or leaves |

A vacant position is a `position` with no current `assignment` — a fact, not a
report someone assembles. Headcount planned, headcount filled and headcount
vacant are three counts over two tables.

### Everything is a period

Pattern [14.5](../03-database/rules/14-patterns.md#145-a-period-not-a-flag), applied without
exception:

```
org_unit      valid_from, valid_to      the structure as it was
position      valid_from, valid_to      the establishment as it was
assignment    valid_from, valid_to      who sat where
compensation  valid_from, valid_to      what was agreed
absence       valid_from, valid_to      who was away
certification valid_from, valid_to      who was qualified
```

There is **no `is_dismissed` column** anywhere in this schema, and no
`current_position_id`. Whether a person is employed today is
`EXISTS (assignment WHERE valid_from <= today AND (valid_to IS NULL OR valid_to > today))`,
and the same query with a different date answers the same question about any day
in the company's history.

Every one of those tables carries an exclusion constraint preventing overlap on
its natural key. The database refuses two simultaneous assignments to one
employment; it does not rely on the application remembering to check.

### One person may be employed more than once

`employment` is a separate table from `employee` because the relationship can
occur several times and several at once: a rehire after two years, a second
part-time employment in a different company of the group, a transfer between
legal entities that is legally a termination and a hiring.

`employee` therefore holds no dates of hire or dismissal. The first hire is the
earliest `employment.valid_from`; the last departure is the latest `valid_to`
with no open employment after it.

### A personnel action is an event

Pattern [14.4](../03-database/rules/14-patterns.md#144-a-ledger-and-a-derived-balance).
`employment_event` is the ledger of what happened to the relationship: hired,
transferred, promoted, rate changed, suspended, resumed, terminated. The periods
in `assignment` and `compensation` are the *state* those events produce.

An event carries the document that authorized it — a `docflow.document`, approved
through the one workflow engine the system has. A change of assignment without an
event, or an event without an approved document, is a defect that the nightly
`PersonnelActionReconciliation` reports.

### A time code is a row

`time_sheet_entry` has one row per employee, per day, **per time code** — worked,
overtime, night, holiday, sickness, unpaid leave, training — with the hours.

It does not have `hours_worked`, `hours_overtime`, `hours_night` as columns
([14.2](../03-database/rules/14-patterns.md#142-a-repeating-group-is-a-child-table)). The codes are
`reference_item` rows in the list `TIME_CODE`, so a new one — a new shift
premium, a new statutory category — is entered by an HR administrator and appears
in the time sheet, the payroll input and the reports at once, with no release
([14.3](../03-database/rules/14-patterns.md#143-a-declaration-and-its-slots)).

### Compensation is agreed here and calculated elsewhere

`compensation` is a period-dated row per employment and per kind: a base salary,
an allowance, a piece rate, a fixed bonus entitlement. It says what was agreed,
in what currency, at what frequency, from when.

It is **read** by D6 and never written by it. A recalculation produces a new
`payroll.payroll_run`; it does not touch an agreement. An agreement that changes
retroactively is a new `compensation` row with an earlier `valid_from` and an
`employment_event` explaining it — never an edit, because an edit would silently
change every payroll already run against it.

---

## Tables

Schema `hr` — **23 tables in 6 groups**, with every column, its type, its
constraints and its indexes:
**[03-database/schemas/hr.md](../03-database/schemas/hr.md)**.

The physical model lives at one level and is not repeated here
([how to read a schema file](../03-database/README.md#how-to-read-a-schema-file)).
What belongs to this document is the model above — the aggregates and their
invariants — and everything below it: the classes that implement them, the
endpoints that expose them, the permissions that guard them and the pages that
use them.


## Reference data

Loaded by the schema migration, versioned with it — as `reference_list` entries
created in D1 and populated here:

`EMPLOYMENT_CONTRACT_KIND`, `TERMINATION_REASON`, `PERSONNEL_ACTION_REASON`,
`ABSENCE_KIND`, `TIME_CODE`, `ALLOWANCE_KIND`, `JOB_FAMILY`, `EDUCATION_LEVEL`,
`CERTIFICATION_KIND`, `COURSE_KIND`, `FAMILY_RELATION`, `EXPENSE_KIND`,
`DEPARTURE_REASON`.

Thirteen lists, thirteen sets of rows, **no tables**. Each is edited on the one
enumerations screen D1 provides
([D1](D1-reference.md#the-shared-enumeration-mechanism)).

The organizational structure, the job catalogue and the establishment are **not**
seed data: they are the company's own and are entered or imported.

---

## Classes

The `hr` module. The structure —
[backend rule 2](../04-backend/rules/02-module-structure.md).

### `api/` — the public interface

| Class | Operations |
|---|---|
| `HrFacade` | `getEmployee(id)`, `getEmploymentAt(employeeId, date)`, `getAssignmentAt(employmentId, date)`, `getCompensationAt(employmentId, date)`, `getOrgUnit(id)`, `getOrgUnitSubtree(id)`, `getPositionOccupancy(positionId, date)`, `isAbsent(employeeId, date)` |
| `HrQuery` | batch reads: `getEmployees(ids)`, `getAssignmentsAt(employmentIds, date)`, `getOrgUnits(ids)` |
| dto | `EmployeeDto`, `EmploymentDto`, `AssignmentDto`, `CompensationDto`, `OrgUnitDto`, `OrgUnitTreeDto`, `PositionDto`, `JobDto`, `AbsenceDto`, `TimeSheetDto`, `CertificationDto` |
| events | `EmployeeCreated`, `EmploymentStarted`, `EmploymentEnded`, `AssignmentChanged`, `CompensationChanged`, `AbsenceApproved`, `AbsenceCancelled`, `TimeSheetApproved`, `TimeSheetLocked`, `CertificationExpired`, `OrgUnitChanged` |

**Every read on this facade takes a date.** `getEmploymentAt`, not
`getEmployment`. An interface that cannot express "as at" quietly forces every
caller to assume "as at now", and reports built on that assumption are wrong for
every past period.

### `domain/` — business logic

| Class | Type | Responsibility |
|---|---|---|
| `OrgUnit` | entity | a unit, its period, its place in the tree |
| `OrgStructure` | value object | the tree as at a date: subtree, ancestors, path |
| `Job` | entity | a job in the catalogue |
| `Position` | entity | a seat, its budget, its reporting line |
| `Employee` | entity | the record of a person employed |
| `Employment` | aggregate root | the relationship, its assignments, compensation and events |
| `Assignment` | entity | a placement for a period |
| `Compensation` | entity | an agreement for a period |
| `EmploymentEvent` | entity | a personnel action; immutable |
| `Absence` | aggregate root | an absence and its state |
| `TimeSheet`, `TimeSheetEntry` | entities | time recording |
| `Certification` | entity | a qualification with a validity |
| `Course`, `CourseSession`, `CourseEnrolment` | entities | training |
| `DateRange` | value object | a half-open period; overlap, containment, duration |
| `Fte` | value object | a share of a full rate; sums, compares, never exceeds its bound |
| `OrgUnitTreeRule` | rule | no cycles |
| `OrgUnitPeriodWithinParentRule` | rule | a unit does not outlive its parent |
| `PositionOccupancyRule` | rule | assigned full-time equivalent never exceeds budgeted |
| `ReportingLineHasNoCycleRule` | rule | |
| `AssignmentWithinEmploymentRule` | rule | |
| `AssignmentPositionIsValidRule` | rule | |
| `CertifiedForJobRule` | rule | a job requiring certification is occupied only by someone holding one |
| `AbsenceWithinEmploymentRule` | rule | |
| `EntryWithinSheetPeriodRule` | rule | |
| `DailyHoursRule` | rule | 24 hours a day, across every code |
| `CertificationFromCourseRule` | rule | passing a session issues the certification the course declares |
| `EmploymentService` | domain service | hire, transfer, promote, suspend, terminate — each closes and opens the right periods and writes the event |
| `WorkingCalendarService` | domain service | working days between two dates, per the production calendar |
| `EntitlementService` | domain service | rebuilds `absence_entitlement` |
| `OrgStructureService` | domain service | moving a unit, recomputing `path` |

`EmploymentService` is where the domain's real complexity lives, and it is
deliberately one service rather than seven handlers doing period arithmetic each
in its own way: closing an assignment, opening the next one and writing the event
is one operation, and doing two of the three is the defect this design exists to
prevent.

### `application/` — scenarios

`CreateOrgUnitHandler`, `UpdateOrgUnitHandler`, `MoveOrgUnitHandler`,
`CloseOrgUnitHandler`, `CreateJobHandler`, `UpdateJobHandler`,
`CreatePositionHandler`, `UpdatePositionHandler`, `ClosePositionHandler`,
`CreateEmployeeHandler`, `UpdateEmployeeHandler`, `HireHandler`,
`TransferHandler`, `PromoteHandler`, `ChangeCompensationHandler`,
`SuspendHandler`, `ResumeHandler`, `TerminateHandler`, `RehireHandler`,
`RequestAbsenceHandler`, `ApproveAbsenceHandler`, `CancelAbsenceHandler`,
`CreateTimeSheetHandler`, `FillTimeSheetHandler`, `SubmitTimeSheetHandler`,
`ApproveTimeSheetHandler`, `AddEducationHandler`, `AddCertificationHandler`,
`CreateCourseHandler`, `ScheduleSessionHandler`, `EnrolHandler`,
`RecordEnrolmentOutcomeHandler`, `SubmitExpenseHandler`, `ApproveExpenseHandler`,
`RecordExitInterviewHandler`.

Read queries: `OrgChartQuery`, `HeadcountQuery`, `VacancyQuery`,
`EmploymentHistoryQuery`, `AbsenceCalendarQuery`, `TimeSheetSummaryQuery`,
`CertificationExpiryQuery`, `TurnoverQuery`.

Scheduled jobs: `EntitlementRebuildJob`, `CertificationExpiryJob`,
`ProbationEndingJob`, `ContractExpiringJob`, `PersonnelActionReconciliation`,
`OrphanReferenceJob`.

### `adapter/web/` — controllers

`OrgUnitController`, `JobController`, `PositionController`, `EmployeeController`,
`EmploymentController`, `AbsenceController`, `TimeSheetController`,
`TrainingController`, `CertificationController`, `EmployeeExpenseController`,
`HrReportController`.

**Eleven controllers, one per resource.** None exceeds 200 lines; none reaches
into another domain.

### `adapter/persistence/` — storage

`OrgUnitRepository`, `JobRepository`, `PositionRepository`, `EmployeeRepository`,
`EmploymentRepository`, `AbsenceRepository`, `EntitlementRepository`,
`TimeSheetRepository`, `CertificationRepository`, `CourseRepository`,
`EmployeeExpenseRepository`.

Plus `OrgStructureCache` — the unit tree as at today, invalidated on
`OrgUnitChanged`. Historical dates are not cached: they are asked for rarely and
must never be stale.

### Volume estimate

~160 classes: 11 controllers, 11 repositories, 35 handlers, 8 read queries, 6
jobs, ~25 entities and value objects, 11 rules, 4 domain services, 2 facades,
~15 DTOs, 11 events, mappers.

---

## Endpoints

`/api/v1/hr`. The full description is in the OpenAPI specification; here — the
composition and the permissions.

### Organizational structure and establishment

| Method | Path | Permission | Note |
|---|---|---|---|
| GET | `/org-units` | `hr.org.read` | filters `companyId`, `kind`, `asOf` |
| GET | `/org-units/tree` | `hr.org.read` | the tree; parameters `rootId`, `asOf` |
| GET | `/org-units/{id}` | `hr.org.read` | |
| POST | `/org-units` | `hr.org.write` | |
| PUT | `/org-units/{id}` | `hr.org.write` | |
| POST | `/org-units/{id}/move` | `hr.org.write` | with an effective date |
| POST | `/org-units/{id}/closure` | `hr.org.write` | closes the period |
| GET | `/jobs` | `hr.job.read` | |
| POST / PUT | `/jobs` | `hr.job.write` | |
| GET | `/positions` | `hr.position.read` | filters `orgUnitId`, `jobId`, `isVacant`, `asOf` |
| GET | `/positions/{id}` | `hr.position.read` | |
| POST / PUT | `/positions` | `hr.position.write` | |
| GET | `/positions/{id}/occupancy` | `hr.position.read` | who has held it, and when |

`asOf` is a parameter on **every** list that reads a period-dated table. Its
default is today; its presence is what makes the history reachable from the API
rather than only from the database.

### Employees and employments

| Method | Path | Permission | Note |
|---|---|---|---|
| GET | `/employees` | `hr.employee.read` | filters `orgUnitId`, `branchId`, `isEmployed`, `asOf` |
| GET | `/employees/{id}` | `hr.employee.read` | |
| POST | `/employees` | `hr.employee.write` | requires an existing `party.person` |
| PUT | `/employees/{id}` | `hr.employee.write` | |
| GET | `/employees/{id}/employments` | `hr.employment.read` | |
| GET | `/employees/{id}/history` | `hr.employment.read` | the full event ledger |
| POST | `/employments` | `hr.employment.hire` | hiring |
| GET | `/employments/{id}` | `hr.employment.read` | |
| POST | `/employments/{id}/transfer` | `hr.employment.transfer` | |
| POST | `/employments/{id}/promotion` | `hr.employment.transfer` | |
| POST | `/employments/{id}/suspension` | `hr.employment.suspend` | |
| POST | `/employments/{id}/resumption` | `hr.employment.suspend` | |
| POST | `/employments/{id}/termination` | `hr.employment.terminate` | |
| GET | `/employments/{id}/compensation` | `hr.compensation.read` | the full history |
| POST | `/employments/{id}/compensation` | `hr.compensation.write` | a new period |

There is no `DELETE` on an employment and no `PUT` on a compensation row.
Personnel history is not editable through the API, and the absence of those two
routes is where that is stated.

### Absence and time

| Method | Path | Permission |
|---|---|---|
| GET | `/absences` | `hr.absence.read` |
| POST | `/absences` | `hr.absence.request` |
| POST | `/absences/{id}/approval` | `hr.absence.approve` |
| POST | `/absences/{id}/cancellation` | `hr.absence.approve` |
| GET | `/absences/calendar` | `hr.absence.read` |
| GET | `/entitlements` | `hr.absence.read` |
| GET | `/time-sheets` | `hr.time_sheet.read` |
| GET | `/time-sheets/{id}` | `hr.time_sheet.read` |
| POST | `/time-sheets` | `hr.time_sheet.write` |
| PUT | `/time-sheets/{id}/entries` | `hr.time_sheet.write` |
| POST | `/time-sheets/{id}/submission` | `hr.time_sheet.write` |
| POST | `/time-sheets/{id}/approval` | `hr.time_sheet.approve` |

### Training, qualifications, expenses

| Method | Path | Permission |
|---|---|---|
| GET | `/courses` | `hr.training.read` |
| POST / PUT | `/courses` | `hr.training.write` |
| GET | `/course-sessions` | `hr.training.read` |
| POST / PUT | `/course-sessions` | `hr.training.write` |
| POST | `/course-sessions/{id}/enrolments` | `hr.training.write` |
| PUT | `/enrolments/{id}/outcome` | `hr.training.write` |
| GET | `/certifications` | `hr.certification.read` |
| POST | `/certifications` | `hr.certification.write` |
| GET | `/certifications/expiring` | `hr.certification.read` |
| GET | `/employees/{id}/education` | `hr.employee.read` |
| POST | `/employees/{id}/education` | `hr.employee.write` |
| GET | `/expenses` | `hr.expense.read` |
| POST | `/expenses` | `hr.expense.submit` |
| POST | `/expenses/{id}/approval` | `hr.expense.approve` |

### Reports

| Method | Path | Permission | Note |
|---|---|---|---|
| GET | `/reports/headcount` | `hr.report.read` | planned, filled, vacant, as at a date |
| GET | `/reports/turnover` | `hr.report.read` | by unit and period |
| GET | `/reports/org-chart` | `hr.org.read` | as at a date |
| GET | `/reports/absence-summary` | `hr.report.read` | |
| GET | `/reports/payroll-input` | `hr.report.payroll_input` | what D6 consumes, in a readable form |

**63 endpoints over 11 resources in total.**

### The domain's error codes

`hr.org_unit.cycle_detected`, `hr.org_unit.outlives_parent`,
`hr.position.over_budgeted`, `hr.position.not_valid_at_date`,
`hr.employee.party_already_employed`, `hr.employee.personnel_number_taken`,
`hr.employment.overlaps_existing`, `hr.employment.already_terminated`,
`hr.employment.termination_reason_required`,
`hr.assignment.overlaps_existing`, `hr.assignment.outside_employment`,
`hr.assignment.certification_missing`, `hr.compensation.overlaps_existing`,
`hr.compensation.retroactive_needs_reason`, `hr.absence.overlaps_existing`,
`hr.absence.entitlement_exceeded`, `hr.absence.outside_employment`,
`hr.time_sheet.period_locked`, `hr.time_sheet.daily_hours_exceeded`,
`hr.time_sheet.already_exists_for_period`, `hr.enrolment.session_full`.

---

## Permissions

| Permission | What it allows |
|---|---|
| `hr.org.read` / `.write` | the organizational structure |
| `hr.job.read` / `.write` | the job catalogue |
| `hr.position.read` / `.write` | the establishment |
| `hr.employee.read` / `.write` | employee records |
| `hr.employment.read` / `.hire` / `.transfer` / `.suspend` / `.terminate` | employments |
| `hr.compensation.read` / `.write` | **what people are paid** |
| `hr.absence.read` / `.request` / `.approve` | absence |
| `hr.time_sheet.read` / `.write` / `.approve` | time recording |
| `hr.training.read` / `.write` | training |
| `hr.certification.read` / `.write` | qualifications |
| `hr.expense.read` / `.submit` / `.approve` | employee expenses |
| `hr.report.read` / `.payroll_input` | reports |

`hr.compensation.read` is deliberately not implied by `hr.employee.read`, and is
the permission most of the organization does not hold. A supervisor who may see
their team, approve their leave and sign their time sheet does not thereby see
what any of them earns.

The four employment operations are separate permissions rather than one `.write`
because they are legally distinct acts with distinct approvals, and because a
system that grants them together cannot express the ordinary arrangement in which
a manager may transfer but only HR may terminate.

**The data-scope restriction:** a user sees the org units, branches and companies
within their scope ([ADR-0006](../../docs/02-decisions/ADR-0006-auth-model.md)),
applied in `adapter/persistence`. For this domain the scope is by **org unit
subtree** as well as by branch: a department head sees their department and
everything under it, as at the date asked for.

Everything in this schema is personal data. The access rules, the export rules
and the retention rules follow [08-security.md](../08-security.md); every read of
`compensation` and every export of an employee list is audited with the requester
and the filter used.

---

## Pages

`pages/hr`. The types — [frontend rule 2](../06-frontend/rules/02-page-types.md).

| Code | Route | Type | Permission | Purpose |
|---|---|---|---|---|
| `HR-ORG-T` | `/hr/org-units` | L | `hr.org.read` | the structure as a tree, with a date selector |
| `HR-ORG-F` | `/hr/org-units/:id` | F | `hr.org.write` | the unit form |
| `HR-JOB-L` | `/hr/jobs` | L | `hr.job.read` | the job catalogue |
| `HR-POS-L` | `/hr/positions` | L | `hr.position.read` | the establishment: planned, filled, vacant |
| `HR-POS-F` | `/hr/positions/:id` | F | `hr.position.write` | the position form with its occupancy history |
| `HR-EMP-L` | `/hr/employees` | L | `hr.employee.read` | employees, filtered by unit, branch and date |
| `HR-EMP-C` | `/hr/employees/:id` | V | `hr.employee.read` | the employee card: person, employments, assignments, absence, training |
| `HR-EMP-F` | `/hr/employees/:id/edit` | F | `hr.employee.write` | the editable part — which is small |
| `HR-EMT-A` | `/hr/employments/:id/action` | F | `hr.employment.transfer` | one form for hire, transfer, promotion, suspension and termination, driven by the action chosen |
| `HR-CMP-L` | `/hr/employments/:id/compensation` | L | `hr.compensation.read` | the compensation history as periods |
| `HR-ABS-L` | `/hr/absences` | L | `hr.absence.read` | absence requests and their state |
| `HR-ABS-C` | `/hr/absences/calendar` | L | `hr.absence.read` | the team calendar |
| `HR-TSH-L` | `/hr/time-sheets` | L | `hr.time_sheet.read` | time sheets by unit and period |
| `HR-TSH-F` | `/hr/time-sheets/:id` | F | `hr.time_sheet.write` | the sheet grid: days across, time codes down |
| `HR-TRN-L` | `/hr/courses` | L | `hr.training.read` | courses and sessions |
| `HR-TRN-F` | `/hr/course-sessions/:id` | F | `hr.training.write` | the session with its enrolments and outcomes |
| `HR-CRT-L` | `/hr/certifications` | L | `hr.certification.read` | qualifications, with the expiring ones first |
| `HR-EXP-L` | `/hr/expenses` | L | `hr.expense.read` | employee expenses |
| `HR-REP-L` | `/hr/reports` | L | `hr.report.read` | headcount, turnover, org chart, absence |

**19 pages.** Two of them carry the design:

`HR-EMT-A` is **one** action form, not five. Which fields it shows comes from the
action chosen and from `employment_event.kind`; the periods it closes and opens
are `EmploymentService`'s single operation. Five separate order screens would be
five places to get the period arithmetic wrong.

`HR-TSH-F` is a grid whose rows are `TIME_CODE` reference rows. A thirteenth time
code adds a row to the grid and nothing else — no component, no column, no
release ([14.3](../03-database/rules/14-patterns.md#143-a-declaration-and-its-slots)).

### The domain's components

| Component | Where it is used | Behaviour |
|---|---|---|
| `OrgUnitLookup` | every HR filter, D5 budgets, D6, D12 | the unit tree as at a date, with subtree selection |
| `EmployeeLookup` | service orders, tasks, CRM, approvals | search by personnel number and by the person's name from D2, employed-at-a-date filter |
| `AsOfDatePicker` | every list over a period-dated table | one control, one default, one place the "as at" semantics are explained |
| `PeriodTimeline` | assignments, compensation, absence, certification | a horizontal timeline of periods with gaps and overlaps visible |

`PeriodTimeline` exists because the periods in this schema are only as useful as
the user's ability to see them. A gap between two assignments is a data defect
that is invisible in a table and obvious on a timeline.

### Page states

Every page defines: loading (`Skeleton`), empty (`EmptyState` with a hint), error
(`ErrorState` with the code and the `traceId`), no permission
(`PermissionGate`). A page showing a past date renders every form read-only.

---

## Audit

The domain owner's decision on what is audited
([§11](../03-database/rules/11-audit.md)). This domain audits more than any other
except D5, because its records are evidence in an employment dispute:

| Table | Audited | Why |
|---|---|---|
| `employment` | all changes | the relationship itself |
| `employment_event` | inserts only | immutable; the insert is the whole history |
| `assignment` | all changes | who worked where is contested more often than anything else here |
| `compensation` | all changes, **and every read** | what someone earns; the read is audited because access to it is the sensitive act |
| `employee` | all changes | |
| `absence` | all state changes | leave entitlement is a legal right |
| `time_sheet` | submission, approval and locking | it is payroll input |
| `time_sheet_entry` | changes after submission only | a draft being filled in is noise |
| `position` | all changes | the establishment is a budgeting decision |
| `org_unit` | all changes, `parent_id` and the period especially | moving a unit changes every report by unit |
| `certification` | inserts and expiry | it gates who may do the work |
| `employee_expense` | approval and payment | |
| `absence_entitlement` | **not audited** | derived and rebuildable |
| `org_unit_name`, `job_name` | **not audited** | a translation does not change meaning |
| `education`, `work_experience` | **not audited** | recorded once from a document; changes are rare and harmless |

Auditing reads is otherwise not done anywhere in the system. `compensation` is
the exception, and it is deliberate: the question that gets asked after a leak is
who looked, not who changed.

---

## Open questions

| # | Question | Affects |
|---|---|---|
| D3-Q1 | May one person hold two concurrent employments in the group, and may the same `party.person` be an employee of two companies at once? | `ex_employment__no_overlap`, `employment.is_primary`, the headcount reports |
| D3-Q2 | Is the establishment (`position`) actually planned, or is headcount managed informally? | 1 table and 3 endpoints; if it is not planned, `assignment` points at `job` and `org_unit` directly |
| D3-Q3 | Does the payment bank account belong to the person or to the employment? | `employee.bank_account_number` moves to `employment` |
| D3-Q4 | Which absence kinds accrue entitlement, on what rule, and does unused leave carry over? | `EntitlementService`, `absence_entitlement.carried_over_days` |
| D3-Q5 | Is the time sheet kept per day and per code, or only as a monthly total? | `time_sheet_entry` volume — tens of millions of rows against hundreds of thousands |
| D3-Q6 | Which jobs legally require a valid certification to be occupied? | `job.requires_certification` seed, `CertifiedForJobRule` |
| D3-Q7 | What is the statutory retention period for personnel records, and does it differ by record kind? | the retention decisions, the partitioning of `time_sheet_entry` |
| D3-Q8 | Is recruitment — vacancies, candidates, interviews — in scope for the system at all? | a possible D3 extension of 4–6 tables, or nothing |
| D3-Q9 | Are performance reviews in scope? | likewise, 2–3 tables |
| D3-Q10 | Does a transfer between companies of the group terminate an employment and start another, or continue one? | `EmploymentService.transfer`, the turnover report, and every seniority calculation |

D3-Q1 and D3-Q10 change the shape of the aggregate and are the two that must be
answered first. The rest change columns and seeds. All of them are closed by the
domain owner **before** the first migration of this schema.
