# CLAUDE.md — PUV_Pipeline

Nortek Vector PUV processing pipeline: raw instrument files → QC'd timeseries →
spectra → wave forcing → IG / nonlinear diagnostics. Public repo
(`github.com/holdenlesliebole/Nortek_Vector_PUV_Pipeline`), so it is written to be
site-agnostic — everything site-specific lives in one config file per deployment.

Parent context: `../AGENTS.md` (Scripps research root; shared by Claude and
Codex). This file governs work
*inside* `PUV_Pipeline/`.

---

## Session startup — read these first

1. **`docs/todo.md`** — the live tracker. Its top block is the current state.
   *(Local-only: gitignored, so it is absent in a fresh clone.)*
2. **`docs/pipeline_levels.md`** — per-level status, counts, what is verified vs
   deferred. **Authoritative on status** if it disagrees with `PIPELINE_NOTES.md`.
3. **`PIPELINE_NOTES.md`** — design rationale behind the QC and processing
   choices. Explains *why*, not *what is done*.
4. **`README.md`** — user-facing entry point: requirements, quick start, how to
   configure a deployment.
5. **`config/deployment_registry.m`** — the definitive list of known deployments.

**Not current — do not read as status:** the dated `docs/RESULTS_*.md` and
`docs/*_2026-07-09.md` files are historical run logs. They record what was
actually run at the time and are kept deliberately; never "correct" them.
Likewise `outputs/_*_backup_*/` and `outputs/rerun_*/` are frozen snapshots.

**Don't trust this file for state — check it.** `docs/todo.md` is gitignored, so
a fresh clone has no live tracker, and prose goes stale. Five audits reconstruct
the truth in a few minutes, and each has caught something no other check did:

| audit | answers |
|---|---|
| `validation/audit_registry_loads.m` | do all configs build, and does any output on disk belong to none of them? **Run this first** — a config that throws is invisible to every other audit |
| `validation/audit_L4_coverage.m` | are all 65 records complete and time-aligned to their L2? |
| `scripts/audit_clock_lag.m` | is every filename-clocked record at lag 0 against the tidal reference? (needs a current L3) |
| `validation/audit_config_provenance.m` | which `doffp`/`latlon`/`shorenormal` values cite a source on their own line? |
| `validation/audit_L1_qcopts.m` | would rebuilding each L1 from its config reproduce the `qc.opts` stored in it? (loads all L1, several minutes) |

If a count in any doc disagrees with what these report, **the audit is right**.

---

## Current state (2026-10-14)

Detail and open items: the top block of `docs/todo.md`. Code changes:
`CHANGELOG.md`. Catalog changes: `docs/catalog_changes/`.

- **Catalog 2026-10-14.1 is on the server** (`/Volumes/group/PUV_data/Vector/Processed_HLB/`,
  pushed and verified 2026-10-14: 269/269 files at equal size, manifest sha256
  269/269, sidecars 269/269). 65 records / 46 deployments; 9 have `L4_xspec`.
- **One code version.** All 65 records rebuilt at L2-L4 on 2026-10-12/14, plus
  all 9 xspec, by `scripts/rerun_heading_ws_2026_10_07.m` stage `combined`
  under `scripts/run_L4_refresh_watchdog.sh`. L1 not rebuilt in that pass.
- **What the 2026-10 work fixed:** ENU declination (SOL24, LPL24, LPL25A);
  logged mount heading for 9 compass-drift records + SIO24A from `.VEC`;
  `Tvalid` in every config (was injected by the July reruns); 29 L4 files
  built from superseded L2s; edge-gap fills that extrapolated (L2-L4);
  settling velocity (F&C 2004 C1 20 / C2 1.1) and per-segment viscosity;
  seeded t_tide; NOAA tidal depth required (TOR24W/MOP586_10m had a silent
  fallback); provenance sidecars on every L2-L4/xspec file, L1 backfilled.
- **Audits 2026-10-14:** L1 qcopts 65/65, L4 content 65/65, registry 50/50.
- **The plain drivers stamp provenance** (since 2026-10-15,
  `shared/save_with_provenance.m`), same block and sidecar as the rerun script.
  A no-git checkout stamps `git_hash 'unknown (no git)'` (SOFT at push).
- **Known field failures are flagged in the configs** (`knownFailed`, 7
  instruments); drivers skip them and error only on new failures.
- **Tide station is per deployment** (`cfg.tideStation`; SD configs 9410230).
  `PUV_L3_currents` errors outside SD without one, on a failed NOAA download
  (unless `allowTtideFallback`) and without t_tide (unless `allowNoTides`).
  Catalina still uses 9410230 as built, pending Holden (Avalon 9410079 is the
  nearest harmonic station).
- **`check_prov` compares code by directory.** Any edit under a level's code
  folders (L3: `L3_forcing/`, `L3_transport/`, `shared/`) SOFT-refuses every
  file of that level at the next push until a change entry carries `code_ack`.
  The 2026-10-14/15 driver edits are acknowledged by the pending entry
  `docs/catalog_changes/2026-10-15_driver_provenance_tides.md`.
- **Open (do not guess):** IB18W/IB19S `doffp` source unknown; 69 geometry
  values unannotated (July count); 42 records on the 250 um placeholder D50;
  12 disputed headings (`shared/heading_disputed_records.m`); off-bed pressure
  QC off until the next L1 rebuild; IB19S/MOP045_7m 2019-04-22 19:30 IG
  anomaly; `get_k.m`/`xyRotate.m` still resolve from old
  `Beach_Change_Observation` folders on Holden's path (not called by repo code; L3
  needs them from the lab toolbox); October backups removed 2026-10-16 (manifests in `docs/archive_snapshot_manifests/`).
- **History still true (July 2026):** filename clocks are Pacific local
  (`clockOffsetHours`, all at lag 0); 23 hand-placed coordinates were corrected
  from the surveyed logs (only `PUV_L4_xspec.m` separations used them);
  Catalina shore-normal 63 deg from currents and survey, not the wave axis;
  `TorreyOffshore` and `LPL` are the same station; the 17-min archive was
  deleted 2026-07-28 (manifest in `docs/`).

---

## Durable decisions a new session must know

**Two ingest paths, and the ASCII one can lie.** L1 reads either the Nortek
ExploreV ASCII export (`.dat`/`.sen`/`.hdr`) or the raw recorder binary
(`.VEC`/`.vec`/`.049`) via `L1_raw_to_qc/read_VEC.m`. ExploreV is *not* required.
Auto-detection prefers ASCII when a `.dat` exists, which is wrong when an export
was interrupted — `TORREY02_1.dat` holds 5.1 days of a 174-day record. Set
`instr.rawFormat = 'VEC'` to force the binary; a warning fires whenever both
forms are present. Sampling rate and coordinate system come from the binary's
User Configuration record, so a 0-byte `.hdr` is not fatal.

**One burst per raw file.** Both ingest paths treat each `_N` recorder file as a
separate burst. Do not concatenate them: L1's battery-cutoff rule truncates the
record at the first gap over a second, and the 100 MiB split seams can lose a
second, which silently discards months of good data.

**Firmware-1.21 archive quirks (all handled; see `read_VEC.m` /
`vec_clock_from_filenames.m`).** The pre-2019 instruments report 8 Hz in their
config but are actually 2 Hz — `read_VEC` measures the rate from the records.
Their clock runs from a wrong epoch (2000/2002); recover it with
`instr.clockSource='filename'` + `deployYear` (from the `MMDDHHMM` filenames),
or `clockSource='fixed'` + `deployStart` when the filenames aren't wall-clock.
`instr.decimateTo` decimates a genuine high-rate (8 Hz) record to 2 Hz. Set
`cfg.qcOpts.cutoffGapSec=60` for these (benign per-file hiccups). The "8 Hz +
dead RTC" framing in older notes was wrong on both counts.

**The recovered filename clock is Pacific LOCAL time — add `clockOffsetHours`
to reach UTC (2026-07-28).** `vec_clock_from_filenames.m` recovers what the
recorder was *set* to and says in its own header that it cannot tell whether
that was UTC or local; that check was never run until now. Cross-correlating
L2 depth against the NOAA-referenced `L3.tidal.depth_pred` put **every**
`clockSource='filename'` record at R ≈ −0.55 at lag 0 and 0.92–0.999 at −8 h.
It is a **fixed offset, not a timezone conversion**: `TOR15D`, `TOR16D`,
`TOR17D` and `COR17D` sit entirely in daylight time and still want 8 h, and
`CDF15C` spans the 2016-03-13 DST change without a break — the recorders were
set to PST and left there. 2014-15 is the exception at 7 h. All 18 records were
rebuilt L1→L4 (the offset is baked in at L1) and re-audited to lag 0 with
`scripts/audit_clock_lag.m`. `TOR14A` has 45 valid segments and cannot be
validated; it takes +7 from its season-mates — flag it if it ever matters.
**Get the sign by derivation, not by trial.** With data `D(t)=W(t+δ)` and
prediction `P(t)=W(t)`, rolling P by L matches when `L=−δ`, so a measured lag
of −8 means the labels are slow and 8 h must be **added**. Applying −8 makes a
record twice as wrong and still "validates" against a lag scan.

**A config that throws is invisible, not loud.** Every batch driver and audit
walks `deployment_registry()` inside `try ... catch, continue`, so one broken
deployment cannot abort a multi-hour run — but a config that *errors* is then
indistinguishable from one that does not exist. `TOR18A` was omitted from
`TorreyOffshore_config`'s `clockOffsetMap` on 2026-07-27; the `containers.Map`
threw, and it vanished from the clock-fix rerun, from `audit_L4_coverage` (64
records against 65 L4 files on disk) and from the revision-risk sweep for a day,
while its outputs sat on disk looking complete. Its data was fine — measured
lag 0, R=0.997, so offset 0 was right — but nothing would have told us.
**Run `validation/audit_registry_loads.m` after touching any config**; it is the
one audit that does not swallow errors, and it also lists outputs on disk that
no registry entry claims. When adding a per-deployment `containers.Map`, every
deployment must appear in it — there is no benign default.
**A count that disagrees with the file system is a symptom, not a rounding.**

**Every config assumption that has been checked was wrong. Assume the next one
is too.** This is not a figure of speech — it is the July 2026 tally, six for
six:

| assumption in the config | reality |
|---|---|
| Cardiff: "`doffp` was not recorded" | recorded, per deployment |
| Coronado: "`doffp` was not recorded" | recorded — and the two deployments genuinely differ (0.58 / 0.72), so the single "program-typical" 0.65 was wrong in *both* directions |
| Catalina: "`doffp` was not recorded" | recorded; the same file also had a **21.9 km** lat/lon error and unset serial |
| TorreyOffshore: one `doffp` for 2014–2019 | recorded per deployment, spanning 0.38–0.76 |
| Filename clock is UTC | Pacific **local**; 19 records 7–8 h out |
| Coordinates are surveyed | 23 were hand-placed, up to **925 m** out |

**The mechanism is always the same.** The value was inferred once during initial
setup, the inference was written down as fact — often in the *file header*
rather than on the line — and nothing ever went back to the field log. A header
note does not age with the value it describes, and a plausible number attracts
no suspicion. None of these were found by the pipeline failing; every one was
found by someone going and reading the source document.

**So:** treat an **unannotated value as unverified**, not as fine. Put the source
on the line — deployment name, workbook, sheet, and the row's own wording — so
the next reader can check it in one grep. Match on **serial number**, which is
unambiguous, rather than on site and depth. Before trusting any inherited
geometry, open `/Volumes/group/DeploymentNotes/*.xls` and look;
`config/DOFFP_LOOKUP_CHECKLIST.md` says where. Two search traps live there:
mid-deployment rows are often labeled only **"Redeploy"** with no site name, and
a `doffp` may be quoted to the **altimeter face** rather than the pressure port.

**The cheap detector: sort by precision.** A surveyed GPS fix is 5–7 decimal
places (≈1 m); anything at 3 dp is ≈111 m and was placed by hand. That single
sort found 17 wrong records that no other check had flagged.
**69 values still carry no on-line source** — that is the size of the remaining
exposure, not a clean bill of health.

**The pipeline is standalone through L4.** L1–L4 must run without any altimeter
data. Coupling to the altimeter pipeline happens only at L5.

**Higher levels are snapshots of L2, so never index L4 by an L2 index.** L3 and
L4 are built at `numel(L2.time)` *as L2 stood at build time*. An L1/L2 rerun can
change the segment grid — the 2026-07-10/11 channel-decoupling rerun's new
trim/anchor gained a leading segment on 3 records, which offset their whole L4 by
one. Two traps follow. **Equal counts do not prove alignment** (a grid can gain
one at the start and lose one at the end), and **MATLAB silently accepts a
logical mask shorter than the array it indexes**, so `L2.Hs_SS(L4mask)` returns
wrong-hour data with no error rather than crashing. Always match on `time` via
`shared/l4_l2_index_map.m`, which returns `info.identity` so callers can assert.
`validation/audit_L4_coverage.m` checks the whole catalog for this.

**A stored diagnostic that nothing reads will not save you.** Z (pressure vs
velocity-predicted pressure) was computed per segment from 2026-06 and consumed
by nothing, so `RUBY22/MOP582_30m` sat in the catalog for months with a dead
pressure transducer — 6 mm median `Hs` at a 30.6 m open-coast site — invisible to
every other L2 QC test, while its median Z was 8.9e-05 against 0.85–1.04
everywhere else. Since 2026-07-27 it is a record-level flag
(`shared/ztest_record_flag.m`, stored at `L2.qc_record`, swept by
`validation/audit_ztest_records.m` with no rebuild needed). It is a **flag, not a
gate**: it marks the record and never drops segments. When using
`r(Z, depth)` as the regression guard on the 2026-06-05 formula fix, **exclude
flagged records** — that one dead record drags r from −0.015 to −0.78 by itself
and reads exactly like the bug returning.

**After any L1/L2 rerun, rebuild L3/L4 or record why not.** The 2026-07-12
decision to leave L4 as-is was defensible and was re-verified on 2026-07-26
(velocity fields unchanged to ≤7e-3 m/s; `Hs` moved >10 cm on 16 of 50,289 valid
segments), but the same rerun left 11 records with an L3 older than its L2 for
two weeks. Check with `validation/audit_L4_coverage.m` and an mtime sweep of
L2-vs-L3/L4 before trusting a level after a rerun.

**Coordinates.** L1 outputs the buoy frame (+x **West**, +y **North**, +z Up).
L2 rotates to shore-normal (+x onshore, +y alongshore-north) from either
`instr.shorenormal` (manual, any site) or `instr.mopStation` (CDIP, California).
Site-wide conventions (cross-shore origin, MOP numbering, NAVD88 datums) are in
`../AGENTS.md`.

**L2 segments are 1 hour** (`segLen = 7200` @ 2 Hz), switched from 17 min in
May 2026. **The 17-min archive was deleted from the server 2026-07-28** (10 GB,
19 deployments, L2+L3 only). Its manifest and README are kept as a record of
what it held at `docs/archive_Processed_HLB_17min_{manifest.csv,README.md}`.
It was not a clean reference by the end: it held no L1 of its own and was
derived from an L1 that has since been superseded three times (channel
decoupling 07-10/11, `doffp` on 25 records 07-27, clock on 18 records 07-28), so
differencing new work against it would have mixed segment-length effects with
input corrections. The mean-flow results it supported are written out with
tables in `docs/mean_flow_validation_plan.md`, and the comparison itself is
re-runnable from the current L1 at both segment lengths — which is the better
test anyway. `validation/compare_seglen_phase2.m` will not run until someone
regenerates a 17-min L2.

**`doffp` is required and it matters.** Pressure-sensor height above the bed, in
meters, from the field log — for San Diego, `/Volumes/group/DeploymentNotes/`.
L2 uses a single fixed value per deployment, so records where the bed moved a lot
carry extra uncertainty (see IB19W). Also set `cfg.qcOpts.Tvalid` to the site's
water-temperature range; the `[-2 40]` default is a wide safety bound, not a
good site value.

**A PUV cannot measure its own `doffp`, and no residual trick recovers it.** The
pressure case is rigid on a jetted pipe, so `P/ρg = η_surface − z_sensor`; the
bed elevation never enters. When the bed scours, `doffp` changes because `z_bed`
moved while `z_sensor` did not, and the pressure record is *unchanged*.
Differencing measured depth against a tide gauge therefore returns a constant,
not the bed history — and it will look like a clean null result rather than a
failure. `RUBY22/MOP578_10m` came back flat (+1.7 ± 2.4 cm) against a logged
12 cm change; that flatness is the physics, not evidence about the bed. Nothing
on the instrument points down (co-deployed altimeters do, but that is L5).
What the residual *does* measure is whether the **mount** moved, which is a real
QC check — it is what tested the Catalina slumping hypothesis.
**The good news is that it mostly does not matter.** Measured on the
TorreyOffshore records where `doffp` was corrected by up to 25 cm: depth moves
one-for-one (≈3%), but `U_b` moves 0.10%, and `τ_b`/`shields` 0.27%, because the
bed-transfer term is `cosh(k·doffp)` and `k·doffp ≈ 0.04` at 9 m under swell, so
the correction is second-order. Worst realistic case (5 m, 6 s) is ≈0.9%. Treat
`doffp` uncertainty as serious for **depth-normalized** quantities (`Hs/h`,
Ursell) and negligible for bed stress and mobilisation.
Where a record needs time resolution, use the **measured** knots: the 2024-25
and 2025-26 logs record mid-deployment *inspection* values, not just endpoints
(Torrey 5m MOP586: 77 → 33 → 63 cm). Interpolating between measurements is
defensible; fitting a line between two endpoints is not.

**`TBR23` vs `TOR23S`.** `TBR23` breaks the `SITE+year+season` convention but is
kept because Paper_1 depends on the name. `TOR23S` is a registry alias to the
same config; `cfg.name` stays `'TBR23'`. A full rename is a coordinated
cross-repo cleanup — see `docs/todo.md`.

---

## Working rules

- **All code is MATLAB.** Run with
  `/Applications/MATLAB_R2025a.app/bin/matlab -nodisplay -nosplash -nodesktop -batch "startup_puv; …"`.
  `startup_puv` puts the whole repo on the path. **That command's exit code is
  0 even when the batch errors** (`-nodisplay` with `-batch` on R2025a/macOS,
  checked 2026-10-14); judge a run by its log, or drop `-nodisplay` when the
  exit code matters.
- **Tests:** `run_all_tests` (validation/run_all_tests.m) runs the 23
  self-contained tests and exits nonzero on a failure; `run_all_tests('includeData',
  true)` adds the read-only ones that need `outputs/`, the server or the network.
- **Batch over the catalog** with `PUV_L{1,2,3,4}_run_all` — each skips
  deployments that already have outputs, so adding one deployment is cheap. The
  single-deployment `PUV_L*_driver` scripts hardcode `deployment_name` at the top.
- **Copy raw to local first.** `copy_raw_to_local(cfg)` caches into `raw_cache/`
  (gitignored); reading multi-GB files over the SMB mount is far slower. Check
  the mount is up before any run — see `../server_io_patterns.md`.
- **Outputs are not versioned.** `outputs/` is gitignored; it is reproducible
  from raw + code, and the durable copy is on the server.
- **One-off session scripts stay untracked.** Scripts written to accomplish a
  single task do not belong in the repo.
- **Verify before claiming.** New or reprocessed records get a magnitude check
  (Hs, Tp, depth vs nominal, W≈0) and, where a CDIP MOP station exists, an Hs
  comparison against it. See `docs/recopied_data_backlog.md` for the Tier A
  numbers as a worked example.

> **`outputs/` is a symlink** to `~/LocalData/Scripps/Research/PUV_Pipeline/outputs` (outside iCloud sync, excluded from Time Machine; 2026-09-22). Paths resolve normally; the canonical copy is on reefbreak.
