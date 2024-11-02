#!/bin/bash

# Given a debian/changelog distribution pocket name, return container tag
function get_baseimage_from_distribution_name() {

  # Remove longest pattern from end of variable, e.g. 'bookworm-security' would be 'bookworm'
  # (https://tldp.org/LDP/abs/html/parameter-substitution.html)
  NAME="${1%%-*}"

  # @TODO: Ideally read /usr/share/distro-info/debian.csv and ubuntu.csv directly
  case "$NAME" in
    unstable)
      echo "debian:sid"
      ;;
    experimental | sid | trixie | bookworm | bullseye | buster)
      echo "debian:$NAME"
      ;;
    plucky | oracular | noble | mantic | jammy | focal)
      echo "ubuntu:$NAME"
      ;;
    *)
      log_error "@TODO: Container baseimage mapping not implemented for $NAME"
      exit 1
  esac

}

function get_ubuntu_equivalent_from_debian_release() {

  # Remove longest pattern from end of variable, e.g. 'bookworm-security' would be 'bookworm'
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
    echo "plucky"
  else
    # Historical equivalents for each Ubuntu release based on what Debian
    # release happened around the same time and thus have most of the package
    # versions identical in the repository
    #
    # @TODO: Ideally read /usr/share/distro-info/ubuntu.csv directly
    case $SERIES in
      plucky | oracular | noble | mantic | lunar | jammy | hirsute | focal | disco | bionic | zesty)
        # For every Ubuntu name always return it as-is
        echo "$SERIES"
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
