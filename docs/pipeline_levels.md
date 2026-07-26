# PUV Pipeline Processing Levels

Updated: July 24, 2026

> ⚠️ **Corrected 2026-07-26 — L4 is NOT complete.** `bispectra` is missing on
> **23 of 65 records** (the whole pre-2023 archive ingest plus Cardiff and
> Coronado), and `L4.ref` is one segment short of L2 on **3 records**
> (SIO25B, TOR24S/MOP586_7m, TOR24W/MOP586_10m), which silently breaks any
> consumer that indexes L4 with an L2 segment index. Details and the affected
> list are in the HIGH PRIORITY section at the top of `docs/todo.md`.
> Re-audit with `validation/audit_L4_coverage.m`.

**Catalog size:** 65 instrument-records across 46 deployments, present at every
level L1–L3 and **partially at L4** (see the correction above); 9 deployments
also carry `L4_xspec`. The "33/40" figures that
appeared in earlier revisions of this file predate the pre-2023 archive
additions (CAT21A/B, RUBY22, IB18W, IB19S, then TOR19W/TOR20W/IB19W) and have
been updated in place below.

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
- Variability-based tilt QC + tilt correction rotation
- Pitch/roll/pressure/correlation QC
- Coordinate rotation to buoy frame (+x West, +y North, +z Up)
- Output struct: `PUV.{time, P, BuoyCoord, InstrCoord, T, ...}`

**Status:** Complete and verified. 65 instrument-records processed across 46
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
- QC diagnostics: nanMaxFrac=0.10 rejection, Z-test stored per segment

**Status:** Complete, verified 8/8 product checks, 65 instrument-records
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
- Shields parameter time series (configurable D50)
- Rouse number time series
- Mobilization fraction (% time above critical Shields)
- Cumulative bottom energy flux

### L3d — Current Decomposition
- t_tide tidal harmonic analysis on uMean/vMean
- Subtidal (wave-driven) residual currents
- Undertow magnitude
- Tidal validation against NOAA Scripps Pier gauge (R=0.995, UTC confirmed)

**Status:** Complete and batch-processed across all 65 instrument-records.
Output: `outputs/L3/{deployment}/{label}_L3.mat`.

---

## L4: Nonlinear-Wave / IG Dynamics (MOSTLY BUILT)

**Input:** L1 + L2 `.mat` files
**Output:** Per-instrument nonlinear-wave and IG diagnostics

### Modules built and validated on TBR23 (May 2026)
- **`PUV_L4_eta.m`** — P (dBar) → η (m) per L2 segment, three bands
  (total, swell, IG). Hs reconstruction matches L2 to 0.5%.
- **`PUV_L4_reflection.m`** — Sheremet incident/reflected split, R²(f),
  IG flux. Sign convention validated via `corr(η_swell, U_swell) = +0.984`.
  R²_IG ≈ 1 reflects bound-wave contamination — true shoreline R² needs
  `PUV_L4_boundwave.m` (deferred) to remove bound IG first.
- **`PUV_L4_bispectra.m`** — bicoherence + skewness + asymmetry +
  swell-IG difference coupling. Sub-segment averaging gives EDOF ≈ 130,
  b95 ≈ 0.215. `bic_swell_ig_diff` is monotonic in depth at TBR23 →
  consistent with Hasselmann/Herbers bound-wave forcing prediction.
- **`PUV_L4_xspec.m`** — pairwise IG cross-spectra (cpsd on `eta_ig`)
  for multi-instrument arrays. Best-overlap segment matching across
  per-instrument L2 start-time offsets. TBR23: ⟨γ²⟩_IG = 0.35
  cross-shore (~100 m sep) vs 0.13 alongshore (~600 m sep), 2.4× drop
  quantifies IG directional spread.
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

### Deferred
- **`PUV_L4_boundwave.m`** — bound/free IG separation. Needed for clean
  shoreline reflection coefficients (currently inflated by bound-IG
  contamination).
- Batch over the full catalog (65 instrument-records). ~21 hr at nfft=1024,
  ~80 hr at nfft=2048 (paper-quality).

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
