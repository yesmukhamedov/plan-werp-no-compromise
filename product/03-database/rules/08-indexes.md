---
id: PROD-03-R08
title: "Rule 8. Indexes"
status: draft
---

## 8. Indexes

- An index is created **for a named query**; the migration description states
  which one. "It might be useful" is not a reason.
- The mandatory minimum per table: the primary key; a unique index on every
  natural key; **an index on every foreign key column** — a foreign key without
  one turns every parent delete and every join into a scan; a partial index on
  `deleted_at IS NULL` where the queries filter by it.
- A composite index is ordered by selectivity, the most selective column first,
  and its name lists the columns in that order.
- A partial index is preferred to a full one wherever the query always carries
  the same filter.
- A covering index (`INCLUDE`) is used only where a measurement shows the
  index-only scan matters.
- Text search by a fragment uses a trigram index; a full-text search uses
  `tsvector` with a stored generated column. Neither is done with `LIKE '%…%'`
  over a table.
- An index that no query uses is dropped: it costs a write on every insert. Index
  usage is a monitored metric ([11-observability.md](../../11-observability.md)), and
  an index with zero scans over a quarter is reported.
- Every table above ten million rows has its index set derived from measured
  query plans before the first release, not after the first complaint.
