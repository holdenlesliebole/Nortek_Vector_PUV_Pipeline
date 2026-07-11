# Defect fixes + real-data verification, 2026-07-10

Branch `puv-channel-decoupling-2026-07`. Closes the eight defects the independent review and
self-audit found in the Stage-1/2 channel-decoupling code. Every fix lives in a pure,
tested function (`puv_channel_qc`, `puv_trim_anchor`, `seg_is_bad`) — the root cause was that
the prior suites exercised the algebra, never `PUV_raw_process`.

## Tests — four suites, 54 assertions, all green

| suite | drives | asserts | n |
|---|---|---|---|
| `test_puv_channel_qc` | the real `puv_channel_qc` | healthy / dead-thermistor / toppled / dead-AND-toppled / seasonal / on-deck / whole-record-dead | 19 |
| `test_puv_trim_anchor` | `puv_trim_anchor` | normal / dead-pressure-fallback / both-dead-error | 3 |
| `test_L2_channel_decoupling` | the real `PUV_L2_spectral` | velocity-only + pressure-only recovery, implausible-depth flagging, legacy compat | 13 |
| `test_channel_decoupling` | the masking algebra | the original decoupling identities | 10 |

## Real-data verification on TOR23W/MOP586_10m

The temperature fix intentionally changes behavior, so the regression is not a no-op — it is
a *characterization*. Two runs, both re-running L1+L2 from raw into a scratch dir.

### Default bounds `Tvalid = [-2 40]`

| quantity | pre-fix (committed) | post-fix | reading |
|---|---|---|---|
| healthy-data ΔHs (max) | 7.77e-3 | **7.77e-3** | identical |
| Δskewness, ΔuMean (max) | 0 | **0** | velocity path bitwise-identical |
| velocity recovered | 159 | **151** | −8 (see below) |
| — of which 25-29 Dec (peak) | 110 | **110** | storm peak intact |
| rescaled samples | 1,344,422 | **1,213,881** | fewer |
| rescale before 25 Dec | 0 | **0** | no-op exact |
| `Tref` | 16.90 | **17.06** | now from in-water plausible samples |

The −8 velocity segments and the reduced rescale are the SAME cause: on 25-26 Dec the sensor
block was failing (T dropping 17 → 8.6 → −1.7 °C) but those readings sit inside the wide
`[-2, 40]` default. The code therefore treats the thermistor as healthy, trusts the jittery
tilt from the failing block, and rejects 8 velocity segments — and does not rescale the
biased velocities. This is the honest cost of a bound wide enough to be safe everywhere.

### Site bound `Tvalid = [9 26]` (San Diego coastal)

| quantity | default `[-2 40]` | site `[9 26]` | pre-fix (committed) |
|---|---|---|---|
| velocity recovered | 151 | **159** | 159 |
| — of which 25-29 Dec (peak) | 110 | **110** | 110 |
| rescaled samples | 1,213,881 | **1,342,084** | 1,344,422 |
| recovered segments at qc_flag=3 | all | **all (159/159)** | all |
| median rescale factor | 1.0579 | **1.0583** | 1.0581 |

The site bound **restores full recovery** (159) and rescale coverage (1.34M, matching the
pre-fix committed run) by flagging the Dec 25-26 implausible-for-December readings as failure
-- WITHOUT the deviation test's corruption path (it never mis-flags genuine cold water,
because the discriminant is an absolute physical range, not a distance from a moving median).
This is the definitive "works as intended" result: same detection performance as before, on
the deployments that matter, with the data-corruption class removed.

The SD range treats −1.7 and 8.6 °C as implausible (SD December water is ~15 °C), flags them
as failure, keeps the velocity, and rescales it — restoring the recovery and the rescale
coverage. This is why **the archive rerun must set `cfg.qcOpts.Tvalid` to the site's water
range**, not the wide default.

## The defect → fix → test map

| # | defect | fix | test |
|---|---|---|---|
| F6 | `TmaxDev=8` deviation test corrupts genuine cold-upwelling velocity | physical-plausibility bounds + optional rate gate | scenario S |
| F1a | `Tref` poisoned by deck / early failure | `Tref` from in-water plausible samples | scenario D |
| F1b | dead thermistor disables the topple gate (keeps toppled velocity) | unconditional absolute-tilt gate | scenario BT |
| F2 | static-tilt flagged even when no static tilt exists | flag only where computable | scenario W |
| F3 | `bad_seg` leaves `qc_flag=1` on a known-implausible segment | set `qc_flag=4` | RUN E1/E2 |
| F4 | pressure-only branch skips the sanity check | shared `seg_is_bad`, applied in both paths | RUN E3 |
| F5 | whole-deployment dead pressure crashes, discarding good velocity | channel-aware trim anchor | trim A/B/C |
| F7 | `c(T)` fit extrapolated | clamp to the fit's data range | in code |
| F8 | static-tilt uses a global median | unchanged; noted | — |

## Still open (unchanged by this work)

- ~~Propagate `qc_flag` into `build_L4_site`~~ **DONE 2026-07-10** (`l4_puv_qc`, `test_l4_puv_qc`): FAIL segments dropped, flags travel per burst, backward-compatible. Full L4 rebuild still waits on the rerun.
- N7 (0.12-0.16 Hz reconstructed-spectrum deficit), N4 (noise-floor subtraction).
- The scoped TOR23W + TBR23 rerun, with `Tvalid = [9 26]`.
