---
id: PROD-03-R10
title: "Rule 10. Large tables"
status: draft
---

## 10. Large tables

A table is large when its size changes a decision, not when it feels big.
Thresholds, measured before each choice:

| Volume | What is decided |
|---|---|
| > 10 million rows | the index set comes from measured plans; reads move to a replica |
| > 50 million rows, time-ordered | range partitioning by the domain's time key |
| history older than the retention period | a partition detached into the archive schema, not a `_archive` table |

- Partitioning is introduced on measured volume and a measured query pattern, not
  in advance.
- Archiving is **detaching a partition**, never copying rows into a table with a
  different name. A historical row keeps its identifier and its shape.
- Retention per table is a decision of the domain owner recorded in the
  specification; where the law sets it, the law is cited.
