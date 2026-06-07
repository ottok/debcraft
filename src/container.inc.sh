#!/bin/bash

# @TODO: Skip building container in vain repeatedly
# (if container already exists and is newer than debian/control mtime/ctime)
#
# podman images --noheading --filter reference="$CONTAINER" --format="table {{.ID}} {{.Repository}} {{.Tag}} {{.CreatedAt}} {{.CreatedSince}}"
# 3ea068db053c  localhost/debcraft-entr-debian-sid  latest      2023-12-10 02:36:49 +0000 UTC 5 hours ago
#

CONTAINER_DIR="$BUILD_DIRS_PATH/debcraft-container-$PACKAGE"

log_info "Building container '$CONTAINER' in '$CONTAINER_DIR' for build ID '$BUILD_ID'"

mkdir --parents "$CONTAINER_DIR"
cp --archive "$DEBCRAFT_LIB_DIR"/container/* "$CONTAINER_DIR"

# Make it visible what this temporary directory was used for
echo "[$(date --iso-8601=seconds)] Building container $CONTAINER for build $BUILD_ID" >> "$CONTAINER_DIR/status.log"

# Customize baseimage distribution release/seris to match package to be built
sed "s/FROM debian:sid/FROM $BASEIMAGE/" -i "$CONTAINER_DIR/Containerfile"

# Make package CI scripts available in container
if [ -d debian/ci ]
then
  log_info "Include the 'debian/ci/' subdirectory in the build container"
  cp --archive --verbose debian/ci "$CONTAINER_DIR/"
else
  # If "ci" subdirectory does not exist, for example after being removed from
  # the package, ensure it does not exist in container either
  rm --recursive --force "$CONTAINER_DIR/ci"
  # Ensure the COPY in the Containerfile will not fail on missing directory
  mkdir --parents "$CONTAINER_DIR/ci"
fi

# Make contents of extra repository available inside container when built
if [ -n "${DEBCRAFT_EXTRA_REPOSITORY}" ]
then
  log_info "Include extra repository in build container: ${DEBCRAFT_EXTRA_REPOSITORY[0]}"
  mkdir --parents "$CONTAINER_DIR/extra_repository_dir"
  for i in "${DEBCRAFT_EXTRA_REPOSITORY[0]}"/*.deb
  do
    cp --archive --verbose "$i" "$CONTAINER_DIR/extra_repository_dir/"
  done
else
  # If DEBCRAFT_EXTRA_REPOSITORY is no longer set, ensure no extra local
  # repository exists in container either
  rm --recursive --force "$CONTAINER_DIR/extra_repository_dir"
  # Ensure the COPY in the Containerfile will not fail on missing directory
  mkdir --parents "$CONTAINER_DIR/extra_repository_dir"
fi

# Customize preinstalled build dependencies to match the package to be built
cp --archive debian/control "$CONTAINER_DIR/"

# Force pulling new base image
# @TODO: Automatically use --pull when making sure dependencies are updated
# @TODO: Consider using '--cache-ttl=1h' in Podman 4.x series
if [ -n "$PULL" ]
then
  CONTAINER_BUILD_ARGS="${CONTAINER_BUILD_ARGS} --no-cache --pull=true"
  log_debug_var CONTAINER_BUILD_ARGS
fi

# Mount persistent apt cache directory into container build so downloaded .deb
# packages survive across image builds. Podman supports --volume during build;
# Docker does not, so this is Podman-only.
#
# Intentionally left unimplemented for Docker: `docker build` does not support
# bind-mounting host directories during the build phase (unlike Podman's
# `--volume`), and BuildKit cache mounts would require invasive Dockerfile
# syntax changes. Docker builds therefore start with an empty apt cache each
# time and re-download packages on every container rebuild.
# Note: `docker buildx build` (BuildKit) does support `RUN --mount=type=cache`,
# which could be an option if the project switched to BuildKit syntax.
if [[ "${CONTAINER_CMD:-}" == *podman* ]]
then
  mkdir -p "$APT_CACHE_DIR"
  # Pre-create partial directory with host ownership so apt does not create it
  # inside the container as an unmapped subuid
  mkdir -p "$APT_CACHE_DIR/partial"
  log_debug "Mounting apt cache directory '$APT_CACHE_DIR' into container build"
  CONTAINER_BUILD_ARGS="$CONTAINER_BUILD_ARGS --volume=$APT_CACHE_DIR:/var/cache/apt/archives"
fi
# Docker builds do not mount APT_CACHE_DIR; see comment above.

# Podman does not need '--file=Containerfile', but needed for Docker compatibility
# shellcheck disable=SC2086 # intentionally allow variable to expand to multiple arguments
$CONTAINER_CMD build  \
  --tag "$CONTAINER" \
  --build-arg SOURCE_DATE_EPOCH=0 \
  --iidfile="$CONTAINER_DIR/container-$BUILD_ID-iid" \
  --build-arg HOST_ARCH=$HOST_ARCH \
  $CONTAINER_BUILD_ARGS \
  --file="$CONTAINER_DIR/Containerfile" \
  "$CONTAINER_DIR" \
  | tee -a "$CONTAINER_DIR/build.log" \
  || FAILURE="true"

# @TODO: Redirect all output to log if too verbose?
# --logfile="$CONTAINER_DIR/container-$BUILD_ID.log" \

# Fix ownership of apt cache files created by container root user mapped to subuid
if [ -d "$APT_CACHE_DIR" ]
then
  find "$APT_CACHE_DIR" ! -uid "${UID}" -execdir chown --no-dereference "${UID}":"${GROUPS[0]}" {} + 2>/dev/null || true
fi

if [ -n "$FAILURE" ]
then
  log_error "Container build failed - see output above for details. If apt fails on missing packages, try '--pull' to build container from scratch."
  exit 1
fi
