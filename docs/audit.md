# PUV Pipeline — Audit Log

Consistency/staleness audits of the docs, LaTeX, config, and scripts against
the code and the server catalog. Newest entry first; prior entries are kept as
history (findings marked resolved when fixed, so recurring drift is visible).

---

## 2026-07-28

Run after the session that corrected the filename clock (Pacific local → UTC,
18 records rebuilt L1–L4) and 23 placeholder coordinates. Catalog: **65
instrument-records / 46 deployments**, 0 missing sub-products, 0 alignment
problems, 50/50 registry entries building. Server sync in progress at the time
of writing.

### Broken — dead paths with identifiable successors

`docs/mean_flow_validation_plan.md` names six validation scripts that have
moved or been renamed. The doc is a May 2026 plan and still reads as live
guidance, so a future session following it would hit six dead ends.

| line | reference | successor |
|---|---|---|
| :120 | `validation/test1_Hs2_scaling.m` | `validation/_retired/test1_Hs2_scaling.m` |
| :568 | `validation/test1b_robustness_checks.m` | `validation/_retired/…` |
| :604 | `validation/test1c_wave_direction_check.m` | `validation/_retired/…` |
| :124 | `validation/check_vector_range_settings.m` | `validation/check_all_vector_ranges.m` |
| :690 | `validation/run_phase2_all_hourly.m` | `validation/run_phase2_all_deployments.m` (renamed in `c453725`) |
| :436 | `validation/reprocess_all_hourly.m` | deleted in `c453725`, **no direct successor** |

**RESOLVED 2026-07-28.** All five repointed. The sixth
(`reprocess_all_hourly.m`) is annotated in place rather than rewritten — the
statement that the run used it is true history; it simply no longer exists,
because re-processing to 1 hour is now just `PUV_L2_run_all`.

17-min segments are retired, so the two scripts that existed only to run the
1-hour case alongside them (`run_phase2_all_hourly.m`,
`reprocess_all_hourly.m`) are struck through with their removing commit cited,
and `run_phase2_all_deployments.m` is no longer labelled "(17-min)" — it reads
whatever `outputs/L2` holds, which is 1-hour.
**The 17-min references in the results prose were left alone**: that section is
the record of the 17-min vs 1-hour comparison itself, and rewriting it would
destroy the finding. `compare_seglen_phase2.m` survives but is flagged as
needing the frozen `Processed_HLB_17min/` archive, since it cannot run against
the current `outputs/L2`.

### Stale — built PDFs behind their source

| PDF | built | source | gap |
|---|---|---|---|
| `docs/puv_pipeline_slides.pdf` | 04-30 | 07-27 | **~3 months** — RESOLVED, see below |
| `docs/multitaper_writeup.pdf` | 04-30 | 07-10 | ~2.3 months |
| `docs/compile_sections.pdf` | 05-05 | 07-10 | ~2 months |

**RESOLVED 2026-07-28 (slides).** The deck did not merely need rebuilding — **it
did not compile.** The 2026-07-27 edit introduced `\num{}` at l.1125/1137
without adding `\usepackage{siunitx}`, so every build since had failed with
"Undefined control sequence" and no PDF. A stale build artifact can mean a
broken source, not just a forgotten rebuild; check that it *builds* before
assuming it is merely old.

A second defect surfaced once it compiled: l.1771 pointed at
`Paper_1/paper/figures/fig_forcing_response_v2.png`, which Paper_1 had moved
into `paper/figures/archive/`. It was silently rendering as a draft box.
Repointed to the same file's new location — **not** to
`fig_ssd_forcing_latest.png`, which is a different name of unverified content
and would be a guess.

PDFs are now date-stamped so history is kept:
`puv_pipeline_slides_2026-04-30.pdf` (archived) and
`puv_pipeline_slides_2026-07-28.pdf` (47 pages, clean build).

⚠️ **The rebuilt deck still carries the retracted spectral-peak-broadening
frames.** The source has had a `RETRACTED 2026-07-25` banner in its comments
since the resolution-artifact finding, but the banner is a LaTeX comment and so
does not appear in the PDF. Anyone opening the built deck sees the retracted
claims presented normally. Fix before showing it to anyone.

### Cruft — orphan docs

Nothing links to these and none has been touched in ~2–4 months. Archive
candidates, not deletions:
`docs/multitaper_notes.md` (04-09), `docs/email_body_to_bill.md` (05-06),
`docs/meeting_walkthrough/walkthrough.md` (05-07).

The dated `RESULTS_*.md` files are also unreferenced but are **protected
historical run logs** per `CLAUDE.md` — leave them.

### Checked and clean (recorded so the next audit need not re-derive)

- **Record counts agree** across `CLAUDE.md`, `PIPELINE_NOTES.md`,
  `docs/deployment_database_overview.md` and this file: 65/46 everywhere.
- **All `\includegraphics` resolve** once `\graphicspath` is honoured
  (`../outputs/validation/`, `../outputs/L1/diagnostics/`). An earlier pass that
  ignored `\graphicspath` reported 32 false missing figures.
- **All cross-repo links resolve** — `Paper_2/docs/`, `Altimeter_Pipeline/docs/`,
  `PUV_paper/docs/`, `../server_io_patterns.md`.
- **No near-duplicate script families** (`*_v2`, `*_final`).
- `parse_hdr` is a **local function** inside `validation/check_all_vector_ranges.m`,
  not a missing file. `config/HIREEF25_config.m` is an illustrative example in
  `NEW_DEPLOYMENT.md`; `config/TOR23S_config.m` is a planned file in an unchecked
  TODO. All three are false positives — noted so they are not re-flagged.

### Resolved since 2026-07-24

- `RUBY22` lat/lon, the last **declared placeholder** in the provenance lint,
  is now sourced. Lint moved 33/1/82 → **47 sourced / 0 placeholders / 69
  unannotated**.
- `TOR18A` was registered and fully processed but omitted from
  `TorreyOffshore_config`'s `clockOffsetMap`; the config threw and every
  registry loop swallowed it via `catch, continue`. Caught by a count mismatch
  (64 inspected vs 65 L4 files on disk). New guard:
  `validation/audit_registry_loads.m`.

### Still open (carried forward)

- `IB18W`/`IB19S` `doffp` — configs say 0.66/0.62, the 2018-19 log says 70/73 cm,
  neither config value appears in the notes. Source unknown; 4 records.
- 69 geometry values still lack on-line provenance.
- `TOR25S/MOP586_5m` `doffp` quoted to the altimeter face rather than the
  pressure port.

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
