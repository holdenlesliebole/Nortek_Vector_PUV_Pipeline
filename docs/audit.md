# PUV Pipeline — Audit Log

Consistency/staleness audits of the docs, LaTeX, config, and scripts against
the code and the server catalog. Newest entry first; prior entries are kept as
history (findings marked resolved when fixed, so recurring drift is visible).

---

## 2026-07-24

Run after a large session that ingested the pre-2023 raw-`.VEC` archive (Tier
A/B/C, 23 new deployments) and rewrote much of the docs. Server catalog:
**65 instrument-records / 46 deployments** (authoritative: `Processed_HLB/manifest.csv`).

This is a processing-pipeline repo — no paper manuscript, figure registry, or
`\includegraphics`, so the three-way figure↔manuscript↔registry check is N/A.
`docs/PUV_Pipeline_Guide.tex` is self-contained and its PDF is current (both
2026-07-24).

### Findings

**STALE — high value**
1. `docs/pre2023_deployment_inventory.md` has a corrected update-box at the top
   (2026-07-24) but a **stale body**. The "Sarah archive notes (May 5, 2026)"
   section (≈L138–182), the Group C table row for `Sarah_LPL_2014-2023` (L111),
   and the Tier 2B/3 rows (L193–194) still assert the Sarah archive is **8 Hz,
   dead-RTC, "not drop-in", "multi-day effort"** — all disproved this session
   (it is 2 Hz; the clock runs from a wrong epoch; 12 of it were processed as
   Tier C). A reader who skips the top box gets the wrong story.
   → Successor is unambiguous: `docs/recopied_data_backlog.md` "Tier C".
   *Fix: add dated superseded markers to those sections/rows pointing at Tier C.*
   **safe.**

2. `docs/deployment_database_overview.md` (dated April 5, 2026; "Prepared for
   Brian Woodward") states **"40 instruments across 20 deployments, 33
   processed"** (now 65/46) and calls the instruments **"Nortek AWAC"** (they
   are Nortek Vector). Two living docs point at it as a reference
   (`PIPELINE_NOTES.md` L341/L343, `docs/todo.md` L274), so a new session
   following those pointers reads the stale counts and wrong instrument name.
   *Fix: it is a point-in-time deliverable — add a "superseded snapshot as of
   2026-04-05; current catalog is 65/46, see pipeline_levels.md" header rather
   than rewriting it; optionally caveat the two pointers.* **needs a call**
   (frozen deliverable vs. living reference).

**STALE — low value**
3. `config/DOFFP_LOOKUP_CHECKLIST.md` (2026-04-09) lists no `doffp` entries for
   the archive configs (TOR14–20, CDF, COR, IB19W). Those use documented
   inherited/estimated `doffp` (recorded in each config's header), so they are
   not "pending a DeploymentNotes lookup" in the same sense as the modern
   deployments the checklist tracks. Note only; no fix required.

**NON-FINDINGS (checked, OK)**
- Catalog counts consistent at 65/46 across `CLAUDE.md`, `PIPELINE_NOTES.md`,
  `docs/pipeline_levels.md`, `docs/todo.md`. `L4_xspec` = 9 deployments in both
  docs and manifest.
- Every code path named in the living docs resolves on disk (`read_VEC.m`,
  `copy_to_server.m`, `shared/*.m`, config files, etc.).
- Registry (50 keys) consistent with `TorreyOffshore_config` (17 table cases =
  16 registered + TOR20A held out). TOR20A and the 2023 dye correctly absent
  from the server manifest.
- Deep-reference `.tex` files (`methods_L1_L2`, `results_validation`,
  `multitaper_writeup`) carry their "predates the 2026-07 rework / see the
  Guide" markers — intentionally superseded, not broken.
- `README.md`, `config/README.md`, `docs/NEW_DEPLOYMENT.md` current (raw-`.VEC`
  ingest documented; no stale toolbox/count claims).
- Historical logs correctly not treated as live: `docs/RESULTS_*.md`,
  `docs/*_2026-07-0*.md`, `draft_email_to_bill.md`, `mean_flow_validation_plan.md`.

### Actions
- [x] (safe) Marked the stale Sarah sections/rows + the top-box "8 Hz/dead RTC"
  line in `pre2023_deployment_inventory.md` as superseded → Tier B/C
  (2026-07-24).
- [x] (needs a call → applied) Added a superseded-snapshot header to
  `deployment_database_overview.md` and caveated the two `PIPELINE_NOTES.md`
  pointers to it (2026-07-24). The `docs/todo.md` pointer is inside a dated
  "(May 5)" history entry and was left as-is.
