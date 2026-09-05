---
id: PROD-03-R13
title: "Rule 13. Performance"
status: draft
---

## 13. Performance

- Queries are profiled at a volume comparable to production, on data with a
  comparable distribution.
- The N+1 problem is caught by a test ([09-quality.md](../../09-quality.md)).
- Heavy reads — reports, exports, analytics — go to a replica, and the code says
  so explicitly.
- Every query that a screen depends on has a measured budget
  ([10-performance.md](../../10-performance.md)); a plan regression is a build failure.
