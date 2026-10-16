# Audit: multitaper_writeup.tex

Audited 2026-10-15. Status values as in `audit_compile_sections.md`.

Decision: **marked historical with an up-front status section**, and corrected in
place where a statement was wrong when written (the taper count). The estimator
comparison is a record of the April decision, and its tables come from a run that
cannot be reproduced exactly from the current L1 at 17-minute segments, so the
numbers were not recomputed. Retracted sections are boxed, not deleted.

| claim | old line | status | evidence | action |
|---|---|---|---|---|
| Header comment: points to Guide, "L1 QC predates rework" | 1–4 | irrelevant to this note | | replaced with a status comment |
| `\SI` used without siunitx | 35 | wrong (build error risk) | preamble | siunitx loaded |
| `Section~\ref{sec:mean_flow_validation}` in another document | 32 | wrong (undefined reference) | label lives in methods_L1_L2.tex | removed with the May note |
| Production: 1-hour, full MTM, K=7, ~14 dof | 34–36 | K and dof **wrong** | psd_multitaper.m:33; dpss(7200,4) → K=6 | corrected in status section |
| Welch nfft 256, 50% overlap, Δf 0.0078 Hz | 43–44, 60–62 | current as a description of the baseline | 2/256 | kept |
| Hybrid: K=7, ~105 estimates per bin | 64–68 | **wrong** | K=6; 15 sub-segments × 6 = 90 | corrected with note |
| Full MTM on 2048 samples, K=7, Δf 0.00098, ~24 bins across peak | 70–73 | K wrong; Δf current | fs/2048 = 9.77e-4 | K corrected |
| Parseval within 1% | 79–80 | unverifiable | no artifact | kept |
| Qp definition, Qp=1 white | 86–97 | current | Goda (1970) form | kept |
| Table 1 medians (4795 segments, 17-min) | 103–126 | unverifiable (April run; not reproducible as-is: `scripts/compare_spectral_methods.m` now runs at 1-hour) | script lines 26–31 (segLen default 7200) | kept as April record; status note |
| Z-test ~0.79, "property of the data" | 166–172 | **wrong** (L2 formula bug fixed 2026-06-05) | PIPELINE_NOTES.md "L2 Z-test formula"; catalog L2 TBR23/MOP580_7m median Z 0.986 (1,354 valid 1-hour segments, computed 2026-10-15) | Superseded box |
| Implications for MOP: H4 winner, MOP broadens peak ~24%, H2/H3 ruled out | 174–223 | **retracted** 2026-07-24 / 2026-07-27 | findings_resolution_artifact_2026-07-24.md; findings_hypothesis_elimination_2026-07-27.md (paper repository, not public) | Retracted box; noted that the 1.07 → 1.24 rise with resolution is the artifact's signature |
| Ruby2D setup and table | 225–296 | historical (17-min new side); "no revision" overstated for spread | legacy_pipeline_defects.tex | box; bullet scoped to Hs, Tp, direction |
| Ruby2D Z-test 0.76 vs 1.02, open question | 342–350 | resolved: Z formula bug | PIPELINE_NOTES.md (TBR23 medians 0.91–0.99 after fix) | Resolved box |
| Conclusion: mtm_full default, `opts.spectralMethod` | 354–357 | current | PUV_L2_spectral.m:77 | kept |
| nfft = 2048 | 354 | stale | PUV_L2_spectral.m:182–184 (nfft = segLen = 7200) | box |
| Processing time 0.7 → 2.7 min, 33 instruments | 367–369 | historical | | box |
| Figures 1–4 match the text | 371–412 | **wrong**: PNGs dated 2026-06-07; Z panel medians 0.974/0.979/0.986 match the post-fix catalog value for 1-hour segments, not the April 0.79; ΔTp full = +0.67 ± 2.22 s | outputs/validation/spectral_method_comparison_*.png; L2 check | caption notes added. Regenerating the April 17-min figures would need a scratch copy of the script with opts.segLen = 2048 run on the current L1, and would no longer match the April table either; not done |
| `---` em dashes | 132, 145, 151, 295, 333–334 | style | | recast |

## Counts

- Claims checked: 22.
- Stale: 6. Wrong: 7 (siunitx, cross-document ref, K=7 ×3 locations counted once
  per claim, hybrid 105, Z-test explanation, figures vs text).
  Retracted-but-unmarked: 1 (MOP implications).
- Fixed in text: 14.
- Flagged, not fixed: 3 (Parseval check, Table 1 values, figure regeneration).
