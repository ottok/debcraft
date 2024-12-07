# -*- shell-script -*-
# debcraft(1) completion

_debcraft_complete() {
  local cur prev generic_options distributions
  COMPREPLY=()

  # Options that can be used with most commands in Debcraft
  generic_options="--build-dirs-path --distribution --container-command --pull --copy --clean"

  # Examples of distributions
  distributions="debian:sid debian:bookworm ubuntu:devel ubuntu:24.04"

  function find_targets() {
    local targets
    # If current word resolves to an actual directory of file path, look up
    # potential cancidates as targets
    if [ -n "$(find "$1"* -maxdepth 0 2>/dev/null)" ]
    then
      targets="$(find "$1"* -maxdepth 3 -type d -exec sh -c 'test -f "$1/debian/changelog"' _ {} \; -print 2>/dev/null)"
      targets="$targets $(find "$1"* -maxdepth 0 -type d -o -type f -name '*.dsc' 2>/dev/null)"
    fi
    echo $targets
  }

  # Current word the user is typing
  cur="${COMP_WORDS[COMP_CWORD]}"
  # Previous word
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # To debug, run in a separate windows `tail -F /tmp/debug`
  #echo "DEBUG: '$prev$cur'" >> /tmp/debug

  local options
  local targets

  case "$prev$cur" in
    debcraft-*)
      # First argument should be one these
      options="--help --version"
      ;;
    debcraft*)
      # First argument should be one these
      options="build validate test release shell prune --help --version"
      ;;
    build*|validate*)
      # Suggest directories, .dsc files, or URLs for 'build'
      targets="$(find_targets "$cur")"
      options="$generic_options $targets https://"
      ;;
    release*)
      options="$generic_options --with-binaries"
      ;;
    test*|shell*)
      options="$generic_options"
      ;;
    prune*)
      # These commands have no options
      ;;
    --container-command*)
      # Complete file paths for options requiring paths
      options="docker podman"
      ;;
    --distribution*)
      # Suggest common distributions
      options="$distributions"
      ;;
    *)
      # Fall back on generic options and paths
      options="$generic_options $targets https://"
      ;;
  esac

  COMPREPLY=( $(compgen -W "$options" -- "$cur") )
  return 0
}

complete -o nosort -F _debcraft_complete debcraft
