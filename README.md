# Debcraft: Easiest way to modify and build Debian packages

Debcraft is a tool for developers to make high quality Debian packages effortlessly.

The core design principles are:
1. Be opinionated, make the correct thing automatically without asking user to make too many decisions, and when full automation is not possible, steer users to follow the beat practices in software development.
2. Use git, git-buildpackage and quilt as Debian is on a path to standardize on them as shown by https://trends.debian.net/.
3. Unlike traditional chroot based tools, Debcraft uses Linux containers for improved isolation, security and reproducibility.
4. Create build environment containers on the fly so users don't need to plan ahead what chroots or containers they have.
5. Have extremely fast rebuilds as that is what users are likely to spend most of their time on.
6. Store logs and artifacts from builds and help users review changes between builds and package versions to maximize users' understanding of how their changes affect the outcome.
7. Don't expect users to run the latest version of Debian or even Debian or Ubuntu at all. The barrier to run Debcraft should be as low as possible, so that anyone can participate in debugging Debian package builds and improving them.
8. Encourage users to submit improvements on Salsa and to collaborate with Debian and upstreams instead of just making their own private Debian packages.
9. Teach users about the Debian policy gradually and in context, so that over time users grow towards Debian maintainership.


## Installation

For the time being Debcraft is not available in the Debian repositories or even as a package at all. To use it, simply clone the git repository and link the script from any directory you have in your `$PATH`, such as `$HOME/bin`

```
git clone
cd debcraft
ln -s ${PWD}/debcraft.sh ~/bin/debcraft
```

## Use examples

```
$ debcraft build
Running in path /home/otto/debian/entr/pkg-entr/entr that has Debian package sources for 'entr'
Use 'podman' container image 'debcraft-entr-debian-sid' for package 'entr'
Building container 'debcraft-entr-debian-sid' in '/home/otto/debian/entr/pkg-entr/debcraft-container-entr' for build ID '1703089647.a4117db+master'
STEP 1/14: FROM debian:sid
...
COMMIT debcraft-entr-debian-sid
--> 2c907056c5f
Successfully tagged localhost/debcraft-entr-debian-sid:latest
2c907056c5f0aea133329f92316bec70270ba8f505361b6d77b95329626763c2
Previous build was in ../debcraft-build-entr-1703089512.a4117db+master
Building package in /home/otto/debian/entr/pkg-entr/debcraft-build-entr-1703089647.a4117db+master
Obey DEB_BUILD_OPTIONS=''
gbp:info: Performing the build
dpkg-buildpackage: info: source package entr
dpkg-buildpackage: info: source version 5.3-1
dpkg-buildpackage: info: source distribution unstable
dpkg-buildpackage: info: source changed by Otto Kekäläinen <otto@debian.org>
 dpkg-source --before-build .
dpkg-buildpackage: info: host architecture amd64
dpkg-source: info: using patch list from debian/patches/series
dpkg-source: info: applying libbsd-overlay.patch
dpkg-source: info: applying kfreebsd-support.patch
dpkg-source: info: applying debug-system-test.patch
dpkg-source: info: applying simplified-build-test.patch
dpkg-source: info: applying system-test-fixes.patch
 debian/rules clean
dh clean --buildsystem=makefile
   dh_auto_clean -O--buildsystem=makefile
   dh_autoreconf_clean -O--buildsystem=makefile
   dh_clean -O--buildsystem=makefile
 debian/rules binary
dh binary --buildsystem=makefile
   dh_update_autotools_config -O--buildsystem=makefile
   dh_autoreconf -O--buildsystem=makefile
   debian/rules override_dh_auto_configure
make[1]: Entering directory '/tmp/build/source'
ln -sf Makefile.linux Makefile
make[1]: Leaving directory '/tmp/build/source'
   dh_auto_build -O--buildsystem=makefile
	make -j8 "INSTALL=install --strip-program=true"
make[1]: Entering directory '/tmp/build/source'
cc -g -O2 -ffile-prefix-map=/tmp/build/source=. -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -D_GNU_SOURCE -D_LINUX_PORT -isystem /usr/include/bsd -DLIBBSD_OVERLAY  -Imissing -Wdate-time -D_FORTIFY_SOURCE=2 -DRELEASE=\"5.3\" -Wl,-z,relro -Wl,-z,now -lpthread -Wl,-z,nodlopen -Wl,-u,libbsd_init_func -lbsd-ctor -lbsd  missing/kqueue_inotify.c entr.c -o entr
entr.c: In function ‘run_utility’:
entr.c:416:17: warning: ignoring return value of ‘realpath’ declared with attribute ‘warn_unused_result’ [-Wunused-result]
  416 |                 realpath(leading_edge->fn, arg_buf);
      |                 ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
make[1]: Leaving directory '/tmp/build/source'
   dh_auto_test -O--buildsystem=makefile
	make -j8 test
make[1]: Entering directory '/tmp/build/source'
ls entr.1 | ./entr -zns 'wc $0'
 184  927 5126 /tmp/build/source/entr.1
sh returned exit code 0
make[1]: Leaving directory '/tmp/build/source'
   create-stamp debian/debhelper-build-stamp
   dh_testroot -O--buildsystem=makefile
   dh_prep -O--buildsystem=makefile
   debian/rules override_dh_auto_install
make[1]: Entering directory '/tmp/build/source'
dh_auto_install -- PREFIX=/usr
	make -j8 install DESTDIR=/tmp/build/source/debian/entr AM_UPDATE_INFO_DIR=no "INSTALL=install --strip-program=true" PREFIX=/usr
make[2]: Entering directory '/tmp/build/source'
install entr /tmp/build/source/debian/entr/usr/bin
install -m 644 entr.1 /tmp/build/source/debian/entr/usr/share/man/man1
make[2]: Leaving directory '/tmp/build/source'
make[1]: Leaving directory '/tmp/build/source'
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
dpkg-deb: building package 'entr' in '../entr_5.3-1_amd64.deb'.
dpkg-deb: building package 'entr-dbgsym' in '../entr-dbgsym_5.3-1_amd64.deb'.
 dpkg-genbuildinfo --build=binary -O../entr_5.3-1_amd64.buildinfo
 dpkg-genchanges --build=binary -O../entr_5.3-1_amd64.changes
dpkg-genchanges: info: binary-only upload (no source code included)
 dpkg-source --after-build .
dpkg-source: info: unapplying system-test-fixes.patch
dpkg-source: info: unapplying simplified-build-test.patch
dpkg-source: info: unapplying debug-system-test.patch
dpkg-source: info: unapplying kfreebsd-support.patch
dpkg-source: info: unapplying libbsd-overlay.patch
dpkg-buildpackage: info: binary-only upload (no source included)
Cache directory:    /.ccache
Config file:        /.ccache/ccache.conf
System config file: /etc/ccache.conf
Stats updated:      Wed Dec 20 16:27:30 2023
Local storage:
  Cache size (GiB): 0.0 / 5.0 ( 0.00%)
  Files:              0
  Hits:               0
  Misses:             0
  Reads:              0
  Writes:             0
Create lintian.log
Create filelist.log

Build completed in 5 seconds and created:
total 64K
 20K entr-dbgsym_5.3-1_amd64.deb
8.0K entr_5.3-1_amd64.build
8.0K entr_5.3-1_amd64.buildinfo
4.0K entr_5.3-1_amd64.changes
 20K entr_5.3-1_amd64.deb
4.0K filelist.log
   0 lintian.log

Build 1703089647.a4117db+master of entr completed successfully
Results visible in /home/otto/debian/entr/pkg-entr/debcraft-build-entr-1703089647.a4117db+master
You can use for example:
  meld ../debcraft-build-entr-1703089512.a4117db+master /home/otto/debian/entr/pkg-entr/debcraft-build-entr-1703089647.a4117db+master &
```

## Documentation

See `debcraft --help` for detailed usage instructions.

```
$ debcraft --help
usage: debcraft [options] <build|validate|release|prune> [<path|pkg|srcpkg|dsc|git-url>]

Debcraft is a tool to easily build .deb packages. The 'build' argument accepts
as a subargument any of:
  * path to directory with program sources including a debian/ subdirectory
    with the Debian packaging instructions
  * path to a .dsc file and source tarballs that can be built into a .deb
  * Debian package name, or source package name, that apt can download
  * git http(s) or ssh url that can be downloaded and built

The commands 'validate' and 'release' are intended to be used to finalilze
a package build. The command 'prune' will clean up temporary files by Debcraft.

In addition to parameters below, anything passed in DEB_BUILD_OPTIONS will also
be honored (currently DEB_BUILD_OPTIONS='').
Note that Debcraft builds never runs as root, and thus packages with
DEB_RULES_REQUIRES_ROOT are not supported.

optional arguments:
  --build-dirs-path    Path for writing build files and arfitacs (default: parent directory)
  --distribution       Linux distribution to build in (default: debian:sid)
  --container-command  container command to use (default: podman)
  --clean              ensure container base is updated and sources clean
  -h, --help           display this help and exit
  --version            display version and exit
```

## Debian package

The Debian package has intentionally not been created yet. For now the only way to install this is via a `git clone`, which should be fine to early adopters and also make the step to doing `git commits` and submitting them to the project low friction. When the tool is more mature it will be packaged and made available in Debian officially, as well as for other Linux distros where developers might want to work on packaging that targets multiple distros, Debian included.

## Feedback requested

Please test out Debcraft and share your feedback. Bug reports at https://salsa.debian.org/otto/debcraft/-/issues are welcome on for example:

* Documentation: Is it easy to start using Debcraft? How could the documentation be clarified further?
* Structure: Are you able to productively use Debcraft? Is the tool easy to reason about? Does the features and code architecture make sense?
* Compatibility: Does Debcraft work on your laptop and with your favorite Linux distro / release / package?

## Additional information

### Development as an open source project

*This project is open source and contributions are welcome!* The project maintains a promise that the initial review will happen in 48h for all Merge Requests received. The [code review will be conducted professionally]() and the code base aims to maintain a very high qualiy bar, so please reserve time to polish your code submission in a couple of review rounds.

The project is hosted at https://salsa.debian.org/otto/debcraft with mirrors at https://gitlab.com/ottok/debcraft and https://github.com/ottok/debcraft.

### Roadmap

Debcraft does not intend to replace well working existing tools like [git-buildpackage](https://honk.sigxcpu.org/piki/projects/git-buildpackage/), but rather build upon them making the overall process of as easy as possible. **Current development focus is to make the `debcraft build` as easy and efficient as possible** and it is already quite capable. The `release` is already fully usable. The `prune` currently does nothing.

The `validate` command only does static testing for the source directory without modifying anything. Something like `polish` to run [lintian-brush](https://manpages.debian.org/unstable/lintian-brush/lintian-brush.1.en.html) and other tools to automatically improve the package source code might be added later, or a command to run dynamic tests on the built binaries (create local repo, run piuparts, autopkgtests, some of the Salsa-CI tests locally etc).

To help Debian Developers with recurring work, a command such as `update` to automatically import a new upstream version might also be implemented later.

Search for _@TODO_ comments in the sources to see which parts are incomplete and pending to be written out.

### Programming language: Bash

Bash was specifically chosen as the main language to keep the code contribution barrier for this tool as low as possible. Additionally, as Debcraft mainly builds upon invoking other programs via their command-line interface, using Bash scripting helps keep the code base small and lean compared to using a proper programming language to run tens of subshells. If the limitations of Bash (e.g. lack of proper testing framework, limited control of output with merely ANSI codes, overly simplistic error handling..) starts to feel limiting parts of this tool might be rewritten in fast to develop language like Python, Mojo, Nim, Zig or Rust.

Note that Bash is used to its fullest. There is no need to restrict functionality to POSIX compatibility as Debcraft will always run on Linux using Linux containers anyway.

### High quality, secure and performant code

Despite being written with Bash, Debcraft still aims to highest possible code quality by enforcing that the code base in Shellcheck clean along with other applicable static testing, such as spellchecking. While running `set -e` is in effect to stop execution on any error unless explicitly handled. The Bash code should avoid spawning subshells if it can be avoided. For example us in-line [Bash parameter substitution](https://tldp.org/LDP/abs/html/parameter-substitution.html) instead of spawning `sed` commands in subshells.

There are no fixed release dates or fixed milestone scopes. Maintaining high quality triumps other priorities. This tool is intended to automate Debian packaging work that has existed for decades, and the tools should be robust enough to stand the test of time and serve for decades to come.

### Prioritize readability

It is more important for code to be easy to read and reason about than quick to write. Therefore, always spend a bit of extra effort to make things clear and easy to read. For example, write `--parameter` instead of just `-p` when possible. Most commands are also run with `--verbose` intentionally to expose to users what is happening. Automation in a developer tool does not mean that things should be hidden - in this tool automation is transparent, doing as much as possible on behalf of the user but still transparent about what is being done.

### Testing

To help with ensuring the above about code quality, the project has both Gitlab-CI for automatic testing and a simple `make test` command to run the same testing locally while developing.

### Name

Why the name _Debcraft_? Because the name _debuild_ was already taken. The 'craft' also helps setting users in the correct mindset, hinting towards that producing high quality Debian packages and maintaining operating system over many years and decades is not just a pure technical task, but involves following industry wisdoms, anticipating unknowns and hand-crafting and tuning things to be as perfect as possible.

### Related software

* [dpkg-buildpackage](https://manpages.debian.org/unstable/dpkg-dev/dpkg-buildpackage.1.en.html)
* [debuild](https://manpages.debian.org/unstable/devscripts/debuild.1.en.html)
* [UMT](https://wiki.ubuntu.com/SecurityTeam/BuildEnvironment#Setting_up_and_using_UMT)

## Licence

Debcraft is free and open source software as published under GPLv3.
