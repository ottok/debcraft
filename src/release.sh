#!/bin/bash

# Use subshell to avoid having cd .. back
(cd "$TARGET"; git reset --hard; git clean -fdx)

# Use subshell to avoid having cd .. back
# Use -S so all tools (dpkg-build, dpkg-source) see it. Using --build=source
# would not bee enough.
(cd "$TARGET"; gbp buildpackage --git-notify=on --git-builder="debuild --no-lintian -i -I" -S -d)

# Show source-only Lintian info without saving it in a file
# Don't fail if there are errors, as we often want to proceed to test uploads anyway
lintian -EvIL +pedantic --profile=debian --color=always ./*.changes || true
