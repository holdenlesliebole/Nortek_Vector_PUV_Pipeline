# TOR23W MOP586_10m velocity cutoff moved from 15:29 to 03:00 UTC on 2023-12-30

```catalog-change
status: published 2026-11-19.1
files:
  - L2/TOR23W/MOP586_10m_L2.mat
  - L3/TOR23W/MOP586_10m_L3.mat
  - L4/TOR23W/MOP586_10m_L4.mat
  - L4_xspec/TOR23W/xspec.mat
code_ack:
  - L2: built at fb8587d with the uncommitted config/TOR23W_config.m velInvalidFrom edit (the change this entry publishes) and the new driver scripts/rebuild_tor23w10m_cutoff_2026_11_19.m; git diff fb8587d c6b7c37 touches only those two files and this entry, no pipeline code; HLB 2026-11-19
  - L3: same build as L2 (fb8587d plus the uncommitted cutoff config and driver; committed as c6b7c37); HLB 2026-11-19
  - L4: same build as L2 (fb8587d plus the uncommitted cutoff config and driver; committed as c6b7c37); HLB 2026-11-19
  - L4_xspec: same build as L2 (fb8587d plus the uncommitted cutoff config and driver; committed as c6b7c37); HLB 2026-11-19
fallback_ack: false
```

HLB decision 2026-11-19. `config/TOR23W_config.m` `velInvalidFrom` moves from 2023-12-30 15:29 UTC to
2023-12-30 03:00 UTC. The 2026-11-13 cutoff came from the ratio of sea-swell $U_b$ at 10 m to 15 m (reference
median 1.377, 5% to 95% band 1.287 to 1.463, 1,029 hours; failure stretch 0.39). The same rule applied to the six
paired hours of 30 December before 15:29 gives 1.31 to 1.38 for the segments centred 00:30 to 02:30 and 0.24 to
0.27 for 04:30 to 06:30; 03:30 has no 15 m pair. L2 segments are one hour centred on :30, so 03:00 keeps the last
good segment (02:00 to 03:00) whole. Source: `Paper_2/docs/RESULTS_puv_alt_rerun_2026-11-19.md`. Driver and gates:
`scripts/rebuild_tor23w10m_cutoff_2026_11_19.m` (log `outputs/_logs/tor23w10m_cutoff_2026-11-19.log`).

How big:
- L2: 3 segments lose `segValid_vel` (centred 2023-12-30 04:30, 05:30, 06:30 UTC); the 1,085 segments before
  02:31 are unchanged field by field; `segValid` (972) and `segValid_p` unchanged; shore-normal 264.5 deg.
- L3: the record-median fallback temperature moves 17.0471 to 17.0476 degC, because two of the dropped segments
  carried 13.1 and 10.9 degC from the failed sensor (inside Tvalid [9 26]). T_used, nu, ws, theta_cr and tau_cr
  move at 484 segments, all with `segValid` = 0; every valid segment is unchanged. Storm events unchanged.
  Gate G3 was amended post hoc for this (HLB 2026-11-19; recorded in the driver header).
- L4: eta and bispectra unchanged; `moments` moves (velocity-dependent).
- L4_xspec/TOR23W: rebuilt from the new L4, 15 pairs, no field moved. Note: an earlier xspec stage on
  2026-11-19 12:06 rewrote this file before the L2 to L4 pass (content identical); the driver now refuses that.
- Downstream: Altimeter_Pipeline L4 rebuilt (parent stamps 42/42, Hs_combined coverage 6/6 at 100% after two
  builds lost the MOP gap-fill to CDIP 504s); Paper 1 sidecar `TOR23W_MOP586_10m_ubar_filled` regenerated (C1
  pass). Paper 2: only the 10 m velocity-only moments move (30 December recovered bursts 12 to 6, median
  skewness 0.26 to 0.50; recovered total 116 to 113).

How to tell a new copy: `L2.velGap.velInvalidFrom` = 2023-12-30 03:00:00 UTC.

Backup of the replaced files: `outputs/_pre_tor23w10m_cutoff_backup_2026-11-19/` (931 MB). **Deleted 2026-11-19**
after publication as 2026-11-19.1 and verification (local = provenance sidecar = server manifest = server file,
4/4). What it held, with sha256 and how to regenerate (config at fb8587d, velInvalidFrom 15:29 UTC):
`docs/archive_snapshot_manifests/removed_pre_tor23w10m_cutoff_backup_2026-11-19_manifest.csv`. Its xspec.mat was the
12:06 rewrite, content-identical to the 2026-11-18.1 file but not byte-identical.
