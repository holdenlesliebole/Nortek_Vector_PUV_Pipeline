# PUV–Altimeter Correlation Plan (PUV Pipeline Perspective)

Written from the PUV pipeline side to complement
`Altimeter_Pipeline/docs/puv_correlation_plan.md`.

Last updated: April 6, 2026

---

## Overview

The PUV pipeline (L1→L2→L3) produces 17-minute wave forcing statistics.
The altimeter pipeline produces burst-averaged bed level at ~17–30 min
cadence. Correlating these two datasets enables direct observation of
how wave forcing drives sediment transport at the bed — the fundamental
question underlying both the TBR23 morphology paper and the wave dynamics
spinoff.

---

## PUV products most relevant for bed level correlation

### Primary (from L2/L3, per 17-min segment)

| Product | Field | Units | Why it matters |
|---|---|---|---|
| Bed orbital velocity | `L2.Ub` | m/s | Directly drives sediment mobilization |
| Bed shear stress | `L2.tau_b` | Pa | Determines if sand moves (Shields threshold) |
| Shields parameter | `L3.shields` | — | Dimensionless mobilization metric |
| Mobilization flag | `L3.mobilized` | logical | Binary: is sand moving? |
| Wave height | `L2.Hs` | m | Bulk forcing metric |
| Energy flux | `L2.Ef` | W/m | Wave power arriving at the site |
| Bottom energy flux | `L3.Fb` | W/m | Energy flux evaluated at bed |
| Cumulative Fb | `L3.Fb_cum` | J/m | Integrated forcing over time |
| Velocity skewness | `L2.vmom.skewness` | — | Onshore transport asymmetry |
| Acceleration asymmetry | `L2.vmom.asymmetry` | — | Pitched-forward wave shape |
| u|u|² moment | `L2.vmom.u_uabs2` | m³/s³ | Energetics bedload flux proxy |
| |u|³ moment | `L2.vmom.u_abs3` | m³/s³ | Energetics suspended load proxy |
| Mean cross-shore current | `L2.uMean` | m/s | Undertow (offshore transport) |
| Mean alongshore current | `L2.vMean` | m/s | Longshore transport |
| Subtidal cross-shore | `L3.subtidal.u` | m/s | Wave-driven undertow (tidal removed) |
| Swell energy flux | `L3.Ef_swell` | W/m | Swell vs sea forcing |
| Sea energy flux | `L3.Ef_sea` | W/m | Local wind wave contribution |
| Peak period | `L2.Tp` | s | Wave type indicator |
| Water depth | `L2.depth` | m | Tidal modulation of forcing |

### Secondary (useful but not primary drivers)

| Product | Field | Why |
|---|---|---|
| TKE | `L2.reynolds.TKE` | Turbulent mixing intensity |
| Reynolds stress uw | `L2.reynolds.uw` | Vertical momentum flux |
| Wave direction | `L2.meanDir` | Oblique vs shore-normal forcing |
| Rouse number | `L3.rouse` | Suspension vs bedload regime |
| Orbital excursion | `L2.Aw` | Bedform-scale transport |
| Tidal depth prediction | `L3.tidal.depth_pred` | Tidal phase at time of transport |

---

## Timestamp alignment

### Agreement with altimeter-side proposal

The ±5 min nearest-neighbor approach is correct for several reasons:

1. **Both are integrated quantities** — PUV segments are 17-min averages,
   altimeter bursts are 2.5–15 min medians. Interpolation would be
   physically meaningless.

2. **Cadence is similar** — PUV = 17.07 min, altimeter = 17–30 min.
   Nearest-neighbor within ±5 min will match most segments when both
   instruments are running.

3. **No shared clock** — the instruments have independent clocks. PUV
   clocks are confirmed UTC (validated against NOAA tide gauge, lag = 0.0
   hours). Altimeter clocks have no drift measurement. A ±5 min tolerance
   accommodates small clock offsets.

### PUV-side implementation

```matlab
% For each altimeter burst timestamp t_alt:
[dt, idx] = min(abs(L2.time - t_alt));
if dt < minutes(5)
    % Match: copy L2 fields to L4 struct
else
    % No match: set PUV fields to NaN
end
```

### Recommended addition: flag tidal phase

Since transport is nonlinear in depth, the tidal phase matters. The L4
struct should include `L3.tidal.depth_pred` (from NOAA) at each matched
timestamp, enabling analyses conditioned on tidal stage (e.g., does the
same Shields parameter produce different bed change at high vs low tide?).

---

## Agreement with proposed analysis approaches

### The 5 transport relationships — assessment

| # | Proposed relationship | PUV fields | Assessment |
|---|---|---|---|
| 1 | Excess shear stress: dz/dt ~ (τ - τ_cr)^n | `L2.tau_b`, `L3.shields` | **Agree.** This is the most physically grounded. Use Shields - θ_cr rather than raw τ for universality. |
| 2 | Energy flux: dz/dt ~ Ef | `L2.Ef`, `L3.Fb` | **Agree, but use Fb** (bottom energy flux) not total Ef. Fb is more physically relevant to bed processes. |
| 3 | Velocity cubed: dz/dt ~ <|u|³> | `L2.vmom.u_abs3` | **Agree.** This is the Bailard energetics formulation. Already computed in L2. |
| 4 | Velocity moments: dz/dt ~ <u|u|²> | `L2.vmom.u_uabs2` | **Agree.** Captures the directional asymmetry (net onshore vs offshore flux). This is distinct from |u|³ which is unsigned. |
| 5 | Equilibrium/disequilibrium | `L2.Hs`, `L2.depth` | **Agree with caution.** Dean-type equilibrium models need a beach profile shape assumption. Better to test empirically rather than prescribe the equilibrium form. |

### Recommended additions

**6. Undertow-driven offshore transport**: `L3.subtidal.u` captures the
wave-driven return flow. During storms, undertow intensifies and drives
offshore bar migration. The correlation dz/dt vs subtidal.u may show a
distinct offshore-transport signal during storm events.

**7. Swell vs sea forcing decomposition**: Test whether bed change
correlates better with `L3.Ef_swell` or `L3.Ef_sea`. If swell dominates
morphological response (longer waves feel the bottom more), this would
have implications for using the MOP model for morphology prediction.

**8. Cumulative forcing between survey dates**: Rather than instantaneous
dz/dt vs forcing, integrate both sides: cumulative Fb between survey dates
vs net bed level change. This reduces noise from individual storm events
and tests the bulk transport relationship.

---

## Pitfalls to watch for

### 1. Coordinate conventions

**PUV shore-normal rotation**: After L2 processing, `uMean` and velocity
moments are in shore-normal coordinates (+x onshore, +y alongshore north)
if the CDIP THREDDS rotation succeeded. If it fell back to buoy coords
(+x West, +y North), the cross-shore direction is approximate. Check
`L2.shorenormal` — if NaN, the rotation failed.

**Altimeter sign convention**: accretion = positive, erosion = negative.
This means a **positive** dz/dt with a **negative** (offshore) uMean
indicates offshore-driven accretion — which would be unusual. The sign
conventions are consistent as long as both sides document them.

### 2. Spatial offset

At SIO Pier, the PUV and altimeter are on **different pipes** (~2m apart).
At Torrey Pines, they're co-located (<0.5m). For SIO, the spatial offset
introduces a decorrelation, especially for small-scale bedforms. For
Torrey Pines, the co-location is ideal.

### 3. Temporal offset between forcing and response

Bed change may lag wave forcing by hours to days:
- **Storm erosion**: response begins immediately during the storm but
  continues after the storm passes (settling, gravity flows)
- **Recovery accretion**: begins days after a storm when milder waves
  push sand back onshore
- Test lagged correlations: dz/dt(t+lag) vs forcing(t) for lag = 0
  to 48 hours

### 4. Depth correction for altimeter

The altimeter measures distance from sensor to bed. If the sensor pipe
bends (which happens during storms — same issue as PUV), the measured
distance changes without actual bed change. The altimeter pipeline
handles this with tilt correction (`a_corrected = a * cos(α)`), but
the PUV tilt data could provide an independent check if the instruments
are co-located.

### 5. Clock drift on altimeters

The altimeter clocks have **no drift measurement** (unlike PUV which has
measured drift at recovery). Over a 30-day deployment, even 1 sec/day
drift = 30 sec offset. This is within the ±5 min tolerance, but for
phase-sensitive analyses (e.g., does bed change lead or lag the wave
forcing?) the clock uncertainty limits temporal resolution to ~minutes.

### 6. doffp changes from bed level change

The PUV's `doffp` (sensor height above bed) changes as the bed accretes
or erodes. Our L2 uses a fixed doffp from deployment notes. The altimeter
data could provide a **time-varying doffp** correction:
```
doffp(t) = doffp_initial - Δz_altimeter(t)
```
This would improve the bed velocity and bed stress estimates, especially
for deployments with large bed change (>10 cm). Implementation: add as
an optional input to L2 reprocessing, not as a real-time correction.

### 7. Storm-period data gaps

The most scientifically interesting periods (storms) are when both
instruments are most likely to fail. The PUV has MOP gap-filling for
wave forcing context. The altimeter data gaps during storms mean we may
not observe the actual erosion — only the pre-storm and post-storm
bed level. The L4 struct should flag storm periods and distinguish
between "no bed change observed" and "no data during this period."

---

## L4/L5 struct design — PUV perspective

### Agree with altimeter-side backbone

Using altimeter timestamps as the backbone makes sense because:
- Altimeter is the "response" variable (what we're trying to explain)
- PUV is the "forcing" variable (what drives the response)
- Regression/correlation analyses naturally have the response on the
  left side

### Recommended L5 struct additions (from PUV side)

```
L5.time                    % altimeter burst timestamps (backbone)
L5.dz_mm                   % bed level change from altimeter
L5.dzdt_mm_hr              % bed change rate from altimeter
L5.alt_quality             % altimeter quality flag

% PUV forcing (matched to altimeter timestamps)
L5.Hs                      % significant wave height
L5.Tp                      % peak period
L5.Ef                      % total energy flux
L5.Fb                      % bottom energy flux
L5.Ub                      % bed orbital velocity
L5.tau_b                   % bed shear stress
L5.shields                 % Shields parameter
L5.mobilized               % mobilization flag
L5.skewness                % velocity skewness
L5.asymmetry               % acceleration asymmetry
L5.u_abs3                  % |u|^3 moment
L5.u_uabs2                 % u|u|^2 moment
L5.uMean                   % mean cross-shore current
L5.vMean                   % mean alongshore current
L5.subtidal_u              % subtidal cross-shore (undertow)
L5.Ef_swell                % swell energy flux
L5.Ef_sea                  % sea energy flux
L5.depth                   % water depth
L5.tidal_depth             % NOAA tidal prediction
L5.Fb_cum                  % cumulative bottom flux
L5.puv_match_dt_min        % timestamp offset of match (minutes)
L5.puv_valid               % true if PUV data available
L5.storm_flag              % true during detected storm events

% Metadata
L5.site                    % site name
L5.puv_deployment          % PUV deployment name
L5.alt_deployment          % altimeter deployment name
L5.D50                     % grain size used
L5.doffp                   % PUV sensor height above bed
```

---

## Implementation priority — agree with altimeter side

1. **SIO Pier 6m** — simplest, longest record, but PUV-altimeter spatial
   offset and the canyon focusing effect complicate interpretation
2. **Torrey Pines 5m** — co-located, clean 3-month records, ideal for
   method development. TBR23 period has concurrent beach surveys.
3. **Torrey Pines 7m/10m** — extend to cross-shore array
4. **Torrey Pines full array** — multi-depth transport analysis
5. **Solana Beach** — lowest priority due to pipe relocation issues

### Recommendation: start with TOR24S MOP586

The TOR24S spring 2024 deployment has the best combination of:
- Co-located PUV + altimeter at 5m, 7m, 10m depths
- High valid-segment rates (90-99%)
- Multiple storm events (6-7 per instrument)
- Beach survey data available for validation
- No major instrument failures

---

## References to PUV Pipeline code

- L2 outputs: `PUV_Pipeline/outputs/L2/{deployment}/{label}_L2.mat`
- L3 outputs: `PUV_Pipeline/outputs/L3/{deployment}/{label}_L3.mat`
- Deployment configs: `PUV_Pipeline/config/{deployment}_config.m`
- Pipeline repo: https://github.com/holdenlesliebole/Nortek_Vector_PUV_Pipeline
- Pipeline architecture: `PUV_Pipeline/docs/pipeline_levels.md`
- L2 product verification: `PUV_Pipeline/validation/verify_L2_products.m`
