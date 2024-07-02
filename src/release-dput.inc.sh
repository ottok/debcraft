#!/bin/bash

# Newline to separate output from whatever preceded
echo

if [ -f ~/.devscripts ] && [ -z "$DEBUG" ]
then
  log_info "After thorough review, sign the package and upload with:"
  log_info "  (cd $RELEASE_DIR && debsign *.changes && dput ftp-master *.changes)"
  # @TODO: Or from dput-ng recommend `dput --full-upload-log *.changes`?
  # @TODO: Or for special cases like stable updates recommend `dput --delayed=7 ftp-master *.changes`?
  log_info
  log_info "Remember to tag the exact commit that was uploaded about 10 minutes"
  log_info "later after seeing acknowledgement email from ftp-master:"
  log_info "  gbp tag --verbose && gbp push --verbose"
else
  log_info "To submit a package to Debian or Ubuntu officially you need to have"
  log_info "your PGP key in the Debian/Ubuntu keyring and configured in ~/.devscripts"
  log_info "Before you can be an uploading Debian Developer, you need to have a"
  log_info "track record of sponsored package maintainership and high quality"
  log_info "contributions - see https://www.debian.org/devel/join/newmaint"
  log_info
  log_info "Becoming a DD is highly recommended if you have what it takes!"
fi
