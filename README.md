# Nortek Vector PUV Pipeline

A MATLAB pipeline that turns raw **pressure + velocity (PUV)** records from
Nortek Vector current meters into quality-controlled 2 Hz time series (L1),
hourly wave spectra and bulk parameters (L2), wave-forcing and transport
proxies (L3), and nonlinear-wave and infragravity (IG) diagnostics (L4).
Everything site-specific lives in one config file per deployment, so the same
drivers run any deployment.

The San Diego catalog it was built for holds 65 instrument-records from 46
deployments (2014-2026), published on the SIO group share as catalog version
**2026-10-14.1**.

Where to read next:
- `docs/NEW_DEPLOYMENT.md`: running your own deployment at any site.
- `docs/pipeline_levels.md`: the level-by-level reference and current status.
- `PIPELINE_NOTES.md`: why each processing choice was made.
- `CHANGELOG.md`: code changes, newest first.
- `docs/PUV_Pipeline_Guide.pdf`: the long-form methods writeup. It was last
  rebuilt on 2026-07-24 and does not describe the 2026-10 changes listed in
  `CHANGELOG.md`.

---

## What it produces

| Level | Output | Contents |
|-------|--------|----------|
| **L1** | QC'd 2 Hz time series | per-file bursts, clock drift and offset, tilt correction, **per-channel** QC (velocity, pressure, temperature, tilt judged independently), sound-speed correction, rotation to the buoy frame with magnetic declination |
| **L2** | hourly segments | multitaper spectra, pressure correction to surface elevation, Hs/Tp/direction, near-bed velocity, bed and Reynolds stress, velocity moments, P-U consistency diagnostics |
| **L3** | forcing metrics | band energy (IG, swell, sea), storm events, transport proxies (Shields, settling velocity, Rouse, mobilization), tidal and subtidal currents |
| **L4** | nonlinear and IG diagnostics | eta in three bands, incident/reflected IG split, bound/free IG separation, bispectra, frequency-resolved moments, velocity PDFs; `L4_xspec` holds pairwise IG cross-spectra for multi-instrument deployments |
| **L5** | *(planned)* | PUV-altimeter merge for bed change against forcing |

L1-L4 need no altimeter data. Outputs land in
`outputs/L{1..4}/<deployment>/<label>_*.mat` and `outputs/L4_xspec/<deployment>/xspec.mat`.

---

## Requirements

**MATLAB R2025a** (development and testing; earlier releases are untested) with:

| product | needed for | |
|---|---|---|
| Signal Processing Toolbox | DPSS multitaper spectra and `cpsd` (L1 QC, L2, `L4_xspec`) | required |
| Aerospace Toolbox | `igrfmagm`, the IGRF magnetic declination applied at L1 | required |
| Parallel Computing Toolbox | `PUV_L4_bispectra` with `opts.useParallel = true` (used by `PUV_L4_run_all`) | optional; the serial path gives bit-identical results |

These are what `matlab.codetools.requiredFilesAndProducts` reports for the L1-L4
drivers, modules, `copy_to_server` and the provenance code (scan of
2026-10-14, run with a clean path). Mapping Toolbox and Statistics and Machine
Learning Toolbox are not needed by L1-L4; a few standalone `validation/`
analysis scripts use the latter.

Network access is needed only for: a CDIP MOP station as the shore-normal
source (`instr.mopStation`, California), a CDIP offshore reference
(`instr.refStation`), and the NOAA tide predictions used at L3.

Raw data can be either the ExploreV ASCII export (`.dat`/`.sen`/`.hdr`) or the
recorder binary (`.VEC`/`.vec`/`.049`), which `L1_raw_to_qc/read_VEC.m`
decodes. ExploreV and Windows are not required. Point `cfg.rawDataRoot` at any
folder; the bundled San Diego configs point at
`/Volumes/group/PUV_data/Vector/`.

### External dependencies (not in this repository)

L1, L2 and L4 use only files in this repository. **L3 needs 11 files from
outside it.** The list is kept in `shared/external_deps.m`, and every L3
provenance sidecar records the path and SHA-256 of each one as used.

| file(s) | from | used by |
|---|---|---|
| `t_tide.m`, `t_predic.m`, `t_astron.m`, `t_getconsts.m`, `t_vuf.m`, `t_constituents.mat`, `t_equilib.dat`, `tide3.dat` | **t_tide version 1.3** (header revision 29/9/14), R. Pawlowicz, B. Beardsley and S. Lentz (2002), *Computers & Geosciences* 28, 929-937, distributed by the author (UBC EOAS, "T_TIDE harmonic analysis toolbox") | `PUV_L3_currents` tidal fit |
| `read_MOPline2.m` | the SIO Coastal Processes lab MATLAB `toolbox/` (not public; ask the lab) | CDIP MOP reader behind `cdip_station_reference` (`PUV_L3_storms`) |
| `get_k.m`, `xyRotate.m` | helpers it calls | |

t_tide is not redistributed here because its license is informal. Put it on
the MATLAB path yourself. If it is not on the path, `PUV_L3_currents` adds
`~/Documents/Scripps/Research/toolbox/t_tide_v1.3/`, and `PUV_L3_currents` and
`PUV_L3_storms` add `~/Documents/Scripps/Research/toolbox/` for the lab
functions. Those fallback folders match the lab layout; elsewhere, add the
folders to your path before running L3.

What happens without them:
- No t_tide: `PUV_L3_currents` **stops with an error** pointing here. Pass
  `opts.allowNoTides = true` to build an L3 without tidal and subtidal
  currents on purpose.
- No lab toolbox: no MOP storm reference (recorded as a fallback in
  provenance). The NOAA tide no longer needs the toolbox.

NOAA tide predictions come from `shared/noaa_tide_predictions.m` (the same
request the toolbox `getztide2.m` made, with the station as an argument) at the
config's `cfg.tideStation`, and are needed for every L3. A failed download is an
error unless `opts.allowTtideFallback = true`, which falls back to a t_tide fit
of the record (`L3.tidal.depth_source = 't_tide'`, recorded as a fallback). A
config with no `tideStation` gets La Jolla 9410230 if its instruments lie in San
Diego County, and an error anywhere else. The station used is stored in
`L3.tidal.station` and in the L3 provenance.

---

## Quick start

```matlab
>> cd /path/to/PUV_Pipeline
>> startup_puv            % adds the repo to the path (not outputs/, raw_cache/, .git/, .claude/)

% optional: cache the raw files locally (network reads are slow)
>> reg = deployment_registry(); f = reg('TBR23'); cfg = f();
>> copy_raw_to_local(cfg);           % -> raw_cache/TBR23/

% each driver has deployment_name = '...' at the top; set it, then run in order
>> PUV_L1_driver          % outputs/L1/TBR23/
>> PUV_L2_driver          % outputs/L2/TBR23/
>> PUV_L3_driver          % outputs/L3/TBR23/
>> PUV_L4_driver          % outputs/L4/TBR23/
>> PUV_L4_xspec_driver    % outputs/L4_xspec/TBR23/ (two or more instruments)
```

`PUV_L1_run_all` ... `PUV_L4_run_all` and `PUV_L4_xspec_run_all` process every
registered deployment and skip records whose output already exists.
`PUV_L4_run_all` leaves out `bispectra` by default (`runBispectra = false`,
the slow module) and says so at the end.

Every driver keeps going when one record fails, then **ends with an error**
naming each config that threw and each record it did not write, so
`matlab -batch` exits nonzero. Seven of the 72 configured records have no L1
because the instrument failed in the field. Their configs flag them
(`instruments(k).knownFailed = '<cause>; <source>'`), and the drivers skip them
with a `KNOWN FAILED` line, so the error means a new failure.
`validation/audit_registry_loads.m` lists them as known.

Every file the drivers write carries provenance (an embedded `prov` field and a
`<file>.prov.json` sidecar), the same stamp as the catalog rebuild; see
"Provenance and the published catalog".

---

## Configuring a deployment

`config/deployment_registry.m` maps a name to its config function; 50 names
are registered (`TOR23S` is an alias of `TBR23`). Names follow
`SITE + year + optional season letter`; `TBR23` is the one legacy exception
(the Torrey Pines Beach Recovery 2023 campaign).

To add a deployment (full walkthrough in `docs/NEW_DEPLOYMENT.md`):

1. Copy `config/TEMPLATE_config.m` to `config/<NAME>_config.m` and rename the
   function.
2. Per instrument: `label`, `filePrefix`, `rawSubfolder`, `latlon`,
   `depth_nominal`, **`doffp`** (pressure-port height above the bed, m;
   required), `heading`, and a shore-normal source.
3. Set `cfg.qcOpts.Tvalid` to the site's water-temperature range, in the
   config (San Diego coastal `[9 26]`; the default `[-2 40]` only catches
   gross failures). L1 and L3 both read it. Set `cfg.tideStation` to the
   nearest NOAA CO-OPS harmonic station (San Diego configs: `'9410230'`, La
   Jolla); L3 errors without it outside San Diego County. An instrument that
   failed in the field stays in the config with
   `knownFailed = '<cause>; <source>'`, so the drivers skip it.
4. Put the **source of every `doffp`, `latlon`, `heading` and `shorenormal`
   on the same line** as a comment: workbook, sheet, row, serial number and the
   cell's wording. `validation/audit_config_provenance.m` lists the values that
   have none.
5. Heading: leave `NaN` (onboard compass median) unless the compass drifts or
   steps at constant tilt; then use the logged mount heading. A record whose
   log and compass differ by more than 10 deg, kept on the compass, goes in
   `shared/heading_disputed_records.m`.
6. Register it in `config/deployment_registry.m`, then run
   `validation/audit_registry_loads.m`. It is the one check that does not
   swallow a config that throws.

Shore-normal: `instr.shorenormal = <deg>` (offshore-pointing bearing, 0 = N,
90 = E; any site; takes precedence) or `instr.mopStation = 'D0580'` (fetched
from CDIP, California). With neither, velocity stays in buoy coordinates and
the L4 incident/reflected split is skipped. An offshore reference for
validation figures and storm context is optional: `instr.refStation` with a
CDIP buoy id (`'233p1'`, any site) or a MOP point (`'D0580'`).

San Diego users: `doffp`, heading, coordinates and clock drift come from
`/Volumes/group/DeploymentNotes/*.xls`; `config/DOFFP_LOOKUP_CHECKLIST.md`
lists where to look and the traps (rows labeled only "Redeploy", `doffp`
quoted to the altimeter face).

---

## Coordinates and units

- After L1: `+x` West, `+y` North, `+z` Up (buoy/MOP frame), true north.
- After L2 rotation: `+x` onshore, `+y` alongshore north. `q_x > 0` is onshore.
- Pressure in dBar; depths in m; times UTC.
- Heading in configs: degrees magnetic; the IGRF declination is added at L1.

---

## Quality control

L1 judges each channel on its own, so a dead thermistor or pressure sensor does
not discard good velocity. Each L2 segment carries:

- `segValid`: all channels good.
- `segValid_vel` / `segValid_p`: velocity or pressure products usable.
- `qc_flag`: 1 good, 2 not evaluated, 3 suspect (recovered or sound-speed
  rescaled), 4 fail. Anything reconstructed is 3, never 1.
- `Hs_source`: `'measured'`, `'reconstructed'` or `'none'`.

At L4 these travel per burst as `puv_qc_flag`, `puv_segValid_vel`,
`puv_segValid_p`. `L2.qc_record` holds a record-level Z-test flag (pressure
against velocity-predicted pressure); it marks a record and drops nothing.
Two records are excluded from reported statistics at reporting time
(`shared/excluded_records.m`: RUBY22/MOP582_30m, over-ranged pressure sensor;
RUBY22/MOP579_6m).

---

## Provenance and the published catalog

**Sidecars.** Each output file built by the catalog rebuild carries a
provenance block, embedded as a `prov` field and written beside it as
`<file>.prov.json` (`shared/build_provenance.m`, `shared/write_prov_sidecar.m`).
It records a `build_id`, the git commit and whether the tree was dirty, where
each key function resolved, the parents' `build_id`s, the external files with
their SHA-256, the physical choices applied (for L3: D50 and its source,
settling-velocity constants, viscosity model, `Tvalid`, tidal source), any
fallback taken, and the SHA-256 of the saved bytes. As of catalog 2026-10-14.1:
65 L2, 65 L3, 65 L4 and 9 `L4_xspec` sidecars written at build time; the 65 L1
sidecars were backfilled (`scripts/backfill_provenance.m`) and say so in their
`backfilled` field.

**The drivers stamp too (from 2026-10-15).** `PUV_L*_driver`,
`PUV_L*_run_all`, `PUV_L4_xspec_driver` and `PUV_L4_xspec_run_all` save
through `shared/save_with_provenance.m`, which writes the same embedded block
and sidecar, with parents linked by `build_id` (L2 from L1; L3 and L4 from L2;
xspec from every member L4). Their outputs pass the provenance gate like the
catalog's (`validation/test_driver_provenance.m`). The 2026-10-14.1 catalog
itself was built with `scripts/rerun_heading_ws_2026_10_07.m` (stages
`combined` and `xspecprov`), driven by `scripts/run_L4_refresh_watchdog.sh`.
A checkout without `.git` (a zip download) records `git_hash = 'unknown (no
git)'`; `check_prov` SOFT-refuses such a file until a change entry
acknowledges its level.

**Server catalog.** `/Volumes/group/PUV_data/Vector/Processed_HLB/`, laid out
`<DEPLOYMENT>/Level{1,2,3,4}_QC/<label>_*.mat` plus `L4_xspec`, each with its
`.prov.json`. Alongside: `manifest.csv` (one row per file: size, `sha256`,
`build_id`, `git_hash`, `backfilled`, `catalog_version_first`), `manifests/`
(every previous manifest), `CHANGELOG.md` (what changed in each catalog
version), and a generated `README.md`. Catalog versions are `YYYY-MM-DD.N`.

**Telling an old copy from a new one.** Compute the SHA-256 of your copy and
look it up in `manifest.csv` or `manifests/manifest_<version>.csv`; the row
names the catalog version it first appeared in. Inside an L3 from 2026-10-14.1,
`transport_params.ws_C1 == 20`, `ws_C2 == 1.1`, and `L3.nu`, `L3.T_used` and
`L3.tidal.ttide_rng` exist. Any 2026-10-14.1 L2-L4 file has a sidecar whose
`backfilled` field is empty.

**Publishing.** `scripts/copy_to_server.m` checks each file with
`shared/check_prov.m` before copying. HARD refusals: no provenance; bytes that
differ from the sidecar's SHA-256; a config or derived value that no longer
matches; a parent rebuilt since (built from a superseded parent). SOFT
refusals, cleared by a pending change entry: the level's code changed since the
build commit, an external dependency changed, a recorded fallback, uncommitted
code. Any file whose bytes differ from the server manifest must be named by a
pending entry in `docs/catalog_changes/`. The code check is by directory
(for L3: `L3_forcing/`, `L3_transport/`, `shared/`), so even a driver-only edit
SOFT-refuses every file of that level at the next push until an entry
acknowledges it. Refused files that already exist on the server stay there.

**No external writes into `outputs/`.** Only this pipeline writes
`outputs/`. Another repository, notebook or hand edit that rewrites an output
in place makes its bytes disagree with its sidecar, and the push refuses it.
To change an output, change the code or config here and rebuild. Rule and
entry format: `docs/catalog_changes/README.md`.

---

## Tests

```matlab
>> startup_puv
>> run_all_tests                         % self-contained tests
>> run_all_tests('includeData', true)    % also tests that read outputs/, the server or the network
```

or from a shell, exiting nonzero on any failure:

```
matlab -batch "cd /path/to/PUV_Pipeline; startup_puv; run_all_tests"
```

`validation/run_all_tests.m` runs 23 tests (synthetic closure tests in
`L1_raw_to_qc/`, `L2_spectral/` and `validation/`, plus a shell test of the
watchdog with a stand-in for MATLAB), prints PASS, FAIL or SKIP per test and
the total, and lists the tests it did not run with the reason. Three tests
(`test_provenance`, `test_fillmissing_endvalues`, `test_l3_tide_station`) need the L3 external files
and are skipped, not failed, when any is missing from the path. It never runs
the three tests that write into `outputs/validation/`.

Use plain `matlab -batch` when the exit code matters: on R2025a under macOS,
`matlab -nodisplay -batch "<command>"` exits 0 even when the command errors
(checked 2026-10-14 with `error('t:x','boom')`).

After touching configs or rebuilding, also run the audits:
`validation/audit_registry_loads.m` (every config builds),
`validation/audit_L1_qcopts.m` (stored L1 QC options match the configs),
`validation/audit_L4_coverage.m` (every L4 complete, aligned to and consistent
with its L2), `validation/audit_config_provenance.m` (geometry values without a
source), `scripts/audit_clock_lag.m` (filename-clocked records at lag 0 against
the tide). These read `outputs/`.

---

## Known limitations

- **Disputed headings.** 12 records keep a compass heading that differs from
  the logged mount heading by more than 10 deg: TOR14B, TOR14C, TOR15A, TOR15D,
  TOR17B, TOR17D (MOP591_9m), COR17D/MOP158_9m, CDF15A and CDF15C (MOP677_9m),
  TOR24W/MOP586_10m, TOR25S/MOP586_15m and SIO25E/SIO_6m. Their directional
  quantities (mean direction, Sxy, current direction) are uncertain by at least
  that much; see `shared/heading_disputed_records.m`.
- **Grain size.** 42 of 65 records use the 250 um placeholder D50, 4 an
  assumed site default (217.4 um) and 19 a measured distribution (tally of the
  L3 sidecars, 2026-10-14). Bed stress, Shields, mobilization, settling
  velocity and Rouse on the placeholder records will move when measured values
  arrive; L4 does not depend on D50.
- **Settling velocity.** Ferguson & Church (2004), C1 = 20, C2 = 1.1, chosen
  from the measurement method; six formulas could not be distinguished against
  the TBR23 surveys, and they spread about +-15% at 250 um.
- **`doffp` is fixed per deployment.** The bed can move tens of cm during a
  deployment (logged changes up to 23 cm). This moves depth and depth-normalized
  quantities (Hs/h, Ursell) by about 3% and bed stress by under 0.3%. IB18W and
  IB19S carry `doffp` values whose source is unknown.
- **Off-bed pressure QC is off.** The vertical-transit detector in
  `puv_channel_qc` stays off until the next deliberate L1 rebuild, so descent
  samples can pass pressure QC (SIO24A: 61 s at 3.1 dBar at a 6 m site). No L2
  segment in the catalog is affected.
- **Catalina tidal depth is La Jolla's.** CAT21A/B set `tideStation =
  '9410230'` (as built), 110 km away; the nearest NOAA harmonic station is
  9410079 Avalon. Over the CAT21A record the two predictions differ by 2.8 cm
  rms (max 8 cm). Switching needs an L3 rebuild and a change entry.
- **Unsourced geometry.** 69 `doffp`/`latlon`/`shorenormal` values carried no
  on-line source at the last audit (2026-07-28). Treat them as unverified.

---

## Repository layout

```
PUV_Pipeline/
  startup_puv.m     run first; adds the repo to the MATLAB path
  config/           per-deployment configs, registry, TEMPLATE_config.m
  L1_raw_to_qc/     raw files -> QC'd 2 Hz time series
  L2_spectral/      spectra, bulk wave parameters, bed velocity and stress
  L3_forcing/       bands, storms, transport proxies, currents
  L3_transport/     paper-specific transport-model wrappers
  L4_ig/            nonlinear-wave and IG diagnostics, cross-spectra
  shared/           functions used across levels, provenance, external_deps
  validation/       tests (test_*), audits (audit_*), model-comparison analyses
  scripts/          one-off and catalog-maintenance scripts (see below)
  docs/             references, catalog change entries, historical run logs
  raw_cache/        local raw copies (ignored by git)
  outputs/          processed outputs (ignored by git)
```

`scripts/` is not the supported pipeline. It holds the catalog rebuild
(`rerun_heading_ws_2026_10_07.m`, `run_L4_refresh_watchdog.sh`), the server
push (`copy_to_server.m`), and many dated one-off diagnostics. Several of those
carry absolute paths from the maintainer's machine and will not run elsewhere
unchanged. `scripts/archive/` holds retired scripts that nothing cites.

---

*Maintainer: Holden Leslie-Bole, Scripps Institution of Oceanography. Questions: open an issue.*
