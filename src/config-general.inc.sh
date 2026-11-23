#!/bin/bash

# The build directories path is defaulted in debcraft.sh, before actions are
# dispatched, as 'prune' needs the path but must not create the directory
mkdir -p "$BUILD_DIRS_PATH"

# If no explicit value, try to autodetect and default to Podman if both installed
if [ -z "$CONTAINER_CMD" ]
then
  if command -v podman > /dev/null
  then
    CONTAINER_CMD="podman"
  elif command -v docker > /dev/null
  then
    CONTAINER_CMD="docker"
  elif command -v distrobox-host-exec >/dev/null 2>&1 && distrobox-host-exec podman --version >/dev/null 2>&1
  then
    CONTAINER_CMD="distrobox-host-exec podman"
  elif command -v distrobox-host-exec >/dev/null 2>&1 && distrobox-host-exec docker --version >/dev/null 2>&1
  then
    CONTAINER_CMD="distrobox-host-exec docker"
  else
    log_error "Either 'podman' or 'docker' must be available to use Debcraft"
    exit 1
  fi
fi

# Determine container type and customizations if needed
version=$(${CONTAINER_CMD} --version)
CONTAINER_SUPPORTS_OVERLAYS=false
if [[ $version =~ 'podman' ]]
then
  CONTAINER_TYPE='podman'
  CONTAINER_RUN_ARGS=("--userns=keep-id")

  # Podman 4.3+ can mount a source directory as an overlay filesystem, which
  # allows building on a copy without actually copying anything. 4.3 is the
  # first version that can also run a container whose working directory is on
  # the overlay volume (https://github.com/containers/podman/issues/15789).
  # Overlay mounts only work for a local Podman that does not itself run
  # inside a container. DEBCRAFT_DISABLE_OVERLAY allows explicitly opting out,
  # which the test suite uses to also exercise the shared-clone fallback.
  CONTAINER_VERSION="$(echo "$version" | \
    grep --only-matching --extended-regexp '[0-9]+\.[0-9]+' | head --lines=1)"
  if [ -z "${DEBCRAFT_DISABLE_OVERLAY:-}" ] &&
     printf '4.3\n%s\n' "$CONTAINER_VERSION" | sort --version-sort --check=quiet &&
     [ -z "${container:-}" ] &&
     [ ! -e /.dockerenv ] && [ ! -e /run/.containerenv ]
  then
    CONTAINER_SUPPORTS_OVERLAYS=true
  fi
elif [[ $version =~ 'Docker' ]]
then
  CONTAINER_TYPE='docker'
  CONTAINER_RUN_ARGS=("--user=${UID}")
else
  log_error "Invalid value in --container-command=$CONTAINER_CMD"
  exit 1
fi

# Use [ -t 1 ] to check if stdout (file descriptor 1) is attached to a terminal
# in order to later decide if `--tty` can be used when launching containers.
# When running inside a CI system never try to attach a terminal.
if [ -t 1 ] && [ -z "${CI:-}" ]
then
  CONTAINER_CAN_HAVE_TTY=true
fi

# Environment variables to pass into the containers. List them explicitly as
# Docker does not expand wildcards in '--env', while Podman does.
CONTAINER_ENV_VARS=(
  DEB_BUILD_OPTIONS
  DEB_BUILD_PROFILES
  DEBEMAIL
  DEBNAME
  DEBFULLNAME
  DEBCRAFT_FULL_BUILD
)

# Build the corresponding --env arguments for variables that are set. This is
# called before each container run so that variables exported later, such as
# DEBCRAFT_FULL_BUILD, are included as well.
function add_container_env_args() {
  local env_var
  CONTAINER_ENV_ARGS=()
  for env_var in "${CONTAINER_ENV_VARS[@]}"
  do
    if [ -n "${!env_var+set}" ]
    then
      CONTAINER_ENV_ARGS+=("--env=$env_var")
    fi
  done
}

# Explicit exports
export CONTAINER_CMD
export CONTAINER_TYPE
export CONTAINER_RUN_ARGS
export CONTAINER_ENV_ARGS
export CONTAINER_CAN_HAVE_TTY
export CONTAINER_SUPPORTS_OVERLAYS
