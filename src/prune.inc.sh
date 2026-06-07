#!/bin/bash

# Helper to interactively prune files matching a find expression
# Usage: prune_section "Description" "directory" [find arguments...]
prune_section() {
  local description="$1"
  local dir="$2"
  shift 2

  echo
  log_info "## $description"

  if [ ! -d "$dir" ]
  then
    log_info "Directory '$dir' does not exist, skipping."
    return
  fi

  local count
  count=$(find "$dir" "$@" -print 2>/dev/null | wc -l)

  if [ "$count" -eq 0 ]
  then
    log_info "No items found to prune."
    return
  fi

  log_info "Found $count files or directories to prune, among others:"
  find "$dir" "$@" -ls 2>/dev/null | head -n 25 || true

  if [ "$count" -gt 25 ]
  then
    echo "  .."
  fi

  echo
  read -r -p "Press [Enter] to delete $count files or directories, or type [s]kip to jump to next items instead:" confirm

  if [ -z "$confirm" ]
  then
    log_info "Deleting $count items..."
    # Not using rm -rfv because the recursive verbosity would be too noisy;
    # we already echo a single clean line per item above.
    # Not using find -delete because it only removes empty directories,
    # while the matched targets (build dirs, caches, etc.) typically contain files.
    while IFS= read -r -d '' item
    do
      echo "  deleting: $item"
      rm -rf "$item"
    done < <(find "$dir" "$@" -print0 2>/dev/null)
    log_info "Deleted $count items."
  else
    log_info "Skipped deletion of $count items."
  fi
}

if [ -z "${APT_CACHE_DIR:-}" ]
then
  log_error "APT_CACHE_DIR is not set - debcraft configuration is broken"
  exit 1
fi

# Prune apt cache files older than threshold
prune_section "Apt cache files older than ${PRUNE_AGE_DAYS} days" "$APT_CACHE_DIR" -name "partial" -prune -o -name "*.deb" -type f -ctime +"${PRUNE_AGE_DAYS}"

# Prune build directories that failed before build started (no files inside)
# shellcheck disable=SC2016 # $1 is expanded by inner sh -c, not the parent shell
prune_section "Empty build directories (failed before build started)" "$BUILD_DIRS_PATH" -maxdepth 1 \( -name "debcraft-build-*" -o -name "debcraft-release-*" \) -type d -mtime +"${PRUNE_AGE_DAYS}" -exec sh -c '[ -z "$(find "$1" -type f 2>/dev/null)" ]' _ {} \;

# Prune build directories that failed halfway (no .buildinfo files)
# shellcheck disable=SC2016 # $1 is expanded by inner sh -c, not the parent shell
prune_section "Build directories without .buildinfo (failed halfway)" "$BUILD_DIRS_PATH" -maxdepth 1 \( -name "debcraft-build-*" -o -name "debcraft-release-*" \) -type d -mtime +"${PRUNE_AGE_DAYS}" -exec sh -c '[ -z "$(find "$1" -maxdepth 1 -name "*.buildinfo" -type f 2>/dev/null)" ]' _ {} \;

# Prune stale per-package build caches (ccache/sccache)
echo
log_info "## Stale per-package build caches (ccache/sccache)"

if [ -d "$BUILD_DIRS_PATH" ]
then
  # shellcheck disable=SC2016 # $1 is expanded by inner sh -c, not the parent shell
  mapfile -t OLD_CACHES < <(find "$BUILD_DIRS_PATH" -maxdepth 1 -name "debcraft-cache-*" -type d \
    -exec sh -c '[ -z "$(find "$1" -name "stats" -type f -mtime -'"$PRUNE_AGE_DAYS"' -print -quit 2>/dev/null)" ]' _ {} \; -print)

  count=${#OLD_CACHES[@]}

  if [ "$count" -eq 0 ]
  then
    log_info "No stale per-package build caches found to prune."
  else
    log_info "Found $count stale cache directories to prune, among others:"
    printf '  %s\n' "${OLD_CACHES[@]}" | head -n 25 || true

    if [ "$count" -gt 25 ]
    then
      echo "  .."
    fi

    read -r -p "Press [Enter] to delete $count cache directories, or type [s]kip to jump to next items instead:" confirm

    if [ -z "$confirm" ]
    then
      log_info "Deleting $count cache directories..."
      for cache in "${OLD_CACHES[@]}"
      do
        echo "  deleting: $cache"
        rm -rf "$cache"
      done
      log_info "Deleted $count cache directories."
    else
      log_info "Skipped deletion of $count cache directories."
    fi
  fi
fi

# Prune old build artifacts from successful builds (keep logs and buildinfo)
prune_section "Old build artifacts (.deb, .orig.tar.*, .debian.tar.xz)" "$BUILD_DIRS_PATH" -maxdepth 2 -path "*/debcraft-build-*/*" -type f \( -name "*.deb" -o -name "*.orig.tar.*" -o -name "*.debian.tar.xz" \) -mtime +"${PRUNE_AGE_DAYS}"

# Prune old release artifacts
prune_section "Old release artifacts (.deb, .orig.tar.*, .debian.tar.xz)" "$BUILD_DIRS_PATH" -maxdepth 2 -path "*/debcraft-release-*/*" -type f \( -name "*.deb" -o -name "*.orig.tar.*" -o -name "*.debian.tar.xz" \) -mtime +"${PRUNE_AGE_DAYS}"

# Prune old container build contexts
echo
log_info "## Old container build contexts"

if [ -d "$BUILD_DIRS_PATH" ]
then
  mapfile -t OLD_CONTAINERS < <(find "$BUILD_DIRS_PATH" -maxdepth 1 -name "debcraft-container-*" -type d -mtime +"${PRUNE_AGE_DAYS}" -print)

  count=${#OLD_CONTAINERS[@]}

  if [ "$count" -eq 0 ]
  then
    log_info "No old container build contexts found to prune."
  else
    log_info "Found $count old container directories to prune, among others:"
    printf '  %s\n' "${OLD_CONTAINERS[@]}" | head -n 25 || true

    if [ "$count" -gt 25 ]
    then
      echo "  .."
    fi

    read -r -p "Press [Enter] to delete $count container directories, or type [s]kip to jump to next items instead:" confirm

    if [ -z "$confirm" ]
    then
      log_info "Deleting $count container directories..."
      for container in "${OLD_CONTAINERS[@]}"
      do
        echo "  deleting: $container"
        rm -rf "$container"
      done
      log_info "Deleted $count container directories."
    else
      log_info "Skipped deletion of $count container directories."
    fi
  fi
fi

# Prune legacy debcraft container directories scattered in source trees
echo
log_info "## Legacy debcraft container directories (outside cache)"

if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ]
then
  log_warn "HOME is unset or is root directory; skipping legacy container search for safety"
else
  mapfile -t LEGACY_CONTAINERS < <(find "$HOME" -maxdepth 3 -name "debcraft-container-*" -type d ! -path "${BUILD_DIRS_PATH}/*" 2>/dev/null)

  count=${#LEGACY_CONTAINERS[@]}

  if [ "$count" -eq 0 ]
  then
    log_info "No legacy debcraft container directories found."
  else
    log_info "Found $count legacy container directories to prune, among others:"
    printf '  %s\n' "${LEGACY_CONTAINERS[@]}" | head -n 25 || true

    if [ "$count" -gt 25 ]
    then
      echo "  .."
    fi

    read -r -p "Press [Enter] to delete $count legacy container directories, or type [s]kip to jump to next items instead:" confirm

    if [ -z "$confirm" ]
    then
      log_info "Deleting $count legacy container directories..."
      for container in "${LEGACY_CONTAINERS[@]}"
      do
        echo "  deleting: $container"
        rm -rf "$container"
      done
      log_info "Deleted $count legacy container directories."
    else
      log_info "Skipped deletion of $count legacy container directories."
    fi
  fi
fi

# @TODO: Delete after 2 years
# - deb files from build directories, as they take too much space
# - orig.tar.gz(.asc), debian.tar.xz from release dirs, take unnecessary space

# @TODO: Automatically compress with xz all logs or after a delay, or on explicit 'prune'?

# @TODO: For debcraft-* containers: podman volume prune --force && podman system prune --force
