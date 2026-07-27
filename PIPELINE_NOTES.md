# PUV Pipeline — Design Notes and Decisions

This document records the architectural decisions, known issues, and rationale
behind the pipeline design. Update it when decisions change.

For a getting-started guide aimed at new users, see `README.md`. For the
detailed, current level-by-level reference, see `docs/pipeline_levels.md`.

---

## Directory Structure

```
PUV_Pipeline/
    startup_puv.m              — adds all subdirs to MATLAB path; run first
    config/                    — per-deployment config functions + registry
    L1_raw_to_qc/              — raw .dat/.sen/.hdr → QC'd PUV struct (.mat)
    L2_spectral/               — spectral analysis, wave stats, bed velocity
    L3_forcing/                — band decomposition, storms, transport proxies, currents
    L3_transport/              — paper-specific transport model wrappers
    L4_ig/                     — nonlinear-wave + infragravity dynamics
    shared/                    — canonical copies of shared functions
    raw_cache/                 — local copies of raw server files (not committed)
    outputs/L1|L2|L3|L4/       — processed outputs per deployment (not committed)
```

Related directories:
- Raw data (read-only): `/Volumes/group/PUV_data/Vector/`
- Deployment notes: `/Volumes/group/DeploymentNotes/`
- Old first-gen code (archived): `Beach_Change_Observation/Vector/PUVs/`
- Paper 1 analysis: `Paper 1/DataCodes/`

---

## Pipeline Stages

### L1: Raw → QC'd timeseries
- **Input**: raw `.dat`/`.sen`/`.hdr` files from lab server
- **Script**: `PUV_L1_driver.m` (loops instruments) → `PUV_raw_process.m` (one instrument)
- **Processing**: load bursts, clock drift correction, pitch/roll/pressure QC,
  correlation QC (minCorr < 70%), rotate to buoy coords (+x WEST, +y NORTH, +z UP)
- **Output**: `outputs/L1/{deployment}/{label}_processed.mat` containing `PUV` struct

### L2: Spectral analysis
- **Input**: L1 `.mat` files
- **Script**: `PUV_L2_driver.m` → `PUV_L2_spectral.m`
- **Processing**: 1-hour (7200-sample @ 2 Hz) UTC-aligned segments, detrend,
  Wu pressure correction, multi-taper PSD (DPSS NW=4, K=7), Hs/Tp/energy flux,
  bed velocity (IFFT method), Reynolds stress, velocity moments, shore-normal
  rotation (cached for L4), optional MOP comparison
- **Output**: `outputs/L2/{deployment}/{label}_L2.mat` per instrument

### L3: Wave forcing characterization
- **Input**: L2 `.mat` files
- **Script**: `PUV_L3_driver.m` (modules: `PUV_L3_bands`, `PUV_L3_storms`,
  `PUV_L3_transport`, `PUV_L3_currents`)
- **Processing**:
  - **L3a band decomposition** — energy flux + Hs by band: F_ig, F_swell,
    F_sea, F_total per segment. Bands: IG [0.004–0.04], swell [0.04–0.10],
    sea [0.10–0.25] Hz; dominant-band flag per segment
  - **L3b storm/event detection** — storm events from Hs time series,
    event metrics, calm/recovery windows, MOP gap-filling
  - **L3c transport proxies** — bottom energy flux Fb, Shields/Rouse time
    series (configurable D50), mobilization fraction
  - **L3d current decomposition** — t_tide harmonic analysis on uMean/vMean,
    subtidal residual currents, undertow (validated vs NOAA Scripps gauge)
- **Output**: `outputs/L3/{deployment}/{label}_L3.mat` per instrument
- `L3_transport/` holds thin, paper-specific transport-model wrappers
  (`run_transport_model.m`: Bailard → Hoefel & Elgar → undertow → Shields);
  these stay paper-specific and are not part of the universal pipeline.

### L4: Nonlinear-wave / IG dynamics
- **Input**: L1 + L2 `.mat` files
- **Script**: `PUV_L4_driver.m` (modules: `PUV_L4_eta`, `PUV_L4_reflection`,
  `PUV_L4_bispectra`, `PUV_L4_moments`, `PUV_L4_velocity_pdf`,
  `PUV_L4_boundwave`; array cross-spectra via `PUV_L4_xspec_driver.m`)
- **Processing**: P → η in three bands; Sheremet incident/reflected IG split;
  bicoherence/skewness/asymmetry bispectra; frequency-resolved moment
  correlations; pooled velocity PDFs; bound/free IG separation
- **Output**: `outputs/L4/{deployment}/{label}_L4.mat` per instrument
- See `docs/pipeline_levels.md` for the full L4 output-struct shape.

### L5: PUV–altimeter integration (planned)
- Merges L2/L3 products with altimeter bed-level for bed-change vs forcing.
  Not yet implemented — see `docs/pipeline_levels.md` and `project_L5_plan`.

---

## Key Design Decisions

### Segment length: 1 hour (7200 samples @ 2 Hz), UTC-aligned
**Canonical L2 segmentation is 1-hour, non-overlapping, aligned to UTC
top-of-hour boundaries** (`opts.segLen = 7200`, the default in
`PUV_L2_spectral.m`). Hour alignment matches the MOP/CDIP reporting cadence,
which the validation and L4 cross-spectra modules rely on. Tidal signal is
removed by per-segment detrending, not by tidal fitting.

The original Ruby2D pipeline used 1-hour segments with **tidal fitting**, which
was abandoned because tidal artifacts persisted after fitting. The earlier
iteration of this pipeline then used 17-min (2048-sample) segments to get finer
temporal resolution. The current pipeline returns to 1-hour segments — but with
detrending instead of tidal fitting, MOP/CDIP-aligned boundaries, and a
multi-taper estimator (NW=4, 7 DPSS tapers).
**Do not reintroduce tidal fitting or 3-hour segments.**

The 17-min mode is still available as a fallback by passing `opts.segLen = 2048`.

Tradeoffs:
- 1 hour: finer frequency resolution, better IG-band coverage, MOP/CDIP-aligned;
  detrending handles tide robustly at these depths
- 17 min: better temporal resolution, df ≈ 0.001 Hz with multi-taper —
  retained as an option but no longer the default

### .nc files: deprecated
`save_initial_processingPUV_netcdf.m` is commented out in the original
`PUV_raw_process.m` and has been confirmed unused. The Paper 1 pipeline
loads `.mat` files only. `.nc` export is available as an optional step if
data sharing/archival requires it, but is not part of the standard pipeline.

### .mat format: primary intermediate format
Use `-v7.3` (HDF5) for large structs. Preserves datetime objects directly
(unlike .nc which converts to datenum and loses timezone). Can be opened
by Python via h5py if needed.

### L2 code: PUV_all_in_one.m is the reference implementation
`PUV_all_in_one.m` (Paper 1/DataCodes/PUV/) is the actually-used, working
L2 implementation. `PUV_MOP_master.m` is a cleaner but incomplete rewrite
with undefined variables — it was never run to completion and should not
be used as a reference. Both are archived in place.

### Config system: DeploymentNotes are authoritative
Per-deployment processing parameters (lat/lon, heading, clock drift, sensor
offset) come from `/Volumes/group/DeploymentNotes/DeploymentNotes{year}.xls`.
The annual checkout spreadsheets (`VectorPUV_{year}Checkout.xlsx`) have serial
numbers and qualitative checklist items but NOT the numerical processing params.
`TBR23_Notes.xlsx` (local) was the only machine-readable source before
DeploymentNotes was discovered — its format is the template for new deployments.

### Raw file reading: use textscan, not load()
MATLAB's `load()` on large ASCII files is extremely slow (30+ min for 316 MB).
Use `textscan(fid, repmat('%f',1,N), 'CollectOutput', true)` instead.
Files on `/Volumes/group/` are on a network mount — copy to local disk first
using `copy_raw_to_local(cfg)` before running L1 processing.
Local cache goes to `PUV_Pipeline/raw_cache/`.

### Raw-binary ingestion: read_VEC (added 2026-07)
L1 reads either the Nortek ExploreV ASCII export (`.dat`/`.sen`/`.hdr`) or the
raw recorder binary (`.VEC`/`.vec`/`.049`), via `L1_raw_to_qc/read_VEC.m`.
ExploreV — and Windows — are not required. This was needed to process the
pre-2019 archive (`recopied/`), most of which has no ASCII export at all, and to
avoid a partial-export trap (one deployment's `.dat` covers 5 of 174 days and
ends mid-line).

Decoder facts and design choices:
- **Verified bit-exact** against the one overlapping ASCII export
  (`test_read_VEC.m`): velocity/amp/corr/clock/flags identical over 886k velocity
  + 443k system records; pressure/attitude agree to the ASCII print precision.
- Records are confirmed by their Nortek checksum before use (`0xA5` occurs freely
  inside velocity data, so a sync-byte match alone is not enough).
- **fs is measured from the decoded records** (velocity-count / 1 Hz system-count),
  NOT from `512/AvgInterval`. The config derivation is right on firmware 3.43 but
  reports 8 Hz on firmware 1.21 where the data is 2 Hz; `read_VEC` keeps the config
  value as `fs_config` and warns on disagreement. This is why the 2015–2018 set was
  wrongly believed to need 8 Hz pipeline support — it does not.
- **Coordinate system + sampling rate come from the binary's User Configuration
  record**, so a 0-byte `.hdr` (unreadable from ASCII) is not fatal. Every file
  checked is XYZ.
- **One burst per raw file.** Both ingest paths treat each `_N` / hourly file as a
  separate burst, so the battery-cutoff detector never reads a file seam as a gap.
  Bursts are merged in **chronological order** (sorted by their monotonic clock),
  not filename order — `MMDDHHMM` names sort January ahead of the previous
  November, which scrambled the year-crossing Cardiff 2015–16 record until fixed.
- `.049` files (Cardiff) are ordinary Vector binary missing only the leading
  `0xA5` sync byte; `read_VEC` restores it.

### Wrong-epoch clock recovery: vec_clock_from_filenames (added 2026-07)
The firmware-1.21 recorders stamp a nonsense clock epoch (2000-01-01 / 2002-01-01),
but the clock *runs* correctly and each hourly file is named `MMDDHHMM` for the
true wall-clock hour. A single constant offset (median over all files) reconciles
them; opt in per instrument with `clockSource='filename'` + `deployYear`. The guard
rejects on the 98th-percentile spread (not the max), so a few dying-battery outlier
files near end-of-life don't veto an otherwise-clean deployment. Every recovered
span matches the logged deployment date; Cardiff1049 (whose clock *was* set right)
is the control and agrees to 33 s. Related L1 robustness added at the same time:
`cfg.qcOpts.cutoffGapSec` (raise above the benign ~3 s per-file hiccups),
power-on-glitch trimming, and end-of-life clock-jump truncation.

### Coordinate conventions
- After L1 rotation: +x WEST, +y NORTH, +z UP (left-handed, MOP convention)
- After L2 shorenormal rotation: +x onshore (shore-normal), +y alongshore north
- Transport sign convention: q_x positive = onshore flux
- Pressure: dBar (raw from instrument, not converted to Pa)

### Magnetic declination: Aerospace Toolbox required (for `igrfmagm`)
We avoid the `decyear()` Aerospace function by inlining the decimal-year calc:
```matlab
doy   = datenum(yr, mo, dy) - datenum(yr, 1, 0);
isLeap = (mod(yr,4)==0 && mod(yr,100)~=0) || mod(yr,400)==0;
decYr  = yr + (doy-1) / (365 + double(isLeap));
```
but the declination itself uses `igrfmagm()`, which **is an Aerospace Toolbox
function** (`toolbox/aero/aero/igrfmagm.m`) — so **Aerospace Toolbox is required**.
(An earlier version of this note mislabeled it as Mapping Toolbox; it is not.)
We use `igrfmagm`, not `wrldmagm` (also Aerospace): `wrldmagm` is limited to a
5-year WMM lifespan and errors on older deployment dates.
`igrfmagm(height_km, lat, lon, decYr, 13)` — height in km, IGRF model epoch 13.

---

## Raw Data Structure on Lab Server

Location: `/Volumes/group/PUV_data/Vector/`

Two layouts exist:
- **Subfolder layout** (older, multi-instrument): one subfolder per instrument
  inside the deployment folder, e.g. `Torrey20230503-20230816/MOP580-5m16739/`
- **Flat layout** (newer, single-instrument): files directly in deployment folder,
  e.g. `SouthSIOPier20250123-20250329/6M-51102_1.dat`

`PUV_raw_process.m` handles both via `instr.rawSubfolder` (empty = flat).

### File prefix naming
The file prefix (e.g. `5m_16739_MOP580`) is user-defined at programming time and
is not guaranteed to match the instrument serial number. The serial number in the
config comes from DeploymentNotes. Both are recorded in the config for reference.

### Known server issue fixed
`Torrey20230503-20230816/` previously had both MOP580-7m and MOP586-7m files
mixed in a single misnamed folder (`MOP586-7m17047`). Fixed on 2026-04-01:
- Created `MOP580-7m58002/` with the MOP580 files
- Renamed to `MOP586-7m58602/` for the MOP586 files
- Redistributed `.dep`/`.log` config files to correct instrument folders

---

## Known Issues and Review Items

See also: `config/CONFIG_REVIEW_NOTES.md` for deployment-specific items.

### L2 Z-test formula — fixed 2026-06-05
`PUV_L2_spectral.m` formerly computed the predicted pressure spectrum from
velocity as `Spp_from_vel = (Suu+Svv) · vel2pres²` with
`vel2pres = (g·k/ω)·cosh(k·d)/cosh(k·h)`. At sensor depth the cosh factors
should cancel and the (g·k/ω) factor enters as its inverse, so the
correct relation is `Spp_from_vel = (Suu+Svv)·(ω/(g·k))²`. The bug
produced a monotonic depth dependence in `ztest_SS` and `ztest_IG`
(median Z ≈ 0.33 at H=5 m climbing to ≈ 2.8 at H=15 m) that mimicked
shoaling-wave nonlinearity but was a pure formula error. Net error
factor was `(g·k/ω)⁴·cosh²(k·d)/cosh²(k·h)`, monotonic in depth.

Status:
- Fix landed in `L2_spectral/PUV_L2_spectral.m`, Z-test block ~line 393.
- TBR23 L2 files reprocessed 2026-06-05; medians now Z = 0.91–0.99.
- All other deployments reprocessed via `PUV_L2_rerun_for_Zfix.m`
  on the same date; corrected medians sit at Z = 0.92–0.97 across
  depths 4–18 m (saved at
  `Paper_1/paper/figures/figS_Z_corrected_all_deployments_20260605.txt`).
- Regression guard: `L2_spectral/test_ztest_linear.m` feeds a synthetic
  linear surface wave through the spectral routine and asserts Z = 1.0
  within tolerance at H = 3, 5, 7, 10, 15, 20 m. Now invoked from
  `scripts/test_new_L2_fields.m`; run before any future L2-touching
  publication.
- No downstream pipeline product (L3 transport, L4 IG, bulk wave
  parameters) reads or filters on Z, so manuscript-bound quantities
  (Sk, As, bispectra) were not affected.

Naming note: the diagnostic is called Z in the literature (Elgar,
Raubenheimer & Guza 2005, MST 16), not z². The L2 field name
`ztest_SS` is retained for code-style consistency, but user-facing
text, figure captions, and equations should write Z. Retention
window 0.5 < Z < 2.

**Z became a record-level QC flag on 2026-07-27.** Until then Z was computed and
stored per segment but never consumed by anything, so a record could fail it
silently — which is exactly what `RUBY22/MOP582_30m` did for months. Its
pressure transducer is dead, and no other L2 QC test catches it, but its median
Z is 8.9e-05 against 0.85–1.04 for every other record: four orders of magnitude
clear, and the only record flagged in the catalog.

- `shared/ztest_record_flag.m` — reduces per-segment Z to one verdict
  (`ok` / `FLAG` / `insufficient`). Used by both the pipeline and the audit, so
  the threshold cannot drift between them.
- `PUV_L2_spectral.m` stores it at `L2.qc_record.ztest_SS` / `.ztest_IG` and
  warns on failure. Records built before this date lack the field.
- `validation/audit_ztest_records.m` sweeps the catalog and computes the verdict
  for older records too, so **no L2 rebuild is needed** to use it.

It is a **flag, not a gate**: it marks the record and warns, and never drops
segments. A per-segment hard gate on Z would silently discard data on a
diagnostic that is itself sensitive to velocity noise. `insufficient` (fewer
than 20 valid segments) is deliberately not a failure — thin data is not
evidence of a bad sensor.

Two things to know when reading the output. The catalog median is ~0.97 rather
than 1.0 because velocity noise inflates `Suu+Svv`, inflating the predicted
pressure; it is flat in depth, so it is not a formula artifact. And when
checking `r(Z, depth)` as a regression guard against the formula bug, **exclude
flagged records** — the single dead record at 30.6 m drags r from −0.015 to
−0.78 by itself and reads exactly like a depth trend.

### bed_velocity_ifft.m — potential conjugate symmetry bug
In the loop over FFT bins, the negative-frequency bin is set to the conjugate
of the *already-scaled* positive bin. For k > N/2 the positive-frequency
processing is skipped (continue), but its conjugate partner at N-k was already
handled in a prior iteration. This appears logically correct but is subtle —
verify with a synthetic test case (known sinusoid input, check output amplitude).

### calculate_friction_factor.m — overrides input u_b
The function accepts `u_b` as an input but then immediately recomputes it
internally from wave parameters (H, a, L, T). The input `u_b` is silently
discarded. This is likely a bug — the function was probably intended to accept
u_b directly. Not currently used in the main pipeline; flag before using.

### rotate_shorenormal.m — moplist.mat dependency
The function does `load('moplist.mat')` relying on MATLAB path. The file is in
`Beach_Change_Observation/Vector/PUVs/PUV_Processing-main/extra/`. Canonical
copy placed in `PUV_Pipeline/shared/`. The function also makes a live CDIP
THREDDS call to get shore-normal angle — requires internet access at runtime.

### TOR23W/SOL23 instruments with NaN clock drift
7 of 9 instruments from the winter 2023-24 campaign (formerly NN24) have
unknown clock drift (battery depletion or missing field notes).
See `config/CONFIG_REVIEW_NOTES.md` for full list.

### L3/L4 are snapshots of L2 — index alignment is not guaranteed (2026-07-26)

L3 and L4 allocate their per-segment arrays at `numel(L2.time)` and loop
`1:nSeg`. That is correct at build time and stays correct only for as long as L2
does not change. Because L2 is periodically re-derived (QC changes, the
channel-decoupling rerun, trim/anchor changes), **an L4 file records the segment
grid of whichever L2 was canonical when it was built.**

The 2026-07-10/11 rerun's new trim/anchor recovered one extra segment at the
*start* of L2 on three records (SIO25B/SIO_6m, TOR24S/MOP586_7m,
TOR24W/MOP586_10m). Their L4 was then offset by one for every segment — the first
one included, not just after some drop point.

Two properties make this dangerous rather than merely wrong:

1. **Equal counts do not prove alignment.** A grid can gain a segment at the
   start and lose one at the end and still have the same length. The only sound
   test is to match on `time`. (For a sanity probe, a one-hour shift on a tidal
   record shows up as ~0.5 m in `depth`, against ~0.01 m for ordinary QC drift —
   the two are not confusable.)
2. **MATLAB accepts a logical mask shorter than the array it indexes.** So
   `L2.Hs_SS(mask)` with an L4-length `mask` silently returns the first
   `numel(mask)` entries instead of erroring. This was live in
   `validation/fig_L4_boundwave_catalog.m`, mispairing every point of its
   bound-fraction-vs-`Hs²` panel on the three affected records. An out-of-range
   *numeric* index crashes and is survivable; the logical-mask form does not.

**Rule:** never index an L4 array with an L2 index. Use
`shared/l4_l2_index_map.m` (matches by `time`, returns `info.identity` for
assertions). `validation/audit_L4_coverage.m` sweeps the catalog for both
problems, checking every sub-product rather than the first one it finds.

The same reasoning applies to L3, which is why an L1/L2 rerun must be followed by
either a regen of the higher levels or a written justification for skipping it —
the 07-12 rerun left 11 records with an L3 older than its L2 for two weeks
because the regen covered one batch and not the other.

### Config comments do not age with the values they describe (2026-07-27)

Four config headers asserted that field data was unavailable. **All four were
wrong** — the numbers were in a `DeploymentNotes*.xls` or `SoCal_instruments*.xls`
workbook the whole time, and L1–L4 had been built on the placeholder for months.

| config | claimed | reality |
|---|---|---|
| Cardiff | "doffp is not recorded for these years" | recorded: 0.54 / 0.55 m |
| Coronado | same | recorded: 0.58 / 0.72 m — and the 0.65 "program-typical" split the difference, wrong in *both* directions |
| Catalina | "placeholder — fill from notes before running L2" | never done; also a **21.9 km** lat/lon error and an unset serial |
| TorreyOffshore | 0.63 m "carried from the 2019-2020 notes" | true, but carried back across 2014–2019 without checking per-year values |

**Where to look:** sheet **'All Data'**, column "Deployment Depth below sand (cm)"
(which usually reads "Pressure port *N* cm above sand"). Match on **serial AND
deployment ordinal AND season** — serials are reused across years, so a serial
alone gives false hits. Beware `DeploymentNotes2021Torrey.xls`: its 'Torrey'
sheet is a *different* experiment (a shallow Paros swash array); the Vector data
is in 'All Data'.

**When a config label disagrees with the notes, resolve from the data.** Catalina's
A/B labelling did not match the notes' two deployments. Rather than guess, the
mapping was settled on two independent lines: L1 time spans (CAT21A starts on the
exact changeover day, both sit inside S/N 15032's window) and the `.sen` compass
(232.7 / 230.7 deg, near 15032's surveyed 222.7, nothing like 15033's 56.2). Both
agreed. `CATISL02`/`CATISL03` turned out to be recorder file-set names, not serials.

**The structural fix:** `validation/audit_config_provenance.m`. It classifies every
`doffp` / `latlon` / `shorenormal` assignment from *its own trailing comment* —
sourced, declared-placeholder, or unannotated. A first version scanned the whole
header for words like "placeholder" and failed in both directions: it flagged a
header that merely *described* a placeholder it had already fixed, and it could
not tell a measured 0.75 m from a default 0.75 m. **Put the source on the line:**

```matlab
cfg.instruments(k).doffp = 0.71;   % m, port 71cm above sand (S/N 15032)
```

not in a header paragraph that will not age with the value.

### A partial L4 rebuild destroys everything it does not recompute (2026-07-27)

`L4` is a single struct in a single `.mat`. A script that recomputes two or
three products and then does

```matlab
L4.eta = ...;  L4.bispectra = ...;  L4.ref = ...;
save(l4Path, 'L4', '-v7.3');     % <-- overwrites the WHOLE file
```

silently deletes every other field. This is not hypothetical:
`scripts/reprocess_heading_fix.m` did exactly this twice, both times during a
heading fix — **TBR23/MOP580_5m** in May 2026 (lost `label`,
`deploymentName`, `LATLON`, `doffp`, `shorenormal`, `mopStation`, `builtAt`) and
**TOR16B/C/D** on 2026-07-27 (lost `LATLON`, `doffp`, `shorenormal`, `pdf`).
The May damage reached the server and sat in the canonical copy for two months.

Three things made it invisible for that long:

1. **`audit_L4_coverage` checked only the seven sub-products, not the
   metadata**, so the damaged record reported clean. Fixed 2026-07-27 — the
   audit now has a `meta` column and lists stripped records separately.
2. Nothing in a single-instrument workflow reads the lost fields, so the
   record looks fine right up until something does.
3. The loss is not cosmetic where it bites. **`PUV_L4_xspec` reads
   `L4.LATLON` and `L4.shorenormal`**, so a stripped record hard-errors on any
   multi-instrument deployment — and `shorenormal` is the record of *which
   rotation was applied*, which is precisely the provenance you want after
   correcting a heading.

**Rules.** Any script that re-saves an L4 file must write the complete struct,
matching the metadata block at the end of `PUV_L4_driver`. `clear L4` before
building, or the struct leaks across loop iterations and one instrument
inherits another's fields. To fill gaps in an existing file without touching
computed products, use `scripts/repair_L4_metadata_2026_07_27.m` — it is
additive, refuses to patch a record whose L4 grid does not match L2, and was
verified to leave `bispectra` and `ref` bit-identical. `scripts/copy_to_server.m`
now refuses to push an incomplete L4 at all.

---

## Archived Scripts (do not use)

| Script | Location | Reason archived |
|--------|----------|-----------------|
| `PUV_L1.m` | `Vector/PUVs/PUV_Processing-main/` | Replaced by `PUV_L1_driver.m` |
| `PUV_raw_process.m` (original) | `Vector/PUVs/PUV_Processing-main/Level1_QC/` | Replaced; had eval(), interactive figures |
| `PUV_all_in_one.m` | `Paper 1/DataCodes/PUV/` | Will be replaced by `PUV_L2_driver.m` |
| `PUV_MOP_master.m` | `Paper 1/DataCodes/PUV/` | Never ran to completion; undefined variables |
| `PUV_all_in_one_for_Nick.m` | `Paper 1/DataCodes/PUV/` | Regenerate from pipeline if needed |
| `PUV_code_combined_3h_incoming.m` | `Vector/PUVs/PUV_Processing-main/` | 3-hour tiding approach abandoned |
| `PUV_L2_analysis.m` | `Vector/PUVs/PUVs/` | Superseded by L2 driver |
| `importNortekPUVdat.m` | `Vector/` | Early scratch script, not generalized |
| `calculate_friction_factor.m` | `Paper 1/DataCodes/PUV/` | Deleted — used Jonsson formula inconsistent with Swart (1974) in `bed_stress.m`; also had bug where `u_b` input was silently overwritten internally. Use `bed_stress.m` instead. |

---

## Status snapshot — May 11, 2026 (HISTORICAL; see docs/pipeline_levels.md for current)

> Live per-level status (counts, what's verified, what's deferred) is tracked
> in `docs/pipeline_levels.md` — treat that as authoritative if it disagrees
> with the summary below. This section captures the design rationale behind the
> QC and processing choices.

### L1 — complete, 65 instrument-records across 46 deployments
- Variability-based tilt QC (2° rolling std threshold, 30° absolute cap)
- Sample-by-sample tilt correction for bent pipes (3D rotation using pitch/roll)
- Pressure QC uses a healthy first-burst reference window for the median
  threshold (added May 6 after the RUBY22/MOP579_6m sensor-block-failure
  bug; protects against the inversion failure mode where >50% of samples
  are saturated)
- Handles mixed file prefixes (underscore/hyphen), single-burst files, IGRF-14 fallback
- Two ingest paths (added 2026-07-24): the Nortek ExploreV ASCII export, or the
  raw recorder binary decoded by `read_VEC`. The binary path removes the
  Windows-only ExploreV step and recovers sampling rate / coordinate system from
  the User Configuration record when the `.hdr` export is 0 bytes. Auto-detection
  prefers ASCII, which is wrong for interrupted exports — pin
  `instr.rawFormat = 'VEC'` in that case; a warning fires when both forms exist.
- L1 heading bug fixed at TBR23/MOP580_5m and TOR24S/MOP586_7m (180° error
  surfaced by the per-band R²_swell ≫ R²_IG reflection diagnostic)
- Dropped records are documented hardware failures (genuine tilt limits — bent
  pipes, burial-during-storms, knocked-over instruments; battery, kelp,
  corrosion), correctly rejected — not a bug. Fix candidates and per-instrument
  explanations in `docs/deployment_database_overview.md` (a superseded 2026-04-05
  snapshot — its counts are stale) and `docs/todo.md`.
- Catalog: deployments across 8 sites (Torrey nearshore + offshore/LPL-mouth,
  SIO Pier, Solana, LPL lagoon, Imperial Beach, Cardiff, Coronado, Catalina) —
  current status in `docs/pipeline_levels.md`; the 2026-04-05
  `docs/deployment_database_overview.md` snapshot is superseded.

### L2 — complete, 65/65 instrument-records processed
- Per-segment guard rejects segments with `Hs/h > 1.5` or
  `|h - depth_nominal|/depth_nominal > 0.5` (added May 6; catches
  segments that straddle a sensor-failure boundary in the L1 record);
  also nanMaxFrac=0.10 rejection
- 1-hour (7200 @ 2 Hz) UTC-aligned segments, detrend, Wu pressure correction
  (17-min still available via `opts.segLen = 2048`)
- **Spectral method: full multi-taper** (NW=4, 7 DPSS tapers, nfft=2048,
  df ≈ 0.001 Hz). Welch with Hanning still available via
  `opts.spectralMethod = 'welch'`. See `docs/multitaper_writeup.pdf` for
  comparison and recommendation rationale.
- Both auto-spectra (Spp, Suu, Svv) and cross-spectra (Spu, Spv, Suv)
  computed with the same DPSS tapers — preserves spectral consistency
  for directional analysis (a1, b1, a2, b2)
- Shore-normal rotation via CDIP THREDDS with fallback to buoy coords
- Z-test (pressure-velocity consistency) and radiation stress tensor
  (Sxx, Syy, Sxy from a2/b2) computed and stored
- **D50 = 0.25 mm placeholder** — real grain size data from Laser Particle Analyzer
  campaign expected soon. Bed stress can be recomputed from stored Ub and Tp.
- **Wu pressure correction**: standard linear wave theory Kp = cosh(k*z)/cosh(k*H).
  Confirmed identical to the Wu (1986) approximation and the legacy modified
  coefficients used in earlier pipeline iterations — all three methods produce
  the same Kp to 4–5 decimal places.

### Validation — complete, confirmed across TBR23 + TOR23W/SOL23
- PUV-MOP comparison: Hs R² = 0.83–0.86 for good instruments
- ~~Spectral shape analysis: MOP spectral peak broadening identified as root cause
  of systematic positive Hs bias (R(Qp)=0.30–0.63 across 11 instruments)~~
  **RETRACTED 2026-07-25 — artifact, not physics.** The metric interpolated MOP's
  ~20 coarse bins up onto the PUV's 3601-point grid (~2-45x mismatch). A PUV spectrum
  compared against a degraded copy of *itself* through that path returns 68.3%
  bandwidth narrowing and Qp ratio 1.225 — more than the whole reported effect.
  On a matched grid it is absent and changes sign by site. The "11 instruments"
  count was also stale (saved `.mat` has 33; catalog now has 65).
  Replacement: `validation/compare_shape_matched.m` + `run_matched_shape_sweep.m`.
  Tests: `validation/test_resolution_artifact.m`, `test_shape_metric_sensitivity.m`,
  `test_shoal_bin_synthetic.m`. Write-up:
  `PUV_paper/docs/findings_resolution_artifact_2026-07-24.md`.
- **Mechanism attribution (redone 2026-07-27, 72,948 hours / 61 records).**
  An earlier version eliminated three mechanisms in favour of MOP peak
  broadening, which was afterwards shown to be a grid artifact. The redone
  analysis inverts that:
  - **Nonlinear shoaling is the mechanism.** Energy transfers from the peak to
    its super-harmonic: the PUV/model ratio troughs at 0.94-0.95 for
    f/fp = 1.3-1.5 and peaks at 1.34 at f/fp = 2.1 when Hs/h > 0.12, against
    1.10 below. Organised by Ursell (rho = +0.332), not depth (-0.114 with Hs/h
    held fixed). The spectral-width ratio runs from 1.000 below Hs/h = 0.04 to
    1.100 above 0.20. Bicoherence orders the harmonic excess within Hs/h bands
    (-0.008 below 0.06, +0.285 above 0.20).
    *The earlier test correlated Ursell against the low-swell band and found
    R^2 = 0.004 -- the transfer is at 2*fp, so that test looked in the wrong place.*
  - **Bound long waves are the difference-frequency counterpart.** Predicted /
    observed bound-IG rises with Hs/h (rho = +0.913 per record) and crosses unity
    near Hs/h = 0.12. Against the width discrepancy the partial controlling for
    Hs/h is only +0.149 -- collinear with the above because both arise from the
    same triads, not a separate explanation.
    *The earlier rejection cited excess energy "concentrated at the peak"; that
    concentration was itself the artifact.*
  - **Directional spread is a real, separate bias.** PUV sigma_1 exceeds the
    model's by a median factor 1.156 (p = 2.6e-6), but does not covary with the
    discrepancy (p = 0.30, 0.54). Rotation-invariant, so unaffected by the
    2026-07-27 heading corrections.
  - **Peak broadening: eliminated.** Matched-grid Qp ratio 1.008 (p = 0.70 on
    the shape factor).
  Code: `validation/redo_hypothesis_elimination.m`. Write-up:
  `../PUV_paper/docs/findings_hypothesis_elimination_2026-07-27.md`.
- Full hypothesis testing suite in `validation/`
- **Ruby2D head-to-head vs the legacy pipeline (April 9, 2026)**: 2,322 matched
  60-min segments on MOP582_6m, Oct 2021 – Feb 2022. Hs RMS 5 cm (R² = 0.98),
  direction RMS 1.2° (R² = 0.93), spread RMS 1.7° (R² = 0.88). Multi-taper
  pipeline reproduces an independent prior pipeline within instrument noise;
  the window mismatch we expected to find a strong directional signature
  for is small in practice (~1°). Spectral shapes are visibly smoother
  (variance reduction) but the underlying peak structure agrees. See
  `docs/pipeline_comparison_legacy.md` for the full writeup and
  `outputs/validation/Ruby2D/` for the figures and numeric summary.
  Comparison scripts: `scripts/process_ruby2d_one.m`,
  `scripts/extract_legacy_bulk.m`, `scripts/compare_ruby2d.m`.

### L3 — complete, batch-processed across all instruments
Band decomposition, storm/event detection, transport proxies, and current
decomposition (t_tide tidal harmonics validated against the NOAA Scripps Pier
gauge, R=0.995, UTC confirmed). Output: `outputs/L3/{deployment}/{label}_L3.mat`.
The paper-specific transport-model wrapper (`run_transport_model.m`) stays in
the Paper 1 directory — deployment-specific, not part of the universal pipeline.

### L4 — modules validated on TBR23, built across all 65 records (2026-07-26)
- `PUV_L4_eta` (P → η, three bands; Hs reconstruction matches L2 to 0.5%)
- `PUV_L4_reflection` (Sheremet incident/reflected split; sign convention
  validated via `corr(η_swell, U_swell) = +0.984`)
- `PUV_L4_bispectra` (bicoherence/skewness/asymmetry; `bic_swell_ig_diff`
  monotonic in depth at TBR23, consistent with bound-wave forcing)
- `PUV_L4_xspec` (pairwise IG cross-spectra for arrays, best-overlap matching)
- `PUV_L4_moments` and `PUV_L4_velocity_pdf` (reverse-engineered Bill O'Reilly
  MOP511 6m analysis — frequency-resolved skewness/asymmetry correlations and
  pooled |u| PDFs)
- `PUV_L4_boundwave` (bound/free IG separation, η and u) feeding
  `PUV_L4_reflection_free` — the shoreline reflection coefficient that `L4.ref`
  alone overstates through bound-IG contamination. Regime limit: the
  second-order theory over-predicts above `Hs/h` ≈ 0.10.
- Reflection bands inform the per-band R²_swell ≫ R²_IG heading diagnostic that
  caught the L1 180° errors above.
- `bispectra` is the runtime bottleneck, which is why `PUV_L4_run_all` skips it
  and a separate pass fills it in. That split is the direct cause of the
  2026-07-26 gap: 23 records ingested after the one-time backfill pass never got
  it. If `run_all` is used to add records, run the bispectra pass afterwards.
- See `docs/pipeline_levels.md` for the full L4 output-struct shape, and the
  L3/L4 index-alignment note under "Known Issues" above before writing any
  consumer that joins L4 to L2.

### L5 — planned (PUV–altimeter integration)
Not yet implemented. See `docs/pipeline_levels.md` and `project_L5_plan`.
