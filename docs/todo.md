# PUV Pipeline — Master To-Do List

Tracks tasks across all processing levels. Grouped by priority.

---

## Immediate (needed for TBR23 paper)

### L3a: Frequency-Band Energy Decomposition
- [ ] Write `PUV_L3_spectral_bands.m` — compute F_ig, F_swell, F_sea per segment from L2 spectra
- [ ] Write `PUV_L3_driver.m` — single deployment driver
- [ ] Write `PUV_L3_run_all.m` — batch runner
- [ ] Confirm band definitions with advisor: IG [0.004–0.04], swell [0.04–0.10], sea [0.10–0.25]
- [ ] Test on TBR23, verify F_total matches L2.Ef

### L3b: Storm/Event Detection
- [ ] Write `detect_storm_events.m` — threshold + duration based event detection
- [ ] Define event metrics: peak Hs, duration, total energy, cumulative flux
- [ ] Identify the early 2023 storm sequence in context of TBR23 deployment

### L3c: Transport Proxies
- [ ] Write `compute_bottom_flux.m` — Fb = ρg·cg·Ub² (spectral integral)
- [ ] Add Shields parameter time series to L3 output
- [ ] Compute mobilization fraction per deployment
- [ ] Implement cumulative bottom flux (for survey-to-survey comparison)

### Pipeline Maintenance
- [ ] Re-run full L2 for all deployments (bed velocity + asymmetry fixes) — DONE for TBR23
- [ ] Retry SOL25B and TBR23 MOP580_5m shore-normal rotation when THREDDS stable
- [ ] Brian meeting: review deployment_database_overview.md
- [ ] Cross-check TBR23 L2 output against original PUV_all_in_one.m values

---

## Near-term (needed soon but not blocking TBR23)

### L3d: Current Decomposition
- [ ] Integrate UTide or t_tide for tidal harmonic analysis
- [ ] Compute subtidal residual currents from L2.uMean/vMean
- [ ] Validate tidal current magnitudes against known tidal constituents

### Grain Size Integration
- [ ] Process Laser Particle Analyzer data → D50 per site
- [ ] Update config files with site-specific D50
- [ ] Re-run L2 bed stress with real D50 (Ub unaffected, only tau_b/Shields change)

### Documentation
- [ ] Update Beamer slides with L2 verification results and cross-deployment summary
- [ ] Update LaTeX methods section with bed velocity fix and asymmetry fix
- [ ] Fix LaTeX interpreter on MATLAB plot axes (use 'Interpreter','latex')
- [ ] Clean up site map legend (extra entries from data loop)
- [ ] Fix "Ignoring extra legend entries" warnings in L1 diagnostic plots

---

## Medium-term (spinoff paper / Chapter 2)

### L4: IG / Bound Wave Dynamics
- [ ] Review Athina Lange's Ruby2D code for IG analysis methods
- [ ] Implement bispectral analysis (bicoherence)
- [ ] Bound vs free IG wave separation
- [ ] Cross-instrument IG coherence for multi-instrument arrays
- [ ] Quantify IG energy generation in the cross-shore array

### L5: PUV-Altimeter Integration
- [ ] Write altimeter data loader (AA400 .log files and EA400 .log files)
- [ ] Time-align altimeter bed elevation with L2/L3 wave segments
- [ ] Correlate bed level change with Shields exceedance
- [ ] Identify scour/accretion events in altimeter timeseries
- [ ] Estimate transport rates from bed level change + continuity equation

### Wave Dynamics Paper
- [ ] Investigate SIO Pier canyon focusing mechanism in detail
- [ ] Quantify depth trend in peak ratio across all cross-shore arrays
- [ ] Analyze temporal/seasonal variability of spectral shape bias
- [ ] Draft paper figures (see PUV_Wave_Dynamics_Paper/docs/todo.md)

---

## Long-term

### Additional Transport Models
- [ ] Implement Bailard (1981) energetics model
- [ ] Implement Hoefel & Elgar (2003) acceleration-skewness correction
- [ ] Implement undertow-driven offshore transport estimation
- [ ] Compare model predictions against observed morphology change
- [ ] Rodriguez-Padilla transport model (if applicable)

### Pipeline Hardening
- [ ] Investigate SIO24B/24C/25A failures with Brian — can any data be recovered?
- [ ] Consider raising tiltAbsMax from 30° to 35° for SIO24B (32° stable tilt)
- [ ] Vectorize bed_velocity_ifft tilt correction loop for speed
- [ ] Add option for time-varying doffp from altimeter data
- [ ] Cache shore-normal angles locally to avoid THREDDS dependency
