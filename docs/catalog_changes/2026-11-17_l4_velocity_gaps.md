# L4 velocity modules apply the L2 velocity gaps

```catalog-change
status: pending
files:
  - L4/CAT21A/*
  - L4/COR16B/*
  - L4/RUBY22/*
  - L4/SOL23/*
  - L4/TOR14A/*
  - L4/TOR14C/*
  - L4/TOR15B/*
  - L4/TOR16B/*
  - L4/TOR16C/*
  - L4/TOR17C/*
  - L4/TOR23W/*
  - L4/TOR24W/*
code_ack:
  - L4: PUV_L4_driver applies shared/l1_velocity_gap_mask.m to L1 BuoyCoord U, V, W before the reflection, reflection_free, boundwave and velocity_pdf modules; the same rule L2 applies inline (beam-step unconfirmed samples and instr.velInvalidFrom); test_l1_velocity_gap_mask 4/4
fallback_ack: false
```

**Why.** Catalog 2026-11-17.1 made L2 treat two kinds of L1 sample as velocity gaps: samples
the beam-step correction flagged unconfirmed, and samples after a record's `velInvalidFrom`
cutoff (HLB, 2026-11-13, decision 2 and 4). Four L4 modules read L1 velocity directly rather than
through L2, so in 2026-11-17.1 they still used the unconfirmed samples as recorded. The cutoff
already reached them in effect, because the gapped hours fail `segValid` and the modules skip
them.

**Affected records.** The 16 records with unconfirmed samples, 2,988 samples in all (counts from
`outputs/_logs/beamstep_L1_table_2026-11-13.csv`): TOR23W MOP586_10m 2,597 (nearly all after its
cutoff), TOR17C MOP591_9m 159, RUBY22 MOP579_6m 89, TOR16B 52, COR16B 28, TOR24W MOP586_10m 15,
SOL23 MOP651_7m 12, RUBY22 MOP582_30m 10, SOL23 MOP654_7m 8, TOR16C 7, TOR23W MOP580_7m 6 in this
table (15 after HLB's 2026-11-14 ruling flagged its double steps), and 1 each at CAT21A, TOR14A,
TOR14C, TOR15B and TOR23W MOP586_5m. No other record changes. The listed globs cover whole
deployments; L4 for the other instruments in them rebuilds unchanged.

**Expected size of the change.** Small. A few unconfirmed samples per valid hour at most, filled
by each module's existing fill rule. The tails of the pooled velocity PDF are the most exposed.
Not measured yet; the rebuild should report each affected field's largest change.

**Not changed.** L1, L2, L3, L4_xspec, and every L4 field that does not read L1 velocity
(eta, bispectra, moments).
