#!/bin/bash

# Delete first part from BASEIMAGE (e.g. 'debian:' form 'debian:sid') and map
# remaining release name into a Ubuntu series name
SERIES="$(get_ubuntu_equivalent_from_debian_release "${BASEIMAGE##*:}")"

# Newline to separate output from whatever preceded
echo

if [ -z "$DEBCRAFT_PPA" ] || [ -n "$DEBUG" ]
then
  log_info "No DEBCRAFT_PPA defined, skip upload to Launchpad"
  echo
  log_info "See https://help.launchpad.net/Packaging/PPA on how anybody can sign"
  log_info "up for an account on Launchpad to build Debian/Ubuntu packages on"
  log_info "multiple architectures and release them in a personal repository"
  return # skip the rest of this file and return bach to calling script
fi

log_info "DEBCRAFT_PPA set as '$DEBCRAFT_PPA'"

# ppa:otto/ppa -> otto/ppa
PPA="${DEBCRAFT_PPA#*:}"
# otto/ppa -> otto
PPA_OWNER="${PPA%/*}"
# otto/ppa -> ppa
PPA_NAME="${PPA#*/}"

# Launchpad uploads depend on signed source package, thus can't be done inside a container
if ! command -v backportpackage > /dev/null
then
  log_error "No 'backportpackage found, please install 'ubuntu-dev-tools'"
  exit 1
fi

# Run backportpackage in the RELEASE_DIR
cd "$RELEASE_DIR" || exit 1

DSC="$(ls ./*.dsc)"
CMD="backportpackage --yes --upload='$DEBCRAFT_PPA' --destination='$SERIES' --suffix='~$BUILD_ID' '$DSC'"

echo
read -r -p "Press Ctrl+C to cancel or press enter to proceed with:
$CMD
"

# If Ctrl+C was not issued, upload to Launchpad
eval "$CMD"

# Return to original directory where sources reside
cd - || exit 1

log_info "Review build results at https://launchpad.net/~${PPA_OWNER}/+archive/ubuntu/${PPA_NAME}/+builds?build_text=&build_state=all"
