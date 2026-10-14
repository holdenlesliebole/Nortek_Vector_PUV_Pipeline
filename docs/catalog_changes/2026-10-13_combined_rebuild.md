# Combined rebuild: edge-gap fills, settling velocity and viscosity, seeded tides, provenance

```catalog-change
status: published 2026-10-14.1
files:
  - L2/*/*
  - L3/*/*
  - L4/*/*
  - L4_xspec/*/*
code_ack:
  - L1: off-bed (vertical-transit) pressure QC added, OFF unless a config sets qcOpts.offBedDbar; no L1 rebuilt
  - L2: gap fills no longer extrapolate past segment edges (fillmissing EndValues 'nearest', 8 sites)
  - L3: F&C 2004 nominal-diameter settling velocity (C1 20, C2 1.1); per-segment viscosity seawater_nu(T); per-fraction Rouse; t_tide seeded (rng 0, cboot); NOAA tidal depth required; edge-gap fill fix in currents
  - L3: (after the rebuild) t_tide fallback path moved to Research/toolbox/t_tide_v1.3 (6e70e8b); identical bytes (12/12 external-dep sha256 match the L3 stamps), no output change
  - L4: edge-gap fill fix in eta, boundwave, reflection, reflection_free, velocity_pdf
fallback_ack: false
```

All 65 catalog records were rebuilt on 2026-10-12/13 from one code version, and
every rebuilt file now carries a provenance stamp (`<file>.prov.json`, plus an
embedded `prov` field). Rebuilt: L2-L4 for 45 records, L3-L4 for 12, a full L3
for all 65, and all 9 `L4_xspec` files. L1 was not rebuilt; its stamps are
backfilled and say so.

**Edge-gap fills.** Gap filling extrapolated a straight line past a segment
edge, which turned the last swell samples into a slow ramp. That ramp
contaminated IG and velocity statistics. In synthetic tests a 400-sample edge
gap inflated L4 IG variance about 70x and L2 velocity rms about 6x; the fix
holds both within 10%. In the catalog, L2 Hs moved by at most 3.5 cm, except on
one segment: IB19S/MOP045_7m, 2019-04-22 19:30, which has a 425-sample trailing
gap and moved 15.6 cm. Near-bed velocity statistics moved more on edge-gap
segments (Ub, u_rms: about 4% median, 25% at p95). Storm-event counts are
unchanged on every record; event peak Hs moved by at most 1.2 cm.

**Settling velocity and viscosity.** Settling velocity now uses Ferguson &
Church's natural-sand values for nominal diameters (C1 20, C2 1.1), since grain
sizes come from laser diffraction. It was previously C1 18, C2 1.0, and before
2026-10-07 the smooth-sphere C2 0.4. Kinematic viscosity now comes from each
segment's measured water temperature instead of a fixed 1.0e-6 m2/s. A
pre-registered test against the TBR23 surveys could not tell six settling
formulas apart, so this choice rests on the paper and the measurement method.
The formula spread is about +-15% at 250 um. Across the 65 records, settling
velocity fell by 8-24% (median 16%). The critical Shields number rose by 0.4-11%
(median 6%). The mobilized fraction fell by 0 to 10.7
percentage points (median 1.6). Rouse numbers are now also given at D16, D50
and D84 where a measured grain-size distribution exists (`rouse_D16/D50/D84`,
`transport_params.D_source`).

**Tides.** t_tide is now seeded, so L3 tidal and subtidal currents are
reproducible. They changed once in this release for that reason alone. L3
refuses any record whose tidal depth did not come from NOAA. TOR24W/MOP586_10m
had silently used the t_tide fallback, and now uses NOAA.

**How to tell a new copy from an old one.**
- L3: `transport_params.ws_C1 == 20` and `ws_C2 == 1.1`; `L3.nu` and `L3.T_used` per segment; `L3.tidal.ttide_rng`.
- L2, L3, L4 and xspec: a `.prov.json` sidecar whose `backfilled` field is empty.
