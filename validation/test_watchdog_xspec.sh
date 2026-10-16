#!/bin/zsh
# TEST_WATCHDOG_XSPEC  scripts/run_L4_refresh_watchdog.sh must rebuild L4_xspec
# for every deployment that had a record PASS in ANY launch, including a launch
# later killed for a hang.
#
# A stand-in for MATLAB (no MATLAB is started, nothing outside a temporary
# folder is read or written) plays three records through STAGE=combined:
#   DEPA/a1  PASS, then DEPA/hang hangs in the same launch -> launch 1 killed
#   DEPB/b1  PASS in launch 2
#   DEPC/c1  PASS in launch 2, but DEPC has no xspec
# Like rerun_heading_ws_2026_10_07.m, the stand-in rebuilds xspec at the end of
# a combined launch that completes (unless skipXspec=true), and in stage
# 'xspecprov' for the deployments it is given. Each rebuild is logged.
# Criteria fixed before the first run: xspec rebuilt for DEPA and DEPB (each
# exactly once), not for DEPC, and DEPA/hang named as built on its previous L4.
#
# Usage:  validation/test_watchdog_xspec.sh [watchdog.sh]   (default: the repo's)
# To watch it fail on the pre-2026-10-14 watchdog:
#   git show 4efe10b:scripts/run_L4_refresh_watchdog.sh > /tmp/old_wd.sh
#   validation/test_watchdog_xspec.sh /tmp/old_wd.sh --legacy
# (--legacy adds only the test hooks: MATLAB/POLL_SEC overrides, and killing the
# launch's own process tree instead of every MATLAB and pool worker on the host.)

set -u
REPO=${0:A:h:h}
WD=${1:-$REPO/scripts/run_L4_refresh_watchdog.sh}
T=$(mktemp -d); trap 'rm -rf $T' EXIT
if [[ ${2:-} == --legacy ]]; then
  # the legacy script resolves REPO from its own location; keep it under a fake repo
  mkdir -p $T/repo/scripts
  sed -e 's|^MATLAB=/Applications/MATLAB_R2025a.app/bin/matlab$|MATLAB=${MATLAB}|' \
      -e 's|^    sleep 60$|    sleep $POLL_SEC|' \
      -e 's|^      mpid=.*$|      for p in $(pgrep -P $pid) $(pgrep -P $(pgrep -P $pid) 2>/dev/null); do kill $p 2>/dev/null; done|' \
      -e '/^      \[\[ -n \$mpid \]\]/d' -e '/pkill -f distcomp_evaluate_filetask/d' $WD > $T/repo/scripts/wd.sh
  chmod +x $T/repo/scripts/wd.sh; WD=$T/repo/scripts/wd.sh
fi
mkdir -p $T/out/L4_xspec/DEPA $T/out/L4_xspec/DEPB $T/logs
touch $T/out/L4_xspec/DEPA/xspec.mat $T/out/L4_xspec/DEPB/xspec.mat
CALLS=$T/xspec_calls.txt; touch $CALLS

cat > $T/fakeMATLAB <<'FAKE'
#!/bin/zsh
cmd=$5
outRoot=$(print -r -- $cmd | sed -E "s/.*outRoot='([^']*)'.*/\1/")
stage=$(print -r -- $cmd | sed -E "s/.*stage='([^']*)'.*/\1/")
calls=$outRoot/../xspec_calls.txt
if [[ $stage == xspecprov ]]; then
  for d in $(print -r -- $cmd | sed -E "s/.*xspecDeps=\{([^}]*)\}.*/\1/" | tr -d "'" | tr ',' ' '); do
    echo $d >> $calls; echo "  $d xspec rebuilt with provenance, 1 pairs"
  done
  exit 0
fi
recs=$(print -r -- $cmd | sed -E "s/.*combinedRecs=\{([^}]*)\}.*/\1/" | tr -d "'")
passdeps=()
for r in ${(s:;:)recs}; do
  dep=${r%%,*}; rest=${r#*,}; lab=${rest%%,*}; lv=${rest#*,}
  echo "[combined $lv] $dep/$lab"
  if [[ $lab == hang ]]; then sleep 600; fi
  printf '  %-7s %-11s %-6s PASS | fake\n' $dep $lab $lv
  passdeps+=($dep)
done
if [[ $cmd != *skipXspec=true* ]]; then
  for d in ${(u)passdeps}; do
    [[ -f $outRoot/L4_xspec/$d/xspec.mat ]] && { echo $d >> $calls; echo "  $d xspec rebuilt with provenance, 1 pairs"; }
  done
fi
FAKE
chmod +x $T/fakeMATLAB

STAGE=combined MATLAB=$T/fakeMATLAB POLL_SEC=1 STALL_SEC=3 KILL_WORKERS=0 \
  $WD $T/logs $T/out 'DEPA/a1:L3L4' 'DEPA/hang:L3L4' 'DEPB/b1:L3L4' 'DEPC/c1:L3' > $T/wd_out.txt 2>&1
rc=$?
sleep 1
pass=0; total=0
chk() { total=$((total+1)); if (( $1 )); then pass=$((pass+1)); fi; printf '  %-60s %d\n' "$2" $1; }
nA=$(grep -cx DEPA $CALLS); nB=$(grep -cx DEPB $CALLS); nC=$(grep -cx DEPC $CALLS)
chk $(( nA == 1 )) "DEPA xspec rebuilt once (record passed in a hung launch): $nA"
chk $(( nB == 1 )) "DEPB xspec rebuilt once: $nB"
chk $(( nC == 0 )) "DEPC (no xspec) not rebuilt: $nC"
chk $(( $(grep -c 'DEPA/hang' $T/wd_out.txt) >= 1 )) "DEPA/hang reported (hung, previous L4 kept)"
echo "--- watchdog output (exit $rc) ---"; cat $T/wd_out.txt
echo "=== watchdog xspec: $pass/$total checks as required"
(( pass == total )) || { echo "  FAIL"; exit 1; }
echo "  PASS"
