#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

case "$1" in
  '')
    echo "The Debcraft downloader must be called with at least one parameter:"
    echo "  * url to git repository"
    echo "  * path to a .dsc file"
    echo "  * name of binary package, source package or command in Debian"
    ;;

  http://* | https://* | git@*)
    # Arguments with this form must be git urls
    #
    # @TODO: Use --depth=1 if gbp would support automatically fetching more
    # commits until it sees the merge on the upstream branch and has enough to
    # actually build the package
    echo "Clone git repository $1 with 'git-buildpackage' ('gbp clone')"
    gbp clone --verbose --pristine-tar "$1"
    ;;

  *.dsc)
    echo "Unpack $1 and associated Debian and source tar packages with 'dpkg-source'"
    # Use Debian source .dcs control file
    dpkg-source --extract "$1"
    ;;

  *)
    if [ "$(apt-cache showsrc "$1" | wc -l || true)" -gt 1 ]
    then
      # Check if it is a binary or source and try to get it with apt-source. If
      # 'apt-cache showsrc' yields no results it will output 'W: Unable to
      # locate package $TARGET' in stderr which would intentionally be visible
      # for the user. The stdout will also have one line of output. If there is
      # a result, the stdout would be much longer.
      echo "Download source package for '$1' with 'apt-get source'"
      apt-get source "$1"
    elif command -v "$1" > /dev/null
    then
      # As a last attempt, try to find what command the $TARGET might be, and
      # resolve the source package for it
      echo "Attempt to find source package for command '$1' with 'dpkg --search'"
      PACKAGE="$(dpkg --search "$(command -v "$1")" | cut --delimiter=':' --field 1 || true)"
      if [ -n "$PACKAGE" ]
      then
        echo "Download source package for '$PACKAGE'"
        apt-get source "$PACKAGE"
      else
        echo "Unable to find any Debian package for command '$1'"
        exit 1
      fi
    elif [ -f /var/lib/command-not-found/commands.db ]
    then
      PACKAGE="$(/usr/lib/command-not-found "$1" 2>&1 | grep --only-matching --perl-regexp "apt install \K([a-z0-9-]+)" | tail --lines=1 || true)"
      if [ -n "$PACKAGE" ]
      then
        echo "Download source package '$PACKAGE' for command '$1'"
        apt-get source "$PACKAGE"
      else
        echo "Unable to find any Debian package for command '$1' from commands.db"
        exit 1
      fi
    else
      echo "Unable to find any source package for argument '$1'"
      exit 1
    fi
    ;;
esac
