# Working rules for this repository

## Language

Everything written into this repository is in **English**: documents, headings,
tables, diagrams, identifiers, commit messages, PR descriptions, script output,
CI messages, and — later — the product's source code, API contracts, error
messages and migration names.

The only exception is user-facing product text, which is governed by
[ADR-0010](docs/02-decisions/ADR-0010-i18n.md) and lives in translation
catalogues, never inline in the code.

Conversation with the plan owner is held in Russian; nothing from that
conversation is copied into the repository untranslated.

## Comments in code

The shipped product contains **no comments** — not one line. Not a header
block, not a `TODO`, not a commented-out fragment, not a docstring standing in
for a name.

The reasoning: a comment is a patch over code that fails to explain itself. What
a comment would have said belongs somewhere that cannot drift out of date —

| The comment would say | Where it goes instead |
|---|---|
| what this does | the name of the function, type or variable |
| why it is done this way | an ADR in [docs/02-decisions/](docs/02-decisions/README.md) |
| what must not be broken | a test |
| what the shape of the data is | a type, a constraint, a schema |
| what remains to be done | an epic in [backlog/](backlog/README.md) |
| what the API means | the contract ([ADR-0005](docs/02-decisions/ADR-0005-contract-first-api.md)) |

The rule applies to the source code of the application that will be built, and
to nothing else. Nothing in this repository is that code. The plan documents are
prose by nature — including the specifications under `product/` and every code
sample inside them — and the tooling under `tools/` and `.github/` is not the
product either. Comments are free everywhere here; the rule begins in the
product's own repository.

## Notes between sessions

An assistant session may leave notes for the sessions that follow — that is not
a product comment and is not affected by the rule above. Such notes go into the
session memory directory or into an explicitly agreed scratch file, never into
the product's source code. Nothing carrying the word "note to self" survives
into what ships.
