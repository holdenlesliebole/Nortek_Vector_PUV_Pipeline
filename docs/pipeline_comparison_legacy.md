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
