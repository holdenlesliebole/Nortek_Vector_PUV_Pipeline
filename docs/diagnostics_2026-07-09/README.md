# Diagnostics behind docs/L1_sensor_block_failure_2026-07-09.md

Promoted out of a session scratchpad so nothing depends on /tmp. Read-only analyses;
none of these modify the pipeline or its outputs.

scripts/
  sen.awk, sen2.awk   stream a Nortek .sen -> per-minute / per-10-min sensor-block stats
  dat2.awk            stream a .dat -> per-10-min per-beam correlation, amplitude, pressure
                      (NOTE: use awk's DEFAULT field splitting. -F' +' is off by one
                       because .dat rows have leading whitespace.)
  vel.awk             stream a .dat row range -> 20-min velocity moments
  attrib2.py          daily tables of beam correlation / amplitude / pressure
  ref7.m              20-min reference stats from the L1 .mat products
  zvshs.m             ztest_SS vs wave height, per frame

  along3.m            CDIP MOP alongshore Hs scan, 576-590
  bandir.m, dpband.m  frequency x direction conditioning of the MOP586 swell deficit
  e3b/e3c/e3d.m       segment retention, outage contiguity, MOP580-vs-MOP586 in situ
  tbr23.m, qtest.m    Steve Elgar's z-test and Q-test applied to Chapter 1's TBR23 data

data/
  vel_10m.csv                 20-min u/v stats, MOP586_10m raw, 2023-12-18..12-31
  dat2_10m.csv.gz             per-10-min beam correlation + pressure, whole deployment
  sen2_10m.csv.gz             per-10-min battery/soundspeed/heading/pitch/roll/temp
  L1_MOP586_{7,10}m.csv       20-min reference stats from the QC'd L1 products
  alongshore_Hs_576-590_dec2023storm.csv
