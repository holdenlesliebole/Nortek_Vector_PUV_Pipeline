# Full L1-L4 rebuild: beam-step correction, T_b bed-stress period, Swart friction factor

```catalog-change
status: published 2026-11-17.1
files:
  - L1/*/*
  - L2/*/*
  - L3/*/*
  - L4/*/*
  - L4_xspec/*/*
code_ack:
  - L1: beam-step correction in beam space (vector_beam_step_correct, vector_head_matrix); scalar XYZ heading rotation as the catalog's matrix product; placeholder heads skipped; power-on trim bounded to 10 s
  - L2: unconfirmed beam-step samples and instr.velInvalidFrom treated as velocity gaps; T_b near-bed period (tb-period-20261105); Swart rough-flow friction factor and orbital amplitude (swart-amplitude-20261111)
  - L3: rebuilt from the new L2 (bed stress via shared/bed_stress_ks); no L3 code change of its own
  - L4: rebuilt from the new L1 and L2; no L4 code change of its own
  - L4_xspec: rebuilt from the new L4; no code change of its own
  - built from uncommitted code on branch beam-step-correction-20261113 (worktree PUV_Pipeline_beamstep, base f8c6b5c, with swart-amplitude-20261111 hand-merged); HLB decision 5 of 2026-11-13, push approved by HLB 2026-11-16 before commit
fallback_ack: false
```

All 66 records were rebuilt L1 to L4, with the 9 L4_xspec files, from one code version
(HLB decision 5, 2026-11-13). Decisions, rule, tests and the run log with denominators:
`docs/SPEC_L1_beam_step_correction_2026-11-13.md` sections 11 and 12.

What changed:
- **L1 beam-step correction.** Nortek Vector one-beam velocity steps (k x Delta along a beam,
  Delta about 1.49 to 1.53 m/s, |k| <= 2) removed in beam space on the recorded velocity. Largest
  counts: TOR23W MOP586_10m 8,997 samples (8,996 after its velocity cutoff), TOR17C 4,600, TOR16C
  1,090; TBR23 MOP586_5m 1 sample (2023-06-24 23:23:04 UTC, 4.09 to 0.05 m/s). New L1 fields:
  qc.vel_beamstep_k, qc.vel_beamstep_unconfirmed, qc.beamstep, head.T, head.info.
- **L2.** Unconfirmed step samples and `instr.velInvalidFrom` (TOR23W MOP586_10m from
  2023-12-30 15:29 UTC) are velocity gaps. T_b and Swart bed stress on every record (TBR23 already
  carried them).
- **Config.** TOR24W MOP586_15m serial 17047 (was 16737). TOR23W MOP580_7m flags its 15 double-step
  samples unconfirmed (HLB ruling 2026-11-14). CAT21A/B L1 now carry the corrected location.
- **Declination refreshed** on 16 L1 records by 2.2e-6 to 2.5e-3 deg (pure rotation, max
  |du_h| 3.1e-4 m/s), CAT21A/B by -0.0616 deg (location fix).

How big:
- Summed hourly <u|u|^3> (full velocity): TOR25S MOP586_15m -0.3196 to -0.7334 m^4/s^4 h
  (-129.5%); TBR23 MOP586_5m +0.5241 to +0.5590 m^4/s^4 h (+6.7%).
- TBR23 closure diff: L2 identical field for field except MOP586_5m segment 916 and the
  ztest_IG record median it feeds (1.0283 to 1.0290).
- L3 mobilized fraction rises at the October-built 9 m records (e.g. TOR17A 77.1% to 99.1%): the
  T_b/Swart bed stress, flagged for review.

How to tell a new copy: L1 has `qc.beamstep`; L2 has `velGap`; provenance git_hash f8c6b5c
(dirty) on branch beam-step-correction-20261113.
