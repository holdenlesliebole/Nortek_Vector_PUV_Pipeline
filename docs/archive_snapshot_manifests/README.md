# Snapshot manifests

One CSV per `outputs/` snapshot or staging directory that existed on 2026-09-21, written
before the storage-audit cleanup (`Research/STORAGE_AUDIT_2026-09-21.md`, item B). Columns:
`path` (relative to the snapshot root), `bytes`, `mtime_iso`. Twelve of the sixteen
directories were removed on 2026-09-21 by `scripts/remove_verified_snapshots_2026_09_21.sh`
after the local canonical levels were verified identical to the server copy; the four
small ones (`_pre_L3regen_backup_2026-07-26`, `_pre_rouse_backup_2026-08-13`,
`_pre_latlon_xspec_backup_2026-07-28`, `_pre_xspec_regen_backup_2026-07-26`) still exist.
Each manifest records what a snapshot held; the data itself is the superseded state that
the change named in the directory replaced, documented in `docs/todo.md`.
