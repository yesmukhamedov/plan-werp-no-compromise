---
id: PROD-06-R06
title: "Frontend rule 6. Performance"
status: draft
---

## Performance

- The bundle is split by route; a page loads only its own code.
- Tables are virtualized: 10,000 rows are not rendered in full.
- The bundle size budget is checked in CI; exceeding it means the merge is
  refused.
- The target figures — [07-nfr.md](../../07-nfr.md).

---
