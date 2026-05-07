# PUV Pipeline — Design Notes and Decisions

This document records the architectural decisions, known issues, and rationale
behind the pipeline design. Update it when decisions change.

---

## Directory Structure

```
PUV_Pipeline/
    startup_puv.m              — adds all subdirs to MATLAB path; run first
    config/                    — per-deployment config structs + registry
    L1_raw_to_qc/              — raw .dat/.sen/.hdr → QC'd PUV struct (.mat)
    L2_spectral/               — spectral analysis, wave stats, bed velocity
    L3_transport/              — sediment transport models (Paper 1 specific)
    shared/                    — canonical copies of shared functions
    raw_cache/                 — local copies of raw server files (not committed)
    outputs/L1|L2|L3/          — processed outputs per deployment
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
- **Script**: `PUV_L2_driver.m`
- **Processing**: 17-min (2048-sample @ 2Hz) segments, detrend, Wu pressure
  correction, Welch PSD, Hs/Tp/energy flux, bed velocity (IFFT method),
  Reynolds stress, velocity moments, optional MOP comparison
- **Output**: `outputs/L2/{deployment}/` struct per instrument

### L3: Transport & Derived Products (Paper_1)
- Lives in `Paper_1/DataCodes/` — deployment-specific analysis, not reusable pipeline
- `run_transport_model.m`: Bailard → Hoefel & Elgar → undertow → Shields hierarchy

#### L3 additions needed:
- **Frequency-band energy flux decomposition**: Compute energy flux separately for
  sea band vs swell band (and optionally IG band) per burst. This is needed for a
  Paper_1 figure showing which frequency band drives morphological change at 5m vs 7m.
  The PUV L2 output already has full spectra — L3 just needs to integrate F(f) over
  defined bands and output time series of F_sea, F_swell, F_ig per instrument.
  Band definitions: IG = 0.004–0.04 Hz, swell = 0.04–0.10 Hz, sea = 0.10–0.25 Hz
  (confirm with Holden). This supports the "local seas vs swell" finding in Paper_1.

---

## Key Design Decisions

### Segment length: 17 minutes (2048 samples @ 2 Hz)
The original Ruby2D pipeline used 1-hour segments with tidal fitting.
This was abandoned because tidal artifacts persisted even after fitting.
The canonical approach is 17-min segments with detrending.
**Do not reintroduce tidal fitting or 3-hour segments.**

Tradeoffs documented:
- 17 min: better temporal resolution, robust detrending, multi-taper estimator
  with NW=4 (7 DPSS tapers), df ≈ 0.001 Hz, standard in nearshore literature
- 1 hour: finer frequency resolution, better IG band coverage — not worth the
  tidal contamination at these depths

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

### Coordinate conventions
- After L1 rotation: +x WEST, +y NORTH, +z UP (left-handed, MOP convention)
- After L2 shorenormal rotation: +x onshore (shore-normal), +y alongshore north
- Transport sign convention: q_x positive = onshore flux
- Pressure: dBar (raw from instrument, not converted to Pa)

### Magnetic declination: no Aerospace Toolbox required
`decyear()` requires Aerospace Toolbox. Replaced with inline calculation:
```matlab
doy   = datenum(yr, mo, dy) - datenum(yr, 1, 0);
isLeap = (mod(yr,4)==0 && mod(yr,100)~=0) || mod(yr,400)==0;
decYr  = yr + (doy-1) / (365 + double(isLeap));
```
`igrfmagm()` requires Mapping Toolbox (available). Use this, not `wrldmagm()` (Aerospace Toolbox).
`wrldmagm` is limited to a 5-year WMM lifespan and errors on older deployment dates.
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

## Current Status (as of May 7, 2026)

### L1 — 38/44 instruments processed
- Variability-based tilt QC (2° rolling std threshold, 30° absolute cap)
- Sample-by-sample tilt correction for bent pipes (3D rotation using pitch/roll)
- Pressure QC uses a healthy first-burst reference window for the median
  threshold (added May 6 after the RUBY22/MOP579_6m sensor-block-failure
  bug; protects against the inversion failure mode where >50% of samples
  are saturated)
- Handles mixed file prefixes (underscore/hyphen), single-burst files, IGRF-14 fallback
- 6 records still failing L1 are at genuine tilt limits (bent pipes,
  burial-during-storms, knocked-over instruments); fix candidates noted
  in `docs/deployment_database_overview.md`
- Catalog: 23 deployments × 6 sites (Torrey, SIO Pier, Solana, LPL lagoon,
  Imperial Beach, Catalina) — see `docs/deployment_database_overview.md`

### L2 — complete, 38/38 instruments processed
- Per-segment guard rejects segments with `Hs/h > 1.5` or
  `|h - depth_nominal|/depth_nominal > 0.5` (added May 6; catches
  segments that straddle a sensor-failure boundary in the L1 record)
- 17-min (2048 @ 2 Hz) segments, detrend, Wu pressure correction
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
- Spectral shape analysis: MOP spectral peak broadening identified as root cause
  of systematic positive Hs bias (R(Qp)=0.30–0.63 across 11 instruments)
- Ruled out: nonlinear shoaling, directional narrowing, bound long waves
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

### L3 / Paper 1 wrapper — not yet written
Thin wrapper in `Paper 1/DataCodes/` calling shared pipeline with TBR23 config.
`run_transport_model.m` stays in Paper 1 — deployment-specific.
