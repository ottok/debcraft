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
	@echo -n "Codespell version: "
	@codespell --version
	@echo $$(shellcheck --version | head -n 2)
	@help2man --version | head -n 1

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
		--name "Easy, fast and secure way to build Debian packages" \
		--section 1 \
		--manual "Debcraft usage" \
		--output $(DESTDIR)/usr/share/man/man1/debcraft.1 \
		--no-info \
		./debcraft.sh
	# Filter out inclusion of DEB_BUILD_OPTIONS in static Makefile.
	sed -i -e 's@ (currently DEB_BUILD_OPTIONS=.*)\.@.@g' \
		$(DESTDIR)/usr/share/man/man1/debcraft.1

install: build
	install -v -p -D debcraft.sh $(DESTDIR)/usr/bin/debcraft
	install -v -p -D --mode=0644 bash-completion/debcraft-completion.sh $(DESTDIR)/usr/share/bash-completion/completions/debcraft
	# install -v -p -D --target-directory=$(DESTDIR)/usr/share/debcraft src/*
	# GNU 'install' does not support subdirectories, so use regular 'cp' instead
	cp -a src $(DESTDIR)/usr/share/debcraft

install-local:
	@echo "Installing Debcraft as symlinc at ~/bin/debcraft"
	mkdir -p ~/.local/bin
	mkdir -p ~/.local/share/bash-completion/completions
	ln --force --symbolic --verbose ${PWD}/debcraft.sh ~/.local/bin/debcraft
	ln --force --symbolic --verbose ${PWD}/bash-completion/debcraft-completion.sh ~/.local/share/bash-completion/completions/debcraft

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
