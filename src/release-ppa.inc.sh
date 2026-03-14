#!/bin/bash

# Delete first part from BASEIMAGE (e.g. 'debian:' form 'debian:sid') and map
# remaining release name into a Ubuntu series name
SERIES="$(get_ubuntu_equivalent_from_debian_release "${BASEIMAGE##*:}")"

# Newline to separate output from whatever preceded
echo

if [ -z "$DEBCRAFT_PPA" ] || [ -n "$DEBUG" ]
then
  log_info "No environment variable DEBCRAFT_PPA defined, skip upload to Launchpad"
  echo
  log_info "See $(clickable_link "help.launchpad.net/Packaging/PPA") on how anybody can sign"
  log_info "up for an account on Launchpad to build Debian/Ubuntu packages on"
  log_info "multiple architectures and release them in a personal repository."
  return # skip the rest of this file and return bach to calling script
fi

# ppa:otto/ppa -> otto/ppa
PPA="${DEBCRAFT_PPA#*:}"
# otto/ppa -> otto
PPA_OWNER="${PPA%/*}"
# otto/ppa -> ppa
PPA_NAME="${PPA#*/}"

# Launchpad uploads depend on signed source package, thus can't be done inside a container
if ! command -v backportpackage > /dev/null
then
  log_error "No 'backportpackage' found, please install 'ubuntu-dev-tools'"
  exit 1
fi

while true
do
  read -r -p "Upload to PPA '$DEBCRAFT_PPA' release '$SERIES' [Y|n]?  " selection
  case $selection in
    ''|[Yy]*)
      log_info "Proceed with upload"
      break
      ;;
    [Nn]*)
      log_warn "Upload to PPA skipped"
      return # skip the rest of this file and return bach to calling script
      # no break needed due to 'return' above
      ;;
    *)
      log_warn "Invalid selection. Please enter y or n."
      ;;
  esac
done

# Run backportpackage in the RELEASE_DIR
cd "$RELEASE_DIR" > /dev/null || (log_error "Unable to change directory to $RELEASE_DIR"; exit 1)

# There should be exactly one .dsc file in the release directory
DSC="$(find . -maxdepth 1 -name "*.dsc" -print -quit)"

# Always build locally first (without --upload)
backportpackage --yes --dont-sign --release-pocket --destination="$SERIES" --suffix="~$BUILD_ID" --workdir="$RELEASE_DIR" "$DSC" | tee -a "$RELEASE_DIR/backportpackage.log" 2>&1

# Find the backports generated .changes file (with '~bpo' in the name)
BPO_CHANGES_FILE=$(find "$RELEASE_DIR" -maxdepth 1 -name "*~bpo*_source.changes" -print -quit)

# Extract Debian revision e.g. "26.4.25-2" -> "2"
DEBIAN_REVISION="${DEBIAN_VERSION##*-}"

case "$DEBIAN_REVISION" in
  0*|1*)
    # Initial release starting with -1 (or .e.g -0ubuntu1) - keep orig.tar.*
    ;;
  *)
    # Follow-up release - remove orig.tar.*
    log_info "Detected revision -$DEBIAN_REVISION - uploading without orig.tar.* to save bandwidth"
    sed -i '/\.orig\.tar\./d' "$BPO_CHANGES_FILE"
    ;;
esac

# Re-sign the .changes file (always re-sign to ensure validity)
debsign --re-sign "$BPO_CHANGES_FILE" > "$RELEASE_DIR/debsign.log" 2>&1

dput "$DEBCRAFT_PPA" "$BPO_CHANGES_FILE" # | tee -a "$RELEASE_DIR/dput.log" 2>&1
PPA_URL="launchpad.net/~${PPA_OWNER}/+archive/ubuntu/${PPA_NAME}/+builds?build_text=&build_state=all"
log_info "Review build results at $(clickable_link "$PPA_URL")"

# Return to original directory where sources reside, and don't output anything
cd - > /dev/null || exit 1
