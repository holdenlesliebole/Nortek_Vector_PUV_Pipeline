# Changelog

Code-level changes, newest first. Commit hashes refer to this repository.
What each change did to the published catalog, with measured sizes, is in
`docs/catalog_changes/`; the server copy has its own `CHANGELOG.md` per
catalog version. Changes before 2026-10-07 are recorded in `PIPELINE_NOTES.md`
and the dated `docs/RESULTS_*.md` logs.

## Unreleased (2026-10-14, repository polish)

- L3 drivers (`PUV_L3_driver`, `PUV_L3_run_all`) pass the config's
  `l1_qc_opts(cfg).Tvalid` to `PUV_L3_transport`. They used the [-2 40]
  default, so a thermistor reading inside that range but outside the site range
  set the segment's viscosity. The catalog was not affected: it was built by
  `rerun_heading_ws_2026_10_07.m`, which already passed the config value. Test:
  `validation/test_L3_driver_tvalid.m` (6/6; 0/6 on the previous drivers).
- All `PUV_L{1..4}_driver`, `PUV_L{1..4}_run_all` and `PUV_L4_xspec_run_all`
  end with an error naming every config that threw and every record not
  written, instead of printing "Done.". Test:
  `validation/test_driver_loud_failures.m` (9/9; 0/9 on the previous
  drivers).
- `PUV_L1_driver` and `PUV_L2_driver`: the catch block formatted the stack
  with `arrayfun(@(s) string(s.name), ...)`, which throws
  `MATLAB:invalidConversion`, so the first failed instrument aborted the
  deployment with that error in place of the real one. Found by the test above.
- `run_L4_refresh_watchdog.sh` rebuilds `L4_xspec`, with provenance, once
  after its last MATLAB launch, for every deployment with an xspec and at least
  one record that passed in any launch (new stage `xspecprov` in
  `rerun_heading_ws_2026_10_07.m`; combined launches run with
  `skipXspec = true`). Before, xspec ran at the end of each launch, so a
  launch killed for a hang skipped it. On a hang the watchdog now kills its own
  launch's process tree, not the first MATLAB matching a pattern. Test:
  `validation/test_watchdog_xspec.sh` (4/4; 3/4 on the previous watchdog,
  which never rebuilt the xspec of a deployment whose record passed in a
  launch later killed for a hang). Stage `xspecprov` was also run for SOL23
  into a scratch tree: the result equals the catalog xspec in every field but
  `builtAt`, and its sidecar links both parent L4 build_ids.
- `validation/run_all_tests.m`: one entry point for the self-contained tests.
- 14 unreferenced one-off scripts moved to `scripts/archive/` (README there).
- `L2_spectral/test_pressure_correction_synthetic.m` adds its own repository's
  `shared/` instead of an absolute path on the maintainer's machine.
- Docs: README, `docs/pipeline_levels.md`, `PIPELINE_NOTES.md`,
  `docs/NEW_DEPLOYMENT.md` updated for the changes below.

## 2026-10-14

- `shared/ws_to_D.m`: grain diameter from settling velocity, the inverse of
  `settling_velocity`, with `validation/test_ws_to_D_20261014.m` (4efe10b).
- `copy_to_server`: a baseline push now writes the change entries into the
  server `CHANGELOG.md` (it dropped them when no file counted as changed)
  (8552249).
- Change entries: the t_tide path move needs no rebuild (22a89fe); all 65
  records got L2-L4 in the combined rebuild (82a094d).

## 2026-10-13

- `l1_qc_opts`: `offBedDbar` is absent from the defaults (absent = off), so
  existing L1 `qc.opts` still equal their config (a4ee50d; supersedes the
  explicit `Inf` of 1d3acf2).
- Combined rebuild: when L2 is rebuilt, storm events are reported, not gated;
  the CDIP storm-reference data stays a hard gate. The L4 Z gate fails only on
  a new flag, so an already-flagged record (RUBY22/MOP582_30m) can be rebuilt
  (761eb86).
- Catalog change entry for the combined rebuild (9175471).

## 2026-10-12

- t_tide fallback path and docs point at `Research/toolbox/t_tide_v1.3`
  (4be9065, merged 6e70e8b). Same bytes as before (12/12 external-dependency
  SHA-256 match the L3 stamps).

## 2026-10-09

- **Provenance** (0c1ecc0, f2167bd, 5afd08c). `shared/build_provenance`,
  `write_prov_sidecar`, `read_prov`, `check_prov`, `prov_applied`: every output
  gets an embedded `prov` block and a `<file>.prov.json` sidecar with build_id,
  git hash, resolved key functions, parents' build_ids, applied choices,
  fallbacks and the SHA-256 of the saved bytes. `shared/external_deps` lists
  the 12 out-of-repo files L3 needs and the stamps record their hashes.
  `scripts/backfill_provenance.m` writes marked sidecars for files built
  before stamping. `copy_to_server` refuses files by `check_prov` (HARD and
  SOFT refusals) and requires a change entry in `docs/catalog_changes/` for
  any file whose bytes changed. Tests: `validation/test_provenance.m` (14/14).
- **Gap fills** no longer extrapolate past segment edges: all 18 `fillmissing`
  calls in L2-L4 use `'EndValues','nearest'`; `PUV_L3_currents` fits t_tide only
  over the span where velocity exists (d95012c). Test:
  `validation/test_fillmissing_endvalues.m` (40806d0).
- **L3 sediment physics** (247e3d0). `settling_velocity` gains shape options;
  default `natural_nominal` (Ferguson & Church 2004, C1 20, C2 1.1), and it
  returns the constants used. `seawater_nu` and `soulsby_whitehouse_theta_cr`
  move into `shared/` (the latter had been reached through Paper_1 on the
  path). `PUV_L3_transport(L3, L2, opts)`: per-segment viscosity from
  `L2.Tmean`, per-segment ws, theta_cr and tau_cr, per-fraction Rouse
  (`rouse_D16/_D50/_D84`). Test: `validation/test_L3_transport_closure.m`.
- **Deterministic t_tide**: each call runs under `rng(0,'twister')` and
  restores the caller's state (3ccbcd9). Test:
  `validation/test_l3_currents_determinism.m` (reads outputs).
- **NOAA tidal depth required** in the combined rebuild; `L3.tidal.depth_source`
  and `ttide_rng` are stamped (1ae303d). The combined stage rebuilds L3 in full
  for every record (441bbaf).
- **Off-bed pressure QC**: `puv_channel_qc` can fail `valid_p` during vertical
  transit (a61cdaa); left off until the next L1 rebuild (1d3acf2, a4ee50d).
  Scenario E in `L1_raw_to_qc/test_puv_channel_qc.m`.
- Disputed headings: LPL23 has no usable log value and TOR25S/MOP586_10m is not
  disputed; 12 of 45 listed (e41154a).
- `copy_to_server` change-entry checks (B2/B4), combined record lists,
  generalized watchdog (378959e).

## 2026-10-08

- `audit_L4_coverage` checks L4 content against L2 (`L4.eta.depth` against
  `L2.depth` on time-matched segments), not only alignment (b1b5479, 316dd0b).
- `rerun_heading_ws` stage `L4`: L4-only rebuild of content-stale L4s (0052b61);
  fresh parallel pool per record, `run_L4_refresh_watchdog.sh` for hangs,
  backups written to `.part` and renamed when complete (c6b8f3d).
- `startup_puv` clears its temporaries (7d6a282).

## 2026-10-07

- **ENU declination**: `enu_to_buoy_frame.m`; the ENU branch of
  `PUV_raw_process` adds the IGRF declination and L1 stamps
  `rotation.coordSystem` and `rotation.declinationApplied` (53888d0). Test:
  `validation/test_enu_declination_closure.m`.
- **Tvalid in configs**: 12 configs set `cfg.qcOpts.Tvalid = [9 26]` on the
  line (the July reruns had injected it); QC defaults factored into
  `l1_qc_opts.m`; `validation/audit_L1_qcopts.m` (f995fca).
- `startup_puv` keeps `.claude/` worktrees, `.git`, `outputs` and `raw_cache`
  off the path; worktree copies had shadowed this checkout (f3159a0).
- **Heading rule**: nine records take the logged mount heading where the
  compass drifts (COR16B, TOR16A-D, TOR17A, TOR17C, TOR24S/MOP586_5m and _7m);
  the TOR16 `headingFix` is retired; `shared/heading_disputed_records.m` lists
  records with log and compass more than 10 deg apart (bde01b2, f357fe4,
  e2247c9). SIO24A reads `.VEC` with the corrected file prefix.
- L3 stamps the settling-velocity C2 used (01fab01).
- `scripts/rerun_heading_ws_2026_10_07.m`: staged catalog rebuild with
  preflight, before/after gates, raw-cache size checks and refusal to save on a
  silent CDIP fallback (5bc7c3e, 0c80de4, 66de47f, a529cf7);
  `scripts/rerun_enu_declination_2026_10_07.m` (53888d0, 49b73d9).
