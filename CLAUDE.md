# CLAUDE.md — PUV_Pipeline

Nortek Vector PUV processing pipeline: raw instrument files → QC'd timeseries →
spectra → wave forcing → IG / nonlinear diagnostics. Public repo
(`github.com/holdenlesliebole/Nortek_Vector_PUV_Pipeline`), so it is written to be
site-agnostic — everything site-specific lives in one config file per deployment.

Parent context: `../CLAUDE.md` (Scripps research root). This file governs work
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

---

## Current state (2026-07-27)

- **Catalog:** 65 instrument-records across 46 deployments, at every level
  L1–L4; 9 deployments also have `L4_xspec` (the multi-instrument ones).
- **Canonical processed copy:** `/Volumes/group/PUV_data/Vector/Processed_HLB/`,
  laid out `<DEPLOYMENT>/Level{1,2,3,4}_QC/<label>_*.mat`, with `manifest.csv`
  and a generated `README.md`. Push with `scripts/copy_to_server.m` (idempotent,
  size+mtime skip; it also regenerates the manifest and README, and now refuses
  to push deployments that are not in the registry).
- **Levels L1–L4 are complete and verified**, re-verified 2026-07-26 after the
  L4 repair below. L5 (PUV↔altimeter merge) is planned, not built.
- **L4 repair, 2026-07-26.** An audit found `bispectra` missing on 23 of 65
  records and 3 records whose L4 sat one index off the current L2. Both had the
  same cause — **L4 built against a superseded L2 snapshot**, not a module bug.
  All 26 were rebuilt/backfilled (4.15 h, 0 failures) and
  `validation/audit_L4_coverage.m` now reports every record complete and
  time-aligned. Also regenerated L3 for 11 records whose L3 predated their L2
  (TBR23 ×4, TOR23W ×6, SIO24A). Details in `docs/todo.md`.
- **Local `outputs/` is a superset of the catalog.** `TOR20A/MOP591_9m` has L2
  and L3 on disk but is deliberately unregistered. Enumerate records via
  `deployment_registry()`, not by globbing `outputs/L*/*/`.
- **Site geometry, 2026-07-27.** `doffp` placeholders were resolved from the
  field logs on 9 records (RUBY22 ×3, Cardiff ×2, Coronado ×2, Catalina ×2) and
  propagated through L2→L4. **Three config headers claimed the data was not
  recorded; all three were wrong** — see `config/DOFFP_LOOKUP_CHECKLIST.md` for
  where to look and how to match. Catalina also had a **21.9 km lat/lon error**
  and unset serial/`depth_nominal`. Still carried rather than sourced:
  `TorreyOffshore` 0.63 m, real but copied back across 2014–2019.
- **A config comment does not age with the value it describes.** Run
  `validation/audit_config_provenance.m` — it classifies each `doffp`/`latlon`/
  `shorenormal` assignment from *its own trailing comment* (sourced /
  declared-placeholder / unannotated). **Put the source on the line, not in the
  header.** Current state: 33 sourced, 1 declared placeholder
  (`RUBY22` lat/lon, still "approximate" though the exact coordinates are in the
  same workbook row its `doffp` came from), 82 unannotated.
- **Catalina shore-normal is data-derived, not surveyed.** `CAT21A`/`CAT21B` are
  outside CDIP MOP coverage, so there is no station to look the angle up from.
  `shorenormal = 90` (offshore, due east) was estimated from the wave principal
  axis (`a2`/`b2` → 92.7°), corroborated by the wave mean direction (107°) and
  the mean-current principal axis (62.5°, anisotropy 3.12). **Uncertainty is
  ±20°** — the four estimators span 77°, and a 20° error mixes 34 % of the
  alongshore component into the cross-shore one. Treat CAT cross-shore
  quantities as indicative, not quantitative. Full reasoning in
  `CAT21A_config.m`.
- **Pre-2023 archive: Tiers A, B, and C are all done** (2026-07-24), decoded from
  raw `.VEC` — 23 new deployments back to 2014. Tier A = `TOR19W`/`TOR20W`/`IB19W`;
  Tier B = `TOR15A/B`, `TOR16B`, `TOR17D`, `CDF15A/C`, `COR16B/D`; Tier C = the
  Torrey/Los-Peñasquitos-mouth offshore station (`TOR14A`…`TOR19A`). **Two held
  out** with the reasons documented: `TOR20A` (sequence-counter filenames, timing
  unvalidatable) and the 2023 LPL dye (surfzone/intertidal, unsuitable). Full
  account: `docs/recopied_data_backlog.md`.

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
`../CLAUDE.md`.

**L2 segments are 1 hour** (`segLen = 7200` @ 2 Hz), switched from 17 min in
May 2026. The legacy 17-min archive lives at `Processed_HLB_17min/` and exists
only to reproduce the May 2026 mean-flow validation.

**`doffp` is required and it matters.** Pressure-sensor height above the bed, in
metres, from the field log — for San Diego, `/Volumes/group/DeploymentNotes/`.
L2 uses a single fixed value per deployment, so records where the bed moved a lot
carry extra uncertainty (see IB19W). Also set `cfg.qcOpts.Tvalid` to the site's
water-temperature range; the `[-2 40]` default is a wide safety bound, not a
good site value.

**`TBR23` vs `TOR23S`.** `TBR23` breaks the `SITE+year+season` convention but is
kept because Paper_1 depends on the name. `TOR23S` is a registry alias to the
same config; `cfg.name` stays `'TBR23'`. A full rename is a coordinated
cross-repo cleanup — see `docs/todo.md`.

---

## Working rules

- **All code is MATLAB.** Run with
  `/Applications/MATLAB_R2025a.app/bin/matlab -nodisplay -nosplash -nodesktop -batch "startup_puv; …"`.
  `startup_puv` puts the whole repo on the path.
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
