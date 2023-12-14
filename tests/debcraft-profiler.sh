#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# Run a profiler in the background that every second records what was the last
# line in the log at that time, and thus helps construct a profile of on what
# was most tiem spent waiting on while running the program.
CMD="$*"
ID="$(date '+%s')"
LOG_OUTPUT="debug-profiler-$ID.log"
LOG_PROFILE="debug-profiler-$ID.profile"

echo -e "\e[38;5;5mDebcraft profile executing command: $CMD\e[0m"
echo -e "\e[38;5;5mCommand output recorded in: $LOG_OUTPUT\e[0m"
echo -e "\e[38;5;5mProfile collected in: $LOG_PROFILE\e[0m"

eval "$CMD" | tee -a "$LOG_OUTPUT" &
PID="$!"

echo "PID: $PID"

while kill -0 "$PID" 2> /dev/null
do
  echo -n "${EPOCHREALTIME}: " >> "$LOG_PROFILE"
  tail --lines=1 "$LOG_OUTPUT"  >> "$LOG_PROFILE"
  read -srt 1 && break_ # avoids forking 'sleep'
done

echo
echo -e "\e[38;5;5mDebcraft profile done executing command: $CMD\e[0m"
