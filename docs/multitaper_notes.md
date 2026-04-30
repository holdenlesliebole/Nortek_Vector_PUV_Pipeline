# Multi-taper spectral estimation: scoping notes for PUV pipeline

**STATUS: IMPLEMENTED.** Multi-taper (NW=4, nfft=2048) is the default
spectral method in the pipeline as of April 2026. See
`multitaper_writeup.pdf` for the comparison results and recommendation,
and `shared/psd_multitaper.m` for the implementation. These notes are
preserved for historical context only.

---

Notes for discussion with Mark based on CPG sediment transport meeting, April 8 2026.

## Current implementation

The L2 spectral processor (`PUV_L2_spectral.m`) uses Welch's method with a Hanning window:

```matlab
win = hanning(256);      % nfft = 256 samples
noverlap = 128;           % 50% overlap
[Spp, ~] = pwelch(pSeg, win, noverlap, nfft, fs);  % auto-spectra
[Spu, ~] = cpsd(pSeg, uSeg, win, noverlap, nfft, fs);  % cross-spectra
```

Each 17-minute segment (2048 samples at 2 Hz) is subdivided into 256-sample sub-segments with 50% overlap, giving ~15 sub-segments per spectral estimate. Frequency resolution: df = fs/nfft = 2/256 = 0.0078 Hz.

## What multi-taper does differently

Welch's method reduces variance by averaging spectra from overlapping sub-segments, each multiplied by a single window (Hanning). Multi-taper (Thomson, 1982) instead applies K orthogonal tapers (discrete prolate spheroidal sequences, DPSS) to the *same* data segment and averages the K resulting spectra. The tapers are designed to concentrate spectral energy within a chosen half-bandwidth W.

The key parameter is the time-bandwidth product NW (typically 2-4), which sets the tradeoff:
- NW = 2 → 3 usable tapers, narrower bandwidth, lower variance reduction
- NW = 4 → 7 usable tapers, broader bandwidth, more variance reduction

## What would change in the pipeline

Five spectral quantities feed into all downstream products:

| Quantity | Type | Used for |
|----------|------|----------|
| Spp | auto | pressure correction → S_eta → Hs, Tp, Ef |
| Suu | auto | directional coefficients, bed velocity |
| Svv | auto | directional coefficients, bed velocity |
| Spu | cross | a1 directional coefficient |
| Spv | cross | b1 directional coefficient |

MATLAB's `pmtm` handles auto-spectra but not cross-spectra. To get multi-taper cross-spectra (needed for a1, b1), we'd compute tapered FFTs directly:

```matlab
[E, V] = dpss(nfft, NW);       % DPSS tapers, nfft x K
K = sum(V > 0.99);              % number of usable tapers

% For each sub-segment (or full segment):
Xk = fft(data .* E(:,1:K));     % tapered FFTs, nfft x K

% Auto-spectrum: mean over tapers
Sxx = mean(abs(Xk).^2, 2) / (fs * nfft);

% Cross-spectrum: mean over tapers
Sxy = mean(conj(Xk_x) .* Xk_y, 2) / (fs * nfft);
```

This replaces the `pwelch`/`cpsd` calls (lines 207-213 of `PUV_L2_spectral.m`). Everything downstream of the five spectral quantities (pressure correction, bulk parameters, directional coefficients, bed velocity) stays the same.

## Tradeoffs: Hanning/Welch vs. multi-taper

**Spectral leakage.** The Hanning window has sidelobe suppression of ~-31 dB. DPSS tapers are optimal in the sense of maximizing energy concentration within the resolution bandwidth; their leakage is controlled by NW and is generally lower than Hanning for the same effective bandwidth.

**Variance.** With 256-point sub-segments and 50% overlap over 2048 samples, the current Welch estimate averages ~15 periodograms. A multi-taper with NW=4 applied to the same 256-point sub-segments would average ~7 tapers × ~15 sub-segments = ~105 estimates, reducing variance by roughly 7x relative to Welch (or equivalently, achieving the same variance with fewer sub-segments, allowing longer sub-segments for better frequency resolution).

**Frequency resolution.** This is where multi-taper gets interesting for PUV work. The current df = 0.0078 Hz is coarse relative to the swell peak (~0.06-0.08 Hz, so only ~3 frequency bins across the peak). With multi-taper, we could use longer sub-segments (e.g., nfft = 512 or 1024) while maintaining acceptable variance, giving df = 0.004 or 0.002 Hz. That would better resolve the swell peak structure and the spectral excess feature.

**Bias.** Multi-taper introduces a bias proportional to the bandwidth 2W. For smooth spectra this is negligible. At sharp spectral peaks (swell), the peak amplitude will be slightly attenuated and broadened. This is the same tradeoff as increasing nfft in Welch; i.e. you trade resolution against variance.

**Directional estimates.** The a1/b1 coefficients come from cross-spectral ratios. Multi-taper cross-spectra have lower variance, which should reduce scatter in directional estimates, especially at low-energy frequencies where cross-spectral coherence is marginal.

## Practical considerations

**Computation time.** DPSS computation (`dpss(nfft, NW)`) is fast for nfft ≤ 1024. The per-segment cost is comparable to Welch and is dominated by FFTs, and K FFTs per taper vs. ~15 FFTs per sub-segment are similar.

**Hybrid approach.** We could apply multi-taper within Welch's framework and use DPSS tapers instead of Hanning on each 256-point sub-segment, then average over both tapers and sub-segments. This is sometimes called "multi-taper Welch" and gives the leakage benefits of DPSS with the variance reduction of segment averaging. The implementation just replaces `win = hanning(nfft)` with a taper matrix.

**Window correction.** The Hanning window has a known equivalent noise bandwidth (ENBW = 1.5 bins). DPSS tapers are energy-normalized by construction (the eigenvalues V give the energy concentration), so no separate correction is needed if we normalize properly.

**Validation.** We should run both methods on the same data and compare: (1) bulk parameters (Hs, Tp, Tm02), (2) spectral shape at the swell peak, (3) a1/b1 directional coefficients, (4) the spectral excess figure. If bulk Hs changes by more than ~1%, that matters for consistency with prior work.

## What this means for Ruby2D comparison

If we change the spectral method, we should quantify the impact before deciding whether Ruby2D PUV results need to be reprocessed. A controlled test: process TBR23 with both Hanning/Welch and multi-taper, compare Hs and spectral shape. If differences are within the MOP-PUV scatter, the method change probably doesn't warrant reprocessing Ruby2D.

## Recommendation

Start with the hybrid approach (DPSS tapers within Welch sub-segments, same nfft=256), since it's a minimal code change (swap `hanning(nfft)` for a DPSS taper loop) and isolates the window effect from the segment-length effect. Then test a pure multi-taper on longer segments (nfft=512 or 1024) to see if the improved frequency resolution changes the spectral excess picture.
