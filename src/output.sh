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
