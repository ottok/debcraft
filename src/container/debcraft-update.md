# To be able to submit MR the package must be on Salsa, but pushing could also
# be done from a fork

± gbp pull --track-missing
gbp:info: Fetching from default remote for each branch
gbp:info: Branch 'debian/latest' is already up to date.
gbp:info: Branch 'upstream/latest' is already up to date.
gbp:info: Branch 'pristine-tar' is already up to date.

± gbp import-dscs --debsnap --verbose $(basename $PWD)
...very slow...
gbp:warning: Version 26.4.23-0+deb12u1 already imported.
gbp:warning: Version 26.4.23-0+deb13u1 already imported.
gbp:warning: Version 26.4.23-1 already imported.

± gbp import-dsc apt:$(basename $PWD)/sid
gbp:info: Downloading 'galera-4/sid' using 'apt-get'...
gbp:warning: Version 26.4.23-1 already imported.

Alternatively run something along:
curl -sL https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/mariadb-10.6/1:10.6.22-0ubuntu0.22.04.1/mariadb-10.6_10.6.22-0ubuntu0.22.04.1.debian.tar.xz | tar xvJ

± grep 'Repository:' debian/upstream/metadata
Repository: https://github.com/codership/galera.git

For an example see e.g. https://salsa.debian.org/debian/dh-make/-/blob/master/lib/debian/upstream.ex/metadata.ex

± grep upstreamvcs .git/config
[remote "upstreamvcs"]
	fetch = +refs/heads/4.x:refs/remotes/upstreamvcs/4.x

± git fetch upstreamvcs --tags
remote: Enumerating objects: 55, done.
remote: Counting objects: 100% (33/33), done.
remote: Compressing objects: 100% (24/24), done.
remote: Total 55 (delta 10), reused 9 (delta 9), pack-reused 22 (from 1)
Unpacking objects: 100% (55/55), 142.64 KiB | 1.50 MiB/s, done.
From https://github.com/codership/galera
   6d8c35db..c71ef30a  4.x             -> upstreamvcs/4.x
 * [new tag]           release_26.4.24 -> release_26.4.24

git verify-tag release_26.4.24
error: release_26.4.24: cannot verify a non-tag object of type commit.

± git verify-tag mariadb-11.4.8
gpg: Signature made Wed 06 Aug 2025 06:19:16 AM PDT
gpg:                using RSA key 177F4010FE56CA3336300305F1656F24C74CD1D8
gpg: Good signature from "MariaDB Signing Key <signing-key@mariadb.org>" [full]

uscan only verifies if pgpmode=gittag?
https://salsa.debian.org/go-team/packages/webtunnel/-/commit/8512c2a963f012decb5cfc2d4721741fb530ab9f

# NOTE! The %(version)s is populated by git-buildpackage
# NOTE! Signing the upstream import tag is not possible inside Debcraft
# Would require mounting container with:
#    -v $(gpgconf --list-dir agent-socket):/run/user/1000/gnupg/S.gpg-agent
#    -e GPG_TTY=/dev/pts/0
# and inside container:
#    export GPG_AGENT_INFO=/run/user/1000/gnupg/S.gpg-agent

± gbp import-orig --uscan --no-sign-tags --no-interactive --postimport="dch -v %(version)s 'New upstream release'"
gbp:info: Launching uscan...
gpgv: Signature made Wed 10 Sep 2025 10:34:55 AM PDT
gpgv:                using RSA key 3D53839A70BC938B08CDD47F45460A518DA84635
gpgv: Good signature from "Codership Oy (Codership Signing Key) <info@galeracluster.com>"
gbp:info: Using uscan downloaded tarball ../galera-4_26.4.24.orig.tar.gz
gbp:info: Importing '../galera-4_26.4.24.orig.tar.gz' to branch 'upstream/latest'...
gbp:info: Source package is galera-4
gbp:info: Upstream version is 26.4.24
gbp:info: Replacing upstream source on 'debian/latest'
gbp:info: Running Postimport hook
gbp:info: Successfully imported version 26.4.24 of ../galera-4_26.4.24.orig.tar.gz

± git diff
diff --git a/debian/changelog b/debian/changelog
index ce71d7aa..3cb15560 100644
--- a/debian/changelog
+++ b/debian/changelog
@@ -1,3 +1,9 @@
+galera-4 (26.4.24-1) UNRELEASED; urgency=medium
+
+  * New upstream release
+
+ -- Otto Kekäläinen <otto@debian.org>  Thu, 09 Oct 2025 10:38:07 -0700
+
 galera-4 (26.4.23-1) unstable; urgency=medium


# Note that if upstream was already imported, and you are preparing an update on
# another branch, this command needs to be used instead:
± gbp import-ref --upstream-version=10.11.14 --postimport="dch -v %(version)s 'New upstream release'"
gbp:warning: This script is experimental, it might change incompatibly between versions.
gbp:info: Replacing upstream source on 'ubuntu/24.04-noble'
gbp:info: Running Postimport hook
gbp:info: Successfully imported version 10.11.14



# This is interactive if gbp.conf says so
± gbp dch --distribution=UNRELEASED --commit --commit-msg="Update changelog and refresh patches after %(version)s import" -- debian
gbp:info: Launching uscan...
gpgv: Signature made Wed 10 Sep 2025 10:34:55 AM PDT
gpgv:                using RSA key 3D53839A70BC938B08CDD47F45460A518DA84635
gpgv: Good signature from "Codership Oy (Codership Signing Key) <info@galeracluster.com>"
gbp:info: Using uscan downloaded tarball ../galera-4_26.4.24.orig.tar.gz
gbp:info: Importing '../galera-4_26.4.24.orig.tar.gz' to branch 'upstream/latest'...
gbp:info: Source package is galera-4
gbp:info: Upstream version is 26.4.24
gbp:info: Replacing upstream source on 'debian/latest'
gbp:info: Running Postimport hook
gbp:info: Successfully imported version 26.4.24 of ../galera-4_26.4.24.orig.tar.gz

± git show
commit 987c92d6fa250b58d32513c8faf435da53a66fff (HEAD -> debian/latest)
Author: Otto Kekäläinen <otto@debian.org>
Date:   Thu Oct 9 10:38:54 2025 -0700

    Update changelog and refresh patches after 26.4.24-1 import

diff --git a/debian/changelog b/debian/changelog
index ce71d7aa..742e67cb 100644
--- a/debian/changelog
+++ b/debian/changelog
@@ -1,3 +1,22 @@
+galera-4 (26.4.24-1) UNRELEASED; urgency=medium
+
+  * New upstream release
+  * Salsa CI: Enable most of Salsa CI features
+  * Salsa CI: Avoid using `apt-get -qq` in cases where it hides errors
+  * Salsa CI: Refactor for better flow and remove unnecessary parts
+  * Salsa CI: Ignore apt key errors when testing upgrades from old releases
+  * Salsa CI: Strip now obsolete apt key directives
+  * Salsa CI: Always assume `apt-get --yes`
+  * Salsa CI: Force apt/dpkg to install new config files and not stop
+  * Salsa CI: Remove existing /lib* diversions by base-files to upgrade it
+  * Salsa CI: Unify with similar job logic in MariaDB Server and Entr packages
+  * Salsa CI: Drop extra variables that don't seem to be necessary anymore
+  * Salsa CI: Automatically use archive.d.o for discontinued releases
+  * Salsa CI: Replace bullseye-backports with trixie-backports
+  * Salsa CI: Disable ARM builds until a shared ARM runners is available again
+
+ -- Otto Kekäläinen <otto@debian.org>  Thu, 09 Oct 2025 10:38:43 -0700
+
 galera-4 (26.4.23-1) unstable; urgency=medium


± git commit --amend --no-edit --message="$(git log -1 --pretty=%s | sed 's/\([0-9]\+\.[0-9.]\+\)-[0-9]\+/\1/g')"
[debian/latest 47ba97a2] Update changelog and refresh patches after 26.4.24 import
 Date: Thu Oct 9 10:38:54 2025 -0700
 2 files changed, 22 insertions(+), 3 deletions(-)

± gbp pq import --force --time-machine=10
gbp:info: 10 tries left
gbp:info: Trying to apply patches at '987c92d6fa250b58d32513c8faf435da53a66fff'
gbp:warning: Patch small_gcache_size_for_salsa.patch failed to apply, retrying with whitespace fixup
gbp:error: Failed to apply '/home/otto/galera/pkg-galera-4/galera-4/.git/gbp-pqg77zoyi4/patches/small_gcache_size_for_salsa.patch': Error running git apply: error: patch failed: galera/tests/defaults_check.cpp:60
error: galera/tests/defaults_check.cpp: patch does not apply
gbp:info: 9 tries left
gbp:info: Trying to apply patches at 'bf119b214ecdc3fc7b1db0851b1e533d33eedd75'
gbp:warning: Patch small_gcache_size_for_salsa.patch failed to apply, retrying with whitespace fixup
gbp:error: Failed to apply '/home/otto/galera/pkg-galera-4/galera-4/.git/gbp-pqg77zoyi4/patches/small_gcache_size_for_salsa.patch': Error running git apply: error: patch failed: galera/tests/defaults_check.cpp:60
error: galera/tests/defaults_check.cpp: patch does not apply
gbp:info: 8 tries left
gbp:info: Trying to apply patches at '54f2112eb2f733da67705d936a494323b711f3a3'
gbp:info: 2 patches listed in 'debian/patches/series' imported on 'patch-queue/debian/latest'

± git rebase -
First, rewinding head to replay your work on top of it...
Applying: Running daemon under nobody user is not recommended.
Applying: Reduce galera.cache size test for Salsa
Using index info to reconstruct a base tree...
M	galera/tests/defaults_check.cpp
Falling back to patching base and 3-way merge...
Auto-merging galera/tests/defaults_check.cpp

± gbp pq export --drop
gbp:info: On 'patch-queue/debian/latest', switching to 'debian/latest'
gbp:info: Generating patches from git (debian/latest..patch-queue/debian/latest)
gbp:info: Dropped branch 'patch-queue/debian/latest'.

± git commit --amend --all --no-edit
[debian/latest 67cbc192] Update changelog and refresh patches after 26.4.24 import
 Date: Thu Oct 9 10:38:54 2025 -0700
 2 files changed, 22 insertions(+), 3 deletions(-)


Run outside container to sign tag:

± git describe --tags upstream/latest
upstream/26.4.24

± git tag --points-at upstream/latest
upstream/26.4.24

± git tag --force -sign --message "$(git for-each-ref refs/tags/upstream/26.4.24 --format='%(contents:subject)')" upstream/26.4.24 upstream/latest
Updated tag 'upstream/26.4.24' (was 1331b185)

± git tag --force --sign --message="$(git tag --list --format='%(contents:subject)' upstream/26.4.24)" upstream/26.4.24 upstream/latest
Updated tag 'upstream/26.4.24' (was 179eda42)



git checkout -b "next/$(git branch --show-current)"
NEXT="$(git branch --show-current)"
git checkout debian/latest && git reset --hard HEAD^^
git checkout $NEXT
git push --set-upstream otto "$(git branch --show-current)"


gbp dch --release --commit -- debian
