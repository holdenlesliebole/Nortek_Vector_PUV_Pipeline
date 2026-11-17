#!/bin/zsh
# Rerun copy_to_server.m until it completes, remounting reefbreak when the SMB mount drops
# (2026-11-16: "Socket is not connected" at file 84/273). copy_to_server is idempotent (size
# and mtime skip), so each attempt resumes. Max ATTEMPTS (default 10). Run from the repo root.
ATTEMPTS=${ATTEMPTS:-10}; LOGD=outputs/_logs
for i in $(seq 1 $ATTEMPTS); do
  if ! mount | grep -q /Volumes/group; then
    osascript -e 'mount volume "smb://hlesliebole@reefbreak.ucsd.edu/group"' >/dev/null 2>&1; sleep 10
  fi
  if ! mount | grep -q /Volumes/group; then echo "$(date '+%F %T') attempt $i: mount unavailable" >> $LOGD/push_remount.log; sleep 300; continue; fi
  log=$LOGD/copy_to_server_$(date +%Y%m%d%H%M).log
  echo "$(date '+%F %T') attempt $i -> $log" >> $LOGD/push_remount.log
  /Applications/MATLAB_R2025a.app/bin/matlab -nosplash -nodesktop -batch "startup_puv; dryRun = false; run scripts/copy_to_server.m" > $log 2>&1
  if grep -q "^{Error\|Error using" $log; then
    echo "$(date '+%F %T') attempt $i failed: $(grep -m1 -A1 '^{Error' $log | tr '\n' ' ')" >> $LOGD/push_remount.log; sleep 60
  else
    echo "$(date '+%F %T') attempt $i completed" >> $LOGD/push_remount.log; exit 0
  fi
done
echo "$(date '+%F %T') gave up after $ATTEMPTS attempts" >> $LOGD/push_remount.log; exit 1
