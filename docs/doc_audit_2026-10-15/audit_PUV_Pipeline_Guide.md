# Audit: PUV_Pipeline_Guide.tex (pass 1 audit; pass 2 revision)

Audited 2026-10-15 against the code and docs as of that morning. A change set
(provenance in the drivers, a `knownFailed` registry flag, per-deployment
`tideStation`, fatal missing t_tide) was landing at the time; rows that touch it
are marked **in flight** and must be rechecked in pass 2 against the final state.
Status values as in `audit_compile_sections.md`.

| # | claim | line | status | evidence | proposed fix (pass 2) |
|---|---|---|---|---|---|
| 1 | "Revised July 2026" | 37 | stale | README: Guide last rebuilt 2026-07-24 | date and a status paragraph |
| 2 | Five processing levels | 45 | current (L5 planned) | pipeline_levels.md | keep |
| 3 | Catalog 26 deployments, 45 instrument-records, 2015 Cardiff onward | 69–70 | **stale** | 46 deployments, 65 records, 2014–2026 (README) | update; cite catalog version 2026-10-14.1 |
| 4 | L4 table row omits boundwave, reflection_free, moments, xspec | 84–85 | stale | pipeline_levels.md L4 | add |
| 5 | MATLAB R2023b or newer | 103 | **wrong/unsupported** | README: R2025a tested, earlier untested | change |
| 6 | Signal Processing + Aerospace required; Mapping not | 103–109 | current | README requirements | keep; add Parallel (optional) |
| 7 | "t_tide must be on the path" | 106 | stale/**in flight** | README: 12 external files (t_tide 1.3, lab toolbox getztide2/read_MOPline2, helpers); missing t_tide becomes fatal | rewrite from final code |
| 8 | Internet only for CDIP shore-normal; falls back to buoy coords | 110–111 | stale | README: also CDIP ref station, NOAA tides; catalog build refuses silent CDIP fallback (CHANGELOG 10-07) | rewrite |
| 9 | `cfg = reg('TBR23')();` | 128 | **wrong** (MATLAB does not allow call chaining on a returned handle) | README uses `f = reg('TBR23'); cfg = f();` | fix |
| 10 | Drivers use raw_cache/ automatically | 126 | current for L1 | PUV_L1_driver.m:31 | keep |
| 11 | Output file name `{label}_L{n}.mat` | 142 | partly wrong | L1 is `{label}_processed.mat` | fix |
| 12 | run_all skips existing outputs | 139–141 | current; incomplete | README: drivers end with an error naming failures; 7 known field failures always reported (**in flight**: `knownFailed` flag) | rewrite from final code |
| 13 | Copy an existing config as template | 160 | stale | config/TEMPLATE_config.m exists; NEW_DEPLOYMENT.md | point to template + NEW_DEPLOYMENT.md |
| 14 | DeploymentNotes{year}.xls is the source | 162 | current | CLAUDE.md, DOFFP checklist | keep; add "source on the line" rule and audit_config_provenance |
| 15 | config/CONFIG_REVIEW_NOTES.md, DOFFP_LOOKUP_CHECKLIST.md | 167 | current (both exist) | ls config/ | keep |
| 16 | Old-season metadata in PandPUV2015-2025.xlsx, Checkout sheets | 176–178 | unverifiable here | server not checked | leave or verify on server |
| 17 | VEC setup: rawFormat, clockSource, deployYear, cutoffGapSec 60 | 172–175 | incomplete | `instr.clockOffsetHours` required (filename clock is Pacific local) | add clockOffsetHours |
| 18 | qcOpts table defaults | 192–203 | current | l1_qc_opts.m | keep; add offBedDbar (absent = off) |
| 19 | Set Tvalid [9 26] for San Diego | 213–214 | current | all 21 configs set [9 26] | keep; say it is in every catalog config |
| 20 | read_VEC bit-exact, 886,319 / 443,131 records | 229–232 | current per docs | pre2023_deployment_inventory.md:15 | keep |
| 21 | 8 Hz config vs 2 Hz records | 248–253 | current | CLAUDE.md, read_VEC.m | keep |
| 22 | Filename clock = "true wall-clock hour"; offset constant | 255–264 | **wrong by omission**: the wall clock was Pacific local, 7–8 h from UTC | CLAUDE.md 2026-07-28; vec_clock_from_filenames.m; configs | add clockOffsetHours and the sign derivation |
| 23 | Control instrument agrees to 33 s | 263–264 | current | vec_clock_from_filenames.m:28; recopied_data_backlog.md:108 | keep |
| 24 | Archive edge cases (hiccups, power-on glitch, battery clock drift, year crossing) | 270–283 | current | PUV_raw_process.m:100–160 | keep |
| 25 | Each raw file its own burst; chronological order | 287–290 | current | CLAUDE.md, PUV_raw_process.m | keep |
| 26 | L1 reads .dat/.sen/.hdr; "merges bursts" | 301–302 | stale wording | also .VEC | fix |
| 27 | Drivers error if previous level missing | 319–320 | current, incomplete | CHANGELOG 10-14 (loud failures) | expand (**in flight**: provenance in drivers) |
| 28 | Channel decoupling; 120 h storm-peak velocity recovered (TOR23W 586_10m) | 337–341 | current | L1_sensor_block_failure_2026-07-09.md:291 | keep |
| 29 | Per-channel validity list | 350–361 | current | puv_channel_qc.m | keep; add off-bed detector (off) |
| 30 | Tilt variability trusted only when sensor block healthy; static tilt substituted | 368–371 | current | puv_channel_qc.m:105–114; PUV_raw_process.m:635–646 | keep |
| 31 | Sound-speed rescale, Nortek N3015-030 §2.4.9 | 388–397 | current (code); manual reference unverifiable | PUV_raw_process.m:589–617 | keep |
| 32 | Provenance flag table (segValid…, qc_flag, Hs_source, vel_c_*) | 404–421 | current | PUV_L2_spectral.m:361–362, 430, 446–449, 542 | keep; distinguish from file-level provenance sidecars |
| 33 | qc_flag 4 for implausible pressure | 426–427 | current | PUV_L2_spectral.m:542 (HsMaxToHRatio 1.5, depthDeviationMax 0.5) | keep |
| 34 | "At L4 these flags travel per burst as puv_qc_flag…; qc_flag 4 dropped from every merged field" | 429–430 | **wrong for this repo's L4**: no L4_ig module writes `puv_*` fields; they appear only in a downstream merged product (`L4_TP_10m`, RESULTS_rerun_2026-07-10.md:111). README.md:192 repeats the claim | grep of repo | remove or say where it lives; tell README owner |
| 35 | Failure signatures table | 440–457 | current per docs | L1_sensor_block_failure doc | keep |
| 36 | Raw bursts "merged into a continuous series" | 465–466 | stale wording | per-file bursts | fix |
| 37 | Tilt rotation R_roll R_pitch | 474–476 | **wrong order** | PUV_raw_process.m:676–678 implement R_pitch·R_roll | fix (as in methods_L1_L2.tex) |
| 38 | "Heading rotation is static (uses the surveyed heading, not the live compass)" | 481–482 | **wrong** | heading NaN → compass median; logged heading only for 9 drifting-compass records; 12 disputed (heading_disputed_records.m) | rewrite with the 2026-10-07 heading rule |
| 39 | IGRF declination | 480 | current, incomplete | igrfmagm epoch 14/13; ENU declination added 2026-10-07 | add ENU |
| 40 | 1-hour UTC-aligned segments, 1.9× noise floor | 486–490 | current | PUV_L2_spectral.m:64, 94–117 | keep |
| 41 | Stationarity audit confirmed | 490–491 | unverifiable | no artifact | soften or cite |
| 42 | >10% NaN dropped; smaller gaps linearly interpolated | 491–492 | stale | EndValues nearest since 2026-10-09; segValid_vel/_p | fix |
| 43 | Shore-normal from CDIP | 493–494 | incomplete | instr.shorenormal precedence | fix |
| 44 | Depth formula | 494–496 | current | | keep |
| 45 | K = 7 tapers, ≈14 dof | 499 | **wrong** | psd_multitaper.m:33 → K = 6 for NW = 4 | fix |
| 46 | MTM "matches Welch's effective bandwidth" | 501–503 | **wrong** | 2.2e-3 Hz vs Welch-256 7.8e-3 Hz bins | fix |
| 47 | Pressure correction, Kp<0.1 | 506–510 | current | | keep |
| 48 | Hs bands, Tp, Tm02, direction, Ef | 512–517 | current, bands under-specified | compute_bulk_params.m | specify total band; S_eta weighting |
| 49 | Bed velocity factor cosh(kH)/cosh[k(H−z_s)] | 520 | **wrong** | bed_velocity_ifft.m:68 (1/cosh(k z_s)) | fix |
| 50 | ks = 2.5 D50, D50 0.25 mm default | 521–523 | **wrong** | PUV_L2_spectral.m:297–325 | fix; grain tally 19/4/42 |
| 51 | L3 bands, storms 1.5 m/6 h/12 h/7 d | 529–534 | current (thresholds hardcoded) | PUV_L3_storms.m:37–39 | keep |
| 52 | Rouse "classifying bedload vs suspended" (stress unstated) | 536–537 | stale | tau_m since 2026-08-13; F&C ws, seawater_nu, per-fraction | add |
| 53 | NOAA Scripps Pier tide, R 0.995 vs 0.987 | 537–539 | current as of 10-14; **in flight** (per-deployment tideStation) | PUV_L3_currents.m:67 | rewrite from final code |
| 54 | Validation vs MOP: biases "traced to" nonlinear shoaling, narrowing, bound waves **and MOP peak broadening** | 550–553 | **wrong**: peak broadening retracted 2026-07-24; narrowing does not explain the difference (2026-07-27) | results_validation.tex boxes | rewrite |
| 55 | Ruby2D bulk parameters at R² = 0.93–0.98 | 555–556 | **wrong** (selective) | results table: Hs 0.981, Tp 0.761, direction 0.927, spread 0.877 | quote the range 0.76–0.98, or Hs/direction only |
| 56 | Mean flow, 38 instruments, Stokes match, 0.24 mm/s floor | 557–562 | historical; predates 2026-05-14 heading fixes | local mean-flow planning note (not in the repository) | add caveat |
| 57 | Decoder MOP check: R² 0.88–0.94, 1–4 cm bias; firmware-1.21 0.65–0.87, biases < 9 cm | 563–570 | current per July docs; pre-dates clock/doffp fixes | recopied_data_backlog.md:58, 137 (Tier C 0.5–0.9 at :187) | keep with date; mention Tier C range |
| 58 | Deeper writeups results_validation.tex, multitaper_writeup.tex "carry the full tables" | 574–575 | stale framing | both now historical with retractions | point to compile_sections.pdf, legacy_pipeline_defects.pdf |
| 59 | Output reference L1/L2 fields, vmom sub-struct | 584–594 | current | PUV_L2_spectral.m:263–269 | keep; add L3/L4 fields, prov sidecars |
| 60 | Coordinates, dBar | 596–598 | current | README | keep |
| 61 | Troubleshooting references | 618–622 | current (files exist) | ls docs/, config/ | add README, CHANGELOG, NEW_DEPLOYMENT.md, audits, run_all_tests |
| 62 | Missing entirely: provenance sidecars and catalog versions, copy_to_server gate, no-external-writes rule, excluded_records, heading_disputed_records, external_deps, run_all_tests and the five audits, known limitations | n/a | stale by omission | README sections | add a short section each, or point to README |
| 63 | `---` em dashes (17 lines) | 65, 107, 150, 225, 228, 241, 256, 257, 301, 306, 310, 313, 367, 377, 397, 465, 558 | style | `grep -c -- '---'` | recast |

## Counts

- Claims checked: 63.
- Current: 30. Stale (incl. omissions): 16. Wrong: 13 (#5, 9, 11, 22, 34, 37, 38,
  45, 46, 49, 50, 54, 55; #11 partly). Unverifiable: 4 (#16, 31 reference, 41,
  and the R values in #53). In flight: 4 (#7, 12, 27, 53).
- Fixed in pass 1: 0 (audit only). Pass 2: see below.

Rows #37, #45, #46, #49, #50 are the same errors corrected in
`methods_L1_L2.tex`; pass 2 can reuse that text. Rows #34 and the taper count
(#45) also appear in files outside this task (README.md:192; pipeline_levels.md:167,
PIPELINE_NOTES.md:49/106/736, pipeline_comparison_legacy.md:14/56/109,
puv_pipeline_slides.tex:1379/1393).

## Pass 2 (2026-10-15, after commits 63c26a3, f9ef7b9, e843683, 719c52b)

The Guide was rewritten against this table and the landed code. Every stale and
wrong row was fixed; the four **in flight** rows were rechecked against the
final code:

- #7 external files: now 11 (getztide2 left `external_deps`); missing t_tide is an
  error unless `opts.allowNoTides` (`PUV_L3_currents`, CHANGELOG 2026-10-15).
- #12 and #27 failures: `knownFailed` per instrument (7 records, `shared/known_failed.m`),
  drivers skip with `KNOWN FAILED` and end in error only on new failures; drivers
  write provenance through `shared/save_with_provenance.m`.
- #53 tides: `cfg.tideStation` per config, `shared/noaa_tide_predictions.m`, San
  Diego default only inside the county, Catalina flagged approximation (2.8 cm rms
  against 9410079), `L3.tidal.station` stamped and checked by `check_prov`.

Added sections: provenance and the published catalog, L4 methods, known
limitations, audits, tests. Unverifiable rows (#16, #31 manual reference, #41) were
dropped (#41) or kept with their source named. Build: 0 errors, 0 warnings,
16 pages.

Shared errors fixed outside the Guide in the same pass: taper count in
`docs/pipeline_levels.md`, `PIPELINE_NOTES.md` (3 places),
`docs/pipeline_comparison_legacy.md` (3 places) and the `shared/psd_multitaper.m`
docstring; tilt-order comments in `L1_raw_to_qc/PUV_raw_process.m` (2 places);
README L4 flag fields (#34); Fb formula in `docs/pipeline_levels.md`. Not changed:
`docs/puv_pipeline_slides.tex` (K = 7 at two frames) and
`docs/archive_Processed_HLB_17min_README.md` (a record of the deleted archive).
