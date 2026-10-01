# Debcraft: Easy, fast and secure way to build Debian packages

* **Easy**: Build any Debian/Ubuntu package in one single command. If you don't
  have the package or source already downloaded, it will be done automatically.
  Also, a build container (both Podman and Docker supported) is automatically
  built using the target Debian or Ubuntu suite in `debian/changelog` and with
  exact build dependencies from `debian/control`. Users are spared from having
  to manually prepare ahead or maintain [sbuild](https://wiki.debian.org/sbuild)
  root file systems or similar. The command output is (relatively) easy to read,
  and it also teaches users about Debian packaging in context.

* **Fast**: Container layer caching is utilized to make builds and re-builds
  blazingly fast. Debian packages that support [ccache](https://ccache.dev/),
  as well as C/C++ and Rust builds that support
  [sccache](https://github.com/mozilla/sccache), build even faster.

* **Secure**: Builds happen inside hermetic containers with no network access.
  This ensures all dependencies are properly managed and the built binaries
  equally trustworthy as the source code it was built from. This also protects
  the host system from getting polluted with extra development libraries, and
  adds an extra layer of protection to prevent anything malicious in the source
  code from accessing secrets on the host system. The additional logs provided
  by Debcraft also help audit changes in Debian package sources and build
  artifacts.

  Commands that need to reach the network in order to do their job are the
  exceptions: the `build` and `release` commands run hermetically, but
  `improve`, `test` and `shell` deliberately do not, and `update` never runs a
  container at all.

## Usage

### Typical usage examples

#### Build a package straight from Debian unstable

```shell
debcraft build <package>
```

#### Build package from a specific Debian/Ubuntu release

```shell
debcraft build --distribution trixie <package>
```

#### Build from a local directory

```shell
debcraft build
```

#### Drop into a shell inside the build container for debugging

```shell
debcraft shell
```

Note that the shell is the one command that intentionally runs as `root` inside
the container, so that packages can be installed and upgraded while debugging,
whereas builds always run as an unprivileged user.

#### Automatically apply packaging improvements on a branch

```shell
git switch -c develop
debcraft improve
```

#### Update the package to the latest upstream version

```shell
debcraft update
```

#### Run the Debian-specific regression tests (autopkgtest)

```shell
debcraft test
```

#### Build and ensure all dependencies are latest possible

```shell
debcraft build --pull
```

#### Build on a copy so that the sources stay free of build artifacts

```shell
debcraft build --copy
```

#### Perform a cross build

```shell
debcraft build --host-architecture arm64
```

#### Build using additional packages from a local repository

```shell
debcraft build --extra-repository <path to .deb files>
```

#### List previous builds and their logs

```shell
debcraft logs
```

#### Build and publish to Launchpad Personal Package Archive (PPA)

```shell
DEBCRAFT_PPA=ppa:otto/ppa debcraft release
```

#### Copy build artifacts to another directory

```shell
debcraft build --release-to ~/deb-builds
```

#### Free disk space by removing old build directories

```shell
debcraft prune --older-than 180
```

#### Pass build options

```shell
DEB_BUILD_OPTIONS="parallel=4 nocheck noautodbgsym" debcraft build
```

### Command reference

```
$ debcraft --help
usage: debcraft <build|improve|test|release|update|shell|logs|prune> [options] [<path|pkg|srcpkg|dsc|git-url>]

Debcraft is a tool to easily build .deb packages. The 'build' argument accepts
any of the following:

  * path to directory with program sources including a debian/ subdirectory with
    the Debian packaging instructions

  * path to a .dsc file and source tarballs that can be built into a .deb

  * Debian package name or source package name that apt can download

  * git http(s) or ssh URL that can be downloaded and built

The command 'improve' will try to apply various improvements to the package
based on tools in Debian that automate package maintenance. The command 'test'
will run the Debian-specific regression test suite if the package has
autopkgtest support, and drops to a shell for investigation if tests fail to
pass. The command 'release' uploads a package that is ready to be released and
the command 'update' tries to update the package to the latest upstream version
if the package git repository layout is compatible.

The command 'shell' can be used to explore the container and 'prune' will
clean up temporary files created by Debcraft. Unlike the other commands,
'prune' is not tied to any source package and can be run from anywhere: it
cleans up the build directories of all packages, and reports how much disk
space Debcraft occupies before it deletes anything.

In addition to parameters below, anything passed in DEB_BUILD_OPTIONS will also
be honored (currently DEB_BUILD_OPTIONS=''). Successful builds
include running './debian/rules clean' to clean up artifacts, while failed
builds will leave them around for inspection.

optional arguments:
  --build-dirs-path       Path for writing build files and artifacts (default: ~/.cache/debcraft)
  --distribution          Linux distribution to build in (default: debian:sid)
  --container-command     Container command to use (default: podman)
  --host-architecture     Host architecture to use when performing a cross build
  --skip-sources          Build only binaries and skip creating a source
                          tarball to make the build slightly faster
                          ('debcraft build' only)
  --with-binaries         Create a release with both source and binaries,
                          for example with the intent to upload to NEW
                          ('debcraft release' only)
  --pull                  Ensure container base is updated
  --copy                  Perform the build on a copy of the package directory
  --clean                 Ensure sources are clean before and after build
                          (only needed for packages with incomplete 'debian/clean'
                          or 'debian/.gitignore' definitions)
  --extra-repository      Use directory as local package repository for builds
  --config                Path to debcraft configuration file
  --release-to            After build or release, copy artefacts to specified dir
  --older-than            Only prune files and directories that are older than
                          the given number of days (default: 365)
                          ('debcraft prune' only)
  --yes                   Don't ask for confirmation, delete everything that
                          the action matches
                          ('debcraft prune' and PPA release uploads)
  --debug                 Emit debug information
  -h, --help              Display this help and exit
  --version               Display version and exit

To learn more, or to contribute to Debcraft, see project page at
https://salsa.debian.org/debian/debcraft

To gain more Debian Developer knowledge, please read
https://www.debian.org/doc/manuals/developers-reference/
and https://www.debian.org/doc/debian-policy/
```

### Example output from build

```
$ debcraft build
Running in directory /home/otto/debian/entr that has Debian package sources for 'entr'
Use 'podman' container image 'debcraft-entr-debian-sid' for package 'entr'
Building container 'debcraft-entr-debian-sid' in '/home/otto/.cache/debcraft/debcraft-container-entr' for build ID '1790865664.548d1d5+debian.latest'
STEP 1/36: FROM debian:sid
STEP 2/36: ARG HOST_ARCH
--> Using cache 2a3cb9adb7e1ef4dfd8ce7cb2b1b9a03dc7d1483b78dcbbe3e83385e8afb5ccb
--> 2a3cb9adb7e1
...
COMMIT debcraft-entr-debian-sid
--> 3665920e16bf
Successfully tagged localhost/debcraft-entr-debian-sid:latest
3665920e16bf9eb8216d49c417504f25615e46e49216f6d6027ca0961c37ef12
Previous build was in /home/otto/.cache/debcraft/debcraft-build-entr-1789446347.548d1d5+debian.latest
Previous tagged release was in /home/otto/.cache/debcraft/debcraft-build-entr-1789446347.548d1d5+debian.latest
Building package at /home/otto/.cache/debcraft/debcraft-build-entr-1790865664.548d1d5+debian.latest
'../entr_5.8.orig.tar.gz' -> '/home/otto/.cache/debcraft/debcraft-build-entr-1790865664.548d1d5+debian.latest/entr_5.8.orig.tar.gz'
Create original source package and signature using pristine-tar
pristine-tar: /debcraft/entr_5.8.orig.tar.gz already exists and is valid
pristine-tar: successfully generated ../entr_5.8.orig.tar.gz
pristine-tar: successfully generated ../entr_5.8.orig.tar.gz.asc
Using existing orig tarball, preventing gbp from creating a new one
DEB_BUILD_OPTIONS set as 'parallel=4 noautodbgsym'
Running 'dpkg-buildpackage --build=any,all' to create .deb packages
Running 'gbp buildpackage --git-no-create-orig' to create .deb packages from git repository
followed by './debian/rules clean' to ensure source directory is clean
gbp:info: Performing the build
dpkg-buildpackage: info: source package entr
dpkg-buildpackage: info: source version 5.8-1
dpkg-buildpackage: info: source distribution unstable
dpkg-buildpackage: info: source changed by Otto Kekäläinen <otto@debian.org>
 dpkg-source --before-build .
dpkg-buildpackage: info: host architecture amd64
dpkg-source: info: using patch list from debian/patches/series
dpkg-source: info: applying system-test-with-system-binary.patch
dpkg-source: info: applying Include-local-strlcpy.patch
 debian/rules clean
dh clean --buildsystem=makefile
   dh_auto_clean -O--buildsystem=makefile
   dh_autoreconf_clean -O--buildsystem=makefile
   dh_clean -O--buildsystem=makefile
 dpkg-source -b .
dpkg-source: info: using source format '3.0 (quilt)'
dpkg-source: info: verifying ../entr_5.8.orig.tar.gz.asc
dpkg-source: info: building entr using existing ../entr_5.8.orig.tar.gz
dpkg-source: info: building entr using existing ../entr_5.8.orig.tar.gz.asc
dpkg-source: info: using patch list from debian/patches/series
dpkg-source: info: building entr in ../entr_5.8-1.debian.tar.xz
dpkg-source: info: building entr in ../entr_5.8-1.dsc
 debian/rules binary
dh binary --buildsystem=makefile
   dh_update_autotools_config -O--buildsystem=makefile
   dh_autoreconf -O--buildsystem=makefile
   debian/rules override_dh_auto_configure
make[1]: Entering directory '/debcraft/source'
ln -sf Makefile.linux Makefile
make[1]: Leaving directory '/debcraft/source'
   dh_auto_build -O--buildsystem=makefile
	make -j4 INSTALL="install --strip-program=true"
make[1]: Entering directory '/debcraft/source'
cat /dev/null missing/kqueue_inotify.c missing/strlcpy.c > compat.c
cc -g -O2 -Werror=implicit-function-declaration -ffile-prefix-map=/debcraft/source=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wdate-time -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -D_LINUX_PORT -Imissing -DRELEASE=\"5.7\" -c status.c
cc -g -O2 -Werror=implicit-function-declaration -ffile-prefix-map=/debcraft/source=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wdate-time -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -D_LINUX_PORT -Imissing -DRELEASE=\"5.7\" -c entr.c
cc -g -O2 -Werror=implicit-function-declaration -ffile-prefix-map=/debcraft/source=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wdate-time -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -D_LINUX_PORT -Imissing -DRELEASE=\"5.7\" -c compat.c
status.c: In function 'start_log_filter':
status.c:48:17: warning: ignoring return value of 'asprintf' declared with attribute 'warn_unused_result' [-Wunused-result]
   48 |                 asprintf(&awk_script, "%s/.entr/status.awk", pw->pw_dir);
      |                 ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
cc -g -O2 -Werror=implicit-function-declaration -ffile-prefix-map=/debcraft/source=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wdate-time -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -D_LINUX_PORT -Imissing -o entr compat.o status.o entr.o -Wl,-z,relro -Wl,-z,now
make[1]: Leaving directory '/debcraft/source'
   dh_auto_test -O--buildsystem=makefile
	make -j4 test
make[1]: Entering directory '/debcraft/source'
ls entr.1 | EV_TRACE=1 ./entr -zn wc -l entr.1
open_max: 65536
209 entr.1
make[1]: Leaving directory '/debcraft/source'
   create-stamp debian/debhelper-build-stamp
   dh_testroot -O--buildsystem=makefile
   dh_prep -O--buildsystem=makefile
   debian/rules override_dh_auto_install
make[1]: Entering directory '/debcraft/source'
dh_auto_install -- PREFIX=/usr
	make -j4 install DESTDIR=/debcraft/source/debian/entr AM_UPDATE_INFO_DIR=no INSTALL="install --strip-program=true" PREFIX=/usr
make[2]: Entering directory '/debcraft/source'
install entr /debcraft/source/debian/entr/usr/bin
install -m 644 entr.1 /debcraft/source/debian/entr/usr/share/man/man1
make[2]: Leaving directory '/debcraft/source'
make[1]: Leaving directory '/debcraft/source'
   dh_installdocs -O--buildsystem=makefile
   dh_installchangelogs -O--buildsystem=makefile
   dh_installman -O--buildsystem=makefile
   dh_installsystemduser -O--buildsystem=makefile
   dh_perl -O--buildsystem=makefile
   dh_link -O--buildsystem=makefile
   dh_strip_nondeterminism -O--buildsystem=makefile
   dh_compress -O--buildsystem=makefile
   dh_fixperms -O--buildsystem=makefile
   dh_missing -O--buildsystem=makefile
   dh_dwz -a -O--buildsystem=makefile
   dh_strip -a -O--buildsystem=makefile
   dh_makeshlibs -a -O--buildsystem=makefile
   dh_shlibdeps -a -O--buildsystem=makefile
   dh_installdeb -O--buildsystem=makefile
   dh_gencontrol -O--buildsystem=makefile
   dh_md5sums -O--buildsystem=makefile
   dh_builddeb -O--buildsystem=makefile
dpkg-deb: building package 'entr' in '../entr_5.8-1_amd64.deb'.
 dpkg-genbuildinfo -O../entr_5.8-1_amd64.buildinfo
 dpkg-genchanges -O../entr_5.8-1_amd64.changes
dpkg-genchanges: info: including full source code in upload
 debian/rules clean
dh clean --buildsystem=makefile
   dh_auto_clean -O--buildsystem=makefile
	make -j4 distclean
make[1]: Entering directory '/debcraft/source'
rm -f *.o compat.c entr
rm -f Makefile
make[1]: Leaving directory '/debcraft/source'
   dh_autoreconf_clean -O--buildsystem=makefile
   dh_clean -O--buildsystem=makefile
 dpkg-source --after-build .
dpkg-source: info: unapplying Include-local-strlcpy.patch
dpkg-source: info: unapplying system-test-with-system-binary.patch
dpkg-buildpackage: info: full upload (original source is included)
Cache stats: ccache
Cache directory:       /debcraft/cache/ccache
Config file:           /debcraft/cache/ccache/ccache.conf
Directory config file:
System config file:    /etc/ccache.conf
Stats updated:         Thu Oct  1 14:41:42 2026
Cacheable calls:         3 /   5 (60.00%)
  Hits:                  0 /   3 ( 0.00%)
    Direct:              0
    Preprocessed:        0
  Misses:                3 /   3 (100.0%)
Uncacheable calls:       2 /   5 (40.00%)
  Called for linking:    1 /   2 (50.00%)
  No input file:         1 /   2 (50.00%)
Successful lookups:
  Direct:                0 /   3 ( 0.00%)
  Preprocessed:          0 /   3 ( 0.00%)
Local storage:
  Cache size (GB):     0.0 / 3.0 ( 0.04%)
  Files:                90
  Hits:                  0 /   3 ( 0.00%)
  Misses:                3 /   3 (100.0%)
  Reads:                 6
  Writes:                6

Create lintian.log
N:
P: entr source: package-uses-old-debhelper-compat-version 13
N:
N:   This package uses a debhelper compatibility level that is no longer
N:   recommended. Please consider using the recommended level.
N:
N:   For most packages, the best way to set the compatibility level is to
N:   specify debhelper-compat (= X) as a Build-Depends in debian/control. You
N:   can also use the debian/compat file or export DH_COMPAT in debian/rules.
N:
N:   If no level is selected debhelper defaults to level 1, which is
N:   deprecated.
N:
N:   Please refer to the debhelper(7) manual page for details.
N:
N:   Visibility: pedantic
N:   Show-Always: no
N:   Check: debhelper
N:

Create blhc.log
CFLAGS missing (-fPIE): cc -g -O2 -Werror=implicit-function-declaration -ffile-prefix-map=/debcraft/source=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wdate-time -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -D_LINUX_PORT -Imissing -DRELEASE=\"5.7\" -c compat.c
CFLAGS missing (-fPIE): cc -g -O2 -Werror=implicit-function-declaration -ffile-prefix-map=/debcraft/source=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wdate-time -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -D_LINUX_PORT -Imissing -DRELEASE=\"5.7\" -c entr.c
CFLAGS missing (-fPIE): cc -g -O2 -Werror=implicit-function-declaration -ffile-prefix-map=/debcraft/source=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wdate-time -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -D_LINUX_PORT -Imissing -DRELEASE=\"5.7\" -c status.c
LDFLAGS missing (-fPIE -pie): cc -g -O2 -Werror=implicit-function-declaration -ffile-prefix-map=/debcraft/source=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -Wdate-time -D_FORTIFY_SOURCE=2 -D_GNU_SOURCE -D_LINUX_PORT -Imissing -o entr compat.o status.o entr.o -Wl,-z,relro -Wl,-z,now

Create filelist.log

Create control.log and maintainer-scripts.log

Create diffoscope report comparing to previous build

Create diffoscope report comparing to last tagged build

Build completed in 10 seconds and created:
total 356K
4.0K blhc.log
4.0K build.err.log
4.0K build.err.log.diff
4.0K build.err.log.last-tagged.diff
8.0K build.log
4.0K build.log.diff
4.0K build.log.last-tagged.diff
8.0K buildinfo.log
8.0K buildinfo.log.diff
8.0K buildinfo.log.last-tagged.diff
4.0K changes.log
4.0K changes.log.diff
4.0K changes.log.last-tagged.diff
4.0K control.log
 88K diffoscope.last-tagged.html
 88K diffoscope.previous.html
 20K entr_5.8-1.debian.tar.xz
4.0K entr_5.8-1.dsc
8.0K entr_5.8-1_amd64.buildinfo
4.0K entr_5.8-1_amd64.changes
 24K entr_5.8-1_amd64.deb
 28K entr_5.8.orig.tar.gz
4.0K entr_5.8.orig.tar.gz.asc
4.0K filelist.log
4.0K lintian.log
4.0K lintian.log.diff
4.0K lintian.log.last-tagged.diff

Artifacts at /home/otto/.cache/debcraft/debcraft-build-entr-1790865664.548d1d5+debian.latest

To compare build artifacts with those of previous similar build you can use for example:
  meld /home/otto/.cache/debcraft/debcraft-build-entr-1789446347.548d1d5+debian.latest /home/otto/.cache/debcraft/debcraft-build-entr-1790865664.548d1d5+debian.latest &
  browse /home/otto/.cache/debcraft/debcraft-build-entr-1790865664.548d1d5+debian.latest/diffoscope.previous.html

To compare build artifacts with the previous tagged release run:
  meld /home/otto/.cache/debcraft/debcraft-build-entr-1789446347.548d1d5+debian.latest /home/otto/.cache/debcraft/debcraft-build-entr-1790865664.548d1d5+debian.latest &
  browse /home/otto/.cache/debcraft/debcraft-build-entr-1790865664.548d1d5+debian.latest/diffoscope.last-tagged.html
```

## Installation

### Debian package

[Debcraft](https://tracker.debian.org/pkg/debcraft) ships in Debian 13 "Trixie"
and in the `universe` component of Ubuntu 25.04 "Plucky" and newer. In those
distributions one can simply install with:

```
apt install debcraft
```

If you do not have Podman nor Docker installed, it will install Podman by
default.

### Development version

To use the latest development version, simply clone the git repository and run
`make install-local`, which links the script into `~/.local/bin`, a directory
that is part of `$PATH` on most distributions. Alternatively link the script
manually from any other directory you have in your `$PATH`.

```
git clone https://salsa.debian.org/debian/debcraft.git
cd debcraft
make install-local
```

## Caching build dependencies

The containers built by Debcraft use
[auto-apt-proxy](https://manpages.debian.org/unstable/auto-apt-proxy/auto-apt-proxy.1.en.html)
and will enable any proxy that was found at the time of building the container.

To benefit from caching,
[apt-cacher-ng](https://manpages.debian.org/unstable/apt-cacher-ng/apt-cacher-ng.8.en.html)
or equivalent needs to be installed on the host machine or somewhere on the
local network where `auto-apt-proxy` can find it. Example commands to install
and verify that caching works below:

```
$ sudo apt-get install --yes --no-install-recommends apt-cacher-ng
..

$ sudo systemctl enable --now apt-cacher-ng
Synchronizing state of apt-cacher-ng.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable apt-cacher-ng

$ ss -tlnp | grep 3142
LISTEN 0      250          0.0.0.0:3142      0.0.0.0:*
LISTEN 0      250             [::]:3142         [::]:*

$ sudo tail --follow /var/log/apt-cacher-ng/apt-cacher.log
[sudo] password for otto:
1781237516|I|14782|192.168.1.8|debrep/dists/sid/InRelease
1781237516|O|102|192.168.1.8|debrep/dists/sid/InRelease
1781237523|I|443636|192.168.1.8|debrep/pool/main/n/ncurses/ncurses-bin_6.6+20251231-1+b1_amd64.deb
1781237523|O|442411|192.168.1.8|debrep/pool/main/n/ncurses/ncurses-bin_6.6+20251231-1+b1_amd64.deb
1781237524|I|1678530|192.168.1.8|debrep/pool/main/p/perl/perl-base_5.40.1-8_amd64.deb
1781237524|O|1677282|192.168.1.8|debrep/pool/main/p/perl/perl-base_5.40.1-8_amd64.deb
1781237524|I|1099100|192.168.1.8|debrep/pool/main/g/glibc/libc-gconv-modules-extra_2.42-16_amd64.deb
1781237524|O|1097877|192.168.1.8|debrep/pool/main/g/glibc/libc-gconv-modules-extra_2.42-16_amd64.deb
```

During the container build you would see something along:

```
STEP 17/36: RUN apt-get update -q &&     apt-get install -q --yes --no-install-recommends       auto-apt-proxy && ...
Get:1 http://deb.debian.org/debian sid InRelease [189 kB]
Get:2 http://deb.debian.org/debian sid/main amd64 Packages [10.5 MB]
...
Setting up auto-apt-proxy (17.1) ...
Detected apt proxy: http://192.168.1.8:3142
```

## Development

### Design tenets

The core design principles are:
1. **Be opinionated, make the correct thing automatically** without asking user
   to make too many decisions, and when full automation is not possible, steer
   users to follow the best practices in software development.
2. Use [git](https://tracker.debian.org/pkg/git),
   [git-buildpackage](https://tracker.debian.org/pkg/git-buildpackage) as Debian
   is on a path to standardize on them as shown by the [Debian Trends
   website](https://trends.debian.net/).
3. **Use Linux containers** (not chroot like traditional Debian tools do) for
   improved isolation, security and reproducibility.
4. **Create build environment containers on the fly** so users don't need to
   plan ahead what containers or chroots to have.
5. **Be extremely fast** in what users are likely to spend most of their time
   on: rebuilds.
6. **Store logs and artifacts from builds and help users review changes**
   between builds and package versions to maximize users' understanding of how
   their changes affect the outcome.
7. **Don't expect users to run the latest version of Debian** or even Debian or
   Ubuntu at all. The barrier to run Debcraft should be as low as possible, so
   that anyone can participate in debugging Debian package builds and improving
   them.
8. **Encourage users to collaborate** and submit improvements upstream and on
   Salsa instead of just making their own private Debian packages.
9. **Teach users about the Debian policy** gradually and in context, so that
   over time users grow towards Debian maintainership.

Note! Debcraft builds never run as root, and thus packages that declare
`Rules-Requires-Root: yes` in `debian/control` are not supported, and won't be
supported as also [dpkg](https://manpages.debian.org/unstable/dpkg/) itself is
heading in the direction of never using root in package builds.

### Development as an open source project

**This project is open source and contributions are welcome!** The project
maintains a promise that the initial review will happen in 48h for all Merge
Requests received. The [code review will be conducted
professionally](https://optimizedbyotto.com/post/how-to-code-review/) and the
code base aims to maintain a very high quality bar, so please reserve time to
polish your code submission in a couple of review rounds.

The project is hosted at https://salsa.debian.org/debian/debcraft with mirrors at
https://gitlab.com/ottok/debcraft and https://github.com/ottok/debcraft.

### Programming language: Bash

Bash was specifically chosen as the main language for this tool in order to keep
the code contribution barrier as low as possible. Additionally, as Debcraft
mainly builds upon invoking other programs via their command-line interface,
using Bash scripting helps keep the code base small and lean compared to using a
proper programming language to run tens of subshells. If the limitations of Bash
(e.g. lack of proper testing framework, limited control of output with merely
ANSI codes, overly simplistic error handling etc) start to feel limiting, parts
of this tool might be rewritten in a fast to develop language like Python, Mojo,
Nim, Zig or Rust.

Note that Bash is used to the fullest. There is no need to restrict
functionality to POSIX compatibility as Debcraft will always run on Linux using
Linux containers anyway.

### High quality, secure and performant code

Despite being written with Bash, Debcraft still aims for the highest possible code
quality by enforcing that the code base is Shellcheck-clean along with other
applicable static testing, such as spellchecking. Also, running `set -e` is in
effect to stop execution on any error unless explicitly handled.

The Bash code should avoid spawning subshells if it can be avoided. For example
use in-line [Bash parameter
substitution](https://tldp.org/LDP/abs/html/parameter-substitution.html) instead
of spawning `sed` commands in subshells.

There are no fixed release dates or fixed milestone scopes. Maintaining high
quality trumps other priorities. This tool is intended to automate Debian
packaging work that has existed for decades, and the tools should be robust
enough to stand the test of time and serve for decades to come.

### Prioritize readability

It is more important for code to be easy to read and reason about than quick to
write. Therefore, always spend a bit of extra effort to make things clear and
easy to read. For example, write `--parameter` instead of just `-p` when
possible. Most commands are also run with `--debug` intentionally to expose to
users what is happening.

Automation in a developer tool does not mean that things should be hidden - in
this tool automation is transparent, doing as much as possible on behalf of the
user but still transparent about what is being done.

### Testing

To help with ensuring the above about code quality, the project has both GitLab
CI for automatic testing and a simple `make test` command to run the same
testing locally while developing.

### Name

Why the name _Debcraft_? Because the name _debuild_ was already taken. The
'craft' also helps set users in the correct mindset, hinting towards that
producing high quality Debian packages and maintaining an operating system over
many years and decades is not just a pure technical task, but involves following
industry wisdom, anticipating unknowns and hand-crafting and tuning things to
be as perfect as possible.

### Related software

* [dpkg-buildpackage](https://manpages.debian.org/unstable/dpkg-dev/dpkg-buildpackage.1.en.html)
* [debuild](https://manpages.debian.org/unstable/devscripts/debuild.1.en.html)
* [Deb-o-matic](https://debomatic.github.io/)
* [UMT](https://wiki.ubuntu.com/SecurityTeam/BuildEnvironment#Setting_up_and_using_UMT)

## Advanced usage examples

### GitHub Actions

If you would like to build Debian packages out of GitHub Actions, debcraft can
come in handy. GitHub Actions only offer Ubuntu-based runners, but debcraft
allows to build packages for different releases of both Debian and Ubuntu.

Unfortunately you cannot put a file in the directory `.github/workflows` directly
in a project which hosts a Debian package as it would fail to build due to
changes to the source.

A possible solution is to host the building logic in a separate repository
and fetch the proper sources for the package via parameters to the workflow.

See https://github.com/centic9/debian-packages/blob/main/.github/workflows/debian-package-debcraft.yml
for a resulting GitHub Action which can build any package as long as sources
are available in a repository on GitHub.

### Custom Distribution Mapping

If you are using a custom or private Debian derivative (e.g., Scibian, Kali
Linux) or need to use internal base images, you can map distribution names to
specific container images.

`debcraft` reads configuration files in the following order:
1. `/etc/debcraft`
2. `~/.config/debcraft`
3. A custom file provided via `--config <path>`

Example configuration file:

```bash
# /etc/debcraft
# The pattern should be as follow :
DEBCRAFT_DISTRIBUTION_MAPPING["distribution_name"]="container_image_name"
# e.g.
DEBCRAFT_DISTRIBUTION_MAPPING["scibian*"]="scibian"
DEBCRAFT_DISTRIBUTION_MAPPING["kali*"]="kali-linux/kali-rolling"
DEBCRAFT_DISTRIBUTION_MAPPING["custom-distribution*"]="my-registry.com/build-image"
```

**Note:** Pattern matching (globs) like `*` are supported for distribution names
parsed from the changelog.

## Copyright and licence

Copyright 2023-2026 Otto Kekäläinen & collaborators

Debcraft is free and open source software as published under GNU General Public
License version 3 or later (`GPL-3.0-or-later`).
