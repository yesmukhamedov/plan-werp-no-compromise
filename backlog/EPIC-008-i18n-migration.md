---
id: EPIC-008
title: Multilingual support migration
phase: 0 (preparation) → 3 (execution)
owner: not assigned
status: todo
---

# EPIC-008. Multilingual support migration

## Why

Three languages (ru / en / tr), ~1,700 messages per language. Today the
dictionaries live in two places in two different formats: `react-intl` with a
1,573-line declaration file and a Babel extraction script on the frontend, an
`i18n` directory and `messages*.properties` on the backend.

The keys are opaque and partly coincide with transliterated field names from the
inherited ERP.

The work seems "free" — which is why it is regularly underestimated.

## Result

A single dictionary for the system with meaningful keys, complete in all three
languages.

## Tasks

### TASK-0801. Collect all the messages

From all the sources: the frontend, the backend, the separate services, error
messages, email and SMS templates, texts in reports.

**Acceptance:** a consolidated list; duplicates and discrepancies between the
sources are identified.

### TASK-0802. Determine liveness

Messages not used by any screen or service.

**Acceptance:** the dead messages are flagged and are not carried over.

### TASK-0803. Design the key scheme

Hierarchical, tied to the domain and the screen
([ADR-0010](../docs/02-decisions/ADR-0010-i18n.md)). The "old key → new" mapping.

**Acceptance:** the scheme is described; the mapping is complete for the messages
being carried over.

### TASK-0804. Check the completeness of the translations

Messages not translated into all three languages.

**Acceptance:** a list of gaps; a decision on each — translate it or drop the
message.

> After the migration the completeness check becomes part of CI: a missing
> translation breaks the build
> ([ADR-0010](../docs/02-decisions/ADR-0010-i18n.md)).

### TASK-0805. Define the translation maintenance process

Who adds translations after launch and how — a developer in the code or a content
owner through a tool.

**Acceptance:** [OQ-010](../transition/12-open-questions.md#oq-010) is closed;
the choice of message store depends on the answer.

### TASK-0806. Design the localization of errors

The server returns an error code and parameters, and the client substitutes the
localized text ([API rule 5](../product/05-api/rules/05-errors.md)).

**Acceptance:** a list of error codes with messages in three languages; the codes
are declared in the API specification.

### TASK-0807. Localization of reports and printable forms

**Acceptance:** the requirement is handed over to the reporting subsystem
([ADR-0009](../docs/02-decisions/ADR-0009-reporting-and-exports.md)).

## Epic closure criteria

- [ ] All the messages are collected and duplicates and discrepancies identified
- [ ] The dead messages are weeded out
- [ ] The key scheme is designed and the mapping described
- [ ] The gaps in the translations are closed
- [ ] OQ-010 is closed
- [ ] The error codes are localized and declared in the specification
- [ ] The requirements for localizing reports are handed over
