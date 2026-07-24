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

| Folder | Deployment | Instrument | Window |
|---|---|---|---|
| `TorreyPines2019-2020MOP582_10meter` | **TOR19W** | S/N 15277, MOP582 10 m | 2019-11-15 → 2020-05-06 |
| `TorreyPines2020-2021_10meter` | **TOR20W** | S/N 15277, MOP582 10 m | 2020-10-29 → 2021-03-31 |
| `2019-2020-IB-Cortez` | **IB19W** | S/N 15032, MOP045 Cortez 6 m | 2019-11-18 → 2020-05-27 |

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

## Tier B — still outstanding

All of these are readable by `read_VEC`. The blocker is no longer file format; it is that
they are **8 Hz** (firmware 1.21) with a **dead real-time clock** — every file reports
`2013-06-28 09:52:25`, so true timestamps must be reconstructed from the `MMDDHHMM`
filenames and cross-checked against the checkout sheets. Both problems are shared with the
Sarah archive, so they are worth solving once.

- `Torrey1181_2015`, `Torrey1053_2016`, `Torrey1049_2017`, `Torrey0806_2018`
- `Cardiff1049_2015-2016`, `Cardiff1053_2016`, `Cardiffbackbeach_Jan2016`
- `CoronadoJan_2017`, `Coronado4thDeployment_2018`
- `Sarah_LPL_2014-2023` — **mislabeled**: the `.hdr` files identify the contents as Torrey
  Pines (`C:\PROJECTS\SoCal2014\TorreyPines\`), not Los Peñasquitos. Also 8 Hz with
  hour-named files and multiple deployments per season. Ownership/scope still to confirm.

Needed for Tier B, in order: (1) 8 Hz support in L2 — segment-length defaults assume 2 Hz —
or a decimation step at L1; (2) filename → timestamp reconstruction with a validation check;
(3) per-deployment configs from `SoCal_instruments_201*.xls` and the winter checkout sheets.

## Already processed — do NOT redo

- `Catalina_2021` → CAT21A/B · `Ruby2D_2021-2022` → RUBY22
- `20190422_IB_North` / `_South` → IB18W / IB19S. Note these are a *different* deployment
  from `2019-2020-IB-Cortez` (now IB19W), even though it is the same instrument at the same
  MOP line one season later.
- The `Ruby2D_2021-2022/Torrey_2019-2020_MOP582_10m/` and `Torrey_2020-2021_MOP582_10m/`
  subfolders are **empty placeholders** — they do not duplicate TOR19W/TOR20W.
