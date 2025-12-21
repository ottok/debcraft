#!/bin/bash

# Expand backslash sequences once into a variable, then print literally using %s
# to avoid double-expansion mangling nested escape sequences (like links).
function log_error() {
  local msg; printf -v msg "%b" "$*"
  printf "\e[38;5;1mDEBCRAFT ERROR: %s\e[0m\n" "$msg" >&2
}

function log_warn() {
  local msg; printf -v msg "%b" "$*"
  printf "\e[38;5;3mDEBCRAFT WARNING: %s\e[0m\n" "$msg" >&2
}

function log_info() {
  local msg; printf -v msg "%b" "$*"
  printf "\e[38;5;33m%s\e[0m\n" "$msg"
}

# OSC 8 escape sequences for clickable hyperlinks
function clickable_link() {
  # One argument mandatory
  local url="$1"
  # Second argument optional and if missing, just display the url
  local text="${2:-$url}"

  # Ensure links are formatted as valid urls
  case "$url" in
    *://*)
      # Already has a scheme:// - leave as-is
      ;;
    /*)
      # Local absolute path - prepend file://
      url="file://${url}"
      ;;
    *)
      # Everything else - prepend https://
      url="https://${url}"
      ;;
  esac

  # Use BEL (\a) instead of ST (\e\\) as the OSC terminator and use %b
  # to ensure we output literal bytes that won't be re-interpreted.
  printf "%b]8;;%s%b%s%b]8;;%b" "\e" "$url" "\a" "$text" "\e" "\a"
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
    # Using local variable + printf %s to avoid double-expansion
    local msg; printf -v msg "%b" "$1"
    printf "\e[38;5;5mDEBCRAFT DEBUG: %s (at line %s)\e[0m\n" "$msg" "$(caller)"
  }

  # Print the variable name and value in one "log_debug_var example" call
  function log_debug_var() {
    # Outputs variable type and contents, e.g 'declare -x ACTION="release"'
    # Using local variable + printf %s to avoid double-expansion
    local msg; printf -v msg "%b" "$(declare -p "$1")"
    printf "\e[38;5;5mDEBCRAFT DEBUG: %s (at %s:%s)\e[0m\n" "$msg" "${BASH_SOURCE[1]}" "${BASH_LINENO[0]}"
  }

  function log_debug_env() {
    printf "\e[38;5;5mDEBCRAFT DEBUG:\n"
    set | grep '^[A-Za-z_]' | grep -v '^[A-Za-z_].*()' | sort
    printf "\e[0m\n"
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
