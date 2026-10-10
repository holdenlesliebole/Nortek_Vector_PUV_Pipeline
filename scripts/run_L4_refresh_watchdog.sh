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

set -u
LOGDIR=$1; OUTROOT=$2; shift 2
REPO=${0:A:h:h}
STAGE=${STAGE:-L4}
STALL_SEC=${STALL_SEC:-2700}
MATLAB=/Applications/MATLAB_R2025a.app/bin/matlab
HUNG=$LOGDIR/phase3_${STAGE}_hung.txt; touch $HUNG
remaining=("$@")
n=0
while (( ${#remaining} > 0 )); do
  n=$((n+1)); LOG=$LOGDIR/phase3_${STAGE}_log_wd$n.txt
  recs=""
  for r in $remaining; do
    if [[ $STAGE == combined ]]; then rl=${r%%:*}; lv=${r##*:}; recs+="'${rl%%/*}','${rl#*/}','$lv';"
    else recs+="'${r%%/*}','${r#*/}';"; fi
  done
  if [[ $STAGE == combined ]]; then setv="combinedRecs={${recs%;}};"; else setv="onlyRecs={${recs%;}};"; fi
  echo "[watchdog] launch $n: ${#remaining} record(s) -> $LOG"
  ( cd $REPO && $MATLAB -nodisplay -nosplash -nodesktop -batch \
      "outRoot='$OUTROOT'; stage='$STAGE'; dryRun=false; $setv run('scripts/rerun_heading_ws_2026_10_07.m')" \
      > $LOG 2>&1 ) &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    sleep 60
    age=$(( $(date +%s) - $(stat -f %m $LOG) ))
    if (( age > STALL_SEC )); then
      cur=$(grep -E '^\[(L4|combined [A-Z0-9]+)\] ' $LOG | tail -1 | sed -E 's/^\[(L4|combined [A-Z0-9]+)\] //')
      if [[ -z $cur ]]; then
        echo "[watchdog] no log progress for ${age}s BEFORE any record started (startup/pool): killing launch $n"
      else
        echo "[watchdog] no log progress for ${age}s on '$cur': killing launch $n"
        echo "$cur  HUNG $(date '+%Y-%m-%d %H:%M') (launch $n, no log write for ${age}s)" >> $HUNG
      fi
      mpid=$(pgrep -f "MATLAB.*rerun_heading_ws_2026_10_07" | head -1)
      [[ -n $mpid ]] && { pkill -P $mpid 2>/dev/null; kill $mpid 2>/dev/null; }
      pkill -f distcomp_evaluate_filetask 2>/dev/null
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
np=$(cat $LOGDIR/phase3_${STAGE}_log_wd*.txt 2>/dev/null | grep -E '^  [A-Z0-9]+ +[A-Za-z0-9_]+ +([A-Z0-9]+ +)?PASS' | awk '{print $1"/"$2}' | sort -u | wc -l | tr -d ' ')
echo "[watchdog] finished: $np records passed (unique); hung: $(wc -l < $HUNG | tr -d ' ')"
