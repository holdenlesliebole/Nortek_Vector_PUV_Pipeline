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

1,999 hourly segments across five records spanning 5.5–11.7 m depth and four
sites. Two of the records (TOR19W and TOR20W, MOP582, 10–11 m, 2019–2021) are the
same station, depth and era as the published analysis in this line, so the
numbers there transfer directly.

## D1 — auto/cross estimator mismatch

Worse than the code reading suggested. The legacy auto-spectra
(`calculate_fft2`) use a Hanning window with **50% overlap**
(`num = floor(2n/nfft)-1` ensembles); the cross-spectra (`cospec`) use a Hamming
window with **zero** overlap. The two differ in window *and* in degrees of
freedom, so `a1 = Re(Spu)/√(Spp·(Suu+Svv))` mixes estimators with different
variance as well as different spectral windows.

| quantity | median | IQR | 95th pct of \|Δ\| |
|---|---|---|---|
| mean direction $D_p$ | −0.06° | −1.56 to +1.45° | **7.2°** |
| $a_1$ at peak | −0.001 | −0.045 to +0.041 | 0.173 |
| $b_2$ at peak | +0.001 | −0.083 to +0.088 | **0.327** |

**Mean direction largely survives; $b_2$ does not.** $b_2$ is bounded on
$[-1,1]$, so a 95th-percentile error of 0.33 is a third of the available range.
Radiation stress $S_{xy}$ is built directly from $b_2$ and inherits this in full,
which makes legacy alongshore forcing the least trustworthy product of that
pipeline. $D_p$ is unbiased in the median because the error is random rather than
systematic, but individual hours reach 7°.

The error grows with directional spread (median \|Δ$D_p$\| of 1.43° below 15°
spread, 2.77° at 20–25°) and is largest at low $H_s$ — consistent with a
variance-driven mechanism rather than a bias.

*Caveat on the spread statistic.* Directional spread computed at the single peak
bin returned an interquartile range of 36°, which overstates the defect. With
zero-overlap cross-spectra the peak-bin $r_1 = \sqrt{a_1^2+b_1^2}$ is noisy and
occasionally exceeds 1, where it must be clamped, so a single-bin spread
amplifies the degrees-of-freedom difference rather than isolating the window
mismatch. The $a_1$ and $b_2$ figures above are the defensible ones. A
band-averaged spread would be the fair comparison and has not been run.

## D3 — NaN replaced by zero: latent for $H_s$, active for velocity

Could not be exercised as documented. The prediction was an $H_s$ deficit
proportional to gap fraction, but **pressure is essentially gapless** in these
records (NaN fraction 2×10⁻⁵), so the measured $H_s$ difference is identically
zero and the correlation with gap fraction is null ($\rho = +0.06$, $p = 0.08$).

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
| 6–8 | 739 | 0.000 |
| 8–10 | 121 | 0.002 |
| 10–40 | 800 | **0.018** |

Opposite to the expectation recorded above, which reasoned from noise
amplification being permitted in shallow water. Measured on $H_s$, the two rules
diverge in **deeper** water, where $K_p$ falls below the cutoff across more of the
band and the capped and zeroed treatments disagree over a wider frequency range.
The effect is 1.8% at 10 m and above, negligible below 8 m.

## Design differences, not defects

**Swell-band upper limit (0.20 vs 0.25 Hz).** Legacy $H_s^{SS}$ runs
**3.0% low** in the median, rising to 8.3% for $T_p < 8$ s and falling to 2.4%
for $T_p > 16$ s. As expected, this is a wind-sea effect and negligible in
swell-dominated conditions.

**Peak period definition.** The legacy energy-weighted centroid is **2.8 s lower**
than the argmax definition in the median (IQR −4.4 to −1.4 s, 95th percentile
7.2 s). This is the largest single difference between the pipelines and it is not
an error in either — the two quantities simply are not the same. Anyone
comparing a legacy $T_p$ against a $T_p$ from another study, or against a model
$T_p$, is comparing different definitions unless the centroid is stated.

## What this means for results produced with the legacy code

- **$H_s$ is safe to within a few percent**, with the caveat that the swell-band
  choice makes it 3% low relative to a 0.25 Hz cutoff and the $K_p$ rule adds
  ~2% at depths above 10 m. Neither is a defect; both are stateable offsets.
- **Mean wave direction is usable**, biased by less than 0.1° in the median,
  though individual hours reach 7°.
- **$T_p$ differs by definition, not by error** — the largest single discrepancy,
  and the one most likely to be misread as agreement or disagreement with other
  work.
- **Directional spread, $b_2$, radiation stress and alongshore forcing are the
  products to distrust.** D1 damages them directly and D3 compounds it by zeroing
  ~9% of the velocity record.
- **D2** (frequency-grid mismatch between `fm` and `f_co`) and **D5**
  (`Suv` indexed at line 49, computed at line 107) remain unquantified. They are
  structural faults with no correct magnitude to measure; D5 in particular either
  errors or silently reuses a stale workspace variable, and its effect depends on
  execution history rather than on the data.

## Limits of this comparison

Each defect was emulated from the legacy source rather than by running the legacy
pipeline end to end, so this measures the documented differences and would miss
any additional behaviour arising from their interaction. Five records at four
sites is a narrow condition span; in particular no record here has meaningful
pressure gaps, and none exceeds $H_s$ = 4 m. The single-bin spread caveat under
D1 applies.
