#!/bin/bash

# Given a debian/changelog distribution pocket name, return container tag
function get_baseimage_from_distribution_name() {
  case "$1" in
  unstable)
    echo "debian:sid"
    ;;
  *)
    log_warn "@TODO: Function $0 not implemented for $1"
    exit 1
  esac
}
