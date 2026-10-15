# Driver provenance, known-failed flags, per-deployment tide station: code only

```catalog-change
status: pending
files:
  - L1/*/*
  - L2/*/*
  - L3/*/*
  - L4/*/*
  - L4_xspec/*/*
code_ack:
  - L1: driver/provenance/QC-guard changes (drivers stamp provenance, skip knownFailed instruments, name failed labels; build_provenance handles a no-git checkout); no output values changed
  - L2: driver/provenance/QC-guard changes (as L1, plus the 2026-10-14 loud-failure and stack-format fixes in the drivers); no output values changed
  - L3: driver/provenance/QC-guard changes (PUV_L3_currents takes cfg.tideStation, 9410230 for every San Diego config as built; NOAA fetch via shared/noaa_tide_predictions, identical to getztide2 for 9410230; errors instead of silent t_tide fallback or missing t_tide; 2026-10-14 driver Tvalid fix); no output values changed
  - L4: driver/provenance/QC-guard changes (drivers stamp provenance, skip knownFailed instruments); no output values changed
  - L4_xspec: driver/provenance/QC-guard changes (xspec driver and run_all stamp provenance); no output values changed
fallback_ack: false
changes: false
```

Code changes only; no catalog file was rebuilt, and no file's bytes are expected
to change at the next push. The file patterns above are wide only because a
`code_ack` applies to the files an entry names: without them every catalog file
would SOFT-refuse ("code changed since build commit") after the 2026-10-14 and
2026-10-15 driver edits. `changes: false` makes this an acknowledgement-only
entry: it does not explain a changed sha256, so a file whose bytes changed is
still refused unless another entry describes that change.

What changed (details in `CHANGELOG.md`, 2026-10-15):
- The plain drivers (`PUV_L*_driver`, `PUV_L*_run_all`, xspec driver and
  run_all) now write the same provenance as the rebuild script.
- Seven configured instruments that never produced data carry
  `knownFailed` in their configs; the drivers skip them.
- `cfg.tideStation` is set in every config. All San Diego configs and the two
  Catalina configs use 9410230, the station every catalog L3 was built with, so
  `L3.tidal.depth_pred` is unchanged. Catalina's value is flagged in its config
  as a known approximation pending a decision (nearest NOAA harmonic station
  9410079 Avalon; the two predictions differ by 2.8-3.0 cm rms over CAT21A/B).
- `PUV_L3_currents` now errors on a failed NOAA download and on a missing
  t_tide instead of falling back silently.

L3 files built before this change have no `L3.tidal.station`. `check_prov`
compares the stamped station with the config only when the stamp records one,
so those files are not refused for it.
