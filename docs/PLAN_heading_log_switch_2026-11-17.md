# Logged headings for the 12 formerly disputed records (2026-11-17)

Branch `heading-log-switch-20261117`, cut from `beam-step-correction-20261113`
at 30cbe00 (catalog 2026-11-17.1, the beam-step rebuild). Driver:
`scripts/rebuild_heading_log_2026_11_17.m`; watchdog for the bispectra parfor:
`scripts/run_heading_L2L4_watchdog.sh`.

## Decision

HLB, 2026-11-16: where the diver-logged mount heading and the onboard compass
median differ by more than 10 deg, use the logged value, exactly as recorded.
The deciding evidence is independent of both: for all 12 such records, the
single constant rotation that best matches CDIP MOP Sxy has the sign of
(log - compass), usually within 4 deg and at most 10.3 deg off it (CDF15C).
Sources: `Paper_2/docs/RESULTS_eof_recovery_renumber_2026-11-12.md` G30-G31 and
`Paper_2/scripts/analysis/explore_sxy_rotation_2026_11_16.m`. MOP is supporting
evidence only. No MOP-fitted or other new value enters any config, because
where the PUV and MOP differ the PUV may be right.

## Values

Each logged value was re-read on 2026-11-17 from the workbook on
`/Volumes/group/DeploymentNotes/` at the cited row, and each row's serial was
checked against the config's serial for that deployment. All 12 match
`shared/heading_disputed_records.m` as it stood.

| record | logged (deg mag) | compass in L1 | shift | source row |
|---|---:|---:|---:|---|
| TOR17D MOP591_9m | 66.7 | 100.5 | -33.8 | SoCal_instruments_2017-2018.xls row 36 (ditto of row 33) |
| TOR14C MOP591_9m | 101.5 | 76.0 | +25.5 | SoCal_instruments_2014.xls row 42 |
| TOR17B MOP591_9m | 66.7 | 87.6 | -20.9 | SoCal_instruments_2017-2018.xls row 34 (ditto of row 33) |
| TOR15D MOP591_9m | 43.0 | 26.7 | +16.3 | SoCal_instruments_2015.xls row 59 |
| TOR15A MOP591_9m | 63.6 | 48.7 | +14.9 | SoCal_instruments_2015.xls row 55 |
| TOR14B MOP591_9m | 101.5 | 90.0 | +11.5 | SoCal_instruments_2014.xls row 41 |
| COR17D MOP158_9m | 28.9 | 49.1 | -20.2 | SoCal_instruments_2017-2018.xls row 40 (ditto of row 37) |
| CDF15A MOP677_9m | 62.2 | 47.6 | +14.6 | SoCal_instruments_2015.xls row 49 |
| CDF15C MOP677_9m | 62.2 | 47.5 | +14.7 | SoCal_instruments_2015.xls row 52 |
| TOR24W MOP586_10m | 59.5 | 71.9 | -12.4 | DeploymentNotes2024-2025.xls row 34 |
| TOR25S MOP586_15m | 34.2 | 46.1 | -11.9 | DeploymentNotes2024-2025.xls row 40 |
| SIO25E SIO_6m | 88.0 | 99.3 | -11.3 | DeploymentNotes2025-2026.xls row 8 |

"Compass in L1" is `PUV.rotation.sensor` in the 2026-11-17.1 L1, read with
h5read. It differs from the median in the disputed table by up to 0.2 deg
(TOR17D 100.5 vs 100.3), because the two medians were taken over different
samples. The shift is computed from the L1 value, which is what the rotation
acts on. The 2014 rows read "113.3 deg (101.5mag)"; the magnetic value is used,
the same convention as every other logged heading. TOR24W's 59.5 deg was carried
forward from the previous deployment ("KVH Compass failed. 59.5deg previously
measured."), not measured for this one. TOR24W's other edit on this branch is
none: its MOP586_15m serial correction (16737 -> 17047) from the beam-step
commit is unchanged.

## Predictions (written before any rebuild)

The XYZ rotation (`xyz_to_buoy_frame`) uses one heading per record, so a heading
change Delta rotates every buoy-frame velocity sample by Delta about the
vertical. The declination is unchanged (same LATLON and dates). Therefore:

- L1: the bearing of every velocity sample moves by exactly the shift in the
  table, speed is unchanged, and nothing else changes. W, P, T, the instrument-
  frame velocity, every QC field and the beam-step fields stay bitwise equal.
- L2: meanDir moves by minus the shift. The mean current turns by the shift.
  Sxy, a1, b1, a2, b2, Suu, Svv, Sxx, Syy, uBed_rms, vBed_rms, phase_PU,
  qtest_PU, vmom and the directional Reynolds terms change. Their rotation
  invariants (Suu+Svv, Sxx+Syy, a1^2+b1^2, a2^2+b2^2, TKE, w_rms) and every
  pressure-derived or speed-derived field (Hs, Tp, Ub, tau_b, T_b, Ef) do not.
- L3: only uMean/vMean and the tidal and subtidal velocity change. Storm
  events, bed stress, Shields, Rouse, settling velocity and the tidal depth fit
  do not.
- L4: eta and the bispectra do not change. Reflection, the velocity PDF, the
  bound wave and reflection-free fields depend on velocity direction and will
  move.
- L4_xspec (TOR24W, TOR25S): the cross-spectra are rebuilt because their parent
  L4 files changed; whether any field moves is reported.

The tolerances and gate rules are in the driver's header (G1-G4) and were fixed
before any record was rebuilt. One check was moved from gated to reported
before any run: the tidal-velocity bearing. t_tide fits u + iv linearly, but its
prediction keeps only constituents with SNR > 2 and estimates the bootstrap
noise per axis. A rotation can therefore move a borderline constituent across
that threshold. The break test: `gateBreakShift = 0.01` must make G1 fail on a
record, while the same record passes with 0.

## Size, backups, raw

- Raw cache: `~/LocalData/Scripps/Research/PUV_Pipeline/raw_cache_heading_20261117`,
  only these 12 instruments, about 13.9 GB (the beam-step raw cache was
  deleted). Deleted 2026-11-18 after the push was verified (13 GB).
- No byte backups. The 50 files to be overwritten (48 L1-L4 plus 2 xspec,
  13.2 GB) are in `docs/archive_snapshot_manifests/pre_heading_log_2026-11-17_manifest.csv`
  (path, bytes, sha256), and all 50 match sha256s in the server manifest of
  catalog 2026-11-17.1 (checked 2026-11-17). The server copy is the rollback.

## Stale downstream after this catalog version

Directional quantities for these 12 records change by the shift above:
meanDir, Sxy (and the other radiation-stress terms), a1/b1/a2/b2, cross-shore
and alongshore velocity moments, mean, tidal and subtidal current direction, and
the L4 reflection and velocity-PDF products. Anything computed from a copy older
than this catalog version is stale for these records, including the Paper_2
PUV-vs-MOP Sxy diagnostics of 2026-11-16 (`explore_sxy_torrey_2026_11_16.m`,
`explore_sxy_rotation_2026_11_16.m`). Listed in `docs/todo.md`.

## Run log

Logs: `outputs/_logs/heading_log_{L1,L2L4,gapL4}_2026-11-17.log`, plus the watchdog retry logs
`heading_log_L2L4_retry_202611181330.log` and `heading_log_*_wd1_*.log`.

- **L1, 2026-11-17 16:08 to 17:21: 12/12 PASS.** Bearing moved by the shift within 1.1e-13 deg,
  speed by at most 8.9e-16 m/s. The first attempt failed G1 on metadata (vecFile root, hdrFile,
  nPlaceholder, flagWhenNoDelta); HLB ruled these post hoc exceptions (c383f0f, b394b05). The
  break test (gateBreakShift = +0.01 deg) failed as it must.
- **L2-L4, 2026-11-17 22:51 to 2026-11-18 17:18: 12/12 PASS.** The first run failed G2 at all 12:
  the bearing in the shore-normal frame moves by minus the shift, not plus (one axis is flipped).
  HLB approved the post hoc sign correction (bfffd5e). meanDir within 8.5e-14 deg of minus the
  shift, current bearing within 8.0e-13 deg. Tidal and subtidal speed changed by at most
  4.0e-02 m/s (TOR14C); constituent counts above SNR 2 changed at 11/12 (reported, not gated).
  The watchdog killed TOR24W during its L4 save and truncated the file; its L2, L3 and L4 were
  restored from the server (sha256 = manifest) and the save made atomic (5b184f3) before the
  rerun. TOR24W, TOR25S and SIO25E ran with serial bispectra (69 min to 88 min each).
- **gapL4, 2026-11-18 05:51 to 13:27: 20/20 PASS.** The first run failed at records where
  `varP_over_varU` is Inf; HLB approved the within_tol fix (acc5e35), break test 7/7. No value
  changed (see `docs/catalog_changes/2026-11-17_l4_velocity_gaps.md`).
- **xspec, 2026-11-18 17:20: 5/5 PASS**, 23 pairs, no field changed (xspec reads `eta.eta_ig` and
  geometry only).
- **Altimeter L4, 2026-11-18 17:21:** rebuilt with `run_L4.m` and pushed to reefbreak, 11/11
  sha256 = manifest. Parent stamps 36/42 current before, 42/42 after. Details and the TP 5 m MOP
  gap-fill finding are in `Altimeter_Pipeline/NOTES.md`.
- **PUV push, 2026-11-18 20:11 to 20:54: catalog 2026-11-18.1**, one attempt with
  `run_push_with_remount.sh`. 73 files copied, 200 refused as unchanged; manifest.csv 273 rows;
  CHANGELOG written; prior manifest kept at `manifests/manifest_before_2026-11-18.1.csv`. The
  first dry run refused 11 files as dirty (a tracked docs edit during their builds); HLB approved
  the code_ack (8a7b8d6). Verified after the push: 73/73 server sha256 = local = sidecar
  `file_sha256` = manifest. Both catalog entries set to `published 2026-11-18.1`.
- **Sxy rotation rerun, 2026-11-18:** `Paper_2/scripts/analysis/explore_sxy_rotation_2026_11_16.m`
  with `'*'`, 63 records. No record outside the 12 changed its best rotation. Median |best
  rotation| for the 12 fell from 12 deg to 3.2 deg (other 51 records: 3.5 deg). Each new best
  rotation equals the old one minus (log - compass) within the 0.5 deg grid. Largest remaining:
  CDF15C -10.5 deg, TOR15D -9.5 deg, SIO25E +7.5 deg. SIO25E's correlation at zero rotation fell
  from 0.78 to 0.46. No adjustment made.
