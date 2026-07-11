# Channel-decoupling rerun — TOR23W + TBR23 results (2026-07-10)

L1+L2 re-run for both deployments with the per-channel QC and the San Diego site bound
`Tvalid = [9 26]`, from the local raw cache. Written to `outputs/rerun_2026-07-10/` (parallel
tree; canonical `outputs/` untouched). Scripts: `scripts/rerun_channel_decoupling_2026_07_10.m`,
`scripts/compare_rerun_2026_07_10.m`. Canonical L2 baseline: the 2026-06-05 Z-fixed build.

## 1. Existing results are unchanged

On segments valid in both the old and new pipelines, the wave height is essentially identical:

| deployment | instruments | median ΔHs | p95 |ΔHs| | max |ΔHs| |
|---|---|---|---|---|
| TOR23W | all 6 | **0.0000 m** | ≤ 9 mm | 0.22 m (one boundary segment on 15 m) |
| TBR23 | all 4 | 0.0000 m | ≤ 9 mm | 0.041 m |

Velocity moments on clean segments are bit-identical (max Δskewness = 0). The rare
few-centimetre outliers are individual partial segments where the per-channel QC now keeps a
few more valid pressure samples than the old row-level gate — more data on that segment, not
different data. **Chapter 1's clean summer analysis and Chapter 2's existing analysis stand;
the fix only adds recovered data.**

## 2. What the rerun recovers

Every instrument gains `qc_flag = 3` (recovered) segments. There are two kinds, and which one
depends on which channel had failed:

- **Velocity recovery** (`segValid_vel & ~segValid_p`): velocity moments recovered where the
  pressure sensor died. Only MOP586_10m has these.
- **Wave-forcing recovery** (`segValid_p & ~segValid_vel`): `Hs`, `Tp`, `S_eta` recovered
  where the Doppler failed but pressure survived. Most instruments have these; the recovered
  `Hs` is a clean pressure measurement (the segment is partial, hence `qc_flag = 3`, but the
  `Hs` itself is `Hs_source = 'measured'`).

### TOR23W (Chapter 2 — the storm winter)

| instrument | clean (qc 1) | recovered (qc 3) | fail (qc 4) | recovery type | when |
|---|---|---|---|---|---|
| **MOP586_10m** | 972 | **159** | 438 | **velocity** | 120 h of the 25-29 Dec storm peak |
| MOP580_5m | 1007 | 652 | 0 | wave forcing | 41% storms (`Hs`>1.5 m), med 1.35 m |
| MOP580_7m | 1058 | 503 | 20 | wave forcing | 49% storms, med 1.48 m |
| MOP586_5m | 1094 | 443 | 0 | wave forcing | 48% storms, med 1.47 m |
| MOP586_15m | 1190 | 350 | 0 | wave forcing | 19% storms, med 1.08 m |
| MOP586_7m | 1694 | 3 | 0 | wave forcing | all 3 storms (the healthy survivor) |

### TBR23 (Chapter 1 — the summer recovery)

| instrument | clean (qc 1) | recovered (qc 3) | recovery type | when |
|---|---|---|---|---|
| MOP580_5m | 805 | **867** | wave forcing | all calm (0% storm, med 0.67 m) |
| MOP586_5m | 1429 | 222 | wave forcing | all calm, med 0.44 m |
| MOP586_7m | 1382 | 208 | wave forcing | all calm, med 0.45 m |
| MOP580_7m | 1354 | 148 | wave forcing | all calm, med 0.47 m |

## 3. The headline: MOP586_10m storm-peak transport signal

**25-29 Dec 2023: 120 hourly segments, all 120 now carry recovered velocity moments
(`qc_flag = 3`). The old pipeline had zero valid velocity here.** Recovered velocity skewness
ranges 0.107 to 1.054 (median 0.311) over the peak. This is the entire reason for the work:
the 10 m frame had no valid bursts above `Hs ≈ 2 m`, and Chapter 2's transport-moment analysis
now has the storm peak it was missing. The 438 `qc_flag = 4` segments are the post-30-Dec
period where the instrument was buried and genuinely dead — correctly flagged and excluded.

## 4. Reading the recovery per chapter

**Chapter 2 (TOR23W).** Two distinct gains. (i) The transport signal: 159 recovered velocity
moments at MOP586_10m, including the full Dec storm peak — directly feeds the moment-vs-`Hs`
analysis. (ii) Wave forcing during storms: 350-650 recovered `Hs` segments per frame, ~40-50%
of them during storms, so the wave-forcing record through the two-winter deployment is now far
more complete during the events that move sediment.

**Chapter 1 (TBR23).** All recoveries are pressure-only (`Hs`), all during calm summer
conditions — the Doppler was failing in low-scatterer summer water while pressure stayed
healthy. This makes the summer wave-forcing time series more continuous (MOP580_5m nearly
doubles, 805 → 1672 segments with usable pressure), but it does **not** add velocity moments,
so Chapter 1's velocity-moment / transport analysis is unchanged. The value for Chapter 1 is
forcing-record completeness, not new transport data.

## 5. Provenance and caveats

- Every recovered segment is `qc_flag = 3`. Filter to `qc_flag == 1` for clean-only; include
  `== 3` deliberately.
- The MOP586_10m velocity recoveries carry the sound-speed-rescale scale uncertainty
  (a few percent in velocity, ~2-3% in `⟨u³⟩`); the pressure-only `Hs` recoveries do not (the
  pressure was healthy).
- Canonical `outputs/` is **not yet promoted**. Promotion overwrites the Ch.1/Ch.2 pipeline
  inputs and is the next deliberate step, followed by the L4 rebuild.

---

## 6. Promoted to canonical + L4 rebuilt (end-to-end verified)

Canonical `outputs/L1,L2/{TOR23W,TBR23}` promoted from the rerun (backup at
`outputs/_pre_channeldecoupling_backup_2026-07-10/`). PUV L4 (`L4_TP_*.mat`) rebuilt via the
qc-aware `build_L4_site` (Altimeter_Pipeline `l4-qc-propagation-2026-07`; L4 backup at
`Altimeter_Pipeline/outputs/_L4_backup_2026-07-10/`).

The qc-aware L4 build fired as designed on MOP586_10m: **876 altimeter bursts matched to
failed (buried-instrument) PUV segments dropped as `qc_flag=4`; 318 matched to recovered
segments flagged `qc_flag=3`** (~2 altimeter bursts per hourly PUV segment).

**End-to-end headline — `L4_TP_10m`, 25-29 Dec 2023 storm peak:**

| | bursts in window | with a velocity moment |
|---|---|---|
| OLD L4 | 360 | **20** |
| NEW L4 | 360 | **220** |

An 11× fill of the storm-peak transport signal, now spanning Hs 0.82-3.18 m (skewness 0.11 to
1.05, median 0.32), all `puv_qc_flag=3`. Clean bursts are bit-identical: 7093 matched, max
Δskewness = 0.000, max ΔUb = 1.6e-8. `L4_TP_10m` carries `puv_qc_flag`, `puv_segValid_vel`,
`puv_segValid_p` per burst.

**Chapter 1 (TBR23): no manuscript changes needed.** Every Paper_1 consumer of TBR23 L2 gates
on `segValid` (bit-identical), and the recovered segments carry `segValid=false`, so they are
invisible; the reported valid/total counts, Table PUVstats, Table 7, and Hs figures (which use
the MOP hindcast) all reproduce identically. The recovery is opt-in and Ch.1 does not opt in.
