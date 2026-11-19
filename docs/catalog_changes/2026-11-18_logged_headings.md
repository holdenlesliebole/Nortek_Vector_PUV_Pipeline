# Logged mount headings for the 12 formerly disputed records

```catalog-change
status: published 2026-11-18.1
files:
  - L1/TOR14B/MOP591_9m_processed.mat
  - L1/TOR14C/MOP591_9m_processed.mat
  - L1/TOR15A/MOP591_9m_processed.mat
  - L1/TOR15D/MOP591_9m_processed.mat
  - L1/TOR17B/MOP591_9m_processed.mat
  - L1/TOR17D/MOP591_9m_processed.mat
  - L1/COR17D/MOP158_9m_processed.mat
  - L1/CDF15A/MOP677_9m_processed.mat
  - L1/CDF15C/MOP677_9m_processed.mat
  - L1/TOR24W/MOP586_10m_processed.mat
  - L1/TOR25S/MOP586_15m_processed.mat
  - L1/SIO25E/SIO_6m_processed.mat
  - L2/TOR14B/MOP591_9m_L2.mat
  - L2/TOR14C/MOP591_9m_L2.mat
  - L2/TOR15A/MOP591_9m_L2.mat
  - L2/TOR15D/MOP591_9m_L2.mat
  - L2/TOR17B/MOP591_9m_L2.mat
  - L2/TOR17D/MOP591_9m_L2.mat
  - L2/COR17D/MOP158_9m_L2.mat
  - L2/CDF15A/MOP677_9m_L2.mat
  - L2/CDF15C/MOP677_9m_L2.mat
  - L2/TOR24W/MOP586_10m_L2.mat
  - L2/TOR25S/MOP586_15m_L2.mat
  - L2/SIO25E/SIO_6m_L2.mat
  - L3/TOR14B/MOP591_9m_L3.mat
  - L3/TOR14C/MOP591_9m_L3.mat
  - L3/TOR15A/MOP591_9m_L3.mat
  - L3/TOR15D/MOP591_9m_L3.mat
  - L3/TOR17B/MOP591_9m_L3.mat
  - L3/TOR17D/MOP591_9m_L3.mat
  - L3/COR17D/MOP158_9m_L3.mat
  - L3/CDF15A/MOP677_9m_L3.mat
  - L3/CDF15C/MOP677_9m_L3.mat
  - L3/TOR24W/MOP586_10m_L3.mat
  - L3/TOR25S/MOP586_15m_L3.mat
  - L3/SIO25E/SIO_6m_L3.mat
  - L4/TOR14B/MOP591_9m_L4.mat
  - L4/TOR14C/MOP591_9m_L4.mat
  - L4/TOR15A/MOP591_9m_L4.mat
  - L4/TOR15D/MOP591_9m_L4.mat
  - L4/TOR17B/MOP591_9m_L4.mat
  - L4/TOR17D/MOP591_9m_L4.mat
  - L4/COR17D/MOP158_9m_L4.mat
  - L4/CDF15A/MOP677_9m_L4.mat
  - L4/CDF15C/MOP677_9m_L4.mat
  - L4/TOR24W/MOP586_10m_L4.mat
  - L4/TOR25S/MOP586_15m_L4.mat
  - L4/SIO25E/SIO_6m_L4.mat
  - L4_xspec/TOR24W/*
  - L4_xspec/TOR25S/*
  - L4_xspec/RUBY22/*
  - L4_xspec/SOL23/*
  - L4_xspec/TOR23W/*
code_ack:
  - L2: built at acc5e35 with an uncommitted edit to a docs/ Markdown file only (TOR25S MOP586_15m, SIO25E and the five xspec); git diff acc5e35 014d0db touches docs/ only, no code; HLB 2026-11-18
  - L3: built at acc5e35 with an uncommitted edit to a docs/ Markdown file only (TOR25S MOP586_15m, SIO25E and the five xspec); git diff acc5e35 014d0db touches docs/ only, no code; HLB 2026-11-18
  - L4: built at acc5e35 with an uncommitted edit to a docs/ Markdown file only (TOR25S MOP586_15m, SIO25E and the five xspec); git diff acc5e35 014d0db touches docs/ only, no code; HLB 2026-11-18
  - L4_xspec: built at acc5e35 with an uncommitted edit to a docs/ Markdown file only (TOR25S MOP586_15m, SIO25E and the five xspec); git diff acc5e35 014d0db touches docs/ only, no code; HLB 2026-11-18
fallback_ack: false
```

**What changed.** For the 12 records where the diver-logged mount heading and the onboard
compass median differ by more than 10 deg, L1 now uses the logged heading, exactly as recorded
in the deployment workbooks (HLB decision, 2026-11-16). Evidence: for all 12, the constant
rotation that best matches CDIP MOP Sxy has the sign of (logged minus compass), usually within
4 deg (Paper_2 `docs/RESULTS_eof_recovery_renumber_2026-11-12.md` G30-G31,
`scripts/analysis/explore_sxy_rotation_2026_11_16.m`). MOP was supporting evidence only; no
MOP-fitted value entered any config. The values, workbook rows and serial checks are in
`docs/PLAN_heading_log_switch_2026-11-17.md`. `shared/heading_disputed_records.m` now lists
no disputed records and keeps the 12 as switched.

| record | logged (deg mag) | was (compass) | shift (deg) |
|---|---:|---:|---:|
| TOR17D MOP591_9m | 66.7 | 100.5 | -33.8 |
| TOR14C MOP591_9m | 101.5 | 76.0 | +25.5 |
| TOR17B MOP591_9m | 66.7 | 87.6 | -20.9 |
| TOR15D MOP591_9m | 43.0 | 26.7 | +16.3 |
| TOR15A MOP591_9m | 63.6 | 48.7 | +14.9 |
| TOR14B MOP591_9m | 101.5 | 90.0 | +11.5 |
| COR17D MOP158_9m | 28.9 | 49.1 | -20.2 |
| CDF15A MOP677_9m | 62.2 | 47.6 | +14.6 |
| CDF15C MOP677_9m | 62.2 | 47.5 | +14.7 |
| TOR24W MOP586_10m | 59.5 | 71.9 | -12.4 |
| TOR25S MOP586_15m | 34.2 | 46.1 | -11.9 |
| SIO25E SIO_6m | 88.0 | 99.3 | -11.3 |

TOR24W's 59.5 deg was carried forward from the previous deployment in the notes ("KVH Compass
failed"), not measured for this one.

**Size of the change, from the gates.**
- L1 (12/12): every velocity sample's bearing moved by the shift to within 1.1e-13 deg; speed
  changed by at most 8.9e-16 m/s; W, P, T, instrument-frame velocity, QC and beam-step fields
  unchanged.
- L2 (12/12): meanDir moved by minus the shift to within 8.5e-14 deg; the mean-current
  bearing moved by minus the shift in the shore-normal frame (apply_shorenormal_rotation flips
  one axis) to within 8.0e-13 deg; rotation invariants and all pressure- and speed-derived fields
  (Hs, Tp, Ub, tau_b, Ef) unchanged within 1e-9 relative.
- L3: storm events, bed stress, Shields, Rouse, settling velocity and the tidal depth fit
  unchanged. Tidal and subtidal velocity change. Their bearings do not move by exactly the
  shift, because t_tide keeps only constituents with SNR > 2 and a rotation moves borderline
  constituents across it (for example TOR14C 6 -> 3 velocity constituents, CDF15C 10 -> 13).
  Tidal current speed changed by at most 3.9e-02 m/s and subtidal by at most 4.0e-02 m/s (both
  TOR14C); at the other 11 records by at most 2.3e-02 m/s.
- L4: eta and bispectra unchanged; reflection, reflection_free, boundwave, moments and the
  velocity PDF move with velocity direction.
- L4_xspec: rebuilt because parent L4 files changed (TOR24W, TOR25S) or for provenance (RUBY22,
  SOL23, TOR23W). 5/5 rebuilt (23 pairs); no field changed within 1e-9 relative, as expected,
  because xspec reads only `eta.eta_ig` and pair geometry, neither of which depends on heading.

**Also found.** The 2026-11-17.1 L1 files carry mixed metadata vintages: the beam-step code
gained `qc.nPlaceholder` and `qc.flagWhenNoDelta` part way through that build (43/66 records have
neither field, 22/66 `nPlaceholder` only, 1/66 both). The 12 rebuilt L1s carry both. No values
differ because of it.

**Stale downstream.** Anything computed for these 12 records from an earlier catalog version:
meanDir, Sxy and the other radiation-stress terms, a1/b1/a2/b2, cross- and alongshore velocity
moments, mean, tidal and subtidal current direction, and the L4 reflection and velocity-PDF
products.

**How to tell new from old.** The new L1s have `PUV.rotation.sensor` equal to the logged value
in the table.
