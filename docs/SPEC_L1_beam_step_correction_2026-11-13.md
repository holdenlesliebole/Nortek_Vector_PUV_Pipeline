# Spec: L1 correction of Nortek Vector one-beam velocity steps (2026-11-13)

**Status: EXPLORATORY build, branch `beam-step-correction-20261113` (worktree
`../PUV_Pipeline_beamstep`, cut from `origin/main` f8c6b5c, the published catalog 2026-10-16.1;
the repository has no `master`). Not committed, not merged, no catalog rebuild.** The rule and
every test criterion below were written before any test in section 7 was run. Section 8 records
what was looked at before this spec was fixed, so the reader can judge which tests are blind.

Evidence for the problem: `docs/DIAGNOSIS_L1_velocity_spikes_2026-11-13.md` and its addendum.
Measured effect on transport moments: morphology_ml
`experiments/deep_transport_map/step2_ladder_closure_plan_DRAFT_2026-11-12.md` section 11.

## 1. What is corrected

The Vector occasionally reports one beam offset by k·Δ, with Δ ≈ 1.51 m/s along the beam and
|k| = 1 (about 1% of events |k| = 2), for one sample or a short run, at 70% to 93% correlation.
L1's correlation gate passes it. In instrument XYZ it is a jump of about 4 m/s (8 m/s for |k| = 2)
along one column of the head transformation matrix T. Two beams can step at once (TOR25S
MOP586_15m, L1 index 8453056, 6.85 m/s). The step size is empirical: Nortek's documents give no
ambiguity velocity for the 4 m/s setting (diagnosis addendum A1).

## 2. Where in L1

`PUV_raw_process.m`, new block "BEAM-STEP CORRECTION", placed after per-channel QC
(`puv_channel_qc`) and the leading-NaN trim, and **before** the sound-speed factor, the tilt
rotation, the XYZ `W = −W` flip and the heading rotation. There the velocity is in the recorded
instrument frame, so a step has its recorded size and lies exactly along a column of T. Beams are
b = T⁻¹·x on samples with `qc.valid_vel`. Samples failing `valid_vel` are never read or changed.
Only flagged samples are written, as x′ = x − T·(kΔ); every other sample is bitwise unchanged.

Records not corrected (stamped, values left as recorded):
- **ENU records** (`excluded_ENU`; LPL, SOL and any other ENU instrument). Reaching beams needs the
  onboard heading/pitch/roll rotation undone with 1 Hz attitude, and Nortek's exact convention for
  that is unverified here. Their step counts are approximate (diagnosis addendum A3).
- **BEAM records** (`excluded_BEAM`; none known).
- **Decimated records** (`excluded_decimated`, `instr.decimateTo`): the FIR decimation smears a
  step. No current config decimates.
- `cfg.beamStep.enable = false` or `instr.beamStep.enable = false` (`disabled`), which must carry
  its reason in the config.

An XYZ record with no readable head matrix is an **error**, not a silent skip.

## 3. Head matrix

`vector_head_matrix.m` reads T from every non-empty `.hdr` ("Transformation matrix", Head
configuration) and from the Head Configuration record (0xA5 0x04, 224 bytes, checksum verified) of
the first raw binary: nine int16 at bytes 8 to 25 of the 176-byte System field, row-major, ÷ 4096.
`read_VEC.m` now also returns it as `meta.headT`. All sources must agree within 1e-4 (the `.hdr`
prints 4 decimals). Stamped into L1 as `PUV.head.T` and `PUV.head.info` (source, head serial,
files, agreement).

## 4. The rule (`vector_beam_step_correct.m`), as amended (section 9)

| parameter | value | why |
|---|---|---|
| `Delta0` | 1.50 m/s | search value for the Δ-estimation pass; catalog median 1.508 m/s |
| `DeltaWindow` | [1.40, 1.60] m/s | diagnosis: 5th to 95th percentile of one-beam steps 1.393 to 1.600 m/s (L1 space, tilt-biased); raw 1.46 to 1.52 m/s |
| `tolEdge` | 0.35 m/s | residual allowed on **every** beam at an edge; raw steps move the other beams < 0.06 m/s |
| `kMax` | 2 | double steps exist (3.01 to 3.05 m/s); no larger seen |
| `gapShortSec` | 2.0 s (4 missing samples at 2 Hz) | gaps up to this are "short" |
| `gapMaxSec` | 10.0 s (20 missing samples) | longest QC gap an edge may bridge |
| `runMaxSec` | 15.0 s | longest correctable run, gaps included (L1-valid runs are ≤ 11 samples = 5.5 s) |
| `refHalfSec` | 30.0 s | half-width of the moving median that anchors the absolute level |
| `nFit` | 3 | clean samples each side for the level check's local quadratic |
| `tolLevel` | 0.35 m/s | level-check tolerance on every beam |

Gaps are counted in **missing samples** between two valid samples.

1. **Segments.** Valid samples are chained; more than `gapMaxSec` of missing samples starts a new
   segment.
2. **Edges.** For each interval between chained samples, the beam change d is detrended by the
   local flow slope: the median rate of change over the 2 neighboring intervals on each side (same
   segment; neighbors across long gaps or with any beam changing by more than Δ/2 left out),
   times the interval length. No detrending across gaps longer than `gapShortSec`. The interval
   is an **edge** if k = round(d/Δ) is nonzero on some beam, |k| ≤ `kMax` on all, and
   |d − kΔ| < `tolEdge` on **all three** beams.
3. **Pieces and absolute offsets.** A segment is split into **pieces** at every gap the edge
   test could not cross (one or more missing samples, no edge). Inside a piece the cumulative
   edge sum K gives the relative level exactly. The absolute level comes from the data: the
   unwrapped beam u = b − KΔ is the true beam velocity plus an unknown multiple of Δ, and the
   true beam velocity's local median lies within ±Δ/2 of zero (that only needs a mean beam
   velocity under 0.75 m/s, a mean horizontal current under about 3 m/s). So
   C = round(movmedian(u, ±`refHalfSec`)/Δ) and each sample's offset is OFF = K + C.
4. **Candidates.** A candidate run is a maximal stretch with OFF ≠ 0, spanning at most
   `runMaxSec`, in which every offset change is an edge of that size (otherwise it is counted in
   `nLongOffsets` and not touched). Its two bounding transitions are classified: **two-edge**,
   **one-edge** or **zero-edge**. A zero-edge candidate must be a whole piece isolated by QC gaps
   of 1 to 4 missing samples on both sides; other zero-edge stretches are rejected outright.
5. **Confirmation.** |OFF| ≤ `kMax` on every beam, and unless the run is two-edge with both
   edges joining adjacent samples (no gap), the **level check**: every run sample satisfies
   |b − fit − OFFΔ| < `tolLevel` on every beam, where fit is a quadratic in time, per beam,
   through the `nFit` nearest samples on **each** side that are in no candidate (at least 2 per
   side), within `gapMaxSec` of the run (`gapShortSec` for zero-edge runs).
   Correction b′ = b − OFFΔ, applied as x′ = x − T·(OFFΔ).
6. **Flags.** A failing two-edge run, or a failing one-edge run whose edge joins adjacent
   samples, is **flagged unconfirmed and left unchanged**. Other failing candidates are only
   counted (`nRejectedOneZeroEdge`); in shallow summer flow they are mostly flow-made edges
   across gaps, and flagging them made the flag meaningless (1,739 flagged samples at TOR24S
   MOP586_5m with 0 steps, rule version of run 7).
7. **Δ per record**, from that record's own recorded-frame beams: a first pass with `Delta0`
   collects the stepped-beam |d| (detrended) of single-beam, |k| = 1 edges of confirmed runs,
   between adjacent samples only; Δ = their median, stamped with n and the interquartile range.
   Outside `DeltaWindow`: status `refused_delta`, **no correction**, warning
   `PUV_raw_process:beamStepRefused`. No edges: status `no_steps`. Δ is constant per record; its
   sound-speed dependence (diagnosis A2: present, not proportional) is not modeled. A record with
   very few edges gets a noisy Δ (single-edge scatter about 0.02 m/s), which leaves a residual of
   that size on its few corrected samples.

Why real flow should not pass: a confirmed correction needs either two edges between adjacent
samples (each a change that, in XYZ, lies within tolerance of ±Δ times one column of T, about
4 m/s horizontal with a matching 0.5 m/s vertical, in 0.5 s, with the other two beams quiet), or
a local quadratic through clean samples on both sides that the run sits exactly OFF·Δ off on the
stepped beams and on the fit for the others. T3 tests this on amplified storm flow.

## 5. Stored in L1

- `PUV.qc.vel_beamstep_k` (N × 3 int8): offset removed per beam in units of Δ; 0 elsewhere.
- `PUV.qc.vel_beamstep_unconfirmed` (N × 1 logical): step-like spans left unchanged.
- `PUV.qc.beamstep`: status, Δ, Δ source, n edges, IQR, counts (samples, runs, level-checked,
  zero-edge and one-edge runs, double, multi-beam, run-length histogram 1 / 2-3 / 4-10 / 11-30
  samples, longest, unconfirmed runs and samples, unclosed edges (`nLongOffsets`), edges,
  segments), options.
- `PUV.head.T`, `PUV.head.info`.
- `cfg.beamStep.dumpInputTo` / `instr.beamStep.dumpInputTo` (test hook): saves the corrector's
  exact input (recorded-frame velocity, valid mask, fs, T, time) to a `.mat`.

`valid_vel` is **not** changed. Whether unconfirmed samples should also be masked is HLB's call.

## 6. Data available for the tests

- Local raw (`PUV_Pipeline/raw_cache/`, exact head matrices): TOR24S MOP586_5m and MOP586_7m,
  TOR16A to TOR16D, TOR17A, TOR17C, COR16B, SIO24A; LPL24, LPL25A, SOL24 (ENU, excluded).
- Server-only raw (`/Volumes/group/PUV_data/Vector/`): TOR23W MOP586_5m and MOP586_7m,
  TOR25S MOP586_15m, TBR23 MOP586_5m, every other 2023 to 2025 Torrey record. Reading them needs
  HLB's approval (asked 2026-11-13); this session's brief allows only `.hdr` reads from the server.
- Existing L1 outputs cannot stand in: they are tilt-rotated and do not store pitch and roll, so
  recorded-frame beams cannot be recovered exactly from them.

## 7. Tests and their fixed criteria

All counts are printed as n/n. Seeds are fixed (`rng(20261113)`). Δ_inj = 1.508 m/s.

**T1. Head matrix.** On every local record with both a `.hdr` and a binary, the two sources agree
within 1e-4. Pass: n/n records.

**T2. Synthetic closure.** Base: the corrector's dumped input for a real record, restricted to a
window in which the corrector itself (Δ = 1.508 m/s given) makes 0 corrections and 0 unconfirmed
flags. (The base is "clean" by the corrector's own judgment; that is a stated limitation.)
- Calm base: TOR24S MOP586_5m, the 3-day window with the **lowest** sea-swell (0.04 to 1 Hz)
  horizontal velocity variance among windows with at least 90% valid samples.
- Storm base: TOR23W MOP586_5m if its raw is approved, else the local XYZ record and 3-day window
  with the **highest** sea-swell horizontal velocity variance among windows with at least 70%
  valid samples. Which one was used is reported.
- Injections, on random beams and signs, sites at least 200 samples apart:
  - S1: 200 single steps, |k| = 1;
  - S2: 50 double steps, |k| = 2;
  - S3: 30 two-beam steps (k = +1 on one beam, −1 on another), single sample;
  - S4: 40 runs of 2 to 11 samples, |k| = 1;
  - S5: 10 runs of 12 to 30 samples, |k| = 1;
  - S6: 60 single steps with an injected QC gap (valid = false) of 1 to 4 samples on one or both
    sides;
  - S7: 30 single steps with an injected gap of 5 to 20 samples on one side (these need the
    level check).
- **T2a (Δ given = 1.508 m/s).** Pass if all hold:
  - every injected (sample, beam, k) is flagged exactly: n/n, per category;
  - 0 flags at non-injected samples;
  - every unflagged sample bitwise equal to the base;
  - max |x′ − x_clean| ≤ 1 mm/s over injected samples.
  - **Exception fixed now:** in the storm base, S7 is reported separately. Its criterion is
    "0 wrong corrections; each injection either corrected or flagged unconfirmed", because the
    level check is meant to refuse when the flow is too energetic to judge.
- **T2b (Δ estimated).** Pass if |Δ̂ − 1.508| ≤ 0.010 m/s, flags as in T2a (n/n, 0 false), and
  at every injected sample |x′ − x_clean| ≤ Σ|k|·|Δ̂ − Δ_inj|·(max column norm of T) + 1e-9 m/s (Σ over beams, so a two-beam step counts 2).

**T3. Amplified-flow stress (cannot correct real flow).** The storm base with no injections,
velocities multiplied by 1.5 and by 2.0 (Δ = 1.508 m/s given). Pass: 0 corrected samples at both.

**T4. Real-data false correction.** Full L1 builds, Δ estimated: TOR23W MOP586_5m and MOP586_7m
(if raw approved), TOR24S MOP586_5m and TOR24S MOP586_7m. Pass: 0 corrected samples each. Unconfirmed flags and
edges are reported, with no criterion.

**T5. Break tests.** Each runs T2a on the calm base and must **fire**: T2a fails, or the corrector
refuses. The unbroken copy (T2a, same base, same seed) must pass in the same run.
- B1: columns 1 and 2 of T swapped (fires through beam labels: steps on beams 1 and 2 come out on
  the other beam);
- B2: Δ = 1.0 m/s given (fires through `refused_delta`);
- B3: sign of Z flipped in the input (the L1 `W = −W` convention applied before beam space);
- B4: rows 1 and 2 of T swapped;
- B5: steps injected at 1.30 m/s with Δ estimated (fires through `refused_delta`).

**T6. Real-data check** (report; two fixed criteria). Full L1 builds with and without the
correction for TOR25S MOP586_15m and TBR23 MOP586_5m (raw approval needed), plus TOR17C (local):
- list the corrected samples (time, beams, k, XYZ before and after);
- hourly ⟨u|u|²⟩ and ⟨u|u|³⟩ summed over the record, before and after, for comparison with
  morphology_ml's mask-and-fill estimate (TOR25S 15 m ⟨u|u|³⟩ −129%; TBR23 5 m +6.7%);
- criterion 1: the TOR25S MOP586_15m 6.85 m/s sample (L1 index 8453056, located by time) is
  corrected on two beams;
- criterion 2 (from the diagnosis's sketch): at TOR17C, 2018-03-06 16:00 to 2018-03-07 06:00
  (filename clock), the share of valid samples per hour with |b₂| > 0.9 m/s falls below 0.1% in
  every hour, and hourly median beam velocities move by less than 0.005 m/s.

**T7. Regression.** `run_all_tests` (self-contained) passes n/n, and a new
`test_vector_beam_step.m` (synthetic, no data) passes n/n with each of its checks seen to fail
once.

## 8. What was looked at before this spec was fixed (exploratory)

- TOR24S MOP586_5m and TOR17C were built with a first version of the rule (`gapMaxSec` 2 s, no
  level check). TOR17C left 594 runs (631 samples) unconfirmed, mostly runs whose closing edge
  crossed a 2.5 s to 50 s QC gap in quiet flow (beam 2 flickering between −0.08 m/s and +1.40 m/s).
  That led to `gapMaxSec` 10 s with the level check for gaps over 2 s.
- With the second version of the rule, TOR17C: Δ = 1.4886 m/s (IQR 1.477 to 1.499 m/s,
  5,654 edges), 3,057 runs and 4,947 samples corrected, 70 runs (286 samples) unconfirmed.
  (Run 7 later showed that version made wrong corrections in TOR17C's dense flicker.)
- TOR24S MOP586_5m: 0 corrections, 1 unclosed real-flow edge (section 4, item 6), which led to
  flagging only step-length spans. **So T4 on TOR24S MOP586_5m is not blind**; TOR24S MOP586_7m,
  TOR23W MOP586_5m and TOR23W MOP586_7m are (none had been built when this was written).

## 9. Amendments to the rule after test runs (dated, with the result that prompted each)

The test criteria in section 7 were not changed by any of these. Each amendment changed the
method and the tests were rerun unchanged. The self-contained test
(`L1_raw_to_qc/test_vector_beam_step.m`, written before its first run) is the C1 to C4 and
B1 to B5 set: C1/C2 calm synthetic, C3 energetic synthetic (two swell components, peak
horizontal speed about 3.6 m/s), C4 energetic × 2.0 with no steps.

1. **2026-11-13, run 1** (rule of section 4 as first written: raw differences, segment-mode
   baseline, 61-sample median level reference). C1 S7 27/30 (gap measured as index difference, so
   a 20-missing-sample gap broke the segment); C3 3/200 singles, everything else 0, all silent
   misses, 0 wrong; C4 and B1 to B5 pass. Changes: gaps counted in missing samples; edges
   detrended by the local slope.
2. **Run 2.** Every category failed in C1 (a single missed edge in a 2-day segment moved the
   segment-mode baseline for everything after it; detrending across long gaps made edges worse).
   Changes: no detrending across long gaps; forward pairing with unclosed edges as level shifts,
   replacing the segment mode and `modeFracMin`.
3. **Run 3.** C1 pass, C2 pass with Δ̂ = 1.5177 m/s (bias 0.0097 m/s against a 0.010 m/s
   criterion); C3 S1 to S5 n/n, S6 39/60, S7 1/30, all silent misses. Changes: step-sized
   neighbors left out of the slope median, ±2 neighbors; one-edge runs at gaps the edge test
   could not cross, with the level check.
4. **Run 4.** C2 Δ̂ = 1.5109 m/s; C3 S6 35/60 (25 missed), S7 5/30 + 25 unconfirmed. Changes: any
   uncrossed gap (1 or more missing samples) can bound a one-edge run; level check against a
   local quadratic through 3 clean samples each side instead of a 61-sample moving median
   (`refHalfSec` removed, `nFit` added).
5. **Run 5.** C3 S6 57/60 (+1 unconfirmed, 2 missed), S7 29/30 (+1 unconfirmed). The 2 misses
   were single valid samples with gaps on both sides that neither crossing passed. Change:
   zero-edge runs (section 4, item 4).
6. **Run 6.** C1, C2 (Δ̂ = 1.5109 m/s), C4 pass, B1 to B5 fire; C3 S6 59/60 (+1 unconfirmed).
   Real-data validation v1: T1, T2 calm, T3, T5 pass; storm base S6 59/60 (+1 unconfirmed);
   TOR24S MOP586_5m (0 steps) carried 1,758 unconfirmed flags. A two-edge run across short gaps
   skipped the level check, which left a route for flow-made edge pairs. Changes: the level check
   is required unless both edges join adjacent samples; only two-edge and gap-free one-edge
   rejects are flagged.
7. **Run 7.** Synthetic and real T2 unchanged in outcome (one storm S6 case now a silent miss).
   **T6 criterion 2 exposed WRONG corrections at TOR17C**: in its dense three-level flicker
   (b₂ at −1.5, 0 and +1.5 m/s), forward pairing took an offset level as baseline after an
   unclosed edge and moved true samples (one from 0.01 m/s to −1.5 m/s). The sparse synthetic
   injections could not show this. Change: absolute anchoring by the moving median of the
   unwrapped beam (section 4, item 3), replacing forward pairing. A post hoc synthetic check C5
   (dense flicker, criterion fixed before its first run) was added to the self-contained test.
8. **Run 8.** C5 2,483/2,483 exact; C3 S6 51/60, S7 22/30 (spikes whose entry crossing failed
   were anchored with the samples before them). Change: anchor per piece, splitting at every
   uncrossed gap (section 4, item 3); this also absorbed the separate zero-edge pass.
9. **Run 9 (current rule).** Results in section 10.

## 10. Results with the current rule (run 9, 2026-11-13)

Raw output, unedited. Commands: `test_vector_beam_step` (self-contained) and
`validate_beam_step_20261113(<dump folder>)` (real data; inputs dumped by full L1 builds of the
local raw records with `cfg.beamStep.dumpInputTo`). Section 2 of
`docs/REPORT_L1_beam_step_correction_2026-11-13.md` summarizes these against the criteria.

### 10.1 Self-contained test

```
=== test_vector_beam_step ===
  [PASS] C1 calm, Delta given: T2a
         S1 single 200/200; S2 double 50/50; S3 two-beam 30/30; S4 run 2-11 40/40; S5 run 12-30 10/10; S6 gap 1-4 60/60; S7 gap 5-20 30/30; 
         false flags 0, untouched bitwise 1, max err 8.60e-16 m/s, status corrected
  [PASS] C2 calm, Delta estimated 1.5105 m/s: T2b
         S1 single 200/200; S2 double 50/50; S3 two-beam 30/30; S4 run 2-11 40/40; S5 run 12-30 10/10; S6 gap 1-4 60/60; S7 gap 5-20 30/30; 
         false flags 0, untouched bitwise 1, max err 1.34e-02 m/s, status corrected
  [FAIL] C3 energetic, Delta given: T2a (S7 exception)
         S1 single 200/200; S2 double 50/50; S3 two-beam 30/30; S4 run 2-11 40/40; S5 run 12-30 10/10; S6 gap 1-4 59/60 (1 missed); S7 gap 5-20 29/30 (+1 unconf); 
         false flags 0, untouched bitwise 1, max err 4.06e+00 m/s, status corrected
  [PASS] C4 energetic x2.0, no steps: 0 corrected
         offset fraction 34.5%
  [PASS] C5 dense flicker (post hoc): 2483/2483 exact, 0 false flags
  [PASS] B1 T columns 1,2 swapped: fires
         S1 single 62/200 (138 WRONG); S2 double 18/50 (32 WRONG); S3 two-beam 0/30 (30 WRONG); S4 run 2-11 16/40 (24 WRONG); S5 run 12-30 3/10 (7 WRONG); S6 gap 1-4 26/60 (34 WRONG); S7 gap 5-20 5/30 (25 WRONG); 
         false flags 0, untouched bitwise 1, max err 1.21e-15 m/s, status corrected
  [PASS] B2 Delta = 1.0 m/s: fires (refused_delta)
         S1 single 0/200 (200 missed); S2 double 0/50 (50 missed); S3 two-beam 0/30 (30 missed); S4 run 2-11 0/40 (40 missed); S5 run 12-30 0/10 (10 missed); S6 gap 1-4 0/60 (60 missed); S7 gap 5-20 0/30 (30 missed); 
         false flags 0, untouched bitwise 1, max err 8.12e+00 m/s, status refused_delta
  [PASS] B3 Z sign flipped: fires
         S1 single 0/200 (200 missed); S2 double 0/50 (50 missed); S3 two-beam 30/30; S4 run 2-11 0/40 (40 missed); S5 run 12-30 0/10 (10 missed); S6 gap 1-4 0/60 (60 missed); S7 gap 5-20 0/30 (30 missed); 
         false flags 0, untouched bitwise 1, max err 8.12e+00 m/s, status corrected
  [PASS] B4 T rows 1,2 swapped: fires
         S1 single 0/200 (200 missed); S2 double 0/50 (50 missed); S3 two-beam 0/30 (30 missed); S4 run 2-11 0/40 (40 missed); S5 run 12-30 0/10 (10 missed); S6 gap 1-4 0/60 (60 missed); S7 gap 5-20 0/30 (30 missed); 
         false flags 0, untouched bitwise 1, max err 8.12e+00 m/s, status no_steps
  [PASS] B5 steps of 1.30 m/s, Delta estimated: fires (refused_delta)
         S1 single 0/200 (200 missed); S2 double 0/50 (50 missed); S3 two-beam 0/30 (30 missed); S4 run 2-11 0/40 (40 missed); S5 run 12-30 0/10 (10 missed); S6 gap 1-4 0/60 (60 missed); S7 gap 5-20 0/30 (30 missed); 
         false flags 0, untouched bitwise 1, max err 7.00e+00 m/s, status refused_delta
------------------------------------------------------------
{Error using test_vector_beam_step (line 76)
assertion failed
```

### 10.2 Real-data tests T1, T2, T3, T5, T6 criterion 2

```
=== T1 head matrix (hdr vs binary, tol 1e-4) and current-rule counts ===
  COR16B_MOP158_9m     head vec      VEC 4397 |dT| NaN | corrected     Delta 1.5012 (n  254, IQR 1.489-1.514) | runs  220 (1:202 2-3:18 4-10:0 11-30:0; 0-edge 0, 1-edge 0, double 0, 2-beam 9)  240 samples = 52.3 ppm | unconf 22 runs 28 samples | unclosed 0
  SIO24A_SIO_6m        head hdr+vec  VEC 5675 |dT| 4.8e-05 | corrected     Delta 1.5104 (n    2, IQR 1.505-1.516) | runs    1 (1:1 2-3:0 4-10:0 11-30:0; 0-edge 0, 1-edge 0, double 0, 2-beam 0)    1 samples = 0.1 ppm | unconf 0 runs 0 samples | unclosed 0
  TOR16A_MOP591_9m     head hdr+vec  VEC 4386 |dT| 4.9e-05 | no_steps      Delta NaN (n    0, IQR NaN-NaN) | runs    0 (1:0 2-3:0 4-10:0 11-30:0; 0-edge 0, 1-edge 0, double 0, 2-beam 0)    0 samples = 0.0 ppm | unconf 0 runs 0 samples | unclosed 0
  TOR16B_MOP591_9m     head vec      VEC 4400 |dT| NaN | corrected     Delta 1.5054 (n  197, IQR 1.493-1.515) | runs  165 (1:155 2-3:8 4-10:2 11-30:0; 0-edge 0, 1-edge 0, double 0, 2-beam 2)  179 samples = 58.7 ppm | unconf 51 runs 52 samples | unclosed 0
  TOR16C_MOP591_9m     head hdr+vec  VEC 4386 |dT| 4.9e-05 | corrected     Delta 1.5055 (n 1445, IQR 1.495-1.515) | runs 1010 (1:941 2-3:66 4-10:3 11-30:0; 0-edge 0, 1-edge 4, double 0, 2-beam 50) 1090 samples = 198.9 ppm | unconf 6 runs 7 samples | unclosed 0
  TOR16D_MOP591_9m     head hdr+vec  VEC 4400 |dT| 4.9e-05 | corrected     Delta 1.4904 (n  108, IQR 1.476-1.499) | runs   85 (1:71 2-3:14 4-10:0 11-30:0; 0-edge 0, 1-edge 12, double 0, 2-beam 0)   99 samples = 15.8 ppm | unconf 0 runs 0 samples | unclosed 0
  TOR17A_MOP591_9m     head hdr+vec  VEC 4400 |dT| 4.9e-05 | corrected     Delta 1.5030 (n    1, IQR 1.503-1.503) | runs    1 (1:1 2-3:0 4-10:0 11-30:0; 0-edge 0, 1-edge 0, double 0, 2-beam 0)    1 samples = 0.2 ppm | unconf 0 runs 0 samples | unclosed 0
  TOR17C               head hdr+vec  VEC 4400 |dT| 4.9e-05 | corrected     Delta 1.4901 (n 4440, IQR 1.478-1.501) | runs 3192 (1:2403 2-3:650 4-10:131 11-30:8; 0-edge 8, 1-edge 481, double 0, 2-beam 0) 4600 samples = 1067.5 ppm | unconf 112 runs 159 samples | unclosed 0
  TOR24S_MOP586_5m     head hdr+vec  VEC 5724 |dT| 5.0e-05 | no_steps      Delta NaN (n    0, IQR NaN-NaN) | runs    0 (1:0 2-3:0 4-10:0 11-30:0; 0-edge 0, 1-edge 0, double 0, 2-beam 0)    0 samples = 0.0 ppm | unconf 0 runs 0 samples | unclosed 1
  TOR24S_MOP586_7m     head hdr+vec  VEC 5729 |dT| 4.1e-05 | no_steps      Delta NaN (n    0, IQR NaN-NaN) | runs    0 (1:0 2-3:0 4-10:0 11-30:0; 0-edge 0, 1-edge 0, double 0, 2-beam 0)    0 samples = 0.0 ppm | unconf 0 runs 0 samples | unclosed 0
  T1: 8/8 records with both sources agree within 1e-4 -> PASS
=== T2 base selection ===
  calm base : TOR24S_MOP586_5m 10-Apr-2024 19:50:06 to 13-Apr-2024 19:50:05, sea-swell horiz. var 0.0548 m^2/s^2, valid 98.5%
  storm base: COR16B_MOP158_9m 21-Jan-2017 18:50:52 to 24-Jan-2017 18:50:51, sea-swell horiz. var 0.4625 m^2/s^2, valid 99.1%, max |u_h| 2.86 m/s
=== T2 synthetic closure on real bases ===
  [PASS] T2a calm, Delta given
        S1 single 200/200; S2 double 50/50; S3 two-beam 30/30; S4 run 2-11 40/40; S5 run 12-30 10/10; S6 gap 1-4 60/60; S7 gap 5-20 30/30; 
        false flags 0, untouched bitwise 1, max err 8.88e-16 m/s, Delta 1.5080, status corrected
  [PASS] T2b calm, Delta estimated 1.5082 m/s
        S1 single 200/200; S2 double 50/50; S3 two-beam 30/30; S4 run 2-11 40/40; S5 run 12-30 10/10; S6 gap 1-4 60/60; S7 gap 5-20 30/30; 
        false flags 0, untouched bitwise 1, max err 1.14e-03 m/s, Delta 1.5082, status corrected
  [FAIL] T2a storm, Delta given (S7 exception)
        S1 single 200/200; S2 double 50/50; S3 two-beam 30/30; S4 run 2-11 40/40; S5 run 12-30 10/10; S6 gap 1-4 59/60 (1 missed); S7 gap 5-20 30/30; 
        false flags 0, untouched bitwise 1, max err 4.14e+00 m/s, Delta 1.5080, status corrected
  [FAIL] T2b storm, Delta estimated 1.5085 m/s (reported; T2b criterion)
        S1 single 200/200; S2 double 50/50; S3 two-beam 30/30; S4 run 2-11 40/40; S5 run 12-30 10/10; S6 gap 1-4 59/60 (1 missed); S7 gap 5-20 30/30; 
        false flags 0, untouched bitwise 1, max err 4.14e+00 m/s, Delta 1.5085, status corrected
=== T3 amplified storm flow, no injections (Delta given 1.508 m/s) ===
  x1.0: 0 corrected samples, 0 unconfirmed samples, 0 edges -> PASS
  x1.5: 0 corrected samples, 0 unconfirmed samples, 1 edges -> PASS
  x2.0: 0 corrected samples, 0 unconfirmed samples, 0 edges -> PASS
=== T5 break tests on the calm base (each must fire; unbroken T2a above) ===
  B1 T columns 1,2 swapped             status corrected     exact 136/420, wrong 284 -> fires: PASS
  B2 Delta = 1.0 m/s                   status refused_delta exact 0/420, wrong 0 -> fires: PASS
  B3 Z sign flipped                    status corrected     exact 30/420, wrong 0 -> fires: PASS
  B4 T rows 1,2 swapped                status no_steps      exact 0/420, wrong 0 -> fires: PASS
  B5 1.30 m/s steps, Delta estimated   status refused_delta exact 0/420, wrong 0 -> fires: PASS
=== T6 criterion 2: TOR17C 2018-03-07 00:00-14:00 UTC (filename clock 03-06 16:00 to 03-07 06:00) ===
  03-07 00:00  n  7100  |b2|>0.9 m/s: 19.000% ->  0.000%   max |d median| 0.0055 m/s
  03-07 01:00  n  4850  |b2|>0.9 m/s: 15.856% ->  2.907%   max |d median| 0.0077 m/s
  03-07 02:00  n   143  |b2|>0.9 m/s:  0.000% ->  0.000%   max |d median| 0.0000 m/s
  03-07 03:00  n  3438  |b2|>0.9 m/s:  0.000% ->  0.000%   max |d median| 0.0000 m/s
  03-07 04:00  n  7134  |b2|>0.9 m/s:  0.000% ->  0.000%   max |d median| 0.0000 m/s
  03-07 05:00  n  6360  |b2|>0.9 m/s:  0.000% ->  0.000%   max |d median| 0.0000 m/s
  03-07 06:00  n  5179  |b2|>0.9 m/s:  0.000% ->  0.000%   max |d median| 0.0000 m/s
  03-07 07:00  n   771  |b2|>0.9 m/s:  0.000% ->  0.000%   max |d median| 0.0000 m/s
  03-07 08:00  n  1388  |b2|>0.9 m/s: 20.749% ->  5.403%   max |d median| 0.0105 m/s
  03-07 09:00  n  2277  |b2|>0.9 m/s: 25.033% ->  7.773%   max |d median| 0.0119 m/s
  03-07 10:00  n  2624  |b2|>0.9 m/s: 19.169% ->  3.392%   max |d median| 0.0081 m/s
  03-07 11:00  n   777  |b2|>0.9 m/s:  2.445% ->  0.257%   max |d median| 0.0013 m/s
  03-07 12:00  n  3240  |b2|>0.9 m/s:  7.006% ->  0.216%   max |d median| 0.0032 m/s
  03-07 13:00  n  6009  |b2|>0.9 m/s: 10.351% ->  0.316%   max |d median| 0.0018 m/s
  hours below 0.1%: 7/14 -> FAIL; max hourly median change 0.0119 m/s (< 0.005) -> FAIL
```

### 10.3 T4 full L1 builds

```
T4 MOP586_5m: status no_steps, corrected samples 0, unconfirmed 0, rejected 182, unclosed 1, k-array 11686584x3, head VEC 5724
T4 MOP586_7m: status no_steps, corrected samples 0, unconfirmed 0, rejected 0, unclosed 0, k-array 11860243x3, head VEC 5729
```

### 10.4 T6 on existing L1 (APPROXIMATE: L1 tilt rotation not undone; raw is server-only)

```
TOR25S MOP586_15m: head VEC 5728 from 5 .hdr (max diff 0.0e+00)
  rotation check: max |reproduced - stored BuoyCoord| = 0.00e+00 m/s
  status corrected, Delta 1.4948 m/s (n 61, IQR 1.486-1.505)
                nSamples: 36
                   nRuns: 34
       nRunsLevelChecked: 5
           nRunsZeroEdge: 0
            nRunsOneEdge: 0
             nRunsDouble: 0
          nRunsMultiBeam: 1
              runLenHist: [32 2 0 0]
              longestRun: 2
        nUnconfirmedRuns: 0
     nUnconfirmedSamples: 0
            nLongOffsets: 0
    nRejectedOneZeroEdge: 0
                  nEdges: 69
               nSegments: 243
  corrected samples: 36
   795412  2025-03-10 07:04:23  k=[ 0 -1  0]  beams before [ -0.00  -1.50  -0.00] after [ -0.00  -0.00  -0.00]  |u_h|  4.00 ->  0.01 m/s
   1068130  2025-03-11 20:57:02  k=[ 0  1  0]  beams before [ -0.00   1.51   0.06] after [ -0.00   0.01   0.06]  |u_h|  3.95 ->  0.14 m/s
   1248299  2025-03-12 21:58:27  k=[ 0 -1  0]  beams before [ -0.01  -1.51  -0.00] after [ -0.01  -0.02  -0.00]  |u_h|  4.03 ->  0.04 m/s
   1319952  2025-03-13 07:55:33  k=[ 0 -1  0]  beams before [  0.00  -1.50   0.00] after [  0.00  -0.01   0.00]  |u_h|  4.04 ->  0.04 m/s
   1369138  2025-03-13 14:45:26  k=[ 0  0 -1]  beams before [  0.01   0.02  -1.49] after [  0.01   0.02   0.01]  |u_h|  4.04 ->  0.02 m/s
   1444394  2025-03-14 01:12:34  k=[ 0  1  0]  beams before [  0.01   1.55   0.01] after [  0.01   0.05   0.01]  |u_h|  4.10 ->  0.10 m/s
   1481679  2025-03-14 06:23:17  k=[ 0  0 -1]  beams before [  0.01   0.00  -1.50] after [  0.01   0.00  -0.01]  |u_h|  4.05 ->  0.03 m/s
   2040253  2025-03-17 11:58:04  k=[ 0  1  0]  beams before [ -0.01   1.50  -0.00] after [ -0.01   0.01  -0.00]  |u_h|  4.02 ->  0.03 m/s
   5362369  2025-04-05 17:22:22  k=[ 0  1  0]  beams before [  0.01   1.49   0.01] after [  0.01  -0.00   0.01]  |u_h|  3.98 ->  0.03 m/s
   5534911  2025-04-06 17:20:13  k=[ 1  0  0]  beams before [  1.49   0.01   0.00] after [ -0.01   0.01   0.00]  |u_h|  3.92 ->  0.04 m/s
   5555697  2025-04-06 20:13:26  k=[ 0  0  1]  beams before [ -0.01  -0.01   1.48] after [ -0.01  -0.01  -0.01]  |u_h|  4.01 ->  0.02 m/s
   5559018  2025-04-06 20:41:06  k=[ 0 -1  0]  beams before [  0.00  -1.52   0.01] after [  0.00  -0.03   0.01]  |u_h|  4.08 ->  0.08 m/s
   5559847  2025-04-06 20:48:01  k=[ 0  1  0]  beams before [  0.01   1.50   0.01] after [  0.01   0.00   0.01]  |u_h|  3.98 ->  0.02 m/s
   5560984  2025-04-06 20:57:29  k=[ 0  0 -1]  beams before [  0.01   0.01  -1.48] after [  0.01   0.01   0.02]  |u_h|  4.01 ->  0.02 m/s
   5561750  2025-04-06 21:03:52  k=[ 0  1  0]  beams before [ -0.00   1.49   0.01] after [ -0.00  -0.01   0.01]  |u_h|  3.98 ->  0.03 m/s
   5579108  2025-04-06 23:28:31  k=[ 0  1  0]  beams before [ -0.00   1.49  -0.00] after [ -0.00  -0.00  -0.00]  |u_h|  4.01 ->  0.01 m/s
   6992709  2025-04-15 03:48:32  k=[ 0 -1  0]  beams before [ -0.02  -1.51   0.02] after [ -0.02  -0.01   0.02]  |u_h|  4.04 ->  0.11 m/s
   7098440  2025-04-15 18:29:37  k=[ 0 -1  0]  beams before [ -0.02  -1.49   0.00] after [ -0.02   0.00   0.00]  |u_h|  3.97 ->  0.05 m/s
   7122851  2025-04-15 21:53:03  k=[ 0 -1  0]  beams before [ -0.02  -1.50  -0.02] after [ -0.02  -0.00  -0.02]  |u_h|  3.96 ->  0.04 m/s
   7262414  2025-04-16 17:16:04  k=[ 1  0  0]  beams before [  1.49  -0.00   0.00] after [ -0.00  -0.00   0.00]  |u_h|  3.95 ->  0.01 m/s
   7440730  2025-04-17 18:02:02  k=[ 0  1  0]  beams before [  0.00   1.50   0.00] after [  0.00   0.00   0.00]  |u_h|  4.00 ->  0.01 m/s
   7441362  2025-04-17 18:07:18  k=[ 0 -1  0]  beams before [  0.00  -1.49  -0.01] after [  0.00   0.00  -0.01]  |u_h|  3.99 ->  0.02 m/s
   7695183  2025-04-19 05:22:29  k=[ 0  1  0]  beams before [ -0.01   1.50   0.01] after [ -0.01   0.01   0.01]  |u_h|  4.03 ->  0.04 m/s
   7782487  2025-04-19 17:30:01  k=[ 0  0 -1]  beams before [ -0.01   0.00  -1.49] after [ -0.01   0.00   0.01]  |u_h|  4.00 ->  0.04 m/s
   8418213  2025-04-23 09:47:44  k=[ 0  0 -1]  beams before [ -0.02   0.01  -1.49] after [ -0.02   0.01   0.00]  |u_h|  4.01 ->  0.07 m/s
   8426654  2025-04-23 10:58:04  k=[ 0 -1  0]  beams before [ -0.00  -1.51  -0.01] after [ -0.00  -0.01  -0.01]  |u_h|  4.02 ->  0.02 m/s
   8447408  2025-04-23 13:51:01  k=[-1  0  0]  beams before [ -1.49  -0.00   0.00] after [  0.01  -0.00   0.00]  |u_h|  3.94 ->  0.02 m/s
   8447409  2025-04-23 13:51:02  k=[-1  0  0]  beams before [ -1.49  -0.00   0.03] after [  0.01  -0.00   0.03]  |u_h|  3.98 ->  0.07 m/s
   8450317  2025-04-23 14:15:16  k=[ 0  1  0]  beams before [ -0.02   1.48   0.01] after [ -0.02  -0.01   0.01]  |u_h|  3.98 ->  0.06 m/s
   8450318  2025-04-23 14:15:16  k=[ 0 -1  0]  beams before [ -0.03  -1.51   0.00] after [ -0.03  -0.01   0.00]  |u_h|  4.01 ->  0.07 m/s
   8453057  2025-04-23 14:38:06  k=[ 1  0 -1]  beams before [  1.49   0.00  -1.48] after [ -0.00   0.00   0.01]  |u_h|  6.86 ->  0.04 m/s
   8460455  2025-04-23 15:39:45  k=[ 0 -1  0]  beams before [ -0.01  -1.49  -0.00] after [ -0.01   0.01  -0.00]  |u_h|  3.96 ->  0.04 m/s
   8461991  2025-04-23 15:52:33  k=[ 1  0  0]  beams before [  1.49  -0.00   0.01] after [ -0.01  -0.00   0.01]  |u_h|  3.91 ->  0.06 m/s
   8464635  2025-04-23 16:14:35  k=[ 0  1  0]  beams before [ -0.01   1.47  -0.00] after [ -0.01  -0.03  -0.00]  |u_h|  3.94 ->  0.06 m/s
   8465500  2025-04-23 16:21:47  k=[ 0  0 -1]  beams before [  0.01   0.01  -1.52] after [  0.01   0.01  -0.03]  |u_h|  4.13 ->  0.11 m/s
   9036478  2025-04-26 23:39:56  k=[ 0 -1  0]  beams before [  0.00  -1.51   0.01] after [  0.00  -0.01   0.01]  |u_h|  4.06 ->  0.06 m/s
  unconfirmed samples: 0
TBR23 MOP586_5m: head VEC 5730 from 5 .hdr (max diff 0.0e+00)
  rotation check: max |reproduced - stored BuoyCoord| = 0.00e+00 m/s
  status corrected, Delta 1.5315 m/s (n 2, IQR 1.521-1.542)
                nSamples: 1
                   nRuns: 1
       nRunsLevelChecked: 0
           nRunsZeroEdge: 0
            nRunsOneEdge: 0
             nRunsDouble: 0
          nRunsMultiBeam: 0
              runLenHist: [1 0 0 0]
              longestRun: 1
        nUnconfirmedRuns: 0
     nUnconfirmedSamples: 0
            nLongOffsets: 0
    nRejectedOneZeroEdge: 0
                  nEdges: 2
               nSegments: 3907
  corrected samples: 1
   6601154  2023-06-24 23:23:04  k=[-1  0  0]  beams before [ -1.56  -0.03   0.00] after [ -0.03  -0.03   0.00]  |u_h|  4.09 ->  0.08 m/s
  unconfirmed samples: 0
TOR25S MOP586_15m: 36 samples changed, in 27 segValid_vel hours (of 1566)
  whole record, segValid_vel:
    <u|u|^2> full        -1.8734 m^3/s^3 h -> -1.9496 m^3/s^3 h  change -4.1%
    <u|u|^3> full        -0.3196 m^4/s^4 h -> -0.7334 m^4/s^4 h  change -129.5%
    <u|u|^2> detrended   +0.1927 m^3/s^3 h -> +0.1152 m^3/s^3 h  change -40.2%
    <u|u|^3> detrended   +0.5174 m^4/s^4 h -> +0.0973 m^4/s^4 h  change -81.2%
    (context: sum |<u|u|^2>| 4.452 m^3/s^3 h, sum |<u|u|^3>| 2.219 m^4/s^4 h)
TBR23 MOP586_5m: 1 samples changed, in 1 segValid_vel hours (of 1429)
  whole record, segValid_vel:
    <u|u|^2> full        +0.3438 m^3/s^3 h -> +0.3525 m^3/s^3 h  change +2.5%
    <u|u|^3> full        +0.5241 m^4/s^4 h -> +0.5590 m^4/s^4 h  change +6.7%
    <u|u|^2> detrended   +1.5924 m^3/s^3 h -> +1.6011 m^3/s^3 h  change +0.5%
    <u|u|^3> detrended   +1.1351 m^4/s^4 h -> +1.1696 m^4/s^4 h  change +3.0%
    (context: sum |<u|u|^2>| 3.468 m^3/s^3 h, sum |<u|u|^3>| 1.674 m^4/s^4 h)
  Paper 1 segments (1429, bailard_full_segments.csv):
    <u|u|^2> full        +0.3438 m^3/s^3 h -> +0.3525 m^3/s^3 h  change +2.5%
    <u|u|^3> full        +0.5241 m^4/s^4 h -> +0.5590 m^4/s^4 h  change +6.7%
    <u|u|^2> detrended   +1.5924 m^3/s^3 h -> +1.6011 m^3/s^3 h  change +0.5%
    <u|u|^3> detrended   +1.1351 m^4/s^4 h -> +1.1696 m^4/s^4 h  change +3.0%
    (context: sum |<u|u|^2>| 3.468 m^3/s^3 h, sum |<u|u|^3>| 1.674 m^4/s^4 h)
```

### 10.5 Exact runs on server raw (HLB approved the copy 2026-11-13: "Yes, copy them")

Raw cache: `~/LocalData/Scripps/Research/PUV_Pipeline/raw_cache_beamstep/`, 1.7 GB, `.VEC` and
`.hdr` only of TOR25S MOP586_15m, TBR23 MOP586_5m, TOR23W MOP586_5m and MOP586_7m, copied
read-only from `/Volumes/group/PUV_data/Vector/`; 40/40 files equal in size to the server. Evictable;
**delete when HLB rules on the rebuild.** Each record was built twice with the same code and raw
(`.VEC` ingest), correction off and on. Moments: hour segments matched to the catalog L2 by
segment center, catalog shore-normal angle, morphology_ml helpers unchanged. The uncorrected
builds reproduce the catalog-L1 moments of section 10.4 to 4 decimals.

```
  Head matrix: hdr+vec (head VEC 5723)
  Tilt < 1° — no tilt correction needed
RESULT TOR23W MOP586_5m | no_steps | head VEC 5723 | Delta NaN m/s (n 0, IQR NaN-NaN) | corrected 0 samples in 0 runs | unconfirmed 0 | rejected 517 | unclosed 0
  Head matrix: hdr+vec (head VEC 5729)
  Tilt correction: median pitch=1.3°, roll=0.1° — applying rotation
RESULT TOR23W MOP586_7m | no_steps | head VEC 5729 | Delta NaN m/s (n 0, IQR NaN-NaN) | corrected 0 samples in 0 runs | unconfirmed 0 | rejected 6 | unclosed 0
  Head matrix: hdr+vec (head VEC 5728)
RESULT TOR25S MOP586_15m | corrected | head VEC 5728 | Delta 1.4948 m/s (n 61, IQR 1.486-1.505) | corrected 36 samples in 34 runs | unconfirmed 0 | rejected 0 | unclosed 0
   2025-03-10 07:04:23 k=[ 0 -1  0] |u_h| 4.00 -> 0.01 m/s
   2025-03-11 20:57:02 k=[ 0  1  0] |u_h| 3.95 -> 0.14 m/s
   2025-03-12 21:58:27 k=[ 0 -1  0] |u_h| 4.03 -> 0.04 m/s
   2025-03-13 07:55:33 k=[ 0 -1  0] |u_h| 4.04 -> 0.04 m/s
   2025-03-13 14:45:26 k=[ 0  0 -1] |u_h| 4.04 -> 0.02 m/s
   2025-03-14 01:12:34 k=[ 0  1  0] |u_h| 4.10 -> 0.10 m/s
   2025-03-14 06:23:17 k=[ 0  0 -1] |u_h| 4.05 -> 0.03 m/s
   2025-03-17 11:58:04 k=[ 0  1  0] |u_h| 4.02 -> 0.03 m/s
   2025-04-05 17:22:22 k=[ 0  1  0] |u_h| 3.98 -> 0.03 m/s
   2025-04-06 17:20:13 k=[ 1  0  0] |u_h| 3.92 -> 0.04 m/s
   2025-04-06 20:13:26 k=[ 0  0  1] |u_h| 4.01 -> 0.02 m/s
   2025-04-06 20:41:06 k=[ 0 -1  0] |u_h| 4.08 -> 0.08 m/s
   2025-04-06 20:48:01 k=[ 0  1  0] |u_h| 3.98 -> 0.02 m/s
   2025-04-06 20:57:29 k=[ 0  0 -1] |u_h| 4.01 -> 0.02 m/s
   2025-04-06 21:03:52 k=[ 0  1  0] |u_h| 3.98 -> 0.03 m/s
   2025-04-06 23:28:31 k=[ 0  1  0] |u_h| 4.01 -> 0.01 m/s
   2025-04-15 03:48:32 k=[ 0 -1  0] |u_h| 4.04 -> 0.11 m/s
   2025-04-15 18:29:37 k=[ 0 -1  0] |u_h| 3.97 -> 0.05 m/s
   2025-04-15 21:53:03 k=[ 0 -1  0] |u_h| 3.96 -> 0.04 m/s
   2025-04-16 17:16:04 k=[ 1  0  0] |u_h| 3.95 -> 0.01 m/s
   2025-04-17 18:02:02 k=[ 0  1  0] |u_h| 4.00 -> 0.01 m/s
   2025-04-17 18:07:18 k=[ 0 -1  0] |u_h| 3.99 -> 0.02 m/s
   2025-04-19 05:22:29 k=[ 0  1  0] |u_h| 4.03 -> 0.04 m/s
   2025-04-19 17:30:01 k=[ 0  0 -1] |u_h| 4.00 -> 0.04 m/s
   2025-04-23 09:47:44 k=[ 0  0 -1] |u_h| 4.01 -> 0.07 m/s
   2025-04-23 10:58:04 k=[ 0 -1  0] |u_h| 4.02 -> 0.02 m/s
   2025-04-23 13:51:01 k=[-1  0  0] |u_h| 3.94 -> 0.02 m/s
   2025-04-23 13:51:02 k=[-1  0  0] |u_h| 3.98 -> 0.07 m/s
   2025-04-23 14:15:16 k=[ 0  1  0] |u_h| 3.98 -> 0.06 m/s
   2025-04-23 14:15:16 k=[ 0 -1  0] |u_h| 4.01 -> 0.07 m/s
   2025-04-23 14:38:06 k=[ 1  0 -1] |u_h| 6.86 -> 0.04 m/s
   2025-04-23 15:39:45 k=[ 0 -1  0] |u_h| 3.96 -> 0.04 m/s
   2025-04-23 15:52:33 k=[ 1  0  0] |u_h| 3.91 -> 0.06 m/s
   2025-04-23 16:14:35 k=[ 0  1  0] |u_h| 3.94 -> 0.06 m/s
   2025-04-23 16:21:47 k=[ 0  0 -1] |u_h| 4.13 -> 0.11 m/s
   2025-04-26 23:39:56 k=[ 0 -1  0] |u_h| 4.06 -> 0.06 m/s
  Head matrix: hdr+vec (head VEC 5730)
  Tilt correction: median pitch=-0.2°, roll=-3.8° — applying rotation
RESULT TBR23 MOP586_5m | corrected | head VEC 5730 | Delta 1.5315 m/s (n 2, IQR 1.526-1.537) | corrected 1 samples in 1 runs | unconfirmed 0 | rejected 0 | unclosed 0
   2023-06-24 23:23:04 k=[-1  0  0] |u_h| 4.09 -> 0.05 m/s

TOR25S MOP586_15m: 36 samples changed; 1566 segValid_vel hours matched (catalog L2 has 1566); 27 hours contain a change
  <u|u|^2> full        -1.8734 m^3/s^3 h -> -1.9496 m^3/s^3 h  change -4.1%
  <u|u|^3> full        -0.3196 m^4/s^4 h -> -0.7334 m^4/s^4 h  change -129.5%
  <u|u|^2> detrended   +0.1927 m^3/s^3 h -> +0.1152 m^3/s^3 h  change -40.2%
  <u|u|^3> detrended   +0.5174 m^4/s^4 h -> +0.0973 m^4/s^4 h  change -81.2%

TBR23 MOP586_5m: 1 samples changed; 1429 segValid_vel hours matched (catalog L2 has 1429); 1 hours contain a change
  <u|u|^2> full        +0.3438 m^3/s^3 h -> +0.3525 m^3/s^3 h  change +2.5%
  <u|u|^3> full        +0.5241 m^4/s^4 h -> +0.5590 m^4/s^4 h  change +6.7%
  <u|u|^2> detrended   +1.5924 m^3/s^3 h -> +1.6011 m^3/s^3 h  change +0.5%
  <u|u|^3> detrended   +1.1351 m^4/s^4 h -> +1.1696 m^4/s^4 h  change +3.0%

TOR23W MOP586_5m: 0 samples changed; 1094 segValid_vel hours matched (catalog L2 has 1094); 0 hours contain a change
  <u|u|^2> full        +12.2018 m^3/s^3 h -> +12.2018 m^3/s^3 h  change +0.0%
  <u|u|^3> full        +22.3969 m^4/s^4 h -> +22.3969 m^4/s^4 h  change +0.0%
  <u|u|^2> detrended   +30.4496 m^3/s^3 h -> +30.4496 m^3/s^3 h  change +0.0%
  <u|u|^3> detrended   +48.5328 m^4/s^4 h -> +48.5328 m^4/s^4 h  change +0.0%

TOR23W MOP586_7m: 0 samples changed; 1694 segValid_vel hours matched (catalog L2 has 1694); 0 hours contain a change
  <u|u|^2> full        +13.7833 m^3/s^3 h -> +13.7833 m^3/s^3 h  change +0.0%
  <u|u|^3> full        +32.4785 m^4/s^4 h -> +32.4785 m^4/s^4 h  change +0.0%
  <u|u|^2> detrended   +33.2337 m^3/s^3 h -> +33.2337 m^3/s^3 h  change +0.0%
  <u|u|^3> detrended   +58.5824 m^4/s^4 h -> +58.5824 m^4/s^4 h  change +0.0%
```

## 11. HLB decisions (2026-11-13)

HLB approved all five decisions put to him in `docs/REPORT_L1_beam_step_correction_2026-11-13.md`
section 6. His words, relayed by the deep_transport_map session: "Yes, all five".

1. **The rule is accepted with its three failures as stated**: storm synthetic S6 59/60 (real
   COR16B base and synthetic), TOR17C flicker hours 7/14 below 0.1%, TOR17C hourly median shift
   0.0119 m/s against 0.005 m/s. They are not to be tuned away; they stay documented here.
2. **In L2, samples flagged `qc.vel_beamstep_unconfirmed` are treated as gaps** for the existing
   fill rule.
3. **TOR24W MOP586_15m serial** in `config/TOR24W_config.m` changes from 16737 to 17047 (head
   VEC 5728), with a dated comment citing the `.hdr` and DeploymentNotes2024-2025.xls rows 37 and
   39.
4. **TOR23W MOP586_10m gets a documented per-record velocity cutoff** from 2023-12-30 15:29 UTC
   (L2 index 1097, 0-based). The depth-neighbor Ub audit is a separate follow-up, not part of
   this rebuild.
5. **The rebuild bundle.** Hand-merge `beam-step-correction-20261113` with `tb-period-20261105`
   and `swart-amplitude-20261111` (both kept; this also settles HLB's T_b/Swart question). Then
   rebuild all 66 L1 records, L2 to L4, the 9 L4_xspec files and the stale Altimeter_Pipeline L4.
   Declared size: about 92.8 GB raw read, about 96 GB of local outputs replaced; run
   `storage_audit.sh` before and after.
   - The reefbreak push waits for the Paper 1 closure diff: TBR23 L2 should match the current
     build field for field except MOP586_5m segment 916 and anything the detector adds. That diff
     is reported before any push, and the push needs HLB's separate go.
   - The 1.7 GB `raw_cache_beamstep` and the 4.2 GB scratch dumps are deleted once the rebuild is
     verified, and the deletion is recorded.
   - No commits without HLB asking.

## 12. Rebuild log (decision 5), 2026-11-13 onward

**Code.** `swart-amplitude-20261111` (contains `tb-period-20261105`) hand-merged into the worktree,
uncommitted: 19 files taken from that branch as they are, `PUV_raw_process.m` 3-way merged with no
conflict (the beam-step block stays before sound speed, tilt and the buoy-frame rotation),
`CHANGELOG.md` conflict resolved by keeping both entries. Decisions 2 to 4 implemented:
`PUV_L2_spectral.m` velocity gaps (test `L2_spectral/test_L2_velgap.m`, 6/6 with 2 break tests),
`config/TOR23W_config.m` `velInvalidFrom = 2023-12-30 15:29 UTC`, `config/TOR24W_config.m`
serial 17047. C3 in `test_vector_beam_step` became a guard on the accepted outcome (fires when
broken: S6 0/60 with `tolLevel` 0). `run_all_tests` on the merged tree: **27/27 pass**.

**Driver.** `scripts/rebuild_beamstep_2026_11_13.m` (stages preflight, raw, L1, L2L4, xspec).
Preflight: 50 deployments, **66 records**, 66/66 with an L1 on disk. L1 gate: the new L1 must equal
the old one except velocity at corrected samples, or it is not saved.

**Before writing.**
- `storage_audit.sh --quick`: 253 GiB free; `~/LocalData` 272 GB.
- Manifest of every L1-L4 and L4_xspec file before the rebuild:
  `docs/archive_snapshot_manifests/pre_beamstep_rebuild_2026-11-13_manifest.csv`, 548 files,
  102.7 GB, sha256. No byte backups (the server holds catalog 2026-10-14.1).
- Byte snapshot for the closure diff: `outputs/_pre_beamstep_TBR23_2026-11-13/` (TBR23 L1 and L2,
  2.8 GB). Delete when the closure diff is accepted and the push verified.
- Raw: `~/LocalData/Scripps/Research/PUV_Pipeline/raw_cache_rebuild_20261113/` (about 92.8 GB,
  copied read-only from `/Volumes/group/PUV_data/Vector`, server read 5.9 MB/s). Evictable; delete
  once the rebuild is verified.

**Correction (first person, rule 15).** I said the closure diff would show TBR23's bed-stress
fields changing on every segment because of the T_b and Swart branches. That is false for TBR23:
all four TBR23 L2 files were built 2026-11-12 (07:37Z to 07:51Z) from 2571829 on
`swart-amplitude-20261111` with `dirty: true` (their `.prov.json`), so they already carry both
changes, and the snapshot is byte-identical to them (4/4). The closure diff therefore judges every
field, bed-stress included, against identical; a difference outside the segments holding
corrected or unconfirmed samples is a finding (the dirty tree differed from 2571829, or the merge
changed something). The expectation of change does hold for the October-built deployments.

**L1 gate, first pass (13 locally cached records).** ENU 3/3 PASS (SOL24, LPL24, LPL25A: 0 samples
changed, saved). XYZ 10/10 FAILED the gate, not saved: buoy-frame U and V differed outside the
corrected samples (W and instrument-frame U, V did not). Cause, measured on the stored L1:
`tb-period-20261105`'s `xyz_to_buoy_frame` computes the scalar-heading rotation elementwise, which
rounds differently from the 2x2 matrix product the catalog was built with, by at most 4.4e-16 m/s
on about 40% of samples (TOR24S/MOP586_7m 5,037,962 of 11,335,718; TOR17C 1,657,498 of 4,308,976;
TBR23/MOP586_5m 3,965,521 of 11,056,771); the matrix product reproduces the stored BuoyCoord with
max difference 0 m/s on all three. Change: `xyz_to_buoy_frame` uses the matrix product for a
scalar heading (the per-sample path, used by SOL25A only, is unchanged); it now reproduces the
stored TOR24S/MOP586_7m BuoyCoord bitwise, and `test_xyz_heading_rotation` passes, break cases
included. The gate itself was not loosened.

**L1, local pass after the rotation fix.** 10/10 XYZ records PASS (TOR24S MOP586_5m and MOP586_7m,
TOR16A to TOR16D, TOR17A, TOR17C, COR16B, SIO24A; beam-step samples changed 0, 0, 0, 179, 1,090, 99,
1, 4,600, 240, 1). L2-L4 for those 13 records: **13/13 PASS** (L2 time grid, CDIP shore-normal and
storm reference unchanged; L2 segValid and Hs unchanged on every record; L4 aligned with
eta.depth = L2.depth to 0 m). **Flag:** the L3 mobilized fraction rises on 12 of the 13 (TOR17A
77.1% to 99.1%, TOR16A 80.5% to 98.8%, TOR17C 85.8% to 99.3%, COR16B 87.3% to 96.8%) with ws and
theta_cr unchanged. This is the T_b/Swart bed stress reaching the October-built records; it was
not investigated here.

**Raw copy.** Finished with 0 failures, **137 GB** (declared 92.8 GB from a `du` over SMB, which
under-reported; e.g. TBR23 8.8 GB local against 4.4 GB by server `du`). Free disk afterwards
119 GiB.

**L1, remaining 53 records, first pass.** 31 PASS, 22 FAILED (not saved). With the gate's numbers
(re-run report-only):
- 16 records (LPL23, LPL25B, RUBY22 x3, SIO25B, SIO25D, SIO25E, TOR24S MOP580_7m and MOP586_10m,
  TOR24W x3, TOR25S x2): only `rotation.mag` differs, by 2.2e-6 deg to 2.5e-3 deg; buoy-frame
  velocity changes by exactly a rotation through that angle (max |du_h|/|u_h| equals |dmag| in
  radians on all 16; max |du_h| 3.1e-4 m/s); instrument frame identical. The declination computed
  today differs slightly from the one stored when each L1 was built.
- SOL26A: U, V differ by at most 1.2e-16 m/s (built 2026-10-16 with the elementwise rotation).
- CAT21A: declination -0.0616 deg and LATLON: the July correction of its 21.9 km coordinate error
  never reached L1 (its L1 predates provenance stamping). Pure rotation, max |du_h| 4.2 mm/s.
- CAT21B, SIO25C, IB19S MOP055_7m, TOR23W MOP586_10m: the 2026-07-24 power-on-glitch trim
  (commit 662177c) discarded 84,064 to 5,687,824 leading samples of single-file records whose L1s
  predate it; two came out empty, two with 1,700 and 2,676 samples against 125,811 and 1,419,004.
- TOR18A: its `*_rep` repair files carry a placeholder head (identity matrix, serial VEC 0000).

**Changes (each after the failure above; the gate's identity requirement was not loosened):**
- `vector_head_matrix` skips placeholder heads and counts them (TOR18A: 1,322 real `.hdr` agree,
  4 placeholders skipped, head VEC 4400; a placeholder-only input still refuses).
- The power-on trim is bounded: a stretch longer than `cfg.qcOpts.powerOnGlitchMaxSec` (default
  10 s) before the first gap is data, and the interior-cutoff logic handles the gap as before
  2026-07-24. The gate then shows whether the result reproduces the pre-July L1.
- Gate extension, the only one: accepted if the differences are confined to `rotation.mag`, a
  LATLON now equal to the config value, and buoy-frame U, V, with every buoy-frame change no larger
  than a rotation through the measured declination change, |du_h| <= |u_h| |dmag| (1 + 1e-6) +
  1e-14 m/s, |dmag| <= 0.1 deg, and the NaN pattern identical. Break test (dmag halved): fires on
  2/2 (CAT21A, TOR24S MOP580_7m); unbroken: 3/3 accept (with SOL26A's rounding). It refreshes
  stale declinations rather than carrying them forward (HLB's standing rule to fix stale products).

**Reporting caveat.** For status `no_steps` the stored `qc.beamstep.counts` describe the
Delta-estimation pass, not corrections: TOR23W MOP580_7m reads `no_steps` with 12 runs found at
Delta0 but none corrected, because no single-beam gap-free edge was available to estimate Delta.
Its 15 step-like samples are therefore left as recorded and are not flagged unconfirmed.

**L1, held records, second pass (2026-11-14).** 22/22 PASS and saved; **all 66 L1 records rebuilt**
(66 distinct records PASS in `outputs/_logs/beamstep_L1_table_2026-11-13.csv`). The four records
the bounded trim affects, against the gate:
- IB19S MOP055_7m: strict identity, 0 of 9,228,002 samples differing (no beam steps).
- TOR23W MOP586_10m: strict identity outside its 8,997 corrected samples (11,307,915 total).
  Delta = 1.4285 m/s, against 1.49 to 1.53 m/s elsewhere: its thermistor was dead, the recorded
  sound speed fell from 1,512 m/s to 1,433 m/s, and 1.508 x 1433/1512 = 1.429 m/s. So the step
  scales with the recorded sound speed (EXPLORATORY support for H1). 8,996 of the 8,997 fall after
  its velocity cutoff (first 2023-12-28 22:52:11, last 2024-01-04 00:00:45 UTC); 2,597 unconfirmed.
- SIO25C: declination group only (dmag 5.97e-5 deg, max |du_h| 7.8e-7 m/s); all other fields
  identical; 125,811 samples, 125,310 with finite velocity, all of which are rotated.
- CAT21B: declination and the Catalina LATLON fix (dmag -0.0616 deg, max |du_h| 7.2e-4 m/s), 1
  beam-step sample; 1,419,004 samples, 462,673 finite.
The exact per-sample count of rotated U, V differences for SIO25C and CAT21B was not kept (the
gate checks a bound, not a count, and the old L1 is replaced locally; the server copy has it).
TOR16B under the bounded trim, report-only against its L1 rebuilt earlier the same day: strict
identity outside its 179 corrected samples (6,088,251 total).

**TOR23W MOP580_7m's 15 uncorrected samples.** 12 runs (1 to 3 samples), all **double steps**
(k = +2 on beam 2), 2023-12-29 05:54:54.5 to 13:50:57.5 UTC; entry jumps +2.59 to +3.01 m/s,
exit -2.53 to -2.96 m/s on beam 2, other beams within 0.42 m/s; |x_h| 5.89 to 6.40 m/s. Delta was
not estimable because the estimate uses only single-beam |k| = 1 gap-free edges, and every edge
here is |k| = 2. They fall in 9 L2 segments (1064 to 1072, 0-based; Hs 2.82 to 3.38 m), **none
segValid_vel** (the storm in which this frame toppled), so they enter no L2 or L3 number; only the
L4 modules reading L1 velocity directly could see them.

**Held:** the L2-L4 launch for the remaining 53 records was blocked by this session's permission
check (it overwrites catalog L2-L4 files); it waits for an explicit go-ahead.

**HLB rulings, 2026-11-14** (relayed; his words: "yes delete the 136 gb and any other files we can
clean up. i don't like disk bloat. seems prudent to flag those tor23w hours.")

*TOR23W MOP580_7m flagged.* New per-record option `beamStep.flagWhenNoDelta` (default false;
set only in `config/TOR23W_config.m` for MOP580_7m): when Delta is not estimable, the runs the
Delta0 pass confirmed are flagged `qc.vel_beamstep_unconfirmed` (values unchanged; status
`no_delta_flagged`), so L2 gaps them under decision 2. Test C6 in `test_vector_beam_step`
(post hoc, criterion fixed before its run): with the option, 20/20 injected double steps flagged
exactly, values bitwise unchanged; without it, 0 flagged. The L1 was rebuilt from raw and saved
only after a gate: every field identical to the stored L1 except the flag, `qc.beamstep` and the
new metadata `head.info.nPlaceholder` (= 0); **15 samples flagged, equal to the 15 known**:
2023-12-29 05:54:54.5, 06:09:19.0, 07:39:52.0, 08:10:25.0, 08:10:40.5, 09:39:29.0, 09:58:05.0,
10:27:16.5, 10:36:47.5, 10:36:48.0, 10:36:48.5, 11:40:15.5, 12:55:50.5, 13:50:57.5, 13:50:58.0 UTC.
They lie in invalid storm hours of the toppled frame (L2 segments 1064 to 1072, none
segValid_vel), so no L2 or L3 number changes. Not flagged: 6 further step-like samples in 3 runs
that the Delta0 pass itself could not confirm (the ruling named the 15). Not covered by the ruling:
**LPL23 LPL_8m** has the same situation with 1 run of 1 sample; left unflagged for HLB.

*Deletions (rule 25: nothing pending reads them; only L1 reads raw and all 66 L1 records have
passed; the scratch dumps fed tests whose results are written above).*
| path | measured size | regenerate |
|---|---|---|
| `~/LocalData/Scripps/Research/PUV_Pipeline/raw_cache_rebuild_20261113/` | 140.55 GB (du -k) | `stage='raw'` of `scripts/rebuild_beamstep_2026_11_13.m` (copy_raw_to_local from `/Volumes/group/PUV_data/Vector`) |
| `~/LocalData/Scripps/Research/PUV_Pipeline/raw_cache_beamstep/` | 1.75 GB | copy the `.VEC` and `.hdr` of TOR25S MOP586_15m, TBR23 MOP586_5m, TOR23W MOP586_5m and MOP586_7m from `/Volumes/group/PUV_data/Vector` |
| session scratch `runs/` (corrector-input dumps, off/on L1 builds) | 8.20 GB | L1 builds with `cfg.beamStep.dumpInputTo` from re-copied raw |
| session scratch `l1approx/` | 0.41 GB | `l1approx_correct` on the catalog L1 (approximate path, superseded) |
Deleted 2026-11-14; free space 102.6 GiB before, **221.2 GiB after**. Kept: the TBR23 snapshot
`outputs/_pre_beamstep_TBR23_2026-11-13/` (2.8 GB, until the closure diff is accepted), the sha256
manifest, and the older `outputs/_pre_*` snapshots (resolved separately by the morphology_ml
session). `validate_beam_step_20261113.m` can no longer be rerun without regenerating dumps.

**L2-L4 hang (2026-11-15).** The L2-L4 run for the remaining 53 records, started 2026-11-14 on
HLB's go-ahead, hung in the L4 bispectra parfor on IB19S MOP055_7m (record 21 of 66): the log was
last written 2026-11-14 17:34 and the client sat 16.5 h with its 10 pool workers idle, the hang
`run_L4_refresh_watchdog.sh` exists for. I had launched without a watchdog. Stopped the client
(PID 13699) and its workers only; IB19S MOP055_7m's L2 and L4 untouched (dated 2026-10-12/13;
saves are all-or-nothing). 20/66 records had passed L2-L4 by then, 0 failed. Relaunched under
`scripts/run_beamstep_L2L4_watchdog.sh` (45 min stall limit, HUNG records skipped, then retried
once with serial bispectra via `retryHung`/`serialL4`). Watchdog test with a stand-in MATLAB:
stall detected and the record marked HUNG, relaunch skipped it, serial retry ran, 0 processes
left over.

**L2-L4 watchdog run 1 (2026-11-15 10:02 to 15:40).** One stall (SIO25B, 2,703 s; killed and
marked HUNG). Result: 31/66 records PASS in all. 35 FAILED, every one at the same gate: the CDIP
THREDDS shore-normal fetch returned nothing (L2 shorenormal NaN against the stored 259.4 to 283
deg), so nothing was saved for them; they include all four TBR23 records and the two serial
retries (IB19S MOP055_7m, SIO25B). At 18:41 CDIP answered again (HTTP 302 in 0.3 s; D0586 fetch
264.5 deg, equal to the stored value), and the 35 were relaunched under the watchdog.


**L2-L4 complete (2026-11-16 03:55).** Relaunch under the watchdog: no stall; serial retries of
IB19S MOP055_7m and SIO25B passed. **66/66 records PASS L2-L4**, 0 outstanding.

**TBR23 Paper 1 closure diff** (`validation/closure_diff_TBR23_20261113.m`; snapshot
`outputs/_pre_beamstep_TBR23_2026-11-13` against the rebuilt L2; every field judged against
identical; allowed segments derived from the new L1's corrected or unconfirmed samples).
- Self-compare (new against new): 4/4 records, 0 fields differ.
- MOP580_7m (1,502 segments) and MOP586_7m (1,590): every compared field identical, bed stress
  included (tau_b, fric_w, Aw, Tb, Ub, uBed_rms, vBed_rms each N/N segments identical). The only
  differences are the three new `velGap` stamp fields.
- MOP580_5m (1,672): every field identical. Its one corrected sample (2023-06-23 22:51:18 UTC) is
  in segment 1229 (0-based), which is neither segValid nor segValid_vel, so no L2 value moves.
- MOP586_5m (1,651): **every segment-level difference is in segment 916** (44 fields, all in the
  allowed set; for example vmom.u_uabs3 max |d| 0.0345 m^4/s^4 and tau_b 0.0145 Pa on that
  segment); the bed-stress fields read 1650/1651 segments identical. The two whole-record fields the
  diff marks UNEXPECTED, `qc_record.ztest_IG.median` and its `reason` string (1.0283 to 1.0290), are
  explained by segment 916 alone: its ztest_IG moved from 0.9739 to 1.1444, and the median over the
  other 1,428 valid segments is 1.028639 in both builds; status `ok` in both.
- Verdict: TBR23 L2 matches the current build field for field, except MOP586_5m segment 916 and
  the record median it feeds. No tau_b or Tb difference anywhere else, so the dirty-tree build of
  2571829 and the merged code agree on TBR23. **The reefbreak push still needs HLB's separate go.**


**L4_xspec (2026-11-16).** 9/9 deployments rebuilt with provenance (IB18W 1 pair, IB19S 1,
RUBY22 3, SOL23 1, TBR23 6, TOR23W 15, TOR24S 6, TOR24W 3, TOR25S 1).

**Altimeter_Pipeline L4 (2026-11-16).** Pre-rebuild sizes and sha256 of the six files:
`docs/archive_snapshot_manifests/pre_beamstep_altimeter_L4_2026-11-16_manifest.csv` (19.7 MB).
`build_L4_site.m` now stamps each PUV L2 and L3 it reads (`L4.prov_parents`); new
`CODES/check_L4_parents_current.m` compares the stamps with the live sidecars. The first rebuild
exposed a bug in my stamp: the path reached `read_prov` as a MATLAB string, so only the embedded
block was read and every stored sha256 was empty; the check reported 0/42 current. Fixed (char
path), rebuilt: **42/42 parent stamps current; break test 1/42 STALE, as required**;
`check_L4_grainsize_current` 6/6 current. Burst counts and puv_valid unchanged at every site.
Ub changed on 124 (TP 5 m), 21 (7 m), 52 (10 m), 146 (15 m), 916 (SIO) and 2,879 (SOL) rows; the
largest changes are the stale August rows the diagnosis found (max |dUb| 13.5 m/s at 15 m,
3.24 m/s at 10 m, 2.4 m/s at SIO), the rest are this rebuild's L2 changes. `storm_flag` sums to 0
at every site in both the August and the new build: pre-existing, not investigated.
`NOTES.md`'s STALE paragraph was replaced: local L4 rebuilt, reefbreak L4 still the August build.


**Audits after the rebuild (2026-11-16).** `audit_registry_loads`: 51/51 entries build, no
orphaned outputs, 7 known-failed instruments, 0 missing. `audit_L4_coverage`: 66/66
content-current (L4.eta.depth = L2.depth to 1e-9 m), 0 alignment problems (its informational
"L4 builtAt older than L2 mtime" on 63/66 follows from saving L2 after building L4 in memory).
`audit_L1_qcopts`: 66/66 match their config. `audit_clock_lag`: 19/19 PASS at lag 0.

**Storage after.** `storage_audit.sh --quick`: 132 GiB free (253 GiB before the rebuild; 221 GiB
right after deleting the caches). `~/LocalData` 277 GB (272 GB before), PUV outputs 100 GB. The
89 GiB gap is held by two Time Machine local snapshots taken while the raw cache existed
(2026-11-13 21:03 and 2026-11-14 16:59); it is released when they expire. Not touched (backups are
HLB's). Scratch copy of the old Altimeter L4 (19 MB) deleted. Kept: the TBR23 snapshot (2.8 GB),
both manifests, the older `outputs/_pre_*` snapshots.

**Done; waiting on HLB:** the reefbreak push (PUV catalog L1-L4 and xspec, Altimeter L4), after
he accepts the TBR23 closure diff; deleting the TBR23 snapshot after that; commits on this branch
and in Altimeter_Pipeline (nothing committed).


**Push (HLB: "Accept, push", 2026-11-16).** HLB accepted the TBR23 closure diff.
- *PUV catalog:* change entry `docs/catalog_changes/2026-11-16_beamstep_tb_swart_rebuild.md`
  (with the pending SOL25A/SOL26A entry). Dry run of `scripts/copy_to_server.m`: provenance gate
  **0 of 273 files refused, 0 forced**, all 273 changed, catalog version 2026-11-16.1. The code_ack
  records that the files were built from uncommitted code (f8c6b5c, dirty), with HLB's approval to
  push before committing. Real push: see below.
- *Altimeter L4:* the six `L4/L4_*.mat` and five `diagnostics/figures/L4_*_diagnostics.png` copied to
  `/Volumes/group/Altimeter_data/Processed_HLB/` (temporary name, then rename); server sha256 equal to
  local on **11/11**; their 11 lines in `MANIFEST.sha256` updated (213 lines); a dated note added to
  `README.md`. Previous server MANIFEST and README kept in
  `docs/archive_snapshot_manifests/altimeter_Processed_HLB_{MANIFEST,README}_pre_2026-11-16.*`. My first
  README append ran through an unquoted heredoc and lost its backticked names (the shell tried to
  execute them; none existed, nothing ran); rewritten from the saved copy plus a correct note, body
  verified unchanged.

- *PUV push, attempt 1:* failed 2026-11-16 15:01 at file 84 of 273 (`copyfile ... Socket is not
  connected`): the reefbreak SMB mount dropped. 83 files had been copied; the server manifest,
  README and CHANGELOG are written only at the end, so they still described 2026-10-14.1. Write
  throughput before the drop: 16.2 GB in 3.5 h (1.3 MB/s). Remounted 21:25 and resumed under
  `scripts/run_push_with_remount.sh` (reruns the idempotent push, remounting first, up to 10
  attempts).
- *PUV push, wrapper attempts 1 to 5 (2026-11-16 21:25 to 2026-11-17 09:20):* the mount dropped
  twice more (22:32, and 03:38 at file 223 of 273, `SOL23/Level4_QC/MOP654_7m_L4.mat`). The
  wrapper's own remounts failed from 07:29 to 09:15; a manual remount at 09:18 succeeded and
  attempt 5 started 09:20. Attempt 2 wrote 30.4 GB in 5.1 h (1.7 MB/s). Left at 09:20: 51 files,
  37.8 GB. The push now stamps catalog version 2026-11-17.1 (run date), not 2026-11-16.1.
- *PUV push, attempts 5 to 7:* the mount dropped again at 09:45 (file 227); attempt 7 (10:38, lab
  network, about 11 to 12 MB/s) completed 11:43: 273 files, 102,482.4 MB, 47 deployments,
  manifest.csv (273 rows), CHANGELOG.md and README.md written as **catalog 2026-11-17.1**. Both
  pending entries (this rebuild, and 2026-10-16 SOL25A heading/SOL26A) now read `published 2026-11-17.1`.
- *Push verification (2026-11-17, after a forced remount; scratchpad verify_push.py, criteria fixed
  before running, break test dropping one manifest match fired):* manifest rows matched to server
  files 273/273, unlisted server files 0; sizes server = manifest = local 273/273; local sha256 =
  sidecar = manifest 273/273; server-file sha256 = manifest 21/21 (all 9 xspec plus 12 random,
  seed 20261117); git f8c6b5c and build_id 273/273.
- *Cleanup (HLB 2026-11-16, "delete raw_cache, the /Library/Caches, and outputs 2/"):*
  - Main checkout `PUV_Pipeline/raw_cache/`: 34,857 files, 22.17 GB removed after checking each
    exists on reefbreak at equal size under its registry rawDataRoot (34,857/34,858, 0 IO errors;
    break test fired). Kept `raw_cache/Ruby2D/legacy_bulk_582_6m.mat` (238 KB, not on the server,
    loaded by scripts/compare_ruby2d.m and diag_compare.m; the 2026-09-21 cleanup kept it too).
    Path and size list: `docs/archive_snapshot_manifests/removed_main_raw_cache_2026-11-17_manifest.csv`.
    Regenerate by re-caching from the registry rawDataRoot.
  - `PUV_Pipeline/outputs 2/`: empty, removed.
  - `~/Library/Caches`: 16.0 GB to 6.0 GB. brew cleanup (2.4 GB), pip cache purge (0.6 GB), and the
    contents of com.apple.Music, com.skype.skype.ShipIt, metro-maker4-updater, colima, Zotero and
    Google Earth (none running). Skipped: Claude app, Codex, Google/Chrome, MATLAB, Apple system
    daemons.
  - `outputs/_pre_beamstep_TBR23_2026-11-13/` (2.8 GB) removed after the verified push. I meant to
    write a fresh manifest first, but the relative path went through the `outputs` symlink and the
    write failed while the removal ran. Its contents (TBR23 L1 and L2 before the rebuild, a byte copy)
    are already recorded with sha256 in `pre_beamstep_rebuild_2026-11-13_manifest.csv`; regenerate
    from base f8c6b5c without the beam-step block.
  - Disk: deletions are held by the Time Machine local snapshot of 2026-11-17 11:30 until it expires.
