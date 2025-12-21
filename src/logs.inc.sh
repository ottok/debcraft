#!/bin/bash

# Wrap the entire functionality inside a single functaion for better namespace
# and execution isolation
list_logs() {
  # The build directory path
  local DISPLAY_LOGS_PATH
  DISPLAY_LOGS_PATH="${BUILD_DIRS_PATH/#$HOME/\~}"

  if [ ! -d "$BUILD_DIRS_PATH" ]
  then
    log_error "Build directory '$DISPLAY_LOGS_PATH' does not exist"
    exit 1
  fi

  # A completed build generates a .buildinfo file, which is a reliable indicator
  # for a successful build. Find all such files for the current package, then
  # extract their unique parent directory paths.
  local files=()
  mapfile -t files < <(find "$BUILD_DIRS_PATH" -maxdepth 2 -type f -name "*.buildinfo" -path "*/debcraft-*-$PACKAGE-*/*" -printf "%h\n" | sort -u)

  if [ ${#files[@]} -eq 0 ]
  then
    log_warn "No completed logs found for package '$PACKAGE' in '$DISPLAY_LOGS_PATH'"
    return
  fi

  log_info "Available logs for completed builds in '$DISPLAY_LOGS_PATH':"

  # Add a header for the tabular output.
  printf "%-19s  %-8s  %-25s  %s\n" "TIMESTAMP" "COMMIT" "BRANCH" "PATH"
  # List full paths to completed build directories, sorted by modification time.
  # - stat: prints modification time (%Y, Unix epoch) and path (%n), separated by a semicolon.
  # - sort: sorts numerically (-n) based on the first field (-k1,1), using ';' as a delimiter (-t';').
  # - The while loop then reads each line, parses details from the path, and
  #   prints them in a tabular format for better readability.
  stat -c '%Y;%n' "${files[@]}" | sort -t';' -k1,1n | while IFS=';' read -r timestamp path
  do
    local dirname
    dirname=$(basename "$path")

    # The build_id always starts with a 10-digit Unix timestamp.
    local build_id
    build_id=$(echo "$dirname" | grep -oE '[0-9]{10}.*$')

    local branch="<none>"
    local commit="<none>"
    local commit_part

    if [[ $build_id == *+* ]]
    then
      branch="${build_id##*+}"
      commit_part="${build_id%%+*}"
    else
      commit_part="$build_id"
    fi

    if [[ $commit_part == *.* ]]
    then
      commit="${commit_part##*.}"
      commit="${commit:0:8}"
    fi

    local pretty_path
    pretty_path="${path/#$HOME/\~}"
    local pretty_date
    pretty_date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')

    printf "%-19s  %-8s  %-25s  %s\n" "$pretty_date" "$commit" "$branch" "$(clickable_link "file://$path" "$pretty_path")"
  done
}

list_logs
