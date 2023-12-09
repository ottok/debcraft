#!/bin/bash

function log_error() {
  echo "ERROR: $1" >&2
}

function log_warn() {
  echo "WARNING: $1" >&2
}

function log_info() {
  echo "$1"
}

if [ -z "$DEBUG" ]
then
  # If not running in DEBUG mode, don't do anything on these
  function log_debug() {
    true
  }
  function log_debug_var() {
    true
  }
else
  echo "DEBUG: Running Debcraft in debug mode"

  # Print debug information not normally visible
  function log_debug() {
    echo "DEBUG: $1"
  }

  # Print the variable name and value in one "log_debug_var example" call
  function log_debug_var() {
    # E.g. "example:"
    echo -n "$1: "
    # E.g. value of $example
    eval 'echo $'"$1"
  }
fi
