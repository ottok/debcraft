#!/bin/bash

# stop on any unhandled error
set -e

# @TODO: pipefail not in POSIX
set -o pipefail

# show commands (debug)
#set -x

# shellcheck source=src/container/output.inc.sh
source "/output.inc.sh"

VALIDATION_ERRORS=()

# @TODO: Nag if remote git branches for debian/upstream/pristine-tar have newer stuff than locally (risk for new local changes to be in vain)

# @TODO: Nag if git tags are missing for past debian/changelog releases (i.e. forgot to run 'gbp tag')

# @TODO: Nag if local git tags have not been pushed (i.e. forgot to run 'gbp push')

# @TODO: codespell --interactive=0 --check-filenames --check-hidden debian/
# @TODO: ^ automatically fix with extra parameter --write
# @TODO: find * -type f | xargs spellintian --picky
# @TODO: enchant-2 -d en -a debian/changelog # ispell line format, does not work for a human
# @TODO: aspell -d en -c debian/changelog # interactive mode, checks whole file not just latest entry
# @TODO: aspell --mode=debctrl -c debian/control
# @TODO: find -name *.md -exec aspell --mode=markdown -c "{}" +;
# @TODO: hunspell -d en_US debian/changelog # interactive mode

# @TODO: For each manpage run: LC_ALL=C.UTF-8 MANROFFSEQ='' MANWIDTH=80 man --warnings -E UTF-8 -l -Tutf8 -Z $MANPAGE >/dev/null

# @TODO: suspicious-source --verbose --directory . # no output if no findings, and most findings false positives

# @TODO: 'duck -v --color=always' check validity or URLS in debian/control, debian/upstream, debian/copyright etc

# @TODO: adequate # Findings for listdc++6 and libc6 out-of-the-box, but could
# be useful if current package installed and added to
# '/var/lib/adequate/pending' for limiting checks to it

# @TODO: Run autopkgtest inside container: autopkgtest -- null
# @TODO: However, autopkgtest needs root to install dependencies first, so needs to have build first, local repo and apt permissions

# @TODO: licensecheck --check=. --recursive --copyright . # only lists what licenses if found without actually
# validating anything about debian/copyright correctness

# @TODO: 'debmake -kk' produces diff that updates licenses for debian/copyright, but not years, and also seems incomplete

# @TODO: find . -type f \( -iname '*.po' -o -iname '*.pot' -o -iname '*.mo' -o -iname '*.gmo' \) -exec i18nspector --jobs 1 {} +
# @TODO: find . -type f \( -iname '*.po' -o -iname '*.pot' \) -exec msgfmt --check --check-compatibility --check-accelerators --output-file=/dev/null {} \;

# @TODO: find . -type f \( -iname '*.yaml' -o -iname '*.yml' -o -iwholename ./debian/upstream/metadata -o -iwholename ./debian/upstream/edam \) -exec yamllint {} +

# @TODO: blhc --all --debian --line-numbers --color *.build
# or alternatively as Salsa-CI uses: blhc --debian --line-numbers --color ${SALSA_CI_BLHC_ARGS} ${WORKING_DIR}/*.build || [ $? -eq 1 ]
# However both versions result in blhc outputting 'No compiler commands' so I am not sure if it works at all?

# @TODO: If allowed to modify package, run 'lintian-brush --no-update-changelog --modern --uncertain'?

# @TODO: diffoscope --html report.html old.deb new.deb

log_info "Validating files in debian/ in general with Debputy..."
if ! debputy lint --spellcheck > /dev/null
then
  log_error "Debputy reported issues, please run 'debputy lint --spellcheck'"
  VALIDATION_ERRORS+=('debputy-lint')
fi

log_info "Validating that files in debian/ are properly formatted and sorted..."
if ! debputy reformat --style black --no-auto-fix > /dev/null
then
  log_error "Debputy reported issues, please run 'debputy reformat --style black'"
  VALIDATION_ERRORS+=('deputy-reformat-black')
fi

log_info "Validating that all shell scripts in debian/rules pass Shellcheck..."
# End with  '|| true' to avoid emitting error codes in case no files were found
SH_SCRIPTS="$(grep -Irnw debian/ -e '^#!.*/sh' | sort -u | cut -d ':' -f 1 || true)"
BASH_SCRIPTS="$(grep -Irnw debian/ -e '^#!.*/bash' | sort -u | cut -d ':' -f 1 || true)"
if [ -n "$SH_SCRIPTS" ] || [ -n "$BASH_SCRIPTS" ]
then
  # shellcheck disable=SC2086 # intentional expansion of arguments
  if ! shellcheck -x --shell=sh $SH_SCRIPTS > /dev/null || ! shellcheck -x --shell=bash $BASH_SCRIPTS > /dev/null
  then
    log_error "Shellcheck reported issues, please run it manually"
    VALIDATION_ERRORS+=('shellcheck')

    # @TODO: Automatically fix by applying diff from `shellcheck -x --enable=all --format=diff`
  fi
fi

# Emit non-zero exit code if there was errors
if [ -n "${VALIDATION_ERRORS[*]}" ]
then
  log_error "Failed on errors: ${VALIDATION_ERRORS[*]}"
  exit 1
fi
