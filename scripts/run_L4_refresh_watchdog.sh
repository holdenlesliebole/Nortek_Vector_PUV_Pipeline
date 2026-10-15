#!/bin/zsh
# RUN_L4_REFRESH_WATCHDOG  Drive stage 'L4' or 'combined' of
# rerun_heading_ws_2026_10_07.m with a hang watchdog. On 2026-10-08 the MATLAB client sat for 5.5 h in the bispectra
# parfor with every worker idle, and no record after it ran.
#
#   scripts/run_L4_refresh_watchdog.sh <logdir> <outRoot> <dep/label> [<dep/label> ...]
#   STAGE=combined scripts/run_L4_refresh_watchdog.sh <logdir> <outRoot> <dep/label:levels> ...
#        (levels L3, L3L4 or L2L3L4; logs phase3_<stage>_log_wd<N>.txt)
#
# Runs MATLAB on the listed records. If the current log has not been written for
# STALL_SEC (default 2700 s = 45 min), it kills that MATLAB and its pool workers,
# marks the record in progress as HUNG (its L4 is untouched: nothing is saved
# until every gate passes) and relaunches on the records not yet attempted. A
# record is attempted once; "PASS saved", "FAILED" and HUNG are all final.
# Writes <logdir>/phase3_L4_log_wd<N>.txt per launch and <logdir>/phase3_L4_hung.txt.
#
# L4_xspec: launches run with skipXspec=true, and after the LAST launch one
# separate MATLAB run (stage 'xspecprov', log phase3_<stage>_xspecprov.txt)
# rebuilds xspec, with provenance, for every deployment that has an xspec and
# had at least one record PASS in ANY launch. Before 2026-10-14 xspec ran at the
# end of each launch, so a launch killed for a hang skipped it and left IB19S,
# IB18W and RUBY22 xspec stale behind their rebuilt L4s.
# Members that FAILED or HUNG keep their previous L4, and the xspec is built on
# what is on disk; they are listed at the end.
#
# Testing: MATLAB=<stand-in executable> POLL_SEC=<s> STALL_SEC=<s> KILL_WORKERS=0 override the
# MATLAB binary and the timings (validation/test_watchdog_xspec.sh).

set -u
LOGDIR=$1; OUTROOT=$2; shift 2
REPO=${0:A:h:h}
STAGE=${STAGE:-L4}
STALL_SEC=${STALL_SEC:-2700}
POLL_SEC=${POLL_SEC:-60}
MATLAB=${MATLAB:-/Applications/MATLAB_R2025a.app/bin/matlab}
HUNG=$LOGDIR/phase3_${STAGE}_hung.txt; touch $HUNG
KILL_WORKERS=${KILL_WORKERS:-1}
descendants() { local c; for c in $(pgrep -P $1); do descendants $c; echo $c; done; }
remaining=("$@")
n=0
while (( ${#remaining} > 0 )); do
  n=$((n+1)); LOG=$LOGDIR/phase3_${STAGE}_log_wd$n.txt
  recs=""
  for r in $remaining; do
    if [[ $STAGE == combined ]]; then rl=${r%%:*}; lv=${r##*:}; recs+="'${rl%%/*}','${rl#*/}','$lv';"
    else recs+="'${r%%/*}','${r#*/}';"; fi
  done
  if [[ $STAGE == combined ]]; then setv="combinedRecs={${recs%;}}; skipXspec=true;"; else setv="onlyRecs={${recs%;}};"; fi
  echo "[watchdog] launch $n: ${#remaining} record(s) -> $LOG"
  ( cd $REPO && $MATLAB -nodisplay -nosplash -nodesktop -batch \
      "outRoot='$OUTROOT'; stage='$STAGE'; dryRun=false; $setv run('scripts/rerun_heading_ws_2026_10_07.m')" \
      > $LOG 2>&1 ) &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    sleep $POLL_SEC
    age=$(( $(date +%s) - $(stat -f %m $LOG) ))
    if (( age > STALL_SEC )); then
      cur=$(grep -E '^\[(L4|combined [A-Z0-9]+)\] ' $LOG | tail -1 | sed -E 's/^\[(L4|combined [A-Z0-9]+)\] //')
      if [[ -z $cur ]]; then
        echo "[watchdog] no log progress for ${age}s BEFORE any record started (startup/pool): killing launch $n"
      else
        echo "[watchdog] no log progress for ${age}s on '$cur': killing launch $n"
        echo "$cur  HUNG $(date '+%Y-%m-%d %H:%M') (launch $n, no log write for ${age}s)" >> $HUNG
      fi
      # kill this launch's own process tree (not any other MATLAB on the machine)
      for p in $(descendants $pid); do kill $p 2>/dev/null; done
      # pool workers may not be descendants; KILL_WORKERS=0 skips this
      # machine-wide kill (it would also hit other sessions' pools)
      (( KILL_WORKERS )) && pkill -f distcomp_evaluate_filetask 2>/dev/null
      kill $pid 2>/dev/null; sleep 5
      break
    fi
  done
  wait $pid 2>/dev/null
  # final outcomes so far, across every launch log and the hung list
  done_list=$(cat $LOGDIR/phase3_${STAGE}_log_wd*.txt 2>/dev/null | grep -E '^  [A-Z0-9]+ +[A-Za-z0-9_]+ +([A-Z0-9]+ +)?(PASS|FAILED)' | awk '{print $1"/"$2}' | sort -u)
  hung_list=$(awk '{print $1}' $HUNG | sort -u)
  next=()
  for r in $remaining; do
    rk=${r%%:*}
    if ! print -r -- "$done_list" | grep -qxF "$rk" && ! print -r -- "$hung_list" | grep -qxF "$rk"; then next+=($r); fi
  done
  if (( ${#next} == ${#remaining} )); then echo "[watchdog] no progress in launch $n; stopping"; break; fi
  remaining=($next)
done
passed=$(cat $LOGDIR/phase3_${STAGE}_log_wd*.txt 2>/dev/null | grep -E '^  [A-Z0-9]+ +[A-Za-z0-9_]+ +([A-Z0-9]+ +)?PASS' | awk '{print $1"/"$2}' | sort -u)
np=$(print -r -- "$passed" | grep -c .)
echo "[watchdog] finished: $np records passed (unique); hung: $(wc -l < $HUNG | tr -d ' ')"

# ---- L4_xspec, once, after every launch: each deployment with an xspec and any PASS ----
xdeps=()
for dep in $(print -r -- "$passed" | grep . | cut -d/ -f1 | sort -u); do
  [[ -f $OUTROOT/L4_xspec/$dep/xspec.mat ]] && xdeps+=($dep)
done
if (( ${#xdeps} == 0 )); then
  echo "[watchdog] xspec: no deployment with an xspec had a record pass; nothing to rebuild"
else
  XLOG=$LOGDIR/phase3_${STAGE}_xspecprov.txt
  xlist=""; for dep in $xdeps; do xlist+="'$dep',"; done
  echo "[watchdog] xspec: rebuilding ${#xdeps} deployment(s) with provenance: ${xdeps[*]} -> $XLOG"
  ( cd $REPO && $MATLAB -nodisplay -nosplash -nodesktop -batch \
      "outRoot='$OUTROOT'; stage='xspecprov'; dryRun=false; xspecDeps={${xlist%,}}; run('scripts/rerun_heading_ws_2026_10_07.m')" \
      > $XLOG 2>&1 )
  xok=$(grep -cE '^  [A-Z0-9]+ +xspec rebuilt with provenance' $XLOG)
  echo "[watchdog] xspec: $xok/${#xdeps} rebuilt with provenance (see $XLOG)"
  # members whose own L4 was NOT rebuilt in this pass (FAILED or HUNG)
  for dep in $xdeps; do
    bad=$( { cat $LOGDIR/phase3_${STAGE}_log_wd*.txt 2>/dev/null | grep -E "^  $dep +[A-Za-z0-9_]+ +([A-Z0-9]+ +)?FAILED" | awk '{print $1"/"$2}'; \
             awk '{print $1}' $HUNG | grep "^$dep/"; } | sort -u | tr '\n' ' ')
    [[ -n $bad ]] && echo "[watchdog] xspec $dep built with previous L4 for: $bad"
  done
  (( xok == ${#xdeps} )) || exit 1
fi
