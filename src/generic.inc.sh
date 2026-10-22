#!/bin/bash

# Clean up before (and after) a build
function reset_if_source_repository_and_option_clean() {
  if [ -n "$CLEAN" ] && [ -d "$PWD/.git" ]
  then
    echo
    log_info "Cleaning and resetting the git repository (including submodules)"
    git clean -fdx --quiet
    git submodule --quiet foreach --recursive git clean -fdx
    git reset --hard --quiet
    git submodule --quiet foreach --recursive git reset --hard
    git submodule --quiet update --init --recursive
  fi
}

# Copy upstream tarball from parent directory to destination if it exists
# Usage: copy_upstream_tarball <package> <version> <destination>
function copy_upstream_tarball() {
  local package="$1"
  local version="$2"
  local dest="$3"
  local tarball

  if tarball="$(find_orig_tarball "$package" "$version")"
  then
    cp_update_none "$tarball" "$dest/"
    return 0
  fi
  return 1
}

# Find the orig tarball in the parent directory
# Usage: find_orig_tarball <package> <version>
# Prints the tarball path if found
function find_orig_tarball() {
  local package="$1"
  local version="$2"
  local ext tarball

  # The package and version come from the local source tree controlled by the
  # user running Debcraft. Path traversal via these values is not a security
  # boundary, as the user can already modify or execute anything in the tree.
  for ext in xz gz bz2 lzma zst
  do
    tarball="../${package}_${version}.orig.tar.${ext}"
    if [ -f "$tarball" ]
    then
      printf '%s\n' "$tarball"
      return 0
    fi
  done
  return 1
}

# Check if orig tarball already exists in parent directory
# Usage: check_orig_tarball_exists <package> <version>
# Returns: 0 if found, 1 if not found
function check_orig_tarball_exists() {
  find_orig_tarball "$1" "$2" > /dev/null
}

# Check if a pristine-tar branch is available locally or on the remote
# Returns: 0 if found, 1 if not found
function pristine_tar_branch_exists() {
  if [ -n "$(git branch --list pristine-tar)" ]
  then
    return 0
  elif git show-ref --verify --quiet refs/remotes/origin/pristine-tar
  then
    return 0
  else
    return 1
  fi
}

# Check if the source package is native and thus does not use an orig tarball
function source_package_is_native() {
  local version

  if [ -f debian/source/format ]
  then
    if grep --quiet --fixed-strings "native" debian/source/format
    then
      return 0
    else
      return 1
    fi
  fi

  # Format 1.0 is native when the version has no Debian revision. Avoid
  # dpkg-parsechangelog as Debcraft may run on a non-Debian host.
  version="${DEBIAN_VERSION:-}"
  if [ -z "$version" ] && [ -f debian/changelog ]
  then
    version="$(head --lines=1 debian/changelog | cut --delimiter='(' --fields=2 | cut --delimiter=')' --fields=1)"
  fi

  if [ -z "$version" ]
  then
    return 1
  fi

  if [[ "$version" == *-* ]]
  then
    return 1
  fi

  return 0
}

# Download the orig tarball matching <version> from the Debian or Ubuntu archive.
# Usage: download_orig_tarball <package> <version> <destination>
# Returns: 0 on success, 1 if the tarball was not found or could not be fetched
function download_orig_tarball() {
  local package="$1"
  local version="$2"
  local dest="$3"
  local prefix archive component base_url url listing filename tmp sha256 size
  local -a archives components curl_download_args wget_download_args

  # Show download progress only when stderr is a terminal, to avoid flooding
  # CI logs or captured output with progress bar redraws.
  if [ -t 2 ]
  then
    curl_download_args=(--progress-bar)
    wget_download_args=(--progress=bar:force)
  else
    curl_download_args=(--silent)
    wget_download_args=(--quiet)
  fi

  # Debian and Ubuntu pool directories use the first four characters for
  # source package names starting with 'lib' (e.g. libabc -> liba) and the
  # first character otherwise. This follows the archive directory layout.
  case "$package" in
    lib*) prefix="${package:0:4}" ;;
    *) prefix="${package:0:1}" ;;
  esac

  # Prefer the archive matching the target distribution, then fall back to the
  # other one so packages published only in Ubuntu or only in Debian work.
  case "${BASEIMAGE:-}" in
    ubuntu:*)
      archives=("https://archive.ubuntu.com/ubuntu/pool" "https://deb.debian.org/debian/pool")
      ;;
    *)
      archives=("https://deb.debian.org/debian/pool" "https://archive.ubuntu.com/ubuntu/pool")
      ;;
  esac

  for archive in "${archives[@]}"
  do
    case "$archive" in
      *ubuntu.com*)
        components=(main restricted universe multiverse)
        ;;
      *)
        components=(main contrib non-free non-free-firmware)
        ;;
    esac

    for component in "${components[@]}"
    do
      base_url="${archive}/${component}/${prefix}/${package}/"
      log_debug "Checking for source package at $base_url"

      if command -v curl > /dev/null
      then
        if ! listing="$(curl --fail --location --silent --show-error "$base_url" 2> /dev/null)"
        then
          log_debug "No source package listing found at $base_url"
          continue
        fi
      elif command -v wget > /dev/null
      then
        if ! listing="$(wget --quiet --output-document=- "$base_url" 2> /dev/null)"
        then
          log_debug "No source package listing found at $base_url"
          continue
        fi
      else
        log_error "Neither 'curl' nor 'wget' is available to download the orig tarball"
        return 1
      fi

      # The trailing '|| true' prevents 'set -e' with 'pipefail' from aborting
      # when this archive component has no matching tarball.
      filename="$(printf '%s\n' "$listing" |
        grep --only-matching --perl-regexp 'href="\K[^"]+\.orig\.tar\.[[:alnum:]]+' |
        grep --fixed-strings -- "_${version}.orig.tar." |
        head --lines=1 || true)"

      if [ -n "$filename" ]
      then
        url="${base_url}${filename}"
        log_debug "Found '$filename' in $base_url"
        log_info "No upstream tarball found in parent directory, nor is there a pristine-tar branch present it could be derived from"
        log_info "Attempt to download it from $(clickable_link "$url")"
        if ! tmp="$(mktemp "$dest/.${filename}.XXXXXX")"
        then
          log_error "Unable to create a temporary file in '$dest'"
          return 1
        fi
        if command -v curl > /dev/null
        then
          log_debug "Running: curl --fail --location --show-error ${curl_download_args[*]} --output $tmp $url"
          if ! curl --fail --location --show-error "${curl_download_args[@]}" --output "$tmp" "$url"
          then
            rm --force "$tmp"
            return 1
          fi
        else
          log_debug "Running: wget ${wget_download_args[*]} --output-document=$tmp $url"
          if ! wget "${wget_download_args[@]}" --output-document="$tmp" "$url"
          then
            rm --force "$tmp"
            return 1
          fi
        fi
        chmod 0644 "$tmp"
        mv "$tmp" "$dest/$filename"
        if command -v sha256sum > /dev/null
        then
          sha256="$(sha256sum "$dest/$filename" | cut -d ' ' -f 1)"
        else
          sha256="$(shasum --algorithm 256 "$dest/$filename" | cut -d ' ' -f 1)"
        fi
        size="$(wc -c < "$dest/$filename" | tr -d '[:space:]')"
        log_info "Downloaded: $sha256 $size $filename"
        return 0
      fi
    done
  done

  return 1
}

# Ensure the orig tarball is available in the parent directory on the host.
# Usage: conditional_download_orig_tarball <package> <version>
function conditional_download_orig_tarball() {
  local package="$1"
  local version="$2"
  local parent orig_tarball
  parent="$(dirname "$PWD")"

  if source_package_is_native
  then
    return 0
  fi

  if orig_tarball="$(find_orig_tarball "$package" "$version")"
  then
    log_debug "Found existing $orig_tarball - it will be used"
    return 0
  fi

  # Without git there is no pristine-tar branch to export from, so the orig
  # tarball must already be present in the parent directory. Do not run any git
  # commands in a non-git source tree.
  if [ ! -e "$PWD/.git" ]
  then
    log_error "Unable to find the orig tarball for '$package' '$version'" \
              "in the parent directory." \
              "Run 'uscan --download-current-version' to fetch it" \
              "according to debian/watch, then retry."
    exit 1
  fi

  # If a pristine-tar branch exists, git-buildpackage in the container will
  # export the orig tarball from it. No host-side pristine-tar installation is
  # needed.
  if pristine_tar_branch_exists
  then
    log_debug "Found pristine-tar branch - the orig tarball will be exported from it"
    return 0
  else
    log_warn "Any existing 'upstream/*' git branch or tag cannot used" \
             "without a 'pristine-tar' branch, as the exported tarball may" \
             "end up having the wrong contents or file format, leading to" \
             "rejections of the resulting .change/.dsc contents."
  fi

  # Do not infer archive availability from the Debian revision: a -0/-1 package
  # may already have been uploaded, while a -2 or later revision may still be
  # waiting for its first upload. Just attempt the download and report failure.
  if download_orig_tarball "$package" "$version" "$parent"
  then
    return 0
  fi

  log_error "Unable to find the orig tarball for '$package' '$version'" \
            "in the parent directory." \
            "Run 'uscan --download-current-version' to fetch it" \
            "according to debian/watch, then retry."
  exit 1
}

# cp --update=none if available, otherwise use legacy/obsolete cp --no-clobber
# coreutils version 9.3 was released 2023-04-18
function cp_update_none() {
  coreutils_version=$(cp --version | head -1 | sed "s/.* //")
  if printf "9.3\n%s" "$coreutils_version" | sort --version-sort --check=quiet
  then
    cp --verbose --update=none "$@"
  else
    cp --verbose --no-clobber "$@"
  fi
}

# Ensure git user identity is available for operations that make commits.
# If the repository has local user.name/email, nothing is done.  If not
# locally but globally configured, exports GIT_AUTHOR_NAME,
# GIT_AUTHOR_EMAIL, GIT_COMMITTER_NAME and GIT_COMMITTER_EMAIL so the
# identity can be forwarded into containers.  If neither is configured,
# prints an error and exits.
function ensure_git_identity() {
  if git config --local user.name >/dev/null 2>&1 &&
     git config --local user.email >/dev/null 2>&1
  then
    return 0
  fi

  local global_name global_email
  global_name="$(git config --global user.name 2>/dev/null || true)"
  global_email="$(git config --global user.email 2>/dev/null || true)"

  if [ -n "$global_name" ] && [ -n "$global_email" ]
  then
    export GIT_AUTHOR_NAME="$global_name"
    export GIT_AUTHOR_EMAIL="$global_email"
    export GIT_COMMITTER_NAME="$global_name"
    export GIT_COMMITTER_EMAIL="$global_email"
    log_info "Using global git identity '$global_name <$global_email>'"
    return 0
  fi

  log_error "Git user name and email are not configured." \
            "Please set them in this repository with:" \
            "  git config --local user.name 'Your Name'" \
            "  git config --local user.email 'you@example.com'" \
            "Or configure them globally with:" \
            "  git config --global user.name 'Your Name'" \
            "  git config --global user.email 'you@example.com'"
  exit 1
}
