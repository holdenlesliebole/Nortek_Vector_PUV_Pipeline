# PUV Pipeline Processing Levels

Updated: 2026-10-14

> **Current state, 2026-10 (catalog version 2026-10-14.1).** All 65 records
> were rebuilt at L2-L4 on 2026-10-12/14 from one code version, plus all 9
> `L4_xspec` files. L1 was not rebuilt in that pass. What changed, by level:
>
> - **L1.** ENU records now add the magnetic declination (about 11.07 deg at
>   San Diego; SOL24, LPL24, LPL25A rebuilt 2026-10-07). Nine XYZ records whose
>   compass drifts or steps at constant tilt take the field-log mount heading
>   (COR16B, TOR16A-D, TOR17A, TOR17C, TOR24S/MOP586_5m and _7m), and SIO24A
>   is decoded from `.VEC`; those 10 were rebuilt L1-L4 on 2026-10-07. Twelve
>   other records whose logged and compass headings differ by more than 10 deg
>   keep the compass value and are listed in `shared/heading_disputed_records.m`.
>   A vertical-transit (off-bed) pressure detector exists in
>   `puv_channel_qc` but is OFF until the next deliberate L1 rebuild.
> - **L2-L4.** Gap fills no longer extrapolate past a segment edge
>   (`fillmissing ... 'EndValues','nearest'` at every site). In the catalog L2
>   Hs moved by at most 3.5 cm except one segment (IB19S/MOP045_7m,
>   2019-04-22 19:30, 15.6 cm); Ub and u_rms moved about 4% median and 25% at
>   the 95th percentile on edge-gap segments.
> - **L3.** Settling velocity uses Ferguson & Church (2004) nominal-diameter
>   constants (C1 20, C2 1.1); viscosity comes from each segment's measured
>   temperature (`shared/seawater_nu`); Rouse numbers are also given at D16,
>   D50 and D84 where a measured grain-size distribution exists. Settling
>   velocity fell 8-24% (median 16%) across the 65 records. t_tide is seeded,
>   so tidal and subtidal currents are reproducible.
> - **L4.** 29 L4 files built from superseded L2s were rebuilt on 2026-10-08;
>   `validation/audit_L4_coverage.m` now checks content (L4.eta.depth against
>   L2.depth), not only time alignment.
> - **Provenance.** Every L2, L3, L4 and xspec file carries a sidecar
>   `<file>.prov.json` written at build time; the 65 L1 sidecars were
>   backfilled and say so. See README "Provenance and the published catalog".
>
> Numbers above are from `docs/catalog_changes/2026-10-13_combined_rebuild.md`
> and the 2026-10-07/08 entries in `docs/todo.md`. The two July blocks below
> are kept as the record of those fixes; their "complete and verified" status
> lines describe the catalog as it stood in July.

> **2026-07-28 (historical): timestamps and site geometry corrected. Read this before
> using any pre-2023 record or any `L4_xspec`.**
>
> - **L1 timestamps.** The clock recovered from `MMDDHHMM` filenames was Pacific
>   **local**, not UTC. All 19 `clockSource='filename'` records were 7–8 h out of
>   phase against the NOAA tidal reference. `instr.clockOffsetHours` now converts
>   them; 18 records were rebuilt L1→L4 and every one re-audits at lag 0
>   (`scripts/audit_clock_lag.m`, R = 0.92–0.999). Bulk statistics were never
>   affected — only the time axis, and anything joined on it.
> - **`LATLON` on 23 records** was a hand-placed approximation, up to 925 m out.
>   Corrected from the surveyed field logs. This changes **no measurement**: the
>   only consumer is `PUV_L4_xspec.m:205`, which derives pair separations from it.
>   `L4_xspec` was rebuilt for `RUBY22`, `TOR24S`, `TOR24W`, `TOR25S`;
>   separations moved −50% to +53% while per-pair coherences are unchanged to
>   four decimals. **Redo any coherence- or phase-versus-separation result from
>   those four**; nothing else is affected.
> - **`TOR18A`** was registered and fully processed but absent from every
>   registry-driven audit for a day, because its config threw and every loop
>   swallows that with `catch, continue`. Its data was correct. Guard added:
>   `validation/audit_registry_loads.m`.
> - **The 17-min archive is gone** (deleted from the server 2026-07-28).
>   `validation/compare_seglen_phase2.m` will not run until a 17-min L2 is
>   regenerated from current L1.
>
> Catalog re-verified after all of the above: 65 records, 0 missing
> sub-products, 0 stripped metadata, 0 alignment problems, 50/50 configs
> building.

> **2026-07-26 (historical): L4 repaired and re-verified.** Two defects found on 07-26 are
> fixed: `bispectra` was missing on 23 of 65 records, and 3 records
> (SIO25B/SIO_6m, TOR24S/MOP586_7m, TOR24W/MOP586_10m) had an L4 built against a
> superseded L2 whose segment grid had gained a leading segment. Both traced to
> the same cause — L4 built against a different L2 snapshot — not to a bug in any
> L4 module. `validation/audit_L4_coverage.m` now reports all 65 records complete
> and time-aligned. Full account in `docs/todo.md`.

**Catalog size:** 65 instrument-records across 46 deployments, present at
every level L1–L4; 9 deployments also carry `L4_xspec`. Audits on 2026-10-14:
L4 content against L2 65/65, L1 qc.opts against config 65/65, registry 50/50
configs building. The "33/40"
figures that appeared in earlier revisions of this file predate the pre-2023
archive additions (CAT21A/B, RUBY22, IB18W, IB19S, then TOR19W/TOR20W/IB19W) and
have been updated in place below.

**Why 65 and not 72.** The registry configures **72** instrument-records; 7 have
no L1/L2 because the instrument genuinely failed in the field, so the catalog is
65. Each config flags them with `instruments(k).knownFailed` (cause and
source), and since 2026-10-15 the drivers skip them with a `KNOWN FAILED` line
instead of counting them as failures; `validation/audit_registry_loads.m` lists
them as known. Each is documented with its cause in
`docs/deployment_database_overview.md`:

| record | cause |
|---|---|
| SIO24B/SIO_6m | knocked over, 32° tilt, beam corr <10% |
| SIO24C/SIO_6m | battery depleted, no valid pressure |
| SIO25A/SIO_6m | started upside-down, pin corrosion |
| SOL23/MOP651_5m | battery depleted; instrument lost 2 yr, pipe bent |
| TOR24S/MOP586_15m | pipe issues, no valid pressure |
| TOR24W/MOP586_5m | pipe bent by kelp, too buried to recover |
| TOR25S/MOP586_5m | pipe bent, kelp blockage |

**`outputs/` may hold more than the catalog.** `TOR20A/MOP591_9m` has L2 and L3
on disk from an exploratory run but is deliberately **not registered** (timing
unvalidatable — see `docs/recopied_data_backlog.md`). Anything that enumerates
records by globbing `outputs/L*/*/` rather than by
`deployment_registry()` will pick it up. `scripts/copy_to_server.m` carries a
registry guard for exactly this reason.

## Design Philosophy

Each level transforms data from the previous level into higher-order products.
Levels L1–L3 are **universal** — they produce the same outputs regardless of
the scientific question. L4 builds nonlinear-wave and IG diagnostics on top
of L2. L5 (planned) merges with external altimeter data for transport
estimation.

All levels are deployment-agnostic: run any deployment through L1→L2→L3 and
get the same standardized output struct.

---

## L1: Raw → QC'd Timeseries (COMPLETE)

**Input:** Raw Nortek files — either the ExploreV ASCII export
(`.dat`/`.sen`/`.hdr`) or the raw recorder binary (`.VEC`/`.vec`/`.049`),
selected by `instr.rawFormat` or auto-detected. See `L1_raw_to_qc/read_VEC.m`.
**Output:** Continuous 2 Hz time series with QC flags applied

- Burst merging, clock drift correction
- `instr.clockOffsetHours` — Pacific local → UTC on filename-clocked records
  (see PIPELINE_NOTES; the offset is baked in here, so changing it needs an
  L1 rebuild)
- Variability-based tilt QC + tilt correction rotation
- Pitch/roll/pressure/correlation QC
- Coordinate rotation to buoy frame (+x West, +y North, +z Up). XYZ records:
  true bearing of +x = heading + declination (IGRF, `igrfmagm`). ENU records
  (2026-10-07): Nortek ENU is magnetic, so `enu_to_buoy_frame` adds the
  declination; `PUV.rotation.coordSystem` and `.declinationApplied` stamp which
  path ran, so a pre-fix ENU L1 is detectable.
- Heading source (2026-10-07): the config `heading` is the field-log mount
  heading where the compass drifts or steps at constant tilt, else NaN (compass
  median). Records with log and compass more than 10 deg apart are listed in
  `shared/heading_disputed_records.m` (12 of 45 with a usable log value);
  directional analyses exclude them or report both.
- QC options come from `l1_qc_opts(cfg)` and are stored at `PUV.qc.opts`;
  `validation/audit_L1_qcopts.m` compares them with the config. The off-bed
  detector (`cfg.qcOpts.offBedDbar`) is absent from every config, so OFF.
- Output struct: `PUV.{time, P, BuoyCoord, InstrCoord, T, ...}`

**Status (2026-10-14):** 65 records. 10 rebuilt on 2026-10-07 (9 heading
records, SIO24A) and 3 ENU records the same day; the rest date from the July
reruns. L1 provenance sidecars are backfilled (built before stamping existed).
**Status (July 2026, historical):** Complete and verified. 65 instrument-records processed across 46
deployments. Records that were dropped are documented hardware failures
(battery, tilt, kelp, corrosion), correctly rejected — not a bug. See `todo.md`
"Verified L1 QC behavior" for the per-instrument explanations.

---

## L2: Spectral Analysis (COMPLETE)

**Input:** L1 `.mat` files
**Output:** Per-segment spectral products

- **Segmentation: 7200 samples = 1 hour @ 2 Hz, non-overlapping**, aligned
  to UTC top-of-hour boundaries (matches MOP/CDIP cadence). Legacy 17-min
  (2048-sample) segments can be re-enabled by passing `opts.segLen = 2048`.
- Multi-taper PSD (DPSS, NW=4, K=7 tapers) via `shared/psd_multitaper.m`;
  same tapers used for auto- and cross-spectra so directional coefficients
  are consistent (this was a critical bug in the legacy pipeline — see
  `pipeline_comparison_legacy.md`)
- Pressure correction → surface elevation spectrum (Wu correction, Kp
  zeroed below 0.1 rather than capped)
- Shore-normal rotation via `apply_shorenormal_rotation` (`L2.shorenormal`
  cached so L4 modules don't re-hit CDIP THREDDS)
- Bulk wave parameters: Hs, Tp, Tm02, mean direction, energy flux
- Near-bed velocity via IFFT transfer function
- Bed stress (Swart 1974)
- Reynolds stress, TKE
- Velocity moments (skewness, asymmetry via Hilbert transform, |u|³,
  u·|u|², a², a³, a_spike) via `shared/compute_velocity_moments.m`
- Mean currents per segment (uMean, vMean)
- Gap filling within a segment holds the edge value (`'EndValues','nearest'`,
  2026-10-09); before, a NaN run at a segment edge became a linear ramp, which
  inflated IG and velocity statistics (synthetic 400-sample edge gap: L4 IG
  variance about 70x, L2 velocity rms about 6x; `validation/test_fillmissing_endvalues.m`)
- QC diagnostics: nanMaxFrac=0.10 rejection; per-segment Z (pressure vs
  velocity-predicted pressure) and Q (P–U coherence)
- **Record-level Z flag** (2026-07-27): `L2.qc_record.ztest_SS/_IG` via
  `shared/ztest_record_flag.m`, warning on failure. A flag, not a gate — it
  never drops segments. Sweep the catalog with
  `validation/audit_ztest_records.m`, which works on existing L2 files and
  needs no rebuild. Currently 1 flagged (`RUBY22/MOP582_30m`, dead pressure
  transducer, median Z = 8.9e-05), 2 too thin to judge, 62 passing at median
  Z = 0.9738.

**Status (2026-10-14):** 65 records rebuilt 2026-10-12/14 with the edge-gap
fix, each with a provenance sidecar.
**Status (July 2026, historical):** Complete, verified 8/8 product checks, 65 instrument-records
processed at 1-hour cadence. Output: `outputs/L2/{deployment}/{label}_L2.mat`.

---

## L3: Wave Forcing Characterization (COMPLETE)

**Input:** L2 `.mat` files
**Output:** Per-segment derived forcing metrics + deployment summaries

### L3a — Frequency-Band Energy Decomposition
- Energy flux by band: F_ig, F_swell, F_sea, F_total per segment
- Band definitions: IG [0.004–0.04], swell [0.04–0.10], sea [0.10–0.25] Hz
- Band-averaged Hs: Hs_ig, Hs_swell, Hs_sea
- Dominant-band flag per segment

### L3b — Storm/Event Detection
- Storm events from Hs time series (threshold + duration)
- Event metrics: peak Hs, duration, total energy, cumulative flux
- Calm-period identification (recovery windows)
- MOP gap-filling for missing PUV hours

### L3c — Transport Proxies
- Bottom energy flux Fb = ρg·cg·Ub² (spectral integral)
- Shields parameter time series (configurable D50), from the **wave** stress
  amplitude `L2.tau_b` — the correct quantity for wave mobilization
- Wave-current combined bed shear stress (Soulsby 1997): `tau_c`, `tau_m`, `tau_max`
- Rouse number time series, computed from **`tau_m`**, the mean combined stress
- Mobilization fraction (% time above critical Shields)
- Cumulative bottom energy flux
- Per segment (2026-10-09): kinematic viscosity `L3.nu` from the segment's
  `L2.Tmean` (`shared/seawater_nu`, Sharqawy et al. 2010, S = 33.5 psu); a
  segment outside `opts.Tvalid` or NaN takes the record median, a record with
  no usable temperature takes 17 C (counted in `transport_params.T_source`).
  The drivers pass the config's `l1_qc_opts(cfg).Tvalid` (fixed 2026-10-14;
  before that the drivers used [-2 40], while the catalog rebuild script
  already passed the config value). Settling velocity `L3.ws`, critical Shields
  `L3.theta_cr` and `L3.tau_cr` follow per segment.
- Settling velocity: Ferguson & Church (2004) with nominal-diameter constants
  C1 = 20, C2 = 1.1 (`settling_velocity` default `natural_nominal`), because
  the measured grain sizes come from laser diffraction. Stamped as
  `transport_params.ws_C1/ws_C2/ws_shape`. History: smooth-sphere C2 = 0.4
  until 2026-08-13, C2 = 1.0 until 2026-10-09. A pre-registered test against
  the TBR23 surveys could not distinguish six formulas; the spread across them
  is about +-15% at 250 um.
- Per-fraction Rouse numbers `rouse_D16/_D50/_D84` where `site_grain_size`
  has a measured distribution (`transport_params.D_source`).
- Grain size: 19 of 65 records use a measured D50 (TBR23/Torrey sites), 4 an
  assumed site default (217.4 um) and 42 the 250 um placeholder in
  `L2.params.D50` (tally from the L3 sidecars, 2026-10-14).

> **Rouse changed on 2026-08-13.** It was previously computed from the
> oscillatory wave stress amplitude, which is the wrong stress: the Rouse profile
> assumes a steady boundary layer with diffusivity `kappa*u_star*z` over the water
> column, whereas the wave boundary layer is centimetres thick, and an amplitude
> is not a mean. Both errors inflated `u_star`, so the old field **overstated
> suspension** (median 4.8 against a corrected 41.5 at MOP580 5 m). The field was
> regenerated across all L3; no downstream code consumed it, and `shields`,
> `mobilized`, `Fb` and `Fb_cum` are bit-identical. See `docs/audit.md`
> (2026-08-13) and the entrainment/suspension/advection split documented in
> `shared/wave_current_stress.m`.

### L3d — Current Decomposition
- t_tide tidal harmonic analysis on uMean/vMean
- Subtidal (wave-driven) residual currents
- Undertow magnitude
- Tidal validation against NOAA Scripps Pier gauge (R=0.995, UTC confirmed)
- t_tide runs with `rng(0,'twister')` (2026-10-09; the caller's RNG state is
  restored), because its bootstrap error estimate decides which constituents
  enter the prediction; unseeded, two runs of one record differed by
  0.003-0.007 m/s. Stamped at `L3.tidal.ttide_rng`.
- Tidal depth (`L3.tidal.depth_pred`) comes from NOAA predictions for station
  9410230 (La Jolla, Scripps Pier) through the lab toolbox's `getztide2`,
  for every site; when the download fails the code falls back to a t_tide fit
  and records `L3.tidal.depth_source = 't_tide'`. The catalog rebuild refused
  any record without NOAA depth (TOR24W/MOP586_10m had silently used the
  fallback). The plain drivers do not refuse it. For a site far from La Jolla
  the NOAA prediction is the wrong tide.
- The t_tide fit covers only the span where velocity exists (2026-10-09).

**Status (2026-10-14):** all 65 L3 rebuilt in full on 2026-10-12/14 (bands,
storms, transport, currents) with the changes above, NOAA tidal depth on 65/65.
Output: `outputs/L3/{deployment}/{label}_L3.mat`.

---

## L4: Nonlinear-Wave / IG Dynamics (built for all 65 records; rebuilt 2026-10-12/14)

**Status (2026-10-14):** all 65 L4 and 9 `L4_xspec` rebuilt with the edge-gap
fill fix and provenance. On 2026-10-07, 29 of 65 L4 files did not match their
own L2 (`L4.eta.depth - L2.depth` up to 3.2 cm), because they were built
before the July L1/L2 reruns; they held spurious IG values (Hs_IG up to
19.9 m). They were rebuilt on 2026-10-08, and `audit_L4_coverage` now checks
content. Open: IB19S/MOP045_7m segment 2019-04-22 19:30 had L4 Hs_IG 3.88 m
against L2's 0.757 m with 424 missing pressure samples in the window (before
the fill fix); still listed as open in `docs/todo.md`.

`L4_xspec` depends on every member L4. Rebuild it whenever any member L4
changes. `scripts/run_L4_refresh_watchdog.sh` does this once after all its
MATLAB launches (stage `xspecprov`), since a launch killed for a hang never
reached its own xspec step (left IB19S, IB18W and RUBY22 xspec stale twice).

**Input:** L1 + L2 `.mat` files
**Output:** Per-instrument nonlinear-wave and IG diagnostics

### Modules built and validated on TBR23 (May 2026)
- **`PUV_L4_eta.m`** — P (dBar) → η (m) per L2 segment, three bands
  (total, swell, IG). Hs reconstruction matches L2 to 0.5%.
- **`PUV_L4_reflection.m`** — Sheremet incident/reflected split, R²(f),
  IG flux. Sign convention validated via `corr(η_swell, U_swell) = +0.984`.
  R²_IG ≈ 1 reflects bound-wave contamination — true shoreline R² needs
  `PUV_L4_boundwave.m` to remove bound IG first (built; see below).
- **`PUV_L4_bispectra.m`** — bicoherence + skewness + asymmetry +
  swell-IG difference coupling. At the current 1-hour segments
  (`segLen=7200`, `nfft=2048`, 50% overlap) each segment holds K = 6
  sub-segments, giving `edof = K·mg·2 = 60` and `b95 = sqrt(6/60) = 0.316`,
  uniform across the catalog. (Revisions of this file before 2026-07-26
  quoted EDOF ≈ 130 / b95 ≈ 0.215, which came from the retired 17-min
  segmentation.) `bic_swell_ig_diff` is monotonic in depth at TBR23 →
  consistent with Hasselmann/Herbers bound-wave forcing prediction.
  `opts.useParallel` runs the per-segment bispectrum calls under `parfor`
  (~4x on 10 cores) and is bit-identical to the serial path: only the
  `bispectrum` calls are parallelised, while the derived quantities and the
  time-mean accumulation stay serial and in index order.
- **`PUV_L4_xspec.m`** — pairwise IG cross-spectra (cpsd on `eta_ig`)
  for multi-instrument arrays. Best-overlap segment matching across
  per-instrument L2 start-time offsets. TBR23: ⟨γ²⟩_IG = 0.35
  cross-shore (~100 m sep) vs 0.13 alongshore (~600 m sep), 2.4× drop
  quantifies IG directional spread.
  **This is the only module that reads `LATLON`** — pair separations
  (`sep_crossshore`, `sep_alongshore`, `sep_total`) are derived from it at
  `PUV_L4_xspec.m:205`. A wrong coordinate therefore corrupts no measurement
  but mislabels every separation, so it is the one product that must be
  rebuilt after a coordinate fix. Rebuilt 2026-07-28 for `RUBY22`, `TOR24S`,
  `TOR24W`, `TOR25S` (separations moved −50% to +53%; coherences unchanged
  to four decimals, as expected).
- **`PUV_L4_moments.m`** (May 11) — reverse-engineered Bill O'Reilly
  MOP511 6m analysis. Frequency-resolved correlation r(f) between
  hourly u-skewness/asymmetry and √Spp(f), raw + 120-hr smoothed,
  peak-frequency linear predictor. Also computes the var(P)/var(U)
  QC diagnostic (Bill Fig 2). Output at `L4.moments`.
- **`PUV_L4_velocity_pdf.m`** (May 11) — pooled |u| histogram across
  the deployment (Bill Fig 10). Rotates L1 via `L2.shorenormal`,
  mirrors L2 hourly segment alignment, returns onshore/offshore counts,
  crossover velocity, mean |u|. Output at `L4.pdf`. The crossover
  velocity is hypothesized to track Shields-bedload thresholds —
  pending LPA D50 ingestion to confirm.

- **`PUV_L4_boundwave.m`** — bound/free IG separation (Hasselmann second-order
  kernel), on both η and u. Feeds `PUV_L4_reflection_free.m`, which reruns the
  Sheremet split on the bound-stripped residual and so gives the shoreline
  reflection coefficient that `L4.ref` alone overstates. Note the regime limit:
  the second-order theory over-predicts above `Hs/h` ≈ 0.10, so filter on
  `Hs/h` before using `bound_frac`.

### Batch notes
- A full-catalog L4 build is dominated by `bispectra`. Measured 2026-07-26:
  **2.3 s per valid segment serial, 0.57 s under `opts.useParallel`** on a
  10-core machine. The 2026-07-26 repair did 3 full rebuilds plus 23 bispectra
  backfills (25.8k valid segments) in **4.15 h**.
- **`PUV_L4_run_all.m` deliberately skips `bispectra`** (see the comment at its
  call site) because it is the slow module. Anything built by `run_all` alone
  therefore lacks `bispectra` until a separate pass fills it in. This is exactly
  how the 23 archive records ended up missing it — they were ingested after the
  one-time `scripts/refresh_L4_bispectra.m` pass had already run.

### L4 output struct shape (per instrument)
```
L4
├── label, deploymentName, doffp, LATLON, shorenormal, mopStation, builtAt
├── eta:        time, fs, segLen, depth, bands, eta_total, eta_swell,
│               eta_ig, fCut, segValid                         (~270 MB)
├── ref:        time, fs, segLen, depth, segValid, shorenormal, bandIG,
│               eta_IG_in/out, var_IG_in/out, R2_IG,
│               fIG, S_IG_in/out, R2_f, cg_IG,
│               Ef_IG_in/out/net                               (~190 MB)
├── bispectra:  time, fs, segLen, segValid, f, df, bands, K, nfftSub,
│               skewness, asymmetry, b95, edof,
│               bic_max_overall, bic_swell_self, bic_swell_ig_diff,
│               B_mean, Bic_mean, Bip_mean, nValid             (~few KB)
├── boundwave:  time, fs, segLen, segValid, depth, fIG, bandIG, bandSwell,
│               eta_ig_bound/free, u_ig_bound/free,
│               S_ig_bound/free/total, bound_frac, bound_frac_raw,
│               bound_frac_f, var_ig_*, var_u_ig_*               (~400 MB)
├── reflection_free: same shape as `ref`, but the Sheremet split run on the
│               bound-stripped residual — use this for shoreline R²
├── moments:    time, f, segValid, varP_over_varU,
│               skewness_u, asymmetry_u,
│               r_skew_Spp, r_asym_Spp, r_skew_Suu, r_asym_Suu,
│               r_skew_Spp_s, r_asym_Spp_s,
│               peak.{skew_fHz, skew_r, asym_fHz, asym_r},
│               fit_hourly/fit_smoothed.{slope,intercept,r2,fHz,n},
│               opts                                           (~MB)
└── pdf:        edges, centers, N_on, N_off, diff, weighted, cum,
                crossover_u, mean_absU, n_segments_used, opts  (~KB)
```

> ⚠️ **A partial rebuild destroys the rest of the file.** `L4` is one struct in
> one `.mat`, so a script that recomputes a few products and re-saves wipes
> every field it did not set — including the metadata block. This happened
> twice via `scripts/reprocess_heading_fix.m` (TBR23/MOP580_5m in May 2026,
> TOR16B/C/D on 2026-07-27) and went unnoticed because the audit checked only
> sub-products. Any script that re-saves L4 must write the complete struct
> (copy the metadata block from `PUV_L4_driver`) and `clear L4` between
> iterations. `validation/audit_L4_coverage` now checks metadata as well, and
> `scripts/copy_to_server.m` refuses to push an incomplete L4. To fill gaps
> without touching computed products, use
> `scripts/repair_L4_metadata_2026_07_27.m` (additive; verified to leave
> `bispectra`/`ref` bit-identical). Full account in `PIPELINE_NOTES.md`.

> ⚠️ **Never index an L4 per-segment array with an L2 segment index.** Every L4
> sub-product is built at `numel(L2.time)` *as L2 stood at build time*, and an
> L1/L2 rerun can change the segment grid. Equal counts do not prove alignment —
> a grid can gain a segment at the start and lose one at the end. Worse, MATLAB
> silently accepts a logical mask shorter than the array it indexes, so
> `L2.Hs_SS(L4mask)` returns wrong-hour data with no error (this bug was live in
> `fig_L4_boundwave_catalog.m` until 2026-07-26). Use
> **`shared/l4_l2_index_map.m`**, which matches by `time` and returns
> `info.identity` so callers can assert:
>
> ```matlab
> [l4map, info] = l4_l2_index_map(L2, L4);
> j = l4map(i);                 % L2 index i -> L4 index j
> if isnan(j), continue; end    % no L4 counterpart for this L2 segment
> ```

---

## L5: PUV–Altimeter Integration (PLANNED)

**Input:** L2 + L3 `.mat` files + altimeter/echologger bed level
**Output:** Bed-change time series correlated with wave forcing

Design reconciled with `Altimeter_Pipeline/docs/puv_correlation_plan.md`;
see `docs/altimeter_correlation_plan.md` for the PUV-side spec. Memory
`project_L5_plan.md` is the current reference.

- Altimeter timestamp backbone; PUV matched within ±5 min nearest-neighbor
- 8 candidate transport relationships (Shields excess, Fb, |u|³,
  u·|u|², equilibrium/disequilibrium, undertow, swell-vs-sea, cumulative
  Fb between surveys)
- Time-varying doffp from altimeter bed level (replaces fixed deployment
  doffp in L2)
- Start point: TOR24S MOP586 (co-located 5/7/10 m, six storms, full
  beach-survey concurrence)

**Status:** Not yet implemented. Module skeleton + transport relationship
fits are the next major build.

---

## Analysis layer (downstream of the pipeline)

Pipeline outputs (the L1–L4 `.mat` files documented above) feed site-specific
analysis and figures, which live outside this repo. The pipeline itself is
analysis-agnostic: it produces the standardized per-level outputs, and
downstream studies consume them however they need.
