#!/bin/bash

# Given a debian/changelog distribution pocket name, return container tag
function get_baseimage_from_distribution_name() {

  # Keep '-backports' suffix as e.g. 'bookworm-backports' is a valid container
  # image name at https://hub.docker.com/_/debian/tags
  # Remove '-security' suffix, e.g. 'bookworm-security' would be 'bookworm'
  # (https://tldp.org/LDP/abs/html/parameter-substitution.html)
  NAME="${1%%-security}"
  # Remove -proposed-updates suffix as it is not a container tag
  NAME="${NAME%%-proposed-updates}"

  # @TODO: Compary to how sbuild does this based
  # Debian: -security, -updates, -backports, -backports-sloppy, -proposed-updates, -lts
  # At https://hub.docker.com/_/debian/tags?name=bookworm- bookworm-backports exist, but not the others
  # Ubuntu: -security, -updates, -backports, -proposed, -esm
  # At https://hub.docker.com/_/ubuntu/tags?name=noble- none of above seem to exist

  # @TODO: Ideally read /usr/share/distro-info/debian.csv and ubuntu.csv directly
  case "$NAME" in
    unstable)
      echo "debian:sid"
      ;;
    experimental | sid | trixie* | bookworm* | bullseye* | buster* | stretch* )
      echo "debian:$NAME"
      ;;
    questing* | plucky* | oracular* | noble* | mantic* | jammy* | focal*)
      echo "ubuntu:$NAME"
      ;;
    *)
      log_error "@TODO: Container baseimage mapping not implemented for $NAME"
      exit 1
  esac

}

function get_ubuntu_equivalent_from_debian_release() {

  # Remove any suffix, e.g. 'bookworm-security' or 'bookworm-backports' would be
  # just 'bookworm' for the sake of Ubuntu equivalent lookup
  # (https://tldp.org/LDP/abs/html/parameter-substitution.html)
  SERIES="${1%%-*}"

  # Current Launchpad Debian Sid equivalent
  if [ "$SERIES" == "UNRELEASED" ] ||
     [ "$SERIES" == "sid" ] ||
     [ "$SERIES" == "unstable" ] ||
     [ "$SERIES" == "experimental" ]
  then
    # NOTE! This line needs to be updated 2x year
    # @TODO: Ideally read last line from /usr/share/distro-info/ubuntu.csv directly
    echo "questing"
  else
    # Historical equivalents for each Ubuntu release based on what Debian
    # release happened around the same time and thus have most of the package
    # versions identical in the repository
    #
    # @TODO: Ideally read /usr/share/distro-info/ubuntu.csv directly
    case $SERIES in
      questing | plucky | oracular | noble | mantic | lunar | jammy | hirsute | focal | disco | bionic | zesty)
        # For every Ubuntu name always return it as-is
        echo "$SERIES"
        ;;
      trixie)
        # August 2025
        echo "plucky"
        ;;
      bookworm)
        # June 2023
        echo "lunar"
        ;;
      bullseye)
        # August 2021
        echo "hirsute" # or impish
        ;;
      buster)
        # July 2019
        echo "disco" # or eoan
        ;;
      stretch)
        # June 2017
        echo "zesty" # or artful
        ;;
      *)
        log_error "@TODO: Debian to Ubuntu release mapping not implemented for $SERIES"
        exit 1
    esac
  fi

}
