---
id: PRN-03
title: Engineering standards
status: draft
---

# Engineering standards

The rules [NC-01…NC-15](01-no-compromise.md) say what must not be done. This
document says how things are done. It is stack-neutral: the concrete tools are
substituted after [ADR-0003](../02-decisions/ADR-0003-backend-stack.md).

## Repository and branches

- One repository per top-level component; the structure is defined by
  [ADR-0007](../02-decisions/ADR-0007-repo-layout.md).
- `main` is always in a state fit for building and deploying.
- Work happens in short-lived branches, merged through PRs; a direct push to
  `main` is technically forbidden.
- Commit messages follow Conventional Commits; the changelog is assembled from
  them.

## Review

- At least one reviewer, not the author.
- The reviewer answers three questions: is the task solved correctly, are the
  rules unbroken, will the next person understand this a year from now.
- A PR larger than ~400 changed lines is split where possible.

## Module structure

Every module in the system has the same shape. The model is the `bridge`
repository: a README explaining purpose, principles and structure; separation
along the axes "who calls us" and "who we integrate with"; tests next to the
code; configuration from environment variables with mandatory values validated
at start-up.

The mandatory minimum for a module:

```
README.md          purpose, principles, structure, how to run, how to test
<public API>       what other modules see — explicit and narrow
<domain>           business logic independent of transport and storage
<adapters>         storage, HTTP, queues, external systems
<tests>            next to the code, run by a single command
```

A module README is mandatory and is updated together with the code. A module
without a README is not merged.

## Naming

- One domain entity — one name across the whole system: in the code, in the API,
  in the data schema, in the interface and in conversation. The glossary is
  [GLOSSARY.md](../../GLOSSARY.md).
- Transliteration in names is forbidden: either the concept is translated in the
  glossary once, or it is used as it is — but not `bukrs`, `matnr`, `lifnr`, and
  not `srok_dogovora`. The current field names are inherited from a third-party
  ERP and must be decoded in the glossary before being carried over.
- Names in the data schema are `snake_case`, singular for an entity.

## Errors

- One error model for the whole system: a machine-readable code, a
  human-readable message, a request identifier for searching the logs.
- An error is not swallowed: it is either handled or propagated with context.
- The client never receives a stack trace, a class name, SQL text or a table
  name.

## Handling time and money

- Time is stored in UTC and displayed in the user's time zone. The time zone is
  not baked into the image.
- Money — only a fixed-precision decimal type, never a floating-point number.
  The rounding rules are defined once at the platform level
  ([product/03-database/](../../product/03-database/README.md)) and are not overridden
  in the domains.
- The currency is stored together with the amount.

## Schema migrations

- Forward only, versioned only, through a migration tool only.
- Every migration is applied reversibly against a copy of production data before
  it is merged.
- Backward-incompatible changes are broken into steps (add → backfill → switch →
  drop).
- `ddl-auto` and any runtime schema autogeneration are forbidden in all
  environments.

## Performance

- Every list is paginated; endpoints returning an unbounded result set do not
  exist.
- Database queries are profiled against a realistic data volume, not an empty
  database.
- The N+1 problem is caught by a test, not in production.
- Reports and exports running longer than a threshold are executed
  asynchronously, with a notification to the user.

## Security

- Secrets come only from the secret store, never from the repository, the image
  or a log.
- External traffic is TLS only.
- Every endpoint declares the permission it requires (NC-12).
- Input is validated at the boundary, not deep inside the logic.
- More detail — [product/08-security.md](../../product/08-security.md).

## Documentation

- Documentation lives next to the code and changes together with it.
- Architectural decisions go into ADRs only, one file per decision.
- The API specification is generated from the contract, not written by hand
  ([ADR-0005](../02-decisions/ADR-0005-contract-first-api.md)).
- A document nobody reads is deleted, not "maintained".

## Comments in the code

- The product's source code contains **no comments** — not one line. No header
  blocks, no `TODO`, no commented-out fragments, no docstring that merely
  restates the name.
- A comment is a patch over code that does not explain itself, and it is the one
  artefact nothing verifies: the compiler, the tests and CI all stay silent when
  it goes stale. What a comment would have said is therefore moved to a place
  that cannot drift —

  | Would have been a comment about | Goes into |
  |---|---|
  | what the code does | the name of the function, type or variable |
  | why it is done this way | an ADR |
  | what must not break | a test |
  | the shape of the data | a type, a constraint, a schema migration |
  | work still to be done | an epic in the backlog |
  | the meaning of an endpoint | the API contract |

- If a fragment cannot be understood without a comment, the fragment is
  rewritten — extracted into a named function, given a domain type, or split
  until the name is enough.
- **How it is checked:** a linter rule in the new project's CI that fails the
  build on any comment token in the product's source trees.
- **Scope:** the rule covers the source code of the application being built, and
  nothing else. None of this repository is that code — neither the plan
  documents, nor the specifications under `product/` and the code samples inside
  them, nor the tooling under `tools/` and `.github/`. The rule begins in the
  product's own repository.

## Language

- Everything committed is in English: code, identifiers, schema and migration
  names, API contracts, log and error messages, commit messages, and the
  documents in this repository.
- User-facing text is not written inline anywhere. It lives in the translation
  catalogues described in
  [ADR-0010](../02-decisions/ADR-0010-i18n.md), keyed and translated there.
