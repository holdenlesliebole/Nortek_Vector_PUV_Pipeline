# Audit: compile_sections.tex (+ methods_L1_L2.tex, results_validation.tex)

Audited 2026-10-15 against the code at branch `sediment-module-corrections-20260817`
(HEAD 81d1905, plus uncommitted work by another session) and catalog 2026-10-14.1.
Status values: **current**, **stale** (was true, no longer), **wrong** (was never
true, or contradicts the code), **unverifiable** (no artifact in reach to check).
"Action" says what the 2026-10-15 revision did.

Decision on structure: the Methods were **updated to the current method** with a
boxed "Changed 2026-10" / "Corrected 2026-10" note at each change. The Results were
**marked historical**, not recomputed: they record analyses on a catalog that has
since been rebuilt, and recomputing them is the paper repository's job (its
reconciliation was in progress on 2026-10-15). Retracted passages stay in place
inside visible boxes, because they are the record of what was claimed.

## compile_sections.tex (wrapper)

| claim | location | status | evidence | action |
|---|---|---|---|---|
| Header comment: "L1 QC description predates the 2026-07 per-channel QC rework" | top comment | stale (now fixed) | methods rewritten | comment replaced with current status |
| siunitx stub fallback; `\citep`/`\citet` stubs print keys | preamble | wrong behavior: `\citep[e.g.,][]{...}` breaks the stub and prints garbage | results_validation.tex old lines 203, 351 | stubs removed; siunitx loaded directly; all citations written as author-year text or flagged keys |
| Title "PUV Pipeline --- Methods..." | `\title` | em dash | | recast with colon |
| Date "April 2026" | `\date` | stale | | "Draft of April 2026; methods updated 15 October 2026" |
| Figures from `../outputs/validation/` | `\graphicspath` | current, but outputs/ is gitignored, so a fresh clone cannot build | .gitignore | stated in header comment |
| No reader orientation | | missing | | added "How to read this document" section with what is current, what is historical, what to read next |

## methods_L1_L2.tex

| claim | old line | status | evidence | action |
|---|---|---|---|---|
| Instruments at nominal depths 5–7 m, two positions per transect | 14–15 | stale (TBR23 only) | registry: 72 configured records, depth_nominal 5.0–30.0 m, median 7.5 | replaced with catalog values |
| z_s typically 0.75–0.77 m | 18 | stale (TBR23 only) | registry: doffp 0.38–1.09 m | replaced |
| Raw .dat/.sen/.hdr merged into continuous series | 22–23 | stale | `read_VEC.m`; PUV_raw_process.m:150–160 (per-burst gap scan) | added .VEC path, one-burst-per-file |
| Linear clock drift | 23–24 | current | PUV_raw_process.m:88–95 | kept; added clockOffsetHours (configs: Coronado/Cardiff +8; TorreyOffshore map 7/8/0) |
| Battery cutoff at gaps > 1 s | 25–28 | current, incomplete | PUV_raw_process.m:109–113 (`cutoffGapSec`, 60 s in 3 configs) | added |
| QC: pitch/roll > ±5° removed | 31 | **wrong** for current code | l1_qc_opts.m (tiltStdMax 2, tiltAbsMax 30); no 5° test in puv_channel_qc.m | replaced, Changed note |
| Pressure outside [P̄/2, 2P̄], P̄ = deployment median | 31–33 | stale | PUV_raw_process.m:411–442 (first 10% of record, ≥1000 samples, P>0.5 dbar) | replaced |
| Correlation < 70% | 33–34 | current | l1_qc_opts.m corrMin 70 | kept |
| Flagged samples set to NaN (row-level) | 34 | stale | puv_channel_qc.m per-channel masks | replaced |
| Tilt variability: 60-s window, 2°, abs cap 30° | 36–40 | current | l1_qc_opts.m tiltWindow 120, tiltStdMax 2, tiltAbsMax 30 | kept |
| Tilt rotation v = R_roll R_pitch v_raw | 46–50 | **wrong** (order) | PUV_raw_process.m:676–678 components equal R_pitch·R_roll; code comment at :631 repeats the wrong order | equation corrected, Corrected note; code comment flagged to coordinator |
| Tilt correction applied always | 41–44 | incomplete | PUV_raw_process.m:657 (only if median tilt > 1°) | added |
| Buoy frame +x W, +y N, +z up, left-handed | 71–72 | current | W×N = down | kept |
| IGRF-13 | 74 | stale | PUV_raw_process.m:695–699 (epoch 14 first, fallback 13 capped) | updated |
| Heading "from deployment notes" | 73 | stale | 2026-10-07 heading rule (compass median unless drift) | updated; disputed-heading list cited |
| ENU records | n/a | missing | enu_to_buoy_frame.m, CHANGELOG 2026-10-07 | added |
| 1-hour, 7200 samples | 82 | current | PUV_L2_spectral.m:64 | kept; added UTC top-of-hour (:94–117) |
| 1.87× noise floor | 87 | current | √(7200/2048)=1.875 | kept |
| Within-hour stationarity audit confirmed | 88–91 | unverifiable | no audit artifact in repo | flagged in note |
| >10% NaN segments discarded | 91–92 | stale | segValid_vel / segValid_p (PUV_L2_spectral.m:361–362) | updated |
| Gaps filled by linear interpolation | 93–94 | stale | 'EndValues','nearest' (:375, :407, :466–469; CHANGELOG 2026-10-09) | updated with impact numbers from catalog_changes |
| Shore-normal from CDIP THREDDS | 95–97 | incomplete | instr.shorenormal precedence (README) | updated |
| Depth formula, ρ=1025, g=9.81 | 99–103 | current | PUV_L2_spectral.m:68–69, 459–461 | kept |
| MTM NW=4, **K=7**, **2K=14 dof** | 112–114 | **wrong** | psd_multitaper.m:33 `K = sum(V > 0.99)`; dpss(7200,4) eigenvalues → K=6 (run 2026-10-15) | corrected to K=6, 12 dof, Corrected note |
| Δf ≈ 2.78e-4 Hz | 115–116 | current | fs/7200 | kept; added resolution bandwidth 2NW/T = 2.2e-3 Hz |
| MTM bandwidth comparable to Welch 256 | 120–124 | wrong | Welch 256 bins 7.8e-3 Hz vs MTM 2.2e-3 Hz bandwidth | replaced |
| Kp = cosh(kz_s)/cosh(kH), Newton, Kp<0.1 zeroed, fCut | 128–140 | current | pressure_correction_linear.m:84; get_wavenumber.m:4; KpMin 0.1 | kept |
| Hs over SS and IG bands | 144–147 | incomplete | compute_bulk_params.m:51–53 (also total 0.004–0.25) | added total |
| Tp argmax in SS band | 147–149 | current | compute_bulk_params.m:58–61 | kept |
| Tm02 = sqrt(m0/m2) | 150 | current, band unstated | :68–70 (total band) | band stated |
| Mean direction from a1,b1 | 150–152 | current, weighting unstated | :81–90 (S_eta-weighted; a1 formed with S_eta in denominator, see flag) | weighting stated; flagged |
| Energy flux ρg∫cg S df | 153–155 | current | :101 (total band) | kept |
| Bed velocity factor cosh(kH)/cosh[k(H−z_s)] | 159–163 | **wrong** | bed_velocity_ifft.m:6–9, 30–34, 68 (1/cosh(k z_s); header says the old form was wrong) | corrected, Corrected note |
| Swart (1974) | 167 | current | PUV_L2_spectral.m:636–645 | kept |
| ks = 2.5 D50, D50 = 0.25 mm | 168–170 | **wrong** | PUV_L2_spectral.m:297–325 (2.5·D84 from site_grain_size, else legacy 10·D50); bed_stress.m:33 | corrected; grain tally 19/4/42 from README |
| Reynolds stress, TKE, Sk, As Hilbert | 170–177 | current | compute_reynolds_stress, compute_velocity_moments | kept |
| MOP validation method (17-min interpolated, 4 hypotheses incl. Qp) | 179–219 | stale/historical; H4 method retracted | validation/archive/README.md | marked Historical method |
| L3 bands IG/swell/sea | 225–228 | current | PUV_L3_bands.m:32–34 | kept |
| "each 17-minute segment" | 229 | stale | segLen 7200 | 1-hour |
| Storm thresholds "configurable" 1.5 m, 6 h, 12 h, 7 days | 234–238 | thresholds current; "configurable" wrong | PUV_L3_storms.m:37–39 hardcoded; :138–139 | wording fixed |
| Fb over SS band | 246–248 | current | PUV_L3_transport.m:185 | kept |
| Shields, Soulsby–Whitehouse, mobilization | 248–252 | current | :138–191 | kept |
| Rouse P = ws/(κu*) (stress unstated) | 253–255 | stale | :74–96, :207–209 (tau_m since 2026-08-13) | updated; ws F&C C1 20 C2 1.1, viscosity, per-fraction added |
| t_tide on u+iv | 259–262 | current | PUV_L3_currents.m | kept; seeding and span added |
| NOAA 9410230 | 262–264 | current as of 10-14; changing (tideStation in flight) | PUV_L3_currents.m:67 (opts.tideStation, uncommitted) | noted as in flight |
| R = 0.995 vs 0.987 for TBR23 | 266 | unverifiable | no artifact found | kept, labeled TBR23/April |
| Clocks confirmed UTC, lag 0 | 266–268 | stale as a catalog statement | CLAUDE.md, audit_clock_lag.m: filename-clock records were local | restricted to TBR23, filename clocks noted |
| Mean-flow method: 38 instruments, 17-min + 1-hour | 272–362 | historical; 17-min not rerunnable | 17-min archive deleted 2026-07-28 | marked Historical method |
| `---` em dashes | 16, 276–277 | style | | recast |

## results_validation.tex

All numbers here are April–July 2026 results; the whole section was marked
historical with a status box. Rows below list what was checked or flagged.

| claim | old line | status | evidence | action |
|---|---|---|---|---|
| 33 of 40 instruments processed | 12–14 | stale | catalog 65 of 72 (pipeline_levels.md) | covered by historical box |
| MOP580 5m low agreement attributed to kelp fouling | 19–22 | Hs part unaffected; see below | | kept |
| Excess at swell peak; not from transfer function | 31–49 | **superseded** (grid artifact) | findings_resolution_artifact_2026-07-24.md | Superseded box |
| Hypothesis values (ρ 0.332, ν 1.000, 1.338, bic −0.008/+0.285, σ1 1.156, p 2.6e-6, 0.913, 0.758, 0.288, 0.149, 0.30, 0.54) | 68–118 | match 2026-07-27 findings doc; 6 moved on 07-28 refresh; none recomputed on 2026-10-14.1 | paper repository: findings_hypothesis_elimination_2026-07-27.md; findings_refresh_2026-07-28.md | box lists the 07-28 values (quoted from the refresh doc, not recomputed) |
| Matched-grid Qp 1.008 over 62 records, IQR 0.980–1.039, legacy 1.203 | 221–226 | unverifiable here (refresh doc gives 1.009) | refresh doc | kept |
| Peak broadening: Qp 1.88 vs 1.75, bandwidth 16.7%, R=0.44 and interpretation | 185–205 | **retracted 2026-07-24**; retraction existed only as a LaTeX comment, invisible in the PDF | old lines 120–183 comment | visible Retracted box |
| Ruby2D: legacy single periodogram Δf 2.78e-4 | 245–247 | consistent with archived L2 (Tp at 1200/1800/3600 s = first bins of 2.78e-4 grid); current legacy source uses nfft 2400 for auto and cross | legacy repository beachpeeps/PUV_Processing, Level2_QC/vector_wave_stats_hanning.m:37–39, cospec.m:14 | note added |
| Ruby2D table values | 269–272 | unverifiable from saved result (ruby2d_582_6m_compare.mat holds only summary structs, not inspected field by field) | outputs/validation/Ruby2D/ | kept as April record |
| "Prior Ruby2D statistics do not require revision" | 324 | overstated for spread and b2 | legacy_pipeline_defects.tex (17° p95 band-averaged spread; b2 p95 0.326) | scoped to Hs, Tp, direction in note |
| Δf 0.000976 for new pipeline | 285 | stale (17-min) | | covered by Ruby2D box |
| SIO: "distinct from universal peak broadening" | 358–362 | depends on retracted result | | box added |
| SIO citations `munk1948`, `shepard1950`; `rogers2002`, `booij1999` | 203, 351 | unverifiable (keys only, no bibliography) | no .bib | rendered as flagged keys, not guessed references |
| L3 energy flux closure 1.0000 for 33 instruments | 373–375 | stale scope | | historical box |
| Rouse median P = 2.8–6.0 | 397–398 | **stale** (old stress) | pipeline_levels.md L3c (4.8 → 41.5 at MOP580 5m) | L3 box |
| Shields with D50 0.25 mm | 392–395 | stale for TBR23 | site_grain_size | L3 box |
| Tidal R > 0.99 "confirming the UTC clock convention" | 408–411 | stale as a catalog statement | filename-clock records local time | L3 box |
| TBR23 recovery section | 413–471 | historical; moved to the TBR23 paper repository | | box |
| MOP580 5m negative skewness (92%) and ū anti-correlation attributed to kelp fouling | 468–471, 537–541 | **doubtful**: the record's heading was 180° wrong until 2026-05-14, which by itself flips the sign of u | maintainer's local task log, 2026-05-14 entry (heading 270.74° corrected to 90.74°) | box on TBR23 section; flagged |
| Mean-flow results (33/38 instruments, sign fractions 66–81%) | 473–576 | predate the 2026-05-14 heading fixes (TOR24S/MOP586_7m included with reversed sign) | local mean-flow planning note, not in the repository (run of 2026-05-05) | box |
| Undefined refs tab:validation, tab:spectral_ratio, tab:hypotheses, tab:mean_flow_headline | 16, 36, 66, 489 | wrong (tables never drafted) | | replaced with "(table planned, never drafted)" |
| `---` em dashes, "organised" | 46–47, 82, 329, 338, 557; 74 | style | | recast; US spelling |

## Counts (methods + results + wrapper)

- Claims checked: 78 (wrapper 6, methods 44, results 28).
- Stale: 32. Wrong: 9 (taper count/dof, bed-velocity factor, ks, tilt rotation
  order, ±5° QC, Welch-bandwidth comparison, storm "configurable", citation stubs,
  undefined table refs). Retracted-but-invisible: 1 (peak broadening).
- Fixed in text: 41 (all wrong items, the methods stale items, visible retraction
  and historical boxes on results).
- Flagged, not fixed (unverifiable or outside the edit scope): 9 (stationarity
  audit; TBR23 R values; Ruby2D table; matched Qp 1.008; four citation keys; the
  kelp-vs-heading attribution of MOP580 5m; mean-direction weighting in code; tilt
  comment in code).
