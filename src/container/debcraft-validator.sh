#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

VALIDATION_ERRORS=()

log_info "Validating that the directory debian/patches/ contents and debian/patches/series file match by count..."
if [ "$(find debian/patches/ -type f -not -name series | wc -l)" != "$(wc -l < debian/patches/series)" ]
then
  log_error "The directory debian/patches/ file count does not match that in debian/series. Check if these are unaccounted patches:"
  find debian/patches -type f -not -name series -printf "%P\n" | sort > /tmp/patches-directory-sorted
  sort debian/patches/series > /tmp/patches-series-sorted
  diff --side-by-side /tmp/patches-series-sorted /tmp/patches-directory-sorted
  VALIDATION_ERRORS+=('patches-mismatch')
fi

log_info "Validating that the files in debian/ are properly formatted and sorted..."
if [ -n "$(wrap-and-sort --wrap-always --dry-run)" ]
then
  log_error "The directory debian/ contains files that could be automatically formatted and sorted with 'wrap-and-sort':"
  wrap-and-sort --wrap-always --dry-run
  VALIDATION_ERRORS+=('wrap-and-sort')
fi

log_info "Validating that the debian/rules can be parsed by Make..."
if ! make --dry-run --makefile=debian/rules > /dev/null
then
  log_error "Make fails to parse the debian/rules file:"
  make --dry-run --makefile=debian/rules
  VALIDATION_ERRORS+=('debian-rules-syntax')
fi

log_info "Validating that all shell scripts in debian/rules pass Shellcheck..."
SH_SCRIPTS="$(grep -Irnw debian/ -e '^#!.*/sh' | sort -u |cut -d ':' -f 1 | xargs)"
BASH_SCRIPTS="$(grep -Irnw debian/ -e '^#!.*/bash' | sort -u |cut -d ':' -f 1 | xargs)"
if [ -n "$SH_SCRIPTS" ] || [ -n "$BASH_SCRIPTS" ]
then
  # shellcheck disable=SC2086 # intentional expansion of arguments
  if ! shellcheck -x --shell=sh $SH_SCRIPTS > /dev/null || ! shellcheck -x --shell=bash $BASH_SCRIPTS > /dev/null
  then
    log_error "Shellcheck reported issues, please run it manually"
    VALIDATION_ERRORS+=('shellcheck')
  fi
fi

# Emit non-zero exit code if there was errors
if [ -n "${VALIDATION_ERRORS[*]}" ]
then
  exit 1
fi
