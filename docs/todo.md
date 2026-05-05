# PUV Pipeline — Master To-Do List

Tracks tasks across all processing levels. Grouped by priority.
Updated: May 5, 2026

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

### Mean-flow validation (May 2026, response to the Vector noise concern)
- [x] Phase 1 TBR23 5-test framework (Hs² scaling, cross-instr correlation, tidal modulation, Reynolds stress, range setting)
- [x] Phase 2 cross-deployment Test 1+3+4 across 33 instruments at 17-min L2: |β|<2cm/s for 100%, median α/α_th=+0.53, 66% correct sign
- [x] 1-hour L2 reprocess of all 33 instruments (`reprocess_all_hourly.m`); Phase 2 against hourly: |β|<2cm/s for 94%, median α/α_th=+0.71, 81% correct sign — sharpens at marginal sites (Solana flips 20%→100% correct sign)
- [x] Per-instrument record figures (33 PNGs in `outputs/validation/mean_flow/_per_instrument/`)
- [x] Robustness: alongshore α also predominantly negative; high-Hs-only fit doubles R² (`test1b_robustness_checks.m`)
- [x] Wave-direction discrimination test rules out shore-normal-rotation explanation: |α_v1| > |α_v0| in 90%, CI on α_v1 excludes 0 in 83%, sign matches radiation-stress prediction (`test1c_wave_direction_check.m`)
- [x] Email draft to the advisor with theory introduction, 3 hypotheses, headline numbers, all robustness checks (`docs/draft_email_to_bill.md`)
- [ ] Send email (awaiting Holden review)

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

### Pre-2023 historical archive ingestion (independent track, not blocking the advisor email)
17 historical deployments in `/Volumes/group/PUV_data/Vector/recopied/` plus Sarah's 2014–2023 LPL record. Scoped in `docs/pre2023_deployment_inventory.md`. Adds long-term Torrey baseline, 9-year LPL series, and 4 new sites (Cardiff, Coronado, Imperial Beach, Catalina).
- [ ] Spot-check older firmware compatibility: parse one .hdr from 2015 and one from 2024, confirm `parse_hdr.m` and `read_VEC` handle both.
- [ ] Tier 1 first — Ruby2D_2021-2022 (10 sub-folders, 1 already validated against legacy) and TorreyPines2019-2020/2020-2021 MOP582 10m. Existing pipeline configs largely transferable.
- [ ] Tier 2 — Cardiff (3), Coronado (2), Imperial Beach (3), Catalina (1) need new MOP-station IDs and shore-normal angles. Catalina almost certainly outside CDIP MOP coverage — needs manual bathymetry-derived shore-normal.
- [ ] Tier 3 — older Torrey single-instrument deployments (2015, 2016, 2017, 2018) for long-term wave climate baseline.
- [ ] Tier 4 — Sarah's LPL_2014-2023 archive — 9 yearly sub-folders, needs Sarah's checkout spreadsheets to rebuild configs.
- [ ] Run mean-flow Phase 2 framework on the expanded catalog; send an update with the broader cross-deployment result.

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
- [ ] **Adapt L2 default to 1-hour segments** (`segLen = 7200` @ 2 Hz) — current default is legacy 17-min (2048). Mean-flow validation and within-hour-stationarity audit support 1-hour as the better choice for bulk parameters and segment-mean velocity (matches MOP cadence, finer Δf, longer N for ū). When this lands: regenerate L2/L3 across all deployments, update the LaTeX methods section accordingly. Reference: `docs/mean_flow_validation_plan.md`.
- [ ] Vectorize bed_velocity_ifft tilt correction loop
- [ ] Cache shore-normal angles locally (currently fetched from CDIP THREDDS each L2 call)
- [ ] Add time-varying doffp option to L2

### Verified L1 QC behavior (May 5)
The 7 instruments dropped from 40→33 are all documented hardware failures
(see `docs/deployment_database_overview.md`). The L1 QC is correctly
rejecting bad data:
- SOL23/MOP651_5m: battery+bent pipe, lost 2 yrs
- SIO24B: knocked over (32° tilt) — fails tilt-absolute QC
- SIO24C: battery depleted, beam corr <70% throughout — fails correlation QC
- SIO25A: started upside-down, pin corrosion — fails tilt+correlation QC
- TOR24S/MOP586_15m, TOR24W/MOP586_5m, TOR25S/MOP586_5m: pipe issues / kelp burial — fail pressure or tilt QC

This is **not a bug**. The "empty L1 diagnostic plots" I saw earlier are the
expected render when every sample is NaN'd by QC. No fix needed.
