#!/bin/bash

# @TODO: Move all of this to run inside the container

log_info "Validate that the directory debian/patches/ contents and debian/patches/series file match by count"
if [ "$(find debian/patches/ -type f -not -name series | wc -l)" != "$(wc -l < debian/patches/series)" ]
then
  log_error "The directory debian/patches/ file count does not match that in debian/series. Check if these are unaccounted patches:"
  find debian/patches -type f -not -name series -printf "%P\n" | sort > /tmp/patches-directory-sorted
  sort debian/patches/series > /tmp/patches-series-sorted
  diff --side-by-side /tmp/patches-series-sorted /tmp/patches-directory-sorted
  exit 1
fi

#log_info "Validate that the files in debian/ are properly formatted and sorted"
#if [ -n "$(wrap-and-sort --wrap-always --dry-run)" ]
#then
#  log_error "The directory debian/ contains files that could be automatically formatted and sorted with 'wrap-and-sort':"
#  wrap-and-sort --wrap-always --dry-run --verbose
#  exit 1
#fi

log_info "Validate that the debian/rules can be parsed by Make"
if ! make --dry-run --makefile=debian/rules > /dev/null
then
  log_error "Make fails to parse the debian/rules file:"
  make --dry-run --makefile=debian/rules
  exit 1
fi

#log_info "Validate that all shell scripts in debian/rules pass Shellcheck"
#SH_SCRIPTS="$(grep -Irnw debian/ -e '^#!.*/sh' | sort -u |cut -d ':' -f 1 | xargs)"
#BASH_SCRIPTS="$(grep -Irnw debian/ -e '^#!.*/bash' | sort -u |cut -d ':' -f 1 | xargs)"
#if [ -n "$SH_SCRIPTS" ] || [ -n "$BASH_SCRIPTS" ]
#then
#  # shellcheck disable=SC2086 # intentional expansion of arguments
#  if ! shellcheck -x --shell=sh $SH_SCRIPTS > /dev/null || shellcheck -x --shell=bash $BASH_SCRIPTS > /dev/null
#  then
#      log_error "Shellcheck reported issues, please run it manually"
#      exit 1
#  fi
#fi

RELEASE="$(dpkg-parsechangelog  --show-field=distribution)"

# Remove longest pattern from end of variable, e.g. 'bookworm-security' would be 'bookworm'
# (https://tldp.org/LDP/abs/html/parameter-substitution.html)
RELEASE="${RELEASE%%-*}"

SERIES="$(get_ubuntu_equivalent_from_debian_release "$RELEASE")"

# Find the most recent builds
# shellcheck disable=SC2012
BUILD_DIR="$(ls --sort=time --format=single-column --group-directories-first --directory ../debcraft-build-* | head --lines=1)"

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
    backportpackage --yes --upload='$PPA' --destination='$SERIES' --suffix='~$BUILD_ID' '$DSC'
  "

  # Upload to Launchpad
  backportpackage --yes --upload="$PPA" --destination="$SERIES" --suffix="~$BUILD_ID" "$DSC"
fi
