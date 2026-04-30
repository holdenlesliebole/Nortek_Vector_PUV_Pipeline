# PUV Pipeline — Master To-Do List

Tracks tasks across all processing levels. Grouped by priority.
Updated: April 9, 2026

---

## Completed

### Pipeline (L1-L3) — fully operational
- [x] L1: raw→QC with tilt correction, 33/40 instruments
- [x] L2: spectral analysis, all products verified 8/8 checks
- [x] L2 bug fixes: bed_velocity_ifft inverted transfer function, asymmetry Hilbert transform
- [x] L3a: frequency-band energy decomposition
- [x] L3b: storm/event detection with MOP gap-filling
- [x] L3c: transport proxies (Fb, Shields, Rouse, mobilization)
- [x] L3d: tidal decomposition (t_tide + NOAA depth, UTC confirmed)
- [x] Full L3 batch run on all 33 instruments
- [x] SOL25B and TBR23 MOP580_5m shore-normal rotation retried successfully

### Validation
- [x] Cross-deployment spectral shape: R(Qp) positive for all 33 instruments
- [x] SIO Pier Scripps Canyon focusing: 2-5x amplification
- [x] Hypothesis testing: 4 mechanisms tested, MOP peak broadening confirmed
- [x] Tidal validation: NOAA Scripps Pier gauge R=0.995, UTC confirmed
- [x] L2 product verification: 8/8 checks pass
- [x] Ruby2D head-to-head vs legacy pipeline (MOP582_6m): Hs RMS 5 cm, R²=0.98; Dir RMS 1.2°, R²=0.93. See `pipeline_comparison_legacy.md` and `outputs/validation/Ruby2D/`

### TBR23 Paper Analysis — first pass complete
- [x] Loaded MOPS survey data (22 jetski surveys during deployment)
- [x] Extracted bed elevation at PUV instrument cross-shore positions
- [x] Built forcing-response time series figure (fig_forcing_response_v2.m)
- [x] Built transport mechanism figure (fig_transport_mechanisms_v4.m)
- [x] Identified competing transport: skewness (onshore) vs undertow (offshore)
- [x] Found recovery boundary at ~6-7m depth
- [x] Validated skewness vs Ruessink et al. 2012 parameterization
- [x] Discovered tidal modulation of undertow (high tide = stronger offshore)
- [x] Flagged MOP580_5m as compromised for transport analysis (kelp fouling)

### Documentation
- [x] LaTeX methods section (L1, L2, L3, validation methodology)
- [x] LaTeX results section (spectral bias, hypothesis testing, L3 results, SIO Pier)
- [x] Beamer slide deck (37 slides with L3 section)
- [x] Deployment database for Brian
- [x] Site map with satellite basemap and MOP transects
- [x] PUV-altimeter correlation plan (reconciled with altimeter pipeline)
- [x] PUV Wave Dynamics Paper repo created

---

## Immediate (TBR23 paper)

### TBR23 Analysis — next steps
- [ ] Implement Bailard/Hoefel & Elgar transport calculation using L2 products
- [ ] Compare computed transport rates against observed bed change between surveys
- [ ] Analyze surfzone position modulation of forcing depth
- [ ] Build broader morphology context figure (pre-storm, storm, recovery from MOPS + MOP)
- [ ] Cross-check TBR23 L2 against original PUV_all_in_one.m values
- [ ] Reproduce Bill O'Reilly's cumulative Fb^3 analysis with pipeline data

### TBR23 Paper Writing
- [ ] Draft introduction (25-year context, winter 2023 storms, recovery question)
- [ ] Draft methods (adapt from PUV_Pipeline docs/)
- [ ] Draft results (forcing-response, transport mechanisms, recovery boundary)
- [ ] Draft discussion (skewness vs undertow balance, surfzone modulation, depth dependence)

### Grain Size Integration
- [ ] Process Laser Particle Analyzer data → D50 per site
- [ ] Update configs with site-specific D50
- [ ] Re-run L2/L3 bed stress and Shields with real D50

---

## Near-term

### Pipeline Refinements
- [ ] Fix LaTeX interpreter on MATLAB plot axes across all validation scripts
- [ ] Clean up site map legend (extra entries)
- [ ] Update Beamer slides with TBR23 analysis results
- [ ] Brian meeting feedback: review failed instruments, any data recoverable?

### Ruby2D follow-ups (from April 2026 head-to-head)
- [ ] Investigate Z-test discrepancy: legacy ~1.0 vs ours ~0.76 (same systematic ~0.79 in TBR23). Check whether legacy computes Z on uncorrected vs corrected Spp, or whether ours has a normalization bug
- [ ] Investigate 25% match-rate gap: which Ruby2D hours does our pipeline drop? Likely `nanMaxFrac = 0.10` rejection. Decide whether to relax for backward-compatibility runs
- [ ] Confirm Ruby2D `doffp = 0.60 m` against `DeploymentNotes2021Torrey.xls` (currently a placeholder in `process_ruby2d_one.m`)
- [ ] Run full Ruby2D campaign through our pipeline (other instruments beyond 582_6m) once doffp is confirmed
- [ ] Optional: extend the head-to-head to other Ruby2D instruments to confirm the bulk-parameter agreement holds across the deployment

### L5: PUV-Altimeter Integration
- [ ] Build L5 merge function (reconciled plan in docs/altimeter_correlation_plan.md)
- [ ] Start with TOR24S MOP586 (co-located, multi-depth)
- [ ] Test 8 transport relationships from reconciled plan
- [ ] Implement time-varying doffp correction from altimeter bed level

---

## Medium-term (spinoff papers)

### L4: IG / Bound Wave Dynamics
- [ ] Review the legacy Ruby2D code for methods
- [ ] Implement bispectral analysis (bicoherence)
- [ ] Bound vs free IG wave separation
- [ ] Cross-instrument IG coherence for multi-instrument arrays

### Wave Dynamics Paper (PUV_Wave_Dynamics_Paper repo)
- [ ] SIO Pier canyon focusing investigation
- [ ] Depth trend in peak ratio across all cross-shore arrays
- [ ] Seasonal variability analysis
- [ ] Draft figures and manuscript

---

## Ideas for Later

### Tidal Current Gap-Filling
- [ ] Fit NOAA elevation → tidal current transfer function during reliable periods
- [ ] Predict tidal currents during data gaps

### Additional Transport Models
- [ ] Rodriguez-Padilla acceleration-skewness transport
- [ ] Full Bailard energetics with bedload + suspended load
- [ ] Compare model predictions against altimeter bed change (L5)

### Pipeline Hardening
- [ ] Investigate SIO24B/24C/25A with Brian
- [ ] Vectorize bed_velocity_ifft tilt correction loop
- [ ] Cache shore-normal angles locally
- [ ] Add time-varying doffp option to L2
