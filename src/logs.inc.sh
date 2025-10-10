run_logs() {
  log_info "Showing logs for package '$PACKAGE'"

  # The build directory path
  local LOGS_PATH="$BUILD_DIRS_PATH"
  local DISPLAY_LOGS_PATH
  DISPLAY_LOGS_PATH="$(echo "$LOGS_PATH" | sed "s|^$HOME|~|")"

  if [ ! -d "$LOGS_PATH" ]
  then
    log_warn "Build directory '$DISPLAY_LOGS_PATH' does not exist."
    return
  fi

  # Find all potential build/release directories for the package.
  local potential_dirs=()
  mapfile -d '' potential_dirs < <(find "$LOGS_PATH" -maxdepth 1 -type d \( -name "debcraft-build-$PACKAGE-*" -o -name "debcraft-release-$PACKAGE-*" \) -print0)

  # Filter for directories that contain a .buildinfo file, indicating a completed build.
  local files=()
  for dir in "${potential_dirs[@]}"
  do
    # A completed build has a .buildinfo file. Check for existence of at least one.
    if find "$dir" -maxdepth 1 -type f -name "*.buildinfo" -print -quit | grep -q .
    then
      files+=("$dir")
    fi
  done

  if [ ${#files[@]} -eq 0 ]
  then
    log_warn "No completed logs found for package '$PACKAGE' in '$DISPLAY_LOGS_PATH'."
    log_warn "Have you run a build or release for this package yet?"
    return
  fi

  log_info "Available logs for completed builds in '$DISPLAY_LOGS_PATH':"
  # List full paths to completed build directories, sorted by modification time.
  stat -c '%Y;%n' "${files[@]}" | sort -t';' -k1,1n | cut -d';' -f2- | sed "s|^$HOME|~|"
}

run_logs
