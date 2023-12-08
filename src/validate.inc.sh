#!/bin/bash

# Find the most recent builds
# shellcheck disable=SC2012
BUILD_DIR="$(ls -t -r -d -1 build-*/ | tail -n 1)"

# Validate that the build actually passed and .dsc exists

# Execute the rest of the script in the build directory
cd "$BUILD_DIR" || exit 1

# Suggest upload only if *.dsc built
if ls ./*.dsc > /dev/null 2>&1
then
  DSC="$(ls ./*.dsc)"

  # Default to personal PPA if no other set
  if [ -z "$PPA" ]
  then
    PPA="ppa:$(id -un)/ppa"
  fi

  SERIES=$(cd "$TARGET" || exit 1; dpkg-parsechangelog -S distribution)

  # Strip away any -updates or -security components before upload
  SERIES=$(echo "$SERIES" | sed 's/-updates//g' | sed 's/-security//g')

  # Current Launchpad Debian Sid equivalent
  if [ "$SERIES" = 'unstable' ] || [ "$SERIES" = 'sid' ] || [ "$SERIES" = 'UNRELEASED' ] || [ "$SERIES" = 'experimental' ]
  then
    SERIES='noble'
  fi

  # Historical equivalents
  case $SERIES in
    bookworm)
      # June 2023
      SERIES='lunar'
      ;;
    bullseye)
      # August 2021
      SERIES='hirsute' # or impish
      ;;
    buster)
      # July 2019
      SERIES='disco' # or eoan
      ;;
    stretch)
      # June 2017
      SERIES='zesty' # or artful
      ;;
  esac
  echo # Space to make output more readable

  # POSIX sh does not support 'read -p' so run int via bash
  # shellcheck disable=SC2153 # BUILD_DIR is defined in calling parent Debcraft
  read -r -p "Press Ctrl+C to cancel or press enter to proceed with:
  backportpackage -y -u $PPA -d $SERIES -S ~$BUILD_ID $DSC
  "

  # Upload to Launchpad
  backportpackage -y -u "$PPA" -d "$SERIES" -S "~$BUILD_ID" "$DSC"
fi
