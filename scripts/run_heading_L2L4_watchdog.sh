#!/bin/zsh
# RUN_HEADING_L2L4_WATCHDOG  Drive stage $STAGE ('L2L4', default, or 'gapL4') of rebuild_heading_log_2026_11_17.m with a hang
# watchdog (as run_L4_refresh_watchdog.sh does for the October script). The bispectra parfor
# can hang with every worker idle (2026-10-08, 5.5 h; 2026-11-14, 16.5 h on IB19S/MOP055_7m).
# If the run log is not written for STALL_SEC (default 2700 s), the MATLAB client and its
# pool workers are killed, the record in progress is appended to _logs/heading_log_L2L4_hung.txt
# (nothing was saved for it: saves are all-or-nothing per record), and MATLAB relaunches on
# the records not yet attempted. When a launch ends normally, every HUNG record is retried
# once with serial bispectra (retryHung). Run from the repo root.
STAGE=${STAGE:-L2L4}
case $STAGE in L2L4) TAG='heading L2L3L4';; gapL4) TAG='gapL4';; *) echo "STAGE must be L2L4 or gapL4"; exit 1;; esac
STALL_SEC=${STALL_SEC:-2700}; POLL_SEC=${POLL_SEC:-60}
MATLAB=${MATLAB:-/Applications/MATLAB_R2025a.app/bin/matlab}
LOGD=outputs/_logs; HUNG=$LOGD/heading_log_${STAGE}_hung.txt; touch $HUNG
run_one() {   # $1 = extra MATLAB assignments, $2 = log file
  $MATLAB -nosplash -nodesktop -batch "stage='$STAGE'; skipDone=true; $1 run scripts/rebuild_heading_log_2026_11_17.m" > $2 2>&1 &
  local pid=$!
  while kill -0 $pid 2>/dev/null; do
    sleep $POLL_SEC
    local kids=$(pgrep -P $pid | tr '\n' ' ')
    local age=$(( $(date +%s) - $(stat -f %m $2) ))
    if (( age > STALL_SEC )); then
      local rec=$(grep "^\[$TAG\]" $2 | tail -1 | sed "s/^\[$TAG\] //; s|/|\||")
      echo "$(date '+%F %T') STALL ${age}s on $rec: killing $pid and workers" >> $LOGD/heading_log_${STAGE}_watchdog.log
      # pool workers are children of the client (captured above), so only this run's are killed
      kill $pid ${=kids} 2>/dev/null; sleep 5; kill ${=kids} 2>/dev/null
      [[ -n "$rec" ]] && echo "$rec" >> $HUNG
      return 1
    fi
  done
  return 0
}
n=0
while true; do
  n=$((n+1)); log=$LOGD/heading_log_${STAGE}_wd${n}_$(date +%Y%m%d%H%M).log
  echo "$(date '+%F %T') launch $n" >> $LOGD/heading_log_${STAGE}_watchdog.log
  run_one "" $log && break
done
if [[ -s $HUNG ]]; then
  echo "$(date '+%F %T') retrying HUNG with serial bispectra: $(tr '\n' ' ' < $HUNG)" >> $LOGD/heading_log_${STAGE}_watchdog.log
  run_one "retryHung=true;" $LOGD/heading_log_${STAGE}_retry_$(date +%Y%m%d%H%M).log || echo "$(date '+%F %T') retry stalled too" >> $LOGD/heading_log_${STAGE}_watchdog.log
fi
echo "$(date '+%F %T') done" >> $LOGD/heading_log_${STAGE}_watchdog.log
