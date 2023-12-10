#!/bin/bash

# Given a debian/changelog distribution pocket name, return container tag
function get_baseimage_from_distribution_name() {

  # Strip additional parts, e.g. 'bookworm-security' would be 'bookworm'
  NAME="${1//-*/}"

  case "$NAME" in
  unstable)
    echo "debian:sid"
    ;;
  experimental | sid | trixie | bookworm | bullseye | buster)
    echo "debian:$NAME"
    ;;
  noble | jammy | focal)
    echo "ubuntu:$NAME"
    ;;
  *)
    log_warn "@TODO: Container baseimage mapping not implemented for $NAME"
    exit 1
  esac

}
