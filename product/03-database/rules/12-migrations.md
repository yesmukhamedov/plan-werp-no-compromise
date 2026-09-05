---
id: PROD-03-R12
title: "Rule 12. Migrations"
status: draft
---

## 12. Migrations

- Versioned only, forward only, through the migration tool only.
- One migration — one intention, with a description that answers: why this
  change, which query the new index serves, how it is rolled back.
- Every migration is applied to a copy of production data before the merge, and
  its duration on that copy is recorded.
- A migration that locks a table for longer than the stated budget is rejected in
  review, not discovered in production.
- Breaking changes come in four steps, each a separate release:
  **add → backfill → switch → drop**.
- Runtime schema autogeneration is disabled in **all** environments, the
  development one included. The schema is the migration files and nothing else.
- Reference (seed) data is versioned together with the schema.
- The schema of a new environment is built by running every migration from zero;
  a dump restore is never the way an environment is created.
