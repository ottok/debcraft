#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

# -------------------------------------------------------------------------
# Auto‑bump copyright year in debian/copyright
# -------------------------------------------------------------------------

CURRENT_YEAR=$(date +%Y)

log_debug "Current year: $CURRENT_YEAR"

# If the current year already appears anywhere, nothing to do
if grep -qF "$CURRENT_YEAR" debian/copyright
then
  echo "Copyright year $CURRENT_YEAR already present in debian/copyright"
else
  # Find authors (name + email) who have committed to any file under debian/
  # in the previous calendar year
  SINCE_DATE=$((CURRENT_YEAR - 1))-01-01
  log_debug "Looking for commits since $SINCE_DATE"
  mapfile -t authors < <(
    git log --since="$SINCE_DATE" --format='%aN <%aE>' -- debian/ 2>/dev/null |
      sort -u
  )
  log_debug "Authors found: ${authors[*]}"

  if (( ${#authors[@]} ))
  then
    # Build an associative array mapping author → start year (first year seen)
    declare -A start_year
    for author in "${authors[@]}"
    do
      log_debug "Processing author: $author"
      # Look for an existing line for this author (any year, not just at line start)
      if line=$(grep -E "${author}" debian/copyright)
      then
        # Extract the earliest year mentioned for this author (first occurrence)
        yr=$(printf '%s' "$line" | grep -Eo '[0-9]{4}' | head -n1)
        start_year["$author"]=$yr
        log_debug "Existing entry found, start year = $yr"
      else
        start_year["$author"]=$CURRENT_YEAR
        log_debug "No existing entry, using current year = $CURRENT_YEAR"
      fi
    done

    # Write a temporary mapping file for awk (author<TAB>start_year)
    map_file="$(mktemp)"
    for a in "${!start_year[@]}"
    do
      printf '%s\t%s\n' "$a" "${start_year[$a]}" >> "$map_file"
    done
    log_debug "Start‑year map contents:"
    log_debug_var "$map_file"

    # Create a temporary file that will become the new copyright file
    tmp_file="$(mktemp)"

    log_debug "Starting AWK processing to detect Files: debian/* stanza"

    awk -v yr="$CURRENT_YEAR" -v hdr="Copyright:" -v map_file="$map_file" '
      BEGIN {
        # Load author → start_year mapping
        while ((getline line < map_file) > 0) {
          split(line, parts, "\t")
          author[parts[1]] = parts[2]
        }
        close(map_file)
        skip_authors = 0
        found_files = 0
        # print "AWK: Starting processing, map loaded with " length(author) " authors" > "/dev/stderr"
      }

      # Detect single-line format: Files: debian/*
      /^Files:[[:space:]]+debian\/\*[[:space:]]*$/ {
        # print "AWK: Found single-line Files: debian/* at line " NR > "/dev/stderr"
        print $0
        print hdr
        for (a in author) {
          start = author[a]
          if (start == yr) range = yr
          else range = start "-" yr
          print " " range " " a
        }
        skip_authors = 1
        found_files = 1
        next
      }

      # Detect multi-line format: Files:\n debian/*
      /^Files:[[:space:]]*$/ {
        # print "AWK: Found Files: header at line " NR ", checking next line" > "/dev/stderr"
        current_line = $0
        # Read the next line to check if it contains debian/*
        if ((getline next_line) > 0) {
          # print "AWK: Next line is: [" next_line "]" > "/dev/stderr"
          if (next_line ~ /^[[:space:]]+debian\/\*/) {
            # print "AWK: Found debian/* on continuation line - processing stanza" > "/dev/stderr"
            print current_line
            print next_line
            print hdr
            for (a in author) {
              start = author[a]
              if (start == yr) range = yr
              else range = start "-" yr
              print " " range " " a
            }
            skip_authors = 1
            found_files = 1
            next
          } else {
            # print "AWK: Next line does not contain debian/*, printing normally" > "/dev/stderr"
            print current_line
            print next_line
            next
          }
        } else {
          # End of file after Files: line
          print current_line
          next
        }
      }

      # While inside the author block, skip the original Copyright line
      # and any indented author lines
      skip_authors {
        if ($0 ~ /^Copyright:/) {
          # print "AWK: Skipping original Copyright line at " NR > "/dev/stderr"
          next
        }
        if ($0 ~ /^ /) {
          # print "AWK: Skipping indented author line at " NR > "/dev/stderr"
          next
        }
        # End of block when a non‑indented line that is not a Copyright appears
        # print "AWK: End of author block at line " NR ", resuming normal output" > "/dev/stderr"
        skip_authors = 0
      }

      # Default action: print the line
      {
        print $0
      }

      END {
        if (!found_files) {
          print "ERROR: Files: debian/* stanza not found in original file!" > "/dev/stderr"
        }
      }
    ' debian/copyright > "$tmp_file" && mv "$tmp_file" debian/copyright

    # Ensure the file ends with a newline (add one only if missing)
    if [ "$(tail -c1 debian/copyright | od -An -tx1 | tr -d ' \n')" != "0a" ]
    then
      echo "" >> debian/copyright
    fi

    # Clean up the temporary mapping file
    rm -f "$map_file"

    # Commit the updated copyright file
    git add debian/copyright
    git commit -F - <<'EOF'
Update copyright years for recent contributors

EOF
  else
    echo "No recent contributors found for debian/, no copyright update needed"
  fi
fi
