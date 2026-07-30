# validation/archive — spent scaffolding, kept deliberately

**Archived 2026-07-30 (PUV_paper todo #44). Nothing here is deleted, and
nothing here should be deleted.** Several of these scripts encode a
*falsified* hypothesis, and the record of what was ruled out is why the
surviving claims are defensible rather than merely asserted. A reviewer
asking "how do you know it isn't X?" is answered by these files. All figure
inputs are saved `.mat` in `outputs/validation/`, so nothing in the live
figure chain depends on this directory; what lives here is provenance.

Findings docs are in `../../../PUV_paper/docs/`. The older `_retired/`
directory (segment-length comparisons and the `test1*` series) predates this
archive and is left as it was.

## The three named in the archive policy

| script | why it is kept |
|---|---|
| `test_sxy_conditioning.m` | The reason the alongshore metric changed: proved negative `Sxy` correlation is a conditioning artifact of one-signed records (ρ(\|net\|/gross, Sxy_R) = −0.390), not a quality flag. Without it, `findings_consequences_2026-07-25.md` §11.1 reads as a preference rather than a derivation. |
| `test_linear_threshold.m` | Why the linear boundary is a **band, not a line**: ν rises smoothly (F(2,20) = 1.48, p = 0.25) and the crossing moves 0.042–0.108 with the tolerance. The manuscript's ordering-not-value claim rests on this. |
| `test_harmonic_closure_ratio.m` | A *failed* test kept with its diagnosis: it fed `L2.Spp` (pressure) where the established path uses `L2.S_eta`, and the missing `1/Kp²` deflated ν. Cost two wrong diagnoses before it was found (`findings_harmonic_closure_2026-07-29.md`). Superseded by `run_harmonic_closure_sufficient.m` + `compare_shape_matched.m` `opts.fpMultList`. |

## Superseded analysis paths

| script | status |
|---|---|
| `analyze_spectral_shape.m` | **DEPRECATED — the artifact source.** Computed shape metrics after interpolating the model up onto the PUV grid; produced the retracted broadening claim (`findings_resolution_artifact_2026-07-24.md`). Kept as the "before" of fig03. Quote nothing from it. |
| `compare_PUV_MOP.m`, `compare_PUV_MOP_spectra.m`, `run_PUV_MOP_validation.m` | The pre-matched-grid comparison path. `compare_PUV_MOP.m:105–117` is the inlined shoaling block that `shared/shoal_mop_to_site.m` reproduces to 1e-12 (`test_shoal_bin_synthetic.m` TEST A). |
| `analyze_harmonic_band_l2.m` | Impedance-era harmonic-band metrics (`harmonic_band_l2.mat`, kept). β values superseded by the HG91 full theory (doc 15) and then by the bispectral β (doc 17). |
| `analyze_bound_waves.m` | Early bound-wave exploration; superseded by the doc 13–17 chain. |
| `test_harmonics_v2.m` | Early harmonic-metric iteration; superseded by the matched-grid path. |
| `run_full_validation_suite.m` | Early umbrella driver; superseded by the individual `run_*_sweep.m` drivers. |

## Results now written up (script spent, finding lives in the doc)

| script | finding |
|---|---|
| `test_boundary_and_harmonics.m` | `findings_boundary_harmonics_2026-07-25.md` (doc 4): the ordered hierarchy + harmonic localisation; thresholds recomputed 2026-07-28. Saved `boundary_harmonics.mat`. |
| `test_merge_hypothesis.m` | `findings_merge_test_2026-07-25.md` (doc 3): discrepancy organises on Hs/h, not depth. Saved `merge_test.mat`. |
| `test_skewness_proxy.m` | `findings_skewness_proxy_2026-07-29.md` (doc 8): no single nonlinearity parameter reproduces skewness. Discussion §"what the harmonic band is needed for". |
| `analyze_depth_dependence.m` | Settled: no depth trend in anything (all p > 0.16); depth is a proxy for Hs/h. |
| `investigate_SIO_amplification.m` | The canyon end-member investigation behind appendix A3. |
| `test_period_defs.m` | Full-spectrum period treatment (`findings_consequences_2026-07-25.md`). |
| `test_sxy_estimators.m` | The `Sxy_b0` estimator selection (with `test_sxy_conditioning.m` above). |
| `paper1_period_sensitivity.m` | Paper-1 favor: T_b vs T_p sensitivity; result quoted in the Paper 1 repo. |
| `compare_wavenumber_methods.m` | Decision record: Newton solve kept; Wu & Thornton (1986) approximation rejected (referenced from `PUV_paper/docs/architecture.md`). |

## Era scaffolding (pre-reframe phases; no live claim rests on these)

`aggregate_phase2_results.m`, `compare_seglen_phase2.m`,
`run_phase2_all_deployments.m`, `site_summary_phase2.m`,
`test_phase1c_pilot.m`, `test2_cross_instrument.m`,
`test3_tidal_modulation.m`, `test4_reynolds_consistency.m`,
`validate_tidal_decomposition.m`, `check_all_vector_ranges.m`,
`legacy_defect_isolation.m`, `list_seglen_outliers.m`,
`per_instrument_record.m`.
