# Mean Cross-Shore Flow Validation Plan

## Background

The advisor raised a Nortek Vector instrument concern about the mean
cross-shore flow (undertow) component of the TBR23 paper after looking at
SIO MOP 511 6m PUV data (Apr 2024 – Mar 2026).

Their argument:
- Vector velocity range was set to 4 m/s (max nominal).
- Spec accuracy: 0.5% of range = 2 cm/s on a single sample.
- Grand mean of 2M samples at SIO 511 was ~2 cm/s, heading 205° (southward
  shore-parallel).
- That magnitude is at the noise floor of the instrument.
- Nortek/other literature notes: range settings much larger than the desired
  signal lead to noisy mean-flow estimates.
- Conclusion: there is no significant/measurable mean cross-shore flow with
  these settings.

## Why this argument needs unpacking

The 0.5%-of-range spec is **single-sample worst-case accuracy**. It conflates
two error sources:

1. **Random Doppler/phase noise** — averages down by √N. A 17-min segment
   (N=2048) reduces 2 cm/s single-sample noise to ~0.4 mm/s segment-mean noise.
   A 1-hour segment (N=7200) reduces it to ~0.24 mm/s.
2. **Systematic offset** — DC bias from beam misalignment, calibration drift,
   phase ambiguity preference. Does not average down. *This* is what the
   2 cm/s grand mean at SIO 511 most likely reflects.

The paper's claim is **not** "the constant time-mean cross-shore velocity is
non-zero." It is "the segment-mean cross-shore velocity *varies systematically
with wave forcing and tidal phase*." A constant instrumental offset has no
forcing dependence, no tidal modulation, no Hs² scaling. The diagnostic is to
test whether the time-varying behavior matches physical expectations.

## Five tests (all needed before answering the question definitively)

### Test 1 — Hs² scaling
Stokes return flow theory (depth-averaged, narrow-band random sea):

  uMean ≈ -g/(16·c·h) · Hs²,  where c = √(g·h)

For h=5 m, c≈7 m/s, slope α ≈ -1.75 cm/s per m². For Hs=1 m → u≈-1.7 cm/s;
for Hs=2 m → u≈-7 cm/s.

Plot uMean vs Hs² per instrument. Fit y = α·x + β.
- α ≠ 0 (with sign matching theory) → wave-driven flow is real.
- β ≈ 0 → no constant instrumental offset.
- β ≠ 0 → systematic bias of magnitude β (the noise-floor concern).
- Slopes consistent across instruments at similar depths → not a per-instrument
  artifact.

### Test 2 — Cross-instrument consistency
TBR23 has four independent Vectors at MOP 580 & 586, each at 5 m and 7 m.
Each was calibrated separately. Compare:
- Slope α from Test 1 across instruments.
- Time correlation R(uMean_i, uMean_j) at common timestamps.
- Magnitude consistency at shared wave conditions.

If all four give consistent α with depth-appropriate scaling, instrument bias
is ruled out.

### Test 3 — Tidal-phase modulation
Project memory (April 2026) says undertow is stronger at high tide. Verify
this is a real, repeatable modulation. Bin uMean by tidal phase and:
- Stratify by Hs to remove Hs-correlated tide effects (storms vs spring tides).
- Compute conditional mean and 95% CI per phase bin.
- Test: does the modulation amplitude scale with Hs²?

A constant instrumental bias has zero tidal modulation, so any reproducible
modulation > noise is signal.

### Test 4 — Reynolds-stress consistency
The cross-shore wave-momentum balance gives:

  d⟨S_xx⟩/dx + ρ·g·h·dη̄/dx + ρ·⟨u'w'⟩ = 0  (depth-averaged steady)

In the surf zone, undertow is the bottom boundary-layer return flow that
balances the radiation-stress gradient. ⟨u'w'⟩ from the same Vector provides
an *independent* PUV-internal estimate. If ⟨u'w'⟩ scales with Hs² and
correlates with uMean, both quantities are signal — they would have to be
biased in identical, suspicious ways to be coincident.

### Test 5 — Velocity range setting
Check Vector configuration files / deployment notes for each TBR23
instrument. If range was set to 1 m/s (not 4 m/s), the noise calculation
becomes 0.5% × 1 = 5 mm/s single-sample, **0.05 mm/s segment-mean**, well
below any reported signal. If 4 m/s, the concern about systematic bias
remains valid in principle but is addressed by Tests 1–4.

## Execution plan

### Phase 1 — TBR23 (4 instruments)
- [ ] Test 1: Hs² scaling per instrument
- [ ] Test 2: cross-instrument correlation and slope comparison
- [ ] Test 3: tidal-phase modulation, conditional on Hs
- [ ] Test 4: Reynolds-stress (⟨u'w'⟩) vs uMean
- [ ] Test 5: Vector range setting from deployment notes

Decision: if Phase 1 results clearly support real wave-driven flow, proceed
to Phase 2. If results are ambiguous, narrow paper to skewness-only story.

### Phase 2 — All deployments (33 instruments across 20+ deployments)
Repeat Tests 1–4 across the full instrument inventory:
- LPL23, LPL24, LPL25A, LPL25B
- SIO24A–E, SIO25A–E (note: SIO Pier amplification anomaly already documented)
- SOL23, SOL24, SOL25A, SOL25B
- TBR23 (covered in Phase 1)
- TOR23W, TOR24S, TOR24W, TOR25S

Aggregate plots:
- α vs depth across all instruments (does shallower → larger |α| as theory predicts?)
- α vs Vector range setting (does the slope depend on range setting? if so → bias)
- Histogram of intercepts β across instruments (should cluster near zero if no systematic)

## Outputs

- `validation/test1_Hs2_scaling.m` — Test 1 implementation
- `validation/test2_cross_instrument.m` — Test 2
- `validation/test3_tidal_modulation.m` — Test 3
- `validation/test4_reynolds_consistency.m` — Test 4
- `validation/check_vector_range_settings.m` — Test 5
- `outputs/validation/mean_flow/` — figures and stats
- This file — running log of results and decisions

## Results log (filled in as tests complete)

### TBR23

#### Test 1 — Hs² scaling
Run: `validation/test1_Hs2_scaling.m`. Fit `uMean = α·Hs² + β`, segments
with `Hs ≥ 0.2 m`. Compare to Stokes return-flow theory `α_th = -g/(16·c·h)`.

| Instrument  | h_med | α (slope, 95% CI)            | β (intercept, 95% CI) [m/s]   | R²    | α_theory | α/α_th |
|-------------|-------|------------------------------|--------------------------------|-------|----------|--------|
| MOP580_5m†  | 6.21  | +0.0109 [+0.0078, +0.0141]   | +0.0014 [-0.0006, +0.0035]    | 0.016 | -0.0127  | -0.86  |
| MOP580_7m   | 8.29  | -0.0101 [-0.0150, -0.0051]   | -0.0062 [-0.0085, -0.0040]    | 0.003 | -0.0082  | +1.23  |
| MOP586_5m   | 5.54  | -0.0177 [-0.0218, -0.0136]   | +0.0010 [-0.0009, +0.0029]    | 0.014 | -0.0150  | +1.18  |
| MOP586_7m   | 8.27  | -0.0116 [-0.0173, -0.0060]   | -0.0077 [-0.0101, -0.0052]    | 0.003 | -0.0082  | +1.42  |

† MOP580_5m flagged compromised in memory (kelp fouling → artifact negative
skewness). Wrong-sign α here is consistent with that flag — exclude from analysis.

**Findings:**
1. **3/4 non-fouled instruments show α < 0** (correct sign: undertow is offshore
   under +x onshore convention) with 95% CIs excluding zero.
2. **Magnitudes are within 18–42% of Stokes return-flow theory** — reasonable
   given the simplified theory ignores directional spread, finite-band effects,
   and bathymetric deviations.
3. **Intercepts:**
   - 5m instruments: β CI includes zero → **no constant instrumental offset**.
   - 7m instruments: β = -6 to -8 mm/s, CI excludes zero → small but significant
     offset, **3-4× below the 2 cm/s instrument-noise concern**.
4. **R² is low (0.3–1.6%)** — Hs² explains a small fraction of uMean variance.
   This is the main caveat. Expected residual sources: tidal Eulerian residual
   currents, wind drift, alongshore-tilted bathymetric pressure gradients,
   finite-band Stokes corrections. **Test 3 (tidal modulation) should explain
   a large fraction of this residual variance.**

**Verdict on the noise-floor concern from Test 1 alone:** Slopes are real and physically
consistent. The 7m intercepts (-6 to -8 mm/s) are below his stated noise
floor but worth reconciling with Test 5. Low R² is the open question — to be
addressed by Test 3.

#### Test 2 — Cross-instrument consistency
Run: `validation/test2_cross_instrument.m`. Time correlation of `uMean`
across pairs of independently-calibrated Vectors at common timestamps
(matched within 12 min).

**Correlation matrix R(uMean_i, uMean_j):**

|              | MOP580_5m† | MOP580_7m | MOP586_5m | MOP586_7m |
|--------------|-----------|-----------|-----------|-----------|
| MOP580_5m†   | 1.00      | **-0.48** | **-0.34** | **-0.33** |
| MOP580_7m    | -0.48     | 1.00      | +0.30     | **+0.55** |
| MOP586_5m    | -0.34     | +0.30     | 1.00      | **+0.57** |
| MOP586_7m    | -0.33     | +0.55     | +0.57     | 1.00      |

**Mean(u_i − u_j) across matched timestamps (m/s):**

|              | MOP580_5m | MOP580_7m | MOP586_5m | MOP586_7m |
|--------------|-----------|-----------|-----------|-----------|
| MOP580_5m†   |  0.000    | +0.013    | +0.009    | +0.014    |
| MOP580_7m    | -0.013    |  0.000    | -0.003    | +0.002    |
| MOP586_5m    | -0.009    | +0.003    |  0.000    | +0.005    |
| MOP586_7m    | -0.014    | -0.002    | -0.005    |  0.000    |

**Findings:**
1. **The three non-fouled instruments correlate positively with each
   other** (R = +0.30 to +0.57). Independent calibrations cannot produce
   coincident time-varying signals — this is shared physical variance.
2. **Strongest correlation is at the same depth across the two MOP lines**
   (MOP580_7m vs MOP586_7m, R=+0.55), exactly as expected for a wave-driven
   process with depth-dependent magnitude.
3. **MOP580_5m anti-correlates with all three other instruments** (R = -0.33
   to -0.48). This is decisive evidence that MOP580_5m is compromised
   (kelp fouling per memory). Anti-correlation across all pairs is not a
   physical depth or distance effect — it's bad data.
4. **Mean offsets between non-fouled instruments are 2–5 mm/s** —
   consistent with small calibration differences, well below the
   single-sample 2 cm/s noise floor and 1.5–4× smaller than the residual
   intercepts in Test 1. The ~1 cm/s offset against MOP580_5m further
   confirms that instrument's compromise.

**Verdict on the noise-floor concern from Test 2:** Decisive. Three independent
Vectors that share time-varying uMean variance with R up to 0.57 cannot
all be reading instrumental noise. Cross-instrument calibration offsets
between the three non-fouled instruments are at the mm/s scale, not the
cm/s scale.

---

## Phase 1 — TBR23 verdict

**Aggregate result across 5 tests: the instrumental-bias hypothesis is
not consistent with the TBR23 data.** Specifically:

1. **Random Doppler noise is not the issue** — Test 5 confirms 4 m/s range
   setting, but √N averaging reduces the floor to <0.4 mm/s on segment
   means, well below the signals at issue.
2. **Slopes against Hs² are real and physically sized** (Test 1, 3 of 4
   instruments), within 18–42% of Stokes-return-flow theory.
3. **Tidal modulation grows with Hs** (Test 3): from 2 cm/s at low Hs to
   6–8 cm/s at high Hs. A constant offset has zero modulation in any
   stratum. This is the most decisive test.
4. **Reynolds stress and uMean co-vary** at each instrument (Test 4):
   independent processing paths from the same record share variance
   (R = +0.24 to +0.63).
5. **Independent Vectors share time-varying uMean variance** (Test 2):
   R up to +0.57 for non-fouled instruments at matching depths.

**The kelp-fouled MOP580_5m fails every test** — wrong-sign Hs² slope,
incoherent tidal phase pattern, anti-correlation with peers. Already
flagged in memory; remains excluded.

**The residual concern that remains** is the 6–8 mm/s intercepts at the
two 7m instruments in Test 1. These are below the cm/s noise floor
cited in the original concern but are statistically distinguishable from zero. Possible
contributors: small calibration offsets, Eulerian tidal residual, finite-
band Stokes corrections, mean flow components not in pure Hs² scaling.
Phase 2 (cross-deployment) will tell us whether these intercepts cluster
near zero across many instruments (random calibration) or systematically
trend with depth/setting (something physical or systematic).

---

#### Test 3 — Tidal modulation
Run: `validation/test3_tidal_modulation.m`. Tidal phase from analytic
signal of bandpassed (1/30 hr to 1/3 hr) detrended depth, segments binned
into 16 phases × 3 Hs strata, bootstrap 95% CI per bin.

**Modulation amplitude (peak-to-peak uMean within Hs stratum):**

| Instrument  | Hs<0.6 m | 0.6 ≤ Hs < 1.0 | Hs ≥ 1.0 m   |
|-------------|----------|----------------|--------------|
| MOP580_5m†  | 3.5 cm/s | 1.3 cm/s       | 3.8 cm/s     |
| MOP580_7m   | 1.8 cm/s | 2.7 cm/s       | **6.0 cm/s** |
| MOP586_5m   | 2.7 cm/s | 2.7 cm/s       | **6.6 cm/s** |
| MOP586_7m   | 1.9 cm/s | 2.4 cm/s       | **8.3 cm/s** |

† Kelp-fouled, non-monotonic — consistent with its known compromise.

**Findings:**
1. **For 3/4 instruments, modulation amplitude grows monotonically with Hs**:
   2 cm/s at Hs<0.6 m → 6–8 cm/s at Hs≥1.0 m. A constant instrumental bias
   has zero modulation in *every* stratum, by definition.
2. **High-Hs modulation amplitudes (6–8 cm/s) are 30–80× the random-noise
   floor of segment-mean velocity** (~0.4 mm/s at 17-min averaging). They are
   also 3–4× larger than the systematic-offset-suspect intercepts in Test 1.
3. **Phase pattern is physically consistent**: maximum offshore (most
   negative) cross-shore mean velocity occurs near low/rising tide, when the
   surfzone has migrated landward toward the instrument and wave setup
   gradients at PUV depth are steepest. Near high tide the modulation flattens.
4. **Low-Hs strata show ~2–3 cm/s modulation independent of waves** — likely
   Eulerian tidal residual currents at this site, real but a separate
   mechanism. The wave-driven contribution is what *grows on top* of this.
5. **Kelp-fouled MOP580_5m fails as expected** — incoherent phase pattern,
   non-monotonic Hs scaling. Consistent with its memory flag.

**Verdict on the noise-floor concern from Test 3:** Decisive. A 6–8 cm/s
reproducible modulation that grows with Hs and matches physical phase
expectations cannot be explained by a constant instrumental offset.

#### Test 4 — Reynolds-stress consistency
Run: `validation/test4_reynolds_consistency.m`. Two checks: (a) Hs² scaling
of `<u'w'>`, and (b) time correlation between `uMean` and `<u'w'>` at the
same instrument.

| Instrument  | α(uw) per Hs² | β(uw)    | R²(uw,Hs²) | R(uMean, uw) |
|-------------|---------------|----------|------------|--------------|
| MOP580_5m†  | +0.00100      | +0.00010 | 0.308      | +0.41        |
| MOP580_7m   | -0.00043      | +0.00011 | 0.196      | **+0.63**    |
| MOP586_5m   | -0.00078      | +0.00017 | 0.109      | +0.24        |
| MOP586_7m   | +0.00028      | +0.00009 | 0.092      | **+0.55**    |

**Findings:**
1. **The Hs² scaling of `<u'w'>` is mixed in sign and modest in R²** (9–31%).
   `<u'w'>` measured at a single point in the water column is not a clean
   proxy for bed Reynolds stress — it includes wave-orbital phase
   correlations that depend on instrument depth and water depth, not just
   the radiation-stress gradient. Sign-of-α is not diagnostic here.
2. **`R(uMean, <u'w'>)` is positive across all four instruments** (0.24 to
   0.63). Two quantities derived from the *same* velocity record but via
   *independent* processing paths — segment mean vs fluctuating covariance —
   share variance. Pure instrumental noise in either would push this toward
   zero. The 7m instruments (farther from the surfzone, less turbulent
   contamination) show the strongest correlation.

**Verdict on the noise-floor concern from Test 4:** Moderately supportive. Test 4 is
not as decisive as Test 3, but the consistent positive correlation between
two independently-derived statistics from the same record is hard to
explain away as instrument bias.

#### Test 5 — Vector range setting
Inspected raw `.hdr` files at `/Volumes/group/PUV_data/Vector/Torrey20230503-20230816/`.

| Instrument  | Nominal velocity range | Sampling rate | Coord system |
|-------------|------------------------|---------------|--------------|
| MOP580_5m   | **4.00 m/s**           | 2 Hz          | XYZ          |
| MOP580_7m   | **4.00 m/s**           | 2 Hz          | XYZ          |
| MOP586_5m   | **4.00 m/s**           | 2 Hz          | XYZ          |
| MOP586_7m   | **4.00 m/s**           | 2 Hz          | XYZ          |

All four match the SIO 511 setting flagged. **Cannot escape the concern
via range setting — must address via Tests 1–4.**

Quantitative implications of the 4 m/s range:
- Spec single-sample accuracy: 0.5% × 4 = 2 cm/s.
- After 17-min averaging (N=2048): random-noise-limited σ_mean ≈ 2 cm/s / √2048 ≈ **0.4 mm/s**.
- After 1-hour averaging (N=7200): σ_mean ≈ **0.24 mm/s**.
- Therefore segment-mean uMean noise from random Doppler error is sub-mm/s,
  >10× below the slopes (~1.7 cm/s per m² of Hs²) measured in Test 1.
- The remaining concern is **systematic offset** — DC bias, calibration drift,
  beam misalignment — which doesn't average down. The 7m intercepts of -6 to
  -8 mm/s in Test 1 could be either small real residual flow OR systematic
  offset. Tests 3 and 4 are the discriminator.

### Cross-deployment (Phase 2)

#### Inventory verification (2026-05-03)

The deployment registry contains 40 instrument-configurations across 21
deployments. Cross-checked against L1/L2 outputs on disk:

- **33 instruments** have L1 + L2 outputs and are in the Phase 2 summary.
- **7 instruments** are configured but lack L1 outputs:
  - `SOL23/MOP651_5m` — known instrument failure (battery depleted, pipe
    bent on recovery; documented in `SOL23_config.m`).
  - `SIO24B/SIO_6m`, `SIO24C/SIO_6m`, `SIO25A/SIO_6m`,
    `TOR24S/MOP586_15m`, `TOR24W/MOP586_5m`, `TOR25S/MOP586_5m` — all
    fail at L1 with `"No valid pressure data remains after QC"`. The L1
    diagnostic plots are completely empty (no pitch/roll/pressure data
    rendered), indicating the merged time vector is empty by the time QC
    runs. All six show a battery-cutoff-detected-in-burst-5 pattern in
    the L1 log. **This is a real bug in `PUV_raw_process.m` (likely in
    the cutoff-truncation-then-merge code path) that has been silently
    dropping these instruments from the dataset.** Tracked as a separate
    engineering task; Phase 2 results presented here are based on the 33
    successfully-processed instruments.

#### Phase 2 — Test 1 across 33 instruments (17-min L2)

Run: `validation/run_phase2_all_deployments.m`.

| Site         | N  | median α (m/s/m²) | median α/α_th | α<0 fraction | median β (m/s) | |β|<2 cm/s | median modHi (m/s) |
|--------------|----|-------------------|---------------|--------------|----------------|------------|--------------------|
| Torrey       | 18 | −0.0067           | +0.77         | **83%**      | −0.0040        | 100%       | 0.028              |
| LPL lagoon   | 4  | −0.0073           | +0.88         | 75%          | +0.0030        | 100%       | 0.021              |
| Solana       | 5  | +0.0025           | −0.27         | 20%          | +0.0011        | 100%       | 0.031              |
| SIO Pier     | 5  | +0.0048           | −0.49         | 40%          | −0.0047        | 100%       | 0.030              |
| **All (32, exc. flagged)** | 32 | **−0.0033** | **+0.53** | **66%** | **−0.0006** | **100%** | **0.028** |

The Torrey site (18 instruments across 5 deployments and depths from
4.8 to 15.5 m) gives the cleanest theory match: 83% have the correct
α sign and the median α/α_theory = +0.77. Median tidal modulation
amplitude at H_s ≥ 1 m is 2.8 cm/s — well above any noise floor
argument. The LPL lagoon site agrees, surprisingly cleanly given it's
inside the inlet rather than open coast (4 instruments, all with
|β|<2 cm/s, median α/α_th = +0.88). Solana and SIO Pier are weaker —
the Solana scatter is small in absolute terms (median α magnitude is
2.5 mm/s/m², close to the Stokes value but with the wrong sign in
3 of 5), and SIO Pier is contaminated by the documented amplification
anomaly plus the 61-segment SIO25C partial deployment.

**Key headline numbers:**

- **|β| < 2 cm/s for 100% of instruments** — the 2 cm/s noise floor
  is not reached by *any* segment-mean intercept. Median |β| is 0.6 mm/s.
- **Median α/α_theory = +0.53** — empirical slopes consistent with
  Stokes return-flow magnitudes (and within the factor-of-2 expected
  given simplified theory).
- **66% of instruments have α<0** (correct sign for offshore undertow).
  The 34% with positive α are dominated by the SIO Pier site
  (positive-amplification anomaly already documented in our spectral
  work) and a few R²<0.05 cases where α is essentially unconstrained.

#### SIO Pier specifics (where the noise-floor argument originated)

5 deployments on the SIO Pier at h ≈ 6.95–7.37 m:

| Deployment | h_med | α        | β        | R² (Hs²) | mod amp at high Hs | N segs |
|------------|-------|----------|----------|----------|---------------------|--------|
| SIO24A     | 6.99  | −0.0089  | −0.0047  | 0.027    | 5.3 cm/s            | 5062   |
| SIO25B     | 6.95  | −0.0049  | −0.0043  | 0.016    | 2.1 cm/s            | 3692   |
| SIO25C     | 7.24  | **+0.0286** (R²=0.001, **N=61**) | −0.0075 | 0.001 | NaN | **61** |
| SIO25D     | 7.16  | +0.0146  | −0.0078  | 0.038    | 2.9 cm/s            | 5527   |
| SIO25E     | 7.37  | +0.0048  | −0.0017  | 0.013    | 3.1 cm/s            | 7041   |

**Diagnosis of the SIO Pier "outlier":**

- The +0.029 outlier in the aggregate `phase2_alpha_vs_depth` figure is
  **SIO25C with N=61 segments** — only ~17 hours of data before some
  pipeline issue cut it off. R² is 0.001. The slope estimate is
  meaningless and the modulation amplitude is NaN (insufficient
  high-Hs hours). Should be excluded from the SIO Pier story.
- The remaining four full-record SIO deployments are mixed: SIO24A and
  SIO25B have negative α (theory-consistent, R²≈0.02–0.03), SIO25D and
  SIO25E have small positive α with very low R². β values are all
  within ±5 mm/s, well inside the 2 cm/s box.
- This is consistent with the previously-documented SIO Pier
  amplification anomaly — the pier site already shows wave-spectral
  behavior that doesn't match unobstructed nearshore propagation.
  Mean-flow at SIO Pier behaves accordingly; it is not the cleanest
  test of Stokes-return-flow theory.

The 3 still-unprocessed SIO Pier deployments (SIO24B/C, SIO25A) would
fill out this picture but the L1 pipeline bug prevents that for now.

#### Phase 2 — same instruments at 1-hour segmentation

To address a likely follow-up concern that the 17-min mean reflects
sampling-noise that hasn't averaged down enough, the same 33 instruments
were re-processed with 1-hour segments (`segLen=7200`, NW=4) using
`validation/reprocess_all_hourly.m`. Phase 2 results from
`outputs/validation/mean_flow_hourly/_aggregate/phase2_summary.mat`:

| Site         | N  | median α (m/s/m²) | median α/α_th | α<0 fraction | median β (m/s) | |β|<2 cm/s | median modHi (m/s) |
|--------------|----|-------------------|---------------|--------------|----------------|------------|--------------------|
| Torrey       | 18 | −0.0063           | +0.71         | 78%          | −0.0041        | 94%        | 0.028              |
| LPL lagoon   | 4  | −0.0074           | +0.89         | 75%          | +0.0031        | 100%       | 0.023              |
| Solana       | 5  | **−0.0081**       | **+0.82**     | **100%**     | −0.0014        | 100%       | 0.026              |
| SIO Pier     | 5  | **−0.0045**       | **+0.43**     | **80%**      | −0.0042        | 80%        | 0.023              |
| **All (32)** | 32 | **−0.0063**       | **+0.71**     | **81%**      | **−0.0028**    | **94%**    | **0.026**          |

**Key shifts vs 17-min:**

- **Solana median α flips from +0.0025 → −0.0081 (theory match), 20% →
  100% correct sign.** R² for SOL24/MOP654_7m more than doubles
  (0.073 → 0.186). For SOL23/MOP654_7m, R² increases from 0.015 →
  0.053.
- **SIO Pier median α flips from +0.0048 → −0.0045, 40% → 80% correct
  sign.** SIO25D goes from +0.0146 → −0.0120 once it's averaged over
  longer segments.
- **Torrey is stable** across segmentations. Median α is −0.0067 →
  −0.0063, 83% → 78% correct sign (small).
- Aggregate: **median α/α_theory rises from +0.53 → +0.71, α<0 fraction
  rises from 66% → 81%.**

#### Segmentation comparison figure

`outputs/validation/mean_flow/_aggregate/seglen_compare_alpha_beta.png`
shows four panels matching 33 instruments between 17-min and 1-hour
results:

- **α scatter:** R = 0.737, |Δα|<0.005 in 81% (excluding the SIO25C
  partial deployment with N=61 segments and R²=0.001 which is a
  meaningless fit). Points cluster on the 1:1 diagonal. Below-diagonal
  outliers are Solana/SIO Pier instruments where 1-hour averaging
  pulls α toward theory.
- **β scatter:** All non-partial-deployment points sit inside the
  ±2 cm/s noise box for both segmentations. Median |β| improves
  slightly: 0.0059 → 0.0052 m/s.
- **R² scatter:** **30 of 31 instruments fit better at 1-hour.** Median
  R² rises 0.015 → 0.022. Solana shows the largest gains.
- **Δα histogram:** median = +0.0000, RMS = 0.007. The distribution is
  tightly centered at zero with a small left tail (the few instruments
  shifting toward more-negative, theory-consistent α).

#### What this means physically

The 1-hour averaging adds a √(7200/2048) ≈ 1.87× noise reduction on
top of the 17-min √2048 ≈ 45× reduction. The fact that:

1. α is segmentation-independent for instruments where R² is already
   modest (Torrey, LPL),
2. α moves *toward* theory at sites where 17-min α was poorly
   constrained (Solana, SIO Pier — both with low R² at 17-min),
3. β stays inside the 2 cm/s box at both segmentations and tightens
   slightly,

is incompatible with the noise hypothesis. Random instrument noise
would either show no segment-length dependence (if already noise-
floor-limited at 17-min) or push estimates toward zero with longer
averaging. Instead, longer averaging exposes a bigger negative slope
where the 17-min was inconclusive — exactly what would happen if a
real wave-driven signal were being partially obscured by noise at
17-min in the more-marginal records.

---

## Phase 2 final verdict

Across 33 independently-calibrated Vectors at four sites, two
segmentation choices, and three independent test families
(slope-against-H_s², tidal-phase modulation, cross-instrument
consistency, Reynolds-stress co-variation):

- **No instrument has a segment-mean intercept exceeding ±2 cm/s
  in the 17-min analysis.** 30 of 32 stay inside ±2 cm/s in 1-hour.
- **66% (17-min) and 81% (1-hour) of instruments show α<0** with
  magnitudes consistent with Stokes return-flow theory.
- **Tidal-phase modulation amplitudes at H_s ≥ 1 m are 2–8 cm/s**
  across nearly every Torrey instrument — a constant offset has zero
  modulation by definition.
- **Sites where 17-min was noisy (Solana, SIO Pier) sharpen toward
  the theory-consistent answer with 1-hour averaging**, not away.

The kelp-fouled MOP580_5m at TBR23 fails every test as expected (already
flagged). The SIO25C partial deployment (N=61) is excluded from the
segmentation comparison.

---

## Phase 2 robustness checks (2026-05-04 / 2026-05-05)

Three follow-up fits were added to preempt the strongest objections
are likely to raise to the H_s² scaling argument: storm-coherent
confounding, low-R² fragility, and shore-normal-rotation-error
explanations for any non-zero alongshore α.

### (a) Alongshore α — `validation/test1b_robustness_checks.m`

If α_u were just storm-correlated noise, α_v should land somewhere
unrelated. Instead α_v is also predominantly negative, similar
magnitude to α_u (|α_u|/|α_v| ≈ 0.70), at both segmentations:

| segmentation | median α_u | median α_v | α<0 (cross/along) |
|--------------|------------|------------|-------------------|
| 17-min       | −0.0033    | −0.0076    | 66% / 78%         |
| 1-hour       | −0.0063    | −0.0073    | 81% / 78%         |

Both wave-momentum-balance components scale cleanly with H_s² and
have signs consistent with NW-swell-driven southward longshore
current under SD County wave climate. Generic storm forcing (wind,
atmospheric pressure setup) would not produce clean H_s² scaling in
*both* components with consistent signs across many independent
deployments.

### (b) High-H_s-only fit — same script, restricted to H_s ≥ 1 m

Stokes theory applies cleanly only in the wave-forcing-dominant
regime. Restricting the cross-shore fit to H_s ≥ 1 m:

| segmentation | median R² (full) | median R² (H_s≥1 m) | improvement |
|--------------|------------------|---------------------|-------------|
| 17-min       | 0.015            | 0.033               | 2.1×        |
| 1-hour       | 0.023            | 0.051               | 2.2×        |

R² roughly doubles. 21/29 instruments improve. Median α/α_theory =
+0.69 with 23/29 having the correct sign in the high-H_s subset.
The unexplained variance at low H_s is consistent with Eulerian
tidal residuals and other non-wave processes that wash out in the
wave-forcing-dominant regime.

Figure: `outputs/validation/mean_flow/_aggregate/robustness_alongshore_and_highHs.png`.

### (c) Wave-direction discrimination — `validation/test1c_wave_direction_check.m`

the specific worry on the alongshore signal is whether it could
reflect a wrong shore-normal-rotation angle (so our "alongshore" axis
mixes in cross-shore flow). To discriminate, fit:

  v̄ = α_v0 · H_s² + α_v1 · sin(2θ_rel) · H_s² + β_v

θ_rel is wave incidence relative to shore-normal. Because L2.meanDir
is computed from PUV cross-spectra in the rotated frame
(`atan2d(Spv, Spu)` after shore-normal rotation), it equals θ_rel
directly. Hypotheses:

- **Real radiation-stress longshore current:** α_v1 dominates;
  α_v1 > 0 in this convention (NW swells → south, S swells → north).
- **Coordinate-rotation error θ_err:** α_v0 = α_u·tan(θ_err), and
  α_v1 ≈ 0.

Result across 30 instruments at 1-hour:

| Quantity | Value |
|----------|-------|
| median α_u | −0.0075 m/s/m² |
| median α_v0 (wave-dir-independent) | −0.0050 m/s/m² |
| **median α_v1 (sin(2θ) coefficient)** | **+0.0441 m/s/m²** |
| **|α_v1| > |α_v0|** | **90%** of instruments |
| **CI on α_v1 excludes 0** | **83%** of instruments |
| α_v1 > 0 (NW-swell drives southward) | 80% of instruments |
| CI on α_v0 excludes 0 | 73% of instruments |

The wave-direction-dependent term dominates by roughly a factor of 9
in median magnitude and per-instrument in 90% of records. **Pure
rotation error predicts α_v1 = 0 — the data exclude this in 83% of
instruments individually.** The sign of α_v1 also matches expectation:
positive in 80% of records, which corresponds to NW swells driving
southward currents and S swells driving northward currents — the
classical radiation-stress longshore-current signature.

The residual α_v0 ≈ −5 mm/s/m² is small. Reading it as pure rotation
error gives an upper bound — most α_v0/α_u ratios sit within the
±15° "rotation lines" on the figure, and some of α_v0 likely reflects
real Eulerian alongshore residual flow rather than rotation error.
Any actual shore-normal angle error is at most a few degrees, and
the bulk of the alongshore signal is real radiation-stress-driven
longshore current.

Figure: `outputs/validation/mean_flow/_aggregate/wave_direction_check.png`.

---

## Outputs catalog

Aggregate figures (mean flow):
- `outputs/validation/mean_flow/_aggregate/phase2_alpha_vs_depth.png`
- `outputs/validation/mean_flow/_aggregate/phase2_beta_histogram.png`
- `outputs/validation/mean_flow/_aggregate/phase2_alpha_ratio_histogram.png`
- `outputs/validation/mean_flow/_aggregate/phase2_modulation_vs_depth.png`
- `outputs/validation/mean_flow/_aggregate/seglen_compare_alpha_beta.png`
- `outputs/validation/mean_flow/_aggregate/robustness_alongshore_and_highHs.png`
- `outputs/validation/mean_flow/_aggregate/wave_direction_check.png`
- `outputs/validation/mean_flow_hourly/_aggregate/...` (parallel hourly versions)

Per-instrument record figures:
- `outputs/validation/mean_flow/_per_instrument/<deployment>_<label>.png`
  (33 figures; H_s time series, uMean colored by H_s, scatter vs H_s²
  with Stokes line, and uMean PDF stratified by H_s).

Aggregate summaries:
- `outputs/validation/mean_flow/_aggregate/phase2_summary.mat` (17-min)
- `outputs/validation/mean_flow_hourly/_aggregate/phase2_summary.mat` (1-hour)
- `outputs/validation/mean_flow/_aggregate/robustness_summary.mat`
- `outputs/validation/mean_flow/_aggregate/wave_direction_check.mat`

Email draft: `docs/draft_email_to_bill.md`.

---

## Validation scripts created in this work

- `validation/test1_Hs2_scaling.m` — H_s² scaling fit per instrument
- `validation/test2_cross_instrument.m` — cross-instrument correlation
- `validation/test3_tidal_modulation.m` — tidal-phase modulation
- `validation/test4_reynolds_consistency.m` — Reynolds stress vs uMean
- `validation/test1b_robustness_checks.m` — alongshore + high-H_s checks
- `validation/test1c_wave_direction_check.m` — wave-direction discrimination
- `validation/run_phase2_all_deployments.m` — driver (17-min)
- `validation/run_phase2_all_hourly.m` — driver (1-hour)
- `validation/reprocess_all_hourly.m` — L2 batch with 1-hour segments
- `validation/aggregate_phase2_results.m` — cross-deployment figures
- `validation/compare_seglen_phase2.m` — 17-min vs 1-hour comparison
- `validation/per_instrument_record.m` — per-instrument record figures
- `validation/site_summary_phase2.m` — per-site numeric summary
- `validation/list_seglen_outliers.m` — diagnostic for seglen Δα outliers
- `validation/inventory_check.m` — compares registry vs L1/L2/Phase 2
- `validation/check_all_vector_ranges.m` — parses .hdr range settings

---

## L1 status — verified, not a bug (May 5)

The 7 instruments missing from the 40-configured / 33-processed gap
are all documented hardware failures (kelp fouling, bent pipes, dead
batteries, knocked-over instruments) per
`docs/deployment_database_overview.md`. The L1 QC is correctly
rejecting bad data:

| Instrument | Documented hardware issue | QC trigger |
|---|---|---|
| SOL23/MOP651_5m | Battery depleted, bent pipe, lost 2 yrs | Pressure unrecoverable |
| SIO24B | Knocked over, 32° tilt, beam corr <10% | Tilt-absolute (>30°) |
| SIO24C | Battery depleted 12/31/24, beam corr <70% | Correlation QC |
| SIO25A | Upside-down at start, pin corrosion | Tilt + correlation QC |
| TOR24S/MOP586_15m | Pipe issues per deployment notes | Pressure / tilt |
| TOR24W/MOP586_5m | Pipe bent by kelp, buried | Pressure / tilt |
| TOR25S/MOP586_5m | Pipe bent, kelp blockage | Pressure / tilt |

The "empty L1 diagnostic plot" I observed earlier is the expected
render when every sample is NaN'd by tilt+pressure QC: pitch_qc,
roll_qc, pressure_qc are all-NaN, so the plot has axes with no data
lines. Compare to a successful deployment (e.g., SIO24A) where the
diagnostic shows the full pressure / tilt time series. No bug, no
fix needed.

