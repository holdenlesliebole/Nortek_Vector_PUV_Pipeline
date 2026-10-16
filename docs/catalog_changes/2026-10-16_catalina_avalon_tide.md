# Catalina tidal depth from Avalon (9410079) instead of La Jolla (9410230)

```catalog-change
status: pending
files:
  - L3/CAT21A/*
  - L3/CAT21B/*
fallback_ack: false
```

CAT21A and CAT21B now set `cfg.tideStation = '9410079'` (Avalon, Santa Catalina
Island; 33.345, -118.325 from the NOAA mdapi station record), 1.92 km from the
surveyed instrument position. Their L3 was rebuilt on 2026-10-16 with the plain
L3 driver. Before this, both used 9410230 La Jolla, 110 km away, because the
toolbox `getztide2.m` hardcoded it.

Only `L3.tidal.depth_pred`, `L3.tidal.station`, `L3.tidal.station_source` and the
provenance block changed. Every other L3 leaf is bit-identical to the 2026-10-14.1
files, including the t_tide currents, which come from the measured velocities.
L1, L2 and L4 do not read the tide station.

Size of the change in `depth_pred`, over valid segments:

| record | n | rms | max | mean |
|---|---|---|---|---|
| CAT21A | 1860 | 2.54 cm | 7.90 cm | -0.04 cm |
| CAT21B | 4 | 1.63 cm | 1.71 cm | +1.62 cm |

Fit of each prediction to the measured CAT21A depth:
- The total residual is about the same: 3.49 cm rms for La Jolla, 3.52 cm for
  Avalon (hourly grid, mean removed). It is dominated by non-tidal water level,
  which neither prediction contains.
- A constituent fit to the measured depth favors Avalon on the large terms.
  Vector error is 1.3 cm against 2.5 cm on M2, 0.9 against 2.0 on S2, and 0.4
  against 0.6 on O1. It is 1.4 against 1.1 on K1.

The mount-movement check (measured depth minus prediction) gives the same
answer with either station: a trend of +0.11 cm/30 d with La Jolla and
+0.15 cm/30 d with Avalon.

How to tell the files apart: new files carry `L3.tidal.station = '9410079'`
and `prov.applied.tide_station = '9410079'`; old ones have no `tidal.station`
field.
