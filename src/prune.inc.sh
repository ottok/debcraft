#!/bin/bash

log_error "@TODO: Pruning not implemented"
exit 1

# @TODO: Delete immediately
# - builds that failed before build started (=all build directories with no files, only one of more empty directory)

# @TODO: Delete after X weeks
# - builds that filed halfway (=build directories without any .buildinfo files)

# @TODO: Delete after 2 years
# - deb files from build directories, as they take too much space
# - orig.tar.gz(.asc), debian.tar.xz from release dirs, take unnecessary space

# @TODO: Automatically compress with xz all logs or after a delay, or on explicit 'prune'?

# @TODO: For debcraft-* containers: podman volume prune --force && podman system prune --force
