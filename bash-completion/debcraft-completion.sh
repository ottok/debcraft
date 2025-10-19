# -*- shell-script -*-
# debcraft(1) completion

_debcraft_complete() {
  local cur prev generic_options distributions
  COMPREPLY=()

  # Options that can be used with most commands in Debcraft
  generic_options="--build-dirs-path --distribution --container-command --host-architecture --pull --copy --clean"

  # Examples of distributions
  distributions="debian:sid debian:bookworm ubuntu:devel ubuntu:24.04"

  # Examples of architectures
  architectures="alpha armel armhf arm64 hppa i386 amd64 m68k mips64el PowerPC PPC64 ppc64el riscv64 s390x SH4 sparc64 x32"

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
      options="build improve test release update shell logs prune --help --version"
      ;;
    improve*)
      # Suggest directories, .dsc files, or URLs for 'build'
      targets="$(find_targets "$cur")"
      options="$generic_options $targets https://"
      ;;
    build*)
       targets="$(find_targets "$cur")"
       options="$generic_options $targets --skip-sources https://"
      ;;
    release*)
      options="$generic_options --with-binaries"
      ;;
    update*)
      targets="$(find_targets "$cur")"
      options="--build-dirs-path --container-command --host-architecture --pull --copy --clean $targets https://"
      ;;
    test*|shell*)
      options="$generic_options"
      ;;
    logs*)
      targets="$(find_targets "$cur")"
      options="--build-dirs-path --copy --clean $targets"
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
    --host-architecture*)
      # Suggest common architectures
      options="$architectures"
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
