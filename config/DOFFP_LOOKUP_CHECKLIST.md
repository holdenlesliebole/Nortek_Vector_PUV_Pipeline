# doffp Lookup Checklist

`doffp` = pressure-sensor height above the bed, in metres. It sets the
pressure→elevation transfer (`Kp = cosh(k·doffp)/cosh(k·H)`) and shifts the
reported water depth one-for-one, so a wrong value biases `Hs` and everything
spectral built on it.

**Source:** `/Volumes/group/DeploymentNotes/` — `DeploymentNotes{years}.xls` for
2018 onward, `SoCal_instruments_{years}.xls` for 2014–2018. In both, sheet
**'All Data'**, column **"Deployment Depth below sand (cm)"** (which despite the
name usually reads "Pressure port *N* cm above sand"). Convert cm → m.

**Match on serial number AND deployment ordinal AND season.** Serials are reused
across years, so a serial alone gives false hits. The deployment ordinal
("2nd Deployment") plus the date range disambiguates.

**Use the at-deployment value**, and record the recovery value in a comment —
the difference is real bed change, and it is the uncertainty carried by a single
fixed `doffp`.

**Beware the wrong sheet.** `DeploymentNotes2021Torrey.xls` has a 'Torrey' sheet
that is a *different* experiment (a shallow Paros swash array, sensor elevations
−0.3 to −0.45 m NAVD88). The Vector PUV data is in 'All Data'.

---

## Status (updated 2026-07-27)

**Every catalog record now has a sourced or explicitly-reasoned `doffp`.**

### Resolved 2026-07-27 — these had been placeholders

| record | was | now (at deployment) | source |
|---|---|---|---|
| RUBY22/MOP578_10m | 0.60 | **0.79** (0.91 recovery) | `DeploymentNotes2021Torrey.xls` 'All Data', S/N 16310 |
| RUBY22/MOP579_6m | 0.60 | **0.69** (0.70) | " S/N 16737 |
| RUBY22/MOP582_30m | 0.60 | **0.80** (0.83, in a scour pit) | " S/N 12414 |
| CDF15A/MOP677_9m | 0.65 | **0.54** (0.59) | `SoCal_instruments_2015.xls`, 1st Deployment, V1049 |
| CDF15C/MOP677_9m | 0.65 | **0.55** (0.54) | " 3rd Deployment, V1053 |
| COR16B/MOP158_9m | 0.65 | **0.58** (0.42) | `SoCal_instruments_2016-2017.xls`, 2nd Deployment, V1181 |
| COR17D/MOP158_9m | 0.65 | **0.72** (0.76) | `SoCal_instruments_2017-2018.xls`, 4th Deployment, V1181 |
| CAT21A/CAT_isl | 0.75 | **0.71** | `DeploymentNotes2020-2021.xls`, S/N 15032 |
| CAT21B/CAT_isl | 0.75 | **0.71** | " (same instrument — see `CAT21A_config.m`) |

**Three config headers said the data was unavailable, and all three were wrong.**
Cardiff and Coronado claimed "doffp is not recorded for these years"; Catalina
called it a placeholder to fill "before running L2" (it never was, and L1–L4 were
built on it). If you meet another such claim, check the workbook before believing
it.

Coronado also shows why one program-typical value is unsafe: its two deployments
are genuinely 0.58 and 0.72, so the single 0.65 placeholder was wrong in both
directions.

### Sourced, but carried across years — worth refining

- **TorreyOffshore** (`TOR14A`…`TOR19A`, 12 records): `doffp = 0.63` is real —
  `DeploymentNotes2019-2020.xls`, "Los Pen Nortek Vector ADV", S/N 0806,
  "Pressure port 63cm above sand" — but it is carried *back* across 2014–2019.
  Per-year values likely exist in `SoCal_instruments_2014/2015/2016-2017/
  2017-2018.xls`, which all carry the same column. **Not yet checked.** For
  scale, that one 2019-2020 deployment moved 63 → 74 cm over its own duration.

### Filled from notes earlier — no action

TBR23 (0.75–0.77), TOR23W/SOL23 (0.60–1.09), TOR24S, TOR24W, TOR25S, SOL24,
SOL25A/B, SIO24A–C, SIO25A–E, LPL23–25B, IB18W, IB19S, IB19W, TOR19W, TOR20W.

> A previous revision of this file listed ~27 open lookups for these. They had
> already been filled in the configs and the checklist was never updated. **If
> this file and a config disagree, believe the config.**

---

## Sensitivity — how hard is a given value worth chasing?

Measured on the 2026-07-27 corrections, recomputed from the stored `Spp` with
the `Kp` recomputation closing to 2.2e-16 against the pipeline:

- **depth** shifts by *exactly* the `doffp` change — one-for-one
- **Hs** moved −0.39 % to +0.67 % for `doffp` changes of −0.11 to +0.20 m
- **Hs/h** moved −1.08 % to +1.03 %

`Hs` is forgiving. Depth, and every nonlinearity parameter that divides by it
(`Hs/h`, Ursell, Shields), are not. Chase the value when the record feeds
depth-dependent or nonlinearity analysis.

Propagating a correction is cheap: `doffp` is only *stored* at L1
(`PUV_raw_process.m` copies it; nothing in L1 reads it), so the raw binaries do
**not** need re-decoding. Patch the L1 scalar, then rerun L2→L3→L4. See
`scripts/rerun_doffp_fix_2026_07_27.m` for the pattern.
