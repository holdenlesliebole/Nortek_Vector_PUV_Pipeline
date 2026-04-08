# PUV Pipeline — Master To-Do List

Tracks tasks across all processing levels. Grouped by priority.
Updated: April 8, 2026

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

### L5: PUV-Altimeter Integration
- [ ] Build L5 merge function (reconciled plan in docs/altimeter_correlation_plan.md)
- [ ] Start with TOR24S MOP586 (co-located, multi-depth)
- [ ] Test 8 transport relationships from reconciled plan
- [ ] Implement time-varying doffp correction from altimeter bed level

---

## Medium-term (spinoff papers)

### L4: IG / Bound Wave Dynamics
- [ ] Review Athina Lange's Ruby2D code for methods
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
