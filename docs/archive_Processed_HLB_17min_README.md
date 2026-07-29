# PUV Vector Processed Data — Holden Leslie-Bole

Processed Nortek Vector PUV data from 19 deployments along the San Diego coast.
Generated: 2026-05-01.

## Source

Pipeline: https://github.com/holdenlesliebole/Nortek_Vector_PUV_Pipeline
Commit: 7e4e0f2

## Levels

- **Level2_QC** — Spectral analysis on 17-min segments (2048 samples @ 2 Hz):
  multi-taper PSD (DPSS, NW=4, K=7), surface elevation spectrum S_eta(f),
  bulk wave parameters (Hs, Tp, mean direction, spread), directional Fourier
  coefficients (a1, b1, a2, b2), Z-test, radiation stress.
- **Level3_QC** — Forcing-derived quantities: energy partitioning by frequency
  band, bed velocity / stress, Shields parameter, Rouse number, MOP shoaled
  reference, currents.

L1 (QC'd raw time series) is regenerable from raw data + this pipeline and
is not included here to keep the share size manageable.

## Layout

```
Processed_HLB/
  README.md
  manifest.csv      — per-file index (deployment, instrument, depth, time range, sizes)
  <deployment>/
    Level2_QC/      — *_L2.mat
    Level3_QC/      — *_L3.mat
```

## Conventions

- Coordinate system: x cross-shore (positive onshore), y alongshore (positive north)
- Vertical: NAVD88 (MSL = 0.774 m, MHW = 1.344 m)
- Times: UTC, datetime
- File naming: `<MOP_or_site>_<depth>m_L<N>.mat` (e.g., MOP580_7m_L2.mat)

## Ruby2D note

Ruby2D contains a Level2 reprocess of the legacy archived L1 file using the
multi-taper pipeline, used for the head-to-head validation in
`docs/pipeline_comparison_legacy.md` (in the source repo). It is not a new
deployment.

## Contact

Holden Leslie-Bole <hlesliebole@ucsd.edu>, Scripps Institution of Oceanography.
