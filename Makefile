# Ensure errors are emitted past the pipes to tee
SHELL=/bin/bash -o pipefail

all: build test install

test: test-static test-debcraft

# All generic static tests that don't need Debcraft to actually run
test-static:
	@echo "Running static tests"
	codespell --interactive=0 --check-filenames --check-hidden --skip=.git
	shellcheck -x --shell=bash $(shell grep -Irnw -e '^#!.*/bash' | sort -u |cut -d ':' -f 1 | xargs)
	# @TODO: Evaluate using '-o all' to run extra validation (https://github.com/koalaman/shellcheck/wiki/Optional)
	# @TODO: podman build --validate Containerfile?

# Run Debcraft and ensure it behaves as expected
test-debcraft:
	@echo "Running Debcraft tests"
	tests/debcraft-tests.sh

#build: test
#	pandoc to convert README to h2mfile?
#	help2man -S "Debcraft" \
#	 -o "/usr/share/man/man1/debcraft.1" \
#	 -I "${h2mfile}" \
#	 --no-info \
#	 ./debcraft.sh

install: # build
	@echo "Installing Debcraft as symlinc at ~/bin/debcraft"
	ln --symbolic --verbose ${PWD}/debcraft.sh ~/bin/debcraft
	# @TODO: In future install scripts, man page, bash autocomplete etc in proper
	# system locations honoring $(DESTDIR)
