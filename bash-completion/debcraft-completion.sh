# -*- shell-script -*-

_debcraft() {
  local cur prev opts
  COMPREPLY=()

  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  commands="build validate release --help"

  COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )

  return 0
}

complete -o default -F _debcraft debcraft

# @TODO: see this for tips?
# https://salsa.debian.org/debian/devscripts/-/raw/main/scripts/debuild.bash_completion?ref_type=heads
