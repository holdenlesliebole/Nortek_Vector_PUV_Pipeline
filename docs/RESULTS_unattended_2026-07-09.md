# Unattended run, 2026-07-09 → 07-10. Results.

Branch `puv-channel-decoupling-2026-07`. Driver `scripts/unattended_2026_07_09.sh`.
Raw output in `docs/diagnostics_2026-07-09/unattended/`.

Ran 23:49 → 06:21. All three stages completed; the mount held.

---

## R — real-data regression of Stage 1 + 2 on TOR23W/MOP586_10m

L1 and L2 re-run from raw with the new per-channel code, into a scratch `outputDir`.
`outputs/L1`, `outputs/L2`, `outputs/L4` untouched.

**What L1 reported.**

```
Per-channel QC: velocity 73.8% valid, pressure 64.3% valid, tilt 97.7% valid
--> 1327162 samples (11.7%) carry healthy velocity that the old row-level gate discarded
4747 samples (0.0%) have healthy Doppler but a TRUSTED bad tilt: velocity invalidated, as before
Sound-speed correction: 37.2% of samples had invalid T; 1344422 rescaled (median factor 1.0581)
  source: own c(T) fit: c = 1470.04 + 2.4054*T, Tref = 16.90 C -> c_true = 1510.7 m/s
Static tilt applied to 72895 samples (pitch 1.60, roll -0.10 deg)
```

**The sound-speed reference validates independently.** L1 derived `c_true = 1510.7 m/s` from
the instrument's *own* healthy `c(T)` fit evaluated at `Tref = 16.90 °C`. The standalone
recovery used the neighbouring 7 m frame's *measured* `c = 1512.0 m/s`. Two unrelated routes,
**agreement 0.09%**. (The fitted slope, 2.41 m/s per °C, is not the physical `dc/dT ≈ 3.2`,
because the healthy temperature range is narrow and the fit is poorly conditioned in slope.
It is only ever *evaluated inside* that range, so this is harmless — but it means the fit must
not be extrapolated, and `cfg.soundSpeedRef` should be preferred whenever a companion frame
exists.)

### R1 — is the change a no-op on healthy data?

**For velocity, exactly.** For pressure-derived `Hs`, not quite, and I had claimed otherwise.

| quantity | max Δ over the 972 segments valid in both |
|---|---|
| `skewness`, `u_uabs2`, `uMean`, `Tp` | **0** (bit-identical) |
| `Ub` | 1.6e−8 |
| `depth` | 4.9e−4 m |
| `ztest_SS` | 2.0e−3 |
| **`Hs`** | **7.8e−3 m** |

Distribution of `|ΔHs|`: **median exactly 0**; 875 of 972 segments (90%) bit-identical;
97 segments change at all; **one** exceeds 1 mm; worst is 7.8 mm, i.e. 0.58% relative.

**Why.** The old row-level gate NaN'd *pressure* on rows where only the **Doppler** failed
(beam correlation < 70%) or the tilt flag fired. Pressure now survives those rows, so a
healthy segment can contain *more* valid pressure samples than before. This is more data, not
different data. But the honest statement is: **the change is a bitwise no-op on the velocity
path, and a sub-centimetre improvement on the pressure path.** It is not a no-op on `Hs`.

### R2 — does it recover what the old gate destroyed?

**159 segments** that the old pipeline discarded now carry velocity moments.
**110 of them fall in 25–29 Dec 2023**, the storm-peak window. Every one:

- `qc_flag = 3` ✔
- `segValid = false` ✔ — so `build_L4_site.getL2sub`, `PUV_L4_moments` and `PUV_L4_eta`
  cannot pick them up by accident
- `Hs` is NaN ✔ — no pressure product invented from a dead sensor
- median velocity skewness `+0.2787`, all 159 finite

The remaining 49 lie in 30 Dec – 7 Jan and correspond to the brief partial recoveries of
4–6 Jan (beam correlation back to 70–94%). They pass Nortek's threshold legitimately, but the
instrument was degrading; `qc_flag = 3` covers them.

### R3 — does the rescale fire only where the thermistor failed?

Yes, and the assertion that "failed" was a bug in my *test*, not in the code.

| | n | qc_flag |
|---|---|---|
| rescaled, usable | 159 | all **3** ✔ |
| rescaled, unusable | 149 | all **4** ✔ |
| rescaled with `qc_flag = 1` | **0** ✔ | |
| rescale applied before 25 Dec | **0** ✔ | |
| `max abs(vel_c_factor − 1)` before 25 Dec | **0.000e+00** ✔ | |

The no-op property is exact. Factor range 0.9669 – 1.0581: the nine segments below 1 are
where the dying thermistor read *high* (`c_rec` up to 1562 m/s), so the instrument used too
large a sound speed and the recorded velocity was too large. Correcting **down** is right.

---

## N8 — MOP586_5m and MOP586_15m: a THIRD failure mechanism

Their raw lives in `Torrey20231114-20240213`, not `...-20240118` (and the `5M_58602` file
prefix is reused across campaigns — scope any glob by folder).

From the S1 survey, both are **completely clean in the sensor block**:

| frame | %T implausible | %T dev > 8 | c range | %batt out | %tilt > 30° | tilt_drift |
|---|---|---|---|---|---|---|
| MOP586-5m17043 | 0.0 | 0.0 | 1.6–7.8 m/s | 0.0 | 0.00 | ±0.4 |
| MOP586-15m15277 | 0.0 | 0.0 | 3.0–11.0 m/s | 0.0 | 0.00 | ±0.1 |

Neither a sensor-block failure nor a topple. Their 466 and 350 lost segments must therefore be
**Doppler failures** — beam correlation below 70%, from burial, scour or bubbles. The `.sen`
carries no acoustic diagnostics, so this signature is invisible to S1 by construction; it is
identified by *exclusion*, and confirming it needs the `.dat`.

**Their velocity is not recoverable. Their pressure never failed.** Which exposed the
symmetric hole in Stage 1 — see below.

---

## The symmetric defect, now fixed

L2 had a velocity-only branch and **no pressure-only branch**. A segment whose Doppler died
but whose pressure sensor was perfectly healthy still produced nothing. That is the same bug
in the other direction, and by segment count it is the *dominant* one in the archive.

`PUV_L2_spectral` now computes, when `segValid_p && ~segValid_vel`:
`Hs`, `Hs_SS`, `Hs_IG`, `Tp`, `Tm02`, `Ef`, `depth`, `S_eta`, `Spp`, `Kp`, `fCut`.
Direction (`meanDir`, `a1`, `b1`, `a2`, `b2`), `Ub`, `tau_b`, the radiation stresses, the
z-test and the Q-test all require velocity and are left NaN.

`Hs_source = 'measured'` (the `Hs` *is* measured) but `qc_flag = 3`, because **`qc_flag`
describes the completeness of the segment, not the quality of any one product.** Consult
`segValid_vel` / `segValid_p` for which products are trustworthy.

Gated by `test_L2_channel_decoupling` RUN D. **D3: `Hs` recovered from a velocity-dead segment
is identical to the healthy run, to 0.0.**

---

## S1 — failure-signature survey of the whole Vector archive

15 750 `.sen` files, **238 instrument-part records** with a usable interior, 51 deployment
folders. 5 h 38 m of streaming, one pass, no `.dat` read.

| class | n |
|---|---|
| healthy | 210 |
| out-of-water (recovery / deck) | 10 |
| frame moved or toppled → **not recoverable** | 10 |
| sensor block failed → **velocity recoverable** | 5 |
| both (inspect) | 3 |

### Recoverable sensor-block failures

| deployment | file | %T dev>8 | %T implaus | c range | %batt out | p95 roll |
|---|---|---|---|---|---|---|
| **16737_MOP579_6m** | TORREY16737_1 | 39.2 | 29.6 | 134.6 | 1.2 | 1.65 |
| **16737_MOP579_6m** | TORREY16737_2 | 8.8 | 93.3 | 134.6 | 0.8 | 1.35 |
| **16737_MOP579_6m** | TORREY16737_3 | 21.1 | 97.2 | 134.6 | 80.0 | 6.85 |
| **16737_MOP579_6m** | TORREY16737_4 | 0.0 | 100.0 | 0.0 | 100.0 | 1.55 |
| **MOP586_10m16306** | 10M586_16306 | 33.8 | 31.4 | 134.6 | 7.3 | 1.15 |
| MOP654_7m17036 | 7M654_17036_5 | 6.4 | 0.0 | 35.2 | 0.0 | 24.35 |
| Catalina_2021 | CATISL02 | 0.0 | 0.0 | 12.5 | 19.6 | 0.45 |

**`16737_MOP579_6m` is RUBY22/MOP579_6m** — the exact instrument the original L1 code comment
was written about (`PUV_raw_process.m:457-463`). The survey rediscovered it independently, and
resolves its progressive sensor-block death part by part: temperature implausible 29.6% →
93.3% → 97.2% → 100%, battery out 80% then 100%. **Its early parts are candidates for the same
velocity recovery**, subject to a `.dat` correlation check.

`MOP654_7m17036_5` is a trailing part (p95 roll 24°) and probably includes recovery handling.
`Catalina_2021 CATISL02` is a battery anomaly only (c range 12.5 m/s, tilt 0.01) — not a
sensor-block failure.

### Frames that moved or toppled — not recoverable

| deployment | file | %tilt>30 | p95 roll | tilt_drift | head_drift |
|---|---|---|---|---|---|
| Cardiffbackbeach_Jan2016 | V104901 | 53.46 | 54.45 | **53.40** | 101.4 |
| 2023Jan_LPL_DYE01_ADV | LPSDYE02 | 33.76 | 31.15 | 29.59 | −29.7 |
| 2023Jan_LPL_DYE01_ADV | LPSDYE03 | 0.00 | 24.05 | 22.08 | −264.2 |
| **MOP580_7m17042** | 7M580_17042_3 | 0.55 | 20.15 | **20.32** | 25.5 |
| **MOP580_7m17042** | 7M580_17042_4 | 100.00 | 33.85 | 0.10 | 2.3 |
| MOP654_7m17036 | 7M654_17036_3 | 0.00 | 16.35 | 11.92 | 19.9 |
| MOP651_7m16310 | 7M651_16310_5 | 1.19 | 23.65 | 10.99 | 209.5 |
| 12414_MOP582-30m | TORREY12414_8 | 0.00 | 10.35 | −9.64 | 211.0 |
| SouthSIOPier20240328 | 6M-51102_5 | 3.16 | 23.15 | 0.85 | −1.9 |

MOP580_7m parts 3 and 4 are the topple N6 found: part 3 catches the fall (`tilt_drift` 20.3°),
part 4 is the frame lying over at a steady 33.9° (`tilt_drift` ≈ 0, but 100% past 30°). Both
discriminants are needed; neither alone would catch both parts.

### Caveats on the survey

1. **A frame on the seabed cannot roll 167°.** `p95|roll| > 90°` means the file is mostly
   *out of water* — the instrument powered on before deployment or sitting on the deck after
   recovery. The `.sen` has no pressure, so this is the only in-water proxy available, and it
   is why 10 records classify as "out-of-water" rather than "toppled." It also means the
   trailing part-file of a deployment is nearly always contaminated.
2. **S1 cannot see Doppler failure.** Burial, scour and bubbles kill beam correlation, which
   lives in the `.dat`. A probe buried under a healthy sensor block reads "healthy" here.
   That is fine — the correlation gate handles it automatically in L1 — but it means
   *"healthy" in this table means "sensor block and frame are healthy,"* not "the data are good."
3. `head_drift` beyond ±180° is a wraparound artifact (LPSDYE03, MOP651, TORREY12414).
4. **The `deployment` column in `S1_failure_inventory.csv` is `basename(dirname(file))` and
   collides**: two campaigns both contain a folder called `MOP586-7m16739`. 10 duplicate keys.
   The script now emits the path relative to `Vector/`; the CSV in this run does not. Re-run
   S1 before using it as a database key.

---

## What this changes about the rerun

210 of 238 records are healthy in the sensor block and the frame, and Stage 1 is a bitwise
no-op on the velocity path there. So the archive-wide L1 rerun is **safe but mostly
inconsequential** — except that the pressure-only branch now recovers `Hs` wherever the
Doppler died, which is the common case.

Suggested scope, in decreasing value:

1. **TOR23W + TBR23** — Chapters 1 and 2 depend on them; TBR23's MOP580_5m sits at 48% valid
   and is undiagnosed; the TOR L2 files still lack `qtest_PU`.
2. **16737_MOP579_6m (RUBY22)** — pull the `.dat`, check beam correlation through the
   sensor-block death, and recover what survives.
3. Everything else — a no-op on velocity, a gain on `Hs` wherever correlation failed.

**Still blocking L4:** `build_L4_site.getL2sub` pulls `vmom` by index with no `segValid`
filter. It must propagate `qc_flag` before L4 is rebuilt, or reconstructed moments will be
silently merged into clean fields.

## Open

- **N7** — the 0.12–0.16 Hz deficit in the reconstructed spectrum. Not noise (wrong sign), not
  the inversion, not the wave field. Small (that band holds 4.8% of Phase-A orbital variance)
  and bounded, but not understood.
- **N4** — subtract the Doppler noise floor before the `Spp_from_vel` transform.
- Confirm N8 by exclusion → by measurement: pull the `.dat` for MOP586_5m / MOP586_15m and
  verify the losses really are beam correlation.
