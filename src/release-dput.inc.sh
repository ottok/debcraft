#!/bin/bash

# Newline to separate output from whatever preceded
echo

if [ -z "$DEBUG" ] && {
    [ -f ~/.devscripts ] || {
      [ -n "$DEBSIGN_KEYID" ] && [ -n "$DEBEMAIL" ] && [ -n "$DEBFULLNAME" ]
    }
  }
then
  log_info "After thorough review, sign the package and upload with:"

  if [[ $BASEIMAGE == ubuntu:* ]]
  then
    DPUT_CONFIG="ubuntu"
  else
    DPUT_CONFIG="ftp-master"
  fi

  log_info "  (cd $RELEASE_DIR && debsign *.changes && dput $DPUT_CONFIG *.changes)"

  # @TODO: Or from dput-ng recommend `dput --full-upload-log *.changes`?
  # @TODO: Or for special cases like stable updates recommend `dput --delayed=7 ftp-master *.changes`?
  log_info
  log_info "Remember to tag the exact commit that was uploaded about 10 minutes"
  log_info "later after seeing acknowledgement email from ftp-master:"
  log_info "  gbp tag --verbose --ignore-new && gbp push --verbose"
else
  log_info "To submit a package to Debian or Ubuntu officially you need to have"
  log_info "your PGP key in the Debian/Ubuntu keyring, and configured in"
  # shellcheck disable=2088  # tilde not intended to be expanded on this line
  log_info "~/.devscripts or the DEBSIGN_KEYID/DEBFULLNAME/DEBEMAIL environment"
  log_info "variables defined in your shell."
  log_info "Before you can be an uploading Debian Developer, you need to have a"
  log_info "track record of sponsored package maintainership and high quality"
  log_info "contributions - see https://www.debian.org/devel/join/newmaint"
  log_info
  log_info "Becoming a DD is highly recommended if you have what it takes!"
fi
