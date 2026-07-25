# Pre-2023 PUV deployment inventory

**Surveyed:** May 5, 2026, from `/Volumes/group/PUV_data/Vector/recopied/`
and `/Volumes/group/DeploymentNotes/`.

> ## 2026-07-24 update — the ExploreV blocker was not real
>
> The May 5 survey concluded that most of this archive was gated behind a
> manual Nortek ExploreV `.VEC → ASCII` conversion on Windows. **That is
> wrong, and three specific claims below are superseded:**
>
> 1. **`.VEC` binary does not need ExploreV.** `L1_raw_to_qc/read_VEC.m`
>    decodes the raw recorder format directly. It is verified bit-exact
>    against the one ASCII export in the archive that overlaps it
>    (`test_read_VEC.m`: 886,319 velocity and 443,131 system rows; velocity,
>    amplitude, correlation, clock and flag columns all exactly equal).
> 2. **A 0-byte `.hdr` is not fatal.** Sampling rate and coordinate system
>    live in the binary's User Configuration record, not just the ASCII
>    header. Every file checked so far reports **XYZ**.
> 3. **`Cardiff1049_2015-2016/`'s `.049` files are not "pre-Vector
>    firmware."** They are ordinary Vector binary missing only the leading
>    `0xA5` sync byte, and parse once it is restored. The "Skip" tier
>    assignment for them is withdrawn.
>
> A fourth finding is new rather than a correction: **the ASCII exports that
> do exist cannot be trusted to be complete.** `TORREY02_1.dat/.sen` cover
> 2019-11-14 to 2019-11-19 — 5.1 days of a 174-day deployment — and both
> terminate mid-line. Ingesting them would have silently yielded 3% of the
> record. `PUV_raw_process` now warns whenever both forms are present.
>
> **Ingested since (all 2026-07-24):** Tier A (`TOR19W`, `TOR20W`, `IB19W`),
> Tier B (`TOR15A/B`, `TOR16B`, `TOR17D`, `CDF15A/C`, `COR16B/D`), and Tier C —
> the multi-year Torrey/Los-Peñasquitos-mouth offshore station from
> `Sarah_LPL_2014-2023/` (`TOR14A`…`TOR19A`). The "8 Hz sampling rate and dead
> real-time clock" once cited as the remaining blocker was **wrong**: those
> instruments are 2 Hz, and the clock runs from a wrong epoch recovered from the
> filenames. Only two deployments are held out (`TOR20A` sequence-counter
> filenames; the 8 Hz surfzone dye). Full account: `recopied_data_backlog.md`.

The current `deployment_registry.m` covers **21 deployments → 40
instrument-deployments → 33 valid records** (after 7 hardware
failures), all from 2023 onward. (A "deployment" is a season-site
campaign with one or more Vectors; "instrument-deployments" is the
sum across all of them, since e.g. TBR23 alone has four Vectors at
MOP580/586 × 5m/7m.)

The `recopied/` folder holds **17 additional historical deployments
back to 2014–2015** that aren't in the registry yet, plus a multi-
year LPL archive with internal sub-folders. These are *additional*
to the 21/40/33 already processed — they would expand the catalog,
not replace any of it.

---

## Deployments not yet in the registry — by file-format readiness

After looking inside each `recopied/` folder, the deployments split
into three groups by what files are actually present:

### Group A — Pipeline-ready (have full `.dat`/`.sen`/`.hdr`/`.VEC` set)

These can be ingested directly. Configs landed in May 2026 commit:

| Deployment folder | Site | Years | Bursts | Notes |
|---|---|---|---|---|
| `Catalina_2021/` (CATISL03) | Catalina Island | Feb-Mar 2021 | multi-burst | → registry: `CAT21A` |
| `Catalina_2021/` (CATISL02) | Catalina Island | Aug 2021 | 1 | → registry: `CAT21B` |
| `Ruby2D_2021-2022/12414_MOP582-30m/` | Torrey MOP582 30m | Nov 2021 | 8 | → registry: `RUBY22.MOP582_30m` |
| `Ruby2D_2021-2022/16310_MOP578_10m/` | Torrey MOP578 10m | 2021-2022 | 2 | → `RUBY22.MOP578_10m` (prefix has `_03_` middle) |
| `Ruby2D_2021-2022/16737_MOP579_6m/` | Torrey MOP579 6m | 2021-2022 | 4 | → `RUBY22.MOP579_6m` |

### Group B — raw `.VEC` binary only

~~Need Nortek `.VEC` → ASCII conversion (run ExploreV first)~~ —
**superseded 2026-07-24**, see the update box at the top. These have only
raw binary `.VEC` files, which `read_VEC` now ingests directly. What
separates the ones already done from the ones still outstanding is the
instrument vintage, not the file format:

| | firmware | fs | clock | status |
|---|---|---|---|---|
| TORREY02 (2019-20, 2020-21), IB-S02 (2019-20) | 3.43 | 2 Hz | valid | **ingested** as TOR19W / TOR20W / IB19W |
| Torrey 1181/1053/1049/0806, Cardiff, Coronado | 1.21 | 2 Hz | wrong epoch, recovered from filenames | **ingested** as TOR15A/B, TOR16B, TOR17D, CDF15A/C, COR16B/D (2026-07-24) |

**Both blockers listed here on 2026-07-23 were wrong** (see
`docs/recopied_data_backlog.md` for the full account). The firmware-1.21
set is **2 Hz, not 8 Hz** — `read_VEC` was mis-deriving the rate from the
User Configuration; it now measures it from the records. The clock is not
dead — it runs from a wrong epoch (2000/2002) and is recovered from the
`MMDDHHMM` filenames (`vec_clock_from_filenames`). No L2 rework or
decimation was needed. All eight are processed and every recovered span
matches the logged deployment date.

| Deployment folder | Site | Years | `.VEC` count |
|---|---|---|---|
| `Torrey1181_2015/` | Torrey Pines | 2015 | 506 |
| `Torrey1053_2016/` | Torrey Pines | 2016 | ~1083 (lowercase `.vec`) |
| `Torrey1049_2017/` | Torrey Pines | 2017 | 849 |
| `Torrey0806_2018/` | Torrey Pines | 2018 | 890 |
| `Coronado4thDeployment_2018/` | Coronado | 2018 | 889 |
| `TorreyPines2020-2021_10meter/` | Torrey MOP582 10m | 2020-2021 | 10 |
| `TorreyPines2019-2020MOP582_10meter/` | Torrey MOP582 10m | 2019-2020 | 11 (`.hdr` exists but is **0 bytes** — incomplete conversion) |
| `Ruby2D_2021-2022/group2/` | Torrey | 2021-2022 | 89 |
| `Ruby2D_2021-2022/Cardiff_2021_MOP669_10m/` | Cardiff MOP669 10m | 2021 | mixed (some bursts have `.hdr`+`.VEC`, some are fragments) |
| Several `Ruby2D_2021-2022/Torrey_*` sub-folders | Torrey | 2019-2022 | empty at top level — must check inside |

### Group C — Older format, may not be Nortek Vector

| Deployment folder | Site | Years | Files | Notes |
|---|---|---|---|---|
| `Cardiff1049_2015-2016/` | Cardiff | 2015-2016 | 1137 `.049` | Looks like pre-Vector firmware (`.049` extension, not Nortek standard). Investigate before attempting conversion. |
| `Cardiffbackbeach_Jan2016/` | Cardiff back beach | Jan 2016 | 19 | Small deployment, format unknown |
| `CoronadoJan_2017/` | Coronado | Jan 2017 | 2 | Almost certainly incomplete (only 2 files) |
| `20190422_IB_North/`, `20190422_IB_South/` | Imperial Beach | Apr 2019 | 10, 9 | Likely partial / failed deployments |
| `2019-2020-IB-Cortez/` | Imperial Beach (Cortez) | 2019-2020 | 7 | Likely partial |
| `Sarah_LPL_2014-2023/` | The offshore station near the Los Peñasquitos lagoon mouth (Torrey Pines State Beach, ~MOP590/591); `.hdr` project path says `…TorreyPines…` | 2014-2023 | nested by year, multiple deployments per season | **~~8 Hz~~ actually 2 Hz; processed 2026-07-24 as Tier C** (`TOR14A`…`TOR19A`) — see `recopied_data_backlog.md`. |

Special folders to check separately:
- `RechargeableBattTest/` — battery test records, not field data
- `Processed_HLB/` — already-processed outputs (manifest.csv generated by Claude)
- `GoPro_Videos/` — video, not Vector data

---

## Site coverage gained from pre-2023

| Site | Pre-2023 deployments | Already in registry |
|---|---|---|
| Torrey Pines | 6 (2015, 2016, 2017, 2018, 2019-2020, 2020-2021, 2021-2022) | TBR23, TOR23W, TOR24S, TOR24W, TOR25S |
| Cardiff | 3 (2015-2016, 2016, Jan 2016) | none — *new site* |
| Coronado | 2 (Jan 2017, 2018) | none — *new site* |
| Imperial Beach | 3 (2019 N, 2019 S, 2019-2020 Cortez) | none — *new site* |
| Catalina | 1 (2021) | none — *new site* |
| LPL (Sarah's archive) | 2014-2023, ~9 yearly sub-deployments | LPL23, LPL24, LPL25A, LPL25B |

**New sites added by pre-2023 catalog:** Cardiff, Coronado, Imperial
Beach, Catalina. The Catalina deployment in particular is in a very
different wave-climate context (offshore island, lower-energy) and
could enrich cross-deployment analysis.

---

## Sarah archive notes (May 5, 2026 survey)

> **⚠ SUPERSEDED 2026-07-24 — processed as "Tier C" in
> `docs/recopied_data_backlog.md`; read that instead.** The constraints below
> were the May-5 guesses and turned out **wrong on both counts**: the archive is
> **2 Hz, not 8 Hz** (`read_VEC` was mis-deriving the rate), and the clock is
> **not dead** — it runs from a wrong epoch and is recovered from the `MMDDHHMM`
> filenames. It was **not** a multi-day pipeline adaptation. 12 of its
> deployments are ingested (the single offshore station near the Los Peñasquitos
> lagoon mouth, ~MOP590/591, named `TOR14A`…`TOR19A`); 4 duplicated Tier B and
> were skipped; `TOR20A` (sequence-counter filenames) and the 8 Hz surfzone dye
> are held out. The paragraphs below are kept only as a record of the original
> survey.

The `Sarah_LPL_2014-2023/` folder is **mislabeled** — its contents are
Torrey Pines deployments, not Los Pe\~nasquitos lagoon. The `.hdr`
files inside identify the source as
`C:\PROJECTS\SoCal2014\TorreyPines\<file>.vec`. This was a multi-year
Torrey Pines record kept by Sarah (2014--2023).

Key constraints for ingesting this archive:

1. **8 Hz sampling rate**, not the pipeline's standard 2 Hz. Adapting
   `PUV_L2_spectral` to handle 8 Hz means rethinking segment-length
   defaults (1 hour = 28800 samples instead of 7200) and downstream
   spectral parameters, or downsampling to 2 Hz on ingest.
2. **Hour-named files.** Each `.dat`/`.hdr`/`.VEC` triplet covers
   1 hour of data with file naming like `12091100.dat`. The pipeline
   currently expects multi-burst single-record deployments with
   `_N`-indexed bursts; hour-named files would need either a directory
   restructure or a new code path.
3. **Embedded RTC date is wrong.** All files claim
   `1/1/2000 12:35 AM` start time. The actual deployment date is
   encoded in the filename (likely `YYMMDDHH` format). Recovering true
   timestamps requires parsing the filename and cross-referencing to
   the checkout spreadsheet `VectorPUV_Winter2019-2020Checkout.xlsx`
   etc.
4. **Sub-structure:** each season folder (e.g., `2014-2015/Raw Data/`)
   contains multiple physically-distinct deployments
   (e.g., `141209_deployment/`, `150127_deployment/`, `150306_deployment/`).
   Each is a separate continuous record at one location with hourly
   roll-over files.
5. The Sarah archive has its own checkout xlsx files inside the folder
   (`VectorPUV_Winter2019-2020Checkout.xlsx`,
   `VectorPUV_Winter2020-2021Checkout.xlsx`) that contain the
   deployment metadata (instrument S/N, lat/lon, doffp, date ranges).
   The 2014-2018 vintage years lack obvious checkout files in the
   archive; metadata may need to come from `SoCal_instruments_201*.xls`
   in `/Volumes/group/DeploymentNotes/`.

**Bottom line:** the Sarah archive is *not* drop-in compatible with
the existing pipeline. Bringing it in is a multi-day effort: pipeline
adaptation for 8 Hz + hour-files, plus filename → date parsing, plus
metadata reconstruction from spreadsheets. The 2023 LPSDYE deployment
(`2023Jan_LPL_DYE01_ADV/`) appears to be a separate single-record
file set with the standard naming convention and is closer to
drop-in.

## Tier reassignment after May 5 survey

Based on the actual file inventory:

| Tier | Deployments | Status |
|------|-------------|--------|
| 1 ✅ | CAT21A, CAT21B, RUBY22 (3 instruments) | Ingested. |
| 1 ✅ | `TorreyPines2019-2020MOP582_10meter` → **TOR19W**, `TorreyPines2020-2021_10meter` → **TOR20W**, `2019-2020-IB-Cortez` → **IB19W** | Ingested 2026-07-24 via `read_VEC`. 2 Hz, valid clock, XYZ. |
| 2A   | `Sarah_LPL_2014-2023/2023Jan_LPL_DYE01_ADV/` | ~~Drop-in single-record~~ — actually a surfzone/intertidal dye study in <1 m water, genuinely 8 Hz; **held out** (unsuitable for the wave-climate pipeline). See `recopied_data_backlog.md`. |
| 2B   | Sarah's 2014-2021 multi-deployment seasons | ✅ **Done 2026-07-24 (Tier C)** — 2 Hz, clock recovered from filenames; 12 processed as `TOR14A`…`TOR19A`, `TOR20A` held out. NOT a multi-day adaptation. |
| 3    | `Cardiff*` (incl. `Cardiff1049_2015-2016`), `Coronado*`, `Torrey1181_2015`, `Torrey1053_2016`, `Torrey1049_2017`, `Torrey0806_2018` | ✅ **Done 2026-07-24 (Tier B)** via `read_VEC` — 2 Hz (not 8 Hz), clock from filenames (not dead). |
| 4    | `Imperial Beach 2019` deployments (`20190422_IB_North/South`) | Already covered by IB18W/IB19S; the separate Nov 2019-May 2020 Cortez record is now IB19W. |
| ~~Skip~~ | ~~`Cardiff1049_2015-2016/` `.049` files~~ | **Withdrawn** — standard Vector binary, only the leading sync byte is missing. Folded into Tier 3. |

---

## Available DeploymentNotes for these deployments

Notes spreadsheets in `/Volumes/group/DeploymentNotes/` cover:

- `SoCal_instruments_2014.xls` / `2015.xls` / `2016-2017.xls` / `2017-2018.xls`
- `DeploymentNotes2018-2019.xls`
- `DeploymentNotes2019-2020.xls`
- `DeploymentNotes2020-2021.xls`
- `DeploymentNotes2021-2022.xls`
- `DeploymentNotes2021Torrey.xls`
- `DeploymentNotes2022-2023.xls`
- `PandPUV2015-2025.xlsx` (master PUV+pressure-only inventory through 2025)
- `PandPUV2015-2025NoSarahNoFalk.xlsx`

So we have field-recorded notes for every year going back to 2014.
None are missing from the database side.

---

## Recommended processing plan

This is meant as a sketch, not a commitment. Things to decide before
launching:

### Tier 1 — high value, low risk
Deployments that fit the existing pipeline cleanly with minimal
config work, give the most marginal benefit.

1. **Ruby2D_2021-2022** — already partially validated against legacy
   pipeline (head-to-head on MOP582_6m showed Hs RMS=5cm, R²=0.98).
   The other 9 instrument-deployments in the Ruby2D folder would
   round out a 6+ instrument cross-shore array at Torrey for the
   2021-2022 winter. `process_ruby2d_one.m` already exists as a
   template; extend to drive all instruments.
2. **TorreyPines2019-2020MOP582_10meter** and
   **TorreyPines2020-2021_10meter** — single-instrument Torrey 10 m
   records. Extends the Torrey time-series back 4 years before TBR23.
   Same pipeline configuration; just need configs.

### Tier 2 — new sites, moderate effort
Deployments that need new configs and possibly new shore-normal /
MOP-station mappings.

3. **Cardiff (3 deployments)** — new site. Need MOP station IDs,
   shore-normal angles, doffp values, instrument metadata. Probably
   1-2 hours of config work + Brian's notes.
4. **Coronado (2 deployments)** — new site, similar work.
5. **Imperial Beach (3 deployments)** — new site, similar work.
6. **Catalina (1 deployment)** — new site, very different orientation
   (offshore island). Probably no MOP station match.

### Tier 3 — deep historical archive
7. **Older Torrey deployments (2015, 2016, 2017, 2018)** — would
   build a long-term Torrey wave climate baseline. Need to confirm
   firmware compatibility (the .sen / .dat format may have evolved).
   Worth a quick spot-check on one record before committing to all.
8. **Sarah's LPL_2014-2023 archive** — 9 years of LPL data is a
   significant artifact. Each yearly sub-folder is probably its own
   deployment. Need Sarah's notes (in `VectorPUV_Winter2019-2020Checkout.xlsx`
   and equivalent) to rebuild configs.

### Tier 4 — likely not useful as-is
9. Short / incomplete deployments: `CoronadoJan_2017` (2 files),
   `20190422_IB_North/South` (10/9 files), `2019-2020-IB-Cortez`
   (7 files). These either failed early or are partial archives.
   Spot-check before committing.

---

## Open questions before processing

- Do older instruments (2015-2018) use the same `.sen` / `.dat`
  format? `parse_hdr` may need version-specific handling. Worth
  spot-checking one .hdr from 2015 vs 2024.
- For new sites (Cardiff, Coronado, Imperial Beach, Catalina), what
  MOP station IDs apply? CDIP MOP coverage may not extend to all
  of these, in which case shore-normal rotation needs an alternate
  source (manual from bathymetry).
- For Sarah's long-term LPL archive, are the yearly sub-folders
  meant to be processed as 1 long deployment per year or split
  into multiple bursts/seasons?
