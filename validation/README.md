# validation/ — model-comparison analyses (ownership map)

This repository serves **two papers**, and this directory is where their
boundary runs. Written 2026-07-30 so a reader arriving from either paper's
citation knows what belongs to what.

| concern | owner | where |
|---|---|---|
| How the in-situ numbers are made (L0→L4 processing, QC, spectral estimation, transfer functions) | **Vector QC paper** (`../Vector_QC_paper/`, JTECH-O) | `L1_*/`, `L2_spectral/`, `L3_*/`, `L4_ig/`, most of `shared/` |
| What the in-situ numbers say about wave models (MOP comparison, matched-grid metrics, bound-energy estimation, alongshore attribution) | **Wave model validation paper** (`../Wave_model_validation_paper/`, Coastal Engineering target) | this directory, plus the model-facing kernels in `shared/` (`shoal_mop_to_site`, `hg91_bound_impedance`, `bound_energy_from_bispectrum`, `recover_P_from_bispectrum`, `bound_wavenumber_spectral`, `excluded_records`) |

The comparison machinery lives here rather than in the paper repo because it
is coupled to the pipeline's data conventions (`L2.S_eta` vs `L2.Spp`, the
L4/L2 index map, the un-doubled one-sided bispectral `P`) and because it is
model-agnostic: pointed at WW3 or ERA5 output instead of MOP, the same
matched-grid and bound-fraction code applies. The paper repo holds only thin
figure scripts that load saved `.mat` from `../outputs/validation/` and plot.

## Layout

- `run_*.m` — catalog sweep drivers. Each writes one `.mat` to
  `outputs/validation/`; the figure registry in
  `Wave_model_validation_paper/docs/architecture.md` maps `.mat` → figure.
- `compare_*.m` — the per-record comparison engines the drivers call
  (`compare_shape_matched`, `compare_derived_quantities`).
- `analyze_*.m`, `diagnose_*.m` — analyses on saved outputs (bispectral β,
  localization reconciliation, COR16B).
- `audit_*.m` — reusable integrity checks (L4 coverage, bulk plausibility,
  registry, timezones). Run these after any reprocessing.
- `test_*.m` — regression tests. Run before quoting a number produced by the
  routine they test (`test_bispectral_bound`, `test_shoal_bin_synthetic`,
  `test_resolution_artifact`, `test_shape_metric_sensitivity`,
  `test_sxy_frame`, `test_sxy_geometry`).
- `sweep_heading_flips.m` — run on any new deployment before analysis.
- `archive/` — spent scaffolding and falsified-hypothesis records, kept
  deliberately with a README mapping each script to the findings doc that
  reports it. **Do not delete.**
- `_retired/` — older pre-archive retirements (segment-length era).

## Versioning note (submission checklist, paper todo #65)

At each paper's submission, tag this repository (and the paper repo) and
freeze the small `outputs/validation/*.mat` figure inputs into the paper
repo's supplementary material, so each paper cites a named, reproducible
version rather than a moving `main`.
