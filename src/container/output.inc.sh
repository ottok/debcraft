#!/bin/bash

function log_error() {
  echo -e "\e[38;5;1mDEBCRAFT ERROR: $*\e[0m" >&2
}

function log_warn() {
  echo -e "\e[38;5;3mDEBCRAFT WARNING: $*\e[0m" >&2
}

function log_info() {
  echo -e "\e[38;5;33m$*\e[0m"
}

if [ -z "$DEBUG" ]
then
  # If not running in DEBUG mode, don't do anything on these
  function log_debug() {
    :
  }
  function log_debug_var() {
    :
  }
  function log_debug_env() {
    :
  }
else
  # Print debug information not normally visible
  function log_debug() {
    echo -e "\e[38;5;5mDEBCRAFT DEBUG: $1 (at line $(caller))\e[0m"
  }

  # Print the variable name and value in one "log_debug_var example" call
  function log_debug_var() {
    # Outputs variable type and contents, e.g 'declare -x ACTION="release"'
    echo -e "\e[38;5;5mDEBCRAFT DEBUG: $(declare -p "$1") (at ${BASH_SOURCE[1]}:${BASH_LINENO[0]})\e[0m"
  }

  function log_debug_env() {
    echo -e "\e[38;5;5mDEBCRAFT DEBUG:"
    set | grep '^[A-Za-z_]' | grep -v '^[A-Za-z_].*()' | sort
    echo -e "\e[0m"
  }

  log_debug "Running Debcraft in debug mode"
fi

# Usage example:
#   CMD="podman build"
#   eval $CMD &
#   spinner $! "$CMD"
function spinner() {
  local PID="$1"
  local CMD="${2:-building}"
  local START_TIME="$EPOCHSECONDS"
  local DELAY="0.1"
  local i=1
  local SPINNER="/-\|"
  local CMD_WIDTH=$(($(tput cols)-25))

  # Start color
  printf "\e[38;5;33m"
  while kill -0 "$PID" 2> /dev/null
  do
    printf "\r[%ss] Executing: %-${CMD_WIDTH}s" "$((EPOCHSECONDS-START_TIME))" "$CMD"
    # shellcheck disable=2059 # this oneliner trick is intentional
    printf "\b${SPINNER:i++%${#SPINNER}:1}"
    sleep "$DELAY"
  done
  printf "\r[%ss] Completed: %-${CMD_WIDTH}s\n" "$((EPOCHSECONDS-START_TIME))" "$CMD"

  # End color
  printf "\e[0m"

  # Debug: View entire color palette
  #for x in {1..254}
  #do
  #  echo -ne "\e[38;5;${x}m${x} "
  #done
  #echo -ne "\e[0m"

  # Debug: View ANSI effects
  #for x in {1..254}
  #do
  #  echo -ne "\e[${x};5;33m${x}\e[0m "
  #done

}

# @TODO: Currently this has no real concept of knowing progress
function progress_bar() {
  BAR_WIDTH=$(($(tput cols)-20))
  printf -v BAR "%$((BAR_WIDTH))s" ''
  echo -n "Progress [${BAR// /.}]"

  i=0
  until test "$i" -gt ${BAR_WIDTH}
  do
    printf -v BAR "%-${i}s" ''
    echo -ne "\rProgress [${BAR// /#}"
    sleep .01
    ((i++))
  done
}
