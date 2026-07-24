# Backlog: unprocessed "recopied" Vector archive

Note added 2026-07-23 (HLB). **The older Nortek Vector deployments in
`reefbreak:/Volumes/group/PUV_data/Vector/recopied/` have NOT been run through this pipeline
(L1→L4)** the way the 2021–2026 deployments have. They need processing.

**Worked 2026-07-24.** Tier A is done; Tier B is scoped below. See
`docs/pre2023_deployment_inventory.md` for the full file-by-file survey.

## How this was confirmed

- `config/deployment_registry.m` — earliest Torrey code was `TOR23S` (2023); no 2019/2020 codes existed.
- `Vector/Processed_HLB/manifest.csv` — earliest processed deployments were 2018–2021 (IB18W, IB19S,
  CAT21A/B, RUBY22, LPL23+). No `TORREY02` / MOP582 / 2019–2020 entries.

## What the format actually turned out to be

The 2026-07-23 note assumed the velocity coordinate frame was unrecoverable because
`.hdr`/`.vhd` are 0 bytes, and the May 5 inventory assumed the `.VEC` files needed Nortek
ExploreV on Windows. **Neither holds.** `L1_raw_to_qc/read_VEC.m` decodes the raw recorder
binary directly, and the configuration records inside it carry the coordinate system,
sampling rate, serial number and deployment clock:

- **Coordinate frame is XYZ** on every file checked — read from the User Configuration
  record, not reconstructed. Heading still comes from the `.sen` compass (magnetic;
  the deployment notes also record it at install).
- The decoder is verified bit-exact against the one overlapping ASCII export
  (`test_read_VEC.m`).
- `Cardiff1049_2015-2016/`'s `.049` files are ordinary Vector binary missing only the
  leading `0xA5` sync byte — not a pre-Vector format.

**The ASCII exports are the untrustworthy part, not the binary.**
`TORREY02_1.dat/.sen` cover 2019-11-14 → 2019-11-19 — **5.1 days of a 174-day deployment** —
and both end mid-line. Ingesting them would have silently produced 3% of the record.
`PUV_raw_process` now warns whenever both an ASCII export and raw binary are present, and
the affected configs pin `rawFormat = 'VEC'`.

## Tier A — DONE (2026-07-24)

2 Hz, firmware 3.43, valid real-time clock. Decoded from `.VEC` and run L1→L4.

| Folder | Deployment | Instrument | Deployed → recovered | L1 record retained | Hourly segments (valid) |
|---|---|---|---|---|---|
| `TorreyPines2019-2020MOP582_10meter` | **TOR19W** | S/N 15277, MOP582 10 m | 2019-11-15 → 2020-05-06 | 2019-11-15 → 2020-04-03 (139.5 d, 24.1 M samples) | 3347 (2858) |
| `TorreyPines2020-2021_10meter` | **TOR20W** | S/N 15277, MOP582 10 m | 2020-10-29 → 2021-03-31 | 2020-10-29 → 2021-03-31 (153.2 d, 26.5 M samples) | 3676 (2965) |
| `2019-2020-IB-Cortez` | **IB19W** | S/N 15032, MOP045 Cortez 6 m | 2019-11-18 → 2020-05-27 | 2019-11-18 → 2020-02-19 (92.4 d, 16.0 M samples) | 2217 (1771) |

The binary covers the full deployment in every case (TOR19W decodes 26.0 M samples to 2020-05-07,
IB19W 18.3 M to 2020-05-28). The shortfall in the L1 record is the pipeline's existing
battery-cutoff rule, which truncates at the first gap over a second once the instrument starts
recording intermittently late in these 5-6 month single-battery deployments — not a decode limit.

**Validation against CDIP MOP**, hourly Hs over the full records:

| | n | R² | bias (PUV−MOP) | RMSE | slope |
|---|---|---|---|---|---|
| TOR19W vs D0582 | 2858 | 0.884 | −0.022 m | 0.132 m | 0.926 |
| TOR20W vs D0582 | 2965 | 0.944 | −0.009 m | 0.123 m | 0.987 |
| IB19W vs D0045 | 1771 | 0.893 | +0.037 m | 0.147 m | 0.863 |

An independent check also falls out of the two Torrey deployments: L2 median depth differs by
0.33 m between them (11.37 vs 11.70 m), matching the 0.29 m difference in `doffp` recorded in the
field notes.

TOR19W was the priority: it is co-located with the MOP582.2 Aquadopp ADCP (S/N 2141, ~15 m)
over the same window, so it is the independent-instrument check on that ADCP's currents for
the `Side_projects/Acoustics` work.

Two things to carry forward:
- `TorreyPines2019-2020MOP582_10meter` also holds a bare `TORREY02.VEC` that **duplicates**
  2019-11-14 → 2019-12-11, already inside `_1` and `_2`. The config's `filePrefix` ends in an
  underscore specifically to exclude it.
- IB19W's pressure port was 73 cm above the sand at deployment but **120 cm at recovery**
  (~47 cm of erosion). L2 uses a single fixed `doffp`, so depth-attenuation corrections late
  in that record are more uncertain than the nominal value suggests.

## Tier B — DONE (2026-07-24), and the "8 Hz / dead RTC" framing was wrong

Eight pre-2019 deployments across three stations, decoded from raw `.VEC`/`.049` and run
L1→L4:

| Deployment | Station | S/N | Recovered span | L1 days |
|---|---|---|---|---|
| `TOR15A` | Torrey offshore MOP591 | 1181 | 2015-11-19 → 2015-12-10 | 21 (died early) |
| `TOR15B` | Torrey offshore MOP591 | 1053 | 2016-01-04 → 2016-02-08 | 35 (clock jump at end) |
| `TOR16B` | Torrey offshore MOP591 | 1049 | 2017-01-05 → 2017-02-09 | 35 |
| `TOR17D` | Torrey offshore MOP591 | 0806 | 2018-03-20 → 2018-04-26 | 37 |
| `CDF15A` | Cardiff MOP677 (new site) | 1049 | 2015-11-19 → 2016-01-05 | 47 |
| `CDF15C` | Cardiff MOP677 (new site) | 1053 | 2016-02-24 → 2016-04-01 | 37 |
| `COR16B` | Coronado MOP158 (new site) | 1181 | 2017-01-05 → 2017-02-09 | 35 |
| `COR17D` | Coronado MOP158 (new site) | 1181 | 2018-03-20 → 2018-04-26 | 37 |

Two claims in the previous version of this section were **wrong**, both corrected while
processing:

1. **Not 8 Hz — 2 Hz.** `read_VEC` derived the rate as `512/AvgInterval`, which is right on
   firmware 3.43 but reports 8 Hz on firmware 1.21 where the records are unambiguously 2 Hz.
   Confirmed three independent ways: the decoded velocity/system record ratio is exactly 2, the
   1 Hz system-record count equals the RTC span in seconds, and the field checkout sheet states
   "Sample rate = 2Hz, Samples per block = 7168, Block time = 3600 s". No L2 rework or
   decimation was needed. The reader now measures the rate from the records.

2. **The clock is not dead — it runs from a wrong epoch.** Files stamp 2000-01-01 or
   2002-01-01, but the clock advances correctly, and the recorder names each hourly file
   `MMDDHHMM` for the real wall-clock hour. A single constant offset reconciles them
   (`vec_clock_from_filenames`, opt in with `clockSource = 'filename'`). Every recovered span
   above matches the logged deployment date. `Cardiff1049` is the control: its RTC was actually
   set correctly, and filename-derived time agrees with it to 33 s.

Other things that surfaced and are now handled in the pipeline (see the L1 commits):
- Firmware 1.21 leaves one benign 3-4 s gap in nearly every hourly file → configurable
  `cfg.qcOpts.cutoffGapSec` (60 s here) so a hiccup is not read as battery death.
- Power-on glitch (one ping, then a multi-minute gap, then the deployment) trimmed off the
  front instead of ending the record (TOR16B).
- A dying battery pulls the clock in the last hours → the offset guard judges the bulk spread
  (98th percentile), not the worst file, so TOR15B's 2 late files don't reject 922 good ones.
- Year-crossing deployments: `MMDDHHMM` filenames sort January ahead of the previous November,
  so bursts are reordered by their (monotonic) clock before merging (CDF15A).

Metadata came from `PandPUV2015-2025.xlsx` (the season-by-season PUV inventory, which resolved
every folder to a logged deployment) and the `VectorPUV_Winter201*Checkout.xlsx` sheets; MOP
transects were resolved from CDIP station coordinates (D0591 315 m, D0677 257 m, D0158 381 m).

**Validation against CDIP MOP**, hourly Hs over each record:

| | n | R² | bias (PUV−MOP) | RMSE | slope |
|---|---|---|---|---|---|
| TOR15A vs D0591 | 445 | 0.744 | −0.021 m | 0.221 m | 0.874 |
| TOR15B vs D0591 | 771 | 0.673 | −0.056 m | 0.413 m | 0.795 |
| TOR16B vs D0591 | 390 | 0.869 | +0.052 m | 0.223 m | 1.016 |
| TOR17D vs D0591 | 857 | 0.841 | −0.054 m | 0.162 m | 0.916 |
| CDF15A vs D0677 | 910 | 0.792 | −0.058 m | 0.263 m | 0.812 |
| CDF15C vs D0677 | 862 | 0.645 | −0.041 m | 0.286 m | 0.742 |
| COR16B vs D0158 | 474 | 0.871 | +0.002 m | 0.303 m | 1.021 |
| COR17D vs D0158 | 807 | 0.796 | −0.085 m | 0.177 m | 0.801 |

These R² (0.65–0.87) are lower than Tier A's 0.88–0.94, which is expected rather than a decode
problem: (a) these instruments sit 250–380 m from the exact MOP transect, vs Tier A's
near-co-located sites; (b) they are older firmware-1.21 units with lower Doppler SNR (TOR16B and
COR16B come in at ~50–75% velocity-valid at L1); (c) the MOP model itself is less certain at
transects this far from a buoy (Bill's Q_p caveat). Biases are all under 9 cm and slopes near 1,
so the absolute Hs is well tracked. The two lowest — TOR15B (0.67, RMSE 0.41) and CDF15C — are
consistent with those specific records: TOR15B's degraded-timestamp tail near battery death
smears the time alignment against the model.

### Still not done

- `Cardiffbackbeach_Jan2016` — a 2-day back-beach test (Jan 6-8 2016), different mixed file
  set; skipped as a short special-purpose deployment, not part of the offshore series.
- `Sarah_LPL_2014-2023` — **mislabeled**: the `.hdr` files identify the contents as Torrey
  Pines (`C:\PROJECTS\SoCal2014\TorreyPines\`), not Los Peñasquitos. Multiple deployments per
  season across nine years; the `read_VEC` + `clockSource='filename'` machinery now built
  should handle it, but ownership/scope is still to confirm with Sarah before processing.
- The 2nd/4th Cardiff and 1st/3rd Torrey deployments of 2015-16, and the 1st/3rd Coronado and
  2nd Torrey of 2016-17, etc. — the archive only holds a subset of each season's four swaps;
  the missing ones are simply not in `recopied/`.

## Already processed — do NOT redo

- `Catalina_2021` → CAT21A/B · `Ruby2D_2021-2022` → RUBY22
- `20190422_IB_North` / `_South` → IB18W / IB19S. Note these are a *different* deployment
  from `2019-2020-IB-Cortez` (now IB19W), even though it is the same instrument at the same
  MOP line one season later.
- The `Ruby2D_2021-2022/Torrey_2019-2020_MOP582_10m/` and `Torrey_2020-2021_MOP582_10m/`
  subfolders are **empty placeholders** — they do not duplicate TOR19W/TOR20W.
