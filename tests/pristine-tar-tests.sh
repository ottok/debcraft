#!/bin/bash

# Unit tests for the pristine-tar tarball handling. These run without a
# container by using a real temporary git repository with a pristine-tar
# branch and fake pristine-tar/dpkg-query commands.

set -e
set -o pipefail

TEST_DIR="$(mktemp --directory)"
trap 'rm --recursive --force "$TEST_DIR"' EXIT

TEST_CMD_PATH="$(readlink --canonicalize-existing "$0")"
DEBCRAFT_SRC_DIR="$(dirname "$(dirname "$TEST_CMD_PATH")")"
PRISTINE_TAR_LIB="$DEBCRAFT_SRC_DIR/src/container/pristine-tar.inc.sh"
GENERIC_LIB="$DEBCRAFT_SRC_DIR/src/generic.inc.sh"

FAKE_BIN="$TEST_DIR/bin"
REPO_DIR="$TEST_DIR/repo"
SOURCE_DIR="$REPO_DIR/src"
PT_LOG="$TEST_DIR/pristine-tar.log"
TEST_PACKAGE="multipart-test"
TEST_VERSION="1.0"

mkdir --parents "$FAKE_BIN" "$SOURCE_DIR"

cat > "$FAKE_BIN/pristine-tar" <<'EOF'
#!/bin/bash
echo "pristine-tar $*" >> "$PT_LOG"
if [ "$1" != "checkout" ]
then
  exit 1
fi
output="$2"
if [ -n "${FAIL_MAIN:-}" ] && [[ "$output" == *".orig.tar."* ]]
then
  exit 1
fi
if [ -n "${FAIL_COMPONENT:-}" ] && [[ "$output" == *".orig-"* ]]
then
  exit 1
fi
mkdir --parents "$(dirname "$output")"
echo "fake tarball" > "$output"
if [[ "$*" == *--signature-file* ]]
then
  signature_file="${*: -1}"
  echo "fake signature" > "$signature_file"
fi
EOF
chmod +x "$FAKE_BIN/pristine-tar"

cat > "$FAKE_BIN/dpkg-query" <<'EOF'
#!/bin/bash
echo "${FAKE_PRISTINE_TAR_VERSION:-1.46}"
EOF
chmod +x "$FAKE_BIN/dpkg-query"

# Create a source repository with a pristine-tar branch that has a signed main
# tarball, an unsigned component tarball, and a signature for another version
# that shares the same version prefix.
cd "$SOURCE_DIR"
git init --quiet
git config user.name "Debcraft Test"
git config user.email "debcraft@example.com"
echo "source" > source-file
git add source-file
git commit --quiet --message "Initial source"
ORIGINAL_BRANCH="$(git symbolic-ref --short HEAD)"

git checkout --quiet --orphan pristine-tar
for file in \
  "${TEST_PACKAGE}_${TEST_VERSION}.orig.tar.xz.delta" \
  "${TEST_PACKAGE}_${TEST_VERSION}.orig.tar.xz.id" \
  "${TEST_PACKAGE}_${TEST_VERSION}.orig.tar.xz.asc" \
  "${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz.delta" \
  "${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz.id" \
  "${TEST_PACKAGE}_${TEST_VERSION}.1.orig.tar.xz.delta" \
  "${TEST_PACKAGE}_${TEST_VERSION}.1.orig.tar.xz.id" \
  "${TEST_PACKAGE}_${TEST_VERSION}.1.orig.tar.xz.asc"
do
  echo "pristine-tar data" > "$file"
done
git add .
git commit --quiet --message "Add pristine-tar data"
git checkout --quiet "$ORIGINAL_BRANCH"

function run_pristine_tar() {
  PATH="$FAKE_BIN:$PATH" \
    PT_LOG="$PT_LOG" \
    DEBIAN_VERSION="${TEST_VERSION}-1" \
    PACKAGE_NAME="$TEST_PACKAGE" \
    FAIL_MAIN="${FAIL_MAIN:-}" \
    FAIL_COMPONENT="${FAIL_COMPONENT:-}" \
    bash -c '
      log_info() { echo "INFO: $*"; }
      log_error() { echo "ERROR: $*"; }
      log_debug_var() { :; }
      source "$1"
    ' _ "$PRISTINE_TAR_LIB"
}

function assert_file() {
  if [ ! -f "$1" ]
  then
    echo "ERROR: Expected file '$1' to exist"
    exit 1
  fi
}

function assert_no_file() {
  if [ -e "$1" ]
  then
    echo "ERROR: Expected file '$1' not to exist"
    exit 1
  fi
}

function clean_tarballs() {
  rm --force "$REPO_DIR"/"${TEST_PACKAGE}"_*.orig*.tar.* \
    "$REPO_DIR"/"${TEST_PACKAGE}"_*.orig*.asc
}

echo "Testing signed main tarball with unsigned component tarball"
clean_tarballs
: > "$PT_LOG"
cd "$SOURCE_DIR"
run_pristine_tar
assert_file "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.orig.tar.xz"
assert_file "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.orig.tar.xz.asc"
assert_file "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz"
assert_no_file "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.1.orig.tar.xz"
grep --quiet --fixed-strings \
  "pristine-tar checkout ../${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz" \
  "$PT_LOG"

echo "Testing that an existing main tarball does not skip missing components"
clean_tarballs
echo "existing tarball" > "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.orig.tar.xz"
: > "$PT_LOG"
run_pristine_tar
assert_file "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz"
if grep --quiet --fixed-strings \
  "pristine-tar checkout ../${TEST_PACKAGE}_${TEST_VERSION}.orig.tar.xz" \
  "$PT_LOG"
then
  echo "ERROR: Existing main tarball was checked out from pristine-tar again"
  exit 1
fi

echo "Testing that component checkout failures are fatal"
clean_tarballs
if FAIL_COMPONENT=true run_pristine_tar > "$TEST_DIR/component-failure.log" 2>&1
then
  echo "ERROR: Component checkout failure did not abort"
  exit 1
fi
grep --quiet --fixed-strings \
  "pristine-tar failed to checkout component tarball" \
  "$TEST_DIR/component-failure.log"

echo "Testing that main tarball checkout failures fall back to gbp"
clean_tarballs
: > "$PT_LOG"
FAIL_MAIN=true run_pristine_tar > /dev/null
assert_file "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz"
assert_no_file "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.orig.tar.xz"

echo "Testing that pristine-tar 1.45 supports --signature-file"
clean_tarballs
: > "$PT_LOG"
FAKE_PRISTINE_TAR_VERSION=1.45 run_pristine_tar > /dev/null
grep --quiet --fixed-strings -- \
  "--signature-file ../${TEST_PACKAGE}_${TEST_VERSION}.orig.tar.xz.asc" \
  "$PT_LOG"

echo "Testing that component copies skip signature files"
clean_tarballs
echo "component" > "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz"
echo "signature" > "$REPO_DIR/${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz.asc"
mkdir --parents "$TEST_DIR/copy-target"
bash -c '
  source "$1"
  copy_upstream_component_tarballs "$2" "$3" "$4"
' _ "$GENERIC_LIB" "$TEST_PACKAGE" "$TEST_VERSION" "$TEST_DIR/copy-target"
assert_file "$TEST_DIR/copy-target/${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz"
assert_no_file "$TEST_DIR/copy-target/${TEST_PACKAGE}_${TEST_VERSION}.orig-component.tar.xz.asc"

echo "All pristine-tar tests passed"
