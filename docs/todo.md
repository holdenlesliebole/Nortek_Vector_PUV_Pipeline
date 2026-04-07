# PUV Pipeline — Master To-Do List

Tracks tasks across all processing levels. Grouped by priority.
Updated: April 6, 2026

---

## Completed

### L3: Wave Forcing Characterization (ALL DONE)
- [x] L3a: frequency-band energy decomposition (PUV_L3_bands.m)
- [x] L3b: storm/event detection with MOP gap-filling (PUV_L3_storms.m)
- [x] L3c: transport proxies — Fb, Shields, Rouse, mobilization (PUV_L3_transport.m)
- [x] L3d: tidal current decomposition via t_tide + NOAA depth (PUV_L3_currents.m)
- [x] Verified on TBR23 and NN24
- [x] Ef_total/L2.Ef = 1.0000 consistency check passes for all instruments
- [x] Timezone confirmed UTC via NOAA cross-correlation

### L2 Bug Fixes
- [x] bed_velocity_ifft: transfer function was inverted (fixed)
- [x] compute_velocity_moments: asymmetry formula fixed (Hilbert transform)
- [x] L2 verification: 8/8 checks pass
- [x] Full L2 re-run with fixes (all deployments)

### Validation
- [x] Cross-deployment spectral shape analysis (33 instruments, 5 sites)
- [x] SIO Pier canyon focusing discovery (2-5x amplification)
- [x] Hypothesis testing suite (4 mechanisms, 1 supported)
- [x] Tidal validation against NOAA Scripps Pier gauge

### Pipeline Maintenance
- [x] All doffp values filled from DeploymentNotes
- [x] File prefix handling (underscore/hyphen, single-burst)
- [x] IGRF epoch 14 fallback
- [x] Tilt correction for bent pipes
- [x] Site map with satellite basemap
- [x] Beamer slide deck (32 slides)
- [x] Deployment database for Brian

---

## Immediate (in progress)

### Full L3 Batch Run
- [ ] Running PUV_L3_run_all for all 33 instruments (in progress)
- [ ] Retry SOL25B and TBR23 MOP580_5m shore-normal rotation
- [ ] Brian meeting: review deployment_database_overview.md

### Documentation Updates
- [ ] Update Beamer slides with L3 results and L2 verification
- [ ] Update LaTeX methods with L3 methodology
- [ ] Fix LaTeX interpreter on MATLAB plot axes
- [ ] Clean up site map legend

---

## Near-term (before TBR23 paper submission)

### TBR23 Paper Analysis (lives in Paper 1 repo)
- [ ] Load survey data (truck lidar + jetski bathymetry)
- [ ] Wave forcing time series figures (L3 band flux, storms, mean currents)
- [ ] Survey-to-survey volume change vs cumulative Fb
- [ ] Depth-dependent response comparison (5m vs 7m pairs)
- [ ] Reproduce Bill O'Reilly's bottom flux analysis with new pipeline
- [ ] See Paper 1/TBR23_analysis_todo.md for full list

### Grain Size Integration
- [ ] Process Laser Particle Analyzer data → D50 per site
- [ ] Update configs with site-specific D50
- [ ] Re-run L2 bed stress and L3 Shields/Rouse with real D50

### Cross-check
- [ ] Compare TBR23 L2 output against original PUV_all_in_one.m values

---

## Medium-term (spinoff papers)

### L4: IG / Bound Wave Dynamics
- [ ] Review Athina Lange's Ruby2D code for methods
- [ ] Implement bispectral analysis (bicoherence)
- [ ] Bound vs free IG wave separation
- [ ] Cross-instrument IG coherence for multi-instrument arrays
- [ ] Quantify IG energy generation across the cross-shore array

### L5: PUV-Altimeter Integration
- [ ] Write altimeter data loader (AA400/EA400 .log files)
- [ ] Time-align altimeter bed elevation with L2/L3
- [ ] Correlate bed level change with Shields exceedance
- [ ] Estimate transport rates from bed level change + continuity

### Wave Dynamics Paper (PUV_Wave_Dynamics_Paper repo)
- [ ] Investigate SIO Pier canyon focusing mechanism
- [ ] Quantify depth trend in peak ratio
- [ ] Seasonal variability of spectral shape bias
- [ ] Draft paper figures and manuscript

---

## Ideas for Later

### Tidal Current Gap-Filling
- [ ] Fit transfer function between NOAA tidal elevation and observed
      tidal currents during reliable periods
- [ ] Use transfer function to predict tidal currents during data gaps
- [ ] Would improve subtidal residual estimates for instruments with
      large gaps (MOP580_5m, MOP651_7m)

### Additional Transport Models
- [ ] Bailard (1981) energetics
- [ ] Hoefel & Elgar (2003) acceleration-skewness correction
- [ ] Rodriguez-Padilla transport model
- [ ] Compare against observed morphology change

### Pipeline Hardening
- [ ] Investigate SIO24B/24C/25A with Brian — any data recoverable?
- [ ] Consider raising tiltAbsMax for SIO24B (32° stable tilt)
- [ ] Vectorize bed_velocity_ifft tilt correction loop
- [ ] Add time-varying doffp option from altimeter data
- [ ] Cache shore-normal angles locally to avoid THREDDS dependency
