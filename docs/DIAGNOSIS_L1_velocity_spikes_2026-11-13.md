# L1 velocity spikes: one-beam steps of about 1.5 m/s, not classical phase wraps (2026-11-13)

**Status: EXPLORATORY diagnosis. Read-only: no code, config, output or server file was changed.**
Asked by the morphology_ml deep_transport_map step 2 session, which found isolated single-sample
jumps of about 4.0 m/s in L1. The L1 change, the rebuild and the merge with `tb-period-20261105` and
`swart-amplitude-20261111` are HLB's decisions. Raw data were read only from the local
`raw_cache/`; `/Volumes/group` was not touched, so instruments without a local raw copy were
analyzed from L1 alone.

## Answer in one paragraph

The isolated ~4.0 m/s spikes are real instrument errors. Each one is a step in a **single beam**,
of fixed size **1.51 m/s along the beam**, which the beam-to-XYZ matrix turns into about 4.0 m/s in
XYZ. About 1% are double steps (about 3.0 m/s along the beam, 8.1 m/s in XYZ). The steps occur
at high correlation (often 80% to 90%), so the L1 correlation gate cannot catch them. They are
**not classical phase wraps** in the sense of a true velocity crossing ±Va: the true beam
velocity at the step is usually near 0 m/s, and the instrument reports beam velocities well
beyond ±0.75 m/s. They behave like the instrument choosing the wrong ambiguity interval. They are
also **not always isolated**. At TOR17C, beam 2 sits offset for runs of up to 186 samples
(93 s). The 2 to 3 m/s shallow group is a detector artifact, not an instrument effect. A
beam-space unwrap at L1 looks feasible; a sketch is at the end.

## Method

- Detection rule, as in the request: jump = x(j) − median(x[j−6..j−2], x[j+2..j+6]) on the
  3-vector; "isolated" means both neighbors' own jumps are below 0.5 m/s; threshold 1.5 m/s
  (lower than the request's 2 m/s, to see the whole distribution). Only samples with
  `qc.valid_vel` count.
- **Change from the morphology_ml rule:** I also required all 13 samples j−6..j+6 to be finite.
  The original rule replaces NaN with 0 in the median and treats a NaN neighbor as "isolated".
- L1 to instrument XYZ: X = `InstrCoord.U`, Y = `InstrCoord.V`, Z = −`BuoyCoord.W`. The sign is
  needed because `PUV_raw_process.m` sets W = −W for XYZ records. Values are divided by
  `qc.vel_c_factor`. L1's pitch/roll rotation (applied when the median tilt exceeds 1°) is not
  undone. For the six ENU-recorded instruments (LPL, SOL, possibly others), "XYZ" here is
  really ENU, so their beam decomposition is approximate.
- XYZ to beam: the inverse of the head's transformation matrix from the ExploreV `.hdr`
  ("Transformation matrix", Head configuration). Where no local `.hdr` exists for a head, I used
  the mean of the 7 local head matrices; their entries differ by up to 0.08 (about 3%).
- Raw ExploreV `.dat` (XYZ, amplitude, correlation) was examined for TOR24S MOP586_5m (S/N 16737,
  head VEC 5724), TOR24S MOP586_7m (S/N 16739, head VEC 5729) and TOR17C MOP591_9m (S/N 1049,
  head VEC 4400, firmware 1.21).
- Scripts (scratch, not in the repo):
  `/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research-morphology-ml/9535ae79-cbd3-48c4-992f-d4118de84c97/scratchpad/`
  `l1_spikes_fin.py` (L1 catalog), `raw_spikes2.py` (raw .dat to beams).

## Known (with the evidence)

1. **The steps are one-beam, of fixed size.** Across the whole L1 catalog (66 records),
   1,258 isolated jumps over 1.5 m/s have a fully finite window. Of these, **950** decompose
   into one beam: the second-largest beam jump is under 0.25 times the largest. Their
   along-beam size is 1.488 m/s at the 25th percentile, **1.508 m/s at the median** and
   1.526 m/s at the 75th percentile (5th to 95th percentile: 1.393 m/s to 1.600 m/s). Their
   XYZ size has a median of 4.05 m/s (1st to 99th percentile: 3.83 m/s to 8.06 m/s).
   - The size is the same on firmware 1.21 (TOR14 to TOR17) and firmware 3.4x (2021 onward),
     across 6 m to 30 m depth, and across every beam: all of beams 1, 2 and 3 appear.
2. **The raw data confirm this with the head's own matrix.** In raw TOR17C, 2,327 isolated
   jumps have all three beam correlations at 70% or more. Their beam jumps are one-beam
   (beam 2) and measure −1.48 m/s to −1.52 m/s or +1.46 m/s to +1.52 m/s. The other two beams
   move by under 0.06 m/s.
   - Typical amplitude at the step: 82 to 95 counts on the stepped beam. Typical correlation:
     72% to 93%. Neighbors look the same, so nothing in amplitude or correlation marks the
     sample.
3. **The XYZ size follows from the transform.** A one-beam step of 1.508 m/s maps to XYZ
   magnitudes of 1.508 m/s × |column of T|. Column norms are 2.61 to 2.73, which gives
   3.94 m/s to 4.11 m/s. The observed one-beam XYZ median is 4.05 m/s.
   - The few discrete directions per deployment are ± the three columns of T, rotated by that
     deployment's heading in the buoy frame. Directions in TOR23W MOP586_10m cluster at
     6 azimuths 60° apart, as three columns with both signs would give.
4. **Double steps exist.** 11 TOR17C events have one-beam jumps of 3.01 m/s to 3.05 m/s (2.0
   times the single step), which gives 8.0 m/s to 8.2 m/s in XYZ.
5. **The 6.8 m/s TOR25S MOP586_15m sample (L1 index 8453056) is two beams stepping at once.**
   Its jump decomposes (mean T) into +1.45 m/s on beam 1 and −1.52 m/s on beam 3, with
   0.01 m/s on beam 2. It drops out of the 13-finite count because it has NaN neighbors.
6. **The steps are not isolated in general.** In raw TOR17C, between 2018-03-06 16:00 and
   2018-03-07 06:00 (filename clock), 7% to 25% of the high-correlation samples per hour have
   beam 2 offset. The offset values cluster at +1.2 m/s to +1.6 m/s and −1.6 m/s to
   −1.4 m/s, while the hourly median beam velocity is −0.06 m/s to +0.02 m/s.
   - Run lengths: 2,787 single samples, 1,203 pairs, 605 triples, 1,069 runs of 4 to 10
     samples, 202 runs of 11 to 100 samples, and 2 runs over 100 samples (longest 186 samples,
     93 s).
   - About 4,100 offset samples in those hours pass the 70% correlation gate.
   - An isolated-spike detector undercounts this kind of event. A 13-sample median detector
     misses it once the run exceeds about 5 samples.
7. **Beam velocities are not confined to ±0.754 m/s.** In TOR24S MOP586_7m, pings with
   correlation under 15% span −2.25 m/s to +2.25 m/s on every beam. The TOR17C offsets sit at
   ±1.4 m/s to ±1.5 m/s. A single-lag ambiguity velocity of 0.754 m/s (half the step) could not
   produce either.
8. **The 2 to 3 m/s shallow group (5 m and 7 m) is a detector artifact.**
   - With the 13-finite requirement, TOR24S MOP586_5m drops from 257 hits to 0,
     TOR23W MOP586_5m from 852 to 0, TOR23W MOP580_5m from 590 to 0, and TOR23W MOP580_7m
     from 287 to 0.
   - Every TOR24S MOP586_5m hit has 2 to 12 NaN samples in its 13-sample window.
   - These are valid storm samples (median own horizontal speed 1.39 m/s) next to QC gaps.
     NaN-as-zero in the reference median makes them look like jumps.
   - Consistent with this, raw TOR24S MOP586_5m and MOP586_7m have 0 of 128 and 0 of 1,566
     isolated raw jumps over 1.5 m/s with all three correlations at 70% or more. Of those jumps,
     126 and 1,565 respectively have a minimum correlation under 50%, so L1 already masks them.
9. **Per-record counts** (one-beam isolated steps, 13-finite window):
   - TOR17C 663, TOR16C 109, TOR23W MOP586_15m 48, TOR24W MOP586_10m 27,
     TOR25S MOP586_15m 22, COR16B 15, TOR23W MOP586_10m 13.
   - Every other record has 0 to 6.
   - Shallow 5 m and 7 m Torrey records have 0 or 1.
   - Steps cluster in time within a record. TOR17C's isolated steps fall in a window of about
     4 days.
10. **Velocity range setting.** Every local `.hdr` (11 heads, 2016 to 2025) reads
    "Nominal velocity range 4.00 m/s" and "Wrap mode OFF". The header gives no beam ambiguity
    velocity.

## Not known

- **The theoretical beam ambiguity velocity for the 4 m/s setting.** The header does not state
  it, and I could not reach Nortek's article on nominal versus horizontal and vertical range
  (support.nortekgroup.com returned HTTP 403). The 1.508 m/s step is an empirical value, not a
  derived one. The required "twice Va from the header or Nortek documentation" check is
  therefore **not done**.
- **Whether the step size scales with sound speed.** It should, if it is a Doppler-phase
  quantity. The spread (interquartile range 0.038 m/s, about 2.5%) leaves room for c to vary by
  about 1% between 1,500 m/s and 1,520 m/s. This was not tested.
- **How many run-type offsets exist outside TOR17C.** Only TOR17C's raw data were scanned for
  runs. The catalog count in item 9 counts isolated steps only.
- **TOR17C L1 sub-cluster.** 54 TOR17C L1 jumps of 2.0 m/s and 3.4 m/s decompose into about
  ±0.75 m/s on two beams with opposite signs. They lie inside the run window of item 6. A
  neighbor median contaminated by the runs is the likely cause, but this is unchecked.
- **TOR23W MOP586_10m.** 251 non-one-beam jumps fall in the last ~470 hours of the record.
  - In that stretch the valid fraction is 14% to 16% and pressure is erratic (standard
    deviation 4.2 dbar against 0.67 dbar before). One hour has a median horizontal speed of
    3.96 m/s.
  - This looks like an instrument failure that partly passes QC, a separate issue from the
    steps.
  - Its effect on L2 segments was not checked.
- The effect on L2 to L4 and on Paper 1's Bailard moments was not computed here.
  morphology_ml's "at most about 3.5% of deployment totals" was not re-derived.

## Hypothesized (labeled, with falsifiers)

- **H1. The Vector resolves velocities beyond a short ambiguity interval internally, and the
  steps are wrong choices of the 2π multiple** (step = 2 × Va_lag ≈ 1.51 m/s, so
  Va_lag ≈ 0.754 m/s along the beam).
  - Fits: fixed step, multiples of 1 and 2, true velocity near 0 m/s at the step, high
    correlation, output beyond ±0.754 m/s.
  - Falsified if Nortek documentation gives a single-lag Va for the 4 m/s setting that is
    inconsistent with 0.754 m/s. Also falsified if the step size does not track c (expected
    proportional to c).
- **H2. Run-type offsets (item 6) are the same mechanism, persisting while conditions favor
  the wrong interval.** Falsified if run offsets differ in size from isolated steps by more than
  their spread (about 0.04 m/s).

## Sketch of an L1 unwrap (not implemented; for HLB's decision)

Work in beam space, before tilt correction and before rotation to the buoy frame.

1. **Beams from the recorded frame.**
   - XYZ records: b = T⁻¹·[X;Y;Z], using the head matrix. `read_VEC.m` does not yet parse the
     matrix. It is in the Head Configuration record (0xA5 0x04) and in the `.hdr`. Stamp the
     matrix into L1 provenance.
   - ENU records (LPL, SOL and any others): first invert the onboard rotation with 1 Hz
     heading, pitch and roll. This is approximate, so flag those records.
2. **Step size Δ.** Δ is fixed per record, estimated from that record's own data as the mode of
   one-beam jump sizes. Accept it only within 1.40 m/s to 1.60 m/s; otherwise refuse and report.
   Optionally scale by c/c_ref, if H1's c-scaling is confirmed first.
3. **Correction.** For each beam, take a reference r(j): a running median over 61 samples
   (30 s), longer than most runs. Set k(j) = round((b(j) − r(j))/Δ) and b′ = b − kΔ.
   - Accept a correction only if |b(j) − r(j) − kΔ| < 0.25 m/s.
   - Repeat once, so runs longer than half the window are re-referenced.
   - Flag records where any run exceeds 30 samples. There the reference itself may be offset.
4. **Return to the recorded frame.** Transform back with T, then continue the existing L1
   chain. Store a per-sample `qc.vel_unwrapped` (beam index and k) and per-record counts.

**Synthetic closure test** (fixed before any result):
- Input: a beam series built from a 12 s wave at 0.8 m/s beam amplitude plus 0.02 m/s noise
  plus a 0.1 m/s mean.
- Inject: 200 single steps, 50 double steps, 20 runs of 2 to 10 samples and 3 runs of 100 to
  186 samples, of ±Δ (Δ = 1.508 m/s), on random beams. Transform to XYZ with a real head T.
- Pass if all of the following hold:
  - every injected step is corrected (count shown as "n/n");
  - zero clean samples are changed;
  - the corrected series matches the clean one within 1 mm/s at every sample.

**Break tests** (each must fire once, with an unbroken copy still passing):
- swap two columns of T;
- set Δ to 1.30 m/s;
- flip the sign of Z (the L1 W = −Z convention);
- drop the second pass with a 150-sample run injected.

**Real-data check:** rerun raw TOR17C 2018-03-06/07. The share of high-correlation samples
with |b2| > 0.9 m/s should fall from 7% to 25% per hour to under 0.1%, and hourly median beam
velocities should be unchanged within 0.005 m/s.

---

## Addendum, 2026-11-13 (later): three checks before any unwrap is written

**Status: EXPLORATORY, read-only.** HLB approved these checks ("Yes, run the checks",
2026-11-13, relayed by the deep_transport_map session). Nothing in the repo or on reefbreak was
changed. reefbreak was mounted (`mount | grep /Volumes/group` checked first), and only the
`.hdr` text files of the 22 priority instruments were read from it. The test and detector
criteria were written down before any number was computed (scratch file
`PREREG_checks2_2026-11-13.md`, beside the scripts named above).

### A1. Theoretical step size: the primary sources do not give it

**What the primary sources give.** Two sources were read:
- Nortek, *Comprehensive Manual – Velocimeters*, N3015-030 (2018), local copy at
  `~/Downloads/N3015-030-Comprehensive-Manual-Velocimeters_1118.pdf`.
- Nortek, *System Integrator Manual* (Oct 2017),
  https://assets.nortekgroup.com/software/System-Integrator-Manual_Oct2017.pdf.

What they say:
1. The ambiguity velocity is "the maximum beam velocity which can be measured", with
   `V_amb = c / (4 * f * timeLagInSeconds)`, where the lag "is pulled from the configuration
   information in the *.HDR file" (Comprehensive Manual §5.3.7). The recommended correction is
   in beam coordinates, `newvel = oldvel ± 2*Vamb`.
2. The vertical range is "pretty much the same as the maximum beam velocity", and the horizontal
   range is "~4x the maximum beam velocity" (§1.2). The manual gives no beam or vertical value
   for the Vector at the 4 m/s setting. Its worked examples are for 0.3 m/s only.
3. The weak-spot table lists, for the Vector at 4.00 m/s, boundary distances of **0.03 m and
   0.06 m**. Two distances suggests two pulse lags. The same section says weak spots are set by
   "the spatial separation between the pulse pairs", and positions are "only estimates", good to
   "a centimeter or more".
4. The System Integrator Manual's User Configuration has `CorrThresh` ("correlation threshold
   for resolving ambiguities", offset 458) and `TiLag2` ("transmit pulse length (counts) second
   lag", offset 462).
   - This is primary-source evidence that the Vector configuration includes a two-lag
     ambiguity resolution.
   - The manual does not state the unit of a "count".
5. All 12 local binaries (2016 to 2025, firmware 1.21 to 3.46) carry identical timing words:
   T1 = 2, T2 = 16, T3 = 7, T4 = 44 ("time between pings (counts)"), T5 = 512, CorrThresh = 0,
   TiLag2 = 2.
   - The `.hdr` "System1..5 = 2 16 7 44 512" lines are these same words.
   - The `.hdr` prints no lag in seconds. "Distance between pings 1.01 m" is not the pulse-pair
     lag.

**Verdict.** I could not get the beam ambiguity velocity for the 4 m/s setting from a primary
source. **Whether 2 × Va equals the 1.508 m/s step is not established.**

**Inference (labeled, not a source value).** Reading the weak-spot distance d as half the
pulse-pair separation gives Δt = 2d/c. The longer distance, 0.06 m ± 0.01 m, then gives
2·Va = 1.56 m/s at c = 1,500 m/s, with a range of 1.34 m/s to 1.88 m/s from the stated
precision. That brackets 1.508 m/s but is too coarse to test it. The shorter distance,
0.03 m, gives Va ≈ 1.6 m/s, which is the right size for the coarse lag of a two-lag scheme.

### A2. Sound-speed scaling (the H1 falsifier)

**Pre-set test.**
- Steps with |k| = 1 and size 1.2 m/s to 1.8 m/s.
- Fit s = a + b·c, with prediction b_pred = median(s)/median(c).
- Verdict rules: the 95% CI contains b_pred and excludes 0 means "consistent"; the CI excludes
  b_pred means "rejected"; the CI contains both means "inconclusive".

**Raw data with the instrument's own recorded c** (`.sen` column 10; samples with any beam
correlation under 70% removed, as in L1):

| record | n steps | c sd (m/s) | slope b | 95% half-width | verdict |
|---|---|---|---|---|---|
| TOR16C | 859 | 1.82 | 8.65e-4 | 4.58e-4 | consistent |
| TOR17C | 2,154 | 1.48 | 4.66e-4 | 3.80e-4 | rejected (positive, about half of b_pred) |
| pooled, cluster bootstrap over 4 records | 3,081 | | CI [4.69e-4, 1.89e-3] | | consistent |

- b_pred = 9.98e-4 (median step 1.494 m/s at median c 1,497.8 m/s).
- TOR16D (67 steps) and TOR17A (1 step) have no spread in c, so no slope can be estimated.
- Binned medians rise monotonically: 1.490 m/s at c of 1,495 m/s to 1,500 m/s,
  1.502 m/s at 1,500 m/s to 1,505 m/s, and 1.507 m/s at 1,505 m/s to 1,510 m/s.
- Residual sd is 0.012 m/s to 0.013 m/s.

**L1 beam space, 15 records with exact head matrices**, c from a fit to the instrument's own
c(T):
- The fit is c = −0.0598·T² + 5.1129·T + 1441.464 (m/s), over T = 11.1 °C to 26.1 °C, with
  residual sd 0.50 m/s.
- The pooled cluster-bootstrap CI is [−1.03e-3, 7.24e-3]: **inconclusive**.
- L1 beam-space steps are biased by L1's tilt rotation: TOR24W MOP586_10m (pitch −4.8°)
  gives a median of 1.363 m/s, and TOR16C gives 1.548 m/s in L1 against 1.505 m/s raw. This
  route cannot test a 1% effect.

**Reading.**
- The step grows with c in both records where it can be measured.
- H1's falsifier, "the step does not track c", is not met.
- Strict proportionality is not confirmed: TOR17C fails it by the pre-set rule.
- c spans only about 11 m/s within each record, so the predicted change is about 0.011 m/s,
  the size of the residual spread.
- Season, temperature and wave conditions vary together, so a step-estimate bias that
  depends on flow could also correlate with c. This was not separated.

### A3. Runs across the catalog

**Detector.**
- Beams are computed from L1 as inv(T)·[U, V, −W]/vel_c_factor.
- The reference is a 61-sample (30.5 s) rolling median.
- A sample is a candidate offset when it lies within 0.35 m/s of k·1.508 m/s from the reference.
- A run counts only if an edge jump confirms it.

**Closure and break tests (synthetic runs injected into clean TOR19W beams).**
- Closure: **207/240 injected runs recovered exactly**, against a pre-set bar of 95%, so the
  test **fails**.
  - Runs of 1 sample: 200/200.
  - Runs of 2 to 30 samples: 7/7.
  - Runs of 31 to 186 samples: 0/33, because a run longer than half the median window becomes
    the reference.
  - False runs on the clean record: 0 in 6.0 × 10⁶ beam-samples.
- The pre-set break test (Δ0 = 1.30 m/s) **did not fire** (206/240 recovered). It was a bad
  break: 1.508 − 1.30 = 0.21 m/s sits inside the 0.35 m/s tolerance. It still needs a working
  break test.
- **So the counts below hold for runs of 30 samples or fewer only.**

**Post hoc edge counter (labeled, never break-tested).** It counts consecutive-sample jumps
within 0.35 m/s of ±1.508 m/s on one beam, with the other two beams moving less than 0.35 m/s.
A hidden long run would add 2 edges with no matching detected run.

**Counts.** Head matrix: exact for Torrey 2023 to 2025 and TBR23 (reefbreak `.hdr`) and for
TOR16A/C/D, TOR17A/C and SIO24A (local `.hdr`). Every other record uses the mean of 7 heads.
LPL and SOL are ENU records, so their counts are approximate.

| record | isolated, 13-sample rule | runs (≤ 30 samples) | singles | 2 to 3 | 4 to 10 | longest | ppm of valid samples | edges (post hoc) |
|---|---|---|---|---|---|---|---|---|
| TOR17C MOP591_9m | 663 | 2,411 | 1,913 | 447 | 51 | 8 | 727 | 4,516 |
| TOR16C MOP591_9m | 109 | 883 | 861 | 21 | 1 | 4 | 166 | 1,450 |
| TOR23W MOP586_10m | 13 | 414 | 326 | 69 | 18 | 11 | 70 | 617 |
| TOR24W MOP586_10m | 27 | 192 | 187 | 5 | 0 | 2 | 18 | 484 |
| TOR23W MOP586_15m | 48 | 190 | 186 | 4 | 0 | 2 | 19 | 378 |
| COR16B MOP158_9m | 15 | 107 | 105 | 2 | 0 | 2 | 24 | 272 |
| TOR16D MOP591_9m | 6 | 68 | 59 | 9 | 0 | 2 | 12 | 108 |
| TOR25S MOP586_15m | 22 | 36 | 35 | 1 | 0 | 2 | 3 | 61 |
| TOR16B MOP591_9m | 6 | 25 | 23 | 2 | 0 | 3 | 9 | 236 |
| TOR24S MOP586_10m | 3 | 7 | 7 | 0 | 0 | 1 | 0.6 | 10 |
| TOR24W MOP586_15m | 3 | 4 | 4 | 0 | 0 | 1 | 0.4 | 8 |
| TOR25S MOP586_10m | 2 | 3 | 3 | 0 | 0 | 1 | 0.3 | 6 |
| TOR24W MOP586_7m | 1 | 1 | 1 | 0 | 0 | 1 | 0.1 | 2 |
| TBR23 MOP580_5m | 0 | 1 | 1 | 0 | 0 | 1 | 0.1 | 1 |
| TBR23 MOP586_5m | 1 | 1 | 1 | 0 | 0 | 1 | 0.1 | 2 |
| catalog total (66 records) | 950 | 4,492 | 3,859 | 562 | 70 | 11 | | 8,400 |

Zero runs in all of these:
- TBR23 MOP580_7m and MOP586_7m;
- TOR23W MOP580_5m, MOP580_7m, MOP586_5m and MOP586_7m;
- TOR24S MOP580_7m, MOP586_5m and MOP586_7m.

Every other record not in the table has 0 to 41 runs. The full table is `catalog_runs.csv` in
the scratch folder.

**Known from A3.**
- **The 13-sample isolated rule undercounts by about 4.7 times** (950 against 4,492 runs). It
  does so outside TOR17C too: TOR24W MOP586_10m 27 against 192, TOR23W MOP586_15m 48 against
  190, TOR25S MOP586_15m 22 against 36.
  - The main cause is QC gaps, not run length. At TOR24W MOP586_10m, 158 of 187 single steps
    have a NaN within ±6 samples, and the rule drops those.
- **Runs in L1-valid data are short**: longest 11 samples (TOR23W MOP586_10m), 8 samples at
  TOR17C. The raw TOR17C runs of up to 186 samples are mostly removed by the 70% correlation
  gate (item 6 above).
- **Every TOR23W MOP586_10m step (392 of 392 single steps) falls in its failure stretch**
  (L1 sample 7.9 × 10⁶ onward). None falls in an L2 segment with segValid_vel = 1.
- The Paper 1 records (TBR23) have 0 or 1 run each. Shallow 5 m and 7 m Torrey records have 0.
- Edges and runs agree where the head matrix is exact. Edges are at or below 2 × runs at
  TOR17C (4,516 against 4,822), TOR16C (1,450 against 1,766) and TOR23W MOP586_15m (378 against
  380). This is post hoc evidence that few long runs are hidden there.
- Edges exceed 2 × runs at three records:
  - TOR16B: 236 against 50, mean head matrix;
  - TOR24W MOP586_10m: 484 against 384, exact head but 4.8° pitch;
  - COR16B: 272 against 214, mean head matrix.
  These excess edges are unexplained.

### A4. TOR23W MOP586_10m failure stretch in L2

- The stretch, L1 sample ≥ 7.9 × 10⁶, holds **472 L2 segments**. Of these, **43 have
  segValid_vel = 1** (0 have segValid = 1).
- Before the stretch, 1,088 of 1,097 segments have segValid_vel = 1.
- In the 43 segments:
  - finite fraction 0.90 to 0.98;
  - median horizontal speed 0.07 m/s to 0.22 m/s;
  - maximum 0.35 m/s to 1.37 m/s;
  - pressure erratic (within-segment sd up to 5.2 dbar, or missing).
- The hour with a 3.96 m/s median speed is not among them.
- If morphology_ml step 2 reads segValid_vel, these 43 hours of velocity reach it from an
  instrument whose pressure had failed. Whether that velocity is trustworthy is not known.

### Ledger for this addendum

**Known**
- Nortek's primary sources give the formula and confirm two-lag ambiguity resolution fields
  (`CorrThresh`, `TiLag2`). They give no Va for the 4 m/s Vector setting.
- In raw data, the step grows with the instrument's c in both testable records. Strict
  proportionality fails at TOR17C.
- The isolated rule undercounts steps by about 4.7 times, mostly next to QC gaps.
- L1-valid runs last 11 samples or fewer.
- TBR23 and shallow Torrey records are essentially clean.
- TOR23W MOP586_10m: 43 velocity-valid L2 hours in its failure stretch.

**Not known**
- The pulse lag in seconds (the unit of a "count"), and so Va.
- Whether the c-slope shortfall at TOR17C is real or bias in the step estimate.
- Runs longer than 30 samples in L1, if any. The detector cannot see them, and the edge counter
  is not break-tested.
- The cause of the excess edges at TOR16B, TOR24W MOP586_10m and COR16B.

**Hypothesized**
- H1 is unchanged and not falsified: a wrong ambiguity branch in a two-lag scheme, with
  step = 2·Va(long lag). Sharpened falsifier: the step should not depend on the head matrix
  used. Re-estimating TOR16C and TOR17C steps in raw beam space with each other's matrices
  should move them by under 0.01 m/s if the step is a property of the firmware rather than of
  the head geometry.

### Consequences for the unwrap sketch (for HLB)

- Take Δ per record from that record's raw beam data, not from L1 beam space. L1's tilt
  rotation biases L1-space step estimates by up to about 10%.
- A 61-sample reference is enough for L1-valid runs (11 samples or fewer). The raw stage needs
  a second pass, or an edge-pairing rule, for runs over 30 samples.
- Correct steps next to QC gaps too. Most steps are there.
- The break test must use a Δ outside the tolerance, for example 1.0 m/s, or a swapped matrix
  column.

### Side finding, not acted on

TOR24W MOP586_15m: `config/TOR24W_config.m` gives S/N 16737, but the raw `.hdr` in
`Torrey20241125-20250220/MOP586-15m16737/` reads "Serial number VEC17047" (head VEC 5728). The
same config gives 16737 to MOP586_10m, whose `.hdr` does read VEC16737. Per
`PUV_Pipeline/CLAUDE.md`, a config value that disagrees with the source document should be
checked against the deployment notes.
