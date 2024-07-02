#!/usr/bin/make -f
# SPDX-FileCopyrightText: 2024 Otto Kekäläinen <otto@debian.org>
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Ensure errors are emitted past the pipes to tee
SHELL=/bin/bash -o pipefail

DESTDIR:=tmp

all: build install

build-depends:
	@echo "Check all build dependencies are present"
	dpkg -l | grep -e codespell -e shellcheck -e help2man

build: manpage build-depends

# @TODO: Use '--include manpage-extras' to include additional info or write the
# README.md as ronn or Pandoc compatible Markdown and convert README.md to man
# page instead of --help (and the --help instead could run 'man --pager=cat
# debcraft'). See
# https://manpages.ubuntu.com/manpages/noble/en/man7/ronn-format.7.html and
# https://eddieantonio.ca/blog/2015/12/18/authoring-manpages-in-markdown-with-pandoc/
manpage:
	@echo "Generate man page for Debcraft"
	mkdir --verbose --parents $(DESTDIR)/usr/share/man/man1
	help2man \
		--name "Debcraft" \
		--source "Debcraft" \
		--section 1 \
		--manual "Debcraft usage" \
		--output $(DESTDIR)/usr/share/man/man1/debcraft.1 \
		--no-info \
		./debcraft.sh

install: build
	mkdir -p $(DESTDIR)/usr/bin
	install -v -p debcraft.sh $(DESTDIR)/usr/bin/debcraft

install-local:
	@echo "Installing Debcraft as symlinc at ~/bin/debcraft"
	ln --symbolic --verbose ${PWD}/debcraft.sh ~/bin/debcraft

test: test-static test-debcraft

# All generic static tests that don't need Debcraft to actually run
# @TODO: Evaluate using '-o all' to run extra validation (https://github.com/koalaman/shellcheck/wiki/Optional)
# @TODO: podman build --validate Containerfile?
test-static:
	@echo "Running static tests"
	codespell --interactive=0 --check-filenames --check-hidden --skip=.git
	shellcheck -x --shell=bash $(shell grep -Irnw -e '^#!.*/bash' | sort -u |cut -d ':' -f 1 | xargs)

# Run Debcraft and ensure it behaves as expected
test-debcraft:
	@echo "Running Debcraft tests"
	tests/debcraft-tests.sh
