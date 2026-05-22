# Nortek Vector PUV Pipeline

A MATLAB pipeline for processing **pressure + velocity (PUV)** data from
Nortek Vector current meters into quality-controlled time series, wave
spectra, and nearshore wave-forcing diagnostics.

It takes raw instrument files (`.dat`/`.sen`/`.hdr`) through five processing
levels — from QC'd time series up to nonlinear-wave / infragravity (IG)
dynamics — using a single, deployment-agnostic configuration system. Run any
deployment through the same drivers and get the same standardized output.

> **New to the repo?** Read this file first, then `docs/pipeline_levels.md`
> for the detailed level-by-level reference and `PIPELINE_NOTES.md` for design
> decisions and known issues.

---

## What it produces

| Level | Output | One-line description |
|-------|--------|----------------------|
| **L1** | QC'd 2 Hz time series | Burst merge, clock-drift + tilt correction, pitch/roll/pressure/correlation QC, rotation to buoy frame |
| **L2** | Per-segment spectra | Multi-taper PSD, pressure correction → surface elevation, bulk wave params (Hs, Tp, direction), near-bed velocity, bed/Reynolds stress, velocity moments |
| **L3** | Forcing metrics | Frequency-band energy decomposition, storm/event detection, transport proxies (Shields, Rouse), tidal + undertow current decomposition |
| **L4** | Nonlinear / IG diagnostics | Surface-elevation bands, incident/reflected IG split, bispectra (skewness/asymmetry/bicoherence), IG cross-spectra, velocity PDFs |
| **L5** | *(planned)* | PUV–altimeter integration for bed-change vs forcing |

Levels L1–L3 are universal; L4 adds nonlinear-wave/IG diagnostics on top of
L2. See `docs/pipeline_levels.md` for full per-level detail.

---

## Requirements

- **MATLAB** (developed on R2023b+). Required toolboxes:
  - **Signal Processing Toolbox** — DPSS multi-taper spectra, Welch fallback
  - **Mapping Toolbox** — `igrfmagm` for magnetic declination (IGRF-13/14)
  - **t_tide** (on the path) — tidal harmonic analysis in L3
  - *Aerospace Toolbox is **not** required* (see PIPELINE_NOTES.md)
- **Internet access at runtime** — shore-normal angle is fetched from CDIP
  THREDDS during L2 (falls back to buoy coordinates if unavailable)
- **Access to the lab server** for raw data: `/Volumes/group/PUV_data/Vector/`
  and deployment metadata: `/Volumes/group/DeploymentNotes/`

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

1. Copy an existing `config/<SITE>_config.m` as a template.
2. Fill in processing parameters from the authoritative source,
   `/Volumes/group/DeploymentNotes/DeploymentNotes{year}.xls` (lat/lon,
   heading, clock drift, sensor offset). The annual checkout spreadsheets have
   serial numbers but **not** the numerical processing parameters.
3. Register it in `config/deployment_registry.m`.
4. See `config/CONFIG_REVIEW_NOTES.md` and `config/DOFFP_LOOKUP_CHECKLIST.md`
   for deployment-specific gotchas.

---

## Repository layout

```
PUV_Pipeline/
  startup_puv.m         run first — adds all subdirs to the MATLAB path
  config/               per-deployment config functions + registry
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
*Questions? Open an issue or ask in lab.*
