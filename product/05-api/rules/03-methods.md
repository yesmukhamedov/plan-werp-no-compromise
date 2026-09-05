---
id: PROD-05-R03
title: "API rule 3. Methods"
status: draft
---

## Methods

| Method | Meaning | Idempotent |
|---|---|---|
| GET | reading, no side effects | yes |
| POST | creation or a non-idempotent action | no |
| PUT | full replacement | yes |
| PATCH | partial change | no |
| DELETE | deletion (as a rule, logical) | yes |
