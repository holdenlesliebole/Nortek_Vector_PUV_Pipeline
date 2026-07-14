# Setting up a new deployment (any site)

This guide walks you through running the pipeline on a **brand-new deployment at
any site** — including sites outside San Diego / California that have no CDIP MOP
transect (e.g. a coral-reef deployment). If you are at an existing San Diego MOP
site, most of this is automatic; the site-agnostic path is called out where it
differs.

The pipeline itself is site-agnostic. Everything site-specific lives in **one
config file per deployment**. You do not need the SIO lab server, the CDIP MOP
network, or any San Diego data to process your own deployment.

---

## 0. Prerequisites

- **MATLAB** R2023b or newer, with:
  - **Signal Processing Toolbox** (required — multi-taper / Welch spectra)
  - **Mapping Toolbox** (required — `igrfmagm` for magnetic declination; works at
    any latitude/longitude worldwide)
  - **t_tide** on the path (only for L3 tidal harmonic analysis; L1/L2/L4 do not
    need it)
- Your **raw Nortek Vector files** for the deployment: the `.dat`, `.sen`, and
  `.hdr` files (or `.VEC` exports). Put them in any folder you like.
- The **deployment metadata** you recorded in the field (see step 2).
- *Internet is only needed if you use a CDIP MOP station for the shore-normal
  angle (California sites). A manually specified angle needs no network.*

---

## 1. Add the pipeline to your MATLAB path

```matlab
>> cd /path/to/PUV_Pipeline
>> startup_puv          % adds all pipeline directories to the path
```

Run `startup_puv` once at the start of every session.

---

## 2. Gather your deployment metadata

For **each instrument** in the deployment you need:

| Field | What it is | Where it comes from |
|-------|-----------|---------------------|
| `label` | short unique name, used in output filenames (e.g. `REEF_5m`) | you choose it |
| `filePrefix` | leading characters of the raw filenames (Nortek base name) | look at your raw files |
| `rawSubfolder` | subfolder under the data root, or `''` if flat | your folder layout |
| `latlon` | `[lat lon]` in degrees (approximate is fine) | field GPS |
| `depth_nominal` | nominal water depth, m | deployment log |
| **`doffp`** | **height of the pressure sensor above the bed, in meters** | **measure in the field** |
| `heading` | instrument +x compass heading; leave `NaN` to auto-read the onboard compass | usually `NaN` |
| `clockDrift` | clock offset over the deployment, seconds; `NaN` if unknown | instrument clock check |
| `serialNum` | instrument serial number (bookkeeping) | instrument label |

**`doffp` is mandatory** — L2 errors without it, because the pressure →
surface-elevation transfer function needs the sensor elevation. Everything else
has a sensible default or auto-computes.

You also choose two deployment-level values:

- `cfg.rawDataRoot` — absolute path to the folder holding the raw files.
- `cfg.qcOpts.Tvalid` — plausible water-temperature range for your site (see
  step 4). **Set this**; do not blindly copy a San Diego range.

---

## 3. Copy the template and fill it in

```matlab
% From config/, copy the template to your site key:
%   cp config/TEMPLATE_config.m config/HIREEF25_config.m
```

Then, in `config/HIREEF25_config.m`:

1. Rename the function line to match the filename: `function cfg = HIREEF25_config()`.
2. Set `cfg.name = 'HIREEF25';`.
3. Set `cfg.rawDataRoot` to your raw-data folder.
4. Fill every field marked `<<< EDIT >>>` for each instrument.

`config/TEMPLATE_config.m` is a single-instrument reef example with inline notes
on every field. For a multi-instrument array, copy the `k = k + 1; ...` block
once per instrument (see `config/TOR24S_config.m` for a five-instrument example).

Then register it — add one line to `config/deployment_registry.m`:

```matlab
registry('HIREEF25') = @HIREEF25_config;
```

---

## 4. Set the temperature QC range (`cfg.qcOpts.Tvalid`)

L1 judges each channel independently. The **thermistor** channel is checked
against `cfg.qcOpts.Tvalid` — a plausible water-temperature range in °C. A
reading outside it flags a failed thermistor, which only affects the sound-speed
correction (velocity and pressure survive on their own).

The pipeline default `[-2 40]` is a wide safety bound that never mis-flags real
water anywhere. **Tighten it to your site** so subtler within-bounds failures are
caught:

- San Diego coastal: `[9 26]`
- Tropical reef (Hawaii): `[22 31]`

> ⚠️ **Do not copy the San Diego `[9 26]` range to a warm-water site.** Reef water
> near 27–29 °C would be flagged as sensor failure, triggering spurious
> sound-speed rescaling of otherwise-good velocities.

---

## 5. Set the shore-normal angle (the one real site-specific choice)

L2 rotates buoy-frame velocity (`+x` West, `+y` North) into a **shore-normal
frame** (`+x` onshore, `+y` alongshore-north). This rotation drives the
cross-shore / alongshore current decomposition (L3) **and** the
incident/reflected infragravity split (L4). There are two ways to supply it:

### Option A — manual angle (any site without CDIP/MOP)

Set one field in the config:

```matlab
cfg.instruments(k).shorenormal = 200;   % degrees
```

`shorenormal` is the **compass bearing (0 = North, 90 = East) of the
offshore-pointing shore normal** — i.e. the direction pointing seaward,
perpendicular to the local depth contours. Get it from:

- a bathymetry chart or satellite image: draw the local isobath, take the
  perpendicular pointing offshore, read its bearing; or
- the dominant shore-normal swell approach direction at the site.

A rough value (±5°) is fine for bulk parameters; be more careful if the
incident/reflected split matters, since it depends on the cross-shore axis.

### Option B — CDIP MOP station (California sites only)

Instead of `shorenormal`, set:

```matlab
cfg.instruments(k).mopStation = 'D0580';
cfg.instruments(k).mopLine    = 580;
```

L2 then fetches the shore-normal angle live from the CDIP THREDDS server (needs
internet). This only works at San Diego / California MOP transects.

> If you set **neither**, L2 leaves velocity in buoy coordinates
> (`shorenormal = NaN`) and the L4 incident/reflected split is skipped. A manual
> angle (`shorenormal` finite) always takes precedence over `mopStation`.

---

## 6. Run the levels in order

Set `deployment_name` at the top of each driver to your key, then run L1 → L4:

```matlab
% (optional) stage raw files locally first — faster than repeated reads:
>> reg = deployment_registry(); configFn = reg('HIREEF25'); cfg = configFn();
>> copy_raw_to_local(cfg);          % copies into raw_cache/HIREEF25/ if desired

% Then, editing deployment_name = 'HIREEF25' at the top of each:
>> PUV_L1_driver     % raw -> QC'd 2 Hz timeseries   (outputs/L1/HIREEF25/)
>> PUV_L2_driver     % spectra + bulk wave params    (outputs/L2/HIREEF25/)
>> PUV_L3_driver     % forcing / currents            (outputs/L3/HIREEF25/)
>> PUV_L4_driver     % nonlinear-wave / IG dynamics  (outputs/L4/HIREEF25/)
```

Each level reads the previous level's `.mat` files and errors clearly if they're
missing, so always run in sequence. `PUV_L2_driver` also runs a couple of
MOP-specific validation figures — those are **skipped automatically** when there
is no `mopStation`, which is expected at a non-California site.

---

## 7. What is San-Diego-specific and safe to ignore

These pieces assume the San Diego MOP/CDIP network and simply **no-op** at other
sites (they never crash the run):

- **MOP storm context** (`L3_forcing/PUV_L3_storms.m`) — pulls external MOP
  hourly wave conditions via `read_MOPline2` (an SIO/CDIP toolbox function you
  will not have). Wrapped in try/catch: storm detection falls back to PUV-only.
- **Bound-wave / directional-spread validation figures** in `PUV_L2_driver` —
  gated on `mopStation`; skipped when absent.
- **Per-site grain size** (`shared/site_grain_size.m`) — a table of San Diego
  sand samples. If your site label has no entry, L2 falls back to a default
  `D50` (0.25 mm) for the bed-stress estimate. **Sediment-transport proxies (L3
  transport: Shields, Rouse) assume a sandy, movable bed with quartz density
  `rho_s = 2650`** — they are not physically meaningful over a rough carbonate
  reef, so ignore L3 transport outputs there (L1/L2/L4 are unaffected). To use a
  real grain size, add an entry to `site_grain_size.m` for your label.

---

## 8. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `doffp is NaN … fill from ... before running L2` | set `cfg.instruments(k).doffp` (pressure-sensor height above bed, m) |
| Warning: *"No shore-normal angle available — processing in buoy coords"* | set `cfg.instruments(k).shorenormal` (or `mopStation` for CA); see step 5 |
| L4 reflection output is empty | `L2.shorenormal` is `NaN` — supply a shore-normal angle (step 5) and re-run L2 |
| Lots of `qc_flag == 4` on temperature; velocities rescaled | `Tvalid` too narrow for your site — widen it (step 4) |
| `Undefined function 'igrfmagm'` | install / license the **Mapping Toolbox** |
| Raw files not found | check `cfg.rawDataRoot`, `rawSubfolder`, and `filePrefix` against your actual filenames |

---

*See `README.md` for the pipeline overview, `docs/pipeline_levels.md` for the
per-level reference, and `docs/PUV_Pipeline_Guide.pdf` for the full methods
writeup.*
