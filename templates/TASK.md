---
id: TASK-NNNN
title: <name>
epic: EPIC-NNN
owner: <a person>
status: todo | in-progress | blocked | done
estimate: <person-days>
---

# TASK-NNNN. <Name>

## What we are doing

Specifically and within bounds. Going beyond the bounds is filed as a separate
task rather than done "along the way".

## Why

One sentence: what becomes possible afterwards.

## How to verify (acceptance criteria)

- [ ] …
- [ ] …

Every criterion is an observable fact on which a yes/no verdict is reached.
Statements like "works correctly", "optimized", "improved" are not criteria.

## Definition of Done

In addition to the criteria above — the
[Task DoD](../docs/01-principles/02-definition-of-done.md#task-dod):

- [ ] Tests are written and coverage is at or above the threshold
- [ ] The rules [NC-01…NC-15](../docs/01-principles/01-no-compromise.md) are not
      violated, CI is green
- [ ] The API contract is updated if public behaviour changed
- [ ] A schema migration with a verified rollback, if the schema changed
- [ ] Review is done
- [ ] Logs, metrics and traces are added wherever the operation matters
- [ ] The module's README is updated if its contract changed

## Dependencies

What it depends on, what it blocks.

## Notes

What was found during the work: surprises, decisions, links. Filled in as things
happen, not in advance.
