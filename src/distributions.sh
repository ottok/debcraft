#!/bin/bash

function get_baseimage_from_distribution_name() {
  case "$1" in
  unstable)
    echo "debian:sid"
    ;;
  *)
    echo "@TODO: Function $0 not implemented for $1" >&2
    exit 1
  esac
}
