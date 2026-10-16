# Audit: legacy_pipeline_defects.tex

Audited 2026-10-15. Status values as in `audit_compile_sections.md`.

Decision: **kept as a current reference with a status note.** Its job (which
legacy products are safe to reuse) has not changed, and every tabulated number
was reproduced from the saved result. Factual slips were corrected in place.

Reproduction: all statistics recomputed on 2026-10-15 from
`outputs/validation/legacy_defect_isolation.mat` (saved 2026-07-27 17:41) with a
scratch script using the same binning as `validation/archive/legacy_defect_isolation.m`.

| claim | location | status | evidence | action |
|---|---|---|---|---|
| 3,713 segments, 10 records | abstract, §2 | current | n = 3713, 10 unique records | kept |
| 5.5–11.7 m depth | abstract | current as record medians (segments span 4.3–12.9 m) | per-record medians 5.5…11.7 | labeled "record-median" |
| five sites | abstract, §7 | **wrong** | records at Torrey (incl. MOP591 offshore), Imperial Beach, Coronado, SIO Pier = 4 | corrected |
| Hs to 4.7 m | abstract | **wrong** for the sample (max sampled 4.59 m); TOR15B record max 4.67 m (July L2) / 4.66 m (catalog 2026-10-14.1) | mat; current L2 | corrected |
| Five records added; lists four | §2 | incomplete (COR16B omitted) | script `cases` | COR16B added (4.19 m max verified; 24.5% velocity NaN verified in current L1) |
| D1 legacy: Hanning 50% overlap auto, Hamming zero-overlap nfft 2400 cross, "changed from 7200. Why?" | §1 | current | legacy repository beachpeeps/PUV_Processing, Level2_QC/calculate_fft2.m:5,11,18; cospec.m:13–14 | kept |
| D3: calculate_fft2.m:11, cospec.m:22 NaN → 0 | §1 | current | same files | kept |
| D4: cap Kp² 10 vs zero Kp<0.1 | §1 | current (pipeline side: KpMin 0.1) | PUV_L2_spectral.m:67 | kept |
| Design: Tp centroid vs argmax "of S_eta" | §1 | **wrong detail**: the script evaluates both on the multitaper pressure spectrum Spp | legacy_defect_isolation.m `tp_both(f_n, Spp_n, ...)` | corrected |
| Table D1 (5 rows: medians, IQRs, p95) | §3 | current (all 15 values reproduce to stated precision) | recomputation | kept |
| Hs-binned table (6 × 4) | §3 | current (one value 8.63 vs 8.62 recomputed; rounding) | recomputation | kept |
| Spread dependence 1.35° → 2.79° | §3 | current | spread bins 0–15: 1.35, 20–25: 2.79 | kept |
| D3: essentially every surviving segment < 1% gap | §4 | current (3,708/3,713) | recomputation | made exact |
| D3: median 0, IQR to +0.19, ρ −0.06, n 1152 | §4 | current; p = 0.038 omitted | recomputation | p added, "does not predict" softened to "barely predicts" |
| TOR19W 8.8% velocity NaN, 2e-5 pressure; COR16B 24% | §4 | current | current L1: 8.85%, 1.66e-5; 24.47% | kept |
| D4 depth table | §5 | current | 0.000/0.000/0.005/0.015 | kept |
| Band limit 2.9% median, 7.8% Tp<8, 2.5% Tp>16 | §6 | current | −0.029, −0.0778, −0.0246 | kept |
| Tp centroid −2.73 s, IQR −4.29 to −1.47, p95 7.11 | §6 | current | recomputation | kept |
| No valid segment has pressure gap > 1% | §7 | **wrong** | 5 segments > 1%, max 0.408 | corrected |
| Reproduce with `validation/legacy_defect_isolation.m` | footer | **stale path** | moved to validation/archive/ on 2026-07-30 (44c27fd); from there `pipeRoot` resolves to validation/ | path corrected, run caveat added |
| Legacy source path | footer | current, relative to Research/ (outside repo) | directory exists | made explicit |
| Input data are current | (implicit) | stale | computed on 2026-07-27 L1/L2; catalog rebuilt since | status note; not rerun |
| RUBY22/MOP579_6m status | (implicit) | stale | shared/excluded_records.m | noted (166 segments) |
| "behaviour", `---` | §1, §4 | style | | US spelling; recast |

## Counts

- Claims checked: 25.
- Stale: 4. Wrong: 5 (sites, max Hs, centroid spectrum, gap >1%, record list
  incomplete).
- Fixed in text: 11 (incl. style).
- Flagged, not fixed: 1 (results not rerun on 2026-10-14.1).
- Pass 2 (2026-10-15): the archived script now finds the repository root by
  walking up to `startup_puv.m`; the root-finding block was checked to resolve to
  the repository from `validation/archive/` and to raise its error from a folder
  with no `startup_puv.m` above it. The full script was not run (it writes into
  `outputs/validation/`).
