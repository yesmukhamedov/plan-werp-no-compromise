---
id: PROD-03-S-HR
title: "hr schema — D3 Personnel"
status: draft
---

# `hr` — D3 Personnel

| | |
|---|---|
| Domain | D3 Personnel ([02-domains.md](../../02-domains.md)) |
| Domain specification | [D3-hr.md](../../spec/D3-hr.md) |
| Tables | **23** |
| State of the model | **designed** |
| Table groups | 6 |

The rules every column below obeys: [rules/](../rules/README.md).
How they are enforced: [checks.md](../checks.md).

---

Schema `hr`. All mutable tables have the
[mandatory columns](../rules/04-mandatory-columns.md) — `id`, `created_at`,
`created_by`, `updated_at`, `updated_by`, `version` — which are not repeated
below. Immutable tables are marked as such.

| Marker | Meaning |
|---|---|
| → `table.id` | a reference **inside** this schema, carrying a foreign key |
| ⇢ `schema.table` | a cross-domain reference **by identifier**, with no database constraint; the application enforces it and a nightly job reports orphans as a metric ([§1](../rules/01-organization.md)) |

## Group 1. Structure and establishment

What the company looks like, independently of who works in it: units, the jobs
the company defines, and the seats it budgets. All of it period-dated, so the
structure of any past date is a query.

### `org_unit` — a unit of the organizational structure

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag) over a tree.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `parent_id` | `uuid` | yes | → `org_unit.id` | the parent unit; `null` is the root |
| `code` | `text` | no | `ck` length 1–20 | the unit code |
| `kind` | `text` | no | `ck IN (COMPANY, DIVISION, DEPARTMENT, TEAM)` | the level |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | the branch it is located at |
| `manager_position_id` | `uuid` | yes | → `position.id` | the position that heads it |
| `cost_center_code` | `text` | yes | `ck` length 1–20 | how it is reported in D5 |
| `path` | `ltree` | no | | the materialized path |
| `depth` | `integer` | no | `ck` ≥ 0 | derived from `path` |
| `valid_from` | `date` | no | | exists from |
| `valid_to` | `date` | yes | | exists until, exclusive |

Indexes: `ux_org_unit__company_id__code__valid_from`,
`ix_org_unit__parent_id`, `ix_org_unit__path` (GiST),
`ix_org_unit__branch_id`,
`ix_org_unit__valid_from__valid_to`.

Constraints: `ck_org_unit__no_self_parent`; `ck_org_unit__validity`.
Application rules: `OrgUnitTreeRule` (no cycles), `OrgUnitPeriodWithinParentRule`
(a unit does not outlive its parent).

`path` and `depth` are maintained by a trigger, covered by a test that writes
bypassing the application — one of the two triggers this domain has.

> The unit is headed by a **position**, not by an employee. The head of a
> department is whoever occupies that seat today, and when they leave, the
> department does not become headless in the data.

### `org_unit_name` — unit names by locale

`org_unit_id` → `org_unit.id`, `locale`, `name`, `short_name`.
Index: `ux_org_unit_name__org_unit_id__locale`.

### `job` — a job as the company defines it

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `code` | `text` | no | `ck` length 1–20 | the job code |
| `family_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `JOB_FAMILY` | the job family |
| `grade` | `smallint` | yes | `ck` 1–30 | the grade |
| `is_managerial` | `boolean` | no | default `false` | the job heads a unit |
| `requires_certification` | `boolean` | no | default `false` | occupancy requires a valid certification |
| `is_active` | `boolean` | no | default `true` | in the catalogue |

Indexes: `ux_job__company_id__code`.

### `job_name` — job titles by locale

`job_id` → `job.id`, `locale`, `name`.
Index: `ux_job_name__job_id__locale`. The job title is printed on employment
documents, so it is translated.

### `position` — a seat in the establishment

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `org_unit_id` | `uuid` | no | → `org_unit.id` | the unit the seat belongs to |
| `job_id` | `uuid` | no | → `job.id` | what job it is |
| `code` | `text` | no | `ck` length 1–20 | the position code |
| `budgeted_fte` | `numeric(5,4)` | no | `ck` 0 < value ≤ 10 | the budgeted full-time equivalent |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | where the seat is |
| `reports_to_position_id` | `uuid` | yes | → `position.id` | the reporting line |
| `valid_from` | `date` | no | | exists from |
| `valid_to` | `date` | yes | | exists until, exclusive |

Indexes: `ux_position__company_id__code__valid_from`,
`ix_position__org_unit_id`, `ix_position__job_id`,
`ix_position__reports_to_position_id`.

Constraints: `ck_position__no_self_report`; `ck_position__validity`.
Application rules: `PositionOccupancyRule` (the assigned full-time equivalent on
any date never exceeds `budgeted_fte`), `ReportingLineHasNoCycleRule`.

`budgeted_fte` above 1 is deliberate: one position row may budget five identical
technician seats rather than five position rows that differ in nothing.

## Group 2. The employment relationship

The core of the domain. An employee is a person **and** a company; an employment
is a period; an assignment is who sat in which seat when; an event is what
happened and which order authorized it.

### `employee` — a person employed

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company that keeps the record |
| `party_id` | `uuid` | no | ⇢ `party.person` | **the person; the only identity reference this schema has** |
| `personnel_number` | `text` | no | `ck` length 1–20 | the personnel number |
| `photo_file_id` | `uuid` | yes | ⇢ `platform.stored_file` | a photograph |
| `bank_account_number` | `text` | yes | `ck` length 1–34 | where salary is paid |
| `bank_id` | `uuid` | yes | ⇢ `accounting.bank` | the bank |

Indexes: `ux_employee__company_id__personnel_number`,
`ux_employee__company_id__party_id`, `ix_employee__party_id`.

That is the whole table. There is no name, no date of birth, no gender, no
nationality, no marital status, no passport, no address, no telephone number and
no email address in it — all of that is `party.person` and the tables around it
in D2, where it belongs and where every other domain already reads it.

> The bank account is here rather than in D2 because it is a fact of the
> **employment**, not of the person: the same person may be paid to different
> accounts by two employers. Whether it should move to `employment` when multiple
> employment is confirmed is [D3-Q3](#open-questions).

### `employment` — one employment relationship

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employee_id` | `uuid` | no | → `employee.id` | the employee |
| `company_id` | `uuid` | no | ⇢ `reference.company` | the employing company |
| `number` | `text` | no | | the employment contract number, from `platform.document_number` |
| `contract_kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `EMPLOYMENT_CONTRACT_KIND` | permanent, fixed-term, seasonal, civil |
| `valid_from` | `date` | no | | the first day of employment |
| `valid_to` | `date` | yes | `ck` > `valid_from` | the day after the last, exclusive |
| `probation_ends_on` | `date` | yes | | the end of probation |
| `termination_reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `TERMINATION_REASON` | why it ended |
| `is_primary` | `boolean` | no | default `true` | the main employment, as opposed to a concurrent one |

Indexes: `ux_employment__company_id__number`,
`ix_employment__employee_id__valid_from`,
`ix_employment__valid_to` partial `WHERE valid_to IS NULL` — the open
employments, which is what almost every screen asks for.

Constraints: `ex_employment__no_overlap` — an exclusion constraint on
(`employee_id`, `company_id`, the date range), so one person cannot hold two
simultaneous employments with the same company;
`ck_employment__terminated_has_reason`
(`valid_to IS NULL OR termination_reason_id IS NOT NULL`).

### `assignment` — an employment placed in a position

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag). **The table that
answers "who worked where on that date".**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employment_id` | `uuid` | no | → `employment.id` | the employment |
| `position_id` | `uuid` | no | → `position.id` | the seat |
| `org_unit_id` | `uuid` | no | → `org_unit.id` | the unit, as at the assignment |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | the branch worked at |
| `fte` | `numeric(5,4)` | no | `ck` 0 < value ≤ 1 | the share of a full rate |
| `is_acting` | `boolean` | no | default `false` | temporarily acting in the position |
| `valid_from` | `date` | no | | from |
| `valid_to` | `date` | yes | | until, exclusive |

Indexes: `ix_assignment__employment_id__valid_from`,
`ix_assignment__position_id__valid_from`,
`ix_assignment__org_unit_id`,
`ix_assignment__valid_to` partial `WHERE valid_to IS NULL`.

Constraints: `ex_assignment__no_overlap` — an exclusion constraint on
(`employment_id`, the date range) **excluding acting assignments**, so an
employment has at most one substantive placement at a time while allowing a
temporary acting one alongside it; `ck_assignment__validity`.

Application rules: `AssignmentWithinEmploymentRule` (the period lies inside the
employment's), `AssignmentPositionIsValidRule` (the position exists for the whole
period), `CertifiedForJobRule` (if the job requires certification, a valid one
exists for the period).

`org_unit_id` is stored rather than derived through `position_id` because a
position may be moved between units and the assignment must keep the unit it was
actually served in. That is the one denormalization in this schema, and this is
the sentence that justifies it.

### `employment_event` — a personnel action

**Immutable.** Pattern:
[14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance) — this is the
ledger; the periods above are its derived state.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employment_id` | `uuid` | no | → `employment.id` | the employment |
| `kind` | `text` | no | `ck IN (HIRE, TRANSFER, PROMOTION, COMPENSATION_CHANGE, SUSPENSION, RESUMPTION, TERMINATION, REHIRE, CONTRACT_EXTENSION)` | what happened |
| `effective_date` | `date` | no | | the date it takes effect |
| `reason_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `PERSONNEL_ACTION_REASON` | why |
| `document_id` | `uuid` | yes | ⇢ `docflow.document` | the approved order that authorized it |
| `assignment_id` | `uuid` | yes | → `assignment.id` | the assignment it created or ended |
| `compensation_id` | `uuid` | yes | → `compensation.id` | the compensation row it created |
| `note` | `text` | yes | `ck` length 1–500 | |

Indexes: `ix_employment_event__employment_id__effective_date`,
`ix_employment_event__kind__effective_date`,
`ix_employment_event__document_id` partial `WHERE document_id IS NOT NULL`.

Constraint: `ck_employment_event__hire_has_assignment`.

### `compensation` — what was agreed

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employment_id` | `uuid` | no | → `employment.id` | the employment |
| `kind` | `text` | no | `ck IN (BASE_SALARY, HOURLY_RATE, PIECE_RATE, ALLOWANCE, FIXED_BONUS)` | what kind of pay |
| `allowance_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `ALLOWANCE_KIND` | which allowance, when `kind = ALLOWANCE` |
| `amount` | `numeric(19,4)` | no | `ck` ≥ 0 | the amount |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | its currency |
| `frequency` | `text` | no | `ck IN (MONTHLY, HOURLY, DAILY, PER_UNIT, ANNUAL)` | what the amount is per |
| `percentage` | `numeric(9,6)` | yes | `ck` 0–10 | for an allowance expressed as a share of the base |
| `valid_from` | `date` | no | | agreed from |
| `valid_to` | `date` | yes | | agreed until, exclusive |

Indexes: `ix_compensation__employment_id__kind__valid_from`,
`ix_compensation__valid_to` partial `WHERE valid_to IS NULL`.

Constraints: `ex_compensation__no_overlap` — an exclusion constraint on
(`employment_id`, `kind`, `allowance_id`, the date range);
`ck_compensation__amount_or_percentage` (exactly one of the two is set);
`ck_compensation__allowance_kind` (`kind <> 'ALLOWANCE' OR allowance_id IS NOT NULL`).

Read by D6 through the domain's facade, written only here, and never edited: a
change is a new row and an `employment_event`.

## Group 3. Absence and time

Who was away, how much leave they have left, and how many hours went to which
time code on which day. This group is the input D6 calculates from.

### `absence` — leave, sickness, unpaid absence

Pattern: [14.1](../rules/14-patterns.md#141-a-variant-is-a-row) — every kind of absence
is one table, and the kind is reference data.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employee_id` | `uuid` | no | → `employee.id` | the employee |
| `employment_id` | `uuid` | no | → `employment.id` | which employment it is against |
| `kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `ABSENCE_KIND` | annual leave, sick leave, unpaid, study, parental |
| `valid_from` | `date` | no | | the first day |
| `valid_to` | `date` | no | `ck` > `valid_from` | the day after the last, exclusive |
| `calendar_days` | `integer` | no | `ck` > 0 | the days the period spans |
| `working_days` | `numeric(9,4)` | no | `ck` ≥ 0 | the working days it consumes |
| `state` | `text` | no | `ck IN (REQUESTED, APPROVED, TAKEN, CANCELLED)` | the lifecycle |
| `document_id` | `uuid` | yes | ⇢ `docflow.document` | the approved order |
| `substitute_employee_id` | `uuid` | yes | → `employee.id` | who covers |

Indexes: `ix_absence__employee_id__valid_from`,
`ix_absence__employment_id`,
`ix_absence__state` partial `WHERE state = 'REQUESTED'`,
`ix_absence__valid_from__valid_to`.

Constraints: `ex_absence__no_overlap` — an exclusion constraint on
(`employee_id`, the date range) among rows whose state is not `CANCELLED`.

Application rule `AbsenceWithinEmploymentRule`. `working_days` is computed by
`WorkingCalendarService` from the production calendar and stored, because the
calendar changes and last year's leave must not be recomputed against this
year's holidays.

### `absence_entitlement` — the leave balance

**Rebuildable.** Derived from the entitlement rules and the absences taken;
rebuilt by a job whose divergence is an alert
([14.4](../rules/14-patterns.md#144-a-ledger-and-a-derived-balance)).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employment_id` | `uuid` | no | → `employment.id` | the employment |
| `kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `ABSENCE_KIND` | which entitlement |
| `year` | `smallint` | no | `ck` 2000–2100 | the entitlement year |
| `entitled_days` | `numeric(9,4)` | no | `ck` ≥ 0 | earned for the year |
| `carried_over_days` | `numeric(9,4)` | no | default 0, `ck` ≥ 0 | brought forward |
| `used_days` | `numeric(9,4)` | no | default 0, `ck` ≥ 0 | consumed by absences |
| `remaining_days` | `numeric(9,4)` | no | generated `STORED` | entitled + carried over − used |
| `rebuilt_at` | `timestamptz` | no | | when this row was computed |

Indexes: `ux_absence_entitlement__employment_id__kind_id__year`.

`remaining_days` is a generated column — a pure function of the same row, which
is what [§9](../rules/09-logic-in-the-database.md) permits.

### `time_sheet` — one employee, one period

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employment_id` | `uuid` | no | → `employment.id` | the employment |
| `org_unit_id` | `uuid` | no | → `org_unit.id` | the unit the sheet is kept by |
| `period_start` | `date` | no | | the first day of the period |
| `period_end` | `date` | no | `ck` ≥ `period_start` | the last day |
| `state` | `text` | no | `ck IN (DRAFT, SUBMITTED, APPROVED, LOCKED)` | the lifecycle |
| `approved_at` | `timestamptz` | yes | | when |
| `approved_by` | `uuid` | yes | ⇢ `platform.app_user` | by whom |

Indexes: `ux_time_sheet__employment_id__period_start`,
`ix_time_sheet__org_unit_id__period_start`,
`ix_time_sheet__state` partial `WHERE state = 'SUBMITTED'`.

`LOCKED` is set when a payroll run has consumed the sheet. A locked sheet is
corrected by a new sheet for the same period marked as a correction, never by an
edit — the same discipline the ledger uses, for the same reason.

### `time_sheet_entry` — one day, one time code

Pattern: [14.2](../rules/14-patterns.md#142-a-repeating-group-is-a-child-table) and
[14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots). **A new time code is a
row of reference data.**

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `time_sheet_id` | `uuid` | no | → `time_sheet.id` | the sheet |
| `work_date` | `date` | no | | the day |
| `time_code_id` | `uuid` | no | ⇢ `reference.reference_item` in list `TIME_CODE` | worked, overtime, night, holiday, sickness, training |
| `hours` | `numeric(9,4)` | no | `ck` 0 < value ≤ 24 | the hours under that code |
| `absence_id` | `uuid` | yes | → `absence.id` | the absence the entry records, when it records one |

Indexes: `ux_time_sheet_entry__time_sheet_id__work_date__time_code_id`,
`ix_time_sheet_entry__work_date`,
`ix_time_sheet_entry__absence_id` partial `WHERE absence_id IS NOT NULL`.

Application rules: `EntryWithinSheetPeriodRule`, `DailyHoursRule` (the hours of
one day across all codes never exceed 24).

> This is the table where the pattern pays most visibly. A thirteenth time code —
> a new shift premium, a new statutory absence category — is a row in
> `reference_item`. It appears in the time sheet, in the payroll input and in
> every report on the day it is entered, with no migration, no release and no
> column that is empty for everyone who does not use it.

## Group 4. Background and qualification

What the employee brings and what they are certified to do. `certification` is
the one that gates work: a job that requires it may not be occupied without a
valid one.

### `education` — education recorded for an employee

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employee_id` | `uuid` | no | → `employee.id` | the employee |
| `level_id` | `uuid` | no | ⇢ `reference.reference_item` in list `EDUCATION_LEVEL` | secondary, vocational, bachelor, master, doctoral |
| `institution_name` | `text` | no | `ck` length 1–255 | where |
| `speciality` | `text` | yes | `ck` length 1–255 | what |
| `graduated_in` | `smallint` | yes | `ck` 1900–2100 | the year |
| `document_number` | `text` | yes | `ck` length 1–40 | the diploma number |
| `file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the scan |

Indexes: `ix_education__employee_id`.

### `work_experience` — experience before or outside the company

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employee_id` | `uuid` | no | → `employee.id` | the employee |
| `employer_name` | `text` | no | `ck` length 1–255 | where |
| `job_title` | `text` | no | `ck` length 1–255 | as what |
| `valid_from` | `date` | no | | from |
| `valid_to` | `date` | yes | `ck` > `valid_from` | until |
| `is_relevant` | `boolean` | no | default `true` | counts towards professional seniority |

Indexes: `ix_work_experience__employee_id__valid_from`.

### `certification` — a qualification held, with its validity

Pattern: [14.5](../rules/14-patterns.md#145-a-period-not-a-flag).

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employee_id` | `uuid` | no | → `employee.id` | the employee |
| `kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `CERTIFICATION_KIND` | driving licence, electrical safety group, professional certificate |
| `number` | `text` | yes | `ck` length 1–40 | the certificate number |
| `issued_by` | `text` | yes | `ck` length 1–255 | the issuer |
| `valid_from` | `date` | no | | valid from |
| `valid_to` | `date` | yes | `ck` > `valid_from` | valid until, exclusive |
| `course_enrolment_id` | `uuid` | yes | → `course_enrolment.id` | the training that produced it |
| `file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the scan |

Indexes: `ix_certification__employee_id__kind_id__valid_from`,
`ix_certification__valid_to` — the expiry report is a scheduled job, not
something a supervisor remembers.

Read by `CertifiedForJobRule` when an assignment is made to a job whose
`requires_certification` is true.

## Group 5. Training

A course is declared once; a session is one run of it; an enrolment is one
employee on one session. Passing a session issues the certification the course
declares.

### `course` — a training course

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `company_id` | `uuid` | no | ⇢ `reference.company` | the company |
| `code` | `text` | no | `ck` length 1–20 | the course code |
| `name` | `text` | no | `ck` length 1–255 | the name |
| `kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `COURSE_KIND` | induction, safety, product, managerial |
| `duration_hours` | `numeric(9,2)` | yes | `ck` > 0 | the length |
| `certification_kind_id` | `uuid` | yes | ⇢ `reference.reference_item` in list `CERTIFICATION_KIND` | what passing it certifies |
| `validity_months` | `smallint` | yes | `ck` > 0 | how long that certification lasts |
| `is_active` | `boolean` | no | default `true` | offered |

Indexes: `ux_course__company_id__code`.

### `course_session` — one run of a course

Pattern: [14.3](../rules/14-patterns.md#143-a-declaration-and-its-slots) — the course
is the declaration, the session is the instance.

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `course_id` | `uuid` | no | → `course.id` | the course |
| `branch_id` | `uuid` | yes | ⇢ `reference.branch` | where it is held |
| `trainer_employee_id` | `uuid` | yes | → `employee.id` | who runs it |
| `starts_on` | `date` | no | | the first day |
| `ends_on` | `date` | no | `ck` ≥ `starts_on` | the last day |
| `capacity` | `smallint` | yes | `ck` > 0 | the seats |
| `state` | `text` | no | `ck IN (PLANNED, RUNNING, COMPLETED, CANCELLED)` | the lifecycle |

Indexes: `ix_course_session__course_id__starts_on`,
`ix_course_session__state` partial `WHERE state = 'PLANNED'`.

### `course_enrolment` — an employee on a session

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `course_session_id` | `uuid` | no | → `course_session.id` | the session |
| `employee_id` | `uuid` | no | → `employee.id` | the employee |
| `state` | `text` | no | `ck IN (ENROLLED, ATTENDED, PASSED, FAILED, WITHDRAWN)` | the outcome |
| `score` | `numeric(5,2)` | yes | `ck` 0–100 | the result |
| `completed_on` | `date` | yes | | when |
| `cost_amount` | `numeric(19,4)` | yes | `ck` ≥ 0 | what it cost |
| `currency_id` | `uuid` | yes | ⇢ `reference.currency` | its currency |

Indexes: `ux_course_enrolment__course_session_id__employee_id`,
`ix_course_enrolment__employee_id`.

Constraint: `ck_course_enrolment__cost_has_currency`.

Passing a session whose course names a `certification_kind_id` creates a
`certification` row valid for `validity_months` — one rule, `CertificationFromCourseRule`,
rather than a manual step someone forgets.

## Group 6. Around the employment

Facts recorded against an employee that other domains consume: dependants for
tax relief, expenses for reimbursement, the interview recorded on departure.

### `dependant` — a family member the employment depends on

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employee_id` | `uuid` | no | → `employee.id` | the employee |
| `party_id` | `uuid` | yes | ⇢ `party.person` | the person, when they are recorded as one |
| `relation_id` | `uuid` | no | ⇢ `reference.reference_item` in list `FAMILY_RELATION` | child, spouse, dependent parent |
| `birth_date` | `date` | yes | | needed for age-dependent relief |
| `valid_from` | `date` | no | | recorded from |
| `valid_to` | `date` | yes | | recorded until, exclusive |
| `is_tax_relevant` | `boolean` | no | default `false` | affects a tax relief D6 applies |

Indexes: `ix_dependant__employee_id__valid_from`.

`party_id` is optional because a dependant is often recorded from a certificate
without becoming a counterparty of the company. When they are one, they are the
same `party.person` as everywhere else
([14.6](../rules/14-patterns.md#146-one-identity-many-roles)).

### `employee_expense` — an expense reimbursed to an employee

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employee_id` | `uuid` | no | → `employee.id` | the employee |
| `employment_id` | `uuid` | no | → `employment.id` | the employment |
| `kind_id` | `uuid` | no | ⇢ `reference.reference_item` in list `EXPENSE_KIND` | travel, fuel, accommodation, materials |
| `expense_date` | `date` | no | | when it was incurred |
| `amount` | `numeric(19,4)` | no | `ck` > 0 | the amount |
| `currency_id` | `uuid` | no | ⇢ `reference.currency` | its currency |
| `state` | `text` | no | `ck IN (SUBMITTED, APPROVED, REJECTED, PAID)` | the lifecycle |
| `document_id` | `uuid` | yes | ⇢ `docflow.document` | the approval |
| `payment_id` | `uuid` | yes | ⇢ `accounting.payment` | how it was reimbursed |
| `file_id` | `uuid` | yes | ⇢ `platform.stored_file` | the receipt |

Indexes: `ix_employee_expense__employee_id__expense_date`,
`ix_employee_expense__state` partial `WHERE state = 'SUBMITTED'`.

### `exit_interview` — the interview recorded on departure

| Column | Type | Null | Constraints | Meaning |
|---|---|---|---|---|
| `employment_id` | `uuid` | no | → `employment.id` | the employment that ended |
| `interviewed_on` | `date` | no | | when |
| `interviewer_employee_id` | `uuid` | yes | → `employee.id` | who conducted it |
| `primary_reason_id` | `uuid` | no | ⇢ `reference.reference_item` in list `DEPARTURE_REASON` | the stated main reason |
| `would_return` | `boolean` | yes | | whether they would return |
| `note` | `text` | yes | `ck` length 1–4000 | the record |

Indexes: `ux_exit_interview__employment_id`.

## Tables that deliberately do not exist

Each was considered, failed the
[three questions](../rules/14-patterns.md#how-a-pattern-is-chosen), and is recorded so
that it is not re-proposed:

| Not a table | Where it lives instead | Which question it failed |
|---|---|---|
| an employee card with names, documents and contacts | `party.person`, `party.identity_document`, `party.address_link`, `party.phone_link` | 1 — the person already exists, once, for the whole system |
| a dismissed-employees table, or a dismissal flag | `employment.valid_to` and `termination_reason_id` | 3 — employment is a period |
| a current-position column on the employee | `assignment` as at a date | 3 |
| a table per absence kind | `absence` with `kind_id` | 1 |
| hours-worked, overtime and night columns on a time sheet | `time_sheet_entry`, one row per code | 2 |
| a salary-history table beside a salary table | `compensation`, which is the history | 3 |
| a table per personnel order kind | `docflow.document` with a `document_type`, and one `employment_event` | 1 — one workflow engine for the system |
| a separate structure for "as at year-end" reporting | the same tables, queried with a date | 3 |
| an organizational-chart table | `org_unit.path` and `position.reports_to_position_id` | 1 |

## Summary

| Table | Estimated rows | Mutability |
|---|---:|---|
| `org_unit` | hundreds | rarely |
| `org_unit_name` | ×3 of the parent | with the parent |
| `job` | hundreds | rarely |
| `job_name` | ×3 of the parent | with the parent |
| `position` | thousands | on establishment revision |
| `employee` | tens of thousands | rarely |
| `employment` | tens of thousands, growing | on hire and departure |
| `assignment` | hundreds of thousands | inserts, plus closing a period |
| `employment_event` | hundreds of thousands | **immutable** |
| `compensation` | hundreds of thousands | inserts, plus closing a period |
| `absence` | hundreds of thousands | state changes |
| `absence_entitlement` | hundreds of thousands | rebuilt |
| `time_sheet` | millions, growing | state changes |
| `time_sheet_entry` | tens of millions, growing | until the sheet locks |
| `education` | tens of thousands | rarely |
| `work_experience` | tens of thousands | rarely |
| `certification` | hundreds of thousands | inserts |
| `course` | hundreds | rarely |
| `course_session` | thousands | state changes |
| `course_enrolment` | hundreds of thousands | state changes |
| `dependant` | tens of thousands | rarely |
| `employee_expense` | hundreds of thousands | state changes |
| `exit_interview` | tens of thousands | rarely |

**23 tables** in total.

Above the partitioning threshold ([§10](../rules/10-large-tables.md)):
`time_sheet_entry`, range-partitioned by `work_date`; `time_sheet`, reviewed
against measured volume before the first release.

Retention: personnel records are kept for the statutory period, which is longer
than the platform default and is cited in the migration that sets it. `absence`,
`time_sheet` and `employee_expense` are the tables where a retention decision
actually removes volume, and each has one recorded.
