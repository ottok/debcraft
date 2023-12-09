
all: install

test:
	shellcheck
	podman Containerfile validate
	codespell --write-changes --summary

build:
	pandoc to convert README to h2mfile?

	help2man -S "Debcraft" \
	 -o "/usr/share/man/man1/debcraft.1" \
	 -I "${h2mfile}" \
	 --no-info \
	 ./debcraft.sh

install: build
	install files?
