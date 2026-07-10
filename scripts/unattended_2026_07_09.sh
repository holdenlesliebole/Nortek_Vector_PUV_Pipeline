#!/bin/bash
# Unattended run, 2026-07-09. Three read-only stages, sequential so they don't starve
# each other of SMB bandwidth. Nothing here modifies outputs/L1, outputs/L2 or outputs/L4.
#
#   R   real-data regression of the Stage-1/2 pipeline change on TOR23W/MOP586_10m
#       -> does the new code leave healthy segments untouched, and does it recover the
#          120 Phase-A hours?  This is the gate on the 26-deployment rerun.
#
#   N8  diagnose the two undiagnosed TOR23W frames, MOP586_5m and MOP580_5m. They show a
#       THIRD signature (many medium runs) that matches neither the sensor-block failure
#       (MOP586_10m) nor the toppled frame (MOP580_7m).
#
#   S1  the cheap .sen survey across every Vector deployment in the archive. The .sen files
#       carry battery, sound speed, heading, pitch, roll and temperature -- every diagnostic
#       needed to CLASSIFY a failure -- at a third of the bytes of the .dat. This is what
#       decides which instruments are worth pulling .dat for, and it is the prerequisite
#       for the full L1 rerun.
#
# The /Volumes/group mount drops. Every stage checks it, tries once to remount, and SKIPS
# with a loud log line rather than silently proceeding on stale or absent data.

set -u
ROOT=/Users/holden/Documents/Scripps/Research/PUV_Pipeline
OUT=$ROOT/docs/diagnostics_2026-07-09/unattended
SP=/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad
MATLAB=/Applications/MATLAB_R2025a.app/bin/matlab
VEC=/Volumes/group/PUV_data/Vector
mkdir -p "$OUT"
LOG=$OUT/run.log
: > "$LOG"

say() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

mount_ok() {
    if mount | grep -q /Volumes/group && ls "$VEC" >/dev/null 2>&1; then return 0; fi
    say "WARN: /Volumes/group is down; attempting remount"
    osascript -e 'mount volume "smb://hlesliebole@reefbreak.ucsd.edu/group"' >/dev/null 2>&1
    sleep 5
    if mount | grep -q /Volumes/group && ls "$VEC" >/dev/null 2>&1; then say "remounted"; return 0; fi
    say "ERROR: remount failed"
    return 1
}

say "=== unattended run start ==="

# ---------------------------------------------------------------- R
say "STAGE R: real-data regression, TOR23W/MOP586_10m"
if mount_ok; then
    "$MATLAB" -batch "run('$SP/regress_stage12.m'); run('$SP/regress_compare.m')" \
        > "$OUT/R_regression.log" 2>&1
    if grep -q REGRESS_COMPARE_DONE "$OUT/R_regression.log"; then
        say "STAGE R: complete"
        grep -E "^R1|^R2|^R3|PASS|INSPECT|max \|Delta|segments" "$OUT/R_regression.log" | head -30 | tee -a "$LOG"
    else
        say "STAGE R: FAILED -- see R_regression.log"
        tail -5 "$OUT/R_regression.log" | tee -a "$LOG"
    fi
else
    say "STAGE R: SKIPPED (mount down)"
fi

# ---------------------------------------------------------------- N8
say "STAGE N8: sensor-block diagnosis of MOP586_5m and MOP580_5m (TOR23W)"
D=$VEC/Torrey20231114-20240118
sen_scan() {   # $1 = filename glob pattern (basename), $2 = out csv
    echo "time,batt,c,heading,pitch,roll,T" > "$2"
    find "$D" -name "$1" -type f 2>/dev/null | sort | while read -r f; do
        awk -F' +' '{n++; b+=$9;c+=$10;h+=$11;p+=$12;r+=$13;T+=$14;
            if(n==1)t=sprintf("%04d-%02d-%02d %02d:%02d:%02d",$3,$1,$2,$4,$5,$6);
            if(n==600){printf "%s,%.2f,%.1f,%.1f,%.2f,%.2f,%.2f\n",t,b/600,c/600,h/600,p/600,r/600,T/600;
                       n=0;b=0;c=0;h=0;p=0;r=0;T=0}}' "$f" >> "$2" 2>/dev/null
    done
}
if mount_ok; then
    sen_scan "5M_58602*.sen" "$OUT/N8_sen_586_5m.csv"
    sen_scan "TORREY02*.sen"  "$OUT/N8_sen_580_5m.csv"
    say "STAGE N8: 586_5m $(wc -l < "$OUT/N8_sen_586_5m.csv") rows, 580_5m $(wc -l < "$OUT/N8_sen_580_5m.csv") rows"
else
    say "STAGE N8: SKIPPED (mount down)"
fi

# ---------------------------------------------------------------- S1
say "STAGE S1: .sen survey across every Vector deployment"
SUM=$OUT/S1_failure_inventory.csv
# NOTE. The .sen carries no pressure, so there is no in-water flag. A naive max over the
# whole file measures the instrument being carried on deck at deployment and recovery, not
# the seabed: a smoke test on the known-healthy MOP586_7m returned max|pitch| = 162.7 deg
# and 1.88% of samples over 30 deg. Everything below is computed on the INTERIOR of the
# record (first and last SKIP minutes dropped), and Tref is the interior median, not a
# leading-window mean that the on-deck air temperature would poison.
echo "deployment,instrument,n_int,pct_T_implausible,pct_T_dev_gt8,Tref,pct_tilt_gt30,p95_abs_pitch,p95_abs_roll,p99_abs_roll,head_drift,pct_batt_out,c_min,c_max,tilt_drift" > "$SUM"
if mount_ok; then
    find "$VEC" -name '*.sen' -type f 2>/dev/null | sort > "$SP/all_sen.txt"
    NTOT=$(wc -l < "$SP/all_sen.txt")
    say "STAGE S1: $NTOT .sen files"
    i=0
    while read -r f; do
        i=$((i+1))
        mount | grep -q /Volumes/group || { say "S1: mount dropped at file $i; stopping"; break; }
        # basename(dirname) collides: two campaigns both contain a folder called
        # MOP586-7m16739. Use the path relative to $VEC so the key is unique.
        dep=$(dirname "${f#$VEC/}")
        ins=$(basename "$f" .sen)
        # one streaming pass: subsample every 60th 1-Hz sample (1/min) for the stats
        awk -F' +' -v dep="$dep" -v ins="$ins" -v SKIP=360 -f "$ROOT/scripts/s1_sen_survey.awk" "$f" >> "$SUM" 2>/dev/null
        [ $((i % 10)) -eq 0 ] && say "S1: $i/$NTOT"
    done < "$SP/all_sen.txt"
    say "STAGE S1: complete, $(($(wc -l < "$SUM")-1)) instruments"
else
    say "STAGE S1: SKIPPED (mount down)"
fi

say "=== unattended run finished ==="
echo "UNATTENDED_DONE" | tee -a "$LOG"
