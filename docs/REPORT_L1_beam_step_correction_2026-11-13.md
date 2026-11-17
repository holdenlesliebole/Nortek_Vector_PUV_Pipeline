# Report to HLB: L1 beam-step correction (2026-11-13)

**Status: EXPLORATORY. Built and tested in the worktree `../PUV_Pipeline_beamstep`, branch
`beam-step-correction-20261113`, cut from `origin/main` f8c6b5c (published catalog 2026-10-16.1;
PUV_Pipeline has no `master`). Nothing committed, nothing merged, no catalog output rebuilt,
nothing written to `/Volumes/group`.** Read from the server: `.hdr` files,
`DeploymentNotes2024-2025.xls`, a `du` of the raw folder, and (approved by HLB) the `.VEC` and
`.hdr` of 4 records, copied to a local cache. The rule, its parameters, every test criterion and the
dated amendment log are in `docs/SPEC_L1_beam_step_correction_2026-11-13.md`.

## 1. What changed

- **Where:** a new block in `L1_raw_to_qc/PUV_raw_process.m`, after per-channel QC and the
  leading trim, before the sound-speed factor, the tilt rotation and the XYZ `W = −W` flip. There
  the velocity is as recorded, so a step lies exactly along a column of the head matrix and has
  its recorded size.
- **Head matrix:** new `vector_head_matrix.m` reads T from every `.hdr` and from the binary's
  Head Configuration record (int16 ÷ 4096) and refuses if they disagree by more than 1e-4.
  `read_VEC.m` now returns `meta.headT`. T is read from the record's own files, never from the
  config serial number.
- **Rule:** new `vector_beam_step_correct.m`.
  - Edges are one-sample beam changes, detrended by the local slope, that sit within 0.35 m/s of
    k·Δ on all three beams.
  - Pieces are split at gaps the edge test cannot cross. Within a piece the absolute level is
    anchored by the moving median of the edge-unwrapped beam.
  - A run is corrected only if both of its edges join adjacent samples. Otherwise it must pass a
    level check against a local quadratic through clean samples on both sides.
  - Δ is estimated per record from its own recorded-frame edges and refused outside 1.40 m/s to
    1.60 m/s.
- **Stored in L1:**
  - `qc.vel_beamstep_k` (N × 3 int8: offset removed per beam, in units of Δ);
  - `qc.vel_beamstep_unconfirmed` (step-like runs left unchanged);
  - `qc.beamstep` (status, Δ, n edges, IQR, counts, options);
  - `head.T` and `head.info`.
  - `valid_vel` is not changed.
- **Not corrected:** ENU records (LPL, SOL) are stamped `excluded_ENU`; their beam inversion would
  need the onboard rotation undone, and that convention is unverified. Decimated records are
  stamped `excluded_decimated` (none in the catalog today).
- **Tests:** `L1_raw_to_qc/test_vector_beam_step.m` is self-contained (synthetic flow). It is
  **not** registered in `run_all_tests`, because one of its checks fails (section 2).
  `validation/validate_beam_step_20261113.m` runs the real-data tests.
- `CHANGELOG.md` has an Unreleased entry.

## 2. Test results (criteria fixed before running; full output in the spec, section 10)

| test | result |
|---|---|
| T1 head matrix, `.hdr` vs binary within 1e-4 | 8/8 records PASS |
| T2a calm base (TOR24S 5 m, 3 days), Δ given | 420/420 exact, 0 false flags, untouched samples bitwise equal, max error 8.9e-16 m/s: PASS |
| T2b calm base, Δ estimated | Δ̂ = 1.5082 m/s (injected 1.508 m/s), 420/420, max error 1.1e-3 m/s: PASS |
| T2a storm base (COR16B 9 m, 3 days, peak 2.86 m/s), Δ given | 419/420: S1 to S5 and S7 n/n, S6 59/60, 1 silently missed, 0 false flags, 0 wrong: **FAIL** |
| T3 storm base × 1.0, × 1.5, × 2.0, no steps | 0, 0 and 0 corrected samples: PASS |
| T4 real records with no steps (full L1 builds) | TOR24S MOP586_5m, TOR24S MOP586_7m, TOR23W MOP586_5m, TOR23W MOP586_7m: 0 corrected each, 4/4 PASS (TOR23W blind; its 5 m storm record had 517 flow-made candidates, all rejected) |
| T5 breaks: T columns swapped, Δ = 1.0 m/s, Z sign flipped, T rows swapped, 1.30 m/s steps | 5/5 fire, unbroken copy passes: PASS |
| T6.1 TOR25S 15 m 6.86 m/s sample corrected on two beams | corrected, beams 1 and 3, k = +1 and −1, 2025-04-23 14:38:06 UTC, 6.86 → 0.04 m/s: PASS |
| T6.2 TOR17C dense-flicker hours, share with \|b₂\| > 0.9 m/s below 0.1% each hour | 7/14 hours: **FAIL** (19.0% → 0.000% at 00:00; 25.0% → 7.8% at 09:00, when only 32% of samples were valid) |
| T6.2 hourly median beam velocity moves < 0.005 m/s | max 0.0119 m/s: **FAIL** (removing ~20% of offset samples on one side moves a median by about this much) |
| self-contained C1, C2, C4, C5 (dense flicker, post hoc) and B1 to B5 | 10/10 PASS (C5: 2,483/2,483 exact) |
| self-contained C3, synthetic storm peaking ~3.6 m/s | S6 59/60 (1 missed): **FAIL** |
| T7 `run_all_tests` (existing self-contained tests) | 23/23 PASS, 0 skipped. The new `test_vector_beam_step` fails on C3 and is not registered |

**The failures are misses, not wrong corrections.**
- Where the rule cannot decide, it leaves the sample as recorded.
- The storm misses are single valid samples between two short QC gaps, where neither crossing
  passes the edge test and the level check cannot fit across the gaps.
- The TOR17C misses are in hours with 19% to 36% of samples valid.
- No tested case changed a true sample. Across TOR17C, all 4,600 corrected samples end at
  |b| ≤ 0.15 m/s, and none started below 0.75 m/s on the corrected beam.

**The rule changed eight times after test runs** (spec, section 9). One change matters most. The
second version made **wrong corrections** in TOR17C's dense three-level flicker. It took an offset
level as its baseline and moved true samples from 0.01 m/s to −1.5 m/s. The sparse synthetic
injections could not show this; T6.2 on real data did. The current rule anchors the absolute
level on the data instead. A dense-flicker synthetic (C5) was then added as a post hoc check.

## 3. Which records the correction touches, and by how much

Current rule, Δ estimated per record, full L1 inputs built from local raw:

| record | Δ (m/s), n edges | runs corrected | samples | ppm of valid | unconfirmed samples |
|---|---|---|---|---|---|
| TOR17C MOP591_9m | 1.4901, 4,440 | 3,192 | 4,600 | 1,068 | 159 |
| TOR16C MOP591_9m | 1.5055, 1,445 | 1,010 | 1,090 | 199 | 7 |
| COR16B MOP158_9m | 1.5012, 254 | 220 | 240 | 52 | 28 |
| TOR16B MOP591_9m | 1.5054, 197 | 165 | 179 | 59 | 52 |
| TOR16D MOP591_9m | 1.4904, 108 | 85 | 99 | 16 | 0 |
| TOR17A MOP591_9m | 1.5030, 1 | 1 | 1 | 0.2 | 0 |
| SIO24A SIO_6m | 1.5104, 2 | 1 | 1 | 0.1 | 0 |
| TOR16A, TOR24S MOP586_5m, TOR24S MOP586_7m | no steps | 0 | 0 | 0 | 0 |

TOR16B and COR16B now use their own head matrices, read from the binary because they have no
`.hdr`. The diagnosis used a 7-head mean for them.

**TOR25S MOP586_15m and TBR23 MOP586_5m, exact.**
- HLB approved copying their raw `.VEC` and `.hdr` (with TOR23W 5 m and 7 m). Each record was
  built twice with the same code and raw, correction off and on.
- Hourly sums use the catalog L2's `segValid_vel` hours, with morphology_ml's recipe
  (`fill_linear_nearest`, `moments`, `detrend`) unchanged.
- TOR25S 15 m had no tilt rotation (median tilt under 1°). TBR23 5 m had a 3.8° roll rotation,
  applied after the correction as in L1.
- The uncorrected builds reproduce the catalog-L1 moments to 4 decimals. An earlier approximate
  pass on the existing L1 (spec section 10.4) gave the same numbers.

| record | samples corrected | ⟨u\|u\|³⟩ full (m⁴/s⁴·h) | ⟨u\|u\|²⟩ full (m³/s³·h) | ⟨u\|u\|³⟩ detrended (m⁴/s⁴·h) |
|---|---|---|---|---|
| TOR25S MOP586_15m | 36 in 27 h (of 1,566 h) | −0.3196 → −0.7334 (−129.5%) | −1.8734 → −1.9496 (−4.1%) | +0.5174 → +0.0973 (−81.2%) |
| TBR23 MOP586_5m | 1 (2023-06-24 23:23:04 UTC, 4.09 → 0.08 m/s) | +0.5241 → +0.5590 (+6.7%) | +0.3438 → +0.3525 (+2.5%) | +1.1351 → +1.1696 (+3.0%) |

- morphology_ml's mask-and-fill estimate was TOR25S 15 m −129% and TBR23 5 m +6.7%.
- This agreement is **expected, not independent**: both methods remove the same samples, and
  the corrected values (|u_h| 0.01 m/s to 0.14 m/s) sit close to what a linear fill gives.
- At TOR25S 15 m the corrected sample set matches morphology_ml's 36 masked samples.
- TBR23's Δ came from only 2 edges (1.5315 m/s). The ⟨u|u|³⟩ change is set by the removed
  4 m/s sample, not by a few-hundredths error in Δ.
- TOR23W MOP586_5m and MOP586_7m: 0 samples changed, so their summed moments are unchanged
  (⟨u|u|³⟩ full +22.3969 m⁴/s⁴·h and +32.4785 m⁴/s⁴·h).

Records not built here: TOR23W MOP586_10m and MOP586_15m, TOR24W MOP586_10m and MOP586_15m,
TOR25S MOP586_10m, and every other server-only record. From the diagnosis (addendum A3), they
hold 7 to 414 steps each. Their numbers come with the rebuild.

## 4. Flagged, not fixed

**TOR24W MOP586_15m serial.**
- `config/TOR24W_config.m` gives S/N 16737 for both the 10 m and the 15 m instrument.
- The 15 m raw folder is named `MOP586-15m16737`, but its `.hdr` reads instrument VEC17047, head
  VEC 5728. `DeploymentNotes2024-2025.xls`, 'All Data', rows 37 and 39, lists the 15 m MOP586
  Vector as S/N 17047 for 11/25/2024 to 02/20/2025 and for its redeploy.
- The 10 m `.hdr` reads VEC16737, head VEC 5724 (rows 33 and 35, S/N 16737).
- **So the 15 m record should use head VEC 5728**, the same head as TOR25S MOP586_15m. The new
  L1 code reads it from the files, so the correction is unaffected.
- The config's `serialNum` for TOR24W MOP586_15m should change to 17047, with that source on the
  line.

**TOR23W MOP586_10m failure stretch: proposed QC rule, not applied.**
- L2 index 1097 (0-based) is 2023-12-30 15:29 UTC. After it, 472 segments remain: 43 pass
  `segValid_vel` and 0 pass `segValid_p`. A sound-speed reconstruction is applied in 39% of
  them and a static tilt in 12%.
- Before it, L2 Ub(10 m)/Ub(15 m) has a median of 1.37 (5% to 95%: 1.30 to 1.44, 913 paired
  hours). After it L2's Ub is NaN, because pressure has failed.
- morphology_ml's L1-based check (plan section 11.2) puts the ratio at 0.39 in all 26 paired
  hours, none inside the band.
- The per-channel rule cannot see this. Correlation and the finite fraction (0.90 to 0.98) look
  healthy, and the 2026-07-09 channel decoupling deliberately rescued velocity through 25 to
  29 Dec, when the sensor block had also died.
- Proposal:
  1. A documented per-record cutoff in `config/TOR23W_config.m`
     (e.g. `instr.velInvalidFrom = datetime(2023,12,30,15,29,0)`, citing the 11.2 numbers),
     honored in L2's `segValid_vel`. This needs a small L2 code change.
  2. A catalog audit, not a gate: on records with a depth-ladder neighbor, compare hourly
     sea-swell Ub with the neighbor's and list hours outside the record's own 5% to 95% band.
     That would find other cases of this kind before deciding on a general rule.

## 5. What the single L1-to-L4 rebuild would need

These are inputs to HLB's declaration. Nothing below has been run.

- **Code to merge first, in order:**
  1. this branch;
  2. HLB's decision on `tb-period-20261105` and `swart-amplitude-20261111` (the latter contains
     the former).
  - `tb-period-20261105` also edits `PUV_raw_process.m` (47 lines, the time-varying XYZ heading),
    so merging it with this branch conflicts in that file and needs a hand merge and a rerun of
    `test_vector_beam_step` and `test_xyz_heading_rotation`.
  - Also flip TOR24W MOP586_15m's serial (section 4) and decide the TOR23W 10 m rule.
- **Scope:** all 66 L1 records (47 deployments).
  - The ENU records still need rebuilding for the new provenance fields, and `check_prov` will
    SOFT-refuse every L1 file at push until a change entry carries `code_ack`.
  - Then L2, L3, L4 and the 9 L4_xspec for everything. The Bailard moments move wherever a step
    was corrected, and L2 changes whenever its L1 changes.
  - Then the Altimeter_Pipeline L4 rebuild that `NOTES.md` defers. Its six files are stale
    against current PUV L2: 51 rows, by up to 244 times. Rebuild them after PUV L2 so they
    inherit the corrected moments.
- **Raw input:** L1 must read raw for every record. Only 14 records' raw are in `raw_cache/`;
  the rest must be copied from `/Volumes/group/PUV_data/Vector`. Measured 2026-11-13 (`du`, all
  file types): 232.1 GB in that folder, of which `Processed_HLB/` is 99.7 GB and `GoPro_Videos/`
  39.6 GB, leaving about 92.8 GB of raw (including Hawaii20260718_20260915, 2.7 GB). Copying only
  `.VEC` and `.hdr` would be smaller: about 0.45 GB of `.VEC` per 2023 to 2025 Torrey record
  against about 1.0 GB for the whole folder. That would need `instr.rawFormat = 'VEC'` wherever
  ASCII is preferred today, which is itself an ingest change to test first.
- **Output volume (replaced in place locally):** L1 22 GB, L2 18 GB, L3 42 MB, L4 56 GB, L4_xspec
  32 MB, about 96 GB in all, plus the server push of the same. Snapshots are not needed if the
  manifest and server copy serve as the reference (storage rules, section 6).
- **Compute:** L1 took about 1 min per record here, with local raw on SSD. L2 to L4 for the
  catalog ran under `scripts/run_L4_refresh_watchdog.sh` in October and took hours.
- **Checks after the rebuild:**
  - `audit_registry_loads`, `audit_L4_coverage`, `audit_L1_qcopts` (qc.opts is unchanged by this
    branch; the beam-step options live in `qc.beamstep.opts`), `audit_clock_lag`;
  - a per-record table of `qc.beamstep` status, Δ and counts. Any `refused_delta` must be
    explained before the push.
  - Paper 1's TBR23 transport numbers move by about +6.7% in ⟨u|u|³⟩ at north 5 m (section 3).
  - morphology_ml step 2 then reruns from the new L1.

## 6. Open decisions for HLB

1. Accept the rule with its three FAILs as stated (misses, not wrong corrections), or tighten
   further first. The cheapest further gain is the gappy TOR17C hours.
2. Whether unconfirmed samples (`qc.vel_beamstep_unconfirmed`) should also be dropped from
   `valid_vel` at L2. They are step-like runs left as recorded: 159 samples at TOR17C, 52 at
   TOR16B, 28 at COR16B.
3. Delete the 1.7 GB raw cache `~/LocalData/Scripps/Research/PUV_Pipeline/raw_cache_beamstep/`
   and the 4.2 GB of scratch dumps when the rebuild is decided. Both were created for these
   tests; the scratch dumps were not declared before they were created.
4. The two flagged items in section 4.
5. The rebuild bundle and its declared size (section 5).


## 7. Rebuild status (2026-11-16)

HLB's five decisions are implemented and the rebuild is complete locally; nothing is pushed or
committed. Full log with denominators: the spec, sections 11 and 12.

- L1 66/66, L2-L4 66/66, L4_xspec 9/9, Altimeter L4 6/6 (parent stamps 42/42 current).
- TBR23 closure diff: identical field for field except MOP586_5m segment 916 and the record
  median it feeds; bed-stress fields identical everywhere else.
- Audits: registry 51/51, L4 coverage 66/66, L1 qc.opts 66/66, clock lag 19/19.
- Code changes beyond the five decisions, each found by a gate and recorded: the scalar heading
  rotation reverted to the catalog's matrix product (bitwise reproduction); placeholder heads
  skipped (TOR18A); the power-on trim bounded to 10 s (four records it had emptied); a bounded
  declination-refresh gate extension (16 records, plus CAT21A's location fix); the L2-L4 watchdog;
  the Altimeter L4 parent stamp and staleness check.
- Flags for HLB: L3 mobilized fraction near 100% at 9 m after T_b/Swart (e.g. TOR17A 77.1% to
  99.1%); Altimeter `storm_flag` 0 at every site before and after; LPL23 (1 sample) and 6 more
  TOR23W MOP580_7m samples left unflagged; free disk held by Time Machine local snapshots.
