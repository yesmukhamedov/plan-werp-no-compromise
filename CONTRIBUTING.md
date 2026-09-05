# How to maintain this plan

The plan is a living document and is run as a project: changes go through PRs,
checks run in CI, decisions are recorded as ADRs.

## Change procedure

1. Branch from `main`.
2. Make the change.
3. Run `./tools/validate.sh` locally.
4. Open a PR describing what changes and why.
5. Review. Changes to ADRs and to the
   [rules](docs/01-principles/01-no-compromise.md) require the plan owner's
   consent.
6. Merge.

Direct pushes to `main` are not made.

## Where to write what

The first question for any change: **is this about what will be, or about how we
get there?**

| I want to | Where |
|---|---|
| Describe a target table, class, endpoint, page | [product/](product/README.md) |
| Describe what turns into what | [transition/](transition/README.md) |
| Record a fact about the system in operation | [docs/00-context/](docs/00-context/) |
| Record an architectural decision | a new ADR from [templates/ADR.md](templates/ADR.md) |
| Change a decision already taken | **do not edit the old ADR** — a new ADR with a `supersedes` link |
| Add work | an epic in [backlog/](backlog/) from [templates/EPIC.md](templates/EPIC.md) |
| Add a risk | [transition/11-risks.md](transition/11-risks.md) |
| Ask a question that changes the plan | [transition/12-open-questions.md](transition/12-open-questions.md) |
| Change a rule | a PR to [01-no-compromise.md](docs/01-principles/01-no-compromise.md) with a rationale |
| Introduce a term | [GLOSSARY.md](GLOSSARY.md) |

### The split rule

**`product/` does not mention legacy. Ever.**

The test: remove every mention of the previous system from the document. Still
makes sense — it belongs in `product/`. Falls apart — it belongs in
`transition/`.

This rule is machine-enforced: `tools/validate.sh` searches `product/` for the
words "legacy", "inherited", "current system" and the names of the legacy
repositories. A PR with such words in `product/` is not merged.

The rationale for a requirement lives in `docs/00-context/`, and both sections
link to it. The phrasing "today it is like this, but it will be different" in
`product/` is replaced by the phrasing "it will be like this" plus a link to the
pain point.

The symmetric rule: mappings (`transition/01…04`, `transition/map/`) **must**
link into `product/` — a map that does not point at the target is not a map but
a list. This is checked too.

### Document pairing

Four slices of the system are described in pairs; both halves change in a single
PR:

| Slice | Product | Transition |
|---|---|---|
| Database | `product/03-database/`, `product/spec/D*.md` | `transition/01-database-mapping.md`, `transition/map/D*.md` |
| Backend | `product/04-backend/`, `product/spec/D*.md` | `transition/02-backend-mapping.md`, `transition/map/D*.md` |
| API | `product/05-api/` | `transition/03-api-mapping.md` |
| Frontend | `product/06-frontend/` | `transition/04-frontend-mapping.md` |

A domain's specification and its mapping are written **together**: a column is
designed and immediately gets its transformation rule. Written at different
times, they drift apart, and the drift is discovered at the migration rehearsal
— that is, too late.

## Rules

### ADRs are not rewritten after the fact

A cancelled decision gets the status "Superseded" and a link to its successor.
What is preserved is not only the outcome but the reason — otherwise in a year's
time the decision will be taken again, and just as wrongly.

### Artefact maturity statuses

Every table, module, endpoint and page in the `product/` registries has a
status: `designed` (code may be written), `outlined` (its composition is known),
`declared` (all that is known is that it is needed). Implementation does not
start before the status is `designed`.

Every item in the `transition/` maps has a decision: migrate / consolidate / do
not migrate / new. An item without a decision is unfinished Phase 0 work.

### Numbers come from measurements

Every number in the plan must be reproducible. The measurement method is in the
[appendix to the inventory](docs/00-context/01-inventory.md#appendix-how-this-was-measured);
the script is [tools/measure.sh](tools/measure.sh).

If a number comes from an estimate rather than a measurement, that is stated
explicitly.

### Estimates come as ranges, with a stated confidence

An estimate is a commitment to recalculate it at the next gate, not a promise to
fit inside it ([transition/10-estimates.md](transition/10-estimates.md)).

### Identifiers are not reused

ADR-NNNN, EPIC-NNN, TASK-NNNN, R-NN, OQ-NN, P-NN, NC-NN, SC-NNN. A cancelled
entry stays in place with a note. Uniqueness is checked in CI.

### Links are relative

Checked in CI. A broken link is grounds for refusing a merge.

### Frontmatter is mandatory

Every document in `docs/` and `backlog/` starts with a `---` block containing the
fields `id`, `title`, `status`. Checked in CI.

## Sensitive data

The repository is **public**. The following must not get in:

| Forbidden | Use instead |
|---|---|
| Internal-network IP addresses | `<internal-host>` |
| Infrastructure host and domain names | "the legacy environment", "the pre-production environment" |
| Service port numbers | do not state them |
| Database, schema and account names | describe them generically |
| Cookie names, names of headers carrying tokens | do not state them |
| Secrets, keys, tokens in any form | never |
| Legacy source code | a description of the behaviour |
| Production data dumps | aggregated metrics |
| Personal data | never |
| Security audit results describing vulnerabilities | only the requirements that follow from them ([EPIC-010](backlog/EPIC-010-security-audit.md#handling-the-results)) |

Some of this is checked automatically in `tools/validate.sh`. The automated check
does not replace attention during review: it catches known patterns, not
everything.

Referring to repositories by name (`werp_java_back_v2`, `bridge`) is acceptable
— those are names, not access.

## Local check

```sh
./tools/validate.sh      # plan integrity check
./tools/measure.sh <path-to-repository>   # recompute legacy metrics
```

`validate.sh` checks: frontmatter, identifier uniqueness, internal links,
sensitive-data patterns, **the product/transition split**, completeness of the
ADR and epic registries, leftover template placeholders. The same script runs in
CI.

## Plan status

Updated in [README.md](README.md) when a gate is passed. Once the project is
finished the plan is moved to the `completed` status and archived together with
the retrospective
([transition/plan/06-phase-5-decommission.md](transition/plan/06-phase-5-decommission.md#7-retrospective)).
