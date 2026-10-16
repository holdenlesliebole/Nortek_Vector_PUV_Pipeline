# SOL25A time-varying heading; SOL26A added

```catalog-change
status: pending
files:
  - L1/SOL25A/*
  - L2/SOL25A/*
  - L3/SOL25A/*
  - L4/SOL25A/*
  - L1/SOL26A/*
  - L2/SOL26A/*
  - L3/SOL26A/*
  - L4/SOL26A/*
code_ack:
  - L1: XYZ rotation moved to xyz_to_buoy_frame.m (same arithmetic); optional time-varying compass heading (instr.headingSmoothHours, xyz_heading_series.m), used only by SOL25A
  - L2: built from a dirty tree whose uncommitted changes were the L1 heading code and the Solana configs, committed unchanged with this entry (pipeline code last edited 13:56, builds from 15:04); no L2 code changed
  - L3: same dirty tree as L2; no L3 code changed
  - L4: same dirty tree as L2; no L4 code changed
fallback_ack: false
```

**SOL25A/MOP654_7m.** The mount turned during the 2025-04-02 storm. The raw
compass (`7M65402_2.sen`) reads 17.2-17.6 deg magnetic until about 11:30 UTC and
13.7-14.2 deg from about 16:00 UTC to the end of the record, and pitch goes from
-2.1 to 0.0 deg over the same hours, so the mount moved, not the compass. The
recovery log gives 13.1 deg magnetic with a new compass (DeploymentNotes2024-2025.xls
'All Data' row 7). The catalog file used one median heading (14.0 deg), which left
the first four weeks about 3.4 deg off. The config now sets
`headingSmoothHours = 1`: each sample is rotated by the compass heading smoothed with
a 1 h circular mean (13.36 to 18.39 deg, median 14.01). L1-L4 rebuilt 2026-10-16 with
the run_all drivers (L4 with bispectra).

Size of the change, new minus old:
- L1: time, pressure, temperature and vertical velocity identical; horizontal speed
  identical to 4e-16 m/s; horizontal velocity rotated by +3.41 deg (hourly median)
  before 2025-04-02 11:00 and -0.09 deg after 17:00.
- L2: grid and all validity masks identical; Hs, Tp, Tm02, Ef and depth bit-identical;
  Ub and tau_b within 1.5e-6 m/s and 1.2e-5 Pa. Before 2 April: meanDir -3.42 deg,
  Sxy -33.2 N/m, Sxx -7.2 N/m (medians); after: under 0.15 deg and 0.7 N/m.
- L3: band energies and Fb identical; shields within 3.4e-6; currents up to 1.2 cm/s
  (median 0.04 cm/s); rouse median change 1e-4.
- L4: eta and bispectra identical; ref R2_IG median change 0.0025 (max 0.063);
  moments skewness_u up to 0.014.
- Against MOP (compare_derived_quantities), the record's two halves now agree:
  PUV - MOP direction -3.8 deg before and -4.2 after 2 April (was -0.8 and -4.4), the
  same as SOL24 (-4.9) and SOL25B (-3.0). Before the fix the heading error happened
  to cancel that offset for four weeks. The heading was chosen from the compass and
  tilt record, not from MOP.

**SOL26A/MOP654_7m (new).** Solana Beach MOP 654.5, 7 m, S/N 15277, deployed
2026-02-25, recovered 2026-05-07 per the log (rows 40-42); 77 cm on deployment.
No heading logged; the compass median (77.9 deg) is used, and the compass held at
77.5-78.3 deg with constant tilt the whole time in the water. ASCII export, consistent
with the .VEC by file size. The recorder kept logging on deck to 2026-05-11, so L2
carries 73 empty hours after the last valid one (2026-05-08 15:30 UTC). Checks: depth
against the NOAA tide best at lag 0, r = 0.998; median Z 0.972 over 1567 segments, no
record flag; Hs against MOP R2 0.78, RMSE 0.075 m, bias +0.027 m (n 1712). The log's
recovery date is a day earlier than the data leave the water; the tide fit says the
clock is right, so the log date is the likelier error. D50 is the Solana assumed
default (217.4 um), as for the other MOP 654.5 records.

How to tell old SOL25A files from new: the new L1 has
`PUV.rotation.headingMode = 'compass_smoothed'` and `PUV.rotation.sensorSeries`.
