# CLAUDE.md — PUV_Pipeline

Nortek Vector PUV processing pipeline: raw instrument files → QC'd timeseries →
spectra → wave forcing → IG / nonlinear diagnostics. Public repo
(`github.com/holdenlesliebole/Nortek_Vector_PUV_Pipeline`), so it is written to be
site-agnostic — everything site-specific lives in one config file per deployment.

Parent context: `../CLAUDE.md` (Scripps research root). This file governs work
*inside* `PUV_Pipeline/`.

---

## Session startup — read these first

1. **`docs/todo.md`** — the live tracker. Its top block is the current state.
   *(Local-only: gitignored, so it is absent in a fresh clone.)*
2. **`docs/pipeline_levels.md`** — per-level status, counts, what is verified vs
   deferred. **Authoritative on status** if it disagrees with `PIPELINE_NOTES.md`.
3. **`PIPELINE_NOTES.md`** — design rationale behind the QC and processing
   choices. Explains *why*, not *what is done*.
4. **`README.md`** — user-facing entry point: requirements, quick start, how to
   configure a deployment.
5. **`config/deployment_registry.m`** — the definitive list of known deployments.

**Not current — do not read as status:** the dated `docs/RESULTS_*.md` and
`docs/*_2026-07-09.md` files are historical run logs. They record what was
actually run at the time and are kept deliberately; never "correct" them.
Likewise `outputs/_*_backup_*/` and `outputs/rerun_*/` are frozen snapshots.

---

## Current state (2026-07-24)

- **Catalog:** 65 instrument-records across 46 deployments, at every level
  L1–L4; 9 deployments also have `L4_xspec` (the multi-instrument ones).
- **Canonical processed copy:** `/Volumes/group/PUV_data/Vector/Processed_HLB/`,
  laid out `<DEPLOYMENT>/Level{1,2,3,4}_QC/<label>_*.mat`, with `manifest.csv`
  and a generated `README.md`. Push with `scripts/copy_to_server.m` (idempotent,
  byte-size skip; it also regenerates the manifest and README).
- **Levels L1–L4 are complete and verified.** L5 (PUV↔altimeter merge) is planned,
  not built.
- **Pre-2023 archive:** Tier A is done (`TOR19W`, `TOR20W`, `IB19W`, decoded from
  raw `.VEC`). Tier B is scoped and outstanding — see
  `docs/recopied_data_backlog.md`.

---

## Durable decisions a new session must know

**Two ingest paths, and the ASCII one can lie.** L1 reads either the Nortek
ExploreV ASCII export (`.dat`/`.sen`/`.hdr`) or the raw recorder binary
(`.VEC`/`.vec`/`.049`) via `L1_raw_to_qc/read_VEC.m`. ExploreV is *not* required.
Auto-detection prefers ASCII when a `.dat` exists, which is wrong when an export
was interrupted — `TORREY02_1.dat` holds 5.1 days of a 174-day record. Set
`instr.rawFormat = 'VEC'` to force the binary; a warning fires whenever both
forms are present. Sampling rate and coordinate system come from the binary's
User Configuration record, so a 0-byte `.hdr` is not fatal.

**One burst per raw file.** Both ingest paths treat each `_N` recorder file as a
separate burst. Do not concatenate them: L1's battery-cutoff rule truncates the
record at the first gap over a second, and the 100 MiB split seams can lose a
second, which silently discards months of good data.

**The pipeline is standalone through L4.** L1–L4 must run without any altimeter
data. Coupling to the altimeter pipeline happens only at L5.

**Coordinates.** L1 outputs the buoy frame (+x **West**, +y **North**, +z Up).
L2 rotates to shore-normal (+x onshore, +y alongshore-north) from either
`instr.shorenormal` (manual, any site) or `instr.mopStation` (CDIP, California).
Site-wide conventions (cross-shore origin, MOP numbering, NAVD88 datums) are in
`../CLAUDE.md`.

**L2 segments are 1 hour** (`segLen = 7200` @ 2 Hz), switched from 17 min in
May 2026. The legacy 17-min archive lives at `Processed_HLB_17min/` and exists
only to reproduce the May 2026 mean-flow validation.

**`doffp` is required and it matters.** Pressure-sensor height above the bed, in
metres, from the field log — for San Diego, `/Volumes/group/DeploymentNotes/`.
L2 uses a single fixed value per deployment, so records where the bed moved a lot
carry extra uncertainty (see IB19W). Also set `cfg.qcOpts.Tvalid` to the site's
water-temperature range; the `[-2 40]` default is a wide safety bound, not a
good site value.

**`TBR23` vs `TOR23S`.** `TBR23` breaks the `SITE+year+season` convention but is
kept because Paper_1 depends on the name. `TOR23S` is a registry alias to the
same config; `cfg.name` stays `'TBR23'`. A full rename is a coordinated
cross-repo cleanup — see `docs/todo.md`.

---

## Working rules

- **All code is MATLAB.** Run with
  `/Applications/MATLAB_R2025a.app/bin/matlab -nodisplay -nosplash -nodesktop -batch "startup_puv; …"`.
  `startup_puv` puts the whole repo on the path.
- **Batch over the catalog** with `PUV_L{1,2,3,4}_run_all` — each skips
  deployments that already have outputs, so adding one deployment is cheap. The
  single-deployment `PUV_L*_driver` scripts hardcode `deployment_name` at the top.
- **Copy raw to local first.** `copy_raw_to_local(cfg)` caches into `raw_cache/`
  (gitignored); reading multi-GB files over the SMB mount is far slower. Check
  the mount is up before any run — see `../server_io_patterns.md`.
- **Outputs are not versioned.** `outputs/` is gitignored; it is reproducible
  from raw + code, and the durable copy is on the server.
- **One-off session scripts stay untracked.** Scripts written to accomplish a
  single task do not belong in the repo.
- **Verify before claiming.** New or reprocessed records get a magnitude check
  (Hs, Tp, depth vs nominal, W≈0) and, where a CDIP MOP station exists, an Hs
  comparison against it. See `docs/recopied_data_backlog.md` for the Tier A
  numbers as a worked example.
