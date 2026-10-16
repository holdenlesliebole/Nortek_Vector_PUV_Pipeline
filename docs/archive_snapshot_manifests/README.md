# Snapshot manifests

One CSV per `outputs/` snapshot or staging directory that existed on 2026-09-21, written
before the storage-audit cleanup (`Research/STORAGE_AUDIT_2026-09-21.md`, item B). Columns:
`path` (relative to the snapshot root), `bytes`, `mtime_iso`. Twelve of the sixteen
directories were removed on 2026-09-21 by `scripts/remove_verified_snapshots_2026_09_21.sh`
after the local canonical levels were verified identical to the server copy; the four
small ones (`_pre_L3regen_backup_2026-07-26`, `_pre_rouse_backup_2026-08-13`,
`_pre_latlon_xspec_backup_2026-07-28`, `_pre_xspec_regen_backup_2026-07-26`) still exist.
Each manifest records what a snapshot held; the data itself is the superseded state that
the change named in the directory replaced, documented in `CHANGELOG.md`.

## Removed 2026-10-16

Six more directories, 146 GB in all, went to the Trash on 2026-10-16. Their manifests add a
fourth column, `sha256`.

| directory | files | what it held |
|---|---|---|
| `_pre_heading_ws_backup_2026-10-07` | 142 | L2-L4 and xspec before the heading and settling-velocity rebuild |
| `_pre_enu_decl_backup_2026-10-07` | 12 | SOL24, LPL24, LPL25A L1-L4 before the ENU declination fix |
| `_staging_SIO24A_2026-10-07` | 2 | SIO24A staging copy for the `.VEC` heading |
| `_pre_combined_backup_2026-10-12` | 174 | L2-L4 and xspec before the combined rebuild, 10-12 pass |
| `_pre_combined_backup_2026-10-13` | 123 | same, 10-13 pass |
| `_pre_combined_backup_2026-10-14` | 6 | same, 10-14 pass |

Preconditions checked that day:
- All 269 local canonical files matched the server manifest sha256 (catalog 2026-10-14.1).
- The PUV_paper reconciliation (`outputs/validation/reconcile_puv_paper_2026-10-14/`) and the
  Paper_1 consistency pass (`Paper_1/results/pipeline_consistency_20261013/`) were done.

One reference was kept. Paper_1's `run_reflection_band010_20261013.m` reads the old TBR23
`L4.ref` from the heading backup. Those four `ref` and `params` structs are in
`outputs/validation/backup_extracts_2026-10-16/TBR23_L4ref_pre_heading_ws_2026-10-07.mat`
(1.2 GB, checked identical to the backup), and the script falls back to it. Delete that file
once the old column of Paper_1's reflection table is no longer needed.

The removed data is the superseded state; it cannot be regenerated from current code. What
replaced it is in `CHANGELOG.md` and `docs/catalog_changes/2026-10-13_combined_rebuild.md`.
