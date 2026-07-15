# Nortek Vector PUV Pipeline

A MATLAB pipeline for processing **pressure + velocity (PUV)** data from
Nortek Vector current meters into quality-controlled time series, wave
spectra, and nearshore wave-forcing diagnostics.

It takes raw instrument files (`.dat`/`.sen`/`.hdr`) through five processing
levels — from QC'd time series up to nonlinear-wave / infragravity (IG)
dynamics — using a single, deployment-agnostic configuration system. Run any
deployment through the same drivers and get the same standardized output.

> **New to the repo?** Read this file for orientation, then
> **`docs/PUV_Pipeline_Guide.pdf`** — the single step-by-step writeup that takes you from
> setup through running your own deployment, the quality-control system, methods, and
> validation. `docs/pipeline_levels.md` is the level-by-level reference and
> `PIPELINE_NOTES.md` holds design decisions and known issues.

---

## What it produces

| Level | Output | One-line description |
|-------|--------|----------------------|
| **L1** | QC'd 2 Hz time series | Burst merge, clock-drift + tilt correction, **per-channel** QC (velocity/pressure/temperature/tilt judged independently), sound-speed correction, rotation to buoy frame |
| **L2** | Per-segment spectra | Multi-taper PSD, pressure correction → surface elevation, bulk wave params (Hs, Tp, direction), near-bed velocity, bed/Reynolds stress, velocity moments |
| **L3** | Forcing metrics | Frequency-band energy decomposition, storm/event detection, transport proxies (Shields, Rouse), tidal + undertow current decomposition |
| **L4** | Nonlinear / IG diagnostics | Surface-elevation bands, incident/reflected IG split, bispectra (skewness/asymmetry/bicoherence), IG cross-spectra, velocity PDFs |
| **L5** | *(planned)* | PUV–altimeter integration for bed-change vs forcing |

Levels L1–L3 are universal; L4 adds nonlinear-wave/IG diagnostics on top of
L2. See `docs/pipeline_levels.md` for full per-level detail.

---

## Requirements

- **MATLAB** (developed on R2023b+). Required toolboxes:
  - **Signal Processing Toolbox** — DPSS multi-taper spectra, Welch fallback (L2)
  - **Aerospace Toolbox** — `igrfmagm` for magnetic declination / IGRF (L1 heading)
  - **t_tide** (on the path, external) — tidal harmonic analysis in L3 only
  - *Mapping Toolbox is **not** required* (`igrfmagm` is an Aerospace Toolbox
    function; `decyear` was replaced by an inline calc — see PIPELINE_NOTES.md)
  - *Statistics and Machine Learning Toolbox is **not** required by the L1–L4
    pipeline* (skewness/kurtosis/corr are computed inline). A few optional
    standalone scripts under `validation/` still use it (`quantile`, `regress`).
- **Internet access at runtime** — only if you use a CDIP source: a MOP station
  for the shore-normal angle (California), or a CDIP `refStation` for the offshore
  wave reference (any site). A manual `instr.shorenormal` and no `refStation` need
  no network.
- **Raw data** — point each deployment's `cfg.rawDataRoot` at wherever your raw
  Nortek files live. A local folder is fine; no lab server is required. *(The
  bundled San Diego configs happen to point at the SIO group share
  `/Volumes/group/PUV_data/Vector/`; your own config points wherever you want.)*

> **Running your own deployment (any site, including non-California / reef
> deployments with no CDIP MOP)?** Start with **`docs/NEW_DEPLOYMENT.md`** and the
> copy-me template **`config/TEMPLATE_config.m`**. The pipeline is site-agnostic;
> everything site-specific lives in one config file.

---

## Quick start

```matlab
% 1. From the repo root, add all pipeline directories to the path:
>> cd /path/to/PUV_Pipeline
>> startup_puv

% 2. (Optional but recommended) copy raw files from the server to local disk
%    — network reads are slow; the drivers auto-use raw_cache/ if present:
>> reg = deployment_registry();
>> cfg = reg('TBR23')();
>> copy_raw_to_local(cfg);

% 3. Run the levels in order. Each driver has a `deployment_name` variable
%    at the top — set it and run:
>> PUV_L1_driver    % raw -> QC'd timeseries   (outputs/L1/TBR23/)
>> PUV_L2_driver    % spectra + bulk params    (outputs/L2/TBR23/)
>> PUV_L3_driver    % forcing characterization (outputs/L3/TBR23/)
>> PUV_L4_driver    % nonlinear / IG dynamics  (outputs/L4/TBR23/)
```

To batch every registered deployment, use the `*_run_all` scripts
(`PUV_L1_run_all`, `PUV_L2_run_all`, …) — they skip deployments that already
have outputs.

Each level reads the previous level's `.mat` files and errors with a clear
message if they're missing, so always run L1 → L2 → L3 → L4 in sequence.

---

## Configuring a deployment

Every deployment is registered in `config/deployment_registry.m`, which maps a
short name to its config function (e.g. `'TBR23' -> @TBR23_config`). To process
a deployment, just set `deployment_name` at the top of a driver to one of:

```
CAT21A CAT21B IB18W IB19S LPL23 LPL24 LPL25A LPL25B RUBY22
SIO24A SIO24B SIO24C SIO25A SIO25B SIO25C SIO25D SIO25E
SOL23 SOL24 SOL25A SOL25B TBR23 TOR23W TOR24S TOR24W TOR25S
```

**Naming convention:** `SITE + year + optional season letter`
(`TBR23` = Torrey Black's Rock summer 2023; `TOR24S` = Torrey spring 2024;
`SIO24A–C` = SIO Pier 2024 chronological). Full key in
`config/deployment_registry.m`.

### Adding a new deployment

**Full walkthrough: `docs/NEW_DEPLOYMENT.md`.** In short:

1. Copy **`config/TEMPLATE_config.m`** (a fully-commented, site-agnostic starting
   point) to `config/<SITE>_config.m` and rename the function to match.
2. Fill in the fields for each instrument: `rawDataRoot`, `label`, `filePrefix`,
   `latlon`, `depth_nominal`, and **`doffp`** (pressure-sensor height above the
   bed — required). Set `cfg.qcOpts.Tvalid` to your site's water-temperature
   range (see QC section below).
3. Set the **shore-normal angle**: `instr.shorenormal` (manual degrees, any site)
   *or* `instr.mopStation` (CDIP lookup, California only) — see below.
4. Register it in `config/deployment_registry.m` (one line:
   `registry('SITE') = @SITE_config;`).

*San Diego users:* the authoritative source for `doffp`/heading/clock drift is
`/Volumes/group/DeploymentNotes/DeploymentNotes{year}.xls`; see
`config/CONFIG_REVIEW_NOTES.md` and `config/DOFFP_LOOKUP_CHECKLIST.md` for
per-deployment gotchas. *Other sites:* take these straight from your field log.

### Shore-normal rotation

L2 rotates buoy-frame velocity (`+x` West, `+y` North) into a shore-normal frame
(`+x` onshore, `+y` alongshore-north), which drives the cross/alongshore currents
(L3) and the incident/reflected IG split (L4). Supply the angle one of two ways:

- **`instr.shorenormal = <deg>`** — a manual shore-normal bearing (offshore-
  pointing, 0 = N, 90 = E). Use this at **any site without a CDIP MOP transect**
  (i.e. anywhere outside California). No internet needed. *Takes precedence.*
- **`instr.mopStation = 'D0580'`** — a CDIP MOP station; the angle is fetched
  live from CDIP THREDDS (California sites; needs internet).

If neither is set, velocity stays in buoy coordinates and the L4
incident/reflected split is skipped.

### Offshore wave reference (optional)

Separately from shore-normal, you can attach a **CDIP station as an offshore
reference** — the role the MOP model plays in San Diego. It drives the L2
validation figures (Hs/Tp/direction, bound-wave, directional spread) and the L3
storm/forcing context. Set `instr.refStation` to any CDIP station id:

- a **directional buoy**, e.g. `'233p1'` — read generically by
  `shared/cdip_station_reference.m` (works at any site; needs internet); or
- a **MOP model point**, e.g. `'D0580'` — delegated to `read_MOPline2` (California).

A buoy is **not** a shore-normal source (it reports direction in a true-north
frame); keep `instr.shorenormal` set for rotation. See `docs/NEW_DEPLOYMENT.md` §6.

---

## Quality control and data provenance

L1 judges each channel independently: **one dead channel never discards data from a channel
that is still good.** A frame whose pressure sensor and thermistor fail during a storm still
yields usable velocity if the Doppler channel is healthy — this recovers storm-peak data the
old row-level QC threw away. Every L2 segment carries provenance so you can filter:

- `segValid` — old-style "all channels good" (unchanged; existing analyses behave as before)
- `segValid_vel` / `segValid_p` — velocity vs. pressure products usable
- `qc_flag` — QARTOD-style: **1** good, **2** not evaluated, **3** suspect (recovered or
  sound-speed-rescaled), **4** fail. Anything reconstructed is `3`, never `1`.
- `Hs_source` — `'measured'` / `'reconstructed'` / `'none'`

To use clean-only forcing, filter on `qc_flag == 1`. To use recovered storm-peak velocity
moments, take `qc_flag == 3` with `segValid_vel`, knowing they carry a few-percent scale
uncertainty. At L4 these travel per burst as `puv_qc_flag` / `puv_segValid_vel` / `puv_segValid_p`.

> **⚠ One config setting matters: `cfg.qcOpts.Tvalid`.** This is the plausible
> water-temperature range that flags a failed thermistor. The default `[-2 40]` is a wide
> safety bound; **set it to your site's range** so subtle thermistor failures are caught
> without mis-flagging genuine water (San Diego coastal `[9 26]`; tropical reef `[22 31]`).
> Do **not** copy a cold-water range to a warm site — it would flag healthy warm water as
> sensor failure. See `docs/PUV_Pipeline_Guide.pdf` §5 for the full rationale.

Three failure signatures are distinguishable from the `.sen` files alone (battery, sound
speed, tilt): **sensor-block failure** (velocity recoverable), **toppled frame** (not), and
**Doppler failure** (not). Full detail in `docs/OUTSTANDING_channel_decoupling.md`.

---

## Repository layout

```
PUV_Pipeline/
  startup_puv.m         run first — adds all subdirs to the MATLAB path
  config/               per-deployment config functions + registry
                        (TEMPLATE_config.m = copy-me starting point for a new site)
  L1_raw_to_qc/         raw .dat/.sen/.hdr  ->  QC'd PUV timeseries
  L2_spectral/          spectral analysis, wave stats, bed velocity
  L3_forcing/           band decomposition, storms, transport proxies, currents
  L3_transport/         (Paper-specific transport models — thin wrappers)
  L4_ig/                nonlinear-wave + infragravity dynamics
  shared/               functions used across levels (wavenumber, multitaper, …)
  config/               deployment configs + registry
  docs/                 detailed references (start with pipeline_levels.md)
  raw_cache/            local copies of server raw files (gitignored)
  outputs/              processed outputs per level/deployment (gitignored)
  PIPELINE_NOTES.md     design decisions, known issues, archived scripts
```

**Outputs and raw caches are not version-controlled** — they are reproducible
from raw data + code (see `.gitignore`). Outputs land in
`outputs/L{1..4}/{deployment}/{label}_L{n}.mat`.

> **About `scripts/`** — this is a working directory of one-off diagnostic,
> migration, and validation scripts (audit_*, probe_*, fig_*, rerun_*, etc.).
> They are **not the supported pipeline** — use the `L{1,2,3,4}_*` drivers for
> processing. Scripts here resolve the repo root from their own file location,
> so they don't need a hardcoded path, but they may reference specific
> deployments or one-off datasets that are not part of the canonical flow.

### Data locations (lab server, read-only)

- Raw data: `/Volumes/group/PUV_data/Vector/`
- Deployment notes: `/Volumes/group/DeploymentNotes/`

See `~/Documents/Scripps/Research/server_io_patterns.md` for caching patterns
that speed up network-mounted I/O.

---

## Where to look next

- **`docs/NEW_DEPLOYMENT.md`** — start here to run the pipeline on your own
  deployment at any site (metadata checklist, shore-normal without CDIP/MOP,
  temperature QC, troubleshooting); pairs with `config/TEMPLATE_config.m`
- **`docs/PUV_Pipeline_Guide.pdf`** — the step-by-step writeup: setup, running a deployment,
  the QC system, methods, validation, and output reference (source: `PUV_Pipeline_Guide.tex`)
- **`docs/pipeline_levels.md`** — the detailed, current level-by-level reference
  (inputs, outputs, status, output-struct shapes)
- **`PIPELINE_NOTES.md`** — design decisions, coordinate conventions, known
  issues, and the list of archived scripts not to use
- **`config/CONFIG_REVIEW_NOTES.md`** — per-deployment review items
- **`docs/`** — deployment inventory, validation plans, legacy-pipeline
  comparison, multitaper notes

---

## Coordinate conventions (quick reference)

- After **L1** rotation: `+x` West, `+y` North, `+z` Up (buoy/MOP frame)
- After **L2** shore-normal rotation: `+x` onshore, `+y` alongshore north
- Transport sign: `q_x > 0` = onshore flux
- Pressure stored in **dBar** (raw, not converted to Pa)

Full convention notes are in `PIPELINE_NOTES.md`.

---

*Maintainer: Holden Leslie-Bole, Scripps Institution of Oceanography.*
*Questions? Open an issue.*
