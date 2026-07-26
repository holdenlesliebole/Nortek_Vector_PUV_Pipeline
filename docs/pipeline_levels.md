# PUV Pipeline Processing Levels

Updated: July 26, 2026

> **2026-07-26 — L4 repaired and re-verified.** Two defects found on 07-26 are
> fixed: `bispectra` was missing on 23 of 65 records, and 3 records
> (SIO25B/SIO_6m, TOR24S/MOP586_7m, TOR24W/MOP586_10m) had an L4 built against a
> superseded L2 whose segment grid had gained a leading segment. Both traced to
> the same cause — L4 built against a different L2 snapshot — not to a bug in any
> L4 module. `validation/audit_L4_coverage.m` now reports all 65 records complete
> and time-aligned. Full account in `docs/todo.md`.

**Catalog size:** 65 instrument-records across 46 deployments, present and
verified at every level L1–L4; 9 deployments also carry `L4_xspec`. The "33/40"
figures that appeared in earlier revisions of this file predate the pre-2023
archive additions (CAT21A/B, RUBY22, IB18W, IB19S, then TOR19W/TOR20W/IB19W) and
have been updated in place below.

**Why 65 and not 72.** The registry configures **72** instrument-records; 7 have
no L1/L2 because the instrument genuinely failed in the field, so the catalog is
65. `PUV_L{1..4}_run_all` reports these as `fail` ("missing L1 or L2 file") on
every run — that is expected, not a regression. Each is documented with its cause
in `docs/deployment_database_overview.md`:

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

## L4: Nonlinear-Wave / IG Dynamics (BUILT — all 65 records, 2026-07-26)

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
