#!/bin/bash

export CCACHE_DIR=/var/cache/ccache
ccache --max-size 3G > /dev/null
# Reset cache counters without showing the "Statistics zeroed" message
ccache --zero-stats > /dev/null
# Put ccache wrappers for gcc, g++ etc in path before the real ones. To disable
# ccache, simply comment out this line.
export PATH="/usr/lib/ccache:${PATH}"

# As sscache has been available in Debian/Ubuntu only since December 2022, check
# that it exists in the current container before trying to use it
if command -v sccache > /dev/null
then
  export SCCACHE_DIR=/var/cache/sccache
  export SCCACHE_CACHE_SIZE=3G
  export SCCACHE_NO_DAEMON=1
  # Reset cache counters without showing the "Statistics zeroed." message in stderr
  sccache --zero-stats 2> /dev/null
  export RUSTC_WRAPPER=sccache
fi

# To enable sccache for C/C++ builds, turn off ccache by commenting the 'export
# PATH' that activates it, and instead turn on some of the options below to
# activate sccache. Note however, that in testing with Galera, the ccache took
# on averadge 45 seconds, while with sccache it took over 60 seconds. Thus using
# sccache is not necessarily faster.

# Override the gcc and g++ binary names as looked up by dpkg-buildpackage.
#export PATH="/usr/lib/sccache:${PATH}"
#
# According to
# https://github.com/mozilla/sccache?tab=readme-ov-file#symbolic-links the
# symbolic links set up by Debian won't work, but it does not say why. Trying to
# run the commands below results in 'Operation not permitted' in a container:
#ln -vf /usr/bin/sccache /usr/lib/sccache/g++
#ln -vf /usr/bin/sccache /usr/lib/sccache/gcc
#ln -vf /usr/bin/sccache /usr/lib/sccache/cc
#ln -vf /usr/bin/sccache /usr/lib/sccache/c++

# These work for plain Makefile base builds, but CMake errors with them on
#   "'/usr/bin/sccache gcc' is not a full path to an existing compiler tool"
#export CC="/usr/bin/sccache gcc"
#export CXX="/usr/bin/sccache g++"

# These work with CMake builds, but only CMake builds..
#export CMAKE_C_COMPILER_LAUNCHER=sccache
#export CMAKE_CXX_COMPILER_LAUNCHER=sccache

# This alone had no effect on regular Makefile nor CMake builds
#export CCACHE_PREFIX=sccache
