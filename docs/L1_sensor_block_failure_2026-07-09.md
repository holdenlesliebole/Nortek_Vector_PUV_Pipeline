# L1 destroys good velocity when the auxiliary sensor block fails

**2026-07-09.** Diagnosis of the TOR23W outages, a proposed pipeline change, and a
validated recipe for recovering the lost bursts. Everything below is measured from raw
`.dat`/`.sen`, not inferred from the QC'd products.

---

## 1. What the L2 record shows

Four of the five TOR23W frames go invalid within days of the 28–29 Dec 2023 storm and stay
invalid for about three weeks. Two of the losses are a **single unbroken run**:

| frame | invalid segments | runs | longest run | window |
|---|---|---|---|---|
| MOP586_10m | 597 | **1** | **597** | 2023-12-25 10:29 → 2024-01-19 06:29 |
| MOP580_7m | 523 | **1** | **523** | 2023-12-28 23:29 → 2024-01-19 17:29 |
| MOP586_5m | 466 | 4 | 431 | 2023-12-30 → 2024-01-17 |
| MOP580_5m | 652 | 11 | 449 | 2024-01-04 → 2024-01-22 |
| **MOP586_7m** | 3 | 2 | 2 | — (99.8% valid throughout) |

The 7 m frame rode out the same storms untouched, so this is not a wave-driven per-burst
dropout and it is not the `nanMaxFrac = 0.10` gate in `PUV_L2_spectral.m:299`.

## 2. What actually failed (MOP586_10m, from the raw files)

Daily means. Correlation is `min` over the three beams; amplitude is the 3-beam mean.

| day | corr b1/b2/b3 | amp | %samp corr<70 | P (dBar) | T (°C) | c (m/s) | pitch |
|---|---|---|---|---|---|---|---|
| Dec 20–24 | 96 / 95 / 95 | ~100 | 0.0% | 9.4 ✓ | 17.0–17.5 ✓ | 1511–1512 ✓ | +1.6° |
| Dec 25 | 93 / 94 / 95 | 102 | 0.0% | **69.2** ✗ | 17.5 | 1479 | +1.4° |
| Dec 26 | 93 / 96 / 97 | 115 | 0.0% | **2.8** ✗ | **−1.7** ✗ | **1444** ✗ | +1.3° |
| Dec 27 | 93 / 96 / 97 | 108 | 0.0% | **0.9** ✗ | **−4.2** ✗ | **1436** ✗ | +1.3° |
| Dec 28 | 93 / 96 / 96 | 115 | 0.1% | **0.4** ✗ | **−5.4** ✗ | **1433** ✗ | +1.3° |
| Dec 29 | 94 / 95 / 96 | 136 | 0.4% | 2.9 ✗ | −5.2 ✗ | 1433 ✗ | +0.9° |
| Dec 30 | 82 / 88 / 76 | 112 | 48% | 98.3 ✗ | −2.3 ✗ | 1442 ✗ | −2.7° |
| Dec 31 | 50 / 57 / 52 | 91 | 99.5% | ✗ | ✗ | ✗ | −7.8° |
| Jan 8–18 | 7 / 8 / 5 | 36–40 | 100% | ✗ | ✗ | ✗ | −7.9° |

Two distinct phases.

**Phase A, 25–29 Dec.** The auxiliary sensor block dies — pressure first (Dec 25), then the
thermistor (Dec 26), taking sound speed and the compass with it. Battery reads 12.4–19.5 V,
heading wanders 70–96° from a rock-steady 78.8°. **The Doppler measurement is untouched:**
beam correlations 92.6–97.0%, amplitude *elevated* (more scatterers, as expected in a storm),
≤0.4% of samples below Nortek's 70% correlation threshold.

**Phase B, 30 Dec onward.** The instrument genuinely dies. Correlation collapses to 5–8% and
amplitude to 36–40 counts — the signature of a buried or damaged probe head. Not recoverable.

## 3. Why L1 threw Phase A away

`PUV_raw_process.m:554-564` nulls the **entire DAT row** — velocities included — when the
tilt-variability flag fires or when pressure leaves `[pMed/2, 2·pMed]`:

```matlab
bad = bad_tilt_var | bad_tilt_abs;   DAT(bad,:) = NaN; SEN(bad,:) = NaN;
bad = DAT(:,15) < pMed/2;            DAT(bad,:) = NaN; SEN(bad,:) = NaN;
bad = DAT(:,15) > pMed*2;            DAT(bad,:) = NaN; SEN(bad,:) = NaN;
```

The comment at `:504-507` justifies the row-level kill: *"the right call when the failure is
sensor-block-wide (pressure + temperature + sound-speed all corrupt → ADV velocities are also
unreliable)."* That justification was written for the RUBY22 sensor-block failure and it is a
**hypothesis about the Doppler channels**, not a measurement of them. Here it is false. The
velocities are fine; only their *scale* is wrong, and that is invertible.

Downstream, `PUV_L2_spectral.m:298` computes `nanFrac` jointly on `p`, `u`, `v`, so a dead
pressure channel also destroys the velocity moments — which need no pressure at all.

## 4. The velocities are good, and the scale error is exactly the sound-speed error

> 🛑 **THE "AGREE TO 0.55%" RESULT IN THIS SECTION IS RETRACTED.** See the Addendum.
> The velocities *are* good — that stands. But `u_rms` integrates the Doppler noise floor,
> which grew 1.88× at this frame during Phase A. Recomputed in the sea-swell band, the
> deflation is **0.9718**, not 0.9457, and the sound-speed ratio (0.9508) then *over*-corrects
> by 2.2%. The scale error is **not yet shown to be exactly the sound-speed error.**

- The recorded velocities are in the **instrument frame**. The corrupt compass never touched
  them; it only enters the rotation the pipeline applies afterwards.
- The recorded velocities **are scaled by the measured sound speed**, so a corrupt thermistor
  biases them linearly: `u_recorded = u_true · c_rec / c_true`.

Closure test, using the healthy MOP586_7m frame 200 m away as a reference. `urms_h ≡
sqrt(var u + var v)` is rotation-invariant in the horizontal, so no rotation is needed.

| day | 10 m urms | 7 m urms | ratio | c_rec |
|---|---|---|---|---|
| Dec 18 | 0.2287 | 0.2892 | 0.791 | 1511 |
| Dec 19 | 0.2353 | 0.3001 | 0.791 | 1512 |
| Dec 20 | 0.1905 | 0.2410 | 0.786 | 1511 |
| Dec 21 | 0.1629 | 0.2086 | 0.792 | 1512 |
| Dec 22 | 0.2141 | 0.2741 | 0.788 | 1512 |
| Dec 23 | 0.1690 | 0.2158 | 0.795 | 1512 |
| Dec 24 | 0.2134 | 0.2686 | 0.797 | 1513 |
| Dec 25 | 0.2070 | 0.2627 | 0.796 | 1479 |
| **Dec 26** | 0.2383 | 0.3172 | **0.753** | 1444 |
| **Dec 27** | 0.2099 | 0.2819 | **0.743** | 1436 |
| **Dec 28** | 0.2630 | 0.3533 | **0.751** | 1433 |
| **Dec 29** | 0.5421 | 0.7116 | **0.768** | 1433 |
| Dec 30 | 0.4221 | 0.6304 | 0.709 | 1442 |

Seven healthy days give a ratio of **0.792 ± 0.004**. Dec 26–28 give **0.749**, a deflation of
**0.9457**. The sound-speed ratio over the same three days is `1437.7 / 1512.0 = ` **0.9509**.

~~**They agree to 0.55%.**~~ **RETRACTED — the statistic is contaminated.** `u_rms` is
broadband and therefore includes the Doppler noise floor (0.60–0.95 Hz), which grew **1.88×**
at the 10 m frame between the control and Phase A while growing only 1.18× at the healthy 7 m
frame. The apparent agreement was between the sound-speed ratio and a number inflated by the
very degradation under investigation. The in-band figure is 0.9718. See the Addendum.

This is the same error class the Chapter-2 audit keeps turning up, committed here by me:
a statistic was validated against a quantity that the failure itself perturbs.

Sanity check on the extraction itself: raw `awk` statistics reproduce L1's QC'd, rotated,
despiked velocities to a **median relative difference of 0.06%** over 504 healthy 20-min bins.

Correcting by `c_true / c_rec` restores the ratio to 0.789 / 0.782 / 0.792 on Dec 26/27/28.

## 5. Recovering the pressure from the velocity (HLB's idea, validated)

`PUV_L2_spectral.m:426` already contains the forward operator, inline, for the z-test:

```matlab
u2p(2:end)   = (2*pi*f_nz(:)) ./ (opts.g * k_seg(:));   % omega / (g k)
Spp_from_vel = (Suu + Svv) .* u2p.^2;
```

So `Spp` — and therefore `S_eta`, `Hs`, `Tp`, `Ef` — can be reconstructed from `(Suu + Svv)`
alone. The only ingredient pressure supplies that velocity does not is the **mean depth `h`**
inside `k(f, h)`.

**Depth transfer.** Over Dec 18–24 (504 twenty-minute bins, tidal range 2.33 m):

> `h(10 m) − h(7 m)` = **2.5108 m**, standard deviation **0.0041 m**, range [2.499, 2.521].

The two frames' mean depths differ by a constant to within **4 mm** across a 2.3 m tide. So
`h_10m(t) = h_7m(t) + Δ` reconstructs the missing depth to ±0.4 cm, which is negligible in
`k(f, h)`.

**Accuracy of the reconstruction.** The z-test *is* the validation, and it has already been
run on every healthy burst. `ztest_SS = Spp_measured / Spp_from_vel`, median by wave height:

| frame | Hs<1 | 1–1.5 | 1.5–2 | 2–2.5 | >2.5 |
|---|---|---|---|---|---|
| MOP586_5m | 0.966 | 0.975 | 0.989 | 1.089 | — |
| MOP586_7m | 0.970 | 0.980 | 0.990 | 1.016 | 1.050 |
| **MOP586_10m** | **0.948** | **0.955** | **0.945** | **0.960** | — |
| MOP586_15m | 0.962 | 0.962 | 0.965 | 0.954 | 0.952 |

At the 10 m frame — the one we need to reconstruct — **`z` is flat in wave height**
(0.945–0.960). `Hs_hat = Hs_true / √z`, so the reconstruction carries a *constant* **+2.6%**
bias, not a growing one, and it can be calibrated out against the frame's own healthy bursts.
Residual accuracy ≈ ±3% in `Hs`.

(The 7 m frame's `z` *does* drift, 0.970 → 1.050, so the same trick there would need a
height-dependent calibration. Worth noting, not needed here.)

**A second, independent confirmation of the sound-speed fix falls out for free:**
`Spp_from_vel ∝ (Suu + Svv) ∝ c²`. Reconstructing `Hs` from the *uncorrected* velocities must
come out ~5% low against both D0586 and the 7 m frame; from the corrected ones it must match.
Run that check before trusting anything.

## 6. What is recoverable

**MOP586_10m, 2023-12-25 00:00 → 2023-12-30 00:00.** 120 hourly model records at D0586,
`Hs` max 3.18 m.

Against the whole TOR23W 10 m deployment (14 Nov – 19 Jan):

| threshold | hours in deployment | hours inside the recoverable window |
|---|---|---|
| Hs > 1.5 m | 209 | 34 (16%) |
| Hs > 2.0 m | 118 | 26 (22%) |
| Hs > 2.5 m | 43 | 11 (26%) |
| **Hs > 3.0 m** | **3** | **3 (100%)** |

The 10 m frame currently has **zero** valid bursts above `Hs ≈ 2 m`. Recovery converts that to
26 hours above 2 m and every hour above 3 m. This is precisely the regime Chapter 2's
transport-moment analysis is missing.

MOP580_7m (single 523-segment run from 28 Dec 23:29) has not been diagnosed yet and may be
partly recoverable on the same logic. MOP580_5m and MOP586_5m have many short runs and a
different signature; diagnose before assuming.

## 7. Proposed pipeline change

The defect is **channel coupling**: one dead auxiliary sensor silently deletes an independent,
healthy measurement. Fix the coupling, not the thresholds.

**L1 (`PUV_raw_process.m`)**
1. Emit **per-channel validity masks** instead of one row-level NaN:
   `valid_vel` (min beam corr ≥ 70 **and** amplitude in range), `valid_p`, `valid_tilt`,
   `valid_T`. Keep the existing thresholds; only stop propagating them across channels.
2. Add a **temperature plausibility gate** (e.g. 5 ≤ T ≤ 30 °C). Where `valid_T` is false and
   `valid_vel` is true, rescale `u,v,w` by `c_true / c_rec` using a fallback temperature
   (nearest healthy frame, or SIO pier SST) and record the factor applied. Where `valid_T` is
   true the factor is identically 1.0, so this is a **no-op on healthy data**.
3. Where `valid_tilt` is false but `valid_vel` is true, rotate with a **robust static
   tilt/heading** taken from the healthy window, and flag it. The frame is bolted to the
   seabed and the recorded coordinate system is XYZ, so heading enters only at rotation.

**L2 (`PUV_L2_spectral.m`)**
4. Split `segValid` into `segValid_vel` and `segValid_p`. Compute `nanFrac` per channel group
   (`:298`). Velocity moments (`skewness`, `asymmetry`, `u_uabs2`, `uMean`, `Ub`) require only
   `segValid_vel`; `Hs`, `Kp`, `S_eta`, `ztest`, `qtest`, `depth` require `segValid_p`.
5. Optional `reconstructP` mode: when `segValid_vel && ~segValid_p`, invert `Spp_from_vel`
   using an externally supplied `h(t)`, and set a `Hs_source` flag. Never silently mix
   reconstructed and measured `Hs` in one field — that is exactly the trap `L4.Hs_combined`
   already sets (see `Paper_2/docs/audit_chapter2_2026-07-09.md`, Addendum 5 §5).

**Before any of this ships, a synthetic closure test** (`test_channel_decoupling.m`), in the
style of `test_ztest_linear.m`:
- Feed a known linear wave field. Corrupt only the pressure channel. Assert the velocity
  moments are bit-identical to the uncorrupted run.
- Corrupt only `T`. Assert the c-rescale recovers the true velocities to machine precision.
- Assert that when `valid_T` is true, the new code path returns results identical to the old.

## 8. Should we re-run all ~30 PUVs?

Eventually yes, but **not blind, and not yet**. Three reasons for a staged approach.

1. **The rerun changes Chapter 1's published numbers.** TBR23's MOP580_5m sits at 48.1% valid
   (`scripts/inspect_MOP580_5m_failure_windows.m` already asks this exact question). If its
   loss is the same sensor-block failure, the rerun adds data to the `⟨u³⟩`-vs-depth
   decomposition that Chapter 1 has already been drafted around. That is good, but it must be
   done deliberately and once, not discovered mid-revision.
2. **The cost is dominated by L1, not L2.** The Z-fix L2 rerun was 3–4 h. L1 re-reads the raw
   archive over SMB and re-parses it: the single 1.3 GB `MOP586_10m` `.dat` took ~4 min to
   stream with `awk`, and MATLAB `textscan` is slower. Stage raw locally first
   (`L1_raw_to_qc/copy_raw_to_local.m` exists for this).
3. **A cheap survey tells us what we would gain.** The `.sen` files are ~1/3 the size of the
   `.dat` and carry battery, sound speed, heading, pitch, roll and temperature — every
   diagnostic needed to *find* a sensor-block failure. Stream the `.sen` for all deployments,
   flag every instrument with implausible `T` or a sound-speed step, and only then pull the
   `.dat` for the flagged ones.

**Recommended order**

| step | what | cost | risk |
|---|---|---|---|
| S1 | `.sen` survey across all deployments → table of sensor-block failures | ~1 h, read-only | none |
| S2 | Implement per-channel masks + `test_channel_decoupling.m` | — | none until rerun |
| S3 | Prove it on TOR23W MOP586_10m: recover Phase A, reconstruct `Hs`, check against D0586 and the 7 m frame | ~1 h | none |
| S4 | Re-run L1→L2→L3→L4 for all deployments, once | overnight | changes Ch.1 + Ch.2 numbers |
| S5 | Rebuild L4 (it is stale anyway: no `ztest` field; TOR L2 lacks `qtest_PU`) and **add the unused MOP580 5 m / 7 m frames**, which `run_L4.m:46-53` never requests | ~1 h | none |

Step S3 is the gate. If the recovered Dec 26–29 bursts reconstruct `Hs` to within a few percent
of D0586 and the 7 m frame, the change is proven on the hardest case in the archive and S4 is
justified. If they do not, we learn that before touching 26 deployments.

## 9. Provenance

Raw: `/Volumes/group/PUV_data/Vector/Torrey20231114-20240118/{MOP586_10m16306, MOP586-7m16739}`.
Mount verified up before every read. Streaming `awk` diagnostics and the comparison scripts are
in the session scratchpad; they should be promoted to `scripts/` if S1 proceeds.

Time base: `.dat` is CONTINUOUS 2 Hz, `t(row j) = 2023-11-14 12:00:02 + (j−1)/2 s`; verified
against the `.sen` row count (94 797 min vs 11 374 800 / 2 s) and against L1's sample count.

---

# Addendum — S3 executed. Recovery works; its absolute scale does not yet close.

**2026-07-09, later.** `scripts/recover_MOP586_10m_phaseA.m`, `validate_recovery_MOP586_10m.m`,
`test_hs_ratio_confound.m`, `diagnose_phaseA_deficit.m`, `diagnose_band_limited_scaling.m`,
and `L1_raw_to_qc/test_channel_decoupling.m`.

## What is established

**The synthetic closure test passes** (`test_channel_decoupling`, ALL PASS). It also
demonstrates the defect: with pressure corrupted and the Doppler perfectly healthy, the
current row-level gate drives `nanFrac(u) = 0.333`, so `PUV_L2_spectral.m:299` skips the
segment and no velocity moment is ever computed. The proposed per-channel gate preserves
the moments bit-for-bit. Magnitude check from the same test: a sound-speed error deflates
`u_rms` by 5.2% and **⟨u³⟩ by 14.9%** — the moment goes as `c³`.

**120 hours of Doppler data are recoverable** at MOP586_10m, 25–29 Dec 2023, `fbad` 0.0–0.6%.
They contain all three hours of the deployment with `Hs > 3` m at D0586, against a frame that
currently has **zero** valid bursts above `Hs ≈ 2` m.

**The rescale is a measured no-op on healthy data**, not a gated one: `c_true/c_rec` has
median **1.00000**, range [0.99945, 1.00099] over the 72 control hours.

**The depth transfer holds.** `Δ = h(10 m) − h(7 m) = 2.7436 m`. On the Phase-A hours where
pressure survived, `H_meas − H_trans = −0.014 m` (max 0.058 m), i.e. **0.5 mm** in `Hs`.

**The reconstruction operator is validated on healthy bursts.** `Hs_rec / Hs_meas = 1.0260`
(IQR 1.0214–1.0317, n=72), against `1/√z = 1.0287` predicted from the frame's own
`ztest_SS = 0.9450`. Agreement 0.26%. HLB's z-test inversion works, and its bias *is* the
z-test, exactly as proposed.

**Inside the failed window, on the 10 hours where pressure still worked,**
`Hs_rec / Hs_meas = 1.0085` [1.0018, 1.0200] — reconstruction against measurement, same
burst, same depth, no shoaling ratio in between.

## 🛑 What I got wrong, and retract

I reported that the broadband velocity deflation (0.9457) and the sound-speed ratio (0.9509)
**"agree to 0.55%"**, and called that a confirmation that `u_recorded ∝ c_measured`.
**That is withdrawn.**

Broadband `u_rms` integrates the Doppler noise floor. Measured over 0.60–0.95 Hz, far above
the wave band, the noise floor at the 10 m frame **grew 1.88×** between the control and Phase A
(the healthy 7 m frame's grew 1.18×) — consistent with beam correlation falling 96 → 93 and
amplitude rising 100 → 136 counts. So the statistic I validated against was contaminated by
exactly the thing that changed.

In the sea-swell band (0.04–0.25 Hz), which excludes the noise floor and the mean flow:

| statistic | control | Phase A | deflation |
|---|---|---|---|
| broadband `u_rms(10m)/u_rms(7m)` | 0.792 | 0.749 | 0.9457 |
| **SS-band orbital amplitude ratio** | **0.7925** | **0.7701** | **0.9718** |

The sound-speed ratio `c_rec/c_true` = 0.9508. Against the *honest* statistic it now
**over**-corrects by 2.2%, rather than matching to 0.55%.

## The open question

Three measurements do not close, and I do not yet know which is wrong:

1. In-band velocity, corrected: **+2.2%** relative to the healthy 10 m/7 m relationship.
2. Reconstructed `Hs` vs the 7 m frame: **−2.6%** relative to the same relationship
   (control `Hs_rec/Hs7` = 0.9890, Phase A = 0.9634).
3. Reconstructed `Hs` vs D0586: **−3.4%** (control `Hs_meas/D0586` = 1.0567, Phase A
   `Hs_rec/D0586` = 1.0204).

Items 1 and 2 have **opposite sign**. Since `Hs_rec` is a linear operator applied to the
in-band velocity, they cannot both be right unless the *operator* also shifted between the
control and Phase A.

Two eliminated already. It is **not** the depth transfer (`D2`, 0.5 mm in `Hs`), and it is
**not** low-frequency contamination of the reconstruction (`D3`: the SS-band and total-band
ratios move together — 0.9543 and 0.9634 in Phase A, 0.9875 and 0.9890 in the control).

It is also **not** a wave-height confound in my control, which I hypothesised and then
refuted: across 3846 healthy co-located bursts spanning `Hs7` = 0.35–3.02 m, the ratio
`Hs10/Hs7` is flat and if anything *rises* with wave height (0.9705 → 0.9762), so it cannot
explain a fall to 0.9354.

**Candidate: period-dependent operator bias. TESTED, REFUTED (N1).** The control is `Tp ≈ 10` s
and the Phase-A storm is `Tp ≈ 15–16` s, and `ztest_SS` had only ever been checked against `Hs`.
Across **5524 healthy MOP586_10m bursts** from all four TOR deployments:

| `Tp` (s) | 6–9 | 9–11 | 11–13 | 13–15 | 15–17 | 17–25 |
|---|---|---|---|---|---|---|
| median `z` | 0.9652 | 0.9590 | 0.9432 | 0.9478 | 0.9428 | 0.9576 |
| `1/√z` bias | 1.0179 | 1.0211 | 1.0297 | 1.0272 | 1.0299 | 1.0219 |

Spearman(`Tp`, `z`) = **−0.022**. OLS `z = 0.9438 + 0.00013·Tp + 0.0052·Hs`, so over
`Tp` 10 → 15.5 s the reconstruction bias moves by **−0.04%**. The operator is not
period-dependent. This does not explain a 2.6% shift.

**Candidate: the grown Doppler noise floor. Ruled out by SIGN.** The transform
`(ω/gk)²·cosh²(kH)/cosh²(k·doffp)` weights 0.25 Hz about ten times more heavily than 0.09 Hz,
so white Doppler noise is strongly amplified in `S_eta`. A noise floor that grew 1.88× would
therefore push `Hs_rec` **up**, and the calibration derived on the quieter control would
*under*-remove it. The observed Phase-A bias is **down**. Noise cannot be the cause, though it
must still be subtracted before the transform in any production implementation.

So four explanations are eliminated: depth transfer, IG-band contamination, wave-height
confound, and period-dependent operator bias. **The inconsistency is unresolved.**

## Named next tests

| # | test | decides | status |
|---|---|---|---|
| N1 | `ztest_SS` vs `Tp`, 5524 healthy bursts | period-dependent operator bias | **done — refuted** |
| N2 | Frequency-resolved comparison: reconstructed `S_eta(f)` at 10 m vs the 7 m frame's `S_eta(f)`, control and Phase A, sub-band by sub-band | *where in frequency* the energy goes missing. This localises the defect instead of guessing at it | **do next** |
| N3 | Within Dec 25 (pressure alive, `c_fac` drifting 1.000 → 1.023), regress uncorrected `Hs_rec/Hs_meas` on `c_fac` | a within-frame, within-day test of `u ∝ c`. Small leverage, but clean and free of the 7 m frame | pending |
| N4 | Subtract the Doppler noise floor (estimated over 0.6–0.95 Hz) from `Suu + Svv` before the transform, then repeat | how much of the residual is noise, in either direction | pending |
| N5 | Confirm the Vector's velocity/sound-speed scaling from Nortek documentation rather than inferring it from data | the scaling law itself. HLB may be able to ask Nortek directly | pending |

## Consequence, stated plainly

The recovery reproduces the storm **shape** convincingly — hour by hour on 28–29 Dec,
`Hs_rec` tracks D0586 and the 7 m frame through the peak (3.45 m at 03:30 on the 29th). Its
**absolute scale carries an unresolved 2–3% uncertainty in velocity**, which becomes
**6–9% in ⟨u³⟩** because the moment goes as `c³`. For Chapter 2's transport-moment analysis
that is not negligible, and it is exactly why the recovered bursts must ship with
`qc_flag = 3` and `Hs_source = 'reconstructed'` (HLB, 2026-07-09) rather than be silently
merged with clean measurements.

**S3 is therefore not yet passed, and S4 (the 26-deployment rerun) stays blocked.**
The channel-decoupling change is proven and safe on its own — it recovers velocity that is
currently discarded, and it is a bitwise no-op where the sensors are healthy. The *sound-speed
rescale* is the piece that is not yet closed, and it is separable: ship the decoupling first
with the rescale disabled and the affected bursts flagged, and enable the rescale only when
N1–N4 resolve the scale.

---

# Addendum 2 — N2/N5 resolve the scale. The recovery is sound where the energy is.

**2026-07-09, later still.** `scripts/n2_frequency_resolved.m`, `n2b_nonlinear_ztest.m`,
and the healthy-pair test in `docs/diagnostics_2026-07-09/`.

## N5 — the scaling law, from Nortek, not inferred

[N3015-030 Comprehensive Manual — Velocimeters](https://assets.nortekgroup.com/software/N3015-030-Comprehensive-Manual-Velocimeters_1118.pdf),
**§2.4.9 "Incorrect Speed of Sound", p. 53** (repeated verbatim as §5.3.4, p. 112). The
equation is an embedded image, which is why text search and the product-page PDF list both
miss it:

> **V_corrected = V_old · (C_new / C_old)**
>
> *"The instruments compute the speed of sound based on the measured temperature (accuracy of
> 0.1° C). A nominal salinity is assumed... Sound speed errors are typically small, but if you
> must correct velocity data for errors, use the following equation."*

And §2.1.4: *"Speed of sound can be set by the user (Fixed) or calculated by the instrument
based on the measured temperature and a user-input value for salinity (Measured)."*

Both frames' `.hdr` files declare `Sound speed MEASURED` and `Salinity 33.5 ppt` — identical,
so the 7 m frame's reported `c` is a valid `C_new` for the 10 m frame. (Independently
confirmed: over the 72 control hours `c_7m/c_10m` has median **1.00000**, range
[0.99945, 1.00099].)

**The correction applied in `recover_MOP586_10m_phaseA.m` is exactly Nortek's own.** The
scaling law is not in doubt.

## N2 — the deflation *is* the sound-speed ratio, in the band that carries the energy

Velocity ratio 10 m / 7 m, Phase A relative to control, expressed as an implied sound-speed
ratio (`√` of the variance ratio). Nortek's law predicts a **flat 0.9497** across all wave bands:

| band (Hz) | implied `c_rec/c_true` |
|---|---|
| 0.040–0.055 | **0.9659** |
| 0.055–0.070 | **0.9488** |
| 0.070–0.090 | **0.9353** |
| 0.090–0.120 | 0.8968 |
| 0.120–0.160 | 0.7845 |
| 0.160–0.200 | 0.8071 |
| 0.200–0.250 | 0.9239 |
| 0.60–0.95 (noise) | 1.1531 |

In the swell band the three values bracket the prediction. **The rescale is verified where all
the storm energy lives.** The residual is confined to `f > 0.12` Hz.

## Two explanations for the high-frequency residual, both refuted

**Bound-harmonic failure of the inversion.** `Spp_from_vel` assumes free linear waves at every
frequency; bound harmonics travel at the primary's phase speed, so the operator should fail in
the harmonic band and fail worse as waves grow. Tested on **5524 healthy bursts** where both
`Spp` and `(Suu,Svv)` were measured, forming `z(f)` band by band:

| band (Hz) | `Hs`<1 | 1–1.5 | 1.5–2 | 2–2.5 | Spearman(`Hs`,`z`) |
|---|---|---|---|---|---|
| 0.040–0.055 | 0.885 | 0.890 | 0.880 | 0.890 | +0.041 |
| 0.070–0.090 | 0.931 | 0.941 | 0.935 | 0.944 | +0.084 |
| 0.120–0.160 | 0.959 | 0.972 | 0.966 | 0.984 | +0.083 |
| 0.160–0.200 | 0.973 | 0.984 | 0.977 | 0.971 | +0.035 |

`z` in the harmonic band is flat, near 1, and *better* than the swell band. `z < 1` everywhere,
so the operator reads slightly **high**, never low. **Refuted.**

**A physical harmonic asymmetry between 9.4 m and 7 m depth.** Tested on healthy co-located
pairs (both frames alive, both `S_eta` from pressure, `Hs7` to 3.02 m): the 0.120–0.160 Hz
ratio is 0.916 → 0.900 across wave-height bins. It does not fall to the 0.643 seen in Phase A.
**Refuted.**

## What is left, and how much it matters

The recovered 10 m spectrum is distorted above 0.12 Hz: a **deficit** at 0.12–0.20 Hz and an
**excess** at 0.20–0.25 Hz (1.142 against a healthy expectation of ~0.79). The excess is the
grown Doppler noise floor, amplified ~10× by the `(ω/gk)²·cosh²(kH)/cosh²(k·doffp)` weighting.
**The 0.12–0.16 Hz deficit remains unexplained.** White Doppler noise adds; it cannot subtract.

But the band is nearly empty of energy:

| window | var(0.04–0.12 Hz) | var(0.12–0.25 Hz) | share above 0.12 Hz |
|---|---|---|---|
| control | 2.486e-02 | 6.363e-03 | 20.4% |
| **Phase A** | **5.535e-02** | **2.805e-03** | **4.8%** |

The storm is swell-dominated, so the distorted band holds under 5% of the orbital variance.

**This reconciles the two measurements that appeared to contradict.** "In-band velocity +2.2%
high" was integrated over the *whole* sea-swell band, 0.04–0.25 Hz, and so absorbed the
distorted region. `Hs_rec` −2.6% low used a transform that weights 0.25 Hz ~10× more than
0.09 Hz, so a defect holding 4.8% of the velocity variance dominated the `Hs` error. They were
never measuring the same thing, and neither refutes the sound-speed correction.

## Revised status

- **Velocity moments** (`skewness`, `asymmetry`, `u_uabs2`, `uMean`, `u_rms`) — computed in the
  time domain from the full velocity, so they inherit the distortion in proportion to its energy
  share. Bound: a ~30% error over 4.8% of the variance moves `u_rms` by ≲1% and `⟨u³⟩` by
  ≲2–3%, not the 6–9% previously feared. **These are the quantities Chapter 2 needs, and they
  are usable**, with `qc_flag = 3`.
- **Reconstructed `Hs`** — restrict the inversion to **0.04–0.12 Hz** and report `Hs_SS` rather
  than the full-band `Hs`. Over the full band it is biased low by ~2.6% for reasons that are
  now localised but not fully explained. Subtract the noise floor (fit over 0.6–0.95 Hz) before
  the transform in any production implementation (N4).
- **Still open:** the 0.12–0.16 Hz deficit. It is small, bounded, and does not affect the
  conclusion, but it is not understood and should not be described as if it were.

**S3 now passes for its intended purpose** — recovering velocity moments through the storm
peak — with the scale verified against Nortek's documented law in the band that carries the
energy. Stage 1 (channel decoupling) and Stage 2 (the rescale) may both proceed. `Hs`
reconstruction (Stage 3) ships swell-band only.
