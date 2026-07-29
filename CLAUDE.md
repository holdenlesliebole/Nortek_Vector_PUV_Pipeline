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

**Don't trust this file for state — check it.** `docs/todo.md` is gitignored, so
a fresh clone has no live tracker, and prose goes stale. Four audits reconstruct
the truth in a few minutes, and each has caught something no other check did:

| audit | answers |
|---|---|
| `validation/audit_registry_loads.m` | do all configs build, and does any output on disk belong to none of them? **Run this first** — a config that throws is invisible to every other audit |
| `validation/audit_L4_coverage.m` | are all 65 records complete and time-aligned to their L2? |
| `scripts/audit_clock_lag.m` | is every filename-clocked record at lag 0 against the tidal reference? (needs a current L3) |
| `validation/audit_config_provenance.m` | which `doffp`/`latlon`/`shorenormal` values cite a source on their own line? |

If a count in any doc disagrees with what these report, **the audit is right**.

---

## Current state (2026-07-28)

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
  header.** Current state (2026-07-28): 47 sourced, 0 declared placeholders,
  69 unannotated — up from 33/1/82 after the coordinate sweep below.
- **Coordinates were the next thing the placeholders hid, 2026-07-28.** A sweep
  of every `latlon` by *decimal precision* found 17 records at 3 dp (~111 m) and
  one at 2 dp. Checked against `/Volumes/group/DeploymentNotes/*.xls` sheet
  `'All Data'` (which carries GPS-surveyed NAD83 fixes, `doffp`, heading and
  clock drift), **23 records were wrong**: `RUBY22` ×3 by up to **925 m**, `LPL`
  ×4 by 453 m, `SIO_Pier` ×5 by 164 m, and the `TOR24S`/`TOR24W`/`TOR25S`
  MOP586 ladder by 47–98 m. All corrected from the survey; `TorreyOffshore` and
  `LPL` turn out to be the **same station** (32.934436, −117.26546) and only
  TorreyOffshore had it right.
  **This is not cosmetic: `PUV_L4_xspec.m:205` derives pair separations from
  `LATLON`.** MOP586 7m–10m was 93 m against a surveyed 143 m (**−35%**), and
  RUBY22 pairs were 42–50% too long. `L4_xspec` was rebuilt for the four
  affected deployments. The per-pair coherences did **not** move — the
  measurement was always right, only the distance attached to it was wrong, so
  any coherence- or phase-versus-separation result needs redoing and nothing
  else does. Verified three ways: serial numbers matching the log exactly
  (`12414`/`16310`/`16737` for RUBY22), the same fixes appearing in two
  independent seasons, and a Dean-profile consistency test scored against
  `TOR23W` as a known-good control (surveyed 1.13 vs rounded 1.82).
  Beware the obvious test that fails: scoring coordinates by how *constant* the
  implied slope is picks the WRONG set, because hand-drawn placeholders are
  evenly spaced and a real profile is concave. Use `separation / Δh^1.5`.
- **Verified clean by the same sweep**, digit for digit against the logs, so
  they need no further checking: `TBR23` ×4, `TOR23W` ×6, `SOL23` ×3,
  `TOR19W`, `TOR20W`, `IB19W`, `CAT21A/B`. Still open: `IB18W`/`IB19S` carry
  `doffp` 0.66/0.62 where the 2018-19 log says 70/73 cm, and neither config
  value appears anywhere in the notes — source unknown, do not guess.
- **Catalina shore-normal: `63°`, and prefer CURRENTS over waves when refraction
  is weak.** `CAT21A`/`CAT21B` are outside CDIP MOP coverage. Four independent
  estimators agree within 6°: imagery of the beach in front of the PUV (63°), the
  mean-current principal axis (62.5°, anisotropy 3.12), and a GPS survey taken
  *during* the deployment (`LiDAR/Mele/Catalina_GPS/20210525_CATALINA_RBR.txt`,
  57.7–61.5°). **The wave principal axis (92.7°) is the outlier and an earlier
  revision wrongly trusted it, applying 90°.** Refraction does not align waves
  with the normal at a sheltered leeward embayment fed by long-period swell
  (median Tp 16.4 s, 52° spread). The coast is embayed — the surveyed trend
  swings 151.5°→137.1° over 460 m — so one angle is a compromise; ±8°.
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
mid-deployment rows are often labelled only **"Redeploy"** with no site name, and
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
`../CLAUDE.md`.

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
metres, from the field log — for San Diego, `/Volumes/group/DeploymentNotes/`.
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
`doffp` uncertainty as serious for **depth-normalised** quantities (`Hs/h`,
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
