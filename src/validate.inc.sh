#!/bin/bash

sleep 5 &
spinner $! "docker build"

exit 1

RELEASE="$(dpkg-parsechangelog  --show-field=distribution)"

# Strip additional parts (-security, -updates)
# e.g. 'bookworm-security' would be 'bookworm'
RELEASE="${RELEASE//-*}"

SERIES="$(get_ubuntu_equivalent_from_debian_release "$RELEASE")"

# Find the most recent builds
# shellcheck disable=SC2012
BUILD_DIR="$(ls -t -r -d -1 ../debcraft-build-*/ | tail -n 1)"

# Validate that the build actually passed and .dsc exists

# Execute the rest of the script in the build directory
cd "$BUILD_DIR" || exit 1

# Suggest upload only if *.dsc built
if ls ./*.dsc > /dev/null 2>&1
then
  DSC="$(ls ./*.dsc)"

  # Default to personal PPA if no other set
  # @TODO: Make this configurable as we can't assume everyone has their local
  # username same as their Launchpad username
  if [ -z "$PPA" ]
  then
    PPA="ppa:$(id -un)/ppa"
  fi

  # @TODO: Launchpad uploads depend on signed source package, thus can't really
  # fully done inside a container -> ask users to run debsign+dput manually
  # shellcheck disable=SC2153 # BUILD_DIR is defined in calling parent Debcraft
  read -r -p "Press Ctrl+C to cancel or press enter to proceed with:
  backportpackage -y -u $PPA -d $SERIES -S ~$BUILD_ID $DSC
  "

  # Upload to Launchpad
  backportpackage --yes --upload="$PPA" --destination="$SERIES" --suffix="~$BUILD_ID" "$DSC"
fi
