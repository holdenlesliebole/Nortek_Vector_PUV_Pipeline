# PUV Pipeline — Audit Log

Consistency/staleness audits of the docs, LaTeX, config, and scripts against
the code and the server catalog. Newest entry first; prior entries are kept as
history (findings marked resolved when fixed, so recurring drift is visible).

---

## 2026-08-13 — sediment modules (settling velocity, Rouse)

Audit of the sediment-transport helpers, prompted by a question about whether
fines can stay suspended long enough to be advected offshore. Five defects, four
fixed. Science context and the resulting depth analysis:
`Paper_2/docs/suspension_regime_by_depth_2026-08-13.md`.

### Broken — wrong formula, shadowing the correct one

`Paper_1/DataCodes/PUV/settling_velocity.m` omitted the `sqrt` in the
Ferguson & Church (2004) eq. 4 denominator:

```
wrong:  ws = R g D^2 / (C1*nu + 0.75*C2*R*g*D^3)
right:  ws = R g D^2 / (C1*nu + sqrt(0.75*C2*R*g*D^3))
```

Without the `sqrt` the D³ term is ~1e-10 against `C1*nu` ~ 1.8e-5, so the
expression collapses to Stokes' law. Overestimates ws for sand by 20–47% over
139–247 µm (**0.0523 vs 0.0358 m/s at D50 = 246 µm**).

This file **shadowed** `PUV_Pipeline/shared/settling_velocity.m` on the saved
MATLAB path, so a bare session resolved to the buggy copy. The shadowing came
from persistent user path state, not from code, so it would not reproduce on
another machine.

**RESOLVED 2026-08-13.** `sqrt` restored, file annotated as a duplicate that
must track the canonical one.

**Paper 1 is unaffected.** Path simulation confirms every manuscript-critical
entry point prepends `PUV_Pipeline/shared` and resolved to the correct value:

| entry point | ws(246 µm) | resolved to |
|---|---|---|
| `fig10_ur_and_depth` | 0.03574 | shared ✓ |
| `figS_transport_4puv` | 0.03574 | shared ✓ |
| `fig_transport_attribution` | 0.03574 | shared ✓ |
| `bailard_split_s3plus` | 0.03574 | shared ✓ |
| `compute_table7_all_puvs` | 0.03574 | shared ✓ |
| bare session, no `addpath` | 0.05229 | **buggy shadow** |

### Wrong input — Rouse driven by the oscillatory wave stress

`L3_forcing/PUV_L3_transport.m:103` passes `L2.tau_b`, the wave stress
amplitude `0.5*rho*f_w*U_bed^2`, into a Rouse number. The Rouse profile assumes
a steady boundary layer with diffusivity `kappa*u_star*z` over the water column;
the wave boundary layer is a few cm thick, and an amplitude is not a mean. Both
errors inflate `u_star`, so the result **overstates suspension**.

Because the bias runs toward suspension, the existing conclusion "Rouse number:
bedload-dominated across all sites" (`docs/puv_pipeline_slides.tex:1574`) is
**conservative and survives the correction**.

**RESOLVED 2026-08-13, fully.** New `shared/wave_current_stress.m` implements the
Soulsby (1997) mean/max combined stress; `shared/rouse_number.m` states which
stress belongs where (entrainment → `tau_max`; suspension → Rouse from `tau_m`;
advection → mean current); and `PUV_L3_transport.m` was rewired to use them.

`L3.rouse` now derives from `tau_m`. `L3.rouse_legacy` keeps the superseded
value, and `L3.tau_c` / `tau_m` / `tau_max` are new outputs.

**Regenerated** with `scripts/regen_L3_rouse_2026_08_13.m`: 65 of 66 files
rebuilt, 1 skipped (unregistered `TOR20A`), 0 failures. Backups in
`outputs/_pre_rouse_backup_2026-08-13/`.

**The regen was proven purely additive before it ran.** Across all 66 files,
every field any downstream code consumes reproduced exactly:

| field | worst relative difference |
|---|---|
| `Fb`, `Fb_cum`, `shields`, `mobilized` | 0.000e+00 |
| `tau_b`, `Ub`, `uMean`, `vMean` | 0.000e+00 |

So **nothing downstream needs re-running**, and no published or in-review number
moves. The correction is large where it applies (median Rouse 40.6 against a
legacy 7.4 at MOP580 5 m, larger in 100% of segments) but it lands entirely on a
field nothing read.

Worth noting as corroboration: the corrected Rouse falls monotonically with depth
across the Torrey deployments (TOR23W: 41.5 at 5 m, 23.0/19.5 at 7 m, 13.7 at
10 m, 9.7 at 15 m; same pattern in TOR24W and TOR25S). Lower Rouse means more
readily suspended, which is the independent depth trend derived from the measured
grain-size transect in
`Paper_2/docs/suspension_regime_by_depth_2026-08-13.md`.

### Blind to selective transport — single-D50 Rouse

Rouse was evaluated at D50 only, which cannot represent preferential export of
the fine fraction. Measured at Torrey, D16 suspends at 0.20–0.29× the stress D50
needs, and below ~8 m the fine tail is suspended at stresses too low to move the
median grain. **RESOLVED 2026-08-13** — `rouse_number` now broadcasts a column of
per-fraction `ws` against a row of stresses.

### Wrong constant, deliberately left in place

`shared/settling_velocity.m` used `C2 = 0.4`, Ferguson & Church's **smooth
sphere** value; natural sand is `C2 = 1.0`. The error is grain-size dependent
(18% at 247 µm, 9.5% at 139 µm), so it distorts cross-shore comparisons as well
as absolute values.

**NOT changed.** `ws` enters Bailard `q_s` inversely and feeds
`run_transport_model.m` and `compute_table7_all_puvs.m`, whose numbers are in
coauthor revision. Now an explicit `'shape'` / `'C2'` option with the **default
preserved at 0.4**. Adopting 1.0 requires re-running both and reconciling Table 7.

### Docstring error

`rouse_number` labelled `P > 7.5` as "no motion". Rouse says nothing about
whether the bed moves, only whether it suspends; motion is set by `tau` against
a critical Shields stress. **RESOLVED** — now "no suspension (bedload only, if
mobilised at all)".

### De-duplicated

`PUV_L3_transport.m` inlined the Soulsby & Whitehouse `theta_cr` expression at
`:74-75` rather than calling `soulsby_whitehouse_theta_cr.m`. The inline was
**numerically identical** (0 relative difference over D50 = 100-500 µm), so this
was a maintainability risk, not a correctness one. Now calls the helper.
The inlined Rouse calc at `:110-114` likewise now calls `rouse_number`.

### Verified clean — Paper 1 Bailard

`run_transport_model.m:214` computes `W_s` via `settling_velocity`, and Bailard
suspended load scales as `1/ws`, so the shadow bug would have understated `q_s`
by 32-53% across the D50 sweep. Checked empirically by running the model under
the manuscript path setup: it resolves to `PUV_Pipeline/shared` and reports
`W_s = 0.0354 / 0.0577 / 0.0797 m/s` at D50 = 0.25 / 0.35 / 0.45 mm, which is
the correct branch (the buggy formula gives ~0.054 at 0.25 mm). **Paper 1's
transport moments are sound.**

### Pushed to reefbreak

`scripts/copy_to_server.m` run 2026-08-13: 269 files, 46 deployments, 101.6 GB
inventoried, `manifest.csv` and `README.md` rewritten. **65 of 66 L3 files now
match the server byte-for-byte**; the one exception is the unregistered
`TOR20A/MOP591_9m_L3.mat`, held out of the catalog on purpose and never
regenerated locally either.

Server copy verified by content, not just size:
`code_version = PUV_L3_transport/2026-08-13`, `rouse_legacy` absent, `tau_c` /
`tau_m` / `tau_max` present, median Rouse 41.46 (was 4.83), median Shields
unchanged.

Note the full sweep is slow (~20 min, I/O bound) because it stat-checks 44 GB of
L1/L2 and 55 GB of L4 over SMB to reach 40 MB of changed L3. Everything else
skipped as already synced.

### The `rouse_legacy` removal, and a trap it exposed

`rouse_legacy` was briefly added alongside the corrected field, then removed:
carrying a knowingly-wrong Rouse number beside the right one is a trap for anyone
reading L3 later.

**Dropping the assignment was not enough.** `PUV_L3_transport` APPENDS to the L3
struct it is handed, so a field that is merely no longer written survives from
whatever produced the file before, and all 65 regenerated files still carried it.
The function now holds an explicit `RETIRED` list that `rmfield`s retired names,
so it self-cleans any older L3 passed through it. Verified 0/66.

`regen_L3_rouse_2026_08_13.m` was also guarded against overwriting its own
backups, since a second run would otherwise replace the true pre-change files
with already-regenerated ones and destroy the only rollback point. Backups
confirmed genuinely pre-change (median Rouse 4.83, no `tau_m`).

### Open

- `TOR20A/MOP591_9m_L3.mat` is unregistered. Confirm whether that is intended or
  a registry gap.
- Four Paper 1 audit scripts hardcode `ws = 0.025` citing a D50 of 0.20 mm that
  `CLAUDE.md` has since superseded: `apply_ci_load_bearing.m:28`,
  `band_filtered_attribution.m:40`, `audit_band_cutoff_sensitivity.m:32`,
  `audit_crossband_validity.m:44`. These are audit/sensitivity scripts, not
  manuscript-number producers, so the exposure is low.
- `settling_velocity` default `C2` remains 0.4 (smooth spheres) rather than the
  natural-grain 1.0, frozen for Paper 1 compatibility. Revisit after the
  manuscript clears review.

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

**RESOLVED 2026-07-28 (science).** The retracted frames are rewritten in place
rather than left behind a comment-only warning — a LaTeX comment never reaches
the PDF, so the built deck had carried the retracted claims with no visible
caveat. The April PDF was deleted (the `.tex` history is in git if that state is
ever needed).

Corrections applied, sourced from
`PUV_paper/docs/findings_resolution_artifact_2026-07-24.md` and
`findings_hypothesis_elimination_2026-07-27.md`:

- H4 frame and Peakedness Diagnostic marked **RETRACTED on the slide itself**,
  carrying the 1.225 self-comparison artifact and the matched-grid `Q_p` ratio
  **1.008** (62/65 records, p = 0.44).
- Cross-Deployment frame rewritten around what survives: `ν` ratio 1.060
  (p = 4.6e-9), peak density 1.064 (p = 8.6e-11), and the depth trend
  ρ(ν, h) = −0.42 at a **fixed 0.18 Hz** band limit — the control that rules out
  `fCut` tracking depth at ρ = −0.998.
- Key Findings and the ledger notes now name **nonlinear shoaling (H1)** as the
  mechanism, per the elimination redone over 72,948 h / 61 records. H1 had been
  ruled out in favour of the artifact, so the whole elimination had to be redone.
- Future-work frame: the wave-dynamics paper's subject changed with the result.

**One thing worth carrying forward:** the old slide argued the finding was
robust *because* it reproduced across 11 instruments. That was the trap — a
biased estimator reproduces everywhere. Breadth of reproduction is not evidence
when the bias is in the metric.

Also fixed: `siunitx` had been **deliberately removed** in `4b834a8`
("remove siunitx/metropolis dependencies"), and the 07-27 edit reintroduced
`\num{}` without it. Rather than re-add the dependency, the two uses are written
longhand, honouring the earlier decision.

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
