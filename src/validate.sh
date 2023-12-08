#!/bin/bash

# Suggest upload only if *.dsc built
if ls ./*.dsc > /dev/null 2>&1
then
  DSC="$(ls ./*.dsc)"

  # Default to personal PPA if no other set
  if [ -z "$PPA" ]
  then
    PPA="ppa:$(id -un)/ppa"
  fi

  SERIES=$(cd "$TARGET"; dpkg-parsechangelog -S distribution)

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


  # The Launchpad upload cannot have any extra Debian/Ubuntu version string
  # components, therefore convert all extra characters to simply dots.
  BRANCH_NAME=${BRANCH_NAME//-/.}

  # Notify
  notify-send --icon=/usr/share/icons/Humanity/actions/48/dialog-apply.svg \
    --urgency=low "Build of $TARGET at $COMMIT_ID (branch $BRANCH_NAME) ready"
  paplay --volume=65536 /usr/share/sounds/freedesktop/stereo/complete.oga

  echo # Space to make output more readable

  # POSIX sh does not support 'read -p' so run int via bash
  read -r -p "Press Ctrl+C to cancel or press enter to proceed with:
  backportpackage -y -u $PPA -d $SERIES -S ~$(date '+%s').$COMMIT_ID+$BRANCH_NAME $DSC
  "

  # Upload to Launchpad
  backportpackage -y -u "$PPA" -d "$SERIES" \
    -S "~$(date '+%s').$COMMIT_ID.$BRANCH_NAME" "$DSC"
fi
