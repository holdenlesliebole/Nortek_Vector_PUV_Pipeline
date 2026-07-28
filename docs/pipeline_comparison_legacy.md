# Pipeline comparison: this PUV pipeline vs. the legacy pipeline (beachpeeps/PUV_Processing)

Notes for discussion with Mark. The legacy code is at:
- GitHub: https://github.com/beachpeeps/PUV_Processing
- Local copy: `Beach_Change_Observation/Vector/PUVs/PUV_Processing-main/Level2_QC/`

This comparison covers the fundamental spectral processing differences only, not downstream add-ons (Shields, Rouse, transport, etc.).

## Side-by-side parameter comparison

| Parameter | Multi-taper pipeline | Legacy pipeline |
|-----------|---------------|-------------------|
| Segment length | 2048 samples (17 min @ 2 Hz) | 2400 samples (20 min @ 2 Hz) |
| PSD method | Multi-taper (DPSS, NW=4, K=7 tapers) | Custom FFT via `get_spectrum()`/`calculate_fft2()` |
| Window | DPSS tapers | Hanning |
| nfft | 2048 (full segment) | 2400 (full segment) |
| df | 0.001 Hz | 0.00083 Hz |
| Cross-spectra | Same DPSS tapers as auto-spectra (`psd_multitaper`) | `cospec()` with Hamming window (different from auto!) |
| Pressure correction | Kp = cosh(k·z_sensor)/cosh(k·H); zero where Kp < 0.1 | K = cosh(k·depth)/cosh(k·doffp); cap K² at 10 |
| Swell band upper | 0.25 Hz | 0.20 Hz |
| Peak period | f at max(S_eta) in swell band | Energy-weighted centroid frequency |
| Energy flux | ρg ∫ cg·S_eta df | Two formulations: Cartesian (Sheremet et al. 2002) and directional (a1/b1 weighted) |
| Radiation stress | Sxx, Syy, Sxy from a2/b2 (Herbers & Guza 1989) | Full 2D tensor (Herbers & Guza 1989) |
| Z-test quality check | Computed and stored (not yet a QC gate) | Checks Spp vs (Suu+Svv) consistency |

## Issues in the legacy code

### 1. CRITICAL: Mismatched window functions between auto- and cross-spectra

Auto-spectra (`get_spectrum` → `calculate_fft2`) use a Hanning window. Cross-spectra (`cospec` → `cpsd`) use a Hamming window with zero overlap (`cospec.m:14-17`). The auto and cross spectra are computed with different estimators.

This violates a basic requirement: for coherence, phase, and directional coefficients to be valid, auto- and cross-spectra must use the same window and overlap. The directional coefficients a1 = Re(Spu) / sqrt(Spp·(Suu+Svv)) mix Hanning-windowed denominators with Hamming-windowed numerators. Estimated impact on directional parameters: 20-40% errors are plausible. Hs is less affected because it only uses auto-spectra.

Our pipeline uses DPSS multi-taper for both auto- and cross-spectra (same tapers, same nfft), preserving spectral consistency for directional analysis.

### 2. BUG: Frequency grid mismatch between fm and f_co

`get_spectrum` returns frequency vector `fm`. `cospec` returns a different vector `f_co`. Later code uses index arrays (`ii`, `ij`) computed from different grids to index into both. The hardcoded `nfft=2400` in `cospec.m:14` has a comment "changed from 7200. Why?" suggesting incomplete debugging. If the grids don't align, directional and pressure-correction calculations silently mix frequencies.

### 3. NaN handling: zeros instead of interpolation

`calculate_fft2.m:11` replaces NaNs with zeros before the FFT. This biases spectra downward in proportion to the gap fraction — a segment with 5% NaN gets ~2.5% low Hs. Our pipeline rejects segments with >10% NaN and interpolates small gaps with `fillmissing`, which is standard practice.

### 4. Pressure correction: arbitrary cap vs principled cutoff

The legacy code caps Kp² at 10 (Kp ≈ 3.16 max amplification). No physical basis for this threshold. At shallow depths this allows substantial noise amplification at high frequencies. Our pipeline zeros frequencies where Kp < 0.1 (configurable), which is SNR-motivated: below that threshold the pressure signal is too attenuated to recover reliably.

### 5. Undeclared variable at line 49

`vector_wave_stats_hanning.m:49` sets `Suv(1:id_low) = NaN`, but `Suv` isn't computed until line 107. This either crashes or silently corrupts data from a previous iteration if the variable persists in workspace.

## Key differences that affect results but aren't bugs

### nfft and frequency resolution

Both pipelines now use full-segment FFTs with similar frequency resolution (df ≈ 0.001 Hz, ~24 bins across the swell peak). Our multi-taper estimator averages over 7 DPSS tapers for variance reduction, while the legacy single-periodogram approach has higher variance per bin. Hs (integral) is unaffected by either choice. See `multitaper_writeup.pdf` for the comparison that drove this method change.

### Swell band upper limit (0.25 vs 0.20 Hz)

During local wind events with short-period seas, the new Hs_SS includes energy that the legacy estimate excludes. In swell-dominated conditions the difference is negligible.

### Peak period definition

The new Tp = 1/f_peak (spectral maximum). The legacy Tm = 1/f_centroid (energy-weighted). These are fundamentally different quantities and will differ by seconds in bimodal seas.

## Items adopted from the legacy code (now in the new pipeline)

- **Z-test** (Spp vs velocity-derived pressure) — added as a QC diagnostic, computed and stored per segment for SS and IG bands. Not yet used as a hard gate.
- **a2, b2 second-harmonic directional coefficients** — computed from velocity auto- and cross-spectra and stored.
- **Radiation stress tensor** (Sxx, Syy, Sxy) — computed from S_eta and a2/b2 following Herbers & Guza (1989), integrated over the SS band.

## What the legacy code has that the new pipeline still doesn't

- **Full 2D directional spectrum** via maximum entropy method (MEM). We only compute first and second Fourier harmonics, sufficient for bulk direction and radiation stress but not for full directional reconstruction.

## What probably doesn't matter

- Segment length (17 vs 20 min): negligible effect.
- Hanning vs Hamming for auto-spectra alone: nearly identical windows. But using *different* windows for auto vs cross spectra is the problem.
- Both use the same wavenumber solver (nonlinear dispersion relation).

## Ruby2D head-to-head test (April 2026)

We reprocessed Ruby2D MOP582_6m (Oct 2021 -- Feb 2022, ~3100 hours of record) with the new multi-taper pipeline and matched it segment-by-segment against the legacy archived L2. The legacy run used **60-min segments** (not the 20 min from the source code) for Ruby2D, giving 3,095 segments; the new pipeline produced 10,903 17-min segments. Segments were matched on segment-midpoint nearest neighbor with a ±30 min tolerance.

**Setup notes:**
- The legacy L1 file (`Torrey_Ruby2D_582_6m_processed.mat`) has the same field structure as the new format (`PUV.time`, `PUV.P`, `PUV.BuoyCoord`, `PUV.fs`), so the new L2 ran directly on it via `scripts/process_ruby2d_one.m` after a thin adapter that adds `label`, `deploymentName`, and `doffp`. `doffp = 0.60 m` is a placeholder pending lookup in `DeploymentNotes2021Torrey.xls`.
  *(2026-07-27: resolved — the real values are 0.79 / 0.69 / 0.80 m for MOP578_10m /
  MOP579_6m / MOP582_30m, from that workbook's 'All Data' sheet. This line records
  the state at the time of the legacy comparison and is left as written.)*
- Legacy spectra are at `df = 0.000278 Hz` (60 min × 2 Hz = 7200 samples), about 3.5x finer than the new pipeline's `df = 0.000976 Hz` (2048 nfft).

### Bulk parameter agreement

| Metric        | Legacy (median) | Multi-taper (median) | Bias (MTM-Legacy) | RMS  | R²   |
|---------------|----------------:|--------------:|-------------------:|-----:|-----:|
| Hs (m)        | 0.771           | 0.757         | -0.009             | 0.053 | 0.981 |
| Tp (s) †      | 13.48           | 13.30         | -0.02              | 1.48  | 0.761 |
| Dir SS (deg)  | -7.3            | -7.2          | +0.2               | 1.2   | 0.927 |
| Spread (deg)  | 14.7            | 15.8          | +1.0               | 1.7   | 0.877 |
| Z-test SS     | 1.017           | 0.756         | --                 | --    | --    |

† Tp is restricted to the SS band (4-25 s) on both sides. Without this filter, the legacy Tp picker assigns a handful of segments to the IG/DC bin (e.g., Tp = 1200, 1800, 3600 s on Jan 15, 2022), tanking the R². The picker is not band-limited in the legacy code; this is a minor bug worth flagging if anyone uses the archived Tp directly.

**Headline:** the pipelines agree within 5 cm RMS on Hs, 1.2 deg on direction, and 1.7 deg on spread, despite the window mismatch, the pressure-correction floor change, and the spectral estimator change. Hs has a small negative bias (~9 mm), spread has a small positive bias (~1 deg, the new pipeline is slightly wider). Both biases are well below segment-to-segment variability.

### Spectral shape

Per-segment spectra are nearly indistinguishable in shape (see `outputs/validation/Ruby2D/ruby2d_582_6m_spectra.png`). At the median segment (Nov 27, 2021 03:00, Hs ≈ 0.77 m) and a storm peak (Dec 14, 2021 22:00, Hs ≈ 2.78 m, bimodal at 0.06 and 0.13 Hz), the integrated Hs values match within ~4% (averaging the three 17-min new-pipeline segments inside the legacy hour). The visible difference is exactly what multi-taper is for: the legacy single-periodogram spectra carry chi-square noise across the full frequency band, while the multi-taper estimate (DPSS K=7) is smoother because the variance is reduced ~7x per bin.

### Match rate

2,322 of 3,095 legacy segments matched (75%). The remaining 25% are hours where the new pipeline either dropped the segment (`segValid = false`, the new `nanMaxFrac = 0.10` rejects more aggressively than the legacy NaN-to-zero approach) or had no covering segments. This is consistent with `calculate_fft2.m:11` in the legacy code zeroing NaNs rather than rejecting them -- it keeps segments the new pipeline drops. For QA purposes, the dropped segments are presumably the noisier ones, so the matched-pair statistics are if anything pessimistic about the new pipeline's accuracy on the cleanest hours.

### Z-test discrepancy (~1.0 vs ~0.76)

The legacy median z = 1.02 (perfect P-UV consistency) while the new pipeline reports 0.76 (consistent with the systematic ~0.79 seen in TBR23). The new pipeline uses the same definition as the legacy code (`Spp_corrected vs (Suu+Svv)/Kp²`), so the difference is most likely:
1. The legacy code computes z on the **uncorrected** Spp (`Spec.SppU`) rather than the corrected (`Spec.SSE`), which is what the stored `ztest_ss_sum` uses.
2. Or we have a normalization bug worth checking.

This is the same gap we flagged in the multi-taper writeup -- worth a focused look but not blocking. Open question for follow-up.

### Conclusions and recommendation

1. **Hs results from Ruby2D do not need to be revisited.** Median difference is sub-cm, RMS is 5 cm. If anyone is using the archived Ruby2D Hs in publications or follow-on analysis, those numbers are essentially correct.
2. **Directional results agree to within 1-2 deg.** The window mismatch we identified in the legacy code does not produce the 20-40% directional errors we feared; the actual impact at this site is modest. This is worth understanding -- possibly the Hanning/Hamming window difference is small enough that the effect on a1, b1 is in the noise.
3. **The peak-period picker bug is real but rare.** A handful of Ruby2D hours have legacy-reported Tp at the IG/DC bin. Anyone reprocessing Ruby2D Tp should band-limit the peak picker.
4. **The Z-test discrepancy is the most interesting open thread.** Same systematic offset as TBR23 (~0.76 vs ~1.0) suggests something about the new pipeline's P-UV consistency calculation, not the data.
5. **The new pipeline is smoother.** The multi-taper variance reduction is visible at the spectral level, even when bulk parameters are essentially identical. This will matter for spectral excess analysis (PUV vs MOP), spectral shape diagnostics, and any analysis that depends on resolving narrow features in S(f).

---

# Quantified: which defect matters, where, and by how much (2026-07-27)

The five issues above were catalogued from code reading. This section measures
them. Each legacy choice was implemented as an isolated switch applied to
identical input, so every difference is attributable to one defect rather than to
the pipelines as wholes. Code: `validation/legacy_defect_isolation.m`.

**A formatted write-up of this section is at `docs/legacy_pipeline_defects.pdf`
(source `.tex` alongside it).** That is the version to hand to anyone outside the
lab; this file keeps the code reading that motivated each test.

3,713 hourly segments across **ten** records spanning 5.5–11.7 m depth, five
sites, and $H_s$ to 4.7 m. Two of the records (TOR19W and TOR20W, MOP582,
10–11 m, 2019–2021) are the same station, depth and era as the published analysis
in this line, so the numbers there transfer directly. Five records were added
2026-07-27 specifically to reach the two regimes the first pass could not: large
$H_s$ (TOR15B, max 4.67 m) and genuine pressure gaps (TOR14B 11%,
TOR23W/MOP586_10m 35%, RUBY22/MOP579_6m 85%).

## D1 — auto/cross estimator mismatch

Worse than the code reading suggested. The legacy auto-spectra
(`calculate_fft2`) use a Hanning window with **50% overlap**
(`num = floor(2n/nfft)-1` ensembles); the cross-spectra (`cospec`) use a Hamming
window with **zero** overlap. The two differ in window *and* in degrees of
freedom, so `a1 = Re(Spu)/√(Spp·(Suu+Svv))` mixes estimators with different
variance as well as different spectral windows.

| quantity | median | IQR | 95th pct of \|Δ\| |
|---|---|---|---|
| mean direction $D_p$ | −0.07° | −1.40 to +1.40° | 6.6° |
| spread, peak bin | −4.32° | −7.78 to +29.03° | 50.3° |
| spread, band-averaged | +0.26° | −9.45 to +6.24° | **17.1°** |
| $a_1$ at peak | −0.001 | −0.043 to +0.040 | 0.177 |
| $b_2$ at peak | +0.002 | −0.080 to +0.085 | **0.326** |

**Mean direction largely survives; $b_2$ does not.** $b_2$ is bounded on
$[-1,1]$, so a 95th-percentile error of 0.33 is a third of the available range.
Radiation stress $S_{xy}$ is built directly from $b_2$ and inherits this in full,
which makes legacy alongshore forcing the least trustworthy product of that
pipeline. $D_p$ is unbiased in the median because the error is random rather than
systematic, but individual hours reach 6.6°.

*Resolved: the spread statistic.* An earlier version of this section reported a
peak-bin spread IQR of 36° with the caveat that it overstated the defect, and
that caveat was right. Averaging the complex first moment over the band before
taking its modulus —
$\bar r_1 = |\sum_f S(f)(a_1+ib_1)| / \sum_f S(f)$, the Kuik et al. (1988)
form — suppresses the degrees-of-freedom noise and isolates the window mismatch.
It cuts the 95th percentile from **50.3° to 17.1°** and moves the median from
−4.3° to +0.26°. So roughly two-thirds of the peak-bin figure was DOF noise. The
defect is real and 17° is still large, but the band-averaged number is the one to
quote.

*Where it gets worse — and it is not where you would guess.* The error grows with
directional spread (median \|Δ$D_p$\| of 1.35° below 15° spread, 2.79° at
20–25°) but **falls monotonically with wave height**: 1.71° at $H_s < 0.5$ m down
to 0.83° above 3 m, with \|Δ$b_2$\| halving over the same range (0.129 → 0.059).
That is the signature of a variance-driven fault — at higher signal-to-noise the
two estimators converge. **Large waves are the regime where legacy directional
output is most trustworthy, not least.** The slight uptick in \|Δ$b_2$\| in the
top bin rests on 28 segments and should not be read as a reversal.

## D3 — NaN replaced by zero: latent for $H_s$, active for velocity

Could not be exercised as documented, and the reason turned out to be more useful
than the number would have been.

**The validity gate is what protects against this defect, not the NaN handling.**
Records were added specifically for their pressure gaps — 11%, 35% and 85% NaN in
the raw pressure. After `segValid`, essentially every surviving segment has a
pressure-gap fraction below 1%. The segments where zeroing would matter never
reach the spectral estimator. Where small gaps do survive, the fractional $H_s$
change is erratic rather than a deficit (median 0, IQR to +0.19) and gap fraction
does not predict it ($\rho = -0.06$, $n = 1152$) — the predicted mechanism
competes with a second one in the opposite direction, since zeroing part of an
oscillating record introduces step discontinuities that inject broadband energy.
Any reprocessing that relaxes the validity gate would expose this defect.

The gaps are in **velocity**: 8.8% NaN in $U$ and $V$ on TOR19W. So the defect
does not bias $H_s$ — it zeros roughly one sample in eleven of the velocity
record before the FFT, which removes velocity variance and therefore acts on the
directional coefficients and on $U_b$, compounding D1 on exactly the quantities
D1 already damages. The original write-up put this defect on the wrong quantity.

Testing the $H_s$ path properly needs a record with genuine pressure dropouts.

## D4 — Kp cap: matters at depth, not in shallow water

| depth (m) | n | median \|Δ$H_s$\|/$H_s$ |
|---|---|---|
| < 6 | 339 | 0.000 |
| 6–8 | 867 | 0.000 |
| 8–10 | 1387 | 0.005 |
| 10–40 | 1120 | **0.015** |

Opposite to the expectation recorded above, which reasoned from noise
amplification being permitted in shallow water. Measured on $H_s$, the two rules
diverge in **deeper** water, where $K_p$ falls below the cutoff across more of the
band and the capped and zeroed treatments disagree over a wider frequency range.
The effect is 1.5% at 10 m and above, negligible below 8 m.

This does not dismiss the shallow-water concern in the original code reading —
that was about noise admitted at high frequency, which affects the spectral tail.
$H_s$ is an integral dominated by the peak and is a poor detector of it.

## Design differences, not defects

**Swell-band upper limit (0.20 vs 0.25 Hz).** Legacy $H_s^{SS}$ runs
**2.9% low** in the median, rising to 7.8% for $T_p < 8$ s and falling to 2.5%
for $T_p > 16$ s. As expected, this is a wind-sea effect and negligible in
swell-dominated conditions.

**Peak period definition.** The legacy energy-weighted centroid is **2.73 s lower**
than the argmax definition in the median (IQR −4.29 to −1.47 s, 95th percentile
7.11 s). This is the largest single difference between the pipelines and it is not
an error in either — the two quantities simply are not the same. Anyone
comparing a legacy $T_p$ against a $T_p$ from another study, or against a model
$T_p$, is comparing different definitions unless the centroid is stated.

## What this means for results produced with the legacy code

- **$H_s$ is safe to within a few percent**, with the caveat that the swell-band
  choice makes it 2.9% low relative to a 0.25 Hz cutoff and the $K_p$ rule adds
  ~1.5% at depths above 10 m. Neither is a defect; both are stateable offsets.
- **Mean wave direction is usable**, biased by less than 0.1° in the median,
  though individual hours reach 6.6°. Best at large $H_s$, worst in broad seas.
- **$T_p$ differs by definition, not by error** — the largest single discrepancy,
  and the one most likely to be misread as agreement or disagreement with other
  work.
- **Directional spread, $b_2$, radiation stress and alongshore forcing are the
  products to distrust.** D1 damages them directly (95th-percentile $b_2$ error
  of 0.33 on a range of 2; band-averaged spread 17° at the 95th percentile) and
  D3 compounds it by zeroing ~9% of the velocity record.
- **D2** (frequency-grid mismatch between `fm` and `f_co`) and **D5**
  (`Suv` indexed at line 49, computed at line 107) remain unquantified. They are
  structural faults with no correct magnitude to measure; D5 in particular either
  errors or silently reuses a stale workspace variable, and its effect depends on
  execution history rather than on the data.

## Limits of this comparison

Each defect was emulated from the legacy source rather than by running the legacy
pipeline end to end, so this measures the documented differences and would miss
any additional behaviour arising from their interaction. Ten records at five
sites is still a narrow condition span: only 28 segments exceed $H_s$ = 3 m, and
**no valid segment carries a pressure-gap fraction above 1%** — so of the two
regimes this exercise set out to probe, one is covered thinly and the other not
at all. D2 and D5 remain unquantified. Where this file and the earlier draft
disagree on the spread statistic, the band-averaged figure supersedes.
