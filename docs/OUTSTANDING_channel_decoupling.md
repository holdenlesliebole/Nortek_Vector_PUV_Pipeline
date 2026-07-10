# Outstanding work — PUV channel decoupling & Phase-A recovery

Branch `puv-channel-decoupling-2026-07`. Companion to
`docs/L1_sensor_block_failure_2026-07-09.md` (the diagnosis) and
`docs/diagnostics_2026-07-09/` (the raw-streaming scripts and derived CSVs).

**One-line status.** Stages 1 and 2 are **implemented and committed** (`e2e069b`, corrected by
`dc1d265`). Two test suites pass: `test_channel_decoupling` (algebra + the toppled-frame
regression) and `test_L2_channel_decoupling` (integration, driving the real `PUV_L2_spectral`).
The sound-speed rescale is verified against Nortek's documented law in the band that carries the
wave energy (Addendum 2). The real-data regression on TOR23W/MOP586_10m is **pending**. 120 hours of
storm-peak Doppler data at MOP586_10m are recoverable today. Residual spectral distortion above
0.12 Hz is bounded at ≲1% on `u_rms` and ≲2–3% on `⟨u³⟩`, and one part of it (a deficit at
0.12–0.16 Hz) is **not understood**.

---

## 1. Settled — do not relitigate

| finding | evidence |
|---|---|
| TOR23W losses are a failed **auxiliary sensor block**, not wave-driven dropout and not the `nanMaxFrac` gate | `docs/L1_sensor_block_failure_2026-07-09.md` §1–2; 586_10m loses 597 segments in **one** run while 586_7m rides out the same storms at 99.8% |
| Phase A (25–29 Dec 2023) Doppler is healthy | beam correlations 92.6–97.0%, amplitude 102–136 counts, ≤0.4% of samples under Nortek's 70% gate |
| Phase B (30 Dec onward) is a genuinely dead instrument | correlation 5–8%, amplitude 36–40 counts. **Not recoverable.** |
| `PUV_raw_process.m:554-564` nulls the whole DAT row on a pressure or tilt fault | code; and `test_channel_decoupling` T1a reproduces it (`nanFrac(u) = 0.333`) |
| `PUV_L2_spectral.m:298` computes `nanFrac` jointly on `(p,u,v)` | so dead pressure destroys velocity moments that never needed pressure |
| L1's heading rotation is **static** (`theta_mag = instr.heading` from config + IGRF declination) | `PUV_raw_process.m:666-677`. The corrupt compass never entered L1's rotation. One less thing to fix. |
| Tilt correction is negligible **at MOP586_10m** | frame tilt 1.3° ⇒ 0.03% on horizontal velocity. NOT general: MOP580_7m rolled to −33.7°, see §7 |
| Depth transfer from the 7 m frame works | `Δ = h(10m) − h(7m) = 2.7436 m`; on Phase-A pressure-alive hours `H_meas − H_trans = −0.014 m` ⇒ **0.5 mm** in `Hs` |
| The z-test inversion (HLB's idea) reconstructs `Spp` from `(Suu+Svv)` | control `Hs_rec/Hs_meas = 1.0260` vs `1/√z = 1.0287` predicted. Agreement 0.26% |
| Operator bias is **not** period-dependent | 5524 healthy bursts: Spearman(`Tp`,`z`) = −0.022; drift over `Tp` 10→15.5 s = −0.04% |
| `Hs10/Hs7` does **not** fall with wave height | 3846 healthy co-located bursts: 0.9705 → 0.9762 as `Hs7` grows. Rules out the confound I first proposed |

## 2. 🛑 Retracted

The claim that broadband `u_rms` deflation (0.9457) and the sound-speed ratio (0.9509)
**"agree to 0.55%"**, and that this confirms `u_recorded ∝ c_measured`.

`u_rms` is broadband and includes the Doppler noise floor, which **grew 1.88×** at the 10 m
frame during Phase A (1.18× at the healthy 7 m frame). In the sea-swell band the deflation is
**0.9718**; the sound-speed ratio then *over*-corrects by 2.2%.

## 3. The open inconsistency

| quantity | Phase A vs healthy baseline |
|---|---|
| in-band orbital velocity, after the `c_true/c_rec` rescale | **+2.2%** |
| reconstructed `Hs` vs the 7 m frame | **−2.6%** |
| reconstructed `Hs` vs CDIP D0586 | **−3.4%** |

> ✅ **RESOLVED by N2.** These never measured the same thing. "+2.2%" was integrated over the
> *whole* sea-swell band, 0.04–0.25 Hz, absorbing a region above 0.12 Hz where the recovered
> spectrum is distorted. `Hs_rec` uses a transform weighting 0.25 Hz ~10× over 0.09 Hz, so a
> defect holding 4.8% of the velocity variance dominated the `Hs` error. Restricted to the
> swell band, the deflation *is* `c_rec/c_true`. Neither number refutes the correction.
> What survives as genuinely open is the 0.12–0.16 Hz deficit (N7).

**Eliminated:** depth transfer (0.5 mm); IG-band contamination (SS and total bands move
together); wave-height confound (refuted, §1); period-dependent operator bias (refuted, §1);
the grown noise floor (ruled out **by sign** — the transform weights 0.25 Hz ~10× more than
0.09 Hz, so extra white noise pushes `Hs_rec` **up**, and the observed bias is **down**).

~~Consequence: 2–3% uncertainty in recovered velocity ⇒ 6–9% in ⟨u³⟩.~~ **Superseded.** With
the scale verified in the swell band, the only residual is the spectral distortion above
0.12 Hz, a band holding **4.8%** of Phase-A orbital variance. Bound: **≲1% on `u_rms`, ≲2–3%
on `⟨u³⟩`.** (`test_channel_decoupling` still measures 14.9% in `⟨u³⟩` for a 5.2% velocity
error — that is why the rescale must be applied, not why the recovery is uncertain.)
`qc_flag = 3` stays on every reconstructed burst regardless.

## 4. Next tests

| # | test | status |
|---|---|---|
| N1 | `ztest_SS` vs `Tp`, 5524 healthy bursts | **done — refuted.** Spearman −0.022 |
| N2 | Frequency-resolved velocity and `S_eta` ratios, control vs Phase A | **done.** Swell band (0.04–0.09 Hz) reproduces `c_rec/c_true` = 0.9497 exactly. Residual confined to `f > 0.12` Hz |
| N2b | Bound-harmonic failure of the linear inversion | **done — refuted.** 5524 healthy bursts: `z` in the harmonic band is flat, near 1, and `z < 1` everywhere (operator reads high, never low) |
| N2c | Physical harmonic asymmetry between 9.4 m and 7 m | **done — refuted.** Healthy pairs to `Hs7` = 3.02 m: 0.12–0.16 Hz ratio 0.916 → 0.900, not 0.643 |
| N5 | Nortek's documented scaling law | **done — confirmed.** `V_corrected = V_old·(C_new/C_old)`, N3015-030 §2.4.9 p.53 |
| **N4** | Subtract the Doppler noise floor (fit over 0.6–0.95 Hz) from `Suu+Svv` before the transform. Explains the 0.20–0.25 Hz **excess**; will not explain the 0.12–0.16 Hz **deficit** (white noise adds, it cannot subtract) | **next** |
| **N7** | **The 0.12–0.16 Hz deficit is unexplained.** Not noise (wrong sign), not the inversion (N2b), not the wave field (N2c). Small (that band holds 4.8% of Phase-A orbital variance) but not understood | **open** |
| N3 | Within Dec 25 (pressure alive, `c_fac` drifting 1.000 → 1.023) regress uncorrected `Hs_rec/Hs_meas` on `c_fac`. Within-frame, within-day | lower priority now that N5 settles the law |
| N6 | Diagnose MOP580_7m | **done — DIFFERENT failure.** Sensor block healthy; the frame toppled (roll → −33.7°, heading 73 → 117°). Not recoverable, and it corrected the Stage-1 tilt rule. See §7 |
| **N8** | Diagnose MOP586_5m (4 runs, longest 431) and MOP580_5m (11 runs, longest 449). A **third** signature — many medium runs. Do not assume either known mechanism | open |
| **R** | Real-data regression: rerun L1+L2 on TOR23W/MOP586_10m with the new code and check (R1) healthy segments unchanged, (R2) Phase-A segments reappear as `segValid_vel`, (R3) rescale fires only where the thermistor failed | **running** |

## 5. Implementation plan (staged, and the stages are separable)

**Stage 1 — ship the decoupling.** Safe on its own, and it is the piece that recovers data.
It is a bitwise no-op wherever the sensors are healthy. Independent of Stage 2.

- `PUV_raw_process.m`: emit per-channel masks `valid_vel` (min beam correlation ≥ 70 **and**
  amplitude in range), `valid_p`, `valid_tilt`, `valid_T`. Stop propagating any of them across
  channels. Keep every existing threshold.
- `PUV_L2_spectral.m`: split `segValid` → `segValid_vel` / `segValid_p`; compute `nanFrac`
  per channel group (`:298`). Velocity moments (`skewness`, `asymmetry`, `u_uabs2`, `uMean`,
  `Ub`) need only `segValid_vel`. `Hs`, `Kp`, `S_eta`, `ztest`, `qtest`, `depth` need
  `segValid_p`.
- Provenance fields, per HLB 2026-07-09 — reconstructed data must never masquerade as clean:
  `vel_c_corrected` (bool), `vel_c_factor` (double, exactly 1.0 on healthy data),
  `vel_rotation_static` (bool), `Hs_source ∈ {'measured','reconstructed','none'}`,
  `qc_flag ∈ {1 good, 2 not evaluated, 3 suspect, 4 fail}`. **Anything reconstructed is 3, never 1.**
- Gate: `L1_raw_to_qc/test_channel_decoupling.m` and `L2_spectral/test_L2_channel_decoupling.m`
  must pass. Both do.
- **Tilt is NOT an auxiliary channel** — see §7. `valid_vel = valid_corr & present &
  (~tilt_trusted | valid_tilt)` where `tilt_trusted = valid_T`.

**Stage 2 — the rescale. UNBLOCKED.** N5 confirms Nortek's `V_corrected = V_old·(C_new/C_old)`;
N2 verifies it against the data in the swell band. Apply it, record `vel_c_factor`, and keep
`qc_flag = 3` on every burst where it was materially applied.

**Stage 3 — optional `reconstructP` mode.** When `segValid_vel && ~segValid_p`, invert
`Spp_from_vel` with an externally supplied `h(t)`, set `Hs_source = 'reconstructed'`.
**Restrict the inversion to the swell band (0.04–0.12 Hz) and report `Hs_SS`, not full-band
`Hs`** — above 0.12 Hz the recovered spectrum is distorted (Addendum 2). Subtract the noise
floor before the transform (N4). Never
silently mix reconstructed and measured `Hs` in one field — that is exactly the trap
`L4.Hs_combined` already sets (see `Paper_2/docs/audit_chapter2_2026-07-09.md`, Addendum 5 §5).

**Stage 4 — the rerun.** Blocked on Stage 1 landing. Order and cost in
`docs/L1_sensor_block_failure_2026-07-09.md` §8. Precede it with the cheap `.sen` survey (S1):
the `.sen` files carry battery, sound speed, heading, pitch, roll and temperature — every
diagnostic needed to *find* a sensor-block failure — at a third of the bytes of the `.dat`.
Only pull `.dat` for the flagged instruments.

**Stage 5 — rebuild L4.** It is stale independently of all of this: it carries **no `ztest`
field at all** (built 2026-05-23, before the 2026-06-05 Z-fix), and the TOR L2 files lack
`qtest_PU` (added to the code 2026-06-26; TBR23 has it, TOR does not). While rebuilding, add
the **MOP580 5 m and 7 m frames**, which `run_L4.m:46-53` never requests and which are the only
in-situ handle on alongshore forcing gradients at Torrey.

## 6. Downstream, not to be forgotten

- Chapter 1's TBR23 `MOP580_5m` sits at **48.1% valid**. `scripts/inspect_MOP580_5m_failure_windows.m`
  already asks whether that is the same failure. If it is, the rerun **changes Chapter 1's
  published numbers** — good, but it must happen once, deliberately, not mid-revision.
- Steve Elgar's z-test and Q-test, run on TBR23, together remove **0.0–0.7%** of segments.
  Nothing needs redoing on a QC'd subset. See `Paper_2/docs/audit_chapter2_2026-07-09.md`,
  Addendum 5 §4. The retention table is the evidence for the response letter.
- Chapter 2 changes wait until this line of inquiry closes (HLB, 2026-07-09).

---

## 7. N6 — MOP580_7m is a DIFFERENT failure, and it corrected the Stage-1 design

**2026-07-09.** MOP580_7m goes invalid in one unbroken 523-segment run from 28 Dec 23:29,
superficially identical to MOP586_10m. It is not the same failure at all.

Its auxiliary sensor block is **healthy throughout**: battery steady at 14.40 V, sound speed
1511 m/s, temperature 17.0–17.4 °C (ordinary seasonal cooling). What failed is the **frame**:

| day | pitch | roll | heading |
|---|---|---|---|
| Dec 28 | −0.77° | −0.63° | 73.2° |
| Dec 29 | **−12.28°** | **−16.74°** | 91.3° |
| Dec 30 | −14.74° | −24.08° | 105.2° |
| Dec 31 | −15.57° | **−33.73°** | 117.4° |

It rotated 44° and rolled past `tiltAbsMax = 30°`. **The instrument fell over.** It is not
recoverable, and it should not be: a frame that is still moving contaminates the velocity with
its own motion, and no rotation repairs that.

### The design error this caught

Stage 1 as first written treated **tilt like pressure and temperature** — an auxiliary channel
that must not gate velocity. That is wrong. Pressure and temperature say nothing about the
Doppler measurement. **Tilt is a statement about the measurement geometry.** Applied to
MOP580_7m, the first version would have kept the toppled-frame velocity and rotated it with a
"healthy" static tilt of −0.5°, fabricating a geometry the instrument never had.

**The corrected rule:** trust the tilt sensor exactly when the sensor block it lives on is
healthy. The thermistor is the tell — it shares that block.

```
tilt_trusted = valid_T
valid_vel    = valid_corr & present & (~tilt_trusted | valid_tilt)
```

- **MOP586_10m**: thermistor dead (T = −5 °C, battery to 19.5 V, heading wandering 70–96°)
  while the frame sat still at 1.3°. Tilt untrusted ⇒ cannot gate velocity ⇒ **rescued**,
  rotated with a static tilt, flagged `vel_rotation_static`.
- **MOP580_7m**: thermistor fine, frame toppled. Tilt trusted ⇒ gates velocity ⇒ **rejected**,
  exactly as the historical pipeline did.
- **Healthy**: unchanged.

Regression `test_channel_decoupling` T6a/T6b/T6c pins all three. **A frame that fell over is
not a sensor fault and must not be "recovered."**

### Consequence for the archive

Two distinct failure modes now have names, and the cheap `.sen` survey (S1) separates them
without touching a single `.dat`:

| signature | mechanism | recoverable? |
|---|---|---|
| `T` implausible, `c` steps, battery erratic, heading wanders, **tilt small** | auxiliary sensor block | **yes** — velocity, with the sound-speed rescale |
| `T`/`c`/battery normal, **tilt grows monotonically past 30°**, heading swings | frame toppled or scoured out | **no** |
| correlation → 5–8%, amplitude → 36 counts | probe buried or destroyed | no |

MOP586_5m (4 runs, longest 431) and MOP580_5m (11 runs, longest 449) are still undiagnosed and
have a third signature — many medium runs. Do not assume either mechanism.
