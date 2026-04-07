# PUV Pipeline Processing Levels

## Design Philosophy

Each level transforms data from the previous level into higher-order products.
Levels L1–L3 are **universal** — they produce the same outputs regardless of
the scientific question. L4+ levels are **analysis-specific** — they combine
PUV products with external data or apply domain-specific models.

All levels are deployment-agnostic: run any deployment through L1→L2→L3 and
get the same standardized output struct.

---

## L1: Raw → QC'd Timeseries (COMPLETE)

**Input:** Raw .dat/.sen/.hdr burst files
**Output:** Continuous 2 Hz time series with QC flags applied

- Burst merging, clock drift correction
- Variability-based tilt QC + tilt correction rotation
- Pitch/roll/pressure/correlation QC
- Coordinate rotation to buoy frame (+x West, +y North, +z Up)
- Output struct: `PUV.{time, P, BuoyCoord, InstrCoord, T, ...}`

**Status:** Complete, verified, 33/40 instruments processed.

---

## L2: Spectral Analysis (COMPLETE)

**Input:** L1 .mat files
**Output:** Per-segment (17-min) spectral products

- Segmentation (2048 samples, non-overlapping)
- Welch PSD (~34 DOF), cross-spectra
- Pressure correction → surface elevation spectrum
- Shore-normal rotation (CDIP THREDDS)
- Bulk wave parameters: Hs, Tp, Tm02, direction, energy flux
- Near-bed velocity (IFFT method)
- Bed stress (Swart 1974)
- Reynolds stress, TKE
- Velocity moments (skewness, asymmetry via Hilbert transform)
- Mean currents per segment

**Status:** Complete, verified 8/8 checks, 33 instruments processed.

---

## L3: Wave Forcing Characterization (TO BUILD)

**Input:** L2 .mat files
**Output:** Per-segment derived forcing metrics + deployment summaries

Universal products that characterize wave forcing independent of any
specific transport model or morphology dataset.

### L3a: Frequency-Band Energy Decomposition
- Energy flux by band: F_ig, F_swell, F_sea, F_total per segment
- Band definitions: IG [0.004–0.04], swell [0.04–0.10], sea [0.10–0.25] Hz
- Band-averaged Hs: Hs_ig, Hs_swell, Hs_sea
- Dominant band flag per segment (swell-dominated vs sea-dominated)

### L3b: Storm/Event Detection
- Identify storm events from Hs time series (threshold exceedance + duration)
- Event metrics: peak Hs, duration, total energy, cumulative flux
- Calm period identification (recovery windows)
- Return period estimation from Hs distribution

### L3c: Transport Proxies
- Bottom energy flux: Fb = ρg·cg·Ub² (spectral integral)
- Shields parameter time series (with configurable D50)
- Rouse number time series
- Mobilization fraction (% time above critical Shields)
- Cumulative bottom energy flux

### L3d: Current Decomposition
- Tidal harmonic analysis on uMean/vMean (UTide or t_tide)
- Subtidal (wave-driven) residual currents
- Undertow estimation
- Longshore current magnitude and direction

### L3 Output Struct
```
L3.time               % segment midpoint times (same as L2)
L3.Ef_ig, Ef_swell, Ef_sea, Ef_total   % band energy flux
L3.Hs_ig, Hs_swell, Hs_sea            % band wave heights
L3.Fb                 % bottom energy flux
L3.shields            % Shields parameter
L3.rouse              % Rouse number
L3.mobilized          % logical: above critical Shields
L3.Fb_cum             % cumulative bottom flux
L3.events             % struct array of detected storm events
L3.uTidal, vTidal     % tidal current components
L3.uSubtidal, vSubtidal  % subtidal residual currents
```

---

## L4: IG / Bound Wave Dynamics (TO BUILD)

**Input:** L1 and L2 .mat files (needs raw timeseries + spectra)
**Output:** Infragravity wave characterization

- Bispectral analysis (bicoherence at swell-IG coupling frequencies)
- Bound vs free IG wave separation (phase relationship with envelope)
- IG energy flux and direction
- Cross-instrument IG coherence (for multi-instrument arrays)
- Reflection coefficient estimation
- Reference: Athina Lange Ruby2D code, Herbers et al.

---

## L5: PUV-Altimeter Integration (TO BUILD)

**Input:** L2 .mat files + altimeter/echologger data from co-located sensors
**Output:** Bed level change correlated with wave forcing

- Load altimeter (AA400) and echologger (EA400) bed elevation time series
- Time-align with L2/L3 wave forcing segments
- Correlate bed level change with:
  - Wave energy flux
  - Shields parameter exceedance
  - Storm events
  - Tidal phase
- Sediment transport rate estimation from bed level change + continuity
- Scour/accretion event detection
- Data sources: `/Volumes/group/Altimeter_data/`

---

## Analysis Layer (paper-specific, NOT in pipeline)

These use pipeline outputs but live in paper-specific repos.

### TBR23 Paper (Paper 1)
- Wave forcing time series overlaid with bathymetric change
- Correlation of L3 forcing metrics with survey-to-survey volume change
- Phi proxy analysis (empirical transport-morphology relationship)
- Comparison across 5m/7m instrument pairs (depth-dependent response)
- Storm response and recovery timescales
- Data: truck lidar (weekly), jetski bathymetry (every 3 days)

### PUV Wave Dynamics Paper (Paper 2)
- MOP spectral peak broadening (cross-deployment)
- SIO Pier canyon focusing
- Depth trend in peak ratio
- Seasonal variability of spectral shape bias
- Repo: holdenlesliebole/PUV_Wave_Dynamics_Paper

### Future Papers
- Lagoon dynamics (LPL deployments)
- Long-term wave climate analysis (25-year survey dataset)
- Sediment transport model validation (when grain size data available)
