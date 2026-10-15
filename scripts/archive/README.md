# scripts/archive: retired one-off scripts

Moved here on 2026-10-14. Each one did a single job on the catalog as it
stood at the time. None is cited by any document, script or test in this
repository, in the sibling research repositories or in `outputs/` (checked by
name with `grep -w` on 2026-10-14), so moving them breaks no reproduction path.
They are kept as a record of what was run. **Do not run them on the current
catalog:**

- They resolve the repository root as `fileparts(fileparts(mfilename('fullpath')))`,
  which from this folder is `scripts/`, not the repository root.
- Several rebuild part of a file in place (one L4 sub-struct, or L3 only) and
  write no provenance sidecar. On the current catalog that makes the file's
  bytes disagree with its sidecar, and `scripts/copy_to_server.m` refuses it.
  `PIPELINE_NOTES.md` ("A partial L4 rebuild destroys everything it does not
  recompute") explains the other hazard.
- The records and code they targeted have since been rebuilt (catalog
  2026-10-14.1).

| script | last commit | what it did |
|---|---|---|
| `migrate_NN24_to_TOR23W_SOL23.m` | 2026-05-22 | moved NN24 outputs into the TOR23W and SOL23 folders |
| `reprocess_all_L2_L3.m` | 2026-05-22 | deleted and rebuilt every L2 and L3 |
| `rerun_validation_mtm.m` | 2026-05-22 | TBR23/MOP580_7m with full multitaper, then MOP validation (Welch against MTM) |
| `rerun_ruby22_mop579_6m.m` | 2026-05-22 | L1 and L2 for RUBY22/MOP579_6m after the saturation-robust pressure QC fix |
| `rerun_ruby22_L2_and_phase2.m` | 2026-05-22 | L2 for the three RUBY22 records with the HsMaxToHRatio filter, then Phase 2 |
| `rerun_ruby22_phase2.m` | 2026-05-22 | Phase 2 Hs^2-scaling test for RUBY22 |
| `regen_stale_L3_2026_07_26.m` | 2026-07-27 | L3 for 11 records whose L2 was newer than their L3 |
| `regen_stale_xspec_2026_07_26.m` | 2026-07-27 | L4_xspec where member L4s had changed |
| `reprocess_heading_fix_2026_07_27.m` | 2026-07-27 | L1-L4 for TOR16B/C/D after the July heading correction (that `headingFix` was itself retired on 2026-10-07) |
| `rebuild_xspec_latlon_fix_2026_07_28.m` | 2026-07-28 | L4_xspec for RUBY22, TOR24S, TOR24W, TOR25S after the coordinate fix |
| `patch_L4_moments_pdf.m` | 2026-07-28 | added `L4.moments` and `L4.pdf` to two heading-fix L4 files |
| `refresh_L4_boundwave.m` | 2026-07-28 | added or refreshed `L4.boundwave` in every L4 in place |
| `refresh_L4_reflection_bands.m` | 2026-07-28 | refreshed `L4.ref` with the band-aware reflection in place |
| `regen_L3_grainsize_2026_07_31.m` | 2026-07-31 | L3 after the BetterSizer S3 Plus grain sizes were adopted |

The current way to rebuild any level with provenance is
`scripts/rerun_heading_ws_2026_10_07.m` (stage `combined`, then `xspecprov`),
driven by `scripts/run_L4_refresh_watchdog.sh`.
