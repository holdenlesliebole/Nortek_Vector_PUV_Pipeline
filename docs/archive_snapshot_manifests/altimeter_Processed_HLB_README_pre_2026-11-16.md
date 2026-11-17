# Processed_HLB — altimeter and echosounder pipeline products

Holden Leslie-Bole. First published 2026-08-24.

Processed products from `Altimeter_Pipeline`
(github.com/holdenlesliebole/Altimeter_Pipeline). The raw instrument files these descend from
are the `.log` / `.dat` files in the parent `Altimeter_data/` directories, which remain the
source of record. **Nothing here is a substitute for the raw data; it is a cache of a
reproducible computation.**

## Layout

```
Processed_HLB/
  L1_L2_L3/{TorreyPines,SouthSIOPier,SolanaBeach}/   per-deployment ladder
  L4/                                                 merged product, one file per site/depth
  provenance/
    L4_pre_grainsize_20260824/                        L4 as it stood before the 2026-08-24 rebuild
    L4_backup_2026-07-10/                             earlier snapshot
  diagnostics/{figures,validation}/                   QC and survey-anchoring plots
  MANIFEST.sha256                                     checksums, generated on the source machine
```

## The levels

| level | what it is |
|---|---|
| **L1** | Raw instrument record parsed to MATLAB, timestamps converted to UTC. Per burst. |
| **L2** | QC'd altitude: phase-space despike per burst (Goring & Nikora 2002), burst-median reduction with per-burst IQR, then a second phase-space despike on the burst-averaged series to catch whole corrupted bursts. |
| **L3** | Bed level referenced to a baseline, chained across deployments. **Sign convention: positive bedlevel = bed moved UP toward the sensor = accretion.** |
| **L4** | L3 merged with co-located PUV L2/L3 forcing, matched within 15 minutes, plus MOP-hindcast gap fill. 58 fields. This is what analysis code reads. |

`L4_*.mat` each contain one struct `L4`. Fields worth knowing: `time` (burst centre, naive UTC,
~20 min), `bedlevel_mm`, `bedlevel_iqr_mm`, `pctValid`, `deploymentID`, `Hs/Tp/Ef/Ub`,
`tau_b_combined`, `shields_combined`, `puv_valid`, `puv_match_min`.

## Two things to check before using L4

**1. Grain-size provenance.** `tau_b_combined` and `shields_combined` depend on grain size
resolved at BUILD time from `PUV_Pipeline/shared/site_grain_size.m` and stamped into
`L4.Ub_D50`, `L4.Ub_D84`, `L4.Ub_ks_m`. If that table has changed since the build, these fields
are stale. Run `CODES/check_L4_grainsize_current.m` in the pipeline repo; it errors on any
mismatch. This copy was built 2026-08-24 and passed.

**2. Sites and depths.**

| file | site | depth | notes |
|---|---|---|---|
| `L4_TP_{5,7,10,15}m.mat` | Torrey Pines MOP586 | 5/7/10/15 m | survey-anchored; the four-depth ladder |
| `L4_SIO_6m.mat` | South SIO Pier MOP511 | 6 m | sequentially anchored (Scripps Canyon makes the MOP transect a poor survey reference) |
| `L4_SOL_7m.mat` | Solana Beach MOP654 | 7 m | echosounder after Jan 2024, not altimeter |

## Provenance of this snapshot

Built from `Altimeter_Pipeline` at commit `bed28a7` (on `master`). That commit fixes a defect
worth knowing about if you compare against anything older: `build_L4_site` used a single
parameter for both the PUV file name and the grain-size table key, which are different
namespaces. At Torrey and Solana they coincide; at SIO they do not, so the SIO grain-size lookup
failed silently and the build fell back to `ks = 10*D50` with a default D50, a 2.8x roughness
overestimate. **Any SIO L4 built before 2026-08-24 has inflated `tau_b_combined` and
`shields_combined`.** Rank statistics are unaffected (a monotonic rescaling preserves ranks);
anything reading absolute stress is not.

`provenance/L4_pre_grainsize_20260824/` is the pre-rebuild state, kept so the before/after is
checkable rather than asserted.

## Not included

Per-campaign rerun directories from the working tree (`SOL25_full`, `TP25`, `SOL25`, `SIO24`)
are strict subsets of `L1_L2_L3/` and were left out to avoid two copies of the same deployments
with different names.

## Regenerating

```
% in Altimeter_Pipeline/CODES
run_all_and_plot     % L1 -> L2 -> L3, writes outputs/all
run_L4               % L3 + PUV -> L4, writes outputs/L4
check_L4_grainsize_current   % verify before trusting tau_b / shields
```
Requires `PUV_Pipeline/outputs/L2` and `L3`, the CPG toolbox, and `/Volumes/group/MOPS` for
survey anchoring.

## Verifying this copy

```sh
cd /Volumes/group/Altimeter_data/Processed_HLB
shasum -a 256 -c MANIFEST.sha256
```
The manifest was generated on the source machine before transfer, so a mismatch means the copy
is damaged, not that the science changed.
