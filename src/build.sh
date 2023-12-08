#!/bin/bash

# Use environment if set, otherwise use nice defaults
DEB_BUILD_OPTIONS="${DEB_BUILD_OPTIONS:-parallel=4 nocheck noautodbgsym}"
echo "Running with DEB_BUILD_OPTIONS=\"$DEB_BUILD_OPTIONS\""

# Clean up old files
(cd "${PWD}/.." && rm --force --verbose -- *.changes *.dsc *.deb)

# Reset ccache stats, silently
CCACHE_DIR="${PWD}"/../buildout/ccache ccache -z -s

# Clean tmp directory
rm --force --verbose "${PWD}"/../buildout/*.*

# Run build inside a contianer image with build dependencies defined in a Podmanfile
# --tty needed for session to have colors automatically
# --interactive needed for Ctrl+C to cancel build and stop container (and not
# just exit tty)
# NOTE!: If build fails, script fails here (due to set pipefail) and there
# will be no notifications or sounds to user.
# shellcheck disable=SC2086
podman run --name "$CONTAINER" \
    $CONTAINER_RUN_ARGS \
    --interactive --tty --rm \
    --shm-size=1G \
    --cpus=4 \
    -v "${PWD}/../buildout":/tmp/build -v "${PWD}/../buildout/ccache":/.ccache \
    -v "$TARGET":/tmp/build/source -w /tmp/build/source \
    -e DEB_BUILD_OPTIONS="$DEB_BUILD_OPTIONS" -e CCACHE_DIR=/.ccache \
    "$CONTAINER" \
    gbp buildpackage --git-builder='debuild --no-lintian --no-sign -i -I' \
    | tee "build-$BUILD_ID.log"

# Podman has user mapping by default. If using Docker, add '--user="$(id -u)"'
# in the command above to enable user mapping.
echo "----------------------------------------------------------------------"
echo # Space to make output more readable

# Show ccache stats
CCACHE_DIR="${PWD}"/../buildout/ccache ccache -s

# Copy generated files to parent directory after successful run
if cp -ra "${PWD}"/../buildout/*.* . > /dev/null 2>&1
then

  # clean up any old filelist from same commit
  rm -f "${PWD}/../filelist-$BUILD_ID.log"
  for package in *.deb
  do
    echo "$package" | cut -d '_' -f 1 >> \
      "${PWD}/../filelist-$BUILD_ID.log"
    dpkg-deb -c "$package" | awk '{print $1 " " $2 " " $6 " " $7 " " $8}' | sort -k 3 >> \
      "${PWD}/../filelist-$BUILD_ID.log"
    echo "------------------------------------------------" >> \
      "${PWD}/../filelist-$BUILD_ID.log"
  done
  echo "${PWD}/../filelist-$BUILD_ID.log created"

  # Run Lintian, but don't exit on errors since 'unstable' and 'sid' releases
  # will likely always emit errors if package complex enough
  # Don't use color, otherwise logs become unreadable and diffs messy
  podman run --name "$CONTAINER" \
    $CONTAINER_RUN_ARGS \
    --interactive --tty --rm \
    --shm-size=1G \
    --cpus=4 \
    -v "${PWD}/../buildout":/tmp/build \
    -w /tmp/build \
    "$CONTAINER" \
    lintian -EvIL +pedantic --profile=debian --color=never ./*.changes \
    | tee "${PWD}/../lintian-$BUILD_ID.log" || true
fi
