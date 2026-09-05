---
id: PROD-04-R02
title: "Backend rule 2. Module structure"
status: draft
---

## Module structure

Every domain module has the same shape:

```
<domain>/
  README.md              purpose, public interface, invariants, how to test
  api/                   the module's PUBLIC interface — the only thing visible from outside
    <Domain>Facade       operations available to other domains
    dto/                 the types the module exchanges with other domains
    event/               the domain events the module publishes
  domain/                business logic; depends on nothing external
    model/               entities and value objects
    rule/                rules and invariants
    <Domain>Service      domain operations
  application/           scenarios; transaction boundaries; authorization
    <UseCase>Handler     one scenario — one handler
  adapter/
    web/                 HTTP: controllers generated from the API specification
      <Resource>Controller
    persistence/         storage
      <Entity>Repository
      <Entity>Record     the representation of a table row
    external/            external systems
  test/
```

**The dependency rule — inwards, never outwards:**

```
adapter  →  application  →  domain
   │                          ▲
   └──────── api ─────────────┘
```

`domain` knows nothing about HTTP or about the database. That is the only thing
that makes it testable without a container and without a database.
