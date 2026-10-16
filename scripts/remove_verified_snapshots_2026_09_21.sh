#!/bin/bash
# remove_verified_snapshots_2026_09_21.sh
# Removes the twelve outputs/ snapshot and staging directories cleared by the
# 2026-09-21 storage audit (Research/STORAGE_AUDIT_2026-09-21.md, item B).
# Gate already passed: local L1-L4 match the server copy under Processed_HLB
# by name and size, both branches pushed, no script reads these directories.
# Each directory is removed only if its manifest in
# docs/archive_snapshot_manifests/<name>.csv exists and its row count equals
# the live file count. Kept on purpose (small, or still cited):
#   _pre_L3regen_backup_2026-07-26, _pre_rouse_backup_2026-08-13,
#   _pre_latlon_xspec_backup_2026-07-28, _pre_xspec_regen_backup_2026-07-26.
set -u
cd "$(dirname "$0")/.." || exit 1
M=docs/archive_snapshot_manifests
echo "outputs before: $(du -sh outputs | cut -f1)"
for n in _pre_archivererun_backup_2026-07-11 _pre_L4fix_backup_2026-07-26 \
         _pre_clockfix_backup_2026-07-27 _pre_doffp_backup_TOR_2026-07-27 \
         _pre_doffp_backup_2026-07-27 rerun_2026-07-10 \
         _pre_grainsize_backup_2026-07-31 _pre_channeldecoupling_backup_2026-07-10 \
         _pre_headingfix_backup_2026-07-27 _pre_L4meta_backup_2026-07-27 \
         _pre_catalina_backup_2026-07-27 rerun_all_2026-07-11; do
  d="outputs/$n"
  [ -d "$d" ] || { printf 'absent   %s\n' "$n"; continue; }
  rows=$(( $(wc -l < "$M/$n.csv") - 1 ))
  files=$(find "$d" -type f | wc -l | tr -d ' ')
  if [ -s "$M/$n.csv" ] && [ "$rows" -eq "$files" ]; then
    rm -rf "$d" && printf 'removed  %-45s %4s files, manifest ok\n' "$n" "$files"
  else
    printf 'SKIPPED  %-45s manifest rows %s != files %s\n' "$n" "$rows" "$files"
  fi
done
echo "remaining snapshot dirs:"; du -sh outputs/_pre_* outputs/rerun_* 2>/dev/null
echo "outputs after: $(du -sh outputs | cut -f1)"
