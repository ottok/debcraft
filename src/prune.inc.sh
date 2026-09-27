#!/bin/bash

# How old files and directories must be to be pruned, unless the user asks for
# something else with '--older-than'
PRUNE_AGE_DAYS="${PRUNE_AGE_DAYS:-365}"

# How many items the run has deleted so far
PRUNED_ITEMS=0

# Build and release directories of any age
PRUNE_BUILD_DIRS=(-maxdepth 1 \( -name "debcraft-build-*" \
                   -o -name "debcraft-release-*" \) -type d)

# Artifacts a successful build or release leaves behind. Logs and .buildinfo
# files are deliberately not matched because they are still needed for a
# release and for showing the logs of a past build.
PRUNE_ARTIFACTS=(-type f \( -name "*.deb" -o -name "*.orig.tar.*" \
                 -o -name "*.debian.tar.xz" \))

# Print the number of bytes that everything a find expression matches occupies
# Usage: prune_bytes [find arguments]
prune_bytes() {
  local total=0
  local size

  # All the matched items are measured with a single 'du' run instead of one
  # run per item, as only the sum of their sizes is of interest here. The size
  # and the path are read NUL-separated, so that a path with a newline in it
  # cannot be mistaken for a size of its own
  while IFS=$'\t' read -r -d '' size _
  do
    total=$((total + size))
  done < <(find "$@" -print0 2>/dev/null \
             | du --summarize --block-size=1 --null --files0-from=- 2>/dev/null)

  echo "$total"
}

# Print a number of bytes in a form a human can read at a glance
# Usage: prune_human <bytes>
prune_human() {
  numfmt --to=iec --suffix=B "$1"
}

# Print how much disk space everything a find expression matches occupies
# Usage: prune_size [find arguments]
prune_size() {
  prune_human "$(prune_bytes "$@")"
}

# Print one row of the disk usage report
# Usage: prune_report_row <bytes> <description>
#
# The number and the unit of the size get a column each, so that the units line
# up even though the sizes do not all have the same number of digits. What the
# size is of is in its description, which names the directories it occupies.
prune_report_row() {
  local size number unit

  # Strip the unit off the size, longest match first so that the whole of a two
  # letter unit goes and not only its last letter
  size=$(prune_human "$1")
  number="${size%%[A-Z]*}"
  unit="${size##*[!A-Z]}"

  printf '  %6s %-2s  %s\n' "$number" "$unit" "$2"
}

# Report how much disk space Debcraft occupies, so that the sections below can
# be seen deleting a part of it rather than appearing to delete all of it. The
# artifacts of builds and releases are counted as part of the build directories
# that hold them, and are broken out only as a detail, so that the total is not
# inflated by counting the same bytes twice.
#
# The types of content are matched here separately from the sections below,
# because a report of everything comes first while the sections match only what
# is old enough to prune.
prune_report_usage() {
  local build_dirs build_dirs_description
  local release_dirs release_dirs_description
  local cache_dirs cache_dirs_description
  local container_dirs container_dirs_description
  local legacy_dirs legacy_dirs_description
  local cache_path

  # Show the build directories path the way a user would write it, as the full
  # path of a cache directory is long enough to push the report off the screen.
  # Shorten it only when it really is below the home directory: a home of just
  # / is a prefix of every absolute path, and replacing it would leave the rest
  # of the path without its first directory
  # shellcheck disable=SC2088 # tilde is literal text for the report, not expanded
  case "$BUILD_DIRS_PATH" in
    "$HOME"/*) cache_path="~/${BUILD_DIRS_PATH#"$HOME"/}" ;;
    *) cache_path="$BUILD_DIRS_PATH" ;;
  esac

  container_dirs=$(prune_bytes "$BUILD_DIRS_PATH" -maxdepth 1 -name "debcraft-container-*" -type d)
  container_dirs_description="in $cache_path/debcraft-container-* directories"
  cache_dirs=$(prune_bytes "$BUILD_DIRS_PATH" -maxdepth 1 -name "debcraft-cache-*" -type d)
  cache_dirs_description="in $cache_path/debcraft-cache-* directories"
  build_dirs=$(prune_bytes "$BUILD_DIRS_PATH" -maxdepth 1 -name "debcraft-build-*" -type d)
  build_dirs_description="in $cache_path/debcraft-build-* directories"
  release_dirs=$(prune_bytes "$BUILD_DIRS_PATH" -maxdepth 1 -name "debcraft-release-*" -type d)
  release_dirs_description="in $cache_path/debcraft-release-* directories"

  # The total covers the build directories path and what is in it, while the
  # container directories of the legacy Debcraft version reported below are in
  # source trees and outside of it
  echo
  log_info "Debcraft is using $(prune_human $((build_dirs + release_dirs + cache_dirs + container_dirs))) of disk space:"
  prune_report_row "$build_dirs" "$build_dirs_description"
  prune_report_row "$release_dirs" "$release_dirs_description"
  prune_report_row "$cache_dirs" "$cache_dirs_description"
  prune_report_row "$container_dirs" "$container_dirs_description"

  # This code section can be deleted in the future as only a small number of
  # users ran the legacy Debcraft version that created container directories in
  # source trees and deleting them is a one-off operation
  if [ -n "${HOME:-}" ] && [ "$HOME" != "/" ]
  then
    legacy_dirs=$(prune_bytes "$HOME" -maxdepth 3 -name "debcraft-container-*" -type d \
                  ! -path "${BUILD_DIRS_PATH}/*")

    # Only report this for users that have legacy directories still around
    if [ "$legacy_dirs" -gt 0 ]
    then
      legacy_dirs_description="in legacy debcraft-container-* directories outside $cache_path"
      prune_report_row "$legacy_dirs" "$legacy_dirs_description"
    fi
  fi
}

# Interactively prune the items that a find expression matches, one section of
# related items at a time.
#
# Usage: prune_section "title" [find arguments]
#
# The find arguments must consist of tests only, i.e. no action, because the
# matched paths are printed NUL-separated by a -print0 that is appended here.
# They must not match any item that is worth keeping.
prune_section() {
  local title="$1"
  shift 1

  # All the items are matched in a single pass, NUL-separated, so that they can
  # be counted, listed and deleted without running find over and over again
  local -a items=()
  mapfile -d '' -t items < <(find "$@" -print0 2>/dev/null)
  local count="${#items[@]}"

  echo
  log_info "$title"

  if [ "$count" -eq 0 ]
  then
    echo "None to prune."
    return
  fi

  echo "Found $count to prune:"

  # A list of up to 20 items is short enough to be shown in full. Anything
  # longer is abbreviated in the middle, by leaving out the items between the
  # first and the last eight, which shows the user that the list was cut
  # without hiding either end of it
  if [ "$count" -le 20 ]
  then
    printf '  %s\n' "${items[@]}"
  else
    printf '  %s\n' "${items[@]:0:8}"
    echo "  ..."
    printf '  %s\n' "${items[@]: -8}"
  fi

  # Confirm the deletion, unless 'prune' was told not to ask anything
  if [ -z "$DEBCRAFT_YES" ]
  then
    # If the confirmation cannot be read, e.g. when there is no terminal, the
    # unset -e of the parent script aborts the run instead of deleting anything.
    # This is also why the read stays a plain command instead of a part of a
    # condition: a function called in a condition runs with unset -e suspended
    # for the whole call, and an empty answer would be taken for consent.
    local confirm
    read -r -p "Press [Enter] to delete $count items, or [s]kip:" confirm

    if [ -n "$confirm" ]
    then
      echo "Skipped deletion of $count items."
      return
    fi
  fi

  echo "Deleting $count items..."
  # Not using 'rm -rfv' because the recursive verbosity would be too noisy, and
  # not using 'find -delete' because it only removes empty directories, while
  # the items to prune, like build directories and caches, do contain files
  local item
  for item in "${items[@]}"
  do
    echo "  deleting: $item"
    rm -rf "$item"
    PRUNED_ITEMS=$((PRUNED_ITEMS + 1))
  done
}

# Tell what Debcraft occupies before anything is deleted, so that the sections
# below can be read as removing a part of it
prune_report_usage

# The build directories of all packages, if Debcraft has ever been run. Nothing
# here is required to exist: pruning a build directory that was never created is
# a no-op, not an error.
if [ -d "$BUILD_DIRS_PATH" ]
then
  # Build and release directories of failed builds, both those that failed
  # before anything was built into them, and those that failed halfway. The
  # directory itself is always removed in full, so only the shell test that
  # tells an abandoned directory apart from one with build results in it varies.
  # shellcheck disable=SC2016 # $1 is expanded by the inner 'sh -c', not here
  prune_section "Empty build and release directories (failed before build started)" \
    "$BUILD_DIRS_PATH" "${PRUNE_BUILD_DIRS[@]}" -mtime +"${PRUNE_AGE_DAYS}" \
    -exec sh -c '[ -z "$(find "$1" -type f 2>/dev/null)" ]' _ {} \;

  # shellcheck disable=SC2016 # $1 is expanded by the inner 'sh -c', not here
  prune_section "Build and release directories without .buildinfo (failed halfway)" \
    "$BUILD_DIRS_PATH" "${PRUNE_BUILD_DIRS[@]}" -mtime +"${PRUNE_AGE_DAYS}" \
    -exec sh -c '[ -z "$(find "$1" -maxdepth 1 -name "*.buildinfo" -type f 2>/dev/null)" ]' _ {} \;

  # Per-package build caches, where a 'stats' file that the compiler cache
  # updates on every use reveals whether the cache is still in use
  # shellcheck disable=SC2016 # $1 is expanded by the inner 'sh -c', not here
  prune_section "Stale per-package build caches (ccache/sccache)" \
    "$BUILD_DIRS_PATH" -maxdepth 1 -name "debcraft-cache-*" -type d \
    -exec sh -c '[ -z "$(find "$1" -name "stats" -type f -mtime -'"$PRUNE_AGE_DAYS"' -print -quit 2>/dev/null)" ]' \
    _ {} \;

  # Artifacts of successful builds and releases. The two are pruned together, as
  # they are the same artifacts of the same builds, only placed in a directory
  # of a different name, and the logs and .buildinfo files next to them are kept
  # either way
  prune_section "Old build and release artifacts (.deb, .orig.tar.*, .debian.tar.xz)" \
    "$BUILD_DIRS_PATH" -maxdepth 2 \
    \( -path "*/debcraft-build-*/*" -o -path "*/debcraft-release-*/*" \) \
    "${PRUNE_ARTIFACTS[@]}" -mtime +"${PRUNE_AGE_DAYS}"

  # Build contexts of container images that were built for a build or a release
  prune_section "Old container build context directories" \
    "$BUILD_DIRS_PATH" -maxdepth 1 -name "debcraft-container-*" -type d \
    -mtime +"${PRUNE_AGE_DAYS}"
else
  echo
  log_info "Debcraft has no build directories in '$BUILD_DIRS_PATH', skipping"
fi

# Container directories that older Debcraft versions created in source trees
# instead of in the build directories path
if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ]
then
  log_warn "HOME is unset or is root directory, skipping search for legacy Debcraft containers"
else
  prune_section "Legacy Debcraft container directories (outside ~/.cache/debcraft)" \
    "$HOME" -maxdepth 3 -name "debcraft-container-*" -type d \
    ! -path "${BUILD_DIRS_PATH}/*"
fi

# Tell how the run ended, and name the ways to reclaim more than it did. Both
# apply whether or not anything was pruned, as a run that pruned something can
# still be given a smaller age, and dangling images are left behind by every
# container build
echo
if [ "$PRUNED_ITEMS" -eq 0 ]
then
  log_info "Pruned nothing, as no files or directories older than $PRUNE_AGE_DAYS days were found."
else
  log_info "Pruned $PRUNED_ITEMS items older than $PRUNE_AGE_DAYS days."
fi

echo "Run 'debcraft prune --older-than <days>' with a smaller number of days to prune more."
echo "It is also recommended to run 'podman image prune' to remove the dangling images that no tag refers to and that are thus unused."

# @TODO: Delete after 2 years
# - deb files from build directories, as they take too much space
# - orig.tar.gz(.asc), debian.tar.xz from release dirs, take unnecessary space

# @TODO: Automatically compress with xz all logs or after a delay, or on explicit 'prune'?

# @TODO: For debcraft-* containers: podman volume prune --force && podman system prune --force
